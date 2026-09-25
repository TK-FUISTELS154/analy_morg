--[[
    =============================================================================
    APEX SUITE - ADVANCED MULTI-MODE SELECTIVE DUMPER & PROJECT EXTRACTOR
    =============================================================================
    Motor de volcado profesional de scripts y jerarquías con:
    1. HEURISTIC_FINDINGS: Extrae carpetas y scripts donde se detectaron vulnerabilidades.
    2. DEPENDENCY_CHAIN: Extrae el script emisor, módulos intermedios y remotes relacionados.
    3. MANUAL_TREE: Extracción selectiva de nodos marcados por el usuario.
    4. FULL_ENVIRONMENT: Volcado total de scripts y módulos con poda de 100,000+ assets visuales
       y time-slicing cooperativo de 12ms para cero congelamientos.
--]]

local SelectiveDumper = {}
SelectiveDumper.__index = SelectiveDumper
SelectiveDumper.ClassName = "SelectiveDumper"

SelectiveDumper.DumpModes = {
    HEURISTIC_FINDINGS = "HEURISTIC_FINDINGS", -- Solo donde hubo detección
    DEPENDENCY_CHAIN   = "DEPENDENCY_CHAIN",   -- Cadena de código emisor + remotes + módulos
    MANUAL_TREE        = "MANUAL_TREE",        -- Nodos seleccionados en el árbol
    FULL_ENVIRONMENT   = "FULL_ENVIRONMENT",   -- Todos los scripts del juego
}

function SelectiveDumper.new(capabilityManager, logger, registry)
    local self = setmetatable({}, SelectiveDumper)
    self.Caps = capabilityManager
    self.Logger = logger
    self.Registry = registry
    -- NOTA: El caché de descompilación se gestiona EXCLUSIVAMENTE en CapabilityManager._decompCache
    -- NO crear cachés locales aquí.
    return self
end

-- Tabla de clases no ejecutables (lookup O(1) en lugar de cadena de IsA)
local PRUNED_CLASSES = {
    BasePart = true, MeshPart = true, Decal = true, Texture = true,
    Sound = true, ParticleEmitter = true, Beam = true, Trail = true,
    Highlight = true, Light = true, SurfaceAppearance = true,
    SpecialMesh = true, BlockMesh = true, CylinderMesh = true,
    UIComponent = true, UILayout = true, UIConstraint = true,
    UICorner = true, UIStroke = true, UIGradient = true, UIPadding = true,
    UIListLayout = true, UIGridLayout = true, UITableLayout = true,
    UIPageLayout = true, UIAspectRatioConstraint = true, UISizeConstraint = true,
    UIScale = true, JointInstance = true, WeldConstraint = true,
    Attachment = true, Constraint = true, Animation = true,
    Keyframe = true, KeyframeSequence = true, Pose = true, Bone = true,
    Clothing = true, BodyColors = true, CharacterMesh = true,
    Accessory = true, Accoutrement = true, PackageLink = true,
    HumanoidDescription = true, LocalizationTable = true, Terrain = true,
    Smoke = true, Fire = true, Sparkles = true,
}

local VISUAL_ASSET_NAMES = {
    assets = true, models = true, sounds = true, audio = true,
    animations = true, anim = true, anims = true, textures = true,
    meshes = true, mesh = true, fx = true, worldfx = true, map = true,
    vfx = true, lighting = true, decals = true, particles = true,
    npcs = true, terrain = true, camera = true, props = true,
    effects = true, visual = true, materials = true, clothing = true,
    accessories = true, rigs = true, characters = true, prefabs = true,
}

function SelectiveDumper:IsPrunedBranch(instance)
    -- 1. Poda por lookup directo de ClassName (O(1))
    if PRUNED_CLASSES[instance.ClassName] then return true end
    
    -- 2. Fallback con IsA para herencia (BasePart cubre Part, WedgePart, etc.)
    if instance:IsA("BasePart") or instance:IsA("Light") or instance:IsA("Constraint")
       or instance:IsA("UIComponent") or instance:IsA("JointInstance") then
        return true
    end
    
    -- 3. Poda por nombre de contenedor visual
    local name = instance.Name:lower()
    if VISUAL_ASSET_NAMES[name] then
        if not (name:find("script") or name:find("module") or name:find("controller") or name:find("network") or name:find("client") or name:find("service") or name:find("handler")) then
            return true
        end
    end
    
    return false
end

function SelectiveDumper:SafeDecompile(instance)
    if not instance or not instance:IsA("LuaSourceContainer") then return nil end
    
    -- Delegación completa al Shared Memory Store centralizado de CapabilityManager
    if self.Caps then
        local code = self.Caps:SafeDecompile(instance)
        return code or "-- [Código no disponible]"
    end
    
    -- Fallback mínimo si no hay CapabilityManager
    local s, direct = pcall(function() return instance.Source end)
    return (s and type(direct) == "string" and #direct > 0 and direct) or "-- [Código no disponible]"
end

function SelectiveDumper:DumpInstance(instance, scriptsOnly, depthLimit, currentDepth)
    currentDepth = currentDepth or 0
    if depthLimit and currentDepth > depthLimit then return nil end
    if self:IsPrunedBranch(instance) then return nil end
    
    local isScript = instance:IsA("LuaSourceContainer")
    local isRemote = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")
    local isValue = instance:IsA("ValueBase") or instance:IsA("Configuration")
    
    local dump = {
        Name = instance.Name,
        ClassName = instance.ClassName,
        Path = instance:GetFullName(),
        Tags = {},
        Attributes = {},
        Properties = {},
        Children = {},
        Source = nil,
        BytecodeSize = 0,
    }
    
    -- 1. Tags de CollectionService
    pcall(function()
        local tags = game:GetService("CollectionService"):GetTags(instance)
        if tags and #tags > 0 then dump.Tags = tags end
    end)
    
    -- 2. Atributos
    local sAttr, attrs = pcall(function() return instance:GetAttributes() end)
    if sAttr and attrs and next(attrs) then dump.Attributes = attrs end
    
    -- 3. Propiedades Relevantes según ClassName
    pcall(function()
        if instance:IsA("ValueBase") then
            local sVal, v = pcall(function() return instance.Value end)
            if sVal then dump.Properties["Value"] = tostring(v) end
        elseif instance:IsA("ProximityPrompt") then
            dump.Properties["ActionText"] = instance.ActionText
            dump.Properties["ObjectText"] = instance.ObjectText
            dump.Properties["HoldDuration"] = instance.HoldDuration
            dump.Properties["MaxActivationDistance"] = instance.MaxActivationDistance
            dump.Properties["Enabled"] = instance.Enabled
            if instance.KeyboardKeyCode then dump.Properties["KeyCode"] = instance.KeyboardKeyCode.Name end
        elseif instance:IsA("ClickDetector") then
            dump.Properties["MaxActivationDistance"] = instance.MaxActivationDistance
        elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
            dump.Properties["Text"] = instance.Text
            dump.Properties["Visible"] = instance.Visible
        elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
            dump.Properties["Image"] = instance.Image
            dump.Properties["Visible"] = instance.Visible
        elseif instance:IsA("Tool") then
            dump.Properties["RequiresHandle"] = instance.RequiresHandle
            dump.Properties["CanBeDropped"] = instance.CanBeDropped
            dump.Properties["ToolTip"] = instance.ToolTip
        elseif instance:IsA("BaseScript") then
            dump.Properties["Enabled"] = instance.Enabled
        end
    end)
    
    -- 4. Código Fuente de Scripts
    if isScript then
        local src = self:SafeDecompile(instance)
        dump.Source = src
        if src then dump.BytecodeSize = #src end
    end
    
    -- 4. Hijos recursivos con poda
    local s, children = pcall(function() return instance:GetChildren() end)
    if s and children then
        for _, child in ipairs(children) do
            if not self:IsPrunedBranch(child) then
                local childDump = self:DumpInstance(child, scriptsOnly, depthLimit, currentDepth + 1)
                if childDump then
                    -- Si filtramos solo scripts, incluir ramas que contengan scripts o sean scripts/remotes
                    if not scriptsOnly or childDump.Source or isRemote or isValue or #childDump.Children > 0 then
                        table.insert(dump.Children, childDump)
                    end
                end
            end
        end
    end
    
    return dump
end

-- =========================================================================
-- MODOS DE EXTRACCIÓN AVANZADA
-- =========================================================================

-- MODO 1: Extracción de hallazgos heurísticos con sus carpetas contenedoras (Estáticos + Dinámicos en Vivo)
function SelectiveDumper:DumpHeuristicFindings(auditResults, onProgress)
    local extractedMap = {}
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.HEURISTIC_FINDINGS,
        Timestamp = tick(),
        TotalExtracted = 0,
        TotalScripts = 0,
        Containers = {},
    }
    
    local function collectFinding(finding)
        if not finding then return end
        local inst = finding.Instance
        
        -- Si no hay Instance directa pero hay Path, intentar resolver objeto
        if not inst and finding.Path then
            pcall(function()
                local parts = string.split(finding.Path, ".")
                local curr = game
                for _, p in ipairs(parts) do
                    curr = curr:FindFirstChild(p)
                    if not curr then break end
                end
                inst = curr
            end)
        end
        if not inst then return end

        local parentFolder = inst.Parent or inst
        
        if not extractedMap[parentFolder] then
            extractedMap[parentFolder] = true
            local containerDump = self:DumpInstance(parentFolder, true, 4)
            if containerDump then
                table.insert(dumpPackage.Containers, {
                    FindingCategory = finding.Tags or {"Detected"},
                    Score = finding.Score or 0,
                    Path = parentFolder:GetFullName(),
                    Data = containerDump,
                })
                dumpPackage.TotalExtracted = dumpPackage.TotalExtracted + 1
            end
        end
    end
    
    -- 1. Hallazgos Estáticos de HeuristicEngine
    if auditResults then
        if auditResults.AntiCheat then
            for _, item in ipairs(auditResults.AntiCheat) do collectFinding(item) end
        end
        if auditResults.Economy then
            for _, item in ipairs(auditResults.Economy) do collectFinding(item) end
        end
        if auditResults.Combat then
            for _, item in ipairs(auditResults.Combat) do collectFinding(item) end
        end
        if auditResults.AdminTools then
            for _, item in ipairs(auditResults.AdminTools) do collectFinding(item) end
        end
    end

    -- 2. Hallazgos Dinámicos en Tiempo Real desde CapabilityManager (RuntimeSuspectRegistry)
    if self.Caps and self.Caps.GetRuntimeSuspects then
        local runtimeSuspects = self.Caps:GetRuntimeSuspects()
        for _, suspect in ipairs(runtimeSuspects) do
            collectFinding(suspect)
        end
    end

    -- 3. Hallazgos de ActionRecorder (Acciones Correlacionadas en Vivo)
    local actionRecorder = self.Registry and self.Registry:Get("ActionRecorder")
    if actionRecorder and actionRecorder.GetCorrelatedSuspects then
        local liveSuspects = actionRecorder:GetCorrelatedSuspects()
        for _, suspect in ipairs(liveSuspects) do
            collectFinding(suspect)
        end
    end

    -- 4. Invocadores de Alto Riesgo de RemoteAnalyzer (ActiveRemoteCallers)
    local remoteAnalyzer = self.Registry and self.Registry:Get("RemoteAnalyzer")
    if remoteAnalyzer and remoteAnalyzer.GetHighRiskCallers then
        local highRiskCallers = remoteAnalyzer:GetHighRiskCallers()
        for _, caller in ipairs(highRiskCallers) do
            collectFinding({
                Path = caller.Path,
                Score = caller.Score or 95,
                Tags = { "ActiveRemoteCaller", caller.RiskLevel or "HIGH" },
            })
        end
    end
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo HEURISTIC_FINDINGS: %d contenedores con hallazgos (estáticos + dinámicos) extraídos.", dumpPackage.TotalExtracted))
    end
    
    return dumpPackage
end

-- MODO 2: Extracción de cadena de ejecución y dependencias
function SelectiveDumper:DumpDependencyChain(actionEntry, onProgress)
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.DEPENDENCY_CHAIN,
        Timestamp = tick(),
        Action = actionEntry and actionEntry.Type or "Unknown",
        InitiatorInstance = nil,
        IntermediateScripts = {},
        RelatedRemotes = {},
    }
    
    if actionEntry then
        if actionEntry.Instance then
            dumpPackage.InitiatorInstance = self:DumpInstance(actionEntry.Instance, false, 3)
            
            local searchScope = actionEntry.Instance.Parent or actionEntry.Instance
            local s, desc = pcall(function() return searchScope:GetDescendants() end)
            if s and desc then
                for _, obj in ipairs(desc) do
                    if obj:IsA("LuaSourceContainer") then
                        table.insert(dumpPackage.IntermediateScripts, {
                            Path = obj:GetFullName(),
                            ClassName = obj.ClassName,
                            Code = self:SafeDecompile(obj),
                        })
                    end
                end
            end
        end
        
        if actionEntry.CorrelatedRemotes then
            for _, rem in ipairs(actionEntry.CorrelatedRemotes) do
                table.insert(dumpPackage.RelatedRemotes, {
                    Path = rem.Path,
                    Method = rem.Method,
                    Args = rem.Args,
                    Snippet = rem.Snippet,
                })
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo DEPENDENCY_CHAIN: %d scripts intermedios y %d remotes vinculados.", #dumpPackage.IntermediateScripts, #dumpPackage.RelatedRemotes))
    end
    
    return dumpPackage
end

-- MODO 3: Extracción manual de lista de nodos
function SelectiveDumper:DumpManualNodes(nodeList, onProgress)
    local results = {
        Mode = SelectiveDumper.DumpModes.MANUAL_TREE,
        Timestamp = tick(),
        Nodes = {},
    }
    
    local lastYield = tick()
    for idx, node in ipairs(nodeList or {}) do
        if tick() - lastYield > 0.012 then
            task.wait()
            lastYield = tick()
        end
        local d = self:DumpInstance(node, false, 6)
        if d then table.insert(results.Nodes, d) end
        if onProgress then pcall(onProgress, idx, #nodeList, node.Name) end
    end
    
    return results
end

-- MODO 4: Extracción total del entorno de scripts del juego (Optimizado y Podado)
function SelectiveDumper:DumpFullEnvironment(onProgress)
    local targetServices = {
        { Service = game:GetService("ReplicatedFirst"), Name = "ReplicatedFirst" },
        { Service = game:GetService("ReplicatedStorage"), Name = "ReplicatedStorage" },
        { Service = game:GetService("StarterPlayer"), Name = "StarterPlayer" },
        { Service = game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"), Name = "PlayerGui" },
    }
    
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.FULL_ENVIRONMENT,
        Timestamp = tick(),
        PlaceId = game.PlaceId,
        Services = {},
        TotalScriptsDumped = 0,
        TotalRemotesDumped = 0,
    }
    
    local lastYield = tick()
    local totalServices = #targetServices
    
    local function countEntities(dumpNode)
        if not dumpNode then return end
        if dumpNode.Source then dumpPackage.TotalScriptsDumped = dumpPackage.TotalScriptsDumped + 1 end
        if dumpNode.ClassName:find("Remote") then dumpPackage.TotalRemotesDumped = dumpPackage.TotalRemotesDumped + 1 end
        for _, child in ipairs(dumpNode.Children or {}) do
            countEntities(child)
        end
    end
    
    for idx, srvEntry in ipairs(targetServices) do
        if srvEntry.Service then
            if onProgress then pcall(onProgress, idx, totalServices, "Volcando " .. srvEntry.Name) end
            
            local srvDump = self:DumpInstance(srvEntry.Service, true, 10)
            if srvDump then
                countEntities(srvDump)
                table.insert(dumpPackage.Services, srvDump)
            end
            
            if tick() - lastYield > 0.012 then
                task.wait()
                lastYield = tick()
            end
        end
    end
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Volcado Total del Entorno completado: %d scripts y %d remotes extraídos.", dumpPackage.TotalScriptsDumped, dumpPackage.TotalRemotesDumped))
    end
    
    return dumpPackage
end

return SelectiveDumper
