--[[
    =============================================================================
    APEX SUITE - MAIN WINDOW (GUI SHELL & TAB COORDINATOR)
    =============================================================================
    Ventana principal modular, arrastrable, minimizable y con cambio fluido de pestañas.
--]]

local MainWindow = {}
MainWindow.__index = MainWindow
MainWindow.ClassName = "MainWindow"

function MainWindow.new(screenGui, registry)
    local self = setmetatable({}, MainWindow)
    self.ScreenGui = screenGui
    self.Registry = registry
    self.Views = {}
    self.CurrentTab = "Audit"
    
    self:BuildWindow()
    return self
end

function MainWindow:BuildWindow()
    -- Contenedor Principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 860, 0, 560)
    mainFrame.Position = UDim2.new(0.5, -430, 0.5, -280)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = self.ScreenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 50, 65)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame
    
    -- Barra de Título
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -120, 1, 0)
    titleText.Position = UDim2.new(0, 14, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🛡️ APEX AUDIT & REVERSE ENGINE PRO"
    titleText.TextColor3 = Color3.fromRGB(240, 245, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 13
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Botones de Control (Cerrar / Minimizar)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -70, 0, 8)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.Parent = titleBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
    
    -- Widget Flotante al minimizar
    local floatWidget = Instance.new("TextButton")
    floatWidget.Size = UDim2.new(0, 48, 0, 48)
    floatWidget.Position = UDim2.new(0.02, 0, 0.45, 0)
    floatWidget.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
    floatWidget.Text = "🛡️"
    floatWidget.TextSize = 22
    floatWidget.Visible = false
    floatWidget.Active = true
    floatWidget.Draggable = true
    floatWidget.Parent = self.ScreenGui
    Instance.new("UICorner", floatWidget).CornerRadius = UDim.new(1, 0)
    
    minBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        floatWidget.Visible = true
    end)
    
    floatWidget.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        floatWidget.Visible = false
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        self.ScreenGui:Destroy()
    end)
    
    -- Barra de Pestañas (Tabs)
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 36)
    tabBar.Position = UDim2.new(0, 10, 0, 52)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame
    
    -- Contenedor de Vistas
    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -20, 1, -102)
    contentArea.Position = UDim2.new(0, 10, 0, 94)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame
    
    self.ContentArea = contentArea
    self.TabBar = tabBar
    self.MainFrame = mainFrame
    
    self:SetupTabs()
end

function MainWindow:SetupTabs()
    local tabs = {
        { Id = "Audit", Label = "🛡️ Auditoría" },
        { Id = "Dumper", Label = "📂 Dumper" },
        { Id = "RemoteSpy", Label = "📡 Remote Spy" },
        { Id = "Economy", Label = "🎰 Economía" },
        { Id = "Tools", Label = "⚙️ Herramientas" },
    }
    
    local tabWidth = 1 / #tabs
    local tabButtons = {}
    
    local function switchTab(tabId)
        self.CurrentTab = tabId
        for id, btn in pairs(tabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 160, 230)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
                btn.TextColor3 = Color3.fromRGB(160, 168, 185)
            end
        end
        
        for id, view in pairs(self.Views) do
            if view and type(view.SetVisible) == "function" then
                view:SetVisible(id == tabId)
            end
        end
    end
    
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(tabWidth, -6, 1, 0)
        btn.Position = UDim2.new((i - 1) * tabWidth, 3, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
        btn.Text = tab.Label
        btn.TextColor3 = Color3.fromRGB(160, 168, 185)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.Parent = self.TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        tabButtons[tab.Id] = btn
        btn.MouseButton1Click:Connect(function()
            switchTab(tab.Id)
        end)
    end
    
    -- Cargar Vistas
    local AuditView = loadstring(readfile and isfile and isfile("suite/gui/views/AuditView.lua") and readfile("suite/gui/views/AuditView.lua") or "")()
    local DumperView = loadstring(readfile and isfile and isfile("suite/gui/views/DumperView.lua") and readfile("suite/gui/views/DumperView.lua") or "")()
    local RemoteSpyView = loadstring(readfile and isfile and isfile("suite/gui/views/RemoteSpyView.lua") and readfile("suite/gui/views/RemoteSpyView.lua") or "")()
    local EconomyView = loadstring(readfile and isfile and isfile("suite/gui/views/EconomyView.lua") and readfile("suite/gui/views/EconomyView.lua") or "")()
    local ToolsView = loadstring(readfile and isfile and isfile("suite/gui/views/ToolsView.lua") and readfile("suite/gui/views/ToolsView.lua") or "")()
    
    if AuditView then self.Views["Audit"] = AuditView.new(self.ContentArea, self.Registry) end
    if DumperView then self.Views["Dumper"] = DumperView.new(self.ContentArea, self.Registry) end
    if RemoteSpyView then self.Views["RemoteSpy"] = RemoteSpyView.new(self.ContentArea, self.Registry) end
    if EconomyView then self.Views["Economy"] = EconomyView.new(self.ContentArea, self.Registry) end
    if ToolsView then self.Views["Tools"] = ToolsView.new(self.ContentArea, self.Registry) end
    
    switchTab("Audit")
end

return MainWindow
