--[[
    =============================================================================
    APEX SUITE - DUMPER VIEW (MULTI-MODE EXTRACTION & DISK RECONSTRUCTION)
    =============================================================================
    Explorador de instancias con 4 modos de extracción profesional:
    - Extracción Manual de Nodos
    - Extracción de Carpetas con Hallazgos Heurísticos
    - Extracción de Cadena de Dependencias y Código Intermedio
    - Volcado Total del Entorno de Scripts en Disco (.lua)
--]]

local DumperView = {}
DumperView.__index = DumperView
DumperView.ClassName = "DumperView"

function DumperView.new(parentFrame, registry)
    local self = setmetatable({}, DumperView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.CurrentMode = "MANUAL_TREE"
    self:Render()
    return self
end

function DumperView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame
    
    -- Barra superior de Modos de Extracción
    local modeBar = Instance.new("Frame")
    modeBar.Size = UDim2.new(1, 0, 0, 32)
    modeBar.BackgroundTransparency = 1
    modeBar.Parent = frame
    
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.48, 0, 1, -38)
    leftPanel.Position = UDim2.new(0, 0, 0, 38)
    leftPanel.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
    leftPanel.Parent = frame
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 8)
    
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.50, 0, 1, -38)
    rightPanel.Position = UDim2.new(0.50, 0, 0, 38)
    rightPanel.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
    rightPanel.Parent = frame
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 8)
    
    -- Botones de Modos en modeBar
    local modes = {
        { Id = "MANUAL_TREE", Label = "🌲 Manual" },
        { Id = "HEURISTIC_FINDINGS", Label = "🎯 Heurístico" },
        { Id = "DEPENDENCY_CHAIN", Label = "🔗 Dependencias" },
        { Id = "FULL_ENVIRONMENT", Label = "🌐 Entorno Total" },
    }
    local modeBtns = {}
    local modeWidth = 1 / #modes
    
    local function setMode(modeId)
        self.CurrentMode = modeId
        for id, btn in pairs(modeBtns) do
            if id == modeId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
                btn.TextColor3 = Color3.fromRGB(160, 168, 185)
            end
        end
    end
    
    for i, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(modeWidth, -4, 1, 0)
        btn.Position = UDim2.new((i - 1) * modeWidth, 2, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
        btn.Text = m.Label
        btn.TextColor3 = Color3.fromRGB(160, 168, 185)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.Parent = modeBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        
        modeBtns[m.Id] = btn
        btn.MouseButton1Click:Connect(function() setMode(m.Id) end)
    end
    setMode("MANUAL_TREE")
    
    -- Panel izquierdo: Búsqueda y acciones
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -12, 0, 28)
    searchBox.Position = UDim2.new(0, 6, 0, 6)
    searchBox.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
    searchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
    searchBox.PlaceholderText = "Filtrar jerarquía..."
    searchBox.Text = ""
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.Parent = leftPanel
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -12, 0, 60)
    infoLabel.Position = UDim2.new(0, 6, 0, 40)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Selecciona un modo arriba y presiona EXTRAER para procesar instancias, código intermedio y carpetas."
    infoLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = leftPanel
    
    local actionRow = Instance.new("Frame")
    actionRow.Size = UDim2.new(1, -12, 0, 32)
    actionRow.Position = UDim2.new(0, 6, 1, -38)
    actionRow.BackgroundTransparency = 1
    actionRow.Parent = leftPanel
    
    local dumpBtn = Instance.new("TextButton")
    dumpBtn.Size = UDim2.new(0.48, -2, 1, 0)
    dumpBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    dumpBtn.Text = "📂 EXTRAER JSON"
    dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpBtn.Font = Enum.Font.GothamBold
    dumpBtn.TextSize = 11
    dumpBtn.Parent = actionRow
    Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 6)
    
    local diskBtn = Instance.new("TextButton")
    diskBtn.Size = UDim2.new(0.48, -2, 1, 0)
    diskBtn.Position = UDim2.new(0.52, 0, 0, 0)
    diskBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
    diskBtn.Text = "💾 PROYECTO A DISCO (.LUA)"
    diskBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    diskBtn.Font = Enum.Font.GothamBold
    diskBtn.TextSize = 10
    diskBtn.Parent = actionRow
    Instance.new("UICorner", diskBtn).CornerRadius = UDim.new(0, 6)
    
    -- Panel derecho: Vista previa
    local previewBox = Instance.new("TextBox")
    previewBox.Size = UDim2.new(1, -12, 1, -12)
    previewBox.Position = UDim2.new(0, 6, 0, 6)
    previewBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    previewBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    previewBox.Text = "-- Los datos estructurados y scripts extraídos se visualizarán aquí."
    previewBox.Font = Enum.Font.Code
    previewBox.TextSize = 11
    previewBox.TextXAlignment = Enum.TextXAlignment.Left
    previewBox.TextYAlignment = Enum.TextYAlignment.Top
    previewBox.ClearTextOnFocus = false
    previewBox.MultiLine = true
    previewBox.TextEditable = false
    previewBox.Parent = rightPanel
    Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 6)
    
    local function executeDump(exportToDisk)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        local heuristic = self.Registry:Get("HeuristicEngine")
        local actionRecorder = self.Registry:Get("ActionRecorder")
        
        if not dumper or not exporter then return end
        
        infoLabel.Text = "⏳ Procesando extracción en modo " .. self.CurrentMode .. "..."
        dumpBtn.Text = "⏳ VOLCANDO..."
        diskBtn.Text = "⏳ VOLCANDO..."
        
        task.spawn(function()
            local startTime = tick()
            local package = nil
            
            local function onProgress(curr, total, name)
                infoLabel.Text = string.format("⏳ Extrayendo [%d/%d]: %s", curr, total, tostring(name or ""):sub(1, 30))
            end
            
            if self.CurrentMode == "HEURISTIC_FINDINGS" then
                local audit = heuristic and heuristic:RunFullAudit(nil, onProgress)
                package = dumper:DumpHeuristicFindings(audit, onProgress)
            elseif self.CurrentMode == "DEPENDENCY_CHAIN" then
                package = dumper:DumpDependencyChain(actionRecorder and actionRecorder.RecentAction, onProgress)
            elseif self.CurrentMode == "FULL_ENVIRONMENT" then
                package = dumper:DumpFullEnvironment(onProgress)
            else
                local defaultRoots = { game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") }
                package = dumper:DumpManualNodes(defaultRoots, onProgress)
            end
            
            local duration = tick() - startTime
            local jsonStr = exporter:ToJSON(package)
            
            local function setSafeText(targetBox, text)
                local maxLimit = 75000
                local str = tostring(text or "")
                if #str > maxLimit then
                    targetBox.Text = string.sub(str, 1, maxLimit) .. string.format("\n\n-- [⚠️ AVISO: Vista previa truncada a %d caracteres por límite de interfaz de Roblox]\n-- [Total: %d caracteres. El proyecto completo e intacto se ha guardado en disco / archivo JSON]", maxLimit, #str)
                else
                    targetBox.Text = str
                end
            end
            setSafeText(previewBox, jsonStr)
            
            if exportToDisk then
                local s, res = exporter:ExportProjectTreeToDisk("Dump_" .. self.CurrentMode .. "_" .. tick(), package)
                if s then
                    infoLabel.Text = string.format("✅ Árbol reconstruido en disco en %.2fs:\n%s", duration, tostring(res))
                else
                    infoLabel.Text = "Resultado: " .. tostring(res)
                end
            else
                local s, path = exporter:SaveToFile("dump_" .. self.CurrentMode .. "_" .. tick() .. ".json", jsonStr)
                infoLabel.Text = string.format("✅ Extracción completada en %.2fs (%s)", duration, tostring(path))
            end
            
            dumpBtn.Text = "📂 EXTRAER JSON"
            diskBtn.Text = "💾 PROYECTO A DISCO (.LUA)"
        end)
    end
    
    dumpBtn.MouseButton1Click:Connect(function() executeDump(false) end)
    diskBtn.MouseButton1Click:Connect(function() executeDump(true) end)
end

function DumperView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return DumperView
