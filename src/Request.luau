--!strict
local HttpService = game:GetService("HttpService")
-- Services
-- Packages
local Option = require("@wally/Option")
local Result = require("@wally/Result")
local Future = require("@wally/Future")
local HashUtil = require("@wally/HashUtil")
-- Modules
local Headers = require("@proj/Headers")
local Url = require("@proj/Url")
local Body = require("@proj/Body")
local Response = require("@proj/Response")
-- Types
type HeaderMap = Headers.HeaderMap
type Url = Url.Url
type TryFromUrl = Url.TryFromUrl
type TryFromHeaderValue = Headers.TryFromHeaderValue
type HeaderValue = Headers.HeaderValue
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>
type Body = Body.Body

type RequestBuilderImpl = {
	__index: RequestBuilderImpl,
	basicAuth: (self: RequestBuilder, username: string, password: string) -> RequestBuilder,
	bearerAuth: (self: RequestBuilder, token: string | Secret) -> RequestBuilder,
	body: (self: RequestBuilder, body: Body) -> RequestBuilder,
	build: (self: RequestBuilder) -> Request,
	header: (self: RequestBuilder, key: string, value: TryFromHeaderValue) -> RequestBuilder,
	headers: (self: RequestBuilder, headers: HeaderMap) -> RequestBuilder,
	query: (self: RequestBuilder, { [string]: string }) -> RequestBuilder,
	json: (self: RequestBuilder) -> RequestBuilder,
	send: (self: RequestBuilder) -> Future<Result<Result<Response, Response>, string>>,
	new: (method: Method, url: Url | TryFromUrl) -> RequestBuilder,
}
type Response = Response.Response
type RequestStruct = {
	method: Method,
	url: Url,
	_query: Option<{ [string]: string }>,
	_body: Option<Body>,
	_headers: Option<HeaderMap>,
}
export type RequestBuilder = typeof(setmetatable({} :: RequestStruct, {} :: RequestBuilderImpl))
export type Method = "GET" | "HEAD" | "POST" | "PUT" | "DELETE" | "OPTIONS" | "TRACE" | "PATCH"
type RequestImpl = {
	__index: RequestImpl,
	builder: (self: Request) -> RequestBuilder,
	send: (self: Request) -> Future<Result<Result<Response, Response>, string>>,

	new: (method: Method, url: Url | TryFromUrl) -> Request,
}
export type Request = typeof(setmetatable({} :: RequestStruct, {} :: RequestImpl))

-- Constants

-- Variables
-- References
-- Private Functions
-- Class
local Request = {} :: RequestImpl
Request.__index = Request

local RequestBuilder = {}
RequestBuilder.__index = RequestBuilder

function newRequest(
	method: Method,
	url: Url | TryFromUrl,
	query: Option<{ [string]: string }>,
	body: Option<Body>,
	headers: Option<HeaderMap>
): Request
	local self = setmetatable({
		method = method,
		url = if typeof(url) == "table" then url else Url.Url.tryFrom(url):unwrap() :: Url,
		_query = query,
		_body = body,
		_headers = headers,
	}, Request)
	table.freeze(self)
	return self
end

function Request:builder(): RequestBuilder
	local builder: RequestStruct = table.clone(self) :: any
	local out = setmetatable(builder, RequestBuilder)
	table.freeze(out)
	return out
end

function Request:send(): Future<Result<Result<Response, Response>, string>>
	return Future.from(function()
		return Result.try(function()
			local url = self._query:match(function(query): string
				return tostring(self.url:query(query))
			end, function(): string
				return tostring(self.url)
			end)
			local body: string? = self._body:match(function(out): string?
				return tostring(out)
			end, function()
				return nil
			end)

			local headers: { [string]: string } = self._headers:match(
				function(map: HeaderMap): { [string]: string }
					local out = {}
					for _, pair in ipairs(map._pairs) do
						out[tostring(pair.key)] = tostring(pair.value)
					end
					return out
				end,
				function()
					return {}
				end
			)

			local isGZip = headers["Accept-Encoding"] == "gzip"
			if isGZip then
				headers["Accept-Encoding"] = nil
			end

			local rbxResponse: Response.RBXResponse = HttpService:RequestAsync({
				Url = url,
				Method = self.method :: Method,
				Headers = headers,
				Body = body,
				Compress = if isGZip then Enum.HttpCompression.Gzip else Enum.HttpCompression.None,
			}) :: any

			local response = Response.Response.new(self.url, rbxResponse)

			if rbxResponse.Success then
				return Result.ok(response)
			else
				return Result.err(response)
			end
		end)
	end)
end

function Request.new(method: Method, url: Url | TryFromUrl): Request
	return newRequest(method, url, Option.none(), Option.none(), Option.none())
end

function RequestBuilder:build(): Request
	return newRequest(self.method :: Method, self.url, self._query, self._body, self._headers)
end

function RequestBuilder:body(body: Body): RequestBuilder
	return newRequest(self.method :: Method, self.url, self._query, Option.some(body), self._headers):builder()
end

function RequestBuilder:query(query: { [string]: string }): RequestBuilder
	return newRequest(
		self.method :: Method,
		self.url,
		Option.some(table.freeze(table.clone(query))),
		self._body,
		self._headers
	):builder()
end

function RequestBuilder:headers(headers: HeaderMap): RequestBuilder
	return newRequest(self.method :: Method, self.url, self._query, self._body, Option.some(headers)):builder()
end

function RequestBuilder:header(key: string, value: TryFromHeaderValue): RequestBuilder
	return newRequest(
		self.method :: Method,
		self.url,
		self._query,
		self._body,
		Option.some(self._headers:match(function(old: HeaderMap): HeaderMap
			local headers = old:clone()
			local _ = headers:append(key, value)
			return headers
		end, function(): HeaderMap
			local headers = Headers.HeaderMap.new()
			local _ = headers:append(key, value)
			return headers
		end))
	):builder()
end

-- has to be a string because you can't b64 encode a secret
function RequestBuilder:basicAuth(username: string, password: string): RequestBuilder
	return self:header("Authorization", "Basic " .. HashUtil.base64_encode(username .. ":" .. password))
end

function RequestBuilder:bearerAuth(token: string | Secret): RequestBuilder
	if typeof(token) == "string" then
		return self:header("Authorization", "Bearer " .. token)
	else
		return self:header("Authorization", token:AddPrefix("Bearer "))
	end
end

function RequestBuilder:json()
	return self:header("Content-Type", "application/json")
end

function RequestBuilder:send(): Future<Result<Result<Response, Response>, string>>
	return self:build():send()
end

function RequestBuilder.new(method: any, url: Url | TryFromUrl): RequestBuilder
	return newRequest(method, url, Option.none(), Option.none(), Option.none()):builder()
end

return {
	Request = Request,
	RequestBuilder = RequestBuilder,
}
