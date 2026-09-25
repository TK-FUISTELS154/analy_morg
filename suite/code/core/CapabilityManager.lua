--[[
    =============================================================================
    APEX SUITE - CAPABILITY MANAGER (DYNAMIC LEVEL DETECTOR & MULTI-ENGINE ADAPTER)
    =============================================================================
    Detecta el nivel real del ejecutor (Nivel 3 a 8), resuelve descompiladores de
    múltiples motores (Synapse, Script-Ware, Fluxus, Delta, KRNL, Studio) y ofrece
    fallbacks seguros para que la suite nunca lance excepciones.
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

function CapabilityManager:Init()
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
    self:EvaluateCapabilities()
end

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
    
    -- 4. Resolución Multi-Motor de Descompiladores
    local decompilerFunc = nil
    if type(decompile) == "function" then
        decompilerFunc = decompile
    elseif getgenv and type(getgenv().decompile) == "function" then
        decompilerFunc = getgenv().decompile
    elseif type(syn) == "table" and type(syn.decompile) == "function" then
        decompilerFunc = syn.decompile
    elseif type(fluxus) == "table" and type(fluxus.decompile) == "function" then
        decompilerFunc = fluxus.decompile
    end
    apis.decompile = decompilerFunc
    
    apis.getscriptbytecode = (type(getscriptbytecode) == "function" and getscriptbytecode)
        or (type(get_script_bytecode) == "function" and get_script_bytecode)
        or (getgenv and type(getgenv().getscriptbytecode) == "function" and getgenv().getscriptbytecode)
        or nil
        
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
    apis.request = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (type(syn and syn.request) == "function" and syn.request) or nil
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

function CapabilityManager:SafeDecompile(scriptInstance)
    if not scriptInstance then return nil end
    
    -- Intento 1: Lectura directa de propiedad Source (Studio / Entornos con permisos de lectura)
    local sSrc, directSrc = pcall(function() return scriptInstance.Source end)
    if sSrc and type(directSrc) == "string" and #directSrc > 0 then
        return directSrc
    end
    
    -- Intento 2: Descompilador C del ejecutor
    local decompiler = self.APIs.decompile or (type(decompile) == "function" and decompile) or (getgenv and type(getgenv().decompile) == "function" and getgenv().decompile)
    if decompiler then
        local success, result = pcall(function()
            return decompiler(scriptInstance)
        end)
        if success and type(result) == "string" and #result > 0 and not result:find("%[Decompilación no soportada") then
            return result
        end
    end
    
    -- Intento 3: Extracción de Bytecode nativo
    local bytecodeGetter = self.APIs.getscriptbytecode or (type(getscriptbytecode) == "function" and getscriptbytecode)
    if bytecodeGetter then
        local success, bc = pcall(function()
            return bytecodeGetter(scriptInstance)
        end)
        if success and bc and #tostring(bc) > 0 then
            return string.format("-- [BYTECODE EXTRAÍDO: %d bytes (Ejecutor sin descompilador de alto nivel)]\n-- Hash/Size: %s", #tostring(bc), tostring(bc):sub(1, 40))
        end
    end
    
    return "-- [Código protegido / No accesible sin descompilador C de Nivel 7+]"
end

return CapabilityManager
