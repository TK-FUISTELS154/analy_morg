--[[
    =============================================================================
    APEX SUITE - REUSABLE GUI COMPONENTS
    =============================================================================
    Colección de componentes POO para interfaces modulares y fluidas.
--]]

local Theme = (getgenv()._APEX_IMPORT and getgenv()._APEX_IMPORT("gui/Theme.lua"))
    or (typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("suite/gui/Theme.lua") and loadstring(readfile("suite/gui/Theme.lua"))())
    or (pcall(function() return game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/gui/Theme.lua") end) and loadstring(game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/gui/Theme.lua"))())

if not Theme then
    Theme = {
        Colors = {
            Background = Color3.fromRGB(18, 20, 26),
            Surface = Color3.fromRGB(25, 28, 36),
            Header = Color3.fromRGB(32, 36, 48),
            Border = Color3.fromRGB(45, 50, 65),
            AccentPrimary = Color3.fromRGB(0, 170, 255),
            TextPrimary = Color3.fromRGB(240, 243, 250),
            TextSecondary = Color3.fromRGB(160, 168, 185),
            Success = Color3.fromRGB(46, 204, 113),
            Danger = Color3.fromRGB(231, 76, 60),
            Warning = Color3.fromRGB(241, 196, 15),
        },
        Fonts = {
            Title = Enum.Font.GothamBold,
            Regular = Enum.Font.Gotham,
            Medium = Enum.Font.GothamMedium,
            Code = Enum.Font.Code,
        },
        CornerRadius = {
            Small = UDim.new(0, 4),
            Medium = UDim.new(0, 8),
            Large = UDim.new(0, 12),
        }
    }
end

local Components = {}

function Components.CreateButton(props)
    local btn = Instance.new("TextButton")
    btn.Size = props.Size or UDim2.new(0, 120, 0, 32)
    btn.Position = props.Position or UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.AccentPrimary
    btn.Text = props.Text or "Button"
    btn.TextColor3 = props.TextColor3 or Theme.Colors.TextPrimary
    btn.Font = props.Font or Theme.Fonts.Medium
    btn.TextSize = props.TextSize or 12
    btn.AutoButtonColor = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = props.CornerRadius or Theme.CornerRadius.Medium
    corner.Parent = btn
    
    if props.OnClick then
        btn.MouseButton1Click:Connect(props.OnClick)
    end
    
    if props.Parent then
        btn.Parent = props.Parent
    end
    
    return btn
end

function Components.CreateCard(props)
    local card = Instance.new("Frame")
    card.Size = props.Size or UDim2.new(1, 0, 0, 60)
    card.Position = props.Position or UDim2.new(0, 0, 0, 0)
    card.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Surface
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius.Medium
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Colors.Border
    stroke.Thickness = 1
    stroke.Parent = card
    
    if props.Parent then
        card.Parent = props.Parent
    end
    return card
end

function Components.CreateTextBox(props)
    local box = Instance.new("TextBox")
    box.Size = props.Size or UDim2.new(1, 0, 1, 0)
    box.Position = props.Position or UDim2.new(0, 0, 0, 0)
    box.BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Background
    box.TextColor3 = props.TextColor3 or Theme.Colors.TextPrimary
    box.PlaceholderText = props.PlaceholderText or ""
    box.PlaceholderColor3 = Theme.Colors.TextSecondary
    box.Font = props.Font or Theme.Fonts.Regular
    box.TextSize = props.TextSize or 12
    box.ClearTextOnFocus = false
    box.MultiLine = props.MultiLine or false
    box.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    box.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Top
    box.TextEditable = (props.TextEditable ~= nil) and props.TextEditable or true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius.Small
    corner.Parent = box
    
    if props.Parent then
        box.Parent = props.Parent
    end
    return box
end

return Components
