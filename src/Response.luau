--!strict
-- Services
local HttpService = game:GetService("HttpService")
-- Packages
local Option = require("@wally/Option")
local Result = require("@wally/Result")
local Future = require("@wally/Future")
-- Modules
local Headers = require("@proj/Headers")
local Body = require("@proj/Body")
local Url = require("@proj/Url")
-- Types
type HeaderMap = Headers.HeaderMap
type Body = Body.Body
type Json = Body.Json
type Url = Url.Url
type Option<V> = Option.Option<V>
type Result<V, E> = Result.Result<V, E>
type Future<V> = Future.Future<V>
export type RBXResponse = {
	Success: boolean,
	StatusCode: number,
	StatusMessage: string,
	Headers: { [string]: string },
	Body: string,
}
type ResponseImpl = {
	__index: ResponseImpl,
	text: (self: Response) -> Result<string, string>,
	json: (self: Response) -> Result<Json, string>,
	bytes: (self: Response) -> Result<buffer, string>,
	headers: (self: Response) -> HeaderMap,
	contentLength: (self: Response) -> Option<number>,
	status: (self: Response) -> number,
	url: (self: Response) -> Url,
	new: (url: Url, rbx: RBXResponse) -> Response,
}

export type Response = typeof(setmetatable(
	{} :: {
		_Url: Url,
		_rbxResponse: {
			Success: boolean,
			StatusCode: number,
			StatusMessage: string,
			Headers: { [string]: string },
			Body: string,
		},
	},
	{} :: ResponseImpl
))
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

local Response = {} :: ResponseImpl
Response.__index = Response

function Response:text(): Result<string, string>
	return Result.ok(self._rbxResponse.Body)
end

function Response:json(): Result<Json, string>
	local ok, result = pcall(function()
		return HttpService:JSONDecode(self._rbxResponse.Body)
	end)
	if ok then
		return Result.ok(result)
	else
		return Result.err("Failed to decode JSON: " .. result)
	end
end

function Response:bytes(): Result<buffer, string>
	if self._rbxResponse.Success then
		return Result.ok(buffer.fromstring(self._rbxResponse.Body))
	else
		return Result.err("Failed to get bytes from response")
	end
end

function Response:headers(): HeaderMap
	local headers = Headers.HeaderMap.new()
	for key, value in pairs(self._rbxResponse.Headers) do
		headers:insert(key, value)
	end
	return headers
end

function Response:contentLength(): Option<number>
	local lengthStr = self._rbxResponse.Headers["Content-Length"]
	if lengthStr then
		local length = tonumber(lengthStr)
		assert(length, "Failed to parse Content-Length header")
		return Option.some(length)
	else
		return Option.none()
	end
end

function Response:status(): number
	return self._rbxResponse.StatusCode
end

function Response:url(): Url
	return self._Url
end

return {
	Response = Response,
	ERROR_CODES = ERROR_CODES,
}
