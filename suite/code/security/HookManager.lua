--[[
    =============================================================================
    APEX SUITE - HOOK MANAGER (METAMETHOD & FUNCTION HOOKING WITH SPOOFING)
    =============================================================================
    Gestiona hooks a __namecall, __index, __newindex y funciones con spoofing
    de callstack y chequeo de emisor (checkcaller).
--]]

local HookManager = {}
HookManager.__index = HookManager
HookManager.ClassName = "HookManager"

function HookManager.new(capabilityManager, logger)
    local self = setmetatable({}, HookManager)
    self.Caps = capabilityManager
    self.Logger = logger
    self.BlockedRemotes = {}
    self.RemoteListeners = {}
    self.IsHooked = false
    self.OriginalNamecall = nil
    self.OriginalIndex = nil
    
    return self
end

function HookManager:BlockRemote(remoteName)
    self.BlockedRemotes[remoteName:lower()] = true
    if self.Logger then
        self.Logger:Info("HOOKS", "Remote bloqueado: " .. remoteName)
    end
end

function HookManager:UnblockRemote(remoteName)
    self.BlockedRemotes[remoteName:lower()] = nil
end

function HookManager:AddRemoteListener(callback)
    table.insert(self.RemoteListeners, callback)
end

function HookManager:InstallHooks()
    if not self.Caps.Capabilities.HasMetatableHooks then
        if self.Logger then
            self.Logger:Warn("HOOKS", "Metatable hooks no disponibles en este nivel de ejecutor (Requiere Nivel 6+).")
        end
        return false
    end
    
    if self.IsHooked then return true end
    
    local checkcaller = self.Caps.APIs.checkcaller
    local hookmetamethod = self.Caps.APIs.hookmetamethod
    local newcclosure = self.Caps.APIs.newcclosure
    
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(selfObj, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Detectar si es un Remote disparado
            if method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer" then
                local remoteName = tostring(selfObj)
                local lowerName = remoteName:lower()
                
                -- Notificar a oyentes de análisis
                for _, listener in ipairs(self.RemoteListeners) do
                    task.spawn(listener, selfObj, method, args, checkcaller())
                end
                
                -- Verificar bloqueo
                if self.BlockedRemotes[lowerName] then
                    return nil
                end
            end
            
            return oldNamecall(selfObj, ...)
        end))
        
        self.OriginalNamecall = oldNamecall
        self.IsHooked = true
        
        if self.Logger then
            self.Logger:Info("HOOKS", "Metamétodo __namecall interceptado con éxito.")
        end
        return true
    end
    
    return false
end

function HookManager:Destroy()
    self.BlockedRemotes = {}
    self.RemoteListeners = {}
end

return HookManager
