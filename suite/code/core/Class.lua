--[[
    =============================================================================
    APEX SUITE - OOP CLASS SYSTEM
    =============================================================================
    Provee herencia simple, constructores, destructores y señales internas.
--]]

local Class = {}
Class.__index = Class
Class.ClassName = "Class"

function Class:Extend(subclassName)
    local subclass = {}
    subclass.__index = subclass
    subclass.ClassName = subclassName or "AnonymousSubclass"
    subclass.Super = self
    
    setmetatable(subclass, {
        __index = self,
        __tostring = function(cls)
            return "Class(" .. cls.ClassName .. ")"
        end
    })
    
    return subclass
end

function Class.new(...)
    local instance = setmetatable({}, Class)
    instance._connections = {}
    instance._isDestroyed = false
    instance:Init(...)
    return instance
end

function Class:Init(...)
    -- Sobrescribir en subclases
end

function Class:IsA(className)
    local current = getmetatable(self)
    while current do
        if current.ClassName == className then
            return true
        end
        current = current.Super
    end
    return false
end

function Class:AddConnection(connection)
    if not self._connections then
        self._connections = {}
    end
    table.insert(self._connections, connection)
    return connection
end

function Class:Destroy()
    if self._isDestroyed then return end
    self._isDestroyed = true
    
    if self._connections then
        for _, conn in ipairs(self._connections) do
            if typeof(conn) == "RBXScriptConnection" then
                pcall(function() conn:Disconnect() end)
            elseif type(conn) == "table" and type(conn.Disconnect) == "function" then
                pcall(function() conn:Disconnect() end)
            elseif type(conn) == "function" then
                pcall(conn)
            end
        end
        table.clear(self._connections)
    end
    
    table.clear(self)
end

return Class
