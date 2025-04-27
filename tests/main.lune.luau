--!strict
-- Services
-- Packages
local option = require("@pkg/@nightcycle/option")
local hashMap = require("@pkg/@nightcycle/hash-map")
local luneUtil = require("@pkg/@nightcycle/lune-util")
-- Modules
local src = require("../src")
local testUtil = require("./test-util")
-- Types
-- Constants

-- Variables
-- References
-- Private Functions
local ledger = testUtil.newLedger
-- Class
local tests = {}

do
	local EXAMPLE_URL_STR = "https://example.com/path/to/resource"
	local SECRET_URL_KEY = "secret_url"
	luneUtil.Env[SECRET_URL_KEY] = option.some(EXAMPLE_URL_STR)

	local SECRET_QUERY_VALUE = "secret_value"
	local SECRET_QUERY_KEY = "secret_query"
	luneUtil.Env[SECRET_QUERY_KEY] = option.some(SECRET_QUERY_VALUE)

	tests.url = ledger({
		constructor = ledger({
			value = ledger({
				str = function()
					src.Url.from(EXAMPLE_URL_STR)
				end,
				secret = function()
					src.Url.from(
						luneUtil.Env[SECRET_URL_KEY]:expect(`no secret assigned at "{SECRET_URL_KEY}"`)
					)
				end,
			}),
			query = ledger({
				table = ledger({
					single = function()
						src.Url.from(EXAMPLE_URL_STR, {
							str = "abc",
						})
					end,
					multiple = function()
						src.Url.from(EXAMPLE_URL_STR, {
							a = "a",
							b = "b",
						})
					end,
				}),
				hashMap = ledger({
					single = function()
						src.Url.from(EXAMPLE_URL_STR, {
							str = "abc",
						})
					end,
					multiple = function()
						src.Url.from(
							EXAMPLE_URL_STR,
							hashMap.from({
								a = "a",
								b = "b",
							})
						)
					end,
				}),
			}),
		}),
		parsing = ledger({
			protocol = ledger({
				https = function()
					local url = src.Url.from(EXAMPLE_URL_STR)
					local out = url:protocol():expect(`no protocol found for {EXAMPLE_URL_STR}`)
					local target = "https"
					assert(out == target, `expected "{out}" to be "{target}"`)
				end,
				http = function()
					local httpExample = EXAMPLE_URL_STR:gsub("https", "http")
					local url = src.Url.from(httpExample)
					local out = url:protocol():expect(`no protocol found for {httpExample}`)
					local target = "http"
					assert(out == target, `expected "{out}" to be "{target}"`)
				end,
			}),
			domain = function()
				local url = src.Url.from(EXAMPLE_URL_STR)
				local out = url:domain():expect(`no domain found for {EXAMPLE_URL_STR}`)
				assert(out == "example.com", `expected "{out}" to be "example.com"`)
			end,
			query = function()
				local query = "a=a&b=b"
				local queryUrl = EXAMPLE_URL_STR .. "?" .. query
				local url = src.Url.from(queryUrl)
				local out = url:query():expect(`no query found for {queryUrl}`)
				assert(out == query, `expected "{out}" to be "{query}"`)
			end,
			path = function()
				local path = "path/to/resource"
				local url = src.Url.from(EXAMPLE_URL_STR)
				local out = url:path():expect(`no path found for {EXAMPLE_URL_STR}`)
				assert(out == path, `expected "{out}" to be "{path}"`)
			end,
		}),
		display = ledger({
			value = ledger({
				str = function()
					local url = src.Url.from(EXAMPLE_URL_STR)
					local out = url:display()
					assert(out == EXAMPLE_URL_STR, `expected "{out}" to be "{EXAMPLE_URL_STR}"`)
				end,
				secret = function()
					local url = src.Url.from(
						luneUtil.Secrets[SECRET_URL_KEY]:expect(`no secret assigned at "{SECRET_URL_KEY}"`)
					)
					local out = url:display()
					assert(type(out) == "table", `expected "{out}" to be a table, received "{type(out)}"`)
					assert(
						out:Build() == EXAMPLE_URL_STR,
						`expected "{out:Build()}" to be "{EXAMPLE_URL_STR}"`
					)
				end,
			}),
			query = ledger({
				str = ledger({
					single = function()
						local url = src.Url.from(EXAMPLE_URL_STR, {
							str = "abc",
						})
						local out = url:display()
						local target = `{EXAMPLE_URL_STR}?str=abc`
						assert(out == target, `expected "{out}" to be "{target}"`)
					end,
					multiple = function()
						local url = src.Url.from(EXAMPLE_URL_STR, {
							a = "a",
							b = "b",
						})
						local out = url:display()
						local target1 = `{EXAMPLE_URL_STR}?a=a&b=b`
						local target2 = `{EXAMPLE_URL_STR}?b=b&a=a`
						assert(
							out == target1 or out == target2,
							`expected "{out}" to be "{target1}" or "{target2}"`
						)
					end,
				}),
				secret = ledger({
					value = ledger({
						single = function()
							local url = src.Url.from(
								luneUtil.Secrets[SECRET_URL_KEY]:expect(
									`no secret assigned at "{SECRET_URL_KEY}"`
								),
								{
									str = "abc",
								}
							)
							local out = url:display()
							local target = `{EXAMPLE_URL_STR}?str=abc`
							assert(
								type(out) == "table",
								`expected "{out}" to be a table, received "{type(out)}"`
							)
							assert(out:Build() == target, `expected "{out:Build()}" to be "{target}"`)
						end,
						multiple = function()
							local url = src.Url.from(
								luneUtil.Secrets[SECRET_URL_KEY]:expect(
									`no secret assigned at "{SECRET_URL_KEY}"`
								),
								{
									a = "a",
									b = "b",
								}
							)
							local out = url:display() :: luneUtil.CompatSecret
							local target1 = `{EXAMPLE_URL_STR}?a=a&b=b`
							local target2 = `{EXAMPLE_URL_STR}?b=b&a=a`
							assert(
								out:Build() == target1 or out:Build() == target2,
								`expected "{out}" to be "{target1}" or "{target2}"`
							)
						end,
					}),
					query = ledger({
						single = function()
							local url = src.Url.from(EXAMPLE_URL_STR, {
								[SECRET_QUERY_KEY] = luneUtil.Secrets[SECRET_QUERY_KEY]:expect(
									`no secret assigned at "{SECRET_QUERY_KEY}"`
								),
							})
							local out = url:display()
							local target = `{EXAMPLE_URL_STR}?{SECRET_QUERY_KEY}={SECRET_QUERY_VALUE}`
							assert(
								type(out) == "table",
								`expected "{out}" to be a table, received "{type(out)}"`
							)
							assert(out:Build() == target, `expected "{out:Build()}" to be "{target}"`)
						end,
						multiple = function()
							local url = src.Url.from(EXAMPLE_URL_STR, {
								[SECRET_QUERY_KEY] = luneUtil.Secrets[SECRET_QUERY_KEY]:expect(
									`no secret assigned at "{SECRET_QUERY_KEY}"`
								),
								abc = "abc",
							})
							local out = url:display()
							local target1 =
								`{EXAMPLE_URL_STR}?{SECRET_QUERY_KEY}={SECRET_QUERY_VALUE}&abc=abc`
							local target2 =
								`{EXAMPLE_URL_STR}?abc=abc&{SECRET_QUERY_KEY}={SECRET_QUERY_VALUE}`
							assert(
								type(out) == "table",
								`expected "{out}" to be a table, received "{type(out)}"`
							)
							local builtOut = out:Build()
							assert(
								builtOut == target1 or builtOut == target2,
								`expected "{builtOut}" to be "{target1}" or "{target2}"`
							)
						end,
					}),
				}),
			}),
		}),
	})
end

ledger(tests):run()
