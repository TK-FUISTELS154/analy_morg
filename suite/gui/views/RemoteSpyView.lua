--[[
    =============================================================================
    APEX SUITE - REMOTE SPY & CAUSAL INTERACTION AUDITOR VIEW v4.0
    (USER INTERACTION & REVERSE ENGINEERING PIPELINE)
    =============================================================================
    Interfaz de Auditoría Causal en Tiempo Real:
      - Feed de Tarjetas de Auditoría Causal (Acción → Scripts → Remotos)
      - Badges de Riesgo y Confianza Semántica
      - Acciones Rápidas: Copiar Replay Script, Ver Código Descompilado, Exportar Bundle
      - Inspector de Código / JSON / Red en panel dividido
--]]

local HttpService = game:GetService("HttpService")

local RemoteSpyView = {}
RemoteSpyView.__index = RemoteSpyView
RemoteSpyView.ClassName = "RemoteSpyView"

local function safeSetClipboard(text)
    if typeof(setclipboard) == "function" then
        local s = pcall(setclipboard, text)
        if s then return true end
    end
    if typeof(toclipboard) == "function" then
        local s = pcall(toclipboard, text)
        if s then return true end
    end
    return false
end

function RemoteSpyView.new(parentFrame, registry)
    local self = setmetatable({}, RemoteSpyView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.LastBundle = nil
    self.ActiveTab = "Replay" -- "Replay", "Bundle", "Decompiled", "Network"
    self.SelectedAction = nil
    self.FeedCards = {}
    self.MaxCards = 60

    self:Render()
    return self
end

function RemoteSpyView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame

    -- =========================================================================
    -- 1. BARRA SUPERIOR DE CONTROL PRINCIPAL
    -- =========================================================================
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 32)
    topBar.BackgroundTransparency = 1
    topBar.Parent = frame

    local toggleSpyBtn = Instance.new("TextButton")
    toggleSpyBtn.Size = UDim2.new(0, 120, 1, 0)
    toggleSpyBtn.Position = UDim2.new(0, 0, 0, 0)
    toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
    toggleSpyBtn.Text = "▶ INICIAR SPY"
    toggleSpyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleSpyBtn.Font = Enum.Font.GothamBold
    toggleSpyBtn.TextSize = 10
    toggleSpyBtn.Parent = topBar
    Instance.new("UICorner", toggleSpyBtn).CornerRadius = UDim.new(0, 5)

    local toggleRecordBtn = Instance.new("TextButton")
    toggleRecordBtn.Size = UDim2.new(0, 145, 1, 0)
    toggleRecordBtn.Position = UDim2.new(0, 125, 0, 0)
    toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 40)
    toggleRecordBtn.Text = "🔴 RASTREAR ACCIONES"
    toggleRecordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleRecordBtn.Font = Enum.Font.GothamBold
    toggleRecordBtn.TextSize = 10
    toggleRecordBtn.Parent = topBar
    Instance.new("UICorner", toggleRecordBtn).CornerRadius = UDim.new(0, 5)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 80, 1, 0)
    clearBtn.Position = UDim2.new(0, 275, 0, 0)
    clearBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    clearBtn.Text = "🗑️ LIMPIAR"
    clearBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    clearBtn.Font = Enum.Font.GothamMedium
    clearBtn.TextSize = 10
    clearBtn.Parent = topBar
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 5)

    -- Status Pill
    local statusPill = Instance.new("TextLabel")
    statusPill.Size = UDim2.new(1, -365, 1, 0)
    statusPill.Position = UDim2.new(0, 362, 0, 0)
    statusPill.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
    statusPill.Text = "Estado: Inactivo | Haz clic en Iniciar Spy o Rastrear"
    statusPill.TextColor3 = Color3.fromRGB(160, 175, 200)
    statusPill.Font = Enum.Font.GothamMedium
    statusPill.TextSize = 10
    statusPill.Parent = topBar
    Instance.new("UICorner", statusPill).CornerRadius = UDim.new(0, 5)

    -- =========================================================================
    -- 2. BARRA DE EXTRACCIÓN RÁPIDA DE BUNDLES INTELIGENTES
    -- =========================================================================
    local extractBar = Instance.new("Frame")
    extractBar.Size = UDim2.new(1, 0, 0, 26)
    extractBar.Position = UDim2.new(0, 0, 0, 36)
    extractBar.BackgroundTransparency = 1
    extractBar.Parent = frame

    local function createExtractButton(text, posX, width)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(width, -4, 1, 0)
        btn.Position = UDim2.new(posX, 0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(210, 225, 245)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.Parent = extractBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        return btn
    end

    local btnUI     = createExtractButton("📦 UI Bundle", 0, 0.25)
    local btnWorld  = createExtractButton("🌍 World Object", 0.25, 0.25)
    local btnCombat = createExtractButton("⚔️ Combat Tool", 0.50, 0.25)
    local btnTrace  = createExtractButton("⚡ Full Trace Gen", 0.75, 0.25)

    -- =========================================================================
    -- 3. CUERPO PRINCIPAL (PANEL DIVIDIDO: FEED DE AUDITORÍA + INSPECTOR)
    -- =========================================================================
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -66)
    body.Position = UDim2.new(0, 0, 0, 66)
    body.BackgroundTransparency = 1
    body.Parent = frame

    -- Panel Izquierdo: Timeline / Feed de Tarjetas Causal
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.48, -4, 1, 0)
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    leftPanel.Parent = body
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 6)

    local feedHeader = Instance.new("Frame")
    feedHeader.Size = UDim2.new(1, 0, 0, 24)
    feedHeader.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
    feedHeader.Parent = leftPanel
    Instance.new("UICorner", feedHeader).CornerRadius = UDim.new(0, 6)

    local feedTitle = Instance.new("TextLabel")
    feedTitle.Size = UDim2.new(1, -10, 1, 0)
    feedTitle.Position = UDim2.new(0, 8, 0, 0)
    feedTitle.BackgroundTransparency = 1
    feedTitle.Text = "⚡ FEED DE AUDITORÍA CAUSAL (ACCIÓN → RED)"
    feedTitle.TextColor3 = Color3.fromRGB(220, 230, 245)
    feedTitle.Font = Enum.Font.GothamBold
    feedTitle.TextSize = 10
    feedTitle.TextXAlignment = Enum.TextXAlignment.Left
    feedTitle.Parent = feedHeader

    local feedScroll = Instance.new("ScrollingFrame")
    feedScroll.Size = UDim2.new(1, -8, 1, -30)
    feedScroll.Position = UDim2.new(0, 4, 0, 26)
    feedScroll.BackgroundTransparency = 1
    feedScroll.ScrollBarThickness = 4
    feedScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 60, 80)
    feedScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    feedScroll.Parent = leftPanel

    local feedLayout = Instance.new("UIListLayout")
    feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
    feedLayout.Padding = UDim.new(0, 6)
    feedLayout.Parent = feedScroll

    feedLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        feedScroll.CanvasSize = UDim2.new(0, 0, 0, feedLayout.AbsoluteContentSize.Y + 10)
    end)

    -- Panel Derecho: Inspector de Código / JSON / Scripts
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.52, -4, 1, 0)
    rightPanel.Position = UDim2.new(0.48, 4, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
    rightPanel.Parent = body
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 6)

    -- Pestañas del Inspector
    local tabRow = Instance.new("Frame")
    tabRow.Size = UDim2.new(1, 0, 0, 26)
    tabRow.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    tabRow.Parent = rightPanel
    Instance.new("UICorner", tabRow).CornerRadius = UDim.new(0, 6)

    local tabs = {
        { Id = "Replay",     Label = "📜 Replay Script" },
        { Id = "Bundle",     Label = "📦 Bundle JSON" },
        { Id = "Decompiled", Label = "🕵️ Código Local" },
        { Id = "Network",    Label = "📡 Log de Red" },
    }
    local tabButtons = {}
    local tabWidth = 1 / #tabs

    local inspectorBox = Instance.new("TextBox")
    inspectorBox.Size = UDim2.new(1, -12, 1, -66)
    inspectorBox.Position = UDim2.new(0, 6, 0, 30)
    inspectorBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    inspectorBox.TextColor3 = Color3.fromRGB(215, 225, 240)
    inspectorBox.Text = "-- Selecciona una acción del feed o genera un bundle para inspeccionar."
    inspectorBox.Font = Enum.Font.Code
    inspectorBox.TextSize = 10
    inspectorBox.TextXAlignment = Enum.TextXAlignment.Left
    inspectorBox.TextYAlignment = Enum.TextYAlignment.Top
    inspectorBox.ClearTextOnFocus = false
    inspectorBox.MultiLine = true
    inspectorBox.TextEditable = false
    inspectorBox.Parent = rightPanel
    Instance.new("UICorner", inspectorBox).CornerRadius = UDim.new(0, 6)

    -- Barra inferior de acciones del inspector (Copiar / Guardar)
    local inspectorActions = Instance.new("Frame")
    inspectorActions.Size = UDim2.new(1, -12, 0, 26)
    inspectorActions.Position = UDim2.new(0, 6, 1, -30)
    inspectorActions.BackgroundTransparency = 1
    inspectorActions.Parent = rightPanel

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0.5, -4, 1, 0)
    copyBtn.Position = UDim2.new(0, 0, 0, 0)
    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
    copyBtn.Text = "📋 COPIAR AL PORTAPAPELES"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 10
    copyBtn.Parent = inspectorActions
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 4)

    local saveFileBtn = Instance.new("TextButton")
    saveFileBtn.Size = UDim2.new(0.5, -4, 1, 0)
    saveFileBtn.Position = UDim2.new(0.5, 4, 0, 0)
    saveFileBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 70)
    saveFileBtn.Text = "💾 GUARDAR EN DISCO"
    saveFileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveFileBtn.Font = Enum.Font.GothamBold
    saveFileBtn.TextSize = 10
    saveFileBtn.Parent = inspectorActions
    Instance.new("UICorner", saveFileBtn).CornerRadius = UDim.new(0, 4)

    -- =========================================================================
    -- SERVICIOS Y REGISTRO
    -- =========================================================================
    local remoteAnalyzer = self.Registry:Get("RemoteAnalyzer")
    local actionRecorder = self.Registry:Get("ActionRecorder")
    local exporter = self.Registry:Get("ReportExporter")
    local eventBus = self.Registry:Get("EventBus")

    local function setInspectorText(text)
        local maxLimit = 75000
        local str = tostring(text or "")
        if #str > maxLimit then
            inspectorBox.Text = string.sub(str, 1, maxLimit)
                .. string.format("\n\n-- [⚠️ AVISO: Truncado a %d caracteres por límite de Roblox TextBox]\n-- [Total: %d caracteres]", maxLimit, #str)
        else
            inspectorBox.Text = str
        end
    end

    local function updateInspectorView()
        if not self.SelectedAction and not self.LastBundle then
            setInspectorText("-- No hay ninguna acción o bundle seleccionado.")
            return
        end

        if self.ActiveTab == "Replay" then
            if self.SelectedAction and actionRecorder then
                local script = actionRecorder:GenerateParametrizedScript(self.SelectedAction, self.SelectedAction.CorrelatedRemotes)
                setInspectorText(script)
            elseif self.LastBundle and self.LastBundle.GeneratedScript then
                setInspectorText(self.LastBundle.GeneratedScript)
            else
                setInspectorText("-- No hay script de replay disponible para esta selección.")
            end
        elseif self.ActiveTab == "Bundle" then
            local bundleObj = self.LastBundle
            if not bundleObj and self.SelectedAction and actionRecorder then
                bundleObj = actionRecorder:ExtractBundle(self.SelectedAction, "INTERACTION_BUNDLE")
            end
            if bundleObj then
                local s, json = pcall(function() return HttpService:JSONEncode(bundleObj) end)
                setInspectorText((s and json) or "-- Error al codificar JSON")
            else
                setInspectorText("-- No hay bundle disponible.")
            end
        elseif self.ActiveTab == "Decompiled" then
            if self.SelectedAction and self.SelectedAction.ControllingScripts and #self.SelectedAction.ControllingScripts > 0 then
                local parts = {}
                for _, scriptInfo in ipairs(self.SelectedAction.ControllingScripts) do
                    table.insert(parts, string.format("-- ====================================================\n-- SCRIPT: %s (%s)\n-- RUTA: %s\n-- ====================================================\n%s\n",
                        scriptInfo.Name, scriptInfo.ClassName, scriptInfo.Path, scriptInfo.SourcePreview or "-- [Código no descompilado]"))
                end
                setInspectorText(table.concat(parts, "\n"))
            else
                setInspectorText("-- No se encontraron scripts locales controladores para esta acción.")
            end
        elseif self.ActiveTab == "Network" then
            if self.SelectedAction and self.SelectedAction.CorrelatedRemotes and #self.SelectedAction.CorrelatedRemotes > 0 then
                local lines = { "-- REMOTOS CORRELACIONADOS CON ESTA ACCIÓN:" }
                for idx, rem in ipairs(self.SelectedAction.CorrelatedRemotes) do
                    table.insert(lines, string.format("[%d] %s (%s)\n    Ruta: %s\n    Latencia: +%.0fms | Confianza: %d%% (%s)\n    Snippet: %s\n    Riesgo: %s\n",
                        idx, rem.Name, rem.TypeSignature or "()", rem.Path,
                        (rem.DeltaTime or 0) * 1000,
                        math.floor((rem.Confidence or 1) * 100),
                        rem.CausalMatch or "Match",
                        rem.Snippet or "N/A",
                        rem.RiskLevel or "LOW"))
                end
                setInspectorText(table.concat(lines, "\n"))
            else
                setInspectorText("-- No hay llamadas de red vinculadas a esta acción.")
            end
        end
    end

    local function selectTab(tabId)
        self.ActiveTab = tabId
        for id, btn in pairs(tabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
                btn.TextColor3 = Color3.fromRGB(150, 165, 185)
            end
        end
        updateInspectorView()
    end

    for i, t in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(tabWidth, -2, 1, 0)
        btn.Position = UDim2.new((i - 1) * tabWidth, 1, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        btn.Text = t.Label
        btn.TextColor3 = Color3.fromRGB(150, 165, 185)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.Parent = tabRow
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        tabButtons[t.Id] = btn
        btn.MouseButton1Click:Connect(function() selectTab(t.Id) end)
    end
    selectTab("Replay")

    -- Botones de copiado y guardado
    copyBtn.MouseButton1Click:Connect(function()
        local text = inspectorBox.Text or ""
        if safeSetClipboard(text) then
            copyBtn.Text = "✅ ¡COPIADO!"
            task.delay(1.5, function() copyBtn.Text = "📋 COPIAR AL PORTAPAPELES" end)
        else
            copyBtn.Text = "⚠️ Portapapeles no soportado"
            task.delay(1.5, function() copyBtn.Text = "📋 COPIAR AL PORTAPAPELES" end)
        end
    end)

    saveFileBtn.MouseButton1Click:Connect(function()
        if exporter then
            local fname = "apex_audit_" .. self.ActiveTab:lower() .. "_" .. tick() .. ".txt"
            local success = exporter:SaveToFile(fname, inspectorBox.Text)
            if success then
                saveFileBtn.Text = "✅ ¡GUARDADO!"
                task.delay(1.5, function() saveFileBtn.Text = "💾 GUARDAR EN DISCO" end)
            end
        end
    end)

    -- =========================================================================
    -- GENERACIÓN DINÁMICA DE TARJETAS DE AUDITORÍA CAUSAL EN EL FEED
    -- =========================================================================
    local cardCounter = 0

    local function createAuditCard(actionEntry)
        cardCounter = cardCounter + 1
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 78)
        card.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        card.LayoutOrder = -cardCounter
        card.Parent = feedScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

        -- Borde indicador
        local border = Instance.new("UIStroke")
        border.Color = Color3.fromRGB(45, 55, 75)
        border.Thickness = 1
        border.Parent = card

        local actType = actionEntry.Type or "Action"
        local icon = (actType == "UIClick" and "🖱️")
            or (actType == "ProximityPrompt" and "🔘")
            or (actType:find("Tool") and "⚔️")
            or (actType == "ClickDetector" and "🎯")
            or (actType == "SurfaceGui" and "📐")
            or (actType == "BillboardGui" and "🏷️")
            or "⚡"

        local details = actionEntry.Details or {}
        local targetName = details.ButtonName or details.ToolName or details.ActionText or details.ObjectName or actType

        -- Título de la tarjeta
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(0.65, 0, 0, 18)
        titleLabel.Position = UDim2.new(0, 8, 0, 4)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = string.format("%s %s: %s", icon, actType, targetName)
        titleLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 10
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.Parent = card

        -- Ruta o resumen
        local pathLabel = Instance.new("TextLabel")
        pathLabel.Size = UDim2.new(1, -16, 0, 14)
        pathLabel.Position = UDim2.new(0, 8, 0, 22)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Text = actionEntry.InstancePath or "Objeto sin ruta jerárquica"
        pathLabel.TextColor3 = Color3.fromRGB(140, 155, 175)
        pathLabel.Font = Enum.Font.Code
        pathLabel.TextSize = 9
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
        pathLabel.Parent = card

        -- Subtítulo de Red / Scripts
        local remotesCount = #(actionEntry.CorrelatedRemotes or {})
        local scriptsCount = #(actionEntry.ControllingScripts or {})

        local metaLabel = Instance.new("TextLabel")
        metaLabel.Size = UDim2.new(0.60, 0, 0, 16)
        metaLabel.Position = UDim2.new(0, 8, 0, 38)
        metaLabel.BackgroundTransparency = 1
        metaLabel.Text = string.format("📡 Remotos: %d | 🕵️ Scripts: %d | Ventana: %.0fms",
            remotesCount, scriptsCount, (actionEntry.CorrelationWindow or 0.35) * 1000)
        metaLabel.TextColor3 = (remotesCount > 0) and Color3.fromRGB(70, 210, 140) or Color3.fromRGB(160, 170, 185)
        metaLabel.Font = Enum.Font.GothamMedium
        metaLabel.TextSize = 9
        metaLabel.TextXAlignment = Enum.TextXAlignment.Left
        metaLabel.Parent = card

        -- Botones de Acción Rápida en la tarjeta
        local btnReplay = Instance.new("TextButton")
        btnReplay.Size = UDim2.new(0, 68, 0, 18)
        btnReplay.Position = UDim2.new(1, -144, 0, 54)
        btnReplay.BackgroundColor3 = Color3.fromRGB(35, 75, 130)
        btnReplay.Text = "📜 Replay"
        btnReplay.TextColor3 = Color3.fromRGB(240, 245, 255)
        btnReplay.Font = Enum.Font.GothamBold
        btnReplay.TextSize = 9
        btnReplay.Parent = card
        Instance.new("UICorner", btnReplay).CornerRadius = UDim.new(0, 3)

        local btnInspect = Instance.new("TextButton")
        btnInspect.Size = UDim2.new(0, 68, 0, 18)
        btnInspect.Position = UDim2.new(1, -72, 0, 54)
        btnInspect.BackgroundColor3 = Color3.fromRGB(30, 110, 75)
        btnInspect.Text = "🔍 Inspeccionar"
        btnInspect.TextColor3 = Color3.fromRGB(240, 255, 245)
        btnInspect.Font = Enum.Font.GothamBold
        btnInspect.TextSize = 9
        btnInspect.Parent = card
        Instance.new("UICorner", btnInspect).CornerRadius = UDim.new(0, 3)

        btnReplay.MouseButton1Click:Connect(function()
            self.SelectedAction = actionEntry
            selectTab("Replay")
            if actionRecorder then
                local script = actionRecorder:GenerateParametrizedScript(actionEntry, actionEntry.CorrelatedRemotes)
                if safeSetClipboard(script) then
                    btnReplay.Text = "✅ ¡Copiado!"
                    task.delay(1.2, function() btnReplay.Text = "📜 Replay" end)
                end
            end
        end)

        btnInspect.MouseButton1Click:Connect(function()
            self.SelectedAction = actionEntry
            updateInspectorView()
        end)

        -- Función para actualizar la tarjeta si se correlacionan nuevos remotos
        local function refreshCard()
            local updatedRemCount = #(actionEntry.CorrelatedRemotes or {})
            metaLabel.Text = string.format("📡 Remotos: %d | 🕵️ Scripts: %d | Ventana: %.0fms",
                updatedRemCount, scriptsCount, (actionEntry.CorrelationWindow or 0.35) * 1000)
            if updatedRemCount > 0 then
                metaLabel.TextColor3 = Color3.fromRGB(70, 210, 140)
                border.Color = Color3.fromRGB(50, 160, 100)
            end
        end

        actionEntry._refreshCard = refreshCard
        table.insert(self.FeedCards, 1, card)

        if #self.FeedCards > self.MaxCards then
            local old = table.remove(self.FeedCards)
            if old and old.Parent then old:Destroy() end
        end

        return card
    end

    -- =========================================================================
    -- HANDLERS DE BOTONES SUPERIORES
    -- =========================================================================
    local isSpyRunning = false
    local isRecordRunning = false

    toggleSpyBtn.MouseButton1Click:Connect(function()
        isSpyRunning = not isSpyRunning
        if isSpyRunning then
            toggleSpyBtn.Text = "⏸️ PAUSAR SPY"
            toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            statusPill.Text = "Estado: 📡 Remote Spy Activo"
            if remoteAnalyzer then remoteAnalyzer:Start() end
        else
            toggleSpyBtn.Text = "▶ INICIAR SPY"
            toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
            statusPill.Text = "Estado: ⏸️ Remote Spy Pausado"
            if remoteAnalyzer then remoteAnalyzer:Stop() end
        end
    end)

    toggleRecordBtn.MouseButton1Click:Connect(function()
        isRecordRunning = not isRecordRunning
        if isRecordRunning then
            toggleRecordBtn.Text = "⏹️ DETENER RASTREO"
            toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            statusPill.Text = "Estado: 🔴 Rastreando Acciones (2D/3D + Raycasting)"
            if actionRecorder then actionRecorder:Start() end
        else
            toggleRecordBtn.Text = "🔴 RASTREAR ACCIONES"
            toggleRecordBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 40)
            statusPill.Text = "Estado: ⏹️ Rastreo Detenido"
            if actionRecorder then actionRecorder:Stop() end
        end
    end)

    clearBtn.MouseButton1Click:Connect(function()
        if remoteAnalyzer then remoteAnalyzer:Clear() end
        if actionRecorder then actionRecorder:Clear() end
        for _, c in ipairs(self.FeedCards) do
            if c and c.Parent then c:Destroy() end
        end
        table.clear(self.FeedCards)
        self.SelectedAction = nil
        self.LastBundle = nil
        setInspectorText("-- Registros y feed limpiados.")
        statusPill.Text = "Estado: Limpio"
    end)

    local function handleExtraction(extType)
        if not actionRecorder then return end
        local bundle, err = actionRecorder:ExtractBundle(self.SelectedAction, extType)
        if not bundle then
            setInspectorText("-- [Error de Extracción]: " .. tostring(err))
            return
        end

        self.LastBundle = bundle
        selectTab("Bundle")

        if exporter then
            local s, jsonStr = pcall(function() return HttpService:JSONEncode(bundle) end)
            if s and jsonStr then
                exporter:SaveToFile("smart_bundle_" .. extType:lower() .. "_" .. tick() .. ".json", jsonStr)
                statusPill.Text = string.format("Estado: Bundle '%s' guardado", extType)
            end
        end
    end

    btnUI.MouseButton1Click:Connect(function() handleExtraction("UI_REMOTE_BUNDLE") end)
    btnWorld.MouseButton1Click:Connect(function() handleExtraction("WORLD_INTERACTION_BUNDLE") end)
    btnCombat.MouseButton1Click:Connect(function() handleExtraction("COMBAT_TOOL_BUNDLE") end)
    btnTrace.MouseButton1Click:Connect(function() handleExtraction("FULL_EXECUTION_TRACE") end)

    -- =========================================================================
    -- SUBSCRIPCIONES A EVENTBUS
    -- =========================================================================
    if eventBus then
        eventBus:Subscribe("ActionRecorded", function(actionEntry)
            createAuditCard(actionEntry)
        end)

        eventBus:Subscribe("ActionCorrelated", function(actionEntry)
            if actionEntry and actionEntry._refreshCard then
                actionEntry._refreshCard()
            end
            if self.SelectedAction == actionEntry then
                updateInspectorView()
            end
        end)

        eventBus:Subscribe("RemoteFired", function(remoteEntry)
            -- Si la pestaña activa es Network, actualizar vista
            if self.ActiveTab == "Network" and not self.SelectedAction then
                local riskEmoji = (remoteEntry.RiskLevel == "CRITICAL" and "🚨")
                    or (remoteEntry.RiskLevel == "HIGH" and "⚔️")
                    or (remoteEntry.RiskLevel == "MEDIUM" and "⚠️")
                    or "📡"
                local line = string.format("%s [%s][%s] %s\n   ▶ Snippet: %s%s\n------------------------------------------------------------------\n",
                    riskEmoji,
                    remoteEntry.RiskLevel or "INFO",
                    remoteEntry.Method,
                    remoteEntry.Path,
                    remoteEntry.Snippet or "N/A",
                    remoteEntry.CallingScript and ("\n   📍 Emisor: " .. remoteEntry.CallingScript) or ""
                )
                inspectorBox.Text = line .. (inspectorBox.Text or "")
            end
        end)
    end
end

function RemoteSpyView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return RemoteSpyView
