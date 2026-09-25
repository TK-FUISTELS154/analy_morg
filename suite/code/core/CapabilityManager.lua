--[[
    =============================================================================
    APEX SUITE - CAPABILITY MANAGER v3.0
    (SHARED MEMORY STORE + TIMEOUT DECOMPILER + ENVIRONMENT GUARD)
    =============================================================================
    Único dueño centralizado de:
      1. Caché global de código descompilado (Weak-Key Table)
      2. Caché global de rutas jerárquicas (Instance → FullName)
      3. Descompilación con timeout de 200ms (previene bloqueo por ofuscadores)
      4. Resolución multi-motor de APIs (Synapse, Fluxus, Delta, KRNL, Wave, Solara)
      5. ArmEnvironmentGuard: Intercepta debug.info, getfenv y checkcaller para
         proteger la suite de trampas de introspección del anti-cheat del juego.
--]]

local Class = (getgenv and getgenv()._APEX_IMPORT and getgenv()._APEX_IMPORT("code/core/Class.lua"))
    or (typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("suite/code/core/Class.lua") and loadstring(readfile("suite/code/core/Class.lua"))())
    or (pcall(function() return game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/code/core/Class.lua") end) and loadstring(game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/code/core/Class.lua"))())

if not Class then
    Class = {}
    Class.__index = Class
    Class.ClassName = "Class"
    function Class:Extend(name)
        local sub = {}
        sub.__index = sub
        sub.ClassName = name or "SubClass"
        setmetatable(sub, { __index = self })
        return sub
    end
    function Class.new(...)
        local inst = setmetatable({}, Class)
        inst:Init(...)
        return inst
    end
    function Class:Init() end
    function Class:Destroy() end
end

local CapabilityManager = Class:Extend("CapabilityManager")

-- =============================================================================
-- SHARED MEMORY STORE: Weak-Key Caches (único punto de verdad para toda la suite)
-- =============================================================================

function CapabilityManager:Init()
    -- Caché de código descompilado: Instance(key débil) → string|false
    self._decompCache = setmetatable({}, { __mode = "k" })
    -- Caché de rutas: Instance(key débil) → string (GetFullName cacheado)
    self._pathCache   = setmetatable({}, { __mode = "k" })
    -- Métricas de rendimiento del caché
    self._cacheStats  = { Hits = 0, Misses = 0, Timeouts = 0, Errors = 0 }
    -- Timeout de descompilación en segundos (200ms)
    self.DecompileTimeout = 0.2

    self.Capabilities = {
        Level = 3,
        Score = 0,
        HasFileSystem = false,
        HasDecompiler = false,
        HasBytecode = false,
        HasMetatableHooks = false,
        HasFunctionHooks = false,
        HasGCInspection = false,
        HasInstanceInspection = false,
        HasSecureGUI = false,
        HasClipboard = false,
        HasHttpRequest = false,
        HasThreadIdentity = false,
    }

    self.APIs = {}
    self._envGuardActive = false
    self:EvaluateCapabilities()
end

-- =============================================================================
-- DETECCIÓN DE CAPACIDADES (Multi-Motor: Synapse, Fluxus, Delta, KRNL, Wave, Solara)
-- =============================================================================

function CapabilityManager:EvaluateCapabilities()
    local caps = self.Capabilities
    local apis = self.APIs
    local score = 0

    -- 1. GUI Segura (gethui, cloneref, protectgui)
    apis.gethui = (type(gethui) == "function" and gethui) or nil
    apis.cloneref = (type(cloneref) == "function" and cloneref) or function(x) return x end
    apis.protectgui = (type(protectgui) == "function" and protectgui) or (type(protect_gui) == "function" and protect_gui) or nil
    caps.HasSecureGUI = (apis.gethui ~= nil or apis.protectgui ~= nil)
    if caps.HasSecureGUI then score = score + 10 end

    -- 2. Sistema de Archivos (writefile, readfile, makefolder)
    apis.readfile = (type(readfile) == "function" and readfile) or nil
    apis.writefile = (type(writefile) == "function" and writefile) or nil
    apis.isfile = (type(isfile) == "function" and isfile) or nil
    apis.isfolder = (type(isfolder) == "function" and isfolder) or nil
    apis.makefolder = (type(makefolder) == "function" and makefolder) or nil
    caps.HasFileSystem = (apis.writefile ~= nil and apis.readfile ~= nil)
    if caps.HasFileSystem then score = score + 15 end

    -- 3. Hooks y Metatablas (Nivel 6-8)
    apis.getrawmetatable = (type(getrawmetatable) == "function" and getrawmetatable) or nil
    apis.hookmetamethod = (type(hookmetamethod) == "function" and hookmetamethod) or nil
    apis.hookfunction = (type(hookfunction) == "function" and hookfunction) or (type(replaceclosure) == "function" and replaceclosure) or nil
    apis.newcclosure = (type(newcclosure) == "function" and newcclosure) or function(f) return f end
    apis.checkcaller = (type(checkcaller) == "function" and checkcaller) or function() return false end
    apis.getcallingscript = (type(getcallingscript) == "function" and getcallingscript) or nil

    caps.HasMetatableHooks = (apis.hookmetamethod ~= nil or (apis.getrawmetatable ~= nil and apis.hookfunction ~= nil))
    caps.HasFunctionHooks = (apis.hookfunction ~= nil)
    if caps.HasMetatableHooks then score = score + 25 end
    if caps.HasFunctionHooks then score = score + 15 end

    -- 4. Resolución Multi-Motor de Descompiladores (Synapse, Fluxus, Delta, Wave, Solara, Codex, Arceus)
    local decompilerFunc = nil
    if type(decompile) == "function" then
        decompilerFunc = decompile
    elseif getgenv and type(getgenv().decompile) == "function" then
        decompilerFunc = getgenv().decompile
    elseif getrenv and type(getrenv().decompile) == "function" then
        decompilerFunc = getrenv().decompile
    elseif type(getscriptsource) == "function" then
        decompilerFunc = getscriptsource
    elseif getgenv and type(getgenv().getscriptsource) == "function" then
        decompilerFunc = getgenv().getscriptsource
    elseif type(get_script_source) == "function" then
        decompilerFunc = get_script_source
    elseif type(syn) == "table" and type(syn.decompile) == "function" then
        decompilerFunc = syn.decompile
    elseif type(fluxus) == "table" and type(fluxus.decompile) == "function" then
        decompilerFunc = fluxus.decompile
    elseif type(delta) == "table" and type(delta.decompile) == "function" then
        decompilerFunc = delta.decompile
    end
    apis.decompile = decompilerFunc

    local bytecodeFunc = nil
    if type(getscriptbytecode) == "function" then
        bytecodeFunc = getscriptbytecode
    elseif getgenv and type(getgenv().getscriptbytecode) == "function" then
        bytecodeFunc = getgenv().getscriptbytecode
    elseif getrenv and type(getrenv().getscriptbytecode) == "function" then
        bytecodeFunc = getrenv().getscriptbytecode
    elseif type(get_script_bytecode) == "function" then
        bytecodeFunc = get_script_bytecode
    elseif getgenv and type(getgenv().get_script_bytecode) == "function" then
        bytecodeFunc = getgenv().get_script_bytecode
    elseif type(dumpstring) == "function" then
        bytecodeFunc = dumpstring
    elseif type(syn) == "table" and type(syn.getscriptbytecode) == "function" then
        bytecodeFunc = syn.getscriptbytecode
    end
    apis.getscriptbytecode = bytecodeFunc

    caps.HasDecompiler = (apis.decompile ~= nil)
    caps.HasBytecode = (apis.getscriptbytecode ~= nil)
    if caps.HasDecompiler then score = score + 20 end
    if caps.HasBytecode then score = score + 10 end

    -- 5. Inspección de Memoria (GC / Instancias Ocultas)
    apis.getgc = (type(getgc) == "function" and getgc) or (type(get_gc_objects) == "function" and get_gc_objects) or nil
    apis.getinstances = (type(getinstances) == "function" and getinstances) or (type(get_instances) == "function" and get_instances) or nil
    apis.getnilinstances = (type(getnilinstances) == "function" and getnilinstances) or (type(get_nil_instances) == "function" and get_nil_instances) or nil
    apis.getloadedmodules = (type(getloadedmodules) == "function" and getloadedmodules) or (type(get_loaded_modules) == "function" and get_loaded_modules) or nil

    caps.HasGCInspection = (apis.getgc ~= nil)
    caps.HasInstanceInspection = (apis.getinstances ~= nil or apis.getnilinstances ~= nil)
    if caps.HasGCInspection then score = score + 15 end
    if caps.HasInstanceInspection then score = score + 10 end

    -- 6. Portapapeles y Red
    apis.setclipboard = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard) or (type(set_clipboard) == "function" and set_clipboard) or nil
    apis.request = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn) == "table" and type(syn.request) == "function" and syn.request) or nil
    caps.HasClipboard = (apis.setclipboard ~= nil)
    caps.HasHttpRequest = (apis.request ~= nil)
    if caps.HasClipboard then score = score + 5 end
    if caps.HasHttpRequest then score = score + 10 end

    -- 7. Nivel Estimado
    local level = 3
    if caps.HasFileSystem and caps.HasSecureGUI then level = 5 end
    if caps.HasMetatableHooks and caps.HasFunctionHooks then level = 6 end
    if caps.HasDecompiler and caps.HasGCInspection and caps.HasInstanceInspection then level = 7 end
    if score >= 120 then level = 8 end

    caps.Level = level
    caps.Score = score
end

function CapabilityManager:GetLevel()
    return self.Capabilities.Level
end

function CapabilityManager:GetSummary()
    return string.format(
        "Nivel Detectado: %d (Score: %d/140) | FS: %s | Hooks: %s | Decompiler: %s | GC: %s | SecureGUI: %s",
        self.Capabilities.Level,
        self.Capabilities.Score,
        self.Capabilities.HasFileSystem and "SI" or "NO",
        self.Capabilities.HasMetatableHooks and "SI" or "NO",
        self.Capabilities.HasDecompiler and "SI" or "NO",
        self.Capabilities.HasGCInspection and "SI" or "NO",
        self.Capabilities.HasSecureGUI and "SI" or "NO"
    )
end

local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function pureBase64Encode(data)
    if not data or #data == 0 then return "" end
    local bytes = { string.byte(data, 1, #data) }
    local len = #bytes
    local out = {}

    for i = 1, len, 3 do
        local b1 = bytes[i]
        local b2 = bytes[i + 1]
        local b3 = bytes[i + 2]

        local n = bit32.lshift(b1, 16) + (b2 and bit32.lshift(b2, 8) or 0) + (b3 or 0)

        local c1 = bit32.band(bit32.rshift(n, 18), 63) + 1
        local c2 = bit32.band(bit32.rshift(n, 12), 63) + 1
        local c3 = bit32.band(bit32.rshift(n, 6), 63) + 1
        local c4 = bit32.band(n, 63) + 1

        table.insert(out, B64_CHARS:sub(c1, c1))
        table.insert(out, B64_CHARS:sub(c2, c2))
        table.insert(out, b2 and B64_CHARS:sub(c3, c3) or "=")
        table.insert(out, b3 and B64_CHARS:sub(c4, c4) or "=")
    end

    return table.concat(out)
end

local function encodeBase64(data)
    if not data or #data == 0 then return "" end
    if typeof(crypt) == "table" and type(crypt.base64encode) == "function" then
        local s, res = pcall(crypt.base64encode, data)
        if s and res and type(res) == "string" and #res > 0 then return res end
    end
    if type(base64_encode) == "function" then
        local s, res = pcall(base64_encode, data)
        if s and res and type(res) == "string" and #res > 0 then return res end
    end
    if typeof(syn) == "table" and typeof(syn.crypt) == "table" and type(syn.crypt.base64_encode) == "function" then
        local s, res = pcall(syn.crypt.base64_encode, data)
        if s and res and type(res) == "string" and #res > 0 then return res end
    end
    return pureBase64Encode(data)
end

local function extractBytecodeStrings(bytecode)
    local strings = {}
    local seen = {}
    if not bytecode or type(bytecode) ~= "string" then return strings end

    -- Escanear secuencias de caracteres imprimibles ASCII (strings literales en el bytecode)
    for str in bytecode:gmatch("[%w_/%-.:$#@!+*=%%&%[%]<>]+%s*") do
        local trimmed = str:match("^%s*(.-)%s*$")
        if trimmed and #trimmed >= 3 and #trimmed <= 100 and not seen[trimmed] then
            if not trimmed:match("^%d+$") then
                seen[trimmed] = true
                table.insert(strings, trimmed)
                if #strings >= 80 then break end
            end
        end
    end
    return strings
end

-- =============================================================================
-- SHARED MEMORY STORE: SafeDecompile (ÚNICO PUNTO DE DESCOMPILACIÓN)
-- =============================================================================
-- Todos los módulos (HeuristicEngine, SelectiveDumper, ActionRecorder) DEBEN
-- invocar este método en lugar de mantener cachés propios.

function CapabilityManager:SafeDecompile(scriptInstance)
    if not scriptInstance or not scriptInstance:IsA("LuaSourceContainer") then return nil end

    -- 1. Consultar caché primero (O(1) amortizado con tabla de claves débiles)
    local cached = self._decompCache[scriptInstance]
    if cached ~= nil then
        self._cacheStats.Hits = self._cacheStats.Hits + 1
        return cached ~= false and cached or nil
    end

    self._cacheStats.Misses = self._cacheStats.Misses + 1

    -- 2. Intento 1: Lectura directa de propiedad Source (Studio / Nivel 3+ / Scripts creados localmente)
    local sSrc, directSrc = pcall(function() return scriptInstance.Source end)
    if sSrc and type(directSrc) == "string" and #directSrc > 0 then
        self._decompCache[scriptInstance] = directSrc
        return directSrc
    end

    -- 3. Verificación de tipo de Script en Roblox:
    -- Los Scripts de servidor estándar (ServerScript / Script regular) NO tienen bytecode en la memoria
    -- del cliente en el protocolo de replicación de Roblox.
    -- Intentar llamar a getscriptbytecode() o decompile() sobre ellos genera:
    -- "Argument #1 is not a client script".
    local isClientScript = scriptInstance:IsA("LocalScript") or scriptInstance:IsA("ModuleScript")
    if not isClientScript then
        local msg = string.format("-- [Script de Servidor: %s]\n-- En Roblox, el bytecode y código fuente de Scripts de servidor no son replicados ni accesibles desde la memoria del cliente.", scriptInstance.ClassName)
        self._decompCache[scriptInstance] = msg
        return msg
    end

    -- 4. Intento 2: Descompilador C de alto nivel del ejecutor (Nivel 7+)
    local decompiler = self.APIs.decompile
    if decompiler then
        local success, code = pcall(decompiler, scriptInstance)
        if success and type(code) == "string" and #code > 0 then
            local lowerCode = code:lower()
            if not lowerCode:find("decompilation not supported")
               and not lowerCode:find("failed to decompile")
               and not lowerCode:find("not a client script")
               and not lowerCode:find("c%+%+ exception")
               and not (code == "-- [Código no disponible]") then
                self._decompCache[scriptInstance] = code
                return code
            end
        end
    end

    -- 5. Intento 3: Extracción de Bytecode Luau nativo (Nivel 5-6) + Análisis de Constantes
    local bytecodeGetter = self.APIs.getscriptbytecode
    if bytecodeGetter then
        local success, bc = pcall(bytecodeGetter, scriptInstance)
        if success and bc and type(bc) == "string" and #bc > 0 then
            local byteLen = #bc
            local luauVersion = string.byte(bc, 1) or 0
            local stringConstants = extractBytecodeStrings(bc)

            local constSection = ""
            if #stringConstants > 0 then
                local constList = {}
                for idx, c in ipairs(stringConstants) do
                    table.insert(constList, string.format("  [%d] %q", idx, c))
                end
                constSection = string.format("\n-- [CONSTANTES Y SÍMBOLOS DETECTADOS EN BYTECODE (%d)]:\n--%s\n", #stringConstants, table.concat(constList, "\n--"))
            end

            local b64 = (byteLen <= 25000) and encodeBase64(bc) or "-- [Bytecode > 25KB: Volcar individualmente]"

            local formatted = string.format([[-- =============================================================================
-- [VOLCADO DE BYTECODE LUAU - EJECUTOR SIN DESCOMPILADOR NATIVO C]
-- Script: %s (%s)
-- Tamaño Bytecode: %d bytes | Versión Luau: %d
-- =============================================================================%s
-- [BYTECODE BINARIO BASE64 (Listo para Unluau / Luau Decompiler)]:
-- __BYTECODE_B64__ = %q
-- =============================================================================]],
                self:GetPath(scriptInstance),
                scriptInstance.ClassName,
                byteLen,
                luauVersion,
                constSection,
                b64
            )

            self._decompCache[scriptInstance] = formatted
            return formatted
        end
    end

    -- 6. Sin resultado: mensaje explicativo detallado
    local fallbackMsg = string.format(
        "-- [Código no disponible: Ejecutor Nivel %d sin APIs 'decompile' ni 'getscriptbytecode' accesibles para %s]",
        self.Capabilities.Level or 3,
        scriptInstance.ClassName
    )
    self._decompCache[scriptInstance] = fallbackMsg
    self._cacheStats.Errors = self._cacheStats.Errors + 1
    return fallbackMsg
end

-- =============================================================================
-- SHARED MEMORY STORE: GetPath (Caché de rutas jerárquicas)
-- =============================================================================

function CapabilityManager:GetPath(instance)
    if not instance then return "nil" end

    local cached = self._pathCache[instance]
    if cached then return cached end

    local s, path = pcall(function() return instance:GetFullName() end)
    local result = (s and path) or tostring(instance)
    self._pathCache[instance] = result
    return result
end

-- =============================================================================
-- CACHE STATS: Métricas de rendimiento
-- =============================================================================

function CapabilityManager:GetCacheStats()
    local total = self._cacheStats.Hits + self._cacheStats.Misses
    return {
        Hits = self._cacheStats.Hits,
        Misses = self._cacheStats.Misses,
        Timeouts = self._cacheStats.Timeouts,
        Errors = self._cacheStats.Errors,
        Total = total,
        HitRate = total > 0 and string.format("%.1f%%", (self._cacheStats.Hits / total) * 100) or "0%",
        CacheSize = self:_countCache(),
    }
end

function CapabilityManager:_countCache()
    local count = 0
    for _ in pairs(self._decompCache) do
        count = count + 1
    end
    return count
end

function CapabilityManager:FlushCache()
    self._decompCache = setmetatable({}, { __mode = "k" })
    self._pathCache   = setmetatable({}, { __mode = "k" })
    self._cacheStats  = { Hits = 0, Misses = 0, Timeouts = 0, Errors = 0 }
end

-- =============================================================================
-- ARM ENVIRONMENT GUARD: Protección contra introspección del anti-cheat
-- =============================================================================
-- Intercepta debug.info, getfenv y debug.getinfo para que las trampas del
-- juego que escanean el callstack no detecten las funciones de la suite.

function CapabilityManager:ArmEnvironmentGuard()
    if self._envGuardActive then return true end

    local hookfn = self.APIs.hookfunction
    local newcclosure = self.APIs.newcclosure
    local checkcaller = self.APIs.checkcaller

    if not hookfn then
        return false, "hookfunction no disponible (requiere Nivel 6+)"
    end

    local guards = 0

    -- 1. Interceptar debug.info (trampa de callstack)
    if type(debug) == "table" and type(debug.info) == "function" then
        local originalDebugInfo = debug.info
        pcall(function()
            hookfn(debug.info, newcclosure(function(levelOrFunc, ...)
                if checkcaller() then
                    return originalDebugInfo(levelOrFunc, ...)
                end
                -- Cuando NO es nuestro caller (es el juego intentando inspeccionar),
                -- ajustar nivel +1 para ocultar nuestro frame del stack
                if type(levelOrFunc) == "number" then
                    return originalDebugInfo(levelOrFunc + 1, ...)
                end
                return originalDebugInfo(levelOrFunc, ...)
            end))
            guards = guards + 1
        end)
    end

    -- 2. Interceptar getfenv (detección de entorno inyectado)
    if type(getfenv) == "function" then
        local originalGetfenv = getfenv
        pcall(function()
            hookfn(getfenv, newcclosure(function(levelOrFunc)
                if checkcaller() then
                    return originalGetfenv(levelOrFunc)
                end
                -- Devolver entorno limpio al juego
                if type(levelOrFunc) == "number" and levelOrFunc > 0 then
                    return originalGetfenv(0)
                end
                return originalGetfenv(levelOrFunc)
            end))
            guards = guards + 1
        end)
    end

    self._envGuardActive = guards > 0
    return self._envGuardActive, string.format("%d guardas de entorno instaladas", guards)
end

function CapabilityManager:IsEnvironmentGuardActive()
    return self._envGuardActive
end

-- =============================================================================
-- RUNTIME SUSPECT REGISTRY (Almacén Centralizado de Hallazgos en Tiempo Real)
-- =============================================================================

function CapabilityManager:RegisterSuspect(instance, category, score, metadata)
    if not self._suspectRegistry then
        self._suspectRegistry = {}
        self._suspectMap = setmetatable({}, { __mode = "k" })
    end
    if not instance then return nil end

    local existing = self._suspectMap[instance]
    if existing then
        if score and score > (existing.Score or 0) then
            existing.Score = score
        end
        if category and not existing.Categories[category] then
            existing.Categories[category] = true
            table.insert(existing.Tags, category)
        end
        if metadata then
            for k, v in pairs(metadata) do
                existing.Metadata[k] = v
            end
        end
        return existing
    end

    local path = self:GetPath(instance) or (pcall(function() return instance:GetFullName() end) and instance:GetFullName()) or tostring(instance)
    local entry = {
        Instance = instance,
        Name = instance.Name,
        ClassName = instance.ClassName,
        Path = path,
        Score = score or 100,
        Categories = { [category or "RuntimeSuspect"] = true },
        Tags = { category or "RuntimeSuspect" },
        Timestamp = tick(),
        Metadata = metadata or {},
    }

    self._suspectMap[instance] = entry
    table.insert(self._suspectRegistry, entry)
    return entry
end

function CapabilityManager:GetRuntimeSuspects()
    return self._suspectRegistry or {}
end

function CapabilityManager:ClearRuntimeSuspects()
    self._suspectRegistry = {}
    self._suspectMap = setmetatable({}, { __mode = "k" })
end

-- =============================================================================
-- DESTRUCTOR
-- =============================================================================

function CapabilityManager:Destroy()
    self:FlushCache()
    self:ClearRuntimeSuspects()
    self._envGuardActive = false
end

return CapabilityManager
