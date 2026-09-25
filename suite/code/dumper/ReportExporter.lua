--[[
    =============================================================================
    APEX SUITE - ADVANCED REPORT & TREE EXPORTER (MULTI-SERVICE DISK RECONSTRUCTION)
    =============================================================================
    Exporta datos en JSON seguro y reconstruye la jerarquía completa de carpetas
    y archivos .lua en el disco del ejecutor (writefile / makefolder), admitiendo
    múltiples servicios y saneamiento de nombres de archivo.
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

function ReportExporter:SanitizeForJSON(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 8 then return "[Depth Limit]" end
    
    local t = typeof(val)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then
        return val
    elseif t == "Instance" then
        return pcall(function() return val:GetFullName() end) and val:GetFullName() or tostring(val)
    elseif t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "Color3" or t == "UDim2" or t == "EnumItem" then
        return tostring(val)
    elseif t == "table" then
        if visited[val] then return "[Circular Reference]" end
        visited[val] = true
        
        local cleanTbl = {}
        for k, v in pairs(val) do
            local cleanKey = tostring(k)
            cleanTbl[cleanKey] = self:SanitizeForJSON(v, depth + 1, visited)
        end
        return cleanTbl
    else
        return tostring(val)
    end
end

function ReportExporter:ToJSON(data)
    local sanitized = self:SanitizeForJSON(data)
    local success, result = pcall(function()
        return HttpService:JSONEncode(sanitized)
    end)
    return success and result or "-- [Error al codificar JSON: estructura inválida]"
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
function ReportExporter:ExportProjectTreeToDisk(rootFolderName, dumpPackage)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)
    
    if not writefileFunc then
        return false, "Sistema de archivos no disponible en este nivel de ejecutor (writefile no disponible)."
    end
    
    local baseDir = "apex_dumps/" .. (rootFolderName or ("dump_" .. tostring(game.PlaceId) .. "_" .. tostring(tick())))
    
    local function ensureDir(path)
        if makefolderFunc and isfolderFunc and not isfolderFunc(path) then
            pcall(makefolderFunc, path)
        end
    end
    
    ensureDir("apex_dumps")
    ensureDir(baseDir)
    
    local writtenScripts = 0
    
    local function writeNode(node, currentPath)
        if not node then return end
        
        local cleanName = tostring(node.Name):gsub("[\\/:*?\"<>|]", "_")
        local thisPath = currentPath .. "/" .. cleanName
        
        -- Si tiene código fuente, guardarlo como .lua
        if node.Source and type(node.Source) == "string" and #node.Source > 0 then
            local scriptFile = thisPath .. ".lua"
            pcall(writefileFunc, scriptFile, node.Source)
            writtenScripts = writtenScripts + 1
        end
        
        -- Si tiene hijos, asegurar la carpeta y escribir recursivamente
        if node.Children and #node.Children > 0 then
            ensureDir(thisPath)
            for _, child in ipairs(node.Children) do
                writeNode(child, thisPath)
            end
        end
    end
    
    -- Manejo polimórfico de paquetes de extracción
    if type(dumpPackage) == "table" then
        if dumpPackage.Services then
            for _, srv in ipairs(dumpPackage.Services) do
                writeNode(srv, baseDir)
            end
        elseif dumpPackage.Nodes then
            for _, node in ipairs(dumpPackage.Nodes) do
                writeNode(node, baseDir)
            end
        elseif dumpPackage.Containers then
            for _, c in ipairs(dumpPackage.Containers) do
                if c.Data then writeNode(c.Data, baseDir) end
            end
        else
            writeNode(dumpPackage, baseDir)
        end
    end
    
    -- Escribir manifiesto JSON
    local manifestPath = baseDir .. "/manifest.json"
    pcall(writefileFunc, manifestPath, self:ToJSON({
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Timestamp = tick(),
        TotalScriptsExported = writtenScripts,
        Mode = dumpPackage and dumpPackage.Mode or "Custom",
    }))
    
    if self.Logger then
        self.Logger:Info("EXPORTER", string.format("Proyecto reconstruido en disco (%d scripts .lua guardados en %s)", writtenScripts, baseDir))
    end
    
    return true, string.format("%s (%d scripts guardados)", baseDir, writtenScripts)
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
