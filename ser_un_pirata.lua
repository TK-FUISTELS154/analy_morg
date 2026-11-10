-- ==============================================================================
-- 🏴‍☠️ CHESTS & TREASURE TRACKER PRO + ADVANCED MOVEMENT & SERVER HOPPER
-- Versión Ultra: Vista Previa 3D en Vivo de Cofres (ViewportFrame),
-- Shift Sprint (250 default), JumpPower (150 default),
-- Preservación Dinámica de Velocidad Nativa del Juego / Barcos, Server Hop & Auto Re-ejecución
-- Adaptado para World.Dynamic y Sistema de Mapas del Tesoro
-- ==============================================================================

-- ==============================================================================
-- 0. SINGLETON PATTERN: DESTRUIR INSTANCIAS PREVIAS Y PREVENIR DOBLE GUI
-- ==============================================================================
if _G.MontaMascotaInstance and type(_G.MontaMascotaInstance.Destroy) == "function" then
    pcall(function() _G.MontaMascotaInstance.Destroy() end)
end

pcall(function()
    local oldGui = (type(gethui) == "function" and gethui():FindFirstChild("EggTrackerPro_GUI"))
        or (game:GetService("CoreGui"):FindFirstChild("EggTrackerPro_GUI"))
        or (game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("EggTrackerPro_GUI"))
    if oldGui then
        oldGui:Destroy()
    end
end)

local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

local function getService(className)
    if className == "Workspace" and typeof(workspace) == "Instance" then return workspace end
    local ok, s = pcall(function() return rawGame:GetService(className) end)
    if ok and s then return s end
    local ok2, s2 = pcall(function() return rawGame:FindFirstChildOfClass(className) end)
    if ok2 and s2 then return s2 end
    local ok3, s3 = pcall(function() return rawGame:FindFirstChildWhichIsA(className) end)
    if ok3 and s3 then return s3 end
    return nil
end

local Workspace = getService("Workspace") or workspace
local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local UserInputService = getService("UserInputService")
local RunService = getService("RunService")
local VirtualUser = getService("VirtualUser")
local TeleportService = getService("TeleportService")
local HttpService = getService("HttpService")

local LocalPlayer = (Players and Players.LocalPlayer) or (Players and Players:FindFirstChildOfClass("Player")) or (Players and Players.PlayerAdded:Wait())
local PlayerGui = (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 10)) or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))

-- Módulos compartidos del juego actual (Registry / Config)
local Shared = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Shared")
local Registry = nil
pcall(function()
    if Shared and Shared:FindFirstChild("Util") and Shared.Util:FindFirstChild("Registry") then
        Registry = require(Shared.Util.Registry)
    end
end)

local IslandsConfig = nil
pcall(function()
    if Shared and Shared:FindFirstChild("Config") and Shared.Config:FindFirstChild("Islands") then
        IslandsConfig = require(Shared.Config.Islands)
    end
end)

--------------------------------------------------------------------------------
-- 1. SEGURIDAD Y CONFIGURACIÓN PERSISTENTE
--------------------------------------------------------------------------------
local connections = {}
local runningThreads = {}
local isScriptActive = true

-- Anti-Kick local
pcall(function()
    if LocalPlayer and typeof(LocalPlayer.Kick) == "function" then
        LocalPlayer.Kick = function(...) return nil end
    end
end)

-- Anti-AFK
if VirtualUser then
    local afkConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    table.insert(connections, afkConn)
end

-- Aislamiento de hilos protegidos
local function SpawnSafe(name, fn, ...)
    local args = { ... }
    local thread = task.spawn(function()
        local ok, err = pcall(function()
            fn(table.unpack(args))
        end)
        if not ok and _G.SECURE_DEBUG then
            warn("[SECURE-TRACKER][" .. tostring(name) .. "] " .. tostring(err))
        end
    end)
    table.insert(runningThreads, thread)
    return thread
end

-- ==============================================================================
-- 2. GESTOR DE CONFIGURACIÓN (.JSON)
-- ==============================================================================
local CONFIG_FILE = "chest_tracker_config.json"
local Config = {
    SprintEnabled = true,
    SprintSpeed = 250,
    JumpEnabled = true,
    JumpPower = 150,
    InfJump = false,
    Noclip = false,
    SortMode = "Luck",
    AutoReexecute = true,
    MinPlayerHop = true,
}

local function saveConfig()
    pcall(function()
        if writefile and HttpService then
            local data = HttpService:JSONEncode(Config)
            writefile(CONFIG_FILE, data)
        end
    end)
end

local function loadConfig()
    pcall(function()
        if isfile and readfile and HttpService and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    Config[k] = v
                end
            end
        end
    end)
end
loadConfig()

--------------------------------------------------------------------------------
-- 3. TABLA DE VALORES ESTIMADOS (💰) Y RAREZAS DE COFRES
--------------------------------------------------------------------------------
local CHEST_VALUE_TABLE = {
    ["Common Chest"]     = 1000,
    ["Wooden Chest"]     = 1000,
    ["Bronze Chest"]     = 2500,
    ["Iron Chest"]       = 5000,
    ["Silver Chest"]     = 15000,
    ["Rare Chest"]       = 25000,
    ["Golden Chest"]     = 75000,
    ["Gold Chest"]       = 75000,
    ["Epic Chest"]       = 150000,
    ["Ruby Chest"]       = 300000,
    ["Emerald Chest"]    = 500000,
    ["Diamond Chest"]    = 1000000,
    ["Legendary Chest"]  = 2500000,
    ["Mythic Chest"]     = 10000000,
    ["Ancient Chest"]    = 25000000,
    ["Cursed Chest"]     = 50000000,
    ["Divine Chest"]     = 100000000,
    ["Ethereal Chest"]   = 500000000,
    ["Sunken Chest"]     = 500000,
    ["Boss Chest"]       = 5000000
}

local CHEST_RARITY_TABLE = {
    ["Common Chest"] = "Common", ["Wooden Chest"] = "Common", ["Bronze Chest"] = "Common",
    ["Iron Chest"] = "Rare", ["Silver Chest"] = "Rare", ["Rare Chest"] = "Rare",
    ["Golden Chest"] = "Epic", ["Gold Chest"] = "Epic", ["Epic Chest"] = "Epic", ["Sunken Chest"] = "Epic",
    ["Ruby Chest"] = "Legendary", ["Emerald Chest"] = "Legendary", ["Diamond Chest"] = "Legendary", ["Legendary Chest"] = "Legendary",
    ["Mythic Chest"] = "Mythic", ["Ancient Chest"] = "Mythic", ["Cursed Chest"] = "Mythic", ["Boss Chest"] = "Mythic",
    ["Divine Chest"] = "Divine",
    ["Ethereal Chest"] = "Ethereal"
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(173, 173, 173),
    Rare      = Color3.fromRGB(0, 170, 255),
    Epic      = Color3.fromRGB(170, 85, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic    = Color3.fromRGB(255, 85, 120),
    Mythical  = Color3.fromRGB(255, 85, 120),
    Divine    = Color3.fromRGB(255, 235, 50),
    Ethereal  = Color3.fromRGB(140, 240, 255),
    Secret    = Color3.fromRGB(255, 50, 50),
    Unknown   = Color3.fromRGB(180, 160, 120)
}

local function formatLuck(val)
    if not val or val <= 0 then return "1" end
    if val >= 1e12 then return string.format("%.1fT", val / 1e12):gsub("%.0T", "T") end
    if val >= 1e9  then return string.format("%.1fB", val / 1e9):gsub("%.0B", "B") end
    if val >= 1e6  then return string.format("%.1fM", val / 1e6):gsub("%.0M", "M") end
    if val >= 1e3  then return string.format("%.1fK", val / 1e3):gsub("%.0K", "K") end
    return tostring(math.floor(val))
end

--------------------------------------------------------------------------------
-- 4. SISTEMA DE FÍSICAS: SHIFT SPRINT & PRESERVACIÓN TOTAL DE VELOCIDAD NATIVA / BARCOS
--------------------------------------------------------------------------------
local nativeWalkSpeed = 16
local isShiftHeld = false
local charConnections = {}
local updateStatusTelemetry = nil

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChildOfClass("Humanoid") or char:FindFirstChild("Humanoid"))
end

local function applyJumpPower(hum)
    if not hum then return end
    if Config.JumpEnabled then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        end)
    end
end

local function isShiftCurrentlyPressed()
    local ok1, k1 = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) end)
    local ok2, k2 = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end)
    return (ok1 and k1) or (ok2 and k2) or false
end

local function bindCharacterPhysics(char)
    for _, c in ipairs(charConnections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(charConnections)

    if not char then return end
    local hum = char:WaitForChild("Humanoid", 8) or char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if not isShiftCurrentlyPressed() then
        nativeWalkSpeed = hum.WalkSpeed
    end
    applyJumpPower(hum)

    local wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        local shiftActive = Config.SprintEnabled and isShiftCurrentlyPressed()
        if not shiftActive then
            nativeWalkSpeed = hum.WalkSpeed
            if updateStatusTelemetry then updateStatusTelemetry() end
        else
            if hum.WalkSpeed ~= (tonumber(Config.SprintSpeed) or 250) then
                nativeWalkSpeed = hum.WalkSpeed
                hum.WalkSpeed = tonumber(Config.SprintSpeed) or 250
            end
        end
    end)
    table.insert(charConnections, wsConn)

    local jpConn = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if Config.JumpEnabled and hum.JumpPower ~= Config.JumpPower then
            pcall(function()
                hum.UseJumpPower = true
                hum.JumpPower = Config.JumpPower
            end)
        end
    end)
    table.insert(charConnections, jpConn)

    if updateStatusTelemetry then updateStatusTelemetry() end
end

local speedHeartbeat = RunService.RenderStepped:Connect(function()
    if not isScriptActive then return end
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then return end

    local shiftPressed = Config.SprintEnabled and isShiftCurrentlyPressed()

    if shiftPressed then
        isShiftHeld = true
        local targetSprint = tonumber(Config.SprintSpeed) or 250
        if hum.WalkSpeed ~= targetSprint then
            hum.WalkSpeed = targetSprint
        end

        if hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
            pcall(function()
                hum.SeatPart.MaxSpeed = targetSprint
            end)
        end
    else
        if isShiftHeld then
            isShiftHeld = false
            hum.WalkSpeed = nativeWalkSpeed
        end
    end
end)
table.insert(connections, speedHeartbeat)

local infJumpConn = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and isScriptActive then
        local hum = getHumanoid()
        if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
table.insert(connections, infJumpConn)

local noclipConn = RunService.Stepped:Connect(function()
    if Config.Noclip and isScriptActive and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)
table.insert(connections, noclipConn)

if LocalPlayer.Character then
    bindCharacterPhysics(LocalPlayer.Character)
end
local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.2)
    bindCharacterPhysics(newChar)
end)
table.insert(connections, charAddedConn)

--------------------------------------------------------------------------------
-- 5. SERVER HOPPER Y AUTO RE-EJECUCIÓN
--------------------------------------------------------------------------------
local RAW_GITHUB_URL = "https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/ser_un_pirata.lua"

local isTeleporting = false
local function queueTeleportCode(codeStr)
    if isTeleporting then return end
    isTeleporting = true
    pcall(function()
        local queue_teleport = (syn and syn.queue_on_teleport)
            or queue_on_teleport
            or (fluxus and fluxus.queue_on_teleport)
            or (identifyexecutor and queue_on_teleport)
        if queue_teleport then
            queue_teleport(codeStr)
        end
    end)
end

local function getReexecScript()
    return string.format([[
        repeat task.wait() until game:IsLoaded()
        task.wait(1.5)
        pcall(function()
            if isfile and isfile("monta_una_mascota.lua") then
                loadstring(readfile("monta_una_mascota.lua"))()
            elseif isfile and isfile("scripts/monta_una_mascota.lua") then
                loadstring(readfile("scripts/monta_una_mascota.lua"))()
            else
                loadstring(game:HttpGet("%s"))()
            end
        end)
    ]], RAW_GITHUB_URL)
end

local function executeServerHop(preferLowPlayers)
    saveConfig()

    if Config.AutoReexecute then
        queueTeleportCode(getReexecScript())
    end

    local placeId = game.PlaceId
    local currentJobId = game.JobId

    task.spawn(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)
        local rawResponse = nil

        pcall(function()
            if typeof(game.HttpGet) == "function" then
                rawResponse = game:HttpGet(url)
            elseif typeof(http_request) == "function" then
                local res = http_request({ Url = url, Method = "GET" })
                rawResponse = res and res.Body
            elseif typeof(request) == "function" then
                local res = request({ Url = url, Method = "GET" })
                rawResponse = res and res.Body
            end
        end)

        if rawResponse then
            local ok, decoded = pcall(function() return HttpService:JSONDecode(rawResponse) end)
            if ok and decoded and decoded.data then
                local serverList = {}
                for _, srv in ipairs(decoded.data) do
                    if srv.id ~= currentJobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                        table.insert(serverList, srv)
                    end
                end

                if #serverList > 0 then
                    if preferLowPlayers then
                        table.sort(serverList, function(a, b) return a.playing < b.playing end)
                    end
                    local targetServer = serverList[1]
                    TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
                    return
                end
            end
        end

        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

local function executeRejoin()
    saveConfig()
    if Config.AutoReexecute then
        queueTeleportCode(getReexecScript())
    end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end

--------------------------------------------------------------------------------
-- 6. GESTOR DE FAROS 3D (BEACONS & HIGHLIGHTS)
--------------------------------------------------------------------------------
local activeTrackers = {}
local cachedEggCards = {}
local selectedEggData = nil

local function removeTracker(uuid)
    local tr = activeTrackers[uuid]
    if tr then
        pcall(function()
            if tr.Clean then tr.Clean() end
        end)
        activeTrackers[uuid] = nil
    end
end

local function clearAllTrackers()
    for id, _ in pairs(activeTrackers) do
        removeTracker(id)
    end
end

local function createHighVisibilityTracker(data)
    removeTracker(data.UUID)

    local uuid = data.UUID
    local pos = data.Position
    local color = data.Color

    local trackerFolder = Instance.new("Folder")
    trackerFolder.Name = "Tracker_" .. tostring(uuid)
    trackerFolder.Parent = workspace

    local bAnchor = Instance.new("Part")
    bAnchor.Name = "BottomAnchor"
    bAnchor.Size = Vector3.new(1, 1, 1)
    bAnchor.Position = pos
    bAnchor.Anchored = true
    bAnchor.CanCollide = false
    bAnchor.Transparency = 1
    bAnchor.Parent = trackerFolder

    local tAnchor = Instance.new("Part")
    tAnchor.Name = "TopAnchor"
    tAnchor.Size = Vector3.new(1, 1, 1)
    tAnchor.Position = pos + Vector3.new(0, 500, 0)
    tAnchor.Anchored = true
    tAnchor.CanCollide = false
    tAnchor.Transparency = 1
    tAnchor.Parent = trackerFolder

    local a0 = Instance.new("Attachment", bAnchor)
    local a1 = Instance.new("Attachment", tAnchor)

    -- Faro de luz vertical hacia el cielo
    local skyBeam = Instance.new("Beam")
    skyBeam.Attachment0 = a0
    skyBeam.Attachment1 = a1
    skyBeam.Width0 = 3.5
    skyBeam.Width1 = 0.8
    skyBeam.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
    skyBeam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.8, 0.25),
        NumberSequenceKeypoint.new(1, 1)
    })
    skyBeam.FaceCamera = true
    skyBeam.LightEmission = 1
    skyBeam.LightInfluence = 0
    skyBeam.Parent = trackerFolder

    -- Línea guía directa desde el jugador
    local tracerBeam = Instance.new("Beam")
    tracerBeam.Name = "TracerLine"
    tracerBeam.Width0 = 0.6
    tracerBeam.Width1 = 0.6
    tracerBeam.Color = ColorSequence.new(color)
    tracerBeam.FaceCamera = true
    tracerBeam.LightEmission = 1
    tracerBeam.Attachment0 = a0
    tracerBeam.Parent = trackerFolder

    local function hookPlayerTracer()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pAtt = hrp:FindFirstChild("TrackerAtt") or Instance.new("Attachment")
            pAtt.Name = "TrackerAtt"
            pAtt.Parent = hrp
            tracerBeam.Attachment1 = pAtt
        end
    end
    hookPlayerTracer()

    -- Cartel 3D
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 175, 0, 54)
    bb.StudsOffset = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 50000
    bb.Adornee = bAnchor
    bb.Parent = trackerFolder

    local tagFrame = Instance.new("Frame", bb)
    tagFrame.Size = UDim2.new(1, 0, 1, 0)
    tagFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    tagFrame.BackgroundTransparency = 0.15
    tagFrame.BorderSizePixel = 0
    Instance.new("UICorner", tagFrame).CornerRadius = UDim.new(0, 6)

    local tagStroke = Instance.new("UIStroke", tagFrame)
    tagStroke.Thickness = 1.8
    tagStroke.Color = color

    local titleLbl = Instance.new("TextLabel", tagFrame)
    titleLbl.Size = UDim2.new(1, 0, 0.52, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = string.format("💰 %s %s", formatLuck(data.Luck), data.Name)
    titleLbl.TextColor3 = color
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12

    local distLbl = Instance.new("TextLabel", tagFrame)
    distLbl.Size = UDim2.new(1, 0, 0.45, 0)
    distLbl.Position = UDim2.new(0, 0, 0.52, 0)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = string.format("%s  |  %dm", data.Rarity, data.Distance)
    distLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.TextSize = 11

    local hl = nil
    if data.Model3D and data.Model3D.Parent then
        hl = Instance.new("Highlight")
        hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.35
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = data.Model3D
        hl.Parent = data.Model3D
    end

    activeTrackers[uuid] = {
        Model3D = data.Model3D,
        Highlight = hl,
        Container = trackerFolder,
        DistanceLabel = distLbl,
        Position = pos,
        Rarity = data.Rarity,
        HookTracer = hookPlayerTracer,
        Clean = function()
            if hl then hl:Destroy() end
            trackerFolder:Destroy()
        end
    }
end

--------------------------------------------------------------------------------
-- 7. CONSTRUCCIÓN DE LA INTERFAZ CON PESTAÑAS (TABS)
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggTrackerPro_GUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000

pcall(function()
    if type(gethui) == "function" then
        screenGui.Parent = gethui()
    else
        screenGui.Parent = PlayerGui
    end
end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end

local mainFrame = Instance.new("Frame")
local defaultSize = UDim2.new(0, 440, 0, 530)
mainFrame.Name = "MainFrame"
mainFrame.Size = defaultSize
mainFrame.Position = UDim2.new(0.03, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Thickness = 1.6
mainStroke.Color = Color3.fromRGB(55, 60, 75)

-- Arrastre de ventana
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

local dragConn = UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
table.insert(connections, dragConn)

-- Header
local header = Instance.new("Frame", mainFrame)
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
titleLabel.Position = UDim2.new(0.04, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🏴‍☠️ CHESTS & SPEED PRO (3D PREVIEW)"
titleLabel.TextColor3 = Color3.fromRGB(250, 250, 250)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Botón Minimizar (-)
local isMinimized = false
local minButton = Instance.new("TextButton", header)
minButton.Name = "MinButton"
minButton.Size = UDim2.new(0, 28, 0, 28)
minButton.Position = UDim2.new(0.82, 0, 0.16, 0)
minButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
minButton.Text = "-"
minButton.TextColor3 = Color3.fromRGB(240, 240, 240)
minButton.Font = Enum.Font.GothamBold
minButton.TextSize = 14
minButton.BorderSizePixel = 0
Instance.new("UICorner", minButton).CornerRadius = UDim.new(0, 6)

-- Botón Cerrar (X)
local closeButton = Instance.new("TextButton", header)
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 28, 0, 28)
closeButton.Position = UDim2.new(0.91, 0, 0.16, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.BorderSizePixel = 0
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

-- Barra de Navegación (Tabs)
local tabBar = Instance.new("Frame", mainFrame)
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(0.92, 0, 0, 32)
tabBar.Position = UDim2.new(0.04, 0, 0.095, 0)
tabBar.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
tabBar.BorderSizePixel = 0
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)

local function createTabButton(name, text, isActive)
    local btn = Instance.new("TextButton", tabBar)
    btn.Name = name
    btn.Size = UDim2.new(0.31, 0, 0.82, 0)
    btn.BackgroundColor3 = isActive and Color3.fromRGB(48, 120, 230) or Color3.fromRGB(28, 31, 39)
    btn.Text = text
    btn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 195)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local tabBtnEggs = createTabButton("TabEggs", "👑 Cofres", true)
local tabBtnPhysics = createTabButton("TabPhysics", "⚡ Físicas", false)
local tabBtnServer = createTabButton("TabServer", "🌐 Servidor", false)

-- Contenedores de Páginas
local contentArea = Instance.new("Frame", mainFrame)
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(0.92, 0, 0.74, 0)
contentArea.Position = UDim2.new(0.04, 0, 0.175, 0)
contentArea.BackgroundTransparency = 1

-- PÁGINA 1: COFRES
local pageEggs = Instance.new("Frame", contentArea)
pageEggs.Name = "PageEggs"
pageEggs.Size = UDim2.new(1, 0, 1, 0)
pageEggs.BackgroundTransparency = 1
pageEggs.Visible = true

local eggsTopBar = Instance.new("Frame", pageEggs)
eggsTopBar.Size = UDim2.new(1, 0, 0, 30)
eggsTopBar.BackgroundTransparency = 1

local sortButton = Instance.new("TextButton", eggsTopBar)
sortButton.Name = "SortButton"
sortButton.Size = UDim2.new(0.48, 0, 1, 0)
sortButton.BackgroundColor3 = Color3.fromRGB(35, 39, 50)
sortButton.Text = "Filtro: " .. (Config.SortMode == "Luck" and "Mayor Valor 💰" or "Distancia")
sortButton.TextColor3 = Color3.fromRGB(220, 220, 220)
sortButton.Font = Enum.Font.GothamMedium
sortButton.TextSize = 11
sortButton.BorderSizePixel = 0
Instance.new("UICorner", sortButton).CornerRadius = UDim.new(0, 6)

local clearTrackersBtn = Instance.new("TextButton", eggsTopBar)
clearTrackersBtn.Size = UDim2.new(0.48, 0, 1, 0)
clearTrackersBtn.Position = UDim2.new(0.52, 0, 0, 0)
clearTrackersBtn.BackgroundColor3 = Color3.fromRGB(50, 38, 42)
clearTrackersBtn.Text = "Limpiar Faros 3D"
clearTrackersBtn.TextColor3 = Color3.fromRGB(240, 180, 180)
clearTrackersBtn.Font = Enum.Font.GothamMedium
clearTrackersBtn.TextSize = 11
clearTrackersBtn.BorderSizePixel = 0
Instance.new("UICorner", clearTrackersBtn).CornerRadius = UDim.new(0, 6)

local scrollList = Instance.new("ScrollingFrame", pageEggs)
scrollList.Name = "EggList"
scrollList.Size = UDim2.new(1, 0, 0.9, 0)
scrollList.Position = UDim2.new(0, 0, 0.1, 0)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 4
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout", scrollList)
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- PÁGINA 2: FÍSICAS (SHIFT SPRINT 250 & JUMP 150)
local pagePhysics = Instance.new("ScrollingFrame", contentArea)
pagePhysics.Name = "PagePhysics"
pagePhysics.Size = UDim2.new(1, 0, 1, 0)
pagePhysics.BackgroundTransparency = 1
pagePhysics.ScrollBarThickness = 4
pagePhysics.CanvasSize = UDim2.new(0, 0, 0, 0)
pagePhysics.AutomaticCanvasSize = Enum.AutomaticSize.Y
pagePhysics.Visible = false

local physLayout = Instance.new("UIListLayout", pagePhysics)
physLayout.Padding = UDim.new(0, 10)
physLayout.SortOrder = Enum.SortOrder.LayoutOrder

local nativeSpeedCard = Instance.new("Frame", pagePhysics)
nativeSpeedCard.Size = UDim2.new(1, 0, 0, 50)
nativeSpeedCard.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
nativeSpeedCard.BorderSizePixel = 0
Instance.new("UICorner", nativeSpeedCard).CornerRadius = UDim.new(0, 8)
local nsStroke = Instance.new("UIStroke", nativeSpeedCard)
nsStroke.Color = Color3.fromRGB(60, 130, 240)
nsStroke.Thickness = 1.2

local lblNativeTitle = Instance.new("TextLabel", nativeSpeedCard)
lblNativeTitle.Size = UDim2.new(0.9, 0, 0.45, 0)
lblNativeTitle.Position = UDim2.new(0.05, 0, 0.08, 0)
lblNativeTitle.BackgroundTransparency = 1
lblNativeTitle.Text = "VELOCIDAD NATIVA DEL JUEGO / BARCO (PRESERVADA)"
lblNativeTitle.TextColor3 = Color3.fromRGB(140, 180, 255)
lblNativeTitle.Font = Enum.Font.GothamBold
lblNativeTitle.TextSize = 10
lblNativeTitle.TextXAlignment = Enum.TextXAlignment.Left

local lblNativeVal = Instance.new("TextLabel", nativeSpeedCard)
lblNativeVal.Size = UDim2.new(0.9, 0, 0.45, 0)
lblNativeVal.Position = UDim2.new(0.05, 0, 0.5, 0)
lblNativeVal.BackgroundTransparency = 1
lblNativeVal.Text = string.format("Base: %.1f | Sprint con Shift: %s", nativeWalkSpeed, Config.SprintEnabled and (tostring(Config.SprintSpeed) .. " (ACTIVO)") or "DESACTIVADO")
lblNativeVal.TextColor3 = Color3.fromRGB(240, 240, 240)
lblNativeVal.Font = Enum.Font.GothamMedium
lblNativeVal.TextSize = 11
lblNativeVal.TextXAlignment = Enum.TextXAlignment.Left

local function createControlCard(parent, title, desc, defaultValue, onToggle, onValChange)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, 0, 0, 68)
    card.BackgroundColor3 = Color3.fromRGB(26, 29, 37)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local lblT = Instance.new("TextLabel", card)
    lblT.Size = UDim2.new(0.55, 0, 0.45, 0)
    lblT.Position = UDim2.new(0.04, 0, 0.1, 0)
    lblT.BackgroundTransparency = 1
    lblT.Text = title
    lblT.TextColor3 = Color3.fromRGB(240, 240, 240)
    lblT.Font = Enum.Font.GothamBold
    lblT.TextSize = 12
    lblT.TextXAlignment = Enum.TextXAlignment.Left

    local lblD = Instance.new("TextLabel", card)
    lblD.Size = UDim2.new(0.55, 0, 0.4, 0)
    lblD.Position = UDim2.new(0.04, 0, 0.52, 0)
    lblD.BackgroundTransparency = 1
    lblD.Text = desc
    lblD.TextColor3 = Color3.fromRGB(150, 155, 170)
    lblD.Font = Enum.Font.Gotham
    lblD.TextSize = 10
    lblD.TextXAlignment = Enum.TextXAlignment.Left

    local inputVal = Instance.new("TextBox", card)
    inputVal.Size = UDim2.new(0.18, 0, 0.5, 0)
    inputVal.Position = UDim2.new(0.58, 0, 0.25, 0)
    inputVal.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
    inputVal.Text = tostring(defaultValue)
    inputVal.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputVal.Font = Enum.Font.GothamBold
    inputVal.TextSize = 12
    inputVal.BorderSizePixel = 0
    Instance.new("UICorner", inputVal).CornerRadius = UDim.new(0, 6)

    inputVal.FocusLost:Connect(function()
        local num = tonumber(inputVal.Text)
        if num and num > 0 then
            onValChange(num)
        else
            inputVal.Text = tostring(defaultValue)
        end
        saveConfig()
    end)

    local toggleBtn = Instance.new("TextButton", card)
    toggleBtn.Size = UDim2.new(0.18, 0, 0.5, 0)
    toggleBtn.Position = UDim2.new(0.78, 0, 0.25, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    toggleBtn.Text = "ON"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 11
    toggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

    local isEnabled = true
    toggleBtn.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        toggleBtn.Text = isEnabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(70, 75, 85)
        onToggle(isEnabled)
        saveConfig()
    end)

    return { Card = card, Input = inputVal, Toggle = toggleBtn, SetState = function(state)
        isEnabled = state
        toggleBtn.Text = isEnabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(70, 75, 85)
    end }
end

local sprintCtrl = createControlCard(pagePhysics, "⚡ Shift Sprint (Correr)", "Mantén presionado Shift para acelerar", Config.SprintSpeed, function(active)
    Config.SprintEnabled = active
    if not active then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = nativeWalkSpeed end
    end
    if updateStatusTelemetry then updateStatusTelemetry() end
end, function(val)
    Config.SprintSpeed = val
    if isShiftCurrentlyPressed() and Config.SprintEnabled then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = val end
    end
    if updateStatusTelemetry then updateStatusTelemetry() end
end)
sprintCtrl.SetState(Config.SprintEnabled)

local jumpCtrl = createControlCard(pagePhysics, "🦘 Poder de Salto (Jump)", "Fuerza de impulso vertical", Config.JumpPower, function(active)
    Config.JumpEnabled = active
    local hum = getHumanoid()
    if hum then
        if active then
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        else
            hum.JumpPower = 50
        end
    end
    if updateStatusTelemetry then updateStatusTelemetry() end
end, function(val)
    Config.JumpPower = val
    local hum = getHumanoid()
    if hum and Config.JumpEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = val
    end
    if updateStatusTelemetry then updateStatusTelemetry() end
end)
jumpCtrl.SetState(Config.JumpEnabled)

local function createSimpleToggle(parent, title, desc, initVal, onToggle)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, 0, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(26, 29, 37)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local lblT = Instance.new("TextLabel", card)
    lblT.Size = UDim2.new(0.7, 0, 0.45, 0)
    lblT.Position = UDim2.new(0.04, 0, 0.1, 0)
    lblT.BackgroundTransparency = 1
    lblT.Text = title
    lblT.TextColor3 = Color3.fromRGB(240, 240, 240)
    lblT.Font = Enum.Font.GothamBold
    lblT.TextSize = 12
    lblT.TextXAlignment = Enum.TextXAlignment.Left

    local lblD = Instance.new("TextLabel", card)
    lblD.Size = UDim2.new(0.7, 0, 0.4, 0)
    lblD.Position = UDim2.new(0.04, 0, 0.52, 0)
    lblD.BackgroundTransparency = 1
    lblD.Text = desc
    lblD.TextColor3 = Color3.fromRGB(150, 155, 170)
    lblD.Font = Enum.Font.Gotham
    lblD.TextSize = 10
    lblD.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", card)
    toggleBtn.Size = UDim2.new(0.2, 0, 0.6, 0)
    toggleBtn.Position = UDim2.new(0.76, 0, 0.2, 0)
    toggleBtn.BackgroundColor3 = initVal and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(70, 75, 85)
    toggleBtn.Text = initVal and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 11
    toggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

    local curState = initVal
    toggleBtn.MouseButton1Click:Connect(function()
        curState = not curState
        toggleBtn.Text = curState and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = curState and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(70, 75, 85)
        onToggle(curState)
        saveConfig()
    end)
end

createSimpleToggle(pagePhysics, "🌌 Salto Infinito (Infinite Jump)", "Salta repetidamente en el aire", Config.InfJump, function(state)
    Config.InfJump = state
end)

createSimpleToggle(pagePhysics, "👻 Atravesar Paredes (Noclip)", "Camina libre a través de obstáculos", Config.Noclip, function(state)
    Config.Noclip = state
end)

-- PÁGINA 3: SERVIDOR (SERVER HOPPER & PERSISTENCIA)
local pageServer = Instance.new("ScrollingFrame", contentArea)
pageServer.Name = "PageServer"
pageServer.Size = UDim2.new(1, 0, 1, 0)
pageServer.BackgroundTransparency = 1
pageServer.ScrollBarThickness = 4
pageServer.CanvasSize = UDim2.new(0, 0, 0, 0)
pageServer.AutomaticCanvasSize = Enum.AutomaticSize.Y
pageServer.Visible = false

local srvLayout = Instance.new("UIListLayout", pageServer)
srvLayout.Padding = UDim.new(0, 10)
srvLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createActionCard(parent, title, desc, btnText, btnColor, onClick)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = Color3.fromRGB(26, 29, 37)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local lblT = Instance.new("TextLabel", card)
    lblT.Size = UDim2.new(0.55, 0, 0.45, 0)
    lblT.Position = UDim2.new(0.04, 0, 0.1, 0)
    lblT.BackgroundTransparency = 1
    lblT.Text = title
    lblT.TextColor3 = Color3.fromRGB(240, 240, 240)
    lblT.Font = Enum.Font.GothamBold
    lblT.TextSize = 12
    lblT.TextXAlignment = Enum.TextXAlignment.Left

    local lblD = Instance.new("TextLabel", card)
    lblD.Size = UDim2.new(0.55, 0, 0.4, 0)
    lblD.Position = UDim2.new(0.04, 0, 0.52, 0)
    lblD.BackgroundTransparency = 1
    lblD.Text = desc
    lblD.TextColor3 = Color3.fromRGB(150, 155, 170)
    lblD.Font = Enum.Font.Gotham
    lblD.TextSize = 10
    lblD.TextXAlignment = Enum.TextXAlignment.Left

    local actionBtn = Instance.new("TextButton", card)
    actionBtn.Size = UDim2.new(0.36, 0, 0.6, 0)
    actionBtn.Position = UDim2.new(0.6, 0, 0.2, 0)
    actionBtn.BackgroundColor3 = btnColor
    actionBtn.Text = btnText
    actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 11
    actionBtn.BorderSizePixel = 0
    Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

    actionBtn.MouseButton1Click:Connect(onClick)
    return actionBtn
end

createActionCard(pageServer, "🚀 Hop a Servidor Vacío", "Busca servidor con menos jugadores", "Hop (Menos Gente)", Color3.fromRGB(45, 120, 230), function()
    executeServerHop(true)
end)

createActionCard(pageServer, "🎲 Hop a Servidor Aleatorio", "Salta a otro servidor disponible", "Hop Aleatorio", Color3.fromRGB(60, 75, 180), function()
    executeServerHop(false)
end)

createActionCard(pageServer, "🔄 Reingresar al Servidor", "Reconectar a la misma sala", "Rejoin", Color3.fromRGB(160, 90, 40), function()
    executeRejoin()
end)

createSimpleToggle(pageServer, "🔁 Auto Re-ejecutar Código", "Ejecuta el script tras cambiar de servidor", Config.AutoReexecute, function(state)
    Config.AutoReexecute = state
    saveConfig()
end)

createSimpleToggle(pageServer, "💾 Guardar Configuración", "Guarda configuraciones en archivo .json", true, function()
    saveConfig()
end)

-- Barra Inferior de Telemetría
local bottomBar = Instance.new("Frame", mainFrame)
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(0.92, 0, 0, 26)
bottomBar.Position = UDim2.new(0.04, 0, 0.93, 0)
bottomBar.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
bottomBar.BorderSizePixel = 0
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 5)

local telemetryLbl = Instance.new("TextLabel", bottomBar)
telemetryLbl.Size = UDim2.new(1, -12, 1, 0)
telemetryLbl.Position = UDim2.new(0, 6, 0, 0)
telemetryLbl.BackgroundTransparency = 1
telemetryLbl.Text = string.format("⚡ Vel Nativa: %.0f | Sprint: %d | Salto: %d", nativeWalkSpeed, Config.SprintSpeed, Config.JumpPower)
telemetryLbl.TextColor3 = Color3.fromRGB(160, 175, 200)
telemetryLbl.Font = Enum.Font.GothamMedium
telemetryLbl.TextSize = 10
telemetryLbl.TextXAlignment = Enum.TextXAlignment.Center

updateStatusTelemetry = function()
    pcall(function()
        lblNativeVal.Text = string.format("Base: %.1f | Sprint con Shift: %s", nativeWalkSpeed, Config.SprintEnabled and (tostring(Config.SprintSpeed) .. " (ACTIVO)") or "DESACTIVADO")
        telemetryLbl.Text = string.format("⚡ Vel Nativa: %.0f | Sprint: %s | Salto: %s", nativeWalkSpeed, Config.SprintEnabled and tostring(Config.SprintSpeed) or "OFF", Config.JumpEnabled and tostring(Config.JumpPower) or "OFF")
    end)
end

local function switchTab(selected)
    pageEggs.Visible = (selected == "Eggs")
    pagePhysics.Visible = (selected == "Physics")
    pageServer.Visible = (selected == "Server")

    tabBtnEggs.BackgroundColor3 = (selected == "Eggs") and Color3.fromRGB(48, 120, 230) or Color3.fromRGB(28, 31, 39)
    tabBtnEggs.TextColor3 = (selected == "Eggs") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 195)

    tabBtnPhysics.BackgroundColor3 = (selected == "Physics") and Color3.fromRGB(48, 120, 230) or Color3.fromRGB(28, 31, 39)
    tabBtnPhysics.TextColor3 = (selected == "Physics") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 195)

    tabBtnServer.BackgroundColor3 = (selected == "Server") and Color3.fromRGB(48, 120, 230) or Color3.fromRGB(28, 31, 39)
    tabBtnServer.TextColor3 = (selected == "Server") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 195)
end

tabBtnEggs.MouseButton1Click:Connect(function() switchTab("Eggs") end)
tabBtnPhysics.MouseButton1Click:Connect(function() switchTab("Physics") end)
tabBtnServer.MouseButton1Click:Connect(function() switchTab("Server") end)

-- Menú Contextual para Cofres
local contextMenu = Instance.new("Frame", screenGui)
contextMenu.Name = "ContextMenu"
contextMenu.Size = UDim2.new(0, 180, 0, 110)
contextMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
contextMenu.ZIndex = 100
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 6)
local ctxStroke = Instance.new("UIStroke", contextMenu)
ctxStroke.Thickness = 1.2
ctxStroke.Color = Color3.fromRGB(80, 85, 100)

local ctxLayout = Instance.new("UIListLayout", contextMenu)
ctxLayout.Padding = UDim.new(0, 4)
local ctxPadding = Instance.new("UIPadding", contextMenu)
ctxPadding.PaddingTop = UDim.new(0, 6)
ctxPadding.PaddingBottom = UDim.new(0, 6)
ctxPadding.PaddingLeft = UDim.new(0, 6)
ctxPadding.PaddingRight = UDim.new(0, 6)

local function createCtxOption(name, text)
    local btn = Instance.new("TextButton", contextMenu)
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.ZIndex = 101
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local btnTrack = createCtxOption("TrackOption", "Marcar Faro 3D")
local btnTeleport = createCtxOption("TpOption", "Teletransportarse")
local btnWaypoint = createCtxOption("WaypointOption", "Trazar Rumbo (Mapa)")

--------------------------------------------------------------------------------
-- 8. ESCANEO, MODELADO 3D DE COFRES Y VISTA PREVIA (VIEWPORTFRAME)
--------------------------------------------------------------------------------
local function resolveInstancePosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and typeof(cf) == "CFrame" then return cf.Position end
        local root = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if root then return root.Position end
    end
    return nil
end

-- Búsqueda de modelos 3D de cofres en Workspace.World.Dynamic o ReplicatedStorage
local function get3DModelForChest(chestName, targetPos)
    local world = Workspace:FindFirstChild("World")
    local dynamic = world and world:FindFirstChild("Dynamic")

    if dynamic then
        local closest, minDist = nil, 30
        for _, obj in ipairs(dynamic:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == chestName or obj.Name:lower():find("chest")) then
                local pos = resolveInstancePosition(obj)
                if pos and targetPos then
                    local dist = (pos - targetPos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = obj
                    end
                elseif not closest then
                    closest = obj
                end
            end
        end
        if closest then return closest end
    end

    local storageFolders = {
        Shared and Shared:FindFirstChild("Assets") and Shared.Assets:FindFirstChild("Chests"),
        Shared and Shared:FindFirstChild("Assets"),
        ReplicatedStorage:FindFirstChild("Assets"),
        ReplicatedStorage:FindFirstChild("Chests")
    }
    for _, folder in ipairs(storageFolders) do
        if folder then
            local found = folder:FindFirstChild(chestName) or folder:FindFirstChild("Chest")
            if found and found:IsA("Model") then
                return found
            end
        end
    end

    return nil
end

-- Generador de cofre 3D procedimental o clonado en el ViewportFrame
local function setupChestViewport(viewportFrame, chestData)
    viewportFrame:ClearAllChildren()

    local camera = Instance.new("Camera")
    camera.FieldOfView = 32
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera

    local previewModel = nil
    if chestData.Model3D then
        pcall(function()
            chestData.Model3D.Archivable = true
            previewModel = chestData.Model3D:Clone()
            for _, d in ipairs(previewModel:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Highlight") then
                    d:Destroy()
                end
            end
        end)
    end

    -- Si no hay modelo 3D clonable (ej. Cofre de Mapa enterrado), construye un Cofre 3D detallado
    if not previewModel or #previewModel:GetDescendants() == 0 then
        if previewModel then previewModel:Destroy() end
        previewModel = Instance.new("Model")

        local base = Instance.new("Part")
        base.Name = "ChestBase"
        base.Size = Vector3.new(3.2, 1.8, 2.2)
        base.Color = Color3.fromRGB(95, 58, 28)
        base.Material = Enum.Material.WoodPlanks
        base.Anchored = true
        base.CanCollide = false
        base.CFrame = CFrame.new(0, -0.4, 0)
        base.Parent = previewModel

        local lid = Instance.new("Part")
        lid.Name = "ChestLid"
        lid.Shape = Enum.PartType.Cylinder
        lid.Size = Vector3.new(3.2, 2.2, 2.2)
        lid.Color = Color3.fromRGB(110, 68, 34)
        lid.Material = Enum.Material.Wood
        lid.Anchored = true
        lid.CanCollide = false
        lid.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
        lid.Parent = previewModel

        local trimColor = chestData.Color or Color3.fromRGB(255, 195, 40)
        local bandLeft = Instance.new("Part")
        bandLeft.Size = Vector3.new(0.35, 2.5, 2.35)
        bandLeft.Color = trimColor
        bandLeft.Material = Enum.Material.Metal
        bandLeft.Anchored = true
        bandLeft.CanCollide = false
        bandLeft.CFrame = CFrame.new(-1.1, 0, 0)
        bandLeft.Parent = previewModel

        local bandRight = bandLeft:Clone()
        bandRight.CFrame = CFrame.new(1.1, 0, 0)
        bandRight.Parent = previewModel

        local lock = Instance.new("Part")
        lock.Size = Vector3.new(0.6, 0.8, 0.3)
        lock.Color = Color3.fromRGB(255, 215, 0)
        lock.Material = Enum.Material.Neon
        lock.Anchored = true
        lock.CanCollide = false
        lock.CFrame = CFrame.new(0, 0.2, 1.15)
        lock.Parent = previewModel

        previewModel.PrimaryPart = base
    end

    previewModel.Parent = viewportFrame

    local cf, size = previewModel:GetBoundingBox()
    local maxDim = math.max(size.X, size.Y, size.Z)
    if maxDim <= 0 then maxDim = 3.5 end
    local dist = maxDim * 1.95

    local camPos = cf.Position + Vector3.new(dist * 0.8, dist * 0.5, dist * 0.85)
    camera.CFrame = CFrame.new(camPos, cf.Position)

    viewportFrame.LightColor = Color3.fromRGB(255, 245, 220)
    viewportFrame.Ambient = Color3.fromRGB(140, 140, 150)
    viewportFrame.LightDirection = Vector3.new(-1, -1.5, -1).Unit

    local spinThread = task.spawn(function()
        local angle = 0
        while isScriptActive and viewportFrame and viewportFrame.Parent do
            angle = (angle + 1.5) % 360
            if previewModel then
                pcall(function()
                    previewModel:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(angle), 0))
                end)
            end
            task.wait(0.04)
        end
    end)
    table.insert(runningThreads, spinThread)
end

-- Escáner adaptado a Workspace.World.Dynamic y Mapas del Tesoro
local function scanChests()
    local list = {}
    local seenUUIDs = {}
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
    local serverNow = Workspace:GetServerTimeNow()

    -- 1. Escanear Workspace.World.Dynamic (Cofres, Cajas, Eventos con botín)
    local world = Workspace:FindFirstChild("World")
    local dynamic = world and world:FindFirstChild("Dynamic")

    if dynamic then
        for _, child in ipairs(dynamic:GetDescendants()) do
            if child:IsA("Model") or (child:IsA("BasePart") and not child.Parent:IsA("Model")) then
                local nameLower = child.Name:lower()
                local isChest = nameLower:find("chest")
                    or nameLower:find("cofre")
                    or nameLower:find("treasure")
                    or nameLower:find("crate")
                    or nameLower:find("loot")
                    or child:GetAttribute("ChestTier") ~= nil
                    or child:GetAttribute("Bounty") ~= nil
                    or child:GetAttribute("Gold") ~= nil

                -- Excluir barcos de jugadores y NPCs
                if isChest and not nameLower:find("ship_") and not child:FindFirstChildOfClass("Humanoid") then
                    local pos = resolveInstancePosition(child)
                    local endsAt = tonumber(child:GetAttribute("EndsAt"))

                    if pos and (not endsAt or serverNow < endsAt) then
                        local uuid = tostring(child:GetAttribute("Uid") or child:GetAttribute("Id") or (child:GetDebugId() .. "_" .. math.floor(pos.X)))
                        if not seenUUIDs[uuid] then
                            seenUUIDs[uuid] = true

                            local rawName = child:GetAttribute("DisplayName") or child:GetAttribute("Type") or child.Name
                            local rarity = child:GetAttribute("Rarity")
                                or child:GetAttribute("Tier")
                                or CHEST_RARITY_TABLE[rawName]
                                or (nameLower:find("mythic") and "Mythic")
                                or (nameLower:find("legend") and "Legendary")
                                or (nameLower:find("epic") or nameLower:find("gold") and "Epic")
                                or (nameLower:find("rare") or nameLower:find("silver") and "Rare")
                                or "Common"

                            local value = tonumber(child:GetAttribute("Value") or child:GetAttribute("Gold") or child:GetAttribute("Reward"))
                                or CHEST_VALUE_TABLE[rawName]
                                or (rarity == "Mythic" and 10000000)
                                or (rarity == "Legendary" and 2500000)
                                or (rarity == "Epic" and 150000)
                                or (rarity == "Rare" and 25000)
                                or 2500

                            local timeLeft = endsAt and math.max(0, math.floor(endsAt - serverNow)) or nil
                            local tagExtra = timeLeft and (tostring(timeLeft) .. "s") or child:GetAttribute("Stage")
                            local color = RARITY_COLORS[rarity] or RARITY_COLORS.Unknown
                            local dist = math.floor((myPos - pos).Magnitude)

                            table.insert(list, {
                                UUID = uuid,
                                Name = tostring(rawName),
                                Position = pos,
                                Weight = value,
                                Mutation = tagExtra,
                                Luck = value,
                                Rarity = rarity,
                                Color = color,
                                Distance = dist,
                                Model3D = child:IsA("Model") and child or nil
                            })
                        end
                    end
                end
            end
        end
    end

    -- 2. Escanear Mapas del Tesoro Activos en DataController / MapController
    pcall(function()
        if Registry then
            local dataCtrl = Registry.TryGet("DataController")
            local mapCtrl = Registry.TryGet("MapController")

            local activeUid = nil
            if mapCtrl and type(mapCtrl.GetActive) == "function" then
                local ok, res = pcall(mapCtrl.GetActive, mapCtrl)
                if ok and type(res) == "string" then activeUid = res end
            end
            if (not activeUid or activeUid == "") and dataCtrl then
                activeUid = dataCtrl:Get("TreasureHunt.ActiveMap")
            end

            local mapsList = nil
            if mapCtrl and type(mapCtrl.GetMaps) == "function" then
                local ok, res = pcall(mapCtrl.GetMaps, mapCtrl)
                if ok and type(res) == "table" then mapsList = res end
            end
            if not mapsList and dataCtrl then
                mapsList = dataCtrl:Get("Maps")
            end

            if type(mapsList) == "table" then
                for _, mapEntry in ipairs(mapsList) do
                    if type(mapEntry) == "table" and mapEntry.IslandId then
                        local isCurrentActive = (mapEntry.Uid == activeUid)
                        local islandPos = nil
                        local islandName = tostring(mapEntry.IslandId)

                        if IslandsConfig and type(IslandsConfig.Get) == "function" then
                            local ok, isl = pcall(IslandsConfig.Get, mapEntry.IslandId)
                            if ok and type(isl) == "table" and typeof(isl.Position) == "Vector3" then
                                islandPos = isl.Position
                                islandName = isl.Name or islandName
                            end
                        end

                        if islandPos then
                            local uuid = "TreasureMap_" .. tostring(mapEntry.Uid or mapEntry.IslandId)
                            seenUUIDs[uuid] = true
                            local rarity = mapEntry.Rarity or (isCurrentActive and "Legendary" or "Epic")
                            local val = tonumber(mapEntry.Reward or mapEntry.Gold) or (isCurrentActive and 2500000 or 500000)
                            local dist = math.floor((myPos - islandPos).Magnitude)

                            table.insert(list, {
                                UUID = uuid,
                                Name = "Mapa: " .. islandName,
                                Position = islandPos,
                                Weight = val,
                                Mutation = isCurrentActive and "ACTIVO" or "En Inventario",
                                Luck = val,
                                Rarity = rarity,
                                Color = RARITY_COLORS[rarity] or RARITY_COLORS.Legendary,
                                Distance = dist,
                                Model3D = get3DModelForChest("Golden Chest", islandPos)
                            })
                        end
                    end
                end
            end

            -- 3. Escanear Eventos Globales con Botín (EventController)
            local evCtrl = Registry.TryGet("EventController")
            if evCtrl and type(evCtrl.GetActiveEvents) == "function" then
                local ok, activeEvs = pcall(evCtrl.GetActiveEvents, evCtrl)
                if ok and type(activeEvs) == "table" then
                    for _, ev in ipairs(activeEvs) do
                        local evPos = ev.Position or ev.Center
                        if typeof(evPos) == "Vector3" then
                            local uuid = "Event_" .. tostring(ev.Uid or ev.Id)
                            seenUUIDs[uuid] = true
                            local endsAt = tonumber(ev.EndsAt)
                            local rem = endsAt and math.max(0, math.floor(endsAt - serverNow)) or nil
                            local dist = math.floor((myPos - evPos).Magnitude)

                            table.insert(list, {
                                UUID = uuid,
                                Name = tostring(ev.Name or ev.Id or "Evento Mundial"),
                                Position = evPos,
                                Weight = 5000000,
                                Mutation = rem and (rem .. "s") or ev.Stage,
                                Luck = 5000000,
                                Rarity = "Mythic",
                                Color = RARITY_COLORS.Mythic,
                                Distance = dist,
                                Model3D = nil
                            })
                        end
                    end
                end
            end
        end
    end)

    for trackedUUID, _ in pairs(activeTrackers) do
        if not seenUUIDs[trackedUUID] then
            removeTracker(trackedUUID)
        end
    end

    if Config.SortMode == "Luck" then
        table.sort(list, function(a, b) return a.Luck > b.Luck end)
    else
        table.sort(list, function(a, b) return a.Distance < b.Distance end)
    end

    return list
end

local function refreshGUI()
    if not isScriptActive then return end
    pcall(function()
        local chests = scanChests()
        local existingCards = {}

        for _, item in ipairs(scrollList:GetChildren()) do
            if item:IsA("Frame") or item:IsA("TextLabel") then
                item:Destroy()
            end
        end

        if #chests == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(1, 0, 0, 50)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Text = "Buscando cofres y tesoros en el mapa..."
            emptyLabel.TextColor3 = Color3.fromRGB(160, 165, 175)
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 12
            emptyLabel.Parent = scrollList
            cachedEggCards = {}
            return
        end

        for idx, data in ipairs(chests) do
            local card = Instance.new("Frame")
            card.Name = "Chest_" .. data.UUID
            card.Size = UDim2.new(1, -6, 0, 60)
            card.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
            card.BorderSizePixel = 0
            card.LayoutOrder = idx
            card.Parent = scrollList

            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

            local cardStroke = Instance.new("UIStroke", card)
            cardStroke.Thickness = 1
            cardStroke.Color = Color3.fromRGB(45, 50, 65)

            local rarityBar = Instance.new("Frame", card)
            rarityBar.Size = UDim2.new(0, 4, 1, -12)
            rarityBar.Position = UDim2.new(0, 6, 0, 6)
            rarityBar.BackgroundColor3 = data.Color
            rarityBar.BorderSizePixel = 0
            Instance.new("UICorner", rarityBar).CornerRadius = UDim.new(0, 4)

            local vpContainer = Instance.new("Frame", card)
            vpContainer.Name = "ViewportContainer"
            vpContainer.Size = UDim2.new(0, 46, 0, 46)
            vpContainer.Position = UDim2.new(0, 16, 0.5, -23)
            vpContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
            vpContainer.BorderSizePixel = 0
            Instance.new("UICorner", vpContainer).CornerRadius = UDim.new(0, 6)

            local vpStroke = Instance.new("UIStroke", vpContainer)
            vpStroke.Thickness = 1
            vpStroke.Color = data.Color

            local vp = Instance.new("ViewportFrame", vpContainer)
            vp.Size = UDim2.new(1, 0, 1, 0)
            vp.BackgroundTransparency = 1
            vp.BorderSizePixel = 0

            setupChestViewport(vp, data)

            local nameLabel = Instance.new("TextLabel", card)
            nameLabel.Size = UDim2.new(0.46, 0, 0.44, 0)
            nameLabel.Position = UDim2.new(0, 70, 0, 6)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = data.Name .. (data.Mutation and (" [" .. tostring(data.Mutation) .. "]") or "")
            nameLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left

            local infoLabel = Instance.new("TextLabel", card)
            infoLabel.Size = UDim2.new(0.46, 0, 0.4, 0)
            infoLabel.Position = UDim2.new(0, 70, 0, 32)
            infoLabel.BackgroundTransparency = 1
            infoLabel.Text = string.format("💰 $%s  |  %s  |  %dm", formatLuck(data.Luck), data.Rarity, data.Distance)
            infoLabel.TextColor3 = data.Color
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.TextSize = 11
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left

            local quickTrackBtn = Instance.new("TextButton", card)
            quickTrackBtn.Name = "QuickTrack"
            quickTrackBtn.Size = UDim2.new(0.28, 0, 0.55, 0)
            quickTrackBtn.Position = UDim2.new(0.69, 0, 0.22, 0)
            quickTrackBtn.BackgroundColor3 = activeTrackers[data.UUID] and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(45, 50, 64)
            quickTrackBtn.Text = activeTrackers[data.UUID] and "★ MARCADO" or "MARCAR"
            quickTrackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            quickTrackBtn.Font = Enum.Font.GothamBold
            quickTrackBtn.TextSize = 10
            quickTrackBtn.BorderSizePixel = 0
            quickTrackBtn.ZIndex = 5
            Instance.new("UICorner", quickTrackBtn).CornerRadius = UDim.new(0, 6)

            quickTrackBtn.MouseButton1Click:Connect(function()
                if activeTrackers[data.UUID] then
                    removeTracker(data.UUID)
                else
                    createHighVisibilityTracker(data)
                end
                refreshGUI()
            end)

            local clickCatcher = Instance.new("TextButton", card)
            clickCatcher.Size = UDim2.new(0.68, 0, 1, 0)
            clickCatcher.BackgroundTransparency = 1
            clickCatcher.Text = ""

            clickCatcher.MouseButton2Click:Connect(function()
                selectedEggData = data
                btnTrack.Text = activeTrackers[data.UUID] and "Desmarcar Faro" or "Marcar Faro 3D"
                local mousePos = UserInputService:GetMouseLocation()
                contextMenu.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y - 36)
                contextMenu.Visible = true
            end)

            existingCards[data.UUID] = {
                Card = card,
                Data = data,
                InfoLabel = infoLabel,
                TrackBtn = quickTrackBtn
            }
        end

        cachedEggCards = existingCards
    end)
end

-- Actualizador dinámico de distancias en tiempo real
local hbConn = RunService.Heartbeat:Connect(function()
    if not isScriptActive then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position

    for uuid, tracker in pairs(activeTrackers) do
        if tracker.DistanceLabel and tracker.Position then
            local dist = math.floor((myPos - tracker.Position).Magnitude)
            tracker.DistanceLabel.Text = string.format("%s  |  %dm", tracker.Rarity or "Chest", dist)
        end
    end

    for uuid, item in pairs(cachedEggCards) do
        if item.InfoLabel and item.Data then
            local dist = math.floor((myPos - item.Data.Position).Magnitude)
            item.InfoLabel.Text = string.format("💰 $%s  |  %s  |  %dm", formatLuck(item.Data.Luck), item.Data.Rarity, dist)
            if item.TrackBtn then
                item.TrackBtn.Text = activeTrackers[uuid] and "★ MARCADO" or "MARCAR"
                item.TrackBtn.BackgroundColor3 = activeTrackers[uuid] and Color3.fromRGB(0, 160, 110) or Color3.fromRGB(45, 50, 64)
            end
        end
    end
end)
table.insert(connections, hbConn)

--------------------------------------------------------------------------------
-- 9. EVENTOS REACTIVOS Y CONTROLADORES EN WORKSPACE.WORLD.DYNAMIC
--------------------------------------------------------------------------------
local refreshScheduled = false
local function scheduleRefresh()
    if not isScriptActive or refreshScheduled then return end
    refreshScheduled = true
    task.delay(0.25, function()
        refreshScheduled = false
        refreshGUI()
    end)
end

local charConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    for _, tr in pairs(activeTrackers) do
        if tr.HookTracer then tr.HookTracer() end
    end
end)
table.insert(connections, charConn)

task.spawn(function()
    local world = Workspace:WaitForChild("World", 10)
    local dynamic = world and world:WaitForChild("Dynamic", 10)
    if dynamic then
        local c1 = dynamic.DescendantAdded:Connect(scheduleRefresh)
        local c2 = dynamic.DescendantRemoving:Connect(scheduleRefresh)
        table.insert(connections, c1)
        table.insert(connections, c2)
    end
end)

-- Minimizar / Expandir (-)
minButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Size = UDim2.new(0, 440, 0, 42)
        tabBar.Visible = false
        contentArea.Visible = false
        bottomBar.Visible = false
        minButton.Text = "+"
    else
        mainFrame.Size = defaultSize
        tabBar.Visible = true
        contentArea.Visible = true
        bottomBar.Visible = true
        minButton.Text = "-"
    end
end)

clearTrackersBtn.MouseButton1Click:Connect(function()
    clearAllTrackers()
    refreshGUI()
end)

-- Cerrar y Destruir Código
local function destroyScript()
    isScriptActive = false
    saveConfig()

    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    for _, conn in ipairs(charConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(charConnections)

    clearAllTrackers()

    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = nativeWalkSpeed
        hum.JumpPower = 50
    end

    for _, th in ipairs(runningThreads) do
        pcall(function() task.cancel(th) end)
    end
    table.clear(runningThreads)

    if screenGui then screenGui:Destroy() end
    _G.MontaMascotaInstance = nil
    print("[SECURE-TRACKER] Código y rastreadores finalizados exitosamente.")
end
closeButton.MouseButton1Click:Connect(destroyScript)

_G.MontaMascotaInstance = {
    Destroy = destroyScript
}

-- Menú Contextual Clicks
local inputConn = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UserInputService:GetMouseLocation()
        local pos = contextMenu.AbsolutePosition
        local size = contextMenu.AbsoluteSize
        
        if mousePos.X < pos.X or mousePos.X > pos.X + size.X or
           mousePos.Y < pos.Y or mousePos.Y > pos.Y + size.Y then
            contextMenu.Visible = false
        end
    end
end)
table.insert(connections, inputConn)

btnTrack.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedEggData then
        if activeTrackers[selectedEggData.UUID] then
            removeTracker(selectedEggData.UUID)
        else
            createHighVisibilityTracker(selectedEggData)
        end
        refreshGUI()
    end
end)

btnTeleport.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedEggData and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and selectedEggData.Position then
            hrp.CFrame = CFrame.new(selectedEggData.Position + Vector3.new(0, 5, 0))
        end
    end
end)

-- Integración nativa con el WaypointController del juego actual
btnWaypoint.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedEggData and Registry then
        pcall(function()
            local wpCtrl = Registry.TryGet("WaypointController")
            if wpCtrl and type(wpCtrl.Set) == "function" then
                wpCtrl:Set("MapPin", {
                    Icon = "Pin",
                    Kind = "Custom",
                    ShowBeam = true,
                    HideWithin = 25,
                    Priority = 5,
                    Position = selectedEggData.Position + Vector3.new(0, 6, 0),
                    Label = selectedEggData.Name,
                    Color = selectedEggData.Color
                })
            end
        end)
    end
end)

sortButton.MouseButton1Click:Connect(function()
    Config.SortMode = (Config.SortMode == "Luck") and "Distance" or "Luck"
    sortButton.Text = "Filtro: " .. (Config.SortMode == "Luck" and "Mayor Valor 💰" or "Distancia")
    saveConfig()
    refreshGUI()
end)

SpawnSafe("BackupHeartbeatLoop", function()
    while isScriptActive and screenGui and screenGui.Parent do
        refreshGUI()
        task.wait(2.5)
    end
end)

refreshGUI()
print("[SECURE-TRACKER] Sistema Pro con Aspecto 3D de Cofres, Shift Sprint (250), JumpPower (150) y Server Hop inicializado correctamente.")