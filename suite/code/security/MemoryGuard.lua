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
    self.CallCount = 0
    self.MaxCallsPerSecond = 5
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
    
    -- Control de ráfagas con micro-espera aleatoria (jitter) anti-heurística
    self.CallCount = self.CallCount + 1
    if (now - self.LastGCTime) < self.MinGCDelay or self.CallCount > self.MaxCallsPerSecond then
        task.wait(math.random(40, 100) / 1000)
        self.CallCount = 0
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

function MemoryGuard:FindTable(expectedKeys)
    local gc = self:GetSafeGC()
    local results = {}
    for _, obj in ipairs(gc) do
        if type(obj) == "table" then
            local matchCount = 0
            for _, key in ipairs(expectedKeys) do
                if rawget(obj, key) ~= nil then matchCount = matchCount + 1 end
            end
            if matchCount == #expectedKeys then table.insert(results, obj) end
        end
    end
    return results
end

function MemoryGuard:FindFunction(targetName)
    local gc = self:GetSafeGC()
    for _, obj in ipairs(gc) do
        if type(obj) == "function" then
            local info = debug.getinfo(obj)
            if info and info.name == targetName then return obj end
        end
    end
    return nil
end

return MemoryGuard
