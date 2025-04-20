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
	text: (self: any) -> Result<string, DecodingError>,
	json: <V>(self: any) -> Result<Json & V, DecodingError>,
	form: (self: any) -> Result<Form, DecodingError>,
	bytes: (self: any) -> Result<buffer, DecodingError>,
	headers: (self: any) -> HeaderMap,
	contentLength: (self: any) -> Option<number>,
	status: (self: any) -> number,
	url: (self: any) -> Url,
}

type ResponseStruct = {
	_url: Url,
	_fetchResponse: LuneUtil.FetchResponse,
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
-- Class

local Response = {} :: ResponseImpl<any>
Response.__index = Response

function Response:__tostring(): string
	return "Response<{"
		.. `"url": "{tostring(self._url)}", "response": {Error.displayAsJson(self._fetchResponse)}`
		.. "}>"
end

function Response:text(): Result<string, DecodingError>
	return Result.ok(self._fetchResponse.body)
end

function Response:json<V>(): Result<Json & V, DecodingError>
	local result = Result.try(function()
		return LuneUtil.Net.jsonDecode(self._fetchResponse.body)
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

function Response:form(): Result<Form, DecodingError>
	local body = Body.fromText(self._fetchResponse.body)
	return body:asForm():match(function(v)
		return Result.ok(v)
	end, function(e)
		return Result.err(
			Error.new("DecodingError")
				:body(self :: any)
				:description(
					e.Description:unwrapOr(`Error decoding text "{self._fetchResponse.body}" into form`)
				)
				:title("Form Decoding Error")
				:build() :: Error<any, ResponseStruct>
		)
	end)
end

function Response:bytes(): Result<buffer, DecodingError>
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
	local headers = HashMap.emptyMut()
	for key, value in pairs(self._fetchResponse.headers) do
		headers:insert(key, value)
	end
	return headers:freeze()
end

function Response:contentLength(): Option<number>
	local lengthStr = self._fetchResponse.headers["Content-Length"]
	if lengthStr then
		local length = tonumber(lengthStr)
		assert(length, "Failed to parse Content-Length header")
		return Option.some(length)
	else
		return Option.none()
	end
end

function Response:status(): number
	return self._fetchResponse.statusCode
end

function Response:url(): Url
	return self._url
end

return {
	new = function<V>(url: Url, fetchResponse: LuneUtil.FetchResponse): Response<V>
		local self = setmetatable({
			_url = url,
			_fetchResponse = fetchResponse,
		}, Response)
		table.freeze(self)
		return self :: any
	end,
	ERROR_CODES = ERROR_CODES,
}
