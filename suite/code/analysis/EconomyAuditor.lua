--[[
    =============================================================================
    APEX SUITE - ECONOMY & RNG AUDITOR (DEEP TABLE PARSING & LOOT VALIDATOR)
    =============================================================================
    Inspecciona la lógica económica real analizando tablas de módulos exportadas,
    valida matemáticamente tablas de probabilidad/loot (suma de pesos y sesgos),
    ejecuta análisis secuencial cooperativo sin sobrecarga de hilos y realiza
    correlación semántica cruzada con remotes para detectar vulnerabilidades
    críticas de validación de precios en el cliente.
--]]

local EconomyAuditor = {}
EconomyAuditor.__index = EconomyAuditor
EconomyAuditor.ClassName = "EconomyAuditor"

function EconomyAuditor.new(heuristicEngine, logger, remoteAnalyzer)
    local self = setmetatable({}, EconomyAuditor)
    self.Heuristic = heuristicEngine
    self.Logger = logger
    self.RemoteAnalyzer = remoteAnalyzer
    return self
end

function EconomyAuditor:IsPrunedBranch(instance)
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
    
    local name = instance.Name:lower()
    local visualAssets = {
        assets = true, models = true, sounds = true, audio = true,
        animations = true, anim = true, anims = true, textures = true,
        meshes = true, mesh = true, fx = true, worldfx = true, map = true,
        vfx = true, lighting = true, decals = true, particles = true,
        npcs = true, terrain = true, camera = true, props = true,
        effects = true, visual = true, materials = true, clothing = true,
        accessories = true, rigs = true, characters = true, prefabs = true,
    }
    
    if visualAssets[name] then
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network") or name:find("shop") or name:find("store") or name:find("client") or name:find("service") or name:find("economy")) then
            return true
        end
    end
    
    return false
end

function EconomyAuditor:IsIgnoredCoreInstance(instance)
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

-- =========================================================================
-- EXTRACTOR Y VALIDADOR MATEMÁTICO DE TABLAS DE PROBABILIDAD (LOOT TABLES)
-- =========================================================================
function EconomyAuditor:ValidateLootTable(tableName, tbl)
    if type(tbl) ~= "table" then return nil end
    
    local totalWeight = 0
    local itemCount = 0
    local items = {}
    local hasProbabilityKeys = false
    
    local probKeys = {
        weight = true, chance = true, probability = true, rate = true,
        droprate = true, percentage = true, odds = true, luck = true,
        ["概率"] = true, ["几率"] = true, ["爆率"] = true, ["確率"] = true, ["шанс"] = true
    }
    
    for key, val in pairs(tbl) do
        if type(val) == "number" and probKeys[tostring(key):lower()] then
            hasProbabilityKeys = true
            totalWeight = totalWeight + val
            itemCount = itemCount + 1
            table.insert(items, { Name = tostring(key), Weight = val })
        elseif type(val) == "table" then
            local entryWeight = nil
            local entryName = tostring(key)
            
            for subK, subV in pairs(val) do
                local subKLower = tostring(subK):lower()
                if probKeys[subKLower] and type(subV) == "number" then
                    entryWeight = subV
                    hasProbabilityKeys = true
                elseif subKLower == "name" or subKLower == "item" or subKLower == "id" or subKLower == "reward" then
                    entryName = tostring(subV)
                end
            end
            
            if entryWeight then
                totalWeight = totalWeight + entryWeight
                itemCount = itemCount + 1
                table.insert(items, { Name = entryName, Weight = entryWeight })
            end
        end
    end
    
    if hasProbabilityKeys and itemCount >= 2 then
        local isImbalanced = false
        local imbalanceReason = nil
        
        -- Verificación matemática de consistencia
        -- Escala 100%: tolerancia [99.0, 101.0]
        -- Escala 1.0: tolerancia [0.99, 1.01]
        local isPercentageScale = (totalWeight > 5.0 and totalWeight < 200.0)
        local isNormalizedScale = (totalWeight > 0.5 and totalWeight < 2.0)
        
        if isPercentageScale and (totalWeight < 99.0 or totalWeight > 101.0) then
            isImbalanced = true
            imbalanceReason = string.format("Suma de probabilidades es %.2f%% (esperado 100%%)", totalWeight)
        elseif isNormalizedScale and (totalWeight < 0.99 or totalWeight > 1.01) then
            isImbalanced = true
            imbalanceReason = string.format("Suma de probabilidades normalizada es %.4f (esperado 1.0)", totalWeight)
        end
        
        return {
            TableName = tableName,
            ItemCount = itemCount,
            TotalWeight = totalWeight,
            Items = items,
            IsImbalanced = isImbalanced,
            ImbalanceReason = imbalanceReason,
        }
    end
    
    return nil
end

-- =========================================================================
-- INSPECCIÓN PROFUNDA DE TABLAS EN MODULESCRIPTS (TABLE PARSING)
-- =========================================================================
function EconomyAuditor:InspectModuleEconomyTable(mod)
    if not mod:IsA("ModuleScript") then return nil end
    
    local s, data = pcall(function() return require(mod) end)
    if not s or type(data) ~= "table" then return nil end
    
    local analysis = {
        IsEconomyModule = false,
        LootTables = {},
        Prices = {},
        Products = {},
        Multipliers = {},
        BusinessCatalogs = {}, -- Catálogos de Cañas, Armas, Mascotas, Mejoras con precios y stats
        KeywordsFound = {},
    }
    
    local econKeys = {
        price = "Prices", cost = "Prices", gem = "Prices", coin = "Prices",
        gold = "Prices", diamond = "Prices", robux = "Prices", currency = "Prices",
        rebirthcost = "Prices", upgradecost = "Prices", baseprice = "Prices",
        productid = "Products", devproductid = "Products", gamepassid = "Products",
        multiplier = "Multipliers", boost = "Multipliers", luckmultiplier = "Multipliers",
        luck = "Multipliers", strength = "Multipliers", speed = "Multipliers",
        ["价格"] = "Prices", ["花费"] = "Prices", ["金币"] = "Prices", ["钻石"] = "Prices",
    }
    
    local function extractItemDetails(itemName, itemTable)
        if type(itemTable) ~= "table" then return nil end
        local itemInfo = { Name = tostring(itemName), Price = nil, Rarity = nil, Multipliers = {}, OtherStats = {} }
        local isItem = false
        
        for k, v in pairs(itemTable) do
            local kLower = tostring(k):lower()
            if (kLower:find("price") or kLower:find("cost") or kLower:find("gem") or kLower:find("coin") or kLower:find("gold")) and type(v) == "number" then
                itemInfo.Price = v
                isItem = true
            elseif kLower:find("rarity") or kLower:find("tier") then
                itemInfo.Rarity = tostring(v)
                isItem = true
            elseif (kLower:find("mult") or kLower:find("luck") or kLower:find("strength") or kLower:find("power") or kLower:find("speed")) and type(v) == "number" then
                itemInfo.Multipliers[tostring(k)] = v
                isItem = true
            elseif type(v) == "number" or type(v) == "string" then
                itemInfo.OtherStats[tostring(k)] = v
            end
        end
        
        return isItem and itemInfo or nil
    end
    
    local function parseTableRecursively(t, prefix, depth)
        if depth > 4 then return end
        
        -- 1. Comprobar si esta tabla es una tabla de loot / probabilidades
        local lootCheck = self:ValidateLootTable(prefix, t)
        if lootCheck then
            table.insert(analysis.LootTables, lootCheck)
            analysis.IsEconomyModule = true
        end
        
        -- 2. Comprobar si esta tabla es un catálogo de items de negocio (ej. Cañas, Armas, Mejoras)
        local detectedCatalog = { Name = prefix, Items = {} }
        for k, v in pairs(t) do
            if type(v) == "table" then
                local item = extractItemDetails(k, v)
                if item then
                    table.insert(detectedCatalog.Items, item)
                end
            end
        end
        
        if #detectedCatalog.Items >= 2 then
            table.insert(analysis.BusinessCatalogs, detectedCatalog)
            analysis.IsEconomyModule = true
        end
        
        for k, v in pairs(t) do
            local kStr = tostring(k)
            local kLower = kStr:lower()
            local currentPath = (prefix == "") and kStr or (prefix .. "." .. kStr)
            
            local category = econKeys[kLower]
            if category and (type(v) == "number" or type(v) == "string") then
                analysis.IsEconomyModule = true
                table.insert(analysis[category], { Key = currentPath, Value = v })
            end
            
            if type(v) == "table" then
                parseTableRecursively(v, currentPath, depth + 1)
            end
        end
    end
    
    parseTableRecursively(data, mod.Name, 1)
    
    if analysis.IsEconomyModule then
        return analysis
    end
    
    return nil
end

-- =========================================================================
-- AUDITORÍA PRINCIPAL SECUENCIAL COOPERATIVA
-- =========================================================================
function EconomyAuditor:ScanEconomyNodes(onProgress)
    local findings = {
        Roulettes = {},
        Shops = {},
        LootTables = {},
        BusinessCatalogs = {}, -- Catálogos de Cañas, Armas, Mascotas, Mejoras
        ValueContainers = {},
        CorrelatedPurchaseRemotes = {},
        Vulnerabilities = {},
        TotalFound = 0,
    }
    
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
    }
    
    local function matchesWord(targetText, keyword)
        if not targetText or not keyword then return false end
        local lowerText = targetText:lower()
        local lowerKw = keyword:lower()
        if lowerKw:find("^[_%W]") or lowerKw:find("[_%W]$") or lowerKw:match("[^\32-\126]") then
            return string.find(lowerText, lowerKw, 1, true) ~= nil
        end
        local pattern = "%f[%w]" .. lowerKw .. "%f[%W]"
        return string.find(lowerText, pattern) ~= nil
    end
    
    local function isCandidate(inst)
        return inst:IsA("ModuleScript") or inst:IsA("ValueBase") or inst:IsA("Configuration") or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("GuiButton")
    end
    
    -- Fase 1: Colectar candidatos con poda estricta
    local candidateQueue = {}
    local lastYield = tick()
    
    local function walk(parent)
        if self:IsPrunedBranch(parent) or self:IsIgnoredCoreInstance(parent) then return end
        
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, inst in ipairs(children) do
                if tick() - lastYield > 0.012 then
                    task.wait()
                    lastYield = tick()
                end
                
                if not self:IsIgnoredCoreInstance(inst) then
                    if isCandidate(inst) then
                        table.insert(candidateQueue, inst)
                    end
                    if not self:IsPrunedBranch(inst) then
                        walk(inst)
                    end
                end
            end
        end
    end
    
    for _, cont in ipairs(containers) do
        if cont then walk(cont) end
    end
    
    -- Fase 2: Inspección Secuencial Cooperativa (Sin contención de workers)
    local total = #candidateQueue
    local startTime = tick()
    local lastProgressUpdate = 0
    local knownItemPrices = {}
    
    for idx = 1, total do
        local inst = candidateQueue[idx]
        local rawName = inst.Name
        local path = inst:GetFullName()
        local isMatch = false
        local matchedTag = ""
        local nodeData = {
            Instance = inst,
            Name = rawName,
            ClassName = inst.ClassName,
            Path = path,
        }
        
        -- 2.1 Inspección Profunda de Módulos (Table Parsing)
        if inst:IsA("ModuleScript") then
            local modAnalysis = self:InspectModuleEconomyTable(inst)
            if modAnalysis then
                isMatch = true
                matchedTag = "ModuleTable(Parsed)"
                nodeData.Details = modAnalysis
                
                -- Almacenar precios conocidos para correlación cruzada con remotes
                for _, p in ipairs(modAnalysis.Prices) do
                    knownItemPrices[p.Key:lower()] = p.Value
                end
                
                -- Detectar tablas de probabilidad desbalanceadas
                for _, lt in ipairs(modAnalysis.LootTables) do
                    if lt.IsImbalanced then
                        table.insert(findings.Vulnerabilities, {
                            Type = "LootMathImbalance",
                            Severity = "MEDIUM",
                            Module = path,
                            TableName = lt.TableName,
                            Details = lt.ImbalanceReason,
                        })
                    end
                end
                
                for _, cat in ipairs(modAnalysis.BusinessCatalogs) do
                    table.insert(findings.BusinessCatalogs, {
                        Module = path,
                        CatalogName = cat.Name,
                        Items = cat.Items,
                        ItemCount = #cat.Items,
                    })
                end
                
                table.insert(findings.LootTables, nodeData)
            end
        end
        
        -- 2.2 Inspección de Atributos Financieros Directos
        if not isMatch and not inst:IsA("GuiButton") then
            local sAttrs, attrs = pcall(function() return inst:GetAttributes() end)
            if sAttrs and attrs then
                for aName, aVal in pairs(attrs) do
                    local aLower = tostring(aName):lower()
                    if aLower:find("chance") or aLower:find("price") or aLower:find("cost") or aLower:find("rate") or aLower:find("luck") or aLower:find("概率") or aLower:find("价格") then
                        isMatch = true
                        matchedTag = string.format("Attr(%s = %s)", aName, tostring(aVal))
                        nodeData.Tag = matchedTag
                        if inst:IsA("ValueBase") or inst:IsA("Configuration") then
                            table.insert(findings.ValueContainers, nodeData)
                        else
                            table.insert(findings.Shops, nodeData)
                        end
                        break
                    end
                end
            end
        end
        
        -- 2.3 Coincidencias Léxicas Contextuales (Sin falsos positivos cosméticos)
        if not isMatch then
            local lowerName = rawName:lower()
            if matchesWord(lowerName, "roulette") or matchesWord(lowerName, "gacha") or matchesWord(lowerName, "wheel") or matchesWord(lowerName, "spin") or lowerName:find("抽奖") or lowerName:find("转盘") or lowerName:find("ルーレット") then
                isMatch = true
                nodeData.Tag = "Lexical(Roulette)"
                table.insert(findings.Roulettes, nodeData)
            elseif matchesWord(lowerName, "shop") or matchesWord(lowerName, "store") or matchesWord(lowerName, "tienda") or matchesWord(lowerName, "market") or lowerName:find("商店") or lowerName:find("ショップ") then
                isMatch = true
                nodeData.Tag = "Lexical(Shop)"
                table.insert(findings.Shops, nodeData)
            end
        end
        
        if isMatch then
            findings.TotalFound = findings.TotalFound + 1
        end
        
        -- Control cooperativo de presupuesto de tiempo (12ms)
        local now = tick()
        if now - lastYield > 0.012 then
            task.wait()
            lastYield = tick()
        end
        
        if onProgress and (now - lastProgressUpdate >= 0.03 or idx == total) then
            lastProgressUpdate = now
            local elapsed = math.max(now - startTime, 0.001)
            local speed = idx / elapsed
            local eta = (speed > 0) and ((total - idx) / speed) or 0
            pcall(onProgress, idx, total, rawName, elapsed, eta, speed)
        end
    end
    
    -- =========================================================================
    -- FASE 3: CORRELACIÓN SEMÁNTICA CRUZADA CON ANALIZADOR DE RED
    -- =========================================================================
    if self.RemoteAnalyzer and self.RemoteAnalyzer.Logs then
        for _, remLog in ipairs(self.RemoteAnalyzer.Logs) do
            local remName = remLog.Name:lower()
            local isPurchaseRemote = remName:find("buy") or remName:find("purchase") or remName:find("shop") or remName:find("comprar") or remName:find("购买") or remName:find("pay")
            
            if isPurchaseRemote or remLog.RiskLevel == "HIGH" then
                table.insert(findings.CorrelatedPurchaseRemotes, {
                    RemoteName = remLog.Name,
                    Path = remLog.Path,
                    Snippet = remLog.Snippet or (self.RemoteAnalyzer.GenerateCodeSnippet and self.RemoteAnalyzer:GenerateCodeSnippet(remLog.Remote, remLog.Method, remLog.Args)) or "N/A",
                    ArgsCount = remLog.ArgsCount,
                })
                
                -- Verificación de Vulnerabilidad: ¿El cliente envía precio o cantidad arbitraria?
                if remLog.Args and #remLog.Args > 0 then
                    for argIdx, argVal in ipairs(remLog.Args) do
                        if type(argVal) == "number" and argVal > 0 then
                            -- Comprobar si coincide con un precio conocido o si parece un precio enviado por el cliente
                            for pName, pVal in pairs(knownItemPrices) do
                                if type(pVal) == "number" and pVal == argVal then
                                    table.insert(findings.Vulnerabilities, {
                                        Type = "ClientControlledPriceVulnerability",
                                        Severity = "CRITICAL",
                                        Remote = remLog.Path,
                                        ArgIndex = argIdx,
                                        SuspectedPrice = argVal,
                                        MatchedItem = pName,
                                        Details = string.format("El cliente envía el precio (%s) en el argumento %d al llamar a %s. Vulnerable a manipulación de precios si no se valida en el servidor.", tostring(argVal), argIdx, remLog.Name),
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("ECONOMY", string.format("Auditoría de Economía completada: %d nodos, %d tablas de loot, %d vulnerabilidades encontradas.", findings.TotalFound, #findings.LootTables, #findings.Vulnerabilities))
    end
    
    return findings
end

return EconomyAuditor
