--[[
    GUERRA DE BLOQUES — v9 (OPTIMIZADO Y PERFECCIONADO)
    Nivel 3 Seguro (Sin hooks, 100% funcional)

    Novedades v9:
    1. Eliminado el HUD / tarjeta de la esquina ("🎯 AIM: OFF").
    2. Eliminado el marco / cuadrado delimitador del ESP en los enemigos.
       (Ahora el ESP es limpio: Texto + Barra de Vida + Highlight opcional).
    3. Compensación activa de retroceso (Recoil Compensation):
       Se enlaza a RenderPriority.Camera.Value + 4 (después del recoil del arma a +3)
       para que la mira no se desvíe al disparar y permanezca fija en el enemigo.
    4. Sincronización perfecta del centro del FOV con la mira de disparo.
    5. Menú de configuración limpio [Tecla F] y apagado seguro [Tecla DEL].
]]

-- ══════════════════════════════════════════════════════════════════
-- 1 · SERVICIOS
-- ══════════════════════════════════════════════════════════════════

local function safeCloneref(obj)
    if cloneref then
        local ok, res = pcall(cloneref, obj)
        if ok and res then return res end
    end
    return obj
end

local Players         = safeCloneref(game:GetService("Players"))
local RunService      = safeCloneref(game:GetService("RunService"))
local UIS             = safeCloneref(game:GetService("UserInputService"))
local Workspace       = safeCloneref(game:GetService("Workspace"))
local HttpService     = safeCloneref(game:GetService("HttpService"))
local LocalPlayer     = Players.LocalPlayer
local Camera          = Workspace.CurrentCamera

local genv = getgenv and getgenv() or _G
local scriptKey = tostring({}):sub(8)

-- ══════════════════════════════════════════════════════════════════
-- 2 · CONFIGURACIÓN
-- ══════════════════════════════════════════════════════════════════

local CFG = {
    FOV             = 160,       -- Radio del FOV en píxeles
    SPEED           = 0.50,      -- Velocidad del aimbot (0.05 a 1.0)
    OFF_Y           = 0.0,       -- Ajuste vertical al apuntar
    MAX_DIST        = 750,       -- Distancia máxima en studs
    AIM_LMB         = true,      -- Apuntar al mantener Click Izquierdo
    AIM_RMB         = true,      -- Apuntar al mantener Click Derecho
    WALL_CHECK      = true,      -- Chequeo de paredes
    TARGET_PART     = "Head",    -- "Head" o "HumanoidRootPart"
    ESP_ENABLED     = true,      -- Activar ESP
    ESP_HIGHLIGHT   = true,      -- Silueta coloreada
    ESP_ALLIES      = false,     -- Ocultar aliados (solo enemigos)
}

local CONFIG_FILE = "GDB_Config_v9.json"

local function saveConfig()
    if writefile then
        pcall(writefile, CONFIG_FILE, HttpService:JSONEncode(CFG))
    end
end

local function loadConfig()
    if readfile and isfile and isfile(CONFIG_FILE) then
        local ok, content = pcall(readfile, CONFIG_FILE)
        if ok and content and content ~= "" then
            local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
            if ok2 and type(data) == "table" then
                for k, v in pairs(data) do
                    if CFG[k] ~= nil and type(v) == type(CFG[k]) then
                        CFG[k] = v
                    end
                end
            end
        end
    end
end
loadConfig()

-- ══════════════════════════════════════════════════════════════════
-- 3 · ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════════

local conns        = {}
local espCache     = {}
local renderName   = "GDB_Loop_" .. scriptKey
local drawingFov   = nil
local gui          = nil

local function isAimKeyPressed()
    if not CFG.AIM_LMB and not CFG.AIM_RMB then return false end
    local lmb = CFG.AIM_LMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local rmb = CFG.AIM_RMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    return lmb or rmb
end

-- ══════════════════════════════════════════════════════════════════
-- 4 · LÓGICA DE EQUIPOS REAL (NATIVA DEL JUEGO)
-- ══════════════════════════════════════════════════════════════════

local function getMyTeamName()
    if LocalPlayer.Team and not LocalPlayer.Neutral then
        return LocalPlayer.Team.Name
    end
    local attr = LocalPlayer:GetAttribute("Team")
    if attr and type(attr) == "string" and attr ~= "" then
        return attr
    end
    if LocalPlayer.Character then
        local cAttr = LocalPlayer.Character:GetAttribute("Team")
        if cAttr and type(cAttr) == "string" and cAttr ~= "" then
            return cAttr
        end
        if LocalPlayer.Character:FindFirstChild("Accessory (Keffiyeh_3)") then return "Reds" end
        if LocalPlayer.Character:FindFirstChild("Accessory (Afrika Balaklava)") then return "Blues" end
    end
    if LocalPlayer.TeamColor then
        local n = LocalPlayer.TeamColor.Name
        if n:find("Red") or n:find("red") then return "Reds" end
        if n:find("Blue") or n:find("blue") then return "Blues" end
    end
    return nil
end

local function getTargetTeamName(char)
    if not char then return nil end

    local player = Players:GetPlayerFromCharacter(char)
    if player then
        if player.Team and not player.Neutral then
            return player.Team.Name
        end
        local pAttr = player:GetAttribute("Team")
        if pAttr and type(pAttr) == "string" and pAttr ~= "" then
            return pAttr
        end
        if player.TeamColor then
            local n = player.TeamColor.Name
            if n:find("Red") or n:find("red") then return "Reds" end
            if n:find("Blue") or n:find("blue") then return "Blues" end
        end
    end

    -- Bots oficiales en workspace.BotRigs
    local bAttr = char:GetAttribute("Team")
    if bAttr and type(bAttr) == "string" and bAttr ~= "" then
        return bAttr
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local rAttr = hrp:GetAttribute("Team")
        if rAttr and type(rAttr) == "string" and rAttr ~= "" then
            return rAttr
        end
    end

    -- Accesorios de respaldo
    if char:FindFirstChild("Accessory (Keffiyeh_3)") then return "Reds" end
    if char:FindFirstChild("Accessory (Afrika Balaklava)") then return "Blues" end

    return nil
end

local function isEnemy(char)
    if not char or char == LocalPlayer.Character then return false end

    -- Jugadores
    local player = Players:GetPlayerFromCharacter(char)
    if player then
        if player == LocalPlayer then return false end
        if player:GetAttribute("God") == true or player:GetAttribute("Invisible") == true then
            return false
        end
        if char:GetAttribute("Protected") == true then
            return false
        end

        local myTeam = getMyTeamName()
        local targetTeam = getTargetTeamName(char)

        if myTeam and targetTeam then
            return myTeam ~= targetTeam
        end

        if not myTeam then
            return true
        end

        return false
    end

    -- Bots
    if char:GetAttribute("Alive") == false or char:GetAttribute("Protected") == true then
        return false
    end

    local myTeam = getMyTeamName()
    local botTeam = getTargetTeamName(char)

    if myTeam and botTeam then
        return myTeam ~= botTeam
    end

    if not myTeam then
        return true
    end

    return false
end

-- ══════════════════════════════════════════════════════════════════
-- 5 · RECOLECCIÓN DE OBJETIVOS
-- ══════════════════════════════════════════════════════════════════

local function getAllTargets()
    local targets = {}
    local seen = {}

    -- 1. Jugadores
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and not seen[char] and char:IsA("Model") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    seen[char] = true
                    table.insert(targets, {
                        char = char,
                        hum = hum,
                        root = hrp,
                        name = player.DisplayName or player.Name,
                    })
                end
            end
        end
    end

    -- 2. Bots oficiales (workspace.BotRigs)
    local botRigs = Workspace:FindFirstChild("BotRigs")
    if botRigs then
        for _, bot in ipairs(botRigs:GetChildren()) do
            if bot:IsA("Model") and not seen[bot] then
                local hum = bot:FindFirstChildOfClass("Humanoid")
                local hrp = bot:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and bot:GetAttribute("Alive") ~= false then
                    seen[bot] = true
                    table.insert(targets, {
                        char = bot,
                        hum = hum,
                        root = hrp,
                        name = "[BOT] " .. bot.Name,
                    })
                end
            end
        end
    end

    -- 3. Carpeta Live
    local live = Workspace:FindFirstChild("Live")
    if live then
        for _, obj in ipairs(live:GetChildren()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character and not seen[obj] then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    seen[obj] = true
                    table.insert(targets, {
                        char = obj,
                        hum = hum,
                        root = hrp,
                        name = obj.Name,
                    })
                end
            end
        end
    end

    -- 4. Otros modelos en Workspace
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child ~= LocalPlayer.Character and not seen[child] then
            if not child:FindFirstChildOfClass("VehicleSeat") and child.Name ~= "Terrain" then
                local hum = child:FindFirstChildOfClass("Humanoid")
                local hrp = child:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    seen[child] = true
                    table.insert(targets, {
                        char = child,
                        hum = hum,
                        root = hrp,
                        name = child.Name,
                    })
                end
            end
        end
    end

    return targets
end

-- ══════════════════════════════════════════════════════════════════
-- 6 · COMPROBACIÓN DE LÍNEA DE VISIÓN
-- ══════════════════════════════════════════════════════════════════

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function canSee(targetPart, targetChar, myChar)
    if not CFG.WALL_CHECK then return true end
    if not targetPart or not targetChar or not myChar then return false end

    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin

    rayParams.FilterDescendantsInstances = {myChar}
    local result = Workspace:Raycast(origin, dir, rayParams)

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(targetChar)
end

-- ══════════════════════════════════════════════════════════════════
-- 7 · CENTRO EXACTO DEL DISPARO / MIRA
-- ══════════════════════════════════════════════════════════════════

local function getCrosshairCenter()
    -- 1. Si el juego tiene la mira en pantalla (WeaponHud)
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pGui then
        local wHud = pGui:FindFirstChild("WeaponHud")
        if wHud and wHud.Enabled then
            local crosshair = wHud:FindFirstChild("Crosshair")
            if crosshair and crosshair.Visible then
                local pos = crosshair.AbsolutePosition
                local size = crosshair.AbsoluteSize
                if size.X > 0 and size.Y > 0 then
                    return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
                end
            end
        end
    end

    -- 2. Si el cursor está bloqueado al centro (ShiftLock / Primera Persona)
    local isLocked = (UIS.MouseBehavior == Enum.MouseBehavior.LockCenter 
                   or UIS.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition)
    if isLocked then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    -- 3. Cursor del ratón en tercera persona libre
    local m = UIS:GetMouseLocation()
    return Vector2.new(m.X, m.Y)
end

-- ══════════════════════════════════════════════════════════════════
-- 8 · INTERFAZ Y CÍRCULO FOV
-- ══════════════════════════════════════════════════════════════════

do
    local sg = Instance.new("ScreenGui")
    sg.Name           = "GDB_v9_" .. scriptKey
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
        if not ok then
            sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    gui = sg
end

local espFolder = Instance.new("Folder")
espFolder.Name   = "ESP_Holder"
espFolder.Parent = gui

-- Círculo FOV Drawing
if Drawing and Drawing.new then
    pcall(function()
        drawingFov = Drawing.new("Circle")
        drawingFov.Thickness = 1.5
        drawingFov.Color = Color3.fromRGB(255, 220, 0)
        drawingFov.Transparency = 0.65
        drawingFov.Filled = false
        drawingFov.Visible = true
    end)
end

-- Círculo FOV GUI Fallback
local guiFov = Instance.new("Frame")
guiFov.AnchorPoint          = Vector2.new(0.5, 0.5)
guiFov.BackgroundTransparency = 1
guiFov.BorderSizePixel      = 0
guiFov.ZIndex               = 15
guiFov.Visible              = (drawingFov == nil)
guiFov.Parent               = gui
Instance.new("UICorner", guiFov).CornerRadius = UDim.new(1, 0)
local guiFovStroke = Instance.new("UIStroke", guiFov)
guiFovStroke.Color        = Color3.fromRGB(255, 220, 0)
guiFovStroke.Thickness    = 1.5
guiFovStroke.Transparency = 0.35

-- Punto central
local centerDot = Instance.new("Frame")
centerDot.Size             = UDim2.new(0, 4, 0, 4)
centerDot.AnchorPoint      = Vector2.new(0.5, 0.5)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel  = 0
centerDot.ZIndex           = 20
centerDot.Parent           = gui
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

-- ══════════════════════════════════════════════════════════════════
-- 9 · PANEL DE AJUSTES [TECLA F]
-- ══════════════════════════════════════════════════════════════════

local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 300, 0, 390)
panel.Position         = UDim2.new(0.5, -150, 0.5, -195)
panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 50
panel.Parent           = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(70, 70, 105)
panelStroke.Thickness = 1.5

local pTitle = Instance.new("TextLabel", panel)
pTitle.Size              = UDim2.new(1, -20, 0, 26)
pTitle.Position          = UDim2.new(0, 12, 0, 8)
pTitle.BackgroundTransparency = 1
pTitle.Font              = Enum.Font.GothamBold
pTitle.TextSize          = 13
pTitle.Text              = "⚔  GUERRA DE BLOQUES · V9"
pTitle.TextColor3        = Color3.fromRGB(255, 215, 60)
pTitle.TextXAlignment    = Enum.TextXAlignment.Left
pTitle.ZIndex            = 51

local pSub = Instance.new("TextLabel", panel)
pSub.Size                = UDim2.new(1, -20, 0, 14)
pSub.Position            = UDim2.new(0, 12, 0, 34)
pSub.BackgroundTransparency = 1
pSub.Font                = Enum.Font.Gotham
pSub.TextSize            = 11
pSub.Text                = "[F] Menú  |  [DEL] Salir"
pSub.TextColor3          = Color3.fromRGB(120, 120, 150)
pSub.TextXAlignment      = Enum.TextXAlignment.Left
pSub.ZIndex              = 51

local function createSep(posY)
    local s = Instance.new("Frame", panel)
    s.Size             = UDim2.new(1, -24, 0, 1)
    s.Position         = UDim2.new(0, 12, 0, posY)
    s.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    s.BorderSizePixel  = 0
    s.ZIndex           = 51
end
createSep(52)

local function createNumInput(labelTxt, key, posY, isFloat)
    local lbl = Instance.new("TextLabel", panel)
    lbl.Size              = UDim2.new(0, 155, 0, 22)
    lbl.Position          = UDim2.new(0, 14, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 11
    lbl.Text              = labelTxt
    lbl.TextColor3        = Color3.fromRGB(210, 210, 225)
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 52

    local box = Instance.new("TextBox", panel)
    box.Size              = UDim2.new(0, 95, 0, 22)
    box.Position          = UDim2.new(0, 185, 0, posY)
    box.BackgroundColor3  = Color3.fromRGB(24, 24, 36)
    box.BorderSizePixel   = 0
    box.Font              = Enum.Font.Gotham
    box.TextSize          = 11
    box.TextColor3        = Color3.fromRGB(255, 255, 255)
    box.Text              = tostring(CFG[key])
    box.ClearTextOnFocus  = false
    box.ZIndex            = 53
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            CFG[key] = isFloat and n or math.floor(n)
            saveConfig()
        else
            box.Text = tostring(CFG[key])
        end
    end)
end

local function createToggle(labelTxt, key, posY)
    local lbl = Instance.new("TextLabel", panel)
    lbl.Size              = UDim2.new(0, 165, 0, 22)
    lbl.Position          = UDim2.new(0, 14, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 11
    lbl.Text              = labelTxt
    lbl.TextColor3        = Color3.fromRGB(210, 210, 225)
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 52

    local btn = Instance.new("TextButton", panel)
    btn.Size              = UDim2.new(0, 75, 0, 22)
    btn.Position          = UDim2.new(0, 205, 0, posY)
    btn.BackgroundColor3  = Color3.fromRGB(28, 28, 44)
    btn.BorderSizePixel   = 0
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 11
    btn.ZIndex            = 53
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local function updateBtn()
        local val = CFG[key]
        btn.Text       = val and "✓ SÍ" or "✗ NO"
        btn.TextColor3 = val and Color3.fromRGB(70, 240, 120) or Color3.fromRGB(240, 70, 70)
    end
    updateBtn()

    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        updateBtn()
        saveConfig()
    end)
end

createNumInput("Radio del FOV (px):",   "FOV",         60, false)
createNumInput("Velocidad de Aim:",     "SPEED",       86, true)
createNumInput("Distancia Máxima (m):", "MAX_DIST",    112, false)
createNumInput("Ajuste Altura Y:",      "OFF_Y",       138, true)
createSep(164)

createToggle("Aim con Click Izq (LMB):", "AIM_LMB",     172)
createToggle("Aim con Click Der (RMB):", "AIM_RMB",     198)
createToggle("Chequeo de Paredes:",      "WALL_CHECK",  224)
createToggle("Activar ESP:",             "ESP_ENABLED", 250)
createToggle("Siluetas (Highlight):",    "ESP_HIGHLIGHT", 276)
createToggle("Mostrar Aliados en ESP:",  "ESP_ALLIES",  302)
createSep(330)

local partBtn = Instance.new("TextButton", panel)
partBtn.Size              = UDim2.new(1, -28, 0, 26)
partBtn.Position          = UDim2.new(0, 14, 0, 340)
partBtn.BackgroundColor3  = Color3.fromRGB(32, 42, 68)
partBtn.BorderSizePixel   = 0
partBtn.Font              = Enum.Font.GothamBold
partBtn.TextSize          = 11
partBtn.TextColor3        = Color3.fromRGB(220, 230, 255)
partBtn.ZIndex            = 53
Instance.new("UICorner", partBtn).CornerRadius = UDim.new(0, 5)

local function updatePartText()
    local name = (CFG.TARGET_PART == "Head") and "CABEZA" or "TORSO (HumanoidRootPart)"
    partBtn.Text = "🎯 Prioridad: " .. name
end
updatePartText()

partBtn.MouseButton1Click:Connect(function()
    CFG.TARGET_PART = (CFG.TARGET_PART == "Head") and "HumanoidRootPart" or "Head"
    updatePartText()
    saveConfig()
end)

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size              = UDim2.new(0, 70, 0, 20)
closeBtn.Position          = UDim2.new(1, -80, 0, 8)
closeBtn.BackgroundColor3  = Color3.fromRGB(150, 35, 35)
closeBtn.BorderSizePixel   = 0
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 10
closeBtn.Text              = "✕ Cerrar"
closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex            = 53
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

do
    local dragging, dragStart, startPos
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = inp.Position
            startPos  = panel.Position
        end
    end)
    panel.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    panel.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
-- 10 · ESP LIMPIO (SIN CUADRADO, SOLO TEXTO + VIDA + SILUETA)
-- ══════════════════════════════════════════════════════════════════

local function clearESP(char)
    local data = espCache[char]
    if data then
        if data.billboard and data.billboard.Parent then
            data.billboard:Destroy()
        end
        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end
        espCache[char] = nil
    end
end

local function renderESP(target, myPos)
    local char  = target.char
    local hum   = target.hum
    local root  = target.root
    local dist  = (root.Position - myPos).Magnitude

    if dist > CFG.MAX_DIST or not CFG.ESP_ENABLED or hum.Health <= 0 then
        clearESP(char)
        return
    end

    local enemy = isEnemy(char)
    if not enemy and not CFG.ESP_ALLIES then
        clearESP(char)
        return
    end

    local mainColor = enemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 160, 255)
    local targetTeam = getTargetTeamName(char) or "Sin Equipo"

    if not espCache[char] then
        local entry = {}

        local bb = Instance.new("BillboardGui")
        bb.Name         = "GDB_ESP"
        bb.Adornee      = root
        bb.Size         = UDim2.new(0, 120, 0, 45)
        bb.StudsOffset  = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop  = true
        bb.ResetOnSpawn = false
        bb.Parent       = espFolder

        -- Etiqueta Nombre y Equipo (Sin marco cuadrado)
        local nameLbl = Instance.new("TextLabel", bb)
        nameLbl.Size              = UDim2.new(1, 0, 0, 15)
        nameLbl.Position          = UDim2.new(0, 0, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font              = Enum.Font.GothamBold
        nameLbl.TextSize          = 11
        nameLbl.TextStrokeTransparency = 0.2
        nameLbl.TextColor3        = mainColor

        -- Etiqueta Distancia
        local distLbl = Instance.new("TextLabel", bb)
        distLbl.Size              = UDim2.new(1, 0, 0, 13)
        distLbl.Position          = UDim2.new(0, 0, 0, 16)
        distLbl.BackgroundTransparency = 1
        distLbl.Font              = Enum.Font.Gotham
        distLbl.TextSize          = 10
        distLbl.TextStrokeTransparency = 0.2
        distLbl.TextColor3        = Color3.fromRGB(225, 225, 225)

        -- Barra de vida horizontal compacta abajo del nombre
        local hpBg = Instance.new("Frame", bb)
        hpBg.Size             = UDim2.new(0.7, 0, 0, 3)
        hpBg.Position         = UDim2.new(0.15, 0, 0, 31)
        hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        hpBg.BorderSizePixel  = 0
        local hpFill = Instance.new("Frame", hpBg)
        hpFill.Size             = UDim2.new(1, 0, 1, 0)
        hpFill.BorderSizePixel  = 0

        entry.billboard = bb
        entry.nameLbl   = nameLbl
        entry.distLbl   = distLbl
        entry.hpFill    = hpFill

        -- Silueta (Highlight)
        if CFG.ESP_HIGHLIGHT then
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name                 = "GDB_Highlight"
                hl.Adornee              = char
                hl.FillColor            = mainColor
                hl.FillTransparency     = 0.6
                hl.OutlineColor         = Color3.fromRGB(255, 255, 255)
                hl.OutlineTransparency  = 0.3
                hl.Parent               = espFolder
                entry.highlight         = hl
            end)
        end

        espCache[char] = entry
    end

    local e = espCache[char]
    local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

    e.nameLbl.TextColor3 = mainColor
    e.nameLbl.Text       = string.format("%s [%s]", target.name, targetTeam)
    e.distLbl.Text       = string.format("%.0f m", dist)
    e.hpFill.Size        = UDim2.new(hpPct, 0, 1, 0)
    e.hpFill.BackgroundColor3 = Color3.fromHSV(hpPct * 0.33, 0.95, 1)

    if e.highlight then
        e.highlight.FillColor = mainColor
        e.highlight.Enabled   = CFG.ESP_HIGHLIGHT
    end
end

local function updateAllESP(allTargets, myPos)
    local activeChars = {}
    for _, t in ipairs(allTargets) do
        activeChars[t.char] = true
        renderESP(t, myPos)
    end

    for char in pairs(espCache) do
        if not activeChars[char] then
            clearESP(char)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════
-- 11 · SELECCIÓN DEL MEJOR OBJETIVO
-- ══════════════════════════════════════════════════════════════════

local function getBestTarget(allTargets, fovCenter, myChar)
    local bestTarget  = nil
    local bestPart    = nil
    local minDistance = CFG.FOV

    for _, t in ipairs(allTargets) do
        local char = t.char
        if isEnemy(char) and t.hum.Health > 0 then
            local part = char:FindFirstChild(CFG.TARGET_PART) 
                      or char:FindFirstChild("Head") 
                      or char:FindFirstChild("HumanoidRootPart")

            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - fovCenter).Magnitude
                    if dist2D <= minDistance then
                        if canSee(part, char, myChar) then
                            minDistance = dist2D
                            bestTarget  = t
                            bestPart    = part
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestPart
end

-- ══════════════════════════════════════════════════════════════════
-- 12 · TECLAS DE ACCESO RÁPIDO
-- ══════════════════════════════════════════════════════════════════

conns[#conns+1] = UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        panel.Visible = not panel.Visible
    elseif inp.KeyCode == Enum.KeyCode.Delete then
        task.spawn(function()
            task.wait(0.05)
            if genv.__GDB_SHUTDOWN then
                genv.__GDB_SHUTDOWN()
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 13 · BUCLE DE RENDERIZADO CON ANTI-RETROCESO (POST-RECOIL)
-- ══════════════════════════════════════════════════════════════════

-- Enlazar a Camera.Value + 4 para ejecutarse DESPUÉS del recoil nativo del arma (Camera.Value + 3)
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 4, function()
    local crosshairPos = getCrosshairCenter()
    local myChar       = LocalPlayer.Character
    local myRoot       = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos        = myRoot and myRoot.Position or Camera.CFrame.Position

    -- 1. Actualizar el círculo del FOV centrado exactamente en la mira
    local diameter = CFG.FOV * 2
    if drawingFov then
        drawingFov.Position = crosshairPos
        drawingFov.Radius   = CFG.FOV
        drawingFov.Visible  = true
        guiFov.Visible      = false
    else
        guiFov.Position = UDim2.new(0, crosshairPos.X, 0, crosshairPos.Y)
        guiFov.Size     = UDim2.new(0, diameter, 0, diameter)
        guiFov.Visible  = true
    end

    centerDot.Position = UDim2.new(0, crosshairPos.X, 0, crosshairPos.Y)

    -- 2. Recolectar objetivos
    local allTargets = getAllTargets()

    -- 3. Actualizar ESP limpio
    updateAllESP(allTargets, myPos)

    -- 4. Comprobar si se está apuntando
    local isAiming = isAimKeyPressed()

    if isAiming and myChar and myRoot then
        -- Cambiar color de FOV a rojo al apuntar
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 60, 60) end
        guiFovStroke.Color = Color3.fromRGB(255, 60, 60)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)

        -- 5. Seleccionar mejor enemigo
        local target, targetPart = getBestTarget(allTargets, crosshairPos, myChar)

        if target and targetPart then
            -- 6. Orientar la cámara directamente al objetivo
            -- Al ejecutarse después del recoil nativo (+4), anula la desviación del arma
            local camPos = Camera.CFrame.Position
            local aimPos = targetPart.Position + Vector3.new(0, CFG.OFF_Y, 0)
            local targetLook = CFrame.lookAt(camPos, aimPos)

            if CFG.SPEED >= 1 then
                Camera.CFrame = targetLook
            else
                Camera.CFrame = Camera.CFrame:Lerp(targetLook, math.clamp(CFG.SPEED, 0.05, 1))
            end
        end
    else
        -- Color amarillo neutro al no apuntar
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 220, 0) end
        guiFovStroke.Color = Color3.fromRGB(255, 220, 0)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

-- ══════════════════════════════════════════════════════════════════
-- 14 · APAGADO LIMPIO
-- ══════════════════════════════════════════════════════════════════

local function shutdown()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)

    pcall(function()
        RunService:UnbindFromRenderStep(renderName)
    end)

    if drawingFov then
        pcall(function() drawingFov:Remove() end)
        drawingFov = nil
    end

    for char in pairs(espCache) do
        clearESP(char)
    end
    table.clear(espCache)

    if gui and gui.Parent then
        pcall(function() gui:Destroy() end)
    end

    genv.__GDB_SHUTDOWN = nil
    print("[GDB v9] Script apagado correctamente.")
end

genv.__GDB_SHUTDOWN = shutdown

-- ══════════════════════════════════════════════════════════════════
-- 15 · INICIO
-- ══════════════════════════════════════════════════════════════════

print(string.format("[GDB v9] Listo | FOV: %dpx | Click Izq: %s | Click Der: %s | Menú: F",
    CFG.FOV,
    CFG.AIM_LMB and "ON" or "OFF",
    CFG.AIM_RMB and "ON" or "OFF"
))
