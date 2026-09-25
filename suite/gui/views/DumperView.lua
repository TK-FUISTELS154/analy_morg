--[[
    =============================================================================
    APEX SUITE - ADVANCED DUMPER & INSTANCE MANIPULATOR VIEW v5.0
    (HEATMAP THREAT MATRIX + CLONE/DESTROY/RESTORE PIPELINE + IMPORT SCRIPT GEN)
    =============================================================================
    Explorador de instancias de alto rendimiento (60 FPS) con:
      1. Matriz de Calor Unificada (Heatmap): Cruza Anti-Cheat, Economía, Físicas,
         Remotes y Trazas de Usuario, propagando alertas a carpetas contenedoras.
      2. Manipulador de Instancias Quirúrgico: Clonar, Eliminar, Copiar Código,
         Copiar Ruta (GetFullName / WaitForChild), Copiar Tabla Lua.
      3. Registro de Modificaciones y Reimportación Automática: Registra cualquier
         objeto eliminado o duplicado y genera un script autónomo de restauración.
      4. Filtros Instantáneos y Selección Guiada por Alertas Heurísticas.
--]]

local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
    self.CurrentFilter = "ALL"       -- "ALL", "SUSPICIOUS", "REMOTES", "SCRIPTS", "PHYSICS", "MODIFIED"
    self.ActiveTab = "NodeInspector" -- "NodeInspector", "JSONOutput", "ModHistory", "Stats"

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
    self.IsPickerActive = false
    self.PickerConnection = nil

    -- Registro de Modificaciones (Snapshots de Clonaciones y Eliminaciones)
    self.ModificationHistory = {}
    self.ThreatHeatmap = {}         -- [instance] = { Text, Color, Type, Reason }
    self.ContainerAlertCounts = {}  -- [containerInstance] = count

    self:BuildThreatHeatmap()
    self:Render()
    return self
end

-- =============================================================================
-- 1. CONSTRUCCIÓN Y PROPAGACIÓN DE LA MATRIZ DE CALOR (HEATMAP AGGREGATOR)
-- =============================================================================

function DumperView:BuildThreatHeatmap()
    table.clear(self.ThreatHeatmap)
    table.clear(self.ContainerAlertCounts)

    local heuristic = self.Registry:Get("HeuristicEngine")
    local physics = self.Registry:Get("PhysicsAuditor")
    local remoteAnalyzer = self.Registry:Get("RemoteAnalyzer")
    local actionRecorder = self.Registry:Get("ActionRecorder")

    local function registerThreat(inst, badgeText, color, threatType, reason)
        if not inst then return end
        self.ThreatHeatmap[inst] = {
            Text = badgeText,
            Color = color,
            Type = threatType,
            Reason = reason or badgeText,
        }

        -- Propagar alerta hacia los contenedores ancestros
        local parent = inst.Parent
        while parent and parent ~= game do
            self.ContainerAlertCounts[parent] = (self.ContainerAlertCounts[parent] or 0) + 1
            parent = parent.Parent
        end
    end

    -- 1. Hallazgos Heurísticos (Anti-Cheat, Economía, Combate, Admin)
    if heuristic and heuristic.LastFullAudit then
        local audit = heuristic.LastFullAudit
        for _, item in ipairs(audit.AntiCheat or {}) do
            registerThreat(item.Instance, "🚨 ANTI-CHEAT", Color3.fromRGB(255, 75, 75), "SUSPICIOUS", "Detección de Anti-Cheat / Kick / Watchdog")
        end
        for _, item in ipairs(audit.Economy or {}) do
            registerThreat(item.Instance, "🎰 ECONOMÍA", Color3.fromRGB(245, 170, 45), "ECONOMY", "Lógica de Tienda / Gacha / Manipulación de Probabilidades")
        end
        for _, item in ipairs(audit.Combat or {}) do
            registerThreat(item.Instance, "⚔️ COMBATE", Color3.fromRGB(230, 90, 160), "COMBAT", "Mecánica de Daño / Hitbox / Combate")
        end
        for _, item in ipairs(audit.AdminTools or {}) do
            registerThreat(item.Instance, "👑 ADMIN", Color3.fromRGB(175, 95, 240), "ADMIN", "Herramienta de Administración / Depuración")
        end
        for _, item in ipairs(audit.Remotes or {}) do
            registerThreat(item.Instance, "📡 REMOTE", Color3.fromRGB(0, 195, 245), "REMOTE", "Punto de Red Replicado")
        end

        -- Emisores de llamadas de red (Cross-Reference Matrix)
        if audit.CrossReferenceMatrix and audit.CrossReferenceMatrix.ScriptsToRemotes then
            for path, _ in pairs(audit.CrossReferenceMatrix.ScriptsToRemotes) do
                pcall(function()
                    local segments = string.split(path, ".")
                    local curr = game
                    for i = 1, #segments do
                        curr = curr and curr:FindFirstChild(segments[i])
                    end
                    if curr and not self.ThreatHeatmap[curr] then
                        registerThreat(curr, "🔗 CALLSITE", Color3.fromRGB(240, 200, 50), "CALLSITE", "Script emisor de llamadas a Remotes")
                    end
                end)
            end
        end
    end

    -- 2. Hallazgos de Físicas y Watchdogs
    if physics and physics.AuditPhysicsRemotes then
        local pRemotes = physics:AuditPhysicsRemotes()
        for _, rInfo in ipairs(pRemotes) do
            if rInfo.Remote and not self.ThreatHeatmap[rInfo.Remote] then
                registerThreat(rInfo.Remote, "🏃 FÍSICA", Color3.fromRGB(70, 220, 150), "PHYSICS", "Remote de Sincronización de Coordenadas/Física")
            end
        end
    end

    -- 3. Trazabilidad Causal de Usuario
    if actionRecorder and actionRecorder.RecordedTimeline then
        for _, act in ipairs(actionRecorder.RecordedTimeline) do
            if act.Instance and not self.ThreatHeatmap[act.Instance] then
                registerThreat(act.Instance, "🎯 TRACE", Color3.fromRGB(60, 230, 140), "TRACE", "Elemento detonador de acción de usuario")
            end
        end
    end
end

function DumperView:GetNodeThreatBadge(instance)
    if not instance then return nil end

    -- 1. Alerta Directa
    local direct = self.ThreatHeatmap[instance]
    if direct then return direct end

    -- 2. Alerta de Remotes Nativos
    if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent") then
        return { Text = "📡 REMOTE", Color = Color3.fromRGB(0, 195, 245), Type = "REMOTE" }
    end

    -- 3. Alerta Heredada / Contenedor con Sospechas Internas
    local alertCount = self.ContainerAlertCounts[instance]
    if alertCount and alertCount > 0 then
        return {
            Text = string.format("🚨 [%d ALERTAS]", alertCount),
            Color = Color3.fromRGB(255, 140, 50),
            Type = "CONTAINER_ALERT",
            Count = alertCount,
        }
    end

    return nil
end

-- =============================================================================
-- 2. SERIALIZACIÓN Y GENERADOR DE CÓDIGO DE REIMPORTACIÓN / RESTAURACIÓN
-- =============================================================================

function DumperView:GenerateLuaCreationSnippet(instance)
    if not instance then return "-- [Instancia inválida]" end

    local lines = {}
    table.insert(lines, string.format("local obj = Instance.new(%q)", instance.ClassName))
    table.insert(lines, string.format("obj.Name = %q", instance.Name))

    pcall(function()
        if instance:IsA("ValueBase") then
            local v = instance.Value
            if type(v) == "string" then
                table.insert(lines, string.format("obj.Value = %q", v))
            else
                table.insert(lines, string.format("obj.Value = %s", tostring(v)))
            end
        elseif instance:IsA("ProximityPrompt") then
            table.insert(lines, string.format("obj.ActionText = %q", instance.ActionText))
            table.insert(lines, string.format("obj.ObjectText = %q", instance.ObjectText))
            table.insert(lines, string.format("obj.HoldDuration = %s", tostring(instance.HoldDuration)))
            table.insert(lines, string.format("obj.MaxActivationDistance = %s", tostring(instance.MaxActivationDistance)))
        elseif instance:IsA("ClickDetector") then
            table.insert(lines, string.format("obj.MaxActivationDistance = %s", tostring(instance.MaxActivationDistance)))
        elseif instance:IsA("Tool") then
            table.insert(lines, string.format("obj.RequiresHandle = %s", tostring(instance.RequiresHandle)))
            table.insert(lines, string.format("obj.CanBeDropped = %s", tostring(instance.CanBeDropped)))
            table.insert(lines, string.format("obj.ToolTip = %q", instance.ToolTip or ""))
        end
    end)

    -- Atributos
    pcall(function()
        local attrs = instance:GetAttributes()
        for k, v in pairs(attrs) do
            if type(v) == "string" then
                table.insert(lines, string.format("obj:SetAttribute(%q, %q)", tostring(k), v))
            else
                table.insert(lines, string.format("obj:SetAttribute(%q, %s)", tostring(k), tostring(v)))
            end
        end
    end)

    -- Tags de CollectionService
    pcall(function()
        local tags = CollectionService:GetTags(instance)
        for _, tag in ipairs(tags) do
            table.insert(lines, string.format("game:GetService('CollectionService'):AddTag(obj, %q)", tag))
        end
    end)

    local parentPath = instance.Parent and instance.Parent:GetFullName() or "Workspace"
    table.insert(lines, string.format("obj.Parent = %s", parentPath))

    return table.concat(lines, "\n")
end

function DumperView:GenerateImportablePatchScript()
    local lines = {}
    table.insert(lines, [=[--[[
    =============================================================================
    APEX SUITE - STANDALONE IMPORTABLE PATCH & REVERSION SCRIPT
    =============================================================================
    Script autónomo generado automáticamente a partir del historial de
    modificaciones (clonaciones, eliminaciones y parches) del Dumper.
--]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
]=])

    if #self.ModificationHistory == 0 then
        table.insert(lines, "-- No hay modificaciones registradas en esta sesión.")
        return table.concat(lines, "\n")
    end

    for idx, mod in ipairs(self.ModificationHistory) do
        table.insert(lines, string.format("\n-- ====================================================================="))
        table.insert(lines, string.format("-- [%d] %s: %s (%s)", idx, mod.Action, mod.Name, mod.ClassName))
        table.insert(lines, string.format("-- Ruta Original: %s", mod.Path))
        table.insert(lines, string.format("-- ====================================================================="))

        if mod.Action == "DESTROY" then
            table.insert(lines, "-- Restauración de objeto eliminado:")
            table.insert(lines, mod.CreationSnippet or "-- [Snippet no disponible]")
            if mod.SourceCode and #mod.SourceCode > 0 and not mod.SourceCode:find("%[Código no disponible") then
                table.insert(lines, string.format("\n-- Código fuente del script restaurado:"))
                table.insert(lines, string.format("local restoredSource = %q", mod.SourceCode))
                table.insert(lines, "pcall(function() obj.Source = restoredSource end)")
            end
        elseif mod.Action == "CLONE" then
            table.insert(lines, string.format("-- Objeto duplicado creado: %s en %s", mod.CloneName or mod.Name, mod.ParentPath or "Workspace"))
            table.insert(lines, mod.CreationSnippet or "-- [Snippet no disponible]")
        end
    end

    table.insert(lines, "\nprint('[APEX] Parche de importación y restauración aplicado con éxito.')")
    return table.concat(lines, "\n")
end

-- =============================================================================
-- 3. RENDERIZADO DE LA INTERFAZ
-- =============================================================================

function DumperView:Render()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = self.Parent
    self.ViewFrame = frame

    -- BARRA SUPERIOR DE MODOS DE EXTRACCIÓN
    local modeBar = Instance.new("Frame")
    modeBar.Size = UDim2.new(1, 0, 0, 30)
    modeBar.BackgroundTransparency = 1
    modeBar.Parent = frame

    local modes = {
        { Id = "MANUAL_TREE",          Label = "🌲 Árbol Manual" },
        { Id = "RUNTIME_INTERACTIONS", Label = "🎯 Interacciones en Vivo" },
        { Id = "HEURISTIC_FINDINGS",   Label = "🛡️ Hallazgos Heurísticos" },
        { Id = "DEPENDENCY_CHAIN",     Label = "🔗 Dependencias" },
        { Id = "FULL_ENVIRONMENT",     Label = "🌐 Entorno Total" },
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

    -- CUERPO PRINCIPAL DIVIDIDO
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -36)
    body.Position = UDim2.new(0, 0, 0, 36)
    body.BackgroundTransparency = 1
    body.Parent = frame

    -- PANEL IZQUIERDO: ÁRBOL VIRTUALIZADO Y FILTROS
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.48, -4, 1, 0)
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    leftPanel.Parent = body
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 6)

    -- Barra de Búsqueda, Picker 2D/3D y Botón Refrescar Heatmap
    local searchRow = Instance.new("Frame")
    searchRow.Size = UDim2.new(1, -10, 0, 26)
    searchRow.Position = UDim2.new(0, 5, 0, 5)
    searchRow.BackgroundTransparency = 1
    searchRow.Parent = leftPanel

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -122, 1, 0)
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
    searchBtn.Size = UDim2.new(0, 24, 1, 0)
    searchBtn.Position = UDim2.new(1, -118, 0, 0)
    searchBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 100)
    searchBtn.Text = "🔍"
    searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBtn.Font = Enum.Font.Gotham
    searchBtn.TextSize = 11
    searchBtn.Parent = searchRow
    Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 5)

    local pickerBtn = Instance.new("TextButton")
    pickerBtn.Size = UDim2.new(0, 64, 1, 0)
    pickerBtn.Position = UDim2.new(1, -90, 0, 0)
    pickerBtn.BackgroundColor3 = Color3.fromRGB(30, 95, 155)
    pickerBtn.Text = "🎯 PICKER"
    pickerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pickerBtn.Font = Enum.Font.GothamBold
    pickerBtn.TextSize = 9
    pickerBtn.Parent = searchRow
    Instance.new("UICorner", pickerBtn).CornerRadius = UDim.new(0, 5)

    local refreshHeatmapBtn = Instance.new("TextButton")
    refreshHeatmapBtn.Size = UDim2.new(0, 24, 1, 0)
    refreshHeatmapBtn.Position = UDim2.new(1, -24, 0, 0)
    refreshHeatmapBtn.BackgroundColor3 = Color3.fromRGB(160, 70, 30)
    refreshHeatmapBtn.Text = "🔥"
    refreshHeatmapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshHeatmapBtn.Font = Enum.Font.Gotham
    refreshHeatmapBtn.TextSize = 11
    refreshHeatmapBtn.Parent = searchRow
    Instance.new("UICorner", refreshHeatmapBtn).CornerRadius = UDim.new(0, 5)

    -- Barra de Filtros Rápidos
    local filterBar = Instance.new("Frame")
    filterBar.Size = UDim2.new(1, -10, 0, 22)
    filterBar.Position = UDim2.new(0, 5, 0, 34)
    filterBar.BackgroundTransparency = 1
    filterBar.Parent = leftPanel

    local filterButtons = {}
    local filters = {
        { Id = "ALL",        Label = "Todos",         Width = 0.18 },
        { Id = "SUSPICIOUS", Label = "🚨 Sospechosos", Width = 0.28 },
        { Id = "REMOTES",    Label = "📡 Remotes",     Width = 0.20 },
        { Id = "SCRIPTS",    Label = "📜 Scripts",     Width = 0.18 },
        { Id = "PHYSICS",    Label = "🏃 Físicas",     Width = 0.16 },
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

    -- Barra de Acción Rápida del Árbol
    local treeActions = Instance.new("Frame")
    treeActions.Size = UDim2.new(1, -10, 0, 24)
    treeActions.Position = UDim2.new(0, 5, 1, -58)
    treeActions.BackgroundTransparency = 1
    treeActions.Parent = leftPanel

    local selectSuspiciousBtn = Instance.new("TextButton")
    selectSuspiciousBtn.Size = UDim2.new(0.60, -2, 1, 0)
    selectSuspiciousBtn.Position = UDim2.new(0, 0, 0, 0)
    selectSuspiciousBtn.BackgroundColor3 = Color3.fromRGB(190, 65, 30)
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

    -- Estado del Árbol
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

    -- PANEL DERECHO: INSPECTOR, ACCIONES QUIRÚRGICAS Y EXPORTACIÓN
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.52, -4, 1, 0)
    rightPanel.Position = UDim2.new(0.48, 4, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
    rightPanel.Parent = body
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 6)

    -- Pestañas del Inspector
    local rightTabRow = Instance.new("Frame")
    rightTabRow.Size = UDim2.new(1, 0, 0, 26)
    rightTabRow.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    rightTabRow.Parent = rightPanel
    Instance.new("UICorner", rightTabRow).CornerRadius = UDim.new(0, 6)

    local rightTabs = {
        { Id = "NodeInspector", Label = "🕵️ Inspector & Acciones" },
        { Id = "JSONOutput",    Label = "📂 Salida JSON" },
        { Id = "ModHistory",    Label = "🧬 Historial & Parches" },
        { Id = "Stats",         Label = "📊 Telemetría" },
    }
    local rightTabButtons = {}
    local rTabWidth = 1 / #rightTabs

    -- Barra de Acciones Quirúrgicas de la Instancia Seleccionada
    local instanceToolBar = Instance.new("Frame")
    instanceToolBar.Size = UDim2.new(1, -12, 0, 26)
    instanceToolBar.Position = UDim2.new(0, 6, 0, 28)
    instanceToolBar.BackgroundTransparency = 1
    instanceToolBar.Parent = rightPanel

    local function createInstToolBtn(text, posX, width, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(width, -2, 1, 0)
        btn.Position = UDim2.new(posX, 1, 0, 0)
        btn.BackgroundColor3 = color or Color3.fromRGB(30, 35, 48)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(240, 245, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.Parent = instanceToolBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        return btn
    end

    local btnCopyPath = createInstToolBtn("📋 Ruta", 0, 0.22, Color3.fromRGB(35, 75, 130))
    local btnCopyCode = createInstToolBtn("📜 Código", 0.22, 0.22, Color3.fromRGB(45, 95, 150))
    local btnClone    = createInstToolBtn("🧬 Clonar", 0.44, 0.26, Color3.fromRGB(35, 125, 75))
    local btnDestroy  = createInstToolBtn("🗑️ Eliminar", 0.70, 0.30, Color3.fromRGB(180, 50, 50))

    -- Caja de Texto Principal del Inspector
    local inspectorBox = Instance.new("TextBox")
    inspectorBox.Size = UDim2.new(1, -12, 1, -126)
    inspectorBox.Position = UDim2.new(0, 6, 0, 58)
    inspectorBox.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    inspectorBox.TextColor3 = Color3.fromRGB(215, 225, 240)
    inspectorBox.Text = "-- Selecciona cualquier nodo en el árbol para inspeccionar o ejecutar acciones quirúrgicas."
    inspectorBox.Font = Enum.Font.Code
    inspectorBox.TextSize = 10
    inspectorBox.TextXAlignment = Enum.TextXAlignment.Left
    inspectorBox.TextYAlignment = Enum.TextYAlignment.Top
    inspectorBox.ClearTextOnFocus = false
    inspectorBox.MultiLine = true
    inspectorBox.TextEditable = false
    inspectorBox.Parent = rightPanel
    Instance.new("UICorner", inspectorBox).CornerRadius = UDim.new(0, 6)

    -- Barra de Exportación de Volcados (JSON, Markdown, Disco, VFS)
    local dumpActionRow = Instance.new("Frame")
    dumpActionRow.Size = UDim2.new(1, -12, 0, 28)
    dumpActionRow.Position = UDim2.new(0, 6, 1, -62)
    dumpActionRow.BackgroundTransparency = 1
    dumpActionRow.Parent = rightPanel

    local dumpJsonBtn = Instance.new("TextButton")
    dumpJsonBtn.Size = UDim2.new(0.25, -2, 1, 0)
    dumpJsonBtn.Position = UDim2.new(0, 0, 0, 0)
    dumpJsonBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 225)
    dumpJsonBtn.Text = "📂 JSON (.json)"
    dumpJsonBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpJsonBtn.Font = Enum.Font.GothamBold
    dumpJsonBtn.TextSize = 8
    dumpJsonBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpJsonBtn).CornerRadius = UDim.new(0, 4)

    local dumpMdBtn = Instance.new("TextButton")
    dumpMdBtn.Size = UDim2.new(0.25, -2, 1, 0)
    dumpMdBtn.Position = UDim2.new(0.25, 1, 0, 0)
    dumpMdBtn.BackgroundColor3 = Color3.fromRGB(0, 175, 130)
    dumpMdBtn.Text = "📄 MARKDOWN (.md)"
    dumpMdBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpMdBtn.Font = Enum.Font.GothamBold
    dumpMdBtn.TextSize = 8
    dumpMdBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpMdBtn).CornerRadius = UDim.new(0, 4)

    local dumpDiskBtn = Instance.new("TextButton")
    dumpDiskBtn.Size = UDim2.new(0.25, -2, 1, 0)
    dumpDiskBtn.Position = UDim2.new(0.50, 2, 0, 0)
    dumpDiskBtn.BackgroundColor3 = Color3.fromRGB(135, 55, 195)
    dumpDiskBtn.Text = "💾 DISCO (.lua)"
    dumpDiskBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpDiskBtn.Font = Enum.Font.GothamBold
    dumpDiskBtn.TextSize = 8
    dumpDiskBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpDiskBtn).CornerRadius = UDim.new(0, 4)

    local dumpVfsBtn = Instance.new("TextButton")
    dumpVfsBtn.Size = UDim2.new(0.25, -2, 1, 0)
    dumpVfsBtn.Position = UDim2.new(0.75, 3, 0, 0)
    dumpVfsBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 85)
    dumpVfsBtn.Text = "📦 VFS ARCHIVE"
    dumpVfsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpVfsBtn.Font = Enum.Font.GothamBold
    dumpVfsBtn.TextSize = 8
    dumpVfsBtn.Parent = dumpActionRow
    Instance.new("UICorner", dumpVfsBtn).CornerRadius = UDim.new(0, 4)

    -- Barra de Utilidades Inferior (Copiar / Guardar Vista)
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
    -- HANDLERS DE ACCIONES QUIRÚRGICAS (CLONAR / ELIMINAR / COPIAR)
    -- =========================================================================
    local function setInspectorText(text)
        local maxLimit = 75000
        local str = tostring(text or "")
        if #str > maxLimit then
            inspectorBox.Text = str:sub(1, maxLimit) .. string.format("\n\n-- [⚠️ Truncado a %d chars por límite de TextBox]\n-- [Total: %d chars]", maxLimit, #str)
        else
            inspectorBox.Text = str
        end
    end

    btnCopyPath.MouseButton1Click:Connect(function()
        local inst = self.SelectedNodeForInspection
        if inst then
            local path = inst:GetFullName()
            if safeSetClipboard(path) then
                btnCopyPath.Text = "✅ ¡Copiado!"
                task.delay(1.2, function() btnCopyPath.Text = "📋 Ruta" end)
            end
        end
    end)

    btnCopyCode.MouseButton1Click:Connect(function()
        local inst = self.SelectedNodeForInspection
        if inst and inst:IsA("LuaSourceContainer") then
            local caps = self.Registry:Get("CapabilityManager")
            local code = caps and caps:SafeDecompile(inst) or inst.Source
            if safeSetClipboard(code) then
                btnCopyCode.Text = "✅ ¡Copiado!"
                task.delay(1.2, function() btnCopyCode.Text = "📜 Código" end)
            end
        end
    end)

    btnClone.MouseButton1Click:Connect(function()
        local inst = self.SelectedNodeForInspection
        if inst then
            local s, cloned = pcall(function() return inst:Clone() end)
            if s and cloned then
                cloned.Name = inst.Name .. "_Clone"
                cloned.Parent = inst.Parent or Workspace

                -- Registrar en Historial
                local snippet = self:GenerateLuaCreationSnippet(inst)
                table.insert(self.ModificationHistory, 1, {
                    Action = "CLONE",
                    Timestamp = tick(),
                    Name = inst.Name,
                    CloneName = cloned.Name,
                    ClassName = inst.ClassName,
                    Path = inst:GetFullName(),
                    ParentPath = inst.Parent and inst.Parent:GetFullName() or "Workspace",
                    CreationSnippet = snippet,
                })

                btnClone.Text = "✅ ¡Clonado!"
                treeStatus.Text = string.format("🧬 Elemento clonado: %s", cloned.Name)
                task.delay(1.5, function() btnClone.Text = "🧬 Clonar" end)
            else
                btnClone.Text = "❌ No clonable"
                task.delay(1.5, function() btnClone.Text = "🧬 Clonar" end)
            end
        end
    end)

    btnDestroy.MouseButton1Click:Connect(function()
        local inst = self.SelectedNodeForInspection
        if inst then
            local caps = self.Registry:Get("CapabilityManager")
            local src = inst:IsA("LuaSourceContainer") and (caps and caps:SafeDecompile(inst) or inst.Source) or nil
            local snippet = self:GenerateLuaCreationSnippet(inst)

            -- Registrar snapshot antes de destruir
            table.insert(self.ModificationHistory, 1, {
                Action = "DESTROY",
                Timestamp = tick(),
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = inst:GetFullName(),
                ParentPath = inst.Parent and inst.Parent:GetFullName() or "Workspace",
                CreationSnippet = snippet,
                SourceCode = src,
            })

            local s, err = pcall(function() inst:Destroy() end)
            if s then
                btnDestroy.Text = "🗑️ ¡Eliminado!"
                treeStatus.Text = string.format("🗑️ Objeto '%s' eliminado y respaldado en historial.", inst.Name)
                self.SelectedNodeForInspection = nil
                setInspectorText("-- Objeto eliminado del juego. Puedes ver su código de restauración en la pestaña 'Historial & Parches'.")
                task.delay(1.5, function() btnDestroy.Text = "🗑️ Eliminar" end)
            else
                btnDestroy.Text = "❌ Error"
                treeStatus.Text = "Error al destruir: " .. tostring(err)
                task.delay(1.5, function() btnDestroy.Text = "🗑️ Eliminar" end)
            end
        end
    end)

    -- =========================================================================
    -- =========================================================================
    -- MENÚ CONTEXTUAL FLOTANTE (CLIC DERECHO / DARKDEX STYLE)
    -- =========================================================================
    local contextMenu = Instance.new("Frame")
    contextMenu.Size = UDim2.new(0, 190, 0, 230)
    contextMenu.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
    contextMenu.BorderSizePixel = 1
    contextMenu.BorderColor3 = Color3.fromRGB(0, 150, 225)
    contextMenu.ZIndex = 120
    contextMenu.Visible = false
    contextMenu.Parent = frame
    Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 6)

    local currentContextObj = nil

    local function createMenuOption(text, icon, posY, callback, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 24)
        btn.Position = UDim2.new(0, 4, 0, posY)
        btn.BackgroundColor3 = color or Color3.fromRGB(24, 28, 40)
        btn.Text = "  " .. icon .. "  " .. text
        btn.TextColor3 = Color3.fromRGB(230, 240, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 121
        btn.Parent = contextMenu
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(0, 130, 200)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = color or Color3.fromRGB(24, 28, 40)
        end)
        btn.MouseButton1Click:Connect(function()
            contextMenu.Visible = false
            if currentContextObj and callback then
                callback(currentContextObj)
            end
        end)
        return btn
    end

    -- =========================================================================
    -- MODAL DE CAMBIO DE NOMBRE (RENAME MODAL)
    -- =========================================================================
    local renameModal = Instance.new("Frame")
    renameModal.Size = UDim2.new(0, 260, 0, 110)
    renameModal.Position = UDim2.new(0.5, -130, 0.4, -55)
    renameModal.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    renameModal.BorderSizePixel = 1
    renameModal.BorderColor3 = Color3.fromRGB(0, 180, 255)
    renameModal.ZIndex = 150
    renameModal.Visible = false
    renameModal.Parent = frame
    Instance.new("UICorner", renameModal).CornerRadius = UDim.new(0, 6)

    local renameTitle = Instance.new("TextLabel")
    renameTitle.Size = UDim2.new(1, -10, 0, 22)
    renameTitle.Position = UDim2.new(0, 5, 0, 4)
    renameTitle.BackgroundTransparency = 1
    renameTitle.Text = "✏️ Cambiar Nombre de Instancia"
    renameTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
    renameTitle.Font = Enum.Font.GothamBold
    renameTitle.TextSize = 10
    renameTitle.ZIndex = 151
    renameTitle.Parent = renameModal

    local renameInput = Instance.new("TextBox")
    renameInput.Size = UDim2.new(1, -16, 0, 26)
    renameInput.Position = UDim2.new(0, 8, 0, 30)
    renameInput.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
    renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    renameInput.Font = Enum.Font.Gotham
    renameInput.TextSize = 11
    renameInput.Text = ""
    renameInput.ZIndex = 151
    renameInput.ClearTextOnFocus = false
    renameInput.Parent = renameModal
    Instance.new("UICorner", renameInput).CornerRadius = UDim.new(0, 4)

    local renameSaveBtn = Instance.new("TextButton")
    renameSaveBtn.Size = UDim2.new(0.48, -2, 0, 24)
    renameSaveBtn.Position = UDim2.new(0, 8, 1, -30)
    renameSaveBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
    renameSaveBtn.Text = "💾 Guardar"
    renameSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    renameSaveBtn.Font = Enum.Font.GothamBold
    renameSaveBtn.TextSize = 10
    renameSaveBtn.ZIndex = 151
    renameSaveBtn.Parent = renameModal
    Instance.new("UICorner", renameSaveBtn).CornerRadius = UDim.new(0, 4)

    local renameCancelBtn = Instance.new("TextButton")
    renameCancelBtn.Size = UDim2.new(0.48, -2, 0, 24)
    renameCancelBtn.Position = UDim2.new(0.52, 2, 1, -30)
    renameCancelBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    renameCancelBtn.Text = "Cancelar"
    renameCancelBtn.TextColor3 = Color3.fromRGB(200, 210, 230)
    renameCancelBtn.Font = Enum.Font.GothamMedium
    renameCancelBtn.TextSize = 10
    renameCancelBtn.ZIndex = 151
    renameCancelBtn.Parent = renameModal
    Instance.new("UICorner", renameCancelBtn).CornerRadius = UDim.new(0, 4)

    local renamingTarget = nil
    local function openRenameModal(obj)
        if not obj then return end
        renamingTarget = obj
        renameInput.Text = obj.Name
        renameModal.Visible = true
        renameInput:CaptureFocus()
    end

    local function applyRename()
        if renamingTarget and renameInput.Text ~= "" then
            local oldName = renamingTarget.Name
            local newName = renameInput.Text
            local s, err = pcall(function() renamingTarget.Name = newName end)
            if s then
                treeStatus.Text = string.format("✏️ Renombrado: '%s' → '%s'", oldName, newName)
                if self.SelectedNodeForInspection == renamingTarget then
                    self:InspectNode(renamingTarget)
                end
                rebuildFlatTree()
            else
                treeStatus.Text = "❌ Error al renombrar: " .. tostring(err)
            end
        end
        renameModal.Visible = false
        renamingTarget = nil
    end

    renameSaveBtn.MouseButton1Click:Connect(applyRename)
    renameInput.FocusLost:Connect(function(enter) if enter then applyRename() end end)
    renameCancelBtn.MouseButton1Click:Connect(function()
        renameModal.Visible = false
        renamingTarget = nil
    end)

    -- Opciones del Menú Contextual
    createMenuOption("Copiar Ruta", "📋", 4, function(obj)
        local path = obj:GetFullName()
        if safeSetClipboard(path) then
            treeStatus.Text = "📋 Ruta copiada: " .. path
        end
    end)

    createMenuOption("Copiar Código", "📜", 32, function(obj)
        local caps = self.Registry:Get("CapabilityManager")
        local src = (caps and caps:SafeDecompile(obj)) or (obj:IsA("LuaSourceContainer") and obj.Source) or "-- [No es script]"
        if safeSetClipboard(src) then
            treeStatus.Text = string.format("📜 Código de '%s' copiado (%d bytes).", obj.Name, #src)
        end
    end)

    createMenuOption("Renombrar", "✏️", 60, function(obj)
        openRenameModal(obj)
    end)

    createMenuOption("Duplicar / Clonar", "🧬", 88, function(obj)
        local s, cloned = pcall(function() return obj:Clone() end)
        if s and cloned then
            cloned.Name = obj.Name .. "_Clone"
            cloned.Parent = obj.Parent or Workspace
            local snippet = self:GenerateLuaCreationSnippet(obj)
            table.insert(self.ModificationHistory, 1, {
                Action = "CLONE",
                Timestamp = tick(),
                Name = obj.Name,
                CloneName = cloned.Name,
                ClassName = obj.ClassName,
                Path = obj:GetFullName(),
                ParentPath = obj.Parent and obj.Parent:GetFullName() or "Workspace",
                CreationSnippet = snippet,
            })
            treeStatus.Text = "🧬 Elemento clonado: " .. cloned.Name
            rebuildFlatTree()
        else
            treeStatus.Text = "❌ No se pudo clonar este objeto."
        end
    end)

    createMenuOption("Eliminar", "🗑️", 116, function(obj)
        local caps = self.Registry:Get("CapabilityManager")
        local src = obj:IsA("LuaSourceContainer") and (caps and caps:SafeDecompile(obj) or obj.Source) or nil
        local snippet = self:GenerateLuaCreationSnippet(obj)
        table.insert(self.ModificationHistory, 1, {
            Action = "DESTROY",
            Timestamp = tick(),
            Name = obj.Name,
            ClassName = obj.ClassName,
            Path = obj:GetFullName(),
            ParentPath = obj.Parent and obj.Parent:GetFullName() or "Workspace",
            CreationSnippet = snippet,
            SourceCode = src,
        })
        local s, err = pcall(function() obj:Destroy() end)
        if s then
            self.SelectedNodes[obj] = nil
            self.SelectedNodeForInspection = nil
            treeStatus.Text = string.format("🗑️ '%s' eliminado y respaldado.", obj.Name)
            rebuildFlatTree()
        else
            treeStatus.Text = "❌ Error al eliminar: " .. tostring(err)
        end
    end, Color3.fromRGB(60, 20, 20))

    createMenuOption("Exportar MD (.md)", "📄", 144, function(obj)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        if dumper and exporter then
            local pkg = dumper:DumpManualNodes({ obj })
            local s, path = exporter:ExportAsMarkdown("dump_" .. obj.Name:gsub("[^%w_]", "_") .. ".md", pkg, "Apex Dump - " .. obj.Name)
            treeStatus.Text = s and ("📄 Exportado MD: " .. tostring(path)) or "Error al exportar MD"
        end
    end)

    createMenuOption("Exportar JSON (.json)", "📂", 172, function(obj)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        if dumper and exporter then
            local pkg = dumper:DumpManualNodes({ obj })
            local jsonStr = exporter:ToJSON(pkg)
            local s, path = exporter:SaveToFile("dump_" .. obj.Name:gsub("[^%w_]", "_") .. ".json", jsonStr)
            treeStatus.Text = s and ("📂 Exportado JSON: " .. tostring(path)) or "Error al exportar JSON"
        end
    end)

    createMenuOption("Inspeccionar", "🕵️", 200, function(obj)
        self:InspectNode(obj)
    end)

    local function openContextMenu(obj, inputPos)
        if not obj then return end
        currentContextObj = obj
        self.SelectedNodeForInspection = obj
        local mousePos = inputPos or UserInputService:GetMouseLocation()
        local framePos = frame.AbsolutePosition
        local localX = math.clamp(mousePos.X - framePos.X + 4, 10, math.max(10, frame.AbsoluteSize.X - 200))
        local localY = math.clamp(mousePos.Y - framePos.Y + 4, 10, math.max(10, frame.AbsoluteSize.Y - 240))
        contextMenu.Position = UDim2.new(0, localX, 0, localY)
        contextMenu.Visible = true
    end

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if contextMenu.Visible then
                local mPos = UserInputService:GetMouseLocation()
                local cPos = contextMenu.AbsolutePosition
                local cSize = contextMenu.AbsoluteSize
                if mPos.X < cPos.X or mPos.X > cPos.X + cSize.X or mPos.Y < cPos.Y or mPos.Y > cPos.Y + cSize.Y then
                    contextMenu.Visible = false
                end
            end
        end
    end)

    -- =========================================================================
    -- DETECTOR / PICKER DE OBJETOS 2D (GUI) Y 3D (WORKSPACE)
    -- =========================================================================
    local function togglePicker()
        self.IsPickerActive = not self.IsPickerActive
        if self.IsPickerActive then
            pickerBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
            pickerBtn.Text = "🎯 ACTIVO"
            treeStatus.Text = "🎯 Haz clic en cualquier elemento 2D (GUI) o 3D (Workspace)..."

            if self.PickerConnection then self.PickerConnection:Disconnect() end
            self.PickerConnection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local mousePos = UserInputService:GetMouseLocation()
                    local targetInst = nil

                    -- 1. Intentar detectar objeto 2D en PlayerGui
                    pcall(function()
                        local lp = game.Players.LocalPlayer
                        if lp then
                            local pGui = lp:FindFirstChild("PlayerGui")
                            if pGui then
                                local guiObjects = pGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
                                for _, guiObj in ipairs(guiObjects) do
                                    if not guiObj:IsDescendantOf(self.Parent) and not guiObj:IsDescendantOf(frame) then
                                        targetInst = guiObj
                                        break
                                    end
                                end
                            end
                        end
                    end)

                    -- 2. Si no es GUI, detectar objeto 3D en Workspace
                    if not targetInst then
                        pcall(function()
                            local cam = Workspace.CurrentCamera
                            if cam then
                                local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
                                local lp = game.Players.LocalPlayer
                                local params = RaycastParams.new()
                                params.FilterType = RaycastFilterType.Exclude
                                if lp and lp.Character then
                                    params.FilterDescendantsInstances = { lp.Character }
                                end
                                local result = Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
                                if result and result.Instance then
                                    targetInst = result.Instance
                                end
                            end
                        end)
                    end

                    if targetInst then
                        -- Expandir todos los ancestros
                        local curr = targetInst.Parent
                        while curr and curr ~= game do
                            self.ExpandedNodes[curr] = true
                            curr = curr.Parent
                        end

                        self.SelectedNodes[targetInst] = true
                        rebuildFlatTree()
                        self:InspectNode(targetInst)

                        for idx, data in ipairs(self.FlatTree) do
                            if data.obj == targetInst then
                                treeScroll.CanvasPosition = Vector2.new(0, math.max(0, (idx - 4) * ROW_HEIGHT))
                                break
                            end
                        end

                        treeStatus.Text = string.format("🎯 Objeto detectado: %s (%s)", targetInst.Name, targetInst.ClassName)
                        togglePicker()
                    end
                end
            end)
        else
            pickerBtn.BackgroundColor3 = Color3.fromRGB(30, 95, 155)
            pickerBtn.Text = "🎯 PICKER"
            if self.PickerConnection then
                self.PickerConnection:Disconnect()
                self.PickerConnection = nil
            end
        end
    end

    pickerBtn.MouseButton1Click:Connect(togglePicker)

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
        treeStatus.Text = string.format("Seleccionados: %d nodos | Filtro: %s | Modo: %s", count, self.CurrentFilter, self.CurrentMode)
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
                local badgeWidth = data.badge and 80 or 0
                frameRow.NameLabel.Position = UDim2.new(0, textX, 0, 0)
                frameRow.NameLabel.Size = UDim2.new(1, -textX - badgeWidth - 28, 1, 0)

                local displayName = self.IsSearching and data.obj:GetFullName() or data.obj.Name
                frameRow.NameLabel.Text = displayName

                if data.badge then
                    frameRow.BadgeLabel.Visible = true
                    frameRow.BadgeLabel.Text = data.badge.Text
                    frameRow.BadgeLabel.TextColor3 = data.badge.Color
                    frameRow.NameLabel.TextColor3 = (data.badge.Type == "SUSPICIOUS") and Color3.fromRGB(255, 100, 100)
                        or (data.badge.Type == "CONTAINER_ALERT") and Color3.fromRGB(255, 160, 60)
                        or (data.badge.Type == "REMOTE") and Color3.fromRGB(120, 220, 255)
                        or (data.badge.Type == "ECONOMY") and Color3.fromRGB(255, 200, 100)
                        or (data.badge.Type == "PHYSICS") and Color3.fromRGB(100, 240, 160)
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
        elseif self.CurrentFilter == "PHYSICS" then
            local lowerName = obj.Name:lower()
            return lowerName:find("move") or lowerName:find("pos") or lowerName:find("cframe") or lowerName:find("velocity") or lowerName:find("speed") or lowerName:find("teleport")
        elseif self.CurrentFilter == "SUSPICIOUS" then
            local badge = self:GetNodeThreatBadge(obj)
            return badge ~= nil
        end
        return true
    end

    function rebuildFlatTree()
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

    refreshHeatmapBtn.MouseButton1Click:Connect(function()
        self:BuildThreatHeatmap()
        rebuildFlatTree()
        treeStatus.Text = "🔥 Matriz de Calor recalculada y propagada."
    end)

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

    -- Filas UI Reutilizadas para Virtualización
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
        badgeLabel.Size = UDim2.new(0, 80, 0, 16)
        badgeLabel.Position = UDim2.new(1, -106, 0, 3)
        badgeLabel.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
        badgeLabel.Font = Enum.Font.GothamBold
        badgeLabel.TextSize = 8
        badgeLabel.Visible = false
        badgeLabel.Parent = row
        Instance.new("UICorner", badgeLabel).CornerRadius = UDim.new(0, 3)

        local moreBtn = Instance.new("TextButton")
        moreBtn.Size = UDim2.new(0, 18, 0, 16)
        moreBtn.Position = UDim2.new(1, -22, 0, 3)
        moreBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
        moreBtn.Text = "⋮"
        moreBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
        moreBtn.Font = Enum.Font.GothamBold
        moreBtn.TextSize = 11
        moreBtn.Parent = row
        Instance.new("UICorner", moreBtn).CornerRadius = UDim.new(0, 3)

        local frameData = {
            Frame = row,
            ExpandBtn = expandBtn,
            CheckBtn = checkBtn,
            NameLabel = nameLabel,
            BadgeLabel = badgeLabel,
            MoreBtn = moreBtn,
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

        -- Menú Contextual (DarkDex Style): Clic Derecho y Botón ⋮
        nameLabel.MouseButton2Click:Connect(function()
            openContextMenu(frameData.NodeObj)
        end)

        moreBtn.MouseButton1Click:Connect(function()
            openContextMenu(frameData.NodeObj)
        end)

        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                openContextMenu(frameData.NodeObj, Vector2.new(input.Position.X, input.Position.Y))
            end
        end)

        row.Parent = treeScroll
        table.insert(self.UIRows, frameData)
    end

    treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleTree)

    selectSuspiciousBtn.MouseButton1Click:Connect(function()
        local count = 0
        for inst, _ in pairs(self.ThreatHeatmap) do
            self.SelectedNodes[inst] = true
            count = count + 1
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

    -- Cargar Raíces del Explorador
    local commonServices = { "Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "RobloxReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer" }
    for _, sName in ipairs(commonServices) do
        pcall(function()
            local srv = game:GetService(sName)
            if srv then table.insert(self.RootNodes, srv) end
        end)
    end
    rebuildFlatTree()

    -- =========================================================================
    -- INSPECTOR DE NODO DERECHO
    -- =========================================================================
    function self:InspectNode(instance)
        self.SelectedNodeForInspection = instance
        self:SelectRightTab("NodeInspector")

        local caps = self.Registry:Get("CapabilityManager")
        local lines = {}
        table.insert(lines, "=============================================================================")
        table.insert(lines, string.format("🕵️ INSPECCIÓN DETALLADA: %s (%s)", instance.Name, instance.ClassName))
        table.insert(lines, string.format("📍 Ruta Completa: %s", instance:GetFullName()))

        local badge = self:GetNodeThreatBadge(instance)
        if badge then
            table.insert(lines, string.format("⚠️ ALERTA DE SEGURIDAD: %s (%s)", badge.Text, badge.Reason or "Detectado en análisis"))
        end
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
                setInspectorText("-- No hay ningún paquete de volcado extraído aún. Presiona EXTRAER JSON o MARKDOWN abajo.")
            end
        elseif tabId == "ModHistory" then
            local patchScript = self:GenerateImportablePatchScript()
            setInspectorText(patchScript)
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
                string.format("• Nodos en Matriz de Calor: %d", (function() local c=0; for _ in pairs(self.ThreatHeatmap) do c=c+1 end return c end)()),
                string.format("• Modificaciones en Historial: %d", #self.ModificationHistory),
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
    -- EJECUCIÓN DE VOLCADOS MULTIHILO (JSON, MARKDOWN, DISCO, VFS)
    -- =========================================================================
    local function executeDump(exportMode)
        local dumper = self.Registry:Get("SelectiveDumper")
        local exporter = self.Registry:Get("ReportExporter")
        local heuristic = self.Registry:Get("HeuristicEngine")
        local actionRecorder = self.Registry:Get("ActionRecorder")

        if not dumper or not exporter then return end

        dumpJsonBtn.Text = "⏳ VOLCANDO..."
        dumpMdBtn.Text = "⏳ VOLCANDO..."
        dumpDiskBtn.Text = "⏳ VOLCANDO..."
        dumpVfsBtn.Text = "⏳ VOLCANDO..."
        treeStatus.Text = "⏳ Procesando extracción multihilo en modo " .. self.CurrentMode .. "..."

        task.spawn(function()
            local startTime = tick()
            local package = nil

            local function onProgress(curr, total, name)
                local elapsed = tick() - startTime
                local speed = curr / math.max(elapsed, 0.001)
                local eta = speed > 0 and ((total - curr) / speed) or 0
                treeStatus.Text = string.format("⏳ [%d/%d] %s | ETA: ~%.1fs", curr, total, tostring(name or ""):sub(1, 20), eta)
            end

            if self.CurrentMode == "RUNTIME_INTERACTIONS" then
                package = dumper:DumpRuntimeInteractions(onProgress)
            elseif self.CurrentMode == "HEURISTIC_FINDINGS" then
                local audit = heuristic and heuristic:RunFullAudit(nil, onProgress)
                package = dumper:DumpHeuristicFindings(audit, onProgress)
            elseif self.CurrentMode == "DEPENDENCY_CHAIN" then
                package = dumper:DumpDependencyChain(actionRecorder and actionRecorder.RecentAction, onProgress)
            elseif self.CurrentMode == "FULL_ENVIRONMENT" then
                package = dumper:DumpFullEnvironment(onProgress)
            else
                local queue = {}
                for obj, isSel in pairs(self.SelectedNodes) do
                    if isSel then table.insert(queue, obj) end
                end

                if #queue == 0 then
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
            elseif exportMode == "md" then
                local mdTitle = "Apex Suite - Volcado " .. self.CurrentMode
                local fname = "dump_" .. self.CurrentMode:lower() .. "_" .. math.floor(tick()) .. ".md"
                local s, path, mdContent = exporter:ExportAsMarkdown(fname, package, mdTitle)
                self:SelectRightTab("JSONOutput")
                setInspectorText(mdContent)
                if s then
                    treeStatus.Text = string.format("✅ Markdown guardado en %.2fs (%d KB) → %s", duration, math.floor(#mdContent / 1024), tostring(path))
                else
                    treeStatus.Text = "Resultado Markdown: " .. tostring(path)
                end
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

            dumpJsonBtn.Text = "📂 JSON (.json)"
            dumpMdBtn.Text = "📄 MARKDOWN (.md)"
            dumpDiskBtn.Text = "💾 DISCO (.lua)"
            dumpVfsBtn.Text = "📦 VFS ARCHIVE"
        end)
    end

    dumpJsonBtn.MouseButton1Click:Connect(function() executeDump("json") end)
    dumpMdBtn.MouseButton1Click:Connect(function() executeDump("md") end)
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
        if visible then
            self:BuildThreatHeatmap()
        end
    end
end

return DumperView
