--[[
    =============================================================================
    APEX SUITE - AUDIT VIEW (DEDICATED MODES & MULTILINGUAL SCANNER)
    =============================================================================
    Pestaña de escaneo heurístico con 4 modos seleccionables:
    - 🛡️ Anti-Cheat & Kicks (Watchdogs, Integridad, Kicks)
    - 🎰 Lógica & Ruleta (Economía, Gacha, Probabilidades, RNG)
    - 📡 Todos los Remotes (Mapeo completo de RemoteEvents y RemoteFunctions)
    - 🌐 Auditoría Completa (Perfil arquitectónico, métricas y scoring)
--]]

local AuditView = {}
AuditView.__index = AuditView
AuditView.ClassName = "AuditView"

function AuditView.new(parentFrame, registry)
    local self = setmetatable({}, AuditView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.CurrentMode = "AntiCheat"
    self:Render()
    return self
end

function AuditView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame
    
    -- 1. Barra de Selección de Modos de Auditoría (Exacto a auditorAutomatico.lua)
    local modeBar = Instance.new("Frame")
    modeBar.Size = UDim2.new(1, 0, 0, 32)
    modeBar.BackgroundTransparency = 1
    modeBar.Parent = frame
    
    local modes = {
        { Id = "AntiCheat", Label = "🛡️ Anti-Cheat & Kicks" },
        { Id = "Economy",   Label = "🎰 Lógica & Ruleta" },
        { Id = "Remotes",   Label = "📡 Todos los Remotes" },
        { Id = "FullAudit", Label = "🌐 Auditoría Completa" },
    }
    local modeBtns = {}
    local tabWidth = 1 / #modes
    
    local previewBox = Instance.new("TextBox") -- Referencia anticipada
    
    local function selectMode(modeId)
        self.CurrentMode = modeId
        for id, btn in pairs(modeBtns) do
            if id == modeId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
                btn.TextColor3 = Color3.fromRGB(160, 168, 185)
            end
        end
        previewBox.Text = string.format("-- Modo seleccionado: %s\nPresiona '⚡ EJECUTAR ESCANEO' para iniciar el análisis.", modeId)
    end
    
    for i, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(tabWidth, -4, 1, 0)
        btn.Position = UDim2.new((i - 1) * tabWidth, 2, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
        btn.Text = m.Label
        btn.TextColor3 = Color3.fromRGB(160, 168, 185)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = modeBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        modeBtns[m.Id] = btn
        btn.MouseButton1Click:Connect(function() selectMode(m.Id) end)
    end
    
    -- 2. Barra de Acciones y Ejecución
    local actionRow = Instance.new("Frame")
    actionRow.Size = UDim2.new(1, 0, 0, 32)
    actionRow.Position = UDim2.new(0, 0, 0, 38)
    actionRow.BackgroundTransparency = 1
    actionRow.Parent = frame
    
    local runBtn = Instance.new("TextButton")
    runBtn.Size = UDim2.new(0, 160, 1, 0)
    runBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    runBtn.Text = "⚡ EJECUTAR ESCANEO"
    runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    runBtn.Font = Enum.Font.GothamBold
    runBtn.TextSize = 12
    runBtn.Parent = actionRow
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 6)
    
    local exportJsonBtn = Instance.new("TextButton")
    exportJsonBtn.Size = UDim2.new(0, 130, 1, 0)
    exportJsonBtn.Position = UDim2.new(0, 168, 0, 0)
    exportJsonBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    exportJsonBtn.Text = "💾 EXPORTAR JSON"
    exportJsonBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    exportJsonBtn.Font = Enum.Font.GothamMedium
    exportJsonBtn.TextSize = 11
    exportJsonBtn.Parent = actionRow
    Instance.new("UICorner", exportJsonBtn).CornerRadius = UDim.new(0, 6)
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -310, 1, 0)
    statusLabel.Position = UDim2.new(0, 306, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Sistema listo para auditar."
    statusLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = actionRow
    
    -- 3. Área de Texto para Visualizar Reporte y Código Decompilado
    previewBox.Size = UDim2.new(1, 0, 1, -78)
    previewBox.Position = UDim2.new(0, 0, 0, 78)
    previewBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    previewBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    previewBox.Font = Enum.Font.Code
    previewBox.TextSize = 11
    previewBox.TextXAlignment = Enum.TextXAlignment.Left
    previewBox.TextYAlignment = Enum.TextYAlignment.Top
    previewBox.ClearTextOnFocus = false
    previewBox.MultiLine = true
    previewBox.TextEditable = false
    previewBox.Parent = frame
    Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 8)
    
    selectMode("AntiCheat")
    
    local lastAuditData = nil
    
    runBtn.MouseButton1Click:Connect(function()
        statusLabel.Text = "Ejecutando escaneo: " .. self.CurrentMode .. "..."
        runBtn.Text = "⏳ ANALIZANDO..."
        task.wait(0.1)
        
        local heuristic = self.Registry:Get("HeuristicEngine")
        local structural = self.Registry:Get("StructuralProfiler")
        if not heuristic then return end
        
        local lines = {}
        
        -- MODO 1: Anti-Cheat & Kicks
        if self.CurrentMode == "AntiCheat" then
            local rep = heuristic:RunAntiCheatAudit()
            lastAuditData = rep
            table.insert(lines, "-- [[ 🛡️ AUDITORÍA AUTOMÁTICA DE SEGURIDAD & ANTI-CHEAT ]] --")
            table.insert(lines, string.format("-- Instancias Sospechosas Encontradas: %d\n", rep.TotalFound))
            
            for _, item in ipairs(rep.Targets) do
                table.insert(lines, string.format("-> [%s] %s | Score: %d/100 | Ruta: %s", item.ClassName, item.Name, item.Score, item.Path))
                if #item.Tags > 0 then
                    table.insert(lines, "   Firmas: " .. table.concat(item.Tags, ", "))
                end
                if item.Code then
                    table.insert(lines, "   [CÓDIGO EXTRAÍDO]:\n" .. item.Code .. "\n")
                end
            end
            
        -- MODO 2: Economía & Ruleta
        elseif self.CurrentMode == "Economy" then
            local rep = heuristic:RunEconomyAudit()
            lastAuditData = rep
            table.insert(lines, "-- [[ 🎰 ANÁLISIS DE RULETA, PROBABILIDADES Y ECONOMÍA ]] --")
            table.insert(lines, string.format("-- Elementos de Azar y Economía Encontrados: %d\n", rep.TotalFound))
            
            for _, item in ipairs(rep.Targets) do
                table.insert(lines, string.format("-> [%s] %s | Ruta: %s", item.ClassName, item.Name, item.Path))
                if item.Code then
                    table.insert(lines, "   [CÓDIGO EXTRAÍDO]:\n" .. item.Code .. "\n")
                end
            end
            
        -- MODO 3: Todos los Remotes
        elseif self.CurrentMode == "Remotes" then
            local rep = heuristic:RunRemotesAudit()
            lastAuditData = rep
            table.insert(lines, "-- [[ 📡 MAPEO COMPLETO DE EVENTOS Y FUNCIONES REMOTAS ]] --")
            table.insert(lines, string.format("-- Total de Remotes Detectados: %d\n", rep.TotalFound))
            
            for _, rem in ipairs(rep.RemoteEvents) do
                table.insert(lines, string.format("-> [RemoteEvent] %s | Ruta: %s", rem.Name, rem.Path))
            end
            for _, rem in ipairs(rep.RemoteFunctions) do
                table.insert(lines, string.format("-> [RemoteFunction] %s | Ruta: %s", rem.Name, rem.Path))
            end
            
        -- MODO 4: Auditoría Completa
        else
            local fullAudit = heuristic:RunFullAudit()
            local archReport = structural and structural:GenerateReport() or nil
            lastAuditData = { Audit = fullAudit, Architecture = archReport }
            
            table.insert(lines, "==================================================================")
            table.insert(lines, "🛡️ REPORTE DE AUDITORÍA HEURÍSTICA & ANÁLISIS TOPOLÓGICO TOTAL")
            table.insert(lines, "==================================================================")
            table.insert(lines, string.format("Total de elementos analizados: %d", fullAudit.TotalScanned))
            table.insert(lines, string.format("Amenazas Críticas detectadas: %d", fullAudit.CriticalIssues))
            table.insert(lines, string.format("Watchdogs / Anti-Cheat localizados: %d", #fullAudit.AntiCheat))
            table.insert(lines, string.format("Vulnerabilidades de Combate: %d", #fullAudit.Combat))
            table.insert(lines, string.format("Sistemas de Economía: %d", #fullAudit.Economy))
            table.insert(lines, string.format("Remotes mapeados: %d\n", #fullAudit.Remotes))
            
            if archReport and archReport.Frameworks then
                table.insert(lines, "• Frameworks Detectados: " .. table.concat(archReport.Frameworks, ", "))
            end
        end
        
        previewBox.Text = table.concat(lines, "\n")
        statusLabel.Text = string.format("Escaneo de '%s' finalizado con éxito.", self.CurrentMode)
        runBtn.Text = "⚡ EJECUTAR ESCANEO"
    end)
    
    exportJsonBtn.MouseButton1Click:Connect(function()
        if not lastAuditData then
            statusLabel.Text = "Ejecuta un escaneo antes de exportar."
            return
        end
        local exporter = self.Registry:Get("ReportExporter")
        if exporter then
            local jsonStr = exporter:ToJSON(lastAuditData)
            local success, target = exporter:SaveToFile("audit_" .. self.CurrentMode .. "_" .. tick() .. ".json", jsonStr)
            if success then
                statusLabel.Text = "Exportado: " .. tostring(target)
            else
                statusLabel.Text = "Fallo al exportar."
            end
        end
    end)
end

function AuditView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return AuditView
