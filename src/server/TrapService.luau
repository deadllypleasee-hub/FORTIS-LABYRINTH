--!strict
-- cframe is the centre of the room floor's top surface. The 8-stud trap
-- deliberately leaves a wide safe lane around it in a 32-stud room.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TrapService = {}
TrapService.__index = TrapService

local SAFE_COLOR = Color3.fromRGB(66, 73, 76)
local WARN_COLOR = Color3.fromRGB(255, 174, 39)
local ACTIVE_COLOR = Color3.fromRGB(225, 52, 42)
local DAMAGE = 20

type Options = {
	isActive: (Player) -> boolean,
}

local function part(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.Material = Enum.Material.Metal
	result.Parent = parent
	return result
end

function TrapService.new(options: Options)
	return setmetatable({
		_isActive = options.isActive,
		_running = true,
		_traps = {} :: { Model },
	}, TrapService)
end

function TrapService:_wait(model: Model, duration: number): boolean
	local deadline = os.clock() + duration
	while self._running and model.Parent and os.clock() < deadline do
		task.wait(math.min(0.1, math.max(0, deadline - os.clock())))
	end
	return self._running and model.Parent ~= nil
end

function TrapService:_damage(cframe: CFrame, victims: { [Player]: boolean })
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if self._isActive(player) and player.Character then
			table.insert(characters, player.Character)
		end
	end
	if #characters == 0 then
		return
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = characters
	local hits = Workspace:GetPartBoundsInBox(cframe * CFrame.new(0, 2.5, 0), Vector3.new(8, 5, 8), overlap)
	for _, hit in hits do
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or victims[player] or not self._isActive(player) then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local relative = cframe:PointToObjectSpace(root.Position)
			-- Limbs and accessories outside the pad cannot create a damage hit.
			-- Jumping above the spikes or walking around them is always possible.
			if math.abs(relative.X) <= 4 and math.abs(relative.Z) <= 4 and relative.Y >= -0.5 and relative.Y <= 4 then
				victims[player] = true
				humanoid:TakeDamage(DAMAGE)
			end
		end
	end
end

function TrapService:spawn(cframe: CFrame, parent: Instance): Model
	assert(self._running, "TrapService has been destroyed")
	local model = Instance.new("Model")
	model.Name = "TelegraphedSpikes"
	model:SetAttribute("State", "Safe")
	model.Parent = parent
	table.insert(self._traps, model)
	local plate = part("WarningPlate", Vector3.new(8, 0.12, 8), cframe * CFrame.new(0, 0.07, 0), model)
	plate.Color = SAFE_COLOR
	local border = part("GoldRim", Vector3.new(8.4, 0.08, 8.4), cframe * CFrame.new(0, 0.02, 0), model)
	border.Color = Color3.fromRGB(171, 133, 56)
	local spikes: { WedgePart } = {}
	for x = -1, 1 do
		for z = -1, 1 do
			local spike = Instance.new("WedgePart")
			spike.Name = "Spike"
			spike.Size = Vector3.new(0.8, 2.6, 0.8)
			spike.CFrame = cframe * CFrame.new(x * 2.4, -1.4, z * 2.4)
			spike.Anchored = true
			spike.CanCollide = false
			spike.CanTouch = false
			spike.CanQuery = false
			spike.CastShadow = false
			spike.Material = Enum.Material.Metal
			spike.Color = Color3.fromRGB(201, 202, 191)
			spike.Transparency = 1
			spike.Parent = model
			table.insert(spikes, spike)
		end
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "TrapWarning"
	sign.Size = UDim2.fromOffset(210, 44)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	sign.MaxDistance = 45
	sign.Adornee = plate
	sign.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "ШИПЫ · ОБХОД СБОКУ"
	label.TextColor3 = Color3.fromRGB(225, 208, 165)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = sign
	task.spawn(function()
		while self._running and model.Parent do
			model:SetAttribute("State", "Safe")
			plate.Color = SAFE_COLOR
			plate.Material = Enum.Material.Metal
			label.Text = "ШИПЫ · ОБХОД СБОКУ"
			label.TextColor3 = Color3.fromRGB(225, 208, 165)
			if not self:_wait(model, 2.5) then
				break
			end
			model:SetAttribute("State", "Warning")
			label.Text = "ОСТОРОЖНО! ШИПЫ"
			label.TextColor3 = WARN_COLOR
			for _ = 1, 3 do
				plate.Material = Enum.Material.Neon
				plate.Color = WARN_COLOR
				if not self:_wait(model, 0.2) then
					return
				end
				plate.Color = SAFE_COLOR
				if not self:_wait(model, 0.2) then
					return
				end
			end
			model:SetAttribute("State", "Active")
			plate.Color = ACTIVE_COLOR
			label.TextColor3 = ACTIVE_COLOR
			for index, spike in spikes do
				local column = (index - 1) % 3 - 1
				local row = math.floor((index - 1) / 3) - 1
				spike.CFrame = cframe * CFrame.new(row * 2.4, 1.4, column * 2.4)
				spike.Transparency = 0
			end
			local victims: { [Player]: boolean } = {}
			for _ = 1, 8 do
				if not self._running or not model.Parent then
					return
				end
				self:_damage(cframe, victims)
				if not self:_wait(model, 0.1) then
					return
				end
			end
			for _, spike in spikes do
				spike.Transparency = 1
			end
		end
	end)
	return model
end

function TrapService:destroy()
	self._running = false
	for _, model in self._traps do
		model:Destroy()
	end
	table.clear(self._traps)
end

return TrapService
