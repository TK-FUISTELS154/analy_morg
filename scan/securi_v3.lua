-- ==============================================================================
-- 🛡️ SECURI_V3.LUA - UNIVERSAL SECURITY & STEALTH FRAMEWORK (NIVELES 3 A 8)
-- ==============================================================================
-- Arquitectura Híbrida de Máximo Sigilo inspirada en Infinite Yield y DarkDex.
-- Diseñado especialmente para ejecutores de Nivel 3-4 (Solara, web injectors,
-- ejecutores móviles) con escalabilidad automática a Nivel 5, 6, 7 y 8 (God-Tier).
--
-- CARACTERÍSTICAS PRINCIPALES:
--   1. GUI 5-Tier Invisible: Alojamiento en gethui, protectgui, RobloxGui (Folder trick),
--      CoreGui o PlayerGui con nombres 100% efímeros y Archivable=false.
--   2. Cero Hooks en Boot: Operación 100% pasiva al arrancar; los hooks a metatablas
--      son bajo demanda para eludir escáneres de integridad en el spawn del personaje.
--   3. Anti-AFK Adaptativo: Desconexión silenciosa de señales (Nivel 7) sin clics simulados;
--      fallback pasivo con VirtualUser y jitter aleatorio (Nivel 3-4).
--   4. Anti-Kick Multi-Capa: Reemplazo directo (Nivel 3), Metatabla __index (Nivel 4-5)
--      y Hook de servicio Players.Kick (Nivel 6-8).
--   5. Aislamiento F9 (Anti-Crash & Anti-Log): Todos los hilos se ejecutan en sandboxes
--      silenciosos que impiden que los anti-cheats intercepten errores vía LogService.
--   6. Protección de Memoria (cloneref Bug Guard & Safe GC): Inmune a corrupción de
--      userdata en ejecutores Nivel 3 y limitador de ráfagas en getgc().
--   7. Ocultación en Colecciones: Hooks de sigilo que filtran las GUIs protegidas de
--      GetChildren(), GetDescendants(), FindFirstChild() y __index para scripts del juego.
-- ==============================================================================

local Securi = {}
Securi.VERSION = "3.0.0"
Securi.NAME = "Securi_v3"

-- 0. NÚCLEO NATIVO Y PROTECCIÓN ANTI-POISONING
local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game
local rawCloneref = (type(cloneref) == "function" and cloneref) or nil

-- Validador de bug de cloneref en ejecutores Nivel 3-4
local function safeCloneref(instance)
    if not instance or not rawCloneref then return instance end
    local ok, cloned = pcall(rawCloneref, instance)
    if ok and cloned and type(cloned) == "userdata" then
        local valid = pcall(function() return cloned.ClassName end)
        if valid then return cloned end
    end
    return instance
end

local Native = {
    GetService = rawGame.GetService,
    GetDescendants = rawGame.GetDescendants,
    GetChildren = rawGame.GetChildren,
    FindFirstChild = rawGame.FindFirstChild,
    FindFirstChildOfClass = rawGame.FindFirstChildOfClass,
    FindFirstChildWhichIsA = rawGame.FindFirstChildWhichIsA,
    WaitForChild = rawGame.WaitForChild,
    IsA = rawGame.IsA
}

-- ==============================================================================
-- 1. EVALUADOR HEURÍSTICO DE NIVEL (NIVELES 3 A 8)
-- ==============================================================================
Securi.Orchestrator = {
    Level = 3,
    Score = 0,
    Capabilities = {},
    Vectors = {
        CanHook = false,
        CanSpoof = false,
        CanProtectGUI = false,
        CanManipulateGC = false,
        CanReadFiles = false,
        CanDisconnectSignals = false,
        CanDecompile = false
    }
}

function Securi.Orchestrator:Evaluate()
    local caps = {}
    local score = 0

    local function test(globalName, ...)
        local aliases = {globalName, ...}
        for _, name in ipairs(aliases) do
            local found = false
            pcall(function()
                local env = (type(getgenv) == "function" and getgenv()) or getfenv(0)
                if env and env[name] ~= nil and type(env[name]) == "function" then
                    found = true
                end
            end)
            if not found then
                pcall(function()
                    if _G and _G[name] ~= nil and type(_G[name]) == "function" then
                        found = true
                    end
                end)
            end
            if found then
                caps[globalName] = true
                return true
            end
        end
        caps[globalName] = false
        return false
    end

    -- Detección de APIs por nivel
    local c_genv       = test("getgenv", "getrenv")
    local c_loadstring = test("loadstring", "load")
    local c_clipboard  = test("setclipboard", "toclipboard", "set_clipboard")
    
    local c_rawmeta    = test("getrawmetatable")
    local c_readonly   = test("setreadonly", "make_writeable", "makewriteable")
    local c_cloneref   = test("cloneref")
    local c_namecall   = test("getnamecallmethod", "get_namecall_method")
    
    local c_gc         = test("getgc", "get_gc_objects")
    local c_nilinst    = test("getnilinstances", "get_nil_instances")
    local c_instances  = test("getinstances", "get_instances")
    local c_senv       = test("getsenv", "get_senv")
    local c_hidden     = test("gethiddenproperty", "get_hidden_property")
    
    local c_hookmeta   = test("hookmetamethod")
    local c_hookfunc   = test("hookfunction", "replaceclosure")
    local c_cclosure   = test("newcclosure")
    local c_caller     = test("checkcaller")
    
    local c_file       = test("readfile") and test("writefile")
    local c_signal     = test("getconnections", "get_signal_cons")
    local c_request    = test("request", "http_request")
    
    local c_hui        = test("gethui", "get_hidden_gui")
    local c_protectgui = test("protectgui", "protect_gui")
    local c_teleport   = test("queue_on_teleport", "queueonteleport")
    local c_decomp     = test("decompile")

    -- Cálculo del puntaje
    if c_genv then score = score + 5 end
    if c_loadstring then score = score + 5 end
    if c_clipboard then score = score + 5 end
    if c_rawmeta then score = score + 10 end
    if c_readonly then score = score + 10 end
    if c_cloneref then score = score + 10 end
    if c_namecall then score = score + 5 end
    if c_gc then score = score + 15 end
    if c_nilinst or c_instances then score = score + 10 end
    if c_hookmeta then score = score + 25 end
    if c_hookfunc then score = score + 20 end
    if c_file then score = score + 15 end
    if c_signal then score = score + 15 end
    if c_hui or c_protectgui then score = score + 20 end
    if c_decomp then score = score + 20 end

    -- Determinación del Nivel Efectivo (3 a 8)
    local level = 3
    if (c_rawmeta and c_readonly) or c_cloneref then level = 4 end
    if c_gc or c_instances or c_senv then level = 5 end
    if c_hookmeta or c_hookfunc then level = 6 end
    if (c_file or c_signal) and level >= 6 then level = 7 end
    if (c_hui or c_protectgui) and level >= 7 then level = 8 end

    self.Level = level
    self.Score = score
    self.Capabilities = caps
    self.Vectors.CanHook = (c_hookmeta or c_hookfunc) and true or false
    self.Vectors.CanSpoof = (c_cloneref or c_readonly) and true or false
    self.Vectors.CanProtectGUI = (c_hui or c_protectgui) and true or false
    self.Vectors.CanManipulateGC = c_gc and true or false
    self.Vectors.CanReadFiles = c_file and true or false
    self.Vectors.CanDisconnectSignals = c_signal and true or false
    self.Vectors.CanDecompile = c_decomp and true or false

    return self.Level
end

Securi.Orchestrator:Evaluate()

function Securi:GetLevel()
    return self.Orchestrator.Level
end

function Securi:IsLevel(minLevel)
    return self.Orchestrator.Level >= (minLevel or 3)
end

-- ==============================================================================
-- 2. SERVICIOS BLINDADOS (Securi.Services)
-- ==============================================================================
-- Resolución universal por ClassName con 4 niveles de fallback y cloneref protegido.
Securi.Services = setmetatable({}, {
    __index = function(self, serviceName)
        local cached = rawget(self, serviceName)
        if cached then return cached end

        local resolved = nil

        -- Fallback Workspace
        if serviceName == "Workspace" and typeof(workspace) == "Instance" then
            resolved = workspace
        end

        -- Nivel 1: GetService oficial
        if not resolved then
            local ok, s = pcall(function() return Native.GetService(rawGame, serviceName) end)
            if ok and s then resolved = s end
        end

        -- Nivel 2: FindFirstChildOfClass
        if not resolved then
            local ok, s = pcall(function() return Native.FindFirstChildOfClass(rawGame, serviceName) end)
            if ok and s then resolved = s end
        end

        -- Nivel 3: FindFirstChildWhichIsA
        if not resolved then
            local ok, s = pcall(function() return Native.FindFirstChildWhichIsA(rawGame, serviceName) end)
            if ok and s then resolved = s end
        end

        -- Nivel 4: Barrido de hijos directos
        if not resolved then
            local ok, children = pcall(function() return Native.GetChildren(rawGame) end)
            if ok and children then
                for _, child in ipairs(children) do
                    if child.ClassName == serviceName then
                        resolved = child
                        break
                    end
                end
            end
        end

        if resolved then
            local secureObj = safeCloneref(resolved)
            rawset(self, serviceName, secureObj)
            return secureObj
        end

        return nil
    end
})

local Players = Securi.Services.Players
local CoreGui = Securi.Services.CoreGui
local HttpService = Securi.Services.HttpService
local RunService = Securi.Services.RunService

function Securi:GetLocalPlayer()
    local plrs = Securi.Services.Players
    if plrs then
        if plrs.LocalPlayer then return plrs.LocalPlayer end
        local ok, lp = pcall(function() return Native.FindFirstChildOfClass(plrs, "Player") end)
        if ok and lp then return lp end
    end
    return nil
end

-- ==============================================================================
-- 3. GESTIÓN SEGURA DE HILOS Y SANDBOX (Securi.Thread)
-- ==============================================================================
-- Aísla errores impidiendo que los anti-cheats detecten fallos vía LogService.MessageOut
Securi.Thread = {}

function Securi.Thread:SpawnSafe(threadName, callback, ...)
    local args = {...}
    return task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(args))
        end)
        if not success and _G.SECURI_DEBUG then
            warn(string.format("[Securi_v3][Thread:%s] Error aislado: %s", tostring(threadName), tostring(err)))
        end
    end)
end

function Securi.Thread:CallSafe(callback, fallback, ...)
    local success, result = pcall(callback, ...)
    if success then return result end
    if _G.SECURI_DEBUG then
        warn(string.format("[Securi_v3][CallSafe] Excepción controlada: %s", tostring(result)))
    end
    return fallback
end

-- ==============================================================================
-- 4. GUI SEGURA MULTI-TIER (Securi.GUI)
-- ==============================================================================
-- Implementa la jerarquía maestra de Infinite Yield y DarkDex:
--   Tier 1 (Nivel 8): gethui()
--   Tier 2 (Nivel 8): protect_gui() + CoreGui
--   Tier 3 (Nivel 3-4): Inyección de Folder en COREGUI.RobloxGui (Evita errores de ScreenGui en CoreGui)
--   Tier 4 (Nivel 4-6): CoreGui directo si es accesible
--   Tier 5 (Nivel 3): PlayerGui con camuflaje total (nombres efímeros, Archivable=false, DisplayOrder=2e9)
Securi.GUI = {
    ProtectedGuis = {},
    ProtectedNames = {}
}

local function generateRandomAlphaNumeric(length)
    local len = length or math.random(15, 24)
    local chars = {}
    for i = 1, len do
        local r = math.random(1, 3)
        if r == 1 then
            chars[i] = string.char(math.random(97, 122)) -- a-z
        elseif r == 2 then
            chars[i] = string.char(math.random(65, 90))  -- A-Z
        else
            chars[i] = string.char(math.random(48, 57))  -- 0-9
        end
    end
    return table.concat(chars)
end

function Securi.GUI:CreateSafe(optionalName, customOptions)
    local options = customOptions or {}
    local finalGuiName = generateRandomAlphaNumeric(options.Length or 18)
    
    local exploitGethui = (type(gethui) == "function" and gethui) or (type(get_hidden_gui) == "function" and get_hidden_gui) or nil
    local exploitProtect = (type(protectgui) == "function" and protectgui)
        or (type(protect_gui) == "function" and protect_gui)
        or (type(syn) == "table" and type(syn.protect_gui) == "function" and syn.protect_gui)
        or nil

    local function createBaseScreenGui()
        local gui = Instance.new("ScreenGui")
        gui.Name = finalGuiName
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 2e9
        gui.IgnoreGuiInset = true
        gui.Archivable = false
        return gui
    end

    local returnedContainer = nil
    local LocalPlayer = Securi:GetLocalPlayer()
    local COREGUI = Securi.Services.CoreGui

    -- Tier 1: gethui() nativo (Nivel 8)
    if exploitGethui then
        local s, hui = pcall(exploitGethui)
        if s and hui then
            local gui = createBaseScreenGui()
            local pOk = pcall(function() gui.Parent = hui end)
            if pOk and gui.Parent then returnedContainer = gui end
        end
    end

    -- Tier 2: protect_gui + CoreGui (Nivel 8)
    if not returnedContainer and exploitProtect and COREGUI then
        pcall(function()
            local gui = createBaseScreenGui()
            exploitProtect(gui)
            gui.Parent = COREGUI
            if gui.Parent then returnedContainer = gui end
        end)
    end

    -- Tier 3: TRUCO DE INFINITE YIELD / DARCKDEX (Nivel 3-4)
    -- Inyectar dentro de RobloxGui como Folder para evitar error de ScreenGui anidado en CoreGui
    if not returnedContainer and COREGUI then
        pcall(function()
            local robloxGui = Native.FindFirstChild(COREGUI, "RobloxGui")
            if robloxGui then
                local folder = Instance.new("Folder")
                folder.Name = finalGuiName
                folder.Archivable = false
                folder.Parent = robloxGui
                if folder.Parent then returnedContainer = folder end
            end
        end)
    end

    -- Tier 4: CoreGui directo si es accesible (Nivel 4-6)
    if not returnedContainer and COREGUI then
        pcall(function()
            local gui = createBaseScreenGui()
            gui.Parent = COREGUI
            if gui.Parent then returnedContainer = gui end
        end)
    end

    -- Tier 5: Fallback seguro en PlayerGui (Nivel 3)
    if not returnedContainer and LocalPlayer then
        pcall(function()
            local pGui = Native.FindFirstChildOfClass(LocalPlayer, "PlayerGui") or Native.WaitForChild(LocalPlayer, "PlayerGui", 5)
            if pGui then
                local gui = createBaseScreenGui()
                gui.Parent = pGui
                if gui.Parent then returnedContainer = gui end
            end
        end)
    end

    -- Fallback final
    if not returnedContainer then
        returnedContainer = createBaseScreenGui()
        pcall(function() returnedContainer.Parent = rawGame:GetService("CoreGui") end)
    end

    self.ProtectedGuis[finalGuiName] = returnedContainer
    self.ProtectedNames[finalGuiName] = true
    if optionalName and type(optionalName) == "string" then
        self.ProtectedNames[optionalName] = true
    end

    -- Notificar al gestor de hooks si está activo
    if Securi.Hooks and Securi.Hooks.RegisterProtectedInstance then
        Securi.Hooks:RegisterProtectedInstance(returnedContainer, finalGuiName)
        if optionalName then
            Securi.Hooks:RegisterProtectedInstance(nil, optionalName)
        end
    end

    return returnedContainer
end

function Securi.GUI:RandomizeName(instance, len)
    if instance and instance.Name then
        local newName = generateRandomAlphaNumeric(len or 16)
        instance.Name = newName
        self.ProtectedNames[newName] = true
        return newName
    end
    return nil
end

function Securi.GUI:BlockDetectionText(player)
    -- Oculta dinámicamente labels en la GUI del jugador que contengan cadenas de ban/kick
    local targetPlayer = player or Securi:GetLocalPlayer()
    if not targetPlayer then return end

    Securi.Thread:SpawnSafe("TextCensor", function()
        local playerGui = Native.WaitForChild(targetPlayer, "PlayerGui", 5)
        if not playerGui then return end

        playerGui.DescendantAdded:Connect(function(desc)
            if desc and (Native.IsA(desc, "TextLabel") or Native.IsA(desc, "TextBox")) then
                local text = tostring(desc.Text):lower()
                if text:find("detect") or text:find("kick") or text:find("ban") or text:find("cheat") then
                    desc.Text = ""
                    desc.Visible = false
                end
            end
        end)
    end)
end

-- ==============================================================================
-- 5. ANTI-AFK ADAPTATIVO (Securi.Presence)
-- ==============================================================================
-- En Nivel 7: Desconexión de señales 100% silenciosa (Cero clics simulados).
-- En Nivel 3-4: VirtualUser con fluctuación temporal para evitar banderas de patrón.
Securi.Presence = {
    IsEnabled = false,
    Connection = nil
}

function Securi.Presence:EnableAntiAFK()
    if self.IsEnabled then return true end
    self.IsEnabled = true

    local LocalPlayer = Securi:GetLocalPlayer()
    if not LocalPlayer then return false end

    -- Método 1: Nivel 7 (Desconexión de señales - Máximo sigilo)
    local getconnectionsFunc = (type(getconnections) == "function" and getconnections)
        or (type(get_signal_cons) == "function" and get_signal_cons)
        or nil

    local signalDisabled = false
    if getconnectionsFunc then
        pcall(function()
            for _, conn in pairs(getconnectionsFunc(LocalPlayer.Idled)) do
                if conn.Disable then
                    conn:Disable()
                    signalDisabled = true
                elseif conn.Disconnect then
                    conn:Disconnect()
                    signalDisabled = true
                end
            end
        end)
    end

    -- Método 2: Nivel 3-4 (Fallback pasivo con VirtualUser)
    if not signalDisabled then
        local VirtualUser = Securi.Services.VirtualUser
        self.Connection = LocalPlayer.Idled:Connect(function()
            if VirtualUser then
                pcall(function()
                    task.wait(math.random(10, 50) / 100)
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end)
    end

    return true
end

-- ==============================================================================
-- 6. ANTI-KICK MULTI-CAPA (Securi.AntiKick)
-- ==============================================================================
-- Protege LocalPlayer.Kick a través de 3 niveles de defensa sin romper el juego.
Securi.AntiKick = {
    IsInstalled = false
}

function Securi.AntiKick:ProtectPlayer(customPlayer)
    if self.IsInstalled then return true end

    local player = customPlayer or Securi:GetLocalPlayer()
    if not player then return false end

    local hookfn = (type(hookfunction) == "function" and hookfunction) or nil
    local checkcaller = (type(checkcaller) == "function" and checkcaller) or function() return false end
    local newcclosure = (type(newcclosure) == "function" and newcclosure) or function(f) return f end
    local getrawmetatable = (type(getrawmetatable) == "function" and getrawmetatable) or nil
    local setreadonly = (type(setreadonly) == "function" and setreadonly) or nil

    local installed = 0

    -- Capa 1: Reemplazo / hook directo de LocalPlayer.Kick
    if typeof(player.Kick) == "function" then
        if hookfn then
            local oldKick
            pcall(function()
                oldKick = hookfn(player.Kick, newcclosure(function(inst, ...)
                    if checkcaller() then
                        return oldKick(inst, ...)
                    end
                    return nil
                end))
                installed = installed + 1
            end)
        else
            -- Nivel 3-4 sin hookfunction: Reemplazo limpio
            pcall(function()
                player.Kick = newcclosure(function(...) return nil end)
                installed = installed + 1
            end)
        end
    end

    -- Capa 2: Protección de Metatabla (Nivel 4-6)
    if getrawmetatable and setreadonly then
        pcall(function()
            local meta = getrawmetatable(player)
            if meta then
                setreadonly(meta, false)
                local oldIndex = meta.__index
                meta.__index = newcclosure(function(selfObj, key)
                    if key == "Kick" and not checkcaller() then
                        return function() return nil end
                    end
                    return oldIndex(selfObj, key)
                end)
                setreadonly(meta, true)
                installed = installed + 1
            end
        end)
    end

    -- Capa 3: Protección a través del servicio Players (Nivel 6)
    local PlayersSrv = Securi.Services.Players
    if PlayersSrv and hookfn then
        pcall(function()
            local origKick = PlayersSrv.Kick
            if origKick then
                hookfn(origKick, newcclosure(function(selfSrv, targetPlr, ...)
                    if targetPlr == player and not checkcaller() then
                        return nil
                    end
                    return origKick(selfSrv, targetPlr, ...)
                end))
                installed = installed + 1
            end
        end)
    end

    self.IsInstalled = (installed > 0)
    return self.IsInstalled
end

-- ==============================================================================
-- 7. GESTOR DE HOOKS Y SIGILO BAJO DEMANDA (Securi.Hooks)
-- ==============================================================================
-- Cero hooks en el boot; solo se activa bajo demanda para ocultar GUIs de GetChildren/GetDescendants.
Securi.Hooks = {
    IsHooked = false,
    ProtectedInstances = setmetatable({}, { __mode = "k" }),
    ProtectedNames = {},
    BlockedRemotes = {}
}

function Securi.Hooks:RegisterProtectedInstance(instance, name)
    if instance then self.ProtectedInstances[instance] = true end
    if name and type(name) == "string" then self.ProtectedNames[name] = true end
end

function Securi.Hooks:BlockRemote(remoteName)
    self.BlockedRemotes[tostring(remoteName):lower()] = true
    if not self.IsHooked and Securi.Orchestrator.Vectors.CanHook then
        self:InstallHooks()
    end
end

function Securi.Hooks:InstallHooks()
    if self.IsHooked then return true end
    if not Securi.Orchestrator.Vectors.CanHook then return false end

    local hookmetamethod = (type(hookmetamethod) == "function" and hookmetamethod) or nil
    local checkcaller = (type(checkcaller) == "function" and checkcaller) or function() return false end
    local newcclosure = (type(newcclosure) == "function" and newcclosure) or function(f) return f end
    local getnamecallmethod = (type(getnamecallmethod) == "function" and getnamecallmethod) or (type(get_namecall_method) == "function" and get_namecall_method) or nil

    if not hookmetamethod or not getnamecallmethod then return false end

    local oldNamecall
    oldNamecall = hookmetamethod(rawGame, "__namecall", newcclosure(function(selfObj, ...)
        local method = getnamecallmethod()
        local args = {...}
        local isExploit = checkcaller()

        -- Bloqueador de Remotes
        if method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer" then
            local rName = tostring(selfObj):lower()
            if Securi.Hooks.BlockedRemotes[rName] then
                return nil
            end
        end

        -- Sigilo de GUI: Filtrado de GetChildren y GetDescendants para scripts del juego
        if not isExploit then
            if method == "GetDescendants" or method == "GetChildren" then
                local res = oldNamecall(selfObj, ...)
                if type(res) == "table" then
                    local clean = {}
                    for _, v in ipairs(res) do
                        if not Securi.Hooks.ProtectedInstances[v] and not (v and Securi.Hooks.ProtectedNames[v.Name]) then
                            table.insert(clean, v)
                        end
                    end
                    return clean
                end
                return res
            elseif method == "FindFirstChild" or method == "WaitForChild" then
                local searchName = args[1]
                if searchName and type(searchName) == "string" and Securi.Hooks.ProtectedNames[searchName] then
                    return nil
                end
            end
        end

        return oldNamecall(selfObj, ...)
    end))

    -- Hook __index
    pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(rawGame, "__index", newcclosure(function(selfObj, key)
            if not checkcaller() and type(key) == "string" and Securi.Hooks.ProtectedNames[key] then
                return nil
            end
            return oldIndex(selfObj, key)
        end))
    end)

    self.IsHooked = true
    return true
end

-- ==============================================================================
-- 8. GESTIÓN SEGURA DE MEMORIA Y GC (Securi.GC)
-- ==============================================================================
Securi.GC = {
    LastScan = 0,
    MinDelay = 1.0,
    Cache = nil,
    CacheTime = 0
}

function Securi.GC:GetSafeGC(forceRefresh)
    local getgcFunc = (type(getgc) == "function" and getgc) or (type(get_gc_objects) == "function" and get_gc_objects) or nil
    if not getgcFunc then return {} end

    local now = tick()
    if not forceRefresh and self.Cache and (now - self.CacheTime < 3.0) then
        return self.Cache
    end

    if (now - self.LastScan) < self.MinDelay then
        task.wait(math.random(40, 100) / 1000)
    end

    self.LastScan = tick()
    local ok, res = pcall(function() return getgcFunc(true) end)
    if ok and type(res) == "table" then
        self.Cache = res
        self.CacheTime = tick()
        return res
    end
    return {}
end

function Securi.GC:FindTable(expectedKeys)
    local gc = self:GetSafeGC()
    local results = {}
    for _, obj in ipairs(gc) do
        if type(obj) == "table" then
            local count = 0
            for _, k in ipairs(expectedKeys) do
                if rawget(obj, k) ~= nil then count = count + 1 end
            end
            if count == #expectedKeys then table.insert(results, obj) end
        end
    end
    return results
end

function Securi.GC:FindFunction(nameOrInfo)
    local gc = self:GetSafeGC()
    for _, obj in ipairs(gc) do
        if type(obj) == "function" then
            local info = debug.getinfo(obj)
            if info and (info.name == nameOrInfo or info.source:find(nameOrInfo)) then
                return obj
            end
        end
    end
    return nil
end

-- ==============================================================================
-- 9. RED Y SERVER HOP (Securi.Network & Securi.Server)
-- ==============================================================================
Securi.Network = {}

function Securi.Network:HttpRequest(options)
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        or nil

    if req then
        local ok, res = pcall(req, options)
        if ok and res then return res end
    end

    -- Fallback HttpService (GET)
    if HttpService and (not options.Method or options.Method == "GET") then
        local ok, body = pcall(function() return HttpService:GetAsync(options.Url) end)
        if ok and body then return { Body = body, StatusCode = 200 } end
    end

    return nil
end

Securi.Server = {}

function Securi.Server:QueueOnTeleport(codeString)
    local qot = (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (type(queueonteleport) == "function" and queueonteleport)
        or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or nil

    if qot and type(codeString) == "string" then
        return pcall(qot, codeString)
    end
    return false
end

-- ==============================================================================
-- 10. ALMACENAMIENTO LOCAL / CONFIGURACIONES (Securi.Storage)
-- ==============================================================================
Securi.Storage = {
    Folder = "SecuriData"
}

function Securi.Storage:Save(fileName, dataTable)
    local writefileFunc = (type(writefile) == "function" and writefile) or nil
    local makefolderFunc = (type(makefolder) == "function" and makefolder) or nil
    local isfolderFunc = (type(isfolder) == "function" and isfolder) or nil

    if writefileFunc and HttpService then
        pcall(function()
            if makefolderFunc and isfolderFunc and not isfolderFunc(self.Folder) then
                makefolderFunc(self.Folder)
            end
            local json = HttpService:JSONEncode(dataTable)
            writefileFunc(self.Folder .. "/" .. fileName .. ".json", json)
        end)
        return true
    end
    return false
end

function Securi.Storage:Load(fileName)
    local readfileFunc = (type(readfile) == "function" and readfile) or nil
    local isfileFunc = (type(isfile) == "function" and isfile) or nil

    if readfileFunc and HttpService then
        local path = self.Folder .. "/" .. fileName .. ".json"
        if isfileFunc and isfileFunc(path) then
            local ok, content = pcall(readfileFunc, path)
            if ok and content then
                local decOk, data = pcall(function() return HttpService:JSONDecode(content) end)
                if decOk then return data end
            end
        end
    end
    return nil
end

-- ==============================================================================
-- 11. SPOOFING DE CALLSTACK (Securi.Spoof)
-- ==============================================================================
Securi.Spoof = {}

function Securi.Spoof:SpoofCallStack()
    if type(getcallingscript) == "function" then
        local original = getcallingscript
        local starter = nil
        pcall(function()
            local sp = Native.GetService(rawGame, "StarterPlayer")
            starter = sp and Native.FindFirstChild(sp, "StarterPlayerScripts")
        end)

        getcallingscript = function()
            local calling = original()
            if calling == nil and starter then
                return starter
            end
            return calling
        end
        return true
    end
    return false
end

-- ==============================================================================
-- 12. RETROCOMPATIBILIDAD CON SCRIPTS EXISTENTES
-- ==============================================================================
-- Permite que scripts que buscaban 'Secure.GUI:CreateSafe' o 'Secure.Thread:SpawnSafe'
-- funcionen inmediatamente sin modificar una sola línea.
Securi.Environment = {
    ProtectPlayer = function(self, player) return Securi.AntiKick:ProtectPlayer(player) end,
    SpoofCallStack = function(self) return Securi.Spoof:SpoofCallStack() end
}

-- Registro seguro en entorno global (sin contaminar _G en ejecutores Nivel 3)
local safeGenv = (typeof(getgenv) == "function" and getgenv()) or nil
if safeGenv and safeGenv ~= _G and safeGenv ~= shared then
    safeGenv.Securi = Securi
    safeGenv.Secure = Securi -- Alias retrocompatible
end

return Securi

