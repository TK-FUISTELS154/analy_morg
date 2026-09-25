--[[
    =============================================================================
    APEX SUITE - ADVANCED REMOTE ANALYZER (PROFILER, RECURSIVE SERIALIZER & RISK SCORER)
    =============================================================================
    Monitorea eventos remotos, desglosa argumentos complejos de forma recursiva (tablas,
    enums, vectores, CFrames, instancias), detecta el script emisor (Callstack),
    calcula nivel de riesgo y genera código ejecutable exacto.
--]]

local RemoteAnalyzer = {}
RemoteAnalyzer.__index = RemoteAnalyzer
RemoteAnalyzer.ClassName = "RemoteAnalyzer"

RemoteAnalyzer.RiskLevel = {
    CRITICAL = "CRITICAL", -- Seguridad, Reportes, Kicks, Bans, Auth
    HIGH     = "HIGH",     -- Combate, Daño, Monedas, Compras
    MEDIUM   = "MEDIUM",   -- Movimiento, Física, Estados
    LOW      = "LOW",      -- Cosméticos, Sonidos, Efectos
}

function RemoteAnalyzer.new(eventBus, logger)
    local self = setmetatable({}, RemoteAnalyzer)
    self.EventBus = eventBus
    self.Logger = logger
    self.Logs = {}
    self.FrequencyMap = {}
    self.IgnoredRemotes = {
        ["characteranims"] = true,
        ["sounddispatcher"] = true,
        ["pingserver"] = true,
        ["defaultchat"] = true,
    }
    self.IsActive = false
    self.SpamThreshold = 10
    return self
end

-- Serializador recursivo exhaustivo de tipos Luau para generar código reproducible
function RemoteAnalyzer:SerializeValue(val, depth)
    depth = depth or 0
    if depth > 5 then return "{ ... }" end -- Prevención de recursión infinita
    
    local t = typeof(val)
    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "Vector2" then
        return string.format("Vector2.new(%.3f, %.3f)", val.X, val.Y)
    elseif t == "CFrame" then
        local x, y, z = val.Position.X, val.Position.Y, val.Position.Z
        local rx, ry, rz = val:ToEulerAnglesXYZ()
        return string.format("CFrame.new(%.3f, %.3f, %.3f) * CFrame.Angles(%.3f, %.3f, %.3f)", x, y, z, rx, ry, rz)
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif t == "UDim2" then
        return string.format("UDim2.new(%.3f, %d, %.3f, %d)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
    elseif t == "EnumItem" then
        return tostring(val)
    elseif t == "Instance" then
        local s, fullName = pcall(function() return val:GetFullName() end)
        if s and fullName then
            return fullName
        else
            return string.format("game:FindFirstChild(%q, true)", val.Name)
        end
    elseif t == "table" then
        local isArray = (#val > 0)
        local parts = {}
        for k, v in pairs(val) do
            local valStr = self:SerializeValue(v, depth + 1)
            if isArray and type(k) == "number" then
                table.insert(parts, valStr)
            else
                local keyStr = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. self:SerializeValue(k, depth + 1) .. "]")
                table.insert(parts, string.format("%s = %s", keyStr, valStr))
            end
        end
        return "{\n  " .. table.concat(parts, ",\n  ") .. "\n}"
    else
        return string.format("%q", tostring(val))
    end
end

function RemoteAnalyzer:GenerateCodeSnippet(remoteObj, method, args)
    local s, path = pcall(function() return remoteObj:GetFullName() end)
    path = (s and path) or tostring(remoteObj)
    
    local serializedArgs = {}
    for _, arg in ipairs(args) do
        table.insert(serializedArgs, self:SerializeValue(arg, 0))
    end
    
    local argsFormatted = table.concat(serializedArgs, ", ")
    return string.format("%s:%s(%s)", path, method, argsFormatted)
end

function RemoteAnalyzer:AssessRiskLevel(remoteName, args)
    local lower = remoteName:lower()
    
    -- 1. Crítico
    if lower:find("ban") or lower:find("kick") or lower:find("detect") or lower:find("report") or lower:find("security") or lower:find("anticheat") or lower:find("integrity") or lower:find("check") then
        return RemoteAnalyzer.RiskLevel.CRITICAL
    end
    
    -- 2. Alto
    if lower:find("damage") or lower:find("buy") or lower:find("purchase") or lower:find("spin") or lower:find("gacha") or lower:find("reward") or lower:find("coin") or lower:find("gem") or lower:find("item") or lower:find("trade") then
        return RemoteAnalyzer.RiskLevel.HIGH
    end
    
    -- 3. Medio
    if lower:find("move") or lower:find("teleport") or lower:find("pos") or lower:find("state") or lower:find("ability") or lower:find("skill") or lower:find("cframe") then
        return RemoteAnalyzer.RiskLevel.MEDIUM
    end
    
    -- Chequeo heurístico por tipo de argumentos
    for _, arg in ipairs(args) do
        local t = typeof(arg)
        if t == "number" and arg > 1000 and (lower:find("add") or lower:find("set")) then
            return RemoteAnalyzer.RiskLevel.HIGH
        end
    end
    
    return RemoteAnalyzer.RiskLevel.LOW
end

function RemoteAnalyzer:ProcessRemoteCall(remoteObj, method, args, isScriptCaller)
    if not self.IsActive then return end
    
    local now = tick()
    local remoteName = tostring(remoteObj)
    local lowerName = remoteName:lower()
    
    -- Ignorar remotes ruidosos
    if self.IgnoredRemotes[lowerName] then return end
    
    -- Control Anti-Spam Adaptativo
    if not self.FrequencyMap[remoteName] then
        self.FrequencyMap[remoteName] = { Count = 1, LastTime = now }
    else
        local data = self.FrequencyMap[remoteName]
        if now - data.LastTime < 1.0 then
            data.Count = data.Count + 1
            if data.Count > self.SpamThreshold then
                return -- Suprimir spam
            end
        else
            data.Count = 1
            data.LastTime = now
        end
    end
    
    local snippet = self:GenerateCodeSnippet(remoteObj, method, args)
    local risk = self:AssessRiskLevel(remoteName, args)
    
    -- Intento de captura del emisor
    local callingScript = nil
    if typeof(getcallingscript) == "function" then
        pcall(function()
            local s = getcallingscript()
            if s then callingScript = s:GetFullName() end
        end)
    end
    
    local logEntry = {
        Timestamp = now,
        Remote = remoteObj,
        Name = remoteName,
        Path = pcall(function() return remoteObj:GetFullName() end) and remoteObj:GetFullName() or remoteName,
        Method = method,
        Args = args,
        ArgsCount = #args,
        Snippet = snippet,
        RiskLevel = risk,
        CallingScript = callingScript,
        IsScriptCaller = isScriptCaller,
    }
    
    table.insert(self.Logs, 1, logEntry)
    if #self.Logs > 300 then
        table.remove(self.Logs)
    end
    
    if self.Logger and risk == RemoteAnalyzer.RiskLevel.CRITICAL then
        self.Logger:Vuln("REMOTESPY", string.format("Remote de riesgo CRÍTICO interceptado: %s (%s)", remoteName, snippet))
    end
    
    if self.EventBus then
        self.EventBus:Publish("RemoteFired", logEntry)
    end
end

function RemoteAnalyzer:Start()
    self.IsActive = true
    if self.Logger then
        self.Logger:Info("REMOTESPY", "Remote Analyzer avanzado activado con serializador recursivo.")
    end
end

function RemoteAnalyzer:Stop()
    self.IsActive = false
    if self.Logger then
        self.Logger:Info("REMOTESPY", "Remote Analyzer pausado.")
    end
end

function RemoteAnalyzer:Clear()
    table.clear(self.Logs)
    table.clear(self.FrequencyMap)
end

function RemoteAnalyzer:SetIgnored(remoteName, shouldIgnore)
    self.IgnoredRemotes[remoteName:lower()] = (shouldIgnore == true) or nil
end

return RemoteAnalyzer
