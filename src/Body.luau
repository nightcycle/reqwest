--!strict
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local LuneUtil = require("@pkg/@nightcycle/lune-util")
local Result = require("@pkg/@nightcycle/result")
local Error = require("@pkg/@nightcycle/error")
local HashMap = require("@pkg/@nightcycle/hash-map")
-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Error<V, B> = Error.Error<V, B>
type HashMap<K, V> = HashMap.HashMap<K, V>

export type FieldValue = string | boolean | number
export type Json = { [string]: FieldValue | Json } | { FieldValue | Json }
export type FormFile = {
	fileName: string,
	contentType: string,
	data: string,
}
export type Form = {
	boundary: string,
	fields: HashMap<string, FieldValue | Json>,
	files: HashMap<string, FormFile>,
}
export type ContentType = "text/json" | "application/octet-stream" | "text/plain" | "multipart/form-data"
type EncodingError = Error<"EncodingError", ContentType>
type BodyImpl<V> = {
	__index: BodyImpl<V>,
	__tostring: (self: any) -> string,
	asBytes: (self: any) -> Result<buffer, EncodingError>,
	asText: (self: any) -> Result<V & string, EncodingError>,
	asJson: (self: any) -> Result<V & Json, EncodingError>,
	asForm: (self: any) -> Result<V & Form, EncodingError>,
}
type BodyStruct = {
	_contentType: ContentType,
	_content: Json | buffer | string | Form,
}
export type Body<V> = BodyImpl<V> --typeof(setmetatable({}, {} :: BodyImpl))
-- Constants
-- Variables
-- References
-- Private Functions
function generateBoundary(): string
	return "------------------------" .. LuneUtil.Net.generateGUID(false)
end
-- Class
local Body = {} :: BodyImpl<any>
Body.__index = Body

function Body:__tostring(): string
	return "Body<{" .. `"type": "{self._contentType}", "length": {self:asText():unwrap():len()}` .. "}>"
end

function Body:asBytes(): Result<buffer, EncodingError>
	local result = Result.try(function()
		if self._contentType == "text/json" then
			return buffer.fromstring(LuneUtil.Net.jsonEncode(self._content))
		elseif self._contentType == "application/octet-stream" then
			return self._content
		elseif self._contentType == "text/plain" then
			return buffer.fromstring(self._content)
		elseif self._contentType == "multipart/form-data" then
			return buffer.fromstring(self:asText():unwrap())
		else
			error(`Unknown content type: "{self._contentType}"`)
		end
	end)
	if result:isOk() then
		return Result.ok(result:unwrap())
	else
		return Result.err(
			Error.new("EncodingError")
				:body(self._contentType :: any)
				:description(result:unwrapErr())
				:title("Buffer Encoding Error")
				:build() :: Error<any, ContentType>
		)
	end
end

function Body:asText(): Result<string, EncodingError>
	local result = Result.try(function()
		if self._contentType == "text/json" then
			return LuneUtil.Net.jsonEncode(self._content)
		elseif self._contentType == "application/octet-stream" then
			return buffer.tostring(self._content)
		elseif self._contentType == "text/plain" then
			return self._content
		elseif self._contentType == "multipart/form-data" then
			local form: Form = self._content
			local boundary: string = form.boundary
			local body: string = ""

			-- Add regular form fields
			form.fields:forEachPair(function(name: string, value)
				body = body .. "--" .. boundary .. "\r\n"
				body = body .. 'Content-Disposition: form-data; name="' .. name .. '"\r\n\r\n'

				-- If value is a table, convert it to JSON
				if type(value) == "table" then
					body = body .. LuneUtil.Net.jsonEncode(value) .. "\r\n"
				else
					body = body .. tostring(value) .. "\r\n"
				end
			end)

			-- Add file fields
			form.files:forEachPair(function(name: string, file)
				body = body .. "--" .. boundary .. "\r\n"
				body = body
					.. 'Content-Disposition: form-data; name="'
					.. name
					.. '"; filename="'
					.. file.fileName
					.. '"\r\n'
				body = body
					.. "Content-Type: "
					.. (file.contentType or "application/octet-stream")
					.. "\r\n\r\n"
				body = body .. file.data .. "\r\n"
			end)

			-- Add closing boundary
			body = body .. "--" .. boundary .. "--"

			return body
		else
			error(`Unknown content type: "{self._contentType}"`)
		end
	end)
	if result:isOk() then
		return Result.ok(result:unwrap())
	else
		return Result.err(
			Error.new("EncodingError")
				:body(self._contentType :: any)
				:description(result:unwrapErr())
				:title("Text Encoding Error")
				:build() :: Error<any, ContentType>
		)
	end
end

function Body:asJson(): Result<Json, EncodingError>
	local result = Result.try(function()
		if self._contentType == "text/json" then
			return self._content
		elseif self._contentType == "application/octet-stream" then
			return LuneUtil.Net.jsonDecode(buffer.tostring(self._content))
		elseif self._contentType == "text/plain" then
			return LuneUtil.Net.jsonDecode(self._content)
		elseif self._contentType == "multipart/form-data" then
			local form: Form = self._content
			local files: { [string]: FormFile } = {}
			form.files:forEachPair(function(k: string, v)
				files[k] = {
					fileName = v.fileName,
					contentType = v.contentType,
					data = v.data,
				}
			end)
			local fields: { [string]: FieldValue } = {}
			form.files:forEachPair(function(k: string, v)
				fields[k] = v.data
			end)
			return {
				files = files,
				fields = fields,
				bounary = form.boundary,
			}
		else
			error(`Unknown content type: "{self._contentType}"`)
		end
	end)
	if result:isOk() then
		return Result.ok(result:unwrap() :: any)
	else
		return Result.err(
			Error.new("EncodingError")
				:body(self._contentType :: any)
				:description(result:unwrapErr())
				:title("JSON Encoding Error")
				:build() :: Error<any, ContentType>
		)
	end
end

function Body:asForm(): Result<Form, EncodingError>
	local result = Result.try(function(): Form
		local buildFromJson = function(json: Json): Form
			local boundaryOpt: Option<string> = Option.none()
			local fields: HashMap.MutHashMap<string, FieldValue | Json> = HashMap.emptyMut()
			local files: HashMap.MutHashMap<string, FormFile> = HashMap.emptyMut()

			for k, v in pairs(json) do
				if k == "boundary" then
					assert(typeof(v) == "string", `Boundary must be a string`)
					boundaryOpt = Option.some(v)
				elseif k == "fields" then
					assert(typeof(v) == "table", `Fields must be a table`)
					for fieldName, fieldValue in pairs(v) do
						if
							typeof(fieldValue) == "string"
							or typeof(fieldValue) == "boolean"
							or typeof(fieldValue) == "number"
							or typeof(fieldValue) == "table"
						then
							fields:insert(fieldName, fieldValue)
						else
							error(
								`Field value must be a string/boolean/number/table, got {typeof(fieldValue)}`
							)
						end
					end
				elseif k == "files" then
					assert(typeof(v) == "table", `Files must be a table`)
					for fileName, fileValue in pairs(v) do
						if
							typeof(fileValue) == "table"
							and typeof(fileValue.fileName) == "string"
							and typeof(fileValue.contentType) == "string"
							and typeof(fileValue.data) == "string"
						then
							files:insert(fileName, {
								fileName = fileValue.fileName,
								contentType = fileValue.contentType,
								data = fileValue.data,
							})
						else
							error(
								`File value at key "{fileName}" must be a table with fileName, contentType, and data`
							)
						end
					end
				else
					error(`Unknown key in JSON: {k}`)
				end
			end

			return table.freeze({
				boundary = boundaryOpt:expect(`"Boundary field not found"`),
				fields = fields:freeze(),
				files = files:freeze(),
			} :: Form)
		end

		local buildFromText = function(formData: string): Form
			-- Extract the boundary from the first line
			local boundaryLine = string.match(formData, "^--(.-)\r\n")
			if not boundaryLine then
				error("Invalid multipart form data: boundary not found")
			end

			local boundary = boundaryLine

			-- Initialize the Form object
			local fileMap: HashMap.MutHashMap<string, FormFile> = HashMap.emptyMut()
			local fieldMap: HashMap.MutHashMap<string, FieldValue | Json> = HashMap.emptyMut()
			-- Split the form data into parts using the boundary
			local parts = {}
			local currentPosition = 1
			local isDone = false

			while not isDone do
				-- Find the start of the next boundary
				local boundaryStart = string.find(formData, "--" .. boundary, currentPosition, true)
				if not boundaryStart then
					break
				end

				-- Check if this is the closing boundary
				if
					string.sub(formData, boundaryStart + #boundary + 2, boundaryStart + #boundary + 3) == "--"
				then
					isDone = true
					break
				end

				-- Find the end of this part (start of next boundary)
				local nextBoundaryStart =
					string.find(formData, "--" .. boundary, boundaryStart + #boundary, true)
				if not nextBoundaryStart then
					break
				end

				-- Extract the part content (skip the boundary line)
				local bStart = string.find(formData, "\r\n", boundaryStart)
				assert(bStart, `Boundary not found in part: {boundaryStart}`)
				local headerStart = bStart + 2
				local partContent = string.sub(formData, headerStart, nextBoundaryStart - 1)
				table.insert(parts, partContent)

				-- Move position
				currentPosition = nextBoundaryStart
			end

			-- Process each part
			for _, partContent in ipairs(parts) do
				-- Parse the headers and content
				local headers, content = string.match(partContent, "(.-)\r\n\r\n(.*)")
				if not headers or not content then
					continue
				end

				-- Remove trailing \r\n from content if present
				if string.sub(content, -2) == "\r\n" then
					content = string.sub(content, 1, -3)
				end

				-- Extract Content-Disposition header
				local contentDisposition = string.match(headers, "Content-Disposition: form%-data; (.*)")
				if not contentDisposition then
					continue
				end

				-- Extract name and filename (if present)
				local name = string.match(contentDisposition, 'name="(.-)"')
				assert(name, `Name not found in Content-Disposition header: "{contentDisposition}"`)
				local filename = string.match(contentDisposition, 'filename="(.-)"')

				if filename then
					-- This is a file field
					local contentType = string.match(headers, "Content-Type: (.-)\r\n")
						or "application/octet-stream"

					-- Add the file to the form
					fileMap:insert(name, {
						fileName = filename,
						contentType = contentType,
						data = content,
					})
				else
					-- This is a regular field
					-- Check if the content might be JSON
					local success, jsonData = pcall(function()
						return LuneUtil.Net.jsonDecode(content)
					end)

					if success and type(jsonData) == "table" then
						fieldMap:insert(name, jsonData)
					else
						-- Try to convert to appropriate primitive types
						local asNumber = tonumber(content)
						if asNumber then
							fieldMap:insert(name, asNumber)
						elseif content == "true" then
							fieldMap:insert(name, true)
						elseif content == "false" then
							fieldMap:insert(name, false)
						else
							fieldMap:insert(name, content)
						end
					end
				end
			end

			return table.freeze({
				boundary = boundary,
				fields = fieldMap:freeze(),
				files = fileMap:freeze(),
			})
		end

		if self._contentType == "text/json" then
			return buildFromJson(self._content)
		elseif self._contentType == "application/octet-stream" then
			return buildFromText(buffer.tostring(self._content))
		elseif self._contentType == "text/plain" then
			return buildFromText(self._content)
		elseif self._contentType == "multipart/form-data" then
			return self._content
		else
			error(`Unknown content type: "{self._contentType}"`)
		end
	end)
	if result:isOk() then
		return Result.ok(result:unwrap() :: any)
	else
		return Result.err(
			Error.new("EncodingError")
				:body(self._contentType :: any)
				:description(result:unwrapErr())
				:title("Form Encoding Error")
				:build() :: Error<any, ContentType>
		)
	end
end

return {
	fromForm = function<V>(
		fields: HashMap<string, FieldValue>,
		files: HashMap<string, FormFile>,
		boundary: Option<string>
	): Body<V>
		local out = setmetatable(
			{
				_contentType = "multipart/form-data",
				_content = table.freeze({
					boundary = boundary:unwrapOrElse(generateBoundary),
					fields = fields,
					files = files,
				}),
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out :: any
	end,
	fromJson = function<V>(content: Json): Body<V>
		local out = setmetatable(
			{
				_contentType = "text/json",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out :: any
	end,
	fromText = function<V>(content: string): Body<V>
		local out = setmetatable(
			{
				_contentType = "text/plain",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out :: any
	end,
	fromOctetStream = function<V>(content: buffer): Body<V>
		local out = setmetatable(
			{
				_contentType = "application/octet-stream",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out :: any
	end,
}
