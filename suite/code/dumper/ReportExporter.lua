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

function ReportExporter:SanitizeForJSON(val, depth, stack)
    depth = depth or 0
    stack = stack or {}
    if depth > 12 then return "[Depth Limit]" end

    local t = typeof(val)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then
        return val
    elseif t == "Instance" then
        local s, full = pcall(function() return val:GetFullName() end)
        return (s and full) or tostring(val)
    elseif t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "Color3" or t == "UDim2" or t == "EnumItem" then
        return tostring(val)
    elseif t == "table" then
        if stack[val] then return "[Circular Reference]" end
        stack[val] = true

        local cleanTbl = {}
        for k, v in pairs(val) do
            local cleanKey = tostring(k)
            cleanTbl[cleanKey] = self:SanitizeForJSON(v, depth + 1, stack)
        end

        stack[val] = nil -- Liberar de la pila de recursión al desapilar
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
-- MARKDOWN REPORT GENERATOR (.MD)
-- =============================================================================

function ReportExporter:GenerateMarkdown(dumpPackage, title)
    title = title or "Apex Suite - Instance Dump Report"
    local lines = {}

    table.insert(lines, "# " .. title)
    table.insert(lines, "")
    table.insert(lines, string.format("- **Place ID:** `%s`", tostring(game.PlaceId)))
    table.insert(lines, string.format("- **Job ID:** `%s`", tostring(game.JobId)))
    table.insert(lines, string.format("- **Fecha / Timestamp:** `%s` (tick: %.2f)", os.date("!%Y-%m-%d %H:%M:%SZ"), tick()))
    table.insert(lines, string.format("- **Modo de Volcado:** `%s`", dumpPackage and dumpPackage.Mode or "Custom"))
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")

    local totalScripts = 0
    local totalRemotes = 0
    local totalInstances = 0
    local scriptEntries = {}

    local function traverseNode(node, depth, pathSoFar)
        if not node then return end
        totalInstances = totalInstances + 1

        local currentPath = pathSoFar .. "/" .. tostring(node.Name)
        local indent = string.rep("  ", depth)
        local icon = "📁"
        if node.ClassName == "LocalScript" or node.ClassName == "Script" or node.ClassName == "ModuleScript" then
            icon = "📜"
            totalScripts = totalScripts + 1
            table.insert(scriptEntries, {
                Name = node.Name,
                ClassName = node.ClassName,
                Path = node.Path or currentPath,
                Source = node.Source,
                BytecodeSize = node.BytecodeSize or (node.Source and #node.Source or 0),
                Attributes = node.Attributes,
                Tags = node.Tags,
            })
        elseif node.ClassName and node.ClassName:find("Remote") then
            icon = "📡"
            totalRemotes = totalRemotes + 1
        elseif node.ClassName and (node.ClassName:find("Part") or node.ClassName:find("Model")) then
            icon = "📦"
        elseif node.ClassName and node.ClassName:find("Gui") or node.ClassName and (node.ClassName:find("Text") or node.ClassName:find("Button") or node.ClassName:find("Image")) then
            icon = "🖼️"
        end

        table.insert(lines, string.format("%s- %s **%s** (`%s`)", indent, icon, node.Name, node.ClassName or "Instance"))

        for _, child in ipairs(node.Children or {}) do
            traverseNode(child, depth + 1, currentPath)
        end
    end

    table.insert(lines, "## 🌲 Estructura del Árbol de Instancias")
    table.insert(lines, "")

    if type(dumpPackage) == "table" then
        if dumpPackage.Services then
            for _, srv in ipairs(dumpPackage.Services) do
                traverseNode(srv, 0, "")
            end
        elseif dumpPackage.Nodes then
            for _, node in ipairs(dumpPackage.Nodes) do
                traverseNode(node, 0, "")
            end
        elseif dumpPackage.Containers then
            for _, c in ipairs(dumpPackage.Containers) do
                if c.Data then traverseNode(c.Data, 0, "") end
            end
        else
            traverseNode(dumpPackage, 0, "")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## 📊 Métricas de Extracción")
    table.insert(lines, "")
    table.insert(lines, string.format("| Métrica | Cantidad |"))
    table.insert(lines, "| :--- | :--- |")
    table.insert(lines, string.format("| **Total Instancias** | `%d` |", totalInstances))
    table.insert(lines, string.format("| **Scripts Extraídos** | `%d` |", totalScripts))
    table.insert(lines, string.format("| **Remotes Detectados** | `%d` |", totalRemotes))
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## 📜 Código Fuente y Bytecode de Scripts")
    table.insert(lines, "")

    if #scriptEntries == 0 then
        table.insert(lines, "_No se extrajeron scripts de código fuente en esta selección._")
    else
        for idx, sc in ipairs(scriptEntries) do
            table.insert(lines, string.format("### [%d] %s (`%s`)", idx, sc.Name, sc.ClassName))
            table.insert(lines, string.format("- **Ruta:** `%s`", tostring(sc.Path)))
            table.insert(lines, string.format("- **Tamaño:** `%d bytes`", sc.BytecodeSize or 0))
            if sc.Tags and #sc.Tags > 0 then
                table.insert(lines, string.format("- **Tags:** `[%s]`", table.concat(sc.Tags, ", ")))
            end
            if sc.Attributes and next(sc.Attributes) then
                local attrList = {}
                for k, v in pairs(sc.Attributes) do
                    table.insert(attrList, string.format("%s=%s", tostring(k), tostring(v)))
                end
                table.insert(lines, string.format("- **Atributos:** `%s`", table.concat(attrList, ", ")))
            end
            table.insert(lines, "")
            table.insert(lines, "```lua")
            if sc.Source and #sc.Source > 0 and not sc.Source:find("%[Código no disponible") then
                table.insert(lines, sc.Source)
            else
                table.insert(lines, "-- [Código fuente no disponible o protegido por el ejecutor]")
            end
            table.insert(lines, "```")
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end

function ReportExporter:ExportAsMarkdown(filename, dumpPackage, title)
    filename = filename or string.format("apex_dump_%s_%d.md", tostring(game.PlaceId), tick())
    if not filename:match("%.md$") then filename = filename .. ".md" end

    local mdContent = self:GenerateMarkdown(dumpPackage, title)
    local saved, path = self:SaveToFileChunked(filename, mdContent)

    if self.Logger then
        self.Logger:Info("EXPORTER", string.format("Reporte Markdown exportado a %s (%d bytes)", tostring(path), #mdContent))
    end

    return saved, path, mdContent
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
