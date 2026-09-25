--[[
    =============================================================================
    APEX SUITE - ECONOMY & RNG AUDITOR (SYNCHRONIZED WITH REMOTES & HEURISTICS)
    =============================================================================
    Inspecciona profundamente la lógica de economía, ruletas, gachas, drops,
    tablas de probabilidad y precios en múltiples idiomas (Chino, Japonés, Ruso, etc.),
    con poda de ramas no funcionales y time-slicing de 12ms para evitar bloqueos.
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
    local name = instance.Name:lower()
    local visualAssets = {
        assets = true, models = true, sounds = true, audio = true,
        animations = true, textures = true, meshes = true, fx = true,
        worldfx = true, map = true, vfx = true, lighting = true,
        decals = true, particles = true, npcs = true, terrain = true,
        camera = true, props = true, effects = true, visual = true,
    }
    
    if visualAssets[name] then
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network") or name:find("shop") or name:find("store")) then
            return true
        end
    end
    
    if instance:IsA("BasePart") or instance:IsA("MeshPart") or instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("Sound") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
        return true
    end
    
    return false
end

function EconomyAuditor:ScanEconomyNodes(onProgress)
    local findings = {
        Roulettes = {},
        Shops = {},
        LootTables = {},
        ValueContainers = {},
        CorrelatedPurchaseRemotes = {},
        TotalFound = 0,
    }
    
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("StarterGui"),
    }
    
    local lexicon = (self.Heuristic and self.Heuristic.Lexicon.Economy) or {
        "spin", "wheel", "roll", "luck", "chance", "shop", "purchase", "currency", "gem", "crate", "unbox", "gacha", "rebirth", "multiplier", "diamond",
        "抽奖", "抽卡", "轮盘", "扭蛋", "转盘", "概率", "几率", "爆率", "商店", "购买", "金币", "钻石", "充值",
        "ガチャ", "ルーレット", "確率", "購入", "ショップ", "рулетка", "шанс", "магазин", "покупка", "донат"
    }
    
    local function isIgnoredCoreInstance(instance)
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

    local function isEconomyCandidate(inst)
        return inst:IsA("LuaSourceContainer") or inst:IsA("ValueBase") or inst:IsA("Configuration") or inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("GuiButton")
    end

    -- Fase 1: Colectar candidatos rápidamente con poda de ramas
    local candidateQueue = {}
    local lastYield = tick()

    local function walk(parent)
        if self:IsPrunedBranch(parent) or isIgnoredCoreInstance(parent) then return end
        
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, inst in ipairs(children) do
                if tick() - lastYield > 0.012 then
                    task.wait()
                    lastYield = tick()
                end
                
                if not isIgnoredCoreInstance(inst) then
                    if isEconomyCandidate(inst) then
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
        if cont then
            walk(cont)
        end
    end
    
    -- Fase 2: Procesamiento multihilo concurrente
    local total = #candidateQueue
    local nextIndex = 1
    local completed = 0
    local activeWorkers = 6
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
            local myIdx = nextIndex
            nextIndex = nextIndex + 1
            if myIdx > total then break end
            
            local inst = candidateQueue[myIdx]
            if inst then
                local rawName = inst.Name
                local path = inst:GetFullName()
                local isMatch = false
                local matchedTag = ""
                
                for _, kw in ipairs(lexicon) do
                    if matchesWord(rawName, kw) then
                        isMatch = true
                        matchedTag = kw
                        break
                    end
                end
                
                if not isMatch and not inst:IsA("GuiButton") then
                    local sAttrs, attrs = pcall(function() return inst:GetAttributes() end)
                    if sAttrs and attrs then
                        for aName, aVal in pairs(attrs) do
                            local aLower = tostring(aName):lower()
                            if aLower:find("chance") or aLower:find("price") or aLower:find("cost") or aLower:find("rate") or aLower:find("luck") or aLower:find("概率") or aLower:find("价格") then
                                isMatch = true
                                matchedTag = string.format("Attr(%s = %s)", aName, tostring(aVal))
                                break
                            end
                        end
                    end
                end
                
                if isMatch then
                    findings.TotalFound = findings.TotalFound + 1
                    local nodeData = {
                        Instance = inst,
                        Name = rawName,
                        ClassName = inst.ClassName,
                        Path = path,
                        Tag = matchedTag,
                    }
                    
                    if inst:IsA("ModuleScript") then
                        table.insert(findings.LootTables, nodeData)
                    elseif inst:IsA("ValueBase") or inst:IsA("Configuration") then
                        table.insert(findings.ValueContainers, nodeData)
                    elseif matchesWord(rawName, "shop") or matchesWord(rawName, "store") or matchesWord(rawName, "buy") or matchesWord(rawName, "tienda") or string.find(rawName, "商店") or string.find(rawName, "购买") or string.find(rawName, "ショップ") then
                        table.insert(findings.Shops, nodeData)
                    else
                        table.insert(findings.Roulettes, nodeData)
                    end
                end
                
                completed = completed + 1
                notifyProgress(rawName)
            end
            
            if tick() - workerYield > 0.012 then
                task.wait()
                workerYield = tick()
            end
        end
        activeWorkers = activeWorkers - 1
    end
    
    for w = 1, activeWorkers do
        task.spawn(workerLoop)
    end
    
    while activeWorkers > 0 do
        task.wait()
    end
    
    notifyProgress("Completado")
    
    -- Fase 3: Sincronización con Remotes de Compra/Economía
    if self.RemoteAnalyzer and self.RemoteAnalyzer.Logs then
        for _, remLog in ipairs(self.RemoteAnalyzer.Logs) do
            if remLog.RiskLevel == "HIGH" or remLog.Name:lower():find("buy") or remLog.Name:lower():find("purchase") or remLog.Name:lower():find("spin") or remLog.Name:lower():find("gacha") then
                table.insert(findings.CorrelatedPurchaseRemotes, {
                    RemoteName = remLog.Name,
                    Path = remLog.Path,
                    Snippet = remLog.Snippet,
                    ArgsCount = remLog.ArgsCount,
                })
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("ECONOMY", string.format("Auditoría Multihilo de Economía: %d elementos y %d remotes vinculados.", findings.TotalFound, #findings.CorrelatedPurchaseRemotes))
    end
    
    return findings
end

return EconomyAuditor
