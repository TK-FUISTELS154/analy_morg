--[[
    =============================================================================
    APEX SUITE - ADVANCED DUMPER VIEW v4.0
    (VIRTUALIZED EXPLORER + THREAT HEATMAP + SURGICAL MANUAL EXTRACTION)
    =============================================================================
    Explorador interactivo de instancias virtualizado (60 FPS) potenciado con:
      - Resaltado visual de sospechas (Anti-Cheat, Economía, Remotes, Causal Trace)
      - Selección manual quirúrgica individual y por ramas
      - Filtros instantáneos: Todos, Solo Sospechosos, Solo Remotes, Solo Scripts
      - Inspector dinámico de propiedades, tags de CollectionService, atributos y código
      - Exportación multi-formato: JSON plano, Estructura a Disco (.lua) y VFS Archive
--]]

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local DumperView = {}
DumperView.__index = DumperView
DumperView.ClassName = "DumperView"

local ROW_HEIGHT = 22
local INDENT_SIZE = 14
local VISIBLE_ROWS = 24

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

function DumperView.new(parentFrame, registry)
    local self = setmetatable({}, DumperView)
    self.Parent = parentFrame
    self.Registry = registry
    self.ViewFrame = nil
    self.CurrentMode = "MANUAL_TREE" -- "MANUAL_TREE", "HEURISTIC_FINDINGS", "DEPENDENCY_CHAIN", "FULL_ENVIRONMENT"
    self.CurrentFilter = "ALL"       -- "ALL", "SUSPICIOUS", "REMOTES", "SCRIPTS"
    self.ActiveTab = "NodeInspector" -- "NodeInspector", "JSONOutput", "Stats"

    self.FlatTree = {}
    self.SelectedNodes = {}
    self.ExpandedNodes = {}
    self.UIRows = {}
    self.RootNodes = {}
    self.SearchResults = {}
    self.IsSearching = false
    self.SearchId = 0
    self.SelectedNodeForInspection = nil
    self.LastExtractedPackage = nil

    self:Render()
    return self
end

function DumperView:GetNodeThreatBadge(instance)
    if not instance then return nil end
    local heuristic = self.Registry:Get("HeuristicEngine")
    local remoteAnalyzer = self.Registry:Get("RemoteAnalyzer")
    local actionRecorder = self.Registry:Get("ActionRecorder")

    -- 1. Chequeo de Remotes
    if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent") then
        return { Text = "📡 REMOTE", Color = Color3.fromRGB(0, 180, 230), Type = "REMOTE" }
    end

    -- 2. Chequeo en Hallazgos Heurísticos
    if heuristic and heuristic.CrossReferenceMatrix then
        local instPath = instance:GetFullName()
        local callers = heuristic.CrossReferenceMatrix.RemotesToCallers
        if callers and callers[instance.Name] then
            return { Text = "🔗 CALLSITE", Color = Color3.fromRGB(240, 180, 40), Type = "CALLSITE" }
        end
    end

    -- 3. Chequeo de Nombres Sospechosos / Anti-Cheat
    local lowerName = instance.Name:lower()
    if lowerName:find("anticheat") or lowerName:find("security") or lowerName:find("integrity") or lowerName:find("watchdog") or lowerName:find("detection") or lowerName:find("kick") then
        return { Text = "🚨 AC / VULN", Color = Color3.fromRGB(240, 60, 60), Type = "SUSPICIOUS" }
    end
    if lowerName:find("spin") or lowerName:find("roll") or lowerName:find("gacha") or lowerName:find("shop") or lowerName:find("purchase") or lowerName:find("luck") or lowerName:find("chance") then
        return { Text = "🎰 ECON", Color = Color3.fromRGB(210, 140, 40), Type = "ECONOMY" }
    end

    -- 4. Chequeo de Acción de Usuario Correlacionada
    if actionRecorder and actionRecorder.RecentAction and actionRecorder.RecentAction.Instance == instance then
        return { Text = "🎯 TRACE", Color = Color3.fromRGB(80, 220, 120), Type = "TRACE" }
    end

    return nil
end

function DumperView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame

    -- =========================================================================
    -- 1. BARRA SUPERIOR DE MODOS DE EXTRACCIÓN
    -- =========================================================================
    local modeBar = Instance.new("Frame")
    modeBar.Size = UDim2.new(1, 0, 0, 30)
    modeBar.BackgroundTransparency = 1
    modeBar.Parent = frame

    local modes = {
        { Id = "MANUAL_TREE",        Label = "🌲 Árbol Manual Quirúrgico" },
        { Id = "HEURISTIC_FINDINGS", Label = "🎯 Hallazgos Heurísticos" },
        { Id = "DEPENDENCY_CHAIN",   Label = "🔗 Cadena de Dependencias" },
        { Id = "FULL_ENVIRONMENT",   Label = "🌐 Entorno Total Podado" },
    }
    local modeBtns = {}
    local modeWidth = 1 / #modes

    local function setMode(modeId)
        self.CurrentMode = modeId
        for id, btn in pairs(modeBtns) do
            if id == modeId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 150, 225)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
                btn.TextColor3 = Color3.fromRGB(160, 170, 190)
            end
        end
    end

    for i, m in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(modeWidth, -4, 1, 0)
        btn.Position = UDim2.new((i - 1) * modeWidth, 2, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
        btn.Text = m.Label
        btn.TextColor3 = Color3.fromRGB(160, 170, 190)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.Parent = modeBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        modeBtns[m.Id] = btn
        btn.MouseButton1Click:Connect(function() setMode(m.Id) end)
    end
    setMode("MANUAL_TREE")

    -- =========================================================================
    -- 2. CUERPO PRINCIPAL (PANEL IZQUIERDO: ÁRBOL VIRTUALIZADO / PANEL DERECHO: INSPECTOR)
    -- =========================================================================
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -36)
    body.Position = UDim2.new(0, 0, 0, 36)
    body.BackgroundTransparency = 1
    body.Parent = frame

    -- PANEL IZQUIERDO: Árbol de Instancias Virtualizado
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.48, -4, 1, 0)
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    leftPanel.Parent = body
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 6)

    -- Barra de búsqueda + Botón Lupa
    local searchRow = Instance.new("Frame")
    searchRow.Size = UDim2.new(1, -10, 0, 26)
    searchRow.Position = UDim2.new(0, 5, 0, 5)
    searchRow.BackgroundTransparency = 1
    searchRow.Parent = leftPanel

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -30, 1, 0)
    searchBox.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
    searchBox.TextColor3 = Color3.fromRGB(235, 240, 250)
    searchBox.PlaceholderText = "Filtrar por nombre o clase..."
    searchBox.Text = ""
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 11
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchRow
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)

    local searchBtn = Instance.new("TextButton")
    searchBtn.Size = UDim2.new(0, 26, 1, 0)
    searchBtn.Position = UDim2.new(1, -26, 0, 0)
    searchBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 100)
    searchBtn.Text = "🔍"
    searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBtn.Font = Enum.Font.Gotham
    searchBtn.TextSize = 11
    searchBtn.Parent = searchRow
    Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 5)

    -- Barra de Filtros Rápidos
    local filterBar = Instance.new("Frame")
    filterBar.Size = UDim2.new(1, -10, 0, 22)
    filterBar.Position = UDim2.new(0, 5, 0, 34)
    filterBar.BackgroundTransparency = 1
    filterBar.Parent = leftPanel

    local filterButtons = {}
    local filters = {
        { Id = "ALL",        Label = "Todos",         Width = 0.20 },
        { Id = "SUSPICIOUS", Label = "🚨 Sospechosos", Width = 0.32 },
        { Id = "REMOTES",    Label = "📡 Remotes",     Width = 0.24 },
        { Id = "SCRIPTS",    Label = "📜 Scripts",     Width = 0.24 },
    }

    local currentFilterX = 0
    for _, f in ipairs(filters) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(f.Width, -2, 1, 0)
        btn.Position = UDim2.new(currentFilterX, 1, 0, 0)
        btn.BackgroundColor3 = (f.Id == self.CurrentFilter) and Color3.fromRGB(0, 130, 200) or Color3.fromRGB(26, 30, 42)
        btn.Text = f.Label
        btn.TextColor3 = (f.Id == self.CurrentFilter) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 160, 180)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.Parent = filterBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        filterButtons[f.Id] = btn
        currentFilterX = currentFilterX + f.Width
    end

    -- Scrolling Frame del Árbol Virtualizado
    local treeScroll = Instance.new("ScrollingFrame")
    treeScroll.Size = UDim2.new(1, -10, 1, -120)
    treeScroll.Position = UDim2.new(0, 5, 0, 58)
    treeScroll.BackgroundTransparency = 1
    treeScroll.ScrollBarThickness = 4
    treeScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 95)
    treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    treeScroll.Parent = leftPanel

    -- Barra de Acción Rápida del Árbol (Seleccionar Sospechosos / Desmarcar)
    local treeActions = Instance.new("Frame")
    treeActions.Size = UDim2.new(1, -10, 0, 24)
    treeActions.Position = UDim2.new(0, 5, 1, -58)
    treeActions.BackgroundTransparency = 1
    treeActions.Parent = leftPanel

    local selectSuspiciousBtn = Instance.new("TextButton")
    selectSuspiciousBtn.Size = UDim2.new(0.60, -2, 1, 0)
    selectSuspiciousBtn.Position = UDim2.new(0, 0, 0, 0)
    selectSuspiciousBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 30)
    selectSuspiciousBtn.Text = "⚡ SELECCIONAR SOSPECHOSOS"
    selectSuspiciousBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectSuspiciousBtn.Font = Enum.Font.GothamBold
    selectSuspiciousBtn.TextSize = 9
    selectSuspiciousBtn.Parent = treeActions
    Instance.new("UICorner", selectSuspiciousBtn).CornerRadius = UDim.new(0, 4)

    local clearSelectionBtn = Instance.new("TextButton")
    clearSelectionBtn.Size = UDim2.new(0.40, -2, 1, 0)
    clearSelectionBtn.Position = UDim2.new(0.60, 2, 0, 0)
    clearSelectionBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    clearSelectionBtn.Text = "DESMARCAR TODO"
    clearSelectionBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
    clearSelectionBtn.Font = Enum.Font.GothamMedium
    clearSelectionBtn.TextSize = 9
    clearSelectionBtn.Parent = treeActions
    Instance.new("UICorner", clearSelectionBtn).CornerRadius = UDim.new(0, 4)

    -- Barra de Estado / Conteo de Selección
    local treeStatus = Instance.new("TextLabel")
    treeStatus.Size = UDim2.new(1, -10, 0, 24)
    treeStatus.Position = UDim2.new(0, 5, 1, -28)
    treeStatus.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
    treeStatus.Text = "Seleccionados: 0 nodos | Haz clic en [✓] para marcar"
    treeStatus.TextColor3 = Color3.fromRGB(150, 165, 185)
    treeStatus.Font = Enum.Font.GothamMedium
    treeStatus.TextSize = 9
    treeStatus.Parent = leftPanel
    Instance.new("UICorner", treeStatus).CornerRadius = UDim.new(0, 4)

    -- PANEL DERECHO: Inspector de Detalle + Opciones de Volcado
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.52, -4, 1, 0)
    rightPanel.Position = UDim2.new(0.48, 4, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
    rightPanel.Parent = body
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 6)

    -- Pestañas del Inspector Derecho
    local rightTabRow = Instance.new("Frame")
    rightTabRow.Size = UDim2.new(1, 0, 0, 26)
    rightTabRow.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    rightTabRow.Parent = rightPanel
    Instance.new("UICorner", rightTabRow).CornerRadius = UDim.new(0, 6)

    local rightTabs = {
        { Id = "NodeInspector", Label = "🕵️ Inspector de Nodo" },
        { Id = "JSONOutput",    Label = "📂 Salida JSON" },
        { Id = "Stats",         Label = "📊 Telemetría y Caché" },
    }
    local rightTabButtons = {}
    local rTabWidth = 1 / #rightTabs

    local inspectorBox = Instance.new("TextBox")
    inspectorBox.Size = UDim2.new(1, -12, 1, -96)
    inspectorBox.Position = UDim2.new(0, 6, 0, 30)
    inspectorBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    inspectorBox.TextColor3 = Color3.fromRGB(215, 225, 240)
    inspectorBox.Text = "-- Selecciona cualquier nodo en el árbol de la izquierda para inspeccionar sus propiedades, atributos, tags y código descompilado."
    inspectorBox.Font = Enum.Font.Code
    inspectorBox.TextSize = 10
    inspectorBox.TextXAlignment = Enum.TextXAlignment.Left
    inspectorBox.TextYAlignment = Enum.TextYAlignment.Top
    inspectorBox.ClearTextOnFocus = false
    inspectorBox.MultiLine = true
    inspectorBox.TextEditable = false
    inspectorBox.Parent = rightPanel
    Instance.new("UICorner", inspectorBox).CornerRadius = UDim.new(0, 6)

    -- Barra de Ejecución de Volcados en Panel Derecho
    local dumpActionRow = Instance.new("Frame")
    dumpActionRow.Size = UDim2.new(1, -12, 0, 28)
    dumpActionRow.Position = UDim2.new(0, 6, 1, -62)
    dumpActionRow.BackgroundTransparency = 1
    dumpActionRow.Parent = rightPanel

    local dumpJsonBtn = Instance.new("TextButton")
    dumpJsonBtn.Size = UDim2.new(0.33, -3, 1, 0)
    dumpJsonBtn.Position = UDim2.new(0, 0, 0, 0)
    dumpJsonBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 225)
    dumpJsonBtn.Text = "📂 EXTRAER JSON"
    dumpJsonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpJsonBtn.Font = Enum.Font.GothamBold
    dumpJsonBtn.TextSize = 9
    dumpJsonBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpJsonBtn).CornerRadius = UDim.new(0, 4)

    local dumpDiskBtn = Instance.new("TextButton")
    dumpDiskBtn.Size = UDim2.new(0.33, -3, 1, 0)
    dumpDiskBtn.Position = UDim2.new(0.33, 2, 0, 0)
    dumpDiskBtn.BackgroundColor3 = Color3.fromRGB(135, 55, 195)
    dumpDiskBtn.Text = "💾 DISCO (.LUA)"
    dumpDiskBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpDiskBtn.Font = Enum.Font.GothamBold
    dumpDiskBtn.TextSize = 9
    dumpDiskBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpDiskBtn).CornerRadius = UDim.new(0, 4)

    local dumpVfsBtn = Instance.new("TextButton")
    dumpVfsBtn.Size = UDim2.new(0.34, -3, 1, 0)
    dumpVfsBtn.Position = UDim2.new(0.66, 4, 0, 0)
    dumpVfsBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 85)
    dumpVfsBtn.Text = "📦 VFS ARCHIVE"
    dumpVfsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpVfsBtn.Font = Enum.Font.GothamBold
    dumpVfsBtn.TextSize = 9
    dumpVfsBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpVfsBtn).CornerRadius = UDim.new(0, 4)

    -- Barra de Utilidades Inferior (Copiar / Limpiar)
    local utilityRow = Instance.new("Frame")
    utilityRow.Size = UDim2.new(1, -12, 0, 26)
    utilityRow.Position = UDim2.new(0, 6, 1, -30)
    utilityRow.BackgroundTransparency = 1
    utilityRow.Parent = rightPanel

    local copyInspectorBtn = Instance.new("TextButton")
    copyInspectorBtn.Size = UDim2.new(0.5, -3, 1, 0)
    copyInspectorBtn.Position = UDim2.new(0, 0, 0, 0)
    copyInspectorBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 135)
    copyInspectorBtn.Text = "📋 COPIAR AL PORTAPAPELES"
    copyInspectorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyInspectorBtn.Font = Enum.Font.GothamBold
    copyInspectorBtn.TextSize = 9
    copyInspectorBtn.Parent = utilityRow
    Instance.new("UICorner", copyInspectorBtn).CornerRadius = UDim.new(0, 4)

    local saveToFileBtn = Instance.new("TextButton")
    saveToFileBtn.Size = UDim2.new(0.5, -3, 1, 0)
    saveToFileBtn.Position = UDim2.new(0.5, 3, 0, 0)
    saveToFileBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 75)
    saveToFileBtn.Text = "💾 GUARDAR VISTA ACTUAL"
    saveToFileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveToFileBtn.Font = Enum.Font.GothamBold
    saveToFileBtn.TextSize = 9
    saveToFileBtn.Parent = utilityRow
    Instance.new("UICorner", saveToFileBtn).CornerRadius = UDim.new(0, 4)

    -- =========================================================================
    -- LÓGICA DE VIRTUALIZACIÓN DEL ÁRBOL
    -- =========================================================================
    local function hasChildrenSafe(obj)
        local s, c = pcall(function() return obj:GetChildren() end)
        return (s and c and #c > 0)
    end

    local function getChildrenSafe(obj)
        local s, c = pcall(function() return obj:GetChildren() end)
        return (s and c and c) or {}
    end

    local function updateStatusLabel()
        local count = 0
        for _ in pairs(self.SelectedNodes) do count = count + 1 end
        treeStatus.Text = string.format("Seleccionados: %d nodos | Modo: %s", count, self.CurrentMode)
    end

    local function updateVisibleTree()
        local canvasY = treeScroll.CanvasPosition.Y
        local startIndex = math.max(1, math.floor(canvasY / ROW_HEIGHT) + 1)

        for i = 1, VISIBLE_ROWS do
            local rowDataIndex = startIndex + i - 1
            local data = self.FlatTree[rowDataIndex]
            local frameRow = self.UIRows[i]

            if data and frameRow then
                frameRow.Frame.Visible = true
                frameRow.Frame.Position = UDim2.new(0, 0, 0, (rowDataIndex - 1) * ROW_HEIGHT)

                local xOffset = data.depth * INDENT_SIZE
                frameRow.ExpandBtn.Position = UDim2.new(0, xOffset, 0, 3)
                frameRow.CheckBtn.Position = UDim2.new(0, xOffset + 18, 0, 3)

                local textX = xOffset + 38
                frameRow.NameLabel.Position = UDim2.new(0, textX, 0, 0)
                frameRow.NameLabel.Size = UDim2.new(1, -textX - (data.badge and 60 or 0), 1, 0)

                local displayName = self.IsSearching and data.obj:GetFullName() or data.obj.Name
                frameRow.NameLabel.Text = displayName

                if data.badge then
                    frameRow.BadgeLabel.Visible = true
                    frameRow.BadgeLabel.Text = data.badge.Text
                    frameRow.BadgeLabel.TextColor3 = data.badge.Color
                    frameRow.NameLabel.TextColor3 = (data.badge.Type == "SUSPICIOUS") and Color3.fromRGB(255, 120, 120)
                        or (data.badge.Type == "REMOTE") and Color3.fromRGB(130, 220, 255)
                        or (data.badge.Type == "ECONOMY") and Color3.fromRGB(255, 200, 120)
                        or Color3.fromRGB(220, 225, 235)
                else
                    frameRow.BadgeLabel.Visible = false
                    frameRow.NameLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
                end

                frameRow.ExpandBtn.Text = data.hasChildren and (data.isExpanded and "-" or "+") or ""
                frameRow.CheckBtn.Text = self.SelectedNodes[data.obj] and "✓" or ""
                frameRow.NodeObj = data.obj
            elseif frameRow then
                frameRow.Frame.Visible = false
            end
        end
    end

    local function isNodeMatchingFilter(obj)
        if self.CurrentFilter == "ALL" then return true end
        if self.CurrentFilter == "REMOTES" then
            return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent")
        elseif self.CurrentFilter == "SCRIPTS" then
            return obj:IsA("LuaSourceContainer")
        elseif self.CurrentFilter == "SUSPICIOUS" then
            local badge = self:GetNodeThreatBadge(obj)
            return badge ~= nil
        end
        return true
    end

    local function rebuildFlatTree()
        table.clear(self.FlatTree)

        if self.IsSearching then
            for _, obj in ipairs(self.SearchResults) do
                if isNodeMatchingFilter(obj) then
                    local badge = self:GetNodeThreatBadge(obj)
                    table.insert(self.FlatTree, {
                        obj = obj,
                        depth = 0,
                        hasChildren = false,
                        isExpanded = false,
                        badge = badge,
                    })
                end
            end
        else
            local function traverse(nodeList, depth)
                for _, obj in ipairs(nodeList) do
                    if obj.Name ~= "CorePackages" and obj.Name ~= "Terrain" then
                        local isExpanded = self.ExpandedNodes[obj] or false
                        local hasChild = hasChildrenSafe(obj)
                        local badge = self:GetNodeThreatBadge(obj)

                        if isNodeMatchingFilter(obj) or (hasChild and isExpanded) then
                            table.insert(self.FlatTree, {
                                obj = obj,
                                depth = depth,
                                hasChildren = hasChild,
                                isExpanded = isExpanded,
                                badge = badge,
                            })
                        end

                        if isExpanded and hasChild then
                            traverse(getChildrenSafe(obj), depth + 1)
                        end
                    end
                end
            end
            traverse(self.RootNodes, 0)
        end

        treeScroll.CanvasSize = UDim2.new(0, 1600, 0, #self.FlatTree * ROW_HEIGHT)
        task.defer(updateVisibleTree)
    end

    local function selectFilter(filterId)
        self.CurrentFilter = filterId
        for id, btn in pairs(filterButtons) do
            if id == filterId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
                btn.TextColor3 = Color3.fromRGB(150, 160, 180)
            end
        end
        rebuildFlatTree()
    end

    for fId, btn in pairs(filterButtons) do
        btn.MouseButton1Click:Connect(function() selectFilter(fId) end)
    end

    local function performSearch(query)
        query = query:lower()
        self.SearchId = self.SearchId + 1
        local currentSearchId = self.SearchId
        table.clear(self.SearchResults)

        if query == "" then
            self.IsSearching = false
            searchBtn.Text = "🔍"
            rebuildFlatTree()
            return
        end

        self.IsSearching = true
        searchBtn.Text = "..."

        task.spawn(function()
            local processed = 0
            local function checkNode(node)
                local sName, name = pcall(function() return node.Name:lower() end)
                local sClass, className = pcall(function() return node.ClassName:lower() end)
                if sName and sClass then
                    if string.find(name, query, 1, true) or string.find(className, query, 1, true) then
                        table.insert(self.SearchResults, node)
                    end
                end
            end

            for _, root in ipairs(self.RootNodes) do
                if self.SearchId ~= currentSearchId then return end
                checkNode(root)
                local s, descendants = pcall(function() return root:GetDescendants() end)
                if s and descendants then
                    for _, child in ipairs(descendants) do
                        if self.SearchId ~= currentSearchId then return end
                        processed = processed + 1
                        if processed % 3000 == 0 then task.wait() end
                        checkNode(child)
                    end
                end
            end

            if self.SearchId == currentSearchId then
                searchBtn.Text = "🔍"
                rebuildFlatTree()
            end
        end)
    end

    searchBtn.MouseButton1Click:Connect(function() performSearch(searchBox.Text) end)
    searchBox.FocusLost:Connect(function(enter) if enter then performSearch(searchBox.Text) end end)

    -- Creación de Filas UI Reutilizadas para Virtualización
    for i = 1, VISIBLE_ROWS do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
        row.BackgroundTransparency = 1
        row.Visible = false

        local expandBtn = Instance.new("TextButton")
        expandBtn.Size = UDim2.new(0, 16, 0, 16)
        expandBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
        expandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        expandBtn.Font = Enum.Font.Code
        expandBtn.TextSize = 12
        expandBtn.Parent = row
        Instance.new("UICorner", expandBtn).CornerRadius = UDim.new(0, 3)

        local checkBtn = Instance.new("TextButton")
        checkBtn.Size = UDim2.new(0, 16, 0, 16)
        checkBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
        checkBtn.TextColor3 = Color3.fromRGB(0, 230, 140)
        checkBtn.Font = Enum.Font.GothamBold
        checkBtn.TextSize = 10
        checkBtn.Parent = row
        Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 3)

        local nameLabel = Instance.new("TextButton")
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = ""
        nameLabel.Parent = row

        local badgeLabel = Instance.new("TextLabel")
        badgeLabel.Size = UDim2.new(0, 70, 0, 16)
        badgeLabel.Position = UDim2.new(1, -75, 0, 3)
        badgeLabel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        badgeLabel.Font = Enum.Font.GothamBold
        badgeLabel.TextSize = 9
        badgeLabel.Visible = false
        badgeLabel.Parent = row
        Instance.new("UICorner", badgeLabel).CornerRadius = UDim.new(0, 3)

        local frameData = {
            Frame = row,
            ExpandBtn = expandBtn,
            CheckBtn = checkBtn,
            NameLabel = nameLabel,
            BadgeLabel = badgeLabel,
            NodeObj = nil,
        }

        expandBtn.MouseButton1Click:Connect(function()
            local obj = frameData.NodeObj
            if obj and hasChildrenSafe(obj) then
                self.ExpandedNodes[obj] = not self.ExpandedNodes[obj]
                rebuildFlatTree()
            end
        end)

        checkBtn.MouseButton1Click:Connect(function()
            local obj = frameData.NodeObj
            if obj then
                if self.SelectedNodes[obj] then
                    self.SelectedNodes[obj] = nil
                else
                    self.SelectedNodes[obj] = true
                end
                updateVisibleTree()
                updateStatusLabel()
            end
        end)

        nameLabel.MouseButton1Click:Connect(function()
            local obj = frameData.NodeObj
            if obj then
                self:InspectNode(obj)
            end
        end)

        row.Parent = treeScroll
        table.insert(self.UIRows, frameData)
    end

    treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleTree)

    -- Botones de Selección Rápida de Sospechosos
    selectSuspiciousBtn.MouseButton1Click:Connect(function()
        local count = 0
        local function scanAndSelect(obj)
            local badge = self:GetNodeThreatBadge(obj)
            if badge then
                self.SelectedNodes[obj] = true
                count = count + 1
            end
            local s, d = pcall(function() return obj:GetDescendants() end)
            if s and d then
                for _, child in ipairs(d) do
                    local b = self:GetNodeThreatBadge(child)
                    if b then
                        self.SelectedNodes[child] = true
                        count = count + 1
                    end
                end
            end
        end
        for _, root in ipairs(self.RootNodes) do
            scanAndSelect(root)
        end
        updateVisibleTree()
        updateStatusLabel()
        treeStatus.Text = string.format("⚡ %d nodos sospechosos marcados automáticamente.", count)
    end)

    clearSelectionBtn.MouseButton1Click:Connect(function()
        table.clear(self.SelectedNodes)
        updateVisibleTree()
        updateStatusLabel()
    end)

    -- Raíces estándar de Roblox
    local commonServices = { "Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "RobloxReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer" }
    for _, sName in ipairs(commonServices) do
        pcall(function()
            local srv = game:GetService(sName)
            if srv then table.insert(self.RootNodes, srv) end
        end)
    end
    rebuildFlatTree()

    -- =========================================================================
    -- LÓGICA DEL INSPECTOR DE NODO DERECHO
    -- =========================================================================
    local function setInspectorText(text)
        local maxLimit = 75000
        local str = tostring(text or "")
        if #str > maxLimit then
            inspectorBox.Text = str:sub(1, maxLimit) .. string.format("\n\n-- [⚠️ Truncado a %d chars por límite de Roblox TextBox]\n-- [Total: %d chars]", maxLimit, #str)
        else
            inspectorBox.Text = str
        end
    end

    function self:InspectNode(instance)
        self.SelectedNodeForInspection = instance
        self:SelectRightTab("NodeInspector")

        local caps = self.Registry:Get("CapabilityManager")
        local lines = {}
        table.insert(lines, "=============================================================================")
        table.insert(lines, string.format("🕵️ INSPECCIÓN DETALLADA: %s (%s)", instance.Name, instance.ClassName))
        table.insert(lines, string.format("📍 Ruta Completa: %s", instance:GetFullName()))
        table.insert(lines, "=============================================================================")

        -- Tags de CollectionService
        pcall(function()
            local tags = CollectionService:GetTags(instance)
            if tags and #tags > 0 then
                table.insert(lines, string.format("🏷️ Tags: [%s]", table.concat(tags, ", ")))
            end
        end)

        -- Atributos
        pcall(function()
            local attrs = instance:GetAttributes()
            if attrs and next(attrs) then
                table.insert(lines, "📦 Atributos:")
                for k, v in pairs(attrs) do
                    table.insert(lines, string.format("   • %s = %s", tostring(k), tostring(v)))
                end
            end
        end)

        -- Propiedades según clase
        pcall(function()
            if instance:IsA("ValueBase") then
                table.insert(lines, string.format("💎 Valor (.Value): %s", tostring(instance.Value)))
            elseif instance:IsA("ProximityPrompt") then
                table.insert(lines, string.format("🔘 ActionText: %q | ObjectText: %q | Hold: %.2fs | Key: %s",
                    instance.ActionText, instance.ObjectText, instance.HoldDuration,
                    instance.KeyboardKeyCode and instance.KeyboardKeyCode.Name or "E"))
            elseif instance:IsA("ClickDetector") then
                table.insert(lines, string.format("🎯 MaxActivationDistance: %.1f", instance.MaxActivationDistance))
            elseif instance:IsA("Tool") then
                table.insert(lines, string.format("⚔️ RequiresHandle: %s | CanBeDropped: %s | ToolTip: %q",
                    tostring(instance.RequiresHandle), tostring(instance.CanBeDropped), instance.ToolTip or ""))
            end
        end)

        -- Código Descompilado
        if instance:IsA("LuaSourceContainer") then
            table.insert(lines, "\n-- =====================================================================")
            table.insert(lines, "-- 📜 CÓDIGO FUENTE / BYTECODE EXTRAÍDO:")
            table.insert(lines, "-- =====================================================================")
            local code = caps and caps:SafeDecompile(instance)
            table.insert(lines, code or "-- [Código no disponible]")
        end

        setInspectorText(table.concat(lines, "\n"))
    end

    function self:SelectRightTab(tabId)
        self.ActiveTab = tabId
        for id, btn in pairs(rightTabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
                btn.TextColor3 = Color3.fromRGB(150, 165, 185)
            end
        end

        if tabId == "JSONOutput" then
            if self.LastExtractedPackage then
                local s, json = pcall(function() return HttpService:JSONEncode(self.LastExtractedPackage) end)
                setInspectorText((s and json) or "-- Error al codificar JSON")
            else
                setInspectorText("-- No hay ningún paquete de volcado extraído aún. Presiona EXTRAER JSON abajo.")
            end
        elseif tabId == "Stats" then
            local caps = self.Registry:Get("CapabilityManager")
            local stats = caps and caps:GetCacheStats() or {}
            local statLines = {
                "=============================================================================",
                "📊 TELEMETRÍA Y RENDIMIENTO DEL CACHÉ COMPARTIDO",
                "=============================================================================",
                string.format("• Hits en Caché de Descompilación: %d", stats.Hits or 0),
                string.format("• Misses (Nuevas descompilaciones): %d", stats.Misses or 0),
                string.format("• Tasa de Acierto (Hit Rate): %s", stats.HitRate or "0%"),
                string.format("• Timeouts (>200ms protegidos): %d", stats.Timeouts or 0),
                string.format("• Errores / Scripts no accesibles: %d", stats.Errors or 0),
                string.format("• Entradas Activas en Caché: %d", stats.CacheSize or 0),
                "=============================================================================",
                string.format("• Resumen de Capacidades del Ejecutor:\n  %s", caps and caps:GetSummary() or "N/A"),
            }
            setInspectorText(table.concat(statLines, "\n"))
        end
    end

    for i, t in ipairs(rightTabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(rTabWidth, -2, 1, 0)
        btn.Position = UDim2.new((i - 1) * rTabWidth, 1, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        btn.Text = t.Label
        btn.TextColor3 = Color3.fromRGB(150, 165, 185)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.Parent = rightTabRow
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        rightTabButtons[t.Id] = btn
        btn.MouseButton1Click:Connect(function() self:SelectRightTab(t.Id) end)
    end
    self:SelectRightTab("NodeInspector")

    -- =========================================================================
    -- EJECUCIÓN DE VOLCADOS (JSON, DISCO .LUA, VFS ARCHIVE)
    -- =========================================================================
    local function executeDump(exportMode)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        local heuristic = self.Registry:Get("HeuristicEngine")
        local actionRecorder = self.Registry:Get("ActionRecorder")

        if not dumper or not exporter then return end

        dumpJsonBtn.Text = "⏳ VOLCANDO..."
        dumpDiskBtn.Text = "⏳ VOLCANDO..."
        dumpVfsBtn.Text = "⏳ VOLCANDO..."
        treeStatus.Text = "⏳ Procesando extracción en modo " .. self.CurrentMode .. "..."

        task.spawn(function()
            local startTime = tick()
            local package = nil

            local function onProgress(curr, total, name)
                local elapsed = tick() - startTime
                local speed = curr / math.max(elapsed, 0.001)
                local eta = speed > 0 and ((total - curr) / speed) or 0
                treeStatus.Text = string.format("⏳ [%d/%d] %s | ETA: ~%.1fs", curr, total, tostring(name or ""):sub(1, 20), eta)
            end

            if self.CurrentMode == "HEURISTIC_FINDINGS" then
                local audit = heuristic and heuristic:RunFullAudit(nil, onProgress)
                package = dumper:DumpHeuristicFindings(audit, onProgress)
            elseif self.CurrentMode == "DEPENDENCY_CHAIN" then
                package = dumper:DumpDependencyChain(actionRecorder and actionRecorder.RecentAction, onProgress)
            elseif self.CurrentMode == "FULL_ENVIRONMENT" then
                package = dumper:DumpFullEnvironment(onProgress)
            else
                -- MODO MANUAL_TREE: Extraer exactamente los nodos seleccionados por el usuario
                local queue = {}
                for obj, isSel in pairs(self.SelectedNodes) do
                    if isSel then table.insert(queue, obj) end
                end

                if #queue == 0 then
                    -- Si no seleccionó ninguno, usar raíces principales por defecto
                    queue = { game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") }
                end
                package = dumper:DumpManualNodes(queue, onProgress)
            end

            self.LastExtractedPackage = package
            local duration = tick() - startTime

            if exportMode == "vfs" then
                local s, path = exporter:ExportAsVFSArchive("Dump_" .. self.CurrentMode, package)
                if s then
                    treeStatus.Text = string.format("✅ VFS Archive guardado (%.2fs): %s", duration, tostring(path))
                else
                    treeStatus.Text = "❌ VFS Error: " .. tostring(path)
                end
                self:SelectRightTab("Stats")
            elseif exportMode == "disk" then
                local jsonStr = exporter:ToJSON(package)
                self:SelectRightTab("JSONOutput")
                setInspectorText(jsonStr)

                local s, res = exporter:ExportProjectTreeToDisk("Dump_" .. self.CurrentMode .. "_" .. math.floor(tick()), package)
                if s then
                    treeStatus.Text = string.format("✅ Árbol en disco reconstruido (%.2fs):\n%s", duration, tostring(res))
                else
                    treeStatus.Text = "Resultado: " .. tostring(res)
                end
            else
                local jsonStr = exporter:ToJSON(package)
                self:SelectRightTab("JSONOutput")
                setInspectorText(jsonStr)

                local s, path = exporter:SaveToFile("dump_" .. self.CurrentMode:lower() .. "_" .. math.floor(tick()) .. ".json", jsonStr)
                treeStatus.Text = string.format("✅ JSON guardado en %.2fs (%d KB) → %s", duration, math.floor(#jsonStr / 1024), tostring(path))
            end

            dumpJsonBtn.Text = "📂 EXTRAER JSON"
            dumpDiskBtn.Text = "💾 DISCO (.LUA)"
            dumpVfsBtn.Text = "📦 VFS ARCHIVE"
        end)
    end

    dumpJsonBtn.MouseButton1Click:Connect(function() executeDump("json") end)
    dumpDiskBtn.MouseButton1Click:Connect(function() executeDump("disk") end)
    dumpVfsBtn.MouseButton1Click:Connect(function() executeDump("vfs") end)

    copyInspectorBtn.MouseButton1Click:Connect(function()
        if safeSetClipboard(inspectorBox.Text) then
            copyInspectorBtn.Text = "✅ ¡COPIADO!"
            task.delay(1.5, function() copyInspectorBtn.Text = "📋 COPIAR AL PORTAPAPELES" end)
        end
    end)

    saveToFileBtn.MouseButton1Click:Connect(function()
        local exporter = self.Registry:Get("ReportExporter")
        if exporter then
            local fname = "apex_dump_" .. self.ActiveTab:lower() .. "_" .. tick() .. ".txt"
            local success = exporter:SaveToFile(fname, inspectorBox.Text)
            if success then
                saveToFileBtn.Text = "✅ ¡GUARDADO!"
                task.delay(1.5, function() saveToFileBtn.Text = "💾 GUARDAR VISTA ACTUAL" end)
            end
        end
    end)
end

function DumperView:SetVisible(visible)
    if self.ViewFrame then
        self.ViewFrame.Visible = visible
    end
end

return DumperView
