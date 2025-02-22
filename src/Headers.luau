--!strict
-- Services
-- Packages
local Result = require("@wally/Result")
local Option = require("@wally/Option")
-- Modules
-- Types
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
export type TryFromHeaderValue = string | Secret
type HeaderValueImpl = {
	__index: HeaderValueImpl,
	tryFrom: (value: TryFromHeaderValue) -> Result<HeaderValue, string>,
}
export type HeaderValue = typeof(setmetatable(
	{} :: {
		value: TryFromHeaderName,
	},
	{} :: HeaderValueImpl
))
export type TryFromHeaderName = string | Secret
type HeaderNameImpl = {
	__index: HeaderNameImpl,
	tryFrom: (value: TryFromHeaderName) -> Result<HeaderName, string>,
}
export type HeaderName = typeof(setmetatable(
	{} :: {
		name: TryFromHeaderName,
	},
	{} :: HeaderNameImpl
))
type HeaderPair = {
	key: HeaderName,
	value: HeaderValue,
}
type HeaderMapImpl = {
	__index: HeaderMapImpl,
	new: () -> HeaderMap,
	clone: (self: HeaderMap) -> HeaderMap,
	containsKey: (self: HeaderMap, key: TryFromHeaderName) -> boolean,
	get: (self: HeaderMap, key: TryFromHeaderName) -> Option<HeaderValue>,
	getAll: (self: HeaderMap, key: TryFromHeaderName) -> { HeaderValue },
	insert: (
		self: HeaderMap,
		key: TryFromHeaderName,
		value: TryFromHeaderValue
	) -> Option<TryFromHeaderValue>,
	append: (self: HeaderMap, key: TryFromHeaderName, value: TryFromHeaderValue) -> boolean,
}
export type HeaderMap = typeof(setmetatable(
	{} :: {
		_pairs: { HeaderPair },
	},
	{} :: HeaderMapImpl
))

-- Constants
-- Variables
-- References
-- Private Functions
-- Class

local HeaderName = {}
HeaderName.__index = HeaderName

HeaderName.tryFrom = function(value: TryFromHeaderName): Result<HeaderName, string>
	return Result.err("Not implemented")
end

local HeaderValue = {}
HeaderValue.__index = HeaderValue

HeaderValue.tryFrom = function(value: TryFromHeaderValue): Result<HeaderValue, string>
	return Result.err("Not implemented")
end

local HeaderMap = {} :: HeaderMapImpl
HeaderMap.__index = HeaderMap

function HeaderMap:insert(key: TryFromHeaderName, value: TryFromHeaderValue): Option<TryFromHeaderValue>
	if HeaderMap.containsKey(self, key) then
		return Option.some(value)
	end
	local pair: HeaderPair = {
		key = HeaderName.tryFrom(key):unwrap(),
		value = HeaderValue.tryFrom(value):unwrap(),
	}

	table.freeze(pair)
	table.insert(self._pairs, pair)
	return Option.none()
end

function HeaderMap:append(key: TryFromHeaderName, value: TryFromHeaderValue): boolean
	local containedKey = HeaderMap.containsKey(self, key)

	local pair: HeaderPair = {
		key = HeaderName.tryFrom(key):unwrap(),
		value = HeaderValue.tryFrom(value):unwrap(),
	}
	table.freeze(pair)
	table.insert(self._pairs, pair)
	return containedKey
end

function HeaderMap:getAll(key: TryFromHeaderName): { HeaderValue }
	local out = {}
	for _, pair in ipairs(self._pairs) do
		if pair.key.name == key then
			table.insert(out, pair.value)
		end
	end
	return out
end

function HeaderMap:get(key: TryFromHeaderName): Option<HeaderValue>
	for _, pair in ipairs(self._pairs) do
		if pair.key.name == key then
			return Option.some(pair.value)
		end
	end
	return Option.none()
end

function HeaderMap:containsKey(key: TryFromHeaderName): boolean
	for _, pair in ipairs(self._pairs) do
		if pair.key.name == key then
			return true
		end
	end
	return false
end

function HeaderMap:clone(): HeaderMap
	local out = setmetatable({
		_pairs = table.clone(self._pairs),
	}, HeaderMap)
	table.freeze(out)
	return out
end

HeaderMap.new = function(): HeaderMap
	local out = setmetatable({
		_pairs = {},
	}, HeaderMap)
	table.freeze(out)
	return out
end

return {
	HeaderMap = HeaderMap,
	HeaderName = HeaderName,
	HeaderValue = HeaderValue,
}
