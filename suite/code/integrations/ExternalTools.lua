--[[
    =============================================================================
    APEX SUITE - EXTERNAL TOOLS INTEGRATION (DARKDEX & INFINITE YIELD)
    =============================================================================
    Lanza de forma segura e independiente Infinite Yield y DarkDex con manejo
    de errores, múltiples fuentes de respaldo (CDNs) y verificación de entorno.
--]]

local ExternalTools = {}
ExternalTools.__index = ExternalTools
ExternalTools.ClassName = "ExternalTools"

function ExternalTools.new(logger)
    local self = setmetatable({}, ExternalTools)
    self.Logger = logger
    return self
end

function ExternalTools:FetchScript(urls)
    for _, url in ipairs(urls) do
        local s, content = pcall(function()
            return game:HttpGet(url)
        end)
        if s and type(content) == "string" and #content > 100 then
            return content
        end
    end
    return nil
end

function ExternalTools:LaunchInfiniteYield()
    if self.Logger then
        self.Logger:Info("TOOLS", "Descargando e iniciando Infinite Yield...")
    end
    
    task.spawn(function()
        local urls = {
            "https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua",
            "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
        }
        
        local code = self:FetchScript(urls)
        if code then
            local s, fn = pcall(loadstring, code)
            if s and fn then
                local sRun, errRun = pcall(fn)
                if sRun then
                    if self.Logger then self.Logger:Info("TOOLS", "Infinite Yield iniciado exitosamente.") end
                    return
                else
                    if self.Logger then self.Logger:Error("TOOLS", "Error al ejecutar Infinite Yield: " .. tostring(errRun)) end
                end
            end
        end
        
        if self.Logger then
            self.Logger:Error("TOOLS", "No se pudo descargar Infinite Yield de los repositorios.")
        end
    end)
end

function ExternalTools:LaunchDarkDex()
    if self.Logger then
        self.Logger:Info("TOOLS", "Descargando e iniciando DarkDex Explorer...")
    end
    
    task.spawn(function()
        local urls = {
            "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua",
            "https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua",
        }
        
        local code = self:FetchScript(urls)
        if code then
            local s, fn = pcall(loadstring, code)
            if s and fn then
                local sRun, errRun = pcall(fn)
                if sRun then
                    if self.Logger then self.Logger:Info("TOOLS", "DarkDex Explorer iniciado exitosamente.") end
                    return
                else
                    if self.Logger then self.Logger:Error("TOOLS", "Error al ejecutar DarkDex: " .. tostring(errRun)) end
                end
            end
        end
        
        if self.Logger then
            self.Logger:Error("TOOLS", "No se pudo descargar DarkDex Explorer de los repositorios.")
        end
    end)
end

function ExternalTools:LaunchSelectiveDumper()
    if self.Logger then
        self.Logger:Info("TOOLS", "Iniciando Selective Dumper & Smart Inspector...")
    end
    
    task.spawn(function()
        local code = nil
        
        -- 1. Intentar cargar desde el sistema de archivos local
        if typeof(readfile) == "function" and typeof(isfile) == "function" then
            pcall(function()
                if isfile("scan/selective_dumper.lua") then
                    code = readfile("scan/selective_dumper.lua")
                elseif isfile("scripts/scan/selective_dumper.lua") then
                    code = readfile("scripts/scan/selective_dumper.lua")
                end
            end)
        end
        
        -- 2. Fallback remoto de GitHub
        if not code or #code == 0 then
            local urls = {
                "https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/scan/selective_dumper.lua",
            }
            code = self:FetchScript(urls)
        end
        
        if code and #code > 0 then
            local s, fn = pcall(loadstring, code)
            if s and fn then
                local sRun, errRun = pcall(fn)
                if sRun then
                    if self.Logger then self.Logger:Info("TOOLS", "Selective Dumper & Smart Inspector iniciado exitosamente.") end
                    return
                else
                    if self.Logger then self.Logger:Error("TOOLS", "Error al ejecutar Selective Dumper: " .. tostring(errRun)) end
                end
            end
        end
        
        if self.Logger then
            self.Logger:Error("TOOLS", "No se pudo cargar Selective Dumper.")
        end
    end)
end

return ExternalTools

