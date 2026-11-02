--!strict
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.CombatRules)

local EnemyService = {}
EnemyService.__index = EnemyService

local function part(name, size, color, parent)
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.Color = color
	result.Material = Enum.Material.Slate
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.CanCollide = false
	result.Parent = parent
	return result
end

local function motor(name, parent, limb, offset)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = parent
	joint.Part1 = limb
	joint.C0 = CFrame.new(offset)
	joint.Parent = parent
	limb.CFrame = parent.CFrame * joint.C0
end

local function makeSkeleton(position: Vector3, parent: Instance): (Model, Humanoid, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "CatacombSkeleton"
	local bone = Color3.fromRGB(177, 172, 143)
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), bone, model)
	root.Transparency = 1
	-- FloorBuilder supplies the humanoid root centre, three studs above floor.
	root.CFrame = CFrame.new(position)
	local torso = part("Torso", Vector3.new(1.8, 2, 0.8), Color3.fromRGB(61, 57, 49), model)
	torso.CanCollide = true
	motor("RootJoint", root, torso, Vector3.zero)
	local head = part("Head", Vector3.new(1.6, 1, 1), bone, model)
	head.CanCollide = true
	motor("Neck", torso, head, Vector3.new(0, 1.5, 0))
	for _, side in { -1, 1 } do
		local prefix = if side == -1 then "Left" else "Right"
		local arm = part(prefix .. " Arm", Vector3.new(0.6, 2, 0.6), bone, model)
		motor(prefix .. " Shoulder", torso, arm, Vector3.new(side * 1.2, 0, 0))
		local leg = part(prefix .. " Leg", Vector3.new(0.65, 2, 0.65), bone, model)
		motor(prefix .. " Hip", torso, leg, Vector3.new(side * 0.5, -2, 0))
		local eye = part("Eye", Vector3.new(0.24, 0.24, 0.1), Color3.fromRGB(255, 61, 36), model)
		eye.Material = Enum.Material.Neon
		motor("EyeWeld", head, eye, Vector3.new(side * 0.38, 0.08, -0.52))
	end
	for index = 1, 3 do
		local rib = part("Rib", Vector3.new(1.85, 0.12, 0.2), bone, model)
		motor("RibWeld", torso, rib, Vector3.new(0, 0.65 - index * 0.4, -0.5))
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 84
	humanoid.Health = 84
	humanoid.WalkSpeed = 11
	humanoid.JumpPower = 30
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root
	local board = Instance.new("BillboardGui")
	board.Name = "HealthBar"
	board.Size = UDim2.fromOffset(150, 38)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	board.MaxDistance = 65
	board.Adornee = head
	board.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(22, 19, 16)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(230, 204, 128)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Text = "СКЕЛЕТ · 84"
	label.Parent = board
	model.Parent = parent
	-- The root owns the assembly; clients never simulate or award enemy damage.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root, label
end

function EnemyService.new(options)
	return setmetatable({
		isActive = options.isActive,
		onKilled = options.onKilled,
		entries = {},
		running = true,
	}, EnemyService)
end

function EnemyService:_state(entry, value: string)
	if entry.state ~= value then
		entry.state = value
		entry.model:SetAttribute("EnemyState", value)
	end
end

function EnemyService:_visible(entry, character: Model, target: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entry.model }
	params.IgnoreWater = true
	local hit = workspace:Raycast(entry.root.Position, target.Position - entry.root.Position, params)
	return hit == nil or hit.Instance:IsDescendantOf(character)
end

function EnemyService:_target(entry)
	local closest = nil
	local distance = 48
	for _, player in Players:GetPlayers() do
		if self.isActive(player) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local candidateDistance = (root.Position - entry.root.Position).Magnitude
				if candidateDistance < distance and self:_visible(entry, character, root) then
					closest = { player = player, character = character, humanoid = humanoid, root = root }
					distance = candidateDistance
				end
			end
		end
	end
	return closest
end

function EnemyService:_move(entry, destination: Vector3, now: number)
	if (entry.root.Position - destination).Magnitude < 2.5 then
		entry.humanoid:MoveTo(destination)
		return
	end
	if now >= entry.nextPath then
		entry.nextPath = now + 1.4
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(entry.root.Position, destination)
		end)
		if not self.running or entry.dead or not entry.model.Parent then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			entry.waypoints = path:GetWaypoints()
			entry.waypointIndex = 2
		else
			entry.waypoints = {}
		end
	end
	local waypoint = entry.waypoints[entry.waypointIndex]
	if waypoint then
		if (entry.root.Position - waypoint.Position).Magnitude < 3 then
			entry.waypointIndex += 1
			waypoint = entry.waypoints[entry.waypointIndex]
		end
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				entry.humanoid.Jump = true
			end
			entry.humanoid:MoveTo(waypoint.Position)
			return
		end
	end
	entry.humanoid:MoveTo(destination)
end

function EnemyService:_step(entry)
	local now = os.clock()
	if entry.humanoid.Health <= 0 or not entry.root.Parent then
		return
	end
	local target = self:_target(entry)
	if target then
		entry.target = target
		entry.lastSeen = now
	elseif entry.target and now - entry.lastSeen < 4 then
		local remembered = entry.target
		if
			remembered.player.Parent == Players
			and self.isActive(remembered.player)
			and remembered.player.Character == remembered.character
			and remembered.root.Parent
			and remembered.humanoid.Health > 0
			and (remembered.root.Position - entry.root.Position).Magnitude < 70
		then
			target = remembered
		end
	end
	local fromHome = (entry.root.Position - entry.home).Magnitude
	if target and fromHome < 95 then
		if entry.state == "Patrol" or entry.state == "Return" then
			self:_state(entry, "Detect")
			entry.detectUntil = now + 0.35
			entry.humanoid:MoveTo(entry.root.Position)
			return
		end
		if now < entry.detectUntil then
			return
		end
		local distance = (target.root.Position - entry.root.Position).Magnitude
		if Rules.withinRange(distance, Rules.EnemyRange) and self:_visible(entry, target.character, target.root) then
			self:_state(entry, "Attack")
			entry.humanoid:MoveTo(entry.root.Position)
			if Rules.cooldownReady(now, entry.lastAttack, Rules.EnemyCooldown) then
				entry.lastAttack = now
				-- Both distance and visibility were evaluated on the server this tick.
				target.humanoid:TakeDamage(Rules.EnemyDamage)
			end
		else
			self:_state(entry, "Chase")
			self:_move(entry, target.root.Position, now)
		end
	elseif fromHome > 5 then
		self:_state(entry, "Return")
		self:_move(entry, entry.home, now)
	else
		self:_state(entry, "Patrol")
		if now >= entry.nextPatrol then
			entry.nextPatrol = now + 4
			entry.patrolSide *= -1
			entry.humanoid:MoveTo(entry.home + Vector3.new(entry.patrolSide * 4, 0, 3))
		end
	end
end

function EnemyService:_death(entry)
	if entry.dead then
		return
	end
	entry.dead = true
	self:_state(entry, "Dead")
	local attacker = entry.lastAttacker
	if
		self.running
		and attacker
		and attacker.Parent == Players
		and os.clock() - entry.lastHit <= 12
		and self.isActive(attacker)
	then
		local ok, err = pcall(self.onKilled, attacker, entry.id)
		if not ok then
			warn("FORTIS enemy reward callback failed:", err)
		end
	end
	task.delay(2, function()
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		self.entries[entry.model] = nil
		entry.model:Destroy()
	end)
end

function EnemyService:spawn(position: Vector3, parent: Instance): Model
	assert(self.running, "EnemyService is destroyed")
	local model, humanoid, root, label = makeSkeleton(position, parent)
	local id = HttpService:GenerateGUID(false)
	model:SetAttribute("EnemyId", id)
	local entry = {
		model = model,
		humanoid = humanoid,
		root = root,
		home = root.Position,
		id = id,
		dead = false,
		state = "",
		nextPath = 0,
		waypoints = {},
		waypointIndex = 1,
		detectUntil = 0,
		nextPatrol = 0,
		patrolSide = 1,
		lastSeen = 0,
		connections = {},
	}
	self.entries[model] = entry
	self:_state(entry, "Patrol")
	table.insert(
		entry.connections,
		humanoid.HealthChanged:Connect(function(health)
			label.Text = "СКЕЛЕТ · " .. tostring(math.max(0, math.ceil(health)))
		end)
	)
	table.insert(
		entry.connections,
		humanoid.Died:Connect(function()
			self:_death(entry)
		end)
	)
	task.spawn(function()
		while self.running and not entry.dead and model.Parent do
			local ok, err = pcall(self._step, self, entry)
			if not ok then
				warn("FORTIS enemy update failed:", err)
			end
			task.wait(0.2)
		end
	end)
	return model
end

function EnemyService:getEnemies(): { Model }
	local result = {}
	for model, entry in self.entries do
		if not entry.dead and model.Parent and entry.humanoid.Health > 0 then
			table.insert(result, model)
		end
	end
	return result
end

function EnemyService:damage(model: Model, player: Player, amount: number): boolean
	local entry = self.entries[model]
	if
		not self.running
		or not entry
		or entry.dead
		or entry.humanoid.Health <= 0
		or not self.isActive(player)
		or not Rules.isFinite(amount)
		or amount <= 0
	then
		return false
	end
	entry.lastAttacker = player
	entry.lastHit = os.clock()
	entry.humanoid:TakeDamage(math.min(amount, Rules.SwordDamage))
	-- Deferred signal mode may deliver Humanoid.Died after a remote exit request.
	-- Settle the server kill immediately; the Died listener shares the same guard.
	if entry.humanoid.Health <= 0 then
		self:_death(entry)
	end
	return true
end

function EnemyService:destroy()
	self.running = false
	for model, entry in self.entries do
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		model:Destroy()
	end
	table.clear(self.entries)
end

return EnemyService
