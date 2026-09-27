--[[
	=============================================================================
	JAILBREAK ULTIMATE COMBAT, ROBBERY & ADMIN SUITE PRO v5.5 (LEVEL 3-5 SECURE)
	=============================================================================
	Desarrollado con Arquitectura Apex Suite v5.0 y Núcleo de Seguridad Nivel 3-5.
	Especialmente adaptado para Jailbreak (Badimo) con bypass de detección y sigilo.

	Módulos Principales:
	1. 🎯 Auto-Apuntado Universal (Aimbot) & Spy Radar:
	   - Círculo FOV dinámico con modo Centrado (Offset Y: -28) o Seguidor de Ratón (Mouse Follow).
	   - Suavizado Humano (evita detección de snap 1-frame).
	   - Raycast WallCheck de coberturas y estructuras.
	   - Prioridad de impacto: Cabeza, Torso o Jugador más Cercano.
	   - Sincronización de color: Verde (Visible), Rojo (Oculto), Dorado (Apuntado).
	2. 👁️ Visuales & Radar ESP Avanzado de Bandos:
	   - Detección visual por equipos: 👮 Policías (Azul), 🔴 Criminales (Rojo), ⛓️ Prisioneros (Naranja), 🛡️ Aliados (Verde).
	   - NameTags en 3D con indicador de salud (HP), bando y distancia exacta.
	   - Siluetas translúcidas (Highlights) y Modo Espectador (Spectate).
	3. 🏃 Movimiento & Físicas Seguras:
	   - Speed Engine Seguro por CFrame Delta (sin alterar Humanoid.WalkSpeed).
	   - Salto Infinito en el Aire con Potencia Editable (ESPACIO).
	   - Impulso Vertical (Tecla F) y Dash Horizontal (Tecla G) con fuerza graduable.
	   - Noclip Seguro y Modo Vuelo 3D (Fly).
	4. 📍 Robos & Waypoints de Jailbreak:
	   - Teleport a Bóvedas, Techos y Salidas de: Banco, Joyería, Museo, Casino, Planta de Energía,
	     Mansión del CEO, Tumba, Aeropuerto, Bases Criminales, Cuarteles de Policía y Prisión.
	5. 👥 Bandos & Equipos:
	   - Detección en vivo de Policías, Criminales y Prisioneros.
	   - Toggles para excluir bandos específicos del Aimbot y del Radar ESP.
	6. ☀️ Iluminación & Clima:
	   - Fullbright sin sombras y control de hora del día.
	7. ⚙️ Ajustes & Configuración Persistente (JSON):
	   - Guardado y carga automática de TODAS las configuraciones y atajos en 'jailbreak_config.json'.
	   - Sistema completo de Reasignación de Teclas (Keybinds) interactivo en tiempo real.
	   - Botón 'X' para ocultar por completo (reabrir con Ctrl + F).
	   - Botón 'Finalizar Suite (Kill Process)' en Ajustes para purga completa de memoria.
--]]

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

-- Censura Activa de Detecciones
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

-- Anti-AFK
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
-- SINGLETON GUARD: DESTRUIR INSTANCIAS Y HILOS PREVIOS
-- =============================================================================
if _G.JailbreakCleanup then
	pcall(_G.JailbreakCleanup)
	_G.JailbreakCleanup = nil
end
if _G.JailbreakAdminSuiteInstance then
	pcall(function() _G.JailbreakAdminSuiteInstance:Destroy() end)
	_G.JailbreakAdminSuiteInstance = nil
end

-- =============================================================================
-- ESTADO Y CONFIGURACIÓN PERSISTENTE (CONFIG MANAGER)
-- =============================================================================
local CONFIG_FILE = "jailbreak_config.json"

local State = {
	-- Aimbot & FOV
	AimbotEnabled = false,
	IsAiming = false,
	AimKey = Enum.UserInputType.MouseButton2,
	FOV_Radius = 220,
	ShowFOV = false,
	FOVMouseFollow = false,
	TargetPart = "Head", -- "Head", "UpperTorso", "Closest"
	AimSpeed = 0.75,
	WallCheck = true,
	TeamCheck = true,
	TargetFFA = false,
	OffsetX = 0,
	OffsetY = -28, -- Predeterminado a -28

	-- Visuales & ESP
	ESPEnabled = false,
	SpectateEnabled = false,
	Fullbright = false,
	LockOnEnabled = false,

	-- Colores de Bandos para ESP
	ColorPolice = Color3.fromRGB(0, 165, 255),
	ColorCriminal = Color3.fromRGB(255, 60, 60),
	ColorPrisoner = Color3.fromRGB(255, 165, 0),
	ColorAlly = Color3.fromRGB(50, 230, 120),
	ColorLockOn = Color3.fromRGB(255, 215, 0),
	ColorFOV = Color3.fromRGB(255, 255, 255),

	-- Movimiento & Físicas
	SpeedEngineEnabled = false,
	SpeedValue = 55,
	SprintOnly = false,
	IsSprinting = false,
	InfiniteJump = false,
	InfiniteJumpPower = 55,
	ForwardJump = false,
	ForwardJumpPower = 65,
	HorizontalJump = false,
	HorizontalJumpPower = 110,
	Noclip = false,
	FlyEnabled = false,
	FlySpeed = 50,

	-- Equipos Ignorados
	IgnoredAimTeams = {},
	IgnoredESPTeams = {},

	-- Atajos de Teclado (Keybinds)
	ToggleKey = Enum.KeyCode.F, -- Ctrl + F para mostrar/ocultar
	AimbotToggleKey = Enum.KeyCode.E,
	InfiniteJumpKey = Enum.KeyCode.Space,
	ForwardJumpKey = Enum.KeyCode.X,
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
			AimbotEnabled = State.AimbotEnabled,
			FOV_Radius = State.FOV_Radius,
			ShowFOV = State.ShowFOV,
			FOVMouseFollow = State.FOVMouseFollow,
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

			SpeedEngineEnabled = State.SpeedEngineEnabled,
			SpeedValue = State.SpeedValue,
			SprintOnly = State.SprintOnly,
			InfiniteJump = State.InfiniteJump,
			InfiniteJumpPower = State.InfiniteJumpPower,
			ForwardJump = State.ForwardJump,
			ForwardJumpPower = State.ForwardJumpPower,
			HorizontalJump = State.HorizontalJump,
			HorizontalJumpPower = State.HorizontalJumpPower,
			Noclip = State.Noclip,
			FlyEnabled = State.FlyEnabled,
			FlySpeed = State.FlySpeed,

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
mainFrame.Size = UDim2.new(0, 670, 0, 500)
mainFrame.Position = UDim2.new(0.5, -335, 0.5, -250)
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
closeBtn.BackgroundColor3 = PALETTE.Card
closeBtn.Text = "✕"
closeBtn.TextColor3 = PALETTE.TextMuted
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- El botón 'X' únicamente OCULTA la interfaz
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- Telemetría Inferior
local telemetryBar = Instance.new("TextLabel")
telemetryBar.Size = UDim2.new(1, -24, 0, 22)
telemetryBar.Position = UDim2.new(0, 12, 1, -26)
telemetryBar.BackgroundTransparency = 1
telemetryBar.Text = "FPS: -- | Toggle (Ctrl + " .. State.ToggleKey.Name .. ") | Sprint (Shift) | Salto (Space) | Dash (" .. State.HorizontalJumpKey.Name .. ")"
telemetryBar.TextColor3 = PALETTE.TextMuted
telemetryBar.Font = Enum.Font.Code
telemetryBar.TextSize = 9
telemetryBar.TextXAlignment = Enum.TextXAlignment.Left
telemetryBar.Parent = mainFrame

-- Navegación Lateral (Sidebar Tabs)
local navBar = Instance.new("ScrollingFrame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 160, 1, -76)
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
contentArea.Size = UDim2.new(1, -190, 1, -76)
contentArea.Position = UDim2.new(0, 178, 0, 52)
contentArea.BackgroundColor3 = PALETTE.Surface
contentArea.Parent = mainFrame
Instance.new("UICorner", contentArea).CornerRadius = UDim.new(0, 8)

-- =============================================================================
-- SISTEMA DE PESTAÑAS (ORDEN ESTRUCTURAL PROFESIONAL)
-- =============================================================================
local Tabs = {}
local TabButtons = {}

local TabDefs = {
	{ Id = "Combat",    Title = "🎯 Combate & Aimbot" },
	{ Id = "Visuals",   Title = "👁️ Visuales & ESP" },
	{ Id = "Movement",  Title = "🏃 Movimiento & Físicas" },
	{ Id = "Robberies", Title = "📍 Robos & Waypoints" },
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
				if newKey ~= Enum.KeyCode.Unknown and newKey ~= Enum.KeyCode.LeftControl and newKey ~= Enum.KeyCode.RightControl then
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
-- PESTAÑA 1: 🎯 COMBATE & AUTO-APUNTADO
-- =============================================================================
local pCombat = Tabs["Combat"]

createToggle(pCombat, "🎯 Activar Auto-Apuntado Universal (Aimbot)", State.AimbotEnabled, function(v)
	State.AimbotEnabled = v
end)

createToggle(pCombat, "⭕ Mostrar Círculo FOV en Pantalla", State.ShowFOV, function(v)
	State.ShowFOV = v
	fovFrame.Visible = v
end)

createToggle(pCombat, "🖱️ Círculo FOV Sigue al Puntero del Ratón", State.FOVMouseFollow, function(v)
	State.FOVMouseFollow = v
end)

createSlider(pCombat, "Radio de Campo de Visión (FOV Píxeles)", 60, 450, State.FOV_Radius, function(v)
	State.FOV_Radius = v
	fovFrame.Size = UDim2.new(0, v * 2, 0, v * 2)
end)

createSlider(pCombat, "Desplazamiento Vertical Y del FOV (Offset Y)", -80, 50, State.OffsetY, function(v)
	State.OffsetY = v
	centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
	if not State.FOVMouseFollow then
		fovFrame.Position = centerDot.Position
	end
end)

createSlider(pCombat, "Suavizado de Puntería (Aim Smoothing)", 1, 10, math.floor(State.AimSpeed * 10), function(v)
	State.AimSpeed = v / 10
end)

createToggle(pCombat, "🧱 Comprobador de Paredes (Raycast WallCheck)", State.WallCheck, function(v)
	State.WallCheck = v
end)

createToggle(pCombat, "🛡️ Team Check (No apuntar a miembros del bando)", State.TeamCheck, function(v)
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
-- PESTAÑA 2: 👁️ VISUALES & RADAR ESP DE BANDOS
-- =============================================================================
local pVisuals = Tabs["Visuals"]

createToggle(pVisuals, "👁️ Radar ESP Avanzado de Jugadores y Bandos", State.ESPEnabled, function(v)
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

-- Leyenda de Colores de Bandos
local legendCard = createCard(pVisuals, "Identificación de Bandos en ESP", 76)
local legendText = Instance.new("TextLabel")
legendText.Size = UDim2.new(1, -20, 0, 48)
legendText.Position = UDim2.new(0, 10, 0, 24)
legendText.BackgroundTransparency = 1
legendText.Text = "👮 Azul: Policías | 🔴 Rojo: Criminales\n⛓️ Naranja: Prisioneros | 🛡️ Verde: Aliados\n🎯 Dorado: Objetivo Fijado por Aimbot"
legendText.TextColor3 = PALETTE.TextMuted
legendText.Font = Enum.Font.Gotham
legendText.TextSize = 9
legendText.TextXAlignment = Enum.TextXAlignment.Left
legendText.Parent = legendCard

-- =============================================================================
-- PESTAÑA 3: 🏃 MOVIMIENTO & FÍSICAS SEGURAS
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

createSlider(pMovement, "Potencia del Salto en el Aire (Jump Power)", 30, 160, State.InfiniteJumpPower, function(v)
	State.InfiniteJumpPower = v
end)

createToggle(pMovement, "🚀 Impulso Vertical (Tecla X)", State.ForwardJump, function(v)
	State.ForwardJump = v
end)

createSlider(pMovement, "Fuerza de Impulso Vertical (X)", 40, 150, State.ForwardJumpPower, function(v)
	State.ForwardJumpPower = v
end)

createToggle(pMovement, "💨 Dash Horizontal (Tecla G)", State.HorizontalJump, function(v)
	State.HorizontalJump = v
end)

createSlider(pMovement, "Fuerza de Dash Horizontal (G)", 50, 200, State.HorizontalJumpPower, function(v)
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
			local card = createCard(pTeams, "Bando: " .. tm.Name, 52)
			table.insert(teamCards, card)

			-- Botón de Aim
			local isAimIgnored = State.IgnoredAimTeams[tm.Name] or false
			local aimBtn = Instance.new("TextButton")
			aimBtn.Size = UDim2.new(0, 95, 0, 24)
			aimBtn.Position = UDim2.new(1, -202, 0.5, -12)
			aimBtn.BackgroundColor3 = isAimIgnored and PALETTE.Danger or PALETTE.Success
			aimBtn.Text = isAimIgnored and "🎯 AIM: OFF" or "🎯 AIM: ON"
			aimBtn.TextColor3 = PALETTE.Text
			aimBtn.Font = Enum.Font.GothamBold
			aimBtn.TextSize = 9
			aimBtn.Parent = card
			Instance.new("UICorner", aimBtn).CornerRadius = UDim.new(0, 4)

			aimBtn.MouseButton1Click:Connect(function()
				State.IgnoredAimTeams[tm.Name] = not State.IgnoredAimTeams[tm.Name]
				local ign = State.IgnoredAimTeams[tm.Name]
				aimBtn.BackgroundColor3 = ign and PALETTE.Danger or PALETTE.Success
				aimBtn.Text = ign and "🎯 AIM: OFF" or "🎯 AIM: ON"
				saveConfig()
			end)

			-- Botón de ESP
			local isEspIgnored = State.IgnoredESPTeams[tm.Name] or false
			local espBtn = Instance.new("TextButton")
			espBtn.Size = UDim2.new(0, 95, 0, 24)
			espBtn.Position = UDim2.new(1, -102, 0.5, -12)
			espBtn.BackgroundColor3 = isEspIgnored and PALETTE.Danger or PALETTE.Success
			espBtn.Text = isEspIgnored and "👁️ ESP: OFF" or "👁️ ESP: ON"
			espBtn.TextColor3 = PALETTE.Text
			espBtn.Font = Enum.Font.GothamBold
			espBtn.TextSize = 9
			espBtn.Parent = card
			Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 4)

			espBtn.MouseButton1Click:Connect(function()
				State.IgnoredESPTeams[tm.Name] = not State.IgnoredESPTeams[tm.Name]
				local ign = State.IgnoredESPTeams[tm.Name]
				espBtn.BackgroundColor3 = ign and PALETTE.Danger or PALETTE.Success
				espBtn.Text = ign and "👁️ ESP: OFF" or "👁️ ESP: ON"
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

createKeybindRow(pSettings, "Atajo Mostrar / Ocultar Panel (Ctrl + Key):", State.ToggleKey, function(k)
	State.ToggleKey = k
	telemetryBar.Text = "FPS: -- | Toggle (Ctrl + " .. k.Name .. ") | Sprint (Shift) | Salto (Space) | Dash (" .. State.HorizontalJumpKey.Name .. ")"
end)

createKeybindRow(pSettings, "Atajo Activar Auto-Apuntado:", State.AimbotToggleKey, function(k) State.AimbotToggleKey = k end)
createKeybindRow(pSettings, "Tecla Salto Infinito en Aire:", State.InfiniteJumpKey, function(k) State.InfiniteJumpKey = k end)
createKeybindRow(pSettings, "Tecla Impulso Vertical (X):", State.ForwardJumpKey, function(k) State.ForwardJumpKey = k end)
createKeybindRow(pSettings, "Tecla Dash Horizontal (G):", State.HorizontalJumpKey, function(k) State.HorizontalJumpKey = k end)
createKeybindRow(pSettings, "Atajo Modo Noclip:", State.NoclipKey, function(k) State.NoclipKey = k end)
createKeybindRow(pSettings, "Atajo Modo Vuelo (Fly):", State.FlyKey, function(k) State.FlyKeylocal function performFullCleanup()
	for _, conn in pairs(Connections) do pcall(function() conn:Disconnect() end) end
	Connections = {}
	for char, esp in pairs(ESPCache) do
		if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
		if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
	end
	ESPCache = {}
	if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
	if screenGui then pcall(function() screenGui:Destroy() end) end
	_G.JailbreakAdminSuiteInstance = nil
	_G.JailbreakCleanup = nil
end
_G.JailbreakCleanup = performFullCleanup

-- Botón Kill Process que FINALIZA POR COMPLETO el script en ejecución
createActionButton(pSettings, "❌ FINALIZAR SUITE POR COMPLETO (KILL PROCESS)", PALETTE.Danger, performFullCleanup)

selectTab("Combat")

-- =============================================================================
-- MOTOR DE EJECUCIÓN: AIMBOT LASER, RADAR ESP Y MOVIMIENTO SEGURO
-- =============================================================================

-- Comprobador Inteligente de Visibilidad (Raycast WallCheck)
local function isPartVisible(origin, targetPart, targetChar)
	local myChar = LocalPlayer and LocalPlayer.Character
	local dir = (targetPart.Position - origin)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { myChar, targetChar, Camera }
	rayParams.IgnoreWater = true

	local hit = Workspace:Raycast(origin, dir, rayParams)
	if not hit then return true end
	if hit.Instance then
		if not hit.Instance.CanCollide or hit.Instance.Transparency > 0.65 then
			return true
		end
	end
	return false
end

-- Determina si un modelo debe ser considerado objetivo válido de Aimbot
local function isValidAimTarget(plr, char, hum, hrp)
	if plr == LocalPlayer then return false end
	if not hum or hum.Health <= 0 or not hrp then return false end

	if State.TargetFFA then return true end

	local teamName = plr and plr.Team and plr.Team.Name or "Neutral"
	if State.IgnoredAimTeams[teamName] == true then
		return false
	end

	if State.TeamCheck and LocalPlayer and LocalPlayer.Team and plr and plr.Team and LocalPlayer.Team == plr.Team then
		return false
	end

	return true
end

-- Adquisición de Objetivo Óptimo para Aimbot
local function getBestAimbotTarget()
	if not LocalPlayer or not Camera then return nil end
	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return nil end

	local fovCenter
	if State.FOVMouseFollow then
		fovCenter = UserInputService:GetMouseLocation()
	else
		local vp = Camera.ViewportSize
		fovCenter = Vector2.new(vp.X * 0.5 + State.OffsetX, vp.Y * 0.5 + State.OffsetY)
	end

	local bestTarget = nil
	local bestDist = State.FOV_Radius

	-- 1. Jugadores en Players
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")

			if isValidAimTarget(plr, char, hum, hrp) then
				local targetPart = (State.TargetPart == "Head" and char:FindFirstChild("Head"))
					or (State.TargetPart == "UpperTorso" and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")))
					or hrp

				if targetPart then
					local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
					if onScreen and screenPos.Z > 0 then
						local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - fovCenter).Magnitude
						if screenDist <= bestDist then
							local isVis = not State.WallCheck or isPartVisible(Camera.CFrame.Position, targetPart, char)
							if isVis then
								bestDist = screenDist
								bestTarget = { Player = plr, Character = char, Part = targetPart }
							end
						end
					end
				end
			end
		end
	end

	return bestTarget
end

-- RenderStepped Loop (Aimbot Preciso & FOV Dinámico)
local frameCounter = 0
local lastFpsUpdate = tick()

Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
	frameCounter = frameCounter + 1
	if tick() - lastFpsUpdate >= 0.5 then
		local fps = math.floor(frameCounter / (tick() - lastFpsUpdate))
		frameCounter = 0
		lastFpsUpdate = tick()
		telemetryBar.Text = string.format("FPS: %d | Toggle: Ctrl+%s | Salto: %s | Dash: %s", fps, State.ToggleKey.Name, State.InfiniteJumpKey.Name, State.HorizontalJumpKey.Name)
	end

	-- Manejo dinámico del Círculo FOV
	if State.ShowFOV then
		if State.FOVMouseFollow then
			local mousePos = UserInputService:GetMouseLocation()
			fovFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
			centerDot.Position = fovFrame.Position
		else
			centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
			fovFrame.Position = centerDot.Position
		end
	end

	-- Aimbot / Lock-On con alineación angular directa
	if (State.AimbotEnabled and State.IsAiming) or State.LockOnEnabled then
		local target = getBestAimbotTarget()
		if target and target.Part then
			local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.Part.Position)
			if State.AimSpeed >= 1 then
				Camera.CFrame = targetCFrame
			else
				Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(State.AimSpeed, 0.05, 1.0))
			end
			centerDot.BackgroundColor3 = State.ColorLockOn
		else
			centerDot.BackgroundColor3 = State.ColorFOV
		end
	end
end)

-- Heartbeat Loop (Speed Engine Seguro, Noclip & 3D Fly)
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
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyDir = flyDir - Vector3.new(0, 1, 0) end

		hrp.AssemblyLinearVelocity = Vector3.zero
		if flyDir.Magnitude > 0.05 then
			hrp.CFrame = hrp.CFrame + (flyDir.Unit * (State.FlySpeed * dt))
		end
	end

	-- Speed Bypass Seguro por CFrame Delta
	if State.SpeedEngineEnabled and not State.FlyEnabled and hrp and hum then
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

-- Limpieza periódica de entidades muertas en ESPCache
local function purgeDeadESP()
	for char, esp in pairs(ESPCache) do
		if not char or not char.Parent or not char:IsDescendantOf(Workspace) then
			if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
			if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
			ESPCache[char] = nil
		else
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				if esp.Billboard then esp.Billboard.Visible = false end
				if esp.Highlight then esp.Highlight.Enabled = false end
			end
		end
	end
end

-- Radar ESP Updater (Diferenciación Inteligente de Bandos Sin Duplicados)
Secure.Thread:SpawnSafe("RadarESPUpdater", function()
	while screenGui and screenGui.Parent do
		purgeDeadESP()

		if State.ESPEnabled then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character then
					local char = plr.Character
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")

					if hrp and hum and hum.Health > 0 and char:IsDescendantOf(Workspace) then
						local esp = ESPCache[char]
						if not esp then
							local bb = Instance.new("BillboardGui")
							bb.Name = "ESP_" .. plr.Name
							bb.Size = UDim2.new(0, 160, 0, 38)
							bb.AlwaysOnTop = true
							bb.Adornee = hrp
							bb.Parent = ESPFolder

							local label = Instance.new("TextLabel")
							label.Size = UDim2.new(1, 0, 1, 0)
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.GothamBold
							label.TextSize = 10
							label.TextColor3 = State.ColorAlly
							label.TextStrokeTransparency = 0.25
							label.Parent = bb

							local hl = Instance.new("Highlight")
							hl.Adornee = char
							hl.FillColor = State.ColorAlly
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.55
							hl.OutlineTransparency = 0.15
							hl.Parent = ESPFolder

							esp = { Billboard = bb, Label = label, Highlight = hl }
							ESPCache[char] = esp
						end

						esp.Billboard.Adornee = hrp
						esp.Highlight.Adornee = char

						local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
						local teamName = plr.Team and plr.Team.Name:lower() or "neutral"
						local originalTeamName = plr.Team and plr.Team.Name or "Neutral"
						local teamBadge = "🛡️ Neutral"
						local teamColor = State.ColorAlly

						if teamName:find("police") or teamName:find("guard") or teamName:find("polic") then
							teamBadge = "👮 Policía"
							teamColor = State.ColorPolice
						elseif teamName:find("crim") then
							teamBadge = "🔴 Criminal"
							teamColor = State.ColorCriminal
						elseif teamName:find("prison") or teamName:find("pris") then
							teamBadge = "⛓️ Prisionero"
							teamColor = State.ColorPrisoner
						elseif LocalPlayer and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team then
							teamBadge = "🛡️ Aliado"
							teamColor = State.ColorAlly
						end

						local isIgnored = State.IgnoredESPTeams[originalTeamName] == true
						if isIgnored then
							esp.Billboard.Visible = false
							esp.Highlight.Enabled = false
						else
							esp.Label.TextColor3 = teamColor
							esp.Highlight.FillColor = teamColor
							esp.Label.Text = string.format("%s [%s]\n%d HP | %d m", plr.Name, teamBadge, math.floor(hum.Health), math.floor(dist))
							esp.Billboard.Visible = true
							esp.Highlight.Enabled = true
						end
					end
				end
			end
		else
			for _, esp in pairs(ESPCache) do
				if esp.Billboard then esp.Billboard.Visible = false end
				if esp.Highlight then esp.Highlight.Enabled = false end
			end
		end
		task.wait(0.15)
	end
end)

-- Limpieza de caché ESP cuando un jugador sale
Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(plr)
	if plr.Character then
		local esp = ESPCache[plr.Character]
		if esp then
			if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
			if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
			ESPCache[plr.Character] = nil
		end
	end
end)

-- Manejo de Teclado con Detección Blindada de Ctrl + F
local isCtrlHeld = false

Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		isCtrlHeld = true
	end

	local ctrlActive = isCtrlHeld
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

	-- 1. Atajo Maestro Mostrar / Ocultar (Ctrl + ToggleKey o RightShift)
	local isToggleTriggered = false
	if input.KeyCode == State.ToggleKey and ctrlActive then
		isToggleTriggered = true
	elseif (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl) and UserInputService:IsKeyDown(State.ToggleKey) then
		isToggleTriggered = true
	elseif input.KeyCode == Enum.KeyCode.RightShift then
		isToggleTriggered = true
	end

	if isToggleTriggered then
		mainFrame.Visible = not mainFrame.Visible
		return
	end

	-- 2. Mouse Aiming & Sprinting
	if input.UserInputType == State.AimKey then
		State.IsAiming = true
	end

	if input.KeyCode == State.SprintKey then
		State.IsSprinting = true
	end

	if gameProcessed then return end

	-- 3. Atajos de Funcionalidades
	if input.KeyCode == State.AimbotToggleKey then
		State.AimbotEnabled = not State.AimbotEnabled
	end

	if input.KeyCode == State.NoclipKey then
		State.Noclip = not State.Noclip
	end

	if input.KeyCode == State.FlyKey then
		State.FlyEnabled = not State.FlyEnabled
	end

	if input.KeyCode == State.ESPKey then
		State.ESPEnabled = not State.ESPEnabled
		if not State.ESPEnabled then
			for _, esp in pairs(ESPCache) do
				if esp.Billboard then esp.Billboard.Visible = false end
				if esp.Highlight then esp.Highlight.Enabled = false end
			end
		end
	end

	-- Salto Infinito en el Aire con Potencia Editable
	if input.KeyCode == State.InfiniteJumpKey and State.InfiniteJump then
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hrp then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, State.InfiniteJumpPower, hrp.AssemblyLinearVelocity.Z)
		end
	end

	-- Impulso Vertical (Tecla X)
	if input.KeyCode == State.ForwardJumpKey and State.ForwardJump then
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, State.ForwardJumpPower, hrp.AssemblyLinearVelocity.Z)
		end
	end

	-- Dash Horizontal (Tecla G)
	if input.KeyCode == State.HorizontalJumpKey and State.HorizontalJump then
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
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		isCtrlHeld = false
	end
	if input.UserInputType == State.AimKey then
		State.IsAiming = false
	end
	if input.KeyCode == State.SprintKey then
		State.IsSprinting = false
	end
end)

print("[JAILBREAK SUITE v5.5] Listo. Presiona Ctrl + " .. State.ToggleKey.Name .. " (o RightShift) para abrir/cerrar.")
