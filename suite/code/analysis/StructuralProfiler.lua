--[[
    =============================================================================
    APEX SUITE - STRUCTURAL & ARCHITECTURAL PROFILER (DUCK TYPING & DEPENDENCY MAPPER)
    =============================================================================
    Identifica arquitecturas y frameworks modernos mediante firmas de código
    (Duck Typing de Knit, Flamework, ByteNet, BridgeNet2, ReplicaService),
    mapea el grafo de dependencias de inicialización (require tree) para aislar
    el script Controlador Maestro del juego y computa estadísticas topológicas
    en un solo paso cooperativo con presupuesto de 12ms.
--]]

local StructuralProfiler = {}
StructuralProfiler.__index = StructuralProfiler
StructuralProfiler.ClassName = "StructuralProfiler"

function StructuralProfiler.new(logger, capabilityManager)
    local self = setmetatable({}, StructuralProfiler)
    self.Logger = logger
    self.Caps = capabilityManager
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

-- =========================================================================
-- DUCK TYPING DE FRAMEWORKS POR FIRMAS DE CÓDIGO
-- =========================================================================
function StructuralProfiler:DetectFrameworkSignatures(scriptObj, src)
    local detected = {}
    if not src or #src == 0 then return detected end
    
    -- Knit Framework
    if src:find("CreateController") or src:find("CreateService") or src:find("KnitClient") or src:find("KnitServer") then
        detected["Knit"] = "Knit Framework (CreateController / KnitClient API)"
    end
    
    -- Flamework Framework
    if src:find("@Controller") or src:find("@Service") or src:find("Flamework%.addPaths") or src:find("Flamework%.ignite") then
        detected["Flamework"] = "Flamework Framework (Decorators / Dependency Injection)"
    end
    
    -- ByteNet Optimized Networking
    if src:find("ByteNet%.defineNamespace") or src:find("ByteNet%.definePacket") or src:find("bytenet") then
        detected["ByteNet"] = "ByteNet (High-Performance Binary Buffer Serialization)"
    end
    
    -- BridgeNet2 Networking
    if src:find("BridgeNet2") or src:find("ReferenceIdentifier") or src:find("CreateBridge") then
        detected["BridgeNet2"] = "BridgeNet2 (Lightweight Replicated Communication)"
    end
    
    -- ReplicaService / ReplicaController State Sync
    if src:find("ReplicaService") or src:find("ReplicaController") or src:find("NewClassToken") then
        detected["ReplicaService"] = "ReplicaService (Server-to-Client State Replication)"
    end
    
    -- Red Networking
    if src:find("Red%.Server") or src:find("Red%.Client") then
        detected["Red"] = "Red Networking (Type-Safe RPC)"
    end
    
    return detected
end

-- =========================================================================
-- MAPEO DE DEPENDENCIAS DE INICIALIZACIÓN (REQUIRE GRAPH & MASTER CONTROLLER)
-- =========================================================================
function StructuralProfiler:ExtractRequires(src)
    local requires = {}
    if not src or #src == 0 then return requires end
    
    for reqTarget in src:gmatch("require%s*%(%s*([^%)]+)%s*%)") do
        local cleaned = reqTarget:gsub('"', ''):gsub("'", ""):gsub("%s+", "")
        table.insert(requires, cleaned)
    end
    
    return requires
end

-- =========================================================================
-- GENERADOR DE REPORTE TOPOLÓGICO Y ESTRUCTURAL
-- =========================================================================
function StructuralProfiler:GenerateReport()
    local detectedFrameworks = {}
    local masterControllers = {}
    local dependencyGraph = {}
    
    local topology = {
        ReplicatedFirst = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Bootloader / Early Init" },
        ReplicatedStorage = { Count = 0, Remotes = 0, ModuleScripts = 0, Role = "Shared Network & Data" },
        StarterPlayerScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Client Controllers" },
        StarterCharacterScripts = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Character Logic" },
        PlayerGui = { Count = 0, LocalScripts = 0, ModuleScripts = 0, Role = "Interface Controllers" },
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
        { Service = game:GetService("ReplicatedFirst"), Key = "ReplicatedFirst" },
        { Service = game:GetService("ReplicatedStorage"), Key = "ReplicatedStorage" },
        { Service = game:GetService("StarterPlayer"), Key = "StarterPlayer" },
        { Service = game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"), Key = "PlayerGui" },
    }
    
    local function getScriptSource(inst)
        if self.Caps then
            local s, src = pcall(function() return self.Caps:SafeDecompile(inst) end)
            if s and src then return src end
        end
        local s2, src2 = pcall(function() return inst.Source end)
        if s2 and src2 then return src2 end
        return ""
    end
    
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
        
        -- Detección por Nombre
        local nameLower = inst.Name:lower()
        if nameLower:find("knit") then detectedFrameworks["Knit"] = "Knit Framework" end
        if nameLower:find("flamework") then detectedFrameworks["Flamework"] = "Flamework Framework" end
        if nameLower:find("bytenet") then detectedFrameworks["ByteNet"] = "ByteNet Binary Protocol" end
        if nameLower:find("bridgenet") then detectedFrameworks["BridgeNet2"] = "BridgeNet2 Networking" end
        if nameLower:find("replicaservice") or nameLower:find("replicacontroller") then detectedFrameworks["ReplicaService"] = "ReplicaService State Sync" end
        
        -- Mapeo de Controladores de Entrada y Dependencias
        if inst:IsA("LocalScript") and (topKey == "StarterPlayer" or topKey == "ReplicatedFirst") then
            local path = inst:GetFullName()
            local src = getScriptSource(inst)
            
            -- Duck Typing de Firmas de Código
            local fwSigns = self:DetectFrameworkSignatures(inst, src)
            for fwK, fwDesc in pairs(fwSigns) do
                detectedFrameworks[fwK] = fwDesc
            end
            
            -- Mapeo de Sentencias require(...)
            local requires = self:ExtractRequires(src)
            if #requires > 0 then
                dependencyGraph[path] = requires
            end
            
            -- Identificación de Master Controller / Bootstrapper
            if nameLower:find("init") or nameLower:find("main") or nameLower:find("client") or nameLower:find("boot") or nameLower:find("loader") or nameLower:find("controller") or #requires >= 3 then
                table.insert(masterControllers, {
                    Path = path,
                    Name = inst.Name,
                    RequiredModulesCount = #requires,
                    Dependencies = requires,
                })
            end
        elseif inst:IsA("ModuleScript") then
            -- Muestreo rápido de firmas en módulos clave
            if nameLower:find("network") or nameLower:find("controller") or nameLower:find("service") or nameLower:find("manager") then
                local src = getScriptSource(inst)
                local fwSigns = self:DetectFrameworkSignatures(inst, src)
                for fwK, fwDesc in pairs(fwSigns) do
                    detectedFrameworks[fwK] = fwDesc
                end
            end
        end
        
        -- Mapeo Topológico por Servicio
        if topKey == "ReplicatedFirst" or topKey == "ReplicatedStorage" or topKey == "PlayerGui" then
            topology[topKey].Count = topology[topKey].Count + 1
            if inst:IsA("LocalScript") then
                topology[topKey].LocalScripts = (topology[topKey].LocalScripts or 0) + 1
            elseif inst:IsA("ModuleScript") then
                topology[topKey].ModuleScripts = (topology[topKey].ModuleScripts or 0) + 1
            elseif isRemote and topKey == "ReplicatedStorage" then
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
    
    local activeFrameworkList = {}
    for fwK, fwDesc in pairs(detectedFrameworks) do
        table.insert(activeFrameworkList, fwDesc)
    end
    if #activeFrameworkList == 0 then
        table.insert(activeFrameworkList, "Custom / Vanilla Engine Architecture")
    end
    
    return {
        Frameworks = activeFrameworkList,
        MasterControllers = masterControllers,
        DependencyGraph = dependencyGraph,
        Topology = topology,
        Statistics = stats,
    }
end

return StructuralProfiler
