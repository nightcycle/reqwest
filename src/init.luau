--!strict
-- Services
-- Packages

-- Modules
local Body = require("./Body")
local Request = require("./Request")
local Response = require("./Response")
local Url = require("./Url")
local Client = require("./Client")
-- Types
export type HeaderMap = Response.HeaderMap
export type Body<V> = Body.Body<V>
export type Json = Body.Json
export type Form = Body.Form
export type Request = Request.Request
export type RequestBuilder = Request.RequestBuilder
export type Method = Request.Method
export type Response<V> = Response.Response<V>
export type Client = Client.Client
export type ClientBuilder = Client.ClientBuilder
export type Url = Url.Url
export type PotentialSecret = Url.PotentialSecret
export type ContentType = Body.ContentType
-- Constants
-- Variables
-- References
-- Private Functions

Client.new()
	:build()
	:post("test")
	:body(Body.fromForm({
		A = 1,
		B = 2,
		C = "3",
	}))
	:build()

-- Class
return {
	Body = Body,
	Request = Request,
	Response = Response,
	Client = Client,
	Url = Url,
}
