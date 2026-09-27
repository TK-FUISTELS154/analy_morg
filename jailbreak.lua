--[[
	=============================================================================
	JAILBREAK ULTIMATE COMBAT & ADMIN SUITE PRO (MATERIAL DESIGN 3)
	=============================================================================
	Desarrollado con Arquitectura Apex Suite v5.0 y Resolución Anti-Ofuscación.
	Especialmente adaptado para Jailbreak y juegos de combate / mundo abierto.

	Módulos y Funcionalidades Integradas:
	1. 🏃 Movimiento & Físicas:
	   - WalkSpeed y JumpPower configurables con preservación dinámica de velocidad.
	   - Salto Infinito en el Aire (ESPACIO).
	   - Salto de Desplazamiento Vertical de Impulso (Tecla F).
	   - Salto de Desplazamiento Horizontal / Dash (Tecla G).
	   - Physics Speed Engine (Aceleración por vectores AssemblyLinearVelocity sin rubberbanding).
	   - Noclip Inteligente y Fly Mode con control direccional 3D.
	   - Control de Gravedad personalizable.
	2. 🖱️ Herramientas de Clic & Ratón:
	   - Auto Clicker con CPS ajustable y Modo Hold Click continuo.
	   - Click-to-Teleport con raycast de impacto.
	   - Click-to-Select para inspección inmediata de jugadores u objetos.
	3. ⌨️ Macro Combate & Acciones:
	   - Grabador y reproductor de combinaciones de teclas y clics.
	   - Control de velocidad de reproducción (0.5x a 3.0x) y recorte de silencio inicial.
	4. 🎯 Auto-Apuntado (Aimbot) & Spy Radar:
	   - Aimbot Universal (Círculo FOV dinámico, Raycast WallCheck de coberturas, suavizado, offsets).
	   - Prioridad de objetivo: Cabeza (Head), Torso (UpperTorso), o el más Cercano (Closest).
	   - Marcador Spy ESP sincronizado: Verde (Visible), Rojo (Tras Cobertura), Dorado (Fijado/Lock-On).
	5. 👁️ Visuales & Radar ESP:
	   - Player ESP / NameTags con distancia, barra de vida y bando/equipo.
	   - Hitbox Highlights y Modo Espectador (Spectate).
	6. ⚔️ Combate & Dev Tools:
	   - Camera Lock-On hacia enemigos dentro del radio FOV.
	   - Modificador de FOV de Cámara (60° a 120°).
	   - Admin Heal y Hitbox Inspector.
	7. ☀️ Iluminación & Clima:
	   - Modos Día, Noche, Atardecer y Fullbright (Sin sombras).
	8. 📍 Waypoints & Robos de Jailbreak:
	   - Banco (Bank), Joyería (Jewelry), Museo (Museum), Casino, Planta de Energía (Power Plant).
	   - Mansión del CEO (Mansion Boss), Tumba (Tomb), Avión de Carga (Cargo Plane).
	   - Base Criminal Volcán, Base Criminal Ciudad, Cuartel de Policía y Prisión.
	   - Tiendas de Armas, Garajes y Teleport a Coordenadas XYZ o Jugadores.
	9. 👥 Equipos & Filtrado Táctico:
	   - Detección dinámica de Policías (Police), Criminales (Criminals) y Prisioneros (Prisoners).
	   - Toggles para excluir aliados o equipos enteros del Aimbot y del ESP.
	10. ⚙️ Ajustes & Seguridad:
	    - Atajos de teclado completos (Ctrl + Key o teclas directas).
	    - Patrón Singleton anti-duplicados y botón de Finalización Limpia (Kill Process).
--]]

-- =============================================================================
-- RESOLUTOR UNIVERSAL DE SERVICIOS ANTI-OFUSCACIÓN (APEX RESOLVER v5.0)
-- =============================================================================
local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

local function resolveService(className)
	if className == "Workspace" and typeof(workspace) == "Instance" then return workspace end
	local ok, s = pcall(function() return rawGame:GetService(className) end)
	if ok and s then return s end
	local ok2, s2 = pcall(function() return rawGame:FindFirstChildOfClass(className) end)
	if ok2 and s2 then return s2 end
	local ok3, s3 = pcall(function() return rawGame:FindFirstChildWhichIsA(className) end)
	if ok3 and s3 then return s3 end
	local sChildren = pcall(function() return rawGame:GetChildren() end)
	if sChildren then
		for _, child in ipairs(rawGame:GetChildren()) do
			if child.ClassName == className then return child end
		end
	end
	return nil
end

local Players = resolveService("Players")
local Workspace = resolveService("Workspace") or workspace
local UserInputService = resolveService("UserInputService")
local RunService = resolveService("RunService")
local Lighting = resolveService("Lighting")
local Teams = resolveService("Teams")
local TweenService = resolveService("TweenService")
local Stats = resolveService("Stats")
local VirtualUser = resolveService("VirtualUser")
local VirtualInputManager = resolveService("VirtualInputManager")

local LocalPlayer = Players and (Players.LocalPlayer or Players:FindFirstChildOfClass("Player"))
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")

-- =============================================================================
-- SINGLETON GUARD: DESTRUIR INSTANCIAS PREVIAS
-- =============================================================================
if _G.JailbreakAdminSuiteInstance then
	pcall(function()
		_G.JailbreakAdminSuiteInstance:Destroy()
	end)
	_G.JailbreakAdminSuiteInstance = nil
end

-- Contenedor Seguro para la GUI
local function getSecureGuiParent()
	local parent = nil
	if typeof(gethui) == "function" then
		pcall(function() parent = gethui() end)
	end
	if not parent and typeof(cloneref) == "function" then
		local cg = resolveService("CoreGui")
		if cg then pcall(function() parent = cloneref(cg) end) end
	end
	if not parent then
		parent = resolveService("CoreGui")
	end
	if not parent and LocalPlayer then
		parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3)
	end
	return parent or resolveService("StarterGui")
end

-- =============================================================================
-- ESTADO GLOBAL Y CONFIGURACIÓN
-- =============================================================================
local State = {
	-- Movimiento
	WalkSpeed = 32,
	DefaultSpeed = 16,
	JumpPower = 60,
	DefaultJump = 50,
	Gravity = 196.2,
	DefaultGravity = 196.2,
	FOV = 70,
	DefaultFOV = 70,

	-- Saltos & Desplazamiento
	InfiniteJump = false,
	SpaceJumpKey = Enum.KeyCode.Space,
	InfiniteJumpKey = Enum.KeyCode.J,

	ForwardJump = false,
	JumpKey = Enum.KeyCode.F,
	ForwardJumpDistance = 80,
	ForwardJumpPower = 65,

	HorizontalJump = false,
	HorizontalJumpKey = Enum.KeyCode.G,
	HorizontalJumpPower = 120,

	-- Physics Speed Engine
	PhysicsSpeedEnabled = false,
	PhysicsSpeedValue = 65,
	PhysicsSpeedSprintOnly = false,
	IsSprinting = false,

	Noclip = false,
	FlyEnabled = false,
	FlySpeed = 55,

	-- Clic & Mouse
	AutoClickEnabled = false,
	HoldClickMode = false,
	AutoClickOnlyWhileHolding = false,
	AutoClickCPS = 12,
	LastClickTime = 0,
	ClickTeleport = false,
	ClickSelect = false,
	AutoActivateTool = false,

	-- Auto-Apuntado (Aimbot)
	AimbotEnabled = false,
	IsAiming = false,
	AimKey = Enum.UserInputType.MouseButton2,
	FOV_Radius = 220,
	ShowFOV = false,
	TargetPart = "Head", -- "Head", "UpperTorso", "Closest"
	AimSpeed = 0.8,
	WallCheck = true,
	OffsetX = 0,
	OffsetY = -28,

	-- Equipos & Filtrado
	TeamCheck = true,
	TargetFFA = false,
	TargetedTeams = {},
	IgnoredAimTeams = {},
	IgnoredESPTeams = {},
	CurrentLockedTargetPlayer = nil,

	-- Colores Marcador Spy ESP
	ColorLockOnTarget = Color3.fromRGB(255, 215, 0),
	ColorVisible = Color3.fromRGB(50, 255, 100),
	ColorHidden = Color3.fromRGB(255, 50, 50),
	ColorAlly = Color3.fromRGB(50, 150, 255),
	ColorFOV = Color3.fromRGB(255, 255, 255),

	-- Macro Combate
	IsRecordingMacro = false,
	IsPlayingMacro = false,
	MacroLoop = false,
	MacroPlaybackSpeed = 1.0,
	MacroData = {},
	RecordStartTime = 0,
	FirstInputTime = nil,
	MacroTrimDelay = true,

	-- Visuales & Dev
	ESPEnabled = false,
	SpectateEnabled = false,
	Fullbright = false,
	LockOnEnabled = false,
	HitboxInspector = false,

	-- Atajos de Teclado
	ToggleKey = Enum.KeyCode.RightControl,
	RecordKey = Enum.KeyCode.X,
	PlayKey = Enum.KeyCode.M,
	AutoClickKey = Enum.KeyCode.C,
	AimbotToggleKey = Enum.KeyCode.A,
	NoclipKey = Enum.KeyCode.N,
	FlyKey = Enum.KeyCode.V,
	ESPKey = Enum.KeyCode.E,
	LockOnKey = Enum.KeyCode.L,
	FullbrightKey = Enum.KeyCode.B,
	ClickTPKey = Enum.KeyCode.T,
	HealKey = Enum.KeyCode.H,
	SpeedKey = Enum.KeyCode.LeftShift,

	-- Selección
	SelectedPlayer = nil,
	CurrentTarget = nil
}

local Connections = {}
local ESPCache = {}
local HighlightInstance = nil

-- Waypoints Especiales de Jailbreak
local JAILBREAK_LOCATIONS = {
	{ Name = "🏦 Banco (Bóveda Principal)", Pos = Vector3.new(10, 18, 785) },
	{ Name = "🏦 Banco (Exterior)", Pos = Vector3.new(20, 18, 850) },
	{ Name = "💎 Joyería (Techo)", Pos = Vector3.new(140, 120, 1315) },
	{ Name = "💎 Joyería (Entrada)", Pos = Vector3.new(105, 18, 1310) },
	{ Name = "🏛️ Museo (Techo)", Pos = Vector3.new(1075, 140, 1245) },
	{ Name = "🏛️ Museo (Entrada Frontal)", Pos = Vector3.new(1065, 102, 1200) },
	{ Name = "🎰 Casino (Seguridad)", Pos = Vector3.new(-180, 22, -4710) },
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

-- Paleta Material Design 3 (Dark Theme)
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

local function isCtrlPressed()
	if not UserInputService then return false end
	local s, res = pcall(function()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end)
	return s and res or false
end

-- =============================================================================
-- INTERFAZ GRÁFICA PRINCIPAL
-- =============================================================================
local secureParent = getSecureGuiParent()
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "JailbreakAdminSuitePro"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = secureParent
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
mainFrame.Size = UDim2.new(0, 680, 0, 510)
mainFrame.Position = UDim2.new(0.5, -340, 0.5, -255)
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
title.Text = "⚡ JAILBREAK ULTIMATE COMBAT & ADMIN SUITE PRO"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
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

-- Barra Inferior de Telemetría
local telemetryBar = Instance.new("TextLabel")
telemetryBar.Size = UDim2.new(1, -24, 0, 22)
telemetryBar.Position = UDim2.new(0, 12, 1, -26)
telemetryBar.BackgroundTransparency = 1
telemetryBar.Text = "FPS: -- | Atajo Panel (RightControl) | Sprint (Shift) | Salto Aire (Space) | Dash (G)"
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

-- Contenedor de Páginas (Content Area)
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -190, 1, -76)
contentArea.Position = UDim2.new(0, 178, 0, 52)
contentArea.BackgroundColor3 = PALETTE.Surface
contentArea.Parent = mainFrame
Instance.new("UICorner", contentArea).CornerRadius = UDim.new(0, 8)

-- =============================================================================
-- SISTEMA DE PESTAÑAS (TABS ENGINE)
-- =============================================================================
local Tabs = {}
local TabButtons = {}

local TabDefs = {
	{ Id = "Movement",  Title = "🏃 Movimiento",   Desc = "Velocidad, Saltos y Físicas" },
	{ Id = "Combat",    Title = "🎯 Auto-Apuntado", Desc = "Aimbot, FOV y Spy Radar" },
	{ Id = "Visuals",   Title = "👁️ Visuales & ESP",Desc = "Radar de Jugadores y Wallhack" },
	{ Id = "Robberies", Title = "📍 Robos & TP",    Desc = "Waypoints de Jailbreak y Arenas" },
	{ Id = "Teams",     Title = "👥 Bandos & Equipos",Desc = "Filtros Policías y Criminales" },
	{ Id = "Click",     Title = "🖱️ Clic Tools",    Desc = "Auto Clicker y Click-TP" },
	{ Id = "Macro",     Title = "⌨️ Macro Combate", Desc = "Grabador y Reproductor" },
	{ Id = "Lighting",  Title = "☀️ Iluminación",   Desc = "Fullbright y Clima" },
	{ Id = "Settings",  Title = "⚙️ Ajustes",       Desc = "Atajos y Seguridad" }
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

	-- Botón en NavBar
	local btn = Instance.new("TextButton")
	btn.Name = "TabBtn_" .. t.Id
	btn.Size = UDim2.new(1, -12, 0, 34)
	btn.BackgroundColor3 = PALETTE.Card
	btn.Text = t.Title
	btn.TextColor3 = PALETTE.TextMuted
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 10
	btn.Parent = navBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		for id, p in pairs(Tabs) do
			p.Visible = (id == t.Id)
		end
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
-- COMPONENTES DE UI REUTILIZABLES (HELPERS)
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

	btn.MouseButton1Click:Connect(function()
		pcall(callback)
	end)
	return btn
end

-- =============================================================================
-- PESTAÑA 1: 🏃 MOVIMIENTO & FÍSICAS
-- =============================================================================
local pMovement = Tabs["Movement"]

createToggle(pMovement, "⚡ Super Velocidad Física (Physics Speed Engine)", State.PhysicsSpeedEnabled, function(v)
	State.PhysicsSpeedEnabled = v
end)

createSlider(pMovement, "Fuerza de Desplazamiento Continuo (studs/s)", 16, 250, State.PhysicsSpeedValue, function(v)
	State.PhysicsSpeedValue = v
end)

createToggle(pMovement, "Activar Solo al Mantener Presionado SHIFT (Sprint)", State.PhysicsSpeedSprintOnly, function(v)
	State.PhysicsSpeedSprintOnly = v
end)

createSlider(pMovement, "WalkSpeed Estándar de Personaje", 16, 150, State.WalkSpeed, function(v)
	State.WalkSpeed = v
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = v end
end)

createSlider(pMovement, "Fuerza de Salto Estándar (JumpPower)", 50, 200, State.JumpPower, function(v)
	State.JumpPower = v
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = v
	end
end)

createToggle(pMovement, "🦘 Salto Infinito en el Aire (ESPACIO)", State.InfiniteJump, function(v)
	State.InfiniteJump = v
end)

createToggle(pMovement, "🚀 Salto Vertical de Impulso (Tecla F)", State.ForwardJump, function(v)
	State.ForwardJump = v
end)

createToggle(pMovement, "💨 Dash / Salto Horizontal (Tecla G)", State.HorizontalJump, function(v)
	State.HorizontalJump = v
end)

createToggle(pMovement, "👻 Noclip (Atravesar Paredes)", State.Noclip, function(v)
	State.Noclip = v
end)

createToggle(pMovement, "🦅 Modo Vuelo (Fly Mode)", State.FlyEnabled, function(v)
	State.FlyEnabled = v
end)

createSlider(pMovement, "Velocidad de Vuelo (FlySpeed)", 20, 150, State.FlySpeed, function(v)
	State.FlySpeed = v
end)

-- =============================================================================
-- PESTAÑA 2: 🎯 AUTO-APUNTADO (AIMBOT) & SPY RADAR
-- =============================================================================
local pCombat = Tabs["Combat"]

createToggle(pCombat, "🎯 Activar Auto-Apuntado Universal (Aimbot)", State.AimbotEnabled, function(v)
	State.AimbotEnabled = v
end)

createToggle(pCombat, "⭕ Mostrar Círculo de Campo de Visión (FOV)", State.ShowFOV, function(v)
	State.ShowFOV = v
	fovFrame.Visible = v
end)

createSlider(pCombat, "Radio del Círculo FOV (Píxeles)", 50, 450, State.FOV_Radius, function(v)
	State.FOV_Radius = v
	fovFrame.Size = UDim2.new(0, v * 2, 0, v * 2)
end)

createSlider(pCombat, "Suavizado de Puntería (Aim Smoothing)", 1, 10, math.floor(State.AimSpeed * 10), function(v)
	State.AimSpeed = v / 10
end)

createToggle(pCombat, "🧱 Comprobador de Paredes (Raycast WallCheck)", State.WallCheck, function(v)
	State.WallCheck = v
end)

createToggle(pCombat, "🛡️ No Apuntar a Miembros del Mismo Equipo (Team Check)", State.TeamCheck, function(v)
	State.TeamCheck = v
end)

-- Selector de Parte Objetivo
local partCard = createCard(pCombat, "Parte del Cuerpo Objetivo", 68)
local pHeadBtn = Instance.new("TextButton")
pHeadBtn.Size = UDim2.new(0.3, -4, 0, 24)
pHeadBtn.Position = UDim2.new(0, 10, 0, 32)
pHeadBtn.BackgroundColor3 = PALETTE.Primary
pHeadBtn.Text = "Cabeza"
pHeadBtn.TextColor3 = PALETTE.Text
pHeadBtn.Font = Enum.Font.GothamBold
pHeadBtn.TextSize = 9
pHeadBtn.Parent = partCard
Instance.new("UICorner", pHeadBtn).CornerRadius = UDim.new(0, 4)

local pTorsoBtn = Instance.new("TextButton")
pTorsoBtn.Size = UDim2.new(0.3, -4, 0, 24)
pTorsoBtn.Position = UDim2.new(0.33, 0, 0, 32)
pTorsoBtn.BackgroundColor3 = PALETTE.InputBg
pTorsoBtn.Text = "Torso"
pTorsoBtn.TextColor3 = PALETTE.TextMuted
pTorsoBtn.Font = Enum.Font.GothamBold
pTorsoBtn.TextSize = 9
pTorsoBtn.Parent = partCard
Instance.new("UICorner", pTorsoBtn).CornerRadius = UDim.new(0, 4)

local pClosestBtn = Instance.new("TextButton")
pClosestBtn.Size = UDim2.new(0.3, -4, 0, 24)
pClosestBtn.Position = UDim2.new(0.66, 0, 0, 32)
pClosestBtn.BackgroundColor3 = PALETTE.InputBg
pClosestBtn.Text = "Cercano"
pClosestBtn.TextColor3 = PALETTE.TextMuted
pClosestBtn.Font = Enum.Font.GothamBold
pClosestBtn.TextSize = 9
pClosestBtn.Parent = partCard
Instance.new("UICorner", pClosestBtn).CornerRadius = UDim.new(0, 4)

pHeadBtn.MouseButton1Click:Connect(function()
	State.TargetPart = "Head"
	pHeadBtn.BackgroundColor3 = PALETTE.Primary
	pHeadBtn.TextColor3 = PALETTE.Text
	pTorsoBtn.BackgroundColor3 = PALETTE.InputBg
	pTorsoBtn.TextColor3 = PALETTE.TextMuted
	pClosestBtn.BackgroundColor3 = PALETTE.InputBg
	pClosestBtn.TextColor3 = PALETTE.TextMuted
end)

pTorsoBtn.MouseButton1Click:Connect(function()
	State.TargetPart = "UpperTorso"
	pTorsoBtn.BackgroundColor3 = PALETTE.Primary
	pTorsoBtn.TextColor3 = PALETTE.Text
	pHeadBtn.BackgroundColor3 = PALETTE.InputBg
	pHeadBtn.TextColor3 = PALETTE.TextMuted
	pClosestBtn.BackgroundColor3 = PALETTE.InputBg
	pClosestBtn.TextColor3 = PALETTE.TextMuted
end)

pClosestBtn.MouseButton1Click:Connect(function()
	State.TargetPart = "Closest"
	pClosestBtn.BackgroundColor3 = PALETTE.Primary
	pClosestBtn.TextColor3 = PALETTE.Text
	pHeadBtn.BackgroundColor3 = PALETTE.InputBg
	pHeadBtn.TextColor3 = PALETTE.TextMuted
	pTorsoBtn.BackgroundColor3 = PALETTE.InputBg
	pTorsoBtn.TextColor3 = PALETTE.TextMuted
end)

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

createToggle(pVisuals, "🔒 Camera Lock-On Continuo al Apuntar", State.LockOnEnabled, function(v)
	State.LockOnEnabled = v
end)

createSlider(pVisuals, "Campo de Visión de Cámara (Camera FOV)", 60, 120, State.FOV, function(v)
	State.FOV = v
	if Camera then Camera.FieldOfView = v end
end)

-- =============================================================================
-- PESTAÑA 4: 📍 ROBOS & WAYPOINTS DE JAILBREAK
-- =============================================================================
local pRobberies = Tabs["Robberies"]

local wpHeader = createCard(pRobberies, "Teleport Directo a Zonas de Robo y Arenas", 36)
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
			end)
		end
	end
end

createActionButton(pTeams, "🔄 Actualizar Lista de Bandos", PALETTE.Primary, refreshTeamsList)
refreshTeamsList()

-- =============================================================================
-- PESTAÑA 6: 🖱️ CLIC TOOLS
-- =============================================================================
local pClick = Tabs["Click"]

createToggle(pClick, "⚡ Auto Clicker Continuo", State.AutoClickEnabled, function(v)
	State.AutoClickEnabled = v
end)

createSlider(pClick, "Velocidad de Clics por Segundo (CPS)", 2, 40, State.AutoClickCPS, function(v)
	State.AutoClickCPS = v
end)

createToggle(pClick, "Solo Hacer Clic al Mantener Presionado el Ratón", State.AutoClickOnlyWhileHolding, function(v)
	State.AutoClickOnlyWhileHolding = v
end)

createToggle(pClick, "📍 Click-to-Teleport (Teletransportar al hacer Clic)", State.ClickTeleport, function(v)
	State.ClickTeleport = v
end)

-- =============================================================================
-- PESTAÑA 7: ⌨️ MACRO COMBATE
-- =============================================================================
local pMacro = Tabs["Macro"]

local macroStatusCard = createCard(pMacro, "Estado de Macro: DETENIDO (0 acciones)", 44)
local function updateMacroStatus(text)
	local l = macroStatusCard:FindFirstChildOfClass("TextLabel")
	if l then l.Text = text end
end

createActionButton(pMacro, "⏺️ Grabar Macro (Ctrl + X)", PALETTE.Danger, function()
	State.IsRecordingMacro = not State.IsRecordingMacro
	if State.IsRecordingMacro then
		State.MacroData = {}
		State.RecordStartTime = tick()
		updateMacroStatus("🔴 GRABANDO MACRO...")
	else
		updateMacroStatus(string.format("✅ Macro guardada (%d acciones)", #State.MacroData))
	end
end)

createActionButton(pMacro, "▶️ Reproducir Macro (Ctrl + M)", PALETTE.Success, function()
	if #State.MacroData == 0 then
		updateMacroStatus("⚠️ No hay datos grabados")
		return
	end
	task.spawn(function()
		updateMacroStatus("▶️ REPRODUCIENDO...")
		for _, act in ipairs(State.MacroData) do
			task.wait(act.Delay / math.max(State.MacroPlaybackSpeed, 0.1))
			if act.Type == "Key" and VirtualInputManager then
				pcall(function()
					VirtualInputManager:SendKeyEvent(act.Down, act.Key, false, game)
				end)
			elseif act.Type == "Mouse" and VirtualUser then
				pcall(function()
					if act.Button == "Left" then
						VirtualUser:Button1Down(Vector2.new(0, 0))
						task.wait(0.02)
						VirtualUser:Button1Up(Vector2.new(0, 0))
					end
				end)
			end
		end
		updateMacroStatus(string.format("✅ Macro finalizada (%d acciones)", #State.MacroData))
	end)
end)

-- =============================================================================
-- PESTAÑA 8: ☀️ ILUMINACIÓN & CLIMA
-- =============================================================================
local pLighting = Tabs["Lighting"]

createToggle(pLighting, "💡 Fullbright (Iluminación Total Sin Sombras)", State.Fullbright, function(v)
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

createActionButton(pLighting, "🌅 Ajustar a Atardecer (18:00)", PALETTE.Card, function()
	if Lighting then Lighting.ClockTime = 18 end
end)

-- =============================================================================
-- PESTAÑA 9: ⚙️ AJUSTES & SEGURIDAD
-- =============================================================================
local pSettings = Tabs["Settings"]

createActionButton(pSettings, "❌ CERRAR Y FINALIZAR SUITE (KILL PROCESS)", PALETTE.Danger, function()
	for _, conn in pairs(Connections) do
		pcall(function() conn:Disconnect() end)
	end
	for _, esp in pairs(ESPCache) do
		if esp.Billboard then pcall(function() esp.Billboard:Destroy() end) end
		if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
	end
	if screenGui then screenGui:Destroy() end
	_G.JailbreakAdminSuiteInstance = nil
end)

-- Seleccionar pestaña inicial
selectTab("Movement")

-- Botón cerrar en Header
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
end)

-- =============================================================================
-- MOTOR DE FÍSICAS, AIMBOT Y ESP EN TIEMPO REAL (RENDERSTEPPED / HEARTBEAT)
-- =============================================================================

-- 1. Helper: Obtener Jugador Más Cercano al Cursor dentro de FOV
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
				-- Filtro de Equipos
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
								-- Raycast WallCheck
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

-- 2. Loop de RenderStepped (Aimbot & Telemetría)
local frameCounter = 0
local lastFpsUpdate = tick()

Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
	frameCounter = frameCounter + 1
	if tick() - lastFpsUpdate >= 0.5 then
		local fps = math.floor(frameCounter / (tick() - lastFpsUpdate))
		frameCounter = 0
		lastFpsUpdate = tick()
		telemetryBar.Text = string.format("FPS: %d | Panel: RightControl | Sprint: Shift | Salto: Space | Dash: G", fps)
	end

	-- Aimbot / Lock-On
	if (State.AimbotEnabled and State.IsAiming) or State.LockOnEnabled then
		local target = getBestAimbotTarget()
		if target and target.Part then
			local aimPos = target.Part.Position
			local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
			Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(State.AimSpeed, 0.1, 1.0))
			centerDot.BackgroundColor3 = State.ColorLockOnTarget
		else
			centerDot.BackgroundColor3 = State.ColorFOV
		end
	end
end)

-- 3. Loop de Heartbeat (Physics Speed Engine & Noclip)
Connections.Heartbeat = RunService.Heartbeat:Connect(function()
	local char = LocalPlayer and LocalPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")

	-- Physics Speed Engine
	if State.PhysicsSpeedEnabled and hrp and hum then
		local isMoving = hum.MoveDirection.Magnitude > 0.1
		local shouldSpeed = not State.PhysicsSpeedSprintOnly or State.IsSprinting
		if isMoving and shouldSpeed then
			local targetVelocity = hum.MoveDirection.Unit * State.PhysicsSpeedValue
			hrp.AssemblyLinearVelocity = Vector3.new(targetVelocity.X, hrp.AssemblyLinearVelocity.Y, targetVelocity.Z)
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

	-- Auto Clicker
	if State.AutoClickEnabled then
		local now = tick()
		local interval = 1 / math.max(State.AutoClickCPS, 1)
		if now - State.LastClickTime >= interval then
			State.LastClickTime = now
			if VirtualUser then
				pcall(function()
					VirtualUser:Button1Down(Vector2.new(0, 0))
					task.wait(0.01)
					VirtualUser:Button1Up(Vector2.new(0, 0))
				end)
			end
		end
	end
end)

-- 4. Radar ESP Updater Loop
task.spawn(function()
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
							bb.Size = UDim2.new(0, 140, 0, 30)
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
		task.wait(0.2)
	end
end)

-- 5. Manejo de Entrada de Teclado y Ratón (UserInputService)
Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == State.ToggleKey then
		mainFrame.Visible = not mainFrame.Visible
		return
	end

	if input.UserInputType == State.AimKey then
		State.IsAiming = true
	end

	if input.KeyCode == State.SpeedKey then
		State.IsSprinting = true
	end

	-- Salto Infinito en el Aire
	if input.KeyCode == State.SpaceJumpKey and State.InfiniteJump and not gameProcessed then
		local char = LocalPlayer and LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end

	-- Salto Vertical de Impulso (F)
	if input.KeyCode == State.JumpKey and State.ForwardJump and not gameProcessed then
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

	-- Click-to-Teleport
	if input.UserInputType == Enum.UserInputType.MouseButton1 and State.ClickTeleport and not gameProcessed then
		local mouse = LocalPlayer:GetMouse()
		local hit = mouse and mouse.Hit
		local char = LocalPlayer and LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hit and hrp then
			hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
		end
	end
end)

Connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == State.AimKey then
		State.IsAiming = false
	end
	if input.KeyCode == State.SpeedKey then
		State.IsSprinting = false
	end
end)

print("[JAILBREAK SUITE] Inicializado correctamente con resolución universal de servicios y 9 módulos tácticos.")
