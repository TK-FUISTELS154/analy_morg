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
    -- NOTA: El caché de descompilación se gestiona EXCLUSIVAMENTE en CapabilityManager._decompCache
    -- NO crear cachés locales aquí. Usar self.Caps:SafeDecompile(instance) en todo momento.
    self.LastFullAudit = nil -- Resultados cacheados de auditoría completa para reutilización instantánea
    
    -- DICCIONARIO MULTILINGÜE INTEGRADO DE FIRMAS
    self.Lexicon = {
        AntiCheat = {
            -- Inglés
            "detect", "kick", "ban", "report", "exploit", "cheat", "integrity",
            "watchdog", "tamper", "anticheat", "security", "heartbeat",
            "walkspeed", "jumppower", "teleport", "hook", "metatable", "memscan",
            "gcscan", "honeypot", "tripwire", "flag", "punish", "blacklist",
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
        { Pattern = "debug%.info%s*%(%s*%d", Score = 30, Desc = "Inspección de Callstack / Debug Traps", Category = "AntiCheat" },
        { Pattern = "LocalPlayer:Kick", Score = 50, Desc = "Llamada Directa a Expulsión (LocalPlayer:Kick)", Category = "AntiCheat" },
        { Pattern = "FireServer%(.*[Dd]amage.*%)", Score = 35, Desc = "Disparo de Daño desde el Cliente", Category = "Combat" },
        -- Firmas de Capacidades Críticas de Modding / Admin Abuse
        { Pattern = "BodyVelocity", Score = 35, Desc = "Manipulación de Vuelo / Física Forzada (BodyVelocity)", Category = "Admin" },
        { Pattern = "BodyGyro", Score = 25, Desc = "Manipulación de Orientación / Vuelo (BodyGyro)", Category = "Admin" },
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
       or fullName:find("TestEZ")
       or fullName:find("TopbarPlus")
       or fullName:find("Packages")
       or fullName:find("_Index")
       or fullName:find("Janitor")
       or fullName:find("Promise")
       or fullName:find("Vendor")
       or fullName:find("pkg")
       or fullName:find("Roact")
       or fullName:find("Rodux")
       or fullName:find("Fusion")
       or fullName:find("Flipper")
       or fullName:find("GoodSignal")
       or fullName:find("Signal") then
        return true
    end
    return false
end

function HeuristicEngine:IsPrunedBranch(instance)
    local className = instance.ClassName
    
    -- 1. Poda inmediata por clase no ejecutable (O(1))
    if instance:IsA("BasePart") or instance:IsA("MeshPart") or instance:IsA("Decal") or instance:IsA("Texture")
       or instance:IsA("Sound") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")
       or instance:IsA("Highlight") or instance:IsA("Light") or instance:IsA("SurfaceAppearance")
       or instance:IsA("SpecialMesh") or instance:IsA("BlockMesh") or instance:IsA("CylinderMesh")
       or instance:IsA("UIComponent") or instance:IsA("UILayout") or instance:IsA("UIConstraint")
       or instance:IsA("UICorner") or instance:IsA("UIStroke") or instance:IsA("UIGradient") or instance:IsA("UIPadding")
       or instance:IsA("UIListLayout") or instance:IsA("UIGridLayout") or instance:IsA("UITableLayout")
       or instance:IsA("UIPageLayout") or instance:IsA("UIAspectRatioConstraint") or instance:IsA("UISizeConstraint")
       or instance:IsA("UIScale") or instance:IsA("JointInstance") or instance:IsA("WeldConstraint")
       or instance:IsA("Attachment") or instance:IsA("Constraint") or instance:IsA("Animation")
       or instance:IsA("Keyframe") or instance:IsA("KeyframeSequence") or instance:IsA("Pose") or instance:IsA("Bone")
       or instance:IsA("Clothing") or instance:IsA("BodyColors") or instance:IsA("CharacterMesh")
       or instance:IsA("Accessory") or instance:IsA("Accoutrement") or instance:IsA("PackageLink")
       or instance:IsA("HumanoidDescription") or instance:IsA("LocalizationTable") or instance:IsA("Terrain")
       or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
        return true
    end
    
    -- 2. Poda por Nombre de Contenedor de Recursos Visuales y Modelos 3D
    local name = instance.Name:lower()
    local visualAssets = {
        assets = true, models = true, sounds = true, audio = true,
        animations = true, anim = true, anims = true, textures = true,
        meshes = true, mesh = true, fx = true, worldfx = true, map = true,
        maps = true, vfx = true, lighting = true, decals = true, particles = true,
        npcs = true, terrain = true, camera = true, props = true,
        effects = true, visual = true, materials = true, clothing = true,
        accessories = true, rigs = true, characters = true, prefabs = true,
        modelpartstorage = true, characterassets = true, mapassets = true,
    }
    
    if visualAssets[name] then
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network") or name:find("client") or name:find("service") or name:find("handler")) then
            return true
        end
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
    local firstChunk = code:sub(1, 300):lower()
    if firstChunk:find("^%s*return%s+{") or firstChunk:find("^%s*return%s+setmetatable") then
        local hasLoops = code:find("while%s+") or code:find("for%s+") or code:find("repeat%s+")
        local hasServices = code:find("GetService") or code:find("FireServer") or code:find("InvokeServer") or code:find("Connect%(")
        if not hasLoops and not hasServices then
            return true
        end
    end
    return false
end

function HeuristicEngine:SafeDecompileWithCache(instance)
    if not instance:IsA("LuaSourceContainer") then return nil end
    
    if instance:IsA("BaseScript") and instance.Disabled then
        return nil
    end
    
    -- Delegación completa al Shared Memory Store centralizado de CapabilityManager
    if not self.Caps then return nil end
    
    local code = self.Caps:SafeDecompile(instance)
    if code and #code > 50000 then
        code = code:sub(1, 50000)
    end
    return code
end

-- =========================================================================
-- MOTOR DE ANÁLISIS DE CÓDIGO EN UN SOLO PASO (SINGLE-PASS TOKENIZER & ANALYZER)
-- =========================================================================

function HeuristicEngine:AnalyzeCodeSinglePass(code, rawName, path)
    if not code or #code == 0 then
        return 0, {}, {}, {}, false, false
    end
    
    -- 1. Bypass Inmediato por Huella Digital (Fingerprinting / Módulo Estático / Librería)
    if self:IsStaticDataModule(code) then
        return 0, { "Tipo: Módulo de Configuración Estática" }, {}, {}, true, false
    end
    
    local score = 0
    local tags = {}
    local categoriesFound = {}
    local codeFindings = {}
    local isLibrary = false
    
    local hasRenderLoop = code:find("RenderStepped") or code:find("Heartbeat") or code:find("Stepped")
    local hasCharacterRef = code:find("HumanoidRootPart") or code:find("Torso") or code:find("UpperTorso") or code:find("Character")
    local hasNetwork = code:find("FireServer") or code:find("InvokeServer") or code:find("MarketplaceService")
    
    local lineNum = 1
    local maxFindingsPerRule = 3
    local counts = {
        Kick = 0, Metatable = 0, DebugTrap = 0, Noclip = 0,
        Fly = 0, GlobalState = 0, RNG = 0, Obfuscator = 0
    }
    
    -- Recorrido Lineal en un Solo Paso O(N)
    for line in code:gmatch("([^\r\n]*)\r?\n?") do
        local lLower = line:lower()
        local cleanLine = nil
        local function getCleanLine()
            if not cleanLine then
                cleanLine = line:match("^%s*(.-)%s*$") or ""
                if #cleanLine > 120 then cleanLine = cleanLine:sub(1, 117) .. "..." end
            end
            return cleanLine
        end
        
        -- Regla 1: Llamadas a Expulsión (LocalPlayer:Kick)
        if (line:find("LocalPlayer:Kick") or line:find("Players%.LocalPlayer:Kick")) and counts.Kick < maxFindingsPerRule then
            counts.Kick = counts.Kick + 1
            score = score + 45
            categoriesFound["AntiCheat"] = true
            table.insert(codeFindings, { Desc = "Llamada Directa a Expulsión (LocalPlayer:Kick)", Line = lineNum, Code = getCleanLine() })
            if counts.Kick == 1 then table.insert(tags, "Kick") end
        end
        
        -- Regla 2: Metatablas / Hooking
        if (line:find("hookmetamethod") or line:find("getrawmetatable") or line:find("hookfunction")) and counts.Metatable < maxFindingsPerRule then
            counts.Metatable = counts.Metatable + 1
            score = score + 30
            categoriesFound["AntiCheat"] = true
            table.insert(codeFindings, { Desc = "Manipulación/Auditoría de Metatablas", Line = lineNum, Code = getCleanLine() })
            if counts.Metatable == 1 then table.insert(tags, "Metatables") end
        end
        
        -- Regla 3: Introspección Maliciosa de Callstack (Excluye debug.traceback)
        if (line:find("debug%.info%s*%(%s*%d") or line:find("debug%.getinfo%s*%(%s*%d") or line:find("getfenv%s*%(%s*%d")) and counts.DebugTrap < maxFindingsPerRule then
            counts.DebugTrap = counts.DebugTrap + 1
            score = score + 25
            categoriesFound["AntiCheat"] = true
            table.insert(codeFindings, { Desc = "Introspección Maliciosa de Callstack / Trap (debug.info)", Line = lineNum, Code = getCleanLine() })
            if counts.DebugTrap == 1 then table.insert(tags, "DebugTrap") end
        end
        
        -- Regla 4: Noclip con Seguimiento de Ámbito Léxico (Descarta confeti, selección, partículas)
        if line:find("CanCollide%s*=%s*false") and hasRenderLoop and hasCharacterRef and counts.Noclip < maxFindingsPerRule then
            local isCosmetic = lLower:find("confetti") or lLower:find("selectpart") or lLower:find("particle")
                or lLower:find("ring") or lLower:find("effect") or lLower:find("marker")
                or lLower:find("fishball") or lLower:find("debris") or lLower:find("drop")
                or lLower:find("coin") or lLower:find("visual") or lLower:find("trail")
                or lLower:find("circle") or lLower:find("highlight") or lLower:find("water") or lLower:find("splash")
            
            if not isCosmetic then
                counts.Noclip = counts.Noclip + 1
                score = score + 40
                categoriesFound["Admin"] = true
                table.insert(codeFindings, { Desc = "Rutina Continua de Noclip en Character (RenderStepped)", Line = lineNum, Code = getCleanLine() })
                if counts.Noclip == 1 then table.insert(tags, "Noclip:Contextual") end
            end
        end
        
        -- Regla 5: Manipulación de Vuelo / BodyVelocity
        if line:find("BodyVelocity") and hasCharacterRef and counts.Fly < maxFindingsPerRule then
            counts.Fly = counts.Fly + 1
            score = score + 35
            categoriesFound["Admin"] = true
            table.insert(codeFindings, { Desc = "Manipulación de Vuelo / Fuerza Física (BodyVelocity)", Line = lineNum, Code = getCleanLine() })
            if counts.Fly == 1 then table.insert(tags, "Fly:BodyVelocity") end
        end
        
        -- Regla 6: Exposición de Estado Global / Hooks de Memoria (Categoría Arquitectura / No penaliza AntiCheat)
        if (line:find("_G%.") or line:find("shared%.")) and counts.GlobalState < maxFindingsPerRule then
            counts.GlobalState = counts.GlobalState + 1
            score = score + 5 -- Ponderación mínima informativa (no infla el score de amenaza)
            categoriesFound["Architecture"] = true
            table.insert(codeFindings, { Desc = "Hook de Memoria / Estado Global Compartido (_G / shared)", Line = lineNum, Code = getCleanLine() })
            if counts.GlobalState == 1 then table.insert(tags, "Architecture:GlobalMemoryHook") end
        end
        
        -- Regla 7: Azar Transaccional vs Cosmético (Descarta modulación de audio, pitch, rotación y diálogos)
        if (line:find("math%.random") or line:find("Random%.new")) and hasNetwork and counts.RNG < maxFindingsPerRule then
            local isCosmetic = lLower:find("playbackspeed") or lLower:find("pitch") or lLower:find("volume")
                or lLower:find("rotation") or lLower:find("offset") or lLower:find("color")
                or lLower:find("angles") or lLower:find("dialogue") or lLower:find("greeting")
                or line:find("%[%s*math%.random") or line:find("#%a+%)") or line:find("npc") or line:find("sound")
            
            if not isCosmetic then
                counts.RNG = counts.RNG + 1
                score = score + 25
                categoriesFound["Economy"] = true
                table.insert(codeFindings, { Desc = "Lógica de RNG Vinculada a Red/Transacciones", Line = lineNum, Code = getCleanLine() })
                if counts.RNG == 1 then table.insert(tags, "Economy:TransactionalRNG") end
            end
        end
        
        -- Regla 8: Ofuscadores Comerciales
        if (line:find("LPH_") or line:find("IronBrew") or line:find("MoonSec") or line:find("PSU_")) and counts.Obfuscator < maxFindingsPerRule then
            counts.Obfuscator = counts.Obfuscator + 1
            score = score + 45
            categoriesFound["AntiCheat"] = true
            table.insert(codeFindings, { Desc = "Ofuscador Comercial Detectado", Line = lineNum, Code = getCleanLine() })
            if counts.Obfuscator == 1 then table.insert(tags, "Ofuscador") end
        end
        
        lineNum = lineNum + 1
    end
    
    return score, tags, categoriesFound, codeFindings, false, isLibrary
end

function HeuristicEngine:ExtractRemoteInvocations(code, scriptPath)
    local invocations = {}
    if not code or #code == 0 then return invocations end
    
    local lineNum = 1
    for line in code:gmatch("([^\r\n]*)\r?\n?") do
        -- Buscar invocaciones a FireServer o InvokeServer (patrón corregido para Lua)
        local function tryExtract(pattern, methodName)
            local remExpr, args = line:match(pattern)
            if remExpr and args then
                local cleanRem = remExpr:match("([%w_]+)$") or remExpr
                local cleanArgs = args:match("^%s*(.-)%s*$") or ""
                
                -- Inferir tipos aproximados de los argumentos pasados
                local argTypes = {}
                if #cleanArgs > 0 then
                    for argToken in cleanArgs:gmatch("([^,]+)") do
                        local tToken = argToken:match("^%s*(.-)%s*$")
                        if tToken:find('^"') or tToken:find("^'") then
                            table.insert(argTypes, "string(" .. tToken .. ")")
                        elseif tonumber(tToken) then
                            table.insert(argTypes, "number(" .. tToken .. ")")
                        elseif tToken == "true" or tToken == "false" then
                            table.insert(argTypes, "boolean(" .. tToken .. ")")
                        elseif tToken:find("Vector3") or tToken:find("CFrame") then
                            table.insert(argTypes, "Vector/CFrame")
                        else
                            table.insert(argTypes, "var(" .. tToken .. ")")
                        end
                    end
                end
                
                table.insert(invocations, {
                    RemoteName = cleanRem,
                    FullExpression = remExpr,
                    Method = methodName,
                    ArgumentsRaw = cleanArgs,
                    InferredTypes = #argTypes > 0 and ("(" .. table.concat(argTypes, ", ") .. ")") or "()",
                    LineNumber = lineNum,
                    ScriptPath = scriptPath,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                })
            end
        end
        
        tryExtract("([%w_%.:]+)%s*:%s*[Ff]ire[Ss]erver%s*%((.-)%)", "FireServer")
        tryExtract("([%w_%.:]+)%s*:%s*[Ii]nvoke[Ss]erver%s*%((.-)%)", "InvokeServer")
        
        lineNum = lineNum + 1
    end
    
    return invocations
end

-- Análisis directo y focalizado de un script individual (sin recorrido global)
function HeuristicEngine:AnalyzeScript(instanceOrCode, optionalName)
    local code = nil
    local rawName = optionalName or "UnknownScript"
    local path = rawName
    local instance = nil
    
    if typeof(instanceOrCode) == "Instance" then
        instance = instanceOrCode
        rawName = instance.Name
        path = instance:GetFullName()
        if self:IsIgnoredCoreInstance(instance) then
            return nil
        end
        code = self:SafeDecompileWithCache(instance)
    elseif type(instanceOrCode) == "string" then
        code = instanceOrCode
    end
    
    if not code or #code == 0 then return nil end
    
    local score, tags, categoriesFound, findings, isStaticConfig, isLibrary = self:AnalyzeCodeSinglePass(code, rawName, path)
    local remoteInvocations = self:ExtractRemoteInvocations(code, path)
    
    -- Análisis de Nombres de Léxico
    for catName, keywords in pairs(self.Lexicon) do
        for _, kw in ipairs(keywords) do
            if self:MatchesKeyword(rawName, kw) then
                local weight = (catName == "AntiCheat" and 20) or (catName == "Admin" and 15) or 10
                score = score + weight
                table.insert(tags, catName)
                categoriesFound[catName] = true
                break
            end
        end
    end
    
    if score > 100 then score = 100 end
    
    -- Ponderación por Confianza (Herramienta de Administración Autorizada vs Inyectada)
    local isAuthorizedAdmin = false
    local lowerPath = path:lower()
    if categoriesFound["Admin"] and not categoriesFound["AntiCheat"] and (lowerPath:find("admin") or rawName:lower():find("admin")) then
        isAuthorizedAdmin = true
        table.insert(tags, "Herramienta de Administración Autorizada")
    end
    
    -- Atenuación de Score en Componentes de UI
    if lowerPath:find("playergui") and not categoriesFound["AntiCheat"] and score < 50 then
        score = math.floor(score * 0.6)
    end
    
    local severity = HeuristicEngine.Severity.LOW
    if isAuthorizedAdmin then
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
        Path = path,
        Score = score,
        Severity = severity,
        Tags = tags,
        Categories = categoriesFound,
        Findings = findings,
        RemoteInvocations = remoteInvocations,
        IsStaticConfig = isStaticConfig,
        IsLibrary = isLibrary,
        IsAuthorizedAdmin = isAuthorizedAdmin,
    }
end

function HeuristicEngine:AnalyzeInstance(instance, depth)
    depth = depth or 0
    if not self:IsExecutableOrNetwork(instance) then return nil end
    if self:IsIgnoredCoreInstance(instance) then return nil end
    
    local path = instance:GetFullName()
    local rawName = instance.Name
    local className = instance.ClassName
    local isRem = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")
    
    -- Delegación al analizador focalizado de código
    local analysis = self:AnalyzeScript(instance)
    if not analysis and isRem then
        analysis = {
            Instance = instance,
            Name = rawName,
            Path = path,
            Score = 15,
            Severity = HeuristicEngine.Severity.LOW,
            Tags = { "Clase: " .. className },
            Categories = { Remotes = true },
            Findings = {},
            IsStaticConfig = false,
        }
    end
    
    if analysis then
        analysis.Depth = depth
        analysis.ClassName = className
        
        -- Ponderación Topológica de Ubicación
        if string.find(path, "ReplicatedFirst") then
            analysis.Score = math.min(analysis.Score + 30, 100)
            table.insert(analysis.Tags, "Topología: ReplicatedFirst (Early Boot)")
            analysis.Categories["AntiCheat"] = true
        end
    end
    
    return analysis
end

-- =========================================================================
-- COLECTOR RÁPIDO Y MOTOR DE EJECUCIÓN MULTIHILO (WORKER POOL)
-- =========================================================================

function HeuristicEngine:CollectCandidates(targetContainers)
    -- Se elimina StarterGui para evitar escanear y descompilar duplicados de PlayerGui
    local containers = targetContainers or {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
    }
    
    local queue = {}
    local lastYield = tick()
    
    local function walk(parent, currentDepth)
        if self:IsIgnoredCoreInstance(parent) or self:IsPrunedBranch(parent) then
            return
        end
        
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, child in ipairs(children) do
                if tick() - lastYield > 0.012 then
                    task.wait()
                    lastYield = tick()
                end
                
                if not self:IsIgnoredCoreInstance(child) then
                    if self:IsExecutableOrNetwork(child) then
                        table.insert(queue, { Instance = child, Depth = currentDepth })
                    end
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
    
    return queue
end

function HeuristicEngine:ProcessConcurrently(queue, processFn, onProgress, workerCount)
    workerCount = workerCount or 6
    local total = #queue
    if total == 0 then return end
    
    local nextIndex = 1
    local completed = 0
    local activeWorkers = workerCount
    local startTime = tick()
    local lastProgressUpdate = 0
    
    local function notifyProgress(currentInstName)
        local now = tick()
        if now - lastProgressUpdate >= 0.03 or completed == total then
            lastProgressUpdate = now
            local elapsed = math.max(now - startTime, 0.001)
            local speed = completed / elapsed
            local eta = (speed > 0) and ((total - completed) / speed) or 0
            if onProgress then
                pcall(onProgress, completed, total, currentInstName or "Finalizando...", elapsed, eta, speed)
            end
        end
    end
    
    local function workerLoop()
        local workerYield = tick()
        while true do
            local myIndex = nextIndex
            nextIndex = nextIndex + 1
            if myIndex > total then break end
            
            local item = queue[myIndex]
            if item and item.Instance then
                pcall(processFn, item.Instance, item.Depth)
                completed = completed + 1
                notifyProgress(item.Instance.Name)
            end
            
            if tick() - workerYield > 0.012 then
                task.wait()
                workerYield = tick()
            end
        end
        activeWorkers = activeWorkers - 1
    end
    
    for w = 1, workerCount do
        task.spawn(workerLoop)
    end
    
    while activeWorkers > 0 do
        task.wait()
    end
    
    notifyProgress("Completado")
end

function HeuristicEngine:RunFullAudit(targetContainers, onProgress)
    local results = {
        AntiCheat = {},
        Economy = {},
        Combat = {},
        AdminTools = {},
        Admin = {},
        Architecture = {},
        Remotes = {},
        CrossReferenceMatrix = {
            RemotesToCallers = {},
            ScriptsToRemotes = {},
        },
        CriticalIssues = 0,
        TotalScanned = 0,
        StructuralProfile = nil,
    }
    
    if self.Structural then
        results.StructuralProfile = self.Structural:GenerateReport()
    end
    
    local queue = self:CollectCandidates(targetContainers)
    results.TotalScanned = #queue
    
    self:ProcessConcurrently(queue, function(inst, depth)
        local analysis = self:AnalyzeInstance(inst, depth)
        if analysis then
            if analysis.Severity == 5 or (analysis.Categories["Admin"] and not analysis.Categories["AntiCheat"]) then
                table.insert(results.AdminTools, analysis)
            end
            if analysis.Categories["AntiCheat"] or (analysis.Score >= 55 and not analysis.Categories["Architecture"]) then
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
            if analysis.Categories["Architecture"] then
                table.insert(results.Architecture, analysis)
            end
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                table.insert(results.Remotes, analysis)
            end
            if analysis.Severity == HeuristicEngine.Severity.CRITICAL then
                results.CriticalIssues = results.CriticalIssues + 1
            end
            
            -- Compilar Matriz de Trazabilidad Código-a-Red (Cross-Reference Matrix)
            if analysis.RemoteInvocations and #analysis.RemoteInvocations > 0 then
                results.CrossReferenceMatrix.ScriptsToRemotes[analysis.Path] = analysis.RemoteInvocations
                for _, inv in ipairs(analysis.RemoteInvocations) do
                    local rName = inv.RemoteName
                    if not results.CrossReferenceMatrix.RemotesToCallers[rName] then
                        results.CrossReferenceMatrix.RemotesToCallers[rName] = {}
                    end
                    table.insert(results.CrossReferenceMatrix.RemotesToCallers[rName], {
                        Script = analysis.Path,
                        Line = inv.LineNumber,
                        Method = inv.Method,
                        ArgumentsRaw = inv.ArgumentsRaw,
                        InferredTypes = inv.InferredTypes,
                        Snippet = inv.Snippet,
                    })
                end
            end
        end
    end, onProgress, 6)
    
    self.LastFullAudit = results
    self.CrossReferenceMatrix = results.CrossReferenceMatrix
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo Heurístico Multihilo Completado: %d analizados, %d remotes, %d referencias de red mapeadas, %d amenazas críticas.", results.TotalScanned, #results.Remotes, #results.CrossReferenceMatrix.RemotesToCallers, results.CriticalIssues))
    end
    
    return results
end

-- =========================================================================
-- MÉTODOS DE ESCANEO ESPECÍFICOS (CON REUTILIZACIÓN DE MEMORIA)
-- =========================================================================

-- 1. Escaneo Dedicado de Anti-Cheat, Watchdogs e Integrity Checks
function HeuristicEngine:RunAntiCheatAudit(customLocations, onProgress)
    -- Si ya existe un escaneo previo en memoria y no se piden ubicaciones personalizadas, filtrar instantáneamente
    if not customLocations and self.LastFullAudit and self.LastFullAudit.AntiCheat then
        local cachedTargets = self.LastFullAudit.AntiCheat
        if onProgress then onProgress(#cachedTargets, #cachedTargets, "Caché", 0.001, 0, #cachedTargets) end
        return {
            Category = "AntiCheat",
            Timestamp = tick(),
            Targets = cachedTargets,
            TotalFound = #cachedTargets,
        }
    end

    local report = {
        Category = "AntiCheat",
        Timestamp = tick(),
        Targets = {},
        TotalFound = 0,
    }
    
    local queue = self:CollectCandidates(customLocations)
    
    self:ProcessConcurrently(queue, function(inst, depth)
        local analysis = self:AnalyzeInstance(inst, depth)
        if analysis and (analysis.Categories["AntiCheat"] or analysis.Score >= 40) then
            table.insert(report.Targets, analysis)
            report.TotalFound = report.TotalFound + 1
        end
    end, onProgress, 6)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo de Anti-Cheat Multihilo finalizado: %d watchdogs/kicks localizados.", report.TotalFound))
    end
    
    return report
end

-- 2. Escaneo Dedicado de Economía, Ruleta y Azar
function HeuristicEngine:RunEconomyAudit(customLocations, onProgress)
    -- Reutilización de memoria instantánea
    if not customLocations and self.LastFullAudit and self.LastFullAudit.Economy then
        local cachedTargets = self.LastFullAudit.Economy
        if onProgress then onProgress(#cachedTargets, #cachedTargets, "Caché", 0.001, 0, #cachedTargets) end
        return {
            Category = "Economy",
            Timestamp = tick(),
            Targets = cachedTargets,
            TotalFound = #cachedTargets,
        }
    end

    local report = {
        Category = "Economy",
        Timestamp = tick(),
        Targets = {},
        TotalFound = 0,
    }
    
    local queue = self:CollectCandidates(customLocations)
    
    self:ProcessConcurrently(queue, function(inst, depth)
        local analysis = self:AnalyzeInstance(inst, depth)
        if analysis and (analysis.Categories["Economy"] or analysis.Score >= 20) then
            table.insert(report.Targets, analysis)
            report.TotalFound = report.TotalFound + 1
        end
    end, onProgress, 6)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Escaneo de Economía/Ruletas Multihilo finalizado: %d elementos encontrados.", report.TotalFound))
    end
    
    return report
end

-- 3. Escaneo Dedicado de Todos los Remotes del Juego
function HeuristicEngine:RunRemotesAudit(customLocations, onProgress)
    -- Reutilización de memoria instantánea
    if not customLocations and self.LastFullAudit and self.LastFullAudit.Remotes then
        local cachedRemotes = self.LastFullAudit.Remotes
        local remEvents, remFuncs = {}, {}
        for _, rem in ipairs(cachedRemotes) do
            if rem.ClassName == "RemoteFunction" then
                table.insert(remFuncs, rem)
            else
                table.insert(remEvents, rem)
            end
        end
        if onProgress then onProgress(#cachedRemotes, #cachedRemotes, "Caché", 0.001, 0, #cachedRemotes) end
        return {
            Category = "Remotes",
            Timestamp = tick(),
            RemoteEvents = remEvents,
            RemoteFunctions = remFuncs,
            TotalFound = #cachedRemotes,
        }
    end

    local report = {
        Category = "Remotes",
        Timestamp = tick(),
        RemoteEvents = {},
        RemoteFunctions = {},
        TotalFound = 0,
    }
    
    local queue = self:CollectCandidates(customLocations)
    
    self:ProcessConcurrently(queue, function(inst, depth)
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
    end, onProgress, 8)
    
    if self.Logger then
        self.Logger:Info("AUDIT", string.format("Mapeo de Remotes Multihilo finalizado: %d RemoteEvents, %d RemoteFunctions.", #report.RemoteEvents, #report.RemoteFunctions))
    end
    
    return report
end

return HeuristicEngine
