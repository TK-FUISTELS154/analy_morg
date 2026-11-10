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
    if depth > 32 then return "[Depth Limit]" end

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
-- REPORTE MARKDOWN UNIFICADO TOTAL (.MD)
-- =============================================================================

function ReportExporter:GenerateUnifiedMarkdown(dumpPackage, title)
    title = title or "Apex Suite - Reporte Maestro Unificado del Proyecto"
    local lines = {}
    local function add(l) table.insert(lines, l) end

    add("# " .. title)
    add("")
    add(string.format("- **Place ID:** `%s`", tostring(game.PlaceId)))
    add(string.format("- **Job ID:** `%s`", tostring(game.JobId)))
    add(string.format("- **Fecha de Extracción:** `%s` (UTC)", os.date("!%Y-%m-%d %H:%M:%SZ")))
    add(string.format("- **Modo de Volcado:** `%s`", dumpPackage and dumpPackage.Mode or "Custom"))
    add("")
    add("---")
    add("")

    -- Recolección de Scripts, Remotes y Métricas
    local scriptsList = {}
    local remotesList = {}
    local totalInstances = 0

    local function traverse(node, currentPath)
        if not node then return end
        totalInstances = totalInstances + 1
        local thisPath = currentPath == "" and tostring(node.Name) or (currentPath .. "." .. tostring(node.Name))
        local cls = node.ClassName or "Instance"

        if cls:find("Remote") then
            table.insert(remotesList, {
                Name = node.Name,
                ClassName = cls,
                Path = node.Path or thisPath
            })
        end

        if cls == "LocalScript" or cls == "ModuleScript" or cls == "Script" then
            if node.Source and #node.Source > 0 then
                table.insert(scriptsList, {
                    Name = node.Name,
                    ClassName = cls,
                    Path = node.Path or thisPath,
                    Source = node.Source,
                    Size = #node.Source
                })
            end
        end

        for _, child in ipairs(node.Children or {}) do
            traverse(child, thisPath)
        end
    end

    local rootNodes = dumpPackage.Nodes or dumpPackage.Services or (type(dumpPackage) == "table" and dumpPackage) or {}
    for _, node in ipairs(rootNodes) do
        traverse(node, "")
    end

    -- 1. SECCIÓN DE MÉTRICAS EJECUTIVAS
    add("## 📊 1. Resumen Ejecutivo de Métricas")
    add("")
    add("| Métrica | Cantidad |")
    add("| :--- | :--- |")
    add(string.format("| **Total Instancias Procesadas** | `%d` |", totalInstances))
    add(string.format("| **Total Scripts Descompilados** | `%d` |", #scriptsList))
    add(string.format("| **Total Remotes Detectados** | `%d` |", #remotesList))
    add("")
    add("---")
    add("")

    -- 2. SECCIÓN DE REMOTES Y RED
    add("## 📡 2. Catálogo Interceptado de Remotes")
    add("")
    if #remotesList == 0 then
        add("_No se detectaron RemoteEvents ni RemoteFunctions._")
    else
        add("| # | Tipo | Nombre | Ruta de Instancia |")
        add("| :-: | :--- | :--- | :--- |")
        for i, r in ipairs(remotesList) do
            add(string.format("| %d | `%s` | **%s** | `%s` |", i, r.ClassName, r.Name, r.Path))
        end
    end
    add("")
    add("---")
    add("")

    -- 3. SECCIÓN DE SCRIPTS Y CÓDIGO FUENTE UNIFICADO
    add("## 📜 3. Código Fuente Unificado de Scripts")
    add("")
    add("### 📑 Índice de Scripts")
    for i, sc in ipairs(scriptsList) do
        add(string.format("- **[%04d]** `%s` (`%s`, %.1f KB)", i, sc.Path, sc.ClassName, sc.Size / 1024))
    end
    add("")
    add("---")
    add("")

    for i, sc in ipairs(scriptsList) do
        add(string.format("### [%04d / %04d] %s", i, #scriptsList, sc.Path))
        add(string.format("- **Tipo:** `%s` | **Tamaño:** `%.1f KB`", sc.ClassName, sc.Size / 1024))
        add("")
        add("```lua")
        add(sc.Source)
        add("```")
        add("")
    end

    return table.concat(lines, "\n")
end

function ReportExporter:ExportAsMarkdown(filename, dumpPackage, title)
    filename = filename or string.format("apex_unified_report_%s_%d.md", tostring(game.PlaceId), math.floor(tick()))
    if not filename:match("%.md$") then filename = filename .. ".md" end

    local mdContent = self:GenerateUnifiedMarkdown(dumpPackage, title)
    local saved, path = self:SaveToFileChunked(filename, mdContent)

    if self.Logger then
        self.Logger:Info("EXPORTER", string.format("Reporte Markdown unificado exportado a %s (%d bytes)", tostring(path), #mdContent))
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
-- DISK TREE RECONSTRUCTION (Multi-Service, Anti-Collision, Windows-Safe)
-- =============================================================================

local function ensureDirectoryRecursive(path, makefolderFunc, isfolderFunc)
    if not makefolderFunc then return false end
    local normalized = path:gsub("\\", "/")
    local parts = string.split(normalized, "/")
    local accum = ""
    for _, part in ipairs(parts) do
        if part and #part > 0 then
            accum = accum == "" and part or (accum .. "/" .. part)
            local s, exists = pcall(isfolderFunc, accum)
            if not (s and exists) then
                pcall(makefolderFunc, accum)
            end
        end
    end
    return true
end

local function sanitizeSegment(name)
    local clean = tostring(name or "Unnamed"):gsub('[\\/:*?"<>|]', "_"):gsub("^[%s.]+", ""):gsub("[%s.]+$", "")
    if clean == "" then clean = "Unnamed" end
    return clean
end

function ReportExporter:ExportProjectTreeToDisk(rootFolderName, dumpPackage)
    local writefileFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.writefile) or (type(writefile) == "function" and writefile)
    local makefolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.makefolder) or (type(makefolder) == "function" and makefolder)
    local isfolderFunc = (self.Caps and self.Caps.APIs and self.Caps.APIs.isfolder) or (type(isfolder) == "function" and isfolder)

    if not writefileFunc then
        return false, "Sistema de archivos no disponible en este nivel de ejecutor."
    end

    local baseDir = "apex_dumps/" .. (rootFolderName or ("dump_" .. tostring(game.PlaceId) .. "_" .. tostring(tick())))
    ensureDirectoryRecursive(baseDir, makefolderFunc, isfolderFunc)

    local writtenScripts = 0
    local remotesCatalog = {}
    local lastYield = tick()

    local function writeNode(node, currentPath)
        if not node then return end

        local cleanName = sanitizeSegment(node.Name)
        local thisPath = currentPath .. "/" .. cleanName
        local cls = node.ClassName or "Instance"

        -- Registro de Remotes
        if cls == "RemoteEvent" or cls == "RemoteFunction" or cls == "UnreliableRemoteEvent" then
            table.insert(remotesCatalog, {
                Name = node.Name,
                ClassName = cls,
                Path = node.Path or thisPath,
            })
        end

        -- Si tiene código fuente, guardarlo con extensión según su ClassName
        if node.Source and type(node.Source) == "string" and #node.Source > 0 then
            local ext = (cls == "ModuleScript" and ".module.lua") or (cls == "LocalScript" and ".client.lua") or ".server.lua"
            local scriptFile = thisPath .. ext
            
            ensureDirectoryRecursive(currentPath, makefolderFunc, isfolderFunc)
            pcall(writefileFunc, scriptFile, node.Source)
            writtenScripts = writtenScripts + 1
        end

        -- Si tiene hijos, asegurar la carpeta y escribir recursivamente
        local children = node.Children
        if children and #children > 0 then
            ensureDirectoryRecursive(thisPath, makefolderFunc, isfolderFunc)
            for _, child in ipairs(children) do
                writeNode(child, thisPath)
            end
        end

        -- Time-slicing cooperativo cada 12ms para cero lag en Level 3-4
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

    -- Escribir catálogo de remotes detectados
    if #remotesCatalog > 0 then
        local remotesPath = baseDir .. "/detected_remotes.json"
        pcall(writefileFunc, remotesPath, self:ToJSON(remotesCatalog))
    end

    -- Escribir manifiesto JSON
    local manifestPath = baseDir .. "/manifest.json"
    pcall(writefileFunc, manifestPath, self:ToJSON({
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Timestamp = tick(),
        TotalScriptsExported = writtenScripts,
        TotalRemotesDetected = #remotesCatalog,
        Mode = dumpPackage and dumpPackage.Mode or "Custom",
    }))

    if self.Logger then
        self.Logger:Info("EXPORTER", string.format("Proyecto reconstruido en disco (%d scripts .lua, %d remotes en %s)", writtenScripts, #remotesCatalog, baseDir))
    end

    return true, string.format("%s (%d scripts, %d remotes guardados)", baseDir, writtenScripts, #remotesCatalog)
end

-- =============================================================================
-- SAVEINSTANCE DE ULTRA ALTA VELOCIDAD (.RBXL / .RBXLX)
-- =============================================================================

function ReportExporter:ExportAsSaveInstance(filename, customOptions)
    local saveInstFunc = (typeof(saveinstance) == "function" and saveinstance)
        or (typeof(syn_saveinstance) == "function" and syn_saveinstance)
        or (typeof(save_instance) == "function" and save_instance)
        or (typeof(save_place) == "function" and save_place)

    if not saveInstFunc then
        return false, "Tu ejecutor no dispone de la función nativa 'saveinstance()'. Verifica si tu ejecutor la soporta."
    end

    filename = filename or string.format("Place_%s_%d.rbxl", tostring(game.PlaceId), math.floor(tick()))
    if not filename:match("%.rbxl$") and not filename:match("%.rbxlx$") then
        filename = filename .. ".rbxl"
    end

    -- Configuración afinada para máxima velocidad y evitar congelamientos en Nivel 3-4
    local fastOptions = {
        mode = "optimized",              -- Poda visual rápida para evitar cuelgues
        noscripts = false,               -- Mantener y descompilar scripts
        scriptcache = true,              -- Usar caché para evitar descompilaciones repetidas
        decompile = true,
        timeout = 20,                    -- Máximo 20s por script para no congelar el juego
        SavePlayers = false,             -- Ignorar avatares para aligerar megabytes
        IsolateStarterPlayer = false,
        IsolateLocalPlayer = false,
        IgnoreDefaultProperties = true,  -- No serializar propiedades por defecto (ahorra ~60% de peso)
        IgnoreProperties = { "MeshId", "TextureID" }, -- Salta descargas HTTP lentas de Roblox CDN
        FilePath = filename,
    }

    if type(customOptions) == "table" then
        for k, v in pairs(customOptions) do fastOptions[k] = v end
    end

    local success, err = pcall(saveInstFunc, fastOptions)
    if success then
        if self.Logger then
            self.Logger:Info("EXPORTER", "SaveInstance completado con éxito: " .. filename)
        end
        return true, filename
    else
        return false, "Error al ejecutar saveinstance: " .. tostring(err)
    end
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
