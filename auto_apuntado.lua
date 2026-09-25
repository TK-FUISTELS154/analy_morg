--[[
	===========================================================
	UNIVERSAL AIMBOT & SPY MARKER SUITE PRO (MATERIAL DESIGN 3)
	===========================================================
	Script universal compatible con cualquier juego de Roblox.
	
	Funcionalidades Principales:
	- 🎯 Auto-Apuntado (Aimbot): FOV Círculo, Raycast Paredes, Prioridad Cabeza/Cuerpo/Cercano, Suavizado, Offsets X/Y (Y=-28).
	- 👥 Sistema Universal de Equipos: Detección automática del servicio Teams y atributos. Exclusión independiente de equipos para Aimbot y Spy ESP.
	- 👁️ Marcas ESP & Spy System Sincronizado: Resaltado especial en tiempo real para el enemigo fijado por el Aimbot, enemigos visibles, ocultos y aliados.
	- ⚙️ Panel Integrado Material Design: Control total de parámetros, colores de equipos, lista interactiva de bandos y atajos.
--]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- =========================================================
-- CONFIGURACIÓN Y ESTADO GLOBAL
-- =========================================================
local State = {
	-- Aimbot Config
	AimbotEnabled = true,
	IsAiming = false,
	AimKey = Enum.UserInputType.MouseButton2,
	FOV_Radius = 220,
	ShowFOV = true,
	TargetPart = "Head",                -- "Head", "UpperTorso", "Closest"
	AimSpeed = 0.8,                     -- 0.01 (Suave) a 1.0 (Instantáneo)
	WallCheck = true,                   -- Verificar si el enemigo es visible detrás de coberturas
	OffsetX = 0,
	OffsetY = -28,                      -- Desplazamiento Y predeterminado a -28

	-- Equipos & Filtrado Avanzado
	TeamCheck = true,                   -- No apuntar a aliados
	TargetFFA = false,                  -- Apuntar a todos sin importar equipo
	TargetedTeams = {},                 -- Equipos fijados como objetivo
	IgnoredAimTeams = {},               -- Equipos ignorados por el Aimbot
	IgnoredESPTeams = {},               -- Equipos ignorados por el Spy ESP
	CurrentLockedTargetPlayer = nil,    -- Jugador fijado por el Aimbot

	-- Visuales ESP & Marcador Spy Sincronizado
	ESPEnabled = true,
	ShowHighlight = true,
	ShowBillboard = true,
	ShowDistance = true,
	ShowHealth = true,

	-- Colores de Marcado (Spy System)
	ColorLockOnTarget = Color3.fromRGB(255, 215, 0), -- Dorado brillante para objetivo apuntado
	ColorVisible = Color3.fromRGB(50, 255, 100),     -- Verde cuando se puede disparar
	ColorHidden = Color3.fromRGB(255, 50, 50),       -- Rojo cuando está detrás de cobertura
	ColorAlly = Color3.fromRGB(50, 150, 255),        -- Azul para aliados
	ColorFOV = Color3.fromRGB(255, 255, 255),        -- Color del círculo FOV

	-- Panel Config
	ToggleKey = Enum.KeyCode.F,
	IsActive = true
}

local Connections = {}
local ESPCache = {}

-- Paleta de Colores Material Design 3
local PALETTE = {
	Background = Color3.fromRGB(18, 18, 24),
	Surface = Color3.fromRGB(28, 28, 36),
	Card = Color3.fromRGB(38, 38, 48),
	InputBg = Color3.fromRGB(48, 48, 62),
	Primary = Color3.fromRGB(124, 77, 255),
	PrimaryHover = Color3.fromRGB(145, 102, 255),
	Secondary = Color3.fromRGB(0, 200, 240),
	Success = Color3.fromRGB(46, 125, 50),
	Danger = Color3.fromRGB(229, 57, 53),
	Text = Color3.fromRGB(245, 245, 250),
	TextMuted = Color3.fromRGB(150, 150, 170),
	Stroke = Color3.fromRGB(60, 60, 75)
}

-- =========================================================
-- CREACIÓN DE LA INTERFAZ GRÁFICA (GUI)
-- =========================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("UniversalAimSpyGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UniversalAimSpyGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Punto Central (Crosshair Dot)
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

-- Círculo de Campo de Visión (FOV Circle)
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

-- Frame Principal del Panel
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 600, 0, 460)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -230)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
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
title.Text = "🎯 UNIVERSAL AIMBOT & SPY MARKER SUITE PRO"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 12
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

-- PANEL DE NAVEGACIÓN IZQUIERDO (Pestañas)
local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 140, 1, -56)
navBar.Position = UDim2.new(0, 8, 0, 48)
navBar.BackgroundColor3 = PALETTE.Surface
navBar.Parent = mainFrame

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 8)
navCorner.Parent = navBar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 5)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = navBar

local navPadding = Instance.new("UIPadding")
navPadding.PaddingTop = UDim.new(0, 6)
navPadding.PaddingLeft = UDim.new(0, 5)
navPadding.PaddingRight = UDim.new(0, 5)
navPadding.Parent = navBar

-- CONTENEDOR DE PÁGINAS (DERECHA)
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -164, 1, -56)
contentFrame.Position = UDim2.new(0, 156, 0, 48)
contentFrame.BackgroundColor3 = PALETTE.Surface
contentFrame.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = contentFrame

-- CREADOR DE PÁGINAS
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

local aimbotPage = createPage("Aimbot")
local teamsPage = createPage("Teams")
local spyEspPage = createPage("SpyESP")

aimbotPage.Visible = true
currentActivePage = aimbotPage

local function addTabButton(text, pageRef)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = (pageRef == currentActivePage) and PALETTE.Primary or PALETTE.Card
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.Parent = navBar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
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

addTabButton("🎯 Apuntado", aimbotPage)
addTabButton("👥 Equipos", teamsPage)
addTabButton("👁️ Marcado Spy", spyEspPage)

-- =========================================================
-- AUXILIARES DE ELEMENTOS INTERACTIVOS
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

local function createToggleRow(parent, labelText, defaultState, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = defaultState and PALETTE.Success or PALETTE.Card
	btn.Text = labelText .. "  [" .. (defaultState and "ACTIVADO" or "DESACTIVADO") .. "]"
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
		btn.Text = labelText .. "  [" .. (state and "ACTIVADO" or "DESACTIVADO") .. "]"
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

-- =========================================================
-- DETECCIÓN UNIVERSAL DE EQUIPOS Y ENEMIGOS
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

	if table.find(State.IgnoredAimTeams, targetTeam) then
		return false
	end

	if State.TargetFFA then return true end

	if #State.TargetedTeams > 0 then
		return table.find(State.TargetedTeams, targetTeam) ~= nil
	end

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
-- SISTEMA DE MARCADOR ESP & SPY SYSTEM SINCRONIZADO
-- =========================================================
local function clearESP(character)
	if ESPCache[character] then
		if ESPCache[character].Highlight then ESPCache[character].Highlight:Destroy() end
		if ESPCache[character].Billboard then ESPCache[character].Billboard:Destroy() end
		ESPCache[character] = nil
	end
end

local function updateESP()
	if not State.ESPEnabled then
		for char, _ in pairs(ESPCache) do clearESP(char) end
		return
	end

	local myChar = LocalPlayer.Character
	if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if shouldMarkPlayerESP(player) and player.Character then
			local char = player.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")

			if hum and hum.Health > 0 and root then
				local isEnemyPlayer = shouldAimAtPlayer(player)
				local isCurrentlyLocked = (State.AimbotEnabled and State.IsAiming and player == State.CurrentLockedTargetPlayer)
				local distance = math.floor((myChar.HumanoidRootPart.Position - root.Position).Magnitude)

				if not ESPCache[char] then
					ESPCache[char] = {}

					local highlight = Instance.new("Highlight")
					highlight.Name = "SpyHighlight"
					highlight.FillTransparency = 0.3
					highlight.OutlineTransparency = 0
					highlight.Parent = char
					ESPCache[char].Highlight = highlight

					local billboard = Instance.new("BillboardGui")
					billboard.Name = "SpyBillboard"
					billboard.Size = UDim2.new(0, 140, 0, 40)
					billboard.StudsOffset = Vector3.new(0, 3.5, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = char

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.TextColor3 = PALETTE.Text
					label.TextStrokeTransparency = 0.2
					label.Font = Enum.Font.GothamBold
					label.TextSize = 11
					label.Parent = billboard

					ESPCache[char].Billboard = billboard
					ESPCache[char].TextLabel = label
				end

				local cache = ESPCache[char]
				local headPart = char:FindFirstChild("Head") or root
				local visible = isPartVisible(headPart, char)
				cache.Billboard.Adornee = headPart

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
				clearESP(char)
			end
		else
			if player.Character then clearESP(player.Character) end
		end
	end
end

-- =========================================================
-- CONFIGURACIÓN DE PESTAÑAS Y CONTROLES UI
-- =========================================================

-- PESTAÑA 1: APUNTADO (AIMBOT)
createToggleRow(aimbotPage, "🎯 Auto-Apuntado (Aimbot)", State.AimbotEnabled, function(st)
	State.AimbotEnabled = st
end)

createToggleRow(aimbotPage, "👁️ Mostrar Círculo FOV", State.ShowFOV, function(st)
	State.ShowFOV = st
	fovFrame.Visible = st
end)

createToggleRow(aimbotPage, "🧱 Detección de Coberturas / Paredes", State.WallCheck, function(st)
	State.WallCheck = st
end)

createInputRow(aimbotPage, "Tamaño del Círculo FOV:", State.FOV_Radius, 50, 800, function(val)
	State.FOV_Radius = val
	fovFrame.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

createInputRow(aimbotPage, "Velocidad Suavizado (0.1 a 1.0):", State.AimSpeed, 0.05, 1.0, function(val)
	State.AimSpeed = val
end)

createInputRow(aimbotPage, "Punto Offset X (Horizontal):", State.OffsetX, -200, 200, function(val)
	State.OffsetX = val
	centerDot.Position = UDim2.new(0.5, State.OffsetX, 0.5, State.OffsetY)
	fovFrame.Position = centerDot.Position
end)

createInputRow(aimbotPage, "Punto Offset Y (Vertical):", State.OffsetY, -200, 200, function(val)
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
targetPartBtn.Parent = aimbotPage

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

-- PESTAÑA 2: GESTIÓN UNIVERSAL DE EQUIPOS (EXCLUSIÓN AIMBOT & SPY)
createToggleRow(teamsPage, "🛡️ Filtrar por Equipos Enemigos", State.TeamCheck, function(st)
	State.TeamCheck = st
end)

createToggleRow(teamsPage, "⚔️ Modo Todos Contra Todos (FFA)", State.TargetFFA, function(st)
	State.TargetFFA = st
end)

local teamsCard = Instance.new("Frame")
teamsCard.Size = UDim2.new(1, 0, 0, 200)
teamsCard.BackgroundColor3 = PALETTE.Card
teamsCard.Parent = teamsPage

local tcCorner = Instance.new("UICorner")
tcCorner.CornerRadius = UDim.new(0, 6)
tcCorner.Parent = teamsCard

local teamsScroll = Instance.new("ScrollingFrame")
teamsScroll.Size = UDim2.new(1, -8, 1, -8)
teamsScroll.Position = UDim2.new(0, 4, 0, 4)
teamsScroll.BackgroundTransparency = 1
teamsScroll.ScrollBarThickness = 3
teamsScroll.Parent = teamsCard

local teamsLayout = Instance.new("UIListLayout")
teamsLayout.Padding = UDim.new(0, 4)
teamsLayout.Parent = teamsScroll

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

createActionButton(teamsPage, "🔄 Escanear y Actualizar Equipos", PALETTE.Primary, function()
	refreshTeamsList()
end)

refreshTeamsList()

createColorPickerRow(aimbotPage, "🎨 Color Círculo FOV / Crosshair:", State.ColorFOV, function(c)
	State.ColorFOV = c
	fovStroke.Color = c
	centerDot.BackgroundColor3 = c
end)

createColorPickerRow(aimbotPage, "🎨 Color Enemigo a la Vista (Al Alcance Aim):", State.ColorVisible, function(c)
	State.ColorVisible = c
end)

-- PESTAÑA 3: VISUALES & MARCADOR SPY (PALETA COMPLETA ESP)
createToggleRow(spyEspPage, "👁️ Activar Marcador ESP / Spy System", State.ESPEnabled, function(st)
	State.ESPEnabled = st
end)

createColorPickerRow(spyEspPage, "🎨 Color ESP Objetivo Apuntado (Aimbot):", State.ColorLockOnTarget, function(c)
	State.ColorLockOnTarget = c
end)

createColorPickerRow(spyEspPage, "🎨 Color ESP Enemigo Visible (Al Alcance):", State.ColorVisible, function(c)
	State.ColorVisible = c
end)

createColorPickerRow(spyEspPage, "🎨 Color ESP Enemigo Oculto (Detrás Muro):", State.ColorHidden, function(c)
	State.ColorHidden = c
end)

createColorPickerRow(spyEspPage, "🎨 Color ESP Jugadores Aliados:", State.ColorAlly, function(c)
	State.ColorAlly = c
end)

createActionButton(spyEspPage, "🛑 Destruir Script Definitivamente", PALETTE.Danger, function()
	State.IsActive = false
	RunService:UnbindFromRenderStep("UniversalAimAssistLoop")
	for _, conn in pairs(Connections) do conn:Disconnect() end
	for char, _ in pairs(ESPCache) do clearESP(char) end
	screenGui:Destroy()
	print("[AIMBOT SPY PRO] Script destruido y recursos liberados.")
end)

-- =========================================================
-- EVENTOS Y BUCLE DE RENDERIZADO (AIMBOT + SPY RENDER)
-- =========================================================
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
	if not State.IsActive or gpe then return end

	if input.UserInputType == State.AimKey then
		State.IsAiming = true
		fovStroke.Color = State.ColorHidden
		centerDot.BackgroundColor3 = State.ColorHidden
	elseif input.KeyCode == State.ToggleKey then
		mainFrame.Visible = not mainFrame.Visible
	end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(input)
	if not State.IsActive then return end

	if input.UserInputType == State.AimKey then
		State.IsAiming = false
		fovStroke.Color = State.ColorFOV
		centerDot.BackgroundColor3 = State.ColorFOV
	end
end))

local function onRenderUpdate()
	if not State.IsActive then return end

	-- Ejecutar Auto-Apuntado (Aimbot)
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

	-- Actualizar Marcador Spy / ESP
	updateESP()
end

RunService:BindToRenderStep("UniversalAimAssistLoop", Enum.RenderPriority.Camera.Value + 1, onRenderUpdate)

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

print("[AIMBOT SPY PRO] Sistema universal cargado con éxito. Presiona F para abrir/cerrar menú.")