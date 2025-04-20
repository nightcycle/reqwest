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
type UrlImpl = {
	__tostring: (self: any) -> string,
	__index: UrlImpl,
	display: (self: any) -> PotentialSecret,
	path: (self: any) -> string,
	domain: (self: any) -> string,
	query: (
		self: any,
		query: HashMap<PotentialSecret, PotentialSecret> | { [PotentialSecret]: PotentialSecret }
	) -> Url,
}
type UrlStruct = {
	_source: PotentialSecret,
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

function newUrl(source: PotentialSecret, query: HashMap<PotentialSecret, PotentialSecret>): Url
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
			local source: Secret | LuneUtil.CompatSecret = self._source
			for key, value in pairs(self._query:drain()) do
				table.insert(queryParts, ("%s=%s"):format(key, value))
			end
			if #queryParts > 0 then
				local suffix = table.concat(queryParts, "&")
				if typeof(source) == "table" then
					return source:AddSuffix(suffix)
				else
					return source:AddSuffix(suffix)
				end
			else
				return source
			end
		else
			local source: string = self._source
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
			for key, value in pairs(self._query:drain()) do
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
						suffix ..= `={value}`
					else
						prefix ..= `={value}`
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
		return self._source .. if #queryParts > 0 then "?" .. query else ""
	end
end

function Url:__tostring(): string
	return "Url<{" .. `"source": "{tostring(self._source)}", "query": "{tostring(self._query)}"` .. "}>"
end

function Url:query(query: HashMap<PotentialSecret, PotentialSecret> | { [PotentialSecret]: PotentialSecret })
	return newUrl(self._source, if HashMap.isHashMap(query) then query :: any else HashMap.from(query))
end

return {
	tryFrom = function(value: PotentialSecret): Result<Url, string>
		return Result.try(function()
			return newUrl(value, HashMap.empty())
		end) :: any
	end,
	isUrl = function(value: any?): boolean
		return if typeof(value) == "table" then getmetatable(value) == Url else false
	end,
}
