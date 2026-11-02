--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorValidator = require(ReplicatedStorage.Shared.generation.FloorValidator)
local RoomGenerator = require(script.Parent.RoomGenerator)
local CorridorGenerator = require(script.Parent.CorridorGenerator)

local FloorBuilder = {}

function FloorBuilder.build(layout: any, parent: Instance, origin: Vector3)
	local valid, errors = FloorValidator.validate(layout)
	assert(valid, "Cannot build invalid floor: " .. table.concat(errors, "; "))
	local model = Instance.new("Model")
	model.Name = string.format("Floor_%02d_Seed_%s", layout.floor, tostring(layout.seed))
	-- This bounded prototype floor streams as one unit, including corridor floors.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Floor", layout.floor)
	model:SetAttribute("Seed", layout.seed)
	local roomCenters: { [number]: Vector3 } = {}
	local doors: { [number]: { [string]: boolean } } = {}
	local enemySpawns: { Vector3 } = {}
	local trapSpawns: { CFrame } = {}
	local chestSpawns: { CFrame } = {}
	for _, room in layout.rooms do
		roomCenters[room.id] = origin
			+ Vector3.new(room.x * RoomGenerator.GRID_SIZE, 0, room.z * RoomGenerator.GRID_SIZE)
		doors[room.id] = {}
	end
	for _, edge in layout.edges do
		local a, b = layout.rooms[edge.a], layout.rooms[edge.b]
		local forward, backward
		if b.x > a.x then
			forward, backward = "E", "W"
		elseif b.x < a.x then
			forward, backward = "W", "E"
		elseif b.z > a.z then
			forward, backward = "S", "N"
		else
			forward, backward = "N", "S"
		end
		doors[a.id][forward] = true
		doors[b.id][backward] = true
	end
	for _, room in layout.rooms do
		local center = roomCenters[room.id]
		RoomGenerator.build(room, center, doors[room.id], model)
		if room.kind == "CombatRoom" then
			table.insert(enemySpawns, center + Vector3.new(0, 3, 0))
		elseif room.kind == "TrapRoom" then
			table.insert(trapSpawns, CFrame.new(center))
		elseif room.kind == "TreasureRoom" then
			table.insert(chestSpawns, CFrame.new(center + Vector3.new(0, 1.5, 0)))
		end
	end
	for _, edge in layout.edges do
		CorridorGenerator.build(roomCenters[edge.a], roomCenters[edge.b], model)
	end
	-- Assemble off-world, then expose the complete floor to the server world.
	model.Parent = parent
	return {
		model = model,
		spawnCFrame = CFrame.new(roomCenters[layout.startId] + Vector3.new(0, 4, 0)),
		exitCFrame = CFrame.new(roomCenters[layout.exitId] + Vector3.new(0, 3, 0)),
		enemySpawns = enemySpawns,
		trapSpawns = trapSpawns,
		chestSpawns = chestSpawns,
		roomCenters = roomCenters,
	}
end

return FloorBuilder
