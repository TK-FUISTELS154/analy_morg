--[[
    GUERRA DE BLOQUES — v8 (DEFINITIVO)
    Nivel 3 Seguro (Sin hooks, 100% funcional)
    
    Correcciones aplicadas:
    1. Detección de entrada por hardware en tiempo real (UIS:IsMouseButtonPressed)
       para que el juego no bloquee el click izquierdo ni derecho con gameProcessed.
    2. Raycast de visión (canSee) reparado: ya no excluye al objetivo, detecta paredes
       reales sin falsos negativos.
    3. Detección exacta de equipos (Reds vs Blues) y filtrado de bots (workspace.BotRigs):
       los bots y jugadores aliados ya NO se marcan como enemigos.
    4. FOV adaptativo perfecto con Drawing API y fallback en ScreenGui.
    5. ESP con BillboardGui + Highlights que distingue enemigos (rojo) y aliados (azul).
    6. Panel interactivo [F] y apagado seguro [DEL].
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
local Teams           = safeCloneref(game:GetService("Teams"))
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
    SPEED           = 0.35,      -- Velocidad del lerp de aim (0.05 a 1.0)
    OFF_Y           = 0.0,       -- Offset vertical
    MAX_DIST        = 700,       -- Distancia máxima en studs
    AIM_LMB         = true,      -- Apuntar manteniendo Click Izquierdo
    AIM_RMB         = true,      -- Apuntar manteniendo Click Derecho
    WALL_CHECK      = true,      -- Comprobar si hay paredes bloqueando
    TARGET_PART     = "Head",    -- "Head" o "HumanoidRootPart"
    ESP_ENABLED     = true,      -- Activar ESP
    ESP_HIGHLIGHT   = true,      -- Silueta coloreada
    ESP_ALLIES      = false,     -- Ocultar aliados por defecto (solo enemigos)
}

local CONFIG_FILE = "GDB_Config_v8.json"

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
-- 3 · ESTADO Y VARIABLES GLOBALES
-- ══════════════════════════════════════════════════════════════════

local conns        = {}
local espCache     = {}
local renderName   = "GDB_Render_" .. scriptKey
local drawingFov   = nil
local gui          = nil

-- Detección continua de hardware para los clicks de apuntado
local function isAimKeyPressed()
    if not CFG.AIM_LMB and not CFG.AIM_RMB then return false end
    local lmb = CFG.AIM_LMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local rmb = CFG.AIM_RMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    return lmb or rmb
end

-- ══════════════════════════════════════════════════════════════════
-- 4 · LÓGICA DE EQUIPOS REAL (SEGÚN CÓDIGO NATIVO DEL JUEGO)
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

    -- Si es un Bot (en este juego los bots guardan su equipo en el atributo "Team")
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

    -- Fallback por accesorios
    if char:FindFirstChild("Accessory (Keffiyeh_3)") then return "Reds" end
    if char:FindFirstChild("Accessory (Afrika Balaklava)") then return "Blues" end

    return nil
end

-- Determina si un personaje es hostil/enemigo
local function isEnemy(char)
    if not char or char == LocalPlayer.Character then return false end

    -- Comprobar si es un Jugador Humano
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

        -- Si no hay equipos definidos o es modo libre
        if not myTeam then
            return true
        end

        return false
    end

    -- Comprobar si es un Bot
    if char:GetAttribute("Alive") == false or char:GetAttribute("Protected") == true then
        return false
    end

    local myTeam = getMyTeamName()
    local botTeam = getTargetTeamName(char)

    if myTeam and botTeam then
        return myTeam ~= botTeam
    end

    -- Si el bot no tiene equipo detectado o estamos en FFA
    if not myTeam then
        return true
    end

    return false
end

-- ══════════════════════════════════════════════════════════════════
-- 5 · RECOLECCIÓN DE TODOS LOS PERSONAJES DEL MAPA
-- ══════════════════════════════════════════════════════════════════

local function getAllTargets()
    local targets = {}
    local seen = {}

    -- 1. Jugadores reales
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
                        isBot = false
                    })
                end
            end
        end
    end

    -- 2. Bots oficiales (carpeta workspace.BotRigs)
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
                        isBot = true
                    })
                end
            end
        end
    end

    -- 3. Carpeta Live (si existe en algún modo)
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
                        isBot = true
                    })
                end
            end
        end
    end

    -- 4. Otros modelos con humanoide en Workspace
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
                        isBot = true
                    })
                end
            end
        end
    end

    return targets
end

-- ══════════════════════════════════════════════════════════════════
-- 6 · COMPROBACIÓN DE LÍNEA DE VISIÓN (SIN BUGS)
-- ══════════════════════════════════════════════════════════════════

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function canSee(targetPart, targetChar, myChar)
    if not CFG.WALL_CHECK then return true end
    if not targetPart or not targetChar or not myChar then return false end

    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin

    -- Solo excluimos a nuestro propio personaje para que el rayo viaje hacia el objetivo
    rayParams.FilterDescendantsInstances = {myChar}
    local result = Workspace:Raycast(origin, dir, rayParams)

    -- Si no choca con nada en la trayectoria, hay visión directa
    if not result then
        return true
    end

    -- Si choca con el cuerpo o accesorios del objetivo, es visible
    return result.Instance:IsDescendantOf(targetChar)
end

-- ══════════════════════════════════════════════════════════════════
-- 7 · CENTRO DEL FOV (MOUSE VS PRIMERA PERSONA)
-- ══════════════════════════════════════════════════════════════════

local function getFovCenter()
    local isLocked = (UIS.MouseBehavior == Enum.MouseBehavior.LockCenter 
                   or UIS.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition)
    if isLocked then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        local m = UIS:GetMouseLocation()
        return Vector2.new(m.X, m.Y)
    end
end

-- ══════════════════════════════════════════════════════════════════
-- 8 · INTERFAZ GRÁFICA PROTEGIDA
-- ══════════════════════════════════════════════════════════════════

do
    local sg = Instance.new("ScreenGui")
    sg.Name           = "GDB_UI_" .. scriptKey
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

-- Punto del cursor
local cursorDot = Instance.new("Frame")
cursorDot.Size             = UDim2.new(0, 6, 0, 6)
cursorDot.AnchorPoint      = Vector2.new(0.5, 0.5)
cursorDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cursorDot.BorderSizePixel  = 0
cursorDot.ZIndex           = 25
cursorDot.Parent           = gui
Instance.new("UICorner", cursorDot).CornerRadius = UDim.new(1, 0)

-- HUD Estado
local hud = Instance.new("Frame")
hud.Size             = UDim2.new(0, 230, 0, 64)
hud.Position         = UDim2.new(0, 15, 0, 15)
hud.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
hud.BorderSizePixel  = 0
hud.ZIndex           = 20
hud.Parent           = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 8)
local hudStroke = Instance.new("UIStroke", hud)
hudStroke.Color     = Color3.fromRGB(50, 50, 75)
hudStroke.Thickness = 1

local hudAim = Instance.new("TextLabel", hud)
hudAim.Size              = UDim2.new(1, -16, 0, 20)
hudAim.Position          = UDim2.new(0, 8, 0, 6)
hudAim.BackgroundTransparency = 1
hudAim.Font              = Enum.Font.GothamBold
hudAim.TextSize          = 12
hudAim.Text              = "🎯 AIM: OFF"
hudAim.TextColor3        = Color3.fromRGB(160, 160, 180)
hudAim.TextXAlignment    = Enum.TextXAlignment.Left
hudAim.ZIndex            = 21

local hudTeam = Instance.new("TextLabel", hud)
hudTeam.Size             = UDim2.new(1, -16, 0, 16)
hudTeam.Position         = UDim2.new(0, 8, 0, 26)
hudTeam.BackgroundTransparency = 1
hudTeam.Font             = Enum.Font.Gotham
hudTeam.TextSize         = 11
hudTeam.Text             = "Mi Equipo: Buscando..."
hudTeam.TextColor3       = Color3.fromRGB(220, 220, 100)
hudTeam.TextXAlignment   = Enum.TextXAlignment.Left
hudTeam.ZIndex           = 21

local hudTarget = Instance.new("TextLabel", hud)
hudTarget.Size           = UDim2.new(1, -16, 0, 16)
hudTarget.Position       = UDim2.new(0, 8, 0, 44)
hudTarget.BackgroundTransparency = 1
hudTarget.Font           = Enum.Font.GothamMedium
hudTarget.TextSize       = 11
hudTarget.Text           = "Objetivo: Ninguno"
hudTarget.TextColor3     = Color3.fromRGB(130, 130, 150)
hudTarget.TextXAlignment = Enum.TextXAlignment.Left
hudTarget.ZIndex         = 21

local function updateHUD(active, targetName, myTeamName)
    if active then
        hudAim.Text       = "🎯 AIM: ACTIVO"
        hudAim.TextColor3 = Color3.fromRGB(80, 255, 120)
        cursorDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 70, 70) end
        guiFovStroke.Color = Color3.fromRGB(255, 70, 70)
    else
        hudAim.Text       = "🎯 AIM: OFF"
        hudAim.TextColor3 = Color3.fromRGB(160, 160, 180)
        cursorDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 220, 0) end
        guiFovStroke.Color = Color3.fromRGB(255, 220, 0)
    end

    hudTeam.Text = "Mi Equipo: " .. (myTeamName or "Neutral / FFA")
    if myTeamName == "Reds" then
        hudTeam.TextColor3 = Color3.fromRGB(255, 90, 90)
    elseif myTeamName == "Blues" then
        hudTeam.TextColor3 = Color3.fromRGB(90, 170, 255)
    else
        hudTeam.TextColor3 = Color3.fromRGB(220, 220, 100)
    end

    if targetName then
        hudTarget.Text       = "Objetivo: " .. targetName
        hudTarget.TextColor3 = Color3.fromRGB(0, 230, 255)
    else
        hudTarget.Text       = "Objetivo: Ninguno"
        hudTarget.TextColor3 = Color3.fromRGB(130, 130, 150)
    end
end

-- ══════════════════════════════════════════════════════════════════
-- 9 · PANEL DE CONFIGURACIÓN [TECLA F]
-- ══════════════════════════════════════════════════════════════════

local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 310, 0, 410)
panel.Position         = UDim2.new(0.5, -155, 0.5, -205)
panel.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 50
panel.Parent           = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(70, 70, 110)
panelStroke.Thickness = 1.5

local pTitle = Instance.new("TextLabel", panel)
pTitle.Size              = UDim2.new(1, -20, 0, 28)
pTitle.Position          = UDim2.new(0, 12, 0, 8)
pTitle.BackgroundTransparency = 1
pTitle.Font              = Enum.Font.GothamBold
pTitle.TextSize          = 14
pTitle.Text              = "⚔  GUERRA DE BLOQUES · V8"
pTitle.TextColor3        = Color3.fromRGB(255, 215, 60)
pTitle.TextXAlignment    = Enum.TextXAlignment.Left
pTitle.ZIndex            = 51

local pSub = Instance.new("TextLabel", panel)
pSub.Size                = UDim2.new(1, -20, 0, 16)
pSub.Position            = UDim2.new(0, 12, 0, 36)
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
    s.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
    s.BorderSizePixel  = 0
    s.ZIndex           = 51
end
createSep(56)

local function createNumInput(labelTxt, key, posY, isFloat)
    local lbl = Instance.new("TextLabel", panel)
    lbl.Size              = UDim2.new(0, 160, 0, 22)
    lbl.Position          = UDim2.new(0, 14, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 12
    lbl.Text              = labelTxt
    lbl.TextColor3        = Color3.fromRGB(210, 210, 230)
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 52

    local box = Instance.new("TextBox", panel)
    box.Size              = UDim2.new(0, 100, 0, 22)
    box.Position          = UDim2.new(0, 190, 0, posY)
    box.BackgroundColor3  = Color3.fromRGB(26, 26, 40)
    box.BorderSizePixel   = 0
    box.Font              = Enum.Font.Gotham
    box.TextSize          = 12
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
    lbl.Size              = UDim2.new(0, 170, 0, 22)
    lbl.Position          = UDim2.new(0, 14, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 12
    lbl.Text              = labelTxt
    lbl.TextColor3        = Color3.fromRGB(210, 210, 230)
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.ZIndex            = 52

    local btn = Instance.new("TextButton", panel)
    btn.Size              = UDim2.new(0, 80, 0, 22)
    btn.Position          = UDim2.new(0, 210, 0, posY)
    btn.BackgroundColor3  = Color3.fromRGB(30, 30, 48)
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

createNumInput("Radio del FOV (px):",   "FOV",         66, false)
createNumInput("Velocidad de Aim:",     "SPEED",       92, true)
createNumInput("Distancia Máxima (m):", "MAX_DIST",    118, false)
createNumInput("Ajuste de Altura Y:",   "OFF_Y",       144, true)
createSep(172)

createToggle("Apuntar con Click Izq (LMB):", "AIM_LMB",     180)
createToggle("Apuntar con Click Der (RMB):", "AIM_RMB",     206)
createToggle("Chequeo de Paredes:",          "WALL_CHECK",  232)
createToggle("Activar ESP:",                 "ESP_ENABLED", 258)
createToggle("Siluetas ESP (Highlight):",    "ESP_HIGHLIGHT", 284)
createToggle("Mostrar Aliados en ESP:",      "ESP_ALLIES",  310)
createSep(338)

local partBtn = Instance.new("TextButton", panel)
partBtn.Size              = UDim2.new(1, -28, 0, 26)
partBtn.Position          = UDim2.new(0, 14, 0, 346)
partBtn.BackgroundColor3  = Color3.fromRGB(35, 45, 75)
partBtn.BorderSizePixel   = 0
partBtn.Font              = Enum.Font.GothamBold
partBtn.TextSize          = 12
partBtn.TextColor3        = Color3.fromRGB(220, 230, 255)
partBtn.ZIndex            = 53
Instance.new("UICorner", partBtn).CornerRadius = UDim.new(0, 5)

local function updatePartText()
    local name = (CFG.TARGET_PART == "Head") and "CABEZA" or "TORSO (HumanoidRootPart)"
    partBtn.Text = "🎯 Prioridad de Disparo: " .. name
end
updatePartText()

partBtn.MouseButton1Click:Connect(function()
    CFG.TARGET_PART = (CFG.TARGET_PART == "Head") and "HumanoidRootPart" or "Head"
    updatePartText()
    saveConfig()
end)

local closeBtn = Instance.new("TextButton", panel)
closeBtn.Size              = UDim2.new(0, 75, 0, 22)
closeBtn.Position          = UDim2.new(1, -85, 0, 10)
closeBtn.BackgroundColor3  = Color3.fromRGB(150, 35, 35)
closeBtn.BorderSizePixel   = 0
closeBtn.Font              = Enum.Font.GothamBold
closeBtn.TextSize          = 11
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
-- 10 · RENDERIZADO DEL ESP
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
        bb.Size         = UDim2.new(0, 80, 0, 75)
        bb.StudsOffset  = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop  = true
        bb.ResetOnSpawn = false
        bb.Parent       = espFolder

        local box = Instance.new("Frame", bb)
        box.Size                 = UDim2.new(1, 0, 1, 0)
        box.BackgroundTransparency = 1
        box.BorderSizePixel      = 0
        local boxStroke = Instance.new("UIStroke", box)
        boxStroke.Thickness = 1.5

        local nameLbl = Instance.new("TextLabel", bb)
        nameLbl.Size              = UDim2.new(1, 40, 0, 14)
        nameLbl.Position          = UDim2.new(0, -20, 0, -16)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font              = Enum.Font.GothamBold
        nameLbl.TextSize          = 11
        nameLbl.TextStrokeTransparency = 0.4
        nameLbl.TextColor3        = mainColor

        local distLbl = Instance.new("TextLabel", bb)
        distLbl.Size              = UDim2.new(1, 0, 0, 12)
        distLbl.Position          = UDim2.new(0, 0, 1, 3)
        distLbl.BackgroundTransparency = 1
        distLbl.Font              = Enum.Font.Gotham
        distLbl.TextSize          = 10
        distLbl.TextStrokeTransparency = 0.4
        distLbl.TextColor3        = Color3.fromRGB(220, 220, 220)

        local hpBg = Instance.new("Frame", bb)
        hpBg.Size             = UDim2.new(0, 4, 1, 0)
        hpBg.Position         = UDim2.new(1, 4, 0, 0)
        hpBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        hpBg.BorderSizePixel  = 0
        local hpFill = Instance.new("Frame", hpBg)
        hpFill.AnchorPoint      = Vector2.new(0, 1)
        hpFill.Position         = UDim2.new(0, 0, 1, 0)
        hpFill.Size             = UDim2.new(1, 0, 1, 0)
        hpFill.BorderSizePixel  = 0

        entry.billboard = bb
        entry.boxStroke = boxStroke
        entry.nameLbl   = nameLbl
        entry.distLbl   = distLbl
        entry.hpFill    = hpFill

        if CFG.ESP_HIGHLIGHT then
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name                 = "GDB_Highlight"
                hl.Adornee              = char
                hl.FillColor            = mainColor
                hl.FillTransparency     = 0.55
                hl.OutlineColor         = Color3.fromRGB(255, 255, 255)
                hl.OutlineTransparency  = 0.2
                hl.Parent               = espFolder
                entry.highlight         = hl
            end)
        end

        espCache[char] = entry
    end

    local e = espCache[char]
    local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

    e.boxStroke.Color    = mainColor
    e.nameLbl.TextColor3 = mainColor
    e.nameLbl.Text       = string.format("%s [%s]", target.name, targetTeam)
    e.distLbl.Text       = string.format("%.0f m", dist)
    e.hpFill.Size        = UDim2.new(1, 0, hpPct, 0)
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
-- 11 · SELECCIÓN DEL MEJOR OBJETIVO PARA EL AIM
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
-- 13 · BUCLE DE RENDERIZADO EN TIEMPO REAL
-- ══════════════════════════════════════════════════════════════════

RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
    local fovCenter = getFovCenter()
    local myChar    = LocalPlayer.Character
    local myRoot    = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos     = myRoot and myRoot.Position or Camera.CFrame.Position
    local myTeamName = getMyTeamName()

    -- 1. Actualizar círculo de FOV
    local diameter = CFG.FOV * 2
    if drawingFov then
        drawingFov.Position = fovCenter
        drawingFov.Radius   = CFG.FOV
        drawingFov.Visible  = true
        guiFov.Visible      = false
    else
        guiFov.Position = UDim2.new(0, fovCenter.X, 0, fovCenter.Y)
        guiFov.Size     = UDim2.new(0, diameter, 0, diameter)
        guiFov.Visible  = true
    end

    cursorDot.Position = UDim2.new(0, fovCenter.X, 0, fovCenter.Y)

    -- 2. Recolectar personajes vivos
    local allTargets = getAllTargets()

    -- 3. Actualizar ESP en tiempo real
    updateAllESP(allTargets, myPos)

    -- 4. Comprobación directa de botones de Aim
    local aimingNow = isAimKeyPressed()

    if not aimingNow or not myChar or not myRoot then
        updateHUD(false, nil, myTeamName)
        return
    end

    -- 5. Seleccionar mejor enemigo visible dentro del radio FOV
    local target, targetPart = getBestTarget(allTargets, fovCenter, myChar)

    if not target or not targetPart then
        updateHUD(true, nil, myTeamName)
        return
    end

    -- 6. Apuntar la cámara directamente hacia el objetivo
    local camPos = Camera.CFrame.Position
    local aimPos = targetPart.Position + Vector3.new(0, CFG.OFF_Y, 0)
    local targetLook = CFrame.lookAt(camPos, aimPos)

    if CFG.SPEED >= 1 then
        Camera.CFrame = targetLook
    else
        Camera.CFrame = Camera.CFrame:Lerp(targetLook, math.clamp(CFG.SPEED, 0.05, 1))
    end

    updateHUD(true, target.name, myTeamName)
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
    print("[GDB v8] Script apagado correctamente.")
end

genv.__GDB_SHUTDOWN = shutdown

-- ══════════════════════════════════════════════════════════════════
-- 15 · LISTO
-- ══════════════════════════════════════════════════════════════════

print(string.format("[GDB v8] Iniciado | FOV: %dpx | LMB: %s | RMB: %s | Menú: Tecla F",
    CFG.FOV,
    CFG.AIM_LMB and "Activado" or "Desactivado",
    CFG.AIM_RMB and "Activado" or "Desactivado"
))
