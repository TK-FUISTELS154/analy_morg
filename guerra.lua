-- 150
-- 0
-- -27
-- 1

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local isAiming = false
local isActive = true

-- ================= CONFIGURACIÓN INICIAL =================
local FOV_RADIUS = 250 
local TARGET_PART = "Head" -- Por defecto apunta a la cabeza

local TEAM_1_ACCESSORY = "Accessory (Keffiyeh_3)"
local TEAM_2_ACCESSORY = "Accessory (Afrika Balaklava)"

local OFFSET_X = 0
local OFFSET_Y = 0
local AIM_SPEED = 1 
-- =========================================================

-- Interfaz Principal
local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "AimbotPro"
screenGui.ResetOnSpawn = false

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
targetToggleButton.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
targetToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
targetToggleButton.Text = "Prioridad: CABEZA"
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
    if TARGET_PART == "Head" then
        TARGET_PART = "UpperTorso"
        targetToggleButton.Text = "Prioridad: CUERPO"
        targetToggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50) -- Naranja para cuerpo
    else
        TARGET_PART = "Head"
        targetToggleButton.Text = "Prioridad: CABEZA"
        targetToggleButton.BackgroundColor3 = Color3.fromRGB(60, 120, 255) -- Azul para cabeza
    end
end))

-- ================= LÓGICA DEL SISTEMA =================
local function getPlayerTeam(character)
    if character:FindFirstChild(TEAM_1_ACCESSORY) then return 1
    elseif character:FindFirstChild(TEAM_2_ACCESSORY) then return 2 end
    return nil
end

local function clearESP(character)
    if espCache[character] then
        if espCache[character].Highlight then espCache[character].Highlight:Destroy() end
        if espCache[character].Billboard then espCache[character].Billboard:Destroy() end
        espCache[character] = nil
    end
end

-- DETECCIÓN DE PAREDES
local function isVisible(targetPart, targetCharacter)
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local hit = workspace:Raycast(origin, direction, raycastParams)
    return hit == nil
end

local function updateESP()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myTeam = getPlayerTeam(myChar)
    if not myTeam then return end

    local liveFolder = workspace:FindFirstChild("Live")
    if not liveFolder then return end

    for _, char in pairs(liveFolder:GetChildren()) do
        if char == myChar then continue end
        local enemyTeam = getPlayerTeam(char)
        local humanoid = char:FindFirstChild("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart")

        if enemyTeam and enemyTeam ~= myTeam and humanoid and humanoid.Health > 0 and rootPart then
            local distance = (myChar.HumanoidRootPart.Position - rootPart.Position).Magnitude

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
                textLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                textLabel.TextStrokeTransparency = 0
                textLabel.Font = Enum.Font.GothamBold
                textLabel.TextSize = 13
                
                espCache[char].Billboard = billboard
                espCache[char].TextLabel = textLabel
            end
            
            local targetNode = char:FindFirstChild(TARGET_PART) -- Comprueba la visibilidad de la parte seleccionada
            if targetNode and isVisible(targetNode, char) then
                espCache[char].TextLabel.TextColor3 = Color3.fromRGB(50, 255, 50) 
            else
                espCache[char].TextLabel.TextColor3 = Color3.fromRGB(255, 100, 100) 
            end
            
            espCache[char].TextLabel.Text = string.format("Enemigo\n[ %d m ]", math.floor(distance))
        else
            clearESP(char)
        end
    end
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myTeam = getPlayerTeam(myChar)
    if not myTeam then return nil end

    local closestPart = nil
    local shortestDistance = FOV_RADIUS
    
    local aimCenter = centerDot.AbsolutePosition + (centerDot.AbsoluteSize / 2)
    local liveFolder = workspace:FindFirstChild("Live")
    if not liveFolder then return nil end

    for _, char in pairs(liveFolder:GetChildren()) do
        if char == myChar then continue end
        local enemyTeam = getPlayerTeam(char)
        
        if enemyTeam and enemyTeam ~= myTeam then
            local humanoid = char:FindFirstChild("Humanoid")
            local targetNode = char:FindFirstChild(TARGET_PART) -- Busca la Cabeza o el Pecho según lo que elijas
            
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