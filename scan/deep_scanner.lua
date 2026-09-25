-- ==========================================================
-- DEEP MANUAL SCANNER (Action Logger + Remote Spy + Decompiler)
-- Ingeniería Inversa Avanzada para Roblox
-- ==========================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================================
-- 1. BYPASS DE LIMPIEZA DE GUI
-- ==========================================================
local function getSecureGuiParent()
    local success, result = pcall(function()
        if cloneref then return cloneref(CoreGui) else return CoreGui end
    end)
    if success and result then
        local testGui = Instance.new("ScreenGui")
        local canParent = pcall(function() testGui.Parent = result end)
        if canParent then testGui:Destroy(); return result end
        testGui:Destroy()
    end
    return PlayerGui
end

local secureParent = getSecureGuiParent()
if secureParent:FindFirstChild("DeepScannerPro") then
    secureParent.DeepScannerPro:Destroy()
end

-- ==========================================================
-- 2. VARIABLES DE GRABACIÓN Y FILTROS
-- ==========================================================
local isRecording = false
local recordingLog = {}
local actionCounter = 0
local startTime = 0

-- Variables Contextuales
local lastActionTime = 0
local lastActionContext = "NONE"

-- Filtros Inteligentes (Anti-Spam)
local remoteFrequencies = {}
local SPAM_THRESHOLD = 5 -- Remotes disparados >5 veces por segundo se consideran Spam
local decompiledCache = {}

local inputConnection = nil

-- ==========================================================
-- 3. INTERFAZ GRÁFICA
-- ==========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeepScannerPro"
ScreenGui.DisplayOrder = 999999
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = secureParent

local MainPanel = Instance.new("Frame")
MainPanel.Size = UDim2.new(0, 260, 0, 160)
MainPanel.Position = UDim2.new(1, -280, 0, 20)
MainPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainPanel.BackgroundTransparency = 0.1
MainPanel.BorderSizePixel = 0
MainPanel.Active = true
MainPanel.Draggable = true
MainPanel.Parent = ScreenGui

Instance.new("UICorner", MainPanel).CornerRadius = UDim.new(0, 8)
local UIStroke = Instance.new("UIStroke", MainPanel)
UIStroke.Color = Color3.fromRGB(200, 0, 0)
UIStroke.Thickness = 2

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.Text = " 🕵️ DEEP SCANNER PRO"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Parent = MainPanel

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 30)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Code
StatusLabel.Text = "Esperando..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 12
StatusLabel.Parent = MainPanel

local RecordBtn = Instance.new("TextButton")
RecordBtn.Size = UDim2.new(1, -20, 0, 40)
RecordBtn.Position = UDim2.new(0, 10, 0, 60)
RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
RecordBtn.Font = Enum.Font.GothamBold
RecordBtn.Text = "▶ INICIAR GRABACIÓN"
RecordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RecordBtn.TextSize = 14
RecordBtn.Parent = MainPanel
Instance.new("UICorner", RecordBtn).CornerRadius = UDim.new(0, 5)

local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(1, -20, 0, 40)
StopBtn.Position = UDim2.new(0, 10, 0, 110)
StopBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
StopBtn.Font = Enum.Font.GothamBold
StopBtn.Text = "⏹ DETENER Y EXPORTAR"
StopBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
StopBtn.TextSize = 14
StopBtn.Parent = MainPanel
Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0, 5)

-- ==========================================================
-- 4. HERRAMIENTAS DE EXTRACCIÓN
-- ==========================================================

local function formatTimeElapsed()
    local t = tick() - startTime
    return string.format("%.2f", t)
end

local function addToLog(logType, content)
    local entry = string.format("[%s] [%s] %s", formatTimeElapsed(), logType, content)
    table.insert(recordingLog, entry)
    actionCounter += 1
    StatusLabel.Text = "Eventos grabados: " .. actionCounter
end

local function getPath(instance)
    if not instance then return "nil" end
    local path = instance.Name
    local current = instance.Parent
    while current and current ~= game do
        if string.match(current.Name, "^[%w_]+$") then
            path = current.Name .. "." .. path
        else
            path = current.Name .. '["' .. path .. '"]'
        end
        current = current.Parent
    end
    return path
end

-- Tecnología de decompilación exacta del Dumper
local function decompileScriptSource(scriptObj)
	local source = nil
	if typeof(decompile) == "function" then pcall(function() source = decompile(scriptObj) end) end
	if not source and typeof(getscriptbytecode) == "function" then source = "-- Bytecode extraído (El ejecutor soporta bytecode pero no decompile)" end
	return source or "-- [No se pudo decompilar. Tu ejecutor carece de decompile()]"
end

-- Busca código en LocalScripts dentro del elemento
local function tryDecompile(guiElement)
    local scriptsFound = {}
    
    -- Buscar scripts hijos directos
    for _, child in pairs(guiElement:GetChildren()) do
        if child:IsA("LocalScript") or child:IsA("ModuleScript") then
            table.insert(scriptsFound, child)
        end
    end
    
    -- Si no hay hijos directos, buscamos en el ancestro más cercano que tenga scripts
    if #scriptsFound == 0 and guiElement.Parent then
        for _, child in pairs(guiElement.Parent:GetChildren()) do
            if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                table.insert(scriptsFound, child)
            end
        end
    end
    
    for _, scr in pairs(scriptsFound) do
        local path = getPath(scr)
        if not decompiledCache[path] then
            decompiledCache[path] = true
            local code = decompileScriptSource(scr)
            addToLog("DECOMPILED", string.format("Script %s:\n```lua\n%s\n```", path, code))
        end
    end
end

-- ==========================================================
-- 5. REMOTE SPY (Hooking __namecall)
-- ==========================================================
local oldNamecall
local hookSuccess, hookError = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if isRecording and (method == "FireServer" or method == "InvokeServer") then
            local remoteName = self.Name
            
            -- Anti-Spam: Calculamos frecuencia
            local currentTime = tick()
            if not remoteFrequencies[remoteName] then
                remoteFrequencies[remoteName] = {count = 0, lastCheck = currentTime}
            end
            
            local freqData = remoteFrequencies[remoteName]
            freqData.count += 1
            
            if currentTime - freqData.lastCheck >= 1.0 then
                freqData.lastCheck = currentTime
                if freqData.count > SPAM_THRESHOLD then
                    -- Es spam, lo ignoramos este segundo
                    freqData.count = 0
                    return oldNamecall(self, ...)
                end
                freqData.count = 0
            end
            
            -- Filtro Contextual: Solo grabamos si ocurrió <= 0.5s después de una acción del usuario
            local timeSinceAction = currentTime - lastActionTime
            local isContextual = timeSinceAction <= 0.5
            
            if isContextual or freqData.count <= SPAM_THRESHOLD then
                -- Serializar argumentos
                local argsStr = ""
                for i, arg in pairs(args) do
                    local argType = typeof(arg)
                    local val = tostring(arg)
                    if argType == "Instance" then
                        val = "Instance(" .. getPath(arg) .. ")"
                    elseif argType == "string" then
                        val = '"' .. val .. '"'
                    end
                    argsStr = argsStr .. val .. (i < #args and ", " or "")
                end
                
                local contextStr = isContextual and string.format(" (Causa: %s, %.2fs)", lastActionContext, timeSinceAction) or ""
                addToLog("REMOTE", string.format("%s:%s(%s)%s", getPath(self), method, argsStr, contextStr))
            end
        end
        
        return oldNamecall(self, ...)
    end)
end)

if not hookSuccess then
    print("[WARNING] Tu ejecutor no soporta hookmetamethod. Remote Spy desactivado.")
end

-- ==========================================================
-- 6. CONTROLADOR DE GRABACIÓN
-- ==========================================================
RecordBtn.MouseButton1Click:Connect(function()
    if isRecording then return end
    isRecording = true
    recordingLog = {}
    actionCounter = 0
    startTime = tick()
    
    table.insert(recordingLog, "=== INICIO DE GRABACIÓN DEEP SCANNER ===")
    
    RecordBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    RecordBtn.Text = "🔴 GRABANDO..."
    StatusLabel.Text = "Eventos grabados: 0"
    
    -- Listener de Clics y Teclas
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isRecording then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Registrar Clic en UI
            local mousePos = UserInputService:GetMouseLocation()
            local guiObjects = PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
            
            local clickedElement = nil
            for _, obj in ipairs(guiObjects) do
                if not obj:IsDescendantOf(ScreenGui) then
                    clickedElement = obj
                    break
                end
            end
            
            if clickedElement then
                lastActionTime = tick()
                lastActionContext = "CLICK"
                local path = getPath(clickedElement)
                addToLog("CLICK UI", path .. " | Clase: " .. clickedElement.ClassName)
                
                -- Intentar descompilar scripts asociados
                task.spawn(tryDecompile, clickedElement)
            end
            
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            -- Registrar Tecla
            lastActionTime = tick()
            lastActionContext = "KEYBOARD"
            addToLog("KEYBOARD", "Tecla presionada: " .. tostring(input.KeyCode.Name))
        end
    end)
end)

StopBtn.MouseButton1Click:Connect(function()
    if not isRecording then return end
    isRecording = false
    
    if inputConnection then inputConnection:Disconnect() end
    
    RecordBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    RecordBtn.Text = "▶ INICIAR GRABACIÓN"
    StatusLabel.Text = "Exportando log..."
    
    table.insert(recordingLog, "=== FIN DE GRABACIÓN ===")
    local finalText = table.concat(recordingLog, "\n")
    
    -- Exportar al portapapeles
    if typeof(setclipboard) == "function" then
        pcall(function() setclipboard(finalText) end)
    end
    
    -- Intentar guardar archivo (Para ejecutores compatibles como Synapse/Krnl/Wave)
    if typeof(writefile) == "function" then
        local fileName = "DeepScanner_" .. math.floor(tick()) .. ".txt"
        local s, err = pcall(function() writefile(fileName, finalText) end)
        if s then
            StatusLabel.Text = "¡Guardado en workspace como " .. fileName .. "!"
        else
            StatusLabel.Text = "Error al guardar: " .. tostring(err)
        end
    else
        StatusLabel.Text = "¡Copiado al Portapapeles! (writefile no soportado)"
    end
    
    -- Imprimir en consola F9 como respaldo
    print("\n================== DEEP SCANNER LOG ==================")
    print(finalText)
    print("======================================================")
    
    task.wait(3)
    StatusLabel.Text = "Esperando..."
end)

print("Deep Scanner Pro cargado. Busca la interfaz en la esquina superior derecha.")
