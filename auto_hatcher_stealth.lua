--[[
	AUTO HATCHER (STEALTH MODE)
	Diseñado para bloquear la visibilidad de la ventana de resultados y detenerse al encontrar el objetivo.
]]

-- ==============================================================================
-- 🛡️ STEALTH GUARD - GOD-TIER GUI PROTECTION (Exploit-Agnostic)
-- Módulo Reutilizable: Cópialo y pégalo al inicio de tus scripts.
-- ==============================================================================
local StealthGuard = {}

function StealthGuard.createSecureGui(optionalName)
    local function safeService(serviceName)
        local success, s = pcall(function() return game:GetService(serviceName) end)
        if not success then return nil end
        return (typeof(cloneref) == "function" and cloneref(s)) or s
    end

    local safeCoreGui = safeService("CoreGui")
    
    local function generateInvisibleName()
        local str = ""
        for i = 1, math.random(15, 25) do
            str = str .. string.char(math.random(128, 255))
        end
        return str
    end

    local finalGuiName = optionalName or generateInvisibleName()

    local gui = Instance.new("ScreenGui")
    gui.Name = finalGuiName
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2e9
    gui.IgnoreGuiInset = true
    gui.Archivable = false
    
    local hasGetHui, hui = pcall(function() return gethui() or get_hidden_gui() end)
    local hasProtectGui, protectGuiFunc = pcall(function() return (syn and syn.protect_gui) or protect_gui or protectgui end)
    
    if hasGetHui and typeof(hui) == "Instance" then
        gui.Parent = hui
    elseif hasProtectGui and type(protectGuiFunc) == "function" then
        pcall(function() protectGuiFunc(gui) end)
        gui.Parent = safeCoreGui
    elseif safeCoreGui and safeCoreGui:FindFirstChild("RobloxGui") then
        gui.Parent = safeCoreGui.RobloxGui
    elseif safeCoreGui then
        gui.Parent = safeCoreGui
    else
        local Players = safeService("Players")
        if Players and Players.LocalPlayer then
            gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
        end
    end

    pcall(function()
        if hookmetamethod then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if not checkcaller() and (method == "FindFirstChild" or method == "WaitForChild") then
                    if args[1] == finalGuiName then return nil end
                end
                
                if not checkcaller() and (method == "GetDescendants" or method == "GetChildren") then
                    local result = oldNamecall(self, ...)
                    if type(result) == "table" then
                        local cleanResult = {}
                        for _, v in ipairs(result) do
                            if v ~= gui then table.insert(cleanResult, v) end
                        end
                        return cleanResult
                    end
                end
                
                return oldNamecall(self, ...)
            end))
            
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, idx)
                if not checkcaller() and idx == finalGuiName then return nil end
                return oldIndex(self, idx)
            end))
        end
    end)
    
    return gui
end
-- ==============================================================================

-- Llamar al módulo en la primera línea de ejecución
local screenGui = StealthGuard.createSecureGui()
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")



-- Crear la GUI principal con diseño profesional
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 360, 0, 350)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
title.Text = " 🕵️ AUTO HATCHER (STEALTH)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Estado: Detenido"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = mainFrame

local itemMenu = Instance.new("ScrollingFrame")
itemMenu.Size = UDim2.new(1, -20, 0, 200)
itemMenu.Position = UDim2.new(0, 10, 0, 70)
itemMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
itemMenu.ScrollBarThickness = 4
itemMenu.CanvasSize = UDim2.new(0, 0, 0, 0)
itemMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemMenu.Parent = mainFrame
Instance.new("UICorner", itemMenu).CornerRadius = UDim.new(0, 6)

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 50, 0, 50)
gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = itemMenu

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -20, 0, 40)
startBtn.Position = UDim2.new(0, 10, 0, 290)
startBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
startBtn.Text = "▶ INICIAR"
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.Parent = mainFrame
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

-- Funciones para encontrar los elementos específicos
local function getHatchButton()
    local s = PlayerGui:FindFirstChild("ScreenGui")
    if s then
        local container = s:FindFirstChild("Event")
            and s.Event:FindFirstChild("Main")
            and s.Event.Main:FindFirstChild("_NewHatch")
            and s.Event.Main._NewHatch:FindFirstChild("RightFrame")
            and s.Event.Main._NewHatch.RightFrame:FindFirstChild("BottomFrame")
            and s.Event.Main._NewHatch.RightFrame.BottomFrame:FindFirstChild("_NiuDanHatchBtn")
        if container then
            return container:FindFirstChild("Btn") or container
        end
    end
    return nil
end

local function getNewHatchPop()
    local s = PlayerGui:FindFirstChild("ScreenGui")
    if s then return s:FindFirstChild("NewHatchPop") end
    return nil
end

local VirtualInputManager = game:GetService("VirtualInputManager")

-- Función genérica y precisa para simular clics
local function fireClick(buttonInstance)
    -- Método 1: Simulación Física por Coordenadas (VIM)
    if buttonInstance.AbsolutePosition.X > 0 and buttonInstance.AbsolutePosition.Y > 0 then
        pcall(function()
            local guiInset = game:GetService("GuiService"):GetGuiInset()
            -- Agregar un poco de "jitter" aleatorio (-15 a 15 píxeles) para no hacer clic siempre en el pixel exacto (evade anti-macros)
            local offsetX = math.random(-15, 15)
            local offsetY = math.random(-10, 10)
            
            local x = buttonInstance.AbsolutePosition.X + (buttonInstance.AbsoluteSize.X / 2) + offsetX
            local y = buttonInstance.AbsolutePosition.Y + (buttonInstance.AbsoluteSize.Y / 2) + guiInset.Y + offsetY
            
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            -- El tiempo que un humano mantiene presionado el botón varía ligeramente
            task.wait(math.random(3, 8) / 100)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
    end

    -- Método 2: Señales nativas (Respaldos)
    local events = {"MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated"}
    if typeof(getconnections) == "function" then
        for _, ev in ipairs(events) do
            pcall(function()
                for _, conn in ipairs(getconnections(buttonInstance[ev])) do
                    pcall(function() conn:Fire() end)
                    pcall(function() conn.Function() end)
                end
            end)
        end
    end
    if typeof(firesignal) == "function" then
        for _, ev in ipairs(events) do
            pcall(function() firesignal(buttonInstance[ev]) end)
        end
        pcall(function() firesignal(buttonInstance.InputBegan, {UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin}) end)
        pcall(function() firesignal(buttonInstance.InputEnded, {UserInputType = Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.End}) end)
    end
end

local function getHatchInfoFrame()
    local s = PlayerGui:FindFirstChild("ScreenGui")
    if s then
        local frame = s:FindFirstChild("Event")
            and s.Event:FindFirstChild("Main")
            and s.Event.Main:FindFirstChild("_NewHatch")
            and s.Event.Main._NewHatch:FindFirstChild("_HatchInfoFrame")
        return frame
    end
    return nil
end

-- Variables Globales de Selección
local isRunning = false
local selectedTargetName = ""
local selectedTargetImage = ""
local selectedTargetModel = ""
local selectedTargetText = ""
local selectedBtnUI = nil

-- Función para obtener el nombre del modelo 3D dentro de un ViewportFrame
local function getViewportModelName(vp)
    for _, child in ipairs(vp:GetDescendants()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            return child.Name
        end
    end
    return ""
end

-- (Ya no se necesita isIgnored global porque se limpia dentro del clon)

-- Función para popular el menú con imágenes
local function populateMenu()
    local infoFrame = getHatchInfoFrame()
    if not infoFrame then
        statusLabel.Text = "Error: No se encontró _HatchInfoFrame"
        return
    end
    
    local scroll = infoFrame:FindFirstChild("_AwardInfoScroll")
    local scanTarget = scroll or infoFrame
    
    -- Limpiar menu actual
    for _, child in ipairs(itemMenu:GetChildren()) do
        if child:IsA("ImageButton") then child:Destroy() end
    end
    
    -- Usar un diccionario para evitar duplicados
    local addedTargets = {}
    
    for _, award in ipairs(scanTarget:GetChildren()) do
        if string.find(award.Name, "AwardInfo_") then
            local targetName = award.Name
            
            if not addedTargets[targetName] then
                addedTargets[targetName] = true
                
                local targetSize = award.AbsoluteSize
                local hasSize = targetSize.X > 0 and targetSize.Y > 0
                
                -- Ajustar la grilla entera al tamaño real de la mascota del juego
                if hasSize and gridLayout.CellSize.X.Offset == 50 then
                    gridLayout.CellSize = UDim2.new(0, targetSize.X, 0, targetSize.Y)
                end
                
                -- Crear botón visual contenedor
                local btn = Instance.new("ImageButton")
                if hasSize then
                    btn.Size = UDim2.new(0, targetSize.X, 0, targetSize.Y)
                else
                    btn.Size = UDim2.new(0, 100, 0, 100)
                end
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                btn.Parent = itemMenu
                
                -- Clonar el contenedor ORIGINAL entero
                local clone = award:Clone()
                
                -- Mantener su escala original sin deformar
                clone.Size = UDim2.new(1, 0, 1, 0)
                clone.Position = UDim2.new(0, 0, 0, 0)
                clone.AnchorPoint = Vector2.new(0, 0)
                
                -- Evitar que el clon intercepte los clics de nuestro botón
                if clone:IsA("GuiButton") then clone.Active = false clone.AutoButtonColor = false end
                
                -- Limpiar basura visual (candados, marcas de obtenido, etc) del clon
                for _, child in ipairs(clone:GetDescendants()) do
                    local n = string.lower(child.Name)
                    local p = child.Parent and string.lower(child.Parent.Name) or ""
                    if string.find(n, "已抽中") or string.find(p, "已抽中") 
                       or string.find(n, "unlock") or string.find(p, "unlock")
                       or string.find(n, "exit") or string.find(p, "exit") then
                        pcall(function() child:Destroy() end)
                    end
                end
                
                clone.Parent = btn
                
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                
                local uiStroke = Instance.new("UIStroke")
                uiStroke.Color = Color3.fromRGB(255, 200, 0)
                uiStroke.Thickness = 2
                uiStroke.Transparency = 1
                uiStroke.Parent = btn
                
                -- Botón invisible encima de todo para atrapar el clic
                local clickCatcher = Instance.new("TextButton")
                clickCatcher.Size = UDim2.new(1, 0, 1, 0)
                clickCatcher.BackgroundTransparency = 1
                clickCatcher.Text = ""
                clickCatcher.ZIndex = 100
                clickCatcher.Parent = btn
                
                clickCatcher.MouseButton1Click:Connect(function()
                    if isRunning then return end
                    
                    selectedTargetName = targetName
                    selectedTargetModel = ""
                    selectedTargetImage = ""
                    selectedTargetText = ""
                    
                    -- Leer los datos de rastreo de la interfaz ORIGINAL (no del clon) en el momento exacto del clic
                    -- Esto asegura que el modelo 3D ya haya cargado si el juego lo hizo de forma diferida.
                    for _, child in ipairs(award:GetDescendants()) do
                        local n = string.lower(child.Name)
                        if n == "viewportframe" and child:IsA("ViewportFrame") then
                            selectedTargetModel = getViewportModelName(child)
                        elseif n == "viewportframeshadow" and (child:IsA("ImageLabel") or child:IsA("ImageButton")) then
                            selectedTargetImage = child.Image
                        elseif n == "name" and child:IsA("TextLabel") then
                            selectedTargetText = child.Text
                        end
                    end
                    
                    statusLabel.Text = "Seleccionado: " .. selectedTargetName
                    
                    if selectedBtnUI then
                        selectedBtnUI.UIStroke.Transparency = 1
                    end
                    selectedBtnUI = btn
                    selectedBtnUI.UIStroke.Transparency = 0
                end)
            end
        end
    end
    statusLabel.Text = "Estado: Selecciona tu objetivo en el menú"
end

-- Botón de refrescar menú
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 60, 0, 20)
refreshBtn.Position = UDim2.new(1, -70, 0, 40)
refreshBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
refreshBtn.Text = "Refrescar"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 10
refreshBtn.Parent = mainFrame
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)
refreshBtn.MouseButton1Click:Connect(populateMenu)

-- Intentar popular al inicio
task.delay(1, populateMenu)

local function stopHatcher(reason)
    isRunning = false
    startBtn.Text = "▶ INICIAR"
    startBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
    statusLabel.Text = "Estado: " .. (reason or "Detenido")
end

startBtn.MouseButton1Click:Connect(function()
    if isRunning then
        stopHatcher("Detenido por el usuario")
        return
    end
    
    local targetName = selectedTargetName
    if targetName == "" then
        statusLabel.Text = "Error: Selecciona una imagen del menú"
        return
    end
    
    local hatchBtn = getHatchButton()
    if not hatchBtn then
        statusLabel.Text = "Error: No se detectó _NiuDanHatchBtn"
        return
    end
    
    local hatchPop = getNewHatchPop()
    if not hatchPop then
        statusLabel.Text = "Error: No se detectó NewHatchPop"
        return
    end
    
    isRunning = true
    startBtn.Text = "⏹ DETENER"
    startBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    statusLabel.Text = "Buscando: [" .. targetName .. "]..."
    
    task.spawn(function()
        while isRunning do
            -- 1. Si el popup NO está abierto, hacer clic en el botón de Gacha
            if not hatchPop.Visible then
                -- Pausa humana antes de volver a tirar (entre 0.1 y 0.4 segundos)
                task.wait(math.random(10, 40) / 100)
                
                fireClick(hatchBtn)
                
                -- Esperar hasta que el juego lo abra (Max 1.5s)
                local waited = 0
                while not hatchPop.Visible and waited < 1.5 do
                    task.wait(0.1)
                    waited = waited + 0.1
                end
            end
            
            -- 2. Si el popup YA está abierto, escanear y cerrar
            if hatchPop.Visible then
                -- Tiempo humano simulado para "ver" la mascota antes de cerrarla (entre 0.3 y 0.7 segundos)
                task.wait(math.random(30, 70) / 100)
                
                -- 3. Escanear qué nos tocó dentro del NewHatchPop.Main._Scroll
                local foundTarget = false
                local scrollFrame = hatchPop:FindFirstChild("Main") and hatchPop.Main:FindFirstChild("_Scroll")
                
                if scrollFrame then
                    for _, prize in ipairs(scrollFrame:GetChildren()) do
                        if string.find(prize.Name, "HatchPrize_") then
                            for _, obj in ipairs(prize:GetDescendants()) do
                                -- Método 1: Búsqueda exacta por ID de imagen
                                if selectedTargetImage ~= "" and (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.Image == selectedTargetImage then
                                    foundTarget = true
                                    break
                                end
                                
                                -- Método 2: Búsqueda exacta por Modelo en ViewportFrame
                                if selectedTargetModel ~= "" and obj:IsA("ViewportFrame") then
                                    local mName = getViewportModelName(obj)
                                    if mName ~= "" and mName == selectedTargetModel then
                                        foundTarget = true
                                        break
                                    end
                                end
                                
                                -- Método 3: Búsqueda exacta por Nombre de Mascota (TextLabel)
                                if selectedTargetText ~= "" and obj:IsA("TextLabel") and string.lower(obj.Name) == "name" then
                                    if obj.Text == selectedTargetText then
                                        foundTarget = true
                                        break
                                    end
                                end
                            end
                        end
                        if foundTarget then break end
                    end
                end
                
                -- 4. Reaccionar según el resultado
                if foundTarget then
                    stopHatcher("¡OBJETIVO ENCONTRADO!")
                    break
                end
                
                -- 5. Si no tocó, hacer clic en el botón Exit del popup para cerrarlo rápido
                local exitBtn = hatchPop:FindFirstChild("Top")
                    and hatchPop.Top:FindFirstChild("_Exit")
                    and hatchPop.Top._Exit:FindFirstChild("Btn")
                    
                if exitBtn then
                    fireClick(exitBtn)
                else
                    local closeMask = PlayerGui:FindFirstChild("ScreenGui") and PlayerGui.ScreenGui:FindFirstChild("Event") and PlayerGui.ScreenGui.Event:FindFirstChild("半透明屏蔽层")
                    if closeMask then
                        fireClick(closeMask)
                    end
                end
                
                -- Esperar hasta que el juego lo cierre realmente (Max 1.5s)
                local waited = 0
                while hatchPop.Visible and waited < 1.5 do
                    task.wait(0.1)
                    waited = waited + 0.1
                end
            end
            
            task.wait(0.05)
        end
    end)
end)
