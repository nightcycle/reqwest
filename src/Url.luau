--!strict
-- Services
-- Packages
local Result = require("@wally/Result")
local Option = require("@wally/Option")
-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
export type TryFromUrl = string | Secret
type UrlImpl = {
	__tostring: (self: Url) -> string | Secret,
	__index: UrlImpl,
	path: (self: Url) -> string,
	domain: (self: Url) -> string,
	query: (self: Url, query: { [string]: string }) -> Url,
	tryFrom: (value: TryFromUrl) -> Result<Url, string>,
}

export type Url = typeof(setmetatable(
	{} :: {
		_source: TryFromUrl,
		_query: { [string]: string },
	},
	{} :: UrlImpl
))

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Url = {} :: UrlImpl
Url.__index = Url

function newUrl(source: TryFromUrl, query: { [string]: string }): Url
	return setmetatable({
		_source = source,
		_query = table.freeze(table.clone(query)),
	}, Url)
end

function Url:domain(): string
	if typeof(self._source) == "string" then
		local parts = string.split(self._source, "/")
		return parts[1]
	else
		error("Cannot get domain from secret URL")
	end
end

function Url:path(): string
	if typeof(self._source) == "string" then
		local parts = string.split(self._source, "/")
		table.remove(parts, 1)
		return table.concat(parts, "/")
	else
		error("Cannot get path from secret URL")
	end
end

function Url:__tostring(): TryFromUrl
	local queryParts: { string } = {}
	for key, value in pairs(self._query) do
		table.insert(queryParts, ("%s=%s"):format(key, value))
	end
	local query = table.concat(queryParts, "&")
	if typeof(self._source) == "string" then
		return self._source .. if #queryParts > 0 then "?" .. query else ""
	else
		return self._source:AddSuffix("?" .. query)
	end
end

function Url:query(query: { [string]: string })
	return newUrl(self._source, query)
end

Url.tryFrom = (
	function(value: TryFromUrl): Result<Url, string>
		return Result.try(function()
			return newUrl(value, {})
		end) :: any
	end
) :: any

return {
	Url = Url,
}
