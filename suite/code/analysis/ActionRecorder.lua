--[[
    =============================================================================
    APEX SUITE - ADVANCED ACTION RECORDER & SMART EXTRACTION PIPELINE
    =============================================================================
    Rastrea interacciones del usuario mediante escucha centralizada delegada
    (UserInputService + GetGuiObjectsAtPosition), correlaciona causalmente las
    acciones con los remotes disparados mediante comparación de argumentos,
    evita descompilaciones redundantes con caché y genera scripts de reproducción
    parametrizados y modulares.
--]]

local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local ActionRecorder = {}
ActionRecorder.__index = ActionRecorder
ActionRecorder.ClassName = "ActionRecorder"

-- Tipos de Extracción Inteligente
ActionRecorder.ExtractionType = {
    UI_REMOTE_BUNDLE        = "UI_REMOTE_BUNDLE",        -- Botón/UI + Scripts locales + Remotes asociados
    WORLD_INTERACTION_BUNDLE= "WORLD_INTERACTION_BUNDLE",-- Modelo 3D + ProximityPrompt + Atributos + Remotes
    COMBAT_TOOL_BUNDLE      = "COMBAT_TOOL_BUNDLE",      -- Tool equipado + Animaciones + Hitbox + Remotes
    FULL_EXECUTION_TRACE    = "FULL_EXECUTION_TRACE",    -- Timeline correlacionado + Estado físico + Decompilación
}

function ActionRecorder.new(eventBus, logger, capabilityManager)
    local self = setmetatable({}, ActionRecorder)
    self.EventBus = eventBus
    self.Logger = logger
    self.Caps = capabilityManager
    
    self.IsRecording = false
    self.RecordedTimeline = {}
    self.RecentAction = nil
    self.CorrelationWindow = 0.6 -- Ventana de tiempo (segundos)
    self.PathCache = setmetatable({}, { __mode = "k" }) -- Weak-key cache para instancias
    self.DecompilationCache = {} -- [fullName] = sourceText
    
    self.Connections = {}
    self.LocalPlayer = Players.LocalPlayer
    
    return self
end

function ActionRecorder:GetCachedPath(inst)
    if not inst then return nil end
    local cached = self.PathCache[inst]
    if cached then return cached end
    local s, full = pcall(function() return inst:GetFullName() end)
    if s and full then
        self.PathCache[inst] = full
        return full
    end
    return nil
end

function ActionRecorder:IsIgnoredLibraryScript(inst)
    if not inst then return true end
    local path = self:GetCachedPath(inst) or ""
    if path:find("Packages") or path:find("_Index") or path:find("Janitor")
       or path:find("Promise") or path:find("Vendor") or path:find("Roact")
       or path:find("Rodux") or path:find("Fusion") or path:find("Flipper")
       or path:find("TopbarPlus") or path:find("GoodSignal") or path:find("Signal")
       or path:find("%.spec") or path:find("%.test") then
        return true
    end
    return false
end

function ActionRecorder:GetCurrentPlayerSnapshot()
    local snap = {
        Timestamp = tick(),
        CFrame = nil,
        Health = 100,
        EquippedTool = nil,
        MouseTarget = nil,
        MouseHit = nil,
    }
    
    pcall(function()
        local mouse = self.LocalPlayer:GetMouse()
        if mouse then
            snap.MouseTarget = mouse.Target and self:GetCachedPath(mouse.Target) or nil
            snap.MouseHit = mouse.Hit and tostring(mouse.Hit.Position) or nil
        end
        
        local char = self.LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then snap.CFrame = tostring(hrp.Position) end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then snap.Health = hum.Health end
            
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then snap.EquippedTool = self:GetCachedPath(tool) end
        end
    end)
    
    return snap
end

function ActionRecorder:RegisterAction(actionType, details, relatedInstance)
    local now = tick()
    local snapshot = self:GetCurrentPlayerSnapshot()
    
    local actionEntry = {
        Id = string.format("ACT_%d_%d", math.floor(now), math.random(100, 999)),
        Timestamp = now,
        Type = actionType, -- "Input", "Prompt", "Tool", "StateChange", "UIClick"
        Details = details or {},
        Instance = relatedInstance,
        InstancePath = relatedInstance and self:GetCachedPath(relatedInstance) or nil,
        Snapshot = snapshot,
        CorrelatedRemotes = {},
    }
    
    self.RecentAction = actionEntry
    table.insert(self.RecordedTimeline, 1, actionEntry)
    
    if #self.RecordedTimeline > 250 then
        table.remove(self.RecordedTimeline)
    end
    
    if self.EventBus then
        self.EventBus:Publish("ActionRecorded", actionEntry)
    end
    
    return actionEntry
end

-- =========================================================================
-- CORRELACIÓN CONTEXTUAL Y CAUSAL DE ARGUMENTOS
-- =========================================================================
function ActionRecorder:CalculateCausalConfidence(action, remoteEntry)
    local confidence = 0.5 -- Base temporal
    local matchReason = "Temporal Proximity"
    
    local actDetails = action.Details or {}
    local keywords = {}
    
    if actDetails.ButtonName then table.insert(keywords, tostring(actDetails.ButtonName):lower()) end
    if actDetails.TextOrImage and #actDetails.TextOrImage > 0 then table.insert(keywords, tostring(actDetails.TextOrImage):lower()) end
    if actDetails.ActionText then table.insert(keywords, tostring(actDetails.ActionText):lower()) end
    if actDetails.ObjectText then table.insert(keywords, tostring(actDetails.ObjectText):lower()) end
    if actDetails.ToolName then table.insert(keywords, tostring(actDetails.ToolName):lower()) end
    if actDetails.Key then table.insert(keywords, tostring(actDetails.Key):lower()) end
    
    local remName = (remoteEntry.Name or ""):lower()
    local remArgs = remoteEntry.Args or {}
    
    -- Comparar palabras clave de la acción con el nombre del remote y sus argumentos
    for _, kw in ipairs(keywords) do
        if #kw >= 3 then
            if remName:find(kw, 1, true) then
                confidence = 0.9
                matchReason = string.format("Remote name matches action keyword '%s'", kw)
                break
            end
            
            for _, arg in ipairs(remArgs) do
                local argStr = tostring(arg):lower()
                if argStr:find(kw, 1, true) or kw:find(argStr, 1, true) then
                    confidence = 1.0
                    matchReason = string.format("Remote payload argument '%s' matches action context '%s'", argStr, kw)
                    break
                end
            end
        end
    end
    
    -- Si los argumentos son solo posiciones físicas o ticks y la acción fue un click de UI, reducir confianza
    if action.Type == "UIClick" and #remArgs == 1 and typeof(remArgs[1]) == "Vector3" then
        confidence = 0.2
        matchReason = "Likely background physics update"
    end
    
    return confidence, matchReason
end

function ActionRecorder:CorrelateRemoteCall(remoteEntry)
    if not self.IsRecording or not self.RecentAction then return end
    
    local now = tick()
    local delta = now - self.RecentAction.Timestamp
    
    if delta <= self.CorrelationWindow then
        local confidence, reason = self:CalculateCausalConfidence(self.RecentAction, remoteEntry)
        
        -- Solo vincular si la confianza es razonable (descartar ruido obvio)
        if confidence >= 0.3 then
            table.insert(self.RecentAction.CorrelatedRemotes, {
                DeltaTime = delta,
                Remote = remoteEntry.Remote,
                Name = remoteEntry.Name,
                Path = remoteEntry.Path,
                Method = remoteEntry.Method,
                Args = remoteEntry.Args,
                Snippet = remoteEntry.Snippet,
                Confidence = confidence,
                CausalMatch = reason,
            })
            
            if self.Logger then
                self.Logger:Info("CORRELATION", string.format("Acción [%s] -> Remote [%s] (Confianza: %d%% - %s)", self.RecentAction.Type, remoteEntry.Name, math.floor(confidence * 100), reason))
            end
            
            if self.EventBus then
                self.EventBus:Publish("ActionCorrelated", self.RecentAction)
            end
        end
    end
end

-- =========================================================================
-- GENERADOR DE SCRIPTS DE REPRODUCCIÓN PARAMETRIZADOS
-- =========================================================================
function ActionRecorder:GenerateParametrizedScript(targetAction, correlatedRemotes)
    local lines = {
        "-- ============================================================================",
        "-- [APEX SUITE] PARAMETRIZED REPLAY SCRIPT",
        string.format("-- Acción: %s | ID: %s | Generado: %s", targetAction.Type, targetAction.Id, os.date("%X")),
        "-- ============================================================================",
        "",
        "local function ExecuteRecordedAction(options)",
        "    options = options or {}",
        "    local repeatCount = options.RepeatCount or 1",
        "    local delayBetween = options.DelayBetween or 0.1",
        "    local customArgs = options.CustomArgs",
        "",
        "    for iteration = 1, repeatCount do",
    }
    
    for idx, rem in ipairs(correlatedRemotes) do
        local snippet = rem.Snippet or string.format("%s:%s()", rem.Path, rem.Method or "FireServer")
        table.insert(lines, string.format("        -- Invocación %d [Confianza: %d%% - %s]", idx, math.floor((rem.Confidence or 1) * 100), rem.CausalMatch or "Direct"))
        table.insert(lines, string.format("        if customArgs and customArgs[%d] then", idx))
        table.insert(lines, string.format("            -- Llamada con argumentos personalizados"))
        table.insert(lines, string.format("            local targetRemote = %s", rem.Path))
        table.insert(lines, string.format("            targetRemote:%s(table.unpack(customArgs[%d]))", rem.Method or "FireServer", idx))
        table.insert(lines, string.format("        else"))
        table.insert(lines, string.format("            %s", snippet))
        table.insert(lines, string.format("        end"))
        if idx < #correlatedRemotes then
            table.insert(lines, "        task.wait(0.05)")
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "        if iteration < repeatCount then")
    table.insert(lines, "            task.wait(delayBetween)")
    table.insert(lines, "        end")
    table.insert(lines, "    end")
    table.insert(lines, "end")
    table.insert(lines, "")
    table.insert(lines, "-- Ejemplo de uso:")
    table.insert(lines, "-- ExecuteRecordedAction({ RepeatCount = 5, DelayBetween = 0.2 })")
    table.insert(lines, "return ExecuteRecordedAction")
    
    return table.concat(lines, "\n")
end

-- =========================================================================
-- SISTEMA DE EXTRACCIÓN INTELIGENTE POR TIPOS
-- =========================================================================
function ActionRecorder:ExtractBundle(actionId, extractionType)
    local targetAction = nil
    for _, act in ipairs(self.RecordedTimeline) do
        if act.Id == actionId then
            targetAction = act
            break
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
        CapturedRemotes = targetAction.CorrelatedRemotes,
        ExtractedScripts = {},
        ExtractedInstances = {},
        GeneratedScript = nil,
    }
    
    local function extractScriptSource(inst)
        if inst and inst:IsA("LuaSourceContainer") and not self:IsIgnoredLibraryScript(inst) and self.Caps then
            local fullName = inst:GetFullName()
            if self.DecompilationCache[fullName] then
                bundle.ExtractedScripts[fullName] = self.DecompilationCache[fullName]
            else
                local src = self.Caps:SafeDecompile(inst)
                self.DecompilationCache[fullName] = src
                bundle.ExtractedScripts[fullName] = src
            end
        end
    end
    
    -- 1. Extracción tipo UI_REMOTE_BUNDLE
    if extractionType == ActionRecorder.ExtractionType.UI_REMOTE_BUNDLE then
        if targetAction.Instance then
            table.insert(bundle.ExtractedInstances, targetAction.Instance:GetFullName())
            local s, desc = pcall(function() return targetAction.Instance:GetDescendants() end)
            if s and desc then
                for _, child in ipairs(desc) do
                    extractScriptSource(child)
                end
            end
        end
        
    -- 2. Extracción tipo WORLD_INTERACTION_BUNDLE
    elseif extractionType == ActionRecorder.ExtractionType.WORLD_INTERACTION_BUNDLE then
        if targetAction.Instance then
            local parentModel = targetAction.Instance:FindFirstAncestorOfClass("Model") or targetAction.Instance
            table.insert(bundle.ExtractedInstances, parentModel:GetFullName())
            local s, desc = pcall(function() return parentModel:GetDescendants() end)
            if s and desc then
                for _, child in ipairs(desc) do
                    extractScriptSource(child)
                end
            end
        end
        
    -- 3. Extracción tipo COMBAT_TOOL_BUNDLE
    elseif extractionType == ActionRecorder.ExtractionType.COMBAT_TOOL_BUNDLE then
        local char = self.LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            table.insert(bundle.ExtractedInstances, tool:GetFullName())
            local s, desc = pcall(function() return tool:GetDescendants() end)
            if s and desc then
                for _, child in ipairs(desc) do
                    extractScriptSource(child)
                end
            end
        end
        
    -- 4. Extracción tipo FULL_EXECUTION_TRACE
    else
        bundle.PlayerSnapshot = targetAction.Snapshot
        if targetAction.Instance then
            table.insert(bundle.ExtractedInstances, targetAction.Instance:GetFullName())
            extractScriptSource(targetAction.Instance)
        end
    end
    
    -- Generar Script Parametrizado
    bundle.GeneratedScript = self:GenerateParametrizedScript(targetAction, targetAction.CorrelatedRemotes)
    
    if self.Logger then
        self.Logger:Info("RECORDER", string.format("Paquete inteligente [%s] generado (%d remotes, %d scripts extraídos).", bundle.BundleType, #bundle.CapturedRemotes, #bundle.ExtractedScripts))
    end
    
    return bundle
end

-- =========================================================================
-- CONTROL DE GRABACIÓN Y LISTENERS CENTRALIZADOS (DELEGATED LISTENING)
-- =========================================================================
function ActionRecorder:Start()
    if self.IsRecording then return end
    self.IsRecording = true
    self:StopConnections()
    
    -- 1. Listener Delegado Centralizado (Teclado, Ratón y Clicks en UI)
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not self.IsRecording then return end
        
        local inputType = input.UserInputType
        local isClick = (inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch)
        
        -- Si es un click, determinar qué elemento de UI fue presionado mediante delegación
        if isClick then
            local playerGui = self.LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                local s, guiObjects = pcall(function()
                    return playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
                end)
                
                if s and guiObjects and #guiObjects > 0 then
                    for _, obj in ipairs(guiObjects) do
                        if obj:IsA("GuiButton") or obj:IsA("TextBox") then
                            local btnText = obj:IsA("TextButton") and obj.Text or (obj:IsA("ImageButton") and obj.Image or (obj:IsA("TextBox") and obj.Text or ""))
                            local screenGui = obj:FindFirstAncestorOfClass("ScreenGui")
                            
                            self:RegisterAction("UIClick", {
                                ButtonName = obj.Name,
                                ButtonClass = obj.ClassName,
                                TextOrImage = btnText,
                                ScreenGui = screenGui and screenGui.Name or "Unknown",
                                Hierarchy = obj:GetFullName(),
                            }, obj)
                            return
                        end
                    end
                end
            end
        end
        
        -- Si no fue click en UI, registrar como entrada de juego o ratón en el mundo 3D
        local key = (input.KeyCode.Name ~= "Unknown") and input.KeyCode.Name or inputType.Name
        local mouse = self.LocalPlayer:GetMouse()
        local target = mouse and mouse.Target or nil
        
        self:RegisterAction("InputBegan", {
            Key = key,
            UserInputType = inputType.Name,
            GameProcessed = gameProcessed,
            Target = target and target.Name or "None",
        }, target)
    end))
    
    -- 2. Listener de ProximityPrompts (Interacciones 3D en el mundo)
    pcall(function()
        table.insert(self.Connections, ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
            if not self.IsRecording or player ~= self.LocalPlayer then return end
            self:RegisterAction("ProximityPrompt", {
                ActionText = prompt.ActionText,
                ObjectText = prompt.ObjectText,
                HoldDuration = prompt.HoldDuration,
                PromptParent = prompt.Parent and prompt.Parent.Name or "Unknown",
            }, prompt.Parent)
        end))
    end)
    
    -- 3. Listener de Tools del Personaje (Combate/Items)
    local function hookCharacter(char)
        if not char then return end
        table.insert(self.Connections, char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                self:RegisterAction("ToolEquipped", { ToolName = child.Name }, child)
                table.insert(self.Connections, child.Activated:Connect(function()
                    self:RegisterAction("ToolActivated", { ToolName = child.Name }, child)
                end))
            end
        end))
    end
    
    if self.LocalPlayer.Character then hookCharacter(self.LocalPlayer.Character) end
    table.insert(self.Connections, self.LocalPlayer.CharacterAdded:Connect(hookCharacter))
    
    if self.Logger then
        self.Logger:Info("RECORDER", "Motor de Rastreo Delegado (Zero-Overhead Delegated Listening) iniciado.")
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
        self.Logger:Info("RECORDER", "Motor de Rastreo detenido.")
    end
end

function ActionRecorder:Clear()
    table.clear(self.RecordedTimeline)
    self.RecentAction = nil
end

return ActionRecorder
