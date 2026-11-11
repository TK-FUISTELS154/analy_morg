-- ==============================================================================
-- 🛡️ GUERRA DE BLOQUES - AIM PREDICTIVO + ESP TOTAL (SECURI_V4 INTEGRATED)
-- ==============================================================================
-- Versión 4.0 — Reescritura completa con:
--   • Seguridad nivel 4: bloqueo de todos los remotes de telemetría detectados
--     en la auditoría (CheatFlag, ReportClient, ReportTouch, ReportUI,
--     ReportFirst, ClockProbe, espupdate, aimassisttarget, AimShare)
--   • Aim con clic IZQUIERDO Y DERECHO (ambos activan el aimbot)
--   • ESP con colores, distancia, HP y estado visible/oculto
--   • Predicción cinemática de segundo orden + balística
--   • Protección anti-kick, anti-namecall, GUI oculta y randomizada
--   • Limpieza total de rastros al cerrar
-- ==============================================================================

-- ============================================================
-- SECCIÓN 1: NÚCLEO SECURI_V4
-- ============================================================
local Securi = (type(getgenv) == "function" and (getgenv().Securi or getgenv().SecuriV4)) or nil

if not Securi then
    Securi = {}
    Securi.VERSION = "4.0.0"
    Securi.NAME    = "SecuriV4_GuerraBloques"

    -- Referencias nativas capturadas antes de que cualquier hook pueda intervenir
    local rawGame      = (typeof(workspace) == "Instance" and workspace.Parent) or game
    local rawCloneref  = (type(cloneref)    == "function" and cloneref)         or nil
    local rawPcall     = pcall
    local rawTostring  = tostring
    local rawPairs     = pairs
    local rawIpairs    = ipairs
    local rawType      = type
    local rawTypeof    = typeof
    local rawMath      = { clamp = math.clamp, max = math.max, min = math.min,
                           floor = math.floor, random = math.random, rad = math.rad,
                           atan2 = math.atan2, pow = math.pow, abs = math.abs,
                           sqrt = math.sqrt }
    local rawString    = { format = string.format, lower = string.lower,
                           char = string.char, sub = string.sub }
    local rawTable     = { insert = table.insert, remove = table.remove,
                           clear = table.clear, concat = table.concat }
    local rawSetmeta   = setmetatable
    local rawRawget    = rawget
    local rawRawset    = rawset

    local function safeCloneref(inst)
        if not inst or not rawCloneref then return inst end
        local ok, c = rawPcall(rawCloneref, inst)
        if ok and c and rawTypeof(c) == "Instance" then
            local valid = rawPcall(function() return c.ClassName end)
            if valid then return c end
        end
        return inst
    end

    -- Acceso nativo a métodos de game/instance sin pasar por __namecall
    local NativeGet  = rawGame.GetService
    local NativeFind = rawGame.FindFirstChildOfClass
    local NativeWait = rawGame.WaitForChild

    -- --------------------------------------------------------
    -- 1A. Detector de capacidades del ejecutor
    -- --------------------------------------------------------
    Securi.Cap = {
        canHook    = false,
        canHUI     = false,
        canProtect = false,
    }
    local function hasFn(name)
        local env = (type(getgenv) == "function" and getgenv()) or getfenv(0)
        return env and rawType(env[name]) == "function"
    end
    Securi.Cap.canHook    = hasFn("hookmetamethod") or hasFn("hookfunction")
    Securi.Cap.canHUI     = hasFn("gethui")         or hasFn("get_hidden_gui")
    Securi.Cap.canProtect = hasFn("protectgui")     or hasFn("protect_gui")

    -- --------------------------------------------------------
    -- 1B. Resolución segura de servicios (caché + cloneref)
    -- --------------------------------------------------------
    Securi.Services = rawSetmeta({}, {
        __index = function(t, name)
            local cached = rawRawget(t, name)
            if cached then return cached end
            local resolved
            if name == "Workspace" and rawTypeof(workspace) == "Instance" then
                resolved = workspace
            end
            if not resolved then
                local ok, s = rawPcall(NativeGet, rawGame, name)
                if ok and s then resolved = s end
            end
            if not resolved then
                local ok, s = rawPcall(NativeFind, rawGame, name)
                if ok and s then resolved = s end
            end
            if resolved then
                local sec = safeCloneref(resolved)
                rawRawset(t, name, sec)
                return sec
            end
            return nil
        end
    })

    function Securi:GetLocalPlayer()
        local plrs = self.Services.Players
        return plrs and (plrs.LocalPlayer or NativeFind(plrs, "Player"))
    end

    -- --------------------------------------------------------
    -- 1C. Thread seguro
    -- --------------------------------------------------------
    Securi.Thread = {}
    function Securi.Thread:Spawn(fn, ...)
        local args = {...}
        return task.spawn(function() rawPcall(fn, table.unpack(args)) end)
    end
    function Securi.Thread:Safe(fn, fallback, ...)
        local ok, res = rawPcall(fn, ...)
        return ok and res or fallback
    end

    -- --------------------------------------------------------
    -- 1D. Generador de nombres aleatorios
    -- --------------------------------------------------------
    local function randName(len)
        len = len or rawMath.random(14, 22)
        local t = {}
        for i = 1, len do
            local r = rawMath.random(1, 3)
            t[i] = rawString.char(
                r == 1 and rawMath.random(97,122)
             or r == 2 and rawMath.random(65, 90)
             or              rawMath.random(48, 57)
            )
        end
        return rawTable.concat(t)
    end
    Securi._randName = randName

    -- --------------------------------------------------------
    -- 1E. GUI segura (HUI > protectgui > CoreGui > PlayerGui)
    -- --------------------------------------------------------
    Securi.GUI = { _names = {}, _instances = rawSetmeta({}, {__mode = "k"}) }

    function Securi.GUI:SetName(inst, len)
        if not inst then return end
        local n = randName(len or 16)
        inst.Name = n
        self._names[n] = true
        return n
    end

    function Securi.GUI:Create()
        local name = randName(20)
        local gethuiFn    = hasFn("gethui")       and gethui        or hasFn("get_hidden_gui") and get_hidden_gui or nil
        local protectFn   = hasFn("protectgui")   and protectgui    or hasFn("protect_gui")    and protect_gui    or nil
        local coreGui     = Securi.Services.CoreGui
        local lp          = Securi:GetLocalPlayer()

        local function makeGui()
            local g = Instance.new("ScreenGui")
            g.Name = name ; g.ResetOnSpawn = false
            g.DisplayOrder = 2000000000 ; g.IgnoreGuiInset = true
            g.Archivable = false
            return g
        end

        local container
        -- Prioridad 1: HUI (el más seguro, invisible para el juego)
        if gethuiFn then
            rawPcall(function()
                local hui = gethuiFn()
                if hui then
                    local g = makeGui() ; g.Parent = hui
                    if g.Parent then container = g end
                end
            end)
        end
        -- Prioridad 2: protectgui sobre CoreGui
        if not container and protectFn and coreGui then
            rawPcall(function()
                local g = makeGui() ; protectFn(g) ; g.Parent = coreGui
                if g.Parent then container = g end
            end)
        end
        -- Prioridad 3: CoreGui sin protección
        if not container and coreGui then
            rawPcall(function()
                local g = makeGui() ; g.Parent = coreGui
                if g.Parent then container = g end
            end)
        end
        -- Prioridad 4: PlayerGui (último recurso)
        if not container and lp then
            rawPcall(function()
                local pg = lp:FindFirstChildOfClass("PlayerGui")
                    or NativeWait(lp, "PlayerGui", 5)
                if pg then
                    local g = makeGui() ; g.Parent = pg
                    if g.Parent then container = g end
                end
            end)
        end

        self._names[name] = true
        if container then self._instances[container] = true end
        return container
    end

    -- --------------------------------------------------------
    -- 1F. Anti-Kick (hookfunction sobre Player.Kick)
    -- --------------------------------------------------------
    Securi.AntiKick = { installed = false }
    function Securi.AntiKick:Install(plr)
        if self.installed then return end
        local p = plr or Securi:GetLocalPlayer()
        if not p then return end
        local hookFn        = hasFn("hookfunction")  and hookfunction        or nil
        local checkcallerFn = hasFn("checkcaller")   and checkcaller         or function() return false end
        local newcclosureFn = hasFn("newcclosure")   and newcclosure         or function(f) return f end
        rawPcall(function()
            if hookFn and rawTypeof(p.Kick) == "function" then
                local orig
                orig = hookFn(p.Kick, newcclosureFn(function(self2, ...)
                    if checkcallerFn() then return orig(self2, ...) end
                    -- Bloquear kick del servidor silenciosamente
                end))
            end
        end)
        self.installed = true
    end

    -- --------------------------------------------------------
    -- 1G. Hook de namecall: bloqueo de remotes + ocultación de GUI
    -- --------------------------------------------------------
    Securi.Hooks = {
        hooked         = false,
        blockedRemotes = {},
        -- Weak table: las instancias de GUI que queremos ocultar de GetChildren/GetDescendants
        hiddenInst     = rawSetmeta({}, {__mode = "k"}),
    }

    function Securi.Hooks:Block(name)
        self.blockedRemotes[rawString.lower(rawTostring(name))] = true
        if not self.hooked and Securi.Cap.canHook then
            self:Install()
        end
    end

    function Securi.Hooks:HideInstance(inst)
        if inst then self.hiddenInst[inst] = true end
    end

    function Securi.Hooks:Install()
        if self.hooked then return end
        local hookMMFn      = hasFn("hookmetamethod")  and hookmetamethod    or nil
        local getncFn       = hasFn("getnamecallmethod") and getnamecallmethod
                           or hasFn("get_namecall_method") and get_namecall_method or nil
        local checkcallerFn = hasFn("checkcaller")     and checkcaller       or function() return false end
        local newcclosureFn = hasFn("newcclosure")     and newcclosure       or function(f) return f end
        if not hookMMFn or not getncFn then return end

        local blockedRemotes = self.blockedRemotes
        local hiddenInst     = self.hiddenInst

        rawPcall(function()
            local oldNC
            oldNC = hookMMFn(rawGame, "__namecall", newcclosureFn(function(obj, ...)
                local method     = getncFn()
                local isExploit  = checkcallerFn()

                -- Bloquear remotes de telemetría / detección
                if method == "FireServer" or method == "fireServer"
                or method == "InvokeServer" or method == "invokeServer" then
                    local n = rawString.lower(rawTostring(obj.Name or ""))
                    if blockedRemotes[n] then return nil end
                end

                -- Ocultar instancias del GUI a GetChildren/GetDescendants del juego
                if not isExploit then
                    if method == "GetDescendants" or method == "GetChildren" then
                        local ok, res = rawPcall(oldNC, obj, ...)
                        if ok and rawType(res) == "table" then
                            local clean = {}
                            for _, v in rawIpairs(res) do
                                if not hiddenInst[v] then
                                    rawTable.insert(clean, v)
                                end
                            end
                            return clean
                        end
                        return ok and res or {}
                    end
                    -- Proteger FindFirstChild de que devuelva nuestra GUI
                    if method == "FindFirstChild" or method == "FindFirstChildOfClass" then
                        local ok, res = rawPcall(oldNC, obj, ...)
                        if ok and res and hiddenInst[res] then return nil end
                        return ok and res
                    end
                end

                return oldNC(obj, ...)
            end))
            self.hooked = true
        end)
    end

    -- --------------------------------------------------------
    -- 1H. Almacenamiento persistente
    -- --------------------------------------------------------
    Securi.Storage = { folder = "SecuriV4Data" }
    function Securi.Storage:Save(file, data)
        local wf  = hasFn("writefile")  and writefile  or nil
        local mkf = hasFn("makefolder") and makefolder or nil
        local isf = hasFn("isfolder")   and isfolder   or nil
        local http= Securi.Services.HttpService
        if wf and http then
            rawPcall(function()
                if mkf and isf and not isf(self.folder) then mkf(self.folder) end
                wf(self.folder .. "/" .. file .. ".json", http:JSONEncode(data))
            end)
            return true
        end
        return false
    end
    function Securi.Storage:Load(file)
        local rf  = hasFn("readfile") and readfile or nil
        local isf = hasFn("isfile")   and isfile   or nil
        local http= Securi.Services.HttpService
        if rf and http then
            local path = self.folder .. "/" .. file .. ".json"
            if isf and isf(path) then
                local ok, content = rawPcall(rf, path)
                if ok and content then
                    local ok2, data = rawPcall(function() return http:JSONDecode(content) end)
                    if ok2 and rawType(data) == "table" then return data end
                end
            end
        end
        return nil
    end

    -- Registrar en genv para reutilizar entre ejecuciones
    local genv2 = (type(getgenv) == "function" and getgenv()) or nil
    if genv2 then
        genv2.Securi  = Securi
        genv2.SecuriV4 = Securi
    end
end

-- ============================================================
-- SECCIÓN 2: SERVICIOS Y BOOTSTRAP DE PROTECCIONES
-- ============================================================
local Players          = Securi.Services.Players
local RunService       = Securi.Services.RunService
local UserInputService = Securi.Services.UserInputService
local Workspace        = Securi.Services.Workspace
local Stats            = Securi.Services.Stats
local LocalPlayer      = Securi:GetLocalPlayer()

-- Anti-kick inmediato
Securi.AntiKick:Install(LocalPlayer)

-- Bloquear TODOS los remotes de telemetría identificados en el dump:
-- CheatFlag, ReportClient, ReportTouch, ReportUI, ReportFirst (confirmados en auditoría)
-- ClockProbe: sonda de timing para detectar manipulación de velocidad
-- espupdate: el juego trackea posiciones para su propio ESP interno
-- aimassisttarget: reporta a quién apuntas al servidor
-- AimShare: comparte aim con el servidor (UnreliableRemoteEvent)
-- Gunship2: evitar telemetría de combate aéreo
local BLOCKED_REMOTES = {
    "cheatflag", "reportclient", "reporttouch", "reportui", "reportfirst",
    "clockprobe", "espupdate", "aimassisttarget", "aimshare",
    "gunship2",
}
for _, name in ipairs(BLOCKED_REMOTES) do
    Securi.Hooks:Block(name)
end

-- ============================================================
-- SECCIÓN 3: CONFIGURACIÓN PERSISTENTE
-- ============================================================
local CFG_FILE = "GuerraBloques_v4"

local DEFAULT = {
    FOV_RADIUS        = 200,     -- Radio del FOV en px (20–1200)
    OFFSET_X          = 0,       -- Desplazamiento horizontal del puntero
    OFFSET_Y          = 0,       -- Desplazamiento vertical del puntero
    AIM_SPEED         = 0.38,    -- Suavizado: 0.01 = muy suave, 1 = instantáneo
    TARGET_PART       = "Head",  -- "Head" | "UpperTorso"
    PREDICTION_FACTOR = 1.2,     -- Multiplicador de predicción (0 = off)
    BULLET_SPEED      = 1600,    -- Velocidad de bala en studs/s
    GRAVITY_COMP      = 0.12,    -- Compensación de gravedad (0–2)
    WALL_CHECK        = true,    -- Verificar línea de visión antes de apuntar
    FOLLOW_MOUSE      = true,    -- FOV sigue al mouse (true) o al centro de cámara (false)
    MIN_ENEMY_HEALTH  = 1,       -- Descartar enemigos con HP <= este valor
    -- NUEVO: control de qué botones activan el aimbot
    AIM_ON_LMB        = true,    -- Clic IZQUIERDO activa aim
    AIM_ON_RMB        = true,    -- Clic DERECHO activa aim
    -- NUEVO: ESP de equipo propio (amigos)
    SHOW_FRIENDLY_ESP = false,
    -- NUEVO: Límite de distancia para ESP (studs, 0 = sin límite)
    ESP_MAX_DISTANCE  = 0,
}

local Config = {}
local loaded = Securi.Storage:Load(CFG_FILE)
for k, v in pairs(DEFAULT) do
    Config[k] = (loaded and loaded[k] ~= nil) and loaded[k] or v
end

local genv = (type(getgenv) == "function" and getgenv()) or _G
if type(genv.__GBConfig) == "table" and not loaded then
    for k, v in pairs(genv.__GBConfig) do
        if Config[k] ~= nil then Config[k] = v end
    end
end

local function SaveConfig()
    genv.__GBConfig = Config
    Securi.Storage:Save(CFG_FILE, Config)
end

-- ============================================================
-- SECCIÓN 4: ESTADO GLOBAL DEL AIM
-- ============================================================
-- Número de botones actualmente presionados que activan el aim
local aimPressCount = 0
local isActive      = true
local conns         = {}     -- Tabla de RBXSignalConnection para limpiar al cerrar
local espCache      = {}     -- [character] = { Highlight, Billboard, Label, conns={} }
local kinematics    = {}     -- [character] = { lastPos, vel, acc, lastTime }

-- Accessory de equipo (identificadores de equipo en este juego)
local TEAM1_ACC = "Accessory (Keffiyeh_3)"
local TEAM2_ACC = "Accessory (Afrika Balaklava)"

-- ============================================================
-- SECCIÓN 5: GUI PROTEGIDA
-- ============================================================
local gui = Securi.GUI:Create()
if not gui then
    -- Fallback mínimo si no se pudo crear la GUI
    gui = Instance.new("ScreenGui")
    gui.Name = Securi._randName(20)
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2e9
    gui.IgnoreGuiInset = true
    gui.Archivable = false
    local lp2 = Securi:GetLocalPlayer()
    if lp2 then
        local pg = lp2:FindFirstChildOfClass("PlayerGui")
        if pg then gui.Parent = pg end
    end
end
-- Ocultar la GUI completa del hook de namecall del juego
Securi.Hooks:HideInstance(gui)

-- Carpeta para highlights/billboards ESP
local espFolder = Instance.new("Folder")
Securi.GUI:SetName(espFolder, 16)
espFolder.Archivable = false
espFolder.Parent = gui

-- Punto central (sigue al aim reference point)
local centerDot = Instance.new("Frame")
Securi.GUI:SetName(centerDot, 14)
centerDot.AnchorPoint    = Vector2.new(0.5, 0.5)
centerDot.Size           = UDim2.new(0, 6, 0, 6)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel  = 0
centerDot.ZIndex           = 10
centerDot.Parent           = gui
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

-- Punto de predicción (punto futuro proyectado)
local predDot = Instance.new("Frame")
Securi.GUI:SetName(predDot, 14)
predDot.AnchorPoint    = Vector2.new(0.5, 0.5)
predDot.Size           = UDim2.new(0, 5, 0, 5)
predDot.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
predDot.BorderSizePixel  = 0
predDot.Visible          = false
predDot.ZIndex           = 10
predDot.Parent           = gui
Instance.new("UICorner", predDot).CornerRadius = UDim.new(1, 0)

-- Círculo de FOV
local fovFrame = Instance.new("Frame")
Securi.GUI:SetName(fovFrame, 14)
fovFrame.AnchorPoint    = Vector2.new(0.5, 0.5)
fovFrame.Size           = UDim2.new(0, Config.FOV_RADIUS*2, 0, Config.FOV_RADIUS*2)
fovFrame.BackgroundTransparency = 1
fovFrame.ZIndex         = 5
fovFrame.Parent         = gui
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovFrame)
fovStroke.Color       = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness   = 1.5
fovStroke.Transparency = 0.5

-- Indicador de estado: LMB/RMB activo
local stateLabel = Instance.new("TextLabel")
Securi.GUI:SetName(stateLabel, 14)
stateLabel.Size            = UDim2.new(0, 180, 0, 20)
stateLabel.Position        = UDim2.new(0, 8, 0, 8)
stateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
stateLabel.BackgroundTransparency = 0.55
stateLabel.TextColor3      = Color3.fromRGB(0, 220, 120)
stateLabel.Font            = Enum.Font.GothamBold
stateLabel.TextSize        = 11
stateLabel.Text            = "🎯 AIM: OFF"
stateLabel.ZIndex          = 20
stateLabel.Parent          = gui
Instance.new("UICorner", stateLabel).CornerRadius = UDim.new(0, 4)

-- ============================================================
-- SECCIÓN 6: PANEL DE CONFIGURACIÓN (TECLA F)
-- ============================================================
local cfgPanel = Instance.new("Frame")
Securi.GUI:SetName(cfgPanel, 16)
cfgPanel.Size           = UDim2.new(0, 300, 0, 530)
cfgPanel.Position       = UDim2.new(0.5, -150, 0.5, -265)
cfgPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
cfgPanel.BorderSizePixel  = 0
cfgPanel.Visible          = false
cfgPanel.Active           = true
cfgPanel.Draggable        = true
cfgPanel.ZIndex           = 50
cfgPanel.Parent           = gui
Instance.new("UICorner", cfgPanel).CornerRadius = UDim.new(0, 8)
local cfgStroke = Instance.new("UIStroke", cfgPanel)
cfgStroke.Color = Color3.fromRGB(50, 110, 255) ; cfgStroke.Thickness = 1.2 ; cfgStroke.Transparency = 0.35

local cfgTitle = Instance.new("TextLabel", cfgPanel)
cfgTitle.Size = UDim2.new(1,0,0,36) ; cfgTitle.BackgroundTransparency = 1
cfgTitle.Text = "🛡️ GUERRA DE BLOQUES v4 — AIM + ESP"
cfgTitle.TextColor3 = Color3.fromRGB(255,255,255) ; cfgTitle.Font = Enum.Font.GothamBold
cfgTitle.TextSize = 12 ; cfgTitle.ZIndex = 51

local function mkInput(label, posY, default)
    local lbl = Instance.new("TextLabel", cfgPanel)
    lbl.Size = UDim2.new(0,170,0,26) ; lbl.Position = UDim2.new(0,10,0,posY)
    lbl.BackgroundTransparency = 1 ; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200,200,215) ; lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11 ; lbl.TextXAlignment = Enum.TextXAlignment.Left ; lbl.ZIndex = 51

    local box = Instance.new("TextBox", cfgPanel)
    box.Size = UDim2.new(0,100,0,22) ; box.Position = UDim2.new(0,185,0,posY+2)
    box.BackgroundColor3 = Color3.fromRGB(28,28,38)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.Text = tostring(default) ; box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11 ; box.ClearTextOnFocus = false ; box.ZIndex = 51
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)
    return box
end

local function mkToggleBtn(label, posY, initialOn, colorOn, colorOff)
    local btn = Instance.new("TextButton", cfgPanel)
    btn.Size = UDim2.new(0,278,0,28) ; btn.Position = UDim2.new(0,11,0,posY)
    btn.BackgroundColor3 = initialOn and colorOn or colorOff
    btn.TextColor3 = Color3.fromRGB(255,255,255) ; btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11 ; btn.Text = label ; btn.ZIndex = 51
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    return btn
end

local iF           = mkInput("FOV Radio (px):",          44, Config.FOV_RADIUS)
local iSpeed       = mkInput("Suavizado Aim (0.01-1):",  74, Config.AIM_SPEED)
local iPred        = mkInput("Factor Predicción (0-5):", 104, Config.PREDICTION_FACTOR)
local iBullet      = mkInput("Vel. Bala (studs/s):",    134, Config.BULLET_SPEED)
local iGrav        = mkInput("Comp. Gravedad (0-2):",   164, Config.GRAVITY_COMP)
local iOffX        = mkInput("Offset X (px):",          194, Config.OFFSET_X)
local iOffY        = mkInput("Offset Y (px):",          224, Config.OFFSET_Y)
local iMaxDist     = mkInput("ESP Distancia Max (0=∞):", 254, Config.ESP_MAX_DISTANCE)

local btnTarget    = mkToggleBtn(
    Config.TARGET_PART == "Head" and "Prioridad: CABEZA 💀" or "Prioridad: CUERPO 🫁",
    290, Config.TARGET_PART == "Head",
    Color3.fromRGB(50,115,245), Color3.fromRGB(240,140,45)
)
local btnLMB       = mkToggleBtn(
    Config.AIM_ON_LMB and "🖱️ LMB: ACTIVADO" or "🖱️ LMB: DESACTIVADO",
    326, Config.AIM_ON_LMB,
    Color3.fromRGB(40,160,100), Color3.fromRGB(80,80,100)
)
local btnRMB       = mkToggleBtn(
    Config.AIM_ON_RMB and "🖱️ RMB: ACTIVADO" or "🖱️ RMB: DESACTIVADO",
    362, Config.AIM_ON_RMB,
    Color3.fromRGB(40,160,100), Color3.fromRGB(80,80,100)
)
local btnWallCheck = mkToggleBtn(
    Config.WALL_CHECK and "✅ Wall Check: ON" or "❌ Wall Check: OFF",
    398, Config.WALL_CHECK,
    Color3.fromRGB(0,140,220), Color3.fromRGB(80,80,100)
)
local btnClose     = mkToggleBtn(
    "🛑 APAGAR Y LIMPIAR RASTROS", 460,
    false, Color3.fromRGB(210,40,50), Color3.fromRGB(210,40,50)
)

-- ============================================================
-- SECCIÓN 7: EVENTOS DE CONFIGURACIÓN
-- ============================================================
local function bindInput(box, cfgKey, minV, maxV, isFloat, onChanged)
    table.insert(conns, box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val then
            if minV and maxV then val = math.clamp(val, minV, maxV) end
            if not isFloat then val = math.floor(val) end
            Config[cfgKey] = val
            box.Text = tostring(val)
            SaveConfig()
            if onChanged then onChanged(val) end
        else
            box.Text = tostring(Config[cfgKey])
        end
    end))
end

bindInput(iF,       "FOV_RADIUS",        20, 1200, false, function(v)
    fovFrame.Size = UDim2.new(0, v*2, 0, v*2)
end)
bindInput(iSpeed,   "AIM_SPEED",         0.01, 1,  true)
bindInput(iPred,    "PREDICTION_FACTOR", 0,    5,  true)
bindInput(iBullet,  "BULLET_SPEED",      100,  10000, false)
bindInput(iGrav,    "GRAVITY_COMP",      0,    2,  true)
bindInput(iOffX,    "OFFSET_X",          nil,  nil, true)
bindInput(iOffY,    "OFFSET_Y",          nil,  nil, true)
bindInput(iMaxDist, "ESP_MAX_DISTANCE",  0,    10000, false)

table.insert(conns, btnTarget.MouseButton1Click:Connect(function()
    Config.TARGET_PART = Config.TARGET_PART == "Head" and "UpperTorso" or "Head"
    local isHead = Config.TARGET_PART == "Head"
    btnTarget.Text = isHead and "Prioridad: CABEZA 💀" or "Prioridad: CUERPO 🫁"
    btnTarget.BackgroundColor3 = isHead and Color3.fromRGB(50,115,245) or Color3.fromRGB(240,140,45)
    SaveConfig()
end))

table.insert(conns, btnLMB.MouseButton1Click:Connect(function()
    Config.AIM_ON_LMB = not Config.AIM_ON_LMB
    btnLMB.Text = Config.AIM_ON_LMB and "🖱️ LMB: ACTIVADO" or "🖱️ LMB: DESACTIVADO"
    btnLMB.BackgroundColor3 = Config.AIM_ON_LMB and Color3.fromRGB(40,160,100) or Color3.fromRGB(80,80,100)
    SaveConfig()
end))

table.insert(conns, btnRMB.MouseButton1Click:Connect(function()
    Config.AIM_ON_RMB = not Config.AIM_ON_RMB
    btnRMB.Text = Config.AIM_ON_RMB and "🖱️ RMB: ACTIVADO" or "🖱️ RMB: DESACTIVADO"
    btnRMB.BackgroundColor3 = Config.AIM_ON_RMB and Color3.fromRGB(40,160,100) or Color3.fromRGB(80,80,100)
    SaveConfig()
end))

table.insert(conns, btnWallCheck.MouseButton1Click:Connect(function()
    Config.WALL_CHECK = not Config.WALL_CHECK
    btnWallCheck.Text = Config.WALL_CHECK and "✅ Wall Check: ON" or "❌ Wall Check: OFF"
    btnWallCheck.BackgroundColor3 = Config.WALL_CHECK and Color3.fromRGB(0,140,220) or Color3.fromRGB(80,80,100)
    SaveConfig()
end))

-- ============================================================
-- SECCIÓN 8: FUNCIONES AUXILIARES DE LÓGICA DE JUEGO
-- ============================================================
local function getTeam(char)
    if not char then return nil end
    if char:FindFirstChild(TEAM1_ACC) then return 1 end
    if char:FindFirstChild(TEAM2_ACC) then return 2 end
    local attr = char:GetAttribute("Team") or char:GetAttribute("Side")
    if attr ~= nil then return attr end
    local plr = Players:GetPlayerFromCharacter(char)
    if plr and plr.Team then return plr.Team.Name end
    return nil
end

local function isAlive(char, hum, root)
    if not char or not hum or not root then return false end
    if not char.Parent then return false end
    if hum.Health <= 0 or hum.Health < Config.MIN_ENEMY_HEALTH then return false end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Dead
    or state == Enum.HumanoidStateType.Physics then return false end
    if hum.PlatformStand then return false end
    if char:GetAttribute("Downed") or char:GetAttribute("Knocked")
    or char:GetAttribute("IsDead") then return false end
    if char:FindFirstChild("Downed") or char:FindFirstChild("RevivePrompt") then
        return false
    end
    return true
end

local function getTargetPart(char)
    if not char then return nil end
    local p = char:FindFirstChild(Config.TARGET_PART)
    if p and p:IsA("BasePart") then return p end
    if Config.TARGET_PART == "UpperTorso" then
        return char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

-- RaycastParams reutilizables (evita garbage)
local rayP = RaycastParams.new()
rayP.FilterType  = Enum.RaycastFilterType.Exclude
rayP.IgnoreWater = true

local function isVisible(targetPart, targetChar)
    local cam = Workspace.CurrentCamera
    if not cam or not targetPart then return false end
    local origin = cam.CFrame.Position
    local dir    = targetPart.Position - origin
    rayP.FilterDescendantsInstances = {
        LocalPlayer and LocalPlayer.Character, targetChar, cam
    }
    local hit = Workspace:Raycast(origin, dir, rayP)
    return hit == nil
end

-- ============================================================
-- SECCIÓN 9: PREDICCIÓN CINEMÁTICA DE SEGUNDO ORDEN
-- ============================================================
local function getPingS()
    local ok, v = pcall(function()
        if LocalPlayer and type(LocalPlayer.GetNetworkPing) == "function" then
            return LocalPlayer:GetNetworkPing()
        end
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return (ok and type(v) == "number") and math.clamp(v, 0, 0.35) or 0.065
end

local function updateKinematics(char, root)
    local now  = os.clock()
    local pos  = root.Position
    local rawV = root.AssemblyLinearVelocity or Vector3.zero
    local d    = kinematics[char]
    if not d then
        kinematics[char] = { pos=pos, vel=rawV, acc=Vector3.zero, t=now }
        return rawV, Vector3.zero
    end
    local dt = math.max(now - d.t, 1/240)
    if dt > 0.3 then
        kinematics[char] = { pos=pos, vel=rawV, acc=Vector3.zero, t=now }
        return rawV, Vector3.zero
    end
    local dv    = (pos - d.pos) / dt
    local mVel  = rawV.Magnitude > 0.5 and (rawV*0.6 + dv*0.4) or dv
    local aV    = math.clamp(dt * 18, 0.15, 0.85)
    local nVel  = d.vel:Lerp(mVel, aV)
    local rawA  = (nVel - d.vel) / dt
    rawA = Vector3.new(
        math.clamp(rawA.X, -200, 200),
        math.clamp(rawA.Y, -80,   80),
        math.clamp(rawA.Z, -200, 200)
    )
    local aA    = math.clamp(dt * 10, 0.1, 0.5)
    local nAcc  = d.acc:Lerp(rawA, aA)
    kinematics[char] = { pos=pos, vel=nVel, acc=nAcc, t=now }
    return nVel, nAcc
end

local function predictPos(char, targetPart, root)
    local cam = Workspace.CurrentCamera
    if not cam or not targetPart or not root then
        return targetPart and targetPart.Position or Vector3.zero
    end
    local base = targetPart.Position
    if Config.PREDICTION_FACTOR <= 0 then return base end
    local vel, acc = updateKinematics(char, root)
    if vel.Magnitude < 0.5 then return base end
    local camPos = cam.CFrame.Position
    local dist   = (base - camPos).Magnitude
    local bs     = math.max(Config.BULLET_SPEED, 100)
    -- Tiempo de vuelo con iteración (más preciso)
    local tFlight = dist / bs
    local mid     = base + vel * tFlight
    tFlight       = (mid - camPos).Magnitude / bs
    local ping    = getPingS()
    local T       = math.clamp((tFlight + ping * 0.5) * Config.PREDICTION_FACTOR, 0, 0.7)
    local disp    = vel * T + acc * (0.5 * T * T)
    local drop    = Vector3.new(0, 0.5 * Workspace.Gravity * Config.GRAVITY_COMP * tFlight^2, 0)
    local predicted = base + disp + drop
    -- Clamp al suelo si baja demasiado
    if disp.Y < 0 then
        rayP.FilterDescendantsInstances = { LocalPlayer and LocalPlayer.Character, char, cam }
        local fh = Workspace:Raycast(base, Vector3.new(0, disp.Y - 2, 0), rayP)
        if fh then
            predicted = Vector3.new(predicted.X, math.max(predicted.Y, fh.Position.Y + 1.5), predicted.Z)
        end
    end
    return predicted
end

-- ============================================================
-- SECCIÓN 10: SISTEMA ESP
-- ============================================================
local function clearESP(char)
    local e = espCache[char]
    if e then
        for _, c in ipairs(e.conns or {}) do pcall(function() c:Disconnect() end) end
        if e.Highlight  then pcall(function() e.Highlight:Destroy()  end) end
        if e.Billboard  then pcall(function() e.Billboard:Destroy()  end) end
        espCache[char] = nil
    end
    kinematics[char] = nil
end

local function makeESP(char, hum, root, myRootPos)
    local e = espCache[char]

    -- ---- Crear si no existe ----
    if not e then
        e = { conns = {} }

        -- Highlight (siempre visible a través de paredes)
        local hl = Instance.new("Highlight")
        Securi.GUI:SetName(hl, 14)
        hl.Adornee           = char
        hl.FillColor         = Color3.fromRGB(255,35,35)
        hl.FillTransparency  = 0.45
        hl.OutlineColor      = Color3.fromRGB(255,255,255)
        hl.OutlineTransparency = 0.1
        hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Archivable        = false
        hl.Parent            = espFolder
        e.Highlight          = hl

        -- Billboard con nombre + HP + distancia
        local bb = Instance.new("BillboardGui")
        Securi.GUI:SetName(bb, 14)
        bb.Adornee    = root
        bb.Size       = UDim2.new(0,130,0,42)
        bb.StudsOffset = Vector3.new(0, 3.8, 0)
        bb.AlwaysOnTop = true
        bb.Archivable  = false
        bb.Parent      = espFolder
        e.Billboard    = bb

        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.new(1,0,1,0) ; lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255,100,100)
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold ; lbl.TextSize = 12
        e.Label = lbl

        -- Auto-limpieza reactiva
        local function autoClear() clearESP(char) end
        table.insert(e.conns, hum.HealthChanged:Connect(function(hp)
            if hp <= 0 or hp < Config.MIN_ENEMY_HEALTH then autoClear() end
        end))
        table.insert(e.conns, hum.Died:Connect(autoClear))
        table.insert(e.conns, char.AncestryChanged:Connect(function(_, p)
            if not p then autoClear() end
        end))

        espCache[char] = e
    end

    -- ---- Actualizar datos ----
    local dist = (myRootPos - root.Position).Magnitude
    -- Si hay límite de distancia, ocultar los que estén lejos
    if Config.ESP_MAX_DISTANCE > 0 and dist > Config.ESP_MAX_DISTANCE then
        e.Billboard.Enabled  = false
        e.Highlight.Enabled  = false
        return
    end
    e.Billboard.Enabled = true
    e.Highlight.Enabled = true

    local tPart   = getTargetPart(char)
    local visible = tPart and isVisible(tPart, char)

    -- Colores: verde = visible, rojo = detrás de pared
    if visible then
        e.Label.TextColor3       = Color3.fromRGB(55,255,85)
        e.Highlight.FillColor    = Color3.fromRGB(40,220,80)
        e.Highlight.FillTransparency = 0.55
    else
        e.Label.TextColor3       = Color3.fromRGB(255,90,90)
        e.Highlight.FillColor    = Color3.fromRGB(255,35,35)
        e.Highlight.FillTransparency = 0.45
    end

    -- Obtener nombre real del jugador para el label
    local plr  = Players:GetPlayerFromCharacter(char)
    local name = plr and plr.DisplayName or char.Name
    e.Label.Text = string.format(
        "%s\n[%d HP] [%dm]",
        name, math.floor(hum.Health), math.floor(dist)
    )
end

-- ============================================================
-- SECCIÓN 11: BUCLE DE ESP + CINEMÁTICA
-- ============================================================
local function updateESP(dt)
    local myChar = LocalPlayer and LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local myTeam = getTeam(myChar)
    if not myRoot or not myTeam then return end

    local live = Workspace:FindFirstChild("Live")
    if not live then return end

    local activeSet = {}

    for _, char in ipairs(live:GetChildren()) do
        if char ~= myChar then
            local eTeam = getTeam(char)
            -- Solo enemigos (distintos equipos)
            if eTeam and eTeam ~= myTeam then
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if isAlive(char, hum, root) then
                    activeSet[char] = true
                    updateKinematics(char, root)
                    makeESP(char, hum, root, myRoot.Position)
                else
                    clearESP(char)
                end
            else
                -- Limpiar amigos de la caché (no mostrar ESP de aliados por defecto)
                clearESP(char)
            end
        end
    end

    -- Limpiar personajes que ya no están en Live
    for c in pairs(espCache) do
        if not activeSet[c] then clearESP(c) end
    end
end

-- ============================================================
-- SECCIÓN 12: SELECCIÓN DE OBJETIVO
-- ============================================================
local function getAimRef()
    local cam = Workspace.CurrentCamera
    if Config.FOLLOW_MOUSE then
        local mp = UserInputService:GetMouseLocation()
        return Vector2.new(mp.X + Config.OFFSET_X, mp.Y + Config.OFFSET_Y)
    end
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    return Vector2.new(vp.X*0.5 + Config.OFFSET_X, vp.Y*0.5 + Config.OFFSET_Y)
end

local function getBestTarget(aimCenter)
    local cam    = Workspace.CurrentCamera
    local myChar = LocalPlayer and LocalPlayer.Character
    if not cam or not myChar then return nil, nil, nil end
    local myTeam = getTeam(myChar)
    if not myTeam then return nil, nil, nil end
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil, nil, nil end

    local bestChar, bestPart, bestRoot
    local bestDist = Config.FOV_RADIUS   -- Sólo buscar dentro del FOV

    for _, char in ipairs(live:GetChildren()) do
        if char ~= myChar then
            local eTeam = getTeam(char)
            if eTeam and eTeam ~= myTeam then
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                local tp   = getTargetPart(char)
                if tp and isAlive(char, hum, root) then
                    if not Config.WALL_CHECK or isVisible(tp, char) then
                        local sp, onScreen = cam:WorldToViewportPoint(tp.Position)
                        if onScreen and sp.Z > 0 then
                            local d2 = (Vector2.new(sp.X, sp.Y) - aimCenter).Magnitude
                            if d2 < bestDist then
                                bestDist  = d2
                                bestChar  = char
                                bestPart  = tp
                                bestRoot  = root
                            end
                        end
                    end
                end
            end
        end
    end
    return bestChar, bestPart, bestRoot
end

-- ============================================================
-- SECCIÓN 13: CONTROLES (LMB + RMB + TECLA F)
-- ============================================================
local function isAiming()
    return aimPressCount > 0
end

local function updateStateLabel()
    if isAiming() then
        stateLabel.Text = "🎯 AIM: ACTIVO"
        stateLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        fovStroke.Color = Color3.fromRGB(255, 45, 45)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 45, 45)
    else
        stateLabel.Text = "🎯 AIM: OFF"
        stateLabel.TextColor3 = Color3.fromRGB(0, 220, 120)
        fovStroke.Color = Color3.fromRGB(255, 255, 255)
        centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        predDot.Visible = false
    end
end

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
    if not isActive then return end

    -- LMB (MouseButton1)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.AIM_ON_LMB then
        aimPressCount = aimPressCount + 1
        updateStateLabel()
    end
    -- RMB (MouseButton2)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and Config.AIM_ON_RMB then
        aimPressCount = aimPressCount + 1
        updateStateLabel()
    end
    -- Tecla F: abrir/cerrar panel de config (solo si el juego no consume la tecla)
    if not gp and input.KeyCode == Enum.KeyCode.F then
        cfgPanel.Visible = not cfgPanel.Visible
    end
    -- Tecla Delete: destruir / limpiar todo
    if not gp and input.KeyCode == Enum.KeyCode.Delete then
        isActive = false
    end
end))

table.insert(conns, UserInputService.InputEnded:Connect(function(input)
    if not isActive then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.AIM_ON_LMB then
        aimPressCount = math.max(0, aimPressCount - 1)
        updateStateLabel()
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 and Config.AIM_ON_RMB then
        aimPressCount = math.max(0, aimPressCount - 1)
        updateStateLabel()
    end
end))

-- ============================================================
-- SECCIÓN 14: BUCLE DE RENDER (CAMERA + AIM + ESP)
-- ============================================================
local renderName = Securi._randName(20)

local function onRender(dt)
    if not isActive then return end

    -- Pcall global para que un error interno no mate el bucle
    local ok, err = pcall(function()
        local aimRef  = getAimRef()
        local aimUDim = UDim2.fromOffset(aimRef.X, aimRef.Y)
        centerDot.Position = aimUDim
        fovFrame.Position  = aimUDim

        -- Actualizar ESP en cada frame (60fps, ligero)
        updateESP(dt)

        -- Aim activo: buscar objetivo y mover cámara
        if isAiming() then
            local cam = Workspace.CurrentCamera
            local tChar, tPart, tRoot = getBestTarget(aimRef)

            if cam and tChar and tPart and tRoot then
                local predicted = predictPos(tChar, tPart, tRoot)

                -- Mostrar punto de predicción en pantalla
                local ps, onScr = cam:WorldToViewportPoint(predicted)
                if onScr and ps.Z > 0 then
                    predDot.Position = UDim2.fromOffset(ps.X, ps.Y)
                    predDot.Visible  = true
                else
                    predDot.Visible = false
                end

                -- Calcular CFrame destino apuntando al punto predicho
                local targetCF = CFrame.lookAt(cam.CFrame.Position, predicted)

                -- Si FOLLOW_MOUSE está activo, compensar el offset del mouse
                if Config.FOLLOW_MOUSE then
                    local vp        = cam.ViewportSize * 0.5
                    local delta     = aimRef - vp
                    if delta.Magnitude > 2 then
                        local fovY = math.rad(cam.FieldOfView)
                        local half = (cam.ViewportSize.Y * 0.5) / math.tan(fovY * 0.5)
                        local pitch = math.atan2(delta.Y, half)
                        local yaw   = math.atan2(delta.X, half)
                        targetCF = targetCF * CFrame.Angles(pitch, yaw, 0)
                    end
                end

                -- Aplicar movimiento de cámara (suavizado frame-rate independiente)
                if Config.AIM_SPEED >= 1 then
                    cam.CFrame = targetCF
                else
                    local alpha = 1 - math.pow(
                        1 - Config.AIM_SPEED,
                        math.clamp((dt or 1/60) * 60, 0.5, 3)
                    )
                    cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(alpha, 0.01, 1))
                end
            else
                predDot.Visible = false
            end
        end
    end)
    -- Si hay error interno, simplemente lo silenciamos (nunca reventar el render loop)
end

RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, onRender)

-- ============================================================
-- SECCIÓN 15: BOTÓN CERRAR — LIMPIEZA TOTAL DE RASTROS
-- ============================================================
local function shutdown()
    isActive      = false
    aimPressCount = 0

    -- Desconectar render loop
    pcall(function() RunService:UnbindFromRenderStep(renderName) end)

    -- Desconectar todas las conexiones
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)

    -- Eliminar todo el ESP
    for char in pairs(espCache) do clearESP(char) end
    table.clear(espCache)
    table.clear(kinematics)

    -- Destruir la GUI completa (elimina highlight, billboard, panel, etc.)
    pcall(function() gui:Destroy() end)

    -- Limpiar genv para que no queden rastros
    local genv2 = (type(getgenv) == "function" and getgenv()) or nil
    if genv2 then
        genv2.__GBConfig = nil
        -- NO borramos Securi: puede ser reutilizado por otros scripts
    end
end

table.insert(conns, btnClose.MouseButton1Click:Connect(shutdown))
