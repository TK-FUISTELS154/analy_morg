--[[
    =============================================================================
    APEX SUITE - REPORT EXPORTER v3.0
    (VFS SINGLE-FILE ARCHIVE + CHUNKED STREAM + MULTI-SERVICE DISK TREE)
    =============================================================================
    Exportación avanzada con tres estrategias:
    1. VFS Archive: Consolida todo en un único JSON/Lua serializable (evita I/O masivo)
    2. Chunked Stream: Fragmenta payloads >1MB en chunks seguros para evitar OOM
    3. Disk Tree: Reconstrucción física de carpetas/archivos .lua en disco
--]]

local HttpService = game:GetService("HttpService")

local ReportExporter = {}
ReportExporter.__index = ReportExporter
ReportExporter.ClassName = "ReportExporter"

-- Tamaño máximo de chunk en bytes (800KB para margen de seguridad)
local MAX_CHUNK_BYTES = 800 * 1024
-- Tamaño máximo de payload para escritura directa (1MB)
local MAX_DIRECT_WRITE = 1024 * 1024

function ReportExporter.new(capabilityManager, logger)
    local self = setmetatable({}, ReportExporter)
    self.Caps = capabilityManager
    self.Logger = logger
    return self
end

-- =============================================================================
-- SANITIZACIÓN JSON SEGURA (Profundidad limitada, ciclos detectados)
-- =============================================================================

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

-- =============================================================================
-- VFS SINGLE-FILE ARCHIVE (Evita saturación de I/O con múltiples writefile)
-- =============================================================================
-- Consolida todos los scripts y metadatos en un único archivo JSON serializable.
-- Estructura del VFS: { Manifest, Entries: [{ Path, ClassName, Source, Attributes }] }

function ReportExporter:ExportAsVFSArchive(rootName, dumpPackage)
    local archive = {
        FormatVersion = "VFS_1.0",
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Timestamp = tick(),
        RootName = rootName or "dump",
        Mode = dumpPackage and dumpPackage.Mode or "Custom",
        Entries = {},
        TotalEntries = 0,
    }

    -- Aplanar la jerarquía del dump en entradas lineales
    local function flattenNode(node, parentPath)
        if not node then return end
        local currentPath = parentPath .. "/" .. tostring(node.Name)

        table.insert(archive.Entries, {
            Path = currentPath,
            ClassName = node.ClassName or "Unknown",
            Source = node.Source,
            BytecodeSize = node.BytecodeSize or 0,
            Attributes = node.Attributes,
            Properties = node.Properties,
        })
        archive.TotalEntries = archive.TotalEntries + 1

        for _, child in ipairs(node.Children or {}) do
            flattenNode(child, currentPath)
        end
    end

    if type(dumpPackage) == "table" then
        if dumpPackage.Services then
            for _, srv in ipairs(dumpPackage.Services) do
                flattenNode(srv, "")
            end
        elseif dumpPackage.Nodes then
            for _, node in ipairs(dumpPackage.Nodes) do
                flattenNode(node, "")
            end
        elseif dumpPackage.Containers then
            for _, c in ipairs(dumpPackage.Containers) do
                if c.Data then flattenNode(c.Data, "") end
            end
        else
            flattenNode(dumpPackage, "")
        end
    end

    local jsonStr = self:ToJSON(archive)

    -- Guardar como un único archivo
    local filename = string.format("apex_vfs_%s_%d.json", tostring(game.PlaceId), tick())
    local saved, path = self:SaveToFileChunked(filename, jsonStr)

    if self.Logger then
        self.Logger:Info("EXPORTER", string.format(
            "VFS Archive exportado: %d entradas en %s (%d bytes)",
            archive.TotalEntries, tostring(path), #jsonStr
        ))
    end

    return saved, path, archive
end

-- =============================================================================
-- CHUNKED STREAM EXPORTER (Fragmenta payloads >1MB)
-- =============================================================================

function ReportExporter:SaveToFileChunked(filename, content)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)

    if not writefileFunc then
        return self:CopyToClipboard(content)
    end

    local folder = "apex_reports"
    if makefolderFunc and isfolderFunc and not isfolderFunc(folder) then
        pcall(makefolderFunc, folder)
    end

    local contentLen = #content

    -- Escritura directa si el payload es menor a 1MB
    if contentLen <= MAX_DIRECT_WRITE then
        local fullPath = folder .. "/" .. filename
        local success, err = pcall(writefileFunc, fullPath, content)
        if success then
            if self.Logger then
                self.Logger:Info("EXPORTER", "Archivo guardado: " .. fullPath .. " (" .. tostring(contentLen) .. " bytes)")
            end
            return true, fullPath
        else
            if self.Logger then
                self.Logger:Error("EXPORTER", "Error al escribir: " .. tostring(err))
            end
            return self:CopyToClipboard(content)
        end
    end

    -- Chunked write: fragmentar en múltiples archivos de 800KB
    local chunkIndex = 1
    local offset = 1
    local baseName = filename:match("(.+)%..+$") or filename
    local ext = filename:match("%.(.+)$") or "json"
    local chunkFolder = folder .. "/" .. baseName .. "_chunks"

    if makefolderFunc and isfolderFunc and not isfolderFunc(chunkFolder) then
        pcall(makefolderFunc, chunkFolder)
    end

    local lastYield = tick()
    while offset <= contentLen do
        local chunkEnd = math.min(offset + MAX_CHUNK_BYTES - 1, contentLen)
        local chunk = content:sub(offset, chunkEnd)
        local chunkFile = string.format("%s/chunk_%03d.%s", chunkFolder, chunkIndex, ext)

        local ok, err = pcall(writefileFunc, chunkFile, chunk)
        if not ok and self.Logger then
            self.Logger:Error("EXPORTER", "Error en chunk " .. chunkIndex .. ": " .. tostring(err))
        end

        offset = chunkEnd + 1
        chunkIndex = chunkIndex + 1

        -- Time-slicing cooperativo durante escritura masiva
        if tick() - lastYield > 0.012 then
            task.wait()
            lastYield = tick()
        end
    end

    -- Escribir manifiesto de chunks
    local manifestFile = chunkFolder .. "/manifest.json"
    pcall(writefileFunc, manifestFile, self:ToJSON({
        TotalChunks = chunkIndex - 1,
        TotalBytes = contentLen,
        ChunkSize = MAX_CHUNK_BYTES,
        OriginalFile = filename,
    }))

    if self.Logger then
        self.Logger:Info("EXPORTER", string.format(
            "Chunked write completado: %d chunks (%d bytes totales) en %s",
            chunkIndex - 1, contentLen, chunkFolder
        ))
    end

    return true, chunkFolder
end

-- =============================================================================
-- ESCRITURA ESTÁNDAR A DISCO (backward compatible)
-- =============================================================================

function ReportExporter:SaveToFile(filename, content)
    return self:SaveToFileChunked(filename, content)
end

-- =============================================================================
-- DISK TREE RECONSTRUCTION (Multi-Service)
-- =============================================================================

function ReportExporter:ExportProjectTreeToDisk(rootFolderName, dumpPackage)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)

    if not writefileFunc then
        return false, "Sistema de archivos no disponible en este nivel de ejecutor."
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
    local lastYield = tick()

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

        -- Time-slicing cooperativo
        if tick() - lastYield > 0.012 then
            task.wait()
            lastYield = tick()
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

-- =============================================================================
-- CLIPBOARD FALLBACK
-- =============================================================================

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
