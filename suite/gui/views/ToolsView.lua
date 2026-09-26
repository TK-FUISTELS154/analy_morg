--[[
    =============================================================================
    APEX SUITE - TOOLS & DIAGNOSTICS VIEW
    =============================================================================
    Lanzador de herramientas externas (Infinite Yield, DarkDex) y panel de
    diagnóstico de capacidades del ejecutor.
--]]

local ToolsView = {}
ToolsView.__index = ToolsView
ToolsView.ClassName = "ToolsView"

function ToolsView.new(parentFrame, registry)
    local self = setmetatable({}, ToolsView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self:Render()
    return self
end

function ToolsView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame
    
    local topRow = Instance.new("Frame")
    topRow.Size = UDim2.new(1, 0, 0, 42)
    topRow.BackgroundTransparency = 1
    topRow.Parent = frame
    
    local dexBtn = Instance.new("TextButton")
    dexBtn.Size = UDim2.new(0.32, -3, 1, 0)
    dexBtn.Position = UDim2.new(0, 0, 0, 0)
    dexBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 140)
    dexBtn.Text = "📁 DARKDEX (EXPLORER)"
    dexBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dexBtn.Font = Enum.Font.GothamBold
    dexBtn.TextSize = 10
    dexBtn.Parent = topRow
    Instance.new("UICorner", dexBtn).CornerRadius = UDim.new(0, 6)

    local selectiveBtn = Instance.new("TextButton")
    selectiveBtn.Size = UDim2.new(0.34, -3, 1, 0)
    selectiveBtn.Position = UDim2.new(0.33, 0, 0, 0)
    selectiveBtn.BackgroundColor3 = Color3.fromRGB(0, 145, 110)
    selectiveBtn.Text = "📂 SELECTIVE DUMPER PRO"
    selectiveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectiveBtn.Font = Enum.Font.GothamBold
    selectiveBtn.TextSize = 10
    selectiveBtn.Parent = topRow
    Instance.new("UICorner", selectiveBtn).CornerRadius = UDim.new(0, 6)
    
    local yieldBtn = Instance.new("TextButton")
    yieldBtn.Size = UDim2.new(0.33, 0, 1, 0)
    yieldBtn.Position = UDim2.new(0.67, 0, 0, 0)
    yieldBtn.BackgroundColor3 = Color3.fromRGB(110, 45, 165)
    yieldBtn.Text = "⚡ INFINITE YIELD"
    yieldBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    yieldBtn.Font = Enum.Font.GothamBold
    yieldBtn.TextSize = 10
    yieldBtn.Parent = topRow
    Instance.new("UICorner", yieldBtn).CornerRadius = UDim.new(0, 6)
    
    -- Panel de diagnóstico
    local diagBox = Instance.new("TextBox")
    diagBox.Size = UDim2.new(1, 0, 1, -50)
    diagBox.Position = UDim2.new(0, 0, 0, 50)
    diagBox.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
    diagBox.TextColor3 = Color3.fromRGB(210, 220, 235)
    diagBox.Font = Enum.Font.Code
    diagBox.TextSize = 11
    diagBox.TextXAlignment = Enum.TextXAlignment.Left
    diagBox.TextYAlignment = Enum.TextYAlignment.Top
    diagBox.ClearTextOnFocus = false
    diagBox.MultiLine = true
    diagBox.TextEditable = false
    diagBox.Parent = frame
    Instance.new("UICorner", diagBox).CornerRadius = UDim.new(0, 8)
    
    local caps = self.Registry:Get("CapabilityManager")
    if caps then
        local lines = {
            "==================================================================",
            "⚙️ DIAGNÓSTICO DEL ENTORNO Y NIVEL DEL EJECUTOR",
            "==================================================================",
            caps:GetSummary(),
            "------------------------------------------------------------------",
            string.format("• Nivel Estimado: Nivel %d", caps.Capabilities.Level),
            string.format("• Puntaje de Capacidades: %d / 140", caps.Capabilities.Score),
            string.format("• Sistema de Archivos (writefile/readfile): %s", caps.Capabilities.HasFileSystem and "ACTIVO" or "INACTIVO"),
            string.format("• Metatable Hooks (__namecall/__index): %s", caps.Capabilities.HasMetatableHooks and "ACTIVO" or "INACTIVO"),
            string.format("• Decompilador C (decompile): %s", caps.Capabilities.HasDecompiler and "ACTIVO" or "INACTIVO"),
            string.format("• Inspección de Memoria GC (getgc): %s", caps.Capabilities.HasGCInspection and "ACTIVO" or "INACTIVO"),
            string.format("• Contenedor Seguro GUI (gethui/cloneref): %s", caps.Capabilities.HasSecureGUI and "ACTIVO" or "INACTIVO"),
            "==================================================================",
        }
        diagBox.Text = table.concat(lines, "\n")
    end
    
    local tools = self.Registry:Get("ExternalTools")
    dexBtn.MouseButton1Click:Connect(function()
        if tools then tools:LaunchDarkDex() end
    end)
    
    selectiveBtn.MouseButton1Click:Connect(function()
        if tools then tools:LaunchSelectiveDumper() end
    end)
    
    yieldBtn.MouseButton1Click:Connect(function()
        if tools then tools:LaunchInfiniteYield() end
    end)
end

function ToolsView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return ToolsView
