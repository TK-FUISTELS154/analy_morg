--[[
    =============================================================================
    APEX SUITE - TEST STANDALONE: AUDITORÍA COMPLETA Y HEURÍSTICA TOPOLÓGICA
    =============================================================================
    Archivo autónomo (100% Todo-en-Uno) para depurar y probar en aislamiento:
    - 🛡️ Modo 1: Anti-Cheat, Watchdogs e Integrity Checks
    - 🎰 Modo 2: Lógica de Ruleta, Gacha, Tiendas, Precios y Probabilidades
    - 📡 Modo 3: Mapeo Integral de Remotes (Events & Functions)
    - 🌐 Modo 4: Auditoría Completa Arquitectónica y Detección de Frameworks
    
    Sin dependencias externas ni llamadas HTTP requeridas.
    =============================================================================
--]]

local cloneref = cloneref or function(o) return o end
local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- 1. DETECTOR DE CAPACIDADES Y DECOMPILADOR SEGURO
-- =========================================================================
local Capabilities = {
    Level = 5,
    HasDecompiler = typeof(decompile) == "function",
    HasFileSystem = typeof(writefile) == "function" and typeof(readfile) == "function",
    HasClipboard = typeof(setclipboard) == "function" or typeof(toclipboard) == "function",
    HasSecureGUI = typeof(gethui) == "function",
}

local function safeDecompile(scriptInstance)
    if not Capabilities.HasDecompiler then
        return "-- [Decompilación no soportada en este ejecutor]"
    end
    local s, code = pcall(function()
        return decompile(scriptInstance)
    end)
    if s and type(code) == "string" and #code > 0 then
        return code
    end
    return "-- [Error o código no disponible al decompilar]"
end

-- =========================================================================
-- 2. DICCIONARIO MULTILINGÜE Y FIRMAS ESTÁTICAS
-- =========================================================================
local Lexicon = {
    AntiCheat = {
        "anticheat", "anti_cheat", "ac_", "_ac", "watchdog", "warden", "integrity",
        "tamper", "hook_check", "memcheck", "noclip", "flycheck", "speedcheck",
        "teleportcheck", "bypass", "exploit", "detection", "security", "guard",
        "kick", "ban", "punish", "flag", "report", "crash",
        -- Español
        "anticheat", "seguridad", "proteccion", "vigilante", "expulsar", "baneo", "trampa", "verificar",
        -- Ruso
        "античит", "защита", "кик", "бан", "проверка", "читы",
        -- Chino
        "反作弊", "安全", "封禁", "踢出", "作弊", "检测", "验证", "防护",
        -- Japonés
        "チート対策", "セキュリティ", "BAN", "キック", "不正検出", "検証",
    },
    Economy = {
        "spin", "wheel", "roll", "roulette", "loot", "crate", "box", "case",
        "shop", "store", "buy", "purchase", "price", "cost", "gems", "coins",
        "gold", "cash", "money", "currency", "diamond", "probability", "chance",
        "weight", "drop", "rarity", "gacha", "draw", "ticket",
        -- Español
        "ruleta", "tienda", "comprar", "precio", "costo", "gemas", "monedas", "oro", "dinero", "probabilidad", "azar", "tirada",
        -- Ruso
        "рулетка", "магазин", "купить", "цена", "монеты", "золото", "деньги", "шанс", "дроп",
        -- Chino
        "轮盘", "商店", "购买", "价格", "金币", "钻石", "货币", "概率", "抽奖", "掉落", "扭蛋",
        -- Japonés
        "ルーレット", "ショップ", "購入", "価格", "コイン", "ダイヤ", "確率", "ガチャ", "ドロップ",
    },
    Combat = {
        "hitbox", "damage", "health", "hp", "bullet", "gun", "sword", "weapon",
        "attack", "aim", "silentaim", "cooldown", "parry", "block", "combo",
        "combat", "skill", "stamina", "ammo", "reload",
        -- Español
        "ataque", "arma", "espada", "daño", "vida", "recarga", "habilidad",
        -- Ruso
        "урон", "оружие", "атака", "хп", "пуля",
        -- Chino
        "攻击", "伤害", "武器", "子弹", "生命值", "技能",
        -- Japonés
        "攻撃", "ダメージ", "武器", "弾丸", "スキル",
    },
    Admin = {
        "admin", "owner", "mod", "moderator", "cmd", "command", "rank", "permission",
        "superadmin", "creator", "dev", "developer", "whitelist", "blacklist",
    }
}

local CodeSignatures = {
    { Pattern = "game%.Players%.LocalPlayer:Kick", Score = 50, Desc = "Llamada directa de Kick al LocalPlayer", Category = "AntiCheat" },
    { Pattern = "hookmetamethod", Score = 30, Desc = "Integridad o monitoreo de metamétodos", Category = "AntiCheat" },
    { Pattern = "getrawmetatable", Score = 30, Desc = "Acceso a metatablas del motor", Category = "AntiCheat" },
    { Pattern = "debug%.info", Score = 25, Desc = "Introspección de Callstack / Rastreo", Category = "AntiCheat" },
    { Pattern = "getfenv", Score = 20, Desc = "Lectura del entorno de ejecución", Category = "AntiCheat" },
    { Pattern = "setfenv", Score = 35, Desc = "Modificación del entorno de ejecución", Category = "AntiCheat" },
    { Pattern = "math%.random", Score = 15, Desc = "Lógica de Probabilidad / RNG", Category = "Economy" },
    { Pattern = "Random%.new", Score = 15, Desc = "Lógica de Generador Aleatorio Seguro", Category = "Economy" },
    { Pattern = "MarketplaceService", Score = 25, Desc = "Interacción con compras y Gamepasses", Category = "Economy" },
    -- Capacidades Críticas de Modding / Admin Abuse
    { Pattern = "BodyVelocity", Score = 35, Desc = "Manipulación de Vuelo / Física Forzada (BodyVelocity)", Category = "Admin" },
    { Pattern = "BodyGyro", Score = 25, Desc = "Manipulación de Orientación / Vuelo (BodyGyro)", Category = "Admin" },
    { Pattern = "CanCollide%s*=%s*false", Score = 40, Desc = "Rutina de Noclip en tiempo de ejecución", Category = "Admin" },
    { Pattern = "_G%.", Score = 20, Desc = "Exposición de Variables Globales en Memoria (_G)", Category = "Admin" },
}

-- =========================================================================
-- 3. FILTROS DE CORE DE ROBLOX & EMPAREJAMIENTO EXACTO POR LÍMITES DE PALABRA
-- =========================================================================
local function isIgnoredCoreInstance(inst)
    local fullName = inst:GetFullName()
    if fullName:find("StarterPlayer%.StarterPlayerScripts%.PlayerModule")
       or fullName:find("StarterPlayer%.StarterPlayerScripts%.RbxCharacterSounds")
       or fullName:find("PlayerScriptsLoader")
       or fullName:find("ChatScript")
       or fullName:find("BubbleChat")
       or fullName:find("RobloxGui")
       or fullName:find("%.spec")
       or fullName:find("%.test")
       or fullName:find("Jest")
       or fullName:find("TestEZ") then
        return true
    end
    return false
end

local function matchesKeyword(targetText, keyword)
    if not targetText or not keyword then return false end
    local lowerText = targetText:lower()
    local lowerKw = keyword:lower()
    
    -- Si contiene prefijos/sufijos técnicos o caracteres no alfanuméricos ASCII
    if lowerKw:find("^[_%W]") or lowerKw:find("[_%W]$") or lowerKw:match("[^\32-\126]") then
        return string.find(lowerText, lowerKw, 1, true) ~= nil
    end
    
    -- Palabras ASCII normales: usar límite de frontera de palabra para evitar que 'controller' coincida con 'roll' o 'abandon' con 'ban'
    local pattern = "%f[%w]" .. lowerKw .. "%f[%W]"
    return string.find(lowerText, pattern) ~= nil
end

-- =========================================================================
-- 4. MOTOR DE ANÁLISIS HEURÍSTICO
-- =========================================================================
local function analyzeInstance(inst)
    -- Omitir automáticamente scripts nativos del core de Roblox
    if isIgnoredCoreInstance(inst) then
        return {
            Instance = inst,
            Name = inst.Name,
            ClassName = inst.ClassName,
            Path = inst:GetFullName(),
            Score = 0,
            Severity = "IGNORED",
            MatchedKeywords = {},
            Tags = { "Ignored: Core Roblox Script" },
            Categories = {},
            Code = nil,
            IsIgnored = true,
        }
    end

    local score = 0
    local rawName = inst.Name
    local className = inst.ClassName
    local path = inst:GetFullName()
    local tags = {}
    local categoriesFound = {}
    local matchedKeywords = {}

    -- 1. Ponderación por Nombre con límites de palabra estrictos
    for catName, keywords in pairs(Lexicon) do
        for _, kw in ipairs(keywords) do
            if matchesKeyword(rawName, kw) then
                score = score + 25
                table.insert(matchedKeywords, kw)
                categoriesFound[catName] = true
                table.insert(tags, "Nombre:" .. kw)
                break
            end
        end
    end

    -- 2. Ponderación Topológica de Ubicación
    if string.find(path, "ReplicatedFirst") then
        score = score + 35
        table.insert(tags, "Ubicación:ReplicatedFirst (Arranque Prioritario)")
        categoriesFound["AntiCheat"] = true
    elseif string.find(path, "PlayerScripts") or string.find(path, "StarterPlayer") then
        score = score + 15
        table.insert(tags, "Ubicación:PlayerScripts (Cliente)")
    elseif string.find(path, "ReplicatedStorage") then
        score = score + 10
    end

    -- 3. Ponderación por Clase
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
        score = score + 15
        table.insert(tags, "Clase:Remote")
        categoriesFound["Remotes"] = true
    elseif inst:IsA("ModuleScript") then
        score = score + 10
        table.insert(tags, "Clase:ModuleScript")
    end

    -- 4. Inspección de Atributos
    local sAttrs, attrs = pcall(function() return inst:GetAttributes() end)
    if sAttrs and attrs then
        for attrName, _ in pairs(attrs) do
            for catName, keywords in pairs(Lexicon) do
                for _, kw in ipairs(keywords) do
                    if matchesKeyword(tostring(attrName), kw) then
                        score = score + 10
                        table.insert(tags, "Attr:" .. attrName)
                        categoriesFound[catName] = true
                        break
                    end
                end
            end
        end
    end

    -- 5. Análisis de Código (Scripts y Módulos)
    local decompiledCode = nil
    if inst:IsA("LuaSourceContainer") then
        decompiledCode = safeDecompile(inst)
        if decompiledCode and not decompiledCode:find("%[Decompilación no soportada") then
            -- Firmas estáticas
            for _, sig in ipairs(CodeSignatures) do
                if string.find(decompiledCode, sig.Pattern) then
                    score = score + sig.Score
                    table.insert(tags, sig.Desc)
                    categoriesFound[sig.Category] = true
                end
            end

            -- Multilingüe en código con límites de palabra
            for catName, keywords in pairs(Lexicon) do
                for _, kw in ipairs(keywords) do
                    if matchesKeyword(decompiledCode, kw) then
                        score = score + 5
                        categoriesFound[catName] = true
                        break
                    end
                end
            end

            -- Detección de ofuscadores
            if decompiledCode:find("LPH_") or decompiledCode:find("IronBrew") or decompiledCode:find("MoonSec") or decompiledCode:find("PSU_") then
                score = score + 40
                table.insert(tags, "Ofuscador Detectado (Luraph/IronBrew/Moonsec)")
            end
        end
    end

    if score > 100 then score = 100 end

    local severity = "LOW"
    if score >= 75 or (categoriesFound["AntiCheat"] and score >= 55) or (categoriesFound["Admin"] and score >= 50) then
        severity = "CRITICAL"
    elseif score >= 50 or categoriesFound["Combat"] or categoriesFound["Admin"] then
        severity = "HIGH"
    elseif score >= 25 or categoriesFound["Economy"] then
        severity = "MEDIUM"
    end

    return {
        Instance = inst,
        Name = rawName,
        ClassName = className,
        Path = path,
        Score = score,
        Severity = severity,
        MatchedKeywords = matchedKeywords,
        Tags = tags,
        Categories = categoriesFound,
        Code = decompiledCode,
end

-- =========================================================================
-- 5. MODOS DE AUDITORÍA
-- =========================================================================
local Scanner = {}

function Scanner.RunAntiCheatAudit()
    local results = {
        Category = "AntiCheat",
        Timestamp = os.time(),
        Targets = {},
        TotalFound = 0,
    }
    local containers = {
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("ReplicatedStorage"),
        game:GetService("RobloxReplicatedStorage"),
    }
    for _, loc in ipairs(containers) do
        if loc then
            local s, desc = pcall(function() return loc:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    local analysis = analyzeInstance(inst)
                    if not analysis.IsIgnored and (analysis.Categories["AntiCheat"] or analysis.Score >= 40) then
                        table.insert(results.Targets, analysis)
                        results.TotalFound = results.TotalFound + 1
                    end
                end
            end
        end
    end
    return results
end

function Scanner.RunEconomyAudit()
    local results = {
        Category = "Economy",
        Timestamp = os.time(),
        Roulettes = {},
        Shops = {},
        LootTables = {},
        ValueContainers = {},
        TotalFound = 0,
    }
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"),
    }
    for _, loc in ipairs(containers) do
        if loc then
            local s, desc = pcall(function() return loc:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    local analysis = analyzeInstance(inst)
                    if not analysis.IsIgnored and (analysis.Categories["Economy"] or analysis.Score >= 25) then
                        results.TotalFound = results.TotalFound + 1
                        if matchesKeyword(analysis.Name, "spin") or matchesKeyword(analysis.Name, "wheel") or matchesKeyword(analysis.Name, "ruleta") or matchesKeyword(analysis.Name, "roll") then
                            table.insert(results.Roulettes, analysis)
                        elseif matchesKeyword(analysis.Name, "shop") or matchesKeyword(analysis.Name, "store") or matchesKeyword(analysis.Name, "tienda") or matchesKeyword(analysis.Name, "buy") then
                            table.insert(results.Shops, analysis)
                        elseif inst:IsA("ModuleScript") then
                            table.insert(results.LootTables, analysis)
                        else
                            table.insert(results.ValueContainers, analysis)
                        end
                    end
                end
            end
        end
    end
    return results
end

function Scanner.RunRemotesAudit()
    local results = {
        Category = "Remotes",
        Timestamp = os.time(),
        RemoteEvents = {},
        RemoteFunctions = {},
        TotalFound = 0,
    }
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"),
    }
    for _, loc in ipairs(containers) do
        if loc then
            local s, desc = pcall(function() return loc:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    if not isIgnoredCoreInstance(inst) then
                        if inst:IsA("RemoteEvent") then
                            results.TotalFound = results.TotalFound + 1
                            table.insert(results.RemoteEvents, {
                                Name = inst.Name,
                                ClassName = "RemoteEvent",
                                Path = inst:GetFullName(),
                            })
                        elseif inst:IsA("RemoteFunction") then
                            results.TotalFound = results.TotalFound + 1
                            table.insert(results.RemoteFunctions, {
                                Name = inst.Name,
                                ClassName = "RemoteFunction",
                                Path = inst:GetFullName(),
                            })
                        end
                    end
                end
            end
        end
    end
    return results
end

function Scanner.RunFullAudit()
    local results = {
        Timestamp = os.time(),
        AntiCheat = {},
        Economy = {},
        Combat = {},
        Admin = {},
        Remotes = {},
        CriticalIssues = 0,
        TotalScanned = 0,
        FrameworksDetected = {},
    }

    -- Detección de Frameworks
    local repStorage = game:GetService("ReplicatedStorage")
    if repStorage:FindFirstChild("Knit") or repStorage:FindFirstChild("KnitPackages") then
        table.insert(results.FrameworksDetected, "Knit Framework")
    end
    if repStorage:FindFirstChild("Flamework") then
        table.insert(results.FrameworksDetected, "Flamework")
    end
    if repStorage:FindFirstChild("ReplicaService") or repStorage:FindFirstChild("ReplicaClient") then
        table.insert(results.FrameworksDetected, "ReplicaService")
    end
    if repStorage:FindFirstChild("ByteNet") then
        table.insert(results.FrameworksDetected, "ByteNet Network Engine")
    end

    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"),
    }

    for _, container in ipairs(containers) do
        if container then
            local s, desc = pcall(function() return container:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    results.TotalScanned = results.TotalScanned + 1
                    local analysis = analyzeInstance(inst)

                    if not analysis.IsIgnored and (analysis.Score > 0 or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
                        if analysis.Categories["AntiCheat"] or analysis.Score >= 45 then
                            table.insert(results.AntiCheat, analysis)
                        end
                        if analysis.Categories["Economy"] then
                            table.insert(results.Economy, analysis)
                        end
                        if analysis.Categories["Combat"] then
                            table.insert(results.Combat, analysis)
                        end
                        if analysis.Categories["Admin"] then
                            table.insert(results.Admin, analysis)
                        end
                        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                            table.insert(results.Remotes, analysis)
                        end

                        if analysis.Severity == "CRITICAL" then
                            results.CriticalIssues = results.CriticalIssues + 1
                        end
                    end
                end
            end
        end
    end
    return results
end

-- =========================================================================
-- 5. SERIALIZADOR JSON SEGURO
-- =========================================================================
local function toJSON(tbl, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    local subSpacing = string.rep("  ", indent + 1)
    
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end
    
    local isArray = (#tbl > 0)
    local elements = {}
    
    if isArray then
        for _, v in ipairs(tbl) do
            if type(v) ~= "userdata" and type(v) ~= "function" and type(v) ~= "thread" then
                if type(v) == "table" and v.Instance then
                    -- Evitar serializar referencias de instancias cíclicas
                    local cloneTbl = {}
                    for k2, v2 in pairs(v) do
                        if k2 ~= "Instance" then cloneTbl[k2] = v2 end
                    end
                    table.insert(elements, subSpacing .. toJSON(cloneTbl, indent + 1))
                else
                    table.insert(elements, subSpacing .. toJSON(v, indent + 1))
                end
            end
        end
        return "[\n" .. table.concat(elements, ",\n") .. "\n" .. spacing .. "]"
    else
        for k, v in pairs(tbl) do
            if type(v) ~= "userdata" and type(v) ~= "function" and type(v) ~= "thread" and k ~= "Instance" then
                local keyStr = string.format("%q", tostring(k))
                table.insert(elements, subSpacing .. keyStr .. ": " .. toJSON(v, indent + 1))
            end
        end
        return "{\n" .. table.concat(elements, ",\n") .. "\n" .. spacing .. "}"
    end
end

-- =========================================================================
-- 6. INTERFAZ GRÁFICA FLUIDA CON CONTROL DE LÍMITE DE TEXTO
-- =========================================================================
local screenGuiName = "Apex_Audit_Standalone_Test"
local oldGui = CoreGui:FindFirstChild(screenGuiName) or (LocalPlayer and LocalPlayer.PlayerGui:FindFirstChild(screenGuiName))
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = screenGuiName
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if Capabilities.HasSecureGUI then
    screenGui.Parent = gethui()
elseif CoreGui then
    screenGui.Parent = CoreGui
else
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 720, 0, 500)
mainFrame.Position = UDim2.new(0.5, -360, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 50, 65)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

-- Arrastre de Ventana
local isDragging, dragStart, startPos = false, nil, nil
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)
mainFrame.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Barra de Título
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🛡️ APEX SUITE - TEST DE AUDITORÍA Y HEURÍSTICA"
titleLabel.TextColor3 = Color3.fromRGB(240, 243, 250)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- Selector de Modos
local modeBar = Instance.new("Frame")
modeBar.Size = UDim2.new(1, -24, 0, 32)
modeBar.Position = UDim2.new(0, 12, 0, 46)
modeBar.BackgroundTransparency = 1
modeBar.Parent = mainFrame

local modes = {
    { Id = "AntiCheat", Label = "🛡️ Anti-Cheat & Kicks" },
    { Id = "Economy",   Label = "🎰 Lógica & Ruleta" },
    { Id = "Remotes",   Label = "📡 Todos los Remotes" },
    { Id = "FullAudit", Label = "🌐 Auditoría Completa" },
}

local currentMode = "AntiCheat"
local modeBtns = {}
local previewBox = Instance.new("TextBox")

local function selectMode(id)
    currentMode = id
    for modeId, btn in pairs(modeBtns) do
        if modeId == id then
            btn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
            btn.TextColor3 = Color3.fromRGB(160, 168, 185)
        end
    end
    previewBox.Text = string.format("-- Modo seleccionado: %s\nPresiona '⚡ EJECUTAR ESCANEO' para iniciar el análisis.", id)
end

for i, m in ipairs(modes) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.25, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * 0.25, 2, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
    btn.Text = m.Label
    btn.TextColor3 = Color3.fromRGB(160, 168, 185)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = modeBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    modeBtns[m.Id] = btn
    btn.MouseButton1Click:Connect(function() selectMode(m.Id) end)
end

-- Barra de Acciones
local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, -24, 0, 32)
actionRow.Position = UDim2.new(0, 12, 0, 84)
actionRow.BackgroundTransparency = 1
actionRow.Parent = mainFrame

local runBtn = Instance.new("TextButton")
runBtn.Size = UDim2.new(0, 160, 1, 0)
runBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
runBtn.Text = "⚡ EJECUTAR ESCANEO"
runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
runBtn.Font = Enum.Font.GothamBold
runBtn.TextSize = 11
runBtn.Parent = actionRow
Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 6)

local exportJsonBtn = Instance.new("TextButton")
exportJsonBtn.Size = UDim2.new(0, 120, 1, 0)
exportJsonBtn.Position = UDim2.new(0, 166, 0, 0)
exportJsonBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
exportJsonBtn.Text = "💾 EXPORTAR JSON"
exportJsonBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
exportJsonBtn.Font = Enum.Font.GothamMedium
exportJsonBtn.TextSize = 11
exportJsonBtn.Parent = actionRow
Instance.new("UICorner", exportJsonBtn).CornerRadius = UDim.new(0, 6)

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 130, 1, 0)
copyBtn.Position = UDim2.new(0, 292, 0, 0)
copyBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
copyBtn.Text = "📋 COPIAR TEXTO"
copyBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
copyBtn.Font = Enum.Font.GothamMedium
copyBtn.TextSize = 11
copyBtn.Parent = actionRow
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -430, 1, 0)
statusLabel.Position = UDim2.new(0, 428, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Listo."
statusLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = actionRow

-- Caja de Vista Previa (TextBox con manejo seguro de límite de 200k chars)
previewBox.Size = UDim2.new(1, -24, 1, -128)
previewBox.Position = UDim2.new(0, 12, 0, 120)
previewBox.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
previewBox.TextColor3 = Color3.fromRGB(210, 220, 235)
previewBox.Font = Enum.Font.Code
previewBox.TextSize = 11
previewBox.TextXAlignment = Enum.TextXAlignment.Left
previewBox.TextYAlignment = Enum.TextYAlignment.Top
previewBox.ClearTextOnFocus = false
previewBox.MultiLine = true
previewBox.TextEditable = false
previewBox.Parent = mainFrame
Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 8)

local function setSafePreviewText(text)
    local maxLimit = 75000
    local str = tostring(text or "")
    if #str > maxLimit then
        previewBox.Text = string.sub(str, 1, maxLimit) .. string.format("\n\n-- [⚠️ AVISO: Vista previa truncada a %d caracteres debido al límite de interfaz de Roblox]\n-- [Total: %d caracteres. Para el reporte completo sin truncar, usa '💾 EXPORTAR JSON' o '📋 COPIAR TEXTO']", maxLimit, #str)
    else
        previewBox.Text = str
    end
end

selectMode("AntiCheat")

local lastReportData = nil
local lastFullText = ""

runBtn.MouseButton1Click:Connect(function()
    statusLabel.Text = "Escaneando " .. currentMode .. "..."
    runBtn.Text = "⏳ ANALIZANDO..."
    task.wait(0.1)

    local lines = {}

    if currentMode == "AntiCheat" then
        local rep = Scanner.RunAntiCheatAudit()
        lastReportData = rep
        table.insert(lines, "==================================================================")
        table.insert(lines, "🛡️ AUDITORÍA DE SEGURIDAD & WATCHDOGS (ANTI-CHEAT)")
        table.insert(lines, "==================================================================")
        table.insert(lines, string.format("Instancias Sospechosas Localizadas: %d\n", rep.TotalFound))

        for _, item in ipairs(rep.Targets) do
            table.insert(lines, string.format("-> [%s] %s | Score: %d/100 | Severidad: %s\n   Ruta: %s", item.ClassName, item.Name, item.Score, item.Severity, item.Path))
            if #item.Tags > 0 then
                table.insert(lines, "   Firmas: " .. table.concat(item.Tags, ", "))
            end
            if item.Code then
                table.insert(lines, "   [CÓDIGO DECOMPILADO]:\n" .. item.Code .. "\n")
            end
            table.insert(lines, "------------------------------------------------------------------")
        end

    elseif currentMode == "Economy" then
        local rep = Scanner.RunEconomyAudit()
        lastReportData = rep
        table.insert(lines, "==================================================================")
        table.insert(lines, "🎰 AUDITORÍA DE RULETA, PROBABILIDADES, TIENDAS Y ECONOMÍA")
        table.insert(lines, "==================================================================")
        table.insert(lines, string.format("Total de elementos detectados: %d", rep.TotalFound))
        table.insert(lines, string.format("• Sistemas de Ruleta / Azar: %d", #rep.Roulettes))
        table.insert(lines, string.format("• Módulos de Tiendas / Compras: %d", #rep.Shops))
        table.insert(lines, string.format("• Tablas de Loot (ModuleScripts): %d\n", #rep.LootTables))

        if #rep.Roulettes > 0 then
            table.insert(lines, "[SISTEMAS DE RULETA / AZAR]:")
            for _, item in ipairs(rep.Roulettes) do
                table.insert(lines, string.format("🎰 [%s] %s\n   Ruta: %s", item.ClassName, item.Name, item.Path))
            end
            table.insert(lines, "")
        end

        if #rep.Shops > 0 then
            table.insert(lines, "[TIENDAS Y PRECIOS]:")
            for _, item in ipairs(rep.Shops) do
                table.insert(lines, string.format("🛒 [%s] %s\n   Ruta: %s", item.ClassName, item.Name, item.Path))
            end
            table.insert(lines, "")
        end

        if #rep.LootTables > 0 then
            table.insert(lines, "[TABLAS DE LOOT (MODULES)]:")
            for _, item in ipairs(rep.LootTables) do
                table.insert(lines, string.format("📜 [%s] %s\n   Ruta: %s", item.ClassName, item.Name, item.Path))
                if item.Code then
                    table.insert(lines, "   [CÓDIGO]:\n" .. item.Code .. "\n")
                end
            end
        end

    elseif currentMode == "Remotes" then
        local rep = Scanner.RunRemotesAudit()
        lastReportData = rep
        table.insert(lines, "==================================================================")
        table.insert(lines, "📡 MAPEO COMPLETO DE EVENTOS Y FUNCIONES REMOTAS")
        table.insert(lines, "==================================================================")
        table.insert(lines, string.format("Total de Remotes Mapeados: %d", rep.TotalFound))
        table.insert(lines, string.format("• RemoteEvents: %d", #rep.RemoteEvents))
        table.insert(lines, string.format("• RemoteFunctions: %d\n", #rep.RemoteFunctions))

        for _, r in ipairs(rep.RemoteEvents) do
            table.insert(lines, string.format("⚡ [RemoteEvent] %s\n   Ruta: %s", r.Name, r.Path))
        end
        for _, r in ipairs(rep.RemoteFunctions) do
            table.insert(lines, string.format("🔁 [RemoteFunction] %s\n   Ruta: %s", r.Name, r.Path))
        end

    else
        local rep = Scanner.RunFullAudit()
        lastReportData = rep
        table.insert(lines, "==================================================================")
        table.insert(lines, "🌐 REPORTE DE AUDITORÍA TOPOLÓGICA Y ARQUITECTURA COMPLETA")
        table.insert(lines, "==================================================================")
        table.insert(lines, string.format("Total de Instancias Escaneadas: %d", rep.TotalScanned))
        table.insert(lines, string.format("Amenazas Críticas (Score >= 75): %d", rep.CriticalIssues))
        table.insert(lines, string.format("Watchdogs / Anti-Cheat: %d", #rep.AntiCheat))
        table.insert(lines, string.format("Lógica de Combate / Armas: %d", #rep.Combat))
        table.insert(lines, string.format("Sistemas de Economía / Azar: %d", #rep.Economy))
        table.insert(lines, string.format("Comandos de Administración: %d", #rep.Admin))
        table.insert(lines, string.format("Remotes Mapeados: %d\n", #rep.Remotes))

        if #rep.FrameworksDetected > 0 then
            table.insert(lines, "• Frameworks Detectados: " .. table.concat(rep.FrameworksDetected, ", "))
        else
            table.insert(lines, "• Frameworks Detectados: Ninguno estándar (Arquitectura nativa Luau)")
        end
    end

    lastFullText = table.concat(lines, "\n")
    setSafePreviewText(lastFullText)
    statusLabel.Text = string.format("Escaneo finalizado exitosamente.")
    runBtn.Text = "⚡ EJECUTAR ESCANEO"
end)

exportJsonBtn.MouseButton1Click:Connect(function()
    if not lastReportData then
        statusLabel.Text = "Ejecuta un escaneo primero."
        return
    end
    local jsonStr = toJSON(lastReportData)
    local fileName = "audit_test_" .. currentMode .. "_" .. os.time() .. ".json"
    if Capabilities.HasFileSystem then
        writefile(fileName, jsonStr)
        statusLabel.Text = "Guardado en: " .. fileName
    elseif Capabilities.HasClipboard then
        setclipboard(jsonStr)
        statusLabel.Text = "Copiado JSON al portapapeles."
    else
        statusLabel.Text = "Sin acceso a archivos/clipboard."
    end
end)

copyBtn.MouseButton1Click:Connect(function()
    if #lastFullText == 0 then
        statusLabel.Text = "Sin texto para copiar."
        return
    end
    if Capabilities.HasClipboard then
        setclipboard(lastFullText)
        statusLabel.Text = "Reporte completo copiado al portapapeles."
    else
        statusLabel.Text = "Portapapeles no soportado."
    end
end)

print("[APEX TEST] Test de Auditoría Completa inicializado con éxito.")
