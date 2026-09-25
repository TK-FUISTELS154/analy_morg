--[[
    =============================================================================
    APEX SUITE - DUMPER VIEW v3.0
    (MULTI-MODE EXTRACTION + VFS ARCHIVE + DISK RECONSTRUCTION)
    =============================================================================
    Explorador de instancias con 4 modos de extracción + 3 formatos de salida:
    - JSON plano, VFS Archive (archivo único), Proyecto a Disco (.lua)
    - Barra de progreso con ETA y velocidad
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
    actionRow.Size = UDim2.new(1, -12, 0, 68)
    actionRow.Position = UDim2.new(0, 6, 1, -74)
    actionRow.BackgroundTransparency = 1
    actionRow.Parent = leftPanel
    
    local dumpBtn = Instance.new("TextButton")
    dumpBtn.Size = UDim2.new(0.48, -2, 0, 28)
    dumpBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    dumpBtn.Text = "📂 EXTRAER JSON"
    dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpBtn.Font = Enum.Font.GothamBold
    dumpBtn.TextSize = 11
    dumpBtn.Parent = actionRow
    Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 6)
    
    local diskBtn = Instance.new("TextButton")
    diskBtn.Size = UDim2.new(0.48, -2, 0, 28)
    diskBtn.Position = UDim2.new(0.52, 0, 0, 0)
    diskBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
    diskBtn.Text = "💾 DISCO (.LUA)"
    diskBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    diskBtn.Font = Enum.Font.GothamBold
    diskBtn.TextSize = 10
    diskBtn.Parent = actionRow
    Instance.new("UICorner", diskBtn).CornerRadius = UDim.new(0, 6)
    
    local vfsBtn = Instance.new("TextButton")
    vfsBtn.Size = UDim2.new(1, 0, 0, 28)
    vfsBtn.Position = UDim2.new(0, 0, 0, 34)
    vfsBtn.BackgroundColor3 = Color3.fromRGB(30, 130, 80)
    vfsBtn.Text = "📦 VFS ARCHIVE (Archivo Único)"
    vfsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    vfsBtn.Font = Enum.Font.GothamBold
    vfsBtn.TextSize = 10
    vfsBtn.Parent = actionRow
    Instance.new("UICorner", vfsBtn).CornerRadius = UDim.new(0, 6)
    
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
    
    local function executeDump(exportMode)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        local heuristic = self.Registry:Get("HeuristicEngine")
        local actionRecorder = self.Registry:Get("ActionRecorder")
        
        if not dumper or not exporter then return end
        
        infoLabel.Text = "⏳ Procesando extracción en modo " .. self.CurrentMode .. "..."
        dumpBtn.Text = "⏳ VOLCANDO..."
        diskBtn.Text = "⏳ VOLCANDO..."
        vfsBtn.Text = "⏳ VOLCANDO..."
        
        task.spawn(function()
            local startTime = tick()
            local package = nil
            
            local function onProgress(curr, total, name)
                local elapsed = tick() - startTime
                local speed = curr / math.max(elapsed, 0.001)
                local eta = speed > 0 and ((total - curr) / speed) or 0
                infoLabel.Text = string.format("⏳ [%d/%d] %s | %.1fs | ETA: ~%.1fs", curr, total, tostring(name or ""):sub(1, 25), elapsed, eta)
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
            
            -- Exportar según el modo seleccionado
            if exportMode == "vfs" then
                local s, path = exporter:ExportAsVFSArchive("Dump_" .. self.CurrentMode, package)
                if s then
                    infoLabel.Text = string.format("✅ VFS Archive exportado en %.2fs: %s", duration, tostring(path))
                else
                    infoLabel.Text = "❌ VFS Error: " .. tostring(path)
                end
                previewBox.Text = "-- VFS Archive exportado. El contenido está en el archivo JSON único.\n-- Usa un visor JSON para inspeccionar las " .. tostring(package and package.TotalScriptsDumped or 0) .. " entradas."
            elseif exportMode == "disk" then
                local jsonStr = exporter:ToJSON(package)
                local function setSafeText(targetBox, text)
                    local maxLimit = 75000
                    local str = tostring(text or "")
                    if #str > maxLimit then
                        targetBox.Text = str:sub(1, maxLimit) .. string.format("\n\n-- [⚠️ Truncado a %d chars. Total: %d chars]", maxLimit, #str)
                    else
                        targetBox.Text = str
                    end
                end
                setSafeText(previewBox, jsonStr)
                
                local s, res = exporter:ExportProjectTreeToDisk("Dump_" .. self.CurrentMode .. "_" .. math.floor(tick()), package)
                if s then
                    infoLabel.Text = string.format("✅ Árbol reconstruido en disco en %.2fs:\n%s", duration, tostring(res))
                else
                    infoLabel.Text = "Resultado: " .. tostring(res)
                end
            else
                local jsonStr = exporter:ToJSON(package)
                local function setSafeText(targetBox, text)
                    local maxLimit = 75000
                    local str = tostring(text or "")
                    if #str > maxLimit then
                        targetBox.Text = str:sub(1, maxLimit) .. string.format("\n\n-- [⚠️ Truncado a %d chars. Total: %d chars]", maxLimit, #str)
                    else
                        targetBox.Text = str
                    end
                end
                setSafeText(previewBox, jsonStr)
                
                local s, path = exporter:SaveToFile("dump_" .. self.CurrentMode .. "_" .. math.floor(tick()) .. ".json", jsonStr)
                infoLabel.Text = string.format("✅ JSON exportado en %.2fs (%d KB) → %s", duration, math.floor(#jsonStr / 1024), tostring(path))
            end
            
            dumpBtn.Text = "📂 EXTRAER JSON"
            diskBtn.Text = "💾 DISCO (.LUA)"
            vfsBtn.Text = "📦 VFS ARCHIVE (Archivo Único)"
        end)
    end
    
    dumpBtn.MouseButton1Click:Connect(function() executeDump("json") end)
    diskBtn.MouseButton1Click:Connect(function() executeDump("disk") end)
    vfsBtn.MouseButton1Click:Connect(function() executeDump("vfs") end)
end

function DumperView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return DumperView
