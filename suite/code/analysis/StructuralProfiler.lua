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

-- 3. Métricas Estadísticas de Distribución de Instancias
function StructuralProfiler:CalculateStatistics()
    local stats = {
        TotalInstances = 0,
        ClassDistribution = {},
        RemoteDensity = 0,
        ScriptRatio = 0,
        MeanDepth = 0,
        MaxDepth = 0,
    }
    
    local s, allDesc = pcall(function() return game:GetDescendants() end)
    if not s or not allDesc then return stats end
    
    stats.TotalInstances = #allDesc
    local totalScripts = 0
    local totalRemotes = 0
    local depthSum = 0
    
    for _, inst in ipairs(allDesc) do
        local cName = inst.ClassName
        stats.ClassDistribution[cName] = (stats.ClassDistribution[cName] or 0) + 1
        
        if inst:IsA("LuaSourceContainer") then
            totalScripts = totalScripts + 1
        elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            totalRemotes = totalRemotes + 1
        end
        
        -- Cálculo de Profundidad Jerárquica
        local depth = 0
        local curr = inst.Parent
        while curr and curr ~= game do
            depth = depth + 1
            curr = curr.Parent
        end
        depthSum = depthSum + depth
        if depth > stats.MaxDepth then stats.MaxDepth = depth end
    end
    
    if stats.TotalInstances > 0 then
        stats.MeanDepth = depthSum / stats.TotalInstances
        stats.RemoteDensity = (totalRemotes / stats.TotalInstances) * 100
        stats.ScriptRatio = (totalScripts / stats.TotalInstances) * 100
    end
    
    stats.TotalScripts = totalScripts
    stats.TotalRemotes = totalRemotes
    
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
