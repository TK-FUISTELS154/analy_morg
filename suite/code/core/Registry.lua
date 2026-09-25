--[[
    =============================================================================
    APEX SUITE - SERVICE REGISTRY (DEPENDENCY INJECTION / SERVICE LOCATOR)
    =============================================================================
    Permite registrar y obtener servicios del sistema de manera centralizada.
--]]

local Registry = {}
Registry.__index = Registry
Registry.ClassName = "Registry"

function Registry.new()
    local self = setmetatable({}, Registry)
    self._services = {}
    return self
end

function Registry:Register(name, serviceInstance)
    self._services[name] = serviceInstance
    return serviceInstance
end

function Registry:Get(name)
    return self._services[name]
end

function Registry:Remove(name)
    local service = self._services[name]
    if service and type(service.Destroy) == "function" then
        pcall(function() service:Destroy() end)
    end
    self._services[name] = nil
end

function Registry:Destroy()
    for name, service in pairs(self._services) do
        if service and type(service.Destroy) == "function" then
            pcall(function() service:Destroy() end)
        end
    end
    table.clear(self._services)
end

return Registry
