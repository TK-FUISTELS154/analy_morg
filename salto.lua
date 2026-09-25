--[[
	===========================================================
	UNIVERSAL MATERIAL ADMIN & MOVEMENT PANEL (LOCAL SCRIPT)
	===========================================================
	Instrucciones de uso:
	1. Copia este script en un LocalScript dentro de StarterPlayerScripts o StarterGui.
	2. Opciones de acceso: Presiona 'F2' para ocultar/mostrar el panel.
	3. Incluye: Modificación de Velocidad, Salto Infinito, Teleport por Coordenadas,
	   Teleport a Jugadores, Noclip y Panel Estilo Material Design.
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- =========================================================
-- CONFIGURACIÓN GLOBAL DE VARIABLES
-- =========================================================
local config = {
	WalkSpeed = 32,
	DefaultSpeed = 16,
	JumpPower = 50,
	DefaultJump = 50,
	InfiniteJump = false,
	Noclip = false,
	ToggleKey = Enum.KeyCode.F2,
	SpeedKey = Enum.KeyCode.LeftShift,
	TP_X = 0,
	TP_Y = 10,
	TP_Z = 0
}

local isSpeedActive = false
local selectedPlayerName = nil
local listeningForKey = nil
local scriptConnections = {}

-- Paleta de Colores Material Design (Dark Theme)
local PALETTE = {
	Background = Color3.fromRGB(24, 24, 28),
	Surface = Color3.fromRGB(34, 34, 40),
	Card = Color3.fromRGB(44, 44, 52),
	InputBg = Color3.fromRGB(54, 54, 64),
	Primary = Color3.fromRGB(103, 80, 164),
	PrimaryActive = Color3.fromRGB(128, 98, 205),
	AccentBlue = Color3.fromRGB(2, 136, 209),
	Success = Color3.fromRGB(46, 125, 50),
	Danger = Color3.fromRGB(198, 40, 40),
	Text = Color3.fromRGB(240, 240, 245),
	TextMuted = Color3.fromRGB(160, 160, 175),
	Stroke = Color3.fromRGB(60, 60, 72)
}

-- =========================================================
-- CONSTRUCCIÓN DE LA INTERFAZ GRÁFICA (GUI)
-- =========================================================
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Eliminar versión anterior si existe
local oldGui = playerGui:FindFirstChild("MaterialAdminLocalGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MaterialAdminLocalGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Frame Principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 410)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -205)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = PALETTE.Stroke
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- BARRA SUPERIOR (HEADER)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = PALETTE.Surface
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ UNIVERSAL ADMIN & MOVEMENT PANEL"
title.TextColor3 = PALETTE.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -33, 0, 7)
closeBtn.BackgroundColor3 = PALETTE.Danger
closeBtn.Text = "✕"
closeBtn.TextColor3 = PALETTE.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- PANEL DE NAVEGACIÓN (TABS IZQUIERDA)
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(0, 130, 1, -50)
tabContainer.Position = UDim2.new(0, 8, 0, 45)
tabContainer.BackgroundColor3 = PALETTE.Surface
tabContainer.Parent = mainFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 8)
tabCorner.Parent = tabContainer

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabContainer

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingTop = UDim.new(0, 8)
tabPadding.PaddingLeft = UDim.new(0, 6)
tabPadding.PaddingRight = UDim.new(0, 6)
tabPadding.Parent = tabContainer

-- CONTENEDOR DE PÁGINAS (DERECHA)
local pagesFolder = Instance.new("Frame")
pagesFolder.Name = "Pages"
pagesFolder.Size = UDim2.new(1, -154, 1, -50)
pagesFolder.Position = UDim2.new(0, 146, 0, 45)
pagesFolder.BackgroundColor3 = PALETTE.Surface
pagesFolder.Parent = mainFrame

local pagesCorner = Instance.new("UICorner")
pagesCorner.CornerRadius = UDim.new(0, 8)
pagesCorner.Parent = pagesFolder

-- Funciones para manejar Pestañas
local activePage = nil

local function createPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, -12, 1, -12)
	page.Position = UDim2.new(0, 6, 0, 6)
	page.BackgroundTransparency = 1
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = PALETTE.Primary
	page.Visible = false
	page.Parent = pagesFolder

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 8)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page

	return page
end

local movementPage = createPage("Movement")
movementPage.Visible = true
activePage = movementPage

local teleportPage = createPage("Teleport")
local playersPage = createPage("Players")

local function createTabButton(text, targetPage)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = (targetPage == activePage) and PALETTE.Primary or PALETTE.Card
	btn.Text = text
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = tabContainer

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		for _, child in ipairs(pagesFolder:GetChildren()) do
			if child:IsA("ScrollingFrame") then child.Visible = false end
		end
		for _, b in ipairs(tabContainer:GetChildren()) do
			if b:IsA("TextButton") then b.BackgroundColor3 = PALETTE.Card end
		end
		targetPage.Visible = true
		activePage = targetPage
		btn.BackgroundColor3 = PALETTE.Primary
	end)

	return btn
end

createTabButton("🏃 Movimiento", movementPage)
createTabButton("📍 Teleport XYZ", teleportPage)
createTabButton("👥 Jugadores", playersPage)

-- =========================================================
-- CONTENIDOS DE CADA PESTAÑA
-- =========================================================

-- 1. PESTAÑA MOVIMIENTO
local function createInputRow(parent, labelText, defaultValue, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = PALETTE.Card
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = PALETTE.Text
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.3, -10, 0, 24)
	box.Position = UDim2.new(0.7, 0, 0, 6)
	box.BackgroundColor3 = PALETTE.InputBg
	box.Text = tostring(defaultValue)
	box.TextColor3 = PALETTE.Text
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.Parent = row

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = box

	box.FocusLost:Connect(function()
		local val = tonumber(box.Text)
		if val and callback then
			callback(val)
		else
			box.Text = tostring(defaultValue)
		end
	end)
end

createInputRow(movementPage, "Velocidad (WalkSpeed):", config.WalkSpeed, function(val)
	config.WalkSpeed = val
end)

createInputRow(movementPage, "Fuerza Salto (JumpPower):", config.JumpPower, function(val)
	config.JumpPower = val
end)

-- Botón Toggle Salto Infinito
local function createToggle(parent, labelText, defaultState, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = defaultState and PALETTE.Success or PALETTE.Card
	btn.Text = labelText .. ": " .. (defaultState and "ACTIVADO" or "DESACTIVADO")
	btn.TextColor3 = PALETTE.Text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local state = defaultState
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.BackgroundColor3 = state and PALETTE.Success or PALETTE.Card
		btn.Text = labelText .. ": " .. (state and "ACTIVADO" or "DESACTIVADO")
		if callback then callback(state) end
	end)
end

createToggle(movementPage, "Salto Infinito (En Aire)", config.InfiniteJump, function(st)
	config.InfiniteJump = st
end)

createToggle(movementPage, "Modo Atravesar Paredes (Noclip)", config.Noclip, function(st)
	config.Noclip = st
end)

-- 2. PESTAÑA TELEPORT (XYZ)
local xyzFrame = Instance.new("Frame")
xyzFrame.Size = UDim2.new(1, 0, 0, 40)
xyzFrame.BackgroundColor3 = PALETTE.Card
xyzFrame.Parent = teleportPage

local xyzCorner = Instance.new("UICorner")
xyzCorner.CornerRadius = UDim.new(0, 6)
xyzCorner.Parent = xyzFrame

local function createXYZBox(name, posX, defaultVal)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.3, -8, 0, 26)
	box.Position = UDim2.new(posX, 5, 0, 7)
	box.BackgroundColor3 = PALETTE.InputBg
	box.PlaceholderText = name
	box.Text = tostring(defaultVal)
	box.TextColor3 = PALETTE.Text
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.Parent = xyzFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = box
	return box
end

local boxX = createXYZBox("X", 0, config.TP_X)
local boxY = createXYZBox("Y", 0.33, config.TP_Y)
local boxZ = createXYZBox("Z", 0.66, config.TP_Z)

local function getPos()
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			config.TP_X = math.floor(root.Position.X)
			config.TP_Y = math.floor(root.Position.Y)
			config.TP_Z = math.floor(root.Position.Z)
			boxX.Text = tostring(config.TP_X)
			boxY.Text = tostring(config.TP_Y)
			boxZ.Text = tostring(config.TP_Z)
		end
	end
end

local getPosBtn = Instance.new("TextButton")
getPosBtn.Size = UDim2.new(1, 0, 0, 32)
getPosBtn.BackgroundColor3 = PALETTE.AccentBlue
getPosBtn.Text = "📍 Obtener Posición Actual"
getPosBtn.TextColor3 = PALETTE.Text
getPosBtn.Font = Enum.Font.GothamBold
getPosBtn.TextSize = 11
getPosBtn.Parent = teleportPage

local getPosCorner = Instance.new("UICorner")
getPosCorner.CornerRadius = UDim.new(0, 6)
getPosCorner.Parent = getPosBtn

getPosBtn.MouseButton1Click:Connect(getPos)

local doTpBtn = Instance.new("TextButton")
doTpBtn.Size = UDim2.new(1, 0, 0, 34)
doTpBtn.BackgroundColor3 = PALETTE.Primary
doTpBtn.Text = "🚀 TELETRANSPORTAR A COORDENADAS"
doTpBtn.TextColor3 = PALETTE.Text
doTpBtn.Font = Enum.Font.GothamBold
doTpBtn.TextSize = 11
doTpBtn.Parent = teleportPage

local doTpCorner = Instance.new("UICorner")
doTpCorner.CornerRadius = UDim.new(0, 6)
doTpCorner.Parent = doTpBtn

doTpBtn.MouseButton1Click:Connect(function()
	local x = tonumber(boxX.Text) or config.TP_X
	local y = tonumber(boxY.Text) or config.TP_Y
	local z = tonumber(boxZ.Text) or config.TP_Z
	local char = LocalPlayer.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(x, y, z)
		end
	end
end)

-- 3. PESTAÑA JUGADORES
local selectedPlayerLabel = Instance.new("TextLabel")
selectedPlayerLabel.Size = UDim2.new(1, 0, 0, 24)
selectedPlayerLabel.BackgroundTransparency = 1
selectedPlayerLabel.Text = "Seleccionado: Ninguno"
selectedPlayerLabel.TextColor3 = PALETTE.AccentBlue
selectedPlayerLabel.Font = Enum.Font.GothamBold
selectedPlayerLabel.TextSize = 11
selectedPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedPlayerLabel.Parent = playersPage

local playerButtonsFrame = Instance.new("Frame")
playerButtonsFrame.Size = UDim2.new(1, 0, 0, 36)
playerButtonsFrame.BackgroundTransparency = 1
playerButtonsFrame.Parent = playersPage

local tpToPlayerBtn = Instance.new("TextButton")
tpToPlayerBtn.Size = UDim2.new(1, 0, 0, 32)
tpToPlayerBtn.BackgroundColor3 = PALETTE.Primary
tpToPlayerBtn.Text = "Teletransportarse al Jugador"
tpToPlayerBtn.TextColor3 = PALETTE.Text
tpToPlayerBtn.Font = Enum.Font.GothamBold
tpToPlayerBtn.TextSize = 11
tpToPlayerBtn.Parent = playerButtonsFrame

local tpPlayerCorner = Instance.new("UICorner")
tpPlayerCorner.CornerRadius = UDim.new(0, 6)
tpPlayerCorner.Parent = tpToPlayerBtn

tpToPlayerBtn.MouseButton1Click:Connect(function()
	if selectedPlayerName then
		local target = Players:FindFirstChild(selectedPlayerName)
		if target and target.Character then
			local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
			local myChar = LocalPlayer.Character
			if targetRoot and myChar and myChar:FindFirstChild("HumanoidRootPart") then
				myChar.HumanoidRootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
			end
		end
	end
end)

local playerListContainer = Instance.new("Frame")
playerListContainer.Size = UDim2.new(1, 0, 0, 160)
playerListContainer.BackgroundColor3 = PALETTE.Card
playerListContainer.Parent = playersPage

local plCorner = Instance.new("UICorner")
plCorner.CornerRadius = UDim.new(0, 6)
plCorner.Parent = playerListContainer

local plScroll = Instance.new("ScrollingFrame")
plScroll.Size = UDim2.new(1, -8, 1, -8)
plScroll.Position = UDim2.new(0, 4, 0, 4)
plScroll.BackgroundTransparency = 1
plScroll.ScrollBarThickness = 3
plScroll.Parent = playerListContainer

local plLayout = Instance.new("UIListLayout")
plLayout.Padding = UDim.new(0, 4)
plLayout.Parent = plScroll

local function updatePlayersListUI()
	for _, c in ipairs(plScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 26)
			b.BackgroundColor3 = (selectedPlayerName == p.Name) and PALETTE.Primary or PALETTE.InputBg
			b.Text = "  " .. p.Name
			b.TextColor3 = PALETTE.Text
			b.Font = Enum.Font.Gotham
			b.TextSize = 11
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Parent = plScroll

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 4)
			bCorner.Parent = b

			b.MouseButton1Click:Connect(function()
				selectedPlayerName = p.Name
				selectedPlayerLabel.Text = "Seleccionado: " .. p.Name
				updatePlayersListUI()
			end)
		end
	end
end

Players.PlayerAdded:Connect(updatePlayersListUI)
Players.PlayerRemoving:Connect(function(p)
	if selectedPlayerName == p.Name then
		selectedPlayerName = nil
		selectedPlayerLabel.Text = "Seleccionado: Ninguno"
	end
	updatePlayersListUI()
end)
updatePlayersListUI()

-- =========================================================
-- CONTROL DE EVENTOS (TECLADO & LOOP DE EJECUCIÓN)
-- =========================================================

-- Tecla Shift para Activar Velocidad
table.insert(scriptConnections, UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == config.SpeedKey then
		isSpeedActive = true
	elseif input.KeyCode == config.ToggleKey then
		mainFrame.Visible = not mainFrame.Visible
	elseif input.KeyCode == Enum.KeyCode.Space and config.InfiniteJump then
		local char = LocalPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if humanoid and root then
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
					root.Velocity = Vector3.new(root.Velocity.X, config.JumpPower, root.Velocity.Z)
				end
			end
		end
	end
end))

table.insert(scriptConnections, UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == config.SpeedKey then
		isSpeedActive = false
	end
end))

-- RenderStepped Loop para Velocidad y Noclip
table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if isSpeedActive then
				humanoid.WalkSpeed = config.WalkSpeed
			else
				humanoid.WalkSpeed = config.DefaultSpeed
			end
		end

		if config.Noclip then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end
end))

-- Botón Cerrar (Apagar Script)
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

print("[MATERIAL ADMIN] Panel cargado correctamente en un solo LocalScript. Usa F2 para mostrar/ocultar.")