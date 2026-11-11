--[[
    GUERRA DE BLOQUES — v6
    ESP + AIM + FOV centrado en mouse
    LMB / RMB → aim  |  F → panel  |  DEL → apagar
]]

-- ═══════════════════════════════════════════════════
-- 1 · SERVICIOS
-- ═══════════════════════════════════════════════════

local function safeCloneref(o)
    if cloneref then local ok,r = pcall(cloneref,o) if ok and r then return r end end
    return o
end

local Players         = safeCloneref(game:GetService("Players"))
local RunService      = safeCloneref(game:GetService("RunService"))
local UIS             = safeCloneref(game:GetService("UserInputService"))
local Workspace       = safeCloneref(game:GetService("Workspace"))
local HttpService      = safeCloneref(game:GetService("HttpService"))
local LocalPlayer     = Players.LocalPlayer
local Camera          = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════
-- 2 · CONFIG
-- ═══════════════════════════════════════════════════

-- Accesorios que identifican cada equipo en este juego
local TEAM1_ACC = "Accessory (Keffiyeh_3)"
local TEAM2_ACC = "Accessory (Afrika Balaklava)"
local LIVE      = "Live"   -- carpeta donde viven los personajes

local CFG = {
    FOV        = 150,    -- radio del círculo en píxeles
    SPEED      = 0.20,   -- lerp del aim (0.01 lento – 1 snap)
    OFF_Y      = 0.0,    -- desplazamiento vertical al apuntar
    MAX_DIST   = 600,    -- distancia máxima en studs para ESP y aim
    AIM_LMB    = true,   -- LMB activa aim
    AIM_RMB    = true,   -- RMB activa aim
    WALL_CHECK = true,   -- ignorar enemigos detrás de paredes
    TARGET     = "Head", -- "Head" o "HumanoidRootPart"
    ESP_ON     = true,   -- mostrar ESP
}

-- Almacenamiento sencillo
local SAVE_KEY = "GDB_v6.json"
local function saveConfig()
    if writefile then pcall(writefile, SAVE_KEY, HttpService:JSONEncode(CFG)) end
end
local function loadConfig()
    if readfile and isfile and isfile(SAVE_KEY) then
        local ok, raw = pcall(readfile, SAVE_KEY)
        if ok and raw ~= "" then
            local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok2 and type(t) == "table" then
                for k, v in pairs(t) do
                    if CFG[k] ~= nil and type(v) == type(CFG[k]) then
                        CFG[k] = v
                    end
                end
            end
        end
    end
end
loadConfig()

-- ═══════════════════════════════════════════════════
-- 3 · ESTADO
-- ═══════════════════════════════════════════════════

local conns        = {}
local espCache     = {}   -- [char] → {billboard, stroke, nameLbl, distLbl, hpFill}
local aimCount     = 0    -- cuántos botones de aim están presionados
local renderName   = "GDB_v6_" .. tostring({}):sub(8)
local genv         = getgenv and getgenv() or _G

-- ═══════════════════════════════════════════════════
-- 4 · GUI
-- ═══════════════════════════════════════════════════

local gui
do
    local sg = Instance.new("ScreenGui")
    sg.Name           = renderName
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 999
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, sg)
        sg.Parent = safeCloneref(game:GetService("CoreGui"))
    elseif gethui then
        sg.Parent = gethui()
    else
        local ok = pcall(function()
            sg.Parent = safeCloneref(game:GetService("CoreGui"))
        end)
        if not ok then sg.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end
    end
    gui = sg
end

-- Carpeta para billboards ESP
local espHolder = Instance.new("Folder")
espHolder.Name   = "ESP"
espHolder.Parent = gui

-- ── helpers UI ────────────────────────────────────
local function newLabel(parent, t)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.TextColor3  = Color3.new(1,1,1)
    l.Font        = Enum.Font.GothamBold
    l.TextSize    = 13
    l.Text        = ""
    l.ZIndex      = 10
    for k,v in pairs(t or {}) do l[k]=v end
    l.Parent = parent
    return l
end

local function newFrame(parent, t)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = Color3.fromRGB(14,14,20)
    f.BorderSizePixel  = 0
    f.ZIndex           = 5
    for k,v in pairs(t or {}) do f[k]=v end
    f.Parent = parent
    return f
end

local function newButton(parent, t)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = Color3.fromRGB(35,35,50)
    b.BorderSizePixel  = 0
    b.TextColor3       = Color3.new(1,1,1)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 12
    b.AutoButtonColor  = false
    b.ZIndex           = 11
    for k,v in pairs(t or {}) do b[k]=v end
    b.Parent = parent
    return b
end

local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 6)
    return c
end

local function stroke(parent, color, thick, transp)
    local s = Instance.new("UIStroke", parent)
    s.Color        = color or Color3.fromRGB(80,80,120)
    s.Thickness    = thick or 1.5
    s.Transparency = transp or 0
    return s
end

-- ── Dot del cursor (punto central del FOV) ────────
local cursorDot = Instance.new("Frame")
cursorDot.Size             = UDim2.new(0,6,0,6)
cursorDot.AnchorPoint      = Vector2.new(0.5,0.5)
cursorDot.BackgroundColor3 = Color3.new(1,1,1)
cursorDot.BorderSizePixel  = 0
cursorDot.ZIndex           = 25
cursorDot.Parent           = gui
corner(cursorDot, 10)

-- ── Círculo FOV (anillo que sigue al mouse) ────────
-- Usamos un Frame transparente + UIStroke + UICorner
local fovRing = Instance.new("Frame")
fovRing.AnchorPoint          = Vector2.new(0.5,0.5)
fovRing.BackgroundTransparency = 1
fovRing.BorderSizePixel      = 0
fovRing.ZIndex               = 20
fovRing.Parent               = gui
corner(fovRing, 999)   -- 999 = círculo perfecto
local fovStroke = stroke(fovRing, Color3.fromRGB(255,220,0), 1.5, 0.3)

-- ── HUD estado (arriba izquierda) ─────────────────
local hudBg = newFrame(gui, {
    Size             = UDim2.new(0,220,0,56),
    Position         = UDim2.new(0,10,0,10),
    BackgroundColor3 = Color3.fromRGB(8,8,14),
    ZIndex           = 18,
})
corner(hudBg, 8)
stroke(hudBg, Color3.fromRGB(50,50,80), 1, 0)

local stateLabel = newLabel(hudBg, {
    Size = UDim2.new(1,-12,0,26),
    Position = UDim2.new(0,8,0,4),
    Text = "🎯  AIM: OFF",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(150,150,170),
    TextSize = 13,
    ZIndex = 19,
})
local targetLabel = newLabel(hudBg, {
    Size = UDim2.new(1,-12,0,22),
    Position = UDim2.new(0,8,0,30),
    Text = "",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(0,200,255),
    TextSize = 11,
    ZIndex = 19,
})

local function setHUD(aiming, name)
    if aiming then
        stateLabel.Text       = "🎯  AIM: ACTIVO"
        stateLabel.TextColor3 = Color3.fromRGB(80,255,120)
        cursorDot.BackgroundColor3 = Color3.fromRGB(255,50,50)
        fovStroke.Color       = Color3.fromRGB(255,80,80)
    else
        stateLabel.Text       = "🎯  AIM: OFF"
        stateLabel.TextColor3 = Color3.fromRGB(150,150,170)
        cursorDot.BackgroundColor3 = Color3.new(1,1,1)
        fovStroke.Color       = Color3.fromRGB(255,220,0)
    end
    targetLabel.Text = name and ("▶  "..name) or ""
end

-- ═══════════════════════════════════════════════════
-- 5 · PANEL CONFIG
-- ═══════════════════════════════════════════════════

local PANEL_W, PANEL_H = 290, 400
local panel = newFrame(gui, {
    Size             = UDim2.new(0,PANEL_W,0,PANEL_H),
    Position         = UDim2.new(0.5,-PANEL_W/2, 0.5,-PANEL_H/2),
    BackgroundColor3 = Color3.fromRGB(10,10,16),
    Visible          = false,
    ZIndex           = 40,
})
corner(panel, 10)
stroke(panel, Color3.fromRGB(60,60,110), 1.5, 0)

-- Título del panel
newLabel(panel, {
    Size = UDim2.new(1,-16,0,30),
    Position = UDim2.new(0,8,0,8),
    Text = "⚔  GUERRA DE BLOQUES  v6",
    TextSize = 14,
    TextColor3 = Color3.fromRGB(255,215,50),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 42,
})
newLabel(panel, {
    Size = UDim2.new(1,-16,0,16),
    Position = UDim2.new(0,8,0,38),
    Text = "[F] cerrar  ·  [DEL] apagar",
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.fromRGB(80,80,110),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 42,
})

-- Separador
local function panelSep(y)
    local s = Instance.new("Frame", panel)
    s.Size             = UDim2.new(1,-20,0,1)
    s.Position         = UDim2.new(0,10,0,y)
    s.BackgroundColor3 = Color3.fromRGB(40,40,65)
    s.BorderSizePixel  = 0
    s.ZIndex           = 41
end
panelSep(58)

-- Fila de input numérico
local inputs = {}
local function panelInput(labelTxt, key, y)
    newLabel(panel, {
        Size = UDim2.new(0,145,0,24),
        Position = UDim2.new(0,12,0,y),
        Text = labelTxt,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200,200,220),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 42,
    })
    local box = Instance.new("TextBox")
    box.Size               = UDim2.new(0,100,0,24)
    box.Position           = UDim2.new(0,175,0,y)
    box.BackgroundColor3   = Color3.fromRGB(22,22,36)
    box.BorderSizePixel    = 0
    box.TextColor3         = Color3.fromRGB(220,220,255)
    box.Font               = Enum.Font.Gotham
    box.TextSize           = 12
    box.Text               = tostring(CFG[key])
    box.ClearTextOnFocus   = false
    box.ZIndex             = 43
    box.Parent             = panel
    corner(box, 5)
    inputs[key] = box
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then CFG[key] = n saveConfig()
        else box.Text = tostring(CFG[key]) end
    end)
end

-- Fila de toggle booleano
local toggleBtns = {}
local function panelToggle(labelTxt, key, y)
    newLabel(panel, {
        Size = UDim2.new(0,160,0,24),
        Position = UDim2.new(0,12,0,y),
        Text = labelTxt,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200,200,220),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 42,
    })
    local function getColor(v) return v and Color3.fromRGB(60,220,100) or Color3.fromRGB(220,60,60) end
    local function getTxt(v)   return v and "✓ SÍ" or "✗ NO" end
    local btn = newButton(panel, {
        Size = UDim2.new(0,76,0,24),
        Position = UDim2.new(0,200,0,y),
        Text = getTxt(CFG[key]),
        TextColor3 = getColor(CFG[key]),
        ZIndex = 43,
    })
    corner(btn, 5)
    toggleBtns[key] = btn
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        btn.Text = getTxt(CFG[key])
        btn.TextColor3 = getColor(CFG[key])
        if (key == "AIM_LMB" or key == "AIM_RMB") then
            if not CFG.AIM_LMB and not CFG.AIM_RMB then aimCount = 0 end
        end
        saveConfig()
    end)
end

-- ── Sección PUNTERÍA ──────────────────────────────
newLabel(panel, {
    Size = UDim2.new(1,-16,0,16), Position = UDim2.new(0,12,0,66),
    Text = "▸  PUNTERÍA", TextSize = 11, Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(255,180,50), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
})
panelInput("FOV  (radio px)",   "FOV",      88)
panelInput("Velocidad aim",     "SPEED",   118)
panelInput("Ajuste Y",          "OFF_Y",   148)
panelInput("Dist. máx (studs)", "MAX_DIST",178)
panelSep(208)

-- ── Sección OPCIONES ──────────────────────────────
newLabel(panel, {
    Size = UDim2.new(1,-16,0,16), Position = UDim2.new(0,12,0,214),
    Text = "▸  OPCIONES", TextSize = 11, Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(160,100,255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
})
panelToggle("LMB activa aim",   "AIM_LMB",   236)
panelToggle("RMB activa aim",   "AIM_RMB",   264)
panelToggle("Chequeo de pared", "WALL_CHECK", 292)
panelToggle("ESP visible",      "ESP_ON",     320)
panelSep(350)

-- Botón parte objetivo
local function getPartTxt() return "Parte objetivo: "..CFG.TARGET end
local partBtn = newButton(panel, {
    Size = UDim2.new(1,-24,0,28),
    Position = UDim2.new(0,12,0,358),
    Text = getPartTxt(),
    TextSize = 12,
    ZIndex = 43,
})
corner(partBtn, 6)
partBtn.MouseButton1Click:Connect(function()
    CFG.TARGET = CFG.TARGET == "Head" and "HumanoidRootPart" or "Head"
    partBtn.Text = getPartTxt()
    saveConfig()
end)

-- Botón cerrar
local closeBtn = newButton(panel, {
    Size = UDim2.new(0,76,0,24),
    Position = UDim2.new(1,-88,0,8),
    Text = "✕ Cerrar",
    BackgroundColor3 = Color3.fromRGB(140,25,25),
    TextSize = 12,
    ZIndex = 43,
})
corner(closeBtn, 5)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

-- Arrastrar panel
do
    local drag, dragStart, startPos
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; dragStart = inp.Position; startPos = panel.Position
        end
    end)
    panel.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    panel.InputChanged:Connect(function(inp)
        if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ═══════════════════════════════════════════════════
-- 6 · LÓGICA DE EQUIPO
-- ═══════════════════════════════════════════════════

-- Detecta el equipo del personaje por sus accesorios
local function getTeam(char)
    if not char then return -1 end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            if v.Name == TEAM1_ACC then return 1 end
            if v.Name == TEAM2_ACC then return 2 end
        end
    end
    return 0  -- sin equipo / desconocido
end

local function isEnemy(char, myTeam)
    if myTeam == 0 or myTeam == -1 then return false end  -- no sabemos el equipo propio → no apuntar
    local t = getTeam(char)
    return t ~= 0 and t ~= -1 and t ~= myTeam
end

local function isAlive(hum)
    return hum and hum.Parent and hum.Health > 0
end

local function getTargetPart(char)
    return char:FindFirstChild(CFG.TARGET) or char:FindFirstChild("HumanoidRootPart")
end

-- ═══════════════════════════════════════════════════
-- 7 · VISIBILIDAD (raycast)
-- ═══════════════════════════════════════════════════

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(targetPart, targetChar, myChar)
    if not CFG.WALL_CHECK then return true end
    local origin = Camera.CFrame.Position
    local dir    = targetPart.Position - origin
    rayParams.FilterDescendantsInstances = {myChar, targetChar}
    local res = Workspace:Raycast(origin, dir, rayParams)
    if not res then return true end
    local p = res.Instance.Parent
    return p == targetChar or (p and p.Parent == targetChar)
end

-- ═══════════════════════════════════════════════════
-- 8 · ESP
-- ═══════════════════════════════════════════════════

local function clearESP(char)
    local e = espCache[char]
    if not e then return end
    if e.billboard and e.billboard.Parent then e.billboard:Destroy() end
    espCache[char] = nil
end

local function updateESP(char, hum, root, myRootPos, myChar, myTeam)
    -- Solo mostrar enemigos en ESP (rojo) o aliados (azul)
    local dist = (root.Position - myRootPos).Magnitude
    if dist > CFG.MAX_DIST or not CFG.ESP_ON then
        clearESP(char)
        return
    end

    -- Crear billboard si no existe
    if not espCache[char] then
        local bb = Instance.new("BillboardGui")
        bb.Name         = "GDBESP"
        bb.Adornee      = root
        bb.Size         = UDim2.new(0,56,0,68)
        bb.StudsOffset  = Vector3.new(0,2.8,0)
        bb.AlwaysOnTop  = true
        bb.ResetOnSpawn = false
        bb.Parent       = espHolder

        -- Caja (borde)
        local boxF = Instance.new("Frame", bb)
        boxF.Size                 = UDim2.new(1,0,1,0)
        boxF.BackgroundTransparency = 1
        boxF.BorderSizePixel      = 0
        local boxS = Instance.new("UIStroke", boxF)
        boxS.Thickness = 1.5

        -- Nombre
        local nameLbl = Instance.new("TextLabel", bb)
        nameLbl.Size              = UDim2.new(1,0,0,14)
        nameLbl.Position          = UDim2.new(0,0,0,-16)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font              = Enum.Font.GothamBold
        nameLbl.TextSize          = 11
        nameLbl.TextStrokeTransparency = 0.4
        nameLbl.TextColor3        = Color3.new(1,1,1)

        -- Distancia
        local distLbl = Instance.new("TextLabel", bb)
        distLbl.Size              = UDim2.new(1,0,0,12)
        distLbl.Position          = UDim2.new(0,0,1,2)
        distLbl.BackgroundTransparency = 1
        distLbl.Font              = Enum.Font.Gotham
        distLbl.TextSize          = 10
        distLbl.TextStrokeTransparency = 0.4
        distLbl.TextColor3        = Color3.fromRGB(200,200,200)

        -- Barra HP (a la derecha de la caja)
        local hpBg = Instance.new("Frame", bb)
        hpBg.Size             = UDim2.new(0,4,1,0)
        hpBg.Position         = UDim2.new(1,3,0,0)
        hpBg.BackgroundColor3 = Color3.fromRGB(30,30,30)
        hpBg.BorderSizePixel  = 0
        local hpFill = Instance.new("Frame", hpBg)
        hpFill.AnchorPoint      = Vector2.new(0,1)
        hpFill.Position         = UDim2.new(0,0,1,0)
        hpFill.Size             = UDim2.new(1,0,1,0)
        hpFill.BorderSizePixel  = 0

        espCache[char] = {
            billboard = bb,
            boxStroke = boxS,
            nameLbl   = nameLbl,
            distLbl   = distLbl,
            hpFill    = hpFill,
        }
    end

    local e    = espCache[char]
    local hp   = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    local enemy = isEnemy(char, myTeam)
    local col  = enemy and Color3.fromRGB(255,55,55) or Color3.fromRGB(55,160,255)

    e.boxStroke.Color    = col
    e.nameLbl.Text       = char.Name
    e.nameLbl.TextColor3 = col
    e.distLbl.Text       = string.format("%.0f m", dist)
    e.hpFill.Size        = UDim2.new(1,0,hp,0)
    e.hpFill.BackgroundColor3 = Color3.fromHSV(hp * 0.33, 0.9, 1)
end

local function refreshESP()
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myRootPos = myRoot.Position
    local myTeam    = getTeam(myChar)

    local liveFolder = Workspace:FindFirstChild(LIVE)
    if not liveFolder then
        -- Sin carpeta Live → limpiar todo
        for c in pairs(espCache) do clearESP(c) end
        return
    end

    local seen = {}
    for _, char in ipairs(liveFolder:GetChildren()) do
        if char == myChar then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root and isAlive(hum) then
            seen[char] = true
            updateESP(char, hum, root, myRootPos, myChar, myTeam)
        end
    end

    -- Limpiar personajes que ya no están vivos / en carpeta
    for c in pairs(espCache) do
        if not seen[c] then clearESP(c) end
    end
end

-- ═══════════════════════════════════════════════════
-- 9 · SELECCIÓN DE OBJETIVO (AIM)
-- ═══════════════════════════════════════════════════

local function getMousePos()
    local m = UIS:GetMouseLocation()
    return Vector2.new(m.X, m.Y)
end

local function getBestTarget(mousePos, myChar, myTeam)
    local liveFolder = Workspace:FindFirstChild(LIVE)
    if not liveFolder then return nil, nil end

    local bestChar, bestPart, bestDist
    bestDist = CFG.FOV  -- el enemigo tiene que estar dentro del FOV

    for _, char in ipairs(liveFolder:GetChildren()) do
        if char == myChar then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not (hum and root and isAlive(hum)) then continue end

        -- Solo apuntar a ENEMIGOS
        if not isEnemy(char, myTeam) then continue end

        -- Distancia en studs
        local worldDist = (root.Position - myChar:FindFirstChild("HumanoidRootPart").Position).Magnitude
        if worldDist > CFG.MAX_DIST then continue end

        local part = getTargetPart(char)
        if not part then continue end

        -- Proyectar a pantalla
        local sPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local d2 = (Vector2.new(sPos.X, sPos.Y) - mousePos).Magnitude
        if d2 < bestDist then
            if canSee(part, char, myChar) then
                bestDist = d2
                bestChar = char
                bestPart = part
            end
        end
    end

    return bestChar, bestPart
end

-- ═══════════════════════════════════════════════════
-- 10 · CONTROLES
-- ═══════════════════════════════════════════════════

conns[#conns+1] = UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and CFG.AIM_LMB then
        aimCount = aimCount + 1
    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and CFG.AIM_RMB then
        aimCount = aimCount + 1
    elseif inp.KeyCode == Enum.KeyCode.F then
        panel.Visible = not panel.Visible
    elseif inp.KeyCode == Enum.KeyCode.Delete then
        task.spawn(function()
            task.wait(0.05)
            if genv.__GDB_shutdown then genv.__GDB_shutdown() end
        end)
    end
end)

conns[#conns+1] = UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 and CFG.AIM_LMB then
        aimCount = math.max(0, aimCount - 1)
    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and CFG.AIM_RMB then
        aimCount = math.max(0, aimCount - 1)
    end
end)

-- ═══════════════════════════════════════════════════
-- 11 · RENDER LOOP
-- ═══════════════════════════════════════════════════

RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
    -- Posición actual del mouse
    local mouse = getMousePos()
    local mx, my = mouse.X, mouse.Y

    -- Mover dot y anillo al mouse
    cursorDot.Position = UDim2.new(0, mx, 0, my)   -- AnchorPoint=0.5 ya centra
    local diameter = CFG.FOV * 2
    fovRing.Size     = UDim2.new(0, diameter, 0, diameter)
    fovRing.Position = UDim2.new(0, mx, 0, my)      -- AnchorPoint=0.5 ya centra

    -- Actualizar ESP
    refreshESP()

    -- Sin aim → reset HUD
    if aimCount <= 0 then
        setHUD(false, nil)
        return
    end

    -- Verificar personaje local
    local myChar = LocalPlayer.Character
    if not myChar then setHUD(false,nil) return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then setHUD(false,nil) return end
    local myTeam = getTeam(myChar)

    -- Sin equipo conocido → no apuntar
    if myTeam == 0 or myTeam == -1 then
        setHUD(false, "Sin equipo detectado")
        return
    end

    -- Buscar mejor objetivo dentro del FOV (basado en posición del mouse)
    local bestChar, bestPart = getBestTarget(mouse, myChar, myTeam)

    if not bestChar then
        setHUD(false, nil)
        return
    end

    -- Apuntar (lerp suave de cámara)
    local camPos = Camera.CFrame.Position
    local aimPos = bestPart.Position + Vector3.new(0, CFG.OFF_Y, 0)
    local lookCF = CFrame.lookAt(camPos, aimPos)
    Camera.CFrame = Camera.CFrame:Lerp(lookCF, math.clamp(CFG.SPEED, 0.01, 1))

    setHUD(true, bestChar.Name)
end)

-- ═══════════════════════════════════════════════════
-- 12 · SHUTDOWN
-- ═══════════════════════════════════════════════════

local function shutdown()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    for c in pairs(espCache) do clearESP(c) end
    aimCount = 0
    pcall(function() gui:Destroy() end)
    genv.__GDB_shutdown = nil
    print("[GDB v6] Apagado.")
end

genv.__GDB_shutdown = shutdown

-- ═══════════════════════════════════════════════════
-- 13 · INICIO
-- ═══════════════════════════════════════════════════

print(string.format("[GDB v6] Listo | FOV:%d | LMB:%s | RMB:%s | WALL:%s",
    CFG.FOV,
    CFG.AIM_LMB and "ON" or "OFF",
    CFG.AIM_RMB and "ON" or "OFF",
    CFG.WALL_CHECK and "ON" or "OFF"
))
