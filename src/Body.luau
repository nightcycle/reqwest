--!strict
-- Services
local HttpService = game:GetService("HttpService")
-- Packages
local SerdeJson = require("@wally/SerdeJson")
local Option = require("@wally/Option")
-- Modules
-- Types
type Option<V> = Option.Option<V>
export type Json = SerdeJson.AnyJson
export type ContentType = "text/json" | "application/octet-stream" | "text/plain"
type BodyImpl = {
	__index: BodyImpl,
	__tostring: (self: Body) -> string,
	asBytes: (self: Body) -> buffer,
	new: ((contentType: "text/json", content: Json) -> Body)
		& ((contentType: "application/octet-stream", content: buffer) -> Body)
		& ((contentType: "text/json", content: string) -> Body),
}
type BodyStruct = {
	_contentType: "text/json",
	_content: Json,
} | {
	_contentType: "application/octet-stream",
	_content: buffer,
} | {
	_contentType: "text/plain",
	_content: string,
}

export type Body = typeof(setmetatable({} :: BodyStruct, {} :: BodyImpl))
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Body = {} :: BodyImpl
Body.__index = Body

function Body:asBytes(): buffer
	if self._contentType == "text/json" then
		return buffer.fromstring(HttpService:JSONEncode(self._content))
	elseif self._contentType == "application/octet-stream" then
		return self._content
	elseif self._contentType == "text/plain" then
		return buffer.fromstring(self._content)
	else
		error("Unknown content type")
	end
end

function Body.new(contentType: ContentType, content: Json | buffer | string): Body
	local out = setmetatable(
		{
			_contentType = contentType,
			_content = content,
		} :: BodyStruct,
		Body
	)
	table.freeze(out)
	return out
end

return {
	Body = Body,
}
