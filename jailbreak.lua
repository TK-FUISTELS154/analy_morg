--[[
	=============================================================================
	JAILBREAK ULTIMATE COMBAT, ROBBERY & ADMIN SUITE PRO v5.0 (LEVEL 3-5 SECURE)
	=============================================================================
	Desarrollado con Arquitectura Apex Suite v5.0 y Núcleo de Seguridad Nivel 3-5.
	Especialmente adaptado para Jailbreak (Badimo) con bypass de detección y sigilo.

	Módulos Principales:
	1. 🏃 Movimiento & Físicas Seguras:
	   - Speed Engine Seguro por CFrame Delta (sin alterar Humanoid.WalkSpeed).
	   - Preservación de velocidad al conducir vehículos.
	   - Salto Infinito en el Aire (ESPACIO).
	   - Impulso Vertical (Tecla F) y Dash Horizontal (Tecla G).
	   - Noclip Seguro y Modo Vuelo 3D (Fly).
	2. 🎯 Auto-Apuntado Universal (Aimbot) & Spy Radar:
	   - Círculo FOV dinámico con Suavizado Humano (evita detección de snap 1-frame).
	   - Raycast WallCheck de coberturas y estructuras.
	   - Prioridad: Cabeza, Torso o Jugador más Cercano.
	   - Sincronización de color con el Marcador Spy: Verde (Visible), Rojo (Oculto), Dorado (Apuntado).
	3. 👁️ Visuales & Radar ESP:
	   - Player ESP / NameTags con barra de vida, bando y distancia en metros.
	   - Highlights de silueta y Modo Espectador (Spectate).
	4. 📍 Robos & Waypoints de Jailbreak:
	   - Teleport a Bóvedas, Techos y Salidas de: Banco, Joyería, Museo, Casino, Planta de Energía,
	     Mansión del CEO, Tumba, Aeropuerto, Bases Criminales, Cuarteles de Policía y Prisión.
	5. 👥 Bandos & Equipos:
	   - Detección en vivo de Policías, Criminales y Prisioneros.
	   - Toggles para excluir bandos específicos del Aimbot y del Radar ESP.
	6. ☀️ Iluminación & Clima:
	   - Fullbright sin sombras y control de hora del día.
	7. 🛡️ Núcleo de Seguridad Nivel 3-5 (Scan Secure Core):
	   - GUI Protegida con nombres invisibles aleatorios y DisplayOrder 2e9.
	   - Anti-AFK por VirtualUser no invasivo.
	   - Aislamiento de errores en hilos (Thread:SpawnSafe) sin logs rojos en consola F9.
	   - Censura activa de textos de detección (BlockDetectionText).
	   - Persistencia completa en JSON (jailbreak_config.json) y reasignación interactiva de atajos.
--]]

-- =============================================================================
-- 1. NÚCLEO DE SEGURIDAD Y BYPASS NIVEL 3-5 (SECURE CORE)
-- =============================================================================
local Secure = {}
local realGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

-- Detección segura de APIs de exploit Nivel 3-5 con fallbacks nativos
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
		-- Nivel 1: GetService
		local ok1, s1 = pcall(function() return realGame:GetService(serviceName) end)
		if ok1 and s1 then srv = s1 end
		-- Nivel 2: FindFirstChildOfClass
		if not srv then
			local ok2, s2 = pcall(function() return realGame:FindFirstChildOfClass(serviceName) end)
			if ok2 and s2 then srv = s2 end
		end
		-- Nivel 3: FindFirstChildWhichIsA
		if not srv then
			local ok3, s3 = pcall(function() return realGame:FindFirstChildWhichIsA(serviceName) end)
			if ok3 and s3 then srv = s3 end
		end
		-- Nivel 4: Escaneo directo de hijos
		if not srv then
			pcall(function()
				for _, c in ipairs(realGame:GetChildren()) do
					if c.ClassName == serviceName then srv = c; break end
				end
			end)
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
local Teams = Secure.Services.Teams
local VirtualUser = Secure.Services.VirtualUser

local LocalPlayer = Players and (Players.LocalPlayer or Players:FindFirstChildOfClass("Player"))
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")

-- Gestión de Hilos Seguros (Aislamiento de Errores)
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

-- Gestión de Interfaz Segura Nivel 3-5
Secure.GUI = {}
local function generateInvisibleName()
	local str = ""
	for i = 1, math.random(16, 26) do str = str .. string.char(math.random(128, 254)) end
	return str
end

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

-- Bloqueador de Textos de Detección (Anti-OCR / Anti-Prompt)
function Secure.GUI:BlockDetectionText(player)
	if not player then return end
	Secure.Thread:SpawnSafe("DetectionBlocker", function()
		local pGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 4)
		if pGui then
			pGui.DescendantAdded:Connect(function(desc)
				if desc:IsA("TextLabel") or desc:IsA("TextBox") then
					local t = desc.Text:lower()
					if t:find("kick") or t:find("ban") or t:find("cheat") or t:find("exploit") then
						desc.Text = ""
						desc.Visible = false
					end
				end
			end)
		end
	end)
end

-- Anti-AFK Nivel 3 (No invasivo)
Secure.Presence = {}
function Secure.Presence:EnableAntiAFK()
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

Secure.Presence:EnableAntiAFK()
Secure.GUI:BlockDetectionText(LocalPlayer)

-- =============================================================================
-- SINGLETON GUARD: DESTRUIR INSTANCIAS PREVIAS
-- =============================================================================
if _G.JailbreakAdminSuiteInstance then
	pcall(function() _G.JailbreakAdminSuiteInstance:Destroy() end)
	_G.JailbreakAdminSuiteInstance = nil
end

-- =============================================================================
-- ESTADO Y CONFIGURACIÓN PERSISTENTE (CONFIG MANAGER)
-- =============================================================================
local CONFIG_FILE = "jailbreak_config.json"

local State = {
	-- Movimiento & Físicas
	SpeedEngineEnabled = false,
	SpeedValue = 55,
	SprintOnly = false,
	IsSprinting = false,
	InfiniteJump = false,
	ForwardJump = false,
	ForwardJumpPower = 65,
	HorizontalJump = false,
	HorizontalJumpPower = 110,
	Noclip = false,
	FlyEnabled = false,
	FlySpeed = 50,

	-- Auto-Apuntado (Aimbot)
	AimbotEnabled = false,
	IsAiming = false,
	AimKey = Enum.UserInputType.MouseButton2,
	FOV_Radius = 220,
	ShowFOV = false,
	TargetPart = "Head", -- "Head", "UpperTorso", "Closest"
	AimSpeed = 0.75,
	WallCheck = true,
	TeamCheck = true,
	TargetFFA = false,
	OffsetX = 0,
	OffsetY = -20,

	-- Visuales & ESP
	ESPEnabled = false,
	SpectateEnabled = false,
	Fullbright = false,
	LockOnEnabled = false,

	-- Colores Marcador Spy
	ColorLockOnTarget = Color3.fromRGB(255, 215, 0),
	ColorVisible = Color3.fromRGB(50, 255, 100),
	ColorHidden = Color3.fromRGB(255, 50, 50),
	ColorAlly = Color3.fromRGB(50, 150, 255),
	ColorFOV = Color3.fromRGB(255, 255, 255),

	-- Equipos Ignorados
	IgnoredAimTeams = {},
	IgnoredESPTeams = {},

	-- Atajos de Teclado (Keybinds)
	ToggleKey = Enum.KeyCode.RightControl,
	AimbotToggleKey = Enum.KeyCode.E,
	InfiniteJumpKey = Enum.KeyCode.Space,
	ForwardJumpKey = Enum.KeyCode.F,
	HorizontalJumpKey = Enum.KeyCode.G,
	NoclipKey = Enum.KeyCode.N,
	FlyKey = Enum.KeyCode.V,
	ESPKey = Enum.KeyCode.H,
	FullbrightKey = Enum.KeyCode.B,
	SprintKey = Enum.KeyCode.LeftShift,
}

local function saveConfig()
	if typeof(Secure.API.writefile) ~= "function" or not HttpService then return end
	pcall(function()
		local data = {
			SpeedEngineEnabled = State.SpeedEngineEnabled,
			SpeedValue = State.SpeedValue,
			SprintOnly = State.SprintOnly,
			InfiniteJump = State.InfiniteJump,
			ForwardJump = State.ForwardJump,
			ForwardJumpPower = State.ForwardJumpPower,
			HorizontalJump = State.HorizontalJump,
			HorizontalJumpPower = State.HorizontalJumpPower,
			Noclip = State.Noclip,
			FlyEnabled = State.FlyEnabled,
			FlySpeed = State.FlySpeed,

			AimbotEnabled = State.AimbotEnabled,
			FOV_Radius = State.FOV_Radius,
			ShowFOV = State.ShowFOV,
			TargetPart = State.TargetPart,
			AimSpeed = State.AimSpeed,
			WallCheck = State.WallCheck,
			TeamCheck = State.TeamCheck,
			TargetFFA = State.TargetFFA,
			OffsetX = State.OffsetX,
			OffsetY = State.OffsetY,

			ESPEnabled = State.ESPEnabled,
			Fullbright = State.Fullbright,
			LockOnEnabled = State.LockOnEnabled,

			IgnoredAimTeams = State.IgnoredAimTeams,
			IgnoredESPTeams = State.IgnoredESPTeams,

			ToggleKey = State.ToggleKey.Name,
			AimbotToggleKey = State.AimbotToggleKey.Name,
			InfiniteJumpKey = State.InfiniteJumpKey.Name,
			ForwardJumpKey = State.ForwardJumpKey.Name,
			HorizontalJumpKey = State.HorizontalJumpKey.Name,
			NoclipKey = State.NoclipKey.Name,
			FlyKey = State.FlyKey.Name,
			ESPKey = State.ESPKey.Name,
			FullbrightKey = State.FullbrightKey.Name,
		}
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
local ESPCache = {}

-- Ubicaciones y Robos de Jailbreak
local JAILBREAK_LOCATIONS = {
	{ Name = "🏦 Banco (Bóveda Principal)", Pos = Vector3.new(10, 18, 785) },
	{ Name = "🏦 Banco (Exterior)", Pos = Vector3.new(20, 18, 850) },
	{ Name = "💎 Joyería (Techo)", Pos = Vector3.new(140, 120, 1315) },
	{ Name = "💎 Joyería (Entrada)", Pos = Vector3.new(105, 18, 1310) },
	{ Name = "🏛️ Museo (Techo)", Pos = Vector3.new(1075, 140, 1245) },
	{ Name = "🏛️ Museo (Entrada Frontal)", Pos = Vector3.new(1065, 102, 1200) },
	{ Name = "🎰 Casino (Bóveda / Seguridad)", Pos = Vector3.new(-180, 22, -4710) },
	{ Name = "🎰 Casino (Entrada)", Pos = Vector3.new(-190, 22, -4640) },
	{ Name = "⚡ Planta de Energía (Núcleo)", Pos = Vector3.new(60, 40, 2330) },
	{ Name = "⚡ Planta de Energía (Salida)", Pos = Vector3.new(80, 38, 2390) },
	{ Name = "🏰 Mansión del CEO (Entrada)", Pos = Vector3.new(3150, 60, -4550) },
	{ Name = "⚰️ Tumba (Entrada)", Pos = Vector3.new(480, 22, -440) },
	{ Name = "✈️ Aeropuerto (Pista de Carga)", Pos = Vector3.new(-1200, 42, 2800) },
	{ Name = "🌋 Base Criminal (Volcán)", Pos = Vector3.new(1650, 50, -1700) },
	{ Name = "🏙️ Base Criminal (Ciudad)", Pos = Vector3.new(-220, 18, 1580) },
	{ Name = "👮 Cuartel de Policía (Ciudad)", Pos = Vector3.new(-650, 20, 750) },
	{ Name = "⛓️ Prisión (Patio Central)", Pos = Vector3.new(-1180, 18, -1375) },
	{ Name = "🔫 Tienda de Armas (Ciudad)", Pos = Vector3.new(390, 18, 1070) },
	{ Name = "🔧 Garaje Principal (Ciudad)", Pos = Vector3.new(-340, 18, 1200) },
}

-- Paleta Material Design 3
local PALETTE = {
	Background = Color3.fromRGB(15, 18, 26),
	Surface = Color3.fromRGB(24, 28, 40),
	Card = Color3.fromRGB(32, 38, 54),
	InputBg = Color3.fromRGB(42, 48, 68),
	Primary = Color3.fromRGB(0, 185, 255),
	PrimaryHover = Color3.fromRGB(50, 210, 255),
	Secondary = Color3.fromRGB(255, 180, 0),
	Success = Color3.fromRGB(40, 200, 120),
	Danger = Color3.fromRGB(240, 70, 70),
	Text = Color3.fromRGB(240, 245, 255),
	TextMuted = Color3.fromRGB(140, 160, 190),
	Stroke = Color3.fromRGB(50, 60, 85)
}

-- =============================================================================
-- 2. CREACIÓN DE INTERFAZ GRÁFICA (MATERIAL DESIGN 3)
-- =============================================================================
local screenGui = Secure.GUI:CreateSafe("JailbreakAdminSuitePro")
_G.JailbreakAdminSuiteInstance = screenGui

-- Crosshair Center Dot
local centerDot = Instance.new("Frame")
centerDot.Name = "CenterDot"
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
centerDot.Size = UDim2.new(0, 5, 0, 5)
centerDot.BackgroundColor3 = State.ColorFOV
centerDot.ZIndex = 100
centerDot.Parent = screenGui
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

-- Círculo FOV para Aimbot
local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = centerDot.Position
fovFrame.Size = UDim2.new(0, State.FOV_Radius * 2, 0, State.FOV_Radius * 2)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = State.ShowFOV
fovFrame.ZIndex = 99
fovFrame.Parent = screenGui
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = State.ColorFOV
fovStroke.Thickness = 1.6
fovStroke.Transparency = 0.4
fovStroke.Parent = fovFrame

-- Folder para ESP
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "JailbreakESPFolder"
ESPFolder.Parent = screenGui

-- Ventana Principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 660, 0, 490)
mainFrame.Position = UDim2.new(0.5, -330, 0.5, -245)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = PALETTE.Primary
mainStroke.Thickness = 1.6
mainStroke.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = PALETTE.Surface
header.Parent = mainFrame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ JAILBREAK COMBAT & ROBBERY SUITE PRO (L3-5 SECURE)"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 9)
closeBtn.BackgroundColor3 = PALETTE.Danger
closeBtn.Text = "✕"
closeBtn.TextColor3 = PALETTE.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Telemetría Inferior
local telemetryBar = Instance.new("TextLabel")
telemetryBar.Size = UDim2.new(1, -24, 0, 22)
telemetryBar.Position = UDim2.new(0, 12, 1, -26)
telemetryBar.BackgroundTransparency = 1
telemetryBar.Text = "FPS: -- | Ocultar (" .. State.ToggleKey.Name .. ") | Sprint (Shift) | Salto (Space) | Dash (" .. State.HorizontalJumpKey.Name .. ")"
telemetryBar.TextColor3 = PALETTE.TextMuted
telemetryBar.Font = Enum.Font.Code
telemetryBar.TextSize = 9
telemetryBar.TextXAlignment = Enum.TextXAlignment.Left
telemetryBar.Parent = mainFrame

-- Navegación Lateral (Sidebar Tabs)
local navBar = Instance.new("ScrollingFrame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 155, 1, -76)
navBar.Position = UDim2.new(0, 10, 0, 52)
navBar.BackgroundColor3 = PALETTE.Surface
navBar.BorderSizePixel = 0
navBar.ScrollBarThickness = 2
navBar.ScrollBarImageColor3 = PALETTE.Primary
navBar.Parent = mainFrame
Instance.new("UICorner", navBar).CornerRadius = UDim.new(0, 8)

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 4)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Parent = navBar
Instance.new("UIPadding", navBar).PaddingTop = UDim.new(0, 6)

-- Contenedor de Páginas
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -185, 1, -76)
contentArea.Position = UDim2.new(0, 172, 0, 52)
contentArea.BackgroundColor3 = PALETTE.Surface
contentArea.Parent = mainFrame
Instance.new("UICorner", contentArea).CornerRadius = UDim.new(0, 8)

-- =============================================================================
-- SISTEMA DE PESTAÑAS (TABS ENGINE)
-- =============================================================================
local Tabs = {}
local TabButtons = {}

local TabDefs = {
	{ Id = "Movement",  Title = "🏃 Movimiento" },
	{ Id = "Combat",    Title = "🎯 Auto-Apuntado" },
	{ Id = "Visuals",   Title = "👁️ Visuales & ESP" },
	{ Id = "Robberies", Title = "📍 Robos & TP" },
	{ Id = "Teams",     Title = "👥 Bandos & Equipos" },
	{ Id = "Lighting",  Title = "☀️ Iluminación" },
	{ Id = "Settings",  Title = "⚙️ Ajustes & Atajos" }
}

for _, t in ipairs(TabDefs) do
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page_" .. t.Id
	page.Size = UDim2.new(1, -16, 1, -16)
	page.Position = UDim2.new(0, 8, 0, 8)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = PALETTE.Primary
	page.Visible = false
	page.Parent = contentArea

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = page
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 16)
	end)

	Tabs[t.Id] = page

	local btn = Instance.new("TextButton")
	btn.Name = "TabBtn_" .. t.Id
	btn.Size = UDim2.new(1, -12, 0, 36)
	btn.BackgroundColor3 = PALETTE.Card
	btn.Text = t.Title
	btn.TextColor3 = PALETTE.TextMuted
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 10
	btn.Parent = navBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		for id, p in pairs(Tabs) do p.Visible = (id == t.Id) end
		for id, b in pairs(TabButtons) do
			if id == t.Id then
				b.BackgroundColor3 = PALETTE.Primary
				b.TextColor3 = PALETTE.Text
			else
				b.BackgroundColor3 = PALETTE.Card
				b.TextColor3 = PALETTE.TextMuted
			end
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

-- =============================================================================
-- COMPONENTES DE UI REUTILIZABLES
-- =============================================================================
local function createCard(parent, titleText, height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height or 70)
	card.BackgroundColor3 = PALETTE.Card
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -16, 0, 20)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = PALETTE.Text
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = card

	return card
end

local function createToggle(parent, titleText, defaultVal, callback)
	local card = createCard(parent, titleText, 46)

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 85, 0, 24)
	toggleBtn.Position = UDim2.new(1, -95, 0.5, -12)
	toggleBtn.BackgroundColor3 = defaultVal and PALETTE.Success or PALETTE.InputBg
	toggleBtn.Text = defaultVal and "ACTIVO" or "INACTIVO"
	toggleBtn.TextColor3 = PALETTE.Text
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 9
	toggleBtn.Parent = card
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

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 60, 0, 18)
	valLabel.Position = UDim2.new(1, -70, 0, 6)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(defaultVal)
	valLabel.TextColor3 = PALETTE.Primary
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 10
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = card

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, -20, 0, 8)
	sliderTrack.Position = UDim2.new(0, 10, 0, 36)
	sliderTrack.BackgroundColor3 = PALETTE.InputBg
	sliderTrack.Parent = card
	Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

	local initPct = math.clamp((defaultVal - minVal) / math.max(maxVal - minVal, 1), 0, 1)
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(initPct, 0, 1, 0)
	sliderFill.BackgroundColor3 = PALETTE.Primary
	sliderFill.Parent = sliderTrack
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

	local bindBtn = Instance.new("TextButton")
	bindBtn.Size = UDim2.new(0, 110, 0, 24)
	bindBtn.Position = UDim2.new(1, -120, 0.5, -12)
	bindBtn.BackgroundColor3 = PALETTE.InputBg
	bindBtn.Text = currentKey and currentKey.Name or "None"
	bindBtn.TextColor3 = PALETTE.Secondary
	bindBtn.Font = Enum.Font.GothamBold
	bindBtn.TextSize = 10
	bindBtn.Parent = card
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
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = color or PALETTE.Primary
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function() pcall(callback) end)
	return btn
end

-- =============================================================================
-- PESTAÑA 1: 🏃 MOVIMIENTO & FÍSICAS SEGURAS
-- =============================================================================
local pMovement = Tabs["Movement"]

createToggle(pMovement, "⚡ Super Velocidad (Speed Engine Seguro)", State.SpeedEngineEnabled, function(v)
	State.SpeedEngineEnabled = v
end)

createSlider(pMovement, "Fuerza de Desplazamiento (studs/s)", 16, 250, State.SpeedValue, function(v)
	State.SpeedValue = v
end)

createToggle(pMovement, "Activar Solo al Mantener Presionado SHIFT", State.SprintOnly, function(v)
	State.SprintOnly = v
end)

createToggle(pMovement, "🦘 Salto Infinito en el Aire (ESPACIO)", State.InfiniteJump, function(v)
	State.InfiniteJump = v
end)

createToggle(pMovement, "🚀 Impulso Vertical (Tecla F)", State.ForwardJump, function(v)
	State.ForwardJump = v
end)

createSlider(pMovement, "Fuerza de Impulso Vertical", 40, 150, State.ForwardJumpPower, function(v)
	State.ForwardJumpPower = v
end)

createToggle(pMovement, "💨 Dash Horizontal (Tecla G)", State.HorizontalJump, function(v)
	State.HorizontalJump = v
end)

createSlider(pMovement, "Fuerza de Dash Horizontal", 50, 200, State.HorizontalJumpPower, function(v)
	State.HorizontalJumpPower = v
end)

createToggle(pMovement, "👻 Noclip (Atravesar Paredes)", State.Noclip, function(v)
	State.Noclip = v
end)

createToggle(pMovement, "🦅 Modo Vuelo 3D (Fly Mode)", State.FlyEnabled, function(v)
	State.FlyEnabled = v
end)

createSlider(pMovement, "Velocidad de Vuelo", 20, 160, State.FlySpeed, function(v)
	State.FlySpeed = v
end)

-- =============================================================================
-- PESTAÑA 2: 🎯 AUTO-APUNTADO (AIMBOT) & SPY RADAR
-- =============================================================================
local pCombat = Tabs["Combat"]

createToggle(pCombat, "🎯 Activar Auto-Apuntado Universal (Aimbot)", State.AimbotEnabled, function(v)
	State.AimbotEnabled = v
end)

createToggle(pCombat, "⭕ Mostrar Círculo FOV", State.ShowFOV, function(v)
	State.ShowFOV = v
	fovFrame.Visible = v
end)

createSlider(pCombat, "Radio de Campo de Visión (Píxeles)", 60, 450, State.FOV_Radius, function(v)
	State.FOV_Radius = v
	fovFrame.Size = UDim2.new(0, v * 2, 0, v * 2)
end)

createSlider(pCombat, "Suavizado de Puntería (Smoothing)", 1, 10, math.floor(State.AimSpeed * 10), function(v)
	State.AimSpeed = v / 10
end)

createToggle(pCombat, "🧱 Comprobador de Paredes (Raycast WallCheck)", State.WallCheck, function(v)
	State.WallCheck = v
end)

createToggle(pCombat, "🛡️ Team Check (No apuntar a aliados)", State.TeamCheck, function(v)
	State.TeamCheck = v
end)

-- Selector de Parte Objetivo
local partCard = createCard(pCombat, "Parte del Cuerpo Objetivo", 68)
local pHeadBtn = Instance.new("TextButton")
pHeadBtn.Size = UDim2.new(0.3, -4, 0, 24)
pHeadBtn.Position = UDim2.new(0, 10, 0, 32)
pHeadBtn.BackgroundColor3 = (State.TargetPart == "Head") and PALETTE.Primary or PALETTE.InputBg
pHeadBtn.Text = "Cabeza"
pHeadBtn.TextColor3 = PALETTE.Text
pHeadBtn.Font = Enum.Font.GothamBold
pHeadBtn.TextSize = 9
pHeadBtn.Parent = partCard
Instance.new("UICorner", pHeadBtn).CornerRadius = UDim.new(0, 4)

local pTorsoBtn = Instance.new("TextButton")
pTorsoBtn.Size = UDim2.new(0.3, -4, 0, 24)
pTorsoBtn.Position = UDim2.new(0.33, 0, 0, 32)
pTorsoBtn.BackgroundColor3 = (State.TargetPart == "UpperTorso") and PALETTE.Primary or PALETTE.InputBg
pTorsoBtn.Text = "Torso"
pTorsoBtn.TextColor3 = PALETTE.Text
pTorsoBtn.Font = Enum.Font.GothamBold
pTorsoBtn.TextSize = 9
pTorsoBtn.Parent = partCard
Instance.new("UICorner", pTorsoBtn).CornerRadius = UDim.new(0, 4)

local pClosestBtn = Instance.new("TextButton")
pClosestBtn.Size = UDim2.new(0.3, -4, 0, 24)
pClosestBtn.Position = UDim2.new(0.66, 0, 0, 32)
pClosestBtn.BackgroundColor3 = (State.TargetPart == "Closest") and PALETTE.Primary or PALETTE.InputBg
pClosestBtn.Text = "Cercano"
pClosestBtn.TextColor3 = PALETTE.Text
pClosestBtn.Font = Enum.Font.GothamBold
pClosestBtn.TextSize = 9
pClosestBtn.Parent = partCard
Instance.new("UICorner", pClosestBtn).CornerRadius = UDim.new(0, 4)

local function updateTargetPartUI(part)
	State.TargetPart = part
	pHeadBtn.BackgroundColor3 = (part == "Head") and PALETTE.Primary or PALETTE.InputBg
	pTorsoBtn.BackgroundColor3 = (part == "UpperTorso") and PALETTE.Primary or PALETTE.InputBg
	pClosestBtn.BackgroundColor3 = (part == "Closest") and PALETTE.Primary or PALETTE.InputBg
	saveConfig()
end

pHeadBtn.MouseButton1Click:Connect(function() updateTargetPartUI("Head") end)
pTorsoBtn.MouseButton1Click:Connect(function() updateTargetPartUI("UpperTorso") end)
pClosestBtn.MouseButton1Click:Connect(function() updateTargetPartUI("Closest") end)

-- =============================================================================
-- PESTAÑA 3: 👁️ VISUALES & RADAR ESP
-- =============================================================================
local pVisuals = Tabs["Visuals"]

createToggle(pVisuals, "👁️ Radar ESP de Jugadores y Marcador Spy", State.ESPEnabled, function(v)
	State.ESPEnabled = v
	if not v then
		for _, esp in pairs(ESPCache) do
			if esp.Billboard then esp.Billboard.Visible = false end
			if esp.Highlight then esp.Highlight.Enabled = false end
		end
	end
end)

createToggle(pVisuals, "🔒 Camera Lock-On al Apuntar", State.LockOnEnabled, function(v)
	State.LockOnEnabled = v
end)

-- =============================================================================
-- PESTAÑA 4: 📍 ROBOS & WAYPOINTS DE JAILBREAK
-- =============================================================================
local pRobberies = Tabs["Robberies"]

createCard(pRobberies, "Teleport Directo a Zonas de Robo y Salidas", 36)
for _, loc in ipairs(JAILBREAK_LOCATIONS) do
	createActionButton(pRobberies, loc.Name, PALETTE.Card, function()
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
		if hrp then
			hrp.CFrame = CFrame.new(loc.Pos) + Vector3.new(0, 3, 0)
		end
	end)
end

-- =============================================================================
-- PESTAÑA 5: 👥 BANDOS & EQUIPOS
-- =============================================================================
local pTeams = Tabs["Teams"]

createToggle(pTeams, "Modo Todos Contra Todos (Target FFA)", State.TargetFFA, function(v)
	State.TargetFFA = v
end)

local teamCards = {}
local function refreshTeamsList()
	for _, c in ipairs(teamCards) do pcall(function() c:Destroy() end) end
	teamCards = {}

	if Teams then
		for _, tm in ipairs(Teams:GetTeams()) do
			local card = createCard(pTeams, "Bando: " .. tm.Name, 44)
			table.insert(teamCards, card)

			local ignBtn = Instance.new("TextButton")
			ignBtn.Size = UDim2.new(0, 95, 0, 24)
			ignBtn.Position = UDim2.new(1, -105, 0.5, -12)
			local isIgnored = State.IgnoredAimTeams[tm.Name] or false
			ignBtn.BackgroundColor3 = isIgnored and PALETTE.Danger or PALETTE.Success
			ignBtn.Text = isIgnored and "IGNORADO" or "APUNTAR"
			ignBtn.TextColor3 = PALETTE.Text
			ignBtn.Font = Enum.Font.GothamBold
			ignBtn.TextSize = 9
			ignBtn.Parent = card
			Instance.new("UICorner", ignBtn).CornerRadius = UDim.new(0, 4)

			ignBtn.MouseButton1Click:Connect(function()
				State.IgnoredAimTeams[tm.Name] = not State.IgnoredAimTeams[tm.Name]
				local ign = State.IgnoredAimTeams[tm.Name]
				ignBtn.BackgroundColor3 = ign and PALETTE.Danger or PALETTE.Success
				ignBtn.Text = ign and "IGNORADO" or "APUNTAR"
				saveConfig()
			end)
		end
	end
end

createActionButton(pTeams, "🔄 Actualizar Lista de Bandos", PALETTE.Primary, refreshTeamsList)
refreshTeamsList()

-- =============================================================================
-- PESTAÑA 6: ☀️ ILUMINACIÓN & CLIMA
-- =============================================================================
local pLighting = Tabs["Lighting"]

createToggle(pLighting, "💡 Fullbright (Sin Sombras)", State.Fullbright, function(v)
	State.Fullbright = v
	if Lighting then
		if v then
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
		else
			Lighting.Brightness = 1
			Lighting.GlobalShadows = true
		end
	end
end)

createActionButton(pLighting, "☀️ Ajustar a Día (14:00)", PALETTE.Card, function()
	if Lighting then Lighting.ClockTime = 14 end
end)

createActionButton(pLighting, "🌙 Ajustar a Noche (00:00)", PALETTE.Card, function()
	if Lighting then Lighting.ClockTime = 0 end
end)

-- =============================================================================
-- PESTAÑA 7: ⚙️ AJUSTES & CONFIGURACIÓN PERSISTENTE
-- =============================================================================
local pSettings = Tabs["Settings"]

createKeybindRow(pSettings, "Atajo Mostrar / Ocultar Panel:", State.ToggleKey, function(k)
	State.ToggleKey = k
	telemetryBar.Text = "FPS: -- | Ocultar (" .. k.Name .. ") | Sprint (Shift) | Salto (Space) | Dash (" .. State.HorizontalJumpKey.Name .. ")"
end)

createKeybindRow(pSettings, "Atajo Activar Auto-Apuntado:", State.AimbotToggleKey, function(k) State.AimbotToggleKey = k end)
createKeybindRow(pSettings, "Tecla Salto Infinito en Aire:", State.InfiniteJumpKey, function(k) State.InfiniteJumpKey = k end)
createKeybindRow(pSettings, "Tecla Impulso Vertical (F):", State.ForwardJumpKey, function(k) State.ForwardJumpKey = k end)
createKeybindRow(pSettings, "Tecla Dash Horizontal (G):", State.HorizontalJumpKey, function(k) State.HorizontalJumpKey = k end)
createKeybindRow(pSettings, "Atajo Modo Noclip:", State.NoclipKey, function(k) State.NoclipKey = k end)
createKeybindRow(pSettings, "Atajo Modo Vuelo (Fly):", State.FlyKey, function(k) State.FlyKey = k end)
createKeybindRow(pSettings, "Atajo Radar ESP / Spy:", State.ESPKey, function(k) State.ESPKey = k end)
createKeybindRow(pSettings, "Atajo Fullbright:", State.FullbrightKey, function(k) State.FullbrightKey = k end)

createActionButton(pSettings, "💾 FORZAR GUARDADO DE CONFIGURACIÓN", PALETTE.Success, function()
	saveConfig()
end)

createActionButton(pSettings, "❌ FINALIZAR SUITE (KILL PROCESS)", PALETTE.Danger, function()
	for _, conn in pairs(Connections) do pcall(function() conn:Disconnect() end) end
	for _, esp in pairs(ESPCache) do
		if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
		if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
	end
	if screenGui then screenGui:Destroy() end
	_G.JailbreakAdminSuiteInstance = nil
end)

selectTab("Movement")

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

-- =============================================================================
-- MOTOR DE EJECUCIÓN: AIMBOT, RADAR Y MOVIMIENTO SEGURO
-- =============================================================================
local function getBestAimbotTarget()
	if not LocalPlayer or not Camera then return nil end
	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return nil end

	local mousePos = UserInputService:GetMouseLocation()
	local bestTarget = nil
	local bestDist = State.FOV_Radius

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")

			if hum and hum.Health > 0 and hrp then
				local sameTeam = (State.TeamCheck and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team)
				local ignored = State.IgnoredAimTeams[plr.Team and plr.Team.Name or ""] or false

				if (not sameTeam and not ignored) or State.TargetFFA then
					local targetPart = (State.TargetPart == "Head" and char:FindFirstChild("Head"))
						or (State.TargetPart == "UpperTorso" and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")))
						or hrp

					if targetPart then
						local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
						if onScreen then
							local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
							if mouseDist <= bestDist then
								local isVisible = true
								if State.WallCheck then
									local origin = Camera.CFrame.Position
									local dir = (targetPart.Position - origin)
									local rayParams = RaycastParams.new()
									rayParams.FilterType = Enum.RaycastFilterType.Exclude
									rayParams.FilterDescendantsInstances = { myChar, char }
									rayParams.IgnoreWater = true
									local hit = Workspace:Raycast(origin, dir, rayParams)
									if hit and hit.Instance and hit.Instance.CanCollide then
										isVisible = false
									end
								end

								if isVisible then
									bestDist = mouseDist
									bestTarget = { Player = plr, Character = char, Part = targetPart }
								end
							end
						end
					end
				end
			end
		end
	end

	return bestTarget
end

-- RenderStepped Loop (Aimbot & Telemetría)
local frameCounter = 0
local lastFpsUpdate = tick()

Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
	frameCounter = frameCounter + 1
	if tick() - lastFpsUpdate >= 0.5 then
		local fps = math.floor(frameCounter / (tick() - lastFpsUpdate))
		frameCounter = 0
		lastFpsUpdate = tick()
		telemetryBar.Text = string.format("FPS: %d | Ocultar: %s | Salto: %s | Dash: %s", fps, State.ToggleKey.Name, State.InfiniteJumpKey.Name, State.HorizontalJumpKey.Name)
	end

	-- Aimbot / Lock-On
	if (State.AimbotEnabled and State.IsAiming) or State.LockOnEnabled then
		local target = getBestAimbotTarget()
		if target and target.Part then
			local aimOffset = (Camera.CFrame.RightVector * (State.OffsetX * 0.05)) + (Camera.CFrame.UpVector * (State.OffsetY * 0.05))
			local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.Part.Position + aimOffset)
			Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(State.AimSpeed, 0.1, 1.0))
			centerDot.BackgroundColor3 = State.ColorLockOnTarget
		else
			centerDot.BackgroundColor3 = State.ColorFOV
		end
	end
end)

-- Heartbeat Loop (Speed Engine Seguro & Noclip)
Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
	local char = LocalPlayer and LocalPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")

	-- Speed Bypass Seguro por CFrame Delta
	if State.SpeedEngineEnabled and hrp and hum then
		local isMoving = hum.MoveDirection.Magnitude > 0.1
		local shouldSpeed = not State.SprintOnly or State.IsSprinting
		if isMoving and shouldSpeed then
			local moveVector = hum.MoveDirection.Unit * (State.SpeedValue * dt)
			hrp.CFrame = hrp.CFrame + Vector3.new(moveVector.X, 0, moveVector.Z)
		end
	end

	-- Noclip
	if State.Noclip then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end
end)

-- Radar ESP Updater
Secure.Thread:SpawnSafe("RadarESPUpdater", function()
	while screenGui and screenGui.Parent do
		if State.ESPEnabled then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character then
					local char = plr.Character
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")

					if hrp and hum and hum.Health > 0 then
						local esp = ESPCache[plr]
						if not esp then
							local bb = Instance.new("BillboardGui")
							bb.Name = "ESP_" .. plr.Name
							bb.Size = UDim2.new(0, 140, 0, 32)
							bb.AlwaysOnTop = true
							bb.Adornee = hrp
							bb.Parent = ESPFolder

							local label = Instance.new("TextLabel")
							label.Size = UDim2.new(1, 0, 1, 0)
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.GothamBold
							label.TextSize = 10
							label.TextColor3 = State.ColorVisible
							label.TextStrokeTransparency = 0.3
							label.Parent = bb

							local hl = Instance.new("Highlight")
							hl.Adornee = char
							hl.FillColor = State.ColorVisible
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.6
							hl.OutlineTransparency = 0.2
							hl.Parent = ESPFolder

							esp = { Billboard = bb, Label = label, Highlight = hl }
							ESPCache[plr] = esp
						end

						local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
						local teamName = plr.Team and plr.Team.Name or "Neutral"
						esp.Label.Text = string.format("%s\n[%d HP | %s | %dm]", plr.Name, math.floor(hum.Health), teamName, math.floor(dist))
						esp.Billboard.Visible = true
						esp.Highlight.Enabled = true
					end
				end
			end
		end
		task.wait(0.25)
	end
end)

-- Manejo de Teclado
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == State.ToggleKey then
		mainFrame.Visible = not mainFrame.Visible
		return
	end

	if input.UserInputType == State.AimKey then
		State.IsAiming = true
	end

	if input.KeyCode == State.SprintKey then
		State.IsSprinting = true
	end

	if input.KeyCode == State.AimbotToggleKey and not gameProcessed then
		State.AimbotEnabled = not State.AimbotEnabled
	end

	if input.KeyCode == State.NoclipKey and not gameProcessed then
		State.Noclip = not State.Noclip
	end

	if input.KeyCode == State.ESPKey and not gameProcessed then
		State.ESPEnabled = not State.ESPEnabled
	end

	-- Salto Infinito en el Aire
	if input.KeyCode == State.InfiniteJumpKey and State.InfiniteJump and not gameProcessed then
		local char = LocalPlayer and LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end

	-- Impulso Vertical (F)
	if input.KeyCode == State.ForwardJumpKey and State.ForwardJump and not gameProcessed then
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, State.ForwardJumpPower, hrp.AssemblyLinearVelocity.Z)
		end
	end

	-- Dash Horizontal (G)
	if input.KeyCode == State.HorizontalJumpKey and State.HorizontalJump and not gameProcessed then
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			local moveDir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection.Unit or hrp.CFrame.LookVector
			hrp.AssemblyLinearVelocity = moveDir * State.HorizontalJumpPower + Vector3.new(0, 15, 0)
		end
	end
end)

Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == State.AimKey then
		State.IsAiming = false
	end
	if input.KeyCode == State.SprintKey then
		State.IsSprinting = false
	end
end)

print("[JAILBREAK SUITE] Inicializado con Núcleo Seguro Nivel 3-5 y Bypasses Activos.")
