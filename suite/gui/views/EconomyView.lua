--[[
    =============================================================================
    APEX SUITE - ECONOMY & RNG VIEW (SYNCHRONIZED WITH SHOPS & REMOTES)
    =============================================================================
    Pestaña de auditoría profunda de ruletas, tiendas, loot tables, atributos
    de probabilidad y remotes de transacción en múltiples idiomas.
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
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundTransparency = 1
    topBar.Parent = frame
    
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0, 180, 1, 0)
    scanBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 200)
    scanBtn.Text = "🎰 ESCANEAR ECONOMÍA & RNG"
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 11
    scanBtn.Parent = topBar
    Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 6)
    
    local exportBtn = Instance.new("TextButton")
    exportBtn.Size = UDim2.new(0, 130, 1, 0)
    exportBtn.Position = UDim2.new(0, 188, 0, 0)
    exportBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    exportBtn.Text = "💾 EXPORTAR JSON"
    exportBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
    exportBtn.Font = Enum.Font.GothamMedium
    exportBtn.TextSize = 11
    exportBtn.Parent = topBar
    Instance.new("UICorner", exportBtn).CornerRadius = UDim.new(0, 6)
    
    local resultBox = Instance.new("TextBox")
    resultBox.Size = UDim2.new(1, 0, 1, -44)
    resultBox.Position = UDim2.new(0, 0, 0, 44)
    resultBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    resultBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    resultBox.Text = "-- Presiona 'ESCANEAR ECONOMÍA & RNG' para auditar tiendas, ruletas, loot tables y remotes de compra."
    resultBox.Font = Enum.Font.Code
    resultBox.TextSize = 11
    resultBox.TextXAlignment = Enum.TextXAlignment.Left
    resultBox.TextYAlignment = Enum.TextYAlignment.Top
    resultBox.ClearTextOnFocus = false
    resultBox.MultiLine = true
    resultBox.TextEditable = false
    resultBox.Parent = frame
    Instance.new("UICorner", resultBox).CornerRadius = UDim.new(0, 8)
    
    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "⏳ ESCANEANDO..."
        task.wait(0.1)
        
        local economy = self.Registry:Get("EconomyAuditor")
        if economy then
            local results = economy:ScanEconomyNodes()
            self.LastFindings = results
            
            local lines = {
                "==================================================================",
                "🎰 AUDITORÍA DE SISTEMAS DE ECONOMÍA, RULETA, GACHA & TRANSACCIONES",
                "==================================================================",
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
            
            resultBox.Text = table.concat(lines, "\n")
        end
        scanBtn.Text = "🎰 ESCANEAR ECONOMÍA & RNG"
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
