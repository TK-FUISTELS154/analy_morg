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

    self.CoreGui = self.Cloneref(game:GetService("CoreGui"))
    self.Players = self.Cloneref(game:GetService("Players"))
    self.LocalPlayer = self.Players.LocalPlayer

    self.IsAntiAFKEnabled = false
    self.AntiAFKConnection = nil
    self._kickHookInstalled = false
    self._envGuardInstalled = false

    return self
end

-- =============================================================================
-- SECURE GUI: Contenedor seguro para la suite
-- =============================================================================

function SecurityCore:GetSecureGuiParent()
    local parent = nil

    -- Intento 1: gethui() nativo
    local gethuiFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.gethui) or (type(gethui) == "function" and gethui)
    if gethuiFunc then
        local s, res = pcall(gethuiFunc)
        if s and res then parent = res end
    end

    -- Intento 2: CoreGui con cloneref
    if not parent and self.CoreGui then
        local s, res = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = self.CoreGui
            test:Destroy()
            return self.CoreGui
        end)
        if s and res then parent = self.CoreGui end
    end

    -- Intento 3: Fallback seguro en PlayerGui
    if not parent and self.LocalPlayer then
        parent = self.LocalPlayer:WaitForChild("PlayerGui", 5)
    end

    return parent or game:GetService("CoreGui")
end

function SecurityCore:CreateSafeScreenGui(name)
    local parent = self:GetSecureGuiParent()
    -- Anti-OCR: Nombre aleatorio imposible de escanear por texto
    local randomId = math.random(1000000, 9999999)
    local antiOCR = string.char(math.random(65, 90)) .. string.char(math.random(97, 122))
    local safeName = (name or "AppContainer") .. "_" .. antiOCR .. tostring(randomId)

    -- Limpieza previa
    local existing = parent:FindFirstChild(safeName)
    if existing then pcall(function() existing:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = safeName
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999

    -- Proteger si la API existe
    local protectFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.protectgui)
        or (type(protectgui) == "function" and protectgui)
        or (type(protect_gui) == "function" and protect_gui)
    if protectFunc then
        pcall(protectFunc, gui)
    end

    gui.Parent = parent

    if self.Logger then
        self.Logger:Debug("SECURITY", "ScreenGui seguro creado en " .. tostring(parent:GetFullName()))
    end

    return gui
end

-- =============================================================================
-- ANTI-AFK: VirtualUser + Idled
-- =============================================================================

function SecurityCore:EnableAntiAFK()
    if self.IsAntiAFKEnabled then return end
    self.IsAntiAFKEnabled = true

    local VirtualUser = nil
    pcall(function()
        VirtualUser = game:GetService("VirtualUser")
    end)

    if self.LocalPlayer then
        self.AntiAFKConnection = self.LocalPlayer.Idled:Connect(function()
            if VirtualUser then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end)
    end

    if self.Logger then
        self.Logger:Info("SECURITY", "Anti-AFK activado con éxito.")
    end
end

-- =============================================================================
-- ANTI-KICK: Hook de LocalPlayer:Kick
-- =============================================================================

function SecurityCore:ProtectPlayerKick()
    if self._kickHookInstalled then return true end

    local hookfn = (self.Caps and self.Caps.APIs and self.Caps.APIs.hookfunction) or (type(hookfunction) == "function" and hookfunction)
    local checkcaller = (self.Caps and self.Caps.APIs and self.Caps.APIs.checkcaller) or (type(checkcaller) == "function" and checkcaller) or function() return false end
    local newcclosure = (self.Caps and self.Caps.APIs and self.Caps.APIs.newcclosure) or function(f) return f end

    if not hookfn or not self.LocalPlayer then
        if self.Logger then
            self.Logger:Warn("SECURITY", "Anti-Kick requiere hookfunction (Nivel 6+). Mitigación pasiva.")
        end
        return false
    end

    local oldKick
    local logger = self.Logger
    local s, _ = pcall(function()
        oldKick = hookfn(self.LocalPlayer.Kick, newcclosure(function(inst, message, ...)
            if checkcaller() then
                return oldKick(inst, message, ...)
            end
            if logger then
                logger:Vuln("SECURITY", string.format("LocalPlayer:Kick BLOQUEADO! Razón: %s", tostring(message)))
            end
            return nil
        end))
    end)

    if s then
        self._kickHookInstalled = true
        if self.Logger then
            self.Logger:Info("SECURITY", "Protección activa contra LocalPlayer:Kick instalada.")
        end
        return true
    end

    return false
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
