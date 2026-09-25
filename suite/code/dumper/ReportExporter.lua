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
    if self.Caps.Capabilities.HasFileSystem and self.Caps.APIs.writefile then
        local folder = "apex_reports"
        if self.Caps.APIs.makefolder and self.Caps.APIs.isfolder and not self.Caps.APIs.isfolder(folder) then
            pcall(self.Caps.APIs.makefolder, folder)
        end
        
        local fullPath = folder .. "/" .. filename
        local success, err = pcall(self.Caps.APIs.writefile, fullPath, content)
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
    if not self.Caps.Capabilities.HasFileSystem or not self.Caps.APIs.writefile then
        return false, "Sistema de archivos no disponible en este nivel."
    end
    
    local makefolder = self.Caps.APIs.makefolder
    local isfolder = self.Caps.APIs.isfolder
    local writefile = self.Caps.APIs.writefile
    
    local baseDir = "apex_dumps/" .. (rootFolderName or ("dump_" .. tostring(game.PlaceId) .. "_" .. tostring(tick())))
    
    local function ensureDir(path)
        if makefolder and isfolder and not isfolder(path) then
            pcall(makefolder, path)
        end
    end
    
    ensureDir("apex_dumps")
    ensureDir(baseDir)
    
    local function writeNode(node, currentPath)
        if not node then return end
        
        -- Sanitizar nombres de archivo para Windows/OS
        local cleanName = tostring(node.Name):gsub("[\\/:*?\"<>|]", "_")
        local thisPath = currentPath .. "/" .. cleanName
        
        -- Si es Script o tiene Source, escribir archivo .lua
        if node.Source then
            local scriptFile = thisPath .. ".lua"
            pcall(writefile, scriptFile, node.Source)
        end
        
        -- Si tiene hijos, crear carpeta y recursión
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
    pcall(writefile, manifestPath, self:ToJSON({
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
    if self.Caps.Capabilities.HasClipboard and self.Caps.APIs.setclipboard then
        local success = pcall(self.Caps.APIs.setclipboard, content)
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
