local Rules = require("../src/shared/RunRules")

return function(test)
	test("run launch requires return to hub after terminal states", function()
		assert(Rules.canStart("Hub"))
		for _, status in { "Loading", "Active", "Complete", "Defeated", "unknown" } do
			assert(not Rules.canStart(status))
		end
	end)
	test("floor reward requires active run, defeated enemies and nearby exit", function()
		assert(Rules.canComplete("Active", 0, 12))
		assert(not Rules.canComplete("Active", 1, 0))
		assert(not Rules.canComplete("Active", -1, 0))
		assert(not Rules.canComplete("Active", 0, 12.001))
		for _, status in { "Hub", "Loading", "Complete", "Defeated" } do
			assert(not Rules.canComplete(status, 0, 0))
		end
	end)
	test("invalid exit distances cannot complete a run", function()
		for _, distance in { -1, math.huge, -math.huge, 0 / 0 } do
			assert(not Rules.canComplete("Active", 0, distance))
		end
	end)
	test("dead or inactive players cannot act", function()
		assert(Rules.canAct("Active", 1))
		assert(not Rules.canAct("Active", 0))
		assert(not Rules.canAct("Active", -1))
		assert(not Rules.canAct("Active", 0 / 0))
		assert(not Rules.canAct("Defeated", 100))
		assert(not Rules.canAct("Hub", 100))
	end)
end
