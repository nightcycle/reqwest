--!strict
-- Services
-- Packages
local Option = require("@pkg/@nightcycle/option")
local Result = require("@pkg/@nightcycle/result")
local Future = require("@pkg/@nightcycle/future")
local HashMap = require("@pkg/@nightcycle/hash-map")

-- Modules
local Request = require("./Request")
local Response = require("./Response")
local Url = require("./Url")
-- Types
type HeaderMap = Response.HeaderMap
type Url = Url.Url
type PotentialSecret = Url.PotentialSecret
type HeaderValue = Response.HeaderValue
type HeaderKey = Response.HeaderKey

type Request = Request.Request
type RequestBuilder = Request.RequestBuilder
type Method = Request.Method
type Response<V> = Response.Response<V>
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>
type ClientStruct = any
-- type ClientStruct = {
-- 	_userAgent: Option<HeaderValue>,
-- 	_defaultHeaders: Option<HeaderMap>,
-- 	_gzip: Option<boolean>,
-- }
type ClientImpl = {
	__index: ClientImpl,
	__tostring: (self: Client) -> string,
	builder: (self: Client) -> ClientBuilder,
	get: (self: Client, url: PotentialSecret | Url) -> RequestBuilder,
	post: (self: Client, url: PotentialSecret | Url) -> RequestBuilder,
	put: (self: Client, url: PotentialSecret | Url) -> RequestBuilder,
	delete: (self: Client, url: PotentialSecret | Url) -> RequestBuilder,
	patch: (self: Client, url: PotentialSecret | Url) -> RequestBuilder,
	request: (self: Client, method: Method, url: PotentialSecret | Url) -> RequestBuilder,
	execute: <V, E>(
		self: Client,
		request: Request
	) -> Future<Result<Result<Response<V>, Response<E>>, string>>,
}
type ClientBuilderImpl = {
	__index: ClientBuilderImpl,
	__tostring: (self: ClientBuilder) -> string,
	build: (self: ClientBuilder) -> Client,
	userAgent: (self: ClientBuilder, userAgent: HeaderValue | HeaderValue) -> ClientBuilder,
	defaultHeaders: (self: ClientBuilder, headers: HeaderMap) -> ClientBuilder,
	header: (self: ClientBuilder, key: HeaderKey, value: HeaderValue) -> ClientBuilder,
	gzip: (self: ClientBuilder, enabled: boolean) -> ClientBuilder,
}

export type Client = ClientStruct & ClientImpl
export type ClientBuilder = ClientStruct & ClientBuilderImpl

-- Constants
-- Variables
-- References
-- Private Functions
function newRequestBuilder(client: any, method: Method, url: PotentialSecret | Url): RequestBuilder
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

function Client:__tostring(): string
	return "Client<{"
		.. `"userAgent": "{tostring(self._userAgent)}", "headers": "{tostring(self._defaultHeaders)}", "gzip": "{tostring(
			self._gzip
		)}"`
		.. "}>"
end

local ClientBuilder = {} :: ClientBuilderImpl
ClientBuilder.__index = ClientBuilder

function ClientBuilder:__tostring(): string
	return "ClientBuilder<{"
		.. `"userAgent": "{tostring(self._userAgent)}", "headers": "{tostring(self._defaultHeaders)}", "gzip": "{tostring(
			self._gzip
		)}"`
		.. "}>"
end

function newClient(
	userAgent: Option<HeaderValue>,
	defaultHeaders: Option<HeaderMap>,
	gzip: Option<boolean>
): Client
	local self = setmetatable(
		{
			_userAgent = userAgent,
			_defaultHeaders = defaultHeaders,
			_gzip = gzip,
		} :: ClientStruct,
		Client
	)
	table.freeze(self)
	return self :: any
end

function newBuilder(client: Client): ClientBuilder
	local struct: ClientStruct = table.clone(client) :: any
	local self = setmetatable(struct, ClientBuilder)
	table.freeze(self)
	return self :: any
end

function Client:get(url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, "GET", url) :: any
end

function Client:post(url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, "POST", url) :: any
end

function Client:put(url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, "PUT", url) :: any
end

function Client:delete(url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, "DELETE", url) :: any
end

function Client:patch(url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, "PATCH", url) :: any
end

function Client:request(method: Method, url: PotentialSecret | Url): RequestBuilder
	return newRequestBuilder(self, method, url) :: any
end

function Client:execute<V, E>(request: Request): any
	local req: any = request
	return req:send()
end

function Client:builder(): ClientBuilder
	return newBuilder(self) :: any
end

function ClientBuilder:gzip(enabled: boolean): ClientBuilder
	return newClient(self._userAgent, self._defaultHeaders, Option.some(enabled)):builder()
end

function ClientBuilder:defaultHeaders(headers: HeaderMap): ClientBuilder
	return newClient(self._userAgent, Option.some(headers), self._gzip):builder()
end

function ClientBuilder:header(key: HeaderKey, value: HeaderValue): ClientBuilder
	return newClient(
		self._userAgent,
		self._defaultHeaders:match(function(map): Option<HeaderMap>
			local newMap = HashMap.fromMut(map:drain())
			newMap:insert(key, value)
			return Option.some(newMap:freeze() :: any)
		end, function()
			local newMap = HashMap.from({
				[key] = value,
			})
			return Option.some(newMap :: any)
		end),
		self._gzip
	):builder() :: any
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
	isClient = function(obj: unknown?): boolean
		return typeof(obj) == "table" and getmetatable(obj :: any) == Client
	end,
	isClientBuilder = function(obj: unknown?): boolean
		return typeof(obj) == "table" and getmetatable(obj :: any) == ClientBuilder
	end,
}
