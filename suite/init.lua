--[[
    =============================================================================
    🛡️ APEX AUDIT & REVERSE ENGINE PRO (UNIVERSAL BOOTSTRAPPER)
    =============================================================================
    Sistema Modular de Auditoría Heurística, Dumper y Análisis de Seguridad.
    Totalmente adaptativo para niveles 3 a 8 con arquitectura desacoplada POO.
--]]

local function loadModule(relPath)
    -- Intento 1: Sistema de archivos local
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        local fullPath = "suite/" .. relPath
        if isfile(fullPath) then
            local src = readfile(fullPath)
            local fn, err = loadstring(src)
            if fn then return fn() end
        end
    end
    return nil
end

-- 1. Cargar Núcleo Base (Core)
local Class             = loadModule("code/core/Class.lua")
local CapabilityManager = loadModule("code/core/CapabilityManager.lua")
local EventBus          = loadModule("code/core/EventBus.lua")
local Logger            = loadModule("code/core/Logger.lua")
local Registry          = loadModule("code/core/Registry.lua")

-- 2. Cargar Seguridad (Security)
local SecurityCore      = loadModule("code/security/SecurityCore.lua")
local HookManager       = loadModule("code/security/HookManager.lua")
local MemoryGuard       = loadModule("code/security/MemoryGuard.lua")
local SafeSandbox       = loadModule("code/security/SafeSandbox.lua")

-- 3. Cargar Análisis y Heurística (Analysis)
local HeuristicEngine   = loadModule("code/analysis/HeuristicEngine.lua")
local StructuralProfiler= loadModule("code/analysis/StructuralProfiler.lua")
local RemoteAnalyzer    = loadModule("code/analysis/RemoteAnalyzer.lua")
local ActionRecorder    = loadModule("code/analysis/ActionRecorder.lua")
local EconomyAuditor    = loadModule("code/analysis/EconomyAuditor.lua")

-- 4. Cargar Dumper y Exportador (Dumper)
local VirtualTree       = loadModule("code/dumper/VirtualTree.lua")
local SelectiveDumper   = loadModule("code/dumper/SelectiveDumper.lua")
local ReportExporter    = loadModule("code/dumper/ReportExporter.lua")

-- 5. Cargar Integraciones (Integrations)
local ExternalTools     = loadModule("code/integrations/ExternalTools.lua")

-- 6. Cargar Interfaz Gráfica (GUI)
local MainWindow        = loadModule("gui/MainWindow.lua")

-----------------------------------------------------------------------------
-- INICIALIZACIÓN Y REGISTRO DE SERVICIOS
-----------------------------------------------------------------------------
local eventBus = EventBus and EventBus.new() or nil
local logger = Logger and Logger.new(eventBus) or nil
local registry = Registry and Registry.new() or nil

if registry and logger and eventBus then
    registry:Register("EventBus", eventBus)
    registry:Register("Logger", logger)
    
    local caps = CapabilityManager and CapabilityManager.new()
    if caps then registry:Register("CapabilityManager", caps) end
    
    local security = SecurityCore and SecurityCore.new(caps, logger)
    if security then
        registry:Register("SecurityCore", security)
        security:EnableAntiAFK()
    end
    
    local hooks = HookManager and HookManager.new(caps, logger)
    if hooks then
        registry:Register("HookManager", hooks)
        hooks:InstallHooks()
    end
    
    local memGuard = MemoryGuard and MemoryGuard.new(caps, logger)
    if memGuard then registry:Register("MemoryGuard", memGuard) end
    
    local sandbox = SafeSandbox and SafeSandbox.new(logger)
    if sandbox then registry:Register("SafeSandbox", sandbox) end
    
    local structural = StructuralProfiler and StructuralProfiler.new(logger)
    if structural then registry:Register("StructuralProfiler", structural) end
    
    local heuristic = HeuristicEngine and HeuristicEngine.new(caps, logger, structural)
    if heuristic then registry:Register("HeuristicEngine", heuristic) end
    
    local remoteAnalyzer = RemoteAnalyzer and RemoteAnalyzer.new(eventBus, logger)
    if remoteAnalyzer then
        registry:Register("RemoteAnalyzer", remoteAnalyzer)
        if hooks then
            hooks:AddRemoteListener(function(remote, method, args, isScriptCaller)
                remoteAnalyzer:ProcessRemoteCall(remote, method, args, isScriptCaller)
            end)
        end
    end
    
    local actionRecorder = ActionRecorder and ActionRecorder.new(eventBus, logger, caps)
    if actionRecorder then
        registry:Register("ActionRecorder", actionRecorder)
        if eventBus then
            eventBus:Subscribe("RemoteFired", function(entry)
                actionRecorder:CorrelateRemoteCall(entry)
            end)
        end
    end
    
    local economy = EconomyAuditor and EconomyAuditor.new(heuristic, logger, remoteAnalyzer)
    if economy then registry:Register("EconomyAuditor", economy) end
    
    local dumper = SelectiveDumper and SelectiveDumper.new(caps, logger)
    if dumper then registry:Register("SelectiveDumper", dumper) end
    
    local exporter = ReportExporter and ReportExporter.new(caps, logger)
    if exporter then registry:Register("ReportExporter", exporter) end
    
    local tools = ExternalTools and ExternalTools.new(logger)
    if tools then registry:Register("ExternalTools", tools) end
    
    -- Inicializar GUI Segura
    if security and MainWindow then
        local screenGui = security:CreateSafeScreenGui("ApexSuitePro")
        local window = MainWindow.new(screenGui, registry)
        registry:Register("MainWindow", window)
    end
    
    logger:Info("BOOT", "Apex Suite Pro inicializada con éxito. " .. (caps and caps:GetSummary() or ""))
end

return registry
