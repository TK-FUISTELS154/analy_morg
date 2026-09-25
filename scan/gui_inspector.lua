-- ==========================================================
-- GUI INSPECTOR PRO (Spy Dex)
-- Herramienta profesional para inspeccionar interfaces en Roblox
-- ==========================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
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

if secureParent:FindFirstChild("GuiInspectorPro") then
    secureParent.GuiInspectorPro:Destroy()
end

-- ==========================================================
-- 2. INTERFAZ DE CONTROL E INFORMACIA"N
-- ==========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GuiInspectorPro"
ScreenGui.DisplayOrder = 99999 -- Siempre encima de todo
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = secureParent

local MainPanel = Instance.new("Frame")
MainPanel.Name = "MainPanel"
MainPanel.Size = UDim2.new(0, 300, 0, 200)
MainPanel.Position = UDim2.new(1, -320, 0, 20)
MainPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainPanel.BackgroundTransparency = 0.1
MainPanel.BorderSizePixel = 0
MainPanel.Active = true
MainPanel.Draggable = true
MainPanel.Parent = ScreenGui

Instance.new("UICorner", MainPanel).CornerRadius = UDim.new(0, 8)
local UIStroke = Instance.new("UIStroke", MainPanel)
UIStroke.Color = Color3.fromRGB(150, 0, 255)
UIStroke.Thickness = 2

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.Text = " GUI INSPECTOR PRO"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Parent = MainPanel

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -20, 0, 30)
ToggleBtn.Position = UDim2.new(0, 10, 0, 40)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Text = "ACTIVAR INSPECTOR (HOVER)"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 12
ToggleBtn.Parent = MainPanel
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)

local InfoBox = Instance.new("TextBox")
InfoBox.Size = UDim2.new(1, -20, 0, 110)
InfoBox.Position = UDim2.new(0, 10, 0, 80)
InfoBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
InfoBox.Font = Enum.Font.Code
InfoBox.Text = "Haz clic en ACTIVAR y mueve el ratAn sobre la pantalla. Haz clic izquierdo para capturar el elemento."
InfoBox.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoBox.TextSize = 12
InfoBox.TextXAlignment = Enum.TextXAlignment.Left
InfoBox.TextYAlignment = Enum.TextYAlignment.Top
InfoBox.ClearTextOnFocus = false
InfoBox.TextEditable = false
InfoBox.TextWrapped = true
InfoBox.Parent = MainPanel
Instance.new("UICorner", InfoBox).CornerRadius = UDim.new(0, 4)

-- Cuadro resaltador
local HighlightFrame = Instance.new("Frame")
HighlightFrame.Name = "InspectorHighlight"
HighlightFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
HighlightFrame.BackgroundTransparency = 0.7
HighlightFrame.BorderSizePixel = 0
HighlightFrame.ZIndex = 99999
HighlightFrame.Visible = false
HighlightFrame.Parent = ScreenGui

local HighlightStroke = Instance.new("UIStroke", HighlightFrame)
HighlightStroke.Color = Color3.fromRGB(255, 255, 0)
HighlightStroke.Thickness = 2

-- ==========================================================
-- 3. LA"GICA DE INSPECCIA"N
-- ==========================================================
local isInspecting = false
local currentTarget = nil
local connectionHover = nil
local connectionClick = nil

-- FunciA3n para obtener la ruta exacta
local function getPath(instance)
    if not instance then return "nil" end
    local path = instance.Name
    local current = instance.Parent
    
    while current and current ~= game do
        -- Manejar nombres con espacios o caracteres especiales
        if string.match(current.Name, "^[%w_]+$") then
            path = current.Name .. "." .. path
        else
            path = current.Name .. '["' .. path .. '"]'
        end
        current = current.Parent
    end
    return path
end

-- Analizar eventos (Requiere getconnections)
local function analyzeConnections(instance)
    local info = "Sin eventos detectados."
    if type(getconnections) == "function" then
        local success, conns = pcall(function() return getconnections(instance.MouseButton1Click) end)
        if success and conns and #conns > 0 then
            info = "Conexiones (Click): " .. #conns .. "\n"
            for i, conn in ipairs(conns) do
                local func = conn.Function
                if func then
                    local s, d = pcall(function() return debug.getinfo(func) end)
                    if s and d then
                        info = info .. string.format("- Script: %s | Linea: %s\n", tostring(d.short_src or "LocalScript"), tostring(d.currentline or "?"))
                    end
                end
            end
        else
            info = "No se encontraron conexiones MouseButton1Click."
        end
    else
        info = "Tu ejecutor no soporta getconnections()."
    end
    return info
end

local function toggleInspector()
    isInspecting = not isInspecting
    
    if isInspecting then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        ToggleBtn.Text = "MODO INSPECTOR: ON"
        
        -- Evento Hover
        connectionHover = RunService.RenderStepped:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            -- Buscar GUIs en la posiciA3n del ratA3n (excluyendo el propio inspector)
            local guiObjects = PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
            
            currentTarget = nil
            for _, obj in ipairs(guiObjects) do
                if obj.Name ~= "InspectorHighlight" and not obj:IsDescendantOf(ScreenGui) then
                    currentTarget = obj
                    break
                end
            end
            
            if currentTarget then
                HighlightFrame.Visible = true
                HighlightFrame.Size = UDim2.new(0, currentTarget.AbsoluteSize.X, 0, currentTarget.AbsoluteSize.Y)
                -- Corregir posiciA3n restando el inset (36px normalmente por la barra superior de Roblox)
                local guiInset = game:GetService("GuiService"):GetGuiInset()
                HighlightFrame.Position = UDim2.new(0, currentTarget.AbsolutePosition.X, 0, currentTarget.AbsolutePosition.Y + guiInset.Y)
                
                InfoBox.Text = string.format("Hovering:\n%s\nClase: %s", currentTarget.Name, currentTarget.ClassName)
            else
                HighlightFrame.Visible = false
                InfoBox.Text = "Mueve el ratAn sobre un elemento UI..."
            end
        end)
        
        -- Evento Click (Capturar)
        connectionClick = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and currentTarget then
                -- Pausar inspecciA3n
                toggleInspector()
                
                local path = getPath(currentTarget)
                local conns = ""
                
                if currentTarget:IsA("GuiButton") then
                    conns = "\n\n" .. analyzeConnections(currentTarget)
                end
                
                local finalInfo = string.format("Ruta:\n%s\n\nClase: %s\nVisible: %s%s", path, currentTarget.ClassName, tostring(currentTarget.Visible), conns)
                
                InfoBox.Text = finalInfo
                
                -- Imprimir en F9
                print("\n================== GUI INSPECTOR ==================")
                print(finalInfo)
                print("===================================================\n")
                
                -- Copiar al portapapeles
                if type(setclipboard) == "function" then
                    setclipboard(path)
                    print("[GUI Inspector] Ruta copiada al portapapeles.")
                end
            end
        end)
        
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        ToggleBtn.Text = "ACTIVAR INSPECTOR (HOVER)"
        HighlightFrame.Visible = false
        if connectionHover then connectionHover:Disconnect() end
        if connectionClick then connectionClick:Disconnect() end
    end
end

ToggleBtn.MouseButton1Click:Connect(toggleInspector)

print("Gui Inspector Pro cargado. Busca la interfaz en la esquina superior derecha.")
