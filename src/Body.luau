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
export type Form = HashMap<string, string | boolean | number>
export type Json = { [string]: string | boolean | number | Json } | { string | boolean | number | Json }
export type ContentType =
	"text/json"
	| "application/octet-stream"
	| "text/plain"
	| "application/x-www-form-urlencoded"
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
		elseif self._contentType == "application/x-www-form-urlencoded" then
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
		elseif self._contentType == "application/x-www-form-urlencoded" then
			local txt = ""
			local form: Form = self._content
			local count = 0
			for k, v in pairs(form:drain()) do
				count += 1
				if type(v) == "string" then
					txt = txt .. k .. "=" .. v
				elseif type(v) == "number" then
					txt = txt .. k .. "=" .. tostring(v)
				elseif type(v) == "boolean" then
					txt = txt .. k .. "=" .. tostring(v)
				end
				if count < form:len() then
					txt = txt .. "&"
				end
			end
			return txt
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
			return LuneUtil.Net.jsonEncode(buffer.tostring(self._content))
		elseif self._contentType == "text/plain" then
			return LuneUtil.Net.jsonEncode(self._content)
		elseif self._contentType == "application/x-www-form-urlencoded" then
			local form: Form = self._content
			return form:drain() :: any
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
	local result = Result.try(function()
		if self._contentType == "text/json" then
			local mutHashMap = HashMap.emptyMut()
			for k, v in pairs(mutHashMap) do
				if typeof(k) == "number" then
					error(`array cannot be converted to form: got numeric key "{k}"`)
				end
				mutHashMap:insert(k, v)
			end
			return mutHashMap:freeze() :: any
		elseif self._contentType == "application/octet-stream" then
			local mutHashMap = HashMap.emptyMut()
			for k, v in string.gmatch(buffer.tostring(self._content), "([^&=]+)=([^&]*)") do
				if v == nil then
					continue
				end
				-- URL decode the key and value
				k = string.gsub(k, "%%(%x%x)", function(hex)
					local cNum = tonumber(hex, 16)
					assert(cNum, `Invalid hex value: "{hex}" radix 16`)
					return string.char(cNum)
				end)
				v = string.gsub(v, "%%(%x%x)", function(hex)
					local cNum = tonumber(hex, 16)
					assert(cNum, `Invalid hex value: "{hex}" radix 16`)
					return string.char(cNum)
				end)
				if tonumber(v) then
					local nV = tonumber(v)
					assert(nV, `Invalid number value: "{v}"`)
					mutHashMap:insert(k, nV)
				elseif v == "true" or v == "false" then
					mutHashMap:insert(k, v == "true")
				else
					mutHashMap:insert(k, v)
				end
			end
			return mutHashMap:freeze() :: any
		elseif self._contentType == "text/plain" then
			local mutHashMap = HashMap.emptyMut()
			for k, v in string.gmatch(self._content, "([^&=]+)=([^&]*)") do
				if v == nil then
					continue
				end
				-- URL decode the key and value
				k = string.gsub(k, "%%(%x%x)", function(hex)
					local cNum = tonumber(hex, 16)
					assert(cNum, `Invalid hex value: "{hex}" radix 16`)
					return string.char(cNum)
				end)
				v = string.gsub(v, "%%(%x%x)", function(hex)
					local cNum = tonumber(hex, 16)
					assert(cNum, `Invalid hex value: "{hex}" radix 16`)
					return string.char(cNum)
				end)
				if tonumber(v) then
					local nV = tonumber(v)
					assert(nV, `Invalid number value: "{v}"`)
					mutHashMap:insert(k, nV)
				elseif v == "true" or v == "false" then
					mutHashMap:insert(k, v == "true")
				else
					mutHashMap:insert(k, v)
				end
			end
			return mutHashMap:freeze() :: any
		elseif self._contentType == "application/x-www-form-urlencoded" then
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
	fromForm = function<V>(content: Form | { [string]: boolean | string | number }): Body<V>
		local out = setmetatable(
			{
				_contentType = "application/x-www-form-urlencoded",
				_content = if HashMap.isHashMap(content) then content else HashMap.from(content),
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
