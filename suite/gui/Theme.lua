--[[
    =============================================================================
    APEX SUITE - GUI THEME & DESIGN TOKENS
    =============================================================================
    Paleta de colores profesional, tipografía moderna y estilos consistentes.
--]]

local Theme = {
    Colors = {
        Background = Color3.fromRGB(18, 20, 26),
        Surface    = Color3.fromRGB(25, 28, 36),
        Header     = Color3.fromRGB(32, 36, 48),
        Border     = Color3.fromRGB(45, 50, 65),
        
        AccentPrimary   = Color3.fromRGB(0, 170, 255),
        AccentSecondary = Color3.fromRGB(120, 90, 240),
        
        TextPrimary   = Color3.fromRGB(240, 243, 250),
        TextSecondary = Color3.fromRGB(160, 168, 185),
        TextMuted     = Color3.fromRGB(100, 108, 125),
        
        Success = Color3.fromRGB(46, 204, 113),
        Warning = Color3.fromRGB(241, 196, 15),
        Danger  = Color3.fromRGB(231, 76, 60),
        Info    = Color3.fromRGB(52, 152, 219),
    },
    
    Fonts = {
        Title   = Enum.Font.GothamBold,
        Regular = Enum.Font.Gotham,
        Medium  = Enum.Font.GothamMedium,
        Code    = Enum.Font.Code,
    },
    
    CornerRadius = {
        Small  = UDim.new(0, 4),
        Medium = UDim.new(0, 8),
        Large  = UDim.new(0, 12),
        Round  = UDim.new(1, 0),
    }
}

return Theme
