--[[
    =============================================================================
    APEX SUITE - EXTERNAL TOOLS INTEGRATION (DARKDEX & INFINITE YIELD)
    =============================================================================
    Lanza de forma segura e independiente Infinite Yield y DarkDex con manejo
    de errores y verificación de entorno.
--]]

local ExternalTools = {}
ExternalTools.__index = ExternalTools
ExternalTools.ClassName = "ExternalTools"

function ExternalTools.new(logger)
    local self = setmetatable({}, ExternalTools)
    self.Logger = logger
    return self
end

function ExternalTools:LaunchInfiniteYield()
    if self.Logger then
        self.Logger:Info("TOOLS", "Lanzando Infinite Yield...")
    end
    
    task.spawn(function()
        local success, err = pcall(function()
            loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
        end)
        
        if not success and self.Logger then
            self.Logger:Error("TOOLS", "Error al cargar Infinite Yield: " .. tostring(err))
        end
    end)
end

function ExternalTools:LaunchDarkDex()
    if self.Logger then
        self.Logger:Info("TOOLS", "Lanzando Dex Explorer...")
    end
    
    task.spawn(function()
        local success, err = pcall(function()
            -- Cargar Dex V3/V4 oficial estable
            loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()
        end)
        
        if not success and self.Logger then
            self.Logger:Error("TOOLS", "Error al cargar DarkDex: " .. tostring(err))
        end
    end)
end

return ExternalTools
