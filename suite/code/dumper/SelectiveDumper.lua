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
    HEURISTIC_FINDINGS    = "HEURISTIC_FINDINGS",    -- Solo donde hubo detección
    DEPENDENCY_CHAIN      = "DEPENDENCY_CHAIN",      -- Cadena de código emisor + remotes + módulos
    MANUAL_TREE           = "MANUAL_TREE",           -- Nodos seleccionados en el árbol
    FULL_ENVIRONMENT      = "FULL_ENVIRONMENT",      -- Todos los scripts del juego
    RUNTIME_INTERACTIONS  = "RUNTIME_INTERACTIONS",  -- Exclusivamente carpetas/scripts interactuados en vivo y sus remotes
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

-- Cálculo ultra-rápido de volumen total de trabajo (< 2ms) para conteo exacto de elementos
function SelectiveDumper:CountSubtreeWork(instance, scriptsOnly, depthLimit, currentDepth)
    currentDepth = currentDepth or 0
    if depthLimit and currentDepth > depthLimit then return 0, 0, 0 end
    if self:IsPrunedBranch(instance) then return 0, 0, 0 end
    
    local isScript = instance:IsA("LuaSourceContainer")
    local isRemote = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent")
    
    local count = 1
    local scripts = isScript and 1 or 0
    local remotes = isRemote and 1 or 0
    
    local s, children = pcall(function() return instance:GetChildren() end)
    if s and children then
        for _, child in ipairs(children) do
            if not self:IsPrunedBranch(child) then
                local c, sc, rm = self:CountSubtreeWork(child, scriptsOnly, depthLimit, currentDepth + 1)
                count = count + c
                scripts = scripts + sc
                remotes = remotes + rm
            end
        end
    end
    
    return count, scripts, remotes
end

function SelectiveDumper:CalculateTotalWork(nodeList, scriptsOnly, depthLimit)
    local totalCount = 0
    local totalScripts = 0
    local totalRemotes = 0
    
    for _, node in ipairs(nodeList or {}) do
        if typeof(node) == "Instance" then
            local c, sc, rm = self:CountSubtreeWork(node, scriptsOnly, depthLimit or 8, 0)
            totalCount = totalCount + c
            totalScripts = totalScripts + sc
            totalRemotes = totalRemotes + rm
        end
    end
    
    return totalCount, totalScripts, totalRemotes
end

local function createProgressTracker(totalExpected, onProgress)
    local tracker = {
        completed = 0,
        total = math.max(totalExpected or 1, 1),
        scripts = 0,
        remotes = 0,
        folders = 0,
        onProgress = onProgress,
        lastReport = 0,
        lastYield = tick(),
    }
    
    function tracker:Step(instance, isScript, isRemote, action)
        self.completed = self.completed + 1
        if isScript then
            self.scripts = self.scripts + 1
        elseif isRemote then
            self.remotes = self.remotes + 1
        else
            self.folders = self.folders + 1
        end
        
        local now = tick()
        if self.onProgress and (now - self.lastReport >= 0.025 or self.completed >= self.total) then
            self.lastReport = now
            local instName = instance and instance.Name or "Instancia"
            local fullPath = instance and (pcall(function() return instance:GetFullName() end) and instance:GetFullName() or instName) or instName
            pcall(self.onProgress, math.min(self.completed, self.total), self.total, instName, {
                scripts = self.scripts,
                remotes = self.remotes,
                folders = self.folders,
                currentPath = fullPath,
                action = action or (isScript and "Decompilando" or (isRemote and "Mapeando Remote" or "Extrayendo")),
            })
        end
        
        if now - self.lastYield >= 0.012 then
            task.wait()
            self.lastYield = tick()
        end
    end
    
    function tracker:Finish(summaryName)
        if self.onProgress then
            pcall(self.onProgress, self.total, self.total, summaryName or "Completado", {
                scripts = self.scripts,
                remotes = self.remotes,
                folders = self.folders,
                action = "Finalizado",
            })
        end
    end
    
    return tracker
end

function SelectiveDumper:DumpInstance(instance, scriptsOnly, depthLimit, currentDepth, tracker)
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
    
    -- 4. Notificación y Código Fuente de Scripts
    if isScript then
        if tracker then
            tracker:Step(instance, true, false, "Decompilando Script")
        end
        local src = self:SafeDecompile(instance)
        dump.Source = src
        if src then dump.BytecodeSize = #src end
    else
        if tracker then
            tracker:Step(instance, false, isRemote, isRemote and "Mapeando Remote" or "Extrayendo Nodo")
        end
    end
    
    -- 5. Hijos recursivos con poda
    local s, children = pcall(function() return instance:GetChildren() end)
    if s and children then
        for _, child in ipairs(children) do
            if not self:IsPrunedBranch(child) then
                local childDump = self:DumpInstance(child, scriptsOnly, depthLimit, currentDepth + 1, tracker)
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
    local targetFolders = {}
    local folderMeta = {}
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.HEURISTIC_FINDINGS,
        Timestamp = tick(),
        TotalExtracted = 0,
        TotalScripts = 0,
        TotalRemotes = 0,
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
            table.insert(targetFolders, parentFolder)
            folderMeta[parentFolder] = {
                FindingCategory = finding.Tags or {"Detected"},
                Score = finding.Score or 0,
                Path = parentFolder:GetFullName(),
            }
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

    -- Pre-cálculo exacto de carga de trabajo
    local totalWork = self:CalculateTotalWork(targetFolders, true, 4)
    local tracker = createProgressTracker(totalWork, onProgress)
    
    for _, parentFolder in ipairs(targetFolders) do
        local containerDump = self:DumpInstance(parentFolder, true, 4, 0, tracker)
        if containerDump then
            local meta = folderMeta[parentFolder] or {}
            table.insert(dumpPackage.Containers, {
                FindingCategory = meta.FindingCategory or {"Detected"},
                Score = meta.Score or 0,
                Path = meta.Path or parentFolder:GetFullName(),
                Data = containerDump,
            })
        end
    end
    
    tracker:Finish("Hallazgos Heurísticos Extraídos")
    dumpPackage.TotalExtracted = tracker.completed
    dumpPackage.TotalScripts = tracker.scripts
    dumpPackage.TotalRemotes = tracker.remotes
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo HEURISTIC_FINDINGS: %d elementos extraídos en %d contenedores.", dumpPackage.TotalExtracted, #dumpPackage.Containers))
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
        TotalExtracted = 0,
        TotalScripts = 0,
        TotalRemotes = 0,
    }
    
    local intermediateObjs = {}
    local correlatedRemotes = actionEntry and actionEntry.CorrelatedRemotes or {}
    
    if actionEntry and actionEntry.Instance then
        local searchScope = actionEntry.Instance.Parent or actionEntry.Instance
        local s, desc = pcall(function() return searchScope:GetDescendants() end)
        if s and desc then
            for _, obj in ipairs(desc) do
                if obj:IsA("LuaSourceContainer") then
                    table.insert(intermediateObjs, obj)
                end
            end
        end
    end
    
    local initWork = 0
    if actionEntry and actionEntry.Instance then
        initWork = self:CountSubtreeWork(actionEntry.Instance, false, 3, 0)
    end
    local totalWork = initWork + #intermediateObjs + #correlatedRemotes
    local tracker = createProgressTracker(totalWork, onProgress)
    
    if actionEntry and actionEntry.Instance then
        dumpPackage.InitiatorInstance = self:DumpInstance(actionEntry.Instance, false, 3, 0, tracker)
    end
    
    for _, obj in ipairs(intermediateObjs) do
        tracker:Step(obj, true, false, "Decompilando Script Intermedio")
        table.insert(dumpPackage.IntermediateScripts, {
            Path = obj:GetFullName(),
            ClassName = obj.ClassName,
            Code = self:SafeDecompile(obj),
        })
    end
    
    for _, rem in ipairs(correlatedRemotes) do
        tracker:Step(nil, false, true, "Mapeando Remote Vinculado")
        table.insert(dumpPackage.RelatedRemotes, {
            Path = rem.Path,
            Method = rem.Method,
            Args = rem.Args,
            Snippet = rem.Snippet,
        })
    end
    
    tracker:Finish("Cadena de Dependencias Extraída")
    dumpPackage.TotalExtracted = tracker.completed
    dumpPackage.TotalScripts = tracker.scripts
    dumpPackage.TotalRemotes = tracker.remotes
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo DEPENDENCY_CHAIN: %d scripts intermedios y %d remotes vinculados.", #dumpPackage.IntermediateScripts, #dumpPackage.RelatedRemotes))
    end
    
    return dumpPackage
end

-- MODO 3: Extracción manual de lista de nodos (Multihilo Concurrente con Conteo Exacto de Descendientes)
function SelectiveDumper:DumpManualNodes(nodeList, onProgress)
    local results = {
        Mode = SelectiveDumper.DumpModes.MANUAL_TREE,
        Timestamp = tick(),
        Nodes = {},
        TotalExtracted = 0,
        TotalScripts = 0,
        TotalRemotes = 0,
    }
    
    local list = nodeList or {}
    local total = #list
    if total == 0 then return results end
    
    -- Pre-cálculo ultra-rápido de todos los descendientes y scripts (< 2ms)
    local totalWork, totalSc, totalRm = self:CalculateTotalWork(list, false, 8)
    local tracker = createProgressTracker(totalWork, onProgress)
    
    -- Inicializar slots preservando el orden
    local rawResults = table.create(total)
    local nextIndex = 1
    local numWorkers = math.clamp(math.min(total, 8), 1, 8)
    local activeWorkers = numWorkers
    
    for workerId = 1, numWorkers do
        task.spawn(function()
            while true do
                local currentIdx = nil
                -- Asignación atómica de tarea
                if nextIndex <= total then
                    currentIdx = nextIndex
                    nextIndex = nextIndex + 1
                else
                    break
                end
                
                local node = list[currentIdx]
                if node then
                    local s, d = pcall(function()
                        return self:DumpInstance(node, false, 8, 0, tracker)
                    end)
                    if s and d then
                        rawResults[currentIdx] = d
                    end
                end
            end
            activeWorkers = activeWorkers - 1
        end)
    end
    
    -- Esperar a que todos los workers completen
    while activeWorkers > 0 do
        task.wait()
    end
    
    tracker:Finish("Volcado Manual Finalizado")
    
    for _, d in ipairs(rawResults) do
        if d then table.insert(results.Nodes, d) end
    end
    
    results.TotalExtracted = tracker.completed
    results.TotalScripts = tracker.scripts
    results.TotalRemotes = tracker.remotes
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Volcado Manual completado: %d elementos (%d scripts, %d remotes) procesados con %d hilos.",
            tracker.completed, tracker.scripts, tracker.remotes, numWorkers))
    end
    
    return results
end

-- MODO 4: Extracción total del entorno de scripts del juego (Multihilo Concurrente y Podado)
function SelectiveDumper:DumpFullEnvironment(onProgress)
    local resolveSrv = function(name)
        if getgenv()._APEX_RESOLVER then
            return getgenv()._APEX_RESOLVER.GetService(name)
        end
        local ok, s = pcall(function() return game:GetService(name) end)
        if ok and s then return s end
        local ok2, s2 = pcall(function() return game:FindFirstChildOfClass(name) end)
        return ok2 and s2 or nil
    end

    local getPlayerGui = function()
        if getgenv()._APEX_RESOLVER then
            return getgenv()._APEX_RESOLVER.GetPlayerGui()
        end
        local players = resolveSrv("Players")
        local lp = players and players.LocalPlayer
        return lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui"))
    end

    local targetServices = {
        { Service = resolveSrv("ReplicatedFirst"), Name = "ReplicatedFirst" },
        { Service = resolveSrv("ReplicatedStorage"), Name = "ReplicatedStorage" },
        { Service = resolveSrv("StarterPlayer"), Name = "StarterPlayer" },
        { Service = resolveSrv("StarterGui"), Name = "StarterGui" },
        { Service = resolveSrv("Lighting"), Name = "Lighting" },
        { Service = getPlayerGui(), Name = "PlayerGui" },
        { Service = resolveSrv("Workspace") or workspace, Name = "Workspace" },
    }
    
    -- Filtrar servicios disponibles
    local validServices = {}
    local srvInstances = {}
    for _, item in ipairs(targetServices) do
        if item.Service then
            table.insert(validServices, item)
            table.insert(srvInstances, item.Service)
        end
    end
    
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.FULL_ENVIRONMENT,
        Timestamp = tick(),
        PlaceId = game.PlaceId,
        Services = {},
        TotalExtracted = 0,
        TotalScriptsDumped = 0,
        TotalRemotesDumped = 0,
    }
    
    -- Pre-cálculo total de scripts y remotes
    local totalWork, totalSc, totalRm = self:CalculateTotalWork(srvInstances, true, 10)
    local tracker = createProgressTracker(totalWork, onProgress)
    
    local totalServices = #validServices
    local rawServiceResults = table.create(totalServices)
    local nextServiceIdx = 1
    local numWorkers = math.clamp(math.min(totalServices, 6), 1, 6)
    local activeWorkers = numWorkers
    
    for workerId = 1, numWorkers do
        task.spawn(function()
            while true do
                local currentIdx = nil
                if nextServiceIdx <= totalServices then
                    currentIdx = nextServiceIdx
                    nextServiceIdx = nextServiceIdx + 1
                else
                    break
                end
                
                local srvEntry = validServices[currentIdx]
                if srvEntry and srvEntry.Service then
                    local s, srvDump = pcall(function()
                        return self:DumpInstance(srvEntry.Service, true, 10, 0, tracker)
                    end)
                    
                    if s and srvDump then
                        rawServiceResults[currentIdx] = srvDump
                    end
                end
            end
            activeWorkers = activeWorkers - 1
        end)
    end
    
    while activeWorkers > 0 do
        task.wait()
    end
    
    tracker:Finish("Volcado Total Finalizado")
    
    for _, srvDump in ipairs(rawServiceResults) do
        if srvDump then
            table.insert(dumpPackage.Services, srvDump)
        end
    end
    
    dumpPackage.TotalExtracted = tracker.completed
    dumpPackage.TotalScriptsDumped = tracker.scripts
    dumpPackage.TotalRemotesDumped = tracker.remotes
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Volcado Total Multihilo completado: %d scripts y %d remotes extraídos de %d servicios.",
            dumpPackage.TotalScriptsDumped, dumpPackage.TotalRemotesDumped, #dumpPackage.Services))
    end
    
    return dumpPackage
end

-- =============================================================================
-- MODO 5: Extracción de Interacciones en Vivo (RUNTIME_INTERACTIONS)
-- =============================================================================
function SelectiveDumper:DumpRuntimeInteractions(onProgress)
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.RUNTIME_INTERACTIONS,
        Timestamp = tick(),
        TotalExtracted = 0,
        ExtractedContainers = {},
        ExtractedScripts = {},
        CorrelatedRemotes = {},
    }
    
    local extractedMap = {}
    local scriptMap = {}
    local remoteMap = {}
    local liveSuspects = {}
    local timelineScripts = {}
    local timelineRemotes = {}
    
    -- 1. Desde CapabilityManager:GetRuntimeSuspects()
    if self.Caps and self.Caps.GetRuntimeSuspects then
        local suspects = self.Caps:GetRuntimeSuspects()
        for _, s in ipairs(suspects) do
            table.insert(liveSuspects, s)
        end
    end
    
    -- 2. Desde ActionRecorder
    local actionRecorder = self.Registry and self.Registry:Get("ActionRecorder")
    if actionRecorder then
        if actionRecorder.GetCorrelatedSuspects then
            local recSuspects = actionRecorder:GetCorrelatedSuspects()
            for _, s in ipairs(recSuspects) do
                table.insert(liveSuspects, s)
            end
        end
        for _, act in ipairs(actionRecorder:GetTimeline() or {}) do
            for _, ctrl in ipairs(act.ControllingScripts or {}) do
                if ctrl.Instance and not scriptMap[ctrl.Path] then
                    scriptMap[ctrl.Path] = true
                    table.insert(timelineScripts, { ctrl = ctrl, act = act })
                end
            end
            for _, rem in ipairs(act.CorrelatedRemotes or {}) do
                if rem.Path and not remoteMap[rem.Path] then
                    remoteMap[rem.Path] = true
                    table.insert(timelineRemotes, rem)
                end
            end
        end
    end
    
    -- 3. Desde RemoteAnalyzer
    local remoteAnalyzer = self.Registry and self.Registry:Get("RemoteAnalyzer")
    if remoteAnalyzer and remoteAnalyzer.GetHighRiskCallers then
        for _, caller in ipairs(remoteAnalyzer:GetHighRiskCallers()) do
            table.insert(liveSuspects, {
                Path = caller.Path,
                Score = caller.Score,
                Tags = { "ActiveRemoteCaller", caller.RiskLevel },
            })
        end
    end
    
    -- 4. Pre-cálculo total
    local targetFolders = {}
    for _, susp in ipairs(liveSuspects) do
        local inst = susp.Instance
        if not inst and susp.Path then
            pcall(function()
                local parts = string.split(susp.Path, ".")
                local curr = game
                for _, p in ipairs(parts) do
                    curr = curr:FindFirstChild(p)
                    if not curr then break end
                end
                inst = curr
            end)
        end
        if inst then
            local parentFolder = inst.Parent or inst
            if not extractedMap[parentFolder] then
                extractedMap[parentFolder] = true
                table.insert(targetFolders, parentFolder)
            end
        end
    end
    
    local containerWork = self:CalculateTotalWork(targetFolders, true, 4)
    local totalWork = #timelineScripts + #timelineRemotes + containerWork + #liveSuspects
    local tracker = createProgressTracker(totalWork, onProgress)
    
    for _, item in ipairs(timelineScripts) do
        tracker:Step(item.ctrl.Instance, true, false, "Decompilando Script de Acción")
        local code = self:SafeDecompile(item.ctrl.Instance)
        table.insert(dumpPackage.ExtractedScripts, {
            Name = item.ctrl.Name,
            Path = item.ctrl.Path,
            ClassName = item.ctrl.ClassName,
            ActionType = item.act.Type,
            Code = code,
        })
    end
    
    for _, rem in ipairs(timelineRemotes) do
        tracker:Step(nil, false, true, "Mapeando Remote de Acción")
        table.insert(dumpPackage.CorrelatedRemotes, {
            Name = rem.Name,
            Path = rem.Path,
            Method = rem.Method,
            RiskLevel = rem.RiskLevel,
            Confidence = rem.Confidence,
            TypeSignature = rem.TypeSignature,
            Snippet = rem.Snippet,
        })
    end
    
    for _, parentFolder in ipairs(targetFolders) do
        local containerDump = self:DumpInstance(parentFolder, true, 4, 0, tracker)
        if containerDump then
            table.insert(dumpPackage.ExtractedContainers, {
                Tags = { "LiveInteraction" },
                Score = 100,
                Path = parentFolder:GetFullName(),
                Data = containerDump,
            })
        end
    end
    
    tracker:Finish("Interacciones en Vivo Extraídas")
    dumpPackage.TotalExtracted = tracker.completed
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo RUNTIME_INTERACTIONS: %d contenedores, %d scripts interactuados y %d remotes extraídos.",
            #dumpPackage.ExtractedContainers, #dumpPackage.ExtractedScripts, #dumpPackage.CorrelatedRemotes))
    end
    
    return dumpPackage
end

return SelectiveDumper

