--[[
    =============================================================================
    APEX SUITE / STANDALONE - SELECTIVE GAME DUMPER & SMART INSPECTOR v5.0
    (VIRTUAL SCROLLING TREE, DARKDEX CONTEXT MENU, SMART FRAME & PROPERTY INSPECTOR)
    =============================================================================
    Herramienta avanzada de inspección y volcado selectivo de jerarquías:
      1. Árbol virtualizado ultra-rápido (Virtual Scrolling) con reciclaje de frames.
      2. Menú contextual DarkDex (Clic Derecho): Copiar Ruta, Código, Renombrar, Clonar, Eliminar, Guardar.
      3. Selector / Picker 2D (PlayerGui) y 3D (Workspace) para apuntar y seleccionar objetos en pantalla.
      4. Inspector Inteligente de Frames y Propiedades:
         - GuiObject: Posición, Tamaño, AbsoluteSize/Position, AnchorPoint, ZIndex, Visibilidad, Textos, Imágenes.
         - BasePart: CFrame, Posición, Orientación, Dimensiones, Material, CanCollide, Masa de Ensamble.
         - Scripts: Decompilación protegida, Bytecode y visor de código integrado.
         - Tags y Atributos dinámicos.
      5. Modal de Progreso en Vivo: Contador [X/Y], porcentaje, ETA y velocidad en ops/s.
      6. Exportación Multiformato: JSON, Markdown, y Dump TXT con resolución de Roblox API Dump.
--]]

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local randomSeed = math.random(100000, 999999)
local SPOOFED_GUI_NAME = "ApexSelectiveDumper_" .. tostring(randomSeed)

-- =============================================================================
-- CONTENEDOR SEGURO
-- =============================================================================
local function getSecureGuiParent()
    local parentContainer = nil
    if typeof(gethui) == "function" then pcall(function() parentContainer = gethui() end) end
    if not parentContainer and typeof(cloneref) == "function" and CoreGui then
        pcall(function() parentContainer = cloneref(CoreGui) end)
    end
    if not parentContainer and CoreGui then
        parentContainer = CoreGui
    end
    if not parentContainer and LocalPlayer then
        parentContainer = LocalPlayer:WaitForChild("PlayerGui")
    end
    return parentContainer or game:GetService("StarterGui")
end

local secureParent = getSecureGuiParent()
local oldGui = secureParent:FindFirstChild(SPOOFED_GUI_NAME)
if oldGui then pcall(function() oldGui:Destroy() end) end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = SPOOFED_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = secureParent

-- Portapapeles Seguro
local function safeSetClipboard(text)
    if not text or #text == 0 then return false end
    if typeof(setclipboard) == "function" then
        local s = pcall(function() setclipboard(text) end)
        if s then return true end
    elseif typeof(toclipboard) == "function" then
        local s = pcall(function() toclipboard(text) end)
        if s then return true end
    end
    return false
end

-- =============================================================================
-- INTERFAZ PRINCIPAL
-- =============================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 880, 0, 560)
mainFrame.Position = UDim2.new(0.5, -440, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 168, 255)
mainStroke.Thickness = 1.4
mainStroke.Parent = mainFrame

-- Barra de Título
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -180, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "📂 SELECTIVE DUMPER & SMART INSPECTOR PRO"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -66, 0, 7)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 12
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)

local pickerBtn = Instance.new("TextButton")
pickerBtn.Size = UDim2.new(0, 95, 0, 26)
pickerBtn.Position = UDim2.new(1, -168, 0, 7)
pickerBtn.BackgroundColor3 = Color3.fromRGB(30, 95, 155)
pickerBtn.Text = "🎯 PICKER"
pickerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
pickerBtn.Font = Enum.Font.GothamBold
pickerBtn.TextSize = 10
pickerBtn.Parent = titleBar
Instance.new("UICorner", pickerBtn).CornerRadius = UDim.new(0, 5)

-- Botón Flotante Superior Central (Top Center Pill)
local floatPill = Instance.new("TextButton")
floatPill.Name = "SelectiveDumperPill"
floatPill.Size = UDim2.new(0, 200, 0, 32)
floatPill.Position = UDim2.new(0.5, -100, 0, 10)
floatPill.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
floatPill.Text = "🔍 DUMPER PRO [ABRIR]"
floatPill.TextColor3 = Color3.fromRGB(0, 215, 255)
floatPill.Font = Enum.Font.GothamBold
floatPill.TextSize = 11
floatPill.Visible = false
floatPill.Active = true
floatPill.Draggable = true
floatPill.ZIndex = 300
floatPill.Parent = screenGui
Instance.new("UICorner", floatPill).CornerRadius = UDim.new(1, 0)

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = Color3.fromRGB(0, 168, 255)
pillStroke.Thickness = 1.4
pillStroke.Parent = floatPill

minimizeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    floatPill.Visible = true
    floatPill.Position = UDim2.new(0.5, -100, 0, 10)
end)

floatPill.MouseButton1Click:Connect(function()
    mainFrame.Visible = true
    floatPill.Visible = false
end)

-- =============================================================================
-- PANELES PRINCIPALES (IZQUIERDA: ÁRBOL / DERECHA: INSPECTOR & EXPORTACIÓN)
-- =============================================================================
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.42, -14, 1, -50)
leftPanel.Position = UDim2.new(0, 10, 0, 44)
leftPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
leftPanel.Parent = mainFrame
Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 8)

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.58, -14, 1, -50)
rightPanel.Position = UDim2.new(0.42, 4, 0, 44)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = mainFrame

-- Panel de Búsqueda y Selección en Árbol
local searchBar = Instance.new("Frame")
searchBar.Size = UDim2.new(1, -12, 0, 28)
searchBar.Position = UDim2.new(0, 6, 0, 6)
searchBar.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
searchBar.Parent = leftPanel
Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 5)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -34, 1, 0)
searchBox.Position = UDim2.new(0, 8, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.TextColor3 = Color3.fromRGB(240, 245, 255)
searchBox.PlaceholderText = "🔎 Buscar en árbol (Nombre / Clase)..."
searchBox.PlaceholderColor3 = Color3.fromRGB(120, 135, 160)
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 11
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchBar

local searchBtn = Instance.new("TextButton")
searchBtn.Size = UDim2.new(0, 26, 0, 24)
searchBtn.Position = UDim2.new(1, -28, 0, 2)
searchBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
searchBtn.Text = "🔍"
searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBtn.Font = Enum.Font.Gotham
searchBtn.TextSize = 12
searchBtn.Parent = searchBar
Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 4)

-- Barra de Acciones de Árbol (Seleccionar Todo, Invertir, Limpiar)
local treeActionRow = Instance.new("Frame")
treeActionRow.Size = UDim2.new(1, -12, 0, 22)
treeActionRow.Position = UDim2.new(0, 6, 0, 38)
treeActionRow.BackgroundTransparency = 1
treeActionRow.Parent = leftPanel

local btnSelectAll = Instance.new("TextButton")
btnSelectAll.Size = UDim2.new(0.32, 0, 1, 0)
btnSelectAll.Position = UDim2.new(0, 0, 0, 0)
btnSelectAll.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
btnSelectAll.Text = "✓ Todo"
btnSelectAll.TextColor3 = Color3.fromRGB(0, 215, 255)
btnSelectAll.Font = Enum.Font.GothamMedium
btnSelectAll.TextSize = 9
btnSelectAll.Parent = treeActionRow
Instance.new("UICorner", btnSelectAll).CornerRadius = UDim.new(0, 3)

local btnSelectDesc = Instance.new("TextButton")
btnSelectDesc.Size = UDim2.new(0.34, 0, 1, 0)
btnSelectDesc.Position = UDim2.new(0.33, 0, 0, 0)
btnSelectDesc.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
btnSelectDesc.Text = "⚡ +Descendientes"
btnSelectDesc.TextColor3 = Color3.fromRGB(245, 170, 45)
btnSelectDesc.Font = Enum.Font.GothamMedium
btnSelectDesc.TextSize = 9
btnSelectDesc.Parent = treeActionRow
Instance.new("UICorner", btnSelectDesc).CornerRadius = UDim.new(0, 3)

local btnClearSel = Instance.new("TextButton")
btnClearSel.Size = UDim2.new(0.32, 0, 1, 0)
btnClearSel.Position = UDim2.new(0.68, 0, 0, 0)
btnClearSel.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
btnClearSel.Text = "✕ Limpiar"
btnClearSel.TextColor3 = Color3.fromRGB(240, 90, 90)
btnClearSel.Font = Enum.Font.GothamMedium
btnClearSel.TextSize = 9
btnClearSel.Parent = treeActionRow
Instance.new("UICorner", btnClearSel).CornerRadius = UDim.new(0, 3)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Size = UDim2.new(1, -12, 1, -90)
treeScroll.Position = UDim2.new(0, 6, 0, 64)
treeScroll.BackgroundTransparency = 1
treeScroll.ScrollBarThickness = 5
treeScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 160, 230)
treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
treeScroll.Parent = leftPanel

local treeStatusLabel = Instance.new("TextLabel")
treeStatusLabel.Size = UDim2.new(1, -12, 0, 20)
treeStatusLabel.Position = UDim2.new(0, 6, 1, -24)
treeStatusLabel.BackgroundTransparency = 1
treeStatusLabel.Text = "Marcados: 0 objetos | Clic derecho para opciones DarkDex"
treeStatusLabel.TextColor3 = Color3.fromRGB(140, 155, 180)
treeStatusLabel.Font = Enum.Font.Gotham
treeStatusLabel.TextSize = 9
treeStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
treeStatusLabel.Parent = leftPanel

-- =============================================================================
-- PANEL DERECHO: PESTAÑAS DE INSPECCIÓN INTELIGENTE
-- =============================================================================
local tabHeader = Instance.new("Frame")
tabHeader.Size = UDim2.new(1, 0, 0, 28)
tabHeader.BackgroundTransparency = 1
tabHeader.Parent = rightPanel

local rightTabs = {
    { Id = "Properties", Label = "🏷️ Propiedades & Frame" },
    { Id = "Code",       Label = "📜 Visor de Código" },
    { Id = "Export",     Label = "📦 Volcado & Exportar" },
}
local rightTabButtons = {}
local activeTab = "Properties"

local inspectorBox = Instance.new("TextBox")
inspectorBox.Size = UDim2.new(1, 0, 1, -76)
inspectorBox.Position = UDim2.new(0, 0, 0, 34)
inspectorBox.BackgroundColor3 = Color3.fromRGB(14, 17, 24)
inspectorBox.TextColor3 = Color3.fromRGB(220, 230, 245)
inspectorBox.Font = Enum.Font.Code
inspectorBox.TextSize = 11
inspectorBox.TextXAlignment = Enum.TextXAlignment.Left
inspectorBox.TextYAlignment = Enum.TextYAlignment.Top
inspectorBox.ClearTextOnFocus = false
inspectorBox.MultiLine = true
inspectorBox.TextEditable = false
inspectorBox.Parent = rightPanel
Instance.new("UICorner", inspectorBox).CornerRadius = UDim.new(0, 6)

local actionBottomBar = Instance.new("Frame")
actionBottomBar.Size = UDim2.new(1, 0, 0, 36)
actionBottomBar.Position = UDim2.new(0, 0, 1, -36)
actionBottomBar.BackgroundTransparency = 1
actionBottomBar.Parent = rightPanel

local btnCopyCode = Instance.new("TextButton")
btnCopyCode.Size = UDim2.new(0.32, -3, 1, 0)
btnCopyCode.Position = UDim2.new(0, 0, 0, 0)
btnCopyCode.BackgroundColor3 = Color3.fromRGB(30, 80, 140)
btnCopyCode.Text = "📋 COPIAR TEXTO"
btnCopyCode.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCopyCode.Font = Enum.Font.GothamBold
btnCopyCode.TextSize = 10
btnCopyCode.Parent = actionBottomBar
Instance.new("UICorner", btnCopyCode).CornerRadius = UDim.new(0, 5)

local btnExportDump = Instance.new("TextButton")
btnExportDump.Size = UDim2.new(0.40, -3, 1, 0)
btnExportDump.Position = UDim2.new(0.32, 3, 0, 0)
btnExportDump.BackgroundColor3 = Color3.fromRGB(0, 155, 115)
btnExportDump.Text = "⚡ EXPORTAR SELECCIÓN"
btnExportDump.TextColor3 = Color3.fromRGB(255, 255, 255)
btnExportDump.Font = Enum.Font.GothamBold
btnExportDump.TextSize = 10
btnExportDump.Parent = actionBottomBar
Instance.new("UICorner", btnExportDump).CornerRadius = UDim.new(0, 5)

local btnSaveDisk = Instance.new("TextButton")
btnSaveDisk.Size = UDim2.new(0.28, 0, 1, 0)
btnSaveDisk.Position = UDim2.new(0.72, 3, 0, 0)
btnSaveDisk.BackgroundColor3 = Color3.fromRGB(125, 45, 175)
btnSaveDisk.Text = "💾 DISCO (.txt)"
btnSaveDisk.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSaveDisk.Font = Enum.Font.GothamBold
btnSaveDisk.TextSize = 10
btnSaveDisk.Parent = actionBottomBar
Instance.new("UICorner", btnSaveDisk).CornerRadius = UDim.new(0, 5)

-- =============================================================================
-- MODAL DE PROGRESO DE VOLCADO (DUMP PROGRESS OVERLAY)
-- =============================================================================
local progressOverlay = Instance.new("Frame")
progressOverlay.Name = "DumpProgressOverlay"
progressOverlay.Size = UDim2.new(1, 0, 1, 0)
progressOverlay.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
progressOverlay.BackgroundTransparency = 0.35
progressOverlay.ZIndex = 250
progressOverlay.Visible = false
progressOverlay.Parent = mainFrame

local progressCard = Instance.new("Frame")
progressCard.Size = UDim2.new(0, 480, 0, 230)
progressCard.Position = UDim2.new(0.5, -240, 0.5, -115)
progressCard.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
progressCard.ZIndex = 251
progressCard.Parent = progressOverlay
Instance.new("UICorner", progressCard).CornerRadius = UDim.new(0, 10)

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(0, 175, 255)
cardStroke.Thickness = 1.6
cardStroke.Parent = progressCard

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -24, 0, 26)
modalTitle.Position = UDim2.new(0, 12, 0, 12)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "📦 VOLCADO SELECTIVO EN CURSO"
modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 13
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.ZIndex = 252
modalTitle.Parent = progressCard

local modalPctLabel = Instance.new("TextLabel")
modalPctLabel.Size = UDim2.new(0, 90, 0, 30)
modalPctLabel.Position = UDim2.new(1, -102, 0, 12)
modalPctLabel.BackgroundTransparency = 1
modalPctLabel.Text = "0%"
modalPctLabel.TextColor3 = Color3.fromRGB(0, 230, 140)
modalPctLabel.Font = Enum.Font.GothamBold
modalPctLabel.TextSize = 20
modalPctLabel.TextXAlignment = Enum.TextXAlignment.Right
modalPctLabel.ZIndex = 252
modalPctLabel.Parent = progressCard

local modalTrack = Instance.new("Frame")
modalTrack.Size = UDim2.new(1, -24, 0, 10)
modalTrack.Position = UDim2.new(0, 12, 0, 48)
modalTrack.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
modalTrack.ZIndex = 252
modalTrack.Parent = progressCard
Instance.new("UICorner", modalTrack).CornerRadius = UDim.new(1, 0)

local modalFill = Instance.new("Frame")
modalFill.Size = UDim2.new(0, 0, 1, 0)
modalFill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
modalFill.ZIndex = 253
modalFill.Parent = modalTrack
Instance.new("UICorner", modalFill).CornerRadius = UDim.new(1, 0)

local modalCounter = Instance.new("TextLabel")
modalCounter.Size = UDim2.new(1, -24, 0, 18)
modalCounter.Position = UDim2.new(0, 12, 0, 68)
modalCounter.BackgroundTransparency = 1
modalCounter.Text = "Procesados: [0 / 0] Elementos"
modalCounter.TextColor3 = Color3.fromRGB(220, 230, 245)
modalCounter.Font = Enum.Font.GothamBold
modalCounter.TextSize = 11
modalCounter.TextXAlignment = Enum.TextXAlignment.Left
modalCounter.ZIndex = 252
modalCounter.Parent = progressCard

local modalMetrics = Instance.new("TextLabel")
modalMetrics.Size = UDim2.new(1, -24, 0, 16)
modalMetrics.Position = UDim2.new(0, 12, 0, 90)
modalMetrics.BackgroundTransparency = 1
modalMetrics.Text = "⏱️ Transcurrido: 0.0s | ⏳ ETA: ~0.0s | ⚡ 0 ops/s"
modalMetrics.TextColor3 = Color3.fromRGB(150, 175, 210)
modalMetrics.Font = Enum.Font.Code
modalMetrics.TextSize = 10
modalMetrics.TextXAlignment = Enum.TextXAlignment.Left
modalMetrics.ZIndex = 252
modalMetrics.Parent = progressCard

local modalCurrentItem = Instance.new("TextLabel")
modalCurrentItem.Size = UDim2.new(1, -24, 0, 36)
modalCurrentItem.Position = UDim2.new(0, 12, 0, 114)
modalCurrentItem.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
modalCurrentItem.Text = "  Iniciando escaneo..."
modalCurrentItem.TextColor3 = Color3.fromRGB(170, 185, 205)
modalCurrentItem.Font = Enum.Font.Code
modalCurrentItem.TextSize = 9
modalCurrentItem.TextXAlignment = Enum.TextXAlignment.Left
modalCurrentItem.TextTruncate = Enum.TextTruncate.AtEnd
modalCurrentItem.ZIndex = 252
modalCurrentItem.Parent = progressCard
Instance.new("UICorner", modalCurrentItem).CornerRadius = UDim.new(0, 4)

local modalCloseBtn = Instance.new("TextButton")
modalCloseBtn.Size = UDim2.new(0, 110, 0, 24)
modalCloseBtn.Position = UDim2.new(1, -122, 1, -34)
modalCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
modalCloseBtn.Text = "Ocultar"
modalCloseBtn.TextColor3 = Color3.fromRGB(200, 215, 235)
modalCloseBtn.Font = Enum.Font.GothamMedium
modalCloseBtn.TextSize = 10
modalCloseBtn.ZIndex = 252
modalCloseBtn.Parent = progressCard
Instance.new("UICorner", modalCloseBtn).CornerRadius = UDim.new(0, 4)
modalCloseBtn.MouseButton1Click:Connect(function() progressOverlay.Visible = false end)

-- =============================================================================
-- ÁRBOL VIRTUALIZADO (VIRTUAL SCROLLING LOGIC)
-- =============================================================================
local ROW_HEIGHT = 22
local INDENT_SIZE = 14
local VISIBLE_ROWS = 32

local flatTree = {}
local selectedNodes = {}
local expandedNodes = {}
local uiRows = {}
local rootNodes = {}
local selectedObjectForInspection = nil
local isSearching = false
local searchResults = {}
local searchId = 0

local function hasChildrenSafe(obj)
    local s, c = pcall(function() return obj:GetChildren() end)
    return (s and c and #c > 0)
end

local function getChildrenSafe(obj)
    local s, c = pcall(function() return obj:GetChildren() end)
    return (s and c and c) or {}
end

local function updateStatus()
    local count = 0
    for _, isSel in pairs(selectedNodes) do if isSel then count = count + 1 end end
    treeStatusLabel.Text = string.format("Marcados: %d objetos | Clic derecho para opciones DarkDex", count)
end

-- =============================================================================
-- INSPECTOR INTELIGENTE DE FRAMES Y PROPIEDADES (SMART INSPECTOR)
-- =============================================================================
local function decompileScriptSource(scriptObj)
    if not scriptObj or not scriptObj:IsA("LuaSourceContainer") then return "-- [No es script]" end
    local source = nil
    if typeof(decompile) == "function" then
        local s, code = pcall(decompile, scriptObj)
        if s and code and #code > 0 then source = code end
    end
    if not source then
        local s, src = pcall(function() return scriptObj.Source end)
        if s and src and #src > 0 then source = src end
    end
    return source or "-- [Código no accesible o decompilador no disponible]"
end

local function inspectSmartProperties(obj)
    if not obj then
        inspectorBox.Text = "-- Selecciona un objeto en el árbol o con el Picker para inspeccionarlo."
        return
    end

    selectedObjectForInspection = obj
    local lines = {}
    table.insert(lines, "=============================================================================")
    table.insert(lines, string.format("🕵️ INSPECCIÓN INTELIGENTE: %s (%s)", obj.Name, obj.ClassName))
    table.insert(lines, string.format("📍 Ruta Completa: %s", obj:GetFullName()))
    table.insert(lines, "=============================================================================")

    -- 1. INSPECCIÓN AVANZADA DE INTERFACES GUI (GuiObject / Frame / Button / Text / Image)
    if obj:IsA("GuiObject") then
        table.insert(lines, "\n📐 [GEOMETRÍA Y RENDERIZADO 2D - SMART GUI INSPECTOR]:")
        table.insert(lines, string.format("   • Posición (UDim2): %s (X: %.3f + %d, Y: %.3f + %d)",
            tostring(obj.Position), obj.Position.X.Scale, obj.Position.X.Offset, obj.Position.Y.Scale, obj.Position.Y.Offset))
        table.insert(lines, string.format("   • Tamaño (UDim2):   %s (X: %.3f + %d, Y: %.3f + %d)",
            tostring(obj.Size), obj.Size.X.Scale, obj.Size.X.Offset, obj.Size.Y.Scale, obj.Size.Y.Offset))
        table.insert(lines, string.format("   • Dimensiones Absolutas: Size = (%d, %d) | Pos = (%d, %d)",
            obj.AbsoluteSize.X, obj.AbsoluteSize.Y, obj.AbsolutePosition.X, obj.AbsolutePosition.Y))
        table.insert(lines, string.format("   • AnchorPoint: (%.2f, %.2f) | ZIndex: %d | LayoutOrder: %d",
            obj.AnchorPoint.X, obj.AnchorPoint.Y, obj.ZIndex, obj.LayoutOrder))
        table.insert(lines, string.format("   • Visibilidad: Visible = %s | Active = %s | ClipsDescendants = %s",
            tostring(obj.Visible), tostring(obj.Active), tostring(obj.ClipsDescendants)))
        table.insert(lines, string.format("   • Background: Color = RGB(%d, %d, %d) | Transparency = %.2f",
            math.floor(obj.BackgroundColor3.R * 255), math.floor(obj.BackgroundColor3.G * 255), math.floor(obj.BackgroundColor3.B * 255), obj.BackgroundTransparency))

        -- TextLabel / TextButton / TextBox
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            table.insert(lines, string.format("   • Texto: %q", obj.Text))
            table.insert(lines, string.format("   • Tipografía: Font = %s | TextSize = %d | Color = RGB(%d, %d, %d)",
                obj.Font.Name, obj.TextSize, math.floor(obj.TextColor3.R * 255), math.floor(obj.TextColor3.G * 255), math.floor(obj.TextColor3.B * 255)))
            table.insert(lines, string.format("   • Alineación: X = %s | Y = %s | TextWrapped = %s | TextScaled = %s",
                obj.TextXAlignment.Name, obj.TextYAlignment.Name, tostring(obj.TextWrapped), tostring(obj.TextScaled)))
            if obj:IsA("TextBox") then
                table.insert(lines, string.format("   • TextBox: Placeholder = %q | ClearTextOnFocus = %s | MultiLine = %s",
                    obj.PlaceholderText, tostring(obj.ClearTextOnFocus), tostring(obj.MultiLine)))
            end
        end

        -- ImageLabel / ImageButton
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            table.insert(lines, string.format("   • Imagen: %q | ImageTransparency = %.2f", obj.Image, obj.ImageTransparency))
            table.insert(lines, string.format("   • ImageColor: RGB(%d, %d, %d) | ScaleType = %s",
                math.floor(obj.ImageColor3.R * 255), math.floor(obj.ImageColor3.G * 255), math.floor(obj.ImageColor3.B * 255), obj.ScaleType.Name))
        end

        -- ScrollingFrame
        if obj:IsA("ScrollingFrame") then
            table.insert(lines, string.format("   • Canvas: Size = (%d, %d) | CanvasPosition = (%d, %d)",
                obj.CanvasSize.X.Offset, obj.CanvasSize.Y.Offset, obj.CanvasPosition.X, obj.CanvasPosition.Y))
            table.insert(lines, string.format("   • ScrollBar: Thickness = %d | Direction = %s",
                obj.ScrollBarThickness, obj.ScrollingDirection.Name))
        end

    -- 2. INSPECCIÓN DE OBJETOS 3D DEL MUNDO (BasePart / Model)
    elseif obj:IsA("BasePart") then
        table.insert(lines, "\n🧱 [FÍSICAS Y TRANSFORMACIÓN 3D]:")
        table.insert(lines, string.format("   • Posición: Vector3.new(%.2f, %.2f, %.2f)", obj.Position.X, obj.Position.Y, obj.Position.Z))
        table.insert(lines, string.format("   • Dimensiones (Size): Vector3.new(%.2f, %.2f, %.2f)", obj.Size.X, obj.Size.Y, obj.Size.Z))
        table.insert(lines, string.format("   • Orientación: Vector3.new(%.2f, %.2f, %.2f)", obj.Orientation.X, obj.Orientation.Y, obj.Orientation.Z))
        table.insert(lines, string.format("   • Propiedades Físicas: Anchored = %s | CanCollide = %s | CanTouch = %s",
            tostring(obj.Anchored), tostring(obj.CanCollide), tostring(obj.CanTouch)))
        table.insert(lines, string.format("   • Masa de Ensamble (AssemblyMass): %.2f | Masa Part: %.2f", obj.AssemblyMass, obj:GetMass()))
        table.insert(lines, string.format("   • Material: %s | Transparencia = %.2f | Reflectancia = %.2f",
            obj.Material.Name, obj.Transparency, obj.Reflectance))
        table.insert(lines, string.format("   • Color: RGB(%d, %d, %d)",
            math.floor(obj.Color.R * 255), math.floor(obj.Color.G * 255), math.floor(obj.Color.B * 255)))

    -- 3. INTERACCIONES ESPECIALES (ProximityPrompt / ClickDetector / Tool)
    elseif obj:IsA("ProximityPrompt") then
        table.insert(lines, "\n🔘 [PROXIMITY PROMPT INTERACTIVO]:")
        table.insert(lines, string.format("   • ActionText: %q | ObjectText: %q", obj.ActionText, obj.ObjectText))
        table.insert(lines, string.format("   • HoldDuration: %.2fs | MaxActivationDistance: %.1f studs", obj.HoldDuration, obj.MaxActivationDistance))
        table.insert(lines, string.format("   • Tecla (KeyCode): %s | RequiresLineOfSight: %s",
            obj.KeyboardKeyCode and obj.KeyboardKeyCode.Name or "E", tostring(obj.RequiresLineOfSight)))
    elseif obj:IsA("ClickDetector") then
        table.insert(lines, "\n🎯 [CLICK DETECTOR]:")
        table.insert(lines, string.format("   • MaxActivationDistance: %.1f studs | CursorIcon: %q", obj.MaxActivationDistance, obj.CursorIcon))
    elseif obj:IsA("Tool") then
        table.insert(lines, "\n⚔️ [HERRAMIENTA EQUIPABLE (TOOL)]:")
        table.insert(lines, string.format("   • RequiresHandle: %s | CanBeDropped: %s | ToolTip: %q",
            tostring(obj.RequiresHandle), tostring(obj.CanBeDropped), obj.ToolTip))
    elseif obj:IsA("ValueBase") then
        table.insert(lines, "\n💎 [VALUE BASE]:")
        table.insert(lines, string.format("   • Valor (.Value): %s", tostring(obj.Value)))
    end

    -- 4. ATRIBUTOS Y TAGS DE COLLECTIONSERVICE
    local tags = CollectionService:GetTags(obj)
    if #tags > 0 then
        table.insert(lines, string.format("\n🏷️ Tags CollectionService: [%s]", table.concat(tags, ", ")))
    end

    local attrs = obj:GetAttributes()
    if next(attrs) then
        table.insert(lines, "\n📦 Atributos del Objeto:")
        for k, v in pairs(attrs) do
            table.insert(lines, string.format("   • %s = %s", tostring(k), tostring(v)))
        end
    end

    -- 5. CÓDIGO FUENTE SI ES SCRIPT
    if obj:IsA("LuaSourceContainer") then
        table.insert(lines, "\n-- =====================================================================")
        table.insert(lines, "-- 📜 CÓDIGO FUENTE DECOMPILADO:")
        table.insert(lines, "-- =====================================================================")
        table.insert(lines, decompileScriptSource(obj))
    end

    inspectorBox.Text = table.concat(lines, "\n")
end

local function selectTab(tabId)
    activeTab = tabId
    for id, btn in pairs(rightTabButtons) do
        if id == tabId then
            btn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
            btn.TextColor3 = Color3.fromRGB(150, 165, 185)
        end
    end

    if tabId == "Properties" then
        inspectSmartProperties(selectedObjectForInspection)
    elseif tabId == "Code" then
        if selectedObjectForInspection and selectedObjectForInspection:IsA("LuaSourceContainer") then
            inspectorBox.Text = decompileScriptSource(selectedObjectForInspection)
        else
            inspectorBox.Text = "-- El objeto seleccionado no es un script. Selecciona un LocalScript o ModuleScript."
        end
    elseif tabId == "Export" then
        local count = 0
        for _, isSel in pairs(selectedNodes) do if isSel then count = count + 1 end end
        inspectorBox.Text = string.format([=[
=============================================================================
📦 PANEL DE VOLCADO Y EXPORTACIÓN SELECTIVA
=============================================================================
• Total de Nodos Seleccionados en el Árbol: %d objetos
• Presiona '⚡ EXPORTAR SELECCIÓN' para generar el volcado multihilo.
• Presiona '💾 DISCO (.txt)' para escribir directamente en workspace/ de tu ejecutor.
=============================================================================]=], count)
    end
end

for i, t in ipairs(rightTabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #rightTabs, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * (1 / #rightTabs), 2, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    btn.Text = t.Label
    btn.TextColor3 = Color3.fromRGB(150, 165, 185)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.Parent = tabHeader
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    rightTabButtons[t.Id] = btn
    btn.MouseButton1Click:Connect(function() selectTab(t.Id) end)
end
selectTab("Properties")

-- =============================================================================
-- MENÚ CONTEXTUAL DARKDEX (CLIC DERECHO FLOTANTE)
-- =============================================================================
local contextMenu = Instance.new("Frame")
contextMenu.Size = UDim2.new(0, 190, 0, 200)
contextMenu.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
contextMenu.BorderSizePixel = 1
contextMenu.BorderColor3 = Color3.fromRGB(0, 160, 230)
contextMenu.ZIndex = 300
contextMenu.Visible = false
contextMenu.Parent = mainFrame
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 6)

local currentContextObj = nil

local function createMenuOption(text, icon, posY, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 24)
    btn.Position = UDim2.new(0, 4, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
    btn.Text = "  " .. icon .. " " .. text
    btn.TextColor3 = color or Color3.fromRGB(225, 235, 245)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 301
    btn.Parent = contextMenu
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
        btn.TextColor3 = color or Color3.fromRGB(225, 235, 245)
    end)
    btn.MouseButton1Click:Connect(function()
        contextMenu.Visible = false
        if currentContextObj then callback(currentContextObj) end
    end)
end

createMenuOption("Copiar Ruta", "📋", 4, function(obj)
    local path = obj:GetFullName()
    if safeSetClipboard(path) then
        treeStatusLabel.Text = "📋 Ruta copiada: " .. path
    end
end)

createMenuOption("Copiar Código", "📜", 32, function(obj)
    local src = decompileScriptSource(obj)
    if safeSetClipboard(src) then
        treeStatusLabel.Text = string.format("📜 Código de '%s' copiado (%d bytes).", obj.Name, #src)
    end
end)

createMenuOption("Inspeccionar", "🔍", 60, function(obj)
    inspectSmartProperties(obj)
    selectTab("Properties")
end)

createMenuOption("Duplicar / Clonar", "🧬", 88, function(obj)
    local s, cloned = pcall(function() return obj:Clone() end)
    if s and cloned then
        cloned.Name = obj.Name .. "_Clone"
        cloned.Parent = obj.Parent or Workspace
        treeStatusLabel.Text = "🧬 Clonado: " .. cloned.Name
    else
        treeStatusLabel.Text = "❌ No clonable"
    end
end)

createMenuOption("Eliminar Objeto", "🗑️", 116, function(obj)
    local name = obj.Name
    local s, err = pcall(function() obj:Destroy() end)
    if s then
        treeStatusLabel.Text = string.format("🗑️ Objeto '%s' eliminado.", name)
        selectedObjectForInspection = nil
        inspectorBox.Text = "-- Objeto eliminado."
    else
        treeStatusLabel.Text = "Error al destruir: " .. tostring(err)
    end
end, Color3.fromRGB(255, 100, 100))

createMenuOption("Seleccionar Rama", "✓", 144, function(obj)
    selectedNodes[obj] = true
    local s, c = pcall(function() return obj:GetDescendants() end)
    if s and c then for _, d in ipairs(c) do selectedNodes[d] = true end end
    updateStatus()
end, Color3.fromRGB(0, 230, 140))

createMenuOption("Guardar a Archivo", "💾", 172, function(obj)
    if typeof(writefile) == "function" then
        local src = obj:IsA("LuaSourceContainer") and decompileScriptSource(obj) or obj:GetFullName()
        local fname = obj.Name:gsub("[^%w_%-]", "_") .. ".txt"
        pcall(function() writefile(fname, src) end)
        treeStatusLabel.Text = "💾 Guardado como " .. fname
    end
end)

local function openContextMenu(obj, inputPos)
    if not obj then return end
    currentContextObj = obj
    selectedObjectForInspection = obj
    local mousePos = inputPos or UserInputService:GetMouseLocation()
    local framePos = mainFrame.AbsolutePosition
    local localX = math.clamp(mousePos.X - framePos.X + 4, 10, math.max(10, mainFrame.AbsoluteSize.X - 200))
    local localY = math.clamp(mousePos.Y - framePos.Y + 4, 10, math.max(10, mainFrame.AbsoluteSize.Y - 210))
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

-- =============================================================================
-- PICKER DE OBJETOS 2D (GUI) Y 3D (WORKSPACE)
-- =============================================================================
local isPickerActive = false
local pickerConn = nil

local function togglePicker()
    isPickerActive = not isPickerActive
    if isPickerActive then
        pickerBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 110)
        pickerBtn.Text = "🎯 ACTIVO"
        treeStatusLabel.Text = "🎯 Haz clic en cualquier elemento 2D (GUI) o 3D (Workspace)..."

        if pickerConn then pickerConn:Disconnect() end
        pickerConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local mousePos = UserInputService:GetMouseLocation()
                local targetInst = nil

                -- 1. Buscar en PlayerGui
                pcall(function()
                    local lp = Players.LocalPlayer
                    if lp and lp:FindFirstChild("PlayerGui") then
                        local guiObjects = lp.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
                        for _, guiObj in ipairs(guiObjects) do
                            if not guiObj:IsDescendantOf(screenGui) and not guiObj:IsDescendantOf(mainFrame) then
                                targetInst = guiObj
                                break
                            end
                        end
                    end
                end)

                -- 2. Buscar en Workspace 3D
                if not targetInst then
                    pcall(function()
                        local cam = Workspace.CurrentCamera
                        if cam then
                            local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
                            local lp = Players.LocalPlayer
                            local params = RaycastParams.new()
                            params.FilterType = RaycastFilterType.Exclude
                            if lp and lp.Character then params.FilterDescendantsInstances = { lp.Character } end
                            local result = Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
                            if result and result.Instance then targetInst = result.Instance end
                        end
                    end)
                end

                if targetInst then
                    local curr = targetInst.Parent
                    while curr and curr ~= game do
                        expandedNodes[curr] = true
                        curr = curr.Parent
                    end
                    selectedNodes[targetInst] = true
                    inspectSmartProperties(targetInst)
                    selectTab("Properties")
                    treeStatusLabel.Text = string.format("🎯 Objeto detectado: %s (%s)", targetInst.Name, targetInst.ClassName)
                    togglePicker()
                end
            end
        end)
    else
        pickerBtn.BackgroundColor3 = Color3.fromRGB(30, 95, 155)
        pickerBtn.Text = "🎯 PICKER"
        if pickerConn then
            pickerConn:Disconnect()
            pickerConn = nil
        end
    end
end
pickerBtn.MouseButton1Click:Connect(togglePicker)

-- =============================================================================
-- RENDERIZADO DEL ÁRBOL VIRTUAL
-- =============================================================================
local function updateVisibleTree()
    local canvasY = treeScroll.CanvasPosition.Y
    local startIndex = math.max(1, math.floor(canvasY / ROW_HEIGHT) + 1)
    
    for i = 1, VISIBLE_ROWS do
        local rowDataIndex = startIndex + i - 1
        local data = flatTree[rowDataIndex]
        local frame = uiRows[i]
        
        if data then
            frame.Frame.Visible = true
            frame.Frame.Position = UDim2.new(0, 0, 0, (rowDataIndex - 1) * ROW_HEIGHT)
            
            local xOffset = data.depth * INDENT_SIZE
            frame.ExpandBtn.Position = UDim2.new(0, xOffset, 0, 3)
            frame.CheckBtn.Position = UDim2.new(0, xOffset + 18, 0, 3)
            
            frame.NameLabel.Position = UDim2.new(0, xOffset + 38, 0, 0)
            frame.NameLabel.Size = UDim2.new(1, -(xOffset + 60), 1, 0)
            
            if isSearching then
                frame.NameLabel.Text = data.obj:GetFullName()
            else
                frame.NameLabel.Text = data.obj.Name
            end
            
            frame.ExpandBtn.Text = data.hasChildren and (data.isExpanded and "-" or "+") or ""
            frame.CheckBtn.Text = selectedNodes[data.obj] and "✓" or ""
            frame.CheckBtn.TextColor3 = selectedNodes[data.obj] and Color3.fromRGB(0, 230, 140) or Color3.fromRGB(150, 150, 150)
            
            frame.NodeObj = data.obj
        else
            frame.Frame.Visible = false
        end
    end
end

local function rebuildFlatTree()
    table.clear(flatTree)
    
    if isSearching then
        for _, obj in ipairs(searchResults) do
            table.insert(flatTree, { obj = obj, depth = 0, hasChildren = false, isExpanded = false })
        end
    else
        local function traverse(nodeList, depth)
            for _, obj in ipairs(nodeList) do
                if obj.Name ~= "CorePackages" and obj.Name ~= "Terrain" then
                    local isExpanded = expandedNodes[obj] or false
                    local hasChild = hasChildrenSafe(obj)
                    
                    table.insert(flatTree, {
                        obj = obj,
                        depth = depth,
                        hasChildren = hasChild,
                        isExpanded = isExpanded
                    })
                    
                    if isExpanded and hasChild then
                        traverse(getChildrenSafe(obj), depth + 1)
                    end
                end
            end
        end
        traverse(rootNodes, 0)
    end
    
    treeScroll.CanvasSize = UDim2.new(0, 2000, 0, #flatTree * ROW_HEIGHT)
    task.defer(updateVisibleTree)
end

local function performSearch(query)
    query = query:lower()
    searchId = searchId + 1
    local currentSearchId = searchId
    table.clear(searchResults)
    
    if query == "" then
        isSearching = false
        searchBtn.Text = "🔍"
        rebuildFlatTree()
        return
    end
    
    isSearching = true
    searchBtn.Text = "..."
    
    task.spawn(function()
        local processed = 0
        local function checkNode(node)
            local sName, name = pcall(function() return node.Name:lower() end)
            local sClass, className = pcall(function() return node.ClassName:lower() end)
            if sName and sClass then
                if string.find(name, query, 1, true) or string.find(className, query, 1, true) then
                    table.insert(searchResults, node)
                end
            end
        end

        local s, descendants = pcall(function() return game:GetDescendants() end)
        if s and descendants then
            for _, child in ipairs(descendants) do
                if searchId ~= currentSearchId then return end
                processed = processed + 1
                if processed % 5000 == 0 then task.wait() end
                checkNode(child)
            end
        end
        
        if searchId == currentSearchId then
            searchBtn.Text = "🔍"
            rebuildFlatTree()
        end
    end)
end

searchBtn.MouseButton1Click:Connect(function() performSearch(searchBox.Text) end)
searchBox.FocusLost:Connect(function(enter) if enter then performSearch(searchBox.Text) end end)

-- Pool de Filas UI Reutilizables
for i = 1, VISIBLE_ROWS do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
    row.BackgroundTransparency = 1
    row.Visible = false
    
    local expandBtn = Instance.new("TextButton")
    expandBtn.Size = UDim2.new(0, 15, 0, 15)
    expandBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    expandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    expandBtn.Font = Enum.Font.Code
    expandBtn.TextSize = 12
    expandBtn.Parent = row
    Instance.new("UICorner", expandBtn).CornerRadius = UDim.new(0, 3)
    
    local checkBtn = Instance.new("TextButton")
    checkBtn.Size = UDim2.new(0, 15, 0, 15)
    checkBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
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

    local moreBtn = Instance.new("TextButton")
    moreBtn.Size = UDim2.new(0, 18, 0, 16)
    moreBtn.Position = UDim2.new(1, -20, 0, 3)
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
        MoreBtn = moreBtn,
        NodeObj = nil
    }
    
    expandBtn.MouseButton1Click:Connect(function()
        local obj = frameData.NodeObj
        if obj and hasChildrenSafe(obj) then
            expandedNodes[obj] = not expandedNodes[obj]
            rebuildFlatTree()
        end
    end)
    
    nameLabel.MouseButton1Click:Connect(function()
        local obj = frameData.NodeObj
        if obj then
            inspectSmartProperties(obj)
            selectTab("Properties")
        end
    end)

    nameLabel.MouseButton2Click:Connect(function()
        openContextMenu(frameData.NodeObj)
    end)

    moreBtn.MouseButton1Click:Connect(function()
        openContextMenu(frameData.NodeObj)
    end)
    
    checkBtn.MouseButton1Click:Connect(function()
        local obj = frameData.NodeObj
        if obj then
            if selectedNodes[obj] then selectedNodes[obj] = nil else selectedNodes[obj] = true end
            updateVisibleTree()
            updateStatus()
        end
    end)
    
    row.Parent = treeScroll
    table.insert(uiRows, frameData)
end

treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleTree)

-- Botones de Selección Rápida
btnSelectAll.MouseButton1Click:Connect(function()
    for _, item in ipairs(flatTree) do selectedNodes[item.obj] = true end
    updateVisibleTree()
    updateStatus()
end)

btnSelectDesc.MouseButton1Click:Connect(function()
    local toAdd = {}
    for obj, isSel in pairs(selectedNodes) do
        if isSel then
            local s, desc = pcall(function() return obj:GetDescendants() end)
            if s and desc then for _, d in ipairs(desc) do toAdd[d] = true end end
        end
    end
    for d, _ in pairs(toAdd) do selectedNodes[d] = true end
    updateVisibleTree()
    updateStatus()
end)

btnClearSel.MouseButton1Click:Connect(function()
    table.clear(selectedNodes)
    updateVisibleTree()
    updateStatus()
end)

-- Inicializar Nodos Raíz
local success, children = pcall(function() return game:GetChildren() end)
if success and children then
    rootNodes = children
else
    local commonServices = {"Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "CoreGui", "StarterGui", "StarterPack", "StarterPlayer", "SoundService"}
    for _, sName in ipairs(commonServices) do
        pcall(function()
            local srv = game:GetService(sName)
            if srv then table.insert(rootNodes, srv) end
        end)
    end
end
rebuildFlatTree()

-- =============================================================================
-- MOTOR DE VOLCADO SELECTIVO MULTIHILO
-- =============================================================================
local isDumping = false

local function runSelectiveDump(exportToDisk)
    if isDumping then return end

    local hasSelection = false
    for _, isSelected in pairs(selectedNodes) do if isSelected then hasSelection = true break end end

    if not hasSelection then
        inspectorBox.Text = "⚠️ Error: No has seleccionado ningún objeto en el árbol para volcar."
        return
    end

    isDumping = true
    btnExportDump.Text = "⏳ VOLCANDO..."
    btnExportDump.BackgroundColor3 = Color3.fromRGB(240, 140, 40)

    modalTitle.Text = "📦 VOLCADO SELECTIVO MULTIHILO"
    modalPctLabel.Text = "0%"
    modalFill.Size = UDim2.new(0, 0, 1, 0)
    modalCounter.Text = "Procesados: [0 / 0] Elementos"
    modalCurrentItem.Text = "  Descargando API Dump de Roblox..."
    progressOverlay.Visible = true

    task.spawn(function()
        local startTime = tick()

        -- 1. Descargar API Dump de Roblox para resolución de propiedades
        local success, version = pcall(function() return game:HttpGet("http://setup.roblox.com/versionQTStudio") end)
        version = (success and version) and version:gsub("%s+", "") or "version-0b83e4a36f6d45e4"
        
        local apiSuccess, apiJson = pcall(function() return game:HttpGet("http://setup.roblox.com/" .. version .. "-API-Dump.json") end)
        local resolvedClasses = {}

        if apiSuccess and apiJson then
            local pSuccess, apiData = pcall(function() return HttpService:JSONDecode(apiJson) end)
            if pSuccess and apiData and apiData.Classes then
                local classes = {}
                for _, classData in ipairs(apiData.Classes) do
                    local props = {}
                    for _, member in ipairs(classData.Members) do
                        if member.MemberType == "Property" and (member.Security and member.Security.Read == "None") then
                            local tags = member.Tags or {}
                            if not table.find(tags, "Hidden") and not table.find(tags, "NotScriptable") then
                                table.insert(props, member.Name)
                            end
                        end
                    end
                    classes[classData.Name] = { Superclass = classData.Superclass, Properties = props }
                end
                for className, _ in pairs(classes) do
                    local props = {}
                    local current = classes[className]
                    while current do
                        for _, prop in ipairs(current.Properties) do table.insert(props, prop) end
                        if current.Superclass == "<<<ROOT>>>" then break end
                        current = classes[current.Superclass]
                    end
                    resolvedClasses[className] = props
                end
            end
        end

        -- 2. Serializador de Instancia
        local function serializeInstance(inst, depth)
            local className = inst.ClassName
            local indent = string.rep("  ", depth)
            local lines = { indent .. "-> [" .. className .. "] " .. inst.Name }
            local props = resolvedClasses[className]

            if props then
                for _, propName in ipairs(props) do
                    if propName ~= "Parent" and propName ~= "Name" then
                        local ok, val = pcall(function() return inst[propName] end)
                        if ok and val ~= nil then
                            table.insert(lines, indent .. "    ." .. propName .. " = " .. tostring(val))
                        end
                    end
                end
            end

            if inst:IsA("LuaSourceContainer") then
                table.insert(lines, indent .. "    [CÓDIGO FUENTE]:")
                table.insert(lines, decompileScriptSource(inst))
            end
            return table.concat(lines, "\n") .. "\n"
        end

        -- 3. Cola y Procesamiento Concurrente
        local queue = {}
        local function addNodeToQueue(node, depth)
            table.insert(queue, { node = node, depth = depth })
            local s, c = pcall(function() return node:GetChildren() end)
            if s and c then
                for _, child in ipairs(c) do addNodeToQueue(child, depth + 1) end
            end
        end

        for obj, isSelected in pairs(selectedNodes) do
            if isSelected then addNodeToQueue(obj, 0) end
        end

        local totalToProcess = #queue
        local totalProcessed = 0
        local activeWorkers = 0
        local MAX_WORKERS = 8
        local allDataBuffer = {}
        local fileName = "SelectiveDump_" .. os.time() .. ".txt"

        local function processQueue()
            while #queue > 0 do
                local item = table.remove(queue, 1)
                if item then
                    local node = item.node
                    local depth = item.depth
                    pcall(function()
                        local serializedData = serializeInstance(node, depth)
                        totalProcessed = totalProcessed + 1
                        table.insert(allDataBuffer, serializedData)
                    end)

                    if totalProcessed % 10 == 0 then
                        local elapsed = tick() - startTime
                        local speed = totalProcessed / math.max(elapsed, 0.001)
                        local eta = (totalToProcess > totalProcessed and speed > 0) and ((totalToProcess - totalProcessed) / speed) or 0
                        local pct = math.clamp(totalProcessed / totalToProcess, 0, 1)

                        modalPctLabel.Text = string.format("%d%%", math.floor(pct * 100))
                        modalFill.Size = UDim2.new(pct, 0, 1, 0)
                        modalCounter.Text = string.format("Procesados: [%d / %d] Elementos", totalProcessed, totalToProcess)
                        modalMetrics.Text = string.format("⏱️ %.1fs | ⏳ ETA: ~%.1fs | ⚡ %.0f ops/s", elapsed, eta, speed)
                        modalCurrentItem.Text = "  📄 " .. tostring(node.Name)
                    end
                end
                task.wait()
            end
            activeWorkers = activeWorkers - 1
        end

        for i = 1, MAX_WORKERS do
            activeWorkers = activeWorkers + 1
            task.spawn(processQueue)
        end

        while activeWorkers > 0 do task.wait(0.05) end

        local finalDumpText = "-- [[ APEX SUITE - SELECTIVE API-DRIVEN GAME DUMP ]] --\n\n" .. table.concat(allDataBuffer, "")
        local duration = tick() - startTime

        if exportToDisk and typeof(writefile) == "function" then
            pcall(function() writefile(fileName, finalDumpText) end)
            treeStatusLabel.Text = string.format("💾 Guardado en disco: %s (%.2fs)", fileName, duration)
        end

        selectTab("Export")
        inspectorBox.Text = finalDumpText

        modalPctLabel.Text = "100%"
        modalFill.Size = UDim2.new(1, 0, 1, 0)
        modalCounter.Text = string.format("✅ ¡COMPLETADO! Total: %d objetos en %.2fs", totalProcessed, duration)
        modalCurrentItem.Text = "  ✅ Volcado selectivo listo."

        btnExportDump.Text = "⚡ EXPORTAR SELECCIÓN"
        btnExportDump.BackgroundColor3 = Color3.fromRGB(0, 155, 115)

        task.wait(1.2)
        progressOverlay.Visible = false
        isDumping = false
    end)
end

btnExportDump.MouseButton1Click:Connect(function() runSelectiveDump(false) end)
btnSaveDisk.MouseButton1Click:Connect(function() runSelectiveDump(true) end)
btnCopyCode.MouseButton1Click:Connect(function()
    if safeSetClipboard(inspectorBox.Text) then
        btnCopyCode.Text = "✅ ¡COPIADO!"
        task.delay(1.5, function() btnCopyCode.Text = "📋 COPIAR TEXTO" end)
    end
end)

-- Grip Handle de Redimensionamiento
local resizeGrip = Instance.new("TextButton")
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
local resizeStartMouse, resizeStartSize

resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        resizeStartMouse = Vector2.new(input.Position.X, input.Position.Y)
        resizeStartSize = Vector2.new(mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStartMouse
        local newWidth = math.clamp(resizeStartSize.X + delta.X, 700, 1600)
        local newHeight = math.clamp(resizeStartSize.Y + delta.Y, 400, 1000)
        mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

return screenGui

