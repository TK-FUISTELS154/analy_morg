--[[
    GUERRA DE BLOQUES — v5
    Nivel 3: Sin hookmetamethod / hookfunction
    Autor: TK · Refactor: Antigravity AI
    ─────────────────────────────────────────
    LMB / RMB  → apuntar
    F          → panel config
    DEL        → apagar
]]

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 1 · NÚCLEO SECURI v3 (NIVEL 3)
-- ══════════════════════════════════════════════════════════════════

local function safeCloneref(obj)
    if cloneref then
        local ok, r = pcall(cloneref, obj)
        if ok and r then return r end
    end
    return obj
end

local Securi = {}
Securi._randName = tostring({}):sub(8)  -- nombre único por sesión

-- ── Servicios (cloneref + caché) ──────────────────────────────────
do
    local cache = {}
    local gs    = safeCloneref(game:GetService("RunService") and game)
    setmetatable(Securi, {
        __index = function(_, k)
            if cache[k] then return cache[k] end
            local ok, svc = pcall(function() return safeCloneref(game:GetService(k)) end)
            if ok and svc then cache[k] = svc return svc end
        end
    })
    Securi._gs = gs
end

function Securi:GetLocalPlayer()
    return self.Players and self.Players.LocalPlayer
end

-- ── Hilos seguros ─────────────────────────────────────────────────
Securi.Thread = {}
function Securi.Thread.Spawn(fn, ...)
    local args = {...}
    task.spawn(function() pcall(fn, table.unpack(args)) end)
end
function Securi.Thread.Safe(fn, ...)
    return pcall(fn, ...)
end

-- ── GUI protegida ─────────────────────────────────────────────────
Securi.GUI = {}
function Securi.GUI:Create(name, props)
    local sg = Instance.new("ScreenGui")
    sg.Name            = name or Securi._randName
    sg.ResetOnSpawn    = false
    sg.IgnoreGuiInset  = true
    sg.DisplayOrder    = 999
    for k, v in pairs(props or {}) do sg[k] = v end

    -- intentar proteger
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, sg)
        sg.Parent = safeCloneref(game:GetService("CoreGui"))
    elseif gethui then
        sg.Parent = gethui()
    else
        local ok = pcall(function()
            sg.Parent = safeCloneref(game:GetService("CoreGui"))
        end)
        if not ok then sg.Parent = Securi:GetLocalPlayer() and Securi:GetLocalPlayer():FindFirstChildOfClass("PlayerGui") end
    end
    return sg
end

-- ── Almacenamiento persistente ────────────────────────────────────
Securi.Storage = {}
local _storeKey = "GDB_CFG_v5_" .. Securi._randName:sub(1,4)
function Securi.Storage:Save(data)
    if writefile then
        pcall(writefile, _storeKey..".json", game:GetService("HttpService"):JSONEncode(data))
    end
end
function Securi.Storage:Load()
    if readfile and isfile and isfile(_storeKey..".json") then
        local ok, raw = pcall(readfile, _storeKey..".json")
        if ok and raw and raw ~= "" then
            local ok2, t = pcall(function()
                return game:GetService("HttpService"):JSONDecode(raw)
            end)
            if ok2 and type(t) == "table" then return t end
        end
    end
    return nil
end

-- Registrar en genv
local genv = getgenv and getgenv() or _G
genv.__GDB_v5 = Securi

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 2 · SERVICIOS + CONFIG
-- ══════════════════════════════════════════════════════════════════

local Players        = safeCloneref(game:GetService("Players"))
local RunService     = safeCloneref(game:GetService("RunService"))
local UserInputService = safeCloneref(game:GetService("UserInputService"))
local Workspace      = safeCloneref(game:GetService("Workspace"))
local LocalPlayer    = Players.LocalPlayer
local Camera         = Workspace.CurrentCamera

-- Constantes de equipo
local TEAM1_ACC = "Accessory (Keffiyeh_3)"
local TEAM2_ACC = "Accessory (Afrika Balaklava)"
local LIVE_FOLDER_NAME = "Live"

-- Config por defecto
local DEFAULT = {
    FOV           = 120,
    SPEED         = 0.18,       -- lerp aim
    OFF_X         = 0,
    OFF_Y         = -0.15,
    MAX_DIST      = 500,
    AIM_LMB       = true,
    AIM_RMB       = true,
    WALL_CHECK    = true,
    TARGET_PART   = "Head",     -- "Head" | "HumanoidRootPart"
}

-- Cargar/fusionar config guardada
local saved = Securi.Storage:Load()
if type(saved) == "table" then
    for k, v in pairs(saved) do
        if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then
            DEFAULT[k] = v
        end
    end
end
local CFG = DEFAULT

local function SaveConfig()
    Securi.Storage:Save(CFG)
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 3 · ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════════

local aimPressCount = 0
local conns         = {}
local espCache      = {}   -- [char] = { billboard, boxStroke, nameLabel, distLabel, hpFill }
local renderName    = "GDB_Render_" .. Securi._randName

local function isAiming()
    return aimPressCount > 0
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 4 · GUI PROTEGIDA
-- ══════════════════════════════════════════════════════════════════

local gui = Securi.GUI:Create("GDB_UI")

-- Carpeta ESP
local espFolder = Instance.new("Folder")
espFolder.Name   = "ESPFolder"
espFolder.Parent = gui

-- ── Helper: crear label limpio ────────────────────────────────────
local function mkLabel(parent, props)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.new(1,1,1)
    lbl.Font        = Enum.Font.GothamBold
    lbl.TextSize    = 14
    lbl.Text        = ""
    lbl.ZIndex      = 10
    for k,v in pairs(props or {}) do lbl[k] = v end
    lbl.Parent = parent
    return lbl
end

local function mkFrame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = Color3.fromRGB(15,15,20)
    f.BorderSizePixel  = 0
    f.ZIndex           = 5
    for k,v in pairs(props or {}) do f[k] = v end
    f.Parent = parent
    return f
end

local function mkButton(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = Color3.fromRGB(40,40,50)
    b.BorderSizePixel  = 0
    b.TextColor3       = Color3.new(1,1,1)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.AutoButtonColor  = false
    b.ZIndex           = 11
    for k,v in pairs(props or {}) do b[k] = v end
    b.Parent = parent
    return b
end

local function mkSeparator(parent, yPos)
    local sep = mkLabel(parent, {
        Size = UDim2.new(1,-16,0,12),
        Position = UDim2.new(0,8,0,yPos),
        Text = "──────────────────────────",
        TextColor3 = Color3.fromRGB(60,60,80),
        TextSize = 11,
        Font = Enum.Font.Gotham,
    })
    return sep
end

-- ── Punto central (blanco / rojo activo) ──────────────────────────
local centerDot = Instance.new("Frame")
centerDot.Size              = UDim2.new(0,6,0,6)
centerDot.AnchorPoint       = Vector2.new(0.5,0.5)
centerDot.BackgroundColor3  = Color3.new(1,1,1)
centerDot.BorderSizePixel   = 0
centerDot.ZIndex            = 20
centerDot.Parent            = gui
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1,0)

-- ── Círculo FOV ───────────────────────────────────────────────────
local fovFrame = Instance.new("Frame")
fovFrame.Size              = UDim2.new(0,0,0,0)
fovFrame.AnchorPoint       = Vector2.new(0.5,0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.ZIndex            = 15
fovFrame.Parent            = gui
local fovStroke = Instance.new("UICorner", fovFrame)
fovStroke.CornerRadius = UDim.new(1,0)
local fovOutline = Instance.new("UIStroke", fovFrame)
fovOutline.Color     = Color3.fromRGB(255,220,0)
fovOutline.Thickness = 1.2
fovOutline.Transparency = 0.35

-- ── Etiqueta de estado (arriba-izquierda) ─────────────────────────
local stateLabel = mkLabel(gui, {
    Size     = UDim2.new(0,180,0,28),
    Position = UDim2.new(0,10,0,10),
    Text     = "🎯 AIM: OFF",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(160,160,180),
    TextSize = 13,
    ZIndex = 20,
})

local targetLabel = mkLabel(gui, {
    Size     = UDim2.new(0,220,0,22),
    Position = UDim2.new(0,10,0,36),
    Text     = "",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(0,200,255),
    TextSize = 12,
    ZIndex = 20,
})

local function updateStateLabel(active, name)
    if active then
        stateLabel.Text      = "🎯 AIM: ACTIVO"
        stateLabel.TextColor3 = Color3.fromRGB(80,255,120)
        centerDot.BackgroundColor3 = Color3.fromRGB(255,60,60)
    else
        stateLabel.Text      = "🎯 AIM: OFF"
        stateLabel.TextColor3 = Color3.fromRGB(160,160,180)
        centerDot.BackgroundColor3 = Color3.new(1,1,1)
    end
    targetLabel.Text = name and ("▶ "..name) or ""
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 4b · PANEL DE CONFIGURACIÓN
-- ══════════════════════════════════════════════════════════════════

local PANEL_W, PANEL_H = 300, 420
local cfgPanel = mkFrame(gui, {
    Size     = UDim2.new(0,PANEL_W,0,PANEL_H),
    Position = UDim2.new(0.5,-PANEL_W/2, 0.5,-PANEL_H/2),
    BackgroundColor3 = Color3.fromRGB(12,12,18),
    Visible  = false,
    ZIndex   = 30,
})
local panelCorner = Instance.new("UICorner", cfgPanel)
panelCorner.CornerRadius = UDim.new(0,10)
local panelStroke = Instance.new("UIStroke", cfgPanel)
panelStroke.Color     = Color3.fromRGB(60,60,100)
panelStroke.Thickness = 1.5

-- Título
mkLabel(cfgPanel, {
    Size = UDim2.new(1,-16,0,32),
    Position = UDim2.new(0,8,0,8),
    Text = "⚔  GUERRA DE BLOQUES",
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255,220,60),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 32,
})
mkLabel(cfgPanel, {
    Size = UDim2.new(1,-16,0,18),
    Position = UDim2.new(0,8,0,38),
    Text = "v5  ·  Nivel 3  ·  [F] cerrar  [DEL] apagar",
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(90,90,120),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 32,
})
mkSeparator(cfgPanel, 60)

-- ── Creador de fila input ──────────────────────────────────────────
local inputRows = {}
local function addInputRow(label, cfgKey, yPos, isNum)
    mkLabel(cfgPanel, {
        Size = UDim2.new(0,130,0,22),
        Position = UDim2.new(0,12, 0, yPos),
        Text = label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        ZIndex = 32,
    })
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0,110,0,22)
    box.Position = UDim2.new(0, 170, 0, yPos)
    box.BackgroundColor3 = Color3.fromRGB(25,25,38)
    box.BorderSizePixel = 0
    box.TextColor3 = Color3.fromRGB(220,220,255)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.Text = tostring(CFG[cfgKey])
    box.PlaceholderText = tostring(DEFAULT[cfgKey])
    box.ClearTextOnFocus = false
    box.ZIndex = 33
    box.Parent = cfgPanel
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,5)
    inputRows[cfgKey] = box
    return box
end

-- ── Creador de toggle ──────────────────────────────────────────────
local toggleRows = {}
local function addToggleRow(label, cfgKey, yPos)
    mkLabel(cfgPanel, {
        Size = UDim2.new(0,160,0,22),
        Position = UDim2.new(0,12, 0, yPos),
        Text = label,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12,
        ZIndex = 32,
    })
    local btn = mkButton(cfgPanel, {
        Size = UDim2.new(0,80,0,22),
        Position = UDim2.new(0,200, 0, yPos),
        Text = CFG[cfgKey] and "✓ SÍ" or "✗ NO",
        TextColor3 = CFG[cfgKey] and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,80,80),
        ZIndex = 33,
    })
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    toggleRows[cfgKey] = btn
    return btn
end

-- Filas numéricas
mkLabel(cfgPanel, {
    Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,74),
    Text="PUNTERÍA", TextSize=11, Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(255,180,60), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=32,
})
addInputRow("FOV  (px)",         "FOV",      94,  true)
addInputRow("Velocidad lerp",    "SPEED",    120, true)
addInputRow("Desplaz. X",        "OFF_X",    146, true)
addInputRow("Desplaz. Y",        "OFF_Y",    172, true)
addInputRow("Dist. máxima (m)",  "MAX_DIST", 198, true)
mkSeparator(cfgPanel, 224)

mkLabel(cfgPanel, {
    Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,238),
    Text="OPCIONES", TextSize=11, Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(180,100,255), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=32,
})
addToggleRow("LMB activa aim",   "AIM_LMB",    260)
addToggleRow("RMB activa aim",   "AIM_RMB",    286)
addToggleRow("Chequeo de pared", "WALL_CHECK", 312)
mkSeparator(cfgPanel, 342)

-- Botón parte objetivo
local partBtn = mkButton(cfgPanel, {
    Size = UDim2.new(1,-24,0,26),
    Position = UDim2.new(0,12, 0, 358),
    Text = "Parte: "..CFG.TARGET_PART,
    TextSize = 12,
    ZIndex = 33,
})
Instance.new("UICorner", partBtn).CornerRadius = UDim.new(0,5)
partBtn.MouseButton1Click:Connect(function()
    CFG.TARGET_PART = CFG.TARGET_PART == "Head" and "HumanoidRootPart" or "Head"
    partBtn.Text = "Parte: "..CFG.TARGET_PART
    SaveConfig()
end)

-- Botón cerrar
local closeBtn = mkButton(cfgPanel, {
    Size = UDim2.new(0,80,0,26),
    Position = UDim2.new(1,-92, 1,-36),
    Text = "✕ Cerrar",
    BackgroundColor3 = Color3.fromRGB(160,30,30),
    TextSize = 12,
    ZIndex = 34,
})
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,5)
closeBtn.MouseButton1Click:Connect(function()
    cfgPanel.Visible = false
end)

-- Arrastrar panel
do
    local dragging, dragStart, startPos
    cfgPanel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = cfgPanel.Position
        end
    end)
    cfgPanel.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    cfgPanel.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            cfgPanel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 5 · LÓGICA DE EQUIPOS + ESTADO
-- ══════════════════════════════════════════════════════════════════

local function getTeam(char)
    if not char then return nil end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            if acc.Name == TEAM1_ACC then return 1 end
            if acc.Name == TEAM2_ACC then return 2 end
        end
    end
    return 0
end

local function isAlive(char, hum, root)
    if not char or not hum or not root then return false end
    if not hum.Parent then return false end
    if hum.Health <= 0 then return false end
    return true
end

local function getTargetPart(char)
    if not char then return nil end
    local part = char:FindFirstChild(CFG.TARGET_PART)
    if not part and CFG.TARGET_PART == "Head" then
        part = char:FindFirstChild("HumanoidRootPart")
    end
    return part
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 6 · VISIBILIDAD
-- ══════════════════════════════════════════════════════════════════

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude

local function isVisible(targetPart, targetChar, myChar)
    if not CFG.WALL_CHECK then return true end
    if not targetPart or not myChar then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    rayP.FilterDescendantsInstances = {myChar, targetChar}
    local result = Workspace:Raycast(origin, direction, rayP)
    if not result then return true end
    -- hit algo que pertenece al targetChar → visible
    local hit = result.Instance
    local parent = hit.Parent
    return parent == targetChar or (parent and parent.Parent == targetChar)
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 8 · ESP
-- ══════════════════════════════════════════════════════════════════

local function clearESP(char)
    local e = espCache[char]
    if e then
        for _, inst in pairs(e) do
            if typeof(inst) == "Instance" and inst.Parent then
                inst:Destroy()
            end
        end
        espCache[char] = nil
    end
end

local function makeOrUpdateESP(char, hum, root, myRootPos, myChar)
    if char == myChar then return end

    local dist = (root.Position - myRootPos).Magnitude
    if dist > CFG.MAX_DIST then
        clearESP(char)
        return
    end

    -- Crear entry si no existe
    if not espCache[char] then
        local entry = {}

        local billboard = Instance.new("BillboardGui")
        billboard.Name           = "GDB_ESP_"..char.Name
        billboard.Adornee        = root
        billboard.Size           = UDim2.new(0,60,0,70)
        billboard.StudsOffset    = Vector3.new(0,2.5,0)
        billboard.AlwaysOnTop    = true
        billboard.ResetOnSpawn   = false
        billboard.Parent         = espFolder

        local box = Instance.new("Frame", billboard)
        box.Size                 = UDim2.new(1,0,1,0)
        box.BackgroundTransparency = 1
        box.BorderSizePixel      = 0
        local boxStroke = Instance.new("UIStroke", box)
        boxStroke.Thickness = 1.5

        local nameLabel = Instance.new("TextLabel", billboard)
        nameLabel.Size              = UDim2.new(1,0,0,16)
        nameLabel.Position          = UDim2.new(0,0,0,-18)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font              = Enum.Font.GothamBold
        nameLabel.TextSize          = 11
        nameLabel.TextStrokeTransparency = 0.5

        local distLabel = Instance.new("TextLabel", billboard)
        distLabel.Size              = UDim2.new(1,0,0,14)
        distLabel.Position          = UDim2.new(0,0,1,2)
        distLabel.BackgroundTransparency = 1
        distLabel.Font              = Enum.Font.Gotham
        distLabel.TextSize          = 10
        distLabel.TextStrokeTransparency = 0.5

        local hpBar = Instance.new("Frame", billboard)
        hpBar.Size               = UDim2.new(0,4,1,0)
        hpBar.Position           = UDim2.new(1,3,0,0)
        hpBar.BackgroundColor3   = Color3.fromRGB(40,40,40)
        hpBar.BorderSizePixel    = 0
        local hpFill = Instance.new("Frame", hpBar)
        hpFill.Size              = UDim2.new(1,0,1,0)
        hpFill.AnchorPoint       = Vector2.new(0,1)
        hpFill.Position          = UDim2.new(0,0,1,0)
        hpFill.BackgroundColor3  = Color3.fromRGB(80,255,100)
        hpFill.BorderSizePixel   = 0

        entry.billboard = billboard
        entry.boxStroke = boxStroke
        entry.nameLabel = nameLabel
        entry.distLabel = distLabel
        entry.hpFill    = hpFill
        espCache[char]  = entry
    end

    local e = espCache[char]
    local hp    = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    local isEnemy = getTeam(char) ~= getTeam(myChar)
    local color = isEnemy and Color3.fromRGB(255,60,60) or Color3.fromRGB(60,180,255)

    e.boxStroke.Color    = color
    e.nameLabel.Text     = char.Name
    e.nameLabel.TextColor3 = color
    e.distLabel.Text     = string.format("%.0fm", dist)
    e.distLabel.TextColor3 = Color3.fromRGB(200,200,200)
    e.hpFill.Size        = UDim2.new(1,0, hp, 0)
    e.hpFill.BackgroundColor3 = Color3.fromHSV(hp*0.33, 1, 1)
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 9 · BUCLE ESP
-- ══════════════════════════════════════════════════════════════════

local function updateAllESP()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myRootPos = myRoot.Position

    local liveFolder = Workspace:FindFirstChild(LIVE_FOLDER_NAME)
    if not liveFolder then return end

    local seen = {}
    for _, char in ipairs(liveFolder:GetChildren()) do
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root and isAlive(char, hum, root) then
            seen[char] = true
            makeOrUpdateESP(char, hum, root, myRootPos, myChar)
        end
    end

    -- Limpiar obsoletos
    for char in pairs(espCache) do
        if not seen[char] then clearESP(char) end
    end
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 10 · SELECCIÓN DE OBJETIVO
-- ══════════════════════════════════════════════════════════════════

local function getAimRef()
    local mouse = UserInputService:GetMouseLocation()
    return Vector2.new(mouse.X, mouse.Y)
end

local function getBestTarget(aimCenter, myChar, myTeam, cam)
    local liveFolder = Workspace:FindFirstChild(LIVE_FOLDER_NAME)
    if not liveFolder then return nil end

    local bestChar, bestPart, bestRoot, bestFOV
    bestFOV = CFG.FOV

    for _, char in ipairs(liveFolder:GetChildren()) do
        if char == myChar then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not (hum and root and isAlive(char, hum, root)) then continue end
        if getTeam(char) == myTeam then continue end

        local part = getTargetPart(char)
        if not part then continue end

        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist2D = Vector2.new(screenPos.X, screenPos.Y) - aimCenter
        local dist   = dist2D.Magnitude

        if dist < bestFOV then
            if isVisible(part, char, myChar) then
                bestFOV  = dist
                bestChar = char
                bestPart = part
                bestRoot = root
            end
        end
    end

    return bestChar, bestPart, bestRoot
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 11 · CONTROLES
-- ══════════════════════════════════════════════════════════════════

conns[#conns+1] = UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and CFG.AIM_LMB then
        aimPressCount = aimPressCount + 1
    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and CFG.AIM_RMB then
        aimPressCount = aimPressCount + 1
    elseif inp.KeyCode == Enum.KeyCode.F then
        cfgPanel.Visible = not cfgPanel.Visible
    elseif inp.KeyCode == Enum.KeyCode.Delete then
        -- shutdown llamado abajo
        Securi.Thread.Spawn(function()
            task.wait(0.05)
            if genv.__GDB_v5_shutdown then genv.__GDB_v5_shutdown() end
        end)
    end
end)

conns[#conns+1] = UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and CFG.AIM_LMB then
        aimPressCount = math.max(0, aimPressCount - 1)
    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and CFG.AIM_RMB then
        aimPressCount = math.max(0, aimPressCount - 1)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 12 · EVENTOS DEL PANEL CONFIG
-- ══════════════════════════════════════════════════════════════════

local function bindNumInput(key)
    local box = inputRows[key]
    if not box then return end
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            CFG[key] = n
            SaveConfig()
        else
            box.Text = tostring(CFG[key])
        end
    end)
end

local function bindToggle(key)
    local btn = toggleRows[key]
    if not btn then return end
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        btn.Text = CFG[key] and "✓ SÍ" or "✗ NO"
        btn.TextColor3 = CFG[key] and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,80,80)
        -- si desactivan ambos botones, resetear contador
        if key == "AIM_LMB" or key == "AIM_RMB" then
            if not CFG.AIM_LMB and not CFG.AIM_RMB then
                aimPressCount = 0
            end
        end
        SaveConfig()
    end)
end

for _, key in ipairs({"FOV","SPEED","OFF_X","OFF_Y","MAX_DIST"}) do
    bindNumInput(key)
end
for _, key in ipairs({"AIM_LMB","AIM_RMB","WALL_CHECK"}) do
    bindToggle(key)
end

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 13 · RENDER LOOP
-- ══════════════════════════════════════════════════════════════════

RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    -- Posición del mouse (el FOV lo sigue)
    local mouse   = UserInputService:GetMouseLocation()
    local mx, my  = mouse.X, mouse.Y

    -- Dot en el mouse
    centerDot.Position = UDim2.new(0, mx - 3, 0, my - 3)

    -- Círculo FOV centrado en el mouse
    local fovPx = CFG.FOV * 2
    fovFrame.Size     = UDim2.new(0, fovPx, 0, fovPx)
    fovFrame.Position = UDim2.new(0, mx - fovPx/2, 0, my - fovPx/2)

    -- ESP
    updateAllESP()

    -- Aim
    if not isAiming() then
        updateStateLabel(false, nil)
        return
    end

    local myChar = LocalPlayer.Character
    if not myChar then
        updateStateLabel(false, nil)
        return
    end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myTeam = getTeam(myChar)

    local aimCenter = getAimRef()   -- posición del mouse en pantalla
    local bestChar, bestPart, bestRoot = getBestTarget(aimCenter, myChar, myTeam, Camera)

    if not bestChar then
        updateStateLabel(false, nil)
        return
    end

    -- Apuntar directo a la parte objetivo + offsets
    local camPos   = Camera.CFrame.Position
    local aimPos   = bestPart.Position + Vector3.new(CFG.OFF_X, CFG.OFF_Y, 0)

    -- Mover cámara (lerp suave)
    local targetCF = CFrame.lookAt(camPos, aimPos)
    Camera.CFrame  = Camera.CFrame:Lerp(targetCF, math.clamp(CFG.SPEED, 0.01, 1))

    updateStateLabel(true, bestChar.Name)
end)

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 14 · SHUTDOWN
-- ══════════════════════════════════════════════════════════════════

local function shutdown()
    -- Desconectar todo
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)

    -- Unbind render
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)

    -- Limpiar ESP
    for char in pairs(espCache) do clearESP(char) end

    -- Resetear estado
    aimPressCount = 0

    -- Destruir GUI
    pcall(function() gui:Destroy() end)

    -- Limpiar genv
    if genv then
        genv.__GDB_v5           = nil
        genv.__GDB_v5_shutdown  = nil
    end

    print("[GDB v5] Apagado correctamente.")
end

genv.__GDB_v5_shutdown = shutdown

-- ══════════════════════════════════════════════════════════════════
-- SECCIÓN 15 · INICIO
-- ══════════════════════════════════════════════════════════════════

print(string.format("[GDB v5] Iniciado | FOV:%d | LMB:%s | RMB:%s",
    CFG.FOV,
    CFG.AIM_LMB and "ON" or "OFF",
    CFG.AIM_RMB and "ON" or "OFF"
))
