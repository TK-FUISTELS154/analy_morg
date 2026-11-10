-- ==============================================================================
-- 🛡️ SQUID GAME MASTER ENGINE & ADMIN SUITE PRO (LEVEL 3-5 SECURE CORE)
-- Arquitectura de Seguridad Nivel 3-5, Físicas Avanzadas, Visor de Vidrio y Automatización
-- ==============================================================================

-- =============================================================================
-- 1. NÚCLEO DE SEGURIDAD Y BYPASS NIVEL 3-5 (SECURE CORE)
-- =============================================================================
local Secure = {}
local realGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

local function checkFunc(fn, fallback)
	return (type(fn) == "function" and fn) or fallback or function(...) return ... end
end

Secure.API = {
	cloneref = checkFunc(cloneref, function(x) return x end),
	clonefunction = checkFunc(clonefunction, checkFunc(clonefunc, function(f) return f end)),
	gethui = checkFunc(gethui, checkFunc(get_hidden_gui)),
	protect_gui = checkFunc(protect_gui, checkFunc(protectgui, syn and syn.protect_gui)),
	writefile = checkFunc(writefile),
	readfile = checkFunc(readfile),
	isfile = checkFunc(isfile, function() return false end),
	isfolder = checkFunc(isfolder, function() return false end),
	makefolder = checkFunc(makefolder, function() end),
	newcclosure = checkFunc(newcclosure, function(f) return f end),
	checkcaller = checkFunc(checkcaller, function() return true end),
	getgenv = checkFunc(getgenv, function() return _G end),
}

-- Resolutor de Servicios de 4 Niveles con Caché Blindado
Secure.Services = setmetatable({}, {
	__index = function(self, serviceName)
		local cached = rawget(self, serviceName)
		if cached then return cached end

		if serviceName == "Workspace" and typeof(workspace) == "Instance" then
			rawset(self, serviceName, workspace)
			return workspace
		end

		local srv = nil
		local ok1, s1 = pcall(function() return realGame:GetService(serviceName) end)
		if ok1 and s1 then srv = s1 end
		if not srv then
			local ok2, s2 = pcall(function() return realGame:FindFirstChildOfClass(serviceName) end)
			if ok2 and s2 then srv = s2 end
		end
		if not srv then
			local ok3, s3 = pcall(function() return realGame:FindFirstChildWhichIsA(serviceName) end)
			if ok3 and s3 then srv = s3 end
		end

		local finalSrv = srv and Secure.API.cloneref(srv) or srv
		if finalSrv then rawset(self, serviceName, finalSrv) end
		return finalSrv
	end
})

local HttpService = Secure.Services.HttpService
local Players = Secure.Services.Players
local Workspace = Secure.Services.Workspace or workspace
local UserInputService = Secure.Services.UserInputService
local RunService = Secure.Services.RunService
local Lighting = Secure.Services.Lighting
local VirtualUser = Secure.Services.VirtualUser
local ReplicatedStorage = Secure.Services.ReplicatedStorage

local LocalPlayer = Players and (Players.LocalPlayer or Players:FindFirstChildOfClass("Player"))
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")

-- Gestión de Hilos Seguros
Secure.Thread = {}
function Secure.Thread:SpawnSafe(name, func, ...)
	local args = { ... }
	return task.spawn(function()
		local s, err = pcall(func, table.unpack(args))
		if not s and _G.SECURE_DEBUG then
			warn("[SECURE-FAIL][" .. tostring(name) .. "]: " .. tostring(err))
		end
	end)
end

-- Generador de Identificadores Aleatorios Ocultos
local function generateInvisibleName()
	local str = ""
	for _ = 1, math.random(16, 26) do str = str .. string.char(math.random(128, 254)) end
	return str
end

-- Gestión de Interfaz Segura Nivel 3-5
Secure.GUI = {}
function Secure.GUI:CreateSafe(name)
	local finalName = name or generateInvisibleName()
	local screen = Instance.new("ScreenGui")
	screen.Name = finalName
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 2e9
	screen.IgnoreGuiInset = true
	screen.Archivable = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local parent = nil
	if Secure.API.gethui then
		local s, res = pcall(function() return Secure.API.gethui() end)
		if s and res then parent = res end
	end
	if not parent and Secure.API.protect_gui then
		local cg = Secure.Services.CoreGui
		if cg then
			pcall(function() Secure.API.protect_gui(screen) end)
			parent = cg
		end
	end
	if not parent then parent = Secure.Services.CoreGui end
	if not parent and LocalPlayer then
		parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3)
	end

	screen.Parent = parent or Secure.Services.StarterGui
	return screen
end

-- Bloqueo de Diálogos de Kick y Detección
function Secure.GUI:BlockDetectionText(player)
	if not player then return end
	Secure.Thread:SpawnSafe("DetectionBlocker", function()
		local pGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 4)
		if pGui then
			pGui.DescendantAdded:Connect(function(desc)
				if desc:IsA("TextLabel") or desc:IsA("TextBox") then
					local t = desc.Text:lower()
					if t:find("banned") or t:find("kick") or t:find("cheat detected") or t:find("exploit") then
						desc.Text = ""
						desc.Visible = false
					end
				end
			end)
		end
	end)
end

-- Blindaje Anti-Kick y Anti-AFK
Secure.Presence = {}
function Secure.Presence:EnableProtection()
	pcall(function()
		if LocalPlayer and typeof(LocalPlayer.Kick) == "function" then
			LocalPlayer.Kick = Secure.API.newcclosure(function(...) return nil end)
		end
	end)

	if not LocalPlayer then return end
	Secure.Thread:SpawnSafe("AntiAFK_Loop", function()
		LocalPlayer.Idled:Connect(function()
			if VirtualUser then
				pcall(function()
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.new(0, 0))
				end)
			end
		end)
	end)
end

Secure.Presence:EnableProtection()
Secure.GUI:BlockDetectionText(LocalPlayer)

-- =============================================================================
-- SINGLETON GUARD: DESTRUIR INSTANCIAS Y HILOS PREVIOS
-- =============================================================================
if _G.SquidMasterSuiteCleanup then
	pcall(_G.SquidMasterSuiteCleanup)
	_G.SquidMasterSuiteCleanup = nil
end
if _G.SquidMasterSuiteInstance then
	pcall(function() _G.SquidMasterSuiteInstance:Destroy() end)
	_G.SquidMasterSuiteInstance = nil
end

-- =============================================================================
-- CONFIGURACIÓN PERSISTENTE (JSON STORAGE)
-- =============================================================================
local CONFIG_FILE = "squid_suite_config.json"

local State = {
	-- Movimiento & Físicas
	SpeedEngine = true,
	SpeedValue = 28,
	SprintOnly = false,
	IsSprinting = false,
	InfiniteJump = false,
	InfiniteJumpPower = 60,
	VerticalImpulse = true,
	VerticalImpulsePower = 70,
	HorizontalDash = true,
	HorizontalDashPower = 100,
	Noclip = false,
	FlyEnabled = false,
	FlySpeed = 55,

	-- Minijuegos & Visor de Vidrio
	GlassViewer = false,
	GlassChamsColor = Color3.fromRGB(0, 230, 255),
	AutoSkipCinematics = true,
	AntiFallGuard = false,
	MusicalChairsAssist = false,

	-- Emulación de Cuenta & Economía
	EmulateVIPRole = false,
	EmulateFrontman = false,
	AutoClaimDaily = false,
	AutoClaimGroup = false,

	-- Iluminación
	Fullbright = false,

	-- Atajos de Teclado (Keybinds)
	ToggleKey = Enum.KeyCode.F, -- Shift + F para alternar interfaz
	FlyKey = Enum.KeyCode.V,
	NoclipKey = Enum.KeyCode.N,
	GlassKey = Enum.KeyCode.B,
	VerticalKey = Enum.KeyCode.F, -- Impulso vertical sin shift
	DashKey = Enum.KeyCode.G,     -- Dash horizontal directo
	InfiniteJumpKey = Enum.KeyCode.Space
}

local function saveConfig()
	if typeof(Secure.API.writefile) ~= "function" or not HttpService then return end
	pcall(function()
		local data = {}
		for k, v in pairs(State) do
			if typeof(v) == "EnumItem" then
				data[k] = v.Name
			elseif typeof(v) == "Color3" then
				data[k] = { R = v.R, G = v.G, B = v.B }
			else
				data[k] = v
			end
		end
		Secure.API.writefile(CONFIG_FILE, HttpService:JSONEncode(data))
	end)
end

local function loadConfig()
	if typeof(Secure.API.readfile) ~= "function" or typeof(Secure.API.isfile) ~= "function" or not HttpService then return end
	pcall(function()
		if Secure.API.isfile(CONFIG_FILE) then
			local content = Secure.API.readfile(CONFIG_FILE)
			local data = HttpService:JSONDecode(content)
			if type(data) == "table" then
				for k, v in pairs(data) do
					if k:find("Key") and type(v) == "string" and Enum.KeyCode[v] then
						State[k] = Enum.KeyCode[v]
					elseif type(v) == "table" and v.R and v.G and v.B then
						State[k] = Color3.new(v.R, v.G, v.B)
					elseif State[k] ~= nil and type(State[k]) == type(v) then
						State[k] = v
					end
				end
			end
		end
	end)
end

loadConfig()

local Connections = {}
local GlassCache = {}

-- Paleta Material Design 3 Dark / Aqua
local PALETTE = {
	Background = Color3.fromRGB(13, 16, 23),
	Surface = Color3.fromRGB(20, 24, 34),
	Card = Color3.fromRGB(28, 33, 46),
	InputBg = Color3.fromRGB(36, 42, 58),
	Primary = Color3.fromRGB(0, 195, 255),
	PrimaryHover = Color3.fromRGB(45, 215, 255),
	Secondary = Color3.fromRGB(255, 185, 0),
	Success = Color3.fromRGB(40, 205, 125),
	Danger = Color3.fromRGB(240, 65, 75),
	Text = Color3.fromRGB(242, 246, 255),
	TextMuted = Color3.fromRGB(145, 165, 195),
	Stroke = Color3.fromRGB(46, 56, 78)
}

-- =============================================================================
-- 2. RECICLAJE NATIVO DE LÓGICA DE JUEGO (REMOTES & CLIENT REPLICAS)
-- =============================================================================
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

local function getRemote(name)
	return RemotesFolder and RemotesFolder:FindFirstChild(name)
end

-- Emulación de pases y atributos de red legítimos en memoria
local function applyLocalRoleEmulation()
	pcall(function()
		if State.EmulateVIPRole then
			LocalPlayer:SetAttribute("ChatTag", "👑VIP")
			LocalPlayer:SetAttribute("ChatColor", Color3.fromRGB(0, 255, 255))
			LocalPlayer:SetAttribute("EliteTag", true)
		end
		if State.EmulateFrontman then
			LocalPlayer:SetAttribute("IsFrontman", true)
			LocalPlayer:SetAttribute("IsGuard", false)
		end
		LocalPlayer:SetAttribute("CantSprint", false)
		LocalPlayer:SetAttribute("DISABLE_WALKSPEED", false)
		LocalPlayer:SetAttribute("HasCoffin", false)
	end)

	pcall(function()
		local monetizationMod = ReplicatedStorage:FindFirstChild("Shared", true)
		if monetizationMod and monetizationMod:FindFirstChild("Modules") then
			local mon = monetizationMod.Modules:FindFirstChild("monetization")
			if mon then
				local req = require(mon)
				if req and typeof(req.ownsPass) == "function" then
					req.ownsPass = Secure.API.newcclosure(function(plr, passId)
						return true
					end)
				end
			end
		end
	end)
end

applyLocalRoleEmulation()

-- =============================================================================
-- 3. INTERFAZ GRÁFICA PROFESIONAL (MATERIAL DESIGN 3)
-- =============================================================================
local screenGui = Secure.GUI:CreateSafe("SquidAdminSuitePro")
_G.SquidMasterSuiteInstance = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 660, 0, 480)
mainFrame.Position = UDim2.new(0.5, -330, 0.5, -240)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = PALETTE.Primary
mainStroke.Thickness = 1.6

-- Header
local header = Instance.new("Frame", mainFrame)
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = PALETTE.Surface
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ SQUID ENGINE & DEV SUITE PRO [L3-5 SECURE]"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 9)
closeBtn.BackgroundColor3 = PALETTE.Card
closeBtn.Text = "✕"
closeBtn.TextColor3 = PALETTE.TextMuted
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- Barra Inferior de Telemetría
local telemetryBar = Instance.new("TextLabel", mainFrame)
telemetryBar.Size = UDim2.new(1, -24, 0, 22)
telemetryBar.Position = UDim2.new(0, 12, 1, -26)
telemetryBar.BackgroundTransparency = 1
telemetryBar.Text = "FPS: -- | Menu (Shift + " .. State.ToggleKey.Name .. ") | Salto (Space) | Vert (F) | Dash (G)"
telemetryBar.TextColor3 = PALETTE.TextMuted
telemetryBar.Font = Enum.Font.Code
telemetryBar.TextSize = 9
telemetryBar.TextXAlignment = Enum.TextXAlignment.Left

-- Sidebar de Navegación
local navBar = Instance.new("ScrollingFrame", mainFrame)
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 165, 1, -76)
navBar.Position = UDim2.new(0, 10, 0, 52)
navBar.BackgroundColor3 = PALETTE.Surface
navBar.BorderSizePixel = 0
navBar.ScrollBarThickness = 2
navBar.ScrollBarImageColor3 = PALETTE.Primary
Instance.new("UICorner", navBar).CornerRadius = UDim.new(0, 8)

local navLayout = Instance.new("UIListLayout", navBar)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, 5)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", navBar).PaddingTop = UDim.new(0, 6)

-- Contenedor de Páginas
local contentArea = Instance.new("Frame", mainFrame)
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -195, 1, -76)
contentArea.Position = UDim2.new(0, 182, 0, 52)
contentArea.BackgroundColor3 = PALETTE.Surface
Instance.new("UICorner", contentArea).CornerRadius = UDim.new(0, 8)

local Tabs = {}
local TabButtons = {}

local TabDefs = {
	{ Id = "Movement",  Title = "🏃 Físicas & Movimiento" },
	{ Id = "Games",     Title = "🔍 Vidrio & Minijuegos" },
	{ Id = "Economy",   Title = "💎 Recompensas & Pases" },
	{ Id = "Lighting",  Title = "☀️ Iluminación & Mundo" },
	{ Id = "Settings",  Title = "⚙️ Ajustes & Atajos" }
}

for idx, t in ipairs(TabDefs) do
	local page = Instance.new("ScrollingFrame", contentArea)
	page.Name = string.format("%02d_Page_%s", idx, t.Id)
	page.Size = UDim2.new(1, -16, 1, -16)
	page.Position = UDim2.new(0, 8, 0, 8)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = PALETTE.Primary
	page.Visible = false

	local list = Instance.new("UIListLayout", page)
	list.Padding = UDim.new(0, 8)
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 16)
	end)

	Tabs[t.Id] = page

	local btn = Instance.new("TextButton", navBar)
	btn.Name = string.format("%02d_TabBtn_%s", idx, t.Id)
	btn.LayoutOrder = idx
	btn.Size = UDim2.new(1, -12, 0, 36)
	btn.BackgroundColor3 = PALETTE.Card
	btn.Text = t.Title
	btn.TextColor3 = PALETTE.TextMuted
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 10
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		for id, p in pairs(Tabs) do p.Visible = (id == t.Id) end
		for id, b in pairs(TabButtons) do
			b.BackgroundColor3 = (id == t.Id) and PALETTE.Primary or PALETTE.Card
			b.TextColor3 = (id == t.Id) and PALETTE.Text or PALETTE.TextMuted
		end
	end)

	TabButtons[t.Id] = btn
end

local function selectTab(tabId)
	if TabButtons[tabId] then
		for id, p in pairs(Tabs) do p.Visible = (id == tabId) end
		for id, b in pairs(TabButtons) do
			b.BackgroundColor3 = (id == tabId) and PALETTE.Primary or PALETTE.Card
			b.TextColor3 = (id == tabId) and PALETTE.Text or PALETTE.TextMuted
		end
	end
end

-- Creadores de Componentes UI Reutilizables
local function createCard(parent, titleText, height)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1, 0, 0, height or 68)
	card.BackgroundColor3 = PALETTE.Card
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local titleLabel = Instance.new("TextLabel", card)
	titleLabel.Size = UDim2.new(1, -16, 0, 20)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = PALETTE.Text
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	return card
end

local function createToggle(parent, titleText, defaultVal, callback)
	local card = createCard(parent, titleText, 46)

	local toggleBtn = Instance.new("TextButton", card)
	toggleBtn.Size = UDim2.new(0, 85, 0, 24)
	toggleBtn.Position = UDim2.new(1, -95, 0.5, -12)
	toggleBtn.BackgroundColor3 = defaultVal and PALETTE.Success or PALETTE.InputBg
	toggleBtn.Text = defaultVal and "ACTIVO" or "INACTIVO"
	toggleBtn.TextColor3 = PALETTE.Text
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 9
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

	local isEnabled = defaultVal
	toggleBtn.MouseButton1Click:Connect(function()
		isEnabled = not isEnabled
		toggleBtn.BackgroundColor3 = isEnabled and PALETTE.Success or PALETTE.InputBg
		toggleBtn.Text = isEnabled and "ACTIVO" or "INACTIVO"
		pcall(callback, isEnabled)
		saveConfig()
	end)

	return card, function(newVal)
		isEnabled = newVal
		toggleBtn.BackgroundColor3 = isEnabled and PALETTE.Success or PALETTE.InputBg
		toggleBtn.Text = isEnabled and "ACTIVO" or "INACTIVO"
	end
end

local function createSlider(parent, titleText, minVal, maxVal, defaultVal, callback)
	local card = createCard(parent, titleText, 56)

	local valLabel = Instance.new("TextLabel", card)
	valLabel.Size = UDim2.new(0, 60, 0, 18)
	valLabel.Position = UDim2.new(1, -70, 0, 6)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(defaultVal)
	valLabel.TextColor3 = PALETTE.Primary
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 10
	valLabel.TextXAlignment = Enum.TextXAlignment.Right

	local sliderTrack = Instance.new("Frame", card)
	sliderTrack.Size = UDim2.new(1, -20, 0, 8)
	sliderTrack.Position = UDim2.new(0, 10, 0, 36)
	sliderTrack.BackgroundColor3 = PALETTE.InputBg
	Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

	local initPct = math.clamp((defaultVal - minVal) / math.max(maxVal - minVal, 1), 0, 1)
	local sliderFill = Instance.new("Frame", sliderTrack)
	sliderFill.Size = UDim2.new(initPct, 0, 1, 0)
	sliderFill.BackgroundColor3 = PALETTE.Primary
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

	local isDragging = false
	local function updateSlider(inputX)
		local barAbsPos = sliderTrack.AbsolutePosition.X
		local barAbsSize = sliderTrack.AbsoluteSize.X
		local rel = math.clamp((inputX - barAbsPos) / barAbsSize, 0, 1)
		local val = math.floor(minVal + (maxVal - minVal) * rel)
		sliderFill.Size = UDim2.new(rel, 0, 1, 0)
		valLabel.Text = tostring(val)
		pcall(callback, val)
		saveConfig()
	end

	sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			updateSlider(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSlider(input.Position.X)
		end
	end)

	return card
end

local function createKeybindRow(parent, labelText, currentKey, callback)
	local card = createCard(parent, labelText, 44)

	local bindBtn = Instance.new("TextButton", card)
	bindBtn.Size = UDim2.new(0, 110, 0, 24)
	bindBtn.Position = UDim2.new(1, -120, 0.5, -12)
	bindBtn.BackgroundColor3 = PALETTE.InputBg
	bindBtn.Text = currentKey and currentKey.Name or "None"
	bindBtn.TextColor3 = PALETTE.Secondary
	bindBtn.Font = Enum.Font.GothamBold
	bindBtn.TextSize = 10
	Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 4)

	local listening = false
	bindBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		bindBtn.Text = "Presiona Tecla..."
		bindBtn.TextColor3 = PALETTE.Danger

		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local newKey = input.KeyCode
				if newKey ~= Enum.KeyCode.Unknown then
					bindBtn.Text = newKey.Name
					bindBtn.TextColor3 = PALETTE.Secondary
					listening = false
					conn:Disconnect()
					if callback then callback(newKey) end
					saveConfig()
				end
			end
		end)
	end)

	return card
end

local function createActionButton(parent, text, color, callback)
	local btn = Instance.new("TextButton", parent)
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = color or PALETTE.Primary
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function() pcall(callback) end)
	return btn
end

-- =============================================================================
-- PESTAÑA 1: 🏃 FÍSICAS & MOVIMIENTO SEGURO
-- =============================================================================
local pMovement = Tabs["Movement"]

createToggle(pMovement, "⚡ Super Velocidad CFrame (Sin tocar WalkSpeed)", State.SpeedEngine, function(v)
	State.SpeedEngine = v
end)

createSlider(pMovement, "Velocidad de Desplazamiento (studs/s)", 16, 75, State.SpeedValue, function(v)
	State.SpeedValue = v
end)

createToggle(pMovement, "Activar Velocidad Solo al Correr (Shift)", State.SprintOnly, function(v)
	State.SprintOnly = v
end)

createToggle(pMovement, "🦘 Salto Infinito en el Aire (ESPACIO)", State.InfiniteJump, function(v)
	State.InfiniteJump = v
end)

createSlider(pMovement, "Potencia del Salto en Aire", 40, 130, State.InfiniteJumpPower, function(v)
	State.InfiniteJumpPower = v
end)

createToggle(pMovement, "🚀 Impulso Vertical Directo (Tecla F)", State.VerticalImpulse, function(v)
	State.VerticalImpulse = v
end)

createSlider(pMovement, "Fuerza de Impulso Vertical", 40, 140, State.VerticalImpulsePower, function(v)
	State.VerticalImpulsePower = v
end)

createToggle(pMovement, "💨 Dash Horizontal Hacia Adelante (Tecla G)", State.HorizontalDash, function(v)
	State.HorizontalDash = v
end)

createSlider(pMovement, "Fuerza de Dash Horizontal", 40, 180, State.HorizontalDashPower, function(v)
	State.HorizontalDashPower = v
end)

createToggle(pMovement, "👻 Noclip Seguro (Atravesar Paredes)", State.Noclip, function(v)
	State.Noclip = v
end)

createToggle(pMovement, "🦅 Modo Vuelo 3D (Fly)", State.FlyEnabled, function(v)
	State.FlyEnabled = v
end)

createSlider(pMovement, "Velocidad de Vuelo", 20, 140, State.FlySpeed, function(v)
	State.FlySpeed = v
end)

-- =============================================================================
-- PESTAÑA 2: 🔍 VIDRIO & MINIJUEGOS (ANALIZADOR DE CRISTALES Y AUTOMATIZACIONES)
-- =============================================================================
local pGames = Tabs["Games"]

-- Motor de Visor de Vidrio Inteligente
local function updateGlassViewer(enabled)
	State.GlassViewer = enabled
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			local n = inst.Name:lower()
			if n:find("glass") or n:find("vidrio") or n:find("pane") or n:find("tile") or n:find("bridge") or n:find("honeycomb") then
				if enabled then
					if not GlassCache[inst] then
						GlassCache[inst] = {
							Transparency = inst.Transparency,
							Material = inst.Material,
							Color = inst.Color
						}
					end
					-- Si la parte es no-colisionable o tiene trampas lógicas, la marca en rojo; si es sólida, en cian
					if inst.CanCollide == false then
						inst.Color = Color3.fromRGB(255, 60, 60)
						inst.Transparency = 0.35
					else
						inst.Color = State.GlassChamsColor
						inst.Transparency = 0.55
					end
					inst.Material = Enum.Material.Neon
				else
					if GlassCache[inst] then
						inst.Transparency = GlassCache[inst].Transparency
						inst.Material = GlassCache[inst].Material
						inst.Color = GlassCache[inst].Color
						GlassCache[inst] = nil
					end
				end
			end
		end
	end
end

createToggle(pGames, "🔍 Visor de Vidrio & Revelador de Puente (Glass Mode)", State.GlassViewer, function(v)
	updateGlassViewer(v)
end)

createToggle(pGames, "🛡️ Anti-Caída en Vidrio (Crear Plataforma de Apoyo)", State.AntiFallGuard, function(v)
	State.AntiFallGuard = v
end)

createToggle(pGames, "⏩ Auto-Saltar Cinemáticas (Skip Cutscenes)", State.AutoSkipCinematics, function(v)
	State.AutoSkipCinematics = v
end)

createToggle(pGames, "🪑 Asistencia en Sillas Musicales (Auto-Sit)", State.MusicalChairsAssist, function(v)
	State.MusicalChairsAssist = v
end)

createActionButton(pGames, "🔄 Escaneo Forzado de Paneles de Vidrio", PALETTE.Primary, function()
	updateGlassViewer(State.GlassViewer)
end)

-- =============================================================================
-- PESTAÑA 3: 💎 RECOMPENSAS & PASES
-- =============================================================================
local pEconomy = Tabs["Economy"]

createToggle(pEconomy, "👑 Emular Pase VIP & Chat Tag Dorado/Cian", State.EmulateVIPRole, function(v)
	State.EmulateVIPRole = v
	applyLocalRoleEmulation()
end)

createToggle(pEconomy, "🎭 Emular Rol de Frontman Local", State.EmulateFrontman, function(v)
	State.EmulateFrontman = v
	applyLocalRoleEmulation()
end)

createActionButton(pEconomy, "🎁 Reclamar Recompensa Diaria (Daily Reward)", PALETTE.Success, function()
	local daily = getRemote("DailyRewardRequest")
	if daily then
		daily:FireServer("Day")
		daily:FireServer("Group")
	end
end)

createActionButton(pEconomy, "⭐ Reclamar Recompensa de Grupo", PALETTE.Card, function()
	local grp = getRemote("ClaimGroupReward")
	if grp then
		grp:InvokeServer()
	end
end)

createActionButton(pEconomy, "⚡ Forzar Petición de Prestigio (Prestige)", PALETTE.Secondary, function()
	local prest = getRemote("PrestigeRequest")
	if prest then
		prest:FireServer("upgrade")
	end
end)

-- =============================================================================
-- PESTAÑA 4: ☀️️ ILUMINACIÓN & MUNDO
-- =============================================================================
local pLighting = Tabs["Lighting"]

createToggle(pLighting, "💡 Fullbright (Sin Sombras / Máxima Visibilidad)", State.Fullbright, function(v)
	State.Fullbright = v
	if Lighting then
		pcall(function()
			if v then
				Lighting.Brightness = 2.5
				Lighting.FogEnd = 100000
				Lighting.GlobalShadows = false
			else
				Lighting.Brightness = 1
				Lighting.GlobalShadows = true
			end
		end)
	end
end)

createActionButton(pLighting, "☀️ Fijar Hora: Mediodía (14:00)", PALETTE.Card, function()
	if Lighting then pcall(function() Lighting.ClockTime = 14 end) end
end)

createActionButton(pLighting, "🌙 Fijar Hora: Noche (00:00)", PALETTE.Card, function()
	if Lighting then pcall(function() Lighting.ClockTime = 0 end) end
end)

-- =============================================================================
-- PESTAÑA 5: ⚙️ AJUSTES & ATAJOS
-- =============================================================================
local pSettings = Tabs["Settings"]

createKeybindRow(pSettings, "Atajo Menú (Shift + Key):", State.ToggleKey, function(k)
	State.ToggleKey = k
	telemetryBar.Text = "FPS: -- | Menu (Shift + " .. k.Name .. ") | Salto (Space) | Vert (" .. State.VerticalKey.Name .. ") | Dash (" .. State.DashKey.Name .. ")"
end)

createKeybindRow(pSettings, "Atajo Modo Vuelo (Fly):", State.FlyKey, function(k) State.FlyKey = k end)
createKeybindRow(pSettings, "Atajo Modo Noclip:", State.NoclipKey, function(k) State.NoclipKey = k end)
createKeybindRow(pSettings, "Atajo Visor de Vidrio (Glass):", State.GlassKey, function(k) State.GlassKey = k end)
createKeybindRow(pSettings, "Tecla Impulso Vertical:", State.VerticalKey, function(k) State.VerticalKey = k end)
createKeybindRow(pSettings, "Tecla Dash Horizontal:", State.DashKey, function(k) State.DashKey = k end)

createActionButton(pSettings, "💾 GUARDAR CONFIGURACIÓN A JSON", PALETTE.Success, function()
	saveConfig()
end)

local function performFullCleanup()
	for _, conn in pairs(Connections) do pcall(function() conn:Disconnect() end) end
	Connections = {}
	updateGlassViewer(false)
	if Lighting then
		pcall(function()
			Lighting.Brightness = 1
			Lighting.GlobalShadows = true
		end)
	end
	if screenGui then pcall(function() screenGui:Destroy() end) end
	_G.SquidMasterSuiteInstance = nil
	_G.SquidMasterSuiteCleanup = nil
end
_G.SquidMasterSuiteCleanup = performFullCleanup

createActionButton(pSettings, "❌ FINALIZAR SUITE POR COMPLETO (PURGA TOTAL)", PALETTE.Danger, performFullCleanup)

selectTab("Movement")

-- =============================================================================
-- MOTORES EN SEGUNDO PLANO (FÍSICAS, NOCLIP, VUELO Y MINIJUEGOS)
-- =============================================================================

-- Plataforma de apoyo para Anti-Caída
local supportPlatform = Instance.new("Part")
supportPlatform.Name = "GlassSupportSafety"
supportPlatform.Size = Vector3.new(6, 1, 6)
supportPlatform.Anchored = true
supportPlatform.CanCollide = true
supportPlatform.Transparency = 1
supportPlatform.Parent = Workspace

-- Heartbeat Loop: Físicas, Dash, CFrame Delta & Vuelo 3D
Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
	local char = LocalPlayer and LocalPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")

	-- Modo Vuelo 3D Seguro
	if State.FlyEnabled and hrp then
		local flyDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDir = flyDir + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDir = flyDir - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDir = flyDir - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDir = flyDir + Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyDir = flyDir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then flyDir = flyDir - Vector3.new(0, 1, 0) end

		hrp.AssemblyLinearVelocity = Vector3.zero
		if flyDir.Magnitude > 0.05 then
			hrp.CFrame = hrp.CFrame + (flyDir.Unit * (State.FlySpeed * dt))
		end
	end

	-- Speed Engine por CFrame Delta
	if State.SpeedEngine and not State.FlyEnabled and hrp and hum then
		local isMoving = hum.MoveDirection.Magnitude > 0.1
		local shouldSpeed = not State.SprintOnly or State.IsSprinting
		if isMoving and shouldSpeed then
			local delta = hum.MoveDirection.Unit * (State.SpeedValue * dt)
			hrp.CFrame = hrp.CFrame + Vector3.new(delta.X, 0, delta.Z)
		end
	end

	-- Noclip Continuo
	if State.Noclip then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end

	-- Plataforma de Seguridad en Caídas de Vidrio
	if State.AntiFallGuard and hrp then
		if hrp.AssemblyLinearVelocity.Y < -55 then
			supportPlatform.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.8, hrp.Position.Z)
			supportPlatform.CanCollide = true
		else
			supportPlatform.CanCollide = false
		end
	else
		supportPlatform.CanCollide = false
	end
end)

-- RenderStepped Loop: Telemetría de FPS
local frameCounter = 0
local lastFpsUpdate = tick()

Connections.RenderStepped = RunService.RenderStepped:Connect(function()
	frameCounter = frameCounter + 1
	if tick() - lastFpsUpdate >= 0.5 then
		local fps = math.floor(frameCounter / (tick() - lastFpsUpdate))
		frameCounter = 0
		lastFpsUpdate = tick()
		telemetryBar.Text = string.format("FPS: %d | Menu (Shift+%s) | Salto (%s) | Vert (%s) | Dash (%s)", fps, State.ToggleKey.Name, State.InfiniteJumpKey.Name, State.VerticalKey.Name, State.DashKey.Name)
	end
end)

-- Listener de Cinemáticas Automáticas (Auto-Skip)
Secure.Thread:SpawnSafe("CinematicSkipper", function()
	local skipRemote = getRemote("SkipCutscene")
	if skipRemote then
		skipRemote.OnClientEvent:Connect(function(skipRef)
			if State.AutoSkipCinematics and skipRef then
				task.wait(0.2)
				skipRemote:FireServer(skipRef)
			end
		end)
	end
end)

-- Asistencia en Sillas Musicales (Musical Chairs Auto-Sit)
Secure.Thread:SpawnSafe("MusicalChairsWatcher", function()
	while _G.SquidMasterSuiteInstance do
		if State.MusicalChairsAssist then
			local char = LocalPlayer and LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and not hum.Sit then
				for _, obj in ipairs(Workspace:GetDescendants()) do
					if obj:IsA("Seat") and not obj.Occupant then
						local dist = (char.PrimaryPart.Position - obj.Position).Magnitude
						if dist < 14 then
							obj:Sit(hum)
							break
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- =============================================================================
-- GESTIÓN DE ENTRADA (TECLADO & MOUSE)
-- =============================================================================
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	-- 1. Alternar Interfaz con Shift + ToggleKey
	if input.KeyCode == State.ToggleKey and isShiftHeld then
		mainFrame.Visible = not mainFrame.Visible
		return
	end

	-- 2. Detección de Sprint
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		State.IsSprinting = true
	end

	if gameProcessed then return end

	-- 3. Atajos de Utilidad con Shift
	if isShiftHeld then
		if input.KeyCode == State.FlyKey then
			State.FlyEnabled = not State.FlyEnabled
		elseif input.KeyCode == State.NoclipKey then
			State.Noclip = not State.Noclip
		elseif input.KeyCode == State.GlassKey then
			updateGlassViewer(not State.GlassViewer)
		end
	else
		-- 4. Impulso Vertical y Dash Directos
		if input.KeyCode == State.VerticalKey and State.VerticalImpulse then
			local char = LocalPlayer and LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, State.VerticalImpulsePower, hrp.AssemblyLinearVelocity.Z)
			end
		elseif input.KeyCode == State.DashKey and State.HorizontalDash then
			local char = LocalPlayer and LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local moveDir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection.Unit or hrp.CFrame.LookVector
				hrp.AssemblyLinearVelocity = moveDir * State.HorizontalDashPower + Vector3.new(0, 12, 0)
			end
		end
	end

	-- 5. Salto Infinito en el Aire
	if input.KeyCode == State.InfiniteJumpKey and State.InfiniteJump then
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hrp then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, State.InfiniteJumpPower, hrp.AssemblyLinearVelocity.Z)
		end
	end
end)

Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		State.IsSprinting = false
	end
end)

print("[SQUID ENGINE SUITE PRO] Cargado con éxito. Presiona Shift + " .. State.ToggleKey.Name .. " para abrir el panel.")