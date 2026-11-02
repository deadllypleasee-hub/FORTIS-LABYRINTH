--!strict
-- The HUB is built entirely from Roblox primitives; no external models are needed.
-- Only the LABYRINTH portal is interactive in Stage 1.

local HubBuilder = {}

local STONE = Color3.fromRGB(24, 25, 30)
local STONE_LIGHT = Color3.fromRGB(43, 44, 49)
local GOLD = Color3.fromRGB(210, 165, 70)
local PALE_GOLD = Color3.fromRGB(255, 224, 155)
local INK = Color3.fromRGB(9, 11, 16)

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Material = material or Enum.Material.Slate
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The Back face points toward +Z, into the plaza and toward the spawn.
local function board(parent: Instance, name: string, text: string, position: Vector3, size: Vector3): Part
	local panel = block(parent, name, size, position, INK, Enum.Material.SmoothPlastic)
	panel.CanCollide = false
	panel.CastShadow = false
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Inscription"
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(1100, math.max(200, 1100 * size.Y / size.X))
	surface.LightInfluence = 0
	surface.Parent = panel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(0.94, 0.92)
	label.Position = UDim2.fromScale(0.03, 0.04)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = PALE_GOLD
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = surface
	return panel
end

local function brazier(parent: Instance, x: number, z: number)
	block(parent, "BrazierBase", Vector3.new(4, 1, 4), Vector3.new(x, 0.5, z), GOLD)
	block(parent, "BrazierPillar", Vector3.new(2.2, 5, 2.2), Vector3.new(x, 3.5, z), STONE_LIGHT)
	local flame =
		block(parent, "AmberFlame", Vector3.new(2.8, 1.4, 2.8), Vector3.new(x, 6.7, z), GOLD, Enum.Material.Neon)
	flame.CanCollide = false
	flame.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = PALE_GOLD
	light.Range = 24
	light.Brightness = 1.7
	light.Shadows = false
	light.Parent = flame
end

local function landmark(parent: Instance, x: number, title: string, stage: string)
	block(parent, "FutureLandmarkPlinth", Vector3.new(27, 1, 22), Vector3.new(x, 0.5, 5), STONE_LIGHT)
	for _, offset in { -11, 11 } do
		block(parent, "LandmarkPillar", Vector3.new(2.5, 17, 2.5), Vector3.new(x + offset, 9.5, 0), STONE)
		block(parent, "LandmarkCapital", Vector3.new(3.2, 0.6, 3.2), Vector3.new(x + offset, 18.3, 0), GOLD)
	end
	block(parent, "LandmarkLintel", Vector3.new(26, 2, 4), Vector3.new(x, 19, 0), STONE_LIGHT)
	board(parent, "FutureFeatureSign", title .. "\n" .. stage, Vector3.new(x, 11, 1.5), Vector3.new(23, 8, 0.4))
	board(parent, "FutureFeatureStatus", "В разработке", Vector3.new(x, 3.5, 13), Vector3.new(20, 2.5, 0.4))
end

function HubBuilder.build(parent: Instance): {
	model: Model,
	spawnCFrame: CFrame,
	portalPrompt: ProximityPrompt,
}
	local hub = Instance.new("Model")
	hub.Name = "FORTIS_HUB"
	hub.Parent = parent

	block(hub, "BlackStonePlaza", Vector3.new(184, 2, 184), Vector3.new(0, -1, 0), STONE)
	-- Gold perimeter is flush with the paving and cannot catch moving characters.
	for _, x in { -90, 90 } do
		block(hub, "GoldPlazaBorder", Vector3.new(0.8, 0.1, 180), Vector3.new(x, 0.02, 0), GOLD)
	end
	for _, z in { -90, 90 } do
		block(hub, "GoldPlazaBorder", Vector3.new(180, 0.1, 0.8), Vector3.new(0, 0.02, z), GOLD)
	end
	for _, x in { -93, 93 } do
		block(hub, "PlazaParapet", Vector3.new(2, 5, 188), Vector3.new(x, 2.5, 0), STONE_LIGHT)
	end
	for _, z in { -93, 93 } do
		block(hub, "PlazaParapet", Vector3.new(188, 5, 2), Vector3.new(0, 2.5, z), STONE_LIGHT)
	end
	for _, x in { -78, 78 } do
		for _, z in { -76, 40, 76 } do
			block(hub, "ObsidianPillar", Vector3.new(5, 23, 5), Vector3.new(x, 11.5, z), STONE_LIGHT)
			block(hub, "GoldCapital", Vector3.new(6, 0.8, 6), Vector3.new(x, 23.2, z), GOLD)
		end
	end

	-- A clear aisle to the portal; the legends monument sits beside this route.
	for z = -44, 40, 12 do
		block(hub, "ProcessionalPaving", Vector3.new(17, 0.12, 9), Vector3.new(0, 0.05, z), STONE_LIGHT)
		block(hub, "RouteInlay", Vector3.new(0.4, 0.15, 9), Vector3.new(-8, 0.06, z), GOLD)
		block(hub, "RouteInlay", Vector3.new(0.4, 0.15, 9), Vector3.new(8, 0.06, z), GOLD)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.2, 10)
	spawn.Position = Vector3.new(0, 0.15, 51)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	board(hub, "StudioSignature", "FORTIS GAMES", Vector3.new(0, 23, -87), Vector3.new(55, 5, 1))
	board(hub, "ExperienceTitle", "FORTIS: LABYRINTH", Vector3.new(0, 31, -66), Vector3.new(48, 5, 1))
	board(
		hub,
		"PortalInstructions",
		"ЗАБРОШЕННЫЕ КАТАКОМБЫ\nЭТАЖ 1 • ОДИНОЧНЫЙ ЗАБЕГ",
		Vector3.new(0, 26, -62),
		Vector3.new(36, 4, 1)
	)

	block(hub, "PortalDais", Vector3.new(34, 0.8, 20), Vector3.new(0, 0.4, -62), STONE_LIGHT)
	for _, x in { -13, 13 } do
		block(hub, "PortalColumn", Vector3.new(5, 23, 7), Vector3.new(x, 12, -65), STONE)
		block(hub, "PortalColumnInlay", Vector3.new(0.7, 22, 0.3), Vector3.new(x, 12, -61.4), GOLD)
		block(hub, "PortalFoot", Vector3.new(7, 1.2, 9), Vector3.new(x, 1.4, -65), GOLD)
	end
	block(hub, "PortalLintel", Vector3.new(31, 4, 7), Vector3.new(0, 23.5, -65), STONE_LIGHT)
	block(hub, "PortalGoldLintel", Vector3.new(31.5, 0.8, 7.5), Vector3.new(0, 25.8, -65), GOLD)
	local portal = block(
		hub,
		"LabyrinthGate",
		Vector3.new(20, 19, 0.8),
		Vector3.new(0, 11, -65),
		Color3.fromRGB(75, 55, 130),
		Enum.Material.Neon
	)
	portal.Transparency = 0.34
	portal.CanCollide = false
	portal.CastShadow = false
	-- The prompt is attached at torso height instead of the tall gate's center.
	local promptAttachment = Instance.new("Attachment")
	promptAttachment.Name = "PortalInteraction"
	promptAttachment.Position = Vector3.new(0, -6, 2)
	promptAttachment.Parent = portal
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BeginSoloRun"
	prompt.ActionText = "Начать забег"
	prompt.ObjectText = "LABYRINTH • SOLO"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.35
	prompt.Parent = promptAttachment

	for _, position in { Vector2.new(-23, -51), Vector2.new(23, -51), Vector2.new(-20, 45), Vector2.new(20, 45) } do
		brazier(hub, position.X, position.Y)
	end

	landmark(hub, -57, "МАГАЗИН", "ЭТАП 2")
	landmark(hub, 57, "VIP OVERLORD", "ЭТАП 3")
	block(hub, "LegendsPlinth", Vector3.new(18, 1.2, 16), Vector3.new(33, 0.6, 34), STONE_LIGHT)
	block(hub, "GoldenStele", Vector3.new(8, 17, 4), Vector3.new(33, 9.7, 33), GOLD, Enum.Material.Metal)
	block(hub, "SteleCrown", Vector3.new(10, 1.5, 6), Vector3.new(33, 18.8, 33), GOLD, Enum.Material.Metal)
	board(
		hub,
		"LegendsStageLabel",
		"FORTIS\nLEGENDS\n\nЭТАП 3",
		Vector3.new(33, 10.8, 35.2),
		Vector3.new(7, 13, 0.3)
	)
	board(
		hub,
		"HallStageLabel",
		"HALL OF LEGENDS\nЗАЛ СЛАВЫ • ЭТАП 3",
		Vector3.new(-43, 14, -49),
		Vector3.new(27, 6, 0.5)
	)
	board(
		hub,
		"HowToPlay",
		"ПРОТОТИП • ЭТАП 1\nПодойди к порталу или нажми «В лабиринт»\nАтака: F / кнопка на экране\nЗелье: Q / кнопка на экране\nВернуться: кнопка «В HUB»",
		Vector3.new(-33, 8, 36),
		Vector3.new(25, 12, 0.6)
	)

	return {
		model = hub,
		spawnCFrame = CFrame.new(0, 4, 51),
		portalPrompt = prompt,
	}
end

return HubBuilder
