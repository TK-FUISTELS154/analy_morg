-- ==============================================================================
-- 🛡️ APEX COMBAT SUITE: SECURE ENGINE & HUMANIZED AIMBOT / ESP
-- ==============================================================================

local cloneref = (type(cloneref) == "function" and cloneref) or function(v) return v end

local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Detección de APIs de ratón del inyector
local mouseMoveRel = (type(mousemoverel) == "function" and mousemoverel)
    or (Input and type(Input.MouseMoveRel) == "function" and Input.MouseMoveRel)
    or nil

-- ==============================================================================
-- 1. NÚCLEO DE SEGURIDAD EMBEBIDO (SECURE.LUA ARCHITECTURE)
-- ==============================================================================
local Secure = {
    Level = 3,
    RenderBindName = "ApexCameraPipeline_" .. tostring(math.random(100000, 999999)),
    GuiContainerName = "ApexInterface_" .. tostring(math.random(100000, 999999))
}

local function evaluateSecurityContext()
    pcall(function()
        local getid = getthreadidentity or getidentity or getthreadcontext
        if type(getid) == "function" then
            Secure.Level = getid()
        end
    end)
    if type(hookmetamethod) == "function" or type(hookfunction) == "function" then
        Secure.Level = math.max(Secure.Level, 7)
    end
end
evaluateSecurityContext()

-- Protección Anti-Kick y Anti-AFK
pcall(function()
    if LocalPlayer and typeof(LocalPlayer.Kick) == "function" then
        if type(hookfunction) == "function" and type(newcclosure) == "function" then
            hookfunction(LocalPlayer.Kick, newcclosure(function() return nil end))
        else
            LocalPlayer.Kick = function() return nil end
        end
    end
end)

pcall(function()
    if type(getconnections) == "function" then
        for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
            conn:Disable()
        end
    else
        LocalPlayer.Idled:Connect(function()
            if VirtualUser then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end
        end)
    end
end)

local function getSecureGuiParent()
    local container = nil
    if type(gethui) == "function" then pcall(function() container = gethui() end) end
    if not container and type(protect_gui) == "function" and CoreGui then
        pcall(function() container = CoreGui end)
    end
    if not container and CoreGui then container = CoreGui end
    return container or LocalPlayer:WaitForChild("PlayerGui", 5)
end

-- Limpieza de ejecuciones previas
pcall(function()
    RunService:UnbindFromRenderStep("ApexCameraPipeline")
    RunService:UnbindFromRenderStep("SecureAutoAim")
end)
local secureParent = getSecureGuiParent()
for _, old in ipairs(secureParent:GetChildren()) do
    if string.find(old.Name, "ApexInterface_") or string.find(old.Name, "SecureAimControl_") then
        old:Destroy()
    end
end

----------------------------------------------------------------------
-- 2. CONFIGURACIÓN DEL SISTEMA
----------------------------------------------------------------------
local Config = {
    -- Combate
    AimbotEnabled = true,
    AimMode = "CFrame",         -- "CFrame" (Precisión garantizada) o "MouseRel" (Físico)
    AimBone = "Head",           -- "Head" o "HumanoidRootPart"
    FOVRadius = 220,            -- Radio del círculo de apuntado
    Smoothness = 3.8,           -- Suavizado (1 = Inmediato, 8 = Súper humano)
    Prediction = 0.038,         -- Compensación de velocidad del objetivo
    WallCheck = true,           -- Comprobación de obstáculos visibles
    PrioritizeBots = true,      -- Fijar primero a los bots
    BotWeight = 0.35,           -- Multiplicador de prioridad para bots

    -- Visuales
    EspEnabled = true,
    ShowInfoTags = true,
    DrawFOV = true
}

local State = {
    IsAiming = false,
    CurrentTargetPart = nil,
    CurrentModel = nil,
    CachedEntities = {},
    Highlights = {},
    Billboards = {},
    IsMinimized = false
}

----------------------------------------------------------------------
-- 3. ESCANEO INTELIGENTE DE ENTIDADES (SOPORTE FX Y WORKSPACE)
----------------------------------------------------------------------
local function isBotEntity(model: Model): boolean
    if Players:GetPlayerFromCharacter(model) ~= nil then
        return false
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and (hum.AutoRotate == false or hum.EvaluateStateMachine == false) then
        return true
    end
    return true
end

local function scanEntities()
    local myChar = LocalPlayer.Character
    local list = {}

    -- Los bots de este juego están dentro de Workspace.Fx o en Workspace raíz
    local searchContainers = { Workspace }
    local fxFolder = Workspace:FindFirstChild("Fx")
    if fxFolder then
        table.insert(searchContainers, fxFolder)
    end

    local scannedMap = {}

    for _, container in ipairs(searchContainers) do
        for _, inst in ipairs(container:GetChildren()) do
            if inst:IsA("Model") and inst ~= myChar and not scannedMap[inst] then
                local hum = inst:FindFirstChildOfClass("Humanoid")
                local root = inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart

                if hum and root and hum.Health > 0 then
                    scannedMap[inst] = true
                    table.insert(list, {
                        Model = inst,
                        Humanoid = hum,
                        RootPart = root,
                        IsBot = isBotEntity(inst)
                    })
                end
            end
        end
    end

    State.CachedEntities = list
end

task.spawn(function()
    while true do
        pcall(scanEntities)
        task.wait(0.4)
    end
end)

----------------------------------------------------------------------
-- 4. RAYCASTING Y LÍNEA DE VISIÓN FILTRADA
----------------------------------------------------------------------
local function hasLineOfSight(camPos: Vector3, targetPos: Vector3, targetModel: Model): boolean
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excludeList = { LocalPlayer.Character, targetModel }
    local fx = Workspace:FindFirstChild("Fx")
    if fx then
        local hole = fx:FindFirstChild("HoleFolder")
        local laser = fx:FindFirstChild("LaserFolder")
        if hole then table.insert(excludeList, hole) end
        if laser then table.insert(excludeList, laser) end
    end
    params.FilterDescendantsInstances = excludeList
    params.IgnoreWater = true

    local dir = targetPos - camPos
    local result = Workspace:Raycast(camPos, dir, params)

    if not result then return true end

    -- Ignora partes sin colisión o translúcidas
    local part = result.Instance
    return (part.CanCollide == false or part.Transparency >= 0.75)
end

----------------------------------------------------------------------
-- 5. SELECCIÓN DINÁMICA DEL OBJETIVO
----------------------------------------------------------------------
local function getBestTarget()
    -- Soporte para miras bloqueadas al centro (cámaras de armas) o libres
    local screenCenter = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
        and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        or UserInputService:GetMouseLocation()

    local camPos = Camera.CFrame.Position
    local bestTargetPart = nil
    local bestModel = nil
    local bestScore = math.huge

    for _, entity in ipairs(State.CachedEntities) do
        local model = entity.Model
        if model and model.Parent and entity.Humanoid.Health > 0 then
            local part = model:FindFirstChild(Config.AimBone) or entity.RootPart
            if part then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPoint.Z > 0 then
                    local screenDist = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude

                    if screenDist <= Config.FOVRadius then
                        local visible = true
                        if Config.WallCheck then
                            visible = hasLineOfSight(camPos, part.Position, model)
                        end

                        if visible then
                            local score = screenDist
                            if entity.IsBot and Config.PrioritizeBots then
                                score = score * Config.BotWeight
                            end

                            if score < bestScore then
                                bestScore = score
                                bestTargetPart = part
                                bestModel = model
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTargetPart, bestModel
end

----------------------------------------------------------------------
-- 6. MOTOR DE APUNTADO (POST-CAMERA PIPELINE)
----------------------------------------------------------------------
RunService:BindToRenderStep(Secure.RenderBindName, Enum.RenderPriority.Camera.Value + 20, function(delta)
    if not Config.AimbotEnabled then return end

    -- Detección continua de Clic Derecho
    local isRightClick = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    State.IsAiming = isRightClick

    if not isRightClick then
        State.CurrentTargetPart = nil
        State.CurrentModel = nil
        return
    end

    -- Validación y persistencia de objetivo
    local part = State.CurrentTargetPart
    local model = State.CurrentModel
    local valid = false

    if part and model and model.Parent then
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local sPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            local center = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
                and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                or UserInputService:GetMouseLocation()

            if onScreen and sPos.Z > 0 and (Vector2.new(sPos.X, sPos.Y) - center).Magnitude <= (Config.FOVRadius * 1.3) then
                if not Config.WallCheck or hasLineOfSight(Camera.CFrame.Position, part.Position, model) then
                    valid = true
                end
            end
        end
    end

    if not valid then
        part, model = getBestTarget()
        State.CurrentTargetPart = part
        State.CurrentModel = model
    end

    if not part then return end

    -- Predicción balística
    local velocity = part.AssemblyLinearVelocity or Vector3.zero
    local aimPos = part.Position + (velocity * Config.Prediction)

    if Config.AimMode == "CFrame" then
        -- Interpolación angular por encima de los scripts de armas
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, aimPos)
        local lerpSpeed = math.clamp((1 / Config.Smoothness) * (delta * 60), 0.08, 1)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, lerpSpeed)
    elseif Config.AimMode == "MouseRel" and mouseMoveRel then
        local sPoint, onScreen = Camera:WorldToViewportPoint(aimPos)
        if onScreen and sPoint.Z > 0 then
            local center = UserInputService:GetMouseLocation()
            local deltaX = (sPoint.X - center.X) / Config.Smoothness
            local deltaY = (sPoint.Y - center.Y) / Config.Smoothness
            mouseMoveRel(deltaX, deltaY)
        end
    end
end)

----------------------------------------------------------------------
-- 7. SISTEMA ESP Y RESALTADO CROMÁTICO
----------------------------------------------------------------------
local function clearEsp()
    for _, hl in pairs(State.Highlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    table.clear(State.Highlights)

    for _, bb in pairs(State.Billboards) do
        if bb and bb.Parent then bb:Destroy() end
    end
    table.clear(State.Billboards)
end

local function updateEsp()
    if not Config.EspEnabled then
        clearEsp()
        return
    end

    local activeMap = {}

    for _, entity in ipairs(State.CachedEntities) do
        local model = entity.Model
        if model and model.Parent and entity.Humanoid.Health > 0 then
            activeMap[model] = true

            local isBot = entity.IsBot
            local hlColor = isBot and Color3.fromRGB(255, 210, 40) or Color3.fromRGB(255, 45, 60)

            -- Resaltado Highlight
            local hl = State.Highlights[model]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Name = "ApexHighlight"
                hl.Adornee = model
                hl.FillTransparency = 0.35
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = model
                State.Highlights[model] = hl
            end
            hl.FillColor = hlColor
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)

            -- Marcador de información
            if Config.ShowInfoTags then
                local head = model:FindFirstChild("Head") or entity.RootPart
                local bb = State.Billboards[model]
                if not bb or not bb.Parent then
                    bb = Instance.new("BillboardGui")
                    bb.Name = "ApexTag"
                    bb.AlwaysOnTop = true
                    bb.Size = UDim2.new(0, 120, 0, 26)
                    bb.StudsOffset = Vector3.new(0, 2.6, 0)
                    bb.Adornee = head

                    local tag = Instance.new("TextLabel")
                    tag.Size = UDim2.new(1, 0, 1, 0)
                    tag.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
                    tag.BackgroundTransparency = 0.25
                    tag.Font = Enum.Font.SourceSansBold
                    tag.TextSize = 11
                    tag.Parent = bb
                    Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 5)

                    bb.Parent = head
                    State.Billboards[model] = bb
                end

                local label = bb:FindFirstChildOfClass("TextLabel")
                if label then
                    local dist = math.floor((head.Position - Camera.CFrame.Position).Magnitude)
                    label.TextColor3 = hlColor
                    label.Text = string.format("%s | %dm\nVida: %d", isBot and "🤖 BOT" or "👤 JUGADOR", dist, math.floor(entity.Humanoid.Health))
                end
            end
        end
    end

    for m, hl in pairs(State.Highlights) do
        if not activeMap[m] then
            if hl and hl.Parent then hl:Destroy() end
            State.Highlights[m] = nil
        end
    end
    for m, bb in pairs(State.Billboards) do
        if not activeMap[m] then
            if bb and bb.Parent then bb:Destroy() end
            State.Billboards[m] = nil
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.12)
        pcall(updateEsp)
    end
end)

----------------------------------------------------------------------
-- 8. CÍRCULO FOV (DRAWING API)
----------------------------------------------------------------------
local fovCircle = nil
if Drawing and Drawing.new then
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1.5
        fovCircle.Color = Color3.fromRGB(0, 255, 200)
        fovCircle.Transparency = 0.65
        fovCircle.Filled = false
        fovCircle.Visible = true

        RunService.RenderStepped:Connect(function()
            if fovCircle then
                local center = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
                    and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    or UserInputService:GetMouseLocation()

                fovCircle.Position = center
                fovCircle.Radius = Config.FOVRadius
                fovCircle.Visible = Config.AimbotEnabled and Config.DrawFOV
            end
        end)
    end)
end

----------------------------------------------------------------------
-- 9. INTERFAZ PROFESIONAL
----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = Secure.GuiContainerName
screenGui.ResetOnSpawn = false
screenGui.Parent = secureParent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 380)
main.Position = UDim2.new(0.03, 0, 0.25, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screenGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = string.format("⚡ Apex Combat Suite [Sec Lvl %d]", Secure.Level)
title.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 26, 0, 22)
minBtn.Position = UDim2.new(1, -32, 0, 7)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Font = Enum.Font.SourceSansBold
minBtn.TextSize = 14
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local body = Instance.new("ScrollingFrame")
body.Size = UDim2.new(1, -16, 1, -46)
body.Position = UDim2.new(0, 8, 0, 42)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = body

local function createToggle(name, state, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
    row.Parent = body
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, -8, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = name
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.35, -6, 0, 24)
    btn.Position = UDim2.new(0.65, 0, 0, 5)
    btn.BackgroundColor3 = state and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(150, 45, 45)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.Text = state and "ACTIVO" or "INACTIVO"
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        local newState = onToggle()
        btn.Text = newState and "ACTIVO" or "INACTIVO"
        btn.BackgroundColor3 = newState and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(150, 45, 45)
    end)
end

local function createCycle(name, currentVal, onCycle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
    row.Parent = body
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, -8, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = name
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.45, -6, 0, 24)
    btn.Position = UDim2.new(0.55, 0, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(40, 55, 80)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 11
    btn.Text = currentVal
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        local nextVal = onCycle()
        btn.Text = nextVal
    end)
end

-- Opciones de la Interfaz
createToggle("Aimbot (Clic Derecho)", Config.AimbotEnabled, function()
    Config.AimbotEnabled = not Config.AimbotEnabled
    return Config.AimbotEnabled
end)

createCycle("Modo de Apuntado", Config.AimMode, function()
    Config.AimMode = (Config.AimMode == "CFrame") and "MouseRel" or "CFrame"
    return Config.AimMode
end)

createCycle("Hueso Objetivo", Config.AimBone, function()
    Config.AimBone = (Config.AimBone == "Head") and "HumanoidRootPart" or "Head"
    return Config.AimBone
end)

createToggle("Priorizar Bots", Config.PrioritizeBots, function()
    Config.PrioritizeBots = not Config.PrioritizeBots
    return Config.PrioritizeBots
end)

createToggle("Filtro de Muros (WallCheck)", Config.WallCheck, function()
    Config.WallCheck = not Config.WallCheck
    return Config.WallCheck
end)

createToggle("ESP Resaltado", Config.EspEnabled, function()
    Config.EspEnabled = not Config.EspEnabled
    if not Config.EspEnabled then clearEsp() end
    return Config.EspEnabled
end)

createCycle("Radio FOV", tostring(Config.FOVRadius) .. " px", function()
    local fovs = {140, 220, 300, 400}
    local idx = 1
    for i, v in ipairs(fovs) do if v == Config.FOVRadius then idx = i break end end
    Config.FOVRadius = fovs[(idx % #fovs) + 1]
    return tostring(Config.FOVRadius) .. " px"
end)

createCycle("Suavizado", tostring(Config.Smoothness), function()
    local speeds = {1.5, 3.8, 6.5, 10}
    local idx = 1
    for i, v in ipairs(speeds) do if v == Config.Smoothness then idx = i break end end
    Config.Smoothness = speeds[(idx % #speeds) + 1]
    return tostring(Config.Smoothness)
end)

-- Minimizar y Arrastrar
minBtn.MouseButton1Click:Connect(function()
    State.IsMinimized = not State.IsMinimized
    body.Visible = not State.IsMinimized
    main.Size = State.IsMinimized and UDim2.new(0, 320, 0, 36) or UDim2.new(0, 320, 0, 380)
    minBtn.Text = State.IsMinimized and "+" or "-"
end)

local isDragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then isDragging = false end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and isDragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

scanEntities()