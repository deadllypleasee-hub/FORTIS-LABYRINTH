--!strict
-- Rooms occupy one 32x32 stud cell, separated by 16 stud corridors.
-- center.Y is the WALKABLE floor surface, not the floor part's center.
local RoomGenerator = {}
RoomGenerator.ROOM_SIZE = 32
RoomGenerator.GRID_SIZE = 48
RoomGenerator.DOOR_WIDTH = 10

local STONE = Color3.fromRGB(24, 27, 33)
local GOLD = Color3.fromRGB(188, 145, 60)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Anchored = true
	object.Size = size
	object.Position = position
	object.Color = color
	object.Material = material
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local LABELS = {
	StartRoom = "КАТАКОМБЫ • НАЧАЛО",
	CombatRoom = "ЗАЛ СТРАЖА",
	TrapRoom = "ОСТОРОЖНО: ШИПЫ",
	TreasureRoom = "ЗАБЫТАЯ СОКРОВИЩНИЦА",
	ExitRoom = "ВЫХОД • FORTIS",
}

function RoomGenerator.build(room: any, center: Vector3, doors: { [string]: boolean }, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = string.format("Room_%02d_%s", room.id, room.kind)
	model:SetAttribute("RoomId", room.id)
	model:SetAttribute("RoomKind", room.kind)
	model.Parent = parent
	part(model, "Floor", Vector3.new(32, 2, 32), center - Vector3.new(0, 1, 0), STONE, Enum.Material.Slate)
	-- A gold inlay marks each center without blocking movement or adding lights.
	local inlay =
		part(model, "Inlay", Vector3.new(5, 0.06, 5), center + Vector3.new(0, 0.03, 0), GOLD, Enum.Material.Metal)
	inlay.CanCollide = false
	inlay.CanTouch = false
	inlay.CanQuery = false
	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local sign = if side == "N" or side == "W" then -1 else 1
		local function wall(length: number, offset: number)
			local size = if alongX then Vector3.new(length, 12, 1) else Vector3.new(1, 12, length)
			local position = if alongX then Vector3.new(offset, 6, sign * 16) else Vector3.new(sign * 16, 6, offset)
			part(model, "Wall_" .. side, size, center + position, STONE, Enum.Material.Basalt)
			local trimSize = if alongX then Vector3.new(length, 0.3, 1.1) else Vector3.new(1.1, 0.3, length)
			part(model, "GoldTrim", trimSize, center + position + Vector3.new(0, 5.5, 0), GOLD, Enum.Material.Metal)
		end
		if doors[side] then
			wall(11, -10.5)
			wall(11, 10.5)
		else
			wall(32, 0)
		end
	end
	local lightAnchor =
		part(model, "Lantern", Vector3.new(0.7, 0.7, 0.7), center + Vector3.new(11, 8, 11), GOLD, Enum.Material.Neon)
	lightAnchor.CanCollide = false
	lightAnchor.CanTouch = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 194, 105)
	light.Brightness = 1.5
	light.Range = 28
	light.Shadows = false
	light.Parent = lightAnchor
	if LABELS[room.kind] then
		local anchor = part(
			model,
			"RoomMarker",
			Vector3.new(1, 1, 1),
			center + Vector3.new(0, 9, 0),
			GOLD,
			Enum.Material.SmoothPlastic
		)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		local gui = Instance.new("BillboardGui")
		gui.Name = "RoomLabel"
		gui.Size = UDim2.fromOffset(250, 42)
		gui.MaxDistance = 60
		gui.AlwaysOnTop = false
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = LABELS[room.kind]
		label.TextColor3 = GOLD
		label.TextStrokeTransparency = 0.25
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.Parent = gui
	end
	return model
end

return RoomGenerator
