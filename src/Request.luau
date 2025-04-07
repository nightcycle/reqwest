--!strict
local LuneUtil = require("@pkg/@nightcycle/lune-util")
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local Result = require("@pkg/@nightcycle/result")
local Future = require("@pkg/@nightcycle/future")
local HashMap = require("@pkg/@nightcycle/hash-map")
-- Modules
local Url = require("./Url")
local Body = require("./Body")
local Response = require("./Response")
local EncodeUtil = require("./EncodeUtil")
-- Types
type HashMap<K, V> = HashMap.HashMap<K, V>
type HeaderMap = Response.HeaderMap
type Url = Url.Url
type TryFromUrl = Url.TryFromUrl
type HeaderValue = Response.HeaderValue
type HeaderKey = Response.HeaderKey
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>

type Body<V> = Body.Body<V>

type RequestBuilderImpl = {
	__index: RequestBuilderImpl,
	__tostring: (self: any) -> string,
	basicAuth: (self: any, username: string, password: string) -> RequestBuilder,
	bearerAuth: (self: any, token: string | Secret) -> RequestBuilder,
	body: <V>(self: any, body: Body<V>) -> RequestBuilder,
	build: (self: any) -> Request,
	header: (self: any, key: HeaderKey, value: HeaderValue) -> RequestBuilder,
	headers: (self: any, headers: HeaderMap) -> RequestBuilder,
	query: (self: any, query: HashMap<string, string>) -> RequestBuilder,
	json: (self: any) -> RequestBuilder,
}
type Response<V> = Response.Response<V>
type RequestStruct = {
	method: Method,
	url: Url,
	_query: Option<HashMap<string, string>>,
	_body: Option<Body<any>>,
	_headers: Option<HeaderMap>,
}
export type RequestBuilder = RequestBuilderImpl -- typeof(setmetatable({}, {} :: RequestBuilderImpl))
export type Method = "GET" | "POST" | "PUT" | "DELETE" | "OPTIONS" | "PATCH" -- limited by lune support

type RequestImpl = {
	__index: RequestImpl,
	__tostring: (self: any) -> string,
	builder: (self: Request) -> RequestBuilder,
	send: <V, E>(self: Request) -> Future<Result<Response<V>, Response<E>>>,
}
export type Request = RequestImpl & {
	method: Method,
	url: Url,
} -- typeof(setmetatable({}, {} :: RequestImpl))

-- Constants

-- Variables
-- References
-- Private Functions
-- Class
local Request = {} :: RequestImpl
Request.__index = Request

function Request:__tostring(): string
	return "Request<{"
		.. `"method": "{tostring(self.method)}", "url": "{tostring(self.url)}", "query": "{tostring(
			self._query
		)}", "body": "{tostring(self._body)}", "headers": "{tostring(self._headers)}"`
		.. "}>"
end

local RequestBuilder = {} :: RequestBuilderImpl
RequestBuilder.__index = RequestBuilder

function RequestBuilder:__tostring(): string
	return "Request<{"
		.. `"method": "{tostring(self.method)}", "url": "{tostring(self.url)}", "query": "{tostring(
			self._query
		)}", "body": "{tostring(self._body)}", "headers": "{tostring(self._headers)}"`
		.. "}>"
end

function newRequest<V>(
	method: Method,
	url: Url | TryFromUrl,
	query: Option<HashMap<string, string>>,
	body: Option<V>,
	headers: Option<HeaderMap>
): Request
	local self = setmetatable({
		method = method,
		url = if typeof(url) == "table" then url else Url.tryFrom(url):unwrap() :: Url,
		_query = query,
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

function Request:send<V, E>(): Future<Result<Response<V>, Response<E>>>
	return Future.from(function(): any
		local req: RequestStruct = self :: any
		local url = req._query:match(function(query): string
			return tostring(req.url:query(query))
		end, function(): string
			return tostring(req.url)
		end)
		local body: string? = req._body:match(function(out): string?
			return out:asText():expect(`failed to convert body to string`)
		end, function()
			return nil
		end)

		local headers: { [HeaderKey]: HeaderValue } = req._headers:match(
			function(map: HeaderMap): { [HeaderKey]: HeaderValue }
				return map:drain()
			end,
			function()
				return {}
			end
		)

		local isGZip = headers["Accept-Encoding"] == "gzip"
		if isGZip then
			headers["Accept-Encoding"] = nil
		end

		local fetchResponse: LuneUtil.FetchResponse = LuneUtil.Net.request({
			url = url,
			method = req.method :: any,
			headers = headers :: any,
			body = body,
			options = {
				decompress = isGZip,
			},
		})

		local response = Response.new(req.url, fetchResponse)

		if fetchResponse.ok then
			return Result.ok(response)
		else
			return Result.err(response)
		end
	end)
end

function RequestBuilder:build(): Request
	return newRequest(
		self.method :: any,
		self.url :: any,
		self._query :: any,
		self._body :: any,
		self._headers :: any
	) :: any
end

function RequestBuilder:body<V>(body: Body<any>): RequestBuilder
	return newRequest(
		self.method :: any,
		self.url :: any,
		self._query :: any,
		Option.some(body) :: any,
		self._headers :: any
	):builder() :: any
end

function RequestBuilder:query(query: HashMap<string, string>): RequestBuilder
	return (newRequest(
		self.method :: any,
		self.url :: any,
		Option.some(query),
		self._body :: any,
		self._headers :: any
	) :: any):builder() :: any
end

function RequestBuilder:headers(headers: HeaderMap): RequestBuilder
	return (newRequest(
		self.method :: any,
		self.url :: any,
		self._query :: any,
		self._body :: any,
		Option.some(headers) :: any
	) :: any):builder() :: any
end

function RequestBuilder:header(key: HeaderKey, value: HeaderValue): RequestBuilder
	return newRequest(
		self.method :: any,
		self.url :: any,
		self._query :: any,
		self._body :: any,
		Option.some(self._headers:match(function(old: HeaderMap): HeaderMap
			local headers = old:asMut()
			local _ = headers:insert(key, value)
			return headers
		end, function(): HeaderMap
			local headers = HashMap.emptyMut()
			headers:insert(key, value)
			return headers
		end)) :: any
	):builder() :: any
end

-- has to be a string because you can't b64 encode a secret
function RequestBuilder:basicAuth(username: string, password: string): RequestBuilder
	return self:header("Authorization", "Basic " .. EncodeUtil.Base64.encode(username .. ":" .. password))
end

function RequestBuilder:bearerAuth(token: HeaderValue): RequestBuilder
	if typeof(token) == "string" then
		return self:header("Authorization", ("Bearer " .. token) :: HeaderValue) :: RequestBuilder
	else
		local sec: HeaderValue = token:AddPrefix("Bearer ")
		return self:header("Authorization", sec) :: RequestBuilder
	end
end

function RequestBuilder:json()
	return self:header("Content-Type", "application/json")
end

return {
	new = function(method: Method, url: Url | TryFromUrl): RequestBuilder
		return newRequest(method :: any, url :: any, Option.none(), Option.none(), Option.none()):builder() :: any
	end,
}
