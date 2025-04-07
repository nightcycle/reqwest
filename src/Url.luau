--!strict
-- Services
-- Packages
local Result = require("@pkg/@nightcycle/result")
local Option = require("@pkg/@nightcycle/option")
local HashMap = require("@pkg/@nightcycle/hash-map")
-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type HashMap<K, V> = HashMap.HashMap<K, V>
export type TryFromUrl = string | Secret
type UrlImpl = {
	__tostring: (self: any) -> string | Secret,
	__index: UrlImpl,
	path: (self: any) -> string,
	domain: (self: any) -> string,
	query: (self: any, query: HashMap<string, string>) -> Url,
}
type UrlStruct = {
	_source: TryFromUrl,
	_query: HashMap<string, string>,
}

export type Url = UrlImpl -- typeof(setmetatable({}, {} :: UrlImpl))

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Url = {} :: UrlImpl
Url.__index = Url

function newUrl(source: TryFromUrl, query: HashMap<string, string>): Url
	local out = setmetatable({
		_source = source,
		_query = query,
	}, Url)
	table.freeze(out)
	return out :: any
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
	for key, value in pairs(self._query:drain()) do
		table.insert(queryParts, ("%s=%s"):format(key, value))
	end
	local query = table.concat(queryParts, "&")
	if typeof(self._source) == "string" then
		return self._source .. if #queryParts > 0 then "?" .. query else ""
	else
		return self._source:AddSuffix("?" .. query)
	end
end

function Url:query(query: HashMap<string, string>)
	return newUrl(self._source, query)
end

return {
	tryFrom = function(value: TryFromUrl): Result<Url, string>
		return Result.try(function()
			return newUrl(value, HashMap.empty())
		end) :: any
	end,
}
