--[[
    =============================================================================
    APEX SUITE - STRUCTURAL & STATISTICAL PROFILER
    =============================================================================
    Analiza la topología del juego, identifica frameworks estándar de Roblox
    (Knit, Flamework, ReplicaService, ByteNet) y genera métricas estadísticas
    de distribución, densidad y complejidad arquitectónica.
--]]

local StructuralProfiler = {}
StructuralProfiler.__index = StructuralProfiler
StructuralProfiler.ClassName = "StructuralProfiler"

function StructuralProfiler.new(logger)
    local self = setmetatable({}, StructuralProfiler)
    self.Logger = logger
    return self
end

-- 1. Detección de Frameworks Modernos de Roblox
function StructuralProfiler:DetectFrameworks()
    local frameworks = {
        Knit = false,
        Flamework = false,
        ReplicaService = false,
        ByteNet = false,
        BridgeNet = false,
        RoactRodux = false,
    }
    
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local s, descendants = pcall(function() return replicatedStorage:GetDescendants() end)
    
    if s and descendants then
        for _, inst in ipairs(descendants) do
            local name = inst.Name:lower()
            if name == "knit" or name == "knitclient" then
                frameworks.Knit = true
            elseif name == "flamework" or name == "_flamework" then
                frameworks.Flamework = true
            elseif name:find("replicaservice") or name:find("replicacontroller") then
                frameworks.ReplicaService = true
            elseif name == "bytenet" then
                frameworks.ByteNet = true
            elseif name == "bridgenet" or name == "bridgenet2" then
                frameworks.BridgeNet = true
            elseif name == "roact" or name == "rodux" or name == "fusion" then
                frameworks.RoactRodux = true
            end
        end
    end
    
    return frameworks
end

-- 2. Análisis Topológico de Contenedores Clave
function StructuralProfiler:AnalyzeTopology()
    local topology = {
        ReplicatedFirst = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Bootloader / Early Init" },
        ReplicatedStorage = { Count = 0, Remotes = 0, ModuleScripts = 0, Role = "Shared Network & Data" },
        StarterPlayerScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Client Controllers" },
        StarterCharacterScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Character Logic" },
    }
    
    local function profileService(service, targetKey)
        if not service then return end
        local s, desc = pcall(function() return service:GetDescendants() end)
        if s and desc then
            topology[targetKey].Count = #desc
            for _, inst in ipairs(desc) do
                if inst:IsA("LocalScript") then
                    topology[targetKey].LocalScripts = (topology[targetKey].LocalScripts or 0) + 1
                elseif inst:IsA("ModuleScript") then
                    topology[targetKey].ModuleScripts = (topology[targetKey].ModuleScripts or 0) + 1
                elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                    topology[targetKey].Remotes = (topology[targetKey].Remotes or 0) + 1
                end
            end
        end
    end
    
    profileService(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
    profileService(game:GetService("ReplicatedStorage"), "ReplicatedStorage")
    
    local starterPlayer = game:GetService("StarterPlayer")
    if starterPlayer then
        profileService(starterPlayer:FindFirstChild("StarterPlayerScripts"), "StarterPlayerScripts")
        profileService(starterPlayer:FindFirstChild("StarterCharacterScripts"), "StarterCharacterScripts")
    end
    
    return topology
end

-- 3. Métricas Estadísticas de Distribución de Instancias (Solo Contenedores Operacionales)
function StructuralProfiler:CalculateStatistics()
    local stats = {
        TotalInstances = 0,
        ClassDistribution = {},
        RemoteDensity = 0,
        ScriptRatio = 0,
        MeanDepth = 0,
        MaxDepth = 0,
        TotalScripts = 0,
        TotalRemotes = 0,
    }
    
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("StarterGui"),
    }
    
    local depthSum = 0
    
    local function walk(parent, currentDepth)
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, inst in ipairs(children) do
                stats.TotalInstances = stats.TotalInstances + 1
                local cName = inst.ClassName
                stats.ClassDistribution[cName] = (stats.ClassDistribution[cName] or 0) + 1
                
                if inst:IsA("LuaSourceContainer") then
                    stats.TotalScripts = stats.TotalScripts + 1
                elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                    stats.TotalRemotes = stats.TotalRemotes + 1
                end
                
                depthSum = depthSum + currentDepth
                if currentDepth > stats.MaxDepth then
                    stats.MaxDepth = currentDepth
                end
                
                walk(inst, currentDepth + 1)
            end
        end
    end
    
    for _, cont in ipairs(containers) do
        if cont then
            walk(cont, 1)
        end
    end
    
    if stats.TotalInstances > 0 then
        stats.MeanDepth = depthSum / stats.TotalInstances
        stats.RemoteDensity = (stats.TotalRemotes / stats.TotalInstances) * 100
        stats.ScriptRatio = (stats.TotalScripts / stats.TotalInstances) * 100
    end
    
    return stats
end

function StructuralProfiler:GenerateReport()
    local frameworks = self:DetectFrameworks()
    local topology = self:AnalyzeTopology()
    local stats = self:CalculateStatistics()
    
    local activeFrameworks = {}
    for fName, active in pairs(frameworks) do
        if active then table.insert(activeFrameworks, fName) end
    end
    if #activeFrameworks == 0 then table.insert(activeFrameworks, "Custom / Vanilla Engine Architecture") end
    
    return {
        Frameworks = activeFrameworks,
        Topology = topology,
        Statistics = stats,
    }
end

return StructuralProfiler
