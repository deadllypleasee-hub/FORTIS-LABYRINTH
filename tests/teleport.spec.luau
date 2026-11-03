local Harness = require("./helpers/ServerHarness")
local Ticket = require("../src/shared/RunTicket")

local function fixture()
	local config = { HubPlaceId = 100, DungeonPlaceId = 200 }
	local calls, tickets, serial = {}, {}, 0
	local map = {}
	function map:SetAsync(id, value, ttl)
		assert(ttl == Ticket.Lifetime)
		tickets[id] = value
	end
	function map:RemoveAsync(id)
		tickets[id] = nil
	end
	function map:UpdateAsync(id, callback)
		local result = callback(tickets[id])
		if result then
			tickets[id] = result
		end
		return result
	end
	local teleports = {}
	function teleports:ReserveServerAsync(place)
		table.insert(calls, { kind = "reserve", place = place })
		return "reserved-access-code", "reserved-server"
	end
	function teleports:TeleportAsync(place, players, options)
		table.insert(calls, { kind = "teleport", place = place, players = players, options = options })
	end
	local join = { SourcePlaceId = 100, TeleportData = {} }
	local player = {
		UserId = 42,
		GetJoinData = function()
			return join
		end,
	}
	local api = Harness.load("src/server/TeleportService.luau", {
		TeleportService = teleports,
		MemoryStoreService = {
			GetHashMap = function()
				return map
			end,
		},
		HttpService = {
			GenerateGUID = function()
				serial += 1
				return string.format("%036d", serial)
			end,
		},
		ReplicatedStorage = { Shared = { Config = "Config", RunTicket = "Ticket" } },
	}, { Config = config, Ticket = Ticket }, {
		game = { JobId = "dungeon-job", PrivateServerId = "reserved-server", PrivateServerOwnerId = 0 },
		os = {
			time = function()
				return 100
			end,
		},
		Instance = {
			new = function(class)
				assert(class == "TeleportOptions")
				return {
					SetTeleportData = function(self, value)
						self.data = value
					end,
				}
			end,
		},
		warn = function() end,
	})
	return api, player, calls, tickets, join, config, teleports
end

return function(test)
	test("teleports: actual service reserves Dungeon and binds a server-only ticket", function()
		local api, player, calls, tickets, join = fixture()
		assert(api.toDungeon(player, 12345))
		assert(#calls == 2 and calls[1].kind == "reserve" and calls[1].place == 200)
		local call = calls[2]
		assert(call.place == 200 and call.players[1] == player)
		assert(call.options.ReservedServerAccessCode == "reserved-access-code")
		local id = call.options.data.runId
		local count = 0
		for key in call.options.data do
			assert(key == "runId", "teleport data exposed non-authoritative progress")
			count += 1
		end
		assert(count == 1 and tickets[id].userId == 42 and tickets[id].seed == 12345)
		join.TeleportData.runId = id
		local admitted = api.admit(player)
		assert(admitted.id == id and admitted.seed == 12345)
		assert(api.admit(player) == nil, "ticket replay admitted the same player twice")
	end)

	test("teleports: wrong source, player and malformed tickets cannot authorize admission", function()
		local api, player, calls, tickets, join = fixture()
		api.toDungeon(player, 123)
		local id = calls[2].options.data.runId
		join.TeleportData.runId = id
		join.SourcePlaceId = 999
		assert(api.admit(player) == nil)
		join.SourcePlaceId = 100
		player.UserId = 43
		assert(api.admit(player) == nil)
		player.UserId = 42
		tickets[id].seed = 0 / 0
		assert(api.admit(player) == nil)
	end)

	test("teleports: unconfigured Places do not reserve servers or dispatch teleports", function()
		local api, player, calls, _, _, config = fixture()
		config.HubPlaceId = 0
		assert(not api.toDungeon(player, 1) and not api.toHub(player))
		assert(#calls == 0)
	end)

	test("teleports: failed dispatch revokes the unused run ticket", function()
		local api, player, _, tickets, _, _, service = fixture()
		service.TeleportAsync = function()
			error("Teleport unavailable")
		end
		assert(not api.toDungeon(player, 123))
		assert(next(tickets) == nil)
	end)

	test("teleports: returning to HUB uses the configured Place and player", function()
		local api, player, calls = fixture()
		assert(api.toHub(player))
		assert(#calls == 1 and calls[1].place == 100 and calls[1].players[1] == player)
	end)

	test("run tickets: claim callback retries are idempotent without mutating stored input", function()
		local ticket = { userId = 42, seed = 1, privateServerId = "server", issuedAt = 100 }
		local claimed = assert(Ticket.claim(ticket, 42, "server", "job", "claim", 101))
		assert(ticket.claimId == nil and claimed ~= ticket)
		assert(Ticket.claim(claimed, 42, "server", "job", "claim", 101))
		assert(not Ticket.claim(claimed, 42, "server", "job", "other", 101))
		assert(not Ticket.claim(claimed, 42, "server", "other", "claim", 101))
	end)

	test("run tickets: expiry boundary, future dates and corrupted fields fail closed", function()
		local base = { userId = 42, seed = 1, privateServerId = "server", issuedAt = 100 }
		for _, now in { 99, 280, math.huge, 0 / 0 } do
			assert(not Ticket.claim(base, 42, "server", "job", "claim", now))
		end
		assert(Ticket.claim(base, 42, "server", "job", "claim", 279))
		for _, seed in { -1, 0, 1.5, 2147483647, math.huge, "seed" } do
			local invalid = table.clone(base)
			invalid.seed = seed
			assert(not Ticket.claim(invalid, 42, "server", "job", "claim", 101))
		end
		assert(not Ticket.claim(false, 42, "server", "job", "claim", 101))
	end)
end
