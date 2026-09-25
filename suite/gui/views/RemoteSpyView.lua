--[[
    =============================================================================
    APEX SUITE - REMOTE SPY & SMART ACTION RECORDER VIEW
    =============================================================================
    Monitoreo de remotes, rastreo de acciones (clicks, prompts, tools) y generador
    de paquetes de extracción inteligente por tipos con exportación.
--]]

local RemoteSpyView = {}
RemoteSpyView.__index = RemoteSpyView
RemoteSpyView.ClassName = "RemoteSpyView"

function RemoteSpyView.new(parentFrame, registry)
    local self = setmetatable({}, RemoteSpyView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.LastBundle = nil
    self:Render()
    return self
end

function RemoteSpyView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame
    
    -- Barra superior de controles principales
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 34)
    topBar.BackgroundTransparency = 1
    topBar.Parent = frame
    
    local toggleSpyBtn = Instance.new("TextButton")
    toggleSpyBtn.Size = UDim2.new(0, 130, 1, 0)
    toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
    toggleSpyBtn.Text = "▶ INICIAR SPY"
    toggleSpyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleSpyBtn.Font = Enum.Font.GothamBold
    toggleSpyBtn.TextSize = 11
    toggleSpyBtn.Parent = topBar
    Instance.new("UICorner", toggleSpyBtn).CornerRadius = UDim.new(0, 6)
    
    local toggleRecordBtn = Instance.new("TextButton")
    toggleRecordBtn.Size = UDim2.new(0, 150, 1, 0)
    toggleRecordBtn.Position = UDim2.new(0, 136, 0, 0)
    toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 40)
    toggleRecordBtn.Text = "🔴 RASTREAR ACCIONES"
    toggleRecordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleRecordBtn.Font = Enum.Font.GothamBold
    toggleRecordBtn.TextSize = 11
    toggleRecordBtn.Parent = topBar
    Instance.new("UICorner", toggleRecordBtn).CornerRadius = UDim.new(0, 6)
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 90, 1, 0)
    clearBtn.Position = UDim2.new(0, 292, 0, 0)
    clearBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    clearBtn.Text = "🗑️ LIMPIAR"
    clearBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    clearBtn.Font = Enum.Font.GothamMedium
    clearBtn.TextSize = 11
    clearBtn.Parent = topBar
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)
    
    -- Barra secundaria de tipos de extracción inteligente
    local extractBar = Instance.new("Frame")
    extractBar.Size = UDim2.new(1, 0, 0, 28)
    extractBar.Position = UDim2.new(0, 0, 0, 38)
    extractBar.BackgroundTransparency = 1
    extractBar.Parent = frame
    
    local function createExtractButton(text, posX, width, extType)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(width, -4, 1, 0)
        btn.Position = UDim2.new(posX, 0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(220, 225, 240)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10
        btn.Parent = extractBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        return btn
    end
    
    local btnUI     = createExtractButton("📦 UI Bundle", 0, 0.24, "UI_REMOTE_BUNDLE")
    local btnWorld  = createExtractButton("🌍 World Object", 0.24, 0.24, "WORLD_INTERACTION_BUNDLE")
    local btnCombat = createExtractButton("⚔️ Combat Tool", 0.48, 0.24, "COMBAT_TOOL_BUNDLE")
    local btnTrace  = createExtractButton("⚡ Full Trace Gen", 0.72, 0.28, "FULL_EXECUTION_TRACE")
    
    -- Panel de Registro y Visualización
    local logBox = Instance.new("TextBox")
    logBox.Size = UDim2.new(1, 0, 1, -74)
    logBox.Position = UDim2.new(0, 0, 0, 74)
    logBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    logBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    logBox.Text = "-- Inicia el SPY o RASTREO DE ACCIONES para correlacionar eventos y generar extracciones."
    logBox.Font = Enum.Font.Code
    logBox.TextSize = 11
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.ClearTextOnFocus = false
    logBox.MultiLine = true
    logBox.TextEditable = false
    logBox.Parent = frame
    Instance.new("UICorner", logBox).CornerRadius = UDim.new(0, 8)
    
    -- Lógica de Servicios
    local isSpyRunning = false
    local isRecordRunning = false
    local remoteAnalyzer = self.Registry:Get("RemoteAnalyzer")
    local actionRecorder = self.Registry:Get("ActionRecorder")
    local exporter = self.Registry:Get("ReportExporter")
    local eventBus = self.Registry:Get("EventBus")
    
    toggleSpyBtn.MouseButton1Click:Connect(function()
        isSpyRunning = not isSpyRunning
        if isSpyRunning then
            toggleSpyBtn.Text = "⏸️ PAUSAR SPY"
            toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            if remoteAnalyzer then remoteAnalyzer:Start() end
        else
            toggleSpyBtn.Text = "▶ INICIAR SPY"
            toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
            if remoteAnalyzer then remoteAnalyzer:Stop() end
        end
    end)
    
    toggleRecordBtn.MouseButton1Click:Connect(function()
        isRecordRunning = not isRecordRunning
        if isRecordRunning then
            toggleRecordBtn.Text = "⏹️ DETENER RASTREO"
            toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            if actionRecorder then actionRecorder:Start() end
        else
            toggleRecordBtn.Text = "🔴 RASTREAR ACCIONES"
            toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 40)
            if actionRecorder then actionRecorder:Stop() end
        end
    end)
    
    clearBtn.MouseButton1Click:Connect(function()
        if remoteAnalyzer then remoteAnalyzer:Clear() end
        if actionRecorder then actionRecorder:Clear() end
        logBox.Text = "-- Registros limpiados."
    end)
    
    local function handleExtraction(extType)
        if not actionRecorder then return end
        local bundle, err = actionRecorder:ExtractBundle(nil, extType)
        if not bundle then
            logBox.Text = "-- [Error de Extracción]: " .. tostring(err)
            return
        end
        
        self.LastBundle = bundle
        local jsonStr = exporter and exporter:ToJSON(bundle) or "-- [No exporter]"
        logBox.Text = string.format("==================================================================\n📦 PAQUETE DE EXTRACCIÓN INTELIGENTE: %s\n==================================================================\n%s\n\n[SCRIPT GENERADO]:\n%s", extType, jsonStr, bundle.GeneratedScript or "None")
        
        if exporter then
            exporter:SaveToFile("smart_bundle_" .. extType .. "_" .. tick() .. ".json", jsonStr)
        end
    end
    
    btnUI.MouseButton1Click:Connect(function() handleExtraction("UI_REMOTE_BUNDLE") end)
    btnWorld.MouseButton1Click:Connect(function() handleExtraction("WORLD_INTERACTION_BUNDLE") end)
    btnCombat.MouseButton1Click:Connect(function() handleExtraction("COMBAT_TOOL_BUNDLE") end)
    btnTrace.MouseButton1Click:Connect(function() handleExtraction("FULL_EXECUTION_TRACE") end)
    
    if eventBus then
        eventBus:Subscribe("RemoteFired", function(entry)
            local current = logBox.Text
            local riskEmoji = (entry.RiskLevel == "CRITICAL" and "🚨") or (entry.RiskLevel == "HIGH" and "⚔️") or (entry.RiskLevel == "MEDIUM" and "⚠️") or "📡"
            local line = string.format("%s [%s][%s] %s\n   ▶ Snippet: %s%s",
                riskEmoji,
                entry.RiskLevel or "INFO",
                entry.Method,
                entry.Path,
                entry.Snippet or "N/A",
                entry.CallingScript and ("\n   📍 Emisor: " .. entry.CallingScript) or ""
            )
            logBox.Text = line .. "\n------------------------------------------------------------------\n" .. current
        end)
        
        eventBus:Subscribe("ActionCorrelated", function(act)
            local current = logBox.Text
            local line = string.format("🎯 [CORRELACIÓN DETECTADA] Acción: %s | Remotes Vinculados: %d", act.Type, #act.CorrelatedRemotes)
            logBox.Text = line .. "\n" .. current
        end)
    end
end

function RemoteSpyView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return RemoteSpyView
