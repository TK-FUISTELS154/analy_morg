-- ==============================================================================
-- 🛡️ SECURE.LUA - UNIVERSAL GOD-TIER SECURITY FRAMEWORK
-- ==============================================================================
-- Un framework profesional para scripts de Roblox.
-- Integra Protección GUI, Auto-Ejecución, Guardado de Estado, Anti-AFK, 
-- Bloqueo de Remotes (Network Hooking), Spoofing de Consola y Orquestación Inteligente.
--
-- ==============================================================================
-- 🛠️ SCRIPT DE PRUEBA (CARGAR PANEL VISUAL)
-- ==============================================================================
-- Ejecuta este código desde tu inyector para cargar el panel de diagnósticos:
--
-- pcall(function()
--     loadstring(game:HttpGet("https://pastebin.com/raw/sX4fP8kY?cb=" .. tostring(tick())))()
-- end)
--
-- ==============================================================================
-- 📖 MANUAL DE USO RÁPIDO (ACTUALIZADO v0.1.26)
-- ==============================================================================
-- 1. Inicialización y Diagnóstico (Obligatorio):
--    local Secure = loadstring(game:HttpGet(".../secure.lua"))()
--    Secure.Orchestrator:EvaluateEnvironment() -- Escanea el inyector y adapta el nivel
--    local diag = Secure.Orchestrator:GetDiagnostics() -- Obtiene Nivel, Puntos y APIs
--
-- 2. Proteger la GUI (Inyección invisible Anti-Cheats y Anti-OCR):
--    local miGuiSegura = Secure.GUI:CreateSafe("NombreDelGui")
--    Secure.GUI:BlockDetectionText(game.Players.LocalPlayer) -- Censura textos baneables
--
-- 3. Anti-Kick, Spoofing y Presencia (Sigilo Máximo):
--    Secure.Environment:ProtectPlayer(game.Players.LocalPlayer) -- Bloquea LocalPlayer:Kick()
--    Secure.Environment:SpoofCallStack() -- Oculta que tu script es un exploit (Ocupa Hooks)
--    Secure.Presence:EnableAntiAFK() -- Evita expulsiones por inactividad (20 minutos)
--
-- 4. Aislamiento de Errores y Teleport Seguro:
--    Secure.Thread:SpawnSafe("MiHilo", function() ... end) -- Evita logs rojos en la F9
--    Secure.Server:QueueOnTeleport("print('Inyectado tras Server Hop')")
--
-- 5. Bloqueo de Red (Remotes) y Memoria (GC):
--    Secure.Network:BlockRemote("LogExploiter") -- Bloquea reportes hacia el servidor
--    Secure.GC:EnableSafeWrapper(5) -- Limita getgc a 5 llamadas/seg (Evita flags)
--
-- 6. Sistema de Archivos Local (Guardar Configuraciones):
--    Secure.Config:Save("MiConfig", { Aimbot = true, FOV = 90 })
--    local data = Secure.Config:Load("MiConfig")
--
-- ==============================================================================
local Secure = {}
Secure.VERSION = "0.1.30"

function Secure:GetVersion()
    return self.VERSION
end

-- ==============================================================================
-- 0. NÚCLEO Y BYPASS DEL ENTORNO (ANTI-POISONING)
-- ==============================================================================
-- Bypasses executor-level environment poisoning by taking raw references.
local realGame = workspace.Parent or game
local cloneref = (type(cloneref) == "function" and cloneref) or function(...) return ... end
local clonefunc = (type(clonefunction) == "function" and clonefunction) or function(...) return ... end

-- Cache critical native methods to prevent metatable hooks from interfering with the framework
local Native = {
    GetService = realGame.GetService,
    GetDescendants = realGame.GetDescendants,
    FindFirstChild = realGame.FindFirstChild,
    WaitForChild = realGame.WaitForChild,
    IsA = realGame.IsA
}

-- ==============================================================================
-- 1. ORQUESTADOR INTELIGENTE Y TELEMETRÍA (Logger unificado)
-- ==============================================================================
Secure.Logger = {}

function Secure.Logger:InternalError(source, err)
    if _G.SECURE_DEBUG then
        warn(string.format("[SECURE-FRAMEWORK][%s] Excepción: %s", tostring(source), tostring(err)))
    end
    -- Opcional: Integración futura con crash report / webhook sin romper el flujo
end

Secure.Orchestrator = {
    ExecutionLevel = 3, -- Base Roblox Environment
    Vectors = {
        CanHook = false,
        CanSpoof = false,
        CanProtectGUI = false,
        CanManipulateGC = false,
        CanReadFiles = false,
        CanDecompile = false
    },
    Capabilities = {},
    SupportedFeatures = {}
}

function Secure.Orchestrator:GetDiagnostics()
    return {
        Level = self.ExecutionLevel,
        Score = self._lastPowerScore or 0,
        Supported = self.SupportedFeatures
    }
end

function Secure.Orchestrator:EvaluateEnvironment()
    -- Evaluación heurística predictiva extremadamente precisa (Anti-Spoof)
    local score = 0
    
    local function testCap(...)
        local names = {...}
        for _, globalVar in ipairs(names) do
            local exists = false
            local isFunc = false
            
            -- Chequeo ultra-rápido (Previene cuelgues o crashes)
            pcall(function()
                local env = getfenv(0)
                if env and type(env) == "table" and env[globalVar] ~= nil then
                    exists = true
                    if type(env[globalVar]) == "function" then isFunc = true end
                end
            end)
            
            if not exists then
                pcall(function()
                    if type(getgenv) == "function" then
                        local genv = getgenv()
                        if genv and type(genv) == "table" and genv[globalVar] ~= nil then
                            exists = true
                            if type(genv[globalVar]) == "function" then isFunc = true end
                        end
                    end
                end)
            end
            
            if exists and isFunc then
                self.Capabilities[names[1]] = true
                table.insert(self.SupportedFeatures, names[1])
                return true
            end
        end
        self.Capabilities[names[1]] = false
        return false
    end

    -- Limpiar lista anterior
    self.SupportedFeatures = {}

    -- 1. Identidad de Hilo (Thread Identity) y Base del Motor
    local identity = 0
    local hasGame = false
    pcall(function()
        hasGame = (type(game) == "userdata" and type(workspace) == "userdata")
        local getid = getthreadidentity or getidentity or getthreadcontext
        if type(getid) == "function" then 
            identity = getid() 
        else
            if hasGame then identity = 2 end
        end
    end)
    
    -- 2. Detección Exhaustiva de Capacidades Clave (Exploit API Completa Ampliada)
    
    -- Nivel 3 (Básico)
    local c_basic = testCap("getgenv", "getrenv")
    local c_load = testCap("loadstring", "load")
    local c_clip = testCap("setclipboard", "toclipboard")
    
    -- Nivel 4 (Spoofing & Metatablas)
    local c_meta = testCap("getrawmetatable")
    local c_readonly = testCap("setreadonly", "make_writeable", "makewriteable")
    local c_clone = testCap("cloneref", "clonefunction")
    local c_namecall = testCap("getnamecallmethod", "get_namecall_method")
    
    -- Nivel 5 (Memoria y Entorno)
    local c_gc = testCap("getgc", "get_gc")
    local c_instances = testCap("getnilinstances", "get_nil_instances", "getinstances")
    local c_env = testCap("getcallingscript", "getsenv", "get_senv")
    local c_hidden = testCap("gethiddenproperty", "get_hidden_property", "sethiddenproperty", "set_hidden_property")
    local c_scripts = testCap("getscripts", "get_scripts")
    
    -- Nivel 6 (Hooking - El Núcleo del Exploiting Avanzado)
    local c_hookmeta = testCap("hookmetamethod")
    local c_hookfunc = testCap("hookfunction", "replaceclosure")
    local c_cclosure = testCap("newcclosure", "islclosure", "iscclosure")
    local c_caller = testCap("checkcaller")
    
    -- Nivel 7 (Sistema de Archivos y Red)
    local c_file = testCap("readfile") and testCap("writefile")
    local c_fileext = testCap("isfile", "delfile", "appendfile")
    local c_folder = testCap("isfolder", "makefolder", "listfiles", "delfolder")
    local c_net = testCap("request", "http_request", "syn.request", "fluxus.request")
    local c_signal = testCap("getconnections", "get_signal_cons", "firesignal")
    
    -- Nivel 8 (God-Tier - Evasión, Robo de Juegos y APIs destructivas)
    local c_ui = testCap("gethui", "get_hidden_gui", "protect_gui", "protectgui")
    local c_teleport = testCap("queue_on_teleport", "queueonteleport")
    local c_save = testCap("saveinstance", "save_instance")
    local c_decomp = testCap("decompile", "getscriptbytecode")
    local c_input = testCap("keypress", "mouse1click", "fireclickdetector", "mouse2click")
    local c_thread = testCap("setthreadidentity", "setidentity", "setthreadcontext")

    -- 3. Motor de Puntuación Avanzado (Total: ~120 puntos)
    local power = 0
    if c_basic then power = power + 2 end
    if c_load then power = power + 2 end
    if c_clip then power = power + 1 end
    
    if c_meta then power = power + 3 end
    if c_readonly then power = power + 3 end
    if c_clone then power = power + 4 end
    if c_namecall then power = power + 2 end
    
    if c_gc then power = power + 8 end
    if c_instances then power = power + 5 end
    if c_env then power = power + 5 end
    if c_hidden then power = power + 5 end
    if c_scripts then power = power + 2 end
    
    if c_hookmeta then power = power + 12 end
    if c_hookfunc then power = power + 10 end
    if c_cclosure then power = power + 5 end
    if c_caller then power = power + 5 end
    
    if c_file then power = power + 8 end
    if c_fileext then power = power + 4 end
    if c_folder then power = power + 4 end
    if c_net then power = power + 5 end
    if c_signal then power = power + 5 end
    
    if c_ui then power = power + 8 end
    if c_teleport then power = power + 5 end
    if c_save then power = power + 10 end
    if c_decomp then power = power + 10 end
    if c_input then power = power + 2 end
    if c_thread then power = power + 4 end

    self._lastPowerScore = power

    -- Evaluacion estricta e independiente de la identidad
    local realLevel = 0
    if hasGame then realLevel = 2 end
    if identity > 2 then realLevel = identity end

    if realLevel >= 2 then
        -- Mapeo de Porcentaje a Tiers Absolutos (0 a 8)
        if power == 0 then
            score = realLevel
        elseif power < 15 then
            score = 3 -- Básico (Ej: Solara muy limitado)
        elseif power < 35 then
            score = 4 -- Nivel Intermedio-Bajo
        elseif power < 55 then
            score = 5 -- Nivel Intermedio (Delta sin hooks completos)
        elseif power < 80 then
            score = 6 -- Avanzado (Casi todos los hooks y memoria)
        elseif power < 105 then
            score = 7 -- Premium (Red, Archivos, GC, Hooks)
        else
            score = 8 -- God-Tier (Virtualmente Indetectable y Todo Poderoso)
        end
        
        -- 4. Limitadores Extremos de Seguridad Estructural
        -- Regla 1: Nivel > 4 requiere Spoofing Básico
        if score >= 5 and not (c_readonly or c_clone) then
            score = 4
        end
        
        -- Regla 2: Nivel > 5 requiere Hooking Básico
        if score >= 6 and not (c_hookmeta or c_hookfunc) then
            score = 5
        end
        
        -- Regla 3: Nivel > 6 requiere FileSystem o Red
        if score >= 7 and not (c_file or c_net) then
            score = 6
        end
        
        -- Regla 4: Nivel 8 EXIGE SaveInstance, Decompiler o Manipulación extrema de hilo
        if score == 8 and not (c_save or c_decomp or c_thread) then
            score = 7
        end
    else
        score = realLevel
    end

    -- Actualizar Vectores (Retrocompatibilidad)
    self.Vectors.CanHook = c_hookmeta or c_hookfunc
    self.Vectors.CanManipulateGC = c_gc
    self.Vectors.CanSpoof = c_clone or c_readonly
    self.Vectors.CanProtectGUI = c_ui
    self.Vectors.CanReadFiles = c_file
    self.Vectors.CanDecompile = c_decomp

    self.ExecutionLevel = math.clamp(score, 0, 8)
    
    if _G.SECURE_DEBUG then 
        print(string.format("[Orchestrator] Entorno evaluado. Nivel: %d (ID: %d) | Hooks: %s | GC: %s | Spoof: %s | GUI: %s", 
            self.ExecutionLevel, identity, tostring(self.Vectors.CanHook), tostring(self.Vectors.CanManipulateGC), tostring(self.Vectors.CanSpoof), tostring(self.Vectors.CanProtectGUI))) 
    end
end

function Secure.Orchestrator:ExecuteSafe(targetLevel, fallbackReturn, func, ...)
    -- Control centralizado para mitigación de errores de alto nivel
    if self.ExecutionLevel >= targetLevel then
        local success, result = pcall(func, ...)
        if success then return result end
        Secure.Logger:InternalError("Orchestrator_L" .. targetLevel, result)
    end
    return fallbackReturn
end

function Secure.Orchestrator:SmartWait(targetString, timeout)
    -- Espera inteligentemente hasta que un objeto específico (ej. "admin") se replique
    local startTime = tick()
    local maxWait = timeout or 12
    local RepStorage = Native.GetService(realGame, "ReplicatedStorage")
    
    while tick() - startTime < maxWait do
        local isReady = false
        pcall(function()
            for _, v in pairs(Native.GetDescendants(RepStorage)) do
                if tostring(v.Name):lower():find(targetString:lower()) then
                    isReady = true
                    break
                end
            end
        end)
        
        if isReady and tick() - startTime > 2 then
            task.wait(1)
            break
        end
        task.wait(0.5)
    end
end

Secure.Orchestrator:EvaluateEnvironment()

-- ==============================================================================
-- 2. GESTOR DE CAPACIDADES DINÁMICAS (Exploit API con Fallbacks)
-- ==============================================================================
local function checkFunc(func, fallback)
    if type(func) == "function" then return func end
    return fallback or function(...) return ... end
end

Secure.ExploitAPI = {
    cloneref = checkFunc(cloneref, function(instance) return instance end),
    clonefunction = checkFunc(clonefunc, checkFunc(clonefunction, function(f) return f end)),
    hookmetamethod = checkFunc(hookmetamethod),
    hookfunction = checkFunc(hookfunction),
    getnamecallmethod = checkFunc(getnamecallmethod, checkFunc(get_namecall_method)),
    checkcaller = checkFunc(checkcaller, function() return false end),
    newcclosure = checkFunc(newcclosure, function(f, ...) return f(...) end),
    gethui = checkFunc(gethui, checkFunc(get_hidden_gui)),
    protect_gui = checkFunc(protect_gui, checkFunc(protectgui, syn and type(syn.protect_gui) == "function" and syn.protect_gui)),
    queue_on_teleport = checkFunc(queue_on_teleport, 
        checkFunc(queueonteleport, 
            (syn and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport) or 
            (fluxus and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
        )
    ),
    writefile = checkFunc(writefile),
    readfile = checkFunc(readfile),
    isfolder = checkFunc(isfolder, function() return false end),
    makefolder = checkFunc(makefolder, function() end),
    isfile = checkFunc(isfile, function() return false end),
    getconnections = checkFunc(getconnections, checkFunc(get_signal_cons)),
    setreadonly = checkFunc(setreadonly, checkFunc(make_writeable, function() end)),
    getgenv = checkFunc(getgenv, function() return _G end),
    request = checkFunc(request, checkFunc(http_request, (syn and syn.request) or (http and http.request))),
    getrawmetatable = checkFunc(getrawmetatable),
    setrawmetatable = checkFunc(setrawmetatable),
    getgc = checkFunc(getgc),
    saveinstance = checkFunc(saveinstance),
    getnilinstances = checkFunc(getnilinstances, checkFunc(get_nil_instances, function() return {} end)),
    getinstances = checkFunc(getinstances, checkFunc(get_instances, function() return Native.GetDescendants(realGame) end)),
    gethiddenproperty = checkFunc(gethiddenproperty, checkFunc(get_hidden_property)),
    sethiddenproperty = checkFunc(sethiddenproperty, checkFunc(set_hidden_property)),
    setscriptable = checkFunc(setscriptable, checkFunc(set_scriptable)),
    getscripts = checkFunc(getscripts, checkFunc(get_scripts, function() return {} end)),
    getsenv = checkFunc(getsenv, checkFunc(get_senv))
}

-- ==============================================================================
-- 3. SERVICIOS BLINDADOS (Secure.Services)
-- ==============================================================================
Secure.Services = setmetatable({}, {
    __index = function(self, serviceName)
        local cachedService = rawget(self, serviceName)
        if cachedService then return cachedService end

        local success, serviceObj = pcall(function()
            local rawService = Native.GetService(realGame, serviceName)
            local cloned = Secure.ExploitAPI.cloneref(rawService)
            
            -- PROTECCIÓN MULTI-NIVEL: Verificar que cloneref no corrompió la memoria (Bug de inyectores Nivel 3)
            if cloned and type(cloned) == "userdata" then
                local isCorrect = false
                pcall(function() isCorrect = (cloned.ClassName == serviceName or cloned.Name == serviceName) end)
                if not isCorrect then
                    Secure.Logger:InternalError("Services_ClonerefBug", "cloneref devolvió " .. tostring(cloned.ClassName))
                    return rawService
                end
            end
            
            return cloned or rawService
        end)

        if success and serviceObj then
            rawset(self, serviceName, serviceObj)
            return serviceObj
        end
        
        -- Fallback extremo
        local rawFallback = nil
        pcall(function() rawFallback = Native.GetService(realGame, serviceName) end)
        if rawFallback then
            rawset(self, serviceName, rawFallback)
            return rawFallback
        end
        
        return nil
    end
})

local HttpService = Secure.Services.HttpService
local CoreGui = Secure.Services.CoreGui
local Players = Secure.Services.Players
local VirtualUser = Secure.Services.VirtualUser

-- ==============================================================================
-- 4. GESTIÓN DE HILOS (Secure.Thread)
-- ==============================================================================
Secure.Thread = {}

function Secure.Thread:SpawnSafe(funcName, funcBody, ...)
    local args = {...}
    return task.spawn(function()
        local success, err = pcall(function()
            funcBody(table.unpack(args))
        end)
        if not success then
            Secure.Logger:InternalError("Thread_" .. tostring(funcName), err)
        end
    end)
end

-- ==============================================================================
-- 5. GESTIÓN DE INTERFAZ Y HOOKS (Secure.GUI)
-- ==============================================================================
Secure.GUI = {}
Secure.GUI.ProtectedGuis = {}
Secure.GUI.ScramblerEnabled = false

local function generateInvisibleName()
    local str = ""
    for i = 1, math.random(15, 25) do str = str .. string.char(math.random(128, 255)) end
    return str
end

function Secure.GUI:CreateSafe(optionalName)
    local finalGuiName = optionalName or generateInvisibleName()
    
    local gui = Instance.new("ScreenGui")
    gui.Name = finalGuiName
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2e9
    gui.IgnoreGuiInset = true
    gui.Archivable = false 
    
    local exploit = Secure.ExploitAPI
    local Players = Secure.Services.Players
    local LocalPlayer = Players and Players.LocalPlayer

    -- 1. Cloneref a PlayerGui (Como lo hace IY: cloneref(PlayerGui))
    local PlayerGui = nil
    if LocalPlayer then
        pcall(function() 
            PlayerGui = exploit.cloneref(Native.WaitForChild(LocalPlayer, "PlayerGui", 5))
            -- Validación de bug de cloneref en PlayerGui
            if PlayerGui and type(PlayerGui) == "userdata" then
                local isCorrect = false
                pcall(function() isCorrect = (PlayerGui.Name == "PlayerGui") end)
                if not isCorrect then PlayerGui = Native.WaitForChild(LocalPlayer, "PlayerGui", 5) end
            end
        end)
    end

    -- 2. Definir COREGUI seguro usando el servicio blindado
    local COREGUI = Secure.Services.CoreGui
    if not COREGUI then COREGUI = PlayerGui end

    -- Función auxiliar para crear el ScreenGui base
    local function createBaseScreenGui()
        local gui = Instance.new("ScreenGui")
        gui.Name = finalGuiName
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 2e9
        gui.IgnoreGuiInset = true
        gui.Archivable = false
        return gui
    end

    local returnedGui = nil
    local MAX_DISPLAY_ORDER = 2e9

    -- ARQUITECTURA EXACTA DE INFINITE YIELD
    if exploit.gethui then
        local success, res = pcall(function() return exploit.gethui() end)
        if success and res then
            returnedGui = createBaseScreenGui()
            pcall(function() returnedGui.Parent = res end)
        end
    end

    if not returnedGui and exploit.protect_gui then
        returnedGui = createBaseScreenGui()
        pcall(function() exploit.protect_gui(returnedGui) end)
        pcall(function() returnedGui.Parent = COREGUI end)
    end

    if not returnedGui and COREGUI and Native.FindFirstChild(COREGUI, "RobloxGui") then
        -- TRUCO DE INFINITE YIELD: Evitar ScreenGui en ScreenGui.
        -- Devolvemos un Folder dentro de RobloxGui, el script hijo meterá sus Frames ahí y funcionarán.
        returnedGui = Instance.new("Folder")
        returnedGui.Name = finalGuiName
        pcall(function() returnedGui.Parent = COREGUI.RobloxGui end)
    end

    if not returnedGui and COREGUI then
        returnedGui = createBaseScreenGui()
        pcall(function() returnedGui.Parent = COREGUI end)
    end

    self.ProtectedGuis[finalGuiName] = returnedGui
    return returnedGui
end

function Secure.GUI:EnableScrambler(interval)
    -- Randomiza periódicamente los nombres de las interfaces para evadir anti-cheats
    if self.ScramblerEnabled then return end
    self.ScramblerEnabled = true
    
    Secure.Thread:SpawnSafe("GUIScrambler", function()
        while self.ScramblerEnabled do
            task.wait(interval or 5)
            for oldName, guiObj in pairs(self.ProtectedGuis) do
                if guiObj and guiObj.Parent then
                    local newName = generateInvisibleName()
                    guiObj.Name = newName
                    self.ProtectedGuis[newName] = guiObj
                    self.ProtectedGuis[oldName] = nil
                end
            end
        end
    end)
end

function Secure.GUI:BlockDetectionText(player)
    -- Oculta dinámicamente textos sospechosos en la GUI del jugador ("detect", "kick", "ban")
    Secure.Thread:SpawnSafe("GUIDetectionBlocker", function()
        local playerGui = Native.WaitForChild(player, "PlayerGui")
        if not playerGui then return end
        
        playerGui.DescendantAdded:Connect(function(gui)
            Secure.Thread:SpawnSafe("GUIDetectionBlocker_Descendant", function()
                if gui and gui.Parent and (Native.IsA(gui, "TextLabel") or Native.IsA(gui, "TextBox")) then
                    local text = gui.Text:lower()
                    if text:find("detect") or text:find("kick") or text:find("ban") then
                        gui.Text = ""
                        gui.Visible = false
                    end
                end
            end)
        end)
    end)
end

-- ==============================================================================
-- 6. AUTO-EJECUCIÓN / SERVER HOP (Secure.Server)
-- ==============================================================================
Secure.Server = {}

function Secure.Server:QueueOnTeleport(luaCodeString)
    return Secure.Orchestrator:ExecuteSafe(6, false, function()
        Secure.ExploitAPI.queue_on_teleport(luaCodeString)
        return true
    end)
end

-- ==============================================================================
-- 7. GESTIÓN DE METADATOS Y ESTADO (Secure.Config)
-- ==============================================================================
Secure.Config = {}
Secure.Config.FolderName = "SecureFrameworkConfigs"

function Secure.Config:InitFolder()
    Secure.Orchestrator:ExecuteSafe(3, nil, function()
        if not Secure.ExploitAPI.isfolder(self.FolderName) then
            Secure.ExploitAPI.makefolder(self.FolderName)
        end
    end)
end

function Secure.Config:Save(configName, dataTable)
    return Secure.Orchestrator:ExecuteSafe(3, false, function()
        self:InitFolder()
        local filePath = self.FolderName .. "/" .. configName .. ".json"
        local jsonData = HttpService:JSONEncode(dataTable)
        Secure.ExploitAPI.writefile(filePath, jsonData)
        return true
    end)
end

function Secure.Config:Load(configName)
    return Secure.Orchestrator:ExecuteSafe(3, nil, function()
        local filePath = self.FolderName .. "/" .. configName .. ".json"
        if Secure.ExploitAPI.isfile(filePath) then
            local content = Secure.ExploitAPI.readfile(filePath)
            return HttpService:JSONDecode(content)
        end
        return nil
    end)
end

-- ==============================================================================
-- 8. MÓDULO DE PRESENCIA (ANTI-AFK) (Secure.Presence)
-- ==============================================================================
Secure.Presence = {}

function Secure.Presence:EnableAntiAFK()
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then return false end

    -- Método 1: Nivel Crítico 7 (Desconexión de señales)
    local signalDisabled = Secure.Orchestrator:ExecuteSafe(7, false, function()
        for _, connection in pairs(Secure.ExploitAPI.getconnections(LocalPlayer.Idled)) do
            connection:Disable()
        end
        return true
    end)

    -- Método 2: Nivel Base 3 (VirtualUser Click)
    if not signalDisabled then
        Secure.Thread:SpawnSafe("AntiAFK_Loop", function()
            LocalPlayer.Idled:Connect(function()
                if VirtualUser then
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end
            end)
        end)
    end
    
    return true
end

-- ==============================================================================
-- 9. MÓDULO DE RED BLINDADO (Secure.Network)
-- ==============================================================================
Secure.Network = {}
Secure.Network.BlockedRemotes = {}

function Secure.Network:BlockRemote(remoteName)
    self.BlockedRemotes[remoteName] = true
end

function Secure.Network:HttpRequest(url, method, headers, body)
    -- Intenta nivel 7 (http_request exploit), fallback a nivel 3 (HttpService)
    local exploitRes = Secure.Orchestrator:ExecuteSafe(7, nil, function()
        return Secure.ExploitAPI.request({
            Url = url,
            Method = method or "GET",
            Headers = headers or {},
            Body = body
        })
    end)
    
    if exploitRes then return exploitRes end
    
    return Secure.Orchestrator:ExecuteSafe(3, nil, function()
        if HttpService and method == "GET" then
            return {Body = HttpService:GetAsync(url), StatusCode = 200}
        end
    end)
end

function Secure.Network:EnableGhostMode()
    local RunService = Secure.Services.RunService
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        for _, connection in pairs(Secure.ExploitAPI.getconnections(RunService.RenderStepped)) do
            if tostring(connection.Function):match("Physics") then
                connection:Disable()
            end
        end
        return true
    end)
end

-- ==============================================================================
-- 10. MÓDULO DE ENTORNO (Secure.Environment)
-- ==============================================================================
Secure.Environment = {}

function Secure.Environment:LockTable(t)
    Secure.Orchestrator:ExecuteSafe(5, nil, function() Secure.ExploitAPI.setreadonly(t, true) end)
end

function Secure.Environment:UnlockTable(t)
    Secure.Orchestrator:ExecuteSafe(5, nil, function() Secure.ExploitAPI.setreadonly(t, false) end)
end

function Secure.Environment:CreateSandbox(func)
    local funcToSandBox = Secure.ExploitAPI.clonefunction(func)
    local newEnv = setmetatable({}, { __index = getfenv(), __newindex = function(t, k, v) rawset(t, k, v) end })
    setfenv(funcToSandBox, newEnv)
    return funcToSandBox
end

function Secure.Environment:ProtectFunction(func)
    return Secure.Orchestrator:ExecuteSafe(5, func, function()
        return Secure.ExploitAPI.newcclosure(func)
    end)
end

function Secure.Environment:IsExploitThread()
    return Secure.Orchestrator:ExecuteSafe(5, true, function()
        return Secure.ExploitAPI.checkcaller()
    end)
end

function Secure.Environment:SpoofToString()
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local exploit = Secure.ExploitAPI
        local oldToString
        oldToString = exploit.hookfunction(tostring, exploit.newcclosure(function(...)
            local args = {...}
            if type(args[1]) == "function" and not exploit.checkcaller() then
                -- Return empty or native-like format
            end
            return oldToString(...)
        end))
        return true
    end)
end

function Secure.Environment:ProtectPlayer(player)
    -- Anti-Kick multicapa
    Secure.Orchestrator:ExecuteSafe(6, false, function()
        local exploit = Secure.ExploitAPI
        
        -- Capa 1: Reemplazo directo
        if player and typeof(player.Kick) == "function" then
            player.Kick = exploit.newcclosure(function(...) return nil end)
        end
        
        -- Capa 2: Protección de metatabla
        local playerMeta = exploit.getrawmetatable(player)
        if playerMeta then
            exploit.setreadonly(playerMeta, false)
            local oldIndex = playerMeta.__index
            playerMeta.__index = exploit.newcclosure(function(self, key)
                if key == "Kick" then return function() end end
                return oldIndex(self, key)
            end)
            exploit.setreadonly(playerMeta, true)
        end
        
        -- Capa 3: Protección a través del servicio Players
        if Players then
            local originalKick = Players.Kick
            if originalKick then
                Players.Kick = exploit.newcclosure(function(...)
                    local args = {...}
                    if args[1] == player then return nil end
                    return originalKick(...)
                end)
            end
        end
        return true
    end)
end

function Secure.Environment:SpoofCallStack()
    -- Falsifica getcallingscript para simular proveniencia legítima
    return Secure.Orchestrator:ExecuteSafe(6, false, function()
        local exploit = Secure.ExploitAPI
        local originalGetCallingScript = getcallingscript
        if not originalGetCallingScript then return false end
        
        getcallingscript = function()
            local calling = originalGetCallingScript()
            if calling == nil then
                local success, result = pcall(function()
                    return Native.GetService(realGame, "StarterPlayer").StarterPlayerScripts
                end)
                if success and result then return result end
            end
            return calling
        end
        return true
    end)
end

-- ==============================================================================
-- 11. MÓDULO DE EXTRACCIÓN Y WORKSPACE AVANZADO (Secure.Workspace)
-- ==============================================================================
Secure.Workspace = {}

function Secure.Workspace:SaveInstance(fileName, options)
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local defaultOptions = { Decompile = true, NilInstances = true }
        if options then for k, v in pairs(options) do defaultOptions[k] = v end end
        local finalName = fileName or ("SavedGame_" .. os.date("%d-%m-%Y_%H-%M-%S"))
        Secure.ExploitAPI.saveinstance(defaultOptions)
        return true
    end)
end

function Secure.Workspace:GetHiddenInstances()
    -- Orchestrator gets hidden/nil instances securely
    return Secure.Orchestrator:ExecuteSafe(6, {}, function()
        local nils = Secure.ExploitAPI.getnilinstances()
        if #nils > 0 then return nils end
        
        -- Fallback manual scan if getnilinstances is empty but getinstances works
        local manualNils = {}
        for _, obj in ipairs(Secure.ExploitAPI.getinstances()) do
            if obj.Parent == nil then table.insert(manualNils, obj) end
        end
        return manualNils
    end)
end

-- ==============================================================================
-- 12. MÓDULO DE MANIPULACIÓN DE MEMORIA (Secure.GC)
-- ==============================================================================
Secure.GC = {}

function Secure.GC:FindTable(expectedKeys)
    return Secure.Orchestrator:ExecuteSafe(7, {}, function()
        local results = {}
        for _, obj in pairs(Secure.ExploitAPI.getgc(true)) do
            if type(obj) == "table" then
                local matchCount = 0
                for _, key in ipairs(expectedKeys) do
                    if rawget(obj, key) ~= nil then matchCount = matchCount + 1 end
                end
                if matchCount == #expectedKeys then table.insert(results, obj) end
            end
        end
        return results
    end)
end

function Secure.GC:FindFunction(nameOrUpvalue)
    return Secure.Orchestrator:ExecuteSafe(7, nil, function()
        for _, obj in pairs(Secure.ExploitAPI.getgc(true)) do
            if type(obj) == "function" then
                local info = debug.getinfo(obj)
                if info.name == nameOrUpvalue then return obj end
            end
        end
        return nil
    end)
end

function Secure.GC:EnableSafeWrapper(maxCallsPerSecond)
    -- Protege contra detecciones por abuso de llamadas a getgc
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local exploit = Secure.ExploitAPI
        local realGetGC = exploit.getgc
        local lastGCCall = 0
        local callCount = 0
        local maxCalls = maxCallsPerSecond or 5
        
        exploit.getgc = function(...)
            local now = tick()
            callCount = callCount + 1
            if now - lastGCCall >= 1 then
                callCount = 0
                lastGCCall = now
            end
            
            if callCount > maxCalls then
                task.wait(math.random(50, 150) / 1000)
            end
            lastGCCall = tick()
            return realGetGC(...)
        end
        return true
    end)
end

function Secure.GC:NeutralizeMemoryFunctions(expectedKeys, targetFunction)
    -- Busca tablas de anticheat en memoria y silencia funciones sin romperlas
    Secure.Thread:SpawnSafe("GCNeutralizer", function()
        Secure.Orchestrator:ExecuteSafe(7, false, function()
            local exploit = Secure.ExploitAPI
            local tables = self:FindTable(expectedKeys)
            
            for _, v in next, tables do
                local detectedFunc = rawget(v, targetFunction)
                if type(detectedFunc) == "function" then
                    pcall(function()
                        local oldFunc = detectedFunc
                        exploit.hookfunction(detectedFunc, function(...)
                            local args = {...}
                            -- Heurística genérica de ignore
                            if args[1] == "_" then
                                return oldFunc(...)
                            end
                            return task.wait(9e9)
                        end)
                    end)
                end
            end
        end)
    end)
end

-- ==============================================================================
-- 13. MÓDULO DE TELEMETRÍA (Secure.Logger)
-- ==============================================================================
Secure.Logger = {}

function Secure.Logger:SendCrashReport(webhookUrl, errorMessage, scriptName)
    if not webhookUrl or webhookUrl == "" then return false end
    local bodyData = HttpService:JSONEncode({
        content = "🚨 **Crash Detectado en:** " .. tostring(scriptName),
        embeds = {{ description = "```lua\n" .. tostring(errorMessage) .. "\n```", color = 16711680 }}
    })
    return Secure.Network:HttpRequest(webhookUrl, "POST", {["Content-Type"] = "application/json"}, bodyData)
end

-- ==============================================================================
-- 14. MANIPULACIÓN DE PROPIEDADES OCULTAS (Secure.Instance)
-- ==============================================================================
Secure.Instance = {}

function Secure.Instance:GetHidden(instance, property)
    return Secure.Orchestrator:ExecuteSafe(7, nil, function()
        local exploit = Secure.ExploitAPI
        if exploit.gethiddenproperty then
            local hiddenValue, isHidden = exploit.gethiddenproperty(instance, property)
            return hiddenValue
        end
        return nil
    end)
end

function Secure.Instance:SetHidden(instance, property, value)
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local exploit = Secure.ExploitAPI
        if exploit.sethiddenproperty then
            exploit.sethiddenproperty(instance, property, value)
            return true
        end
        return false
    end)
end

function Secure.Instance:SetScriptable(instance, property, isScriptable)
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local exploit = Secure.ExploitAPI
        if exploit.setscriptable then
            exploit.setscriptable(instance, property, isScriptable)
            return true
        end
        return false
    end)
end

-- ==============================================================================
-- 15. MANIPULACIÓN DE ENTORNOS DE SCRIPT (Secure.Scripts)
-- ==============================================================================
Secure.Scripts = {}

function Secure.Scripts:GetAllLocalScripts()
    return Secure.Orchestrator:ExecuteSafe(7, {}, function()
        return Secure.ExploitAPI.getscripts()
    end)
end

function Secure.Scripts:GetScriptEnvironment(scriptInstance)
    return Secure.Orchestrator:ExecuteSafe(7, nil, function()
        if Secure.ExploitAPI.getsenv then
            return Secure.ExploitAPI.getsenv(scriptInstance)
        end
        return nil
    end)
end

function Secure.Scripts:ModifyScriptVariable(scriptInstance, varName, newValue)
    return Secure.Orchestrator:ExecuteSafe(7, false, function()
        local env = self:GetScriptEnvironment(scriptInstance)
        if env and type(env) == "table" and env[varName] ~= nil then
            env[varName] = newValue
            return true
        end
        return false
    end)
end

-- ==============================================================================
-- 16. GESTOR DE HOOKS DINÁMICO (Secure.HookManager)
-- ==============================================================================
Secure.HookManager = {
    NamecallHooks = {},
    IndexHooks = {}
}

function Secure.HookManager:RegisterNamecallHook(identifier, func, strict)
    -- strict: Si es true, cualquier error en el hook bloquea la llamada (por seguridad).
    -- Si es false (safe mode), un error en el hook permite que la llamada original pase para no romper el juego.
    self.NamecallHooks[identifier] = {Callback = func, Strict = strict or false}
end

function Secure.HookManager:RegisterIndexHook(identifier, func, strict)
    self.IndexHooks[identifier] = {Callback = func, Strict = strict or false}
end

function Secure.HookManager:FireNamecall(selfObj, method, args, isExploitThread)
    for id, hookData in pairs(self.NamecallHooks) do
        local success, result = pcall(hookData.Callback, selfObj, method, args, isExploitThread)
        if not success then
            Secure.Logger:InternalError("HookManager_Namecall_" .. tostring(id), result)
            if hookData.Strict then return nil, true end -- Bloqueo preventivo
        elseif result == "BLOCK_CALL" then
            return nil, true -- El hook solicitó bloquear la llamada
        elseif result ~= nil then
            return result, true -- El hook sobrescribió el retorno
        end
    end
    return nil, false
end

function Secure.HookManager:FireIndex(selfObj, key, isExploitThread)
    for id, hookData in pairs(self.IndexHooks) do
        local success, result = pcall(hookData.Callback, selfObj, key, isExploitThread)
        if not success then
            Secure.Logger:InternalError("HookManager_Index_" .. tostring(id), result)
            if hookData.Strict then return nil, true end
        elseif result == "BLOCK_CALL" then
            return nil, true
        elseif result ~= nil then
            return result, true
        end
    end
    return nil, false
end

-- ==============================================================================
-- 17. METAMETHOD HOOKING MAESTRO (Orquestador Final)
-- ==============================================================================
if Secure.Orchestrator.Vectors.CanHook then
    Secure.Thread:SpawnSafe("InitializeMasterHooks", function()
        local exploit = Secure.ExploitAPI
        
        -- Registrar hooks nativos de los módulos en lugar de hardcodearlos en el __namecall
        Secure.HookManager:RegisterNamecallHook("NetworkBlocker", function(selfObj, method, args, isExploitThread)
            if (method == "FireServer" or method == "InvokeServer") and Secure.Network.BlockedRemotes[selfObj.Name] then
                return "BLOCK_CALL"
            end
        end, true) -- Network Hooking debe ser Strict (no dejar pasar si hay error)

        Secure.HookManager:RegisterNamecallHook("GUIProtection_Namecall", function(selfObj, method, args, isExploitThread)
            if not isExploitThread then
                if method == "FindFirstChild" or method == "WaitForChild" then
                    if Secure.GUI.ProtectedGuis[args[1]] then return "BLOCK_CALL" end
                end
            end
        end, false)
        
        Secure.HookManager:RegisterIndexHook("GUIProtection_Index", function(selfObj, key, isExploitThread)
            if not isExploitThread and type(key) == "string" and Secure.GUI.ProtectedGuis[key] then
                return "BLOCK_CALL"
            end
        end, false)
        
        -- Master Hook __namecall
        local oldNamecall
        oldNamecall = exploit.hookmetamethod(realGame, "__namecall", exploit.newcclosure(function(self, ...)
            local method = exploit.getnamecallmethod()
            local args = {...}
            local isExploitThread = exploit.checkcaller()
            
            -- Disparar Hooks Dinámicos
            local overrideResult, shouldOverride = Secure.HookManager:FireNamecall(self, method, args, isExploitThread)
            if shouldOverride then
                return (overrideResult == "BLOCK_CALL") and nil or overrideResult
            end
            
            -- Filtrado especial de colecciones (GetDescendants / GetChildren)
            if not isExploitThread and (method == "GetDescendants" or method == "GetChildren") then
                local result = oldNamecall(self, ...)
                if type(result) == "table" then
                    local cleanResult = {}
                    for _, v in ipairs(result) do
                        local isProtected = false
                        for _, pGui in pairs(Secure.GUI.ProtectedGuis) do
                            if v == pGui then isProtected = true; break end
                        end
                        if not isProtected then table.insert(cleanResult, v) end
                    end
                    return cleanResult
                end
            end
            
            return oldNamecall(self, ...)
        end))
        
        -- Master Hook __index
        local oldIndex
        oldIndex = exploit.hookmetamethod(realGame, "__index", exploit.newcclosure(function(self, idx)
            local isExploitThread = exploit.checkcaller()
            
            local overrideResult, shouldOverride = Secure.HookManager:FireIndex(self, idx, isExploitThread)
            if shouldOverride then
                return (overrideResult == "BLOCK_CALL") and nil or overrideResult
            end
            
            return oldIndex(self, idx)
        end))
    end)
end

return Secure