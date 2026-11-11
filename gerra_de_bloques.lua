--[[
    GUERRA DE BLOQUES — v11 (PRECISIÓN TOTAL & MIRA DINÁMICA ULTRA-SYNC)
    Nivel 3 Seguro (Sin hooks, 100% funcional)

    Novedades v11:
    1. Sincronización Dinámica con la Mira (Dynamic Sight Tracking):
       El círculo de FOV y el punto central de impacto ya no están fijos en el centro estático.
       Rastrean en tiempo real la posición física 3D de la mira (Sight / Scope / Lamp / Reticle)
       y el cañón del arma (MuzzleAttachment / Handle) en el Viewmodel de la cámara.
       Si el arma se mueve por respiración, balanceo o el culatazo de disparo, el FOV y el aim
       se mueven milimétricamente junto con la mira.
    2. Corrección Balística y Anti-Parallax:
       Eliminado el error de ángulo angular que causaba que el tiro se desfasara.
       La orientación se calcula directamente desde la cámara hacia el objetivo con
       compensación geométrica precisa.
    3. Compensación Activa de Retroceso (Anti-Recoil Compensator):
       Mide en tiempo real la desviación angular (pitch y yaw) del cañón al disparar en ráfaga
       y contrarresta exactamente la elevación del arma para que todas las balas impacten en la cabeza.
    4. Arquitectura de Renderizado en 2 Fases (Sin temblores):
       - Fase 1 (Aim Lock @ Camera.Value + 2): Apuntado limpio después del ratón del jugador
         y antes de que el juego aplique el retroceso visual, evitando conflictos con ARRecoilUndo.
       - Fase 2 (Visual Sync @ Camera.Value + 5): Sincronización visual del FOV y retícula
         inmediatamente después de que el Viewmodel del arma se posicione para el fotograma.
    5. ESP limpio optimizado, menú de configuración [F] y apagado seguro [DEL].
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
-- 2 · CONFIGURACIÓN Y PERSISTENCIA
-- ══════════════════════════════════════════════════════════════════

local CFG = {
    FOV             = 160,       -- Radio del FOV en píxeles
    SPEED           = 0.85,      -- Firmeza de seguimiento (0.1 a 1.0, 1.0 = bloqueo instantáneo)
    OFF_Y           = 0.0,       -- Offset de altura
    MAX_DIST        = 750,       -- Distancia máxima en studs
    AIM_LMB         = true,      -- Aim con Click Izquierdo
    AIM_RMB         = true,      -- Aim con Click Derecho
    WALL_CHECK      = true,      -- Chequeo de paredes
    TARGET_PART     = "Head",    -- "Head" o "HumanoidRootPart"
    RECOIL_COMP     = true,      -- Compensar activamente el retroceso del arma al disparar
    ESP_ENABLED     = true,      -- Activar ESP
    ESP_HIGHLIGHT   = true,      -- Silueta coloreada
    ESP_ALLIES      = false,     -- Ocultar aliados (solo enemigos)
}

local CONFIG_FILE = "GDB_Config_v11.json"

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

local conns                = {}
local espCache             = {}
local renderNameAim        = "GDB_AimLoop_" .. scriptKey
local renderNameVisual     = "GDB_VisualLoop_" .. scriptKey
local drawingFov           = nil
local gui                  = nil
local currentReticleCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function isAimKeyPressed()
    if not CFG.AIM_LMB and not CFG.AIM_RMB then return false end
    local lmb = CFG.AIM_LMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local rmb = CFG.AIM_RMB and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    return lmb or rmb
end

-- ══════════════════════════════════════════════════════════════════
-- 4 · RASTREO DINÁMICO DEL CAÑÓN Y DE LA MIRA (3D ENGINE SYNC)
-- ══════════════════════════════════════════════════════════════════

local function getWeaponAimData()
    local char = LocalPlayer.Character
    local cam  = Workspace.CurrentCamera

    -- 1. Prioridad: Buscar en el Viewmodel que el juego añade dentro de CurrentCamera
    -- El Viewmodel es el modelo en primera persona que experimenta el retroceso, la respiración y el balanceo.
    for _, model in ipairs(cam:GetChildren()) do
        if model:IsA("Model") then
            -- A) Salida del cañón (Muzzle)
            local att = model:FindFirstChild("MuzzleAttachment", true)
            local muzzleCF = nil
            if att and att:IsA("Attachment") then
                muzzleCF = att.WorldCFrame
            else
                local mPart = model:FindFirstChild("Muzzle", true)
                if mPart and mPart:IsA("BasePart") then
                    muzzleCF = mPart.CFrame
                else
                    local handle = model:FindFirstChild("Handle", true)
                    if handle and handle:IsA("BasePart") then
                        local hAtt = handle:FindFirstChild("MuzzleAttachment")
                        if hAtt and hAtt:IsA("Attachment") then
                            muzzleCF = hAtt.WorldCFrame
                        else
                            muzzleCF = handle.CFrame * CFrame.new(0, 0, -1.5)
                        end
                    end
                end
            end

            -- B) Detección de la mira física del arma (Sight / Scope / Lamp / Reticle)
            local sightPart = model:FindFirstChild("Sight", true)
                           or model:FindFirstChild("FrontSight", true)
                           or model:FindFirstChild("ScopeGlass", true)
                           or model:FindFirstChild("Reticle", true)
                           or model:FindFirstChild("Lamp", true)
            local sightCF = (sightPart and sightPart:IsA("BasePart")) and sightPart.CFrame or muzzleCF

            if muzzleCF then
                return muzzleCF, (sightCF or muzzleCF), true
            end
        end
    end

    -- 2. Respaldo: Buscar en la Tool equipada en el personaje (tercera persona)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local att = tool:FindFirstChild("MuzzleAttachment", true)
            if att and att:IsA("Attachment") then
                return att.WorldCFrame, att.WorldCFrame, true
            end
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                local hAtt = handle:FindFirstChild("MuzzleAttachment")
                if hAtt and hAtt:IsA("Attachment") then
                    return hAtt.WorldCFrame, hAtt.WorldCFrame, true
                end
                local hCF = handle.CFrame * CFrame.new(0, 0, -1.5)
                return hCF, hCF, true
            end
        end
    end

    return cam.CFrame, cam.CFrame, false
end

-- ══════════════════════════════════════════════════════════════════
-- 5 · CENTRO DINÁMICO DE LA MIRA Y DE DISPARO (EN PANTALLA 2D)
-- ══════════════════════════════════════════════════════════════════

local function getFiringReticleCenter()
    local cam = Workspace.CurrentCamera
    local muzzleCF, sightCF, hasWeapon = getWeaponAimData()

    if hasWeapon then
        -- 1. Proyectar la dirección hacia donde apunta físicamente el cañón/mira del arma
        -- Cuando el arma dispara o se sacude por retroceso, LookVector se eleva en 3D
        local aimWorldTarget = muzzleCF.Position + (muzzleCF.LookVector * 150)
        local screenPos, onScreen = cam:WorldToViewportPoint(aimWorldTarget)

        if onScreen and screenPos.Z > 0 then
            return Vector2.new(screenPos.X, screenPos.Y), muzzleCF, sightCF, true
        end

        -- 2. Respaldo por posición de la mira física del arma
        local sPos, sOnScreen = cam:WorldToViewportPoint(sightCF.Position)
        if sOnScreen and sPos.Z > 0 then
            return Vector2.new(sPos.X, sPos.Y), muzzleCF, sightCF, true
        end
    end

    -- 3. Respaldo si no hay arma o está fuera de vista: centro exacto de la pantalla
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    return center, cam.CFrame, cam.CFrame, false
end

-- ══════════════════════════════════════════════════════════════════
-- 6 · DETECCIÓN PRECISA DE EQUIPOS
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

    if char:FindFirstChild("Accessory (Keffiyeh_3)") then return "Reds" end
    if char:FindFirstChild("Accessory (Afrika Balaklava)") then return "Blues" end

    return nil
end

local function isEnemy(char)
    if not char or char == LocalPlayer.Character then return false end

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
-- 7 · RECOLECCIÓN DE OBJETIVOS
-- ══════════════════════════════════════════════════════════════════

local function getAllTargets()
    local targets = {}
    local seen = {}

    -- Jugadores
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

    -- Bots oficiales (workspace.BotRigs)
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

    -- Live folder
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

    -- Otros modelos
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
-- 8 · VISIBILIDAD (RAYCAST LIMPIO)
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
-- 9 · INTERFAZ Y CÍRCULO FOV
-- ══════════════════════════════════════════════════════════════════

do
    local sg = Instance.new("ScreenGui")
    sg.Name           = "GDB_Core_" .. scriptKey
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

-- Punto central sincronizado con el impacto
local reticleDot = Instance.new("Frame")
reticleDot.Size             = UDim2.new(0, 4, 0, 4)
reticleDot.AnchorPoint      = Vector2.new(0.5, 0.5)
reticleDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
reticleDot.BorderSizePixel  = 0
reticleDot.ZIndex           = 20
reticleDot.Parent           = gui
Instance.new("UICorner", reticleDot).CornerRadius = UDim.new(1, 0)

-- ══════════════════════════════════════════════════════════════════
-- 10 · PANEL DE CONFIGURACIÓN [TECLA F]
-- ══════════════════════════════════════════════════════════════════

local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 300, 0, 420)
panel.Position         = UDim2.new(0.5, -150, 0.5, -210)
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
pTitle.Text              = "⚔  GUERRA DE BLOQUES · V11"
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
createNumInput("Velocidad Aim (0.1-1):","SPEED",       86, true)
createNumInput("Distancia Máxima (m):", "MAX_DIST",    112, false)
createNumInput("Ajuste Altura Y:",      "OFF_Y",       138, true)
createSep(164)

createToggle("Aim con Click Izq (LMB):", "AIM_LMB",     172)
createToggle("Aim con Click Der (RMB):", "AIM_RMB",     198)
createToggle("Compensar Retroceso:",     "RECOIL_COMP", 224)
createToggle("Chequeo de Paredes:",      "WALL_CHECK",  250)
createToggle("Activar ESP:",             "ESP_ENABLED", 276)
createToggle("Siluetas (Highlight):",    "ESP_HIGHLIGHT", 302)
createToggle("Mostrar Aliados en ESP:",  "ESP_ALLIES",  328)
createSep(356)

local partBtn = Instance.new("TextButton", panel)
partBtn.Size              = UDim2.new(1, -28, 0, 26)
partBtn.Position          = UDim2.new(0, 14, 0, 366)
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
-- 11 · ESP LIMPIO (SIN CUADRADO, SOLO TEXTO + VIDA + SILUETA)
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

        local nameLbl = Instance.new("TextLabel", bb)
        nameLbl.Size              = UDim2.new(1, 0, 0, 15)
        nameLbl.Position          = UDim2.new(0, 0, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font              = Enum.Font.GothamBold
        nameLbl.TextSize          = 11
        nameLbl.TextStrokeTransparency = 0.2
        nameLbl.TextColor3        = mainColor

        local distLbl = Instance.new("TextLabel", bb)
        distLbl.Size              = UDim2.new(1, 0, 0, 13)
        distLbl.Position          = UDim2.new(0, 0, 0, 16)
        distLbl.BackgroundTransparency = 1
        distLbl.Font              = Enum.Font.Gotham
        distLbl.TextSize          = 10
        distLbl.TextStrokeTransparency = 0.2
        distLbl.TextColor3        = Color3.fromRGB(225, 225, 225)

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
-- 12 · SELECCIÓN Y BLOQUEO DEL OBJETIVO (AIMBOT)
-- ══════════════════════════════════════════════════════════════════

local function getBestTarget(allTargets, reticlePos, myChar)
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
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - reticlePos).Magnitude
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
-- 13 · TECLAS DE ACCESO RÁPIDO
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
-- 14 · BUCLE DE RENDERIZADO EN 2 FASES (PRECISIÓN TOTAL & ULTRA-SYNC)
-- ══════════════════════════════════════════════════════════════════

-- FASE 1: BLOQUEO DE AIM Y COMPENSACIÓN ANTI-RETROCESO (@ Camera.Value + 2)
-- Se ejecuta inmediatamente después del ratón de Roblox (Camera.Value) y ANTES de que el juego
-- aplique su retroceso visual temporal (Camera.Value + 3). Esto garantiza que el aim se aplique
-- sobre la base de la cámara sin romper el ciclo ARRecoil / ARRecoilUndo del juego.
RunService:BindToRenderStep(renderNameAim, Enum.RenderPriority.Camera.Value + 2, function()
    local isAiming = isAimKeyPressed()
    if not isAiming then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myChar or not myRoot then return end

    local allTargets = getAllTargets()
    local target, targetPart = getBestTarget(allTargets, currentReticleCenter, myChar)

    if target and targetPart then
        local targetPos = targetPart.Position + Vector3.new(0, CFG.OFF_Y, 0)
        local camPos    = Camera.CFrame.Position

        -- Vector limpio y directo hacia el objetivo (elimina cualquier desfase de parallax)
        local targetDir = (targetPos - camPos).Unit
        local desiredLook = CFrame.lookAt(camPos, camPos + targetDir)

        local finalLook = desiredLook
        if CFG.RECOIL_COMP then
            local muzzleCF, _, hasWeapon = getWeaponAimData()
            if hasWeapon then
                -- Medir la desviación angular local del cañón respecto a la cámara producida por el recoil
                local localDev = Camera.CFrame.Rotation:ToObjectSpace(muzzleCF.Rotation)
                local devPitch, devYaw, _ = localDev:ToOrientation()

                -- Contrarrestar exactamente la elevación y dispersión del retroceso
                local compAngles = CFrame.Angles(-devPitch, -devYaw, 0)
                finalLook = desiredLook * compAngles
            end
        end

        local snapSpeed = math.clamp(CFG.SPEED, 0.05, 1.0)
        if snapSpeed >= 1.0 then
            Camera.CFrame = finalLook
        else
            Camera.CFrame = Camera.CFrame:Lerp(finalLook, snapSpeed)
        end
    end
end)

-- FASE 2: SINCRONIZACIÓN VISUAL DE LA MIRA (FOV) Y ESP (@ Camera.Value + 5)
-- Se ejecuta después de que el Viewmodel del juego (Camera.Value + 4) posicione el arma para el fotograma.
-- De esta forma, el círculo de FOV y el punto de impacto se anclan y mueven en tiempo real
-- exactamente con la mira física del arma y el salto del retroceso.
RunService:BindToRenderStep(renderNameVisual, Enum.RenderPriority.Camera.Value + 5, function()
    local reticleCenter = getFiringReticleCenter()
    currentReticleCenter = reticleCenter

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos  = myRoot and myRoot.Position or Camera.CFrame.Position

    -- 1. Actualizar el círculo de FOV anclado al centro dinámico de la mira
    local diameter = CFG.FOV * 2
    if drawingFov then
        drawingFov.Position = reticleCenter
        drawingFov.Radius   = CFG.FOV
        drawingFov.Visible  = true
        guiFov.Visible      = false
    else
        guiFov.Position = UDim2.new(0, reticleCenter.X, 0, reticleCenter.Y)
        guiFov.Size     = UDim2.new(0, diameter, 0, diameter)
        guiFov.Visible  = true
    end

    reticleDot.Position = UDim2.new(0, reticleCenter.X, 0, reticleCenter.Y)

    -- 2. Cambiar color del retículo si se está apuntando
    local isAiming = isAimKeyPressed()
    if isAiming then
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 60, 60) end
        guiFovStroke.Color = Color3.fromRGB(255, 60, 60)
        reticleDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    else
        if drawingFov then drawingFov.Color = Color3.fromRGB(255, 220, 0) end
        guiFovStroke.Color = Color3.fromRGB(255, 220, 0)
        reticleDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end

    -- 3. Actualizar ESP limpio
    local allTargets = getAllTargets()
    updateAllESP(allTargets, myPos)
end)

-- ══════════════════════════════════════════════════════════════════
-- 15 · APAGADO LIMPIO
-- ══════════════════════════════════════════════════════════════════

local function shutdown()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)

    pcall(function()
        RunService:UnbindFromRenderStep(renderNameAim)
        RunService:UnbindFromRenderStep(renderNameVisual)
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
    print("[GDB v11] Script apagado correctamente.")
end

genv.__GDB_SHUTDOWN = shutdown

-- ══════════════════════════════════════════════════════════════════
-- 16 · INICIO
-- ══════════════════════════════════════════════════════════════════

print(string.format("[GDB v11] Listo | Mira dinámica ultra-sync | FOV: %dpx | Bloqueo firme: %.2f | Menú: F",
    CFG.FOV,
    CFG.SPEED
))
