-- ==============================================================================
-- CLOVER GOD-TIER SPEEDRUN SUITE V10 (SECURE L3-L5 & TOTAL AUTONOMOUS ENGINE)
-- ==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

-- 1. ADAPTADOR ULTRA-ROBUSTO DE SECURE.LUA
local Secure = rawget(getgenv and getgenv() or _G, "Secure")
local SafeContainer = nil

local function InitializeSafeUI()
    if Secure and Secure.GUI and type(Secure.GUI.CreateSafe) == "function" then
        local rawGui = Secure.GUI:CreateSafe("CloverSpeedrunHub")
        if rawGui:IsA("ScreenGui") then
            SafeContainer = rawGui
        else
            -- Si secure.lua devolvió un Folder (evitando ScreenGui en RobloxGui)
            local innerGui = Instance.new("ScreenGui")
            innerGui.Name = "InnerEngineGui"
            innerGui.ResetOnSpawn = false
            innerGui.DisplayOrder = 2e9
            innerGui.Parent = rawGui
            SafeContainer = innerGui
        end
    else
        local fallbackGui = Instance.new("ScreenGui")
        fallbackGui.Name = "CloverSpeedrunHub_Fallback"
        fallbackGui.ResetOnSpawn = false
        fallbackGui.DisplayOrder = 2e9
        local target = (gethui and gethui()) or (type(cloneref) == "function" and cloneref(game:GetService("CoreGui"))) or game:GetService("CoreGui")
        pcall(function() fallbackGui.Parent = target end)
        if not fallbackGui.Parent and LocalPlayer then
            fallbackGui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        end
        SafeContainer = fallbackGui
    end
end

InitializeSafeUI()

local function SafeSpawn(name, fn, ...)
    local args = {...}
    if Secure and Secure.Thread and type(Secure.Thread.SpawnSafe) == "function" then
        return Secure.Thread:SpawnSafe(name, fn, table.unpack(args))
    else
        return task.spawn(function()
            local ok, err = pcall(fn, table.unpack(args))
            if not ok then warn("[SpeedrunThread][" .. tostring(name) .. "]:", err) end
        end)
    end
end

-- 2. REPOSITORIO DE RED Y DEPENDENCIAS (RESOLUCIÓN DINÁMICA)
local Net = {
    ToolAction = nil,
    RunShop = nil,
    CharmClaim = nil,
    TeleportHome = nil,
    TutorialEvent = nil,
    LobbyActions = nil,
    CreateGame = nil
}

local Modules = {
    Tutorial = nil,
    StatSheet = nil,
    Tools = nil,
    Perks = nil
}

SafeSpawn("NetworkResolver", function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 12)
    if remotes then
        Net.ToolAction = remotes:FindFirstChild("ToolAction")
        Net.RunShop = remotes:FindFirstChild("RunShop")
        Net.CharmClaim = remotes:FindFirstChild("CharmClaim")
        Net.TeleportHome = remotes:FindFirstChild("TeleportHome")
        Net.TutorialEvent = remotes:FindFirstChild("TutorialEvent")
        Net.LobbyActions = remotes:FindFirstChild("LobbyActions")
    end

    local lobby = ReplicatedStorage:FindFirstChild("Lobby")
    if lobby and lobby:FindFirstChild("Remotes") then
        local lr = lobby.Remotes
        Net.CreateGame = lr:FindFirstChild("CreateGame")
        if not Net.LobbyActions then Net.LobbyActions = lr:FindFirstChild("LobbyActions") end
    end

    pcall(function() Modules.Tutorial = require(ReplicatedStorage:WaitForChild("Tutorial", 8)) end)
    pcall(function() Modules.StatSheet = require(ReplicatedStorage:WaitForChild("StatSheet", 8)) end)
    pcall(function() Modules.Tools = require(ReplicatedStorage:WaitForChild("Tools", 8)) end)
    pcall(function() Modules.Perks = require(ReplicatedStorage:FindFirstChild("Perks") or ReplicatedStorage:WaitForChild("Perks", 5)) end)
end)

-- 3. ESTADOS Y PARÁMETROS DE INTELIGENCIA ARTIFICIAL
local AI = {
    Enabled = true,
    Task = "Inicializando...",
    IsBusy = false
}

-- Función universal para disparar ProximityPrompts
local function TriggerPrompt(prompt)
    if not prompt or not prompt.Enabled then return end
    if fireproximityprompt then
        fireproximityprompt(prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.04)
            prompt:InputHoldEnd()
        end)
    end
end

-- Obtener la posición física real de venta (DepositRing / Lucky)
local function GetSellCFrame()
    local ring = workspace:FindFirstChild("DepositRing", true)
    if ring then return ring:GetPivot() end
    local deposit = workspace:FindFirstChild("Deposit")
    if deposit then return deposit.CFrame + Vector3.new(0, 1.2, 0) end
    local lucky = workspace:FindFirstChild("Lucky")
    if lucky then return lucky:GetPivot() + Vector3.new(0, 1.2, 0) end
    return CFrame.new(42.5, 8.2, 169.0)
end

-- 4. OMITIR CINEMÁTICAS INICIALES (FAST-FORWARD)
SafeSpawn("SkipCutsceneRoutine", function()
    while true do
        if AI.Enabled and LocalPlayer:GetAttribute("Cutscene") == true then
            AI.Task = "Omitiendo cinemática..."
            if Net.TutorialEvent and Modules.Tutorial then
                pcall(function()
                    Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_INTRO)
                end)
            end
            task.wait(0.3)
        end
        task.wait(0.4)
    end
end)

-- 5. RESOLUTOR DINÁMICO DE TUTORIAL
local function ProcessTutorialStep()
    local step = tonumber(LocalPlayer:GetAttribute("Tutorial")) or 0
    if step == 0 or step == (Modules.Tutorial and Modules.Tutorial.DONE or 99) then
        return false
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    AI.Task = "Completando Tutorial [" .. tostring(step) .. "]"

    if step == 1 then
        -- Cosecha básica inicial (manejada por el núcleo de corte)
        return false
    elseif step == 2 then
        local scf = GetSellCFrame()
        root.CFrame = CFrame.new(scf.Position.X, scf.Position.Y + 1.2, scf.Position.Z)
        task.wait(0.5)
        return true
    elseif step == 3 then
        if Net.TutorialEvent and Modules.Tutorial then
            Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_BOOK_ANY, 3, "desktop")
            Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_BOOK)
        end
        task.wait(0.4)
        return true
    elseif step == 4 then
        if Net.RunShop then
            pcall(function() Net.RunShop:InvokeServer("buyBag") end)
            pcall(function() Net.RunShop:InvokeServer("buyUpgrade", "bag", "size") end)
        end
        task.wait(0.4)
        return true
    elseif step == 5 then
        local barn = workspace:FindFirstChild("SM_Bld_Barn_01")
        local stalls = barn and barn:FindFirstChild("ToolStalls")
        local rakeStall = stalls and stalls:FindFirstChild("Stall_rake")
        if rakeStall then
            root.CFrame = CFrame.new(rakeStall.Position + Vector3.new(0, 1.5, 0))
            task.wait(0.2)
            if Net.TutorialEvent and Modules.Tutorial then
                Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_SHED)
            end
        end
        task.wait(0.4)
        return true
    elseif step == 6 then
        if Net.TutorialEvent and Modules.Tutorial then
            Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_TOOLS)
            Net.TutorialEvent:FireServer(Modules.Tutorial.REPORT_DONE)
        end
        task.wait(0.5)
        return true
    end

    return false
end

-- 6. ENTREGA FINAL Y VICTORIA (4-LEAF VICTORY ROUTINE)
local function CheckFourLeafVictory()
    if LocalPlayer:GetAttribute("HasFour") ~= true then return false end

    AI.Task = "🍀 ¡4 HOJAS ENCONTRADO! ENTREGANDO A FINNEGAN..."
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return true end

    local field = workspace:FindFirstChild("Field")
    local finnegan = field and field:FindFirstChild("Finnegan", true)
    if finnegan then
        local returnPrompt = finnegan:FindFirstChild("ReturnPrompt", true)
        local finnPos = finnegan:GetPivot().Position

        root.CFrame = CFrame.new(finnPos + Vector3.new(0, 1.5, 3.2))
        task.wait(0.08)

        if returnPrompt and returnPrompt.Enabled then
            TriggerPrompt(returnPrompt)
            task.wait(0.4)
        end
    end

    return true
end

-- 7. CONSULTA DINÁMICA DE ESTADÍSTICAS DEL MOTOR
local function GetSnapshot()
    local profile = nil
    if Modules.StatSheet then
        pcall(function() profile = Modules.StatSheet.get(LocalPlayer) end)
    end

    local coins = tonumber(LocalPlayer:GetAttribute("Coins")) or 0
    local luck = tonumber(LocalPlayer:GetAttribute("Luck")) or 0
    local carried = tonumber(LocalPlayer:GetAttribute("Carried")) or 0
    local toolName = tostring(LocalPlayer:GetAttribute("Tool") or "hand")

    local maxBag = 15
    local bagPrice = nil
    if profile and profile.bag then
        maxBag = tonumber(profile.bag.now) or maxBag
        bagPrice = tonumber(profile.bag.price)
    end

    local interval = 0.35
    if profile and profile.tools and profile.tools[toolName] and profile.tools[toolName].stats then
        interval = profile.tools[toolName].stats.interval or interval
    end

    return {
        Coins = coins,
        Luck = luck,
        Carried = carried,
        BagMax = maxBag,
        BagPrice = bagPrice,
        BagPercent = (maxBag > 0) and (carried / maxBag) or 0,
        Tool = toolName,
        Interval = interval,
        Raw = profile
    }
end

-- 8. MATRIZ DE DECISIONES DE COMPRA Y OPTIMIZACIÓN
local function RunSmartEconomy()
    local snap = GetSnapshot()
    local runShop = Net.RunShop
    if not runShop then return end

    -- A. Ventajas permanentes con Tréboles de la Suerte (Perks)
    if snap.Luck > 0 and Net.LobbyActions and Modules.Perks and snap.Raw and snap.Raw.perks then
        for _, perkKey in ipairs(Modules.Perks.ORDER or {}) do
            local pData = snap.Raw.perks[perkKey]
            if pData and pData.price and pData.price <= snap.Luck and pData.level < (pData.max or 99) then
                pcall(function() Net.LobbyActions:InvokeServer("buyPerk", perkKey) end)
                break
            end
        end
    end

    -- B. Mejora de Capacidad de Mochila
    if snap.BagPrice and snap.Coins >= snap.BagPrice then
        pcall(function()
            runShop:InvokeServer("buyUpgrade", "bag", "size")
            runShop:InvokeServer("buyBag")
        end)
    end

    -- C. Adquisición y equipamiento de herramientas por jerarquía
    local toolProgression = { "rake", "scythe", "vacuum", "flamethrower" }
    for _, tKey in ipairs(toolProgression) do
        local tData = snap.Raw and snap.Raw.tools and snap.Raw.tools[tKey]
        if tData and tData.owned ~= true and tData.price and snap.Coins >= tData.price then
            pcall(function()
                local ok = runShop:InvokeServer("buyTool", tKey)
                if ok then runShop:InvokeServer("equip", tKey) end
            end)
            break
        elseif tData and tData.owned == true and snap.Tool ~= tKey then
            pcall(function() runShop:InvokeServer("equip", tKey) end)
        end
    end

    -- D. Sub-mejoras de Grasp y Velocidad de la herramienta activa
    if snap.Raw and snap.Raw.tools and snap.Raw.tools[snap.Tool] then
        local upgrades = snap.Raw.tools[snap.Tool].upgrades
        if upgrades then
            for _, uKey in ipairs({ "grasp", "speed", "reach", "cooling" }) do
                local uData = upgrades[uKey]
                if uData and uData.price and snap.Coins >= uData.price and uData.level < (uData.max or 99) then
                    pcall(function() runShop:InvokeServer("buyUpgrade", snap.Tool, uKey) end)
                    break
                end
            end
        end
    end
end

-- 9. COSECHA PREDICTIVA Y BÚSQUEDA DE TRÉBOL DE 4 HOJAS
local function ExecuteHarvesting()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or LocalPlayer:GetAttribute("HeatLocked") == true then return end

    local cloverParts = workspace:FindFirstChild("CloverParts")
    if not cloverParts or not Net.ToolAction then return end

    local bestTarget = nil
    local bestScore = -1
    local myPos = root.Position

    -- Escaneo de objetivos en tiempo real
    for _, part in ipairs(cloverParts:GetChildren()) do
        if part:IsA("MeshPart") and not part.Name:find("Patch_") then
            local isFour = (part.Name:find("4") or (part.MeshId ~= "" and part.MeshId ~= "rbxassetid://118437862060608"))
            local isRare = (part.BrickColor.Name == "Toothpaste" or part.BrickColor.Name == "Bright yellow")
            local dist = (part.Position - myPos).Magnitude

            local score = 0
            if isFour then
                score = 10000000 -- Prioridad inmediata de victoria
            elseif isRare then
                score = 5000 / (dist + 1)
            else
                score = 100 / (dist + 1)
            end

            if score > bestScore then
                bestScore = score
                bestTarget = part
                if isFour then break end
            end
        end
    end

    if bestTarget then
        AI.Task = "Cortando " .. bestTarget.Name
        
        -- Bypass de reach: reposicionamiento a 2 studs
        root.CFrame = CFrame.new(bestTarget.Position.X, bestTarget.Position.Y + 2.0, bestTarget.Position.Z)
        task.wait(0.02)

        local camLook = CurrentCamera.CFrame.LookVector
        local aimDir = Vector3.new(camLook.X, 0, camLook.Z)
        if aimDir.Magnitude < 0.001 then aimDir = Vector3.new(0, 0, -1) end

        Net.ToolAction:FireServer(bestTarget.Position, aimDir)
    end
end

-- 10. RECLAMO DE AMULETOS Y RECOMPENSAS
local function ProcessDrops()
    local charms = workspace:FindFirstChild("Charms")
    if charms and Net.CharmClaim then
        for _, charm in ipairs(charms:GetChildren()) do
            local prompt = charm:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                TriggerPrompt(prompt)
            end
        end
    end

    if LocalPlayer:GetAttribute("LikeRewardClaimed") ~= true then
        local likeObj = workspace:FindFirstChild("Like Reward")
        local prompt = likeObj and likeObj:FindFirstChild("ClaimPrompt", true)
        if prompt and prompt.Enabled then
            TriggerPrompt(prompt)
        end
    end
end

-- 11. BUCLE MAESTRO INTELIGENTE
SafeSpawn("MasterSpeedrunLoop", function()
    while true do
        if AI.Enabled then
            local inRun = LocalPlayer:GetAttribute("InRun") == true

            if not inRun then
                AI.Task = "En Lobby. Iniciando partida..."
                if Net.CreateGame then
                    pcall(function() Net.CreateGame:FireServer("meadow", 1, 1) end)
                end
                task.wait(1)
            else
                -- 1. Victoria por 4 Hojas
                local won = CheckFourLeafVictory()

                if not won then
                    -- 2. Progreso de Tutorial
                    local onTutorial = ProcessTutorialStep()

                    if not onTutorial then
                        local snap = GetSnapshot()

                        -- 3. Vender si la mochila está llena
                        if snap.BagPercent >= 1.0 then
                            AI.Task = "Vaciando bolsa en Deposit..."
                            local char = LocalPlayer.Character
                            local root = char and char:FindFirstChild("HumanoidRootPart")
                            if root then
                                local scf = GetSellCFrame()
                                root.CFrame = CFrame.new(scf.Position.X, scf.Position.Y + 1.2, scf.Position.Z)
                                local t0 = os.clock()
                                while os.clock() - t0 < 1.3 do
                                    if (tonumber(LocalPlayer:GetAttribute("Carried")) or 0) == 0 then break end
                                    task.wait(0.08)
                                end
                            end
                        else
                            -- 4. Inversión inteligente y recolección
                            RunSmartEconomy()
                            ProcessDrops()
                            ExecuteHarvesting()
                        end
                    end
                end
            end
        end

        local snap = GetSnapshot()
        local waitCadence = math.clamp(snap.Interval * 0.85, 0.12, 0.4)
        task.wait(waitCadence)
    end
end)

-- 12. INTERFAZ GRÁFICA DE CONTROL Y TELEMETRÍA
if SafeContainer then
    local Panel = Instance.new("Frame")
    Panel.Name = "SpeedrunHUD"
    Panel.Size = UDim2.new(0, 270, 0, 160)
    Panel.Position = UDim2.new(0.02, 0, 0.32, 0)
    Panel.BackgroundColor3 = Color3.fromRGB(16, 18, 25)
    Panel.BorderSizePixel = 0
    Panel.Active = true
    Panel.Draggable = true
    Panel.Parent = SafeContainer

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Panel

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(48, 56, 75)
    UIStroke.Thickness = 1.2
    UIStroke.Parent = Panel

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 24)
    Title.Position = UDim2.new(0, 10, 0, 6)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "⚡ Clover Autonomous AI V10"
    Title.TextColor3 = Color3.fromRGB(240, 240, 245)
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Panel

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 42)
    Status.Position = UDim2.new(0, 10, 0, 30)
    Status.BackgroundTransparency = 1
    Status.Font = Enum.Font.Code
    Status.Text = "Cargando telemetría..."
    Status.TextColor3 = Color3.fromRGB(140, 220, 150)
    Status.TextSize = 10
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.TextYAlignment = Enum.TextYAlignment.Top
    Status.Parent = Panel

    local MainToggle = Instance.new("TextButton")
    MainToggle.Size = UDim2.new(1, -20, 0, 30)
    MainToggle.Position = UDim2.new(0, 10, 0, 78)
    MainToggle.BackgroundColor3 = Color3.fromRGB(40, 130, 75)
    MainToggle.Font = Enum.Font.GothamBold
    MainToggle.Text = "IA SPEEDRUN: ACTIVA"
    MainToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainToggle.TextSize = 11
    MainToggle.Parent = Panel

    local BTC = Instance.new("UICorner")
    BTC.CornerRadius = UDim.new(0, 6)
    BTC.Parent = MainToggle

    MainToggle.MouseButton1Click:Connect(function()
        AI.Enabled = not AI.Enabled
        MainToggle.BackgroundColor3 = AI.Enabled and Color3.fromRGB(40, 130, 75) or Color3.fromRGB(35, 40, 50)
        MainToggle.Text = AI.Enabled and "IA SPEEDRUN: ACTIVA" or "IA SPEEDRUN: PAUSADA"
    end)

    local FinneganBtn = Instance.new("TextButton")
    FinneganBtn.Size = UDim2.new(1, -20, 0, 26)
    FinneganBtn.Position = UDim2.new(0, 10, 0, 118)
    FinneganBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 68)
    FinneganBtn.Font = Enum.Font.GothamMedium
    FinneganBtn.Text = "🍀 Forzar Entrega a Finnegan"
    FinneganBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
    FinneganBtn.TextSize = 10
    FinneganBtn.Parent = Panel

    local FBC = Instance.new("UICorner")
    FBC.CornerRadius = UDim.new(0, 5)
    FBC.Parent = FinneganBtn

    FinneganBtn.MouseButton1Click:Connect(function()
        CheckFourLeafVictory()
    end)

    -- Sincronización continua de la telemetría en pantalla
    RunService.RenderStepped:Connect(function()
        local snap = GetSnapshot()
        Status.Text = string.format(
            "Acción: %s\nBolsa: %d/%d (%.0f%%) | $: %d | Suerte: %d\nHerramienta: %s (Cad: %.2fs)",
            AI.Task,
            snap.Carried, snap.BagMax, snap.BagPercent * 100, snap.Coins, snap.Luck,
            snap.Tool:upper(), snap.Interval
        )
    end)
end