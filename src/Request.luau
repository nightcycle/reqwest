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
	__tostring: (self: any) -> string,
	basicAuth: (self: any, username: string, password: string) -> RequestBuilder,
	bearerAuth: (self: any, token: PotentialSecret) -> RequestBuilder,
	body: <V>(self: any, body: Body<V>) -> RequestBuilder,
	build: (self: any) -> Request,
	header: (self: any, key: HeaderKey, value: HeaderValue) -> RequestBuilder,
	headers: (self: any, headers: HeaderMap) -> RequestBuilder,
	query: (self: any, query: HashMap<PotentialSecret, PotentialSecret>) -> RequestBuilder,
	json: (self: any) -> RequestBuilder,
}
type Response<V> = Response.Response<V>
type RequestStruct = {
	method: Method,
	url: Url,
	_query: Option<HashMap<PotentialSecret, PotentialSecret>>,
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
	url: Url | PotentialSecret,
	query: Option<HashMap<PotentialSecret, PotentialSecret>>,
	body: Option<V>,
	headers: Option<HeaderMap>
): Request
	local self = setmetatable({
		method = method,
		url = if Url.isUrl(url) then url else Url.tryFrom(url :: PotentialSecret):unwrap() :: Url,
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
		local url: any = req._query:match(function(query): PotentialSecret
			return req.url:query(query):display() :: PotentialSecret
		end, function(): PotentialSecret
			return req.url:display() :: PotentialSecret
		end)
		local body: string? = req._body:match(function(out): string?
			return out:asText():expect(`failed to convert body to string`)
		end, function()
			return nil
		end)

		local headers: { [any]: any } = req._headers:match(
			function(map: HeaderMap): { [HeaderKey]: HeaderValue }
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

function RequestBuilder:query(query: HashMap<PotentialSecret, PotentialSecret>): RequestBuilder
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
		return newRequest(method :: any, url :: any, Option.none(), Option.none(), Option.none()):builder() :: any
	end,
}
