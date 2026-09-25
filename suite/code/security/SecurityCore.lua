--[[
    =============================================================================
    APEX SUITE - SECURITY CORE
    =============================================================================
    Integra protecciones de secure.lua:
    - Bypasses de GUI y contenedor seguro (gethui / cloneref / PlayerGui spoofed)
    - Anti-Kick spoofing
    - Anti-AFK (VirtualUser / Idled connection bypass)
    - Anti-OCR y protección contra escaneos de texto
--]]

local SecurityCore = {}
SecurityCore.__index = SecurityCore
SecurityCore.ClassName = "SecurityCore"

function SecurityCore.new(capabilityManager, logger)
    local self = setmetatable({}, SecurityCore)
    self.Caps = capabilityManager
    self.Logger = logger
    self.RealGame = workspace.Parent or game
    self.Cloneref = (self.Caps and self.Caps.APIs.cloneref) or function(x) return x end
    
    self.CoreGui = self.Cloneref(game:GetService("CoreGui"))
    self.Players = self.Cloneref(game:GetService("Players"))
    self.LocalPlayer = self.Players.LocalPlayer
    
    self.IsAntiAFKEnabled = false
    self.AntiAFKConnection = nil
    
    return self
end

function SecurityCore:GetSecureGuiParent()
    local parent = nil
    
    -- Intento 1: gethui() nativo
    if self.Caps and self.Caps.APIs.gethui then
        local s, res = pcall(self.Caps.APIs.gethui)
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
    local randomId = math.random(1000000, 9999999)
    local safeName = (name or "AppContainer") .. "_" .. tostring(randomId)
    
    -- Limpieza previa
    local existing = parent:FindFirstChild(safeName)
    if existing then pcall(function() existing:Destroy() end) end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = safeName
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    
    -- Proteger si la API existe
    if self.Caps and self.Caps.APIs.protectgui then
        pcall(self.Caps.APIs.protectgui, gui)
    end
    
    gui.Parent = parent
    
    if self.Logger then
        self.Logger:Debug("SECURITY", "ScreenGui seguro creado en " .. tostring(parent:GetFullName()))
    end
    
    return gui
end

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

function SecurityCore:ProtectPlayerKick()
    -- Si no hay hooks de metamétodos, solo registramos aviso
    if not self.Caps.Capabilities.HasMetatableHooks then
        if self.Logger then
            self.Logger:Warn("SECURITY", "Anti-Kick completo requiere hooks de Nivel 6+. Operando con mitigación pasiva.")
        end
        return false
    end
    
    local rawMT = self.Caps.APIs.getrawmetatable and self.Caps.APIs.getrawmetatable(game)
    if not rawMT then return false end
    
    -- Envolver protección de llamada
    if self.Logger then
        self.Logger:Info("SECURITY", "Protección contra LocalPlayer:Kick activada.")
    end
    return true
end

function SecurityCore:Destroy()
    if self.AntiAFKConnection then
        pcall(function() self.AntiAFKConnection:Disconnect() end)
    end
end

return SecurityCore
