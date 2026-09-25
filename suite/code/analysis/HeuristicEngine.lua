--[[
    =============================================================================
    APEX SUITE - ADVANCED HEURISTIC ENGINE (SYNCHRONIZED WITH STRUCTURAL & STATS)
    =============================================================================
    Motor de análisis de seguridad avanzado sincronizado con el Perfilador
    Topológico y Estadístico, detección multilingüe, análisis de entropía y scoring
    contextual de vulnerabilidades (0-100).
--]]

local HeuristicEngine = {}
HeuristicEngine.__index = HeuristicEngine
HeuristicEngine.ClassName = "HeuristicEngine"

HeuristicEngine.Severity = {
    CRITICAL = 4, -- 80 - 100 pts (Bans, kicks, anticheat traps, auth bypass)
    HIGH     = 3, -- 60 - 79 pts (Currency, purchase, unvalidated damage, combat)
    MEDIUM   = 2, -- 30 - 59 pts (State sync, movement, stats, cooldowns)
    LOW      = 1, -- 0  - 29 pts (Cosmetics, particles, effects, UI)
}

function HeuristicEngine.new(capabilityManager, logger, structuralProfiler)
    local self = setmetatable({}, HeuristicEngine)
    self.Caps = capabilityManager
    self.Logger = logger
    self.Structural = structuralProfiler
    self.DecompCache = setmetatable({}, { __mode = "k" }) -- Caché global en memoria compartida (Lazy Evaluation)
    
    -- DICCIONARIO MULTILINGÜE INTEGRADO DE FIRMAS
    self.Lexicon = {
        AntiCheat = {
            -- Inglés
            "detect", "kick", "ban", "report", "exploit", "cheat", "integrity",
            "watchdog", "tamper", "anticheat", "security", "heartbeat", "noclip",
            "walkspeed", "jumppower", "teleport", "hook", "metatable", "memscan",
            "gcscan", "debug", "honeypot", "tripwire", "flag", "punish", "blacklist",
            -- Chino (中文)
            "检测", "作弊", "外挂", "封号", "封禁", "踢出", "安全", "防封",
            "监控", "反作弊", "查外挂", "异常", "挂机", "校验", "拦截", "风控",
            -- Japonés (日本語)
            "検知", "チート", "不正", "監視", "追放", "セキュリティ", "対策", "報告",
            -- Ruso (Русский)
            "чит", "бан", "кик", "проверка", "защита", "античит", "репорт", "эксплоит",
            -- Español / Portugués
            "seguridad", "bloqueo", "trampa", "expulsion", "baneo", "anticheat", "vigilante"
        },
        
        Economy = {
            -- Inglés
            "spin", "wheel", "roll", "luck", "chance", "mutation", "fuse", "trait",
            "shop", "buy", "purchase", "gem", "coin", "currency", "crate", "unbox",
            "gacha", "reward", "claim", "odds", "drop", "rarity", "egg", "hatch",
            "rebirth", "multiplier", "boost", "cash", "diamond", "inventory", "trade",
            -- Chino (中文)
            "抽奖", "抽卡", "轮盘", "扭蛋", "转盘", "概率", "几率", "爆率", "暴击",
            "商店", "购买", "金币", "钻石", "充值", "背包", "道具", "宠物", "孵化",
            "转生", "强化", "交易", "合成", "奖励", "领取", "稀有度", "元宝",
            -- Japonés (日本語)
            "ガチャ", "ルーレット", "確率", "購入", "ショップ", "卵", "孵化", "報酬", "転生",
            -- Ruso (Русский)
            "рулетка", "шанс", "магазин", "покупка", "донат", "яйцо", "питомец", "награда",
            -- Español / Portugués
            "ruleta", "giro", "probabilidad", "tienda", "comprar", "gemas", "recompensa", "monedas"
        },
        
        Combat = {
            -- Inglés
            "damage", "hit", "attack", "kill", "health", "hp", "strike", "slash",
            "bullet", "shoot", "cast", "spell", "godmode", "invincible", "stamina",
            -- Chino (中文)
            "伤害", "攻击", "击杀", "血量", "生命", "无敌", "受击", "技能", "子弹", "射击",
            -- Japonés (日本語)
            "ダメージ", "攻撃", "スキル", "体力", "無敵", "撃破",
            -- Ruso (Русский)
            "урон", "атака", "хп", "убийство", "бессмертие", "скилл"
        },
        
        Admin = {
            -- Inglés
            "admin", "command", "exec", "backdoor", "rank", "permission", "superadmin",
            -- Chino (中文)
            "管理", "指令", "权限", "后门", "管理员", "命令",
            -- Japonés (日本語)
            "管理者", "コマンド", "権限",
            -- Ruso (Русский)
            "админ", "команды", "консоль", "права"
        }
    }
    
    -- Firmas estáticas de código / regex
    self.CodeSignatures = {
        { Pattern = "getrawmetatable", Score = 35, Desc = "Inspección/Manipulación de Metatablas", Category = "AntiCheat" },
        { Pattern = "hookfunction", Score = 40, Desc = "Hooking de Funciones Detectado", Category = "AntiCheat" },
        { Pattern = "GetPropertyChangedSignal%([\"']WalkSpeed[\"']%)", Score = 30, Desc = "Watchdog de Velocidad (WalkSpeed)", Category = "AntiCheat" },
        { Pattern = "GetPropertyChangedSignal%([\"']JumpPower[\"']%)", Score = 25, Desc = "Watchdog de Salto (JumpPower)", Category = "AntiCheat" },
        { Pattern = "debug%.info", Score = 30, Desc = "Inspección de Callstack / Debug Traps", Category = "AntiCheat" },
        { Pattern = "LocalPlayer:Kick", Score = 50, Desc = "Llamada Directa a Expulsión (LocalPlayer:Kick)", Category = "AntiCheat" },
        { Pattern = "math%.random", Score = 15, Desc = "Generación de Números Aleatorios en Cliente", Category = "Economy" },
        { Pattern = "Random%.new", Score = 15, Desc = "Instanciación de RNG en Cliente", Category = "Economy" },
        { Pattern = "FireServer%(.*[Dd]amage.*%)", Score = 35, Desc = "Disparo de Daño desde el Cliente", Category = "Combat" },
        -- Firmas de Capacidades Críticas de Modding / Admin Abuse
        { Pattern = "BodyVelocity", Score = 35, Desc = "Manipulación de Vuelo / Física Forzada (BodyVelocity)", Category = "Admin" },
        { Pattern = "BodyGyro", Score = 25, Desc = "Manipulación de Orientación / Vuelo (BodyGyro)", Category = "Admin" },
        { Pattern = "CanCollide%s*=%s*false", Score = 40, Desc = "Rutina de Noclip en tiempo de ejecución", Category = "Admin" },
        { Pattern = "_G%.", Score = 20, Desc = "Exposición de Variables Globales en Memoria (_G)", Category = "Admin" },
    }
    
    return self
end

function HeuristicEngine:IsIgnoredCoreInstance(instance)
    local fullName = instance:GetFullName()
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

function HeuristicEngine:IsPrunedBranch(instance)
    local name = instance.Name:lower()
    -- Poda drástica de ramas de recursos visuales y físicos (O(1))
    local visualAssets = {
        assets = true, models = true, sounds = true, audio = true,
        animations = true, textures = true, meshes = true, fx = true,
        worldfx = true, map = true, vfx = true, lighting = true,
        decals = true, particles = true, npcs = true, terrain = true,
        camera = true, props = true, effects = true, visual = true,
    }
    
    if visualAssets[name] then
        -- Salvo que contenga explícitamente palabras de código
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network")) then
            return true
        end
    end
    
    -- Si es una pieza 3D pura o malla, no descender
    if instance:IsA("BasePart") or instance:IsA("MeshPart") or instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("Sound") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
        return true
    end
    
    return false
end

function HeuristicEngine:MatchesKeyword(targetText, keyword)
    if not targetText or not keyword then return false end
    local lowerText = targetText:lower()
    local lowerKw = keyword:lower()
    
    if lowerKw:find("^[_%W]") or lowerKw:find("[_%W]$") or lowerKw:match("[^\32-\126]") then
        return string.find(lowerText, lowerKw, 1, true) ~= nil
    end
    
    local pattern = "%f[%w]" .. lowerKw .. "%f[%W]"
    return string.find(lowerText, pattern) ~= nil
end

function HeuristicEngine:IsExecutableOrNetwork(instance)
    return instance:IsA("LuaSourceContainer") or instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")
end

function HeuristicEngine:IsStaticDataModule(code)
    if not code or #code == 0 then return false end
    local hasReturn = code:find("return%s+{") or code:find("return%s+setmetatable")
    local hasLoops = code:find("while%s+") or code:find("for%s+") or code:find("repeat%s+")
    local hasServices = code:find("GetService") or code:find("FireServer") or code:find("InvokeServer") or code:find("Connect%(")
    return hasReturn and not hasLoops and not hasServices
end

function HeuristicEngine:SafeDecompileWithCache(instance)
    if not instance:IsA("LuaSourceContainer") then return nil end
    
    -- 1. Descarte de scripts desactivados
    if instance:IsA("BaseScript") and instance.Disabled then
        return nil
    end
    
    -- 2. Verificación en Caché (O(1))
    if self.DecompCache[instance] ~= nil then
        return self.DecompCache[instance]
    end
    
    if not self.Caps or not self.Caps.Capabilities.HasDecompiler then
        self.DecompCache[instance] = false
        return nil
    end
    
    -- 3. Descompilación protegida con limitador de tamaño
    local s, code = pcall(function()
        return decompile(instance)
    end)
    
    if s and type(code) == "string" and #code > 0 and not code:find("%[Decompilación no soportada") then
        -- Truncar análisis si el archivo es gigantesco (> 50,000 caracteres) para evitar saturar el analizador
        if #code > 50000 then
            code = code:sub(1, 50000)
        end
        self.DecompCache[instance] = code
        return code
    end
    
    self.DecompCache[instance] = false
    return nil
end

function HeuristicEngine:ExtractCodeSnippets(code, pattern, maxSnippets)
    maxSnippets = maxSnippets or 2
    if not code or #code == 0 then return {} end
    
    -- Comprobación previa de subcadena rápida: Si la palabra no existe en todo el texto, retornar inmediatamente sin partir líneas
    local rawKeyword = pattern:gsub("%%", ""):gsub("%[.-%]", ""):gsub("%(.-%)", "")
    if #rawKeyword > 2 and not code:find(rawKeyword, 1, true) and not code:find(pattern) then
        return {}
    end
    
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

function HeuristicEngine:AnalyzeInstance(instance, depth)
    depth = depth or 0
    -- 1. FILTRADO PREMATURO: Si no es ejecutable ni red, descartar en O(1)
    if not self:IsExecutableOrNetwork(instance) then
        return nil
    end

    local path = instance:GetFullName()
    -- 2. Descarte de Core Roblox
    if self:IsIgnoredCoreInstance(instance) then
        return nil
    end

    local rawName = instance.Name
    local className = instance.ClassName
    local score = 0
    local matchedKeywords = {}
    local tags = {}
    local categoriesFound = {}
    local codeFindings = {}
    local isStaticConfig = false
    local isRem = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")

    -- 3. Análisis de Nombres con límites de palabra estrictos
    for catName, keywords in pairs(self.Lexicon) do
        for _, kw in ipairs(keywords) do
            if self:MatchesKeyword(rawName, kw) then
                local weight = (catName == "AntiCheat" and 25) or (catName == "Admin" and 20) or 15
                score = score + weight
                table.insert(matchedKeywords, string.format("[%s]: %s", catName, kw))
                table.insert(tags, catName)
                categoriesFound[catName] = true
                break
            end
        end
    end

    -- 4. Ponderación Topológica de Ubicación
    if string.find(path, "ReplicatedFirst") then
        score = score + 30
        table.insert(tags, "Topología: ReplicatedFirst (Early Boot)")
        categoriesFound["AntiCheat"] = true
    elseif string.find(path, "PlayerScripts") or string.find(path, "StarterPlayer") then
        score = score + 10
    end

    -- 5. Ponderación por Clase de Red
    if isRem then
        score = score + 15
        table.insert(tags, "Clase: " .. className)
        categoriesFound["Remotes"] = true
    end

    -- 6. Análisis Profundo de Código con Descompilación Perezosa y Caché
    if instance:IsA("LuaSourceContainer") then
        local decompiledCode = self:SafeDecompileWithCache(instance)
        if decompiledCode then
            if instance:IsA("ModuleScript") and self:IsStaticDataModule(decompiledCode) then
                isStaticConfig = true
                table.insert(tags, "Tipo: Módulo de Configuración Estática")
            else
                -- Regla 1: Kick
                if decompiledCode:find("LocalPlayer:Kick") or decompiledCode:find("Players%.LocalPlayer:Kick") then
                    score = score + 45
                    categoriesFound["AntiCheat"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "Kick")
                    table.insert(codeFindings, { Desc = "Llamada Directa a Expulsión (LocalPlayer:Kick)", Snippets = snips })
                    table.insert(tags, "Kick")
                end

                -- Regla 2: Metatables / Debug
                if decompiledCode:find("hookmetamethod") or decompiledCode:find("getrawmetatable") then
                    score = score + 30
                    categoriesFound["AntiCheat"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "metatable")
                    table.insert(codeFindings, { Desc = "Manipulación/Auditoría de Metatablas", Snippets = snips })
                    table.insert(tags, "Metatables")
                end

                if decompiledCode:find("debug%.info") or decompiledCode:find("debug%.traceback") then
                    score = score + 20
                    categoriesFound["AntiCheat"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "debug%.")
                    table.insert(codeFindings, { Desc = "Introspección de Callstack / Trap", Snippets = snips })
                    table.insert(tags, "DebugTrap")
                end

                -- Regla 3: Noclip Contextualizado (Character + Loop)
                local hasCanCollide = decompiledCode:find("CanCollide%s*=%s*false")
                local hasBodyParts = decompiledCode:find("HumanoidRootPart") or decompiledCode:find("Torso") or decompiledCode:find("Character")
                local hasLoop = decompiledCode:find("RenderStepped") or decompiledCode:find("Heartbeat") or decompiledCode:find("Stepped")
                if hasCanCollide and hasBodyParts and hasLoop then
                    score = score + 40
                    categoriesFound["Admin"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "CanCollide")
                    table.insert(codeFindings, { Desc = "Rutina Continua de Noclip en Character (RenderStepped)", Snippets = snips })
                    table.insert(tags, "Noclip:Contextual")
                end

                -- Regla 4: Fly / BodyVelocity
                if decompiledCode:find("BodyVelocity") and (decompiledCode:find("HumanoidRootPart") or decompiledCode:find("Torso")) then
                    score = score + 35
                    categoriesFound["Admin"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "BodyVelocity")
                    table.insert(codeFindings, { Desc = "Manipulación de Vuelo / Fuerza Física (BodyVelocity)", Snippets = snips })
                    table.insert(tags, "Fly:BodyVelocity")
                end

                -- Regla 5: Estado Global (_G / shared)
                if decompiledCode:find("_G%.__") or decompiledCode:find("shared%.__") then
                    score = score + 20
                    categoriesFound["Admin"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "_G%.")
                    table.insert(codeFindings, { Desc = "Exposición de Funciones/Banderas Globales (_G/shared)", Snippets = snips })
                    table.insert(tags, "GlobalState")
                end

                -- Regla 6: RNG Transaccional vs Cosmético
                local hasRandom = decompiledCode:find("math%.random") or decompiledCode:find("Random%.new")
                local hasNetworkOrPurchase = decompiledCode:find("FireServer") or decompiledCode:find("InvokeServer") or decompiledCode:find("MarketplaceService")
                if hasRandom and hasNetworkOrPurchase then
                    score = score + 25
                    categoriesFound["Economy"] = true
                    local snips = self:ExtractCodeSnippets(decompiledCode, "random")
                    table.insert(codeFindings, { Desc = "Lógica de RNG Vinculada a Red/Transacciones", Snippets = snips })
                    table.insert(tags, "Economy:TransactionalRNG")
                elseif hasRandom then
                    table.insert(tags, "RNG Cosmético / Cliente")
                end

                -- Regla 7: Ofuscadores Comerciales
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

    -- Determinar Severidad y Categoría de Herramienta Administrativa
    local severity = HeuristicEngine.Severity.LOW
    if categoriesFound["Admin"] and score >= 45 and not categoriesFound["AntiCheat"] then
        severity = 5 -- ADMIN_TOOL
    elseif score >= 75 or (categoriesFound["AntiCheat"] and score >= 55) then
        severity = HeuristicEngine.Severity.CRITICAL
    elseif score >= 50 or categoriesFound["Combat"] then
        severity = HeuristicEngine.Severity.HIGH
    elseif score >= 25 or categoriesFound["Economy"] then
        severity = HeuristicEngine.Severity.MEDIUM
    end

    return {
        Instance = instance,
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
    }
end

function HeuristicEngine:TraverseOperationalContainers(targetContainers, callback)
    local containers = targetContainers or {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("StarterGui"),
    }
    
    local lastYield = tick()
    
    local function walk(parent, currentDepth)
        if self:IsIgnoredCoreInstance(parent) or self:IsPrunedBranch(parent) then
            return
        end
        
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, child in ipairs(children) do
                -- Time-Slicing cooperativo cada 12ms para mantener los FPS del juego fluidos
                if tick() - lastYield > 0.012 then
                    task.wait()
                    lastYield = tick()
                end
                
                if not self:IsIgnoredCoreInstance(child) then
                    callback(child, currentDepth)
                    if not self:IsPrunedBranch(child) then
                        walk(child, currentDepth + 1)
                    end
                end
            end
        end
    end
    
    for _, cont in ipairs(containers) do
        if cont then
            walk(cont, 1)
        end
    end
end

function HeuristicEngine:RunFullAudit(targetContainers)
    local results = {
        AntiCheat = {},
        Economy = {},
        Combat = {},
        AdminTools = {},
        Admin = {},
        Remotes = {},
        CriticalIssues = 0,
        TotalScanned = 0,
        StructuralProfile = nil,
    }
    
    if self.Structural then
        results.StructuralProfile = self.Structural:GenerateReport()
    end
    
    self:TraverseOperationalContainers(targetContainers, function(inst, depth)
        results.TotalScanned = results.TotalScanned + 1
        local analysis = self:AnalyzeInstance(inst, depth)
        
        if analysis then
            if analysis.Severity == 5 or (analysis.Categories["Admin"] and not analysis.Categories["AntiCheat"]) then
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
            if analysis.Categories["Admin"] then
                table.insert(results.Admin, analysis)
            end
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                table.insert(results.Remotes, analysis)
            end
            
            if analysis.Severity == HeuristicEngine.Severity.CRITICAL then
                results.CriticalIssues = results.CriticalIssues + 1
            end
        end
    end)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo Heurístico Sincronizado Completado: %d analizados, %d remotes, %d amenazas críticas.", results.TotalScanned, #results.Remotes, results.CriticalIssues))
    end
    
    return results
end

-- =========================================================================
-- MÉTODOS DE ESCANEO ESPECÍFICOS / DEDICADOS
-- =========================================================================

-- 1. Escaneo Dedicado de Anti-Cheat, Watchdogs e Integrity Checks
function HeuristicEngine:RunAntiCheatAudit(customLocations)
    local report = {
        Category = "AntiCheat",
        Timestamp = tick(),
        Targets = {},
        TotalFound = 0,
    }
    
    self:TraverseOperationalContainers(customLocations, function(inst, depth)
        local analysis = self:AnalyzeInstance(inst, depth)
        if analysis and (analysis.Categories["AntiCheat"] or analysis.Score >= 40) then
            table.insert(report.Targets, analysis)
            report.TotalFound = report.TotalFound + 1
        end
    end)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo de Anti-Cheat finalizado: %d watchdogs/kicks localizados.", report.TotalFound))
    end
    
    return report
end

-- 2. Escaneo Dedicado de Economía, Ruleta y Azar
function HeuristicEngine:RunEconomyAudit(customLocations)
    local report = {
        Category = "Economy",
        Timestamp = tick(),
        Targets = {},
        TotalFound = 0,
    }
    
    self:TraverseOperationalContainers(customLocations, function(inst, depth)
        local analysis = self:AnalyzeInstance(inst, depth)
        if analysis and (analysis.Categories["Economy"] or analysis.Score >= 20) then
            table.insert(report.Targets, analysis)
            report.TotalFound = report.TotalFound + 1
        end
    end)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo de Economía/Ruletas finalizado: %d elementos encontrados.", report.TotalFound))
    end
    
    return report
end

-- 3. Escaneo Dedicado de Todos los Remotes del Juego
function HeuristicEngine:RunRemotesAudit(customLocations)
    local report = {
        Category = "Remotes",
        Timestamp = tick(),
        RemoteEvents = {},
        RemoteFunctions = {},
        TotalFound = 0,
    }
    
    self:TraverseOperationalContainers(customLocations, function(inst, depth)
        if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
            table.insert(report.RemoteEvents, {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = inst:GetFullName(),
                Depth = depth,
                Instance = inst,
            })
            report.TotalFound = report.TotalFound + 1
        elseif inst:IsA("RemoteFunction") then
            table.insert(report.RemoteFunctions, {
                Name = inst.Name,
                ClassName = "RemoteFunction",
                Path = inst:GetFullName(),
                Depth = depth,
                Instance = inst,
            })
            report.TotalFound = report.TotalFound + 1
        end
    end)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Mapeo de Remotes finalizado: %d RemoteEvents, %d RemoteFunctions.", #report.RemoteEvents, #report.RemoteFunctions))
    end
    
    return report
end

return HeuristicEngine
