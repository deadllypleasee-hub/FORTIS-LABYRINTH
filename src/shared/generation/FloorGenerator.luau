--!strict
local Random = require(if script then script.Parent.Random else "./Random")

export type Room = { id: number, x: number, z: number, kind: string }
export type Edge = { a: number, b: number }
export type Layout = {
	seed: number,
	floor: number,
	rooms: { Room },
	edges: { Edge },
	startId: number,
	exitId: number,
}

local FloorGenerator = {}
local DIRECTIONS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
local ROOM_RANGES = { { 8, 12 }, { 12, 16 }, { 16, 20 }, { 20, 24 }, { 24, 30 } }

local function key(x: number, z: number): string
	return tostring(x) .. ":" .. tostring(z)
end

function FloorGenerator.generate(seed: number, floor: number): Layout
	assert(seed == seed and math.abs(seed) < math.huge and seed % 1 == 0, "seed must be a finite integer")
	assert(floor % 1 == 0 and floor >= 1 and floor <= 25, "floor must be an integer from 1 to 25")
	local rng = Random.new(seed)
	local range = ROOM_RANGES[math.ceil(floor / 5)]
	local count = rng:nextInteger(range[1], range[2])
	local rooms: { Room } = { { id = 1, x = 0, z = 0, kind = "StartRoom" } }
	local edges: { Edge } = {}
	local occupied = { [key(0, 0)] = true }
	local adjacency: { { number } } = { {} }

	local function available(room: Room): { { number } }
		local candidates = {}
		for _, direction in DIRECTIONS do
			local x, z = room.x + direction[1], room.z + direction[2]
			if not occupied[key(x, z)] then
				table.insert(candidates, { x, z })
			end
		end
		return candidates
	end

	while #rooms < count do
		-- Begin with a six-room route. Afterwards grow branches from its frontier.
		local parent = rooms[#rooms]
		local candidates = available(parent)
		if #rooms >= 6 or #candidates == 0 then
			local frontier = {}
			for _, room in rooms do
				if #available(room) > 0 then
					table.insert(frontier, room)
				end
			end
			parent = frontier[rng:nextInteger(1, #frontier)]
			candidates = available(parent)
		end
		local cell = candidates[rng:nextInteger(1, #candidates)]
		local id = #rooms + 1
		local kind = "Corridor"
		if id == 2 then
			kind = "TrapRoom"
		elseif id == 3 then
			kind = "CombatRoom"
		elseif id == 4 then
			kind = "TreasureRoom"
		end
		table.insert(rooms, { id = id, x = cell[1], z = cell[2], kind = kind })
		table.insert(edges, { a = parent.id, b = id })
		occupied[key(cell[1], cell[2])] = true
		adjacency[id] = { parent.id }
		table.insert(adjacency[parent.id], id)
	end

	-- Exit is a distant leaf; never replace the required trap/combat/treasure rooms.
	local queue = { 1 }
	local distance = { [1] = 0 }
	local exitId = 6
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		for _, nextId in adjacency[id] do
			if distance[nextId] == nil then
				distance[nextId] = distance[id] + 1
				table.insert(queue, nextId)
				if nextId >= 5 and distance[nextId] > (distance[exitId] or -1) then
					exitId = nextId
				end
			end
		end
	end
	rooms[exitId].kind = "ExitRoom"
	return { seed = seed, floor = floor, rooms = rooms, edges = edges, startId = 1, exitId = exitId }
end

return FloorGenerator
