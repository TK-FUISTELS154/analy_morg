--[[
    =============================================================================
    APEX SUITE - SECURITY CORE v3.0
    (ENVIRONMENT GUARD + ANTI-KICK + ANTI-AFK + ANTI-OCR + LATENCY-AWARE)
    =============================================================================
    Protecciones activas:
    1. ArmEnvironmentGuard: Delegado a CapabilityManager (debug.info, getfenv)
    2. Anti-Kick: Hook de LocalPlayer:Kick con bypass para caller propio
    3. Anti-AFK: VirtualUser + Idled connection
    4. Anti-OCR: Genera nombres ofuscados para ScreenGui
    5. Latency-Aware Correlation: Ventana dinámica basada en Ping + buffer
--]]

local SecurityCore = {}
SecurityCore.__index = SecurityCore
SecurityCore.ClassName = "SecurityCore"

function SecurityCore.new(capabilityManager, logger)
    local self = setmetatable({}, SecurityCore)
    self.Caps = capabilityManager
    self.Logger = logger
    self.RealGame = workspace.Parent or game

    local clonerefFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.cloneref)
        or (type(cloneref) == "function" and cloneref)
        or function(x) return x end
    self.Cloneref = clonerefFunc

    local resolveSrv = function(cName)
        if getgenv()._APEX_RESOLVER then
            local r = getgenv()._APEX_RESOLVER.GetService(cName)
            if r then return r end
        end
        local ok, s = pcall(function() return self.RealGame:GetService(cName) end)
        if ok and s then return s end
        local ok2, s2 = pcall(function() return self.RealGame:FindFirstChildOfClass(cName) end)
        if ok2 and s2 then return s2 end
        local ok3, s3 = pcall(function() return self.RealGame:FindFirstChildWhichIsA(cName) end)
        return ok3 and s3 or nil
    end

    local rawCoreGui = resolveSrv("CoreGui")
    local rawPlayers = resolveSrv("Players")

    self.CoreGui = rawCoreGui and self.Cloneref(rawCoreGui)
    self.Players = rawPlayers and self.Cloneref(rawPlayers)
    self.LocalPlayer = self.Players and (self.Players.LocalPlayer or self.Players:FindFirstChildOfClass("Player"))

    self.IsAntiAFKEnabled = false
    self.AntiAFKConnection = nil
    self._kickHookInstalled = false
    self._envGuardInstalled = false
    self.ProtectedGuis = {}
    self.HookManager = nil

    return self
end

function SecurityCore:SetHookManager(hookManager)
    self.HookManager = hookManager
    for name, gui in pairs(self.ProtectedGuis) do
        if self.HookManager and self.HookManager.RegisterProtectedInstance then
            self.HookManager:RegisterProtectedInstance(gui, name)
        end
    end
end

-- =============================================================================
-- SECURE GUI: Contenedor seguro para la suite (Adaptativo Niveles 3 a 8)
-- =============================================================================
-- Aplica el modelo multi-capa de Infinite Yield y DarkDex:
--   Tier 1 (Nivel 8): gethui()
--   Tier 2 (Nivel 8): protect_gui() + CoreGui
--   Tier 3 (Nivel 3-4): Inyección de Folder en COREGUI.RobloxGui (Evita errores de ScreenGui en CoreGui)
--   Tier 4 (Nivel 3-4): CoreGui directo si es accesible
--   Tier 5 (Nivel 3): PlayerGui con camuflaje total (nombres aleatorios, Archivable=false, DisplayOrder=2e9)

local function generateRandomName(len)
    local chars = {}
    local length = len or math.random(14, 22)
    for i = 1, length do
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

function SecurityCore:CreateSafeScreenGui(customName)
    local safeName = generateRandomName()
    local finalContainer = nil

    local apis = self.Caps and self.Caps.APIs or {}
    local gethuiFunc = apis.gethui or (type(gethui) == "function" and gethui) or (type(get_hidden_gui) == "function" and get_hidden_gui)
    local protectFunc = apis.protectgui or (type(protectgui) == "function" and protectgui) or (type(protect_gui) == "function" and protect_gui) or (type(syn) == "table" and type(syn.protect_gui) == "function" and syn.protect_gui)

    local function createBaseGui()
        local gui = Instance.new("ScreenGui")
        gui.Name = safeName
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 2e9
        gui.IgnoreGuiInset = true
        gui.Archivable = false
        return gui
    end

    -- Tier 1: gethui() nativo (Nivel 8)
    if gethuiFunc then
        local ok, hui = pcall(gethuiFunc)
        if ok and hui then
            local gui = createBaseGui()
            local pOk = pcall(function() gui.Parent = hui end)
            if pOk and gui.Parent then
                finalContainer = gui
            end
        end
    end

    -- Tier 2: protectgui() + CoreGui (Nivel 8)
    if not finalContainer and protectFunc and self.CoreGui then
        pcall(function()
            local gui = createBaseGui()
            protectFunc(gui)
            gui.Parent = self.CoreGui
            if gui.Parent then finalContainer = gui end
        end)
    end

    -- Tier 3: TRUCO DE INFINITE YIELD / DARCKDEX (Nivel 3-4)
    -- Inyectar dentro de RobloxGui como Folder para evitar error de ScreenGui anidado en CoreGui
    if not finalContainer and self.CoreGui then
        pcall(function()
            local robloxGui = self.CoreGui:FindFirstChild("RobloxGui")
            if robloxGui then
                local folder = Instance.new("Folder")
                folder.Name = safeName
                folder.Archivable = false
                folder.Parent = robloxGui
                if folder.Parent then finalContainer = folder end
            end
        end)
    end

    -- Tier 4: CoreGui directo si es accesible (Nivel 4-6)
    if not finalContainer and self.CoreGui then
        pcall(function()
            local gui = createBaseGui()
            gui.Parent = self.CoreGui
            if gui.Parent then finalContainer = gui end
        end)
    end

    -- Tier 5: Fallback seguro en PlayerGui (Nivel 3)
    if not finalContainer and self.LocalPlayer then
        pcall(function()
            local pGui = self.LocalPlayer:FindFirstChildOfClass("PlayerGui") or self.LocalPlayer:WaitForChild("PlayerGui", 5)
            if pGui then
                local gui = createBaseGui()
                gui.Parent = pGui
                if gui.Parent then finalContainer = gui end
            end
        end)
    end

    -- Fallback de emergencia
    if not finalContainer then
        finalContainer = createBaseGui()
        pcall(function() finalContainer.Parent = game:GetService("CoreGui") end)
    end

    self.ProtectedGuis[safeName] = finalContainer
    if self.HookManager and self.HookManager.RegisterProtectedInstance then
        self.HookManager:RegisterProtectedInstance(finalContainer, safeName)
    end

    if self.Logger then
        local pName = pcall(function() return finalContainer.Parent:GetFullName() end) and finalContainer.Parent:GetFullName() or tostring(finalContainer.Parent)
        self.Logger:Debug("SECURITY", string.format("Contenedor seguro creado (%s) en: %s", finalContainer.ClassName, tostring(pName)))
    end

    return finalContainer
end

function SecurityCore:GetSecureGuiParent()
    -- Retrocompatibilidad
    if self.ProtectedGuis then
        for _, g in pairs(self.ProtectedGuis) do
            if g and g.Parent then return g end
        end
    end
    return self.CoreGui or game:GetService("CoreGui")
end

-- =============================================================================
-- ANTI-AFK: Adaptativo (Nivel 7 Señal Silenciosa vs Nivel 3 VirtualUser)
-- =============================================================================

function SecurityCore:EnableAntiAFK()
    if self.IsAntiAFKEnabled then return end
    self.IsAntiAFKEnabled = true

    local LocalPlayer = self.LocalPlayer
    if not LocalPlayer then return end

    -- Método 1: Nivel 7 (Desconexión de señales - 100% silencioso y sin simular clicks físicos)
    local getconnectionsFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.getconnections)
        or (type(getconnections) == "function" and getconnections)
        or (type(get_signal_cons) == "function" and get_signal_cons)

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
        local VirtualUser = nil
        pcall(function() VirtualUser = game:GetService("VirtualUser") end)
        self.AntiAFKConnection = LocalPlayer.Idled:Connect(function()
            if VirtualUser then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end)
    end

    if self.Logger then
        self.Logger:Info("SECURITY", string.format("Anti-AFK activado con éxito (Método: %s).", signalDisabled and "Nivel 7 Desconexión de Señal" or "Nivel 3 VirtualUser"))
    end
end

-- =============================================================================
-- ANTI-KICK: Multi-Capa (Niveles 3 a 8)
-- =============================================================================

function SecurityCore:ProtectPlayerKick()
    if self._kickHookInstalled then return true end

    local hookfn = (self.Caps and self.Caps.APIs and self.Caps.APIs.hookfunction) or (type(hookfunction) == "function" and hookfunction)
    local checkcaller = (self.Caps and self.Caps.APIs and self.Caps.APIs.checkcaller) or (type(checkcaller) == "function" and checkcaller) or function() return false end
    local newcclosure = (self.Caps and self.Caps.APIs and self.Caps.APIs.newcclosure) or function(f) return f end
    local getrawmetatable = (self.Caps and self.Caps.APIs and self.Caps.APIs.getrawmetatable) or (type(getrawmetatable) == "function" and getrawmetatable)
    local setreadonly = (self.Caps and self.Caps.APIs and self.Caps.APIs.setreadonly) or (type(setreadonly) == "function" and setreadonly)

    local player = self.LocalPlayer
    local installedLayers = 0

    -- Capa 1: Reemplazo o hook directo sobre LocalPlayer.Kick
    if player and typeof(player.Kick) == "function" then
        if hookfn then
            local oldKick
            local s = pcall(function()
                oldKick = hookfn(player.Kick, newcclosure(function(inst, message, ...)
                    if checkcaller() then
                        return oldKick(inst, message, ...)
                    end
                    return nil
                end))
            end)
            if s then installedLayers = installedLayers + 1 end
        else
            -- Nivel 3-4 (Sin hookfunction): Reemplazo directo
            pcall(function()
                player.Kick = newcclosure(function(...) return nil end)
                installedLayers = installedLayers + 1
            end)
        end
    end

    -- Capa 2: Hook en metatabla de Player (Nivel 4-6)
    if player and getrawmetatable and setreadonly then
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
                installedLayers = installedLayers + 1
            end
        end)
    end

    -- Capa 3: Protección a través del servicio Players (Nivel 6)
    if self.Players and hookfn then
        pcall(function()
            local origPlayersKick = self.Players.Kick
            if origPlayersKick then
                hookfn(origPlayersKick, newcclosure(function(selfSrv, targetPlr, ...)
                    if targetPlr == player and not checkcaller() then
                        return nil
                    end
                    return origPlayersKick(selfSrv, targetPlr, ...)
                end))
                installedLayers = installedLayers + 1
            end
        end)
    end

    self._kickHookInstalled = (installedLayers > 0)
    if self.Logger then
        self.Logger:Info("SECURITY", string.format("Anti-Kick instalado (%d capas activas).", installedLayers))
    end
    return self._kickHookInstalled
end

-- =============================================================================
-- ARM ENVIRONMENT GUARD: Delegación a CapabilityManager
-- =============================================================================

function SecurityCore:ArmEnvironmentGuard()
    if self._envGuardInstalled then return true end

    if self.Caps and self.Caps.ArmEnvironmentGuard then
        local ok, msg = self.Caps:ArmEnvironmentGuard()
        self._envGuardInstalled = ok
        if self.Logger then
            if ok then
                self.Logger:Info("SECURITY", "Environment Guard armado: " .. tostring(msg))
            else
                self.Logger:Warn("SECURITY", "Environment Guard no instalado: " .. tostring(msg))
            end
        end
        return ok
    end

    if self.Logger then
        self.Logger:Warn("SECURITY", "CapabilityManager no soporta ArmEnvironmentGuard.")
    end
    return false
end

-- =============================================================================
-- LATENCY-AWARE CORRELATION WINDOW
-- =============================================================================
-- Retorna la ventana de correlación dinámica basada en el Ping actual.
-- Uso: SecurityCore:GetCorrelationWindow() → milisegundos

function SecurityCore:GetCorrelationWindow()
    local stats = game:GetService("Stats")
    local ping = 100 -- Fallback de 100ms

    pcall(function()
        -- Intentar obtener el ping real desde Stats
        local network = stats:FindFirstChild("PerformanceStats")
        if network then
            local pingItem = network:FindFirstChild("Ping")
            if pingItem then
                ping = pingItem:GetValue()
            end
        end
    end)

    -- Intentar método alternativo con GetNetworkPing
    if ping <= 0 then
        pcall(function()
            ping = game:GetService("Players").LocalPlayer:GetNetworkPing() * 1000
        end)
    end

    -- Ventana = Ping actual + 350ms de buffer (mínimo 400ms, máximo 2000ms)
    local window = math.clamp(ping + 350, 400, 2000)
    return window
end

-- =============================================================================
-- FULL SECURITY BOOTSTRAP
-- =============================================================================

function SecurityCore:BootstrapAllProtections()
    local results = {}

    -- 1. Anti-Kick
    results.AntiKick = self:ProtectPlayerKick()

    -- 2. Anti-AFK
    self:EnableAntiAFK()
    results.AntiAFK = self.IsAntiAFKEnabled

    -- 3. Environment Guard
    results.EnvGuard = self:ArmEnvironmentGuard()

    if self.Logger then
        self.Logger:Info("SECURITY", string.format(
            "Bootstrap completo: AntiKick=%s | AntiAFK=%s | EnvGuard=%s",
            tostring(results.AntiKick), tostring(results.AntiAFK), tostring(results.EnvGuard)
        ))
    end

    return results
end

-- =============================================================================
-- DESTRUCTOR
-- =============================================================================

function SecurityCore:Destroy()
    if self.AntiAFKConnection then
        pcall(function() self.AntiAFKConnection:Disconnect() end)
    end
end

return SecurityCore
