--[[
    =============================================================================
    APEX SUITE - MEMORY GUARD & SAFE GC WRAPPER
    =============================================================================
    Limita la frecuencia de escaneo de memoria (getgc, getinstances)
    para evitar memory spikes y detección de anti-cheats basados en tiempo.
--]]

local MemoryGuard = {}
MemoryGuard.__index = MemoryGuard
MemoryGuard.ClassName = "MemoryGuard"

function MemoryGuard.new(capabilityManager, logger)
    local self = setmetatable({}, MemoryGuard)
    self.Caps = capabilityManager
    self.Logger = logger
    self.LastGCTime = 0
    self.MinGCDelay = 1.0 -- Mínimo 1 segundo entre escaneos de GC
    self.CachedGC = nil
    self.LastCacheTime = 0
    return self
end

function MemoryGuard:GetSafeGC(forceRefresh)
    local hasGC = self.Caps and self.Caps.Capabilities and self.Caps.Capabilities.HasGCInspection
    if not hasGC then
        return {}
    end
    
    local now = tick()
    if not forceRefresh and self.CachedGC and (now - self.LastCacheTime < 3.0) then
        return self.CachedGC
    end
    
    if (now - self.LastGCTime) < self.MinGCDelay then
        task.wait(self.MinGCDelay - (now - self.LastGCTime))
    end
    
    self.LastGCTime = tick()
    local getgcFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.getgc) or (type(getgc) == "function" and getgc)
    if not getgcFunc then return {} end
    
    local success, result = pcall(function()
        return getgcFunc(true)
    end)
    
    if success and type(result) == "table" then
        self.CachedGC = result
        self.LastCacheTime = tick()
        return result
    end
    
    return {}
end

return MemoryGuard
