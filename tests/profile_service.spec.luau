local Harness = require("./helpers/ServerHarness")
local ProfileRules = require("../src/shared/ProfileRules")
local Lease = require("../src/shared/ProfileLease")

local function fixture(kind, studio)
	local record, updates, clock = nil, 0, 0
	local hooks = {}
	local store = {}
	function store:UpdateAsync(_, callback)
		updates += 1
		if hooks.update then
			hooks.update()
		end
		local nextRecord = callback(record)
		if nextRecord then
			record = nextRecord
		end
		return nextRecord
	end
	local Service = Harness.load("src/server/ProfileService.luau", {
		DataStoreService = {
			GetDataStore = function()
				return store
			end,
		},
		HttpService = {
			GenerateGUID = function()
				return "profile-session"
			end,
		},
		RunService = {
			IsStudio = function()
				return studio == true
			end,
		},
		ReplicatedStorage = {
			PlaceKind = { Value = kind or "Hub" },
			Shared = { Config = "Config", ProfileRules = "Rules", ProfileLease = "Lease" },
		},
	}, { Config = { EnablePersistence = true }, Rules = ProfileRules, Lease = Lease }, {
		game = { JobId = "hub-job" },
		os = {
			clock = function()
				return clock
			end,
			time = function()
				return 100
			end,
		},
		task = {
			spawn = function() end, -- Autosave loop is outside these deterministic tests.
			wait = function(seconds)
				clock += seconds
				return coroutine.yield("wait")
			end,
		},
		warn = function() end,
	})
	return Service.new(), { UserId = 42 }, hooks, function()
		return record, updates
	end
end

return function(test)
	test("profile service: release and reload serialize across replaced entries", function()
		local service, player, hooks, stored = fixture()
		local previous = service:load(player)
		previous.coins = 50
		local releasing, loaded
		hooks.update = function()
			hooks.update = nil
			coroutine.yield("store")
		end
		local release = coroutine.create(function()
			releasing = service:save(player, true)
		end)
		assert(Harness.resume(release) == "store")
		local reload = coroutine.create(function()
			loaded = service:load(player)
		end)
		assert(Harness.resume(reload) == "wait", "load returned a profile being released")
		Harness.resume(release)
		assert(releasing and not service:isAvailable(player))
		local record = stored()
		record.data.coins = 175 -- Simulate a committed update from the destination server.
		Harness.resume(reload)
		assert(loaded ~= previous and loaded.coins == 175, "reload resurrected stale profile data")
		assert(service:isAvailable(player))
	end)

	test("profile service: simultaneous loads share one successful lease acquisition", function()
		local service, player, hooks, stored = fixture()
		local first, second
		hooks.update = function()
			hooks.update = nil
			coroutine.yield("store")
		end
		local a = coroutine.create(function()
			first = service:load(player)
		end)
		local b = coroutine.create(function()
			second = service:load(player)
		end)
		assert(Harness.resume(a) == "store")
		assert(Harness.resume(b) == "wait")
		Harness.resume(a)
		Harness.resume(b)
		local _, updates = stored()
		assert(first == second and updates == 1)
	end)

	test("profile service: queued autosave reads the current entry after release and reload", function()
		local service, player, hooks, stored = fixture()
		service:load(player).coins = 50
		hooks.update = function()
			hooks.update = nil
			coroutine.yield("store")
		end
		local a = coroutine.create(function()
			service:save(player, true)
		end)
		local b = coroutine.create(function()
			assert(service:save(player, false))
		end)
		Harness.resume(a)
		Harness.resume(b)
		Harness.resume(a)
		service:load(player).coins = 200
		Harness.resume(b)
		assert(stored().data.coins == 200, "queued save overwrote the newly loaded profile")
	end)

	test("profile service: store errors fail closed, unlock operations and allow recovery", function()
		local service, player, hooks = fixture()
		service:load(player).coins = 27
		hooks.update = function()
			error("DataStore unavailable")
		end
		assert(not Harness.finish(function()
			return service:save(player, false)
		end))
		assert(not service:isAvailable(player) and service.locks[player] == nil)
		hooks.update = nil
		assert(service:save(player, false) and service:isAvailable(player))
		assert(service:get(player).coins == 27)
	end)

	test("profile service: Preview and Studio never write production data", function()
		for _, setup in { { "Preview", false }, { "Hub", true }, { "Dungeon", true } } do
			local service, player, _, stored = fixture(setup[1], setup[2])
			assert(service:mode() == "Session")
			service:load(player).coins = 999
			assert(service:save(player, true))
			assert(service:load(player).coins == 0)
			local _, updates = stored()
			assert(updates == 0)
		end
	end)

	test("profile service: shutdown during acquisition releases the newly acquired lease", function()
		local service, player, hooks, stored = fixture()
		hooks.update = function()
			hooks.update = nil
			service.closed = true
		end
		assert(service:load(player) == nil)
		assert(service:get(player) == nil and stored().lock == nil)
	end)
end
