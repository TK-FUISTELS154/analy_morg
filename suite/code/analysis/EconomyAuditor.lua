--[[
    =============================================================================
    APEX SUITE - ECONOMY & RNG AUDITOR (SYNCHRONIZED WITH REMOTES & HEURISTICS)
    =============================================================================
    Inspecciona profundamente la lógica de economía, ruletas, gachas, drops,
    tablas de probabilidad y precios en múltiples idiomas (Chino, Japonés, Ruso, etc.),
    sincronizando en tiempo real con los Remotes interceptados por RemoteAnalyzer.
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

function EconomyAuditor:ScanEconomyNodes()
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
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("StarterGui"),
    }
    
    local lexicon = self.Heuristic and self.Heuristic.Lexicon.Economy or {
        "spin", "wheel", "roll", "luck", "chance", "shop", "item", "purchase", "currency", "gem",
        "抽奖", "抽卡", "轮盘", "扭蛋", "转盘", "概率", "几率", "爆率", "商店", "购买",
        "ガチャ", "ルーレット", "確率", "購入", "ショップ", "рулетка", "шанс", "магазин"
    }
    
    for _, cont in ipairs(containers) do
        if cont then
            local s, desc = pcall(function() return cont:GetDescendants() end)
            if s and desc then
                for _, inst in ipairs(desc) do
                    local name = inst.Name:lower()
                    local rawName = inst.Name
                    local path = inst:GetFullName()
                    local isMatch = false
                    local matchedTag = ""
                    
                    -- 1. Coincidencia por Léxico Multilingüe
                    for _, kw in ipairs(lexicon) do
                        if string.find(name, kw:lower(), 1, true) or string.find(rawName, kw, 1, true) then
                            isMatch = true
                            matchedTag = kw
                            break
                        end
                    end
                    
                    -- 2. Inspección de Atributos de probabilidad o precio
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
                        elseif string.find(name, "shop") or string.find(name, "buy") or string.find(rawName, "商店") or string.find(rawName, "购买") or string.find(rawName, "ショップ") then
                            table.insert(findings.Shops, nodeData)
                        else
                            table.insert(findings.Roulettes, nodeData)
                        end
                    end
                end
            end
        end
    end
    
    -- 3. Sincronización con Remotes de Compra/Economía interceptados por RemoteAnalyzer
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
        self.Logger:Info("ECONOMY", string.format("Auditoría Sincronizada de Economía: %d elementos y %d remotes de transacción vinculados.", findings.TotalFound, #findings.CorrelatedPurchaseRemotes))
    end
    
    return findings
end

return EconomyAuditor
