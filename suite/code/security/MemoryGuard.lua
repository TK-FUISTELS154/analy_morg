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
    if not self.Caps.Capabilities.HasGCInspection then
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
    local success, result = pcall(function()
        return self.Caps.APIs.getgc(true)
    end)
    
    if success and type(result) == "table" then
        self.CachedGC = result
        self.LastCacheTime = tick()
        return result
    end
    
    return {}
end

return MemoryGuard
