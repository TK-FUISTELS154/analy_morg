--[[
    =============================================================================
    APEX SUITE - ADVANCED REMOTE ANALYZER (LAZY SERIALIZER, SCHEMA PROFILING & CALLSITE AUDIT)
    =============================================================================
    Monitorea eventos remotos con serialización perezosa (lazy evaluation) para
    cero impacto en FPS, limpieza automática de frecuencias por ventana deslizante,
    perfilado automático de esquemas/firmas de tipos y auditoría profunda del entorno
    del script invocador (Callsite Auditor).
--]]

local RemoteAnalyzer = {}
RemoteAnalyzer.__index = RemoteAnalyzer
RemoteAnalyzer.ClassName = "RemoteAnalyzer"

RemoteAnalyzer.RiskLevel = {
    CRITICAL = "CRITICAL", -- Seguridad, Reportes, Kicks, Bans, Auth, Validación de Precios
    HIGH     = "HIGH",     -- Combate, Daño, Monedas, Compras, Rebirths
    MEDIUM   = "MEDIUM",   -- Movimiento, Física, Estados
    LOW      = "LOW",      -- Cosméticos, Sonidos, Efectos
}

function RemoteAnalyzer.new(eventBus, logger, heuristicEngine)
    local self = setmetatable({}, RemoteAnalyzer)
    self.EventBus = eventBus
    self.Logger = logger
    self.Heuristic = heuristicEngine
    self.Logs = {}
    self.FrequencyMap = {}
    self.SchemaProfiles = {} -- [remoteName] = { Signatures = {}, CallCount = 0, HasVulnerabilities = false }
    self.IgnoredRemotes = {
        ["characteranims"] = true,
        ["sounddispatcher"] = true,
        ["pingserver"] = true,
        ["defaultchat"] = true,
    }
    self.IsActive = false
    self.SpamThreshold = 10
    self.LastCleanupTime = tick()
    return self
end

function RemoteAnalyzer:SetHeuristicEngine(heuristicEngine)
    self.Heuristic = heuristicEngine
end

function RemoteAnalyzer:GetStaticCallers(remoteName)
    if self.Heuristic and self.Heuristic.CrossReferenceMatrix then
        local matrix = self.Heuristic.CrossReferenceMatrix.RemotesToCallers
        if matrix and matrix[remoteName] then
            return matrix[remoteName]
        end
    end
    return nil
end

-- =========================================================================
-- SERIALIZACIÓN PEREZOSA (ON-DEMAND RECURSIVE SERIALIZER)
-- =========================================================================
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
    for _, arg in ipairs(args or {}) do
        table.insert(serializedArgs, self:SerializeValue(arg, 0))
    end
    
    local argsFormatted = table.concat(serializedArgs, ", ")
    return string.format("%s:%s(%s)", path, method or "FireServer", argsFormatted)
end

-- =========================================================================
-- PERFILADOR AUTOMÁTICO DE ESQUEMAS DE RED (SCHEMA PROFILING)
-- =========================================================================
function RemoteAnalyzer:InferTypeSignature(args)
    local types = {}
    for _, arg in ipairs(args or {}) do
        local t = typeof(arg)
        if t == "table" then
            local isArray = (#arg > 0)
            table.insert(types, isArray and "Array" or "Dictionary")
        else
            table.insert(types, t)
        end
    end
    return "(" .. table.concat(types, ", ") .. ")"
end

function RemoteAnalyzer:UpdateSchemaProfile(remoteName, signature, args)
    local profile = self.SchemaProfiles[remoteName]
    if not profile then
        profile = {
            Signatures = {},
            CallCount = 0,
            HasVariadicSignature = false,
            SuspiciousClientArgs = false,
        }
        self.SchemaProfiles[remoteName] = profile
    end
    
    profile.CallCount = profile.CallCount + 1
    profile.Signatures[signature] = (profile.Signatures[signature] or 0) + 1
    
    local distinctSigs = 0
    for _ in pairs(profile.Signatures) do distinctSigs = distinctSigs + 1 end
    if distinctSigs > 3 then
        profile.HasVariadicSignature = true
    end
    
    -- Detectar si se reciben tablas vacías o parámetros no fuertemente tipados
    for _, arg in ipairs(args or {}) do
        if typeof(arg) == "number" and arg < 0 and (remoteName:lower():find("buy") or remoteName:lower():find("cost")) then
            profile.SuspiciousClientArgs = true
        end
    end
end

-- =========================================================================
-- INSPECCIÓN PROFUNDA DEL RASTREO DE ORIGEN (CALLSITE AUDITOR)
-- =========================================================================
-- INSPECCIÓN PROFUNDA DEL RASTREO DE ORIGEN (CALLSITE AUDITOR)
-- =========================================================================
function RemoteAnalyzer:AuditCallsite()
    local callsite = {
        ScriptPath = nil,
        ScriptName = "Unknown",
        ScriptInstance = nil,
        IsLegitimate = true,
        OriginType = "GameScript", -- "GameScript", "RobloxCore", "InjectedThread"
        ClosureEnvironment = "Normal",
    }
    
    if typeof(getcallingscript) == "function" then
        local s, scriptObj = pcall(getcallingscript)
        if s and scriptObj then
            local sPath, full = pcall(function() return scriptObj:GetFullName() end)
            callsite.ScriptInstance = scriptObj
            callsite.ScriptPath = (sPath and full) or scriptObj.Name
            callsite.ScriptName = scriptObj.Name
            
            if callsite.ScriptPath:find("RobloxGui") or callsite.ScriptPath:find("CorePackages") then
                callsite.OriginType = "RobloxCore"
            end
        else
            -- Si getcallingscript retorna nil en una llamada interceptada, proviene de un hilo inyectado
            callsite.IsLegitimate = false
            callsite.OriginType = "InjectedThread"
            callsite.ScriptName = "[Injected / Anonymous Thread]"
        end
    end
    
    return callsite
end

-- =========================================================================
-- EVALUACIÓN DE RIESGO (CON LÍMITES LÉXICOS Y SUPRESIÓN DE FALSOS POSITIVOS)
-- =========================================================================
function RemoteAnalyzer:AssessRiskLevel(remoteName, args, callsite)
    local lower = remoteName:lower()
    
    -- 1. Crítico
    if lower:find("ban") or lower:find("kick") or lower:find("detect") or lower:find("report") or lower:find("security") or lower:find("anticheat") or lower:find("integrity") or lower:find("check") or lower:find("crash") then
        return RemoteAnalyzer.RiskLevel.CRITICAL
    end
    
    -- 2. Alto
    if lower:find("damage") or lower:find("buy") or lower:find("purchase") or lower:find("spin") or lower:find("gacha") or lower:find("reward") or lower:find("coin") or lower:find("gem") or lower:find("item") or lower:find("trade") or lower:find("rebirth") then
        return RemoteAnalyzer.RiskLevel.HIGH
    end
    
    -- 3. Medio (Fronteras léxicas para "move": descarta "remove", "unmove", "clear")
    local isMove = false
    if not lower:find("remove") and not lower:find("unmove") and not lower:find("clear") then
        if lower:match("%f[%a]move%f[%A]") or lower:find("movement") then
            isMove = true
        end
    end

    if isMove or lower:find("teleport") or lower:find("pos") or lower:find("state") or lower:find("ability") or lower:find("skill") or lower:find("cframe") or lower:find("hit") then
        return RemoteAnalyzer.RiskLevel.MEDIUM
    end
    
    -- Chequeo heurístico por tipo de argumentos
    for _, arg in ipairs(args or {}) do
        local t = typeof(arg)
        if t == "number" and arg > 1000 and (lower:find("add") or lower:find("set") or lower:find("give")) then
            return RemoteAnalyzer.RiskLevel.HIGH
        end
    end
    
    return RemoteAnalyzer.RiskLevel.LOW
end

-- =========================================================================
-- PROCESAMIENTO DE LLAMADAS REMOTAS CON EVALUACIÓN PEREZOSA
-- =========================================================================
function RemoteAnalyzer:ProcessRemoteCall(remoteObj, method, args, isScriptCaller)
    if not self.IsActive then return end
    
    local now = tick()
    local remoteName = tostring(remoteObj)
    local lowerName = remoteName:lower()
    
    -- Ignorar remotes ruidosos
    if self.IgnoredRemotes[lowerName] then return end
    
    -- Control Anti-Spam Adaptativo y Limpieza por Ventana Deslizante (5 segundos)
    if now - self.LastCleanupTime > 5.0 then
        self.LastCleanupTime = now
        for rName, fData in pairs(self.FrequencyMap) do
            if now - fData.LastTime > 5.0 then
                self.FrequencyMap[rName] = nil
            end
        end
    end
    
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
    
    -- Auditoría del invocador y esquema de tipos
    local callsite = self:AuditCallsite()
    local signature = self:InferTypeSignature(args)
    self:UpdateSchemaProfile(remoteName, signature, args)
    
    local risk = self:AssessRiskLevel(remoteName, args, callsite)
    
    -- Estructura de registro liviana (args como referencia nativa pura, snippet generado bajo demanda)
    local logEntry = {
        Timestamp = now,
        Remote = remoteObj,
        Name = remoteName,
        Path = pcall(function() return remoteObj:GetFullName() end) and remoteObj:GetFullName() or remoteName,
        Method = method or "FireServer",
        Args = args,
        ArgsCount = #(args or {}),
        TypeSignature = signature,
        RiskLevel = risk,
        Callsite = callsite,
        CallingScript = callsite.ScriptPath,
        StaticCallers = self:GetStaticCallers(remoteName),
        IsScriptCaller = isScriptCaller,
        _cachedSnippet = nil,
    }
    
    -- Metatabla para generación perezosa de Snippet
    setmetatable(logEntry, {
        __index = function(tbl, key)
            if key == "Snippet" then
                if not tbl._cachedSnippet then
                    tbl._cachedSnippet = self:GenerateCodeSnippet(tbl.Remote, tbl.Method, tbl.Args)
                end
                return tbl._cachedSnippet
            end
            return rawget(tbl, key)
        end
    })
    
    table.insert(self.Logs, 1, logEntry)
    if #self.Logs > 300 then
        table.remove(self.Logs)
    end
    
    -- Inyección dinámica de sospechosos de alto riesgo hacia el RuntimeSuspectRegistry
    local caps = self.Caps or (self.Heuristic and self.Heuristic.Caps)
    if caps and (risk == RemoteAnalyzer.RiskLevel.CRITICAL or risk == RemoteAnalyzer.RiskLevel.HIGH) then
        local targetInst = callsite.ScriptInstance or remoteObj
        caps:RegisterSuspect(targetInst, "ActiveRemoteCaller", (risk == RemoteAnalyzer.RiskLevel.CRITICAL) and 100 or 85, {
            RemotePath = logEntry.Path,
            Method = logEntry.Method,
            RiskLevel = risk,
            CallingScript = callsite.ScriptPath,
            Signature = signature,
        })
    end

    if self.Logger and risk == RemoteAnalyzer.RiskLevel.CRITICAL then
        self.Logger:Vuln("REMOTESPY", string.format("Remote de riesgo CRÍTICO interceptado: %s (%s)", remoteName, signature))
    end
    
    if self.EventBus then
        self.EventBus:Publish("RemoteFired", logEntry)
    end
end

function RemoteAnalyzer:GetHighRiskCallers()
    local callers = {}
    local seen = {}
    for _, log in ipairs(self.Logs) do
        if (log.RiskLevel == RemoteAnalyzer.RiskLevel.CRITICAL or log.RiskLevel == RemoteAnalyzer.RiskLevel.HIGH) and log.CallingScript then
            if not seen[log.CallingScript] then
                seen[log.CallingScript] = true
                table.insert(callers, {
                    Path = log.CallingScript,
                    RemoteName = log.Name,
                    RemotePath = log.Path,
                    RiskLevel = log.RiskLevel,
                    Method = log.Method,
                    TypeSignature = log.TypeSignature,
                    Score = (log.RiskLevel == RemoteAnalyzer.RiskLevel.CRITICAL) and 100 or 85,
                })
            end
        end
    end
    return callers
end

function RemoteAnalyzer:Start()
    self.IsActive = true
    if self.Logger then
        self.Logger:Info("REMOTESPY", "Remote Analyzer avanzado activado (Lazy Serializer & Schema Profiler).")
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
    table.clear(self.SchemaProfiles)
end

function RemoteAnalyzer:SetIgnored(remoteName, shouldIgnore)
    self.IgnoredRemotes[remoteName:lower()] = (shouldIgnore == true) or nil
end

return RemoteAnalyzer
