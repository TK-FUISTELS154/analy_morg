-- ==============================================================================
-- 🥚 APEX SUITE - ROBA UN HUEVO & CHEST TRACKER PRO (ULTRA STEALTH & SPEED ENGINE)
-- ==============================================================================
-- Diseñado con ingeniería inversa del volcado completo del juego (PlaceId: 1794327797).
-- Características Principales:
-- 1. Anti-Cheat Stealth Engine: Cero hooks a Kick, anti-AFK pasivo, GUI camuflada con gethui().
-- 2. Anti-Rubberband Teleport: Micro-pasos seguros que evitan el watchdog de ObbyAntiTP.
-- 3. Bypass de Velocidad de Guardias (Waking Escape):
--    - Roba huevos de CUALQUIER zona (incluyendo la zona Alien/Final con guardias de 279 m/s).
--    - Aprovecha la ventana de "Waking" (~1.2s) del guardia donde WalkSpeed = 0 para escapar al ClosestExitPoint en < 0.25s.
-- 4. Velocidad Adaptativa Dinámica:
--    - Detecta la velocidad del guardia de la zona (GuardEscapeSpeeds / Humanoid.WalkSpeed).
--    - Inyecta hasta 295 m/s (dentro de los 300 soportados nativamente por el motor del juego) para superar al guardia.
-- 5. Escudo Anti-Guardia Activo:
--    - Monitorea la distancia XZ del guardia al portar un huevo; si baja de 30m, activa auto-dodge vertical o escape a la salida.
-- 6. Escáner de 14 Zonas de Guardias y Nidos:
--    - Alien, Cosmic, Light Dark, Cherry Blossom, Jungle, Prehistoric, Abyss Ocean,
--      Titan Temple, Volcano, Snow, Lake, Enchanted Forest, Desert, Forest.
-- 7. 3D ViewportFrame en Vivo, Faros Verticales (Sky Beacons), Tracers y Server Hopper.
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
            warn("[APEX-EGG-TRACKER][" .. tostring(name) .. "] " .. tostring(err))
        end
    end)
    table.insert(runningThreads, thread)
    return thread
end

-- Anti-AFK pasivo e indetectable
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
    SprintSpeed = 48,           -- Velocidad manual
    JumpEnabled = true,
    JumpPower = 90,             -- Salto seguro
    InfJump = false,
    Noclip = false,
    SortMode = "Zone",          -- "Zone", "Distance" o "Luck"
    SelectedZone = "All",
    AutoReexecute = true,
    MinPlayerHop = true,
    TracersEnabled = true,
    BeaconsEnabled = true,
    SafeTeleport = true,        -- Micro-interpolación anti-rubberband

    -- NUEVAS CARACTERÍSTICAS PARA SUPERAR CUALQUIER VELOCIDAD DE GUARDIA
    AdaptiveSpeed = true,       -- Inyección adaptativa de velocidad por zona (hasta 295 m/s)
    WakingEscape = true,        -- Escape instantáneo en ventana Waking de 1.2s del guardia
    AntiGuardShield = true,     -- Auto-dodge si el guardia se acerca a < 30m al portar huevo
    AutoDoffHeavyTools = true,  -- Limpieza de herramientas pesadas que ralentizan
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
-- 4. CATÁLOGO DE ZONAS, GUARDIAS Y METADATOS
-- ==============================================================================
local GAME_ZONES = {
    { Id = "Alien",          Name = "🛸 Alien (Zona Final)",     Tier = 14, GuardSpeed = 279, Color = Color3.fromRGB(0, 255, 170) },
    { Id = "Light Dark",     Name = "🌓 Light Dark",             Tier = 13, GuardSpeed = 270, Color = Color3.fromRGB(220, 150, 255) },
    { Id = "Cosmic",         Name = "🌌 Cosmic",                 Tier = 12, GuardSpeed = 265, Color = Color3.fromRGB(130, 200, 255) },
    { Id = "Cherry Blossom", Name = "🌸 Cherry Blossom (Sakura)",Tier = 11, GuardSpeed = 255, Color = Color3.fromRGB(255, 160, 200) },
    { Id = "Jungle",         Name = "🌴 Jungle",                 Tier = 10, GuardSpeed = 245, Color = Color3.fromRGB(80, 215, 80) },
    { Id = "Prehistoric",    Name = "🦖 Prehistoric",            Tier = 9,  GuardSpeed = 230, Color = Color3.fromRGB(215, 180, 60) },
    { Id = "Abyss Ocean",    Name = "🌊 Abyss Ocean",            Tier = 8,  GuardSpeed = 210, Color = Color3.fromRGB(40, 140, 255) },
    { Id = "Titan Temple",   Name = "🏛️ Titan Temple",           Tier = 7,  GuardSpeed = 180, Color = Color3.fromRGB(255, 175, 40) },
    { Id = "Volcano",        Name = "🌋 Volcano",                Tier = 6,  GuardSpeed = 150, Color = Color3.fromRGB(255, 60, 40) },
    { Id = "Snow",           Name = "❄️ Snow / Tundra",          Tier = 5,  GuardSpeed = 120, Color = Color3.fromRGB(180, 230, 255) },
    { Id = "Lake",           Name = "🏞️ Lake",                   Tier = 4,  GuardSpeed = 95,  Color = Color3.fromRGB(70, 190, 210) },
    { Id = "Enchanted Forest",Name= "✨ Enchanted Forest",       Tier = 3,  GuardSpeed = 251, Color = Color3.fromRGB(160, 75, 255) },
    { Id = "Desert",         Name = "🏜️ Desert",                 Tier = 2,  GuardSpeed = 45,  Color = Color3.fromRGB(235, 190, 120) },
    { Id = "Forest",         Name = "🌲 Forest (Tutorial)",      Tier = 1,  GuardSpeed = 25,  Color = Color3.fromRGB(60, 190, 90) },
}

local ZONE_MAP = {}
for _, z in ipairs(GAME_ZONES) do ZONE_MAP[z.Id] = z end

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

-- ==============================================================================
-- 5. SISTEMA DE FÍSICAS, VELOCIDAD ADAPTATIVA Y ANTI-RUBBERBAND
-- ==============================================================================
local nativeWalkSpeed = 16
local isShiftHeld = false
local isStealingActive = false
local currentAreaSpeedBoost = 0

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

    if not isShiftPressed() and not isStealingActive and currentAreaSpeedBoost == 0 then
        nativeWalkSpeed = hum.WalkSpeed
    end

    if Config.JumpEnabled then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        end)
    end

    local wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not (Config.SprintEnabled and isShiftPressed()) and not isStealingActive and currentAreaSpeedBoost == 0 then
            nativeWalkSpeed = hum.WalkSpeed
        end
    end)
    table.insert(charConnections, wsConn)
end

if LocalPlayer.Character then applyPhysics(LocalPlayer.Character) end
safeConnect(LocalPlayer.CharacterAdded, function(c)
    task.wait(0.2)
    applyPhysics(c)
end)

-- Ciclo de Sprint / Velocidad Sincronizado
safeConnect(RunService.RenderStepped, function()
    if not isScriptActive then return end
    local hum = getHumanoid()
    if not hum or hum.Health <= 0 then return end

    -- Si estamos en secuencia de robo o con boost adaptativo activo
    if currentAreaSpeedBoost > 0 then
        if hum.WalkSpeed ~= currentAreaSpeedBoost then
            hum.WalkSpeed = currentAreaSpeedBoost
        end
        return
    end

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

-- Noclip Sigiloso (sin saturar Stepped)
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
local function safeTeleport(targetPos, speedFactor)
    local hrp = getRootPart()
    if not hrp or not targetPos then return end

    local startPos = hrp.Position
    local dist = (targetPos - startPos).Magnitude

    if not Config.SafeTeleport or dist <= 60 then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        return
    end

    local stepSize = (speedFactor and speedFactor > 1) and 65 or 45
    local waitDelay = (speedFactor and speedFactor > 1) and 0.018 or 0.028
    local steps = math.clamp(math.ceil(dist / stepSize), 2, 16)

    for i = 1, steps do
        if not isScriptActive or not hrp or not hrp.Parent then break end
        local alpha = i / steps
        local nextPos = startPos:Lerp(targetPos + Vector3.new(0, 3, 0), alpha)
        hrp.CFrame = CFrame.new(nextPos)
        task.wait(waitDelay)
    end
    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end
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
    local color = data.Color or Color3.fromRGB(0, 220, 255)

    local folder = Instance.new("Folder")
    folder.Name = "ApexEggBeacon_" .. tostring(uuid)
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
    bbDist.Text = tostring(data.Distance or 0) .. "m | Guardia: " .. tostring(data.GuardSpeed or 25) .. "m/s"
    bbDist.TextColor3 = Color3.fromRGB(255, 255, 255)
    bbDist.Font = Enum.Font.GothamMedium
    bbDist.TextSize = 11
    bbDist.TextStrokeTransparency = 0.3

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
-- 7. ESCÁNER PROFUNDO DE ZONAS, GUARDIAS Y NIDOS (14 ZONAS)
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
    local world = Workspace:FindFirstChild("World")
    local areasFolder = world and world:FindFirstChild("Areas") and world.Areas:FindFirstChild("GuardAreas")

    local function addItem(uuid, name, pos, rarity, val, tag, model3D, zoneId, guardSpeed, exitPos, prompt, uid)
        if not uuid or seen[uuid] or not pos then return end
        seen[uuid] = true

        local color = RARITY_COLORS[rarity] or (zoneId and ZONE_MAP[zoneId] and ZONE_MAP[zoneId].Color) or RARITY_COLORS.Unknown
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
            ZoneId = zoneId or "Desconocida",
            GuardSpeed = guardSpeed or 25,
            ExitPosition = exitPos,
            Prompt = prompt,
            EggUid = uid,
        })
    end

    -- 1. Escaneo de las 14 Zonas de Guardias en Workspace.World.Areas.GuardAreas
    if areasFolder then
        for _, areaModel in ipairs(areasFolder:GetChildren()) do
            local zoneMeta = ZONE_MAP[areaModel.Name]
            local zoneName = zoneMeta and zoneMeta.Name or areaModel.Name
            local guardModel = areaModel:FindFirstChild("Guard")
            local guardHum = guardModel and guardModel:FindFirstChildOfClass("Humanoid")
            local guardSpeed = guardHum and guardHum.WalkSpeed or (zoneMeta and zoneMeta.GuardSpeed) or 25

            -- Obtener punto de salida seguro
            local exitPart = areaModel:FindFirstChild("ClosestExitPoint")
            local exitPos = exitPart and exitPart.Position or nil

            if not exitPos then
                local bounds = areaModel:FindFirstChild("Bounds")
                if bounds and bounds:IsA("BasePart") then
                    exitPos = bounds.Position + Vector3.new(bounds.Size.X * 0.5 + 15, 0, 0)
                end
            end

            -- Nidos en el área
            local nests = areaModel:FindFirstChild("Nests")
            if nests then
                for idx, nest in ipairs(nests:GetChildren()) do
                    local nPos = resolvePosition(nest)
                    if nPos then
                        local prompt = nest:FindFirstChildWhichIsA("ProximityPrompt", true)
                        local eggInNest = nest:FindFirstChild("Egg") or nest:FindFirstChildWhichIsA("Model")
                        local eggUid = nest:GetAttribute("Uid") or (eggInNest and eggInNest:GetAttribute("Uid")) or (areaModel.Name .. "_Nest_" .. idx)
                        local rarity = nest:GetAttribute("Rarity") or (zoneMeta and zoneMeta.Tier >= 10 and "Divine" or (zoneMeta and zoneMeta.Tier >= 6 and "Legendary" or "Rare"))
                        local tag = "Nido (" .. tostring(idx) .. ")"

                        addItem("NestEgg_" .. areaModel.Name .. "_" .. idx, "Huevo de " .. zoneName, nPos, rarity, (zoneMeta and zoneMeta.Tier or 1) * 2000000, tag, eggInNest or nest, areaModel.Name, guardSpeed, exitPos, prompt, eggUid)
                    end
                end
            end
        end
    end

    -- 2. Workspace.AreaEggSlotsClient (Huevos sincronizados en vivo)
    local areaSlots = Workspace:FindFirstChild("AreaEggSlotsClient")
    if areaSlots then
        for _, slot in ipairs(areaSlots:GetChildren()) do
            local pos = resolvePosition(slot)
            if pos then
                local cleanName = slot.Name:gsub("FirstAreaEgg_[%d_]+", ""):gsub("_", " ")
                local prompt = slot:FindFirstChildWhichIsA("ProximityPrompt", true)
                local uid = slot:GetAttribute("Uid") or slot.Name
                addItem("Slot_" .. slot.Name, "Huevo de Área (" .. cleanName .. ")", pos, "Epic", 5000000, "En Vivo", slot:IsA("Model") and slot or nil, "Mapa", 45, nil, prompt, uid)
            end
        end
    end

    -- 3. Workspace.PlacedEggRenders
    local placedRenders = Workspace:FindFirstChild("PlacedEggRenders")
    if placedRenders then
        for _, egg in ipairs(placedRenders:GetChildren()) do
            local pos = resolvePosition(egg)
            if pos then
                local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
                addItem("PlacedEgg_" .. egg.Name, "Huevo Terrestre (" .. egg.Name .. ")", pos, "Rare", 1500000, "Zona", egg:IsA("Model") and egg or nil, "Terreno", 25, nil, prompt, egg.Name)
            end
        end
    end

    -- 4. Workspace.CrystalEggHolders (Huevos de Cristal Divinos)
    local crystalHolders = Workspace:FindFirstChild("CrystalEggHolders")
    if crystalHolders then
        for _, holder in ipairs(crystalHolders:GetChildren()) do
            local pos = resolvePosition(holder)
            if pos then
                local prompt = holder:FindFirstChildWhichIsA("ProximityPrompt", true)
                addItem("Crystal_" .. holder:GetDebugId(), "Huevo de Cristal 💎", pos, "Divine", 35000000, "Cristal", holder:IsA("Model") and holder or nil, "Especial", 100, nil, prompt, holder.Name)
            end
        end
    end

    -- 5. Workspace.Chest y Parásitos
    local directChest = Workspace:FindFirstChild("Chest")
    if directChest then
        local pos = resolvePosition(directChest)
        if pos then
            addItem("Chest_Direct", "Cofre Mágico", pos, "Legendary", 5000000, "Cofre", directChest:IsA("Model") and directChest or nil, "Global", 0, nil, nil, nil)
        end
    end

    local worldFolder = Workspace:FindFirstChild("World")
    if worldFolder then
        for _, child in ipairs(worldFolder:GetDescendants()) do
            if child.Name == "MonsterParasiteMarkers" or child.Name:find("Parasite") then
                for _, marker in ipairs(child:GetChildren()) do
                    if marker.Name == "Chest" or marker.Name:lower():find("chest") then
                        local pos = resolvePosition(marker)
                        if pos then
                            addItem("Parasite_" .. marker:GetDebugId(), "Cofre Parásito 💀", pos, "Mythic", 15000000, "Evento", marker:IsA("Model") and marker or nil, "Evento", 0, nil, nil, nil)
                        end
                    end
                end
            end
        end
    end

    -- Filtro por Zona si está seleccionado
    if Config.SelectedZone and Config.SelectedZone ~= "All" then
        local filtered = {}
        for _, item in ipairs(list) do
            if item.ZoneId == Config.SelectedZone then
                table.insert(filtered, item)
            end
        end
        list = filtered
    end

    -- Ordenamiento
    if Config.SortMode == "Luck" then
        table.sort(list, function(a, b) return (a.Weight or 0) > (b.Weight or 0) end)
    elseif Config.SortMode == "Zone" then
        table.sort(list, function(a, b) return (b.GuardSpeed or 0) > (a.GuardSpeed or 0) end)
    else
        table.sort(list, function(a, b) return (a.Distance or 0) < (b.Distance or 0) end)
    end

    return list
end

-- ==============================================================================
-- 8. MOTOR DE ROBO & ESCAPE SIGILOSO (WAKING WINDOW BYPASS)
-- ==============================================================================
local function executeStealAndEscape(itemData)
    if isStealingActive then return end
    isStealingActive = true

    spawnSafe("StealRoutine_" .. tostring(itemData.UUID), function()
        local hrp = getRootPart()
        local hum = getHumanoid()
        if not hrp or not hum then
            isStealingActive = false
            return
        end

        local eggPos = itemData.Position
        local guardSpeed = itemData.GuardSpeed or 25
        local exitPos = itemData.ExitPosition

        -- Resolver punto de salida seguro si falta
        if not exitPos then
            local world = Workspace:FindFirstChild("World")
            local areasFolder = world and world:FindFirstChild("Areas") and world.Areas:FindFirstChild("GuardAreas")
            local currentArea = areasFolder and areasFolder:FindFirstChild(itemData.ZoneId)
            local exitPart = currentArea and currentArea:FindFirstChild("ClosestExitPoint")
            if exitPart then
                exitPos = exitPart.Position
            else
                exitPos = eggPos + Vector3.new(0, 5, 80)
            end
        end

        -- 1. Teletransporte seguro hacia el nido
        safeTeleport(eggPos + Vector3.new(0, 2.5, 0), 1.2)
        task.wait(0.06)

        -- 2. Inyección de Velocidad Adaptativa mientras roba
        if Config.AdaptiveSpeed then
            currentAreaSpeedBoost = math.clamp(guardSpeed + 20, 65, 295)
            hum.WalkSpeed = currentAreaSpeedBoost
        end

        -- 3. Activar el robo del huevo
        local promptFired = false
        if itemData.Prompt then
            pcall(function()
                if typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(itemData.Prompt, 0)
                    promptFired = true
                else
                    itemData.Prompt:InputHoldBegin()
                    task.wait(itemData.Prompt.HoldDuration or 0.25)
                    itemData.Prompt:InputHoldEnd()
                    promptFired = true
                end
            end)
        end

        -- Invocación directa a Remotes de EggWorld si existe el UID
        if itemData.EggUid then
            pcall(function()
                local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
                local rfCarry = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
                if rfCarry then
                    rfCarry:InvokeServer({ Uid = itemData.EggUid, FirstAreaSlotKey = nil })
                end
            end)
        end

        -- 4. Escape ultrarrápido durante la ventana de Waking del guardia (1.2s congelado)
        if Config.WakingEscape and exitPos then
            task.wait(0.04)
            safeTeleport(exitPos + Vector3.new(0, 3, 0), 2.0)
        end

        task.wait(0.3)
        currentAreaSpeedBoost = 0
        if hum and not isShiftPressed() then
            hum.WalkSpeed = nativeWalkSpeed
        end
        isStealingActive = false
    end)
end

-- ==============================================================================
-- 9. ESCUDO ANTI-GUARDIA Y VELOCIDAD ADAPTATIVA EN SEGUNDO PLANO
-- ==============================================================================
spawnSafe("GuardWatchdogThread", function()
    while isScriptActive do
        task.wait(0.25)
        local hrp = getRootPart()
        local hum = getHumanoid()
        if hrp and hum and hum.Health > 0 and not isStealingActive then
            local world = Workspace:FindFirstChild("World")
            local areasFolder = world and world:FindFirstChild("Areas") and world.Areas:FindFirstChild("GuardAreas")

            if areasFolder then
                local inGuardedZone = false
                local activeGuardSpeed = nativeWalkSpeed

                for _, area in ipairs(areasFolder:GetChildren()) do
                    local guard = area:FindFirstChild("Guard")
                    local gRoot = guard and (guard:FindFirstChild("HumanoidRootPart") or guard:FindFirstChild("Torso"))
                    local gHum = guard and guard:FindFirstChildOfClass("Humanoid")
                    local bounds = area:FindFirstChild("Bounds")

                    -- Verificar si estamos dentro de la zona
                    if bounds and bounds:IsA("BasePart") then
                        local rel = bounds.CFrame:PointToObjectSpace(hrp.Position)
                        local half = bounds.Size * 0.5
                        if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z then
                            inGuardedZone = true
                            local gSpd = gHum and gHum.WalkSpeed or (ZONE_MAP[area.Name] and ZONE_MAP[area.Name].GuardSpeed) or 25
                            activeGuardSpeed = math.clamp(gSpd + 15, 60, 295)

                            -- ESCUDO ACTIVO: si el guardia nos persigue y está a menos de 30 metros
                            if Config.AntiGuardShield and guard and gRoot then
                                local gTarget = guard:GetAttribute("TargetPlayer")
                                local gState = guard:GetAttribute("GuardState")
                                if gState == "Chasing" and (gTarget == tostring(LocalPlayer.UserId) or gTarget == LocalPlayer.Name) then
                                    local xzDist = Vector3.new(hrp.Position.X - gRoot.Position.X, 0, hrp.Position.Z - gRoot.Position.Z).Magnitude
                                    if xzDist < 30 then
                                        -- El guardia está encima: impulso de escape inmediato a la salida
                                        local exit = area:FindFirstChild("ClosestExitPoint")
                                        if exit and exit:IsA("BasePart") then
                                            safeTeleport(exit.Position + Vector3.new(0, 4, 0), 1.8)
                                        else
                                            hrp.CFrame = hrp.CFrame + Vector3.new(0, 24, 0)
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                end

                -- Ajuste adaptativo de velocidad
                if Config.AdaptiveSpeed and not isShiftHeld then
                    if inGuardedZone then
                        if hum.WalkSpeed ~= activeGuardSpeed then
                            hum.WalkSpeed = activeGuardSpeed
                        end
                    else
                        if hum.WalkSpeed > nativeWalkSpeed and not isShiftPressed() then
                            hum.WalkSpeed = nativeWalkSpeed
                        end
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- 10. GESTOR DE VISTA PREVIA 3D (VIEWPORTFRAME)
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

    if not previewModel or #previewModel:GetDescendants() == 0 then
        if previewModel then previewModel:Destroy() end
        previewModel = Instance.new("Model")

        local base = Instance.new("Part", previewModel)
        base.Size = Vector3.new(2.8, 3.4, 2.8)
        base.Shape = Enum.PartType.Ball
        base.Color = itemData.Color or Color3.fromRGB(0, 220, 255)
        base.Material = Enum.Material.SmoothPlastic
        base.Anchored = true
        base.CanCollide = false
        base.CFrame = CFrame.new(0, 0, 0)
    end

    previewModel.Parent = vp
    local cf, sz = previewModel:GetBoundingBox()
    local maxDim = math.max(sz.X, sz.Y, sz.Z, 3)
    local camDist = maxDim * 2.1
    camera.CFrame = CFrame.new(cf.Position + Vector3.new(camDist * 0.7, camDist * 0.5, camDist * 0.9), cf.Position)

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
-- 11. INTERFAZ GRÁFICA MODERNA Y CAMUFLADA (UI)
-- ==============================================================================
local gethuiFunc = (type(gethui) == "function" and gethui)
local parentContainer = (gethuiFunc and gethuiFunc()) or game:GetService("CoreGui") or PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ApexGui_" .. HttpService:GenerateGUID(false):sub(1, 8)
screenGui.ResetOnSpawn = false
screenGui:SetAttribute("ApexEggTrackerGui", true)
pcall(function() screenGui.Parent = parentContainer end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 480, 0, 540)
mainFrame.Position = UDim2.new(0.03, 0, 0.20, 0)
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
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.70, 0, 1, 0)
title.Position = UDim2.new(0.04, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🥚 ROBA UN HUEVO PRO  |  ANTI-GUARD ENGINE"
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

local tabBtnCollect = makeTab("TabCollect", "🥚 Nidos & Huevos", true)
local tabBtnMove = makeTab("TabMove", "⚡ Velocidad & Anti-Guard", false)
local tabBtnZones = makeTab("TabZones", "🗺️ Zonas & Server Hop", false)

local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(0.92, 0, 0.77, 0)
contentArea.Position = UDim2.new(0.04, 0, 0.170, 0)
contentArea.BackgroundTransparency = 1

-- ==============================================================================
-- PÁGINA 1: NIDOS & HUEVOS
-- ==============================================================================
local pageCollect = Instance.new("Frame", contentArea)
pageCollect.Size = UDim2.new(1, 0, 1, 0)
pageCollect.BackgroundTransparency = 1

local topBar = Instance.new("Frame", pageCollect)
topBar.Size = UDim2.new(1, 0, 0, 30)
topBar.BackgroundTransparency = 1

local sortBtn = Instance.new("TextButton", topBar)
sortBtn.Size = UDim2.new(0.48, 0, 1, 0)
sortBtn.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
sortBtn.Text = "Filtro: " .. (Config.SortMode == "Zone" and "Mayor Velocidad ⚡" or (Config.SortMode == "Luck" and "Rareza 💰" or "Distancia 📍"))
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
scrollList.Size = UDim2.new(1, 0, 1, -38)
scrollList.Position = UDim2.new(0, 0, 0, 38)
scrollList.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 4
Instance.new("UICorner", scrollList).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout", scrollList)
listLayout.Padding = UDim.new(0, 6)

-- Menú Contextual
local contextMenu = Instance.new("Frame", screenGui)
contextMenu.Size = UDim2.new(0, 170, 0, 110)
contextMenu.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", contextMenu).Color = Color3.fromRGB(60, 65, 80)

local function makeCtxBtn(txt, color, yPos)
    local btn = Instance.new("TextButton", contextMenu)
    btn.Size = UDim2.new(0.9, 0, 0, 26)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = txt
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local btnCtxSteal = makeCtxBtn("⚡ ROBAR & ESCAPAR", Color3.fromRGB(220, 120, 25), 6)
local btnCtxTP = makeCtxBtn("🚀 Teleport al Nido", Color3.fromRGB(35, 150, 95), 38)
local btnCtxTrack = makeCtxBtn("🎯 Rastrear Faro", Color3.fromRGB(45, 115, 220), 70)

-- ==============================================================================
-- PÁGINA 2: VELOCIDAD & FÍSICAS ANTI-GUARDIA
-- ==============================================================================
local pageMove = Instance.new("Frame", contentArea)
pageMove.Size = UDim2.new(1, 0, 1, 0)
pageMove.BackgroundTransparency = 1
pageMove.Visible = false

local moveScroll = Instance.new("ScrollingFrame", pageMove)
moveScroll.Size = UDim2.new(1, 0, 1, 0)
moveScroll.BackgroundTransparency = 1
moveScroll.BorderSizePixel = 0
moveScroll.ScrollBarThickness = 4

local moveLayout = Instance.new("UIListLayout", moveScroll)
moveLayout.Padding = UDim.new(0, 8)

local function makeToggleRow(txt, initialVal, onToggle, desc)
    local row = Instance.new("Frame", moveScroll)
    row.Size = UDim2.new(1, -6, 0, desc and 48 or 38)
    row.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.72, 0, desc and 0.55 or 1, 0)
    lbl.Position = UDim2.new(0.04, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    if desc then
        local sub = Instance.new("TextLabel", row)
        sub.Size = UDim2.new(0.72, 0, 0.45, 0)
        sub.Position = UDim2.new(0.04, 0, 0.55, 0)
        sub.BackgroundTransparency = 1
        sub.Text = desc
        sub.TextColor3 = Color3.fromRGB(150, 155, 165)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 9
        sub.TextXAlignment = Enum.TextXAlignment.Left
    end

    local toggleBtn = Instance.new("TextButton", row)
    toggleBtn.Size = UDim2.new(0, 52, 0, 26)
    toggleBtn.Position = UDim2.new(0.96, -52, 0.5, -13)
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

makeToggleRow("🛡️ Robo Seguro (Escape en Waking)", Config.WakingEscape, function(v) Config.WakingEscape = v end, "Escapa al punto seguro mientras el guardia se despierta (WalkSpeed=0)")
makeToggleRow("⚡ Velocidad Adaptativa por Zona", Config.AdaptiveSpeed, function(v) Config.AdaptiveSpeed = v end, "Inyecta la velocidad exacta para superar al guardia de la zona (hasta 295 m/s)")
makeToggleRow("👁️ Escudo Anti-Guardia (Auto-Dodge)", Config.AntiGuardShield, function(v) Config.AntiGuardShield = v end, "Auto-teleport si el guardia te persigue a < 30m al portar huevo")
makeToggleRow("🏃 Shift Sprint Manual (48 m/s)", Config.SprintEnabled, function(v) Config.SprintEnabled = v end, "Velocidad segura sin alterar guardias")
makeToggleRow("🦘 Super Salto (JumpPower: 90)", Config.JumpEnabled, function(v) Config.JumpEnabled = v end)
makeToggleRow("🕊️ Salto Infinito", Config.InfJump, function(v) Config.InfJump = v end)
makeToggleRow("👻 Noclip Sigiloso", Config.Noclip, function(v) Config.Noclip = v end)
makeToggleRow("🛡️ Safe Teleport (Anti-Rubberband)", Config.SafeTeleport, function(v) Config.SafeTeleport = v end)
makeToggleRow("📍 Faros Verticales (Sky Beacons)", Config.BeaconsEnabled, function(v) Config.BeaconsEnabled = v end)

-- ==============================================================================
-- PÁGINA 3: TELEPORTS DE ZONAS & SERVER HOP
-- ==============================================================================
local pageZones = Instance.new("Frame", contentArea)
pageZones.Size = UDim2.new(1, 0, 1, 0)
pageZones.BackgroundTransparency = 1
pageZones.Visible = false

local zonesScroll = Instance.new("ScrollingFrame", pageZones)
zonesScroll.Size = UDim2.new(1, 0, 1, 0)
zonesScroll.BackgroundTransparency = 1
zonesScroll.BorderSizePixel = 0
zonesScroll.ScrollBarThickness = 4

local zonesLayout = Instance.new("UIListLayout", zonesScroll)
zonesLayout.Padding = UDim.new(0, 6)

-- Botón Server Hop
local hopBtn = Instance.new("TextButton", zonesScroll)
hopBtn.Size = UDim2.new(1, -6, 0, 36)
hopBtn.BackgroundColor3 = Color3.fromRGB(45, 115, 220)
hopBtn.Text = "🚀 Cambiar de Servidor (Menos Jugadores)"
hopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hopBtn.Font = Enum.Font.GothamBold
hopBtn.TextSize = 11
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 6)

local rejoinBtn = Instance.new("TextButton", zonesScroll)
rejoinBtn.Size = UDim2.new(1, -6, 0, 32)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(35, 150, 95)
rejoinBtn.Text = "🔄 Reconectar al Mismo Servidor"
rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 11
Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)

local sepLbl = Instance.new("TextLabel", zonesScroll)
sepLbl.Size = UDim2.new(1, -6, 0, 20)
sepLbl.BackgroundTransparency = 1
sepLbl.Text = "━━━ TELEPORTS DIRECTOS A ZONAS SEGURAS ━━━"
sepLbl.TextColor3 = Color3.fromRGB(150, 155, 165)
sepLbl.Font = Enum.Font.GothamBold
sepLbl.TextSize = 10

-- Generar botones para cada una de las 14 zonas del juego
for _, zone in ipairs(GAME_ZONES) do
    local zCard = Instance.new("Frame", zonesScroll)
    zCard.Size = UDim2.new(1, -6, 0, 36)
    zCard.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
    Instance.new("UICorner", zCard).CornerRadius = UDim.new(0, 6)

    local zStroke = Instance.new("UIStroke", zCard)
    zStroke.Color = zone.Color
    zStroke.Thickness = 1

    local zNameLbl = Instance.new("TextLabel", zCard)
    zNameLbl.Size = UDim2.new(0.65, 0, 1, 0)
    zNameLbl.Position = UDim2.new(0.04, 0, 0, 0)
    zNameLbl.BackgroundTransparency = 1
    zNameLbl.Text = zone.Name .. "  (⚡ " .. tostring(zone.GuardSpeed) .. " m/s)"
    zNameLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
    zNameLbl.Font = Enum.Font.GothamBold
    zNameLbl.TextSize = 11
    zNameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local zTpBtn = Instance.new("TextButton", zCard)
    zTpBtn.Size = UDim2.new(0, 75, 0, 26)
    zTpBtn.Position = UDim2.new(1, -80, 0.5, -13)
    zTpBtn.BackgroundColor3 = Color3.fromRGB(45, 115, 220)
    zTpBtn.Text = "🚀 Ir Seguro"
    zTpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    zTpBtn.Font = Enum.Font.GothamBold
    zTpBtn.TextSize = 10
    Instance.new("UICorner", zTpBtn).CornerRadius = UDim.new(0, 4)

    zTpBtn.MouseButton1Click:Connect(function()
        local world = Workspace:FindFirstChild("World")
        local areasFolder = world and world:FindFirstChild("Areas") and world.Areas:FindFirstChild("GuardAreas")
        local areaModel = areasFolder and areasFolder:FindFirstChild(zone.Id)
        local exitPart = areaModel and areaModel:FindFirstChild("ClosestExitPoint")

        if exitPart and exitPart:IsA("BasePart") then
            safeTeleport(exitPart.Position + Vector3.new(0, 3, 0))
        elseif areaModel then
            local pos = resolvePosition(areaModel)
            if pos then safeTeleport(pos + Vector3.new(0, 10, 0)) end
        end
    end)
end

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
    pageZones.Visible = (activePage == pageZones)

    for _, b in ipairs({ tabBtnCollect, tabBtnMove, tabBtnZones }) do
        b.BackgroundColor3 = (b == activeBtn) and Color3.fromRGB(45, 115, 220) or Color3.fromRGB(25, 28, 36)
        b.TextColor3 = (b == activeBtn) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 180, 190)
    end
end

tabBtnCollect.MouseButton1Click:Connect(function() switchTab(pageCollect, tabBtnCollect) end)
tabBtnMove.MouseButton1Click:Connect(function() switchTab(pageMove, tabBtnMove) end)
tabBtnZones.MouseButton1Click:Connect(function() switchTab(pageZones, tabBtnZones) end)

-- ==============================================================================
-- 12. REFRESCO DE LISTA DE OBJETIVOS (GUI)
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
        emptyLbl.Text = "🔍 No se encontraron nidos ni huevos activos en el servidor."
        emptyLbl.TextColor3 = Color3.fromRGB(150, 155, 165)
        emptyLbl.Font = Enum.Font.GothamMedium
        emptyLbl.TextSize = 11
        return
    end

    for _, data in ipairs(items) do
        local card = Instance.new("Frame", scrollList)
        card.Size = UDim2.new(1, -6, 0, 60)
        card.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local stroke = Instance.new("UIStroke", card)
        stroke.Thickness = 1.2
        stroke.Color = data.Color or Color3.fromRGB(60, 65, 80)

        local vp = Instance.new("ViewportFrame", card)
        vp.Size = UDim2.new(0, 48, 0, 48)
        vp.Position = UDim2.new(0, 5, 0.5, -24)
        vp.BackgroundTransparency = 1
        setupViewport3D(vp, data)

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(0.55, 0, 0, 18)
        nameLbl.Position = UDim2.new(0, 58, 0, 8)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = data.Name
        nameLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local infoLbl = Instance.new("TextLabel", card)
        infoLbl.Size = UDim2.new(0.55, 0, 0, 16)
        infoLbl.Position = UDim2.new(0, 58, 0, 28)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = string.format("⚡ Guardia: %d m/s  |  📍 %dm  |  %s", data.GuardSpeed or 25, data.Distance or 0, data.Mutation or "")
        infoLbl.TextColor3 = data.Color or Color3.fromRGB(175, 180, 190)
        infoLbl.Font = Enum.Font.GothamMedium
        infoLbl.TextSize = 10
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- BOTÓN 1: ROBAR & ESCAPAR (Bypass total de velocidad)
        local stealBtn = Instance.new("TextButton", card)
        stealBtn.Size = UDim2.new(0, 78, 0, 36)
        stealBtn.Position = UDim2.new(1, -84, 0.5, -18)
        stealBtn.BackgroundColor3 = Color3.fromRGB(220, 120, 25)
        stealBtn.Text = "⚡ ROBAR"
        stealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stealBtn.Font = Enum.Font.GothamBold
        stealBtn.TextSize = 11
        Instance.new("UICorner", stealBtn).CornerRadius = UDim.new(0, 6)

        stealBtn.MouseButton1Click:Connect(function()
            executeStealAndEscape(data)
        end)

        -- Clic en tarjeta abre Menú Contextual
        local clickBtn = Instance.new("TextButton", card)
        clickBtn.Size = UDim2.new(1, -90, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""

        clickBtn.MouseButton1Click:Connect(function()
            selectedItemData = data
            local mPos = UserInputService:GetMouseLocation()
            contextMenu.Position = UDim2.new(0, mPos.X - 10, 0, mPos.Y - 10)
            btnCtxTrack.Text = activeTrackers[data.UUID] and "❌ Quitar Faro" or "🎯 Rastrear Faro"
            contextMenu.Visible = true
        end)
    end
end

-- ==============================================================================
-- 13. CONEXIONES FINALES Y LIMPIEZA
-- ==============================================================================
sortBtn.MouseButton1Click:Connect(function()
    if Config.SortMode == "Zone" then
        Config.SortMode = "Luck"
    elseif Config.SortMode == "Luck" then
        Config.SortMode = "Distance"
    else
        Config.SortMode = "Zone"
    end
    sortBtn.Text = "Filtro: " .. (Config.SortMode == "Zone" and "Mayor Velocidad ⚡" or (Config.SortMode == "Luck" and "Rareza 💰" or "Distancia 📍"))
    saveConfig()
    refreshGUI()
end)

clearAllBtn.MouseButton1Click:Connect(function()
    clearAllTrackers()
    refreshGUI()
end)

btnCtxSteal.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedItemData then
        executeStealAndEscape(selectedItemData)
    end
end)

btnCtxTP.MouseButton1Click:Connect(function()
    contextMenu.Visible = false
    if selectedItemData then
        safeTeleport(selectedItemData.Position + Vector3.new(0, 3, 0))
    end
end)

btnCtxTrack.MouseButton1Click:Connect(function()
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
