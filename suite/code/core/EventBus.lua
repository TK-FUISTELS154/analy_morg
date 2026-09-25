--[[
    =============================================================================
    APEX SUITE - EVENT BUS (PUB/SUB DECOUPLING)
    =============================================================================
    Permite comunicación reactiva y desacoplada entre motores de análisis y UI.
--]]

local EventBus = {}
EventBus.__index = EventBus
EventBus.ClassName = "EventBus"

function EventBus.new()
    local self = setmetatable({}, EventBus)
    self._listeners = {}
    return self
end

function EventBus:Subscribe(eventName, callback)
    if not self._listeners[eventName] then
        self._listeners[eventName] = {}
    end
    
    local listenerId = tostring(math.random(100000, 999999)) .. "_" .. tostring(tick())
    self._listeners[eventName][listenerId] = callback
    
    local unsubscribed = false
    return {
        Disconnect = function()
            if unsubscribed then return end
            unsubscribed = true
            if self._listeners[eventName] then
                self._listeners[eventName][listenerId] = nil
            end
        end
    }
end

function EventBus:Publish(eventName, ...)
    local list = self._listeners[eventName]
    if not list then return end
    
    for _, callback in pairs(list) do
        task.spawn(function(...)
            pcall(callback, ...)
        end, ...)
    end
end

function EventBus:Clear()
    table.clear(self._listeners)
end

return EventBus
