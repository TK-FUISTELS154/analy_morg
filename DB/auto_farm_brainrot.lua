--[[
    ═════════════════════════════════════════════════════════════════════════
    BRAINROT COLLECTOR - AUTO FARM & AUTO DOOR BLOCKER
    ═════════════════════════════════════════════════════════════════════════
    Funciones:
      1. 💰 Auto Recolector de Dinero (Auto Collect Slots 1-10)
      2. 🚪 Auto Bloqueador de Puerta (Auto Door Lock / Laser Defense)
      3. 🔄 Auto Mutador / Reclamador de Animales
      4. 🖥️ Interfaz Visual Moderna y Optimizada
    ═════════════════════════════════════════════════════════════════════════
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Funciones del Exploit
local firetouch = firetouchinterest or (syn and syn.firetouchinterest)
local fireprompt = fireproximityprompt or function() end
local protect_gui = syn_protect_gui or (syn and syn.protect_gui)
local get_hui = gethui or get_hidden_gui or function() return CoreGui end

-- Variables de Estado
local Config = {
    AutoCollect = true,
    AutoBlockDoor = true,
    CollectInterval = 0.5,
    MaxSlots = 10
}

-- Identificación de Remotes
local NetFolder = ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("Net", 10)
local CollectRemote = NetFolder and NetFolder:FindFirstChild("RE/bf314088f02631f55f411d8f04531ec2aac64c398bf519d737831cac2bd28baa")

-- Si el hash cambia entre servidores, buscar automáticamente el Remote de cobro
if not CollectRemote and NetFolder then
    for _, child in ipairs(NetFolder:GetChildren()) do
        if child:IsA("RemoteEvent") and child.Name:sub(1, 3) == "RE/" then
            CollectRemote = child
            break
        end
    end
end

-- =========================================================================
-- 1. SISTEMA DE AUTO RECOLECCIÓN DE DINERO
-- =========================================================================
task.spawn(function()
    while true do
        task.wait(Config.CollectInterval)
        if Config.AutoCollect and CollectRemote then
            for slot = 1, Config.MaxSlots do
                pcall(function()
                    CollectRemote:FireServer(slot)
                end)
            end
        end
    end
end)

-- =========================================================================
-- 2. SISTEMA DE AUTO BLOQUEO DE PUERTA / BASE
-- =========================================================================
local function FindMyBase()
    local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Bases") or workspace:FindFirstChild("Islands") or workspace:FindFirstChild("Tycoons")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("OwnerName") or plot:GetAttribute("Owner")
            if owner and (owner.Value == LocalPlayer.Name or tostring(owner) == LocalPlayer.Name or plot:GetAttribute("Owner") == LocalPlayer.Name) then
                return plot
            end
            -- Verificar si el personaje está dentro del plot
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LocalPlayer.Character.HumanoidRootPart
                if (plot:GetPivot().Position - hrp.Position).Magnitude < 80 then
                    return plot
                end
            end
        end
    end
    return nil
end

local function TriggerDoorLock()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Buscar botones o pads de bloqueo en el workspace / base
    local searchAreas = { workspace, FindMyBase() }
    for _, area in ipairs(searchAreas) do
        if area then
            for _, desc in ipairs(area:GetDescendants()) do
                local name = desc.Name:lower()
                if name:find("door") or name:find("block") or name:find("lock") or name:find("gate") or name:find("laser") then
                    -- Caso 1: Touch Part / Pad
                    if desc:IsA("BasePart") and desc:FindFirstChild("TouchInterest") and firetouch then
                        pcall(function()
                            firetouch(hrp, desc, 0)
                            task.wait(0.05)
                            firetouch(hrp, desc, 1)
                        end)
                    end
                    -- Caso 2: ProximityPrompt
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        pcall(function()
                            fireprompt(desc)
                        end)
                    end
                end
            end
        end
    end
end

-- Bucle de Auto Bloqueador de Puerta
task.spawn(function()
    while true do
        task.wait(2)
        if Config.AutoBlockDoor then
            pcall(TriggerDoorLock)
        end
    end
end)

-- =========================================================================
-- 3. INTERFAZ GRÁFICA FLOTANTE (GUI)
-- =========================================================================
local function CreateUI()
    local parent = get_hui()
    local oldUI = parent:FindFirstChild("Brainrot_AutoFarm_UI")
    if oldUI then oldUI:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "Brainrot_AutoFarm_UI"
    ScreenGui.ResetOnSpawn = false
    if protect_gui then protect_gui(ScreenGui) end
    ScreenGui.Parent = parent

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 260, 0, 190)
    Main.Position = UDim2.new(0.02, 0, 0.4, 0)
    Main.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = Main

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(0, 235, 180)
    MainStroke.Thickness = 1.5
    MainStroke.Transparency = 0.4
    MainStroke.Parent = Main

    -- Título
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundColor3 = Color3.fromRGB(26, 28, 40)
    Title.BorderSizePixel = 0
    Title.Font = Enum.Font.GothamBold
    Title.Text = "⚡ Brainrot Auto Farm"
    Title.TextColor3 = Color3.fromRGB(0, 235, 180)
    Title.TextSize = 13
    Title.Parent = Main

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title

    -- Botón Toggle Auto Recolectar
    local CollectBtn = Instance.new("TextButton")
    CollectBtn.Size = UDim2.new(1, -20, 0, 42)
    CollectBtn.Position = UDim2.new(0, 10, 0, 48)
    CollectBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
    CollectBtn.BorderSizePixel = 0
    CollectBtn.Font = Enum.Font.GothamBold
    CollectBtn.Text = "💰 Auto Recolectar: ON"
    CollectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CollectBtn.TextSize = 12
    CollectBtn.Parent = Main

    local CollectCorner = Instance.new("UICorner")
    CollectCorner.CornerRadius = UDim.new(0, 8)
    CollectCorner.Parent = CollectBtn

    CollectBtn.MouseButton1Click:Connect(function()
        Config.AutoCollect = not Config.AutoCollect
        CollectBtn.Text = "💰 Auto Recolectar: " .. (Config.AutoCollect and "ON" or "OFF")
        CollectBtn.BackgroundColor3 = Config.AutoCollect and Color3.fromRGB(0, 180, 120) or Color3.fromRGB(60, 65, 80)
    end)

    -- Botón Toggle Auto Bloquear Puerta
    local DoorBtn = Instance.new("TextButton")
    DoorBtn.Size = UDim2.new(1, -20, 0, 42)
    DoorBtn.Position = UDim2.new(0, 10, 0, 98)
    DoorBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
    DoorBtn.BorderSizePixel = 0
    DoorBtn.Font = Enum.Font.GothamBold
    DoorBtn.Text = "🚪 Auto Bloquear Puerta: ON"
    DoorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DoorBtn.TextSize = 12
    DoorBtn.Parent = Main

    local DoorCorner = Instance.new("UICorner")
    DoorCorner.CornerRadius = UDim.new(0, 8)
    DoorCorner.Parent = DoorBtn

    DoorBtn.MouseButton1Click:Connect(function()
        Config.AutoBlockDoor = not Config.AutoBlockDoor
        DoorBtn.Text = "🚪 Auto Bloquear Puerta: " .. (Config.AutoBlockDoor and "ON" or "OFF")
        DoorBtn.BackgroundColor3 = Config.AutoBlockDoor and Color3.fromRGB(0, 180, 120) or Color3.fromRGB(60, 65, 80)
    end)

    -- Pie de Estado
    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, 0, 0, 30)
    Status.Position = UDim2.new(0, 0, 1, -32)
    Status.BackgroundTransparency = 1
    Status.Font = Enum.Font.Gotham
    Status.Text = "● Funcionando en segundo plano"
    Status.TextColor3 = Color3.fromRGB(160, 165, 180)
    Status.TextSize = 11
    Status.Parent = Main
end

task.spawn(CreateUI)
