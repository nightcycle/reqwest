--!strict
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local LuneUtil = require("@pkg/@nightcycle/lune-util")
local Result = require("@pkg/@nightcycle/result")
local Error = require("@pkg/@nightcycle/error")
-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Error<V, B> = Error.Error<V, B>
export type Json = { [string]: string | boolean | number | Json } | { string | boolean | number | Json }
export type ContentType = "text/json" | "application/octet-stream" | "text/plain"
type EncodingError = Error<"EncodingError", ContentType>
type BodyImpl = {
	__index: BodyImpl,
	__tostring: (self: any) -> string,
	asBytes: (self: any) -> Result<buffer, EncodingError>,
	asText: (self: any) -> Result<string, EncodingError>,
	asJson: (self: any) -> Result<Json, EncodingError>,
}
type BodyStruct = {
	_contentType: ContentType,
	_content: Json | buffer | string,
}
export type Body = typeof(setmetatable({} :: BodyStruct, {} :: BodyImpl))
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Body = {} :: BodyImpl
Body.__index = Body

function Body:asBytes(): Result<buffer, EncodingError>
	local result = Result.try(function()
		if self._contentType == "text/json" then
			return buffer.fromstring(LuneUtil.Net.jsonEncode(self._content))
		elseif self._contentType == "application/octet-stream" then
			return self._content
		elseif self._contentType == "text/plain" then
			return buffer.fromstring(self._content)
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
			return LuneUtil.Net.jsonEncode(self._content)
		elseif self._contentType == "application/octet-stream" then
			return LuneUtil.Net.jsonEncode(buffer.tostring(self._content))
		elseif self._contentType == "text/plain" then
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
				:title("JSON Encoding Error")
				:build() :: Error<any, ContentType>
		)
	end
end

return {
	fromJson = function(content: Json): Body
		local out = setmetatable(
			{
				_contentType = "text/json",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out
	end,
	fromText = function(content: string): Body
		local out = setmetatable(
			{
				_contentType = "text/plain",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out
	end,
	fromOctetStream = function(content: buffer): Body
		local out = setmetatable(
			{
				_contentType = "application/octet-stream",
				_content = content,
			} :: BodyStruct,
			Body
		)
		table.freeze(out)
		return out
	end,
}
