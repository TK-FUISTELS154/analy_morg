--[[
    =============================================================================
    🛡️ APEX AUDIT & REVERSE ENGINE PRO (UNIVERSAL BOOTSTRAPPER)
    =============================================================================
    Sistema Modular de Auditoría Heurística, Dumper y Análisis de Seguridad.
    Totalmente adaptativo para niveles 3 a 8 con arquitectura desacoplada POO.
    Soporta ejecución local (filesystem) y remota vía GitHub HttpGet.
--]]

local GITHUB_REPO_RAW = "https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/"
local ModuleCache = {}

local function ApexImport(relPath)
    if ModuleCache[relPath] then
        return ModuleCache[relPath]
    end
    
    local codeStr = nil
    
    -- Intento 1: Sistema de archivos local
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        pcall(function()
            if isfile("suite/" .. relPath) then
                codeStr = readfile("suite/" .. relPath)
            elseif isfile(relPath) then
                codeStr = readfile(relPath)
            end
        end)
    end
    
    -- Intento 2: Descarga remota de GitHub HttpGet
    if not codeStr or #codeStr == 0 then
        pcall(function()
            local url = GITHUB_REPO_RAW .. relPath
            codeStr = game:HttpGet(url)
        end)
    end
    
    if codeStr and #codeStr > 0 then
        local fn, err = loadstring(codeStr)
        if fn then
            local result = fn()
            ModuleCache[relPath] = result
            return result
        else
            warn("[APEX BOOT] Error de sintaxis en módulo '" .. relPath .. "': " .. tostring(err))
        end
    else
        warn("[APEX BOOT] No se pudo cargar el módulo: " .. relPath)
    end
    
    return nil
end

getgenv()._APEX_IMPORT = ApexImport

-- 1. Cargar Núcleo Base (Core)
local Class             = ApexImport("code/core/Class.lua")
local CapabilityManager = ApexImport("code/core/CapabilityManager.lua")
local EventBus          = ApexImport("code/core/EventBus.lua")
local Logger            = ApexImport("code/core/Logger.lua")
local Registry          = ApexImport("code/core/Registry.lua")

-- 2. Cargar Seguridad (Security)
local SecurityCore      = ApexImport("code/security/SecurityCore.lua")
local HookManager       = ApexImport("code/security/HookManager.lua")
local MemoryGuard       = ApexImport("code/security/MemoryGuard.lua")
local SafeSandbox       = ApexImport("code/security/SafeSandbox.lua")

-- 3. Cargar Análisis y Heurística (Analysis)
local StructuralProfiler= ApexImport("code/analysis/StructuralProfiler.lua")
local HeuristicEngine   = ApexImport("code/analysis/HeuristicEngine.lua")
local RemoteAnalyzer    = ApexImport("code/analysis/RemoteAnalyzer.lua")
local ActionRecorder    = ApexImport("code/analysis/ActionRecorder.lua")
local EconomyAuditor    = ApexImport("code/analysis/EconomyAuditor.lua")

-- 4. Cargar Dumper y Exportador (Dumper)
local VirtualTree       = ApexImport("code/dumper/VirtualTree.lua")
local SelectiveDumper   = ApexImport("code/dumper/SelectiveDumper.lua")
local ReportExporter    = ApexImport("code/dumper/ReportExporter.lua")

-- 5. Cargar Integraciones (Integrations)
local ExternalTools     = ApexImport("code/integrations/ExternalTools.lua")

-- 6. Cargar Interfaz Gráfica (GUI)
local MainWindow        = ApexImport("gui/MainWindow.lua")

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
    
    local structural = StructuralProfiler and StructuralProfiler.new(logger, caps)
    if structural then registry:Register("StructuralProfiler", structural) end
    
    local heuristic = HeuristicEngine and HeuristicEngine.new(caps, logger, structural)
    if heuristic then registry:Register("HeuristicEngine", heuristic) end
    
    local remoteAnalyzer = RemoteAnalyzer and RemoteAnalyzer.new(eventBus, logger, heuristic)
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
