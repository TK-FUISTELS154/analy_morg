--[[
    =============================================================================
    APEX SUITE - MAIN WINDOW v5.0 (SHELL, SPLASH LOADER & TAB COORDINATOR)
    =============================================================================
    Ventana principal profesional:
      1. Splash Loader inicial al estilo DarkDex con barra de progreso y etapas.
      2. Redimensionable libremente con Grip Handle inferior derecho (700x450 a 1600x1000).
      3. Minimización en la Parte Superior Central (Top-Center Floating Pill).
      4. Diseño estético de élite con acentos glassmorphism y micro-interacciones.
--]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local MainWindow = {}
MainWindow.__index = MainWindow
MainWindow.ClassName = "MainWindow"

function MainWindow.new(screenGui, registry)
    local self = setmetatable({}, MainWindow)
    self.ScreenGui = screenGui
    self.Registry = registry
    self.Views = {}
    self.CurrentTab = "Audit"
    
    self:ShowSplashAndBuild()
    return self
end

-- =============================================================================
-- 1. PANTALLA DE CARGA INICIAL (DARKDEX-STYLE SPLASH LOADER)
-- =============================================================================
function MainWindow:ShowSplashAndBuild()
    local splashFrame = Instance.new("Frame")
    splashFrame.Name = "ApexSplashLoader"
    splashFrame.Size = UDim2.new(0, 420, 0, 210)
    splashFrame.Position = UDim2.new(0.5, -210, 0.5, -105)
    splashFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    splashFrame.BorderSizePixel = 0
    splashFrame.ZIndex = 500
    splashFrame.Parent = self.ScreenGui
    Instance.new("UICorner", splashFrame).CornerRadius = UDim.new(0, 12)

    local splashStroke = Instance.new("UIStroke")
    splashStroke.Color = Color3.fromRGB(0, 168, 255)
    splashStroke.Thickness = 1.8
    splashStroke.Parent = splashFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 32)
    titleLabel.Position = UDim2.new(0, 0, 0, 18)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🛡️ APEX SUITE PRO"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.ZIndex = 501
    titleLabel.Parent = splashFrame

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0, 18)
    subLabel.Position = UDim2.new(0, 0, 0, 48)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = "Advanced Reverse Engineering & Realtime Security Engine"
    subLabel.TextColor3 = Color3.fromRGB(130, 145, 175)
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.TextSize = 10
    subLabel.ZIndex = 501
    subLabel.Parent = splashFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 20)
    statusLabel.Position = UDim2.new(0, 20, 0, 95)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Iniciando subsistemas..."
    statusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
    statusLabel.Font = Enum.Font.Code
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 501
    statusLabel.Parent = splashFrame

    local percentLabel = Instance.new("TextLabel")
    percentLabel.Size = UDim2.new(0, 60, 0, 20)
    percentLabel.Position = UDim2.new(1, -80, 0, 95)
    percentLabel.BackgroundTransparency = 1
    percentLabel.Text = "0%"
    percentLabel.TextColor3 = Color3.fromRGB(200, 215, 235)
    percentLabel.Font = Enum.Font.GothamBold
    percentLabel.TextSize = 11
    percentLabel.TextXAlignment = Enum.TextXAlignment.Right
    percentLabel.ZIndex = 501
    percentLabel.Parent = splashFrame

    -- Barra de Progreso Contenedor
    local barContainer = Instance.new("Frame")
    barContainer.Size = UDim2.new(1, -40, 0, 10)
    barContainer.Position = UDim2.new(0, 20, 0, 122)
    barContainer.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
    barContainer.BorderSizePixel = 0
    barContainer.ZIndex = 501
    barContainer.Parent = splashFrame
    Instance.new("UICorner", barContainer).CornerRadius = UDim.new(1, 0)

    -- Barra de Progreso Relleno
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 175, 255)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 502
    barFill.Parent = barContainer
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

    local footerLabel = Instance.new("TextLabel")
    footerLabel.Size = UDim2.new(1, 0, 0, 18)
    footerLabel.Position = UDim2.new(0, 0, 1, -26)
    footerLabel.BackgroundTransparency = 1
    footerLabel.Text = "Adaptativo Niveles 3 - 8 | Sandbox Seguro"
    footerLabel.TextColor3 = Color3.fromRGB(80, 95, 120)
    footerLabel.Font = Enum.Font.Gotham
    footerLabel.TextSize = 9
    footerLabel.ZIndex = 501
    footerLabel.Parent = splashFrame

    -- Construir Ventana en paralelo oculta
    self:BuildWindow()
    if self.MainFrame then
        self.MainFrame.Visible = false
    end

    -- Secuencia de Carga y Telemetría
    task.spawn(function()
        local steps = {
            { P = 0.20, Text = "[1/5] Inicializando Security Core & Hooks de Red..." },
            { P = 0.45, Text = "[2/5] Calibrando CapabilityManager & MemoryGuard..." },
            { P = 0.70, Text = "[3/5] Indexando Heurística, Remotes & Físicas..." },
            { P = 0.90, Text = "[4/5] Construyendo VirtualTree & Dumper Engine..." },
            { P = 1.00, Text = "[5/5] ¡Suite Lista! Cargando Interfaz..." },
        }

        for _, step in ipairs(steps) do
            statusLabel.Text = step.Text
            percentLabel.Text = math.floor(step.P * 100) .. "%"
            TweenService:Create(barFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(step.P, 0, 1, 0)
            }):Play()
            task.wait(0.22)
        end

        task.wait(0.2)
        
        -- Transición de Revelación
        TweenService:Create(splashFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -210, 0.45, -105)
        }):Play()

        for _, desc in ipairs(splashFrame:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("Frame") or desc:IsA("UIStroke") then
                pcall(function()
                    TweenService:Create(desc, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                        Transparency = 1
                    }):Play()
                end)
            end
        end

        task.wait(0.3)
        splashFrame:Destroy()

        if self.MainFrame then
            self.MainFrame.Visible = true
            self.MainFrame.Size = UDim2.new(0, 880, 0, 580)
            self.MainFrame.Position = UDim2.new(0.5, -440, 0.5, -290)
        end
    end)
end

-- =============================================================================
-- 2. CONSTRUCCIÓN DE VENTANA PRINCIPAL (REDIMENSIONABLE Y MINIMIZABLE)
-- =============================================================================
function MainWindow:BuildWindow()
    -- Contenedor Principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 880, 0, 580)
    mainFrame.Position = UDim2.new(0.5, -440, 0.5, -290)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.ClipsDescendants = false
    mainFrame.Parent = self.ScreenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(38, 44, 60)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame
    
    -- Barra de Título Arrastrable
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundColor3 = Color3.fromRGB(22, 25, 36)
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -130, 1, 0)
    titleText.Position = UDim2.new(0, 14, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🛡️ APEX AUDIT & REVERSE ENGINE PRO  v5.0"
    titleText.TextColor3 = Color3.fromRGB(240, 245, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 13
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Botones de Control (Cerrar / Minimizar)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -66, 0, 8)
    minBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.Parent = titleBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

    -- =========================================================================
    -- WIDGET FLOTANTE AL MINIMIZAR (PARTE SUPERIOR CENTRAL - TOP CENTER PILL)
    -- =========================================================================
    local floatPill = Instance.new("TextButton")
    floatPill.Name = "ApexTopCenterPill"
    floatPill.Size = UDim2.new(0, 210, 0, 32)
    floatPill.Position = UDim2.new(0.5, -105, 0, 10) -- Parte Superior Central
    floatPill.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    floatPill.Text = "🛡️ APEX SUITE [ABRIR]"
    floatPill.TextColor3 = Color3.fromRGB(0, 215, 255)
    floatPill.Font = Enum.Font.GothamBold
    floatPill.TextSize = 11
    floatPill.Visible = false
    floatPill.Active = true
    floatPill.Draggable = true
    floatPill.ZIndex = 300
    floatPill.Parent = self.ScreenGui
    Instance.new("UICorner", floatPill).CornerRadius = UDim.new(1, 0)

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Color = Color3.fromRGB(0, 168, 255)
    pillStroke.Thickness = 1.4
    pillStroke.Parent = floatPill
    
    minBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        floatPill.Visible = true
        floatPill.Position = UDim2.new(0.5, -105, 0, 10)
    end)
    
    floatPill.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        floatPill.Visible = false
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        self.ScreenGui:Destroy()
    end)
    
    -- Barra de Pestañas (Tabs)
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 34)
    tabBar.Position = UDim2.new(0, 10, 0, 48)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame
    
    -- Contenedor de Vistas
    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -20, 1, -94)
    contentArea.Position = UDim2.new(0, 10, 0, 86)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- =========================================================================
    -- GRIP HANDLE DE REDIMENSIONAMIENTO (BOTTOM-RIGHT RESIZE GRIP)
    -- =========================================================================
    local resizeGrip = Instance.new("TextButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.Size = UDim2.new(0, 18, 0, 18)
    resizeGrip.Position = UDim2.new(1, -18, 1, -18)
    resizeGrip.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    resizeGrip.BackgroundTransparency = 0.5
    resizeGrip.Text = "◢"
    resizeGrip.TextColor3 = Color3.fromRGB(0, 180, 255)
    resizeGrip.Font = Enum.Font.GothamBold
    resizeGrip.TextSize = 11
    resizeGrip.ZIndex = 120
    resizeGrip.Parent = mainFrame
    Instance.new("UICorner", resizeGrip).CornerRadius = UDim.new(0, 4)

    local isResizing = false
    local resizeStartMouse = Vector2.zero
    local resizeStartSize = Vector2.zero

    resizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = true
            resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
            resizeStartSize = Vector2.new(mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local currentMouse = Vector2.new(input.Position.X, input.Position.Y)
            local delta = currentMouse - resizeStartMouse
            
            local newWidth = math.clamp(resizeStartSize.X + delta.X, 700, 1600)
            local newHeight = math.clamp(resizeStartSize.Y + delta.Y, 450, 1000)
            
            mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = false
        end
    end)
    
    self.ContentArea = contentArea
    self.TabBar = tabBar
    self.MainFrame = mainFrame
    
    self:SetupTabs()
end

function MainWindow:SetupTabs()
    local tabs = {
        { Id = "Audit",     Label = "🛡️ Auditoría & Físicas" },
        { Id = "Dumper",    Label = "📂 Dumper & Árbol" },
        { Id = "RemoteSpy", Label = "📡 Remote Spy" },
        { Id = "Economy",   Label = "🎰 Economía" },
        { Id = "Tools",     Label = "⚙️ Herramientas" },
    }
    
    local tabWidth = 1 / #tabs
    local tabButtons = {}
    
    local function switchTab(tabId)
        self.CurrentTab = tabId
        for id, btn in pairs(tabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 155, 235)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
                btn.TextColor3 = Color3.fromRGB(150, 160, 180)
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
        btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
        btn.Text = tab.Label
        btn.TextColor3 = Color3.fromRGB(150, 160, 180)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.Parent = self.TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        tabButtons[tab.Id] = btn
        btn.MouseButton1Click:Connect(function()
            switchTab(tab.Id)
        end)
    end
    
    -- Cargar Vistas con Importador Resiliente
    local import = getgenv()._APEX_IMPORT or function(p)
        local s = (typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("suite/" .. p) and readfile("suite/" .. p))
            or (pcall(function() return game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/" .. p) end) and game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/" .. p))
        return s and loadstring(s)()
    end
    
    local AuditView     = import("gui/views/AuditView.lua")
    local DumperView    = import("gui/views/DumperView.lua")
    local RemoteSpyView = import("gui/views/RemoteSpyView.lua")
    local EconomyView   = import("gui/views/EconomyView.lua")
    local ToolsView     = import("gui/views/ToolsView.lua")
    
    if AuditView then self.Views["Audit"] = AuditView.new(self.ContentArea, self.Registry) end
    if DumperView then self.Views["Dumper"] = DumperView.new(self.ContentArea, self.Registry) end
    if RemoteSpyView then self.Views["RemoteSpy"] = RemoteSpyView.new(self.ContentArea, self.Registry) end
    if EconomyView then self.Views["Economy"] = EconomyView.new(self.ContentArea, self.Registry) end
    if ToolsView then self.Views["Tools"] = ToolsView.new(self.ContentArea, self.Registry) end
    
    switchTab("Audit")
end

return MainWindow
