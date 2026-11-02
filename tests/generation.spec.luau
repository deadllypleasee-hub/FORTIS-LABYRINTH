local FloorGenerator = require("../src/shared/generation/FloorGenerator")
local FloorValidator = require("../src/shared/generation/FloorValidator")

local function fingerprint(layout)
	local parts = { tostring(layout.seed), tostring(layout.floor), tostring(layout.exitId) }
	for _, room in layout.rooms do
		table.insert(parts, string.format("%d:%d:%d:%s", room.id, room.x, room.z, room.kind))
	end
	for _, edge in layout.edges do
		table.insert(parts, string.format("%d>%d", edge.a, edge.b))
	end
	return table.concat(parts, "|")
end

return function(test)
	test("generation: 25 floors x 100 seeds remain connected and non-overlapping", function()
		for floor = 1, 25 do
			for seed = 1, 100 do
				local layout = FloorGenerator.generate(seed * 7919, floor)
				local valid, errors = FloorValidator.validate(layout)
				assert(valid, string.format("floor %d seed %d: %s", floor, seed, table.concat(errors, "; ")))
				local exitDegree = 0
				for _, edge in layout.edges do
					if edge.a == layout.exitId or edge.b == layout.exitId then
						exitDegree += 1
					end
				end
				assert(exitDegree == 1, "exit must be a terminal room")
			end
		end
	end)
	test("generation: seed produces identical room graph", function()
		for _, seed in { 0, -1, 17, 2147483646, 999999999 } do
			assert(fingerprint(FloorGenerator.generate(seed, 1)) == fingerprint(FloorGenerator.generate(seed, 1)))
		end
		assert(fingerprint(FloorGenerator.generate(5, 1)) ~= fingerprint(FloorGenerator.generate(6, 1)))
	end)
	test("generation: rejects invalid floor and non-finite seed", function()
		for _, floor in { 0, 26, 1.5 } do
			assert(not pcall(FloorGenerator.generate, 1, floor))
		end
		assert(not pcall(FloorGenerator.generate, math.huge, 1))
		assert(not pcall(FloorGenerator.generate, 1.5, 1))
	end)
	test("validator: rejects overlap, broken route, invalid edge and absent required room", function()
		local overlap = FloorGenerator.generate(42, 1)
		overlap.rooms[2].x = overlap.rooms[1].x
		overlap.rooms[2].z = overlap.rooms[1].z
		assert(not FloorValidator.validate(overlap))
		local disconnected = FloorGenerator.generate(42, 1)
		table.remove(disconnected.edges)
		assert(not FloorValidator.validate(disconnected))
		local badEdge = FloorGenerator.generate(42, 1)
		badEdge.edges[1].b = 999
		assert(not FloorValidator.validate(badEdge))
		local absentCombat = FloorGenerator.generate(42, 1)
		absentCombat.rooms[3].kind = "Corridor"
		assert(not FloorValidator.validate(absentCombat))
	end)
	test("validator: corrupt scalar rooms and non-array entries are rejected without throwing", function()
		for _, roomId in { 1, 3, 6 } do
			local corrupt = FloorGenerator.generate(42, 1)
			corrupt.rooms[roomId] = 12
			local ok, valid = pcall(FloorValidator.validate, corrupt)
			assert(ok and not valid, "scalar room must be safely rejected")
		end
		local corruptKind = FloorGenerator.generate(42, 1)
		corruptKind.rooms[2].kind = 0 / 0
		local ok, valid = pcall(FloorValidator.validate, corruptKind)
		assert(ok and not valid, "non-string room kind must be safely rejected")
		local nonArray = FloorGenerator.generate(42, 1)
		nonArray.rooms.extra = { id = "extra", x = 99, z = 99, kind = "Corridor" }
		assert(not FloorValidator.validate(nonArray))
	end)
end
