--!strict
local LuneUtil = require("@pkg/@nightcycle/lune-util")
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local Result = require("@pkg/@nightcycle/result")
local Future = require("@pkg/@nightcycle/future")
local HashMap = require("@pkg/@nightcycle/hash-map")
local HashLib = require("@pkg/@nightcycle/hashlib")
-- Modules
local Url = require("./Url")
local Body = require("./Body")
local Response = require("./Response")
-- Types
type PotentialSecret = Url.PotentialSecret
type HashMap<K, V> = HashMap.HashMap<K, V>
type HeaderMap = Response.HeaderMap
type Url = Url.Url
type HeaderValue = Response.HeaderValue
type HeaderKey = Response.HeaderKey
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>
type Body<V> = Body.Body<V>

type RequestBuilderImpl = {
	__index: RequestBuilderImpl,
	__tostring: (self: RequestBuilder) -> string,
	basicAuth: (self: RequestBuilder, username: string, password: string) -> RequestBuilder,
	bearerAuth: (self: RequestBuilder, token: PotentialSecret) -> RequestBuilder,
	body: (self: RequestBuilder, body: Body<any>) -> RequestBuilder,
	build: (self: RequestBuilder) -> Request,
	header: (self: RequestBuilder, key: HeaderKey, value: HeaderValue) -> RequestBuilder,
	headers: (self: RequestBuilder, headers: HeaderMap) -> RequestBuilder,
	json: (self: RequestBuilder) -> RequestBuilder,
	send: <V, E>(self: RequestBuilder) -> Future<Result<Response<V>, Response<E>>>,
}
type Response<V> = Response.Response<V>

type RequestStruct = any
-- type RequestStruct = {
-- 	method: Method,
-- 	url: Url,
-- 	_body: Option<Body<any>>,
-- 	_headers: Option<HeaderMap>,
-- }
export type RequestBuilder = RequestStruct & RequestBuilderImpl
export type Method = "GET" | "POST" | "PUT" | "DELETE" | "OPTIONS" | "PATCH"

type RequestImpl = {
	__index: RequestImpl,
	__tostring: (self: RequestStruct) -> string,
	builder: (self: RequestStruct) -> RequestBuilder,
	send: <V, E>(self: RequestStruct) -> Future<Result<Response<V>, Response<E>>>,
	headers: (self: RequestStruct) -> Option<HeaderMap>,
	body: (self: RequestStruct) -> Option<Body<any>>,
	_asFetch: (self: RequestStruct) -> LuneUtil.FetchParams,
}
-- export type Request = RequestImpl & RequestStruct
export type Request = RequestImpl & {
	method: Method,
	url: Url,
}
-- Constants

-- Variables
-- References
-- Private Functions
-- Class
local Request = {} :: RequestImpl
Request.__index = Request

function Request:__tostring(): string
	return "Request<{"
		.. `"method": "{tostring(self.method)}", "url": "{tostring(self.url)}", "body": "{tostring(self._body)}", "headers": "{tostring(
			self._headers
		)}"`
		.. "}>"
end

local RequestBuilder = {} :: RequestBuilderImpl
RequestBuilder.__index = RequestBuilder

function RequestBuilder:__tostring(): string
	return "RequestBuilder<{"
		.. `"method": "{tostring(self.method)}", "url": "{tostring(self.url)}", "body": "{tostring(self._body)}", "headers": "{tostring(
			self._headers
		)}"`
		.. "}>"
end

function newRequest<V>(
	method: Method,
	url: Url | PotentialSecret,
	body: Option<V>,
	headers: Option<HeaderMap>
): Request
	local self = setmetatable({
		method = method,
		url = if Url.isUrl(url) then url else Url.from(url :: PotentialSecret),
		_body = body,
		_headers = headers,
	}, Request)
	table.freeze(self)
	return self :: any
end

function Request:builder(): RequestBuilder
	local builder: RequestStruct = table.clone(self :: any)
	local out = setmetatable(builder, RequestBuilder)
	table.freeze(out)
	return out :: any
end

function Request:_asFetch(): LuneUtil.FetchParams
	local url: string | Secret = (function(): string | Secret
		local out = self.url:display() :: PotentialSecret
		if typeof(out) == "table" then
			return out:Build() :: string | Secret
		end
		return out
	end)()

	local body: string? = self._body:match(function(out): string?
		return out:asText():expect(`failed to convert body to string`)
	end, function()
		return nil
	end)

	local headers: { [any]: any } = self._headers:match(function(map: HeaderMap): { [HeaderKey]: HeaderValue }
		local baseHeaders = map:drain()

		local finalHeaders: { [string | Secret]: string | Secret } = {}
		for key, value in pairs(baseHeaders) do
			local finalKey: Option<string | Secret> = Option.none()
			if typeof(key) == "string" then
				finalKey = Option.some(key :: string | Secret)
			else
				if typeof(key) == "Secret" then
					finalKey = Option.some(key :: string | Secret)
				else
					finalKey = Option.some(key:Build() :: string | Secret)
				end
			end
			local finalValue: Option<string | Secret> = Option.none()
			if typeof(value) == "string" then
				finalValue = Option.some(value :: string | Secret)
			else
				if typeof(value) == "Secret" then
					finalValue = Option.some(value :: string | Secret)
				else
					finalValue = Option.some(value:Build() :: string | Secret)
				end
			end

			finalHeaders[finalKey:expect("bad header key")] = finalValue:expect("bad header value")
		end

		return finalHeaders
	end, function()
		return {}
	end)

	local isGZip = headers["Accept-Encoding"] == "gzip"
	if isGZip then
		headers["Accept-Encoding"] = nil
	end

	return {
		url = url :: any,
		method = self.method :: any,
		headers = headers :: any,
		body = body,
		options = {
			decompress = isGZip,
		},
	} :: LuneUtil.FetchParams
end

function Request:headers(): Option<HeaderMap>
	return self._headers
end
function Request:body(): Option<Body<any>>
	return self._body
end

function Request:send<V, E>(): any
	return Future.from(function(): any
		local request = self:_asFetch()
		local fetchResponse: LuneUtil.FetchResponse = LuneUtil.Net.request(request)
		local response = Response.fromFetchResponse(Url.from(request.url), fetchResponse)
		if fetchResponse.ok then
			return Result.ok(response)
		else
			return Result.err(response)
		end
	end)
end

function RequestBuilder:build(): Request
	return newRequest(self.method :: any, self.url :: any, self._body :: any, self._headers :: any) :: any
end

function RequestBuilder:send<V, E>(): any
	local request: Request = self:build()
	return request:send()
end

function RequestBuilder:body(body: Body<any>): RequestBuilder
	return newRequest(
			self.method :: any,
			self.url :: any,
			Option.some(body) :: any,
			self._headers :: any
		):builder() :: any
end

function RequestBuilder:headers(headers: HeaderMap | { [HeaderKey]: HeaderValue }): RequestBuilder
	return (newRequest(
		self.method,
		self.url,
		self._body,
		if HashMap.isHashMap(headers)
			then Option.some(headers :: any)
			else Option.some(HashMap.from(headers :: any))
	)):builder()
end

function RequestBuilder:header(key: HeaderKey, value: HeaderValue): RequestBuilder
	return newRequest(
		self.method,
		self.url,
		self._body,
		Option.some(self._headers:match(function(old: HeaderMap): HeaderMap
			local headers = old:asMut()
			local _ = headers:insert(key, value)
			return headers:freeze()
		end, function(): HeaderMap
			local headers = HashMap.emptyMut()
			headers:insert(key, value)
			return headers:freeze()
		end))
	):builder()
end

-- has to be a string because you can't b64 encode a secret
function RequestBuilder:basicAuth(username: string, password: string): RequestBuilder
	return self:header("Authorization", "Basic " .. HashLib.base64_encode(username .. ":" .. password))
end

function RequestBuilder:bearerAuth(token: HeaderValue): RequestBuilder
	if typeof(token) == "string" then
		return self:header("Authorization", ("Bearer " .. token) :: HeaderValue) :: RequestBuilder
	else
		local sec: Option<HeaderValue> = Option.none()
		if typeof(token) == "table" then
			sec = Option.some(token:AddPrefix("Bearer ") :: HeaderValue)
		else
			sec = Option.some(token:AddPrefix("Bearer ") :: HeaderValue)
		end

		return self:header("Authorization", sec:expect(`bad token`)) :: RequestBuilder
	end
end

function RequestBuilder:json()
	return self:header("Content-Type", "application/json")
end

return {
	new = function(method: Method, url: Url | PotentialSecret): RequestBuilder
		return newRequest(method :: any, url :: any, Option.none(), Option.none()):builder() :: any
	end,
	isRequest = function(obj: unknown?): boolean
		return typeof(obj) == "table" and getmetatable(obj :: any) == Request
	end,
	isRequestBuilder = function(obj: unknown?): boolean
		return typeof(obj) == "table" and getmetatable(obj :: any) == RequestBuilder
	end,
}
