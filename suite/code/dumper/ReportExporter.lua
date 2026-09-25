--[[
    =============================================================================
    APEX SUITE - ADVANCED REPORT & TREE EXPORTER (PROJECT DISK RECONSTRUCTION)
    =============================================================================
    Guarda datos estructurados en JSON, portapapeles y reconstruye el árbol completo
    de carpetas y archivos .lua en el disco del ejecutor (writefile / makefolder).
--]]

local HttpService = game:GetService("HttpService")

local ReportExporter = {}
ReportExporter.__index = ReportExporter
ReportExporter.ClassName = "ReportExporter"

function ReportExporter.new(capabilityManager, logger)
    local self = setmetatable({}, ReportExporter)
    self.Caps = capabilityManager
    self.Logger = logger
    return self
end

function ReportExporter:ToJSON(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    return success and result or "-- [Error al codificar JSON]"
end

function ReportExporter:SaveToFile(filename, content)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)
    
    if writefileFunc then
        local folder = "apex_reports"
        if makefolderFunc and isfolderFunc and not isfolderFunc(folder) then
            pcall(makefolderFunc, folder)
        end
        
        local fullPath = folder .. "/" .. filename
        local success, err = pcall(writefileFunc, fullPath, content)
        if success then
            if self.Logger then
                self.Logger:Info("EXPORTER", "Archivo guardado exitosamente en: " .. fullPath)
            end
            return true, fullPath
        else
            if self.Logger then
                self.Logger:Error("EXPORTER", "Error al escribir archivo: " .. tostring(err))
            end
        end
    end
    
    return self:CopyToClipboard(content)
end

-- Reconstruye carpetas físicas y archivos .lua en el disco del ejecutor
function ReportExporter:ExportProjectTreeToDisk(rootFolderName, dumpNode)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)
    
    if not writefileFunc then
        return false, "Sistema de archivos no disponible en este nivel."
    end
    
    local baseDir = "apex_dumps/" .. (rootFolderName or ("dump_" .. tostring(game.PlaceId) .. "_" .. tostring(tick())))
    
    local function ensureDir(path)
        if makefolderFunc and isfolderFunc and not isfolderFunc(path) then
            pcall(makefolderFunc, path)
        end
    end
    
    ensureDir("apex_dumps")
    ensureDir(baseDir)
    
    local function writeNode(node, currentPath)
        if not node then return end
        
        local cleanName = tostring(node.Name):gsub("[\\/:*?\"<>|]", "_")
        local thisPath = currentPath .. "/" .. cleanName
        
        if node.Source then
            local scriptFile = thisPath .. ".lua"
            pcall(writefileFunc, scriptFile, node.Source)
        end
        
        if node.Children and #node.Children > 0 then
            ensureDir(thisPath)
            for _, child in ipairs(node.Children) do
                writeNode(child, thisPath)
            end
        end
    end
    
    writeNode(dumpNode, baseDir)
    
    -- Escribir manifiesto JSON
    local manifestPath = baseDir .. "/manifest.json"
    pcall(writefileFunc, manifestPath, self:ToJSON({
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Timestamp = tick(),
        RootName = dumpNode.Name,
        Class = dumpNode.ClassName,
        Path = dumpNode.Path,
    }))
    
    if self.Logger then
        self.Logger:Info("EXPORTER", "Proyecto completo reconstruido en disco: " .. baseDir)
    end
    
    return true, baseDir
end

function ReportExporter:CopyToClipboard(content)
    local setclipFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.setclipboard)
        or (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
        or (type(set_clipboard) == "function" and set_clipboard)
        
    if setclipFunc then
        local success = pcall(setclipFunc, content)
        if success then
            if self.Logger then
                self.Logger:Info("EXPORTER", "Contenido copiado al portapapeles.")
            end
            return true, "CLIPBOARD"
        end
    end
    return false, "No hay soporte para portapapeles ni archivos."
end

return ReportExporter
