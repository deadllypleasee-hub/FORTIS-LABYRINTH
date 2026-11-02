local Rules = require("../src/shared/ProfileRules")

return function(test)
	test("new accounts have isolated reward ledgers", function()
		local first, second = Rules.new(), Rules.new()
		assert(Rules.reward(first, "enemy:1", 10))
		assert(second.coins == 0 and #second.rewards == 0)
		assert(first.potions == 3 and first.version == 1)
	end)
	test("damaged saved data cannot introduce invalid balances or floors", function()
		local profile = Rules.normalize({
			coins = 0 / 0,
			kills = math.huge,
			deaths = -4,
			bestFloor = 900,
			completedFloors = "25",
			potions = 2.9,
			rewards = { "valid", false, string.rep("x", 101) },
		})
		assert(profile.coins == 0 and profile.kills == 0 and profile.deaths == 0)
		assert(profile.bestFloor == 25 and profile.completedFloors == 0 and profile.potions == 2)
		assert(#profile.rewards == 1 and profile.rewards[1] == "valid")
		assert(Rules.normalize(false).potions == 3)
	end)
	test("retrying the same saved reward does not mint coins twice", function()
		local profile = Rules.new()
		assert(Rules.reward(profile, "run:123:floor:1", 75))
		local reloaded = Rules.normalize(profile)
		assert(not Rules.reward(reloaded, "run:123:floor:1", 75))
		assert(reloaded.coins == 75 and #reloaded.rewards == 1)
	end)
	test("invalid reward amounts leave account and ledger unchanged", function()
		local profile = Rules.new()
		for index, amount in { -1, 0.5, math.huge, -math.huge, 0 / 0, 100001 } do
			assert(not Rules.reward(profile, "invalid:" .. tostring(index), amount))
		end
		assert(not Rules.reward(profile, "", 1))
		assert(not Rules.reward(profile, string.rep("x", 101), 1))
		assert(profile.coins == 0 and #profile.rewards == 0)
	end)
	test("balances saturate and recent reward history remains bounded", function()
		local profile = Rules.normalize({ coins = 999999999 })
		for index = 1, 140 do
			assert(Rules.reward(profile, "reward:" .. tostring(index), 10))
		end
		assert(profile.coins == 1000000000 and #profile.rewards == 128)
		assert(not Rules.reward(profile, "reward:140", 10))
	end)
end
