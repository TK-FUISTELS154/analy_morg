-- ==============================================================================
-- 🎯 DUAL INSPECTOR: 3D WORLD PENETRATION & HUD SCANNER
-- ==============================================================================

local cloneref = (type(cloneref) == "function" and cloneref) or function(v) return v end

local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local function setClipboardText(text)
    local clip = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
    if clip then pcall(clip, text); return true end
    return false
end

local function getSecureParent()
    local c = nil
    if type(gethui) == "function" then pcall(function() c = gethui() end) end
    if not c and CoreGui then c = CoreGui end
    return c or LocalPlayer:WaitForChild("PlayerGui", 5)
end

local secureParent = getSecureParent()
local GUI_NAME = "DualInspector_" .. tostring(math.random(100000, 999999))
local prev = secureParent:FindFirstChild(GUI_NAME)
if prev then prev:Destroy() end

local isSelecting3D = false
local currentTarget = nil
local lastExtractedData = ""
local activeHL = nil

----------------------------------------------------------------------
-- EXTRACCIÓN DETALLADA DE DATOS
----------------------------------------------------------------------
local function extractData(obj: Instance)
    if not obj then return "Nada seleccionado." end
    local lines = {}
    table.insert(lines, "================ OBJETO DETECTADO ================")
    table.insert(lines, "Nombre: " .. obj.Name)
    table.insert(lines, "Clase: " .. obj.ClassName)
    table.insert(lines, "Ruta Completa:")
    table.insert(lines, obj:GetFullName())
    table.insert(lines, "--------------------------------------------------")

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        table.insert(lines, "[TEXTO DETECTADO]:")
        table.insert(lines, "• Text: " .. tostring(obj.Text))
        table.insert(lines, "• ContentText: " .. tostring(obj.ContentText))
        table.insert(lines, "• RichText: " .. tostring(obj.RichText))
    end

    if obj:IsA("BasePart") then
        table.insert(lines, "[PARTE FÍSICA 3D]:")
        table.insert(lines, string.format("• Posición: Vector3.new(%.2f, %.2f, %.2f)", obj.Position.X, obj.Position.Y, obj.Position.Z))
        table.insert(lines, string.format("• Tamaño: Vector3.new(%.2f, %.2f, %.2f)", obj.Size.X, obj.Size.Y, obj.Size.Z))
        
        -- Revisar si tiene SurfaceGuis directos
        local sGuis = {}
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
                table.insert(sGuis, child)
            end
        end
        if #sGuis > 0 then
            table.insert(lines, string.format("• GUIs vinculadas directamente (%d):", #sGuis))
            for _, sg in ipairs(sGuis) do
                table.insert(lines, "   -> [" .. sg.ClassName .. "] " .. sg.Name)
                for _, lbl in ipairs(sg:GetDescendants()) do
                    if lbl:IsA("TextLabel") then
                        table.insert(lines, string.format("      ↳ TextLabel '%s': %s (ContentText: %s)", lbl.Name, lbl.Text, lbl.ContentText))
                    end
                end
            end
        end
    end

    local children = obj:GetChildren()
    table.insert(lines, string.format("[HIJOS DIRECTOS]: %d", #children))
    for i, ch in ipairs(children) do
        if i <= 8 then
            table.insert(lines, string.format("  [%s] %s", ch.ClassName, ch.Name))
        end
    end
    table.insert(lines, "==================================================")
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- INTERFAZ
----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 2e9
screenGui.Parent = secureParent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 430, 0, 460)
main.Position = UDim2.new(0.04, 0, 0.2, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
main.BorderSizePixel = 0
main.Parent = screenGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(240, 240, 248)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "🎯 Inspector Directo (Filtro 3D & HUD)"
title.Parent = header

-- Botón 1: Clic 3D puro (Traspasa cualquier GUI de pantalla)
local click3DBtn = Instance.new("TextButton")
click3DBtn.Size = UDim2.new(1, -16, 0, 32)
click3DBtn.Position = UDim2.new(0, 8, 0, 42)
click3DBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
click3DBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
click3DBtn.Font = Enum.Font.SourceSansBold
click3DBtn.TextSize = 13
click3DBtn.Text = "🎯 Clic en el Letrero 3D (Ignora Pantalla 2D)"
click3DBtn.Parent = main
Instance.new("UICorner", click3DBtn).CornerRadius = UDim.new(0, 6)

-- Botón 2: Escaneo rápido del contenedor Hud.Counters
local scanHudBtn = Instance.new("TextButton")
scanHudBtn.Size = UDim2.new(0.5, -10, 0, 28)
scanHudBtn.Position = UDim2.new(0, 8, 0, 78)
scanHudBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 110)
scanHudBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanHudBtn.Font = Enum.Font.SourceSansBold
scanHudBtn.TextSize = 12
scanHudBtn.Text = "🔍 Escanear Hud.Counters"
scanHudBtn.Parent = main
Instance.new("UICorner", scanHudBtn).CornerRadius = UDim.new(0, 6)

-- Botón 3: Copiar Ruta
local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.5, -10, 0, 28)
copyBtn.Position = UDim2.new(0.5, 2, 0, 78)
copyBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
copyBtn.TextColor3 = Color3.fromRGB(220, 230, 250)
copyBtn.Font = Enum.Font.SourceSansBold
copyBtn.TextSize = 12
copyBtn.Text = "📋 Copiar Ruta"
copyBtn.Parent = main
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -118)
scroll.Position = UDim2.new(0, 8, 0, 110)
scroll.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local outputBox = Instance.new("TextBox")
outputBox.Size = UDim2.new(1, -12, 1, 0)
outputBox.Position = UDim2.new(0, 6, 0, 6)
outputBox.BackgroundTransparency = 1
outputBox.TextColor3 = Color3.fromRGB(200, 240, 220)
outputBox.Font = Enum.Font.Code
outputBox.TextSize = 12
outputBox.TextXAlignment = Enum.TextXAlignment.Left
outputBox.TextYAlignment = Enum.TextYAlignment.Top
outputBox.ClearTextOnFocus = false
outputBox.TextEditable = false
outputBox.Text = "Opciones:\n1. Pulsa el botón verde y haz clic sobre el letrero físico en el mapa.\n2. Pulsa 'Escanear Hud.Counters' si los tiempos se cargan en la interfaz del jugador."
outputBox.Parent = scroll

----------------------------------------------------------------------
-- LÓGICA DE CAPTURA
----------------------------------------------------------------------
click3DBtn.MouseButton1Click:Connect(function()
    isSelecting3D = not isSelecting3D
    click3DBtn.BackgroundColor3 = isSelecting3D and Color3.fromRGB(220, 70, 40) or Color3.fromRGB(0, 150, 100)
    click3DBtn.Text = isSelecting3D and "🔍 [ACTIVO] Haz clic directamente en el letrero..." or "🎯 Clic en el Letrero 3D (Ignora Pantalla 2D)"
end)

UserInputService.InputBegan:Connect(function(input)
    if not isSelecting3D then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local mousePos = UserInputService:GetMouseLocation()
        local minPos = main.AbsolutePosition
        local maxPos = minPos + main.AbsoluteSize
        if mousePos.X >= minPos.X and mousePos.X <= maxPos.X and mousePos.Y >= minPos.Y and mousePos.Y <= maxPos.Y then
            return
        end

        -- Traspasa el 100% de los elementos 2D y toma la pieza del mapa
        local hitPart = Mouse.Target
        isSelecting3D = false
        click3DBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
        click3DBtn.Text = "🎯 Clic en el Letrero 3D (Ignora Pantalla 2D)"

        if hitPart then
            -- Comprobar si algún SurfaceGui tiene este objeto como Adornee
            local linkedGui = hitPart:FindFirstChildOfClass("SurfaceGui") 
                or hitPart.Parent:FindFirstChildOfClass("SurfaceGui")

            if not linkedGui then
                local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if pGui then
                    for _, g in ipairs(pGui:GetDescendants()) do
                        if (g:IsA("SurfaceGui") or g:IsA("BillboardGui")) and g.Adornee == hitPart then
                            linkedGui = g
                            break
                        end
                    end
                end
            end

            currentTarget = linkedGui or hitPart
            lastExtractedData = extractData(currentTarget)
            outputBox.Text = lastExtractedData
            print("\n" .. lastExtractedData)

            if activeHL then activeHL:Destroy(); activeHL = nil end
            activeHL = Instance.new("Highlight")
            activeHL.FillColor = Color3.fromRGB(0, 255, 170)
            activeHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            activeHL.Adornee = hitPart
            activeHL.Parent = hitPart
        end
    end
end)

-- Escaneo de Hud.Counters
scanHudBtn.MouseButton1Click:Connect(function()
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local hud = pGui and pGui:FindFirstChild("Gui") and pGui.Gui:FindFirstChild("Hud")
    if not hud then
        outputBox.Text = "No se encontró PlayerGui.Gui.Hud"
        return
    end

    local lines = {"=== ESCANEO DE PLAYERGUI.GUI.HUD ==="}
    for _, desc in ipairs(hud:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local clean = desc.ContentText ~= "" and desc.ContentText or desc.Text
            table.insert(lines, string.format("[%s] %s: '%s'", desc.Parent.Name, desc.Name, clean))
        end
    end
    lastExtractedData = table.concat(lines, "\n")
    outputBox.Text = lastExtractedData
    print("\n" .. lastExtractedData)
end)

copyBtn.MouseButton1Click:Connect(function()
    if currentTarget then
        setClipboardText(currentTarget:GetFullName())
        copyBtn.Text = "✔ ¡Ruta Copiada!"
        task.delay(1.5, function() copyBtn.Text = "📋 Copiar Ruta" end)
    end
end)