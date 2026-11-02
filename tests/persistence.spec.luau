local Lease = require("../src/shared/ProfileLease")
local Rules = require("../src/shared/ProfileRules")

return function(test)
	test("fresh profile acquisition creates a 120-second server lease", function()
		local record = assert(Lease.acquire(nil, "server-a", 1000))
		assert(record.data.version == 1 and record.data.coins == 0)
		assert(record.lock.session == "server-a" and record.lock.expires == 1120)
		assert(record.releasedBy == nil)
	end)

	test("concurrent owner cannot acquire an unexpired profile", function()
		local first = assert(Lease.acquire(nil, "server-a", 1000))
		assert(Lease.acquire(first, "server-b", 1119) == nil)
		assert(first.lock.session == "server-a" and first.lock.expires == 1120)
	end)

	test("expired lease can be reclaimed at the exact expiration boundary", function()
		local first = assert(Lease.acquire(nil, "server-a", 1000))
		first.data.coins = 45
		local reclaimed = assert(Lease.acquire(first, "server-b", 1120))
		assert(reclaimed.lock.session == "server-b" and reclaimed.lock.expires == 1240)
		assert(reclaimed.data.coins == 45)
		assert(first.lock.session == "server-a")
	end)

	test("same server can renew its lease without mutating the old record", function()
		local first = assert(Lease.acquire(nil, "server-a", 1000))
		local renewed = assert(Lease.acquire(first, "server-a", 1030))
		assert(renewed.lock.expires == 1150 and first.lock.expires == 1120)
		assert(renewed.data ~= first.data and renewed.data.rewards ~= first.data.rewards)
	end)

	test("future profile schema cannot be downgraded on load or save", function()
		local future = { data = { version = 2, coins = 999 }, lock = { session = "server-a", expires = 1120 } }
		assert(Lease.acquire(future, "server-a", 1000) == nil)
		assert(Lease.save(future, "server-a", Rules.new(), false, 1000) == nil)
		assert(future.data.coins == 999 and future.data.version == 2)
	end)

	test("malformed stored schema versions fail closed", function()
		for _, version in { "1", -1, 0.5, math.huge, 0 / 0 } do
			assert(Lease.acquire({ data = { version = version } }, "server-a", 1000) == nil)
		end
		assert(Lease.acquire("corrupt", "server-a", 1000) == nil)
		assert(Lease.acquire({ data = "corrupt" }, "server-a", 1000) == nil)
		assert(Lease.acquire({ data = {} }, "server-a", 1000).data.version == 1)
	end)

	test("malformed locks do not grant ownership", function()
		for _, lock in { "corrupt", {}, { session = "server-b", expires = "yesterday" } } do
			local old = { data = Rules.new(), lock = lock }
			assert(Lease.acquire(old, "server-a", 1000) == nil)
			assert(Lease.save(old, "server-a", Rules.new(), false, 1000) == nil)
		end
	end)

	test("autosave normalizes an isolated snapshot and renews owner lease", function()
		local old = assert(Lease.acquire(nil, "server-a", 1000))
		local snapshot = Rules.new()
		snapshot.coins = 87
		assert(Rules.reward(snapshot, "kill:1", 10))
		local saved = assert(Lease.save(old, "server-a", snapshot, false, 1030))
		assert(saved.data.coins == 97 and saved.lock.expires == 1150)
		assert(saved.lock.session == "server-a" and saved.releasedBy == nil)
		snapshot.coins = 0
		table.clear(snapshot.rewards)
		assert(saved.data.coins == 97 and #saved.data.rewards == 1)
		assert(old.data.coins == 0 and old.lock.expires == 1120)
	end)

	test("release retry returns the committed record without issuing newer rewards", function()
		local old = assert(Lease.acquire(nil, "server-a", 1000))
		local snapshot = Rules.new()
		assert(Rules.reward(snapshot, "floor:1", 35))
		local released = assert(Lease.save(old, "server-a", snapshot, true, 1030))
		assert(released.lock == nil and released.releasedBy == "server-a")
		assert(released.data.coins == 35)
		assert(Rules.reward(snapshot, "late-reward", 20))
		local retry = assert(Lease.save(released, "server-a", snapshot, true, 1031))
		assert(retry == released and retry.data.coins == 35)
		assert(#retry.data.rewards == 1)
		assert(Lease.save(released, "server-a", snapshot, false, 1031) == nil)
		assert(Lease.save(released, "server-b", snapshot, true, 1031) == nil)
	end)

	test("fresh acquisition removes release marker and rejects old release retries", function()
		local first = assert(Lease.acquire(nil, "server-a", 1000))
		local released = assert(Lease.save(first, "server-a", first.data, true, 1030))
		local nextOwner = assert(Lease.acquire(released, "server-b", 1031))
		assert(nextOwner.releasedBy == nil and nextOwner.lock.session == "server-b")
		assert(Lease.save(nextOwner, "server-a", first.data, true, 1032) == nil)
	end)

	test("stale writer cannot overwrite progress after another server reclaims lease", function()
		local first = assert(Lease.acquire(nil, "server-a", 1000))
		local nextOwner = assert(Lease.acquire(first, "server-b", 1120))
		local current = Rules.new()
		current.coins = 90
		local saved = assert(Lease.save(nextOwner, "server-b", current, false, 1121))
		local stale = Rules.new()
		stale.coins = 1
		assert(Lease.save(saved, "server-a", stale, false, 1122) == nil)
		assert(Lease.save(saved, "server-a", stale, true, 1122) == nil)
		assert(saved.data.coins == 90 and saved.lock.session == "server-b")
	end)

	test("invalid lease request clocks cannot poison stored expiration", function()
		for _, now in { -1, math.huge, 0 / 0 } do
			assert(Lease.acquire(nil, "server-a", now) == nil)
		end
		assert(Lease.acquire(nil, "", 1000) == nil)
	end)
end
