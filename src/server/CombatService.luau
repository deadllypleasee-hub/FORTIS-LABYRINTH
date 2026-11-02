--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CombatRules = require(ReplicatedStorage.Shared.CombatRules)

local CombatService = {}
CombatService.__index = CombatService

function CombatService.new(options)
	return setmetatable({
		enemyService = options.enemyService,
		isActive = options.isActive,
		notify = options.notify or function() end,
		lastAttacks = {},
		swings = {},
		running = true,
	}, CombatService)
end

function CombatService:_finishSwing(tool: Tool, swing)
	if self.swings[tool] ~= swing then
		return
	end
	self.swings[tool] = nil
	for _, connection in swing.connections do
		connection:Disconnect()
	end
	for _, tween in swing.tweens do
		tween:Cancel()
	end
	if tool.Parent then
		tool.Grip = swing.baseGrip
	end
end

function CombatService:_swing(player: Player, character: Model)
	local tool = character:FindFirstChild("Меч катакомб")
	if not tool or not tool:IsA("Tool") then
		return
	end
	local previous = self.swings[tool]
	if previous then
		self:_finishSwing(tool, previous)
	end
	local swing = { player = player, baseGrip = tool.Grip, tweens = {}, connections = {} }
	self.swings[tool] = swing
	local strike = TweenService:Create(
		tool,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Grip = swing.baseGrip * CFrame.Angles(0, 0, math.rad(-80)) }
	)
	table.insert(swing.tweens, strike)
	table.insert(
		swing.connections,
		tool.AncestryChanged:Connect(function()
			if tool.Parent ~= character then
				self:_finishSwing(tool, swing)
			end
		end)
	)
	table.insert(
		swing.connections,
		strike.Completed:Connect(function(playbackState)
			if self.swings[tool] ~= swing then
				return
			end
			if not self.running or tool.Parent ~= character or playbackState ~= Enum.PlaybackState.Completed then
				self:_finishSwing(tool, swing)
				return
			end
			local recovery = TweenService:Create(
				tool,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Grip = swing.baseGrip }
			)
			table.insert(swing.tweens, recovery)
			table.insert(
				swing.connections,
				recovery.Completed:Connect(function()
					self:_finishSwing(tool, swing)
				end)
			)
			recovery:Play()
		end)
	)
	strike:Play()
end

function CombatService:attack(player: Player): boolean
	if not self.running or not self.isActive(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	local now = os.clock()
	if not CombatRules.cooldownReady(now, self.lastAttacks[player], CombatRules.SwordCooldown) then
		return false
	end
	-- Empty swings also consume the cooldown; payloads cannot bypass this clock.
	self.lastAttacks[player] = now
	self:_swing(player, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local nearest = nil
	local nearestDistance = CombatRules.SwordRange + 1
	for _, enemy in self.enemyService:getEnemies() do
		local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
		local enemyHumanoid = enemy:FindFirstChildOfClass("Humanoid")
		if enemyRoot and enemyRoot:IsA("BasePart") and enemyHumanoid and enemyHumanoid.Health > 0 then
			local direction = enemyRoot.Position - root.Position
			local distance = direction.Magnitude
			local dot = if distance < 0.01 then 1 else root.CFrame.LookVector:Dot(direction.Unit)
			if
				CombatRules.withinRange(distance, CombatRules.SwordRange)
				and CombatRules.isInFront(dot)
				and distance < nearestDistance
			then
				local hit = workspace:Raycast(root.Position, direction, params)
				if not hit or hit.Instance:IsDescendantOf(enemy) then
					nearest = enemy
					nearestDistance = distance
				end
			end
		end
	end
	if nearest then
		local applied = self.enemyService:damage(nearest, player, CombatRules.damage(CombatRules.SwordDamage, 0))
		local remaining = nearest:FindFirstChildOfClass("Humanoid")
		if applied and remaining and remaining.Health > 0 then
			-- Let the kill reward message remain visible on the lethal strike.
			self.notify(player, "Удар: " .. tostring(CombatRules.SwordDamage))
		end
		return applied
	end
	return false
end

function CombatService:forget(player: Player)
	self.lastAttacks[player] = nil
	for tool, swing in self.swings do
		if swing.player == player then
			self:_finishSwing(tool, swing)
		end
	end
end

function CombatService:destroy()
	self.running = false
	for tool, swing in self.swings do
		self:_finishSwing(tool, swing)
	end
	table.clear(self.lastAttacks)
end

return CombatService
