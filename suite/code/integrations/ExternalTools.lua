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

return ExternalTools
