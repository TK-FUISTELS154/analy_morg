--[[
    =============================================================================
    APEX SUITE - ACTION RECORDER v4.0
    (USER INTERACTION & REVERSE ENGINEERING PIPELINE)
    =============================================================================
    Motor de Trazabilidad Causal de Interacciones del Usuario:
      1. Captura Total de Entidades Interactivas (2D y 3D):
         - Interfaces 2D: GuiButton, TextBox, contenedores interactivos (PlayerGui)
         - Mundo 3D: ProximityPrompt, ClickDetector, Tool equipado, SurfaceGui,
           BillboardGui (raycasting desde cámara)
      2. Trazabilidad Causal Estricta (Acción → Script → Red):
         - Ruta absoluta del objeto (GetFullName)
         - Scripts locales que controlan el evento (ancestros + conexiones)
         - RemoteEvent/RemoteFunction disparados dentro de ventana dinámica (Ping+350ms)
         - Comparación semántica de nombres/payloads para correlación causal al 100%
      3. Extracción y Descompilación Selectiva vía CapabilityManager:SafeDecompile
      4. Generador Autónomo de Automatización con WaitForChild resiliente
--]]

local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local ActionRecorder = {}
ActionRecorder.__index = ActionRecorder
ActionRecorder.ClassName = "ActionRecorder"

-- Tipos de Extracción Inteligente
ActionRecorder.ExtractionType = {
    UI_REMOTE_BUNDLE        = "UI_REMOTE_BUNDLE",
    WORLD_INTERACTION_BUNDLE= "WORLD_INTERACTION_BUNDLE",
    COMBAT_TOOL_BUNDLE      = "COMBAT_TOOL_BUNDLE",
    FULL_EXECUTION_TRACE    = "FULL_EXECUTION_TRACE",
}

-- Bibliotecas de terceros a omitir en descompilación
local IGNORED_LIBRARY_PATTERNS = {
    "Packages", "_Index", "Janitor", "Promise", "Vendor", "Roact", "Rodux",
    "Fusion", "Flipper", "TopbarPlus", "GoodSignal", "Signal", "Knit",
    "%.spec", "%.test", "Jest", "TestEZ", "pkg",
}

function ActionRecorder.new(eventBus, logger, capabilityManager)
    local self = setmetatable({}, ActionRecorder)
    self.EventBus = eventBus
    self.Logger = logger
    self.Caps = capabilityManager

    self.IsRecording = false
    self.RecordedTimeline = {}  -- Array cronológico de acciones (más reciente primero)
    self.RecentAction = nil     -- Última acción registrada para correlación
    self.Connections = {}
    self.LocalPlayer = Players.LocalPlayer

    -- =========================================================================
    -- VENTANA DE CORRELACIÓN DINÁMICA (Ping + 350ms)
    -- Se recalcula cada vez que se necesita, basada en la latencia real del jugador
    -- =========================================================================
    self.BaseCorrelationOffset = 0.350  -- 350ms base de tolerancia
    self.MinCorrelationWindow = 0.200   -- Mínimo 200ms
    self.MaxCorrelationWindow = 1.500   -- Máximo 1.5s (conexiones muy malas)

    if self.EventBus then
        self.EventBus:Subscribe("RemoteFired", function(remoteEntry)
            self:CorrelateRemoteCall(remoteEntry)
        end)
    end

    return self
end

-- =============================================================================
-- UTILIDADES DE RUTAS Y FILTROS
-- =============================================================================

function ActionRecorder:GetCachedPath(inst)
    if not inst then return nil end
    -- Delegar a CapabilityManager si disponible (Shared Memory Store)
    if self.Caps then
        return self.Caps:GetPath(inst)
    end
    local s, full = pcall(function() return inst:GetFullName() end)
    return (s and full) or tostring(inst)
end

function ActionRecorder:IsIgnoredLibraryScript(inst)
    if not inst then return true end
    local path = self:GetCachedPath(inst) or ""
    for _, pat in ipairs(IGNORED_LIBRARY_PATTERNS) do
        if path:find(pat) then return true end
    end
    return false
end

-- =============================================================================
-- VENTANA DE LATENCIA DINÁMICA (Ping + 350ms)
-- =============================================================================

function ActionRecorder:GetDynamicCorrelationWindow()
    local pingMs = 0
    pcall(function()
        pingMs = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local pingSec = math.max(pingMs / 1000, 0)
    local window = pingSec + self.BaseCorrelationOffset
    return math.clamp(window, self.MinCorrelationWindow, self.MaxCorrelationWindow)
end

-- =============================================================================
-- SNAPSHOT DEL JUGADOR (Estado físico para verificación en replay)
-- =============================================================================

function ActionRecorder:GetCurrentPlayerSnapshot()
    -- 1. Intentar obtener el snapshot oficial de 24 parámetros desde PhysicsAuditor
    local physicsAuditor = (self.Registry and self.Registry:Get("PhysicsAuditor"))
        or (self.Caps and self.Caps.PhysicsAuditor)
        or (getgenv and getgenv()._APEX_PHYSICS_AUDITOR)
    
    local snap = nil
    if physicsAuditor and type(physicsAuditor.CapturePlayerPhysicsSnapshot) == "function" then
        local s, res = pcall(function() return physicsAuditor:CapturePlayerPhysicsSnapshot() end)
        if s and type(res) == "table" then
            snap = res
        end
    end

    -- 2. Estructura fallback si PhysicsAuditor aún no está inicializado
    if not snap then
        snap = {
            Timestamp = tick(),
            IsAlive = true,
            Gravity = Workspace.Gravity,
            FallenPartsDestroyHeight = Workspace.FallenPartsDestroyHeight,
            WalkSpeed = 16,
            JumpPower = 50,
            JumpHeight = 7.2,
            UseJumpPower = true,
            HipHeight = 0,
            MaxSlopeAngle = 89,
            AutoRotate = true,
            PlatformStand = false,
            Sit = false,
            HumanoidState = "None",
            MoveDirection = Vector3.zero,
            MoveDirectionMagnitude = 0,
            Position = Vector3.zero,
            CFrame = nil,
            LinearVelocity = Vector3.zero,
            AngularVelocity = Vector3.zero,
            HorizontalSpeed = 0,
            VerticalSpeed = 0,
            AssemblyMass = 0,
            CanCollide = true,
            TorsoCanCollide = nil,
            UpperTorsoCanCollide = nil,
            LowerTorsoCanCollide = nil,
            AnatomicalCollisions = {},
            FloorMaterial = "None",
            FloorDistance = nil,
            ForcesDetected = {},
            NetworkOwnership = "Client",
            Health = 100,
            MaxHealth = 100,
        }

        pcall(function()
            local char = self.LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    snap.Position = hrp.Position
                    snap.CFrame = tostring(hrp.CFrame)
                    snap.AssemblyMass = hrp.AssemblyMass
                end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    snap.WalkSpeed = hum.WalkSpeed
                    snap.Health = hum.Health
                    snap.MaxHealth = hum.MaxHealth
                    snap.IsAlive = hum.Health > 0
                    snap.UseJumpPower = hum.UseJumpPower
                    snap.MoveDirection = hum.MoveDirection
                    snap.MoveDirectionMagnitude = hum.MoveDirection.Magnitude
                end
            end
        end)
    end

    -- 3. Enriquecer con telemetría de interacción del cursor y herramientas
    pcall(function()
        local mouse = self.LocalPlayer:GetMouse()
        if mouse then
            snap.MouseTarget = mouse.Target and self:GetCachedPath(mouse.Target) or nil
            snap.MouseHit = mouse.Hit and tostring(mouse.Hit.Position) or nil
        end

        local char = self.LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                snap.EquippedTool = self:GetCachedPath(tool)
            end
        end
    end)

    return snap
end

-- =============================================================================
-- DESCUBRIMIENTO DE SCRIPTS CONTROLADORES (v5.0: getconnections + Clousures + Ancestor Fallback)
-- =============================================================================

function ActionRecorder:DiscoverControllingScripts(targetInstance)
    local scripts = {}
    if not targetInstance then return scripts end

    local visited = {}
    local function addScript(child, matchReason)
        if not child or not child:IsA("LuaSourceContainer") then return end
        if self:IsIgnoredLibraryScript(child) then return end
        local fullName = self:GetCachedPath(child)
        if not visited[fullName] then
            visited[fullName] = true
            local src = nil
            if self.Caps then
                src = self.Caps:SafeDecompile(child)
            end
            table.insert(scripts, {
                Instance = child,
                Path = fullName,
                Name = child.Name,
                ClassName = child.ClassName,
                SourcePreview = src and src:sub(1, 500) or nil,
                HasSource = src ~= nil and #(src or "") > 0,
                MatchReason = matchReason or "Ancestor",
            })
        end
    end

    -- 1. Inspección de conexiones activas vía getconnections() nativo
    local getconn = (type(getconnections) == "function" and getconnections)
        or (self.Caps and self.Caps.APIs and self.Caps.APIs.getconnections)
    
    if getconn then
        local signalsToInspect = {}
        if targetInstance:IsA("GuiButton") then
            pcall(function() table.insert(signalsToInspect, targetInstance.MouseButton1Click) end)
            pcall(function() table.insert(signalsToInspect, targetInstance.Activated) end)
            pcall(function() table.insert(signalsToInspect, targetInstance.MouseButton1Down) end)
        elseif targetInstance:IsA("TextBox") then
            pcall(function() table.insert(signalsToInspect, targetInstance.FocusLost) end)
        elseif targetInstance:IsA("ProximityPrompt") then
            pcall(function() table.insert(signalsToInspect, targetInstance.Triggered) end)
        elseif targetInstance:IsA("ClickDetector") then
            pcall(function() table.insert(signalsToInspect, targetInstance.MouseClick) end)
        elseif targetInstance:IsA("Tool") then
            pcall(function() table.insert(signalsToInspect, targetInstance.Activated) end)
            pcall(function() table.insert(signalsToInspect, targetInstance.Equipped) end)
        end

        for _, signal in ipairs(signalsToInspect) do
            local s, conns = pcall(getconn, signal)
            if s and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local fn = c.Function
                    if fn and type(fn) == "function" then
                        local scriptObj = nil
                        pcall(function()
                            local env = getfenv(fn)
                            if env and env.script and typeof(env.script) == "Instance" then
                                scriptObj = env.script
                            end
                        end)

                        if not scriptObj and debug and debug.getinfo then
                            pcall(function()
                                local info = debug.getinfo(fn)
                                if info and info.source then
                                    local srcPath = info.source:gsub("^@", "")
                                    for _, sInst in ipairs(game:GetDescendants()) do
                                        if sInst:IsA("LuaSourceContainer") and (sInst:GetFullName() == srcPath or sInst.Name == srcPath) then
                                            scriptObj = sInst
                                            break
                                        end
                                    end
                                end
                            end)
                        end

                        if scriptObj then
                            addScript(scriptObj, "getconnections")
                        end
                    end
                end
            end
        end
    end

    -- 2. Fallback: Búsqueda en descendientes y ancestros
    local searchRoots = { targetInstance }
    local parent = targetInstance.Parent
    if parent then table.insert(searchRoots, parent) end

    local ancestorModel = targetInstance:FindFirstAncestorOfClass("Model")
    local ancestorScreenGui = targetInstance:FindFirstAncestorOfClass("ScreenGui")
    if ancestorModel then table.insert(searchRoots, ancestorModel) end
    if ancestorScreenGui then table.insert(searchRoots, ancestorScreenGui) end

    for _, root in ipairs(searchRoots) do
        local s, children = pcall(function() return root:GetDescendants() end)
        if s and children then
            for _, child in ipairs(children) do
                if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                    addScript(child, "AncestorTree")
                end
            end
        end
    end

    return scripts
end

-- =============================================================================
-- REGISTRO DE ACCIONES
-- =============================================================================

function ActionRecorder:RegisterAction(actionType, details, relatedInstance)
    local now = tick()
    local snapshot = self:GetCurrentPlayerSnapshot()
    local controllingScripts = self:DiscoverControllingScripts(relatedInstance)

    local actionEntry = {
        Id = string.format("ACT_%d_%d", math.floor(now), math.random(100, 999)),
        Timestamp = now,
        Type = actionType,
        Details = details or {},
        Instance = relatedInstance,
        InstancePath = relatedInstance and self:GetCachedPath(relatedInstance) or nil,
        Snapshot = snapshot,
        ControllingScripts = controllingScripts,
        CorrelatedRemotes = {},
        CorrelationWindow = self:GetDynamicCorrelationWindow(),
    }

    self.RecentAction = actionEntry
    table.insert(self.RecordedTimeline, 1, actionEntry)

    -- Limitar timeline a 250 entradas
    if #self.RecordedTimeline > 250 then
        table.remove(self.RecordedTimeline)
    end

    if self.EventBus then
        self.EventBus:Publish("ActionRecorded", actionEntry)
    end

    if self.Logger then
        self.Logger:Info("RECORDER", string.format(
            "[%s] %s → %d scripts descubiertos (ventana: %.0fms)",
            actionType,
            actionEntry.InstancePath or "N/A",
            #controllingScripts,
            actionEntry.CorrelationWindow * 1000
        ))
    end

    return actionEntry
end

-- =============================================================================
-- CORRELACIÓN CAUSAL (Acción → Red)
-- =============================================================================
-- Compara semánticamente los nombres del botón, textos, herramientas e
-- identificadores con la carga útil (payload) del remoto para garantizar
-- correlación causal.

function ActionRecorder:CalculateCausalConfidence(action, remoteEntry)
    local confidence = 0.4 -- Base temporal
    local matchReason = "Temporal Proximity"

    local actDetails = action.Details or {}
    local keywords = {}

    -- Recolectar todas las palabras clave de la acción del usuario
    local function addKeyword(val)
        if val and type(val) == "string" and #val >= 2 then
            table.insert(keywords, val:lower())
        end
    end

    addKeyword(actDetails.ButtonName)
    addKeyword(actDetails.TextOrImage)
    addKeyword(actDetails.ActionText)
    addKeyword(actDetails.ObjectText)
    addKeyword(actDetails.ToolName)
    addKeyword(actDetails.PromptParent)
    addKeyword(actDetails.ClickDetectorParent)
    addKeyword(actDetails.Key)
    addKeyword(actDetails.SurfaceGuiName)
    addKeyword(actDetails.BillboardGuiName)

    local remName = (remoteEntry.Name or ""):lower()
    local remArgs = remoteEntry.Args or {}

    -- Comparación semántica multinivel
    for _, kw in ipairs(keywords) do
        if #kw >= 3 then
            -- Nivel 1: Nombre del remote contiene la keyword de la acción
            if remName:find(kw, 1, true) then
                confidence = math.max(confidence, 0.85)
                matchReason = string.format("Nombre del remote contiene '%s'", kw)
            end

            -- Nivel 2: Argumentos del remote contienen la keyword (correlación al 100%)
            for _, arg in ipairs(remArgs) do
                local argStr = tostring(arg):lower()
                if argStr:find(kw, 1, true) or kw:find(argStr, 1, true) then
                    confidence = 1.0
                    matchReason = string.format("Argumento '%s' coincide con contexto '%s'", argStr, kw)
                    break
                end
            end
            if confidence >= 1.0 then break end
        end
    end

    -- Nivel 3: Scripts controladores coinciden con el script emisor del remote
    if remoteEntry.CallingScript and action.ControllingScripts then
        local callerPath = tostring(remoteEntry.CallingScript):lower()
        for _, ctrlScript in ipairs(action.ControllingScripts) do
            if callerPath:find(ctrlScript.Name:lower(), 1, true) then
                confidence = math.max(confidence, 0.95)
                matchReason = string.format("Script emisor '%s' coincide con controlador '%s'", remoteEntry.CallingScript, ctrlScript.Name)
                break
            end
        end
    end

    -- Penalización: clicks de UI con argumento de posición pura = probablemente ruido
    if action.Type == "UIClick" and #remArgs == 1 and typeof(remArgs[1]) == "Vector3" then
        confidence = math.min(confidence, 0.15)
        matchReason = "Probable actualización de física en segundo plano"
    end

    return confidence, matchReason
end

function ActionRecorder:CorrelateRemoteCall(remoteEntry)
    if not self.IsRecording or not self.RecentAction then return end

    local now = tick()
    local action = self.RecentAction
    local delta = now - action.Timestamp
    local window = action.CorrelationWindow or self:GetDynamicCorrelationWindow()

    if delta <= window then
        local confidence, reason = self:CalculateCausalConfidence(action, remoteEntry)

        -- Solo vincular si la confianza supera el umbral (descartar ruido)
        if confidence >= 0.30 then
            table.insert(action.CorrelatedRemotes, {
                DeltaTime = delta,
                Remote = remoteEntry.Remote,
                Name = remoteEntry.Name,
                Path = remoteEntry.Path,
                Method = remoteEntry.Method,
                Args = remoteEntry.Args,
                ArgsCount = remoteEntry.ArgsCount,
                TypeSignature = remoteEntry.TypeSignature,
                Snippet = remoteEntry.Snippet,
                CallingScript = remoteEntry.CallingScript,
                RiskLevel = remoteEntry.RiskLevel,
                Confidence = confidence,
                CausalMatch = reason,
            })

            if self.Logger then
                self.Logger:Info("CORRELATION", string.format(
                    "[%s] → [%s] (Δ%.0fms, Confianza: %d%% - %s)",
                    action.Type, remoteEntry.Name,
                    delta * 1000,
                    math.floor(confidence * 100), reason
                ))
            end

            -- Inyección Causal Directa al Almacén Global (RuntimeSuspectRegistry)
            if confidence >= 0.70 and self.Caps then
                if action.Instance then
                    self.Caps:RegisterSuspect(action.Instance, "RuntimeActionCorrelated", 100, {
                        ActionType = action.Type,
                        Remote = remoteEntry.Path,
                        Confidence = confidence,
                    })
                end
                for _, ctrl in ipairs(action.ControllingScripts or {}) do
                    if ctrl.Instance then
                        self.Caps:RegisterSuspect(ctrl.Instance, "RuntimeActionCorrelatedScript", 100, {
                            ActionType = action.Type,
                            Remote = remoteEntry.Path,
                            Confidence = confidence,
                        })
                    end
                end
                if remoteEntry.Remote then
                    self.Caps:RegisterSuspect(remoteEntry.Remote, "RuntimeCorrelatedRemote", 100, {
                        ActionType = action.Type,
                        Confidence = confidence,
                        Method = remoteEntry.Method,
                    })
                end
            end

            if self.EventBus then
                self.EventBus:Publish("ActionCorrelated", action)
            end
        end
    end
end

-- =============================================================================
-- GENERADOR AUTÓNOMO DE AUTOMATIZACIÓN / REPRODUCCIÓN (Resilient Replay)
-- =============================================================================
-- Genera script Lua modular y parametrizado con:
--   - WaitForChild resiliente con timeout
--   - RepeatCount, DelayBetween, CustomArgs
--   - Verificación de estado del personaje (vida, controles)

function ActionRecorder:GenerateParametrizedScript(targetAction, correlatedRemotes)
    if not correlatedRemotes or #correlatedRemotes == 0 then
        return "-- [APEX] No hay remotos correlacionados para generar script de replay."
    end

    local lines = {
        "-- ============================================================================",
        "-- [APEX SUITE v4.0] RESILIENT PARAMETRIZED REPLAY SCRIPT",
        string.format("-- Acción: %s | ID: %s | Generado: %s", targetAction.Type, targetAction.Id, os.date("%X")),
        string.format("-- Ventana de Correlación: %.0fms | Remotos Vinculados: %d", (targetAction.CorrelationWindow or 0.5) * 1000, #correlatedRemotes),
        "-- ============================================================================",
        "",
        "local Players = game:GetService('Players')",
        "local LocalPlayer = Players.LocalPlayer",
        "",
        "-- Resolución resiliente de remotos con WaitForChild y timeout",
        "local function ResolveRemote(path, timeout)",
        "    timeout = timeout or 10",
        "    local parts = string.split(path, '.')",
        "    local current = game",
        "    for _, part in ipairs(parts) do",
        "        local child = current:WaitForChild(part, timeout)",
        "        if not child then",
        "            warn('[APEX Replay] No se encontró: ' .. part .. ' en ' .. tostring(current))",
        "            return nil",
        "        end",
        "        current = child",
        "    end",
        "    return current",
        "end",
        "",
        "-- Verificación de estado del personaje",
        "local function IsPlayerReady()",
        "    local char = LocalPlayer.Character",
        "    if not char then return false end",
        "    local hum = char:FindFirstChildOfClass('Humanoid')",
        "    if not hum or hum.Health <= 0 then return false end",
        "    return true",
        "end",
        "",
        "local function ExecuteRecordedAction(options)",
        "    options = options or {}",
        "    local repeatCount = options.RepeatCount or 1",
        "    local delayBetween = options.DelayBetween or 0.1",
        "    local customArgs = options.CustomArgs -- { [1] = {arg1, arg2}, [2] = {argA} }",
        "    local requireAlive = (options.RequireAlive ~= false)  -- true por defecto",
        "",
        "    for iteration = 1, repeatCount do",
        "        -- Verificar que el jugador esté vivo antes de cada iteración",
        "        if requireAlive and not IsPlayerReady() then",
        "            warn('[APEX Replay] Jugador no disponible en iteración ' .. iteration .. ', pausando...')",
        "            repeat task.wait(0.5) until IsPlayerReady()",
        "        end",
        "",
    }

    for idx, rem in ipairs(correlatedRemotes) do
        local remotePath = rem.Path or "game"
        -- Convertir GetFullName path a puntos para WaitForChild
        local dotPath = remotePath:gsub("/", "."):gsub("\\", ".")

        table.insert(lines, string.format("        -- Invocación %d: %s [Confianza: %d%% | Riesgo: %s]",
            idx, rem.Name or "Unknown", math.floor((rem.Confidence or 1) * 100), rem.RiskLevel or "N/A"))
        table.insert(lines, string.format("        -- Causa: %s", rem.CausalMatch or "Direct"))
        table.insert(lines, string.format("        local remote_%d = ResolveRemote('%s')", idx, dotPath))
        table.insert(lines, string.format("        if remote_%d then", idx))
        table.insert(lines, string.format("            if customArgs and customArgs[%d] then", idx))
        table.insert(lines, string.format("                remote_%d:%s(table.unpack(customArgs[%d]))", idx, rem.Method or "FireServer", idx))
        table.insert(lines, "            else")

        -- Generar la llamada con los argumentos originales capturados
        local snippet = rem.Snippet
        if snippet and #snippet > 0 then
            table.insert(lines, string.format("                -- Llamada original capturada:"))
            table.insert(lines, string.format("                -- %s", snippet:sub(1, 200)))
            table.insert(lines, string.format("                remote_%d:%s() -- Argumentos originales arriba como referencia", idx, rem.Method or "FireServer"))
        else
            table.insert(lines, string.format("                remote_%d:%s()", idx, rem.Method or "FireServer"))
        end

        table.insert(lines, "            end")
        table.insert(lines, "        end")

        if idx < #correlatedRemotes then
            table.insert(lines, "        task.wait(0.05)")
        end
        table.insert(lines, "")
    end

    table.insert(lines, "        if iteration < repeatCount then")
    table.insert(lines, "            task.wait(delayBetween)")
    table.insert(lines, "        end")
    table.insert(lines, "    end")
    table.insert(lines, "    print('[APEX Replay] Ejecución completada: ' .. repeatCount .. ' iteraciones')")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "-- ========================================")
    table.insert(lines, "-- Ejemplos de uso:")
    table.insert(lines, "-- ========================================")
    table.insert(lines, "-- ExecuteRecordedAction({ RepeatCount = 10, DelayBetween = 0.2, RequireAlive = true })")
    table.insert(lines, "-- ExecuteRecordedAction({ RepeatCount = 1, CustomArgs = { [1] = {'CañaDorada', 3} } })")
    table.insert(lines, "return ExecuteRecordedAction")

    return table.concat(lines, "\n")
end

-- =============================================================================
-- SISTEMA DE EXTRACCIÓN INTELIGENTE POR TIPOS
-- =============================================================================

function ActionRecorder:ExtractBundle(actionId, extractionType)
    local targetAction = nil
    if actionId then
        for _, act in ipairs(self.RecordedTimeline) do
            if act.Id == actionId then
                targetAction = act
                break
            end
        end
    end

    if not targetAction then
        targetAction = self.RecentAction
    end

    if not targetAction then
        return nil, "No hay acciones registradas para extraer."
    end

    local bundle = {
        BundleType = extractionType or ActionRecorder.ExtractionType.FULL_EXECUTION_TRACE,
        ActionId = targetAction.Id,
        ActionType = targetAction.Type,
        Timestamp = targetAction.Timestamp,
        TargetDetails = targetAction.Details,
        InstancePath = targetAction.InstancePath,
        ControllingScripts = targetAction.ControllingScripts,
        CapturedRemotes = targetAction.CorrelatedRemotes,
        ExtractedScripts = {},
        ExtractedInstances = {},
        GeneratedScript = nil,
    }

    -- Función de extracción de código fuente vía CapabilityManager (sin caché local)
    local function extractScriptSource(inst)
        if inst and inst:IsA("LuaSourceContainer") and not self:IsIgnoredLibraryScript(inst) and self.Caps then
            local fullName = self:GetCachedPath(inst)
            if not bundle.ExtractedScripts[fullName] then
                local src = self.Caps:SafeDecompile(inst)
                if src then
                    bundle.ExtractedScripts[fullName] = src
                end
            end
        end
    end

    -- Extraer scripts de los controladores ya descubiertos
    if targetAction.ControllingScripts then
        for _, ctrlInfo in ipairs(targetAction.ControllingScripts) do
            if ctrlInfo.Instance and not bundle.ExtractedScripts[ctrlInfo.Path] then
                extractScriptSource(ctrlInfo.Instance)
            end
        end
    end

    -- 1. UI_REMOTE_BUNDLE
    if extractionType == ActionRecorder.ExtractionType.UI_REMOTE_BUNDLE then
        if targetAction.Instance then
            table.insert(bundle.ExtractedInstances, self:GetCachedPath(targetAction.Instance))
            local screenGui = targetAction.Instance:FindFirstAncestorOfClass("ScreenGui")
            if screenGui then
                local s, desc = pcall(function() return screenGui:GetDescendants() end)
                if s and desc then
                    for _, child in ipairs(desc) do
                        extractScriptSource(child)
                    end
                end
            end
        end

    -- 2. WORLD_INTERACTION_BUNDLE
    elseif extractionType == ActionRecorder.ExtractionType.WORLD_INTERACTION_BUNDLE then
        if targetAction.Instance then
            local parentModel = targetAction.Instance:FindFirstAncestorOfClass("Model") or targetAction.Instance
            table.insert(bundle.ExtractedInstances, self:GetCachedPath(parentModel))
            local s, desc = pcall(function() return parentModel:GetDescendants() end)
            if s and desc then
                for _, child in ipairs(desc) do
                    extractScriptSource(child)
                end
            end
        end

    -- 3. COMBAT_TOOL_BUNDLE
    elseif extractionType == ActionRecorder.ExtractionType.COMBAT_TOOL_BUNDLE then
        local char = self.LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            table.insert(bundle.ExtractedInstances, self:GetCachedPath(tool))
            local s, desc = pcall(function() return tool:GetDescendants() end)
            if s and desc then
                for _, child in ipairs(desc) do
                    extractScriptSource(child)
                end
            end
        end

    -- 4. FULL_EXECUTION_TRACE
    else
        bundle.PlayerSnapshot = targetAction.Snapshot
        if targetAction.Instance then
            table.insert(bundle.ExtractedInstances, self:GetCachedPath(targetAction.Instance))
            extractScriptSource(targetAction.Instance)
        end
    end

    -- Generar Script Parametrizado de Replay
    bundle.GeneratedScript = self:GenerateParametrizedScript(targetAction, targetAction.CorrelatedRemotes)

    -- Contar scripts extraídos (es un diccionario, no un array)
    local scriptCount = 0
    for _ in pairs(bundle.ExtractedScripts) do scriptCount = scriptCount + 1 end

    if self.Logger then
        self.Logger:Info("RECORDER", string.format(
            "Paquete [%s] generado: %d remotes, %d scripts, %d instancias.",
            bundle.BundleType, #bundle.CapturedRemotes, scriptCount, #bundle.ExtractedInstances
        ))
    end

    return bundle
end

-- =============================================================================
-- RAYCASTING 3D: Detección de SurfaceGui, BillboardGui y ClickDetector
-- =============================================================================

function ActionRecorder:Raycast3DFromCamera(screenPos)
    local camera = Workspace.CurrentCamera
    if not camera then return nil, nil end

    local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { self.LocalPlayer.Character }

    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if not result or not result.Instance then return nil, nil end

    local hitPart = result.Instance
    local hitPosition = result.Position
    local parentModel = hitPart:FindFirstAncestorOfClass("Model")

    -- 1. Verificar si el part tiene SurfaceGui directo
    local surfaceGui = hitPart:FindFirstChildOfClass("SurfaceGui")
    -- 2. Verificar BillboardGui directo en el part o su modelo padre
    local billboard = hitPart:FindFirstChildOfClass("BillboardGui") or (parentModel and parentModel:FindFirstChildOfClass("BillboardGui"))

    -- 3. Si no se encontró en el workspace, buscar interfaces en PlayerGui cuyo .Adornee apunte a hitPart o parentModel
    if not surfaceGui and not billboard then
        local playerGui = self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local s, guis = pcall(function() return playerGui:GetDescendants() end)
            if s and guis then
                for _, gui in ipairs(guis) do
                    if gui:IsA("SurfaceGui") or gui:IsA("BillboardGui") then
                        local adornee = gui.Adornee or gui.Parent
                        if adornee == hitPart or (parentModel and adornee == parentModel) then
                            if gui:IsA("SurfaceGui") then
                                surfaceGui = gui
                            else
                                billboard = gui
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    if surfaceGui then
        return "SurfaceGui", {
            SurfaceGuiName = surfaceGui.Name,
            SurfaceGuiPath = self:GetCachedPath(surfaceGui),
            HitPart = hitPart.Name,
            HitPartPath = self:GetCachedPath(hitPart),
            HitPosition = tostring(hitPosition),
            IsAdorneeFromPlayerGui = (surfaceGui.Parent ~= hitPart),
        }, surfaceGui
    end

    if billboard then
        return "BillboardGui", {
            BillboardGuiName = billboard.Name,
            BillboardGuiPath = self:GetCachedPath(billboard),
            HitPart = hitPart.Name,
            HitPartPath = self:GetCachedPath(hitPart),
            HitPosition = tostring(hitPosition),
            IsAdorneeFromPlayerGui = (billboard.Parent ~= hitPart and billboard.Parent ~= parentModel),
        }, billboard
    end

    -- 4. Verificar ClickDetector en el part o ancestros
    local clickDetector = hitPart:FindFirstChildOfClass("ClickDetector")
    if not clickDetector and hitPart.Parent then
        clickDetector = hitPart.Parent:FindFirstChildOfClass("ClickDetector")
    end
    if clickDetector then
        return "ClickDetector", {
            ClickDetectorParent = clickDetector.Parent and clickDetector.Parent.Name or "Unknown",
            ClickDetectorPath = self:GetCachedPath(clickDetector),
            MaxActivationDistance = clickDetector.MaxActivationDistance,
            HitPart = hitPart.Name,
            HitPosition = tostring(hitPosition),
        }, clickDetector.Parent or hitPart
    end

    -- 5. Objeto genérico del mundo (modelo, part interactivo)
    return "WorldObject", {
        ObjectName = hitPart.Name,
        ObjectClass = hitPart.ClassName,
        ObjectPath = self:GetCachedPath(hitPart),
        ModelPath = parentModel and self:GetCachedPath(parentModel) or nil,
        HitPosition = tostring(hitPosition),
    }, hitPart
end

-- =============================================================================
-- CONTROL DE GRABACIÓN Y LISTENERS CENTRALIZADOS
-- =============================================================================

function ActionRecorder:Start()
    if self.IsRecording then return end
    self.IsRecording = true
    self:StopConnections()

    -- =====================================================================
    -- 1. LISTENER DELEGADO DE UI 2D (GuiButton, TextBox, contenedores)
    -- =====================================================================
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not self.IsRecording then return end

        local inputType = input.UserInputType
        local isClick = (inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch)

        if isClick then
            -- Primero: intentar detectar UI 2D
            local playerGui = self.LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                local s, guiObjects = pcall(function()
                    return playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
                end)

                if s and guiObjects and #guiObjects > 0 then
                    for _, obj in ipairs(guiObjects) do
                        if obj:IsA("GuiButton") or obj:IsA("TextBox") then
                            local btnText = ""
                            if obj:IsA("TextButton") or obj:IsA("TextBox") then
                                btnText = obj.Text or ""
                            elseif obj:IsA("ImageButton") then
                                btnText = obj.Image or ""
                            end
                            local screenGui = obj:FindFirstAncestorOfClass("ScreenGui")

                            self:RegisterAction("UIClick", {
                                ButtonName = obj.Name,
                                ButtonClass = obj.ClassName,
                                TextOrImage = btnText,
                                ScreenGui = screenGui and screenGui.Name or "Unknown",
                                Hierarchy = self:GetCachedPath(obj),
                            }, obj)
                            return -- UI capturada, no continuar
                        end
                    end
                end
            end

            -- Segundo: si no hubo UI, hacer raycast 3D para detectar
            -- SurfaceGui, BillboardGui, ClickDetector u objetos del mundo
            local interactionType, details, relatedInstance = self:Raycast3DFromCamera(input.Position)
            if interactionType and details then
                self:RegisterAction(interactionType, details, relatedInstance)
                return
            end
        end

        -- Si no fue click o no se capturó nada, registrar input genérico
        if not gameProcessed then
            local key = (input.KeyCode.Name ~= "Unknown") and input.KeyCode.Name or inputType.Name
            self:RegisterAction("InputBegan", {
                Key = key,
                UserInputType = inputType.Name,
                GameProcessed = gameProcessed,
            }, nil)
        end
    end))

    -- =====================================================================
    -- 2. LISTENER DE PROXIMITYPROMPTS (Interacciones 3D en el mundo)
    -- =====================================================================
    pcall(function()
        table.insert(self.Connections, ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
            if not self.IsRecording or player ~= self.LocalPlayer then return end
            self:RegisterAction("ProximityPrompt", {
                ActionText = prompt.ActionText,
                ObjectText = prompt.ObjectText,
                HoldDuration = prompt.HoldDuration,
                KeyboardKeyCode = prompt.KeyboardKeyCode and prompt.KeyboardKeyCode.Name or "E",
                PromptParent = prompt.Parent and prompt.Parent.Name or "Unknown",
                PromptParentPath = prompt.Parent and self:GetCachedPath(prompt.Parent) or nil,
            }, prompt.Parent)
        end))
    end)

    -- =====================================================================
    -- 3. LISTENER DE TOOLS DEL PERSONAJE (Combate/Items)
    -- =====================================================================
    local function hookCharacter(char)
        if not char then return end

        -- Tools ya equipados
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                table.insert(self.Connections, child.Activated:Connect(function()
                    if not self.IsRecording then return end
                    self:RegisterAction("ToolActivated", {
                        ToolName = child.Name,
                        ToolPath = self:GetCachedPath(child),
                        RequiresHandle = child.RequiresHandle,
                    }, child)
                end))
            end
        end

        -- Tools futuros
        table.insert(self.Connections, char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                if self.IsRecording then
                    self:RegisterAction("ToolEquipped", {
                        ToolName = child.Name,
                        ToolPath = self:GetCachedPath(child),
                    }, child)
                end
                table.insert(self.Connections, child.Activated:Connect(function()
                    if not self.IsRecording then return end
                    self:RegisterAction("ToolActivated", {
                        ToolName = child.Name,
                        ToolPath = self:GetCachedPath(child),
                        RequiresHandle = child.RequiresHandle,
                    }, child)
                end))
            end
        end))

        table.insert(self.Connections, char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") and self.IsRecording then
                self:RegisterAction("ToolUnequipped", {
                    ToolName = child.Name,
                }, nil)
            end
        end))
    end

    if self.LocalPlayer.Character then hookCharacter(self.LocalPlayer.Character) end
    table.insert(self.Connections, self.LocalPlayer.CharacterAdded:Connect(hookCharacter))

    if self.Logger then
        self.Logger:Info("RECORDER", "Motor de Trazabilidad Causal v4.0 iniciado (2D+3D, Raycasting, Ping+"
            .. tostring(math.floor(self.BaseCorrelationOffset * 1000)) .. "ms).")
    end
end

function ActionRecorder:StopConnections()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.Connections)
end

function ActionRecorder:Stop()
    if not self.IsRecording then return end
    self.IsRecording = false
    self:StopConnections()

    if self.Logger then
        self.Logger:Info("RECORDER", string.format(
            "Motor de Trazabilidad detenido. %d acciones en timeline.",
            #self.RecordedTimeline
        ))
    end
end

function ActionRecorder:RemoveAction(target)
    for i, act in ipairs(self.RecordedTimeline) do
        if act == target or act.Id == target then
            local removed = table.remove(self.RecordedTimeline, i)
            if self.RecentAction == removed then
                self.RecentAction = self.RecordedTimeline[1]
            end
            if self.EventBus then
                self.EventBus:Publish("ActionRemoved", removed)
            end
            if self.Logger then
                self.Logger:Info("RECORDER", "Acción eliminada del timeline: " .. tostring(removed.Id))
            end
            return true
        end
    end
    return false
end

function ActionRecorder:ExtractMasterBundle()
    local timeline = self.RecordedTimeline or {}
    local masterBundle = {
        BundleType = "MASTER_ALL_CAPTURES_BUNDLE",
        ExportedAt = os.date("!%Y-%m-%d %H:%M:%SZ"),
        Timestamp = tick(),
        GameInfo = {
            PlaceId = game.PlaceId,
            JobId = game.JobId,
            PlaceVersion = game.PlaceVersion,
        },
        TotalCaptures = #timeline,
        Captures = {},
        UniqueRemotesSummary = {},
        MasterReplayScript = nil,
    }

    local remoteMap = {}
    local replayScripts = {}

    for idx, action in ipairs(timeline) do
        local bundleItem = self:ExtractBundle(action.Id, "TIMELINE_ACTION_BUNDLE")
        if bundleItem then
            table.insert(masterBundle.Captures, bundleItem)
        end

        for _, rem in ipairs(action.CorrelatedRemotes or {}) do
            local key = rem.Path or rem.Name or "Unknown"
            if not remoteMap[key] then
                remoteMap[key] = {
                    Name = rem.Name,
                    Path = rem.Path,
                    Method = rem.Method,
                    TypeSignature = rem.TypeSignature,
                    RiskLevel = rem.RiskLevel,
                    TotalCalls = 0,
                    AssociatedActions = {},
                }
            end
            remoteMap[key].TotalCalls = remoteMap[key].TotalCalls + 1
            table.insert(remoteMap[key].AssociatedActions, action.Id)
        end

        if bundleItem and bundleItem.GeneratedScript then
            table.insert(replayScripts, string.format("-- [[ ACCIÓN %d/%d: %s (ID: %s) ]]\n-- Target: %s\n%s",
                idx, #timeline, action.Type, action.Id, action.InstancePath or "N/A", bundleItem.GeneratedScript))
        end
    end

    for _, rInfo in pairs(remoteMap) do
        table.insert(masterBundle.UniqueRemotesSummary, rInfo)
    end

    if #replayScripts > 0 then
        masterBundle.MasterReplayScript = table.concat({
            "-- ============================================================================",
            "-- [APEX SUITE v4.0] MASTER REPLAY SEQUENCE (ALL CAPTURED INTERACTIONS)",
            string.format("-- Total Acciones: %d | Remotos Únicos: %d | Generado: %s", #timeline, #masterBundle.UniqueRemotesSummary, os.date("%X")),
            "-- ============================================================================",
            "",
            table.concat(replayScripts, "\n\n-- ------------------------------------------------------------\n\n"),
        }, "\n")
    else
        masterBundle.MasterReplayScript = "-- No hay scripts de replay generados para las capturas actuales."
    end

    return masterBundle
end

-- =============================================================================
-- ACCESO A TIMELINE (para la vista RemoteSpyView)
-- =============================================================================

function ActionRecorder:GetTimeline()
    return self.RecordedTimeline
end

function ActionRecorder:GetCorrelatedSuspects()
    local suspects = {}
    local seen = {}

    for _, act in ipairs(self.RecordedTimeline) do
        if act.CorrelatedRemotes and #act.CorrelatedRemotes > 0 then
            for _, rem in ipairs(act.CorrelatedRemotes) do
                if (rem.Confidence or 0) >= 0.70 then
                    if act.Instance and not seen[act.Instance] then
                        seen[act.Instance] = true
                        table.insert(suspects, {
                            Instance = act.Instance,
                            Path = act.InstancePath,
                            Name = act.Instance.Name,
                            ClassName = act.Instance.ClassName,
                            Score = 100,
                            Tags = { "RuntimeActionCorrelated" },
                            ActionType = act.Type,
                            RemotePath = rem.Path,
                        })
                    end

                    for _, ctrl in ipairs(act.ControllingScripts or {}) do
                        if ctrl.Instance and not seen[ctrl.Instance] then
                            seen[ctrl.Instance] = true
                            table.insert(suspects, {
                                Instance = ctrl.Instance,
                                Path = ctrl.Path,
                                Name = ctrl.Name,
                                ClassName = ctrl.ClassName,
                                Score = 100,
                                Tags = { "RuntimeActionCorrelatedScript" },
                                ActionType = act.Type,
                                RemotePath = rem.Path,
                            })
                        end
                    end

                    if rem.Remote and not seen[rem.Remote] then
                        seen[rem.Remote] = true
                        table.insert(suspects, {
                            Instance = rem.Remote,
                            Path = rem.Path,
                            Name = rem.Name,
                            ClassName = rem.Remote.ClassName,
                            Score = 100,
                            Tags = { "RuntimeCorrelatedRemote" },
                            ActionType = act.Type,
                            RemotePath = rem.Path,
                        })
                    end
                end
            end
        end
    end

    return suspects
end

return ActionRecorder
