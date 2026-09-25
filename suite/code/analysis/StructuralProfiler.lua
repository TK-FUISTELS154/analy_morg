--[[
    =============================================================================
    APEX SUITE - STRUCTURAL & STATISTICAL PROFILER
    =============================================================================
    Analiza la topología del juego, identifica frameworks estándar de Roblox
    (Knit, Flamework, ReplicaService, ByteNet) y genera métricas estadísticas
    de distribución, densidad y complejidad arquitectónica con poda de ramas
    y time-slicing para evitar congelamientos de hilo.
--]]

local StructuralProfiler = {}
StructuralProfiler.__index = StructuralProfiler
StructuralProfiler.ClassName = "StructuralProfiler"

function StructuralProfiler.new(logger)
    local self = setmetatable({}, StructuralProfiler)
    self.Logger = logger
    return self
end

function StructuralProfiler:IsPrunedBranch(instance)
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
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network") or name:find("client") or name:find("service") or name:find("handler")) then
            return true
        end
    end
    
    return false
end

function StructuralProfiler:IsIgnoredCoreInstance(instance)
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
       or fullName:find("Fusion") then
        return true
    end
    return false
end

-- Generador de Perfil Topológico y Estadístico en PASE ÚNICO (Single-Pass Pipeline)
function StructuralProfiler:GenerateReport()
    local frameworks = {
        Knit = false,
        Flamework = false,
        ReplicaService = false,
        ByteNet = false,
        BridgeNet = false,
        RoactRodux = false,
    }
    
    local topology = {
        ReplicatedFirst = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Bootloader / Early Init" },
        ReplicatedStorage = { Count = 0, Remotes = 0, ModuleScripts = 0, Role = "Shared Network & Data" },
        StarterPlayerScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Client Controllers" },
        StarterCharacterScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Character Logic" },
    }
    
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
    
    local depthSum = 0
    local lastYield = tick()
    
    local containers = {
        { Service = game:GetService("ReplicatedStorage"), Key = "ReplicatedStorage" },
        { Service = game:GetService("ReplicatedFirst"), Key = "ReplicatedFirst" },
        { Service = game:GetService("StarterPlayer"), Key = "StarterPlayer" },
        { Service = game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"), Key = "PlayerGui" },
    }
    
    local function processNode(inst, currentDepth, topKey)
        stats.TotalInstances = stats.TotalInstances + 1
        local cName = inst.ClassName
        stats.ClassDistribution[cName] = (stats.ClassDistribution[cName] or 0) + 1
        
        local isScript = inst:IsA("LuaSourceContainer")
        local isRemote = inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")
        
        if isScript then
            stats.TotalScripts = stats.TotalScripts + 1
        elseif isRemote then
            stats.TotalRemotes = stats.TotalRemotes + 1
        end
        
        depthSum = depthSum + currentDepth
        if currentDepth > stats.MaxDepth then
            stats.MaxDepth = currentDepth
        end
        
        -- Detección de Frameworks en ReplicatedStorage
        if topKey == "ReplicatedStorage" then
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
        
        -- Mapeo Topológico por Servicio
        if topKey == "ReplicatedFirst" or topKey == "ReplicatedStorage" then
            topology[topKey].Count = topology[topKey].Count + 1
            if inst:IsA("LocalScript") then
                topology[topKey].LocalScripts = (topology[topKey].LocalScripts or 0) + 1
            elseif inst:IsA("ModuleScript") then
                topology[topKey].ModuleScripts = (topology[topKey].ModuleScripts or 0) + 1
            elseif isRemote then
                topology[topKey].Remotes = (topology[topKey].Remotes or 0) + 1
            end
        elseif topKey == "StarterPlayer" then
            local pName = inst.Parent and inst.Parent.Name or ""
            if pName == "StarterPlayerScripts" or inst.Name == "StarterPlayerScripts" then
                topology.StarterPlayerScripts.Count = topology.StarterPlayerScripts.Count + 1
                if inst:IsA("LocalScript") then topology.StarterPlayerScripts.LocalScripts = topology.StarterPlayerScripts.LocalScripts + 1 end
                if inst:IsA("ModuleScript") then topology.StarterPlayerScripts.ModuleScripts = topology.StarterPlayerScripts.ModuleScripts + 1 end
            elseif pName == "StarterCharacterScripts" or inst.Name == "StarterCharacterScripts" then
                topology.StarterCharacterScripts.Count = topology.StarterCharacterScripts.Count + 1
                if inst:IsA("LocalScript") then topology.StarterCharacterScripts.LocalScripts = topology.StarterCharacterScripts.LocalScripts + 1 end
                if inst:IsA("ModuleScript") then topology.StarterCharacterScripts.ModuleScripts = topology.StarterCharacterScripts.ModuleScripts + 1 end
            end
        end
    end
    
    local function walk(parent, currentDepth, topKey)
        if self:IsPrunedBranch(parent) or self:IsIgnoredCoreInstance(parent) then return end
        
        local s, children = pcall(function() return parent:GetChildren() end)
        if s and children then
            for _, inst in ipairs(children) do
                if tick() - lastYield > 0.012 then
                    task.wait()
                    lastYield = tick()
                end
                
                if not self:IsIgnoredCoreInstance(inst) then
                    processNode(inst, currentDepth, topKey)
                    if not self:IsPrunedBranch(inst) then
                        walk(inst, currentDepth + 1, topKey)
                    end
                end
            end
        end
    end
    
    for _, entry in ipairs(containers) do
        if entry.Service then
            walk(entry.Service, 1, entry.Key)
        end
    end
    
    if stats.TotalInstances > 0 then
        stats.MeanDepth = depthSum / stats.TotalInstances
        stats.RemoteDensity = (stats.TotalRemotes / stats.TotalInstances) * 100
        stats.ScriptRatio = (stats.TotalScripts / stats.TotalInstances) * 100
    end
    
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
