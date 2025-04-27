--!strict
-- Services
-- Packages
local result = require("@pkg/@nightcycle/result")
local option = require("@pkg/@nightcycle/option")
-- Modules
-- Types
type Result<V, E> = result.Result<V, E>
type Option<V> = option.Option<V>
export type Ledger = {
	[string]: () -> () | Ledger,
	run: (self: Ledger) -> (),
}
-- Constants
-- Variables
-- References
-- Private Functions
function execute(ledger: Ledger, path: string): { [string]: true | string }
	local results: { [string]: true | string } = {}
	for key, value in pairs(ledger) do
		local keyPath = if path:len() > 0 then path .. "/" .. key else key
		if type(value) == "function" then
			if key == "run" then
				continue
			end
			local success, msg = pcall(function()
				value()
			end)
			results[keyPath] = if success then true else msg
		elseif type(value) == "table" then
			for k, v in pairs(execute(value, keyPath)) do
				results[k] = v :: true | string
			end
		end
	end
	return results
end

-- Class
local util = {}

util.newLedger = function(tests: { [string]: () -> () | Ledger }): Ledger
	local ledger = {}

	ledger.run = function(self: Ledger): ()
		local results = execute(ledger, "")
		local keys = {}
		for key, v in pairs(results) do
			if key == "run" then
				continue
			end
			table.insert(keys, key)
		end
		table.sort(keys)
		local isAllOk = true
		for i, key in ipairs(keys) do
			local value = results[key]
			if value ~= true then
				warn(`{key}: {value}`)
				isAllOk = false
			else
				print(`{key}: ok`)
			end
		end
		if isAllOk then
			print("All tests passed")
		else
			error("Some tests failed")
		end
	end

	for k, v in pairs(tests) do
		ledger[k] = v
	end

	return ledger
end

return util
