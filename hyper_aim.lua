local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local isAiming = false
local isActive = true

-- ================= CONFIGURACIÓN INICIAL =================
local FOV_RADIUS = 100 
local TARGET_PART = "UpperTorso" -- Por defecto apunta al torso (mejor para proyectiles con gravedad)

local OFFSET_X = 0
local OFFSET_Y = -28
local AIM_SPEED = 0.8 
-- =========================================================

-- ================= GUI SEGURO (antidetección) =================
local SPOOFED_GUI_NAME = "AimbotPro_" .. tostring(math.random(100000, 999999))

local function getSecureGuiParent()
    local parent = nil
    if typeof(gethui) == "function" then
        pcall(function() parent = gethui() end)
    end
    if not parent and typeof(cloneref) == "function" and CoreGui then
        pcall(function() parent = cloneref(CoreGui) end)
    end
    if not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    return parent
end

local secureParent = getSecureGuiParent()
local oldGui = secureParent:FindFirstChild(SPOOFED_GUI_NAME)
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = SPOOFED_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = secureParent
-- ================================================================

-- Punto Central (Crosshair)
local centerDot = Instance.new("Frame", screenGui)
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.new(0.5, OFFSET_X, 0.5, OFFSET_Y)
centerDot.Size = UDim2.new(0, 6, 0, 6)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
local dotCorner = Instance.new("UICorner", centerDot)
dotCorner.CornerRadius = UDim.new(1, 0)

-- Círculo de FOV
local fovFrame = Instance.new("Frame", screenGui)
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = centerDot.Position
fovFrame.Size = UDim2.new(0, FOV_RADIUS * 2, 0, FOV_RADIUS * 2)
fovFrame.BackgroundTransparency = 1
local uiCorner = Instance.new("UICorner", fovFrame)
uiCorner.CornerRadius = UDim.new(1, 0)
local uiStroke = Instance.new("UIStroke", fovFrame)
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Thickness = 1.5
uiStroke.Transparency = 0.6

-- ================= MENÚ DE CONFIGURACIÓN (Tecla F) =================
local configFrame = Instance.new("Frame", screenGui)
configFrame.Size = UDim2.new(0, 260, 0, 320) -- Ajustado para hacer espacio al nuevo botón
configFrame.Position = UDim2.new(0.5, -130, 0.5, -160)
configFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
configFrame.Visible = false 
configFrame.Active = true
configFrame.Draggable = true
local configCorner = Instance.new("UICorner", configFrame)
configCorner.CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel", configFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚙️ AJUSTES DE APUNTADO"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14

-- Función para crear inputs
local function createInput(text, posY, defaultVal)
    local label = Instance.new("TextLabel", configFrame)
    label.Size = UDim2.new(0, 140, 0, 30)
    label.Position = UDim2.new(0, 10, 0, posY)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", configFrame)
    box.Size = UDim2.new(0, 80, 0, 25)
    box.Position = UDim2.new(0, 160, 0, posY + 2)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Text = tostring(defaultVal)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    local boxCorner = Instance.new("UICorner", box)
    boxCorner.CornerRadius = UDim.new(0, 4)
    return box
end

-- Controles de texto
local inputFOV = createInput("Tamaño del FOV:", 50, FOV_RADIUS)
local inputX = createInput("Punto Offset X:", 90, OFFSET_X)
local inputY = createInput("Punto Offset Y:", 130, OFFSET_Y)
local inputSpeed = createInput("Velocidad (0.01-1):", 170, AIM_SPEED)

-- BOTÓN SELECTOR DE PRIORIDAD (Cuerpo / Cabeza)
local targetToggleButton = Instance.new("TextButton", configFrame)
targetToggleButton.Size = UDim2.new(0, 230, 0, 30)
targetToggleButton.Position = UDim2.new(0, 15, 0, 215)
targetToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
targetToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
targetToggleButton.Text = "Prioridad: CUERPO"
targetToggleButton.Font = Enum.Font.GothamBold
targetToggleButton.TextSize = 12
local targetBtnCorner = Instance.new("UICorner", targetToggleButton)
targetBtnCorner.CornerRadius = UDim.new(0, 6)

local closeButton = Instance.new("TextButton", configFrame)
closeButton.Size = UDim2.new(0, 200, 0, 35)
closeButton.Position = UDim2.new(0.5, -100, 1, -45)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "APAGAR SCRIPT"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
local btnCorner = Instance.new("UICorner", closeButton)
btnCorner.CornerRadius = UDim.new(0, 6)

local connections = {}
local espCache = {}

-- ================= ACTUALIZAR UI =================
table.insert(connections, inputFOV.FocusLost:Connect(function()
    local val = tonumber(inputFOV.Text)
    if val then
        FOV_RADIUS = val
        fovFrame.Size = UDim2.new(0, FOV_RADIUS * 2, 0, FOV_RADIUS * 2)
    else inputFOV.Text = tostring(FOV_RADIUS) end
end))

local function updateDotPosition()
    centerDot.Position = UDim2.new(0.5, OFFSET_X, 0.5, OFFSET_Y)
    fovFrame.Position = centerDot.Position
end

table.insert(connections, inputX.FocusLost:Connect(function()
    local val = tonumber(inputX.Text)
    if val then OFFSET_X = val; updateDotPosition()
    else inputX.Text = tostring(OFFSET_X) end
end))

table.insert(connections, inputY.FocusLost:Connect(function()
    local val = tonumber(inputY.Text)
    if val then OFFSET_Y = val; updateDotPosition()
    else inputY.Text = tostring(OFFSET_Y) end
end))

table.insert(connections, inputSpeed.FocusLost:Connect(function()
    local val = tonumber(inputSpeed.Text)
    if val then AIM_SPEED = math.clamp(val, 0.01, 1); inputSpeed.Text = tostring(AIM_SPEED)
    else inputSpeed.Text = tostring(AIM_SPEED) end
end))

-- Lógica del botón de prioridad
table.insert(connections, targetToggleButton.MouseButton1Click:Connect(function()
    if TARGET_PART == "UpperTorso" then
        TARGET_PART = "Head"
        targetToggleButton.Text = "Prioridad: CABEZA"
        targetToggleButton.BackgroundColor3 = Color3.fromRGB(60, 120, 255) -- Azul para cabeza
    else
        TARGET_PART = "UpperTorso"
        targetToggleButton.Text = "Prioridad: CUERPO"
        targetToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50) -- Naranja para cuerpo
    end
end))

-- ================= LÓGICA DEL SISTEMA =================

-- Cache de carpetas dinámicas del juego (se refresca cada ~2s para no buscar en cada frame)
local _ignoreCache = {}
local _ignoreCacheTime = 0
local IGNORE_CACHE_TTL = 2 -- segundos

local function getIgnoreList(targetCharacter)
    local now = tick()
    if now - _ignoreCacheTime > IGNORE_CACHE_TTL then
        _ignoreCache = {}
        -- Carpeta principal de proyectiles/efectos del juego
        local ignoreThese = workspace:FindFirstChild("IgnoreThese")
        if ignoreThese then
            table.insert(_ignoreCache, ignoreThese)
            -- Sub-carpeta de límites del mapa (Boundaries)
            local boundaries = ignoreThese:FindFirstChild("Boundaries")
            if boundaries then table.insert(_ignoreCache, boundaries) end
        end
        _ignoreCacheTime = now
    end
    -- Lista final: nuestro personaje + objetivo + efectos del juego
    local list = {LocalPlayer.Character, targetCharacter}
    for _, v in ipairs(_ignoreCache) do
        table.insert(list, v)
    end
    return list
end

-- Fallback completo de partes del cuerpo: R15 → R6 → BlockRig → Raíz
local function getTargetNode(character)
    -- R15 estándar
    local part = character:FindFirstChild(TARGET_PART)
    if part then return part end
    -- R6 / UsesBlockRig usan "Torso" en vez de "UpperTorso"
    if TARGET_PART == "UpperTorso" then
        part = character:FindFirstChild("Torso")
        if part then return part end
    end
    -- Último recurso: centro del modelo (siempre existe en avatares válidos)
    return character:FindFirstChild("HumanoidRootPart")
end

local function clearESP(character)
    if espCache[character] then
        if espCache[character].Highlight then espCache[character].Highlight:Destroy() end
        if espCache[character].Billboard then espCache[character].Billboard:Destroy() end
        espCache[character] = nil
    end
end

-- Limpia entradas del espCache cuyo modelo ya no existe o está muerto
local function cleanESPCache()
    for char, _ in pairs(espCache) do
        local humanoid = char:FindFirstChild("Humanoid")
        if not char.Parent or not humanoid or humanoid.Health <= 0 then
            clearESP(char)
        end
    end
end

-- Determina si un modelo del Workspace es hostil
-- Soporta tanto jugadores reales como bots de IA (que no aparecen en Players)
local function isHostile(model)
    local myChar = LocalPlayer.Character
    if model == myChar then return false end

    -- Verificar si es un jugador registrado en Players
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character == model then
            -- Es un jugador real: usar lógica de equipos
            if player == LocalPlayer then return false end
            if LocalPlayer.Team == nil then return true end
            return player.Team ~= LocalPlayer.Team
        end
    end

    -- No está en Players → es un bot/entidad IA controlada por el servidor
    -- Se considera enemigo por defecto (el juego no indexa bots en Players)
    return true
end

-- DETECCIÓN DE PAREDES — ignora IgnoreThese, Boundaries y efectos del juego
local function isVisible(targetPart, targetCharacter)
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = getIgnoreList(targetCharacter)
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true

    local hit = workspace:Raycast(origin, direction, raycastParams)
    return hit == nil
end

-- Construye la lista de todos los modelos hostiles del Workspace
-- Incluye jugadores reales + bots de IA (escaneo agnóstico)
local function getAllEnemyModels()
    local enemies = {}
    for _, model in pairs(workspace:GetDescendants()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChildWhichIsA("Humanoid")
            local rootPart = model:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and rootPart then
                if isHostile(model) then
                    table.insert(enemies, model)
                end
            end
        end
    end
    return enemies
end

-- Contador para limpiar el cache ESP cada ~3 segundos (evita acumulación de bots muertos)
local _cleanTimer = 0
local CLEAN_INTERVAL = 3

local function updateESP()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- Limpieza periódica del caché (bots muertos, personajes removidos)
    local now = tick()
    if now - _cleanTimer > CLEAN_INTERVAL then
        cleanESPCache()
        _cleanTimer = now
    end

    -- Escaneo global: detecta tanto jugadores reales como bots de IA
    for _, char in pairs(getAllEnemyModels()) do
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then continue end

        local distance = (myRoot.Position - rootPart.Position).Magnitude

        if not espCache[char] then
            espCache[char] = {}
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.FillTransparency = 0.4
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.Parent = char
            espCache[char].Highlight = highlight

            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 100, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = char

            local textLabel = Instance.new("TextLabel", billboard)
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextStrokeTransparency = 0
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextSize = 13

            espCache[char].Billboard = billboard
            espCache[char].TextLabel = textLabel
        end

        -- Fallback completo: UpperTorso (R15) → Torso (R6/BlockRig) → HumanoidRootPart
        local targetNode = getTargetNode(char)

        if targetNode and isVisible(targetNode, char) then
            espCache[char].TextLabel.TextColor3 = Color3.fromRGB(50, 255, 50)  -- Verde = visible
        else
            espCache[char].TextLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Rojo = detrás de pared
        end

        espCache[char].TextLabel.Text = string.format("Enemigo\n[ %d m ]", math.floor(distance))
    end
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end

    local closestPart = nil
    local shortestDistance = FOV_RADIUS
    local aimCenter = centerDot.AbsolutePosition + (centerDot.AbsoluteSize / 2)

    -- Mismo escaneo global: jugadores + bots de IA
    for _, char in pairs(getAllEnemyModels()) do
        local humanoid = char:FindFirstChild("Humanoid")
        -- Fallback completo: R15 → R6 → BlockRig
        local targetNode = getTargetNode(char)

        if humanoid and humanoid.Health > 0 and targetNode then
            if isVisible(targetNode, char) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetNode.Position)

                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimCenter).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestPart = targetNode
                    end
                end
            end
        end
    end
    return closestPart
end

-- ================= CONTROLES =================
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isActive or gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = true
        uiStroke.Color = Color3.fromRGB(255, 0, 0)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end

    if input.KeyCode == Enum.KeyCode.F then
        configFrame.Visible = not configFrame.Visible
    end
end))

table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if not isActive then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = false
        uiStroke.Color = Color3.fromRGB(255, 255, 255)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end))

-- ================= APUNTADO =================
local function onRenderUpdate()
    if not isActive then return end
    updateESP()

    if isAiming then
        local target = getClosestEnemy()
        if target then
            local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
            if AIM_SPEED >= 1 then
                Camera.CFrame = targetCFrame
            else
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, AIM_SPEED)
            end
        end
    end
end

RunService:BindToRenderStep("AimAssistLoop", Enum.RenderPriority.Camera.Value + 1, onRenderUpdate)

closeButton.MouseButton1Click:Connect(function()
    isActive = false
    RunService:UnbindFromRenderStep("AimAssistLoop")
    for _, conn in pairs(connections) do conn:Disconnect() end
    for char, _ in pairs(espCache) do clearESP(char) end
    screenGui:Destroy()
end)