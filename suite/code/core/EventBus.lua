--[[
    =============================================================================
    APEX SUITE - EVENT BUS v2.0 (SYNCHRONOUS-FIRST + PRIORITY DISPATCH)
    =============================================================================
    Pub/Sub optimizado:
    1. Callbacks livianos se ejecutan síncronamente (evita sobrecoste de task.spawn)
    2. Callbacks pesados (marcados con _heavy = true) se despachan con task.spawn
    3. Prioridades opcionales: callbacks con Priority más alto se ejecutan primero
    4. Dead-letter: callbacks que fallan 3 veces se desconectan automáticamente
--]]

local EventBus = {}
EventBus.__index = EventBus
EventBus.ClassName = "EventBus"

local MAX_FAILURES = 3

function EventBus.new()
    local self = setmetatable({}, EventBus)
    self._listeners = {}
    self._listenerMeta = {} -- listenerId → { failures, heavy, priority }
    return self
end

function EventBus:Subscribe(eventName, callback, options)
    if not self._listeners[eventName] then
        self._listeners[eventName] = {}
    end

    options = options or {}
    local listenerId = tostring(math.random(100000, 999999)) .. "_" .. tostring(tick())
    self._listeners[eventName][listenerId] = callback
    self._listenerMeta[listenerId] = {
        Failures = 0,
        Heavy = options.Heavy or false,
        Priority = options.Priority or 0,
    }

    local unsubscribed = false
    return {
        Disconnect = function()
            if unsubscribed then return end
            unsubscribed = true
            if self._listeners[eventName] then
                self._listeners[eventName][listenerId] = nil
            end
            self._listenerMeta[listenerId] = nil
        end
    }
end

function EventBus:Publish(eventName, ...)
    local list = self._listeners[eventName]
    if not list then return end

    -- Recopilar y ordenar por prioridad (más alto primero)
    local sortedCallbacks = {}
    for id, callback in pairs(list) do
        local meta = self._listenerMeta[id]
        table.insert(sortedCallbacks, { Id = id, Fn = callback, Meta = meta or {} })
    end

    if #sortedCallbacks > 1 then
        table.sort(sortedCallbacks, function(a, b)
            return (a.Meta.Priority or 0) > (b.Meta.Priority or 0)
        end)
    end

    -- Despacho inteligente: síncrono para livianos, task.spawn para pesados
    local args = table.pack(...)
    for _, entry in ipairs(sortedCallbacks) do
        local meta = entry.Meta

        if meta.Heavy then
            -- Despacho asíncrono para callbacks marcados como pesados
            task.spawn(function()
                local ok, err = pcall(entry.Fn, table.unpack(args, 1, args.n))
                if not ok then
                    meta.Failures = (meta.Failures or 0) + 1
                    if meta.Failures >= MAX_FAILURES then
                        -- Auto-desconectar callback defectuoso
                        if self._listeners[eventName] then
                            self._listeners[eventName][entry.Id] = nil
                        end
                        self._listenerMeta[entry.Id] = nil
                    end
                end
            end)
        else
            -- Despacho síncrono directo (sin overhead de scheduler)
            local ok, err = pcall(entry.Fn, table.unpack(args, 1, args.n))
            if not ok then
                meta.Failures = (meta.Failures or 0) + 1
                if meta.Failures >= MAX_FAILURES then
                    if self._listeners[eventName] then
                        self._listeners[eventName][entry.Id] = nil
                    end
                    self._listenerMeta[entry.Id] = nil
                end
            end
        end
    end
end

-- PublishAsync: Fuerza despacho asíncrono de TODOS los callbacks (útil para eventos de UI pesados)
function EventBus:PublishAsync(eventName, ...)
    local list = self._listeners[eventName]
    if not list then return end

    local args = table.pack(...)
    for id, callback in pairs(list) do
        task.spawn(function()
            pcall(callback, table.unpack(args, 1, args.n))
        end)
    end
end

function EventBus:GetListenerCount(eventName)
    local list = self._listeners[eventName]
    if not list then return 0 end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    return count
end

function EventBus:Clear()
    table.clear(self._listeners)
    table.clear(self._listenerMeta)
end

return EventBus
