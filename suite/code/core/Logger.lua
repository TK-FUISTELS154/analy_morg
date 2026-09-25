--[[
    =============================================================================
    APEX SUITE - LOGGER
    =============================================================================
    Sistema de registro seguro con niveles de severidad y filtrado anti-spam.
--]]

local Logger = {}
Logger.__index = Logger
Logger.ClassName = "Logger"

Logger.LogLevel = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    VULN = 5,
}

local LevelNames = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "VULN",
}

function Logger.new(eventBus)
    local self = setmetatable({}, Logger)
    self.EventBus = eventBus
    self.MinLevel = Logger.LogLevel.INFO
    self.History = {}
    self.MaxHistory = 500
    return self
end

function Logger:Log(level, tag, message, data)
    if level < self.MinLevel then return end
    
    local entry = {
        Timestamp = tick(),
        Level = level,
        LevelName = LevelNames[level] or "INFO",
        Tag = tag or "GENERAL",
        Message = tostring(message),
        Data = data,
    }
    
    table.insert(self.History, entry)
    if #self.History > self.MaxHistory then
        table.remove(self.History, 1)
    end
    
    local prefix = string.format("[APEX][%s][%s]", entry.LevelName, entry.Tag)
    local formatted = string.format("%s %s", prefix, entry.Message)
    
    if level == Logger.LogLevel.ERROR then
        warn(formatted)
    elseif level == Logger.LogLevel.VULN then
        print("🚨 " .. formatted)
    else
        print(formatted)
    end
    
    if self.EventBus then
        self.EventBus:Publish("LogAdded", entry)
    end
end

function Logger:Debug(tag, msg, data) self:Log(Logger.LogLevel.DEBUG, tag, msg, data) end
function Logger:Info(tag, msg, data) self:Log(Logger.LogLevel.INFO, tag, msg, data) end
function Logger:Warn(tag, msg, data) self:Log(Logger.LogLevel.WARN, tag, msg, data) end
function Logger:Error(tag, msg, data) self:Log(Logger.LogLevel.ERROR, tag, msg, data) end
function Logger:Vuln(tag, msg, data) self:Log(Logger.LogLevel.VULN, tag, msg, data) end

return Logger
