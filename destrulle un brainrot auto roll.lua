local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local randomSeed = math.random(1000000, 9999999)
local SPOOFED_GUI_NAME = "SmartRollerUltimate_" .. tostring(randomSeed)

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

----------------------------------------------------------------------
-- REMOTES Y DATOS EXTRAÍDOS DEL JUEGO
----------------------------------------------------------------------
local Network = ReplicatedStorage:WaitForChild("Network"):WaitForChild("RemoteEvents")
local TraitAction = Network:WaitForChild("TraitAction")
local TraitRolled = Network:WaitForChild("TraitRolled")
local RNGMachineRoll = Network:WaitForChild("RNGMachineRoll")
local RNGUpgradeBuy = Network:FindFirstChild("RNGUpgradeBuy")
local InventoryRemote = Network:FindFirstChild("Inventory")

local TraitData = {
    Admin = 5.0, Nuclear = 4.25, Candy = 3.75, Summer = 3.5,
    WorldCup = 3.5, Glitch = 3.25, Taco = 3.0, Haunted = 3.0,
    CrabRave = 3.0, Firework = 3.0, Lightning = 2.75, Meteor = 2.5,
    Stars = 2.5, Aurora = 2.5, Disco = 2.0, Shark = 2.0,
    Ufo = 1.75, Fire = 1.75, Blackhole = 1.5, Bloodmoon = 1.25, Hacker = 1.25
}

local MutationMultipliers = {
    Ghost = "x4.0", Rainbow = "x3.5", Lava = "x3.0",
    Galaxy = "x2.5", Diamond = "x2.0", Gold = "x1.5"
}

local ItemsConfig = {}
pcall(function()
    ItemsConfig = require(ReplicatedStorage.Configurations.Modules.ItemsConfigurations)
end)

----------------------------------------------------------------------
-- CONFIGURACIÓN DEL USUARIO
----------------------------------------------------------------------
local Config = {
    -- Rasgos
    TraitActive = false,
    TraitDelay = 0.12,
    SelectedTraits = { Admin = true, Nuclear = true },
    MinTraitsRequired = 1,      -- Mínimo de ranuras necesarias (1 a 4)
    CheckMultiplier = true,     -- Validar multiplicador total
    TargetMultiplier = 4.0,     -- Multiplicador mínimo requerido (>= x4.0)
    StopConditionMode = "OR",   -- "OR" = Rasgo O Multiplicador | "AND" = Rasgo Y Multiplicador

    -- RNG
    RngActive = false,
    SelectedAreas = { Immortal = true, Admin = true, Eternal = true },
    SelectedMutations = { Rainbow = true, Ghost = true },
    
    -- Auto-Compra Granular (Solo lo que marques aquí se comprará)
    AutoBuyActive = false,
    BuyOnlySelected = {
        Luck = false,
        RollSpeed = true,       -- Por defecto solo velocidad para acelerar la máquina
        Mutation = false
    },
    
    -- Aceleración de Giro
    TurboAnimation = true,
    AutoAlign = false,
    SimulateKeyE = true,
    SimulateClick = true
}

local Stats = {
    TraitRolls = 0,
    RngRolls = 0,
    LastTraitsList = {},
    LastTotalMult = 1.0,
    LastItem = "Ninguno",
    LastMutation = "Ninguno"
}

----------------------------------------------------------------------
-- ACELERADOR DE ANIMACIONES REAL (HOOK DE TWEENSERVICE)
----------------------------------------------------------------------
-- Si la máquina o la interfaz giran usando TweenService, forzamos la duración a 0.01s
pcall(function()
    if type(hookfunction) == "function" then
        local oldTweenCreate
        oldTweenCreate = hookfunction(TweenService.Create, function(self, inst, info, props)
            if Config.RngActive and Config.TurboAnimation and inst then
                local name = inst.Name:lower()
                local parentName = inst.Parent and inst.Parent.Name:lower() or ""
                if name:find("roll") or name:find("spin") or name:find("wheel") or parentName:find("roller") or parentName:find("rng") then
                    local instantInfo = TweenInfo.new(0.01, Enum.EasingStyle.Linear)
                    return oldTweenCreate(self, inst, instantInfo, props)
                end
            end
            return oldTweenCreate(self, inst, info, props)
        end)
    end
end)

----------------------------------------------------------------------
-- INTERACCIÓN FÍSICA LIMPIA (SIN CLICKS EN FALSO)
----------------------------------------------------------------------
local cachedPrompt = nil
local cachedClick = nil

local function findRngMachine(): Instance?
    local toggles = Workspace:FindFirstChild("Toggles")
    if toggles then
        local found = toggles:FindFirstChild("RNGupgrades") or toggles:FindFirstChild("RNG") or toggles:FindFirstChild("RNGMachine")
        if found then return found end
    end
    for _, inst in ipairs(Workspace:GetChildren()) do
        local lower = inst.Name:lower()
        if (lower:find("rng") or lower:find("mutat") or lower:find("craft")) and (inst:IsA("Model") or inst:IsA("BasePart")) then
            return inst
        end
    end
    return nil
end

local function prepareMachineInteractions()
    if cachedPrompt and cachedPrompt.Parent then return end
    local machine = findRngMachine()
    if machine then
        for _, desc in ipairs(machine:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                cachedPrompt = desc
                desc.HoldDuration = 0 -- Elimina el tiempo de espera al mantener pulsado
            elseif desc:IsA("ClickDetector") then
                cachedClick = desc
            end
        end
    end
end

-- Ejecuta una interacción limpia en lugar de spamear cientos de clics inútiles
local function performSingleRngAction()
    prepareMachineInteractions()

    if Config.AutoAlign then
        local machine = findRngMachine()
        local char = LocalPlayer.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if machine and root then
            local tPos = machine:IsA("Model") and (machine.PrimaryPart and machine.PrimaryPart.CFrame or machine:FindFirstChildWhichIsA("BasePart").CFrame) or machine.CFrame
            if (root.Position - tPos.Position).Magnitude > 12 then
                root.CFrame = tPos + Vector3.new(0, 3, 4)
            end
        end
    end

    if cachedPrompt and cachedPrompt.Parent then
        cachedPrompt.HoldDuration = 0
        if typeof(fireproximityprompt) == "function" then
            pcall(function() fireproximityprompt(cachedPrompt, 0) end)
        end
    end

    if cachedClick and cachedClick.Parent and Config.SimulateClick then
        if typeof(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(cachedClick) end)
        end
    end

    if Config.SimulateKeyE then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end

    pcall(function() RNGMachineRoll:FireServer() end)
    pcall(function() RNGMachineRoll:FireServer("roll") end)
end

----------------------------------------------------------------------
-- HILO CONTROLADO: AUTO-COMPRA SÓLO DE LO MARCADO
----------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1.2)
        if Config.RngActive and Config.AutoBuyActive and RNGUpgradeBuy then
            if Config.BuyOnlySelected.Luck then
                pcall(function() RNGUpgradeBuy:FireServer("Luck") end)
            end
            if Config.BuyOnlySelected.RollSpeed then
                pcall(function() RNGUpgradeBuy:FireServer("RollSpeed") end)
            end
            if Config.BuyOnlySelected.Mutation then
                pcall(function() RNGUpgradeBuy:FireServer("Mutation") end)
            end
        end
    end
end)

----------------------------------------------------------------------
-- LÓGICA DE DETECCIÓN Y PARADA DE RASGOS
----------------------------------------------------------------------
local traitTask = nil
local rngTask = nil
local rngRollCompleted = true

local function parseRolledTraits(data): {string}
    local traits = {}
    if typeof(data) == "table" then
        if data.Traits and typeof(data.Traits) == "table" then
            for _, tr in ipairs(data.Traits) do
                if TraitData[tr] then table.insert(traits, tr) end
            end
        else
            for _, v in pairs(data) do
                if typeof(v) == "string" and TraitData[v] then
                    table.insert(traits, v)
                end
            end
        end
    elseif typeof(data) == "string" then
        for tr in string.gmatch(data, "([^,]+)") do
            local clean = tr:match("^%s*(.-)%s*$")
            if clean ~= "" and TraitData[clean] then
                table.insert(traits, clean)
            end
        end
    end
    return traits
end

TraitRolled.OnClientEvent:Connect(function(data)
    Stats.TraitRolls = Stats.TraitRolls + 1
    local rolledList = parseRolledTraits(data)
    local totalMult = 1.0
    for _, name in ipairs(rolledList) do
        totalMult = totalMult * (TraitData[name] or 1.0)
    end

    Stats.LastTraitsList = rolledList
    Stats.LastTotalMult = totalMult

    -- 1. Condición de Mínimo: Ignora resultados con menos ranuras de las solicitadas
    if #rolledList < Config.MinTraitsRequired then
        return
    end

    -- 2. Detección de rasgo objetivo
    local hasDesiredTrait = false
    local matchedTrait = ""
    for _, name in ipairs(rolledList) do
        if Config.SelectedTraits[name] then
            hasDesiredTrait = true
            matchedTrait = name
            break
        end
    end

    -- 3. Detección de multiplicador acumulado
    local hasDesiredMult = Config.CheckMultiplier and (totalMult >= Config.TargetMultiplier)
    local shouldStop = false
    local reason = ""
    local hasSelectedTraits = next(Config.SelectedTraits) ~= nil

    if Config.StopConditionMode == "OR" then
        if hasDesiredTrait then
            shouldStop = true
            reason = string.format("Rasgo: %s (%d ranuras)", matchedTrait, #rolledList)
        elseif hasDesiredMult then
            shouldStop = true
            reason = string.format("Multiplicador: x%.2f >= x%.2f (%d ranuras)", totalMult, Config.TargetMultiplier, #rolledList)
        end
    else
        local tOk = (not hasSelectedTraits) or hasDesiredTrait
        local mOk = (not Config.CheckMultiplier) or hasDesiredMult
        if tOk and mOk then
            shouldStop = true
            reason = string.format("Estricto cumplido: x%.2f con %s (%d ranuras)", totalMult, matchedTrait, #rolledList)
        end
    end

    if shouldStop then
        Config.TraitActive = false
        warn("★ [MÁQUINA DE RASGOS] ¡OBJETIVO CONSEGUIDO!: " .. reason)
    end
end)

local function startTraitLoop()
    if traitTask then return end
    Config.TraitActive = true
    
    -- Si existe el botón "Fast Roll" oficial en la interfaz, lo pulsamos
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local frBtn = pGui and pGui.Gui.Frames.TraitMachine:FindFirstChild("Fast Roll")
        if frBtn and typeof(firesignal) == "function" then
            firesignal(frBtn.MouseButton1Click)
        end
    end)

    traitTask = task.spawn(function()
        while Config.TraitActive do
            TraitAction:FireServer("roll")
            task.wait(Config.TraitDelay)
        end
        traitTask = nil
    end)
end

local function stopTraitLoop()
    Config.TraitActive = false
    if traitTask then
        task.cancel(traitTask)
        traitTask = nil
    end
end

----------------------------------------------------------------------
-- LÓGICA DE DETECCIÓN Y PARADA DE RNG (REACTIVA Y RÁPIDA)
----------------------------------------------------------------------
local function evaluateRngItem(itemName: string, mutation: string)
    rngRollCompleted = true
    Stats.RngRolls = Stats.RngRolls + 1
    Stats.LastItem = itemName
    Stats.LastMutation = mutation

    local area = "Desconocido"
    if ItemsConfig[itemName] and ItemsConfig[itemName].Area then
        area = ItemsConfig[itemName].Area
    end

    local matchArea = Config.SelectedAreas[area] == true
    local matchMutation = (mutation ~= "Normal") and (Config.SelectedMutations[mutation] == true)

    if matchArea or matchMutation then
        Config.RngActive = false
        warn(string.format("★ [MÁQUINA RNG] ¡OBJETIVO ENCONTRADO!: %s | Área: [%s] | Mutación: [%s]", itemName, area, mutation))
    end
end

RNGMachineRoll.OnClientEvent:Connect(function(data)
    if not Config.RngActive then return end
    if typeof(data) == "table" then
        local name = data.Name or data.Item or data[1]
        local mut = data.Mutation or "Normal"
        if name then evaluateRngItem(tostring(name), tostring(mut)) end
    elseif typeof(data) == "string" then
        evaluateRngItem(data, "Normal")
    end
end)

if InventoryRemote then
    InventoryRemote.OnClientEvent:Connect(function(inv)
        if not Config.RngActive or typeof(inv) ~= "table" or #inv == 0 then return end
        local newest = inv[#inv]
        if newest and newest.Name then
            evaluateRngItem(tostring(newest.Name), tostring(newest.Mutation or "Normal"))
        end
    end)
end

local function startRngLoop()
    if rngTask then return end
    Config.RngActive = true
    rngRollCompleted = true

    rngTask = task.spawn(function()
        while Config.RngActive do
            rngRollCompleted = false
            performSingleRngAction()

            -- Espera reactiva: pasa al siguiente giro tan pronto como el servidor responde
            local startWait = os.clock()
            while not rngRollCompleted and Config.RngActive do
                task.wait(0.02)
                if os.clock() - startWait > 0.35 then -- Timeout de seguridad
                    break
                end
            end
        end
        rngTask = nil
    end)
end

local function stopRngLoop()
    Config.RngActive = false
    if rngTask then
        task.cancel(rngTask)
        rngTask = nil
    end
end

----------------------------------------------------------------------
-- INTERFAZ GRÁFICA DE USUARIO
----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = SPOOFED_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = secureParent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 440, 0, 590)
main.Position = UDim2.new(0.5, -220, 0.45, -295)
main.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ Ultra Auto-Roller Suite (Fixed Speed & Granular)"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
    stopTraitLoop()
    stopRngLoop()
    screenGui:Destroy()
end)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 26, 0, 26)
minBtn.Position = UDim2.new(1, -62, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -50)
body.Position = UDim2.new(0, 8, 0, 44)
body.BackgroundTransparency = 1
body.Parent = main

local isMin = false
minBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    body.Visible = not isMin
    main.Size = isMin and UDim2.new(0, 440, 0, 38) or UDim2.new(0, 440, 0, 590)
end)

local tabTraitsBtn = Instance.new("TextButton")
tabTraitsBtn.Size = UDim2.new(0.5, -4, 0, 28)
tabTraitsBtn.Position = UDim2.new(0, 0, 0, 0)
tabTraitsBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 110)
tabTraitsBtn.Text = "🎭 Máquina de Rasgos"
tabTraitsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tabTraitsBtn.Font = Enum.Font.GothamBold
tabTraitsBtn.TextSize = 12
tabTraitsBtn.Parent = body
Instance.new("UICorner", tabTraitsBtn).CornerRadius = UDim.new(0, 6)

local tabRngBtn = Instance.new("TextButton")
tabRngBtn.Size = UDim2.new(0.5, -4, 0, 28)
tabRngBtn.Position = UDim2.new(0.5, 4, 0, 0)
tabRngBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
tabRngBtn.Text = "🎲 Máquina RNG"
tabRngBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
tabRngBtn.Font = Enum.Font.GothamBold
tabRngBtn.TextSize = 12
tabRngBtn.Parent = body
Instance.new("UICorner", tabRngBtn).CornerRadius = UDim.new(0, 6)

local traitsFrame = Instance.new("Frame")
traitsFrame.Size = UDim2.new(1, 0, 1, -34)
traitsFrame.Position = UDim2.new(0, 0, 0, 34)
traitsFrame.BackgroundTransparency = 1
traitsFrame.Parent = body

local rngFrame = Instance.new("Frame")
rngFrame.Size = UDim2.new(1, 0, 1, -34)
rngFrame.Position = UDim2.new(0, 0, 0, 34)
rngFrame.BackgroundTransparency = 1
rngFrame.Visible = false
rngFrame.Parent = body

tabTraitsBtn.MouseButton1Click:Connect(function()
    tabTraitsBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 110)
    tabTraitsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabRngBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
    tabRngBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
    traitsFrame.Visible = true
    rngFrame.Visible = false
end)

tabRngBtn.MouseButton1Click:Connect(function()
    tabRngBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 110)
    tabRngBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabTraitsBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
    tabTraitsBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
    rngFrame.Visible = true
    traitsFrame.Visible = false
end)

----------------------------------------------------------------------
-- PESTAÑA RASGOS
----------------------------------------------------------------------
local minTraitContainer = Instance.new("Frame")
minTraitContainer.Size = UDim2.new(1, 0, 0, 32)
minTraitContainer.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
minTraitContainer.Parent = traitsFrame
Instance.new("UICorner", minTraitContainer).CornerRadius = UDim.new(0, 6)

local minLabel = Instance.new("TextLabel")
minLabel.Size = UDim2.new(0.48, 0, 1, 0)
minLabel.Position = UDim2.new(0, 8, 0, 0)
minLabel.BackgroundTransparency = 1
minLabel.Text = "Mínimo de Ranuras:"
minLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
minLabel.Font = Enum.Font.SourceSansBold
minLabel.TextSize = 12
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Parent = minTraitContainer

local minBtns = {}
for i = 1, 4 do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.11, 0, 0, 22)
    b.Position = UDim2.new(0.48 + (i - 1) * 0.125, 0, 0, 5)
    b.BackgroundColor3 = (Config.MinTraitsRequired == i) and Color3.fromRGB(0, 160, 120) or Color3.fromRGB(35, 38, 50)
    b.Text = tostring(i)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.Parent = minTraitContainer
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    minBtns[i] = b

    b.MouseButton1Click:Connect(function()
        Config.MinTraitsRequired = i
        for k = 1, 4 do
            minBtns[k].BackgroundColor3 = (Config.MinTraitsRequired == k) and Color3.fromRGB(0, 160, 120) or Color3.fromRGB(35, 38, 50)
        end
    end)
end

local multContainer = Instance.new("Frame")
multContainer.Size = UDim2.new(1, 0, 0, 32)
multContainer.Position = UDim2.new(0, 0, 0, 36)
multContainer.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
multContainer.Parent = traitsFrame
Instance.new("UICorner", multContainer).CornerRadius = UDim.new(0, 6)

local multToggle = Instance.new("TextButton")
multToggle.Size = UDim2.new(0.36, -4, 0, 24)
multToggle.Position = UDim2.new(0, 4, 0, 4)
multToggle.BackgroundColor3 = Config.CheckMultiplier and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 50, 65)
multToggle.Text = "Multiplicador: " .. (Config.CheckMultiplier and "ON" or "OFF")
multToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
multToggle.Font = Enum.Font.SourceSansBold
multToggle.TextSize = 11
multToggle.Parent = multContainer
Instance.new("UICorner", multToggle).CornerRadius = UDim.new(0, 4)

local multInput = Instance.new("TextBox")
multInput.Size = UDim2.new(0.28, -4, 0, 24)
multInput.Position = UDim2.new(0.36, 4, 0, 4)
multInput.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
multInput.TextColor3 = Color3.fromRGB(255, 220, 80)
multInput.Text = ">= x" .. tostring(Config.TargetMultiplier)
multInput.Font = Enum.Font.SourceSansBold
multInput.TextSize = 12
multInput.Parent = multContainer
Instance.new("UICorner", multInput).CornerRadius = UDim.new(0, 4)

local modeLogicBtn = Instance.new("TextButton")
modeLogicBtn.Size = UDim2.new(0.36, -4, 0, 24)
modeLogicBtn.Position = UDim2.new(0.64, 4, 0, 4)
modeLogicBtn.BackgroundColor3 = Color3.fromRGB(50, 65, 95)
modeLogicBtn.Text = "Modo: " .. (Config.StopConditionMode == "OR" and "Rasgo O Mult" or "Rasgo Y Mult")
modeLogicBtn.TextColor3 = Color3.fromRGB(220, 230, 255)
modeLogicBtn.Font = Enum.Font.SourceSansBold
modeLogicBtn.TextSize = 11
modeLogicBtn.Parent = multContainer
Instance.new("UICorner", modeLogicBtn).CornerRadius = UDim.new(0, 4)

multToggle.MouseButton1Click:Connect(function()
    Config.CheckMultiplier = not Config.CheckMultiplier
    multToggle.BackgroundColor3 = Config.CheckMultiplier and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 50, 65)
    multToggle.Text = "Multiplicador: " .. (Config.CheckMultiplier and "ON" or "OFF")
end)

multInput.FocusLost:Connect(function()
    local val = tonumber(multInput.Text:match("%d+%.?%d*"))
    if val and val > 0 then
        Config.TargetMultiplier = val
        multInput.Text = ">= x" .. val
    else
        multInput.Text = ">= x" .. Config.TargetMultiplier
    end
end)

modeLogicBtn.MouseButton1Click:Connect(function()
    Config.StopConditionMode = (Config.StopConditionMode == "OR") and "AND" or "OR"
    modeLogicBtn.Text = "Modo: " .. (Config.StopConditionMode == "OR" and "Rasgo O Mult" or "Rasgo Y Mult")
end)

local traitScroll = Instance.new("ScrollingFrame")
traitScroll.Size = UDim2.new(1, 0, 0, 250)
traitScroll.Position = UDim2.new(0, 0, 0, 72)
traitScroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
traitScroll.BorderSizePixel = 0
traitScroll.ScrollBarThickness = 5
traitScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
traitScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
traitScroll.Parent = traitsFrame
Instance.new("UICorner", traitScroll).CornerRadius = UDim.new(0, 6)

local traitGrid = Instance.new("UIGridLayout")
traitGrid.CellSize = UDim2.new(0.48, 0, 0, 26)
traitGrid.CellPadding = UDim2.new(0.02, 0, 0, 4)
traitGrid.Parent = traitScroll

for name, mult in pairs(TraitData) do
    local isSel = Config.SelectedTraits[name] == true
    local chip = Instance.new("TextButton")
    chip.BackgroundColor3 = isSel and Color3.fromRGB(35, 100, 70) or Color3.fromRGB(24, 27, 36)
    chip.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)
    chip.Font = Enum.Font.SourceSansBold
    chip.TextSize = 11
    chip.Text = string.format("%s [x%.2f]", name, mult)
    chip.Parent = traitScroll
    Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 4)

    chip.MouseButton1Click:Connect(function()
        if Config.SelectedTraits[name] then
            Config.SelectedTraits[name] = nil
            chip.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
            chip.TextColor3 = Color3.fromRGB(180, 185, 200)
        else
            Config.SelectedTraits[name] = true
            chip.BackgroundColor3 = Color3.fromRGB(35, 100, 70)
            chip.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end

local traitStatus = Instance.new("TextLabel")
traitStatus.Size = UDim2.new(1, 0, 0, 46)
traitStatus.Position = UDim2.new(0, 0, 0, 328)
traitStatus.BackgroundTransparency = 1
traitStatus.Text = "Tiros: 0 | Últimos Rasgos: Ninguno\nMultiplicador: x1.00"
traitStatus.TextColor3 = Color3.fromRGB(170, 175, 190)
traitStatus.Font = Enum.Font.SourceSans
traitStatus.TextSize = 12
traitStatus.TextXAlignment = Enum.TextXAlignment.Left
traitStatus.Parent = traitsFrame

local traitToggleBtn = Instance.new("TextButton")
traitToggleBtn.Size = UDim2.new(1, 0, 0, 36)
traitToggleBtn.Position = UDim2.new(0, 0, 0, 380)
traitToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 75)
traitToggleBtn.Text = "▶ INICIAR AUTO-TRAITS"
traitToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
traitToggleBtn.Font = Enum.Font.GothamBold
traitToggleBtn.TextSize = 12
traitToggleBtn.Parent = traitsFrame
Instance.new("UICorner", traitToggleBtn).CornerRadius = UDim.new(0, 6)

traitToggleBtn.MouseButton1Click:Connect(function()
    if Config.TraitActive then
        stopTraitLoop()
        traitToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 75)
        traitToggleBtn.Text = "▶ INICIAR AUTO-TRAITS"
    else
        startTraitLoop()
        traitToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
        traitToggleBtn.Text = "⏹ DETENER AUTO-TRAITS"
    end
end)

----------------------------------------------------------------------
-- PESTAÑA MÁQUINA RNG (COMPRA GRANULAR Y VELOCIDAD TURBO)
----------------------------------------------------------------------
-- Fila 1: Auto-Compra con Filtro Individual
local buyContainer = Instance.new("Frame")
buyContainer.Size = UDim2.new(1, 0, 0, 32)
buyContainer.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
buyContainer.Parent = rngFrame
Instance.new("UICorner", buyContainer).CornerRadius = UDim.new(0, 6)

local masterBuyToggle = Instance.new("TextButton")
masterBuyToggle.Size = UDim2.new(0.30, -2, 0, 24)
masterBuyToggle.Position = UDim2.new(0, 4, 0, 4)
masterBuyToggle.BackgroundColor3 = Config.AutoBuyActive and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 50, 65)
masterBuyToggle.Text = "Mejoras: " .. (Config.AutoBuyActive and "ON" or "OFF")
masterBuyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterBuyToggle.Font = Enum.Font.SourceSansBold
masterBuyToggle.TextSize = 11
masterBuyToggle.Parent = buyContainer
Instance.new("UICorner", masterBuyToggle).CornerRadius = UDim.new(0, 4)

masterBuyToggle.MouseButton1Click:Connect(function()
    Config.AutoBuyActive = not Config.AutoBuyActive
    masterBuyToggle.BackgroundColor3 = Config.AutoBuyActive and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 50, 65)
    masterBuyToggle.Text = "Mejoras: " .. (Config.AutoBuyActive and "ON" or "OFF")
end)

local buyKeys = {
    { Key = "Luck", Label = "Suerte" },
    { Key = "RollSpeed", Label = "Velocidad" },
    { Key = "Mutation", Label = "Mutación" }
}

for i, bk in ipairs(buyKeys) do
    local isChecked = Config.BuyOnlySelected[bk.Key] == true
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.22, 0, 0, 24)
    b.Position = UDim2.new(0.31 + (i - 1) * 0.23, 0, 0, 4)
    b.BackgroundColor3 = isChecked and Color3.fromRGB(30, 90, 140) or Color3.fromRGB(35, 38, 50)
    b.Text = (isChecked and "✓ " or "✗ ") .. bk.Label
    b.TextColor3 = isChecked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 165, 180)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 10
    b.Parent = buyContainer
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    b.MouseButton1Click:Connect(function()
        Config.BuyOnlySelected[bk.Key] = not Config.BuyOnlySelected[bk.Key]
        local active = Config.BuyOnlySelected[bk.Key]
        b.BackgroundColor3 = active and Color3.fromRGB(30, 90, 140) or Color3.fromRGB(35, 38, 50)
        b.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 165, 180)
        b.Text = (active and "✓ " or "✗ ") .. bk.Label
    end)
end

-- Lista de Rarezas / Áreas
local areaScroll = Instance.new("ScrollingFrame")
areaScroll.Size = UDim2.new(1, 0, 0, 125)
areaScroll.Position = UDim2.new(0, 0, 0, 38)
areaScroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
areaScroll.BorderSizePixel = 0
areaScroll.ScrollBarThickness = 5
areaScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
areaScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
areaScroll.Parent = rngFrame
Instance.new("UICorner", areaScroll).CornerRadius = UDim.new(0, 6)

local areaGrid = Instance.new("UIGridLayout")
areaGrid.CellSize = UDim2.new(0.31, 0, 0, 24)
areaGrid.CellPadding = UDim2.new(0.02, 0, 0, 3)
areaGrid.Parent = areaScroll

local allAreas = {
    "Immortal", "Admin", "Eternal", "Transcendent", "Ancient",
    "Celestial", "OG", "Secret", "Divine", "Mythic", "Legendary", "Epic", "Rare"
}
for _, areaName in ipairs(allAreas) do
    local isSel = Config.SelectedAreas[areaName] == true
    local chip = Instance.new("TextButton")
    chip.BackgroundColor3 = isSel and Color3.fromRGB(30, 90, 140) or Color3.fromRGB(24, 27, 36)
    chip.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)
    chip.Font = Enum.Font.SourceSansBold
    chip.TextSize = 11
    chip.Text = areaName
    chip.Parent = areaScroll
    Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 4)

    chip.MouseButton1Click:Connect(function()
        if Config.SelectedAreas[areaName] then
            Config.SelectedAreas[areaName] = nil
            chip.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
            chip.TextColor3 = Color3.fromRGB(180, 185, 200)
        else
            Config.SelectedAreas[areaName] = true
            chip.BackgroundColor3 = Color3.fromRGB(30, 90, 140)
            chip.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end

-- Lista de Mutaciones
local mutScroll = Instance.new("ScrollingFrame")
mutScroll.Size = UDim2.new(1, 0, 0, 100)
mutScroll.Position = UDim2.new(0, 0, 0, 170)
mutScroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
mutScroll.BorderSizePixel = 0
mutScroll.ScrollBarThickness = 5
mutScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mutScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mutScroll.Parent = rngFrame
Instance.new("UICorner", mutScroll).CornerRadius = UDim.new(0, 6)

local mutGrid = Instance.new("UIGridLayout")
mutGrid.CellSize = UDim2.new(0.48, 0, 0, 24)
mutGrid.CellPadding = UDim2.new(0.02, 0, 0, 3)
mutGrid.Parent = mutScroll

for mutName, mult in pairs(MutationMultipliers) do
    local isSel = Config.SelectedMutations[mutName] == true
    local chip = Instance.new("TextButton")
    chip.BackgroundColor3 = isSel and Color3.fromRGB(130, 70, 30) or Color3.fromRGB(24, 27, 36)
    chip.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)
    chip.Font = Enum.Font.SourceSansBold
    chip.TextSize = 11
    chip.Text = string.format("%s [%s]", mutName, mult)
    chip.Parent = mutScroll
    Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 4)

    chip.MouseButton1Click:Connect(function()
        if Config.SelectedMutations[mutName] then
            Config.SelectedMutations[mutName] = nil
            chip.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
            chip.TextColor3 = Color3.fromRGB(180, 185, 200)
        else
            Config.SelectedMutations[mutName] = true
            chip.BackgroundColor3 = Color3.fromRGB(130, 70, 30)
            chip.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end

local rngStatus = Instance.new("TextLabel")
rngStatus.Size = UDim2.new(1, 0, 0, 45)
rngStatus.Position = UDim2.new(0, 0, 0, 278)
rngStatus.BackgroundTransparency = 1
rngStatus.Text = "Tiros: 0 | Último: Ninguno\nModo Turbo: Reactivo al Servidor (Sin spam ciego)"
rngStatus.TextColor3 = Color3.fromRGB(170, 175, 190)
rngStatus.Font = Enum.Font.SourceSans
rngStatus.TextSize = 12
rngStatus.TextXAlignment = Enum.TextXAlignment.Left
rngStatus.Parent = rngFrame

local rngToggleBtn = Instance.new("TextButton")
rngToggleBtn.Size = UDim2.new(1, 0, 0, 36)
rngToggleBtn.Position = UDim2.new(0, 0, 0, 330)
rngToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 100, 180)
rngToggleBtn.Text = "▶ INICIAR AUTO-RNG (VELOCIDAD MÁXIMA)"
rngToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rngToggleBtn.Font = Enum.Font.GothamBold
rngToggleBtn.TextSize = 12
rngToggleBtn.Parent = rngFrame
Instance.new("UICorner", rngToggleBtn).CornerRadius = UDim.new(0, 6)

rngToggleBtn.MouseButton1Click:Connect(function()
    if Config.RngActive then
        stopRngLoop()
        rngToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 100, 180)
        rngToggleBtn.Text = "▶ INICIAR AUTO-RNG (VELOCIDAD MÁXIMA)"
    else
        startRngLoop()
        rngToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
        rngToggleBtn.Text = "⏹ DETENER AUTO-RNG"
    end
end)

----------------------------------------------------------------------
-- MONITOR DE ESTADÍSTICAS EN PANTALLA
----------------------------------------------------------------------
task.spawn(function()
    while screenGui.Parent do
        task.wait(0.25)
        local traitsStr = #Stats.LastTraitsList > 0 and table.concat(Stats.LastTraitsList, ", ") or "Ninguno"
        traitStatus.Text = string.format("Tiros: %d | Ranuras: %d (Mín: %d)\nÚltimos: [%s]\nMultiplicador: x%.2f (Req: >= x%.2f)",
            Stats.TraitRolls, #Stats.LastTraitsList, Config.MinTraitsRequired,
            traitsStr, Stats.LastTotalMult, Config.TargetMultiplier
        )

        local activeBuys = {}
        for k, v in pairs(Config.BuyOnlySelected) do
            if v then table.insert(activeBuys, k) end
        end
        local buyStr = #activeBuys > 0 and table.concat(activeBuys, ", ") or "Ninguna"

        rngStatus.Text = string.format("Tiros: %d | Último Obtenido: %s [%s]\nAuto-Compra: %s (Comprando: %s)",
            Stats.RngRolls, Stats.LastItem, Stats.LastMutation,
            Config.AutoBuyActive and "ACTIVA" or "APAGADA", buyStr
        )

        if not Config.TraitActive and traitToggleBtn.Text:find("DETENER") then
            traitToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 75)
            traitToggleBtn.Text = "▶ INICIAR AUTO-TRAITS"
        end
        if not Config.RngActive and rngToggleBtn.Text:find("DETENER") then
            rngToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 100, 180)
            rngToggleBtn.Text = "▶ INICIAR AUTO-RNG (VELOCIDAD MÁXIMA)"
        end
    end
end)