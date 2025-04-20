--!strict
-- Services
-- Packages
local LuneUtil = require("@pkg/@nightcycle/lune-util")
local Option = require("@pkg/@nightcycle/option")
local Result = require("@pkg/@nightcycle/result")
local Future = require("@pkg/@nightcycle/future")
local Error = require("@pkg/@nightcycle/error")
local HashMap = require("@pkg/@nightcycle/hash-map")

-- Modules
local Body = require("./Body")
local Url = require("./Url")
-- Types
type PotentialSecret = Url.PotentialSecret
type HashMap<K, V> = HashMap.HashMap<K, V>
export type HeaderValue = PotentialSecret
export type HeaderKey = PotentialSecret
export type HeaderMap = HashMap<HeaderKey, HeaderValue>

type Body<V> = Body.Body<V>
type Json = Body.Json
type Form = Body.Form
type Url = Url.Url
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>
type Error<T, Body> = Error.Error<T, Body>
type DecodingError = Error<"DecodingError", ResponseStruct>
type ResponseImpl<V> = {
	__index: ResponseImpl<V>,
	__tostring: (self: any) -> string,
	text: (self: any) -> Result<string & V, DecodingError>,
	json: (self: any) -> Result<Json & V, DecodingError>,
	form: (self: any) -> Result<Form & V, DecodingError>,
	bytes: (self: any) -> Result<buffer, DecodingError>,
	headers: (self: any) -> HeaderMap,
	contentLength: (self: any) -> Option<number>,
	status: (self: any) -> number,
	statusMessage: (self: any) -> string,
	url: (self: any) -> Url,
	builder: (self: any) -> ResponseBuilder<V>,
}

type ResponseBuilderImpl<V> = {
	__index: ResponseBuilderImpl<V>,
	__tostring: (self: any) -> string,
	body: (self: any, body: Body<V>) -> ResponseBuilder<V>,
	status: (self: any, status: number) -> ResponseBuilder<V>,
	statusMessage: (self: any, message: string) -> ResponseBuilder<V>,
	url: (self: any, url: Url) -> ResponseBuilder<V>,
	headers: (self: any, headers: HeaderMap) -> ResponseBuilder<V>,
	build: (self: any) -> Response<V>,
}

type ResponseBuilder<V> = ResponseBuilderImpl<V>

type ResponseStruct = {
	_url: Url,
	_body: Body<any>,
	_statusCode: number,
	_statusMessage: string,
	_headers: HeaderMap,
}

export type Response<V> = ResponseImpl<V> --typeof(setmetatable({}, {} :: ResponseImpl))

-- Constants
local ERROR_CODES = {
	BAD_REQUEST = 400,
	UNAUTHORIZED = 401,
	PAYMENT_REQUIRED = 402,
	FORBIDDEN = 403,
	NOT_FOUND = 404,
	METHOD_NOT_ALLOWED = 405,
	NOT_ACCEPTABLE = 406,
	PROXY_AUTHENTICATION_REQUIRED = 407,
	REQUEST_TIMEOUT = 408,
	CONFLICT = 409,
	GONE = 410,
	LENGTH_REQUIRED = 411,
	PRECONDITION_FAILED = 412,
	CONTENT_TOO_LARGE = 413,
	URI_TOO_LONG = 414,
	UNSUPPORTED_MEDIA_TYPE = 415,
	RANGE_NOT_SATISFIABLE = 416,
	EXPECTATION_FAILED = 417,
	IM_A_TEAPOT = 418, --???
	MISDIRECTED_REQUEST = 421,
	UNPROCESSABLE_CONTENT = 422,
	LOCKED = 423,
	FAILED_DEPENDENCY = 424,
	TOO_EARLY = 425,
	UPGRADE_REQUIRED = 426,
	PRECONDITION_REQUIRED = 428,
	TOO_MANY_REQUESTS = 429,
	REQUEST_HEADER_FIELDS_TOO_LARGE = 431,
	UNAVAILABLE_FOR_LEGAL_REASONS = 451,
	INTERNAL_SERVER_ERROR = 500,
	NOT_IMPLEMENTED = 501,
	BAD_GATEWAY = 502,
	SERVICE_UNAVAILABLE = 503,
	GATEWAY_TIMEOUT = 504,
	HTTP_VERSION_NOT_SUPPORTED = 505,
	VARIANT_ALSO_NEGOTIATES = 506,
	INSUFFICIENT_STORAGE = 507,
	LOOP_DETECTED = 508,
	NOT_EXTENDED = 510,
	NETWORK_AUTHENTICATION_REQUIRED = 511,
}

-- Variables
-- References
-- Private Functions
function newResponseStruct(
	url: Url,
	body: Body<any>,
	status: number,
	statusMessage: string,
	headers: HeaderMap
): ResponseStruct
	return {
		_url = url,
		_body = body,
		_statusCode = status,
		_statusMessage = statusMessage,
		_headers = headers,
	}
end

-- Class

local ResponseBuilder = {} :: ResponseBuilderImpl<any>
ResponseBuilder.__index = ResponseBuilder

local Response = {} :: ResponseImpl<any>
Response.__index = Response

function Response:__tostring(): string
	return "Response<{"
		.. `"url": "{self._url}", "body": {self._body},`
		.. `"statusCode": {self._statusCode}, "statusMessage": {self._statusMessage}, "headers": {self._headers}`
		.. "}>"
end

function Response:text()
	return Result.ok(self._fetchResponse.body) :: any
end

function Response:json()
	return self._body:asJson():match(function(v)
		return Result.ok(v)
	end, function(e)
		return Result.err(
			Error.new("DecodingError")
				:body(self :: any)
				:description(
					e.Description:unwrapOr(`Error decoding text "{self._fetchResponse.body}" into json`)
				)
				:title("JSON Decoding Error")
				:build() :: Error<any, any>
		)
	end)
end

function Response:builder()
	local struct =
		newResponseStruct(self._url, self._body, self._statusCode, self._statusMessage, self._headers)
	local builder = setmetatable(struct, ResponseBuilder)
	table.freeze(builder)
	return builder :: any
end

function Response:form()
	return self._body:asForm():match(function(v)
		return Result.ok(v)
	end, function(e)
		return Result.err(
			Error.new("DecodingError")
				:body(self :: any)
				:description(
					e.Description:unwrapOr(`Error decoding text "{self._fetchResponse.body}" into form`)
				)
				:title("Form Decoding Error")
				:build() :: Error<any, any>
		)
	end)
end

function Response:bytes()
	local result = Result.try(function()
		return buffer.fromstring(self._fetchResponse.body)
	end)
	if result:isOk() then
		return Result.ok(result:unwrap())
	else
		return Result.err(
			Error.new("DecodingError")
				:body(self :: any)
				:description(result:unwrapErr())
				:title("JSON Decoding Error")
				:build() :: Error<any, ResponseStruct>
		)
	end
end

function Response:headers(): HeaderMap
	return self._headers
end

function Response:contentLength(): Option<number>
	return self._headers:get("Content-Length"):match(function(lengthStr)
		local length = tonumber(lengthStr)
		assert(length, "Failed to parse Content-Length header")
		return Option.some(length)
	end, function()
		return Option.none()
	end)
end

function Response:status(): number
	return self._statusCode
end

function Response:statusMessage(): string
	return self._statusMessage
end

function Response:url(): Url
	return self._url
end

function ResponseBuilder:__tostring(): string
	return "ResponseBuilder<{"
		.. `"url": "{self._url}", "body": {self._body},`
		.. `"statusCode": {self._statusCode}, "statusMessage": {self._statusMessage}, "headers": {self._headers}`
		.. "}>"
end

function ResponseBuilder:body(body: Body<any>): ResponseBuilder<any>
	local builder = setmetatable(
		newResponseStruct(self._url, body, self._statusCode, self._statusMessage, self._headers),
		ResponseBuilder
	)
	table.freeze(builder)
	return builder :: any
end
function ResponseBuilder:status(status: number): ResponseBuilder<any>
	local builder = setmetatable(
		newResponseStruct(self._url, self._body, status, self._statusMessage, self._headers),
		ResponseBuilder
	)
	table.freeze(builder)
	return builder :: any
end
function ResponseBuilder:statusMessage(message: string): ResponseBuilder<any>
	local builder = setmetatable(
		newResponseStruct(self._url, self._body, self._statusCode, message, self._headers),
		ResponseBuilder
	)
	table.freeze(builder)
	return builder :: any
end
function ResponseBuilder:url(url: Url): ResponseBuilder<any>
	local builder = setmetatable(
		newResponseStruct(url, self._body, self._statusCode, self._statusMessage, self._headers),
		ResponseBuilder
	)
	table.freeze(builder)
	return builder :: any
end
function ResponseBuilder:headers(headers: HeaderMap): ResponseBuilder<any>
	local builder = setmetatable(
		newResponseStruct(self._url, self._body, self._statusCode, self._statusMessage, headers),
		ResponseBuilder
	)
	table.freeze(builder)
	return builder :: any
end

function ResponseBuilder:build(): Response<any>
	local response = setmetatable(
		newResponseStruct(self._url, self._body, self._statusCode, self._statusMessage, self._headers),
		Response
	)
	table.freeze(response)
	return response :: any
end

return {
	fromFetchResponse = function<V>(url: Url, fetchResponse: LuneUtil.FetchResponse): Response<V>
		local mutHeaders = HashMap.emptyMut()
		for key, value in pairs(fetchResponse.headers) do
			mutHeaders:insert(key, value)
		end
		local headers = mutHeaders:freeze()
		local body = Body.fromText(fetchResponse.body)
		local statusCode = fetchResponse.statusCode
		local statusMessage = fetchResponse.statusMessage
		local responseStruct = newResponseStruct(url, body, statusCode, statusMessage, headers)
		local self = setmetatable(responseStruct, Response)
		table.freeze(self)
		return self :: any
	end,
	ERROR_CODES = ERROR_CODES,
}
