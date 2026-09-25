--[[
    =============================================================================
    APEX SUITE - ADVANCED ACTION RECORDER & SMART EXTRACTION PIPELINE
    =============================================================================
    Rastrea todas las interacciones del usuario (teclado, ratón, UI, 3D ProximityPrompts,
    Tools, estados del Humanoid) y las correlaciona en tiempo real con los Remotes
    disparados para generar paquetes de extracción inteligente por tipos.
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
    self.CorrelationWindow = 0.6 -- Ventana de tiempo (segundos) para correlacionar Remotes
    self.PathCache = setmetatable({}, { __mode = "k" }) -- Weak-key cache para instancias
    
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
        Details = details,
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

function ActionRecorder:CorrelateRemoteCall(remoteEntry)
    if not self.IsRecording or not self.RecentAction then return end
    
    local now = tick()
    local delta = now - self.RecentAction.Timestamp
    
    if delta <= self.CorrelationWindow then
        table.insert(self.RecentAction.CorrelatedRemotes, {
            DeltaTime = delta,
            Remote = remoteEntry.Remote,
            Path = remoteEntry.Path,
            Method = remoteEntry.Method,
            Args = remoteEntry.Args,
            Snippet = remoteEntry.Snippet,
        })
        
        if self.Logger then
            self.Logger:Info("CORRELATION", string.format("Acción [%s] disparó Remote [%s] tras %.3fs", self.RecentAction.Type, remoteEntry.Name, delta))
        end
        
        if self.EventBus then
            self.EventBus:Publish("ActionCorrelated", self.RecentAction)
        end
    end
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
        if inst and inst:IsA("LuaSourceContainer") and self.Caps then
            local src = self.Caps:SafeDecompile(inst)
            bundle.ExtractedScripts[inst:GetFullName()] = src
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
    
    -- Generar Script de Automatización
    local generatedLines = {
        "-- [AUTO-GENERATED EXPLOITATION / AUDIT REPRODUCTION SCRIPT]",
        string.format("-- Acción Origen: %s | Timestamp: %s", targetAction.Type, tostring(targetAction.Timestamp)),
    }
    for _, rem in ipairs(targetAction.CorrelatedRemotes) do
        table.insert(generatedLines, rem.Snippet or string.format("%s:%s()", rem.Path, rem.Method))
    end
    bundle.GeneratedScript = table.concat(generatedLines, "\n")
    
    if self.Logger then
        self.Logger:Info("RECORDER", string.format("Paquete inteligente [%s] generado con éxito (%d remotes, %d scripts extraídos).", bundle.BundleType, #bundle.CapturedRemotes, #bundle.ExtractedScripts))
    end
    
    return bundle
end

-- =========================================================================
-- CONTROL DE GRABACIÓN Y LISTENERS
-- =========================================================================

function ActionRecorder:Start()
    if self.IsRecording then return end
    self.IsRecording = true
    self:StopConnections()
    
    -- 1. Listener de Entradas del Teclado y Ratón
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not self.IsRecording then return end
        
        local inputType = input.UserInputType.Name
        local key = (input.KeyCode.Name ~= "Unknown") and input.KeyCode.Name or inputType
        
        local mouse = self.LocalPlayer:GetMouse()
        local target = mouse and mouse.Target or nil
        
        self:RegisterAction("InputBegan", {
            Key = key,
            UserInputType = inputType,
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
    
    -- 4. Listener Profundo de Interacciones de Interfaz (PlayerGui y UI Buttons)
    local hookedGuiElements = setmetatable({}, { __mode = "k" })
    local function hookGuiElement(element)
        if not element or hookedGuiElements[element] then return end
        
        if element:IsA("GuiButton") then -- TextButton, ImageButton
            hookedGuiElements[element] = true
            table.insert(self.Connections, element.MouseButton1Click:Connect(function()
                if not self.IsRecording then return end
                local btnText = element:IsA("TextButton") and element.Text or (element:IsA("ImageButton") and element.Image or "")
                local screenGui = element:FindFirstAncestorOfClass("ScreenGui")
                
                self:RegisterAction("UIClick", {
                    ButtonName = element.Name,
                    ButtonClass = element.ClassName,
                    TextOrImage = btnText,
                    ScreenGui = screenGui and screenGui.Name or "Unknown",
                    Hierarchy = element:GetFullName(),
                }, element)
            end))
            
        elseif element:IsA("TextBox") then
            hookedGuiElements[element] = true
            table.insert(self.Connections, element.FocusLost:Connect(function(enterPressed)
                if not self.IsRecording then return end
                local screenGui = element:FindFirstAncestorOfClass("ScreenGui")
                
                self:RegisterAction("UIInputSubmitted", {
                    TextBoxName = element.Name,
                    SubmittedText = element.Text,
                    EnterPressed = enterPressed,
                    ScreenGui = screenGui and screenGui.Name or "Unknown",
                }, element)
            end))
        end
    end
    
    local playerGui = self.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        task.spawn(function()
            local s, desc = pcall(function() return playerGui:GetDescendants() end)
            if s and desc then
                local lastYield = tick()
                for _, inst in ipairs(desc) do
                    if tick() - lastYield > 0.012 then
                        task.wait()
                        lastYield = tick()
                    end
                    if not self.IsRecording then break end
                    if inst:IsA("GuiButton") or inst:IsA("TextBox") then
                        hookGuiElement(inst)
                    end
                end
            end
        end)
        
        table.insert(self.Connections, playerGui.DescendantAdded:Connect(function(newDesc)
            if newDesc:IsA("GuiButton") or newDesc:IsA("TextBox") then
                hookGuiElement(newDesc)
            end
        end))
    end
    
    if self.Logger then
        self.Logger:Info("RECORDER", "Motor de Rastreo Total (Inputs, Prompts, Tools & GUI Clicks) iniciado.")
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
