--!strict
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local Result = require("@pkg/@nightcycle/result")
local Future = require("@pkg/@nightcycle/future")
-- Modules
local Request = require("./Request")
local Response = require("./Response")
local Url = require("./Url")
-- Types
type HeaderMap = Response.HeaderMap
type Url = Url.Url
type TryFromUrl = Url.TryFromUrl
type HeaderValue = Response.HeaderValue
type Request = Request.Request
type RequestBuilder = Request.RequestBuilder
type Method = Request.Method
type Response = Response.Response
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>

export type ClientStruct = {
	_userAgent: Option<HeaderValue>,
	_defaultHeaders: Option<HeaderMap>,
	_gzip: Option<boolean>,
}
type ClientImpl = {
	__index: ClientImpl,
	builder: (self: any) -> ClientBuilder,
	get: (self: any, url: TryFromUrl | Url) -> RequestBuilder,
	post: (self: any, url: TryFromUrl | Url) -> RequestBuilder,
	put: (self: any, url: TryFromUrl | Url) -> RequestBuilder,
	delete: (self: any, url: TryFromUrl | Url) -> RequestBuilder,
	patch: (self: any, url: TryFromUrl | Url) -> RequestBuilder,
	request: (self: any, method: Method, url: TryFromUrl | Url) -> RequestBuilder,
	execute: (self: any, request: Request) -> Future<Result<Result<Response, Response>, string>>,
}

export type Client = typeof(setmetatable({} :: ClientStruct, {} :: ClientImpl))

type ClientBuilderImpl = {
	__index: ClientBuilderImpl,
	build: (self: any) -> Client,
	userAgent: (self: any, userAgent: HeaderValue | HeaderValue) -> ClientBuilder,
	defaultHeaders: (self: any, headers: HeaderMap) -> ClientBuilder,
	gzip: (self: any, enabled: boolean) -> ClientBuilder,
}
export type ClientBuilder = typeof(setmetatable({} :: ClientStruct, {} :: ClientBuilderImpl))

-- Constants
-- Variables
-- References
-- Private Functions
function newRequestBuilder(client: Client, method: Method, url: TryFromUrl | Url): RequestBuilder
	local out = Request.new(method, url)

	out = client._defaultHeaders:match(function(headers)
		return out:headers(headers)
	end, function()
		return out
	end)

	out = client._gzip:match(function(gzip)
		return out:header("Accept-Encoding", "gzip")
	end, function()
		return out
	end)

	out = client._userAgent:match(function(userAgent)
		return out:header("User-Agent", if typeof(userAgent) == "table" then userAgent.value else userAgent)
	end, function()
		return out
	end)

	return out :: any
end

-- Class
-- Types

-- Classes
local Client = {} :: ClientImpl
Client.__index = Client

local ClientBuilder = {} :: ClientBuilderImpl
ClientBuilder.__index = ClientBuilder

function newClient(
	userAgent: Option<HeaderValue>,
	defaultHeaders: Option<HeaderMap>,
	gzip: Option<boolean>
): Client
	local self = setmetatable({
		_userAgent = userAgent,
		_defaultHeaders = defaultHeaders,
		_gzip = gzip,
	}, Client)
	table.freeze(self)
	return self
end

function newBuilder(client: Client): ClientBuilder
	local struct: ClientStruct = table.clone(client) :: any
	local self = setmetatable(struct, ClientBuilder)
	table.freeze(self)
	return self
end

function Client:get(url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, "GET", url) :: any
end

function Client:post(url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, "POST", url) :: any
end

function Client:put(url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, "PUT", url) :: any
end

function Client:delete(url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, "DELETE", url) :: any
end

function Client:patch(url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, "PATCH", url) :: any
end

function Client:request(method: Method, url: TryFromUrl | Url): RequestBuilder
	return newRequestBuilder(self, method, url) :: any
end

function Client:execute(request: Request): Future<Result<Result<Response, Response>, string>>
	local req: any = request
	return req:send()
end

function Client:builder(): ClientBuilder
	return newBuilder(self) :: any
end

function ClientBuilder:gzip(enabled: boolean): ClientBuilder
	return newClient(self._userAgent, self._defaultHeaders, Option.some(enabled)):builder() :: any
end

function ClientBuilder:defaultHeaders(headers: HeaderMap): ClientBuilder
	return newClient(self._userAgent, Option.some(headers), self._gzip):builder() :: any
end

function ClientBuilder:userAgent(userAgent: HeaderValue): ClientBuilder
	return newClient(Option.some(userAgent), self._defaultHeaders, self._gzip):builder() :: any
end

function ClientBuilder:build(): Client
	return newClient(self._userAgent, self._defaultHeaders, self._gzip) :: any
end

return {
	new = function(): ClientBuilder
		return newClient(Option.none(), Option.none(), Option.none()):builder() :: any
	end,
}
