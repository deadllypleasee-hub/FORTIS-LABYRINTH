--!strict
local FloorValidator = {}
local VALID_KINDS = {
	StartRoom = true,
	Corridor = true,
	TrapRoom = true,
	CombatRoom = true,
	TreasureRoom = true,
	PuzzleRoom = true,
	SecretRoom = true,
	CheckpointRoom = true,
	BossRoom = true,
	ExitRoom = true,
}

local function integer(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

function FloorValidator.validate(layout: any): (boolean, { string })
	local errors: { string } = {}
	local function reject(message: string)
		table.insert(errors, message)
	end
	if type(layout) ~= "table" or type(layout.rooms) ~= "table" or type(layout.edges) ~= "table" then
		return false, { "layout, rooms and edges must be tables" }
	end
	if not integer(layout.floor) or layout.floor < 1 or layout.floor > 25 then
		reject("invalid floor")
	end
	if not integer(layout.seed) then
		reject("seed must be an integer")
	end
	local count = #layout.rooms
	local occupied, kinds, adjacency = {}, {}, {}
	for id, room in layout.rooms do
		if not integer(id) or id < 1 or id > count then
			reject("rooms must be a contiguous array")
			continue
		end
		if type(room) ~= "table" then
			reject("invalid room")
			continue
		end
		if room.id ~= id then
			reject("room IDs must match contiguous array indices")
		end
		if not integer(room.x) or not integer(room.z) then
			reject("room coordinates must be finite integers")
		else
			local cell = tostring(room.x) .. ":" .. tostring(room.z)
			if occupied[cell] then
				reject("overlapping rooms")
			end
			occupied[cell] = true
		end
		if type(room.kind) ~= "string" or not VALID_KINDS[room.kind] then
			reject("unknown room type")
		else
			kinds[room.kind] = (kinds[room.kind] or 0) + 1
		end
		adjacency[id] = {}
	end
	if count < 8 or count > 30 then
		reject("room count outside supported range")
	end
	if integer(layout.floor) and layout.floor >= 1 and layout.floor <= 25 then
		local zone = math.ceil(layout.floor / 5)
		local minimum = 4 + zone * 4
		local maximum = if zone == 5 then 30 else minimum + 4
		if count < minimum or count > maximum then
			reject("room count outside floor range")
		end
	end
	if
		not integer(layout.startId)
		or type(layout.rooms[layout.startId]) ~= "table"
		or layout.rooms[layout.startId].kind ~= "StartRoom"
	then
		reject("missing start room")
	end
	if
		not integer(layout.exitId)
		or type(layout.rooms[layout.exitId]) ~= "table"
		or layout.rooms[layout.exitId].kind ~= "ExitRoom"
	then
		reject("missing exit room")
	end
	for _, kind in { "StartRoom", "ExitRoom", "CombatRoom", "TrapRoom", "TreasureRoom" } do
		if not kinds[kind] then
			reject("missing required room: " .. kind)
		end
	end
	if kinds.StartRoom ~= 1 or kinds.ExitRoom ~= 1 then
		reject("must have exactly one start and one exit")
	end
	local seenEdges = {}
	for _, edge in layout.edges do
		if
			type(edge) ~= "table"
			or not integer(edge.a)
			or not integer(edge.b)
			or not adjacency[edge.a]
			or not adjacency[edge.b]
		then
			reject("edge refers to an invalid room")
			continue
		end
		local a, b = layout.rooms[edge.a], layout.rooms[edge.b]
		if edge.a == edge.b then
			reject("self edge")
		end
		if
			integer(a.x)
			and integer(a.z)
			and integer(b.x)
			and integer(b.z)
			and math.abs(a.x - b.x) + math.abs(a.z - b.z) ~= 1
		then
			reject("edge must connect adjacent cells")
		end
		local edgeKey = tostring(math.min(edge.a, edge.b)) .. ":" .. tostring(math.max(edge.a, edge.b))
		if seenEdges[edgeKey] then
			reject("duplicate edge")
		end
		seenEdges[edgeKey] = true
		table.insert(adjacency[edge.a], edge.b)
		table.insert(adjacency[edge.b], edge.a)
	end
	if #layout.edges ~= count - 1 then
		reject("floor must be a tree")
	end
	if adjacency[layout.startId] then
		local queue, visited = { layout.startId }, { [layout.startId] = true }
		local head = 1
		while head <= #queue do
			local id = queue[head]
			head += 1
			for _, nextId in adjacency[id] do
				if not visited[nextId] then
					visited[nextId] = true
					table.insert(queue, nextId)
				end
			end
		end
		if #queue ~= count then
			reject("floor contains unreachable rooms")
		end
	end
	return #errors == 0, errors
end

return FloorValidator
