--!strict
local CorridorGenerator = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Anchored = true
	object.Size = size
	object.Position = position
	object.Color = color
	object.Material = Enum.Material.Slate
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

function CorridorGenerator.build(a: Vector3, b: Vector3, parent: Instance): Model
	local dx, dz = math.abs(a.X - b.X), math.abs(a.Z - b.Z)
	assert(((dx == 48 and dz == 0) or (dx == 0 and dz == 48)) and a.Y == b.Y, "corridor needs adjacent grid cells")
	local model = Instance.new("Model")
	model.Name = "Corridor"
	model.Parent = parent
	local center = (a + b) / 2
	local alongX = a.X ~= b.X
	part(
		model,
		"Floor",
		if alongX then Vector3.new(16, 2, 10) else Vector3.new(10, 2, 16),
		center - Vector3.new(0, 1, 0),
		Color3.fromRGB(30, 32, 39)
	)
	for _, sign in { -1, 1 } do
		local offset = if alongX then Vector3.new(0, 6, sign * 5.5) else Vector3.new(sign * 5.5, 6, 0)
		local wallSize = if alongX then Vector3.new(16, 12, 1) else Vector3.new(1, 12, 16)
		part(model, "Wall", wallSize, center + offset, Color3.fromRGB(20, 23, 28))
		local trim = if alongX then Vector3.new(16, 0.3, 1.05) else Vector3.new(1.05, 0.3, 16)
		part(model, "GoldTrim", trim, center + offset + Vector3.new(0, 5.5, 0), Color3.fromRGB(188, 145, 60))
	end
	return model
end

return CorridorGenerator
