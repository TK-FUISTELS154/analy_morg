--[[
	===========================================================
	COMBAT ADMIN & DEVELOPER SUITE PRO (MATERIAL DESIGN 3)
	===========================================================
	Script universal tipo LocalScript para creadores y desarrolladores
	de juegos de combate en Roblox Studio.

	Pestañas y Funcionalidades:
	- 🏃 Movimiento: WalkSpeed, JumpPower, Gravity, Salto Infinito en el Aire (Tecla ESPACIO), Salto de Desplazamiento Vertical (Tecla F), Salto de Desplazamiento Horizontal (Tecla G), Super Velocidad por Vectores Físicos (Physics Speed Engine), Noclip, Fly Mode, Impulse Dash.
	- 🖱️ Herramientas Clic: Auto Clicker (CPS Ráfaga + Modo Mantener Clic Presionado + Filtro Mantener Ratón), Click-to-TP, Click-to-Select.
	- ⌨️ Macro Combate: Grabador y reproductor profesional (Teclado + Ratón Clic Izquierdo/Derecho/Medio, Velocidad Variable, Recorte de silencio).
	- 🎯 Auto-Apuntado & Spy: Aimbot Universal (FOV, Raycast Paredes, Prioridad Cabeza/Cuerpo/Cercano, Suavizado, Offsets X/Y), Marcador ESP de Enemigos Visibles/Ocultos/Apuntados en tiempo real.
	- 👁️ Visuales & Radar: Player ESP/NameTags, Spectate Mode, Hitbox Highlight.
	- ⚔️ Combate & Dev: Camera Lock-On, FOV Changer, Admin Heal, Hitbox Inspector.
	- ☀️ Iluminación & Clima: Día, Noche, Atardecer, Fullbright (Sin Sombras).
	- 📍 Arenas / TP: Waypoints de Arena, Teleport a Jugadores, Coordenadas XYZ.
	- 👥 Jugadores & Equipos: Escaneo dinámico de bandos/equipos con toggles para excluir equipos del Aimbot o del Spy ESP.
	- ⚙️ Ajustes: Configuración completa de atajos por combinación de teclas (Ctrl + Key), teclas directas y Botón de Finalización Total del Script (Kill Process).
--]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- =========================================================
-- ESTADO Y CONFIGURACIÓN DEL PANEL
-- =========================================================
local State = {
	WalkSpeed = 32,
	DefaultSpeed = 16,
	JumpPower = 60,
	DefaultJump = 50,
	Gravity = 196.2,
	DefaultGravity = 196.2,
	FOV = 70,
	DefaultFOV = 70,
	
	-- Movimiento avanzado & SISTEMA DE SALTOS Y DESPLAZAMIENTO
	InfiniteJump = false,               -- Salto 1: Salto Infinito en el aire con ESPACIO (Desactivado por defecto)
	SpaceJumpKey = Enum.KeyCode.Space,  -- Tecla Espacio predeterminada
	InfiniteJumpKey = Enum.KeyCode.J,   -- Ctrl + J (Atajo para activar/desactivar Salto Infinito)

	ForwardJump = false,                -- Salto 2: Salto de Desplazamiento Vertical con F (Desactivado por defecto)
	JumpKey = Enum.KeyCode.F,           -- Tecla F predeterminada (Sin alterar inercia X/Z)
	ForwardJumpDistance = 80,           -- Fuerza / Distancia de impulso vertical
	ForwardJumpPower = 65,              -- Fuerza de desplazamiento vertical hacia arriba

	HorizontalJump = false,             -- Salto 3: Salto de Desplazamiento Horizontal con G (Desactivado por defecto)
	HorizontalJumpKey = Enum.KeyCode.G, -- Tecla G predeterminada
	HorizontalJumpPower = 120,          -- Fuerza de desplazamiento horizontal (studs/s)

	-- Sistema de Super Velocidad por Desplazamiento Físico (Physics Speed Engine)
	PhysicsSpeedEnabled = false,        -- Aceleración continua mediante vectores de velocidad
	PhysicsSpeedValue = 60,             -- Velocidad física continua objetivo (studs/s)
	PhysicsSpeedSprintOnly = false,     -- Solo impulsar cuando se presione la tecla de Sprint (Shift)
	IsSprinting = false,                -- Estado de sprint activo

	Noclip = false,
	FlyEnabled = false,
	FlySpeed = 50,
	
	-- Clic & Mouse (Auto Clicker & Hold Click)
	AutoClickEnabled = false,
	HoldClickMode = false,              -- Modo Mantener Clic Presionado (Hold Down)
	AutoClickOnlyWhileHolding = false,  -- Solo activar cuando el jugador mantenga presionado el ratón
	AutoClickCPS = 10,
	LastClickTime = 0,
	ClickTeleport = false,
	ClickSelect = false,
	AutoActivateTool = false,

	-- Sistema Universal de Auto-Apuntado (Aimbot)
	AimbotEnabled = false,              -- Auto-Apuntado (Desactivado por defecto)
	IsAiming = false,
	AimKey = Enum.UserInputType.MouseButton2,
	FOV_Radius = 220,
	ShowFOV = false,                    -- Círculo FOV (Desactivado por defecto)
	TargetPart = "Head",                -- "Head", "UpperTorso", "Closest"
	AimSpeed = 0.8,                     -- 0.01 (Suave) a 1.0 (Instantáneo)
	WallCheck = true,                   -- Comprobador Raycast de pared/cobertura
	OffsetX = 0,
	OffsetY = -28,                      -- Desplazamiento Y predeterminado a -28

	-- Equipos & Filtrado Avanzado
	TeamCheck = true,                   -- No apuntar a aliados
	TargetFFA = false,                  -- Apuntar a todos (Modo Todos Contra Todos)
	TargetedTeams = {},                 -- Equipos fijados como objetivo
	IgnoredAimTeams = {},               -- Equipos ignorados/excluidos del Aimbot
	IgnoredESPTeams = {},               -- Equipos ignorados/excluidos del Marcador Spy ESP
	CurrentLockedTargetPlayer = nil,    -- Jugador fijado actualmente por el Aimbot

	-- Colores Marcador Spy System & ESP (Sincronización Total)
	ColorLockOnTarget = Color3.fromRGB(255, 215, 0), -- Dorado brillante para el objetivo apuntado
	ColorVisible = Color3.fromRGB(50, 255, 100),     -- Verde cuando es visible y disparable
	ColorHidden = Color3.fromRGB(255, 50, 50),       -- Rojo cuando está detrás de cobertura
	ColorAlly = Color3.fromRGB(50, 150, 255),        -- Azul para aliados
	ColorFOV = Color3.fromRGB(255, 255, 255),        -- Color del círculo FOV y crosshair

	-- Sistema de Macro Combate Profesional
	IsRecordingMacro = false,
	IsPlayingMacro = false,
	MacroLoop = false,
	MacroPlaybackSpeed = 1.0,           -- Multiplicador de velocidad (0.5x a 3.0x)
	MacroData = {},
	RecordStartTime = 0,
	FirstInputTime = nil,
	MacroTrimDelay = true,
	
	-- ATAJOS DE TECLADO CONFIGURABLES
	ToggleKey = Enum.KeyCode.F,        -- Ctrl + F (Mostrar/Ocultar Panel)
	RecordKey = Enum.KeyCode.X,        -- Ctrl + X (Grabar Macro)
	PlayKey = Enum.KeyCode.M,          -- Ctrl + M (Reproducir Macro)
	AutoClickKey = Enum.KeyCode.C,     -- Ctrl + C (Auto Clicker)
	AimbotToggleKey = Enum.KeyCode.A,  -- Ctrl + A (Auto-Apuntado)
	NoclipKey = Enum.KeyCode.N,        -- Ctrl + N (Noclip)
	FlyKey = Enum.KeyCode.V,           -- Ctrl + V (Vuelo)
	ESPKey = Enum.KeyCode.E,           -- Ctrl + E (ESP Radar / Spy System)
	LockOnKey = Enum.KeyCode.L,        -- Ctrl + L (Lock-On)
	FullbrightKey = Enum.KeyCode.B,    -- Ctrl + B (Fullbright)
	ClickTPKey = Enum.KeyCode.T,       -- Ctrl + T (Click-to-TP)
	HealKey = Enum.KeyCode.H,          -- Ctrl + H (Admin Heal)
	SpeedKey = Enum.KeyCode.LeftShift, -- Sprint Key
	
	-- Visuales & ESP
	ESPEnabled = false,
	SpectateEnabled = false,
	Fullbright = false,
	
	-- Combate & Dev
	LockOnEnabled = false,
	HitboxInspector = false,
	
	-- Selección
	SelectedPlayer = nil,
	CurrentTarget = nil
}

local Connections = {}
local ESPCache = {}
local HighlightInstance = nil

-- Paleta de Colores Material Design 3 (Dark Combat Theme)
local PALETTE = {
	Background = Color3.fromRGB(18, 18, 24),
	Surface = Color3.fromRGB(28, 28, 36),
	Card = Color3.fromRGB(38, 38, 48),
	InputBg = Color3.fromRGB(48, 48, 62),
	Primary = Color3.fromRGB(124, 77, 255),        -- Deep Purple
	PrimaryHover = Color3.fromRGB(145, 102, 255),
	Secondary = Color3.fromRGB(0, 200, 240),        -- Cyan Highlight
	Success = Color3.fromRGB(46, 125, 50),          -- Green Active
	Danger = Color3.fromRGB(229, 57, 53),           -- Red Warning
	Text = Color3.fromRGB(245, 245, 250),
	TextMuted = Color3.fromRGB(150, 150, 170),
	Stroke = Color3.fromRGB(60, 60, 75)
}

-- Función auxiliar para verificar si Ctrl está presionado
local function isCtrlPressed()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

-- Comprobar si una tecla pertenece a los atajos de sistema
local function isSystemHotkey(keyCode)
	return keyCode == State.ToggleKey or keyCode == State.RecordKey or keyCode == State.PlayKey or
	       keyCode == State.AutoClickKey or keyCode == State.AimbotToggleKey or keyCode == State.NoclipKey or
	       keyCode == State.FlyKey or keyCode == State.InfiniteJumpKey or keyCode == State.ESPKey or
	       keyCode == State.LockOnKey or keyCode == State.FullbrightKey or keyCode == State.ClickTPKey or
	       keyCode == State.HealKey
end

-- =========================================================
-- CREACIÓN DE LA INTERFAZ GRÁFICA (GUI)
-- =========================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("CombatAdminGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatAdminGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Punto Central Crosshair Dot (Aimbot)
local centerDot = Instance.new("Frame")
centerDot.Name = "CenterDot"
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
centerDot.Size = UDim2.new(0, 5, 0, 5)
centerDot.BackgroundColor3 = State.ColorFOV
centerDot.Parent = screenGui

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = centerDot

-- Círculo de Campo de Visión FOV
local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = centerDot.Position
fovFrame.Size = UDim2.new(0, State.FOV_Radius * 2, 0, State.FOV_Radius * 2)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = State.ShowFOV
fovFrame.Parent = screenGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = State.ColorFOV
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.5
fovStroke.Parent = fovFrame

-- Folder para guardar billboards y highlights ESP
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "AdminESPFolder"
ESPFolder.Parent = screenGui

-- Frame Principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 650, 0, 490)
mainFrame.Position = UDim2.new(0.5, -325, 0.5, -245)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = PALETTE.Stroke
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- HEADER (Barra de Título)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = PALETTE.Surface
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚔️ COMBAT ADMIN & DEV SUITE PRO"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 8)
closeBtn.BackgroundColor3 = PALETTE.Danger
closeBtn.Text = "✕"
closeBtn.TextColor3 = PALETTE.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- HUD DE TELEMETRÍA (FPS / POSICIÓN / ATAJOS RÁPIDOS)
local telemetryBar = Instance.new("TextLabel")
telemetryBar.Size = UDim2.new(1, -20, 0, 20)
telemetryBar.Position = UDim2.new(0, 10, 1, -25)
telemetryBar.BackgroundTransparency = 1
telemetryBar.Text = "FPS: -- | Panel (Ctrl+F) | Salto Aire (Space) | Salto Vert (F) | AutoClick (Ctrl+C)"
telemetryBar.TextColor3 = PALETTE.TextMuted
telemetryBar.Font = Enum.Font.Code
telemetryBar.TextSize = 9
telemetryBar.TextXAlignment = Enum.TextXAlignment.Left
telemetryBar.Parent = mainFrame

-- PANEL DE NAVEGACIÓN IZQUIERDO (Pestañas)
local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 150, 1, -78)
navBar.Position = UDim2.new(0, 8, 0, 48)
navBar.BackgroundColor3 = PALETTE.Surface
navBar.Parent = mainFrame

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 8)
navCorner.Parent = navBar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 3)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = navBar

local navPadding = Instance.new("UIPadding")
navPadding.PaddingTop = UDim.new(0, 5)
navPadding.PaddingLeft = UDim.new(0, 5)
navPadding.PaddingRight = UDim.new(0, 5)
navPadding.Parent = navBar

-- CONTENEDOR DE PÁGINAS (DERECHA)
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -174, 1, -78)
contentFrame.Position = UDim2.new(0, 166, 0, 48)
contentFrame.BackgroundColor3 = PALETTE.Surface
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentFrame

-- CREADOR DE PÁGINAS Y PESTAÑAS
local pages = {}
local currentActivePage = nil

local function createPage(pageName)
	local page = Instance.new("ScrollingFrame")
	page.Name = pageName .. "Page"
	page.Size = UDim2.new(1, -12, 1, -12)
	page.Position = UDim2.new(0, 6, 0, 6)
	page.BackgroundTransparency = 1
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = PALETTE.Primary
	page.Visible = false
	page.Parent = contentFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	pages[pageName] = page
	return page
end

local movementPage = createPage("Movement")
local clickToolsPage = createPage("ClickTools")
local macroPage = createPage("Macro")
local aimbotSpyPage = createPage("AimbotSpy")
local visualsPage = createPage("Visuals")
local combatPage = createPage("Combat")
local lightingPage = createPage("Lighting")
local teleportPage = createPage("Teleport")
local playersPage = createPage("Players")
local settingsPage = createPage("Settings")

movementPage.Visible = true
currentActivePage = movementPage

local function addTabButton(text, pageRef)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 24)
	btn.BackgroundColor3 = (pageRef == currentActivePage) and PALETTE.Primary or PALETTE.Card
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 9
	btn.Parent = navBar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 5)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		for _, p in pairs(pages) do p.Visible = false end
		for _, b in ipairs(navBar:GetChildren()) do
			if b:IsA("TextButton") then b.BackgroundColor3 = PALETTE.Card end
		end
		pageRef.Visible = true
		currentActivePage = pageRef
		btn.BackgroundColor3 = PALETTE.Primary
	end)

	return btn
end

addTabButton("🏃 Movimiento", movementPage)
addTabButton("🖱️ Clic / Mouse", clickToolsPage)
addTabButton("⌨️ Macro Combate", macroPage)
addTabButton("🎯 Auto-Aim & Spy", aimbotSpyPage)
addTabButton("👁️ Visuales / ESP", visualsPage)
addTabButton("⚔️ Combate / Dev", combatPage)
addTabButton("☀️ Iluminación", lightingPage)
addTabButton("📍 Arenas / TP", teleportPage)
addTabButton("👥 Jugadores & Equipos", playersPage)
addTabButton("⚙️ Ajustes", settingsPage)

-- =========================================================
-- AUXILIARES DE ELEMENTOS INTERACTIVOS CON SOPORTE HOTKEY
-- =========================================================
local function createInputRow(parent, labelText, defaultValue, minVal, maxVal, callback)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 36)
	card.BackgroundColor3 = PALETTE.Card
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = PALETTE.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.28, 0, 0, 24)
	box.Position = UDim2.new(0.68, 0, 0, 6)
	box.BackgroundColor3 = PALETTE.InputBg
	box.Text = tostring(defaultValue)
	box.TextColor3 = PALETTE.Text
	box.Font = Enum.Font.GothamBold
	box.TextSize = 11
	box.Parent = card

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = box

	box.FocusLost:Connect(function()
		local num = tonumber(box.Text)
		if num then
			num = math.clamp(num, minVal, maxVal)
			box.Text = tostring(num)
			if callback then callback(num) end
		else
			box.Text = tostring(defaultValue)
		end
	end)
end

local function createToggleRow(parent, baseLabel, keybindKey, defaultState, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = defaultState and PALETTE.Success or PALETTE.Card
	
	local getKeyText = function()
		return keybindKey and (" [" .. keybindKey.Name .. "]") or ""
	end

	btn.Text = baseLabel .. getKeyText() .. "  [" .. (defaultState and "ACTIVADO" or "DESACTIVADO") .. "]"
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local state = defaultState

	local function updateVisuals()
		btn.BackgroundColor3 = state and PALETTE.Success or PALETTE.Card
		btn.Text = baseLabel .. getKeyText() .. "  [" .. (state and "ACTIVADO" or "DESACTIVADO") .. "]"
	end

	btn.MouseButton1Click:Connect(function()
		state = not state
		updateVisuals()
		if callback then callback(state) end
	end)

	return {
		Button = btn,
		SetState = function(newState)
			state = newState
			updateVisuals()
			if callback then callback(state) end
		end,
		Toggle = function()
			state = not state
			updateVisuals()
			if callback then callback(state) end
		end,
		UpdateKey = function(newKey)
			keybindKey = newKey
			updateVisuals()
		end
	}
end

local function createActionButton(parent, text, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return btn
end

-- Selector interactivo de teclas
local function createKeybindRow(parent, labelText, currentKey, isCtrlCombined, callback)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 34)
	card.BackgroundColor3 = PALETTE.Card
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = PALETTE.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local bindBtn = Instance.new("TextButton")
	bindBtn.Size = UDim2.new(0.28, 0, 0, 24)
	bindBtn.Position = UDim2.new(0.68, 0, 0, 5)
	bindBtn.BackgroundColor3 = PALETTE.InputBg
	bindBtn.Text = (isCtrlCombined and "Ctrl + " or "") .. currentKey.Name
	bindBtn.TextColor3 = PALETTE.Secondary
	bindBtn.Font = Enum.Font.GothamBold
	bindBtn.TextSize = 10
	bindBtn.Parent = card

	local bindCorner = Instance.new("UICorner")
	bindCorner.CornerRadius = UDim.new(0, 4)
	bindCorner.Parent = bindBtn

	local listening = false
	bindBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		bindBtn.Text = "Presiona Tecla..."
		bindBtn.TextColor3 = PALETTE.Danger

		local connection
		connection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local newKey = input.KeyCode
				if newKey ~= Enum.KeyCode.LeftControl and newKey ~= Enum.KeyCode.RightControl then
					bindBtn.Text = (isCtrlCombined and "Ctrl + " or "") .. newKey.Name
					bindBtn.TextColor3 = PALETTE.Secondary
					listening = false
					connection:Disconnect()
					if callback then callback(newKey) end
				end
			end
		end)
	end)

	return bindBtn
end

-- Selector de Colores Rápido
local function createColorPickerRow(parent, labelText, defaultColor, callback)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 36)
	card.BackgroundColor3 = PALETTE.Card
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = PALETTE.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local colorPreview = Instance.new("TextButton")
	colorPreview.Size = UDim2.new(0, 50, 0, 24)
	colorPreview.Position = UDim2.new(0.85, -45, 0, 6)
	colorPreview.BackgroundColor3 = defaultColor
	colorPreview.Text = ""
	colorPreview.Parent = card

	local cpCorner = Instance.new("UICorner")
	cpCorner.CornerRadius = UDim.new(0, 4)
	cpCorner.Parent = colorPreview

	local presetColors = {
		Color3.fromRGB(255, 215, 0),  -- Dorado
		Color3.fromRGB(50, 255, 100),  -- Verde
		Color3.fromRGB(255, 50, 50),   -- Rojo
		Color3.fromRGB(0, 200, 240),   -- Cyan
		Color3.fromRGB(255, 200, 0),   -- Amarillo
		Color3.fromRGB(200, 50, 255),  -- Morado
		Color3.fromRGB(255, 255, 255)  -- Blanco
	}
	local colorIndex = 1

	colorPreview.MouseButton1Click:Connect(function()
		colorIndex = (colorIndex % #presetColors) + 1
		local newColor = presetColors[colorIndex]
		colorPreview.BackgroundColor3 = newColor
		if callback then callback(newColor) end
	end)
end

-- Comprobar si un clic ocurre dentro del marco principal del Panel
local function isClickInsideMainFrame(mousePos)
	if not mainFrame.Visible then return false end
	local framePos = mainFrame.AbsolutePosition
	local frameSize = mainFrame.AbsoluteSize
	return mousePos.X >= framePos.X and mousePos.X <= (framePos.X + frameSize.X) and
	       mousePos.Y >= framePos.Y and mousePos.Y <= (framePos.Y + frameSize.Y)
end

-- =========================================================
-- DETECCIÓN UNIVERSAL DE EQUIPOS Y ENEMIGOS DE PRECISIÓN
-- =========================================================
local function getPlayerTeam(player)
	if not player then return "Sin Equipo" end
	if player.Team then return player.Team.Name end
	if player.TeamColor then return player.TeamColor.Name end

	local char = player.Character
	if char then
		local teamAttr = char:GetAttribute("Team") or char:GetAttribute("Faction")
		if teamAttr then return tostring(teamAttr) end

		local teamFolder = char:FindFirstChild("Team") or char:FindFirstChild("Faction")
		if teamFolder and teamFolder:IsA("StringValue") then
			return teamFolder.Value
		end
	end

	return "Sin Equipo"
end

local function shouldAimAtPlayer(targetPlayer)
	if not targetPlayer or targetPlayer == LocalPlayer then return false end

	local targetTeam = getPlayerTeam(targetPlayer)

	-- Si el equipo del jugador está en la lista de ignorados del Aimbot
	if table.find(State.IgnoredAimTeams, targetTeam) then
		return false
	end

	-- Modo Todos Contra Todos (FFA)
	if State.TargetFFA then return true end

	-- Si se especificaron equipos objetivos específicos
	if #State.TargetedTeams > 0 then
		return table.find(State.TargetedTeams, targetTeam) ~= nil
	end

	-- Verificación estándar de equipo contrario
	if State.TeamCheck then
		local myTeam = getPlayerTeam(LocalPlayer)
		if myTeam ~= "Sin Equipo" and targetTeam ~= "Sin Equipo" then
			return myTeam ~= targetTeam
		end
	end

	return true
end

local function shouldMarkPlayerESP(targetPlayer)
	if not targetPlayer or targetPlayer == LocalPlayer then return false end

	local targetTeam = getPlayerTeam(targetPlayer)

	-- Si el equipo del jugador está en la lista de ignorados del Spy ESP
	if table.find(State.IgnoredESPTeams, targetTeam) then
		return false
	end

	return true
end

local function isPartVisible(part, character)
	if not State.WallCheck then return true end
	local origin = Camera.CFrame.Position
	local direction = part.Position - origin

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character, character, Camera}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction, rayParams)
	return result == nil
end

local function getTargetBodyPart(character)
	if not character then return nil end

	if State.TargetPart == "Head" then
		return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	elseif State.TargetPart == "UpperTorso" then
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("Head")
	elseif State.TargetPart == "Closest" then
		local head = character:FindFirstChild("Head")
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if not head then return torso or character:FindFirstChild("HumanoidRootPart") end
		if not torso then return head end

		local aimCenter = centerDot.AbsolutePosition + (centerDot.AbsoluteSize / 2)
		local headScreenPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
		local torsoScreenPos, torsoOnScreen = Camera:WorldToViewportPoint(torso.Position)

		if headOnScreen and torsoOnScreen then
			local headDist = (Vector2.new(headScreenPos.X, headScreenPos.Y) - aimCenter).Magnitude
			local torsoDist = (Vector2.new(torsoScreenPos.X, torsoScreenPos.Y) - aimCenter).Magnitude
			return (headDist < torsoDist) and head or torso
		end
		return head
	end

	return character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
end

local function getClosestEnemyInFOV()
	local closestPart = nil
	local closestPlayer = nil
	local shortestDistance = State.FOV_Radius
	local aimCenter = centerDot.AbsolutePosition + (centerDot.AbsoluteSize / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if shouldAimAtPlayer(player) and player.Character then
			local char = player.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local part = getTargetBodyPart(char)
				if part and isPartVisible(part, char) then
					local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
					if onScreen then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimCenter).Magnitude
						if dist < shortestDistance then
							shortestDistance = dist
							closestPart = part
							closestPlayer = player
						end
					end
				end
			end
		end
	end

	State.CurrentLockedTargetPlayer = closestPlayer
	return closestPart
end

-- =========================================================
-- FUNCIÓN PRINCIPAL DEL AUTO CLICKER & MANTENER CLIC PRESIONADO
-- =========================================================
local isMouseHeldDown = false

local function processAutoClick()
	if not State.AutoClickEnabled then
		if isMouseHeldDown then
			isMouseHeldDown = false
			VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
		end
		return
	end
	
	if State.AutoClickOnlyWhileHolding then
		local holdingLeftClick = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		if not holdingLeftClick then
			if isMouseHeldDown then
				isMouseHeldDown = false
				VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
			end
			return
		end
	end

	local char = LocalPlayer.Character

	if State.HoldClickMode then
		-- MODO MANTENER CLIC PRESIONADO CONTINUO
		if not isMouseHeldDown then
			isMouseHeldDown = true
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			end
			VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
		else
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			end
		end
	else
		-- MODO CLICS RÁPIDOS POR SEGUNDO (CPS RÁFAGA)
		if isMouseHeldDown then
			isMouseHeldDown = false
			VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
		end

		local interval = 1 / math.max(1, State.AutoClickCPS)
		local currentTime = os.clock()
		
		if currentTime - State.LastClickTime >= interval then
			State.LastClickTime = currentTime
			
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then tool:Activate() end
			end
			VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
			task.delay(0.01, function()
				VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
			end)
		end
	end
end

-- =========================================================
-- FUNCIÓN DE RESTAURACIÓN DE SALUD (ADMIN HEAL)
-- =========================================================
local function performAdminHeal()
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = humanoid.MaxHealth end
	end
end

-- =========================================================
-- FUNCIÓN DE FINALIZACIÓN Y DESTRUCCIÓN TOTAL DEL SCRIPT (UNLOAD)
-- =========================================================
local function clearESP(character)
	if ESPCache[character] then
		if ESPCache[character].Highlight then ESPCache[character].Highlight:Destroy() end
		if ESPCache[character].Billboard then ESPCache[character].Billboard:Destroy() end
		ESPCache[character] = nil
	end
end

local function unloadScript()
	print("[COMBAT ADMIN PRO] Cerrando panel y liberando todos los recursos...")
	
	for _, conn in ipairs(Connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(Connections)

	State.AutoClickEnabled = false
	State.AimbotEnabled = false
	State.IsRecordingMacro = false
	State.IsPlayingMacro = false
	State.ESPEnabled = false
	State.LockOnEnabled = false
	State.Noclip = false
	State.FlyEnabled = false
	State.InfiniteJump = false
	State.ForwardJump = false

	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = State.DefaultSpeed
			hum.JumpPower = State.DefaultJump
			hum.PlatformStand = false
		end
	end

	Workspace.Gravity = State.DefaultGravity
	Camera.FieldOfView = State.DefaultFOV
	Camera.CameraType = Enum.CameraType.Custom
	if char and char:FindFirstChildOfClass("Humanoid") then
		Camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
	end

	if State.Fullbright then
		Lighting.Brightness = 2
		Lighting.GlobalShadows = true
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end

	for char, _ in pairs(ESPCache) do clearESP(char) end
	if ESPFolder then ESPFolder:Destroy() end
	if HighlightInstance then HighlightInstance:Destroy() end
	if screenGui then screenGui:Destroy() end

	print("[COMBAT ADMIN PRO] 🛑 Proceso finalizado y destruido por completo.")
end

-- =========================================================
-- SISTEMA DE MACROS DE COMBATE PROFESIONAL Y ROBUSTO
-- =========================================================
local macroStatusLabel = Instance.new("TextLabel")
macroStatusLabel.Size = UDim2.new(1, 0, 0, 24)
macroStatusLabel.BackgroundTransparency = 1
macroStatusLabel.Text = "Estado: ⏹️ Inactivo (0 acciones guardadas)"
macroStatusLabel.TextColor3 = PALETTE.TextMuted
macroStatusLabel.Font = Enum.Font.GothamBold
macroStatusLabel.TextSize = 11
macroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
macroStatusLabel.Parent = macroPage

local function updateMacroStatusUI()
	if State.IsRecordingMacro then
		macroStatusLabel.Text = string.format("Estado: 🔴 Grabando Macro (%d entradas)...", #State.MacroData)
		macroStatusLabel.TextColor3 = PALETTE.Danger
	elseif State.IsPlayingMacro then
		macroStatusLabel.Text = string.format("Estado: ▶️ Reproduciendo Macro (%d acciones | %.1fx)...", #State.MacroData, State.MacroPlaybackSpeed)
		macroStatusLabel.TextColor3 = PALETTE.Secondary
	else
		macroStatusLabel.Text = string.format("Estado: ⏹️ Inactivo (%d acciones guardadas)", #State.MacroData)
		macroStatusLabel.TextColor3 = PALETTE.TextMuted
	end
end

local function toggleMacroRecording()
	if State.IsPlayingMacro then return end

	State.IsRecordingMacro = not State.IsRecordingMacro
	if State.IsRecordingMacro then
		table.clear(State.MacroData)
		State.RecordStartTime = os.clock()
		State.FirstInputTime = nil
		print("[MACRO PRO] 🔴 Grabación iniciada. Presiona teclas o realiza clics.")
	else
		print(string.format("[MACRO PRO] ⏹️ Grabación finalizada. %d acciones registradas.", #State.MacroData))
	end
	updateMacroStatusUI()
end

local function stopMacroPlayback()
	State.IsPlayingMacro = false
	updateMacroStatusUI()
	print("[MACRO PRO] ⏹️ Reproducción detenida.")
end

local function clearMacroData()
	if State.IsPlayingMacro or State.IsRecordingMacro then return end
	table.clear(State.MacroData)
	State.FirstInputTime = nil
	updateMacroStatusUI()
	print("[MACRO PRO] 🗑️ Datos de macro borrados.")
end

local function playMacro()
	if State.IsRecordingMacro or #State.MacroData == 0 or State.IsPlayingMacro then return end

	State.IsPlayingMacro = true
	updateMacroStatusUI()
	print(string.format("[MACRO PRO] ▶️ Reproduciendo macro (Velocidad: %.1fx)...", State.MacroPlaybackSpeed))

	task.spawn(function()
		repeat
			local lastActionTime = 0
			local speedMult = math.max(0.1, State.MacroPlaybackSpeed)

			for _, action in ipairs(State.MacroData) do
				if not State.IsPlayingMacro then break end

				local rawDelay = action.Time - lastActionTime
				local adjustedDelay = rawDelay / speedMult
				if adjustedDelay > 0 then
					task.wait(adjustedDelay)
				end
				lastActionTime = action.Time

				if not State.IsPlayingMacro then break end

				if action.InputType == "Mouse" then
					local buttonEnum = 0
					if action.Button == Enum.UserInputType.MouseButton2 then
						buttonEnum = 1
					elseif action.Button == Enum.UserInputType.MouseButton3 then
						buttonEnum = 2
					end
					VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, buttonEnum, action.State == "Began", game, 0)
				elseif action.InputType == "Keyboard" then
					VirtualInputManager:SendKeyEvent(action.State == "Began", action.KeyCode, false, game)
				end
			end

			task.wait(0.05 / speedMult)
		until not State.MacroLoop or not State.IsPlayingMacro

		State.IsPlayingMacro = false
		updateMacroStatusUI()
		print("[MACRO PRO] ⏹️ Macro completada.")
	end)
end

-- =========================================================
-- FUNCIONES DEL MODO VUELO Y VELOCIDAD FÍSICA
-- =========================================================
local function processFlyMode()
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	if State.FlyEnabled then
		hum.PlatformStand = true
		local moveDir = Vector3.zero
		
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir = moveDir + Camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir = moveDir - Camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir = moveDir + Camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir = moveDir - Camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end
		
		if moveDir.Magnitude > 0 then
			root.Velocity = moveDir.Unit * State.FlySpeed
		else
			root.Velocity = Vector3.zero
		end
	else
		if hum.PlatformStand then
			hum.PlatformStand = false
		end
	end
end

-- LÓGICA MEJORADA DE VELOCIDAD BASADA EN VECTORES FÍSICOS (Bypassa restricciones de WalkSpeed estándar)
local function processPhysicsSpeed()
	if not State.PhysicsSpeedEnabled then return end
	if State.PhysicsSpeedSprintOnly and not State.IsSprinting then return end
	if State.FlyEnabled then return end

	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude > 0.05 then
		local horizontalVector = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
		root.Velocity = Vector3.new(
			horizontalVector.X * State.PhysicsSpeedValue,
			root.Velocity.Y,
			horizontalVector.Z * State.PhysicsSpeedValue
		)
	end
end

-- =========================================================
-- PESTAÑA 1: MOVIMIENTO & SISTEMA DE SALTOS Y DESPLAZAMIENTO
-- =========================================================
createInputRow(movementPage, "Velocidad Caminata Estándar (WalkSpeed):", State.WalkSpeed, 0, 500, function(val)
	State.WalkSpeed = val
	local char = LocalPlayer.Character
	if char and char:FindFirstChildOfClass("Humanoid") then
		char:FindFirstChildOfClass("Humanoid").WalkSpeed = val
	end
end)

createInputRow(movementPage, "Velocidad Vectorial Físico (Physics Speed):", State.PhysicsSpeedValue, 16, 500, function(val)
	State.PhysicsSpeedValue = val
end)

local physicsSpeedToggleRef = createToggleRow(movementPage, "⚡ Super Velocidad (Desplazamiento Continuo)", nil, State.PhysicsSpeedEnabled, function(st)
	State.PhysicsSpeedEnabled = st
end)

createToggleRow(movementPage, "🏃 Activar Velocidad Física Solo al Mantener Shift", nil, State.PhysicsSpeedSprintOnly, function(st)
	State.PhysicsSpeedSprintOnly = st
end)

createInputRow(movementPage, "Fuerza de Salto (JumpPower):", State.JumpPower, 0, 1000, function(val)
	State.JumpPower = val
	local char = LocalPlayer.Character
	if char and char:FindFirstChildOfClass("Humanoid") then
		local hum = char:FindFirstChildOfClass("Humanoid")
		hum.UseJumpPower = true
		hum.JumpPower = val
	end
end)

createInputRow(movementPage, "Gravedad del Mapa (Gravity):", State.Gravity, 0, 500, function(val)
	State.Gravity = val
	Workspace.Gravity = val
end)

createInputRow(movementPage, "Velocidad de Vuelo (FlySpeed):", State.FlySpeed, 10, 300, function(val)
	State.FlySpeed = val
end)

createInputRow(movementPage, "Fuerza Desplazamiento Vertical:", State.ForwardJumpPower, 10, 500, function(val)
	State.ForwardJumpPower = val
end)

createInputRow(movementPage, "Fuerza Desplazamiento Horizontal:", State.HorizontalJumpPower, 10, 500, function(val)
	State.HorizontalJumpPower = val
end)

-- SALTO 1: SALTO INFINITO EN EL AIRE (CON TECLA ESPACIO PRELOGADA)
local infiniteJumpToggleRef = createToggleRow(movementPage, "🌌 Salto Infinito en el Aire [Tecla ESPACIO]", State.SpaceJumpKey, State.InfiniteJump, function(st)
	State.InfiniteJump = st
end)

-- SALTO 2: SALTO DE DESPLAZAMIENTO VERTICAL (CON TECLA F PRELOGADA)
local forwardJumpToggleRef = createToggleRow(movementPage, "🚀 Salto Desplazamiento Vertical [Tecla F]", State.JumpKey, State.ForwardJump, function(st)
	State.ForwardJump = st
end)

-- SALTO 3: SALTO DE DESPLAZAMIENTO HORIZONTAL (CON TECLA G PRELOGADA)
local horizontalJumpToggleRef = createToggleRow(movementPage, "⚡ Salto Desplazamiento Horizontal [Tecla G]", State.HorizontalJumpKey, State.HorizontalJump, function(st)
	State.HorizontalJump = st
end)

local noclipToggleRef = createToggleRow(movementPage, "👻 Modo Noclip (Atravesar Muros)", State.NoclipKey, State.Noclip, function(st)
	State.Noclip = st
end)

local flyToggleRef = createToggleRow(movementPage, "🕊️ Modo Vuelo (Fly Mode)", State.FlyKey, State.FlyEnabled, function(st)
	State.FlyEnabled = st
end)

createActionButton(movementPage, "⚡ Impulso / Dash Vertical & Frontal", PALETTE.Primary, function()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local root = char.HumanoidRootPart
		local currentVel = root.Velocity
		local lookVec = root.CFrame.LookVector
		root.Velocity = Vector3.new(currentVel.X + lookVec.X * 120, currentVel.Y + 25, currentVel.Z + lookVec.Z * 120)
	end
end)

createActionButton(movementPage, "💨 Impulso / Dash Horizontal Instantáneo (360°)", PALETTE.Secondary, function()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local root = char.HumanoidRootPart
		local hum = char:FindFirstChildOfClass("Humanoid")
		local moveDir = (hum and hum.MoveDirection.Magnitude > 0.05 and hum.MoveDirection) or root.CFrame.LookVector
		local hDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
		root.Velocity = Vector3.new(hDir.X * State.HorizontalJumpPower, root.Velocity.Y, hDir.Z * State.HorizontalJumpPower)
	end
end)

-- =========================================================
-- PESTAÑA 2: HERRAMIENTAS DE CLIC & MODO MANTENER PRESIONADO
-- =========================================================
local autoClickToggleRef = createToggleRow(clickToolsPage, "⚡ Auto Clicker", State.AutoClickKey, State.AutoClickEnabled, function(st)
	State.AutoClickEnabled = st
end)

createToggleRow(clickToolsPage, "✊ Modo Mantener Clic Presionado (Hold Down)", nil, State.HoldClickMode, function(st)
	State.HoldClickMode = st
end)

createToggleRow(clickToolsPage, "🖱️ Activar Solo al Sostener Clic Izquierdo", nil, State.AutoClickOnlyWhileHolding, function(st)
	State.AutoClickOnlyWhileHolding = st
end)

createInputRow(clickToolsPage, "Clics Por Segundo [Modo CPS]:", State.AutoClickCPS, 1, 60, function(val)
	State.AutoClickCPS = val
end)

local clickTpToggleRef = createToggleRow(clickToolsPage, "📍 Teleport por Clic (Click-to-TP)", State.ClickTPKey, State.ClickTeleport, function(st)
	State.ClickTeleport = st
end)

createToggleRow(clickToolsPage, "🎯 Seleccionar Jugador por Clic", nil, State.ClickSelect, function(st)
	State.ClickSelect = st
end)

createActionButton(clickToolsPage, "💥 Disparar/Activar Arma Equipada", PALETTE.Primary, function()
	local char = LocalPlayer.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then tool:Activate() end
	end
end)

-- =========================================================
-- PESTAÑA 3: MACRO COMBATE (GRABADOR & REPRODUCTOR ROBUSTO)
-- =========================================================
createActionButton(macroPage, "🔴 Iniciar / Detener Grabación (Ctrl + " .. State.RecordKey.Name .. ")", PALETTE.Danger, function()
	toggleMacroRecording()
end)

createActionButton(macroPage, "▶️ Reproducir / Pausar Macro (Ctrl + " .. State.PlayKey.Name .. ")", PALETTE.Primary, function()
	if State.IsPlayingMacro then
		stopMacroPlayback()
	else
		playMacro()
	end
end)

createActionButton(macroPage, "🗑️ Borrar Macro Actual", PALETTE.Card, function()
	clearMacroData()
end)

createToggleRow(macroPage, "🔁 Reproducción en Bucle (Loop)", nil, State.MacroLoop, function(st)
	State.MacroLoop = st
end)

createInputRow(macroPage, "Velocidad de Reproducción (x1.0, x2.0):", State.MacroPlaybackSpeed, 0.2, 5.0, function(val)
	State.MacroPlaybackSpeed = val
	updateMacroStatusUI()
end)

createToggleRow(macroPage, "✂️ Omitir Silencio Inicial (Trim Delay)", nil, State.MacroTrimDelay, function(st)
	State.MacroTrimDelay = st
end)

-- PESTAÑA 4: AUTO-APUNTADO (AIMBOT) & SPY MARKERS
local aimbotToggleRef = createToggleRow(aimbotSpyPage, "🎯 Auto-Apuntado Universal (Aimbot)", State.AimbotToggleKey, State.AimbotEnabled, function(st)
	State.AimbotEnabled = st
end)

createToggleRow(aimbotSpyPage, "👁️ Mostrar Círculo de Visión FOV", nil, State.ShowFOV, function(st)
	State.ShowFOV = st
	fovFrame.Visible = st
end)

createToggleRow(aimbotSpyPage, "🧱 Detección de Paredes / Coberturas", nil, State.WallCheck, function(st)
	State.WallCheck = st
end)

createInputRow(aimbotSpyPage, "Radio Círculo FOV:", State.FOV_Radius, 50, 800, function(val)
	State.FOV_Radius = val
	fovFrame.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

createInputRow(aimbotSpyPage, "Velocidad Suavizado Aim (0.1-1.0):", State.AimSpeed, 0.05, 1.0, function(val)
	State.AimSpeed = val
end)

createInputRow(aimbotSpyPage, "Punto Offset X (Horizontal):", State.OffsetX, -200, 200, function(val)
	State.OffsetX = val
	centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
	fovFrame.Position = centerDot.Position
end)

createInputRow(aimbotSpyPage, "Punto Offset Y (Vertical):", State.OffsetY, -200, 200, function(val)
	State.OffsetY = val
	centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
	fovFrame.Position = centerDot.Position
end)

local targetPartBtn = Instance.new("TextButton")
targetPartBtn.Size = UDim2.new(1, 0, 0, 36)
targetPartBtn.BackgroundColor3 = PALETTE.Primary
targetPartBtn.Text = "🎯 Prioridad de Apuntado: CABEZA"
targetPartBtn.TextColor3 = PALETTE.Text
targetPartBtn.Font = Enum.Font.GothamBold
targetPartBtn.TextSize = 10
targetPartBtn.Parent = aimbotSpyPage

local tpbCorner = Instance.new("UICorner")
tpbCorner.CornerRadius = UDim.new(0, 6)
tpbCorner.Parent = targetPartBtn

targetPartBtn.MouseButton1Click:Connect(function()
	if State.TargetPart == "Head" then
		State.TargetPart = "UpperTorso"
		targetPartBtn.Text = "🎯 Prioridad de Apuntado: CUERPO"
		targetPartBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	elseif State.TargetPart == "UpperTorso" then
		State.TargetPart = "Closest"
		targetPartBtn.Text = "🎯 Prioridad de Apuntado: MÁS CERCANO"
		targetPartBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 240)
	else
		State.TargetPart = "Head"
		targetPartBtn.Text = "🎯 Prioridad de Apuntado: CABEZA"
		targetPartBtn.BackgroundColor3 = PALETTE.Primary
	end
end)

createColorPickerRow(aimbotSpyPage, "🎨 Color Círculo FOV / Crosshair:", State.ColorFOV, function(c)
	State.ColorFOV = c
	fovStroke.Color = c
	centerDot.BackgroundColor3 = c
end)

createColorPickerRow(aimbotSpyPage, "🎨 Color Enemigo a la Vista (Al Alcance Aim):", State.ColorVisible, function(c)
	State.ColorVisible = c
end)

-- PESTAÑA 5: VISUALES & ESP (MARCADORES Y PALETA COMPLETA DE COLORES DE EQUIPO)
local espToggleRef = createToggleRow(visualsPage, "👁️ Radar / ESP Spy System de Jugadores", State.ESPKey, State.ESPEnabled, function(st)
	State.ESPEnabled = st
	if not st then
		for char, _ in pairs(ESPCache) do clearESP(char) end
	end
end)

createColorPickerRow(visualsPage, "🎨 Color ESP Objetivo Apuntado (Aimbot):", State.ColorLockOnTarget, function(c)
	State.ColorLockOnTarget = c
end)

createColorPickerRow(visualsPage, "🎨 Color ESP Enemigo Visible (Al Alcance):", State.ColorVisible, function(c)
	State.ColorVisible = c
end)

createColorPickerRow(visualsPage, "🎨 Color ESP Enemigo Oculto (Muro):", State.ColorHidden, function(c)
	State.ColorHidden = c
end)

createColorPickerRow(visualsPage, "🎨 Color ESP Jugadores Aliados:", State.ColorAlly, function(c)
	State.ColorAlly = c
end)

createToggleRow(visualsPage, "🎥 Modo Espectador (Spectate Player)", nil, State.SpectateEnabled, function(st)
	State.SpectateEnabled = st
	if st and State.SelectedPlayer then
		local target = Players:FindFirstChild(State.SelectedPlayer)
		if target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			Camera.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
		end
	else
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			Camera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
	end
end)

-- PESTAÑA 6: COMBATE & HERRAMIENTAS DEV
createInputRow(combatPage, "Campo de Visión Cámaras (FOV):", State.FOV, 40, 120, function(val)
	State.FOV = val
	Camera.FieldOfView = val
end)

local lockOnToggleRef = createToggleRow(combatPage, "🎯 Lock-On de Cámara en Enemigos", State.LockOnKey, State.LockOnEnabled, function(st)
	State.LockOnEnabled = st
	if not st then
		Camera.CameraType = Enum.CameraType.Custom
		State.CurrentTarget = nil
	end
end)

createToggleRow(combatPage, "🔍 Inspector de Hitbox / Jugadores", nil, State.HitboxInspector, function(st)
	State.HitboxInspector = st
	if not st and HighlightInstance then
		HighlightInstance:Destroy()
		HighlightInstance = nil
	end
end)

createActionButton(combatPage, "❤️ Restaurar Salud Local (Ctrl + " .. State.HealKey.Name .. ")", PALETTE.Success, function()
	performAdminHeal()
end)

-- PESTAÑA 7: ILUMINACIÓN & CLIMA
createActionButton(lightingPage, "☀️ Modo Día (14:00)", PALETTE.Card, function()
	Lighting.ClockTime = 14
end)

createActionButton(lightingPage, "🌙 Modo Noche (00:00)", PALETTE.Card, function()
	Lighting.ClockTime = 0
end)

createActionButton(lightingPage, "🌅 Modo Atardecer (18:00)", PALETTE.Card, function()
	Lighting.ClockTime = 18
end)

local fullbrightToggleRef = createToggleRow(lightingPage, "💡 Fullbright (Sin Sombras)", State.FullbrightKey, State.Fullbright, function(st)
	State.Fullbright = st
	if st then
		Lighting.Brightness = 3
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	else
		Lighting.Brightness = 2
		Lighting.GlobalShadows = true
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end
end)

-- PESTAÑA 8: TELEPORT & ARENAS
local waypoints = {
	{ Name = "🏠 Spawn Principal", Pos = Vector3.new(0, 10, 0) },
	{ Name = "⚔️ Arena de Combate 1", Pos = Vector3.new(100, 15, 100) },
	{ Name = "🏰 Zona Elevada / Torre", Pos = Vector3.new(0, 100, 0) }
}

for _, wp in ipairs(waypoints) do
	createActionButton(teleportPage, "Ir a: " .. wp.Name, PALETTE.Card, function()
		local char = LocalPlayer.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.CFrame = CFrame.new(wp.Pos)
		end
	end)
end

-- PESTAÑA 9: GESTIÓN DE JUGADORES Y EQUIPOS (EXCLUSIÓN DE EQUIPOS PARA AIMBOT Y SPY)
createToggleRow(playersPage, "🛡️ Filtrar por Equipos Enemigos", nil, State.TeamCheck, function(st)
	State.TeamCheck = st
end)

createToggleRow(playersPage, "⚔️ Modo Todos Contra Todos (FFA)", nil, State.TargetFFA, function(st)
	State.TargetFFA = st
end)

local selectedInfoLabel = Instance.new("TextLabel")
selectedInfoLabel.Size = UDim2.new(1, 0, 0, 24)
selectedInfoLabel.BackgroundTransparency = 1
selectedInfoLabel.Text = "Seleccionado: Ninguno"
selectedInfoLabel.TextColor3 = PALETTE.Secondary
selectedInfoLabel.Font = Enum.Font.GothamBold
selectedInfoLabel.TextSize = 11
selectedInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedInfoLabel.Parent = playersPage

createActionButton(playersPage, "🚀 Teleportar hacia el Jugador", PALETTE.Primary, function()
	if State.SelectedPlayer then
		local target = Players:FindFirstChild(State.SelectedPlayer)
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local myChar = LocalPlayer.Character
			if myChar and myChar:FindFirstChild("HumanoidRootPart") then
				myChar.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
			end
		end
	end
end)

-- PANEL DE EXCLUSIÓN DE EQUIPOS (AIMBOT & SPY ESP)
local teamExclusionTitle = Instance.new("TextLabel")
teamExclusionTitle.Size = UDim2.new(1, 0, 0, 20)
teamExclusionTitle.BackgroundTransparency = 1
teamExclusionTitle.Text = "⚙️ Filtros por Equipo (Excluir Aimbot / Excluir Spy ESP):"
teamExclusionTitle.TextColor3 = PALETTE.Secondary
teamExclusionTitle.Font = Enum.Font.GothamBold
teamExclusionTitle.TextSize = 10
teamExclusionTitle.TextXAlignment = Enum.TextXAlignment.Left
teamExclusionTitle.Parent = playersPage

local teamsListCard = Instance.new("Frame")
teamsListCard.Size = UDim2.new(1, 0, 0, 140)
teamsListCard.BackgroundColor3 = PALETTE.Card
teamsListCard.Parent = playersPage

local tlcCorner = Instance.new("UICorner")
tlcCorner.CornerRadius = UDim.new(0, 6)
tlcCorner.Parent = teamsListCard

local teamsScroll = Instance.new("ScrollingFrame")
teamsScroll.Size = UDim2.new(1, -8, 1, -8)
teamsScroll.Position = UDim2.new(0, 4, 0, 4)
teamsScroll.BackgroundTransparency = 1
teamsScroll.ScrollBarThickness = 3
teamsScroll.Parent = teamsListCard

local teamsListLayout = Instance.new("UIListLayout")
teamsListLayout.Padding = UDim.new(0, 4)
teamsListLayout.Parent = teamsScroll

local function refreshTeamsList()
	for _, child in ipairs(teamsScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local detectedTeams = {}
	if #Teams:GetTeams() > 0 then
		for _, team in ipairs(Teams:GetTeams()) do
			table.insert(detectedTeams, team.Name)
		end
	else
		for _, p in ipairs(Players:GetPlayers()) do
			local tName = getPlayerTeam(p)
			if not table.find(detectedTeams, tName) then
				table.insert(detectedTeams, tName)
			end
		end
	end

	for _, teamName in ipairs(detectedTeams) do
		local isAimIgnored = table.find(State.IgnoredAimTeams, teamName) ~= nil
		local isESPIgnored = table.find(State.IgnoredESPTeams, teamName) ~= nil

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = PALETTE.InputBg
		row.Parent = teamsScroll

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 4)
		rCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.42, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 6, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "👥 " .. teamName
		nameLabel.TextColor3 = PALETTE.Text
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		-- Botón para Ignorar/Permitir Aimbot
		local aimBtn = Instance.new("TextButton")
		aimBtn.Size = UDim2.new(0.26, 0, 0, 22)
		aimBtn.Position = UDim2.new(0.44, 0, 0, 4)
		aimBtn.BackgroundColor3 = isAimIgnored and PALETTE.Danger or PALETTE.Success
		aimBtn.Text = isAimIgnored and "🎯 Aim: OFF" or "🎯 Aim: ON"
		aimBtn.TextColor3 = PALETTE.Text
		aimBtn.Font = Enum.Font.GothamBold
		aimBtn.TextSize = 9
		aimBtn.Parent = row

		local abCorner = Instance.new("UICorner")
		abCorner.CornerRadius = UDim.new(0, 4)
		abCorner.Parent = aimBtn

		aimBtn.MouseButton1Click:Connect(function()
			local idx = table.find(State.IgnoredAimTeams, teamName)
			if idx then
				table.remove(State.IgnoredAimTeams, idx)
			else
				table.insert(State.IgnoredAimTeams, teamName)
			end
			refreshTeamsList()
		end)

		-- Botón para Ignorar/Permitir Marcador Spy ESP
		local espBtn = Instance.new("TextButton")
		espBtn.Size = UDim2.new(0.26, 0, 0, 22)
		espBtn.Position = UDim2.new(0.72, 0, 0, 4)
		espBtn.BackgroundColor3 = isESPIgnored and PALETTE.Danger or PALETTE.Primary
		espBtn.Text = isESPIgnored and "👁️ Spy: OFF" or "👁️ Spy: ON"
		espBtn.TextColor3 = PALETTE.Text
		espBtn.Font = Enum.Font.GothamBold
		espBtn.TextSize = 9
		espBtn.Parent = row

		local ebCorner = Instance.new("UICorner")
		ebCorner.CornerRadius = UDim.new(0, 4)
		ebCorner.Parent = espBtn

		espBtn.MouseButton1Click:Connect(function()
			local idx = table.find(State.IgnoredESPTeams, teamName)
			if idx then
				table.remove(State.IgnoredESPTeams, idx)
			else
				table.insert(State.IgnoredESPTeams, teamName)
			end
			refreshTeamsList()
		end)
	end
end

refreshTeamsList()

local playerListCard = Instance.new("Frame")
playerListCard.Size = UDim2.new(1, 0, 0, 120)
playerListCard.BackgroundColor3 = PALETTE.Card
playerListCard.Parent = playersPage

local plcCorner = Instance.new("UICorner")
plcCorner.CornerRadius = UDim.new(0, 6)
plcCorner.Parent = playerListCard

local playerScroll = Instance.new("ScrollingFrame")
playerScroll.Size = UDim2.new(1, -8, 1, -8)
playerScroll.Position = UDim2.new(0, 4, 0, 4)
playerScroll.BackgroundTransparency = 1
playerScroll.ScrollBarThickness = 3
playerScroll.Parent = playerListCard

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, 4)
playerListLayout.Parent = playerScroll

local function refreshPlayersList()
	for _, child in ipairs(playerScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local tName = getPlayerTeam(p)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 26)
			b.BackgroundColor3 = (State.SelectedPlayer == p.Name) and PALETTE.Primary or PALETTE.InputBg
			b.Text = string.format("  %s [%s]", p.Name, tName)
			b.TextColor3 = PALETTE.Text
			b.Font = Enum.Font.Gotham
			b.TextSize = 10
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Parent = playerScroll

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 4)
			bCorner.Parent = b

			b.MouseButton1Click:Connect(function()
				State.SelectedPlayer = p.Name
				selectedInfoLabel.Text = "Seleccionado: " .. p.Name
				refreshPlayersList()
			end)
		end
	end
end

Players.PlayerAdded:Connect(function()
	refreshPlayersList()
	refreshTeamsList()
end)
Players.PlayerRemoving:Connect(function(p)
	if State.SelectedPlayer == p.Name then
		State.SelectedPlayer = nil
		selectedInfoLabel.Text = "Seleccionado: Ninguno"
	end
	refreshPlayersList()
	refreshTeamsList()
end)
refreshPlayersList()

-- PESTAÑA 10: CONFIGURACIÓN COMPLETA DE ATAJOS (SETTINGS)
createKeybindRow(settingsPage, "Atajo Ocultar Panel (Ctrl + Key):", State.ToggleKey, true, function(newKey)
	State.ToggleKey = newKey
end)

createKeybindRow(settingsPage, "Atajo Auto-Apuntado (Ctrl + Key):", State.AimbotToggleKey, true, function(newKey)
	State.AimbotToggleKey = newKey
	aimbotToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Grabar Macro (Ctrl + Key):", State.RecordKey, true, function(newKey)
	State.RecordKey = newKey
end)

createKeybindRow(settingsPage, "Atajo Reproducir Macro (Ctrl + Key):", State.PlayKey, true, function(newKey)
	State.PlayKey = newKey
end)

createKeybindRow(settingsPage, "Tecla Salto Infinito en Aire:", State.SpaceJumpKey, false, function(newKey)
	State.SpaceJumpKey = newKey
	infiniteJumpToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Tecla Salto Desplazamiento Vertical:", State.JumpKey, false, function(newKey)
	State.JumpKey = newKey
	forwardJumpToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Tecla Salto Desplazamiento Horizontal:", State.HorizontalJumpKey, false, function(newKey)
	State.HorizontalJumpKey = newKey
	horizontalJumpToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Auto Clicker (Ctrl + Key):", State.AutoClickKey, true, function(newKey)
	State.AutoClickKey = newKey
	autoClickToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Modo Noclip (Ctrl + Key):", State.NoclipKey, true, function(newKey)
	State.NoclipKey = newKey
	noclipToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Modo Vuelo (Ctrl + Key):", State.FlyKey, true, function(newKey)
	State.FlyKey = newKey
	flyToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Radar ESP / Spy (Ctrl + Key):", State.ESPKey, true, function(newKey)
	State.ESPKey = newKey
	espToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Lock-On Cámara (Ctrl + Key):", State.LockOnKey, true, function(newKey)
	State.LockOnKey = newKey
	lockOnToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Fullbright (Ctrl + Key):", State.FullbrightKey, true, function(newKey)
	State.FullbrightKey = newKey
	fullbrightToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Teleport por Clic (Ctrl + Key):", State.ClickTPKey, true, function(newKey)
	State.ClickTPKey = newKey
	clickTpToggleRef.UpdateKey(newKey)
end)

createKeybindRow(settingsPage, "Atajo Admin Heal (Ctrl + Key):", State.HealKey, true, function(newKey)
	State.HealKey = newKey
end)

createActionButton(settingsPage, "🔄 Restaurar Todos los Atajos a Valores por Defecto", PALETTE.Card, function()
	State.ToggleKey = Enum.KeyCode.F
	State.RecordKey = Enum.KeyCode.X
	State.PlayKey = Enum.KeyCode.M
	State.AutoClickKey = Enum.KeyCode.C
	State.AimbotToggleKey = Enum.KeyCode.A
	State.NoclipKey = Enum.KeyCode.N
	State.FlyKey = Enum.KeyCode.V
	State.SpaceJumpKey = Enum.KeyCode.Space
	State.JumpKey = Enum.KeyCode.F
	State.HorizontalJumpKey = Enum.KeyCode.G
	State.ESPKey = Enum.KeyCode.E
	State.LockOnKey = Enum.KeyCode.L
	State.FullbrightKey = Enum.KeyCode.B
	State.ClickTPKey = Enum.KeyCode.T
	State.HealKey = Enum.KeyCode.H
	
	autoClickToggleRef.UpdateKey(State.AutoClickKey)
	aimbotToggleRef.UpdateKey(State.AimbotToggleKey)
	noclipToggleRef.UpdateKey(State.NoclipKey)
	flyToggleRef.UpdateKey(State.FlyKey)
	infiniteJumpToggleRef.UpdateKey(State.SpaceJumpKey)
	forwardJumpToggleRef.UpdateKey(State.JumpKey)
	horizontalJumpToggleRef.UpdateKey(State.HorizontalJumpKey)
	espToggleRef.UpdateKey(State.ESPKey)
	lockOnToggleRef.UpdateKey(State.LockOnKey)
	fullbrightToggleRef.UpdateKey(State.FullbrightKey)
	clickTpToggleRef.UpdateKey(State.ClickTPKey)
	
	print("[AJUSTES] Todos los atajos restaurados a valores por defecto.")
end)

createActionButton(settingsPage, "🛑 Destruir y Finalizar Script Definitivamente (Kill Process)", PALETTE.Danger, function()
	unloadScript()
end)

-- =========================================================
-- CONTROL DE HERRAMIENTAS DE CLIC Y EVENTOS DE ENTRADA
-- =========================================================
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
	local isMouseClick = (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3)
	local mousePos = UserInputService:GetMouseLocation()
	local insideUI = isClickInsideMainFrame(mousePos)
	local ctrlHeld = isCtrlPressed()

	-- 1. COMBINACIONES DE TECLAS DEL SISTEMA (Ctrl + Key)
	if input.UserInputType == Enum.UserInputType.Keyboard and ctrlHeld then
		if input.KeyCode == State.ToggleKey then
			mainFrame.Visible = not mainFrame.Visible
			return
		elseif input.KeyCode == State.RecordKey then
			toggleMacroRecording()
			return
		elseif input.KeyCode == State.PlayKey then
			if State.IsPlayingMacro then stopMacroPlayback() else playMacro() end
			return
		elseif input.KeyCode == State.AutoClickKey then
			autoClickToggleRef.Toggle()
			return
		elseif input.KeyCode == State.AimbotToggleKey then
			aimbotToggleRef.Toggle()
			return
		elseif input.KeyCode == State.NoclipKey then
			noclipToggleRef.Toggle()
			return
		elseif input.KeyCode == State.FlyKey then
			flyToggleRef.Toggle()
			return
		elseif input.KeyCode == State.ESPKey then
			espToggleRef.Toggle()
			return
		elseif input.KeyCode == State.LockOnKey then
			lockOnToggleRef.Toggle()
			return
		elseif input.KeyCode == State.FullbrightKey then
			fullbrightToggleRef.Toggle()
			return
		elseif input.KeyCode == State.ClickTPKey then
			clickTpToggleRef.Toggle()
			return
		elseif input.KeyCode == State.HealKey then
			performAdminHeal()
			return
		end
	end

	-- 2. Detección de Tecla de Apuntado (Aimbot Hold - Clic Derecho)
	if input.UserInputType == State.AimKey then
		State.IsAiming = true
		fovStroke.Color = State.ColorHidden
		centerDot.BackgroundColor3 = State.ColorHidden
	end

	-- 3. SALTO 1: SALTO INFINITO EN EL AIRE (Tecla ESPACIO por Defecto)
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == State.SpaceJumpKey and not ctrlHeld and not gpe then
		local char = LocalPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if humanoid and root then
				local currentState = humanoid:GetState()
				local isAirborne = (currentState == Enum.HumanoidStateType.Jumping or currentState == Enum.HumanoidStateType.Freefall)

				if State.InfiniteJump and isAirborne then
					root.Velocity = Vector3.new(root.Velocity.X, State.JumpPower, root.Velocity.Z)
				end
			end
		end
	end

	-- 4. SALTO 2: SALTO DE DESPLAZAMIENTO VERTICAL (Tecla F por Defecto)
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == State.JumpKey and not ctrlHeld and not gpe then
		local char = LocalPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if humanoid and root then
				if State.ForwardJump then
					local currentVel = root.Velocity
					root.Velocity = Vector3.new(
						currentVel.X,
						State.ForwardJumpPower,
						currentVel.Z
					)
				end
			end
		end
	end

	-- 5. SALTO 3: SALTO DE DESPLAZAMIENTO HORIZONTAL (Tecla G por Defecto)
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == State.HorizontalJumpKey and not ctrlHeld and not gpe then
		local char = LocalPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 and State.HorizontalJump then
				local moveDir = humanoid.MoveDirection
				if moveDir.Magnitude > 0.05 then
					moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
				else
					local look = root.CFrame.LookVector
					moveDir = Vector3.new(look.X, 0, look.Z).Unit
				end
				root.Velocity = Vector3.new(
					moveDir.X * State.HorizontalJumpPower,
					root.Velocity.Y,
					moveDir.Z * State.HorizontalJumpPower
				)
			end
		end
	end

	-- 6. Captura de Clics para Click-to-TP y Click Select (Fuera de la GUI del Admin)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not insideUI then
		if State.ClickTeleport and Mouse.Hit then
			local targetPos = Mouse.Hit.Position
			local char = LocalPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			end
		end

		if State.ClickSelect then
			local targetPart = Mouse.Target
			if targetPart then
				local character = targetPart:FindFirstAncestorOfClass("Model")
				if character then
					local player = Players:GetPlayerFromCharacter(character)
					if player and player ~= LocalPlayer then
						State.SelectedPlayer = player.Name
						selectedInfoLabel.Text = "Seleccionado: " .. player.Name
						refreshPlayersList()
					end
				end
			end
		end
	end

	-- 7. Grabación de Macro: Filtra Atajos y Teclas de Control para No Contaminar la Macro
	if State.IsRecordingMacro and not insideUI then
		local now = os.clock()
		if State.MacroTrimDelay and not State.FirstInputTime then
			State.FirstInputTime = now
		end
		local elapsedTime = now - (State.FirstInputTime or State.RecordStartTime)

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode ~= Enum.KeyCode.LeftControl and input.KeyCode ~= Enum.KeyCode.RightControl and not isSystemHotkey(input.KeyCode) then
				table.insert(State.MacroData, {
					InputType = "Keyboard",
					KeyCode = input.KeyCode,
					State = "Began",
					Time = elapsedTime
				})
				updateMacroStatusUI()
			end
		elseif isMouseClick then
			table.insert(State.MacroData, {
				InputType = "Mouse",
				Button = input.UserInputType,
				State = "Began",
				Time = elapsedTime
			})
			updateMacroStatusUI()
		end
	end

	-- 8. Teclas rápidas simples (Sprint & Estado de Aceleración)
	if not gpe then
		if input.KeyCode == State.SpeedKey then
			State.IsSprinting = true
			local char = LocalPlayer.Character
			if char and char:FindFirstChildOfClass("Humanoid") then
				char:FindFirstChildOfClass("Humanoid").WalkSpeed = State.WalkSpeed
			end
		end
	end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input, gpe)
	if input.UserInputType == State.AimKey then
		State.IsAiming = false
		fovStroke.Color = State.ColorFOV
		centerDot.BackgroundColor3 = State.ColorFOV
	end

	if input.KeyCode == State.SpeedKey then
		State.IsSprinting = false
		local char = LocalPlayer.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			char:FindFirstChildOfClass("Humanoid").WalkSpeed = State.DefaultSpeed
		end
	end

	-- Registrar soltado en Macro (Key Up / Mouse Up)
	local isMouseClick = (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3)
	local mousePos = UserInputService:GetMouseLocation()
	local insideUI = isClickInsideMainFrame(mousePos)

	if State.IsRecordingMacro and not insideUI then
		local now = os.clock()
		local elapsedTime = now - (State.FirstInputTime or State.RecordStartTime)

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode ~= Enum.KeyCode.LeftControl and input.KeyCode ~= Enum.KeyCode.RightControl and not isSystemHotkey(input.KeyCode) then
				table.insert(State.MacroData, {
					InputType = "Keyboard",
					KeyCode = input.KeyCode,
					State = "Ended",
					Time = elapsedTime
				})
				updateMacroStatusUI()
			end
		elseif isMouseClick then
			table.insert(State.MacroData, {
				InputType = "Mouse",
				Button = input.UserInputType,
				State = "Ended",
				Time = elapsedTime
			})
			updateMacroStatusUI()
		end
	end
end))

-- =========================================================
-- BUCLE DE FÍSICA Y NOCLIP (Stepped)
-- =========================================================
table.insert(Connections, RunService.Stepped:Connect(function()
	if State.Noclip then
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end
end))

-- =========================================================
-- BUCLE PRINCIPAL DE RENDERIZADO, AIMBOT Y SPY ESP (RenderStepped)
-- =========================================================
local lastTime = tick()
local frameCount = 0
local fps = 60

table.insert(Connections, RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	if tick() - lastTime >= 1 then
		fps = frameCount
		frameCount = 0
		lastTime = tick()
	end

	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local pos = char.HumanoidRootPart.Position
		telemetryBar.Text = string.format("FPS: %d | Panel (Ctrl+%s) | Salto Vert (%s) | Salto Horiz (%s) | AutoClick (Ctrl+%s)", 
			fps, State.ToggleKey.Name, State.JumpKey.Name, State.HorizontalJumpKey.Name, State.AutoClickKey.Name)
	end

	-- Procesar Auto Clicker, Fly Mode y Velocidad Física Continua
	processAutoClick()
	processFlyMode()
	processPhysicsSpeed()

	-- Ejecutar Auto-Apuntado Universal (Aimbot)
	if State.AimbotEnabled and State.IsAiming then
		local targetPart = getClosestEnemyInFOV()
		if targetPart then
			local aimOffsetVector = (Camera.CFrame.RightVector * (State.OffsetX * 0.05)) + (Camera.CFrame.UpVector * (State.OffsetY * 0.05))
			local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position + aimOffsetVector)
			if State.AimSpeed >= 1 then
				Camera.CFrame = targetCFrame
			else
				Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, State.AimSpeed)
			end
		end
	else
		State.CurrentLockedTargetPlayer = nil
	end

	-- Lock-On de Cámara
	if State.LockOnEnabled and State.SelectedPlayer then
		local targetPlayer = Players:FindFirstChild(State.SelectedPlayer)
		if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPlayer.Character.HumanoidRootPart.Position)
		end
	end

	-- ESP NameTags & Marcador Spy System Renderer (Sincronización Total)
	if State.ESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if shouldMarkPlayerESP(player) and player.Character then
				local pChar = player.Character
				local hum = pChar:FindFirstChildOfClass("Humanoid")
				local root = pChar:FindFirstChild("HumanoidRootPart")

				if hum and hum.Health > 0 and root then
					local isEnemyPlayer = shouldAimAtPlayer(player)
					local isCurrentlyLocked = (State.AimbotEnabled and State.IsAiming and player == State.CurrentLockedTargetPlayer)
					local distance = math.floor((char and char:FindFirstChild("HumanoidRootPart") and (char.HumanoidRootPart.Position - root.Position).Magnitude) or 0)

					if not ESPCache[pChar] then
						ESPCache[pChar] = {}

						local highlight = Instance.new("Highlight")
						highlight.Name = "SpyHighlight"
						highlight.FillTransparency = 0.3
						highlight.OutlineTransparency = 0
						highlight.Parent = pChar
						ESPCache[pChar].Highlight = highlight

						local billboard = Instance.new("BillboardGui")
						billboard.Name = "SpyBillboard"
						billboard.Size = UDim2.new(0, 140, 0, 40)
						billboard.StudsOffset = Vector3.new(0, 3.5, 0)
						billboard.AlwaysOnTop = true
						billboard.Parent = ESPFolder

						local label = Instance.new("TextLabel")
						label.Size = UDim2.new(1, 0, 1, 0)
						label.BackgroundTransparency = 1
						label.TextColor3 = PALETTE.Text
						label.TextStrokeTransparency = 0.2
						label.Font = Enum.Font.GothamBold
						label.TextSize = 11
						label.Parent = billboard

						ESPCache[pChar].Billboard = billboard
						ESPCache[pChar].TextLabel = label
					end

					local cache = ESPCache[pChar]
					local headPart = pChar:FindFirstChild("Head") or root
					local visible = isPartVisible(headPart, pChar)
					cache.Billboard.Adornee = headPart

					-- SINCRONIZACIÓN PERFECTA DE COLORES DE APUNTADO Y SPY MARKERS
					if isCurrentlyLocked then
						cache.Highlight.FillColor = State.ColorLockOnTarget
						cache.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
						cache.TextLabel.TextColor3 = State.ColorLockOnTarget
						cache.TextLabel.Text = string.format("🎯 [OBJETIVO APUNTADO]\n%s [ %d m | %d HP ]", player.Name, distance, math.floor(hum.Health))
					elseif isEnemyPlayer then
						if visible then
							cache.Highlight.FillColor = State.ColorVisible
							cache.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
							cache.TextLabel.TextColor3 = State.ColorVisible
							cache.TextLabel.Text = string.format("🔴 %s\n[ %d m | %d HP ]", player.Name, distance, math.floor(hum.Health))
						else
							cache.Highlight.FillColor = State.ColorHidden
							cache.Highlight.OutlineColor = Color3.fromRGB(150, 0, 0)
							cache.TextLabel.TextColor3 = State.ColorHidden
							cache.TextLabel.Text = string.format("👁️ %s [Oculto]\n[ %d m | %d HP ]", player.Name, distance, math.floor(hum.Health))
						end
					else
						cache.Highlight.FillColor = State.ColorAlly
						cache.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
						cache.TextLabel.TextColor3 = State.ColorAlly
						cache.TextLabel.Text = string.format("🛡️ %s\n[ Aliado ]", player.Name)
					end
				else
					clearESP(pChar)
				end
			else
				if player.Character then clearESP(player.Character) end
			end
		end
	end
end))

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)