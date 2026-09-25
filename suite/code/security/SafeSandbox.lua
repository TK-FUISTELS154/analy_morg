--[[
    =============================================================================
    APEX SUITE - SAFE SANDBOX
    =============================================================================
    Aislamiento de hilos y ejecución protegida para evitar logs de error en F9.
--]]

local SafeSandbox = {}
SafeSandbox.__index = SafeSandbox
SafeSandbox.ClassName = "SafeSandbox"

function SafeSandbox.new(logger)
    local self = setmetatable({}, SafeSandbox)
    self.Logger = logger
    return self
end

function SafeSandbox:Spawn(threadName, callback, ...)
    local args = {...}
    task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(args))
        end)
        
        if not success and self.Logger then
            self.Logger:Error("SANDBOX", string.format("Error aislado en hilo '%s': %s", tostring(threadName), tostring(err)))
        end
    end)
end

function SafeSandbox:Call(callback, ...)
    local success, result = pcall(callback, ...)
    if not success and self.Logger then
        self.Logger:Debug("SANDBOX", "Fallo seguro capturado: " .. tostring(result))
    end
    return success, result
end

return SafeSandbox
