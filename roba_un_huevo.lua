-- ==============================================================================
-- 🥚 APEX SUITE - ROBA UN HUEVO & CHEST TRACKER PRO (EDICIÓN DEFINITIVA)
-- ==============================================================================
-- Diseñado e impulsado por el análisis estático y dinámico del juego actual.
-- Características Principales:
-- 1. Anti-Cheat Stealth Engine: Cero hooks a Kick, anti-AFK pasivo, GUI camuflada.
-- 2. Anti-Rubberband Teleport: Micro-pasos seguros que evitan el watchdog de ObbyAntiTP.
-- 3. Escáner Multi-Zona Adaptativo:
--    - Workspace.Chest y Workspace.World.MonsterParasiteMarkers (Cofres)
--    - Workspace.Eggs, PlacedEggRenders, AreaEggSlotsClient y CrystalEggHolders (Huevos)
--    - Workspace.World.Areas (Nidos, GuardAreas, SecretZones)
-- 4. 3D ViewportFrame en Vivo: Previsualización 3D rotatoria en tiempo real.
-- 5. Faros Verticales (Sky Beacons) y Líneas Guía (Tracers) con código de colores por rareza.
-- 6. Server Hopper Inteligente: Búsqueda de servidores con pocos jugadores y auto re-ejecución.
-- ==============================================================================

-- ==============================================================================
-- 0. SINGLETON PATTERN SEGURO (SIN VARIABLES GLOBALES EN _G)
-- ==============================================================================
local GUI_TAG = "ApexEggTracker_" .. tostring(game.PlaceId)
pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local gethuiFunc = (type(gethui) == "function" and gethui)
    local targetParent = (gethuiFunc and gethuiFunc()) or CoreGui or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if targetParent then
        for _, child in ipairs(targetParent:GetChildren()) do
            if child:GetAttribute("ApexEggTrackerGui") == true or child.Name:find("ApexEgg") then
                child:Destroy()
            end
        end
    end
end)

-- ==============================================================================
-- 1. RESOLUTOR DEFENSIVO DE SERVICIOS
-- ==============================================================================
local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

local function resolveService(name)
    if name == "Workspace" and typeof(workspace) == "Instance" then return workspace end
    local ok, s = pcall(function() return rawGame:GetService(name) end)
    if ok and s then return s end
    local ok2, s2 = pcall(function() return rawGame:FindFirstChildOfClass(name) end)
    if ok2 and s2 then return s2 end
    return nil
end

local Workspace = resolveService("Workspace") or workspace
local Players = resolveService("Players")
local ReplicatedStorage = resolveService("ReplicatedStorage")
local UserInputService = resolveService("UserInputService")
local RunService = resolveService("RunService")
local TeleportService = resolveService("TeleportService")
local HttpService = resolveService("HttpService")

local LocalPlayer = (Players and Players.LocalPlayer) or (Players and Players:FindFirstChildOfClass("Player")) or (Players and Players.PlayerAdded:Wait())
local PlayerGui = (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 10)) or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))

-- ==============================================================================
-- 2. GESTIÓN DE HILOS, CONEXIONES Y LIMPIEZA
-- ==============================================================================
local connections = {}
local charConnections = {}
local runningThreads = {}
local isScriptActive = true

local function safeConnect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function()
        return signal:Connect(callback)
    end)
    if ok and conn then
        table.insert(connections, conn)
        return conn
    end
    return nil
end

local function spawnSafe(name, fn, ...)
    local args = { ... }
    local thread = task.spawn(function()
        local ok, err = pcall(function()
            fn(table.unpack(args))
        end)
        if not ok and _G.APEX_DEBUG then
            warn("[APEX-TRACKER][" .. tostring(name) .. "] " .. tostring(err))
        end
    end)
    table.insert(runningThreads, thread)
    return thread
end

-- Anti-AFK pasivo e indetectable (sin forzar VirtualUser en startup)
safeConnect(LocalPlayer.Idled, function()
    pcall(function()
        local vu = rawGame:GetService("VirtualUser")
        if vu then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0, 0))
        end
    end)
end)

-- ==============================================================================
-- 3. CONFIGURACIÓN PERSISTENTE
-- ==============================================================================
local CONFIG_FILE = "roba_un_huevo_config.json"
local Config = {
    SprintEnabled = true,
    SprintSpeed = 48,           -- Velocidad segura para no alertar a ObbyAntiTP
    JumpEnabled = true,
    JumpPower = 90,             -- Salto seguro
    InfJump = false,
    Noclip = false,
    SortMode = "Distance",      -- "Distance" o "Luck"
    AutoReexecute = true,
    MinPlayerHop = true,
    TracersEnabled = true,
    BeaconsEnabled = true,
    SafeTeleport = true,        -- Interpolación anti-rubberband
}

local function saveConfig()
    pcall(function()
        local writefileFunc = type(writefile) == "function" and writefile
        if writefileFunc and HttpService then
            writefileFunc(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadConfig()
    pcall(function()
        local isfileFunc = type(isfile) == "function" and isfile
        local readfileFunc = type(readfile) == "function" and readfile
        if isfileFunc and readfileFunc and HttpService and isfileFunc(CONFIG_FILE) then
            local decoded = HttpService:JSONDecode(readfileFunc(CONFIG_FILE))
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do Config[k] = v end
            end
        end
    end)
end
loadConfig()

-- ==============================================================================
-- 4. TABLAS DE CLASIFICACIÓN Y RAREZAS
-- ==============================================================================
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
    ["Boss Chest"]       = 5000000,
    ["Parasite Chest"]   = 15000000,
    ["Crystal Egg"]      = 20000000,
    ["Area Egg"]         = 5000000,
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(175, 175, 175),
    Rare      = Color3.fromRGB(0, 180, 255),
    Epic      = Color3.fromRGB(180, 85, 255),
    Legendary = Color3.fromRGB(255, 175, 0),
    Mythic    = Color3.fromRGB(255, 80, 120),
    Divine    = Color3.fromRGB(255, 235, 50),
    Ethereal  = Color3.fromRGB(130, 240, 255),
    Secret    = Color3.fromRGB(255, 45, 75),
    Unknown   = Color3.fromRGB(180, 160, 120)
}

local function formatNumber(val)
    if not val or val <= 0 then return "0" end
    if val >= 1e12 then return string.format("%.1fT", val / 1e12):gsub("%.0T", "T") end
    if val >= 1e9  then return string.format("%.1fB", val / 1e9):gsub("%.0B", "B") end
    if val >= 1e6  then return string.format("%.1fM", val / 1e6):gsub("%.0M", "M") end
    if val >= 1e3  then return string.format("%.1fK", val / 1e3):gsub("%.0K", "K") end
    return tostring(math.floor(val))
end

-- ==============================================================================
-- 5. SISTEMA DE FÍSICAS SIGILOSAS Y ANTI-RUBBERBAND
-- ==============================================================================
local nativeWalkSpeed = 16
local isShiftHeld = false
local updateTelemetry = nil

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChildOfClass("Humanoid") or char:FindFirstChild("Humanoid"))
end

local function getRootPart()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function isShiftPressed()
    local ok1, k1 = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) end)
    local ok2, k2 = pcall(function() return UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end)
    return (ok1 and k1) or (ok2 and k2) or false
end

local function applyPhysics(char)
    for _, c in ipairs(charConnections) do pcall(function() c:Disconnect() end) end
    table.clear(charConnections)

    if not char then return end
    local hum = char:WaitForChild("Humanoid", 6) or char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if not isShiftPressed() then
        nativeWalkSpeed = hum.WalkSpeed
    end

    if Config.JumpEnabled then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        end)
    end

    local wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not (Config.SprintEnabled and isShiftPressed()) then
            nativeWalkSpeed = hum.WalkSpeed
            if updateTelemetry then updateTelemetry() end
        end
    end)
    table.insert(charConnections, wsConn)
end

if LocalPlayer.Character then applyPhysics(LocalPlayer.Character) end
safeConnect(LocalPlayer.CharacterAdded, function(c)
    task.wait(0.2)
    applyPhysics(c)
end)

-- Ciclo de Sprint suave sincronizado con RenderStepped
safeConnect(RunService.RenderStepped, function()
    if not isScriptActive then return end
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then return end

    local shift = Config.SprintEnabled and isShiftPressed()
    if shift then
        isShiftHeld = true
        local target = tonumber(Config.SprintSpeed) or 48
        if hum.WalkSpeed ~= target then hum.WalkSpeed = target end

        if hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
            pcall(function() hum.SeatPart.MaxSpeed = target end)
        end
    else
        if isShiftHeld then
            isShiftHeld = false
            hum.WalkSpeed = nativeWalkSpeed
        end
    end
end)

-- Salto Infinito
safeConnect(UserInputService.JumpRequest, function()
    if Config.InfJump and isScriptActive then
        local hum = getHumanoid()
        if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Noclip seguro: solo afecta al torso y root part sin saturar el watchdog de Stepped
safeConnect(RunService.Stepped, function()
    if Config.Noclip and isScriptActive and LocalPlayer.Character then
        for _, name in ipairs({ "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso" }) do
            local part = LocalPlayer.Character:FindFirstChild(name)
            if part and part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Teleportación Inteligente Anti-Rubberband (Bypass de ObbyAntiTP)
local function safeTeleport(targetPos)
    local hrp = getRootPart()
    if not hrp or not targetPos then return end

    local startPos = hrp.Position
    local dist = (targetPos - startPos).Magnitude

    -- Si la distancia es corta o el usuario desactivó SafeTeleport: teletransporte directo
    if not Config.SafeTeleport or dist <= 70 then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
        return
    end

    -- Si la distancia es mayor a 70 studs: micro-interpolación de 45 studs por tick
    spawnSafe("SafeTeleportPath", function()
        local steps = math.clamp(math.ceil(dist / 45), 2, 18)
        for i = 1, steps do
            if not isScriptActive or not hrp or not hrp.Parent then break end
            local alpha = i / steps
            local nextPos = startPos:Lerp(targetPos + Vector3.new(0, 4, 0), alpha)
            hrp.CFrame = CFrame.new(nextPos)
            task.wait(0.028)
        end
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
        end
    end)
end

-- ==============================================================================
-- 6. GESTOR DE FAROS 3D (BEACONS, TRACERS & HIGHLIGHTS)
-- ==============================================================================
local activeTrackers = {}
local selectedItemData = nil

local function removeTracker(uuid)
    local tr = activeTrackers[uuid]
    if tr then
        pcall(function()
            if tr.Folder then tr.Folder:Destroy() end
        end)
        activeTrackers[uuid] = nil
    end
end

local function clearAllTrackers()
    for id, _ in pairs(activeTrackers) do removeTracker(id) end
end

local function createTracker(data)
    removeTracker(data.UUID)

    local uuid = data.UUID
    local pos = data.Position
    local color = data.Color or Color3.fromRGB(255, 200, 0)

    local folder = Instance.new("Folder")
    folder.Name = "ApexBeacon_" .. tostring(uuid)
    folder.Parent = Workspace

    local bAnchor = Instance.new("Part", folder)
    bAnchor.Size = Vector3.new(1, 1, 1)
    bAnchor.Position = pos
    bAnchor.Anchored = true
    bAnchor.CanCollide = false
    bAnchor.Transparency = 1

    local tAnchor = Instance.new("Part", folder)
    tAnchor.Size = Vector3.new(1, 1, 1)
    tAnchor.Position = pos + Vector3.new(0, 600, 0)
    tAnchor.Anchored = true
    tAnchor.CanCollide = false
    tAnchor.Transparency = 1

    local a0 = Instance.new("Attachment", bAnchor)
    local a1 = Instance.new("Attachment", tAnchor)

    -- Faro de luz vertical hacia el cielo (Sky Beam)
    if Config.BeaconsEnabled then
        local beam = Instance.new("Beam", folder)
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 3.8
        beam.Width1 = 0.8
        beam.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.8, 0.25),
            NumberSequenceKeypoint.new(1, 1)
        })
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.LightInfluence = 0
    end

    -- Línea guía directa desde el jugador (Tracer)
    local tracerBeam = nil
    local pAttachment = nil
    if Config.TracersEnabled then
        local hrp = getRootPart()
        if hrp then
            pAttachment = Instance.new("Attachment", hrp)
            tracerBeam = Instance.new("Beam", folder)
            tracerBeam.Attachment0 = pAttachment
            tracerBeam.Attachment1 = a0
            tracerBeam.Width0 = 0.6
            tracerBeam.Width1 = 0.6
            tracerBeam.Color = ColorSequence.new(color)
            tracerBeam.Transparency = NumberSequence.new(0.2)
            tracerBeam.FaceCamera = true
            tracerBeam.LightEmission = 0.9
        end
    end

    -- Etiqueta 3D flotante (BillboardGui)
    local bb = Instance.new("BillboardGui", folder)
    bb.Adornee = bAnchor
    bb.Size = UDim2.new(0, 160, 0, 42)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.AlwaysOnTop = true

    local bbLabel = Instance.new("TextLabel", bb)
    bbLabel.Size = UDim2.new(1, 0, 0.5, 0)
    bbLabel.BackgroundTransparency = 1
    bbLabel.Text = data.Name
    bbLabel.TextColor3 = color
    bbLabel.Font = Enum.Font.GothamBold
    bbLabel.TextSize = 13
    bbLabel.TextStrokeTransparency = 0.2

    local bbDist = Instance.new("TextLabel", bb)
    bbDist.Size = UDim2.new(1, 0, 0.5, 0)
    bbDist.Position = UDim2.new(0, 0, 0.5, 0)
    bbDist.BackgroundTransparency = 1
    bbDist.Text = tostring(data.Distance or 0) .. "m"
    bbDist.TextColor3 = Color3.fromRGB(255, 255, 255)
    bbDist.Font = Enum.Font.GothamMedium
    bbDist.TextSize = 11
    bbDist.TextStrokeTransparency = 0.3

    -- Highlight en el modelo 3D si existe
    local hl = nil
    if data.Model3D and data.Model3D:IsA("Model") then
        pcall(function()
            hl = Instance.new("Highlight", folder)
            hl.Adornee = data.Model3D
            hl.FillColor = color
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0.1
        end)
    end

    activeTrackers[uuid] = {
        Folder = folder,
        DistLabel = bbDist,
        PlayerAtt = pAttachment,
        Position = pos,
        Name = data.Name,
        Color = color,
    }
end

-- ==============================================================================
-- 7. ESCÁNER MULTI-ZONA ADAPTATIVO DEL JUEGO
-- ==============================================================================
local function resolvePosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and cf then return cf.Position end
        local root = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart")
        if root then return root.Position end
    end
    return nil
end

local function scanAllCollectibles()
    local list = {}
    local seen = {}
    local hrp = getRootPart()
    local myPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
    local serverNow = Workspace:GetServerTimeNow()

    local function addItem(uuid, name, pos, rarity, val, tag, model3D)
        if not uuid or seen[uuid] or not pos then return end
        seen[uuid] = true

        local color = RARITY_COLORS[rarity] or RARITY_COLORS.Unknown
        local dist = math.floor((myPos - pos).Magnitude)

        table.insert(list, {
            UUID = uuid,
            Name = name,
            Position = pos,
            Rarity = rarity,
            Weight = val or 1000,
            Mutation = tag,
            Color = color,
            Distance = dist,
            Model3D = model3D,
        })
    end

    -- 1. Workspace.Chest y Workspace.World.MonsterParasiteMarkers (Cofres)
    local directChest = Workspace:FindFirstChild("Chest")
    if directChest then
        local pos = resolvePosition(directChest)
        if pos then
            addItem("Chest_Direct", "Cofre Mágico", pos, "Legendary", 5000000, "Spawn", directChest:IsA("Model") and directChest or nil)
        end
    end

    local world = Workspace:FindFirstChild("World")
    if world then
        for _, child in ipairs(world:GetDescendants()) do
            if child.Name == "MonsterParasiteMarkers" or child.Name:find("Parasite") then
                for _, marker in ipairs(child:GetChildren()) do
                    if marker.Name == "Chest" or marker.Name:lower():find("chest") then
                        local pos = resolvePosition(marker)
                        if pos then
                            addItem("Parasite_" .. marker:GetDebugId(), "Cofre Parásito 💀", pos, "Mythic", 15000000, "Evento", marker:IsA("Model") and marker or nil)
                        end
                    end
                end
            end
        end
    end

    -- 2. Workspace.Eggs y Workspace.PlacedEggRenders (Huevos Activos)
    local eggsFolder = Workspace:FindFirstChild("Eggs")
    if eggsFolder then
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            local pos = resolvePosition(egg)
            if pos then
                local tier = egg:GetAttribute("Tier") or egg:GetAttribute("Rarity") or "Epic"
                addItem("Egg_" .. egg.Name, "Huevo: " .. egg.Name, pos, tier, 2500000, "Eclosión", egg:IsA("Model") and egg or nil)
            end
        end
    end

    local placedRenders = Workspace:FindFirstChild("PlacedEggRenders")
    if placedRenders then
        for _, egg in ipairs(placedRenders:GetChildren()) do
            local pos = resolvePosition(egg)
            if pos then
                addItem("PlacedEgg_" .. egg.Name, "Huevo de Zona (" .. egg.Name .. ")", pos, "Rare", 1000000, "Zona", egg:IsA("Model") and egg or nil)
            end
        end
    end

    -- 3. Workspace.AreaEggSlotsClient (Ranuras de Huevos en Áreas de Mapa)
    local areaSlots = Workspace:FindFirstChild("AreaEggSlotsClient")
    if areaSlots then
        for _, slot in ipairs(areaSlots:GetChildren()) do
            local pos = resolvePosition(slot)
            if pos then
                local cleanName = slot.Name:gsub("FirstAreaEgg_[%d_]+", ""):gsub("_", " ")
                addItem("Slot_" .. slot.Name, "Nido: " .. cleanName, pos, "Rare", 750000, "Nido", slot:IsA("Model") and slot or nil)
            end
        end
    end

    -- 4. Workspace.CrystalEggHolders (Huevos de Cristal)
    local crystalHolders = Workspace:FindFirstChild("CrystalEggHolders")
    if crystalHolders then
        for _, holder in ipairs(crystalHolders:GetChildren()) do
            local pos = resolvePosition(holder)
            if pos then
                addItem("Crystal_" .. holder:GetDebugId(), "Huevo de Cristal 💎", pos, "Divine", 25000000, "Cristal", holder:IsA("Model") and holder or nil)
            end
        end
    end

    -- 5. Workspace.World.Dynamic (Cofres y Eventos en vivo)
    local dynamic = world and world:FindFirstChild("Dynamic")
    if dynamic then
        for _, obj in ipairs(dynamic:GetDescendants()) do
            if obj:IsA("Model") or (obj:IsA("BasePart") and not obj.Parent:IsA("Model")) then
                local nLower = obj.Name:lower()
                if nLower:find("chest") or nLower:find("treasure") or nLower:find("crate") or obj:GetAttribute("ChestTier") then
                    local pos = resolvePosition(obj)
                    local endsAt = tonumber(obj:GetAttribute("EndsAt"))
                    if pos and (not endsAt or serverNow < endsAt) then
                        local uid = tostring(obj:GetAttribute("Uid") or obj:GetDebugId())
                        local rawName = obj:GetAttribute("DisplayName") or obj.Name
                        local rarity = obj:GetAttribute("Rarity") or (nLower:find("mythic") and "Mythic" or (nLower:find("legend") and "Legendary" or "Epic"))
                        local val = tonumber(obj:GetAttribute("Reward") or CHEST_VALUE_TABLE[rawName]) or 250000
                        addItem("Dyn_" .. uid, rawName, pos, rarity, val, "Dynamic", obj:IsA("Model") and obj or nil)
                    end
                end
            end
        end
    end

    -- Ordenamiento
    if Config.SortMode == "Luck" then
        table.sort(list, function(a, b) return (a.Weight or 0) > (b.Weight or 0) end)
    else
        table.sort(list, function(a, b) return (a.Distance or 0) < (b.Distance or 0) end)
    end

    return list
end

-- ==============================================================================
-- 8. GESTOR DE VISTA PREVIA 3D (VIEWPORTFRAME)
-- ==============================================================================
local function setupViewport3D(vp, itemData)
    vp:ClearAllChildren()

    local camera = Instance.new("Camera", vp)
    camera.FieldOfView = 30
    vp.CurrentCamera = camera

    local previewModel = nil
    if itemData.Model3D and itemData.Model3D:IsA("Model") then
        pcall(function()
            itemData.Model3D.Archivable = true
            previewModel = itemData.Model3D:Clone()
            for _, d in ipairs(previewModel:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Highlight") then
                    d:Destroy()
                end
            end
        end)
    end

    -- Generador de cofre procedimental si no hay modelo clonable
    if not previewModel or #previewModel:GetDescendants() == 0 then
        if previewModel then previewModel:Destroy() end
        previewModel = Instance.new("Model")

        local base = Instance.new("Part", previewModel)
        base.Size = Vector3.new(3.2, 1.8, 2.2)
        base.Color = Color3.fromRGB(95, 58, 28)
        base.Material = Enum.Material.WoodPlanks
        base.Anchored = true
        base.CanCollide = false
        base.CFrame = CFrame.new(0, -0.4, 0)

        local lid = Instance.new("Part", previewModel)
        lid.Shape = Enum.PartType.Cylinder
        lid.Size = Vector3.new(3.2, 2.2, 2.2)
        lid.Color = Color3.fromRGB(110, 68, 34)
        lid.Material = Enum.Material.Wood
        lid.Anchored = true
        lid.CanCollide = false
        lid.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))

        local trim = Instance.new("Part", previewModel)
        trim.Size = Vector3.new(0.4, 2.2, 2.3)
        trim.Color = itemData.Color or Color3.fromRGB(255, 195, 40)
        trim.Material = Enum.Material.Metal
        trim.Anchored = true
        trim.CanCollide = false
        trim.CFrame = CFrame.new(0, 0, 0)
    end

    previewModel.Parent = vp
    local cf, sz = previewModel:GetBoundingBox()
    local maxDim = math.max(sz.X, sz.Y, sz.Z, 3)
    local camDist = maxDim * 2.1
    camera.CFrame = CFrame.new(cf.Position + Vector3.new(camDist * 0.7, camDist * 0.5, camDist * 0.9), cf.Position)

    -- Giro suave en 3D
    local angle = 0
    spawnSafe("ViewportSpin_" .. tostring(itemData.UUID), function()
        while isScriptActive and vp and vp.Parent and previewModel and previewModel.Parent do
            angle = (angle + 1.8) % 360
            pcall(function()
                previewModel:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(angle), 0))
            end)
            task.wait(0.035)
        end
    end)
end

-- ==============================================================================
-- 9. INTERFAZ GRÁFICA MODERNA Y CAMUFLADA (UI)
-- ==============================================================================
local gethuiFunc = (type(gethui) == "function" and gethui)
local parentContainer = (gethuiFunc and gethuiFunc()) or game:GetService("CoreGui") or PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ApexGui_" .. HttpService:GenerateGUID(false):sub(1, 8)
screenGui.ResetOnSpawn = false
screenGui:SetAttribute("ApexEggTrackerGui", true)
pcall(function()
    screenGui.Parent = parentContainer
end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 440, 0, 520)
mainFrame.Position = UDim2.new(0.03, 0, 0.22, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local mStroke = Instance.new("UIStroke", mainFrame)
mStroke.Thickness = 1.4
mStroke.Color = Color3.fromRGB(50, 55, 70)

-- Arrastre fluido
local dragging, dragStart, startPos
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

safeConnect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Header
local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.65, 0, 1, 0)
title.Position = UDim2.new(0.04, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🥚 ROBA UN HUEVO PRO"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(0.92, 0, 0.18, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(175, 45, 45)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Barra de Pestañas
local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(0.92, 0, 0, 30)
tabBar.Position = UDim2.new(0.04, 0, 0.095, 0)
tabBar.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
tabBar.BorderSizePixel = 0
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)

local function makeTab(name, txt, active)
    local btn = Instance.new("TextButton", tabBar)
    btn.Name = name
    btn.Size = UDim2.new(0.31, 0, 0.82, 0)
    btn.BackgroundColor3 = active and Color3.fromRGB(45, 115, 220) or Color3.fromRGB(25, 28, 36)
    btn.Text = txt
    btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 180, 190)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    return btn
end

local tabBtnCollect = makeTab("TabCollect", "🥚 Huevos & Cofres", true)
local tabBtnMove = makeTab("TabMove", "⚡ Físicas & Teleport", false)
local tabBtnHop = makeTab("TabHop", "🌐 Server Hop", false)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(0.92, 0, 0.76, 0)
contentArea.Position = UDim2.new(0.04, 0, 0.175, 0)
contentArea.BackgroundTransparency = 1

-- ==============================================================================
-- PÁGINA 1: COFRES & HUEVOS
-- ==============================================================================
local pageCollect = Instance.new("Frame", contentArea)
pageCollect.Size = UDim2.new(1, 0, 1, 0)
pageCollect.BackgroundTransparency = 1

local topBar = Instance.new("Frame", pageCollect)
topBar.Size = UDim2.new(1, 0, 0, 28)
topBar.BackgroundTransparency = 1

local sortBtn = Instance.new("TextButton", topBar)
sortBtn.Size = UDim2.new(0.48, 0, 1, 0)
sortBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
sortBtn.Text = "Filtro: " .. (Config.SortMode == "Luck" and "Mayor Valor 💰" or "Distancia 📍")
sortBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
sortBtn.Font = Enum.Font.GothamMedium
sortBtn.TextSize = 11
Instance.new("UICorner", sortBtn).CornerRadius = UDim.new(0, 5)

local clearAllBtn = Instance.new("TextButton", topBar)
clearAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
clearAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
clearAllBtn.BackgroundColor3 = Color3.fromRGB(140, 45, 45)
clearAllBtn.Text = "Limpiar Faros ❌"
clearAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearAllBtn.Font = Enum.Font.GothamMedium
clearAllBtn.TextSize = 11
Instance.new("UICorner", clearAllBtn).CornerRadius = UDim.new(0, 5)

local scrollList = Instance.new("ScrollingFrame", pageCollect)
scrollList.Size = UDim2.new(1, 0, 1, -34)
scrollList.Position = UDim2.new(0, 0, 0, 34)
scrollList.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 4
Instance.new("UICorner", scrollList).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout", scrollList)
listLayout.Padding = UDim.new(0, 6)

-- Menú Contextual (Teleport / Rastrear)
local contextMenu = Instance.new("Frame", screenGui)
contextMenu.Size = UDim2.new(0, 140, 0, 75)
contextMenu.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", contextMenu).Color = Color3.fromRGB(60, 65, 80)

local function makeCtxBtn(txt, color, yPos)
    local btn = Instance.new("TextButton", contextMenu)
    btn.Size = UDim2.new(0.9, 0, 0, 28)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = txt
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local btnTrack = makeCtxBtn("🎯 Rastrear Faro", Color3.fromRGB(45, 115, 220), 6)
local btnTeleport = makeCtxBtn("⚡ Teleport Seguro", Color3.fromRGB(35, 150, 95), 38)

-- ==============================================================================
-- PÁGINA 2: FÍSICAS & TELEPORT
-- ==============================================================================
local pageMove = Instance.new("Frame", contentArea)
pageMove.Size = UDim2.new(1, 0, 1, 0)
pageMove.BackgroundTransparency = 1
pageMove.Visible = false

local moveLayout = Instance.new("UIListLayout", pageMove)
moveLayout.Padding = UDim.new(0, 10)

local function makeToggleRow(txt, initialVal, onToggle)
    local row = Instance.new("Frame", pageMove)
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.Position = UDim2.new(0.04, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", row)
    toggleBtn.Size = UDim2.new(0, 52, 0, 26)
    toggleBtn.Position = UDim2.new(0.96, -52, 0.16, 0)
    toggleBtn.BackgroundColor3 = initialVal and Color3.fromRGB(45, 160, 90) or Color3.fromRGB(60, 65, 75)
    toggleBtn.Text = initialVal and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 11
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

    local state = initialVal
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(45, 160, 90) or Color3.fromRGB(60, 65, 75)
        toggleBtn.Text = state and "ON" or "OFF"
        onToggle(state)
        saveConfig()
    end)
    return row
end

makeToggleRow("⚡ Shift Sprint Suave (48 studs/s)", Config.SprintEnabled, function(v) Config.SprintEnabled = v end)
makeToggleRow("🦘 Super Salto (JumpPower: 90)", Config.JumpEnabled, function(v) Config.JumpEnabled = v end)
makeToggleRow("🕊️ Salto Infinito", Config.InfJump, function(v) Config.InfJump = v end)
makeToggleRow("👻 Noclip Sigiloso (Bypass Torso)", Config.Noclip, function(v) Config.Noclip = v end)
makeToggleRow("🛡️ Safe Teleport (Anti-Rubberband)", Config.SafeTeleport, function(v) Config.SafeTeleport = v end)
makeToggleRow("📍 Faros Verticales (Sky Beacons)", Config.BeaconsEnabled, function(v) Config.BeaconsEnabled = v end)

-- ==============================================================================
-- PÁGINA 3: SERVER HOPPER
-- ==============================================================================
local pageHop = Instance.new("Frame", contentArea)
pageHop.Size = UDim2.new(1, 0, 1, 0)
pageHop.BackgroundTransparency = 1
pageHop.Visible = false

local hopLayout = Instance.new("UIListLayout", pageHop)
hopLayout.Padding = UDim.new(0, 10)

local hopInfo = Instance.new("TextLabel", pageHop)
hopInfo.Size = UDim2.new(1, 0, 0, 50)
hopInfo.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
hopInfo.Text = "Busca servidores públicos con pocos jugadores para farmear cofres y huevos sin interferencias."
hopInfo.TextColor3 = Color3.fromRGB(180, 185, 195)
hopInfo.Font = Enum.Font.GothamMedium
hopInfo.TextSize = 11
hopInfo.TextWrapped = true
Instance.new("UICorner", hopInfo).CornerRadius = UDim.new(0, 6)

local hopBtn = Instance.new("TextButton", pageHop)
hopBtn.Size = UDim2.new(1, 0, 0, 42)
hopBtn.BackgroundColor3 = Color3.fromRGB(45, 115, 220)
hopBtn.Text = "🚀 Cambiar de Servidor (Menos Jugadores)"
hopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hopBtn.Font = Enum.Font.GothamBold
hopBtn.TextSize = 12
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 6)

local rejoinBtn = Instance.new("TextButton", pageHop)
rejoinBtn.Size = UDim2.new(1, 0, 0, 42)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(35, 150, 95)
rejoinBtn.Text = "🔄 Reconectar al Mismo Servidor"
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 12
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)

-- Server Hop Logic
local function serverHop()
    hopBtn.Text = "⏳ Buscando Servidor..."
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    spawnSafe("ServerHopTask", function()
        local raw = nil
        pcall(function()
            if typeof(game.HttpGet) == "function" then raw = game:HttpGet(url)
            elseif typeof(request) == "function" then raw = request({ Url = url, Method = "GET" }).Body end
        end)
        if raw and HttpService then
            local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and data and data.data then
                local list = {}
                for _, srv in ipairs(data.data) do
                    if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                        table.insert(list, srv)
                    end
                end
                table.sort(list, function(a, b) return a.playing < b.playing end)
                if #list > 0 then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, list[1].id, LocalPlayer)
                    return
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

hopBtn.MouseButton1Click:Connect(serverHop)
rejoinBtn.MouseButton1Click:Connect(function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

-- Cambio de Pestañas
local function switchTab(activePage, activeBtn)
    pageCollect.Visible = (activePage == pageCollect)
    pageMove.Visible = (activePage == pageMove)
    pageHop.Visible = (activePage == pageHop)

    for _, b in ipairs({ tabBtnCollect, tabBtnMove, tabBtnHop }) do
        b.BackgroundColor3 = (b == activeBtn) and Color3.fromRGB(45, 115, 220) or Color3.fromRGB(25, 28, 36)
        b.TextColor3 = (b == activeBtn) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 180, 190)
    end
end

tabBtnCollect.MouseButton1Click:Connect(function() switchTab(pageCollect, tabBtnCollect) end)
tabBtnMove.MouseButton1Click:Connect(function() switchTab(pageMove, tabBtnMove) end)
tabBtnHop.MouseButton1Click:Connect(function() switchTab(pageHop, tabBtnHop) end)

-- ==============================================================================
-- 10. REFRESCO DE LISTA DE OBJETIVOS (GUI)
-- ==============================================================================
local function refreshGUI()
    if not isScriptActive or not scrollList or not scrollList.Parent then return end

    local items = scanAllCollectibles()
    scrollList:ClearAllChildren()
    Instance.new("UIListLayout", scrollList).Padding = UDim.new(0, 6)

    if #items == 0 then
        local emptyLbl = Instance.new("TextLabel", scrollList)
        emptyLbl.Size = UDim2.new(1, 0, 0, 60)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "🔍 No se encontraron cofres ni huevos activos en el servidor."
        emptyLbl.TextColor3 = Color3.fromRGB(150, 155, 165)
        emptyLbl.Font = Enum.Font.GothamMedium
        emptyLbl.TextSize = 11
        return
    end

    for _, data in ipairs(items) do
        local card = Instance.new("Frame", scrollList)
        card.Size = UDim2.new(1, -6, 0, 56)
        card.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        -- Borde con color de rareza
        local stroke = Instance.new("UIStroke", card)
        stroke.Thickness = 1.2
        stroke.Color = data.Color or Color3.fromRGB(60, 65, 80)

        -- Viewport 3D
        local vp = Instance.new("ViewportFrame", card)
        vp.Size = UDim2.new(0, 48, 0, 48)
        vp.Position = UDim2.new(0, 4, 0.5, -24)
        vp.BackgroundTransparency = 1
        setupViewport3D(vp, data)

        -- Nombre
        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(0.65, -60, 0, 18)
        nameLbl.Position = UDim2.new(0, 58, 0, 8)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = data.Name
        nameLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- Rareza / Distancia
        local infoLbl = Instance.new("TextLabel", card)
        infoLbl.Size = UDim2.new(0.65, -60, 0, 16)
        infoLbl.Position = UDim2.new(0, 58, 0, 28)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = string.format("%s  |  📍 %dm  |  %s", data.Rarity, data.Distance or 0, data.Mutation or "")
        infoLbl.TextColor3 = data.Color or Color3.fromRGB(175, 180, 190)
        infoLbl.Font = Enum.Font.GothamMedium
        infoLbl.TextSize = 10
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- Botón Acción Rápida (Teleport directo)
        local tpBtn = Instance.new("TextButton", card)
        tpBtn.Size = UDim2.new(0, 36, 0, 36)
        tpBtn.Position = UDim2.new(1, -42, 0.5, -18)
        tpBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 85)
        tpBtn.Text = "⚡"
        tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 14
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

        tpBtn.MouseButton1Click:Connect(function()
            safeTeleport(data.Position)
        end)

        -- Clic en tarjeta abre Menú Contextual
        local clickBtn = Instance.new("TextButton", card)
        clickBtn.Size = UDim2.new(1, -50, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""

        clickBtn.MouseButton1Click:Connect(function()
            selectedItemData = data
            local mPos = UserInputService:GetMouseLocation()
            contextMenu.Position = UDim2.new(0, mPos.X - 10, 0, mPos.Y - 10)
            btnTrack.Text = activeTrackers[data.UUID] and "❌ Quitar Faro" or "🎯 Rastrear Faro"
            contextMenu.Visible = true
        end)
    end
end

-- ==============================================================================
-- 11. CONEXIONES FINALES Y LIMPIEZA
-- ==============================================================================
sortBtn.MouseButton1Click:Connect(function()
    Config.SortMode = (Config.SortMode == "Luck") and "Distance" or "Luck"
    sortBtn.Text = "Filtro: " .. (Config.SortMode == "Luck" and "Mayor Valor 💰" or "Distancia 📍")
    saveConfig()
    refreshGUI()
end)

clearAllBtn.MouseButton1Click:Connect(function()
    clearAllTrackers()
    refreshGUI()
end)

btnTrack.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedItemData then
        if activeTrackers[selectedItemData.UUID] then
            removeTracker(selectedItemData.UUID)
        else
            createTracker(selectedItemData)
        end
        refreshGUI()
    end
end)

btnTeleport.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedItemData then
        safeTeleport(selectedItemData.Position)
    end
end)

safeConnect(UserInputService.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mPos = UserInputService:GetMouseLocation()
        local pos = contextMenu.AbsolutePosition
        local sz = contextMenu.AbsoluteSize
        if mPos.X < pos.X or mPos.X > pos.X + sz.X or mPos.Y < pos.Y or mPos.Y > pos.Y + sz.Y then
            contextMenu.Visible = false
        end
    end
end)

local function destroyScript()
    isScriptActive = false
    saveConfig()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    for _, c in ipairs(charConnections) do pcall(function() c:Disconnect() end) end
    table.clear(charConnections)
    clearAllTrackers()
    for _, th in ipairs(runningThreads) do pcall(function() task.cancel(th) end) end
    table.clear(runningThreads)
    if screenGui then screenGui:Destroy() end
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = nativeWalkSpeed end
end
closeBtn.MouseButton1Click:Connect(destroyScript)

-- Bucle de refresco en segundo plano (cada 3.5 segundos)
spawnSafe("AutoRefreshLoop", function()
    while isScriptActive and screenGui and screenGui.Parent do
        refreshGUI()
        task.wait(3.5)
    end
end)

refreshGUI()
