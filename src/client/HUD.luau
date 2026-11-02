local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HUD = {}
HUD.__index = HUD

local palette = {
	ink = Color3.fromRGB(13, 15, 19),
	panel = Color3.fromRGB(23, 25, 30),
	gold = Color3.fromRGB(220, 178, 83),
	dim = Color3.fromRGB(155, 149, 132),
	text = Color3.fromRGB(242, 235, 217),
	red = Color3.fromRGB(194, 68, 66),
	green = Color3.fromRGB(101, 176, 128),
}

local function instance(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function round(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, radius or 12)
	else
		instance("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
	end
end

local function outline(parent, color, transparency)
	instance("UIStroke", { Color = color or palette.gold, Transparency = transparency or 0.55 }, parent)
end

local function label(parent, text, position, size, textSize, color)
	return instance("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = text,
		TextSize = textSize or 16,
		TextColor3 = color or palette.text,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function button(parent, text, position, size, primary)
	local object = instance("TextButton", {
		BackgroundColor3 = if primary then palette.gold else palette.panel,
		TextColor3 = if primary then palette.ink else palette.text,
		Position = position,
		Size = size,
		Text = text,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	round(object)
	if not primary then
		outline(object)
	end
	return object
end

local function panel(parent, position, size)
	local object = instance("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, parent)
	round(object, 14)
	outline(object)
	return object
end

function HUD.new(player, remotes)
	local self = setmetatable({}, HUD)
	self.player = player
	self.remotes = remotes
	self.connections = {}
	self.characterConnections = {}
	self.effects = setmetatable({}, { __mode = "k" })
	self.lowQuality = false
	self.destroyed = false
	self.snapshot = { place = "Hub", runStatus = "Loading", coins = 0, kills = 0, potions = 0 }
	self.lastAttack = 0
	self.lastRequest = 0
	self.noticeVersion = 0

	local playerGui = player:WaitForChild("PlayerGui", 15)
	assert(playerGui, "[FORTIS] PlayerGui unavailable")
	self.gui = instance("ScreenGui", {
		Name = "FortisHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	self.root = instance("Frame", {
		Name = "SafeArea",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, self.gui)
	self.scale = instance("UIScale", { Scale = 1 }, self.root)
	self:_build()

	self:_connect(remotes.State.OnClientEvent, function(snapshot)
		if typeof(snapshot) == "table" then
			self.snapshot = snapshot
			self:_render()
		end
	end)
	self:_connect(remotes.Notify.OnClientEvent, function(message)
		if typeof(message) == "string" then
			self:_notice(message)
		end
	end)
	self:_connect(player.CharacterAdded, function(character)
		self:_bindCharacter(character)
	end)
	if player.Character then
		self:_bindCharacter(player.Character)
	end
	self:_connect(UserInputService.InputBegan, function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_attack()
		elseif input.KeyCode == Enum.KeyCode.Q then
			self:_action("UsePotion")
		elseif input.KeyCode == Enum.KeyCode.M then
			self:_open("map")
		elseif input.KeyCode == Enum.KeyCode.I then
			self:_open("inventory")
		end
	end)
	self:_connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		self:_bindCamera()
	end)
	self:_connect(Workspace.DescendantAdded, function(object)
		if self.lowQuality then
			self:_reduceEffect(object)
		end
	end)
	self:_bindCamera()
	self:_render()
	self:_action("RequestState")
	return self
end

function HUD:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.connections, connection)
	return connection
end

function HUD:_build()
	local top = panel(self.root, UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 130))
	label(top, "FORTIS / LABYRINTH", UDim2.fromOffset(16, 10), UDim2.new(0.65, 0, 0, 25), 19, palette.gold)
	self.floor = label(top, "HUB", UDim2.new(0.68, 0, 0, 11), UDim2.new(0.32, -16, 0, 24), 16)
	self.floor.TextXAlignment = Enum.TextXAlignment.Right
	self.healthText =
		label(top, "ЗДОРОВЬЕ  —", UDim2.fromOffset(16, 39), UDim2.new(0.5, -24, 0, 20), 12, palette.dim)
	local healthTrack = instance("Frame", {
		Position = UDim2.fromOffset(16, 65),
		Size = UDim2.new(0.5, -24, 0, 7),
		BorderSizePixel = 0,
		BackgroundColor3 = palette.panel,
		ClipsDescendants = true,
	}, top)
	round(healthTrack, 4)
	self.healthFill = instance("Frame", {
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = palette.red,
	}, healthTrack)
	round(self.healthFill, 4)
	self.coins =
		label(top, "МОНЕТЫ 0   /   УБИЙСТВА 0", UDim2.new(0.5, 0, 0, 43), UDim2.new(0.5, -16, 0, 24), 13)
	self.coins.TextXAlignment = Enum.TextXAlignment.Right
	self.objective = label(
		top,
		"Подключение к серверу…",
		UDim2.fromOffset(16, 86),
		UDim2.new(1, -32, 0, 32),
		14
	)
	self.objective.TextWrapped = true
	self.objective.TextTruncate = Enum.TextTruncate.None

	local menu = instance("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 154),
		Size = UDim2.fromOffset(292, 40),
	}, self.root)
	local mapButton = button(menu, "КАРТА", UDim2.fromOffset(0, 0), UDim2.fromOffset(84, 40))
	local inventoryButton = button(menu, "ВЕЩИ", UDim2.fromOffset(92, 0), UDim2.fromOffset(84, 40))
	local settingsButton = button(menu, "ОПЦИИ", UDim2.fromOffset(184, 0), UDim2.fromOffset(108, 40))
	self:_connect(mapButton.Activated, function()
		self:_open("map")
	end)
	self:_connect(inventoryButton.Activated, function()
		self:_open("inventory")
	end)
	self:_connect(settingsButton.Activated, function()
		self:_open("settings")
	end)

	self.attack = button(self.root, "УДАР\n[F]", UDim2.new(1, -112, 1, -240), UDim2.fromOffset(96, 86), true)
	round(self.attack, 43)
	self.potion = button(self.root, "ЗЕЛЬЕ\n[Q]", UDim2.new(1, -196, 1, -224), UDim2.fromOffset(72, 68))
	self.potion.TextSize = 12
	self:_connect(self.attack.Activated, function()
		self:_attack()
	end)
	self:_connect(self.potion.Activated, function()
		self:_action("UsePotion")
	end)

	self.runButton = button(
		self.root,
		"ВОЙТИ В ЛАБИРИНТ",
		UDim2.new(0.5, -144, 1, -126),
		UDim2.fromOffset(288, 52),
		true
	)
	self:_connect(self.runButton.Activated, function()
		if self.snapshot.runStatus ~= "Loading" then
			self:_action("StartRun", { mode = "SOLO" })
		end
	end)
	self.returnButton =
		button(self.root, "ВЕРНУТЬСЯ В HUB", UDim2.new(0.5, -126, 1, -126), UDim2.fromOffset(252, 48))
	self:_connect(self.returnButton.Activated, function()
		self:_action("ReturnHub")
	end)
	self.hint = label(
		self.root,
		"SOLO • ЭТАЖ 1 • FORTIS GAMES",
		UDim2.new(0.5, -190, 1, -66),
		UDim2.fromOffset(380, 24),
		11,
		palette.dim
	)
	self.hint.TextXAlignment = Enum.TextXAlignment.Center

	self.notice = panel(self.root, UDim2.new(0.5, -206, 0, 204), UDim2.fromOffset(412, 64))
	self.notice.Visible = false
	self.notice.ZIndex = 30
	self.noticeText = label(self.notice, "", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 1, -16), 15)
	self.noticeText.TextWrapped = true
	self.noticeText.TextTruncate = Enum.TextTruncate.None
	self.noticeText.ZIndex = 31

	self.modal = panel(self.root, UDim2.new(0.5, -210, 0.5, -170), UDim2.fromOffset(420, 340))
	self.modal.Visible = false
	self.modal.ZIndex = 20
	self.modalTitle = label(self.modal, "", UDim2.fromOffset(20, 14), UDim2.new(1, -88, 0, 30), 19, palette.gold)
	self.modalTitle.ZIndex = 21
	local close = button(self.modal, "×", UDim2.new(1, -54, 0, 12), UDim2.fromOffset(40, 36))
	close.ZIndex = 22
	self:_connect(close.Activated, function()
		self.modal.Visible = false
	end)
	self.modalContent = instance("Frame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, self.modal)
end

function HUD:_action(action, payload)
	if self.destroyed then
		return
	end
	if action == "Attack" or action == "UsePotion" then
		if self.snapshot.runStatus ~= "Active" then
			return
		end
	end
	if action == "StartRun" or action == "ReturnHub" then
		local now = os.clock()
		if now - self.lastRequest < 1.5 then
			return
		end
		self.lastRequest = now
	end
	self.remotes.Action:FireServer(action, payload)
end

function HUD:_attack()
	if self.modal.Visible or self.snapshot.runStatus ~= "Active" then
		return
	end
	local now = os.clock()
	if now - self.lastAttack < 0.15 then
		return
	end
	self.lastAttack = now
	self:_action("Attack")
end

function HUD:_bindCharacter(character)
	for _, connection in ipairs(self.characterConnections) do
		connection:Disconnect()
	end
	table.clear(self.characterConnections)
	local function bind(humanoid)
		if not humanoid:IsA("Humanoid") then
			return
		end
		local function update()
			if self.destroyed or self.player.Character ~= character then
				return
			end
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			self.healthText.Text =
				string.format("ЗДОРОВЬЕ  %d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
			TweenService:Create(self.healthFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
		end
		table.insert(self.characterConnections, humanoid.HealthChanged:Connect(update))
		table.insert(self.characterConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update))
		update()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		bind(humanoid)
	else
		table.insert(self.characterConnections, character.ChildAdded:Connect(bind))
	end
end

function HUD:_bindCamera()
	if self.cameraConnection then
		self.cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local function resize()
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 700, viewport.Y / 560), 0.78, 1.1)
		self.scale.Scale = scale
		self.root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	self.cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	resize()
end

function HUD:_render()
	local state = self.snapshot
	local active = state.runStatus == "Active"
	local hub = state.place == "Hub" and state.runStatus ~= "Loading"
	self.floor.Text = if state.place == "Dungeon"
		then string.format("ЭТАЖ %d", tonumber(state.floor) or 1)
		else "HUB"
	self.coins.Text = string.format(
		"МОНЕТЫ %d   /   УБИЙСТВА %d",
		tonumber(state.coins) or 0,
		tonumber(state.kills) or 0
	)
	self.objective.Text = state.objective
		or "Исследуйте катакомбы. Следуйте к золотому выходу."
	self.attack.Visible = active
	self.potion.Visible = active
	self.potion.Text = string.format("ЗЕЛЬЕ ×%d\n[Q]", tonumber(state.potions) or 0)
	self.potion.AutoButtonColor = (tonumber(state.potions) or 0) > 0
	self.runButton.Visible = hub
	self.returnButton.Visible = state.place == "Dungeon" and not active and state.runStatus ~= "Loading"
	self.hint.Text = if state.profileMode == "Session"
		then "ПРОТОТИП • ПРОГРЕСС ЭТОЙ СЕССИИ"
		else "SOLO • ПРОТОТИП ЭТАПА 1 • FORTIS GAMES"
	if self.modal.Visible then
		self:_fillModal()
	end
end

function HUD:_notice(message)
	self.noticeVersion += 1
	local version = self.noticeVersion
	self.noticeText.Text = string.sub(message, 1, 500)
	self.notice.Visible = true
	task.delay(4.5, function()
		if not self.destroyed and self.noticeVersion == version then
			self.notice.Visible = false
		end
	end)
end

function HUD:_open(kind)
	if self.modal.Visible and self.modalKind == kind then
		self.modal.Visible = false
		return
	end
	self.modalKind = kind
	self.modal.Visible = true
	self:_fillModal()
end

function HUD:_fillModal()
	self.modalContent:ClearAllChildren()
	local function text(value, y, height, size, color)
		local object =
			label(self.modalContent, value, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, height), size or 15, color)
		object.TextWrapped = true
		object.TextTruncate = Enum.TextTruncate.None
		object.ZIndex = 22
		return object
	end
	if self.modalKind == "inventory" then
		self.modalTitle.Text = "СНАРЯЖЕНИЕ"
		text("01 / МЕЧ КАТАКОМБ", 2, 32, 16, palette.gold)
		text(
			"Стартовое оружие • Common\nУдар: кнопка УДАР, [F] или левая кнопка мыши.",
			42,
			58
		)
		text(
			string.format("02 / ЗЕЛЬЕ ЛЕЧЕНИЯ ×%d", tonumber(self.snapshot.potions) or 0),
			118,
			30,
			16,
			palette.green
		)
		text(
			"Использовать: кнопка ЗЕЛЬЕ или [Q].\nВосстанавливает до 40 здоровья.",
			156,
			66
		)
	elseif self.modalKind == "settings" then
		self.modalTitle.Text = "НАСТРОЙКИ"
		text("ГРАФИКА", 0, 28, 14, palette.dim)
		local quality = button(
			self.modalContent,
			if self.lowQuality then "ЭКОНОМИЯ ВКЛЮЧЕНА" else "ВКЛЮЧИТЬ ЭКОНОМИЮ",
			UDim2.fromOffset(0, 40),
			UDim2.new(1, 0, 0, 48),
			self.lowQuality
		)
		quality.ZIndex = 22
		quality.Activated:Connect(function()
			self:_setLowQuality(not self.lowQuality)
			self:_fillModal()
		end)
		text(
			"Экономия отключает локальные частицы, лучи, следы и динамические тени.",
			100,
			60
		)
		text(
			"Управление: джойстик Roblox / WASD\n[F] удар   [Q] зелье   [M] карта   [I] вещи",
			177,
			62,
			13,
			palette.dim
		)
	else
		self.modalTitle.Text = "КАРТА ЭТАЖА"
		local map = self.snapshot.map
		if not map or not map.rooms or #map.rooms == 0 then
			text(
				"Карта появится после входа в лабиринт.\nЗолотой — вход, зелёный — выход.",
				44,
				94
			)
			return
		end
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		local byId = {}
		for _, room in ipairs(map.rooms) do
			minX, maxX = math.min(minX, room.x), math.max(maxX, room.x)
			minZ, maxZ = math.min(minZ, room.z), math.max(maxZ, room.z)
			byId[room.id] = room
		end
		local step = math.min(46, 330 / math.max(maxX - minX + 1, 1), 184 / math.max(maxZ - minZ + 1, 1))
		local offsetX = (380 - (maxX - minX) * step) / 2
		local offsetZ = (208 - (maxZ - minZ) * step) / 2
		local function point(room)
			return Vector2.new(offsetX + (room.x - minX) * step, offsetZ + (room.z - minZ) * step)
		end
		for _, edge in ipairs(map.edges or {}) do
			local a, b = byId[edge.a], byId[edge.b]
			if a and b then
				local pa, pb = point(a), point(b)
				instance("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset((pa.X + pb.X) / 2, (pa.Y + pb.Y) / 2),
					Size = UDim2.fromOffset(math.max(math.abs(pa.X - pb.X), 3), math.max(math.abs(pa.Y - pb.Y), 3)),
					BackgroundColor3 = palette.dim,
					BorderSizePixel = 0,
					ZIndex = 22,
				}, self.modalContent)
			end
		end
		for _, room in ipairs(map.rooms) do
			local position = point(room)
			local color = if room.kind == "StartRoom"
				then palette.gold
				elseif room.kind == "ExitRoom" then palette.green
				else palette.panel
			local node = instance("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(position.X, position.Y),
				Size = UDim2.fromOffset(math.min(step * 0.55, 23), math.min(step * 0.55, 23)),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 23,
			}, self.modalContent)
			round(node, 3)
			outline(node, palette.gold, 0.2)
		end
		text("ЗОЛОТОЙ / ВХОД     ЗЕЛЁНЫЙ / ВЫХОД", 224, 25, 11, palette.dim)
	end
end

function HUD:_reduceEffect(object)
	if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
		if self.effects[object] == nil then
			self.effects[object] = object.Enabled
		end
		object.Enabled = false
	end
end

function HUD:_setLowQuality(enabled)
	self.lowQuality = enabled
	if enabled then
		self.originalShadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		for _, object in ipairs(Workspace:GetDescendants()) do
			self:_reduceEffect(object)
		end
	else
		if self.originalShadows ~= nil then
			Lighting.GlobalShadows = self.originalShadows
		end
		for object, wasEnabled in pairs(self.effects) do
			if object.Parent then
				object.Enabled = wasEnabled
			end
		end
		table.clear(self.effects)
	end
end

function HUD:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.lowQuality then
		self:_setLowQuality(false)
	end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(self.characterConnections) do
		connection:Disconnect()
	end
	if self.cameraConnection then
		self.cameraConnection:Disconnect()
	end
	self.gui:Destroy()
end

return HUD
