-- Executes actual server modules with explicit service doubles. No Roblox engine
-- behavior is simulated: tests cover API calls, state, errors and interleaving.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Harness = {}

function Harness.load(path, services, modules, globals)
	local environment = table.clone(globals or {})
	environment.game = environment.game or {}
	environment.game.GetService = function(_, name)
		return assert(services[name], "Missing service double: " .. name)
	end
	environment.require = function(token)
		return assert(modules[token], "Missing module double: " .. tostring(token))
	end
	return luau.load(fs.readFile(path), { environment = environment, injectGlobals = true })()
end

function Harness.resume(thread)
	local ok, value = coroutine.resume(thread)
	assert(ok, tostring(value))
	return value
end

function Harness.finish(callback)
	local result
	local thread = coroutine.create(function()
		result = callback()
	end)
	for _ = 1, 100 do
		Harness.resume(thread)
		if coroutine.status(thread) == "dead" then
			return result
		end
	end
	error("operation did not complete")
end

return Harness
