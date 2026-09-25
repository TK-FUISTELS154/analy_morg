--[[
    ═════════════════════════════════════════════════════════════════════════
    COBALT REMOTE SPY - ADVANCED EXPORTER HUB v3.0 (MULTI-REMOTE PICKER)
    ═════════════════════════════════════════════════════════════════════════
    Permite clasificar y seleccionar exactamente qué Remotes capturados exportar:
      • Clasificación por pestañas (Outgoing / Incoming / Todos)
      • Lista de Remotes individuales con conteo de llamadas (x1, x22, etc.)
      • Selección individual, "Seleccionar Todos" y "Deseleccionar Todos"
      • Exportación de: Arguments, Code, Function Info y Response
      • Formatos: .LUA, .JSON y .MD Report
      • Guardado en Archivo (writefile) y Portapapeles (setclipboard)
    ═════════════════════════════════════════════════════════════════════════
--]]

local Exporter = {}
Exporter.__index = Exporter

-- Servicios de Roblox
local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(game.GetService, game, serviceName)
        if success and service then
            local ref = cloneref and cloneref(service) or service
            rawset(self, serviceName, ref)
            return ref
        end
        return nil
    end
})

local HttpService = Services.HttpService
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local CoreGui = Services.CoreGui
local StarterGui = Services.StarterGui
local Players = Services.Players
local LocalPlayer = Players.LocalPlayer

-- Funciones de Exploit / Fallbacks
local writefile = writefile or (wax and wax.shared and wax.shared.writefile)
local setclipboard = setclipboard or toclipboard or (Clipboard and Clipboard.set) or (syn and syn.write_clipboard)
local protect_gui = syn_protect_gui or (syn and syn.protect_gui) or (wax and wax.shared and wax.shared.syn_protect_gui)
local get_hui = gethui or get_hidden_gui or function() return CoreGui end

-- Notificaciones
local function Notify(title, message, duration)
    duration = duration or 4
    if wax and wax.shared and wax.shared.Sonner and wax.shared.Sonner.success then
        wax.shared.Sonner.success(`[Exporter] {message}`)
        return
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Remote Spy Exporter",
            Text = message or "",
            Duration = duration
        })
    end)
end

-- =========================================================================
-- SERIALIZADOR AVANZADO DE DATOS (Roblox Types & Lua Values)
-- =========================================================================
local Serializer = {}

function Serializer.SerializeInstance(instance)
    if not instance or typeof(instance) ~= "Instance" then
        return "nil"
    end
    
    local path = {}
    local current = instance
    while current and current ~= game do
        local parent = current.Parent
        local name = current.Name
        
        local safeName
        if name:match("^[%a_][%w_]*$") and not (name == "Parent" or name == "Value") then
            safeName = "." .. name
        else
            safeName = '["' .. name:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"]'
        end
        table.insert(path, 1, safeName)
        current = parent
    end
    
    if #path == 0 then
        return "game"
    end
    
    local root = path[1]
    local serviceName = root:match('^%.(.*)$') or root:match('^%["(.*)"%]$')
    if serviceName and pcall(game.GetService, game, serviceName) then
        path[1] = string.format('game:GetService("%s")', serviceName)
        return table.concat(path, "")
    end
    
    return "game" .. table.concat(path, "")
end

function Serializer.SerializeValue(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    local valType = typeof(val)
    
    if depth > 10 then
        return '"<Max Depth Reached>"'
    end
    
    if valType == "nil" then
        return "nil"
    elseif valType == "boolean" then
        return tostring(val)
    elseif valType == "number" then
        if val ~= val then return "0/0" end
        if val == math.huge then return "math.huge" end
        if val == -math.huge then return "-math.huge" end
        return tostring(val)
    elseif valType == "string" then
        return string.format("%q", val)
    elseif valType == "Instance" then
        return Serializer.SerializeInstance(val)
    elseif valType == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", tostring(val.X), tostring(val.Y), tostring(val.Z))
    elseif valType == "Vector2" then
        return string.format("Vector2.new(%s, %s)", tostring(val.X), tostring(val.Y))
    elseif valType == "CFrame" then
        local components = {val:GetComponents()}
        return string.format("CFrame.new(%s)", table.concat(components, ", "))
    elseif valType == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.round(val.R * 255), math.round(val.G * 255), math.round(val.B * 255))
    elseif valType == "BrickColor" then
        return string.format('BrickColor.new("%s")', val.Name)
    elseif valType == "UDim" then
        return string.format("UDim.new(%s, %s)", tostring(val.Scale), tostring(val.Offset))
    elseif valType == "UDim2" then
        return string.format("UDim2.new(%s, %s, %s, %s)", tostring(val.X.Scale), tostring(val.X.Offset), tostring(val.Y.Scale), tostring(val.Y.Offset))
    elseif valType == "Ray" then
        return string.format("Ray.new(%s, %s)", Serializer.SerializeValue(val.Origin, depth + 1, visited), Serializer.SerializeValue(val.Direction, depth + 1, visited))
    elseif valType == "NumberRange" then
        return string.format("NumberRange.new(%s, %s)", tostring(val.Min), tostring(val.Max))
    elseif valType == "EnumItem" then
        return tostring(val)
    elseif valType == "ColorSequence" then
        return "ColorSequence.new(...)"
    elseif valType == "NumberSequence" then
        return "NumberSequence.new(...)"
    elseif valType == "DateTime" then
        return string.format("DateTime.fromUnixTimestampMillis(%d)", val.UnixTimestampMillis)
    elseif valType == "table" then
        if visited[val] then
            return '"<Circular Reference>"'
        end
        visited[val] = true
        
        local isArray = true
        local maxIndex = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIndex then maxIndex = k end
            else
                isArray = false
            end
        end
        if isArray and maxIndex ~= count then
            isArray = false
        end
        
        local indent = string.rep("    ", depth + 1)
        local closingIndent = string.rep("    ", depth)
        local entries = {}
        
        if isArray then
            for i = 1, #val do
                table.insert(entries, indent .. Serializer.SerializeValue(val[i], depth + 1, visited))
            end
        else
            for k, v in pairs(val) do
                local keyStr
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. Serializer.SerializeValue(k, depth + 1, visited) .. "]"
                end
                table.insert(entries, string.format("%s%s = %s", indent, keyStr, Serializer.SerializeValue(v, depth + 1, visited)))
            end
        end
        
        visited[val] = nil
        if #entries == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(entries, ",\n") .. "\n" .. closingIndent .. "}"
    elseif valType == "function" then
        return '"function() ... end"'
    else
        return string.format('"%s: %s"', valType, tostring(val))
    end
end

-- =========================================================================
-- MOTOR DE REGISTROS Y EXTRACCIÓN
-- =========================================================================
local Extractor = {}

function Extractor.GetLogsSource()
    local cobaltWax = getgenv().Cobalt or (wax and wax.shared and wax)
    return (cobaltWax and cobaltWax.shared and cobaltWax.shared.Logs) or (wax and wax.shared and wax.shared.Logs)
end

-- Obtiene todos los remotes únicos agrupados por categoría y su lista de llamadas
function Extractor.GetUniqueRemotes(directionTab, searchText)
    local uniqueList = {}
    local logsSource = Extractor.GetLogsSource()
    if not logsSource then return uniqueList end
    
    local categories = {}
    if directionTab == "Outgoing" or directionTab == "All" then
        table.insert(categories, { Name = "Outgoing", Source = logsSource.Outgoing or {} })
    end
    if directionTab == "Incoming" or directionTab == "All" then
        table.insert(categories, { Name = "Incoming", Source = logsSource.Incoming or {} })
    end
    
    for _, cat in ipairs(categories) do
        for id, log in pairs(cat.Source) do
            local inst = log.Instance
            local name = inst and inst.Name or "Unknown"
            local class = inst and inst.ClassName or "RemoteEvent"
            local callCount = (log.Calls and #log.Calls) or 0
            
            local matches = true
            if searchText and searchText ~= "" then
                matches = name:lower():find(searchText:lower(), 1, true) ~= nil
            end
            
            if matches and callCount > 0 then
                local key = string.format("%s_%s_%s", cat.Name, tostring(inst), tostring(id))
                table.insert(uniqueList, {
                    Key = key,
                    Direction = cat.Name,
                    Instance = inst,
                    Name = name,
                    ClassName = class,
                    CallCount = callCount,
                    Log = log,
                    Path = Serializer.SerializeInstance(inst)
                })
            end
        end
    end
    
    -- Ordenar por mayor cantidad de llamadas
    table.sort(uniqueList, function(a, b)
        return a.CallCount > b.CallCount
    end)
    
    return uniqueList
end

function Extractor.GetCallsFromSelectedRemotes(selectedKeys, uniqueRemotesMap, options)
    local callsList = {}
    for key, isSelected in pairs(selectedKeys) do
        if isSelected then
            local remoteData = uniqueRemotesMap[key]
            if remoteData and remoteData.Log and remoteData.Log.Calls then
                for callIndex, call in ipairs(remoteData.Log.Calls) do
                    table.insert(callsList, {
                        Direction = remoteData.Direction,
                        Instance = remoteData.Instance,
                        ClassName = remoteData.ClassName,
                        Name = remoteData.Name,
                        Path = remoteData.Path,
                        CallIndex = callIndex,
                        Call = call,
                        Timestamp = call.Timestamp or os.time(),
                        Method = call.Method or (remoteData.Direction == "Outgoing" and (remoteData.ClassName:find("Function") and "InvokeServer" or "FireServer") or (remoteData.ClassName:find("Function") and "OnClientInvoke" or "OnClientEvent"))
                    })
                end
            end
        end
    end
    
    table.sort(callsList, function(a, b)
        return (a.Timestamp or 0) < (b.Timestamp or 0)
    end)
    
    return callsList
end

function Extractor.BuildCallCode(entry)
    local call = entry.Call
    local path = entry.Path or Serializer.SerializeInstance(entry.Instance)
    local method = entry.Method
    local args = call.Arguments or {}
    
    local serializedArgs = {}
    for _, arg in ipairs(args) do
        table.insert(serializedArgs, Serializer.SerializeValue(arg, 0))
    end
    
    return string.format("%s:%s(%s)", path, method, table.concat(serializedArgs, ", "))
end

function Extractor.BuildFunctionInfo(entry)
    local call = entry.Call
    local info = {}
    
    info["Script Path"] = (call.Origin and Serializer.SerializeInstance(call.Origin)) or (call.Source or "N/A")
    info["Calling Line"] = tostring(call.Line or "N/A")
    info["Calling Source"] = tostring(call.Source or "N/A")
    info["Is Executor"] = tostring(call.IsExecutor or false)
    info["Is Actor"] = tostring(call.IsActor or false)
    
    if call.Function then
        if typeof(call.Function) == "function" then
            info["Closure Type"] = (iscclosure and iscclosure(call.Function)) and "C Closure" or "Luau Closure"
            if debug.getinfo then
                local debugInfo = debug.getinfo(call.Function)
                if debugInfo then
                    info["Function Name"] = (debugInfo.name and debugInfo.name ~= "") and debugInfo.name or "Anonymous"
                    info["Defined Line"] = tostring(debugInfo.linedefined or "N/A")
                end
            end
            if debug.getupvalues then
                local success, uvs = pcall(debug.getupvalues, call.Function)
                info["Upvalues Count"] = success and tostring(#uvs) or "N/A"
            end
            if debug.getconstants then
                local success, consts = pcall(debug.getconstants, call.Function)
                info["Constants Count"] = success and tostring(#consts) or "N/A"
            end
        elseif typeof(call.Function) == "table" then
            info["Function Address"] = call.Function.Address or tostring(call.Function)
            info["Closure Type"] = call.Function.IsC and "C Closure" or "Luau Closure"
        end
    else
        info["Closure Type"] = "Unknown / N/A"
    end
    
    return info
end

function Extractor.BuildResponseInfo(entry)
    local call = entry.Call
    local response = call.InvokeResult or call.Response or call.Returns or call.Result
    if response ~= nil then
        return Serializer.SerializeValue(response, 0)
    end
    return nil
end

-- Generadores de Exportación
function Extractor.GenerateLuaExport(entries, options)
    local lines = {}
    table.insert(lines, "--[[")
    table.insert(lines, "    ═════════════════════════════════════════════════════════════")
    table.insert(lines, "    COBALT REMOTE SPY - CUSTOM EXPORT DUMP")
    table.insert(lines, string.format("    Date: %s", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, string.format("    Place ID: %s | Job ID: %s", tostring(game.PlaceId), game.JobId))
    table.insert(lines, string.format("    Total Calls Exported: %d", #entries))
    table.insert(lines, "    ═════════════════════════════════════════════════════════════")
    table.insert(lines, "--]]\n")
    
    for i, entry in ipairs(entries) do
        table.insert(lines, string.format("-- [%d] -------------------------------------------------------------", i))
        table.insert(lines, string.format("-- Remote: %s (%s)", entry.Name, entry.ClassName))
        table.insert(lines, string.format("-- Direction: %s | Method: %s", entry.Direction, entry.Method))
        table.insert(lines, string.format("-- Path: %s", entry.Path))
        
        -- 1. FUNCTION INFO
        if options.IncludeFunctionInfo then
            table.insert(lines, "\n-- [1. FUNCTION INFO / METADATA]")
            local funcInfo = Extractor.BuildFunctionInfo(entry)
            for k, v in pairs(funcInfo) do
                table.insert(lines, string.format("-- • %s: %s", k, v))
            end
        end
        
        -- 2. ARGUMENTS
        if options.IncludeArguments then
            table.insert(lines, "\n-- [2. ARGUMENTS]")
            local args = entry.Call.Arguments or {}
            table.insert(lines, "local Arguments = " .. Serializer.SerializeValue(args, 0))
        end
        
        -- 3. EXECUTABLE CODE
        if options.IncludeCode then
            table.insert(lines, "\n-- [3. EXECUTABLE SCRIPT]")
            table.insert(lines, Extractor.BuildCallCode(entry))
        end
        
        -- 4. RESPONSE
        if options.IncludeResponse then
            local resp = Extractor.BuildResponseInfo(entry)
            if resp then
                table.insert(lines, "\n-- [4. RESPONSE / RETURN VALUE]")
                table.insert(lines, "local Response = " .. resp)
            else
                table.insert(lines, "\n-- [4. RESPONSE / RETURN VALUE]: (No return value / Event fire)")
            end
        end
        
        table.insert(lines, "\n")
    end
    
    return table.concat(lines, "\n")
end

function Extractor.GenerateJsonExport(entries, options)
    local data = {
        Metadata = {
            GeneratedAt = os.date("%Y-%m-%d %H:%M:%S"),
            PlaceId = game.PlaceId,
            JobId = game.JobId,
            TotalCalls = #entries
        },
        Calls = {}
    }
    
    for i, entry in ipairs(entries) do
        local callData = {
            Index = i,
            Direction = entry.Direction,
            Name = entry.Name,
            ClassName = entry.ClassName,
            Path = entry.Path,
            Method = entry.Method,
            Timestamp = entry.Timestamp
        }
        
        if options.IncludeFunctionInfo then
            callData.FunctionInfo = Extractor.BuildFunctionInfo(entry)
        end
        if options.IncludeArguments then
            callData.Arguments = entry.Call.Arguments or {}
        end
        if options.IncludeCode then
            callData.ExecutableCode = Extractor.BuildCallCode(entry)
        end
        if options.IncludeResponse then
            callData.Response = entry.Call.InvokeResult or entry.Call.Response or entry.Call.Returns or "N/A"
        end
        
        table.insert(data.Calls, callData)
    end
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    return success and encoded or "-- Error encoding JSON"
end

function Extractor.GenerateMarkdownExport(entries, options)
    local lines = {}
    table.insert(lines, "# 🛰️ Cobalt Remote Spy - Capture Report")
    table.insert(lines, string.format("- **Date:** `%s`", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, string.format("- **Place ID:** `%s` | **Job ID:** `%s`", tostring(game.PlaceId), game.JobId))
    table.insert(lines, string.format("- **Total Captured Calls:** `%d`", #entries))
    table.insert(lines, "\n---\n")
    
    for i, entry in ipairs(entries) do
        table.insert(lines, string.format("## Call #%d: `%s` (%s)", i, entry.Name, entry.ClassName))
        table.insert(lines, string.format("- **Direction:** `%s`", entry.Direction))
        table.insert(lines, string.format("- **Path:** `%s`", entry.Path))
        table.insert(lines, string.format("- **Method:** `%s`", entry.Method))
        
        if options.IncludeFunctionInfo then
            table.insert(lines, "\n### 🔍 Function Info")
            local funcInfo = Extractor.BuildFunctionInfo(entry)
            for k, v in pairs(funcInfo) do
                table.insert(lines, string.format("- **%s:** `%s`", k, v))
            end
        end
        
        if options.IncludeArguments then
            table.insert(lines, "\n### 📦 Arguments")
            table.insert(lines, "```lua\n" .. Serializer.SerializeValue(entry.Call.Arguments or {}, 0) .. "\n```")
        end
        
        if options.IncludeCode then
            table.insert(lines, "\n### ⚡ Executable Code")
            table.insert(lines, "```lua\n" .. Extractor.BuildCallCode(entry) .. "\n```")
        end
        
        if options.IncludeResponse then
            local resp = Extractor.BuildResponseInfo(entry)
            table.insert(lines, "\n### 📥 Response / Return Value")
            table.insert(lines, resp and ("```lua\n" .. resp .. "\n```") or "*No return value*")
        end
        
        table.insert(lines, "\n---\n")
    end
    
    return table.concat(lines, "\n")
end

-- =========================================================================
-- INTERFAZ GRÁFICA INTERACTIVA CON CLASIFICADOR Y SELECTOR DE REMOTES
-- =========================================================================
local GUI = {}

function GUI.CreateExporterUI()
    local parent = get_hui()
    local existing = parent:FindFirstChild("Cobalt_Exporter_UI")
    if existing then existing:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Cobalt_Exporter_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    if protect_gui then protect_gui(ScreenGui) end
    ScreenGui.Parent = parent
    
    -- Botón Flotante para Abrir
    local OpenBtn = Instance.new("TextButton")
    OpenBtn.Name = "OpenExporterButton"
    OpenBtn.Size = UDim2.new(0, 130, 0, 36)
    OpenBtn.Position = UDim2.new(1, -145, 0, 15)
    OpenBtn.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
    OpenBtn.BorderSizePixel = 0
    OpenBtn.Font = Enum.Font.GothamBold
    OpenBtn.Text = "📤 Export Hub"
    OpenBtn.TextColor3 = Color3.fromRGB(0, 235, 180)
    OpenBtn.TextSize = 13
    OpenBtn.Parent = ScreenGui
    
    local OpenCorner = Instance.new("UICorner")
    OpenCorner.CornerRadius = UDim.new(0, 8)
    OpenCorner.Parent = OpenBtn
    
    local OpenStroke = Instance.new("UIStroke")
    OpenStroke.Color = Color3.fromRGB(0, 235, 180)
    OpenStroke.Thickness = 1.5
    OpenStroke.Transparency = 0.3
    OpenStroke.Parent = OpenBtn
    
    -- Ventana Principal
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 500, 0, 580)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -290)
    MainFrame.BackgroundColor3 = Color3.fromRGB(16, 17, 23)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Visible = false
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(45, 48, 65)
    MainStroke.Thickness = 1.2
    MainStroke.Parent = MainFrame
    
    -- Topbar
    local Topbar = Instance.new("Frame")
    Topbar.Size = UDim2.new(1, 0, 0, 42)
    Topbar.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
    Topbar.BorderSizePixel = 0
    Topbar.Parent = MainFrame
    
    local TopbarCorner = Instance.new("UICorner")
    TopbarCorner.CornerRadius = UDim.new(0, 10)
    TopbarCorner.Parent = Topbar
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -50, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "⚡ Cobalt Exporter - Selector de Remotes"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Topbar
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -35, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 12
    CloseBtn.Parent = Topbar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    -- Pestañas de Clasificación (Outgoing / Incoming / Todos)
    local TabsFrame = Instance.new("Frame")
    TabsFrame.Size = UDim2.new(1, -24, 0, 34)
    TabsFrame.Position = UDim2.new(0, 12, 0, 50)
    TabsFrame.BackgroundTransparency = 1
    TabsFrame.Parent = MainFrame
    
    local TabsLayout = Instance.new("UIListLayout")
    TabsLayout.FillDirection = Enum.FillDirection.Horizontal
    TabsLayout.Padding = UDim.new(0, 8)
    TabsLayout.Parent = TabsFrame
    
    -- Barra de Búsqueda y Acciones Rápidas
    local ControlBar = Instance.new("Frame")
    ControlBar.Size = UDim2.new(1, -24, 0, 32)
    ControlBar.Position = UDim2.new(0, 12, 0, 90)
    ControlBar.BackgroundTransparency = 1
    ControlBar.Parent = MainFrame
    
    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(0.55, -6, 1, 0)
    SearchBox.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
    SearchBox.BorderSizePixel = 0
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.PlaceholderText = "🔍 Buscar remote..."
    SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.TextSize = 12
    SearchBox.Parent = ControlBar
    
    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 6)
    SearchCorner.Parent = SearchBox
    
    local SelectAllBtn = Instance.new("TextButton")
    SelectAllBtn.Size = UDim2.new(0.22, -4, 1, 0)
    SelectAllBtn.Position = UDim2.new(0.56, 0, 0, 0)
    SelectAllBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
    SelectAllBtn.BorderSizePixel = 0
    SelectAllBtn.Font = Enum.Font.GothamBold
    SelectAllBtn.Text = "☑️ Todos"
    SelectAllBtn.TextColor3 = Color3.fromRGB(0, 235, 180)
    SelectAllBtn.TextSize = 11
    SelectAllBtn.Parent = ControlBar
    
    local SelectAllCorner = Instance.new("UICorner")
    SelectAllCorner.CornerRadius = UDim.new(0, 6)
    SelectAllCorner.Parent = SelectAllBtn
    
    local DeselectAllBtn = Instance.new("TextButton")
    DeselectAllBtn.Size = UDim2.new(0.22, -4, 1, 0)
    DeselectAllBtn.Position = UDim2.new(0.79, 0, 0, 0)
    DeselectAllBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
    DeselectAllBtn.BorderSizePixel = 0
    DeselectAllBtn.Font = Enum.Font.GothamBold
    DeselectAllBtn.Text = "⬜ Ninguno"
    DeselectAllBtn.TextColor3 = Color3.fromRGB(240, 100, 100)
    DeselectAllBtn.TextSize = 11
    DeselectAllBtn.Parent = ControlBar
    
    local DeselectAllCorner = Instance.new("UICorner")
    DeselectAllCorner.CornerRadius = UDim.new(0, 6)
    DeselectAllCorner.Parent = DeselectAllBtn
    
    -- Lista de Remotes con Scroll (Checklist)
    local RemoteListScroll = Instance.new("ScrollingFrame")
    RemoteListScroll.Size = UDim2.new(1, -24, 0, 240)
    RemoteListScroll.Position = UDim2.new(0, 12, 0, 130)
    RemoteListScroll.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    RemoteListScroll.BorderSizePixel = 0
    RemoteListScroll.ScrollBarThickness = 5
    RemoteListScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 235, 180)
    RemoteListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    RemoteListScroll.Parent = MainFrame
    
    local ScrollCorner = Instance.new("UICorner")
    ScrollCorner.CornerRadius = UDim.new(0, 8)
    ScrollCorner.Parent = RemoteListScroll
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 4)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = RemoteListScroll
    
    local ListPadding = Instance.new("UIPadding")
    ListPadding.PaddingTop = UDim.new(0, 6)
    ListPadding.PaddingBottom = UDim.new(0, 6)
    ListPadding.PaddingLeft = UDim.new(0, 6)
    ListPadding.PaddingRight = UDim.new(0, 6)
    ListPadding.Parent = RemoteListScroll
    
    -- Opciones de Datos (Code, Arguments, Function Info, Response)
    local OptionsFrame = Instance.new("Frame")
    OptionsFrame.Size = UDim2.new(1, -24, 0, 60)
    OptionsFrame.Position = UDim2.new(0, 12, 0, 380)
    OptionsFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
    OptionsFrame.BorderSizePixel = 0
    OptionsFrame.Parent = MainFrame
    
    local OptCorner = Instance.new("UICorner")
    OptCorner.CornerRadius = UDim.new(0, 8)
    OptCorner.Parent = OptionsFrame
    
    local OptGrid = Instance.new("UIGridLayout")
    OptGrid.CellSize = UDim2.new(0.48, 0, 0.42, 0)
    OptGrid.CellPadding = UDim2.new(0.04, 0, 0.08, 0)
    OptGrid.Parent = OptionsFrame
    
    local OptPadding = Instance.new("UIPadding")
    OptPadding.PaddingTop = UDim.new(0, 5)
    OptPadding.PaddingLeft = UDim.new(0, 8)
    OptPadding.PaddingRight = UDim.new(0, 8)
    OptPadding.Parent = OptionsFrame
    
    -- Formato y Contador
    local BottomInfoFrame = Instance.new("Frame")
    BottomInfoFrame.Size = UDim2.new(1, -24, 0, 32)
    BottomInfoFrame.Position = UDim2.new(0, 12, 0, 450)
    BottomInfoFrame.BackgroundTransparency = 1
    BottomInfoFrame.Parent = MainFrame
    
    local CounterLabel = Instance.new("TextLabel")
    CounterLabel.Size = UDim2.new(0.45, 0, 1, 0)
    CounterLabel.BackgroundTransparency = 1
    CounterLabel.Font = Enum.Font.GothamBold
    CounterLabel.Text = "Seleccionados: 0 remotes"
    CounterLabel.TextColor3 = Color3.fromRGB(0, 235, 180)
    CounterLabel.TextSize = 12
    CounterLabel.TextXAlignment = Enum.TextXAlignment.Left
    CounterLabel.Parent = BottomInfoFrame
    
    local FormatSelectorFrame = Instance.new("Frame")
    FormatSelectorFrame.Size = UDim2.new(0.52, 0, 1, 0)
    FormatSelectorFrame.Position = UDim2.new(0.48, 0, 0, 0)
    FormatSelectorFrame.BackgroundTransparency = 1
    FormatSelectorFrame.Parent = BottomInfoFrame
    
    local FmtLayout = Instance.new("UIListLayout")
    FmtLayout.FillDirection = Enum.FillDirection.Horizontal
    FmtLayout.Padding = UDim.new(0, 4)
    FmtLayout.Parent = FormatSelectorFrame
    
    -- Botones de Acción
    local BottomBar = Instance.new("Frame")
    BottomBar.Size = UDim2.new(1, -24, 0, 46)
    BottomBar.Position = UDim2.new(0, 12, 1, -56)
    BottomBar.BackgroundTransparency = 1
    BottomBar.Parent = MainFrame
    
    local SaveFileBtn = Instance.new("TextButton")
    SaveFileBtn.Size = UDim2.new(0.48, 0, 1, 0)
    SaveFileBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
    SaveFileBtn.BorderSizePixel = 0
    SaveFileBtn.Font = Enum.Font.GothamBold
    SaveFileBtn.Text = "💾 Guardar Archivo"
    SaveFileBtn.TextColor3 = Color3.fromRGB(15, 25, 20)
    SaveFileBtn.TextSize = 13
    SaveFileBtn.Parent = BottomBar
    
    local SaveCorner = Instance.new("UICorner")
    SaveCorner.CornerRadius = UDim.new(0, 8)
    SaveCorner.Parent = SaveFileBtn
    
    local CopyClipboardBtn = Instance.new("TextButton")
    CopyClipboardBtn.Size = UDim2.new(0.48, 0, 1, 0)
    CopyClipboardBtn.Position = UDim2.new(0.52, 0, 0, 0)
    CopyClipboardBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 250)
    CopyClipboardBtn.BorderSizePixel = 0
    CopyClipboardBtn.Font = Enum.Font.GothamBold
    CopyClipboardBtn.Text = "📋 Copiar Todo"
    CopyClipboardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyClipboardBtn.TextSize = 13
    CopyClipboardBtn.Parent = BottomBar
    
    local CopyCorner = Instance.new("UICorner")
    CopyCorner.CornerRadius = UDim.new(0, 8)
    CopyCorner.Parent = CopyClipboardBtn
    
    -- =====================================================================
    -- ESTADOS Y LÓGICA DINÁMICA
    -- =====================================================================
    local CurrentTab = "Outgoing"
    local SelectedKeys = {}
    local UniqueRemotesMap = {}
    local FilterOptions = {
        IncludeCode = true,
        IncludeArguments = true,
        IncludeFunctionInfo = true,
        IncludeResponse = true,
        Format = "Lua"
    }
    
    local function CreateMiniToggle(parent, labelText, defaultVal, callback)
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = defaultVal and Color3.fromRGB(0, 180, 130) or Color3.fromRGB(45, 48, 62)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Text = (defaultVal and "✓ " or "✕ ") .. labelText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 11
        btn.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn
        
        local val = defaultVal
        btn.MouseButton1Click:Connect(function()
            val = not val
            btn.Text = (val and "✓ " or "✕ ") .. labelText
            btn.BackgroundColor3 = val and Color3.fromRGB(0, 180, 130) or Color3.fromRGB(45, 48, 62)
            callback(val)
        end)
    end
    
    CreateMiniToggle(OptionsFrame, "Code (Script)", true, function(v) FilterOptions.IncludeCode = v end)
    CreateMiniToggle(OptionsFrame, "Arguments", true, function(v) FilterOptions.IncludeArguments = v end)
    CreateMiniToggle(OptionsFrame, "Function Info", true, function(v) FilterOptions.IncludeFunctionInfo = v end)
    CreateMiniToggle(OptionsFrame, "Response", true, function(v) FilterOptions.IncludeResponse = v end)
    
    -- Botones de formato
    local formatButtons = {}
    local function UpdateFormat(fmt)
        FilterOptions.Format = fmt
        for f, b in pairs(formatButtons) do
            b.BackgroundColor3 = (f == fmt) and Color3.fromRGB(0, 200, 150) or Color3.fromRGB(30, 32, 44)
            b.TextColor3 = (f == fmt) and Color3.fromRGB(15, 25, 20) or Color3.fromRGB(200, 200, 215)
        end
    end
    
    for _, fmt in ipairs({"Lua", "JSON", "Markdown"}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.31, 0, 1, 0)
        b.BackgroundColor3 = (fmt == "Lua") and Color3.fromRGB(0, 200, 150) or Color3.fromRGB(30, 32, 44)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.Text = (fmt == "Lua" and ".LUA") or (fmt == "JSON" and ".JSON") or ".MD"
        b.TextColor3 = (fmt == "Lua") and Color3.fromRGB(15, 25, 20) or Color3.fromRGB(200, 200, 215)
        b.TextSize = 11
        b.Parent = FormatSelectorFrame
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = b
        
        formatButtons[fmt] = b
        b.MouseButton1Click:Connect(function() UpdateFormat(fmt) end)
    end
    
    -- Renderizar Lista de Remotes
    local function RenderRemoteList()
        -- Limpiar items anteriores
        for _, child in ipairs(RemoteListScroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local list = Extractor.GetUniqueRemotes(CurrentTab, SearchBox.Text)
        UniqueRemotesMap = {}
        local totalSelected = 0
        local totalCalls = 0
        
        for _, item in ipairs(list) do
            UniqueRemotesMap[item.Key] = item
            if SelectedKeys[item.Key] == nil then
                SelectedKeys[item.Key] = true -- Seleccionados por defecto al aparecer
            end
            if SelectedKeys[item.Key] then
                totalSelected = totalSelected + 1
                totalCalls = totalCalls + item.CallCount
            end
            
            local row = Instance.new("TextButton")
            row.Name = item.Key
            row.Size = UDim2.new(1, 0, 0, 32)
            row.BackgroundColor3 = SelectedKeys[item.Key] and Color3.fromRGB(28, 38, 45) or Color3.fromRGB(24, 26, 35)
            row.BorderSizePixel = 0
            row.AutoButtonColor = true
            row.Text = ""
            row.Parent = RemoteListScroll
            
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row
            
            local rowStroke = Instance.new("UIStroke")
            rowStroke.Color = SelectedKeys[item.Key] and Color3.fromRGB(0, 235, 180) or Color3.fromRGB(38, 41, 55)
            rowStroke.Thickness = 1
            rowStroke.Transparency = SelectedKeys[item.Key] and 0.4 or 0.8
            rowStroke.Parent = row
            
            -- Checkbox Icon
            local CheckBox = Instance.new("TextLabel")
            CheckBox.Size = UDim2.new(0, 20, 1, 0)
            CheckBox.Position = UDim2.new(0, 8, 0, 0)
            CheckBox.BackgroundTransparency = 1
            CheckBox.Font = Enum.Font.GothamBold
            CheckBox.Text = SelectedKeys[item.Key] and "☑" or "☐"
            CheckBox.TextColor3 = SelectedKeys[item.Key] and Color3.fromRGB(0, 235, 180) or Color3.fromRGB(140, 145, 160)
            CheckBox.TextSize = 14
            CheckBox.Parent = row
            
            -- Icono Tipo
            local Icon = Instance.new("TextLabel")
            Icon.Size = UDim2.new(0, 20, 1, 0)
            Icon.Position = UDim2.new(0, 30, 0, 0)
            Icon.BackgroundTransparency = 1
            Icon.Font = Enum.Font.GothamBold
            Icon.Text = item.ClassName:find("Function") and "🔄" or "⚡"
            Icon.TextColor3 = Color3.fromRGB(255, 160, 50)
            Icon.TextSize = 12
            Icon.Parent = row
            
            -- Nombre del Remote
            local NameLabel = Instance.new("TextLabel")
            NameLabel.Size = UDim2.new(1, -110, 1, 0)
            NameLabel.Position = UDim2.new(0, 54, 0, 0)
            NameLabel.BackgroundTransparency = 1
            NameLabel.Font = Enum.Font.GothamBold
            NameLabel.Text = item.Name
            NameLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
            NameLabel.TextSize = 12
            NameLabel.TextXAlignment = Enum.TextXAlignment.Left
            NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            NameLabel.Parent = row
            
            -- Badge de Conteo (x1, x22)
            local CountBadge = Instance.new("TextLabel")
            CountBadge.Size = UDim2.new(0, 46, 0, 20)
            CountBadge.Position = UDim2.new(1, -52, 0.5, -10)
            CountBadge.BackgroundColor3 = Color3.fromRGB(36, 40, 54)
            CountBadge.BorderSizePixel = 0
            CountBadge.Font = Enum.Font.GothamBold
            CountBadge.Text = string.format("x%d", item.CallCount)
            CountBadge.TextColor3 = Color3.fromRGB(255, 180, 50)
            CountBadge.TextSize = 11
            CountBadge.Parent = row
            
            local badgeCorner = Instance.new("UICorner")
            badgeCorner.CornerRadius = UDim.new(0, 4)
            badgeCorner.Parent = CountBadge
            
            -- Toggle al hacer clic
            row.MouseButton1Click:Connect(function()
                SelectedKeys[item.Key] = not SelectedKeys[item.Key]
                CheckBox.Text = SelectedKeys[item.Key] and "☑" or "☐"
                CheckBox.TextColor3 = SelectedKeys[item.Key] and Color3.fromRGB(0, 235, 180) or Color3.fromRGB(140, 145, 160)
                row.BackgroundColor3 = SelectedKeys[item.Key] and Color3.fromRGB(28, 38, 45) or Color3.fromRGB(24, 26, 35)
                rowStroke.Color = SelectedKeys[item.Key] and Color3.fromRGB(0, 235, 180) or Color3.fromRGB(38, 41, 55)
                
                -- Actualizar contador
                local selCount = 0
                for _, it in ipairs(list) do
                    if SelectedKeys[it.Key] then selCount = selCount + 1 end
                end
                CounterLabel.Text = string.format("Seleccionados: %d / %d remotes", selCount, #list)
            end)
        end
        
        RemoteListScroll.CanvasSize = UDim2.new(0, 0, 0, #list * 36 + 12)
        CounterLabel.Text = string.format("Seleccionados: %d / %d remotes (%d calls)", totalSelected, #list, totalCalls)
    end
    
    -- Pestañas de Clasificación
    local tabButtons = {}
    local function SetTab(tabName)
        CurrentTab = tabName
        for name, b in pairs(tabButtons) do
            if name == tabName then
                b.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
                b.TextColor3 = Color3.fromRGB(15, 25, 20)
            else
                b.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
                b.TextColor3 = Color3.fromRGB(200, 200, 215)
            end
        end
        RenderRemoteList()
    end
    
    for _, tab in ipairs({"Outgoing", "Incoming", "All"}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.31, 0, 1, 0)
        b.BackgroundColor3 = (tab == "Outgoing") and Color3.fromRGB(0, 200, 150) or Color3.fromRGB(24, 26, 36)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.Text = (tab == "Outgoing" and "📤 Outgoing") or (tab == "Incoming" and "📥 Incoming") or "🌐 Todos"
        b.TextColor3 = (tab == "Outgoing") and Color3.fromRGB(15, 25, 20) or Color3.fromRGB(200, 200, 215)
        b.TextSize = 11
        b.Parent = TabsFrame
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = b
        
        tabButtons[tab] = b
        b.MouseButton1Click:Connect(function() SetTab(tab) end)
    end
    
    -- Botones Seleccionar / Deseleccionar Todos
    SelectAllBtn.MouseButton1Click:Connect(function()
        local list = Extractor.GetUniqueRemotes(CurrentTab, SearchBox.Text)
        for _, it in ipairs(list) do
            SelectedKeys[it.Key] = true
        end
        RenderRemoteList()
    end)
    
    DeselectAllBtn.MouseButton1Click:Connect(function()
        local list = Extractor.GetUniqueRemotes(CurrentTab, SearchBox.Text)
        for _, it in ipairs(list) do
            SelectedKeys[it.Key] = false
        end
        RenderRemoteList()
    end)
    
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        RenderRemoteList()
    end)
    
    -- Lógica de Exportación
    local function DoExport(destination)
        local calls = Extractor.GetCallsFromSelectedRemotes(SelectedKeys, UniqueRemotesMap, FilterOptions)
        if #calls == 0 then
            Notify("Cobalt Exporter", "No has seleccionado ningún remote con llamadas para exportar.", 4)
            return
        end
        
        local output = ""
        local ext = "lua"
        if FilterOptions.Format == "Lua" then
            output = Extractor.GenerateLuaExport(calls, FilterOptions)
            ext = "lua"
        elseif FilterOptions.Format == "JSON" then
            output = Extractor.GenerateJsonExport(calls, FilterOptions)
            ext = "json"
        elseif FilterOptions.Format == "Markdown" then
            output = Extractor.GenerateMarkdownExport(calls, FilterOptions)
            ext = "md"
        end
        
        local fileName = string.format("Cobalt_Export_%s_%s.%s", tostring(game.PlaceId), os.date("%Y%m%d_%H%M%S"), ext)
        
        if destination == "File" then
            if writefile then
                local success, err = pcall(writefile, fileName, output)
                if success then
                    Notify("Guardado con Éxito", string.format("Exportadas %d llamadas a '%s'", #calls, fileName), 5)
                else
                    Notify("Error al Guardar", tostring(err), 5)
                end
            else
                Notify("Aviso", "writefile no disponible. Copiando al portapapeles...", 4)
                if setclipboard then setclipboard(output) end
            end
        elseif destination == "Clipboard" then
            if setclipboard then
                local success, err = pcall(setclipboard, output)
                if success then
                    Notify("Portapapeles", string.format("¡%d llamadas copiadas al portapapeles!", #calls), 4)
                else
                    Notify("Error", "No se pudo copiar", 4)
                end
            end
        end
    end
    
    SaveFileBtn.MouseButton1Click:Connect(function() DoExport("File") end)
    CopyClipboardBtn.MouseButton1Click:Connect(function() DoExport("Clipboard") end)
    
    -- Apertura y Cierre
    OpenBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
        if MainFrame.Visible then
            RenderRemoteList()
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)
    
    Notify("Cobalt Exporter", "Export Hub v3.0 listo. Haz clic en '📤 Export Hub'.", 5)
end

task.spawn(function()
    task.wait(1)
    pcall(GUI.CreateExporterUI)
end)

return Exporter
