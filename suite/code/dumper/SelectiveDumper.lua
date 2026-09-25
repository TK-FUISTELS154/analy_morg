--[[
    =============================================================================
    APEX SUITE - ADVANCED MULTI-MODE SELECTIVE DUMPER & DEPENDENCY EXTRACTOR
    =============================================================================
    Motor de extracción profesional por modos:
    1. HEURISTIC_FINDINGS: Extrae todas las carpetas y scripts donde se detectaron firmas.
    2. DEPENDENCY_CHAIN: Extrae el script emisor, módulos intermedios y remotes relacionados.
    3. MANUAL_TREE: Extracción selectiva de nodos marcados por el usuario.
    4. FULL_ENVIRONMENT: Volcado total de scripts y módulos de todos los servicios cliente.
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

function SelectiveDumper.new(capabilityManager, logger)
    local self = setmetatable({}, SelectiveDumper)
    self.Caps = capabilityManager
    self.Logger = logger
    return self
end

function SelectiveDumper:DumpInstance(instance, includeChildren, depthLimit, currentDepth)
    currentDepth = currentDepth or 0
    if depthLimit and currentDepth > depthLimit then return nil end
    
    local dump = {
        Name = instance.Name,
        ClassName = instance.ClassName,
        Path = instance:GetFullName(),
        Attributes = {},
        Properties = {},
        Children = {},
        Source = nil,
        BytecodeSize = 0,
    }
    
    -- 1. Extracción de Atributos
    local sAttr, attrs = pcall(function() return instance:GetAttributes() end)
    if sAttr and attrs then dump.Attributes = attrs end
    
    -- 2. Extracción de Código Fuente o Bytecode
    if instance:IsA("LuaSourceContainer") then
        local src = self.Caps:SafeDecompile(instance)
        dump.Source = src
        if src then dump.BytecodeSize = #src end
    end
    
    -- 3. Propiedades Relevantes Seguras
    local commonProps = {"Archivable", "Name", "Parent"}
    if instance:IsA("ValueBase") then table.insert(commonProps, "Value") end
    
    for _, prop in ipairs(commonProps) do
        local s, v = pcall(function() return instance[prop] end)
        if s then dump.Properties[prop] = tostring(v) end
    end
    
    -- 4. Extracción de Hijos Recursiva
    if includeChildren then
        local s, children = pcall(function() return instance:GetChildren() end)
        if s and children then
            for _, child in ipairs(children) do
                local childDump = self:DumpInstance(child, true, depthLimit, currentDepth + 1)
                if childDump then table.insert(dump.Children, childDump) end
            end
        end
    end
    
    return dump
end

-- =========================================================================
-- MODOS DE EXTRACCIÓN AVANZADA
-- =========================================================================

-- MODO 1: Extracción de hallazgos heurísticos con sus carpetas contenedoras
function SelectiveDumper:DumpHeuristicFindings(auditResults)
    local extractedMap = {}
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.HEURISTIC_FINDINGS,
        Timestamp = tick(),
        TotalExtracted = 0,
        Containers = {},
    }
    
    local function collectFinding(finding)
        if not finding or not finding.Instance then return end
        local inst = finding.Instance
        local parentFolder = inst.Parent or inst
        
        if not extractedMap[parentFolder] then
            extractedMap[parentFolder] = true
            local containerDump = self:DumpInstance(parentFolder, true, 4)
            table.insert(dumpPackage.Containers, {
                FindingCategory = finding.Tags or {"Detected"},
                Score = finding.Score or 0,
                Path = parentFolder:GetFullName(),
                Data = containerDump,
            })
            dumpPackage.TotalExtracted = dumpPackage.TotalExtracted + 1
        end
    end
    
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
    end
    
    if self.Logger then
        self.Logger:Info("DUMPER", string.format("Modo HEURISTIC_FINDINGS: %d contenedores con hallazgos extraídos.", dumpPackage.TotalExtracted))
    end
    
    return dumpPackage
end

-- MODO 2: Extracción de cadena de ejecución (Código intermedio entre Action y Remote)
function SelectiveDumper:DumpDependencyChain(actionEntry)
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.DEPENDENCY_CHAIN,
        Timestamp = tick(),
        Action = actionEntry and actionEntry.Type or "Unknown",
        InitiatorInstance = nil,
        IntermediateScripts = {},
        RelatedRemotes = {},
    }
    
    if actionEntry then
        -- Extraer instancia iniciadora (e.g. Botón GUI o Tool o Prompt)
        if actionEntry.Instance then
            dumpPackage.InitiatorInstance = self:DumpInstance(actionEntry.Instance, true, 3)
            
            -- Buscar scripts hermanos o padres directos (código intermedio)
            local searchScope = actionEntry.Instance.Parent or actionEntry.Instance
            local s, desc = pcall(function() return searchScope:GetDescendants() end)
            if s and desc then
                for _, obj in ipairs(desc) do
                    if obj:IsA("LuaSourceContainer") then
                        table.insert(dumpPackage.IntermediateScripts, {
                            Path = obj:GetFullName(),
                            ClassName = obj.ClassName,
                            Code = self.Caps:SafeDecompile(obj),
                        })
                    end
                end
            end
        end
        
        -- Extraer Remotes involucrados
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
function SelectiveDumper:DumpManualNodes(nodeList)
    local results = {
        Mode = SelectiveDumper.DumpModes.MANUAL_TREE,
        Timestamp = tick(),
        Nodes = {},
    }
    for _, node in ipairs(nodeList) do
        table.insert(results.Nodes, self:DumpInstance(node, true))
    end
    return results
end

-- MODO 4: Extracción total del entorno de scripts del juego
function SelectiveDumper:DumpFullEnvironment()
    local targetServices = {
        game:GetService("ReplicatedFirst"),
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
        game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui"),
    }
    
    local dumpPackage = {
        Mode = SelectiveDumper.DumpModes.FULL_ENVIRONMENT,
        Timestamp = tick(),
        Services = {},
        TotalScriptsDumped = 0,
    }
    
    for _, srv in ipairs(targetServices) do
        if srv then
            local srvDump = self:DumpInstance(srv, true, 8)
            table.insert(dumpPackage.Services, srvDump)
        end
    end
    
    return dumpPackage
end

return SelectiveDumper
