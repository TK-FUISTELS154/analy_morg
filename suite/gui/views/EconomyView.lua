--[[
    =============================================================================
    APEX SUITE - ECONOMY & RNG VIEW (MULTITHREADED AUDITOR & PROGRESS HUD)
    =============================================================================
    Pestaña de auditoría profunda de ruletas, tiendas, loot tables, atributos
    de probabilidad y remotes de transacción con motor multihilo y telemetría.
--]]

local EconomyView = {}
EconomyView.__index = EconomyView
EconomyView.ClassName = "EconomyView"

function EconomyView.new(parentFrame, registry)
    local self = setmetatable({}, EconomyView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.LastFindings = nil
    self:Render()
    return self
end

function EconomyView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame
    
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 32)
    topBar.BackgroundTransparency = 1
    topBar.Parent = frame
    
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0, 210, 1, 0)
    scanBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 200)
    scanBtn.Text = "🎰 ESCANEO MULTIHILO"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 11
    scanBtn.Parent = topBar
    Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 6)
    
    local exportBtn = Instance.new("TextButton")
    exportBtn.Size = UDim2.new(0, 130, 1, 0)
    exportBtn.Position = UDim2.new(0, 216, 0, 0)
    exportBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    exportBtn.Text = "💾 EXPORTAR JSON"
    exportBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    exportBtn.Font = Enum.Font.GothamMedium
    exportBtn.TextSize = 11
    exportBtn.Parent = topBar
    Instance.new("UICorner", exportBtn).CornerRadius = UDim.new(0, 6)
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -356, 1, 0)
    statusLabel.Position = UDim2.new(0, 352, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🎰 Auditor de Economía Multihilo listo."
    statusLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = topBar
    
    -- Panel HUD de Telemetría y Barra de Progreso en Tiempo Real
    local progressHud = Instance.new("Frame")
    progressHud.Size = UDim2.new(1, 0, 0, 42)
    progressHud.Position = UDim2.new(0, 0, 0, 38)
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
    progressFill.BackgroundColor3 = Color3.fromRGB(180, 90, 240)
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
    itemIndicator.TextColor3 = Color3.fromRGB(190, 100, 255)
    itemIndicator.Font = Enum.Font.GothamBold
    itemIndicator.TextSize = 10
    itemIndicator.TextXAlignment = Enum.TextXAlignment.Right
    itemIndicator.Parent = progressHud
    
    local resultBox = Instance.new("TextBox")
    resultBox.Size = UDim2.new(1, 0, 1, -86)
    resultBox.Position = UDim2.new(0, 0, 0, 86)
    resultBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    resultBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    resultBox.Text = "-- Presiona 'ESCANEO MULTIHILO' para auditar tiendas, ruletas, loot tables y remotes de compra en tiempo real."
    resultBox.Font = Enum.Font.Code
    resultBox.TextSize = 11
    resultBox.TextXAlignment = Enum.TextXAlignment.Left
    resultBox.TextYAlignment = Enum.TextYAlignment.Top
    resultBox.ClearTextOnFocus = false
    resultBox.MultiLine = true
    resultBox.TextEditable = false
    resultBox.Parent = frame
    Instance.new("UICorner", resultBox).CornerRadius = UDim.new(0, 8)
    
    local function updateProgressUI(completed, total, currentName, elapsed, eta, speed)
        local pct = (total > 0) and math.clamp(completed / total, 0, 1) or 0
        progressFill.Size = UDim2.new(pct, 0, 1, 0)
        itemIndicator.Text = string.format("Progreso: %d%% [%d / %d]", math.floor(pct * 100), completed, total)
        metricsLabel.Text = string.format("⏱️ %.1fs | ⏳ Restante: ~%.1fs | ⚡ %.0f elem/s | 🔍 %s", elapsed, eta, speed, tostring(currentName or ""):sub(1, 30))
    end
    
    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "⏳ PROCESANDO..."
        scanBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 0)
        statusLabel.Text = "Iniciando workers de economía..."
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        task.wait(0.05)
        
        local economy = self.Registry:Get("EconomyAuditor")
        if economy then
            local startTime = tick()
            task.spawn(function()
                local results = economy:ScanEconomyNodes(updateProgressUI)
                self.LastFindings = results
                
                local duration = tick() - startTime
                local lines = {
                    "==================================================================",
                    "🎰 AUDITORÍA MULTIHILO DE ECONOMÍA, RULETA, GACHA & TRANSACCIONES",
                    "==================================================================",
                    string.format("Tiempo Total de Escaneo: %.2fs", duration),
                    string.format("Total de elementos encontrados: %d", results.TotalFound),
                    string.format("• Nodos de Ruleta / Gacha / Tiradas: %d", #results.Roulettes),
                    string.format("• Módulos de Tiendas / Compras: %d", #results.Shops),
                    string.format("• Tablas de Loot & Probabilidad (ModuleScripts): %d", #results.LootTables),
                    string.format("• Contenedores de Atributos & Precios (Values): %d", #results.ValueContainers),
                    string.format("• Remotes de Transacción Vinculados: %d", #results.CorrelatedPurchaseRemotes),
                    "------------------------------------------------------------------\n",
                }
                
                if #results.CorrelatedPurchaseRemotes > 0 then
                    table.insert(lines, "[REMOTES DE COMPRA & TRANSACCIÓN INTERCEPTADOS]:")
                    for _, r in ipairs(results.CorrelatedPurchaseRemotes) do
                        table.insert(lines, string.format("💰 [%s] %s\n   Snippet: %s", r.RemoteName, r.Path, r.Snippet or "N/A"))
                    end
                    table.insert(lines, "")
                end
                
                if #results.Roulettes > 0 then
                    table.insert(lines, "[SISTEMAS DE RULETA & AZAR]:")
                    for _, r in ipairs(results.Roulettes) do
                        table.insert(lines, string.format("🎰 [%s] %s | Tag: %s\n   Ruta: %s", r.ClassName, r.Name, r.Tag, r.Path))
                    end
                    table.insert(lines, "")
                end
                
                if #results.Shops > 0 then
                    table.insert(lines, "[TIENDAS & COMPRAS]:")
                    for _, s in ipairs(results.Shops) do
                        table.insert(lines, string.format("🛒 [%s] %s | Tag: %s\n   Ruta: %s", s.ClassName, s.Name, s.Tag, s.Path))
                    end
                    table.insert(lines, "")
                end
                
                if #results.LootTables > 0 then
                    table.insert(lines, "[TABLAS DE LOOT & PROBABILIDAD (MODULES)]:")
                    for _, l in ipairs(results.LootTables) do
                        table.insert(lines, string.format("📜 [%s] %s | Ruta: %s", l.ClassName, l.Name, l.Path))
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
                
                setSafeText(resultBox, table.concat(lines, "\n"))
                statusLabel.Text = string.format("Escaneo de economía finalizado en %.2fs.", duration)
                metricsLabel.Text = string.format("✅ Completado en %.2fs | Velocidad máxima alcanzada.", duration)
                progressFill.Size = UDim2.new(1, 0, 1, 0)
                scanBtn.Text = "🎰 ESCANEO MULTIHILO"
                scanBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 200)
            end)
        end
    end)
    
    exportBtn.MouseButton1Click:Connect(function()
        if not self.LastFindings then
            resultBox.Text = "-- Realiza un escaneo antes de exportar."
            return
        end
        local exporter = self.Registry:Get("ReportExporter")
        if exporter then
            local jsonStr = exporter:ToJSON(self.LastFindings)
            exporter:SaveToFile("economy_audit_" .. tick() .. ".json", jsonStr)
        end
    end)
end

function EconomyView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return EconomyView
