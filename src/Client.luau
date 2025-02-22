--!strict
-- Services
-- Packages
local Option = require("@wally/Option")
local Result = require("@wally/Result")
local Future = require("@wally/Future")
-- Modules
local Headers = require("@proj/Headers")
local Request = require("@proj/Request")
local Response = require("@proj/Response")

local Url = require("@proj/Url")
-- Types
type HeaderMap = Headers.HeaderMap
type Url = Url.Url
type TryFromUrl = Url.TryFromUrl
type TryFromHeaderValue = Headers.TryFromHeaderValue
type HeaderValue = Headers.HeaderValue
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
	new: () -> Client,
	builder: (self: Client) -> ClientBuilder,
	get: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	post: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	put: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	delete: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	patch: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	head: (self: Client, url: TryFromUrl | Url) -> RequestBuilder,
	request: (self: Client, method: Method, url: TryFromUrl | Url) -> RequestBuilder,
	execute: (self: Client, request: Request) -> Future<Result<Result<Response, Response>, string>>,
}

export type Client = typeof(setmetatable({} :: ClientStruct, {} :: ClientImpl))

type ClientBuilderImpl = {
	__index: ClientBuilderImpl,
	build: (self: ClientBuilder) -> Client,
	userAgent: (self: ClientBuilder, userAgent: HeaderValue | TryFromHeaderValue) -> ClientBuilder,
	defaultHeaders: (self: ClientBuilder, headers: HeaderMap) -> ClientBuilder,
	gzip: (self: ClientBuilder, enabled: boolean) -> ClientBuilder,
	new: () -> ClientBuilder,
}
export type ClientBuilder = typeof(setmetatable(
	{} :: ClientStruct,
	{} :: ClientBuilderImpl
))

-- Constants
-- Variables
-- References
-- Private Functions
function newRequest(client: Client, method: Method, url: TryFromUrl | Url): RequestBuilder
	local out = Request.RequestBuilder.new(method, url)

	out = client._defaultHeaders:match(
		function(headers)
			return out:headers(headers)
		end,
		function()
			return out
		end
	)

	out = client._gzip:match(
		function(gzip)
			return out:header("Accept-Encoding", "gzip")
		end,
		function()
			return out
		end
	)

	out = client._userAgent:match(
		function(userAgent)
			return out:header("User-Agent", if typeof(userAgent) == "table" then userAgent.value else userAgent)
		end,
		function()
			return out
		end
	)

	return out
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
	return newRequest(self, "GET", url)
end

function Client:post(url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, "POST", url)
end

function Client:put(url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, "PUT", url)
end

function Client:delete(url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, "DELETE", url)
end

function Client:patch(url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, "PATCH", url)
end

function Client:head(url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, "HEAD", url)
end

function Client:request(method: Method, url: TryFromUrl | Url): RequestBuilder
	return newRequest(self, method, url)
end

function Client:execute(request: Request): Future<Result<Result<Response, Response>, string>>
	return request:send()
end

function Client:builder(): ClientBuilder
	return newBuilder(self)
end

function Client.new()
	return newClient(
		Option.none(),
		Option.none(),
		Option.none()
	)
end

function ClientBuilder:gzip(enabled: boolean): ClientBuilder
	return newClient(
		self._userAgent,
		self._defaultHeaders,
		Option.some(enabled)
	):builder()
end

function ClientBuilder:defaultHeaders(headers: HeaderMap): ClientBuilder
	return newClient(
		self._userAgent,
		Option.some(headers),
		self._gzip
	):builder()
end

function ClientBuilder:userAgent(userAgent: HeaderValue | TryFromHeaderValue): ClientBuilder
	local userAgentHeaderValue: HeaderValue = if typeof(userAgent) == "table"
		then userAgent
		else Headers.HeaderValue.tryFrom(userAgent):unwrap()

	return newClient(
		Option.some(userAgentHeaderValue),
		self._defaultHeaders,
		self._gzip
	):builder()
end

function ClientBuilder:build(): Client
	return Client.new()
end

function ClientBuilder.new()
	return newClient(
		Option.none(),
		Option.none(),
		Option.none()
	):builder()
end

return {
	Client = Client,
	ClientBuilder = ClientBuilder,
}
