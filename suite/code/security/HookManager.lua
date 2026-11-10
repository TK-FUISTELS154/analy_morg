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
    self.ProtectedInstances = setmetatable({}, { __mode = "k" })
    self.ProtectedNames = {}
    self.IsHooked = false
    self.OriginalNamecall = nil
    self.OriginalIndex = nil
    
    return self
end

function HookManager:RegisterProtectedInstance(instance, name)
    if instance then
        self.ProtectedInstances[instance] = true
    end
    if name and type(name) == "string" then
        self.ProtectedNames[name] = true
    end
end

function HookManager:BlockRemote(remoteName)
    self.BlockedRemotes[remoteName:lower()] = true
    if not self.IsHooked then
        self:InstallHooks()
    end
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
    local hasHooks = self.Caps and self.Caps.Capabilities and self.Caps.Capabilities.HasMetatableHooks
    if not hasHooks then
        if self.Logger then
            self.Logger:Debug("HOOKS", "Metatable hooks no disponibles en este nivel de ejecutor (Nivel pasivo 3-4).")
        end
        return false
    end
    
    if self.IsHooked then return true end
    
    local checkcaller = (self.Caps and self.Caps.APIs and self.Caps.APIs.checkcaller) or (type(checkcaller) == "function" and checkcaller) or function() return false end
    local hookmetamethod = (self.Caps and self.Caps.APIs and self.Caps.APIs.hookmetamethod) or (type(hookmetamethod) == "function" and hookmetamethod)
    local newcclosure = (self.Caps and self.Caps.APIs and self.Caps.APIs.newcclosure) or (type(newcclosure) == "function" and newcclosure) or function(f) return f end
    
    if hookmetamethod then
        -- 1. Hook Maestro __namecall con filtrado de sigilo para colecciones
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(selfObj, ...)
            local method = getnamecallmethod()
            local args = {...}
            local isExploitThread = checkcaller()
            
            -- Detectar si es un Remote disparado
            if method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer" then
                local remoteName = tostring(selfObj)
                local lowerName = remoteName:lower()
                
                -- Notificar a oyentes de análisis
                for _, listener in ipairs(self.RemoteListeners) do
                    task.spawn(listener, selfObj, method, args, isExploitThread)
                end
                
                -- Verificar bloqueo
                if self.BlockedRemotes[lowerName] then
                    return nil
                end
            end
            
            -- Sigilo de GUI: Ocultar instancias protegidas y todos sus descendientes de scripts del juego
            if not isExploitThread then
                if method == "GetDescendants" or method == "GetChildren" then
                    local res = oldNamecall(selfObj, ...)
                    if type(res) == "table" then
                        local clean = {}
                        for _, v in ipairs(res) do
                            local isProtected = false
                            if self.ProtectedInstances[v] or (v and self.ProtectedNames[v.Name]) then
                                isProtected = true
                            else
                                for pInst in pairs(self.ProtectedInstances) do
                                    local s, isDesc = pcall(function() return v:IsDescendantOf(pInst) end)
                                    if s and isDesc then
                                        isProtected = true
                                        break
                                    end
                                end
                            end
                            if not isProtected then
                                table.insert(clean, v)
                            end
                        end
                        return clean
                    end
                    return res
                elseif method == "FindFirstChild" or method == "WaitForChild" then
                    local searchName = args[1]
                    if searchName and type(searchName) == "string" and self.ProtectedNames[searchName] then
                        return nil
                    end
                elseif method == "FindFirstChildOfClass" or method == "FindFirstChildWhichIsA" then
                    local res = oldNamecall(selfObj, ...)
                    if res then
                        local isProtected = false
                        if self.ProtectedInstances[res] or (res and self.ProtectedNames[res.Name]) then
                            isProtected = true
                        else
                            for pInst in pairs(self.ProtectedInstances) do
                                local s, isDesc = pcall(function() return res:IsDescendantOf(pInst) end)
                                if s and isDesc then isProtected = true; break end
                            end
                        end
                        if isProtected then
                            return nil
                        end
                    end
                    return res
                end
            end
            
            return oldNamecall(selfObj, ...)
        end))
        
        self.OriginalNamecall = oldNamecall

        -- 2. Hook Maestro __index para búsquedas de tipo Parent["NombreDeGui"]
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", newcclosure(function(selfObj, key)
                if not checkcaller() and type(key) == "string" and self.ProtectedNames[key] then
                    return nil
                end
                return oldIndex(selfObj, key)
            end))
            self.OriginalIndex = oldIndex
        end)

        self.IsHooked = true
        
        if self.Logger then
            self.Logger:Info("HOOKS", "Hooks maestros de sigilo instalados (__namecall y __index).")
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
