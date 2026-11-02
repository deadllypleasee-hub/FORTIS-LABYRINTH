-- Static construction checks using Lune's real Roblox datatypes and Instances.
-- These inspect stored geometry; they do not simulate physics or Roblox Studio.
-- Lune does not derive Attachment.WorldPosition or synchronize Position/CFrame.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local environment = {}
for _, key in { "Instance", "Vector3", "Vector2", "CFrame", "Color3", "Enum", "UDim2" } do
	environment[key] = roblox[key]
end

local function loadBuilder(path)
	return luau.load(fs.readFile(path), { environment = environment, injectGlobals = true })()
end

local HubBuilder = loadBuilder("src/hub/HubBuilder.luau")
local RoomGenerator = loadBuilder("src/dungeon/RoomGenerator.luau")
local CorridorGenerator = loadBuilder("src/dungeon/CorridorGenerator.luau")
local Vector3 = roblox.Vector3
local Instance = roblox.Instance

local function near(actual, expected)
	assert(math.abs(actual - expected) < 0.001, string.format("expected %f, got %f", expected, actual))
end

local function solids(model)
	local parts = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			assert(item.Anchored, "static scene contains an unanchored part: " .. item.Name)
			assert(item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0, "degenerate part")
			table.insert(parts, item)
		end
		assert(
			not item:IsA("MeshPart")
				and not item:IsA("SpecialMesh")
				and not item:IsA("Decal")
				and not item:IsA("Texture")
				and not item:IsA("Sound")
				and not item:IsA("ImageLabel")
				and not item:IsA("ImageButton"),
			"prototype primitive geometry unexpectedly requires an external asset: " .. item.ClassName
		)
	end
	return parts
end

return function(test)
	test("scene: actual HUB creates an anchored mobile-budget plaza with a supported spawn", function()
		local parent = Instance.new("Folder")
		local hub = HubBuilder.build(parent)
		assert(hub.model.Parent == parent)
		local parts = solids(hub.model)
		assert(#parts > 20 and #parts <= 160, "HUB static-part budget exceeded")
		local plaza = assert(hub.model:FindFirstChild("BlackStonePlaza"))
		local spawn = hub.spawnCFrame.Position
		assert(math.abs(spawn.X - plaza.Position.X) + 2 < plaza.Size.X / 2)
		assert(math.abs(spawn.Z - plaza.Position.Z) + 2 < plaza.Size.Z / 2)
		local floorTop = plaza.Position.Y + plaza.Size.Y / 2
		near(floorTop, 0)
		assert(spawn.Y - floorTop >= 3 and spawn.Y - floorTop <= 6, "spawn is buried or floating too high")
		local spawnLocation = assert(hub.model:FindFirstChildOfClass("SpawnLocation"))
		assert(spawnLocation.Neutral and spawnLocation.Duration == 0)
		parent:Destroy()
	end)

	test("scene: actual portal has a torso-height attachment and a clear central approach", function()
		local parent = Instance.new("Folder")
		local hub = HubBuilder.build(parent)
		local prompt = hub.portalPrompt
		assert(prompt:IsA("ProximityPrompt") and prompt.Parent:IsA("Attachment"))
		local gate = prompt.Parent.Parent
		assert(gate:IsA("BasePart") and not gate.CanCollide, "portal must permit passage")
		-- The HUB is axis aligned, so its stored offsets determine this position.
		local interactionPosition = gate.Position + prompt.Parent.Position
		assert(interactionPosition.Y >= 2 and interactionPosition.Y <= 7, "prompt is above player reach")
		assert(prompt.MaxActivationDistance >= 8 and prompt.MaxActivationDistance <= 16)
		local dais = assert(hub.model:FindFirstChild("PortalDais"))
		assert(math.abs(interactionPosition.X - dais.Position.X) < dais.Size.X / 2)
		assert(math.abs(interactionPosition.Z - dais.Position.Z) < dais.Size.Z / 2)
		-- Check an 4-stud-wide, standing-height aisle from spawn to the dais.
		for _, part in solids(hub.model) do
			local lower = part.Position - part.Size / 2
			local upper = part.Position + part.Size / 2
			local crossesAisle = lower.X < 2 and upper.X > -2 and lower.Z < 51 and upper.Z > -60
			local crossesStandingHeight = lower.Y < 6 and upper.Y > 1.2
			assert(
				not (part.CanCollide and crossesAisle and crossesStandingHeight),
				"blocked portal aisle: " .. part.Name
			)
		end
		parent:Destroy()
	end)

	test("scene: actual room walls preserve a walkable opening for all sixteen door combinations", function()
		local parent = Instance.new("Folder")
		local center = Vector3.new(90, 10, -50)
		local sides = { "N", "S", "E", "W" }
		for mask = 0, 15 do
			local doors = {}
			for index, side in sides do
				doors[side] = bit32.band(mask, bit32.lshift(1, index - 1)) ~= 0
			end
			local room = RoomGenerator.build({ id = mask + 1, kind = "StartRoom" }, center, doors, parent)
			assert(#solids(room) <= 32, "room static-part budget exceeded")
			local floor = assert(room:FindFirstChild("Floor"))
			near(floor.Position.Y + floor.Size.Y / 2, center.Y)
			near(floor.Size.X, RoomGenerator.ROOM_SIZE)
			near(floor.Size.Z, RoomGenerator.ROOM_SIZE)
			for _, side in sides do
				local alongX = side == "N" or side == "S"
				local intervals = {}
				for _, wall in room:GetChildren() do
					if wall.Name == "Wall_" .. side then
						local offset = if alongX then wall.Position.X - center.X else wall.Position.Z - center.Z
						local width = if alongX then wall.Size.X else wall.Size.Z
						table.insert(intervals, { lower = offset - width / 2, upper = offset + width / 2 })
					end
				end
				if doors[side] then
					assert(#intervals == 2, "open side must keep both room corners")
					table.sort(intervals, function(a, b)
						return a.lower < b.lower
					end)
					local gap = intervals[2].lower - intervals[1].upper
					assert(gap >= 8, "door does not allow safe avatar clearance")
					near(gap, RoomGenerator.DOOR_WIDTH)
					assert(intervals[1].upper <= -4 and intervals[2].lower >= 4, "door is off center")
				else
					assert(#intervals == 1 and intervals[1].lower <= 0 and intervals[1].upper >= 0)
				end
			end
			room:Destroy()
		end
		parent:Destroy()
	end)

	test("scene: actual corridors meet both room floors without gaps in each cardinal direction", function()
		local parent = Instance.new("Folder")
		local start = Vector3.new(96, 10, -48)
		for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local destination = start + direction * RoomGenerator.GRID_SIZE
			local corridor = CorridorGenerator.build(start, destination, parent)
			assert(#solids(corridor) <= 8, "corridor static-part budget exceeded")
			local floor = assert(corridor:FindFirstChild("Floor"))
			near(floor.Position.Y + floor.Size.Y / 2, start.Y)
			local alongX = direction.X ~= 0
			local startAxis = if alongX then start.X else start.Z
			local endAxis = if alongX then destination.X else destination.Z
			local floorAxis = if alongX then floor.Position.X else floor.Position.Z
			local floorLength = if alongX then floor.Size.X else floor.Size.Z
			local width = if alongX then floor.Size.Z else floor.Size.X
			near(floorAxis - floorLength / 2, math.min(startAxis, endAxis) + RoomGenerator.ROOM_SIZE / 2)
			near(floorAxis + floorLength / 2, math.max(startAxis, endAxis) - RoomGenerator.ROOM_SIZE / 2)
			assert(width >= 8, "corridor too narrow for avatar navigation")
			near(width, RoomGenerator.DOOR_WIDTH)
			for _, wall in corridor:GetChildren() do
				if wall.Name == "Wall" then
					local wallOffset = if alongX
						then math.abs(wall.Position.Z - start.Z)
						else math.abs(wall.Position.X - start.X)
					local thickness = if alongX then wall.Size.Z else wall.Size.X
					near(wallOffset - thickness / 2, width / 2)
				end
			end
			corridor:Destroy()
		end
		parent:Destroy()
	end)

	test("scene: actual corridor builder rejects detached, diagonal and vertically mismatched endpoints", function()
		local parent = Instance.new("Folder")
		for _, endpoint in { Vector3.zero, Vector3.new(96, 0, 0), Vector3.new(24, 0, 24), Vector3.new(48, 1, 0) } do
			assert(not pcall(CorridorGenerator.build, Vector3.zero, endpoint, parent))
		end
		assert(#parent:GetChildren() == 0, "invalid input exposed partial corridor geometry")
		parent:Destroy()
	end)
end
