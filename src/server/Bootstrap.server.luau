--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local RobloxTeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileRules = require(ReplicatedStorage.Shared.ProfileRules)
local RunRules = require(ReplicatedStorage.Shared.RunRules)
local FloorGenerator = require(ReplicatedStorage.Shared.generation.FloorGenerator)
local FloorBuilder = require(ServerScriptService.Dungeon.FloorBuilder)
local HubBuilder = require(ServerScriptService.Hub.HubBuilder)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)
local TrapService = require(script.Parent.TrapService)
local ProfileService = require(script.Parent.ProfileService)
local RateLimiter = require(script.Parent.RateLimiter)
local Teleports = require(script.Parent.TeleportService)

local kind = ReplicatedStorage:WaitForChild("PlaceKind").Value
local preview = RunService:IsStudio() or kind == "Preview"
local isDungeon = kind == "Dungeon"
local profiles = ProfileService.new()
local limiter = RateLimiter.new()
local sessions = {}
local usedSlots = {}
local joining = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local action = remote("Action")
local state = remote("State")
local notification = remote("Notify")
remotes.Parent = ReplicatedStorage

local world = Instance.new("Folder")
world.Name = "FORTIS"
world.Parent = workspace
workspace.FallenPartsDestroyHeight = -100
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 68, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(45, 44, 55)
Lighting.FogColor = Color3.fromRGB(22, 21, 31)
Lighting.FogStart = 100
Lighting.FogEnd = 260
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.24
atmosphere.Color = Color3.fromRGB(133, 126, 119)
atmosphere.Parent = Lighting

local hub = if not isDungeon or preview then HubBuilder.build(world) else nil
local lobbyCFrame = if hub then hub.spawnCFrame else CFrame.new(0, 4, 0)
if not hub then
	-- Safe landing while the authenticated player's floor is being assembled.
	local lobby = Instance.new("SpawnLocation")
	lobby.Name = "DungeonArrival"
	lobby.Size = Vector3.new(24, 1, 24)
	lobby.Anchored = true
	lobby.Neutral = true
	lobby.Duration = 0
	lobby.Color = Color3.fromRGB(28, 26, 32)
	lobby.Position = Vector3.zero
	lobby.Parent = world
end

local function notify(player, message)
	if player.Parent == Players then
		notification:FireClient(player, message)
	end
end

local function sendState(player)
	local session = sessions[player]
	local data = profiles:get(player)
	if not session or not data or player.Parent ~= Players then
		return
	end
	local run = session.run
	local objective = "Войдите в портал или нажмите «В лабиринт»."
	if session.status == "Loading" then
		objective = "Подготовка забега…"
	elseif session.status == "Active" then
		objective = if #run.enemies:getEnemies() > 0
			then "Найдите скелета и победите его. Шипы можно обойти."
			else "Страж побеждён. Найдите золотой выход на карте."
	elseif session.status == "Complete" then
		objective = "Этаж 1 пройден! Вернитесь в HUB для нового забега."
	elseif session.status == "Defeated" then
		objective = "Забег окончен. Вернитесь в HUB и попробуйте снова."
	end
	state:FireClient(player, {
		place = if run then "Dungeon" else "Hub",
		floor = if run then 1 else 0,
		coins = data.coins,
		kills = data.kills,
		potions = data.potions,
		runStatus = session.status,
		objective = objective,
		profileMode = profiles:mode(),
		seed = if run then run.seed else nil,
		map = if run then { rooms = run.layout.rooms, edges = run.layout.edges } else nil,
	})
end

local function active(player, expectedRun)
	local session = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return session ~= nil
		and session.run == expectedRun
		and character == expectedRun.character
		and profiles:isAvailable(player)
		and humanoid ~= nil
		and RunRules.canAct(session.status, humanoid.Health)
end

local function moveCharacter(player, cframe)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(cframe)
		local root = character.HumanoidRootPart
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function closeRun(session)
	local run = session.run
	if not run then
		return
	end
	session.run = nil
	for _, connection in run.connections do
		connection:Disconnect()
	end
	if run.combat then
		run.combat:destroy()
	end
	if run.enemies then
		run.enemies:destroy()
	end
	if run.traps then
		run.traps:destroy()
	end
	run.geometry.model:Destroy()
end

local function removeSword(player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			local sword = container:FindFirstChild("Меч катакомб")
			if sword then
				sword:Destroy()
			end
		end
	end
end

local function equipSword(player, run)
	removeSword(player)
	local tool = Instance.new("Tool")
	tool.Name = "Меч катакомб"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 1.2, 0.35)
	handle.Color = Color3.fromRGB(95, 62, 30)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.65, 3, 0.2)
	blade.Material = Enum.Material.Metal
	blade.Color = Color3.fromRGB(205, 188, 119)
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, 2, 0)
	blade.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade
	tool.Grip = CFrame.Angles(math.rad(90), 0, 0)
	tool.Parent = player.Character
	table.insert(
		run.connections,
		tool.Activated:Connect(function()
			if active(player, run) then
				run.combat:attack(player)
			end
		end)
	)
end

local function near(player, position, distance)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

local function makePrompt(name, cframe, parent, label, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(5, 3, 3)
	part.CFrame = cframe
	part.Anchored = true
	part.Material = Enum.Material.Metal
	part.Color = color
	part.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = label
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.35
	prompt.RequiresLineOfSight = true
	prompt.Parent = part
	return part, prompt
end

local function buildRun(player, seed, runId)
	local session = sessions[player]
	if not session then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	assert(character and humanoid and humanoid.Health > 0, "A living character is required to enter a floor")
	session.status = "Loading"
	closeRun(session)
	local layout = FloorGenerator.generate(seed, 1)
	-- Generous spacing keeps separate Studio SOLO runs physically apart.
	local origin = Vector3.new(2048 + session.slot * 1600, 0, 0)
	local geometry = FloorBuilder.build(layout, world, origin)
	local run = {
		id = runId or HttpService:GenerateGUID(false),
		seed = seed,
		layout = layout,
		geometry = geometry,
		connections = {},
		chests = {},
		character = character,
		ready = false,
	}
	session.run = run
	local function isActive(candidate)
		return candidate == player and active(player, run)
	end
	run.enemies = EnemyService.new({
		isActive = isActive,
		onKilled = function(killer, enemyId)
			if not isActive(killer) then
				return
			end
			local profile = profiles:get(killer)
			if ProfileRules.reward(profile, run.id .. ":" .. enemyId, Config.KillReward) then
				profile.kills += 1
				notify(killer, "+" .. Config.KillReward .. " монет · скелет повержен")
				sendState(killer)
			end
		end,
	})
	run.combat = CombatService.new({ enemyService = run.enemies, isActive = isActive, notify = notify })
	run.traps = TrapService.new({ isActive = isActive })
	for _, position in geometry.enemySpawns do
		run.enemies:spawn(position, geometry.model)
	end
	for _, cframe in geometry.trapSpawns do
		run.traps:spawn(cframe, geometry.model)
	end
	for index, cframe in geometry.chestSpawns do
		local chest, prompt =
			makePrompt("Сундук", cframe, geometry.model, "Открыть", Color3.fromRGB(161, 115, 40))
		table.insert(
			run.connections,
			prompt.Triggered:Connect(function(candidate)
				if not isActive(candidate) or run.chests[index] or not near(candidate, chest.Position, 12) then
					return
				end
				run.chests[index] = true
				prompt.Enabled = false
				if ProfileRules.reward(profiles:get(candidate), run.id .. ":chest:" .. index, Config.ChestReward) then
					chest.Color = Color3.fromRGB(70, 63, 49)
					notify(candidate, "Сундук: +" .. Config.ChestReward .. " монет")
					sendState(candidate)
				end
			end)
		)
	end
	local gate, prompt = makePrompt(
		"Выход · этаж 1",
		geometry.exitCFrame,
		geometry.model,
		"Завершить этаж",
		Color3.fromRGB(220, 175, 64)
	)
	gate.Material = Enum.Material.Neon
	gate.CanCollide = false
	table.insert(
		run.connections,
		prompt.Triggered:Connect(function(candidate)
			if not isActive(candidate) or not near(candidate, gate.Position, 12) then
				return
			end
			if not RunRules.canComplete(session.status, #run.enemies:getEnemies(), 0) then
				notify(candidate, "Сначала победите стража этого этажа.")
				return
			end
			session.status = "Complete" -- close reward gate before any yielding work
			prompt.Enabled = false
			run.traps:destroy()
			local profile = profiles:get(candidate)
			if ProfileRules.reward(profile, run.id .. ":floor:1", Config.FloorReward) then
				profile.bestFloor = math.max(profile.bestFloor, 1)
				profile.completedFloors += 1
			end
			removeSword(candidate)
			notify(candidate, "FORTIS · Этаж пройден! +" .. Config.FloorReward .. " монет")
			sendState(candidate)
			task.spawn(function()
				profiles:save(candidate, false)
			end)
		end)
	)
	pcall(function()
		player:RequestStreamAroundAsync(geometry.spawnCFrame.Position, 5)
	end)
	if player.Parent ~= Players or sessions[player] ~= session or session.run ~= run then
		return
	end
	if session.status ~= "Loading" or player.Character ~= character or humanoid.Health <= 0 then
		session.status = "Defeated"
		notify(
			player,
			"Подготовка прервана. Вернитесь в HUB для нового забега."
		)
		sendState(player)
		return
	end
	run.ready = true
	session.status = "Active"
	moveCharacter(player, geometry.spawnCFrame)
	local forceField = player.Character and player.Character:FindFirstChildOfClass("ForceField")
	if forceField then
		forceField:Destroy()
	end
	humanoid.Health = humanoid.MaxHealth
	equipSword(player, run)
	sendState(player)
	notify(player, "Этаж 1 · Заброшенные катакомбы")
end

local function recoverTeleport(player)
	local session = sessions[player]
	if not session or session.status ~= "Loading" then
		return
	end
	if not profiles:get(player) then
		if not profiles:load(player) then
			player:Kick(
				"Не удалось безопасно загрузить профиль. Перезайдите позже."
			)
			return
		end
	end
	if sessions[player] ~= session then
		return
	end
	session.status = if session.run then "Defeated" else "Hub"
	notify(player, "Переход не выполнен. Можно повторить.")
	sendState(player)
end

local function startRun(player, payload)
	local session = sessions[player]
	if not session or not RunRules.canStart(session.status) or not profiles:isAvailable(player) then
		return
	end
	if payload and payload.mode ~= nil and payload.mode ~= "SOLO" then
		notify(player, "В этапе 1 доступен SOLO. CO-OP и HARDCORE — этап 2.")
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	session.status = "Loading"
	sendState(player)
	local seed = Random.new():NextInteger(1, 2147483646)
	if preview then
		local ok, err = pcall(buildRun, player, seed)
		if not ok then
			warn("[FORTIS] Floor creation failed:", err)
			moveCharacter(player, lobbyCFrame)
			closeRun(session)
			session.status = "Hub"
			notify(player, "Ошибка создания этажа. Повторите попытку.")
			sendState(player)
		end
	else
		if not profiles:save(player, true) then
			session.status = "Hub"
			notify(player, "Профиль пока не сохранён. Переход отменён.")
			sendState(player)
			return
		end
		local ok, message = Teleports.toDungeon(player, seed)
		if not ok then
			recoverTeleport(player)
			notify(player, message)
		end
	end
end

local function returnHub(player)
	local session = sessions[player]
	if not session or session.status == "Loading" or session.status == "Hub" then
		return
	end
	session.status = "Loading"
	removeSword(player)
	if preview then
		closeRun(session)
		session.status = "Hub"
		moveCharacter(player, hub.spawnCFrame)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		sendState(player)
	else
		sendState(player)
		if not profiles:save(player, true) then
			session.status = "Defeated"
			notify(
				player,
				"Не удалось сохранить профиль. Попробуйте вернуться позже."
			)
			sendState(player)
			return
		end
		if not Teleports.toHub(player) then
			recoverTeleport(player)
		end
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or player.Character ~= character then
		return
	end
	humanoid.Died:Once(function()
		local session = sessions[player]
		local run = session and session.run
		if
			run
			and run.character == character
			and (session.status == "Active" or (session.status == "Loading" and not run.ready))
		then
			session.status = "Defeated"
			local profile = profiles:get(player)
			if profile then
				profile.deaths += 1
			end
			notify(player, "Вы погибли. Нажмите «В HUB», чтобы начать снова.")
			sendState(player)
		end
	end)
	local session = sessions[player]
	if session then
		moveCharacter(player, if session.run then session.run.geometry.spawnCFrame else lobbyCFrame)
	end
end

local function onPlayer(player)
	if joining[player] or sessions[player] then
		return
	end
	joining[player] = true
	local admission = nil
	if isDungeon and not preview then
		admission = Teleports.admit(player)
		if not admission then
			player:Kick("Вход в лабиринт доступен через портал HUB.")
			return
		end
	end
	local profile = profiles:load(player)
	if not profile then
		player:Kick(
			"Не удалось безопасно загрузить профиль. Перезайдите позже."
		)
		return
	end
	if player.Parent ~= Players then
		profiles:save(player, true)
		return
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local session = { status = "Hub", slot = slot, run = nil }
	sessions[player] = session
	joining[player] = nil
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if admission then
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		if sessions[player] == session then
			local ok, err = pcall(buildRun, player, admission.seed, admission.id)
			if not ok then
				warn("[FORTIS] Dungeon initialization failed:", err)
				player:Kick("Не удалось создать этаж. Вернитесь в HUB.")
			end
		end
	elseif preview and isDungeon then
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 10)
		startRun(player, nil)
	end
	sendState(player)
end

local rates = {
	Attack = { 6, 4 },
	UsePotion = { 1, 0.5 },
	StartRun = { 1, 0.2 },
	ReturnHub = { 1, 0.2 },
	RequestState = { 3, 1 },
}
action.OnServerEvent:Connect(function(player, name, payload)
	if type(name) ~= "string" or not rates[name] then
		return
	end
	if payload ~= nil and type(payload) ~= "table" then
		return
	end
	local rate = rates[name]
	if not limiter:allow(player.UserId .. ":" .. name, rate[1], rate[2]) then
		return
	end
	local session = sessions[player]
	if name == "RequestState" then
		sendState(player)
	elseif name == "StartRun" then
		startRun(player, payload)
	elseif name == "ReturnHub" then
		returnHub(player)
	elseif session and session.run and active(player, session.run) then
		if name == "Attack" then
			session.run.combat:attack(player)
		elseif name == "UsePotion" then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local data = profiles:get(player)
			if data.potions > 0 and humanoid.Health < humanoid.MaxHealth then
				data.potions -= 1
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.PotionHealing)
				notify(player, "+" .. Config.PotionHealing .. " здоровья")
				sendState(player)
			end
		end
	end
end)

if hub then
	hub.portalPrompt.Triggered:Connect(function(player)
		if
			near(player, hub.portalPrompt.Parent.WorldPosition, 16)
			and limiter:allow(player.UserId .. ":StartRun", 1, 0.2)
		then
			startRun(player, nil)
		end
	end)
end

RobloxTeleportService.TeleportInitFailed:Connect(function(player)
	recoverTeleport(player)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayer, player)
end)
Players.PlayerRemoving:Connect(function(player)
	joining[player] = nil
	local session = sessions[player]
	if session then
		sessions[player] = nil
		usedSlots[session.slot] = nil
		closeRun(session)
	end
	limiter:forgetPrefix(player.UserId .. ":")
	profiles:save(player, true)
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
game:BindToClose(function()
	profiles:close()
end)
print("[FORTIS] LABYRINTH " .. Config.Version .. " ready · " .. kind .. " · " .. profiles:mode())
