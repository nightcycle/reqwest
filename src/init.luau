--!strict
-- Services
-- Packages

-- Modules
local Body = require("@proj/Body")
local Headers = require("@proj/Headers")
local Request = require("@proj/Request")
local Response = require("@proj/Response")
local Url = require("@proj/Url")
local Client = require("@proj/Client")
-- Types
export type HeaderMap = Headers.HeaderMap
export type HeaderName = Headers.HeaderName
export type HeaderValue = Headers.HeaderValue
export type Body = Body.Body
export type Json = Body.Json
export type Request = Request.Request
export type RequestBuilder = Request.RequestBuilder
export type Method = Request.Method
export type Response = Response.Response
export type Client = Client.Client
export type ClientBuilder = Client.ClientBuilder
export type Url = Url.Url
export type TryFromUrl = Url.TryFromUrl

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
return {
	Body = Body,
	Headers = Headers,
	Request = Request,
	Response = Response,
	Client = Client,
	Url = Url,
}
