--!strict
-- Services
-- Packages
local Result = require("@pkg/@nightcycle/result")
local Option = require("@pkg/@nightcycle/option")
local HashMap = require("@pkg/@nightcycle/hash-map")
local LuneUtil = require("@pkg/@nightcycle/lune-util")

-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type HashMap<K, V> = HashMap.HashMap<K, V>

export type PotentialSecret = string | Secret | LuneUtil.CompatSecret
type UrlStruct = any
-- type UrlStruct = {
-- 	_source: PotentialSecret,
-- 	_query: HashMap<PotentialSecret, PotentialSecret>,
-- }
type UrlImpl = {
	__tostring: (self: Url) -> string,
	__index: UrlImpl,
	display: (self: Url) -> PotentialSecret,
	path: (self: Url) -> Option<string>,
	protocol: (self: Url) -> Option<string>,
	domain: (self: Url) -> Option<string>,
	query: (self: Url) -> Option<string>,
}

export type Url = UrlStruct & UrlImpl

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Url = {} :: UrlImpl
Url.__index = Url

function newUrl(source: PotentialSecret, query: HashMap<PotentialSecret, PotentialSecret>): Url
	if typeof(source) == "string" and source:find("?") then
		local parts = string.split(source, "?")
		source = parts[1]
		local queryString = parts[2]
		local mutQuery = query:asMut()
		for _, part in ipairs(string.split(queryString, "&")) do
			local key, value = string.match(part, "([^=]+)=([^=]+)")
			if key and value then
				mutQuery:insert(key, value)
			end
		end
		query = mutQuery:freeze()
	end
	local out = setmetatable({
		_source = source,
		_query = query,
	}, Url)
	table.freeze(out)
	return out :: any
end

function Url:query(): Option<string>
	if self._query:isEmpty() then
		return Option.none()
	else
		local queryParts: { string } = {}
		for key, value in pairs(self._query:drain()) do
			assert(
				typeof(key) == "string" and typeof(value) == "string",
				"secret URL keys / values can't be returned as strings"
			)
			table.insert(queryParts, ("%s=%s"):format(key, value))
		end
		return Option.from(table.concat(queryParts, "&"))
	end
end

function Url:protocol(): Option<string>
	if typeof(self._source) == "string" then
		local parts = string.split(self._source, "://")
		return Option.from(parts[1])
	else
		error("Cannot get protocol from secret URL source")
	end
end

function Url:domain(): Option<string>
	if typeof(self._source) == "string" then
		local body = string.split(self._source, "://")[2]
		if body then
			local baseDomain = body:split("/")[1]
			if baseDomain and baseDomain:find("?") then
				baseDomain = baseDomain:split("?")[1]
			end
			if baseDomain and baseDomain:find("@") then -- email usernames
				baseDomain = baseDomain:split("@")[2]
			end
			return Option.from(baseDomain)
		end
		return Option.none()
	else
		error("Cannot get domain from secret URL source")
	end
end

function Url:path(): Option<string>
	if typeof(self._source) == "string" then
		local source = self._source:gsub("://", "")
		if source:find("/") == nil then
			return Option.none()
		end
		local parts = string.split(source, "/")
		table.remove(parts, 1)
		return Option.from(table.concat(parts, "/"):split("?")[1])
	else
		error("Cannot get path from secret URL source")
	end
end

function Url:display(): PotentialSecret
	local secretCount = if typeof(self._source) == "Secret" or typeof(self._source) == "table" then 1 else 0
	local isSourceSecret = secretCount == 1
	for key, value in pairs(self._query:drain()) do
		if typeof(key) == "Secret" or typeof(key) == "table" then
			secretCount += 1
		end
		if typeof(value) == "Secret" or typeof(value) == "table" then
			secretCount += 1
		end
	end
	if secretCount > 1 then
		error(`Cannot assemble URL with multiple secrets, found {secretCount}`)
	end

	if secretCount > 0 then
		if isSourceSecret then
			local queryParts: { string } = {}
			local source: Secret | LuneUtil.CompatSecret = self._source :: Secret | LuneUtil.CompatSecret
			for key, value in pairs(self._query:drain()) do
				table.insert(queryParts, ("%s=%s"):format(tostring(key), tostring(value)))
			end
			if #queryParts > 0 then
				local suffix = "?" .. table.concat(queryParts, "&")
				if typeof(source) == "table" then
					return source:AddSuffix(suffix)
				else
					return source:AddSuffix(suffix)
				end
			else
				return source
			end
		else
			local source: string = self._source :: string
			local prefix = source
			local suffix = ""
			local center: Option<Secret | LuneUtil.CompatSecret> = Option.none()
			local queryCount = 0
			for key, value in pairs(self._query:drain()) do
				queryCount += 1
			end
			if queryCount > 0 then
				prefix ..= "?"
			end
			local isPostSecret = false
			local queryIndex = 0
			for key: Secret | LuneUtil.CompatSecret | string, value: Secret | LuneUtil.CompatSecret | string in
				pairs(self._query:drain())
			do
				queryIndex += 1
				if typeof(key) == "table" or typeof(key) == "Secret" then
					isPostSecret = true
					center = Option.some(key)
					suffix ..= "="
				else
					if isPostSecret then
						suffix ..= `{key}=`
					else
						prefix ..= `{key}=`
					end
				end
				if typeof(value) == "table" or typeof(value) == "Secret" then
					isPostSecret = true
					center = Option.some(value)
				else
					if isPostSecret then
						suffix ..= `{value}`
					else
						prefix ..= `{value}`
					end
				end
				if queryCount ~= queryIndex then
					suffix ..= "&"
				end
			end
			if queryIndex > 0 then
				local centerValue = center:expect("Center value is not set")
				if typeof(centerValue) == "table" then
					return centerValue:AddPrefix(prefix):AddSuffix(suffix)
				else
					return centerValue:AddPrefix(prefix):AddSuffix(suffix)
				end
			else
				return source
			end
		end
	else
		local queryParts: { string } = {}
		for key, value in pairs(self._query:drain()) do
			table.insert(queryParts, `{key}={value}`)
		end
		local query = table.concat(queryParts, "&")
		return (self._source :: string) .. if #queryParts > 0 then "?" .. query else ""
	end
end

function Url:__tostring(): string
	return "Url<{" .. `"source": "{tostring(self._source)}", "query": "{tostring(self._query)}"` .. "}>"
end

return {
	from = function(
		value: PotentialSecret,
		query: (
			HashMap<PotentialSecret, PotentialSecret> | { [PotentialSecret]: PotentialSecret? }
		)?
	): Url
		return newUrl(
			value,
			if typeof(query) == "nil"
				then HashMap.empty()
				elseif HashMap.isHashMap(query) then query
				else HashMap.from(query :: any) :: any
		)
	end,
	isUrl = function(value: any?): boolean
		return if typeof(value) == "table" then getmetatable(value) == Url else false
	end,
}
