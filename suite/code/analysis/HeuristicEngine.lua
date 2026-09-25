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

function HeuristicEngine:MatchesKeyword(targetText, keyword)
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

function HeuristicEngine:CalculateEntropy(str)
    if not str or #str == 0 then return 0 end
    local counts = {}
    local len = #str
    for i = 1, len do
        local byte = string.byte(str, i)
        counts[byte] = (counts[byte] or 0) + 1
    end
    local entropy = 0
    for _, count in pairs(counts) do
        local p = count / len
        entropy = entropy - (p * (math.log(p) / math.log(2)))
    end
    return entropy
end

function HeuristicEngine:AnalyzeInstance(instance)
    if self:IsIgnoredCoreInstance(instance) then
        return {
            Instance = instance,
            Name = instance.Name,
            ClassName = instance.ClassName,
            Path = instance:GetFullName(),
            Score = 0,
            Severity = HeuristicEngine.Severity.LOW,
            MatchedKeywords = {},
            Tags = { "Ignored: Core Roblox Script" },
            Categories = {},
            Code = nil,
            IsIgnored = true,
        }
    end

    local rawName = instance.Name
    local className = instance.ClassName
    local path = instance:GetFullName()
    local score = 0
    local matchedKeywords = {}
    local tags = {}
    local categoriesFound = {}
    
    -- 1. Análisis Multilingüe de Nombres con límites de palabra estrictos
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
    
    -- 2. SINCRONIZACIÓN TOPOLÓGICA (Ponderación por ubicación estándar del motor)
    local repFirst = game:GetService("ReplicatedFirst")
    if repFirst and instance:IsDescendantOf(repFirst) then
        score = score + 20
        table.insert(tags, "Topología: ReplicatedFirst (Early Bootloader)")
        categoriesFound["AntiCheat"] = true
    end
    
    -- 3. Análisis de Profundidad y Entropía
    local depth = 0
    local curr = instance.Parent
    while curr and curr ~= game do
        depth = depth + 1
        curr = curr.Parent
    end
    
    local nameEntropy = self:CalculateEntropy(rawName)
    if nameEntropy > 4.2 and #rawName > 10 then
        score = score + 20
        table.insert(tags, string.format("Alta Entropía (%.2f) - Posible Ofuscación", nameEntropy))
    end
    if depth > 8 then
        score = score + 10
        table.insert(tags, string.format("Árbol Profundo (%d niveles)", depth))
    end
    
    -- 4. Inspección de Atributos y Configuraciones
    local successAttrs, attrs = pcall(function() return instance:GetAttributes() end)
    if successAttrs and attrs then
        for attrName, attrVal in pairs(attrs) do
            for catName, keywords in pairs(self.Lexicon) do
                for _, kw in ipairs(keywords) do
                    if self:MatchesKeyword(tostring(attrName), kw) then
                        score = score + 10
                        table.insert(tags, "Attr:" .. attrName)
                        categoriesFound[catName] = true
                        break
                    end
                end
            end
        end
    end
    
    -- 5. Análisis Profundo de Código (Scripts y Módulos)
    local decompiledCode = nil
    if instance:IsA("LuaSourceContainer") then
        decompiledCode = self.Caps:SafeDecompile(instance)
        if decompiledCode and not decompiledCode:find("%[Decompilación no soportada") then
            -- Búsqueda de firmas estáticas
            for _, sig in ipairs(self.CodeSignatures) do
                if string.find(decompiledCode, sig.Pattern) then
                    score = score + sig.Score
                    table.insert(tags, sig.Desc)
                    categoriesFound[sig.Category] = true
                end
            end
            
            -- Análisis multilingüe dentro del propio código con límites de palabra
            for catName, keywords in pairs(self.Lexicon) do
                for _, kw in ipairs(keywords) do
                    if self:MatchesKeyword(decompiledCode, kw) then
                        score = score + 5
                        categoriesFound[catName] = true
                        break
                    end
                end
            end
            
            -- Detección de ofuscadores conocidos
            if decompiledCode:find("LPH_") or decompiledCode:find("IronBrew") or decompiledCode:find("MoonSec") or decompiledCode:find("PSU_") then
                score = score + 40
                table.insert(tags, "Ofuscador Comercial Detectado (Luraph/IronBrew/Moonsec)")
            end
        end
    end
    
    -- Normalizar Score a máximo 100
    if score > 100 then score = 100 end
    
    -- Determinar Severidad
    local severity = HeuristicEngine.Severity.LOW
    if score >= 75 or (categoriesFound["AntiCheat"] and score >= 55) or (categoriesFound["Admin"] and score >= 50) then
        severity = HeuristicEngine.Severity.CRITICAL
    elseif score >= 50 or categoriesFound["Combat"] or categoriesFound["Admin"] then
        severity = HeuristicEngine.Severity.HIGH
    elseif score >= 25 or categoriesFound["Economy"] then
        severity = HeuristicEngine.Severity.MEDIUM
    end
    
    return {
        Instance = instance,
        Name = rawName,
        ClassName = className,
        Path = path,
        Score = score,
        Severity = severity,
        MatchedKeywords = matchedKeywords,
        Tags = tags,
        Categories = categoriesFound,
        Code = decompiledCode,
    }
end

function HeuristicEngine:RunFullAudit(targetContainers)
    local results = {
        AntiCheat = {},
        Economy = {},
        Combat = {},
        Admin = {},
        Remotes = {},
        CriticalIssues = 0,
        TotalScanned = 0,
        StructuralProfile = nil,
    }
    
    if self.Structural then
        results.StructuralProfile = self.Structural:GenerateReport()
    end
    
    local containers = targetContainers or {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
    }
    
    for _, container in ipairs(containers) do
        if container then
            local success, descendants = pcall(function() return container:GetDescendants() end)
            if success and descendants then
                for _, inst in ipairs(descendants) do
                    results.TotalScanned = results.TotalScanned + 1
                    local analysis = self:AnalyzeInstance(inst)
                    
                    if not analysis.IsIgnored and (analysis.Score > 0 or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
                        if analysis.Categories["AntiCheat"] or analysis.Score >= 50 then
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
                        
                        if analysis.Severity == HeuristicEngine.Severity.CRITICAL then
                            results.CriticalIssues = results.CriticalIssues + 1
                        end
                    end
                end
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo Heurístico-Topológico Sincronizado Completado: %d objetos analizados, %d remotes, %d amenazas críticas.", results.TotalScanned, #results.Remotes, results.CriticalIssues))
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
    
    local locations = customLocations or {
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("ReplicatedStorage"),
        game:GetService("RobloxReplicatedStorage"),
    }
    
    for _, loc in ipairs(locations) do
        if loc then
            local s, desc = pcall(function() return loc:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    local analysis = self:AnalyzeInstance(inst)
                    if not analysis.IsIgnored and (analysis.Categories["AntiCheat"] or analysis.Score >= 40) then
                        table.insert(report.Targets, analysis)
                        report.TotalFound = report.TotalFound + 1
                    end
                end
            end
        end
    end
    
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
    
    local locations = customLocations or {
        game:GetService("ReplicatedStorage"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
    }
    
    for _, loc in ipairs(locations) do
        if loc then
            local s, desc = pcall(function() return loc:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    local analysis = self:AnalyzeInstance(inst)
                    if not analysis.IsIgnored and analysis.Categories["Economy"] then
                        table.insert(report.Targets, analysis)
                        report.TotalFound = report.TotalFound + 1
                    end
                end
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo de Economía/Ruletas finalizado: %d elementos encontrados.", report.TotalFound))
    end
    
    return report
end

-- 3. Escaneo Dedicado de Todos los Remotes del Juego
function HeuristicEngine:RunRemotesAudit()
    local report = {
        Category = "Remotes",
        Timestamp = tick(),
        RemoteEvents = {},
        RemoteFunctions = {},
        TotalFound = 0,
    }
    
    local s, desc = pcall(function() return game:GetDescendants() end)
    if s and desc then
        for _, inst in ipairs(desc) do
            if not self:IsIgnoredCoreInstance(inst) then
                if inst:IsA("RemoteEvent") then
                    table.insert(report.RemoteEvents, {
                        Name = inst.Name,
                        Path = inst:GetFullName(),
                        Instance = inst,
                    })
                    report.TotalFound = report.TotalFound + 1
                elseif inst:IsA("RemoteFunction") then
                    table.insert(report.RemoteFunctions, {
                        Name = inst.Name,
                        Path = inst:GetFullName(),
                        Instance = inst,
                    })
                    report.TotalFound = report.TotalFound + 1
                end
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Mapeo de Remotes finalizado: %d RemoteEvents, %d RemoteFunctions.", #report.RemoteEvents, #report.RemoteFunctions))
    end
    
    return report
end

return HeuristicEngine
