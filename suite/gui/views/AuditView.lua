--[[
    =============================================================================
    APEX SUITE - AUDIT VIEW (DEDICATED MULTITHREADED MODES & LIVE PROGRESS HUD)
    =============================================================================
    Pestaña de escaneo heurístico con 4 modos multihilo y panel de telemetría:
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
    
    -- 1. Barra de Selección de Modos de Auditoría
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
        previewBox.Text = string.format("-- Modo seleccionado: %s\nPresiona '⚡ EJECUTAR ESCANEO MULTIHILO' para iniciar el análisis en tiempo real.", modeId)
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
    runBtn.Size = UDim2.new(0, 210, 1, 0)
    runBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    runBtn.Text = "⚡ ESCANEO MULTIHILO"
    runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    runBtn.Font = Enum.Font.GothamBold
    runBtn.TextSize = 11
    runBtn.Parent = actionRow
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 6)
    
    local exportJsonBtn = Instance.new("TextButton")
    exportJsonBtn.Size = UDim2.new(0, 130, 1, 0)
    exportJsonBtn.Position = UDim2.new(0, 216, 0, 0)
    exportJsonBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    exportJsonBtn.Text = "💾 EXPORTAR JSON"
    exportJsonBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    exportJsonBtn.Font = Enum.Font.GothamMedium
    exportJsonBtn.TextSize = 11
    exportJsonBtn.Parent = actionRow
    Instance.new("UICorner", exportJsonBtn).CornerRadius = UDim.new(0, 6)
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -356, 1, 0)
    statusLabel.Position = UDim2.new(0, 352, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "⚡ Motor Multihilo (6 Workers) listo para auditar."
    statusLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = actionRow
    
    -- 3. Panel HUD de Telemetría y Barra de Progreso en Tiempo Real
    local progressHud = Instance.new("Frame")
    progressHud.Size = UDim2.new(1, 0, 0, 42)
    progressHud.Position = UDim2.new(0, 0, 0, 74)
    progressHud.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
    progressHud.Parent = frame
    Instance.new("UICorner", progressHud).CornerRadius = UDim.new(0, 6)
    
    local progressTrack = Instance.new("Frame")
    progressTrack.Size = UDim2.new(1, -16, 0, 6)
    progressTrack.Position = UDim2.new(0, 8, 0, 6)
    progressTrack.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    progressTrack.Parent = progressHud
    Instance.new("UICorner", progressTrack).CornerRadius = UDim.new(0, 3)
    
    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    progressFill.Parent = progressTrack
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 3)
    
    local metricsLabel = Instance.new("TextLabel")
    metricsLabel.Size = UDim2.new(0.65, -8, 0, 22)
    metricsLabel.Position = UDim2.new(0, 8, 0, 16)
    metricsLabel.BackgroundTransparency = 1
    metricsLabel.Text = "⏱️ Transcurrido: 0.0s | ⏳ Restante: 0.0s | ⚡ 0 items/s"
    metricsLabel.TextColor3 = Color3.fromRGB(160, 185, 215)
    metricsLabel.Font = Enum.Font.Code
    metricsLabel.TextSize = 10
    metricsLabel.TextXAlignment = Enum.TextXAlignment.Left
    metricsLabel.Parent = progressHud
    
    local itemIndicator = Instance.new("TextLabel")
    itemIndicator.Size = UDim2.new(0.35, -8, 0, 22)
    itemIndicator.Position = UDim2.new(0.65, 0, 0, 16)
    itemIndicator.BackgroundTransparency = 1
    itemIndicator.Text = "Progreso: 0% [0 / 0]"
    itemIndicator.TextColor3 = Color3.fromRGB(0, 200, 255)
    itemIndicator.Font = Enum.Font.GothamBold
    itemIndicator.TextSize = 10
    itemIndicator.TextXAlignment = Enum.TextXAlignment.Right
    itemIndicator.Parent = progressHud
    
    -- 4. Área de Texto para Visualizar Reporte y Código Decompilado
    previewBox.Size = UDim2.new(1, 0, 1, -122)
    previewBox.Position = UDim2.new(0, 0, 0, 122)
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
    
    local function updateProgressUI(completed, total, currentName, elapsed, eta, speed)
        local pct = (total > 0) and math.clamp(completed / total, 0, 1) or 0
        progressFill.Size = UDim2.new(pct, 0, 1, 0)
        itemIndicator.Text = string.format("Progreso: %d%% [%d / %d]", math.floor(pct * 100), completed, total)
        metricsLabel.Text = string.format("⏱️ %.1fs | ⏳ Restante: ~%.1fs | ⚡ %.0f elem/s | 🔍 %s", elapsed, eta, speed, tostring(currentName or ""):sub(1, 30))
    end
    
    runBtn.MouseButton1Click:Connect(function()
        runBtn.Text = "⏳ PROCESANDO..."
        runBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        statusLabel.Text = "Iniciando workers concurrentes..."
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        task.wait(0.05)
        
        local heuristic = self.Registry:Get("HeuristicEngine")
        local structural = self.Registry:Get("StructuralProfiler")
        if not heuristic then return end
        
        local lines = {}
        local startTime = tick()
        
        task.spawn(function()
            -- MODO 1: Anti-Cheat & Kicks
            if self.CurrentMode == "AntiCheat" then
                local rep = heuristic:RunAntiCheatAudit(nil, updateProgressUI)
                lastAuditData = rep
                table.insert(lines, "-- [[ 🛡️ AUDITORÍA MULTIHILO DE SEGURIDAD & ANTI-CHEAT ]] --")
                table.insert(lines, string.format("-- Instancias Sospechosas Encontradas: %d | Tiempo Total: %.2fs\n", rep.TotalFound, tick() - startTime))
                
                for _, item in ipairs(rep.Targets) do
                    table.insert(lines, string.format("-> [%s] %s | Score: %d/100 | Ruta: %s", item.ClassName, item.Name, item.Score, item.Path))
                    if #item.Tags > 0 then
                        table.insert(lines, "   Firmas: " .. table.concat(item.Tags, ", "))
                    end
                    if item.Findings and #item.Findings > 0 then
                        for _, f in ipairs(item.Findings) do
                            table.insert(lines, "   [" .. f.Desc .. "]")
                            if f.Snippets then
                                for _, snip in ipairs(f.Snippets) do
                                    table.insert(lines, string.format("      Línea %d: %s", snip.Line, snip.Code))
                                end
                            end
                        end
                    end
                end
                
            -- MODO 2: Economía & Ruleta
            elseif self.CurrentMode == "Economy" then
                local rep = heuristic:RunEconomyAudit(nil, updateProgressUI)
                lastAuditData = rep
                table.insert(lines, "-- [[ 🎰 ANÁLISIS MULTIHILO DE RULETA, PROBABILIDADES Y ECONOMÍA ]] --")
                table.insert(lines, string.format("-- Elementos de Azar y Economía Encontrados: %d | Tiempo Total: %.2fs\n", rep.TotalFound, tick() - startTime))
                
                for _, item in ipairs(rep.Targets) do
                    table.insert(lines, string.format("-> [%s] %s | Ruta: %s", item.ClassName, item.Name, item.Path))
                    if item.Findings and #item.Findings > 0 then
                        for _, f in ipairs(item.Findings) do
                            table.insert(lines, "   [" .. f.Desc .. "]")
                        end
                    end
                end
                
            -- MODO 3: Todos los Remotes
            elseif self.CurrentMode == "Remotes" then
                local rep = heuristic:RunRemotesAudit(nil, updateProgressUI)
                lastAuditData = rep
                table.insert(lines, "-- [[ 📡 MAPEO MULTIHILO DE EVENTOS Y FUNCIONES REMOTAS ]] --")
                table.insert(lines, string.format("-- Total de Remotes Detectados: %d | Tiempo Total: %.2fs\n", rep.TotalFound, tick() - startTime))
                
                for _, rem in ipairs(rep.RemoteEvents) do
                    table.insert(lines, string.format("-> [RemoteEvent] %s | Ruta: %s", rem.Name, rem.Path))
                end
                for _, rem in ipairs(rep.RemoteFunctions) do
                    table.insert(lines, string.format("-> [RemoteFunction] %s | Ruta: %s", rem.Name, rem.Path))
                end
                
            -- MODO 4: Auditoría Completa
            else
                local fullAudit = heuristic:RunFullAudit(nil, updateProgressUI)
                local archReport = structural and structural:GenerateReport() or nil
                lastAuditData = { Audit = fullAudit, Architecture = archReport }
                
                table.insert(lines, "==================================================================")
                table.insert(lines, "🛡️ REPORTE DE AUDITORÍA HEURÍSTICA & ANÁLISIS TOPOLÓGICO TOTAL")
                table.insert(lines, "==================================================================")
                table.insert(lines, string.format("Tiempo de Ejecución Multihilo: %.2fs", tick() - startTime))
                table.insert(lines, string.format("Total de elementos analizados: %d", fullAudit.TotalScanned))
                table.insert(lines, string.format("Amenazas Críticas detectadas: %d", fullAudit.CriticalIssues))
                table.insert(lines, string.format("Herramientas Administrativas Dev: %d", #fullAudit.AdminTools))
                table.insert(lines, string.format("Watchdogs / Anti-Cheat localizados: %d", #fullAudit.AntiCheat))
                table.insert(lines, string.format("Vulnerabilidades de Combate: %d", #fullAudit.Combat))
                table.insert(lines, string.format("Sistemas de Economía: %d", #fullAudit.Economy))
                table.insert(lines, string.format("Remotes mapeados: %d\n", #fullAudit.Remotes))
                
                if archReport and archReport.Frameworks then
                    table.insert(lines, "• Frameworks Detectados: " .. table.concat(archReport.Frameworks, ", "))
                end
            end
            
            local function setSafeText(targetBox, text)
                local maxLimit = 75000
                local str = tostring(text or "")
                if #str > maxLimit then
                    targetBox.Text = string.sub(str, 1, maxLimit) .. string.format("\n\n-- [⚠️ AVISO: Vista previa truncada a %d caracteres por límite de interfaz de Roblox]\n-- [Total: %d caracteres. El reporte completo e intacto se puede exportar con '💾 EXPORTAR JSON']", maxLimit, #str)
                else
                    targetBox.Text = str
                end
            end
            
            setSafeText(previewBox, table.concat(lines, "\n"))
            local duration = tick() - startTime
            statusLabel.Text = string.format("Escaneo finalizado en %.2fs (%s).", duration, self.CurrentMode)
            metricsLabel.Text = string.format("✅ Completado en %.2fs | Velocidad máxima alcanzada.", duration)
            progressFill.Size = UDim2.new(1, 0, 1, 0)
            runBtn.Text = "⚡ ESCANEO MULTIHILO"
            runBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
        end)
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
