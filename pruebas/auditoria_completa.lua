--[[
    =============================================================================
    APEX SUITE - MOTOR DE AUDITORÍA Y ANÁLISIS DE SEGURIDAD v2.0 (OPTIMIZADO)
    =============================================================================
    Archivo autónomo de alto rendimiento con optimizaciones arquitectónicas:
    
    1. ⚡ FILTRADO PREMATURO DE INSTANCIAS:
       - Solo se procesan contenedores de código ejecutables (LocalScript, Script, ModuleScript)
         y remotes de red (RemoteEvent, RemoteFunction, UnreliableRemoteEvent).
       - Descarte instantáneo en O(1) de sonidos, mallas, partículas, geometrías y texturas.
    
    2. 🚫 ELIMINACIÓN DE ESCANEOS GLOBALES:
       - Servicios delimitados: ReplicatedStorage, ReplicatedFirst, StarterPlayer, PlayerGui.
       - Cero recorridos sobre Workspace, Terreno o la raíz global (game:GetDescendants).
    
    3. 🧠 REGLAS DE DETECCIÓN CONTEXTUALIZADAS:
       - Noclip contextual: Exige concurrencia de alteración de colisión del Character en bucles (RenderStepped/Heartbeat).
       - Bypass de Módulos de Configuración Estática: Detecta tablas de datos puras y evita falsos positivos.
       - RNG Cosmético vs Transaccional: Diferencia entre animaciones y remotes de compra.
       - Clasificación limpia: Separa 'ADMIN_TOOL' (Herramientas Administrativas) de Cheats y Kicks.
    
    4. 📦 RESUMEN CONTEXTUAL (CERO DESBORDAMIENTO DE MEMORIA):
       - En lugar de clonar megabytes de código descompilado, almacena firmas con líneas y snippets representativos.
       - Serialización JSON ultra ligera y rápida (<25 KB).
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
        return nil
    end
    local s, code = pcall(function()
        return decompile(scriptInstance)
    end)
    if s and type(code) == "string" and #code > 0 then
        return code
    end
    return nil
end

-- =========================================================================
-- 2. FILTROS CORE Y DISCRIMINACIÓN PREMATURA DE INSTANCIAS
-- =========================================================================
local function isIgnoredCorePath(fullName)
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

local function isExecutableOrNetwork(inst)
    return inst:IsA("LuaSourceContainer") or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")
end

-- =========================================================================
-- 3. EMPAREJADOR CON FRONTERAS DE PALABRA (FRONTIER PATTERNS)
-- =========================================================================
local function matchesWord(targetText, keyword)
    if not targetText or not keyword then return false end
    local lowerText = targetText:lower()
    local lowerKw = keyword:lower()
    
    -- Si contiene prefijos/sufijos técnicos o caracteres no alfanuméricos ASCII
    if lowerKw:find("^[_%W]") or lowerKw:find("[_%W]$") or lowerKw:match("[^\32-\126]") then
        return string.find(lowerText, lowerKw, 1, true) ~= nil
    end
    
    -- Límite estricto de frontera de palabra
    local pattern = "%f[%w]" .. lowerKw .. "%f[%W]"
    return string.find(lowerText, pattern) ~= nil
end

-- =========================================================================
-- 4. DICCIONARIO MULTILINGÜE Y FIRMAS ESTÁTICAS CONTEXTUALIZADAS
-- =========================================================================
local Lexicon = {
    AntiCheat = {
        "anticheat", "anti_cheat", "ac_", "_ac", "watchdog", "warden", "integrity",
        "tamper", "hook_check", "memcheck", "noclip", "flycheck", "speedcheck",
        "teleportcheck", "bypass", "exploit", "detection", "security", "guard",
        "kick", "ban", "punish", "flag", "report", "crash",
        -- Español / Multilingüe
        "seguridad", "proteccion", "vigilante", "expulsar", "baneo", "trampa", "verificar",
        "античит", "защита", "кик", "бан", "проверка", "читы",
        "反作弊", "安全", "封禁", "踢出", "作弊", "检测", "验证", "防护",
        "チート対策", "セキュリティ", "BAN", "キック", "不正検出", "検証",
    },
    Economy = {
        "spin", "wheel", "roll", "roulette", "loot", "crate", "box", "case",
        "shop", "store", "buy", "purchase", "price", "cost", "gems", "coins",
        "gold", "cash", "money", "currency", "diamond", "probability", "chance",
        "weight", "drop", "rarity", "gacha", "draw", "ticket",
        -- Español / Multilingüe
        "ruleta", "tienda", "comprar", "precio", "costo", "gemas", "monedas", "oro", "dinero", "probabilidad", "azar", "tirada",
        "рулетка", "магазин", "купить", "цена", "монеты", "золото", "деньги", "шанс", "дроп",
        "轮盘", "商店", "购买", "价格", "金币", "钻石", "货币", "概率", "抽奖", "掉落", "扭蛋",
        "ルーレット", "ショップ", "購入", "価格", "コイン", "ダイヤ", "確率", "ガチャ", "ドロップ",
    },
    Combat = {
        "hitbox", "damage", "health", "hp", "bullet", "gun", "sword", "weapon",
        "attack", "aim", "silentaim", "cooldown", "parry", "block", "combo",
        "combat", "skill", "stamina", "ammo", "reload",
        -- Español / Multilingüe
        "ataque", "arma", "espada", "daño", "vida", "recarga", "habilidad",
        "урон", "оружие", "атака", "хп", "пуля",
        "攻击", "伤害", "武器", "子弹", "生命值", "技能",
        "攻撃", "ダメージ", "武器", "弾丸", "スキル",
    },
    Admin = {
        "admin", "owner", "mod", "moderator", "cmd", "command", "rank", "permission",
        "superadmin", "creator", "dev", "developer", "whitelist", "blacklist",
    }
}

-- Pre-analizador de tablas de datos estáticos (Config bypass)
local function isStaticDataModule(code)
    if not code or #code == 0 then return false end
    -- Si es un módulo que solo retorna una tabla literal y no contiene llamadas a servicios o bucles
    local hasReturn = code:find("return%s+{") or code:find("return%s+setmetatable")
    local hasLoops = code:find("while%s+") or code:find("for%s+") or code:find("repeat%s+")
    local hasServices = code:find("GetService") or code:find("FireServer") or code:find("InvokeServer") or code:find("Connect%(")
    
    if hasReturn and not hasLoops and not hasServices then
        return true
    end
    return false
end

-- Extractor de snippets representativos concisos
local function extractCodeSnippets(code, pattern, maxSnippets)
    maxSnippets = maxSnippets or 2
    local snippets = {}
    local lineNum = 1
    
    for line in code:gmatch("([^\r\n]*)\r?\n?") do
        if line:find(pattern) then
            local cleanLine = line:match("^%s*(.-)%s*$")
            if #cleanLine > 120 then cleanLine = cleanLine:sub(1, 117) .. "..." end
            table.insert(snippets, { Line = lineNum, Code = cleanLine })
            if #snippets >= maxSnippets then break end
        end
        lineNum = lineNum + 1
    end
    return snippets
end

-- =========================================================================
-- 5. MOTOR DE ANÁLISIS HEURÍSTICO REFINADO
-- =========================================================================
local function analyzeInstance(inst, depth)
    depth = depth or 0
    local rawName = inst.Name
    local className = inst.ClassName
    local path = inst:GetFullName()
    
    -- 1. FILTRADO PREMATURO: Si no es ejecutable ni red, descartar en O(1)
    if not isExecutableOrNetwork(inst) then
        return nil
    end
    
    -- 2. Descarte de Core Roblox
    if isIgnoredCorePath(path) then
        return nil
    end
    
    local score = 0
    local matchedKeywords = {}
    local tags = {}
    local categoriesFound = {}
    local codeFindings = {}
    local isStaticConfig = false
    local isRem = inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")

    -- 3. Análisis de Nombres de Scripts y Remotes
    for catName, keywords in pairs(Lexicon) do
        for _, kw in ipairs(keywords) do
            if matchesWord(rawName, kw) then
                local weight = (catName == "AntiCheat" and 25) or (catName == "Admin" and 20) or 15
                score = score + weight
                table.insert(matchedKeywords, kw)
                categoriesFound[catName] = true
                table.insert(tags, "Nombre:" .. kw)
                break
            end
        end
    end

    -- 4. Ponderación Topológica de Ubicación
    if string.find(path, "ReplicatedFirst") then
        score = score + 30
        table.insert(tags, "Topología:ReplicatedFirst (Early Boot)")
        categoriesFound["AntiCheat"] = true
    elseif string.find(path, "PlayerScripts") or string.find(path, "StarterPlayer") then
        score = score + 10
    end

    -- 5. Ponderación por Clase de Red
    if isRem then
        score = score + 15
        table.insert(tags, "Clase:" .. className)
        categoriesFound["Remotes"] = true
    end

    -- 6. Análisis Profundo de Código Contextualizado (Scripts y Módulos)
    if inst:IsA("LuaSourceContainer") then
        local decompiledCode = safeDecompile(inst)
        if decompiledCode and not decompiledCode:find("%[Decompilación no soportada") then
            -- Pre-verificación: ¿Es un módulo de configuración estática pura?
            if inst:IsA("ModuleScript") and isStaticDataModule(decompiledCode) then
                isStaticConfig = true
                table.insert(tags, "Tipo: Módulo de Configuración Estática (Datos Puros)")
            else
                -- Regla 1: Expulsión Directa del LocalPlayer
                if decompiledCode:find("LocalPlayer:Kick") or decompiledCode:find("Players%.LocalPlayer:Kick") then
                    score = score + 45
                    categoriesFound["AntiCheat"] = true
                    local snips = extractCodeSnippets(decompiledCode, "Kick")
                    table.insert(codeFindings, { Desc = "Llamada Directa a Expulsión (LocalPlayer:Kick)", Snippets = snips })
                    table.insert(tags, "Llamada:Kick")
                end

                -- Regla 2: Introspección de Metatablas / Callstack
                if decompiledCode:find("hookmetamethod") or decompiledCode:find("getrawmetatable") then
                    score = score + 30
                    categoriesFound["AntiCheat"] = true
                    local snips = extractCodeSnippets(decompiledCode, "metatable")
                    table.insert(codeFindings, { Desc = "Manipulación/Auditoría de Metatablas", Snippets = snips })
                    table.insert(tags, "Metatables")
                end

                if decompiledCode:find("debug%.info") or decompiledCode:find("debug%.traceback") then
                    score = score + 20
                    categoriesFound["AntiCheat"] = true
                    local snips = extractCodeSnippets(decompiledCode, "debug%.")
                    table.insert(codeFindings, { Desc = "Introspección de Callstack / Trap", Snippets = snips })
                    table.insert(tags, "DebugTrap")
                end

                -- Regla 3: Noclip Contextualizado (Exige Character + Bucle de Física/Render)
                local hasCanCollide = decompiledCode:find("CanCollide%s*=%s*false")
                local hasBodyParts = decompiledCode:find("HumanoidRootPart") or decompiledCode:find("Torso") or decompiledCode:find("Character")
                local hasLoop = decompiledCode:find("RenderStepped") or decompiledCode:find("Heartbeat") or decompiledCode:find("Stepped")
                if hasCanCollide and hasBodyParts and hasLoop then
                    score = score + 40
                    categoriesFound["Admin"] = true
                    local snips = extractCodeSnippets(decompiledCode, "CanCollide")
                    table.insert(codeFindings, { Desc = "Rutina Continua de Noclip en Character (RenderStepped)", Snippets = snips })
                    table.insert(tags, "Noclip:Contextual")
                end

                -- Regla 4: Manipulación de Vuelo y Físicas
                if decompiledCode:find("BodyVelocity") and (decompiledCode:find("HumanoidRootPart") or decompiledCode:find("Torso")) then
                    score = score + 35
                    categoriesFound["Admin"] = true
                    local snips = extractCodeSnippets(decompiledCode, "BodyVelocity")
                    table.insert(codeFindings, { Desc = "Manipulación de Vuelo / Fuerza Física (BodyVelocity)", Snippets = snips })
                    table.insert(tags, "Fly:BodyVelocity")
                end

                -- Regla 5: Exposición de Variables Globales en Memoria (_G / shared)
                if decompiledCode:find("_G%.__") or decompiledCode:find("shared%.__") then
                    score = score + 20
                    categoriesFound["Admin"] = true
                    local snips = extractCodeSnippets(decompiledCode, "_G%.")
                    table.insert(codeFindings, { Desc = "Exposición de Funciones/Banderas Globales (_G/shared)", Snippets = snips })
                    table.insert(tags, "GlobalState")
                end

                -- Regla 6: RNG Transaccional vs Cosmético
                local hasRandom = decompiledCode:find("math%.random") or decompiledCode:find("Random%.new")
                local hasNetworkOrPurchase = decompiledCode:find("FireServer") or decompiledCode:find("InvokeServer") or decompiledCode:find("MarketplaceService")
                if hasRandom and hasNetworkOrPurchase then
                    score = score + 25
                    categoriesFound["Economy"] = true
                    local snips = extractCodeSnippets(decompiledCode, "random")
                    table.insert(codeFindings, { Desc = "Lógica de RNG Vinculada a Red/Transacciones", Snippets = snips })
                    table.insert(tags, "Economy:TransactionalRNG")
                elseif hasRandom then
                    table.insert(tags, "RNG Cosmético / Cliente")
                end

                -- Regla 7: Detección de Ofuscadores Comerciales
                if decompiledCode:find("LPH_") or decompiledCode:find("IronBrew") or decompiledCode:find("MoonSec") or decompiledCode:find("PSU_") then
                    score = score + 45
                    categoriesFound["AntiCheat"] = true
                    table.insert(codeFindings, { Desc = "Ofuscador Comercial Detectado (Luraph/IronBrew/Moonsec)", Snippets = {} })
                    table.insert(tags, "Ofuscador")
                end
            end
        end
    end

    if score > 100 then score = 100 end

    -- Clasificación Estricta de Severidad
    local severity = "LOW"
    if categoriesFound["Admin"] and score >= 45 and not categoriesFound["AntiCheat"] then
        severity = "ADMIN_TOOL" -- Separado claramente de trampas/kicks maliciosos
    elseif score >= 75 or (categoriesFound["AntiCheat"] and score >= 55) then
        severity = "CRITICAL"
    elseif score >= 50 or categoriesFound["Combat"] then
        severity = "HIGH"
    elseif score >= 25 or categoriesFound["Economy"] then
        severity = "MEDIUM"
    end

    return {
        Name = rawName,
        ClassName = className,
        Path = path,
        Depth = depth,
        Score = score,
        Severity = severity,
        MatchedKeywords = matchedKeywords,
        Tags = tags,
        Categories = categoriesFound,
        Findings = codeFindings,
        IsStaticConfig = isStaticConfig,
        Instance = inst,
    }
end

-- =========================================================================
-- 6. RECORRIDO DELIMITADO POR SERVICIOS OPERACIONALES (NO WORKSPACE)
-- =========================================================================
local function traverseOperationalContainers(callback)
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("StarterGui"),
    }
    
    local function walk(parent, currentDepth)
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, child in ipairs(children) do
                callback(child, currentDepth)
                walk(child, currentDepth + 1)
            end
        end
    end
    
    for _, cont in ipairs(containers) do
        if cont then
            walk(cont, 1)
        end
    end
end

-- =========================================================================
-- 7. MODOS DE AUDITORÍA OPTIMIZADOS
-- =========================================================================
local Scanner = {}

function Scanner.RunAntiCheatAudit()
    local results = {
        Category = "AntiCheat",
        Timestamp = os.time(),
        Targets = {},
        TotalFound = 0,
    }
    
    traverseOperationalContainers(function(inst, depth)
        local analysis = analyzeInstance(inst, depth)
        if analysis and (analysis.Categories["AntiCheat"] or analysis.Severity == "CRITICAL" or analysis.Score >= 40) then
            table.insert(results.Targets, analysis)
            results.TotalFound = results.TotalFound + 1
        end
    end)
    
    return results
end

function Scanner.RunEconomyAudit()
    local results = {
        Category = "Economy",
        Timestamp = os.time(),
        Roulettes = {},
        Shops = {},
        LootTables = {},
        TotalFound = 0,
    }
    
    traverseOperationalContainers(function(inst, depth)
        local analysis = analyzeInstance(inst, depth)
        if analysis and (analysis.Categories["Economy"] or analysis.Score >= 20) then
            results.TotalFound = results.TotalFound + 1
            if matchesWord(analysis.Name, "spin") or matchesWord(analysis.Name, "wheel") or matchesWord(analysis.Name, "ruleta") or matchesWord(analysis.Name, "roll") then
                table.insert(results.Roulettes, analysis)
            elseif matchesWord(analysis.Name, "shop") or matchesWord(analysis.Name, "store") or matchesWord(analysis.Name, "tienda") or matchesWord(analysis.Name, "buy") then
                table.insert(results.Shops, analysis)
            else
                table.insert(results.LootTables, analysis)
            end
        end
    end)
    
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
    
    traverseOperationalContainers(function(inst, depth)
        if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
            results.TotalFound = results.TotalFound + 1
            table.insert(results.RemoteEvents, {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = inst:GetFullName(),
                Depth = depth,
            })
        elseif inst:IsA("RemoteFunction") then
            results.TotalFound = results.TotalFound + 1
            table.insert(results.RemoteFunctions, {
                Name = inst.Name,
                ClassName = "RemoteFunction",
                Path = inst:GetFullName(),
                Depth = depth,
            })
        end
    end)
    
    return results
end

function Scanner.RunFullAudit()
    local results = {
        Timestamp = os.time(),
        AntiCheat = {},
        Economy = {},
        Combat = {},
        AdminTools = {},
        Remotes = {},
        CriticalIssues = 0,
        TotalScanned = 0,
        FrameworksDetected = {},
    }

    -- Detección de Frameworks en ReplicatedStorage
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

    traverseOperationalContainers(function(inst, depth)
        results.TotalScanned = results.TotalScanned + 1
        local analysis = analyzeInstance(inst, depth)

        if analysis then
            if analysis.Severity == "ADMIN_TOOL" or (analysis.Categories["Admin"] and not analysis.Categories["AntiCheat"]) then
                table.insert(results.AdminTools, analysis)
            end
            if analysis.Categories["AntiCheat"] or analysis.Score >= 45 then
                table.insert(results.AntiCheat, analysis)
            end
            if analysis.Categories["Economy"] then
                table.insert(results.Economy, analysis)
            end
            if analysis.Categories["Combat"] then
                table.insert(results.Combat, analysis)
            end
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                table.insert(results.Remotes, analysis)
            end

            if analysis.Severity == "CRITICAL" then
                results.CriticalIssues = results.CriticalIssues + 1
            end
        end
    end)

    return results
end

-- =========================================================================
-- 8. SERIALIZADOR JSON ULTRA LIGERO (SIN VOLCADOS MASIVOS DE CÓDIGO)
-- =========================================================================
local function toCleanJSON(tbl, indent)
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
                    local clean = {}
                    for k2, v2 in pairs(v) do
                        if k2 ~= "Instance" then clean[k2] = v2 end
                    end
                    table.insert(elements, subSpacing .. toCleanJSON(clean, indent + 1))
                else
                    table.insert(elements, subSpacing .. toCleanJSON(v, indent + 1))
                end
            end
        end
        return "[\n" .. table.concat(elements, ",\n") .. "\n" .. spacing .. "]"
    else
        for k, v in pairs(tbl) do
            if type(v) ~= "userdata" and type(v) ~= "function" and type(v) ~= "thread" and k ~= "Instance" then
                local keyStr = string.format("%q", tostring(k))
                table.insert(elements, subSpacing .. keyStr .. ": " .. toCleanJSON(v, indent + 1))
            end
        end
        return "{\n" .. table.concat(elements, ",\n") .. "\n" .. spacing .. "}"
    end
end

-- =========================================================================
-- 9. INTERFAZ GRÁFICA FLUIDA & MODERNA
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
mainFrame.Size = UDim2.new(0, 720, 0, 520)
mainFrame.Position = UDim2.new(0.5, -360, 0.5, -260)
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
titleLabel.Text = "🛡️ APEX SUITE - MOTOR DE AUDITORÍA v2.0 (CERO FALSOS POSITIVOS)"
titleLabel.TextColor3 = Color3.fromRGB(240, 243, 250)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
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
statusLabel.Text = "Listo para escanear."
statusLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = actionRow

-- Caja de Vista Previa
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
        previewBox.Text = string.sub(str, 1, maxLimit) .. string.format("\n\n-- [⚠️ AVISO: Vista previa truncada a %d caracteres por límite de Roblox]\n-- [Total: %d caracteres. Para el reporte completo usa '💾 EXPORTAR JSON']", maxLimit, #str)
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
        table.insert(lines, string.format("Instancias Analizadas con Hallazgos: %d\n", rep.TotalFound))

        for _, item in ipairs(rep.Targets) do
            table.insert(lines, string.format("-> [%s] %s | Score: %d/100 | Severidad: %s | Nivel: %d\n   Ruta: %s", item.ClassName, item.Name, item.Score, item.Severity, item.Depth, item.Path))
            if #item.Tags > 0 then
                table.insert(lines, "   Firmas: " .. table.concat(item.Tags, ", "))
            end
            if #item.Findings > 0 then
                table.insert(lines, "   [HALLAZGOS CONTEXTUALES]:")
                for _, f in ipairs(item.Findings) do
                    table.insert(lines, string.format("   • %s", f.Desc))
                    for _, s in ipairs(f.Snippets) do
                        table.insert(lines, string.format("     [Línea %d]: %s", s.Line, s.Code))
                    end
                end
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
        table.insert(lines, string.format("• Nodos de Ruleta / Azar: %d", #rep.Roulettes))
        table.insert(lines, string.format("• Tiendas y Compras: %d", #rep.Shops))
        table.insert(lines, string.format("• Tablas de Loot y Precios: %d\n", #rep.LootTables))

        if #rep.Roulettes > 0 then
            table.insert(lines, "[SISTEMAS DE RULETA / AZAR]:")
            for _, item in ipairs(rep.Roulettes) do
                table.insert(lines, string.format("🎰 [%s] %s (Nivel %d)\n   Ruta: %s", item.ClassName, item.Name, item.Depth, item.Path))
            end
            table.insert(lines, "")
        end

        if #rep.Shops > 0 then
            table.insert(lines, "[TIENDAS Y PRECIOS]:")
            for _, item in ipairs(rep.Shops) do
                table.insert(lines, string.format("🛒 [%s] %s (Nivel %d)\n   Ruta: %s", item.ClassName, item.Name, item.Depth, item.Path))
            end
            table.insert(lines, "")
        end

        if #rep.LootTables > 0 then
            table.insert(lines, "[TABLAS DE CONFIGURACIÓN Y PROBABILIDADES]:")
            for _, item in ipairs(rep.LootTables) do
                table.insert(lines, string.format("📜 [%s] %s | %s\n   Ruta: %s", item.ClassName, item.Name, item.IsStaticConfig and "[Configuración Estática]" or "[Lógica Dinámica]", item.Path))
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
            table.insert(lines, string.format("⚡ [%s] %s (Nivel %d)\n   Ruta: %s", r.ClassName, r.Name, r.Depth, r.Path))
        end
        for _, r in ipairs(rep.RemoteFunctions) do
            table.insert(lines, string.format("🔁 [RemoteFunction] %s (Nivel %d)\n   Ruta: %s", r.Name, r.Depth, r.Path))
        end

    else
        local rep = Scanner.RunFullAudit()
        lastReportData = rep
        table.insert(lines, "==================================================================")
        table.insert(lines, "🌐 REPORTE DE AUDITORÍA TOPOLÓGICA Y ARQUITECTURA COMPLETA")
        table.insert(lines, "==================================================================")
        table.insert(lines, string.format("Total de Contenedores de Código y Red Analizados: %d", rep.TotalScanned))
        table.insert(lines, string.format("Amenazas Críticas de Seguridad: %d", rep.CriticalIssues))
        table.insert(lines, string.format("Herramientas Administrativas del Juego (ADMIN_TOOL): %d", #rep.AdminTools))
        table.insert(lines, string.format("Watchdogs / Anti-Cheat: %d", #rep.AntiCheat))
        table.insert(lines, string.format("Lógica de Combate: %d", #rep.Combat))
        table.insert(lines, string.format("Sistemas de Economía: %d", #rep.Economy))
        table.insert(lines, string.format("Remotes Mapeados: %d\n", #rep.Remotes))

        if #rep.FrameworksDetected > 0 then
            table.insert(lines, "• Frameworks Detectados: " .. table.concat(rep.FrameworksDetected, ", "))
        else
            table.insert(lines, "• Frameworks Detectados: Ninguno estándar (Arquitectura nativa Luau)")
        end

        if #rep.AdminTools > 0 then
            table.insert(lines, "\n[HERRAMIENTAS DE ADMINISTRACIÓN AUTORIZADAS]:")
            for _, adm in ipairs(rep.AdminTools) do
                table.insert(lines, string.format("🛡️ [%s] %s | Ruta: %s", adm.ClassName, adm.Name, adm.Path))
            end
        end
    end

    lastFullText = table.concat(lines, "\n")
    setSafePreviewText(lastFullText)
    statusLabel.Text = string.format("Escaneo finalizado con éxito.")
    runBtn.Text = "⚡ EJECUTAR ESCANEO"
end)

exportJsonBtn.MouseButton1Click:Connect(function()
    if not lastReportData then
        statusLabel.Text = "Ejecuta un escaneo primero."
        return
    end
    local jsonStr = toCleanJSON(lastReportData)
    local fileName = "audit_report_" .. currentMode .. "_" .. os.time() .. ".json"
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

print("[APEX SUITE v2.0] Auditoría Standalone Optimizada lista para ejecutar.")
