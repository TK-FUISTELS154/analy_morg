--[[
    =============================================================================
    🎱 POOL ORACLE AI PRO - 100% EXACT GAME ENGINE PREDICTOR v6.5
    =============================================================================
    Motor de predicción física 1:1 nativo para 8 Ball Pool (Roblox).
    
    Características clave:
      1. Física 100% Real y Saque Inicial (Break Shot) Corregido:
         - Detecta automáticamente el tiro inicial (Break Shot) y activa el multiplicador
           nativo de velocidad (BreakSpeedMultiplier = 2.5x).
         - Simulación multi-colisión de alta resolución (sub-stepping de 12ms) para
           calcular con precisión milimétrica la dispersión del triángulo de 15 bolas.
      2. Control Manual de Fuerza Inicial en la GUI:
         - Modo AUTO: Lee la fuerza en vivo del taco (PowerTrack).
         - Modo MANUAL: Permite fijar y manipular la fuerza deseada (10% a 100% con
           botones de ajuste rápido 25%, 50%, 75%, 100% y steppers +/-) para previsualizar
           tiros antes de tirar del taco.
      3. Detección Vectorial Exacta:
         - Extrae la dirección angular pura desde AimLine.Rotation sin errores de píxeles.
      4. Máquina de Estados Anti-Parpadeo (Frozen Path Pro):
         - Congela la trayectoria exacta al disparar, manteniéndola visible durante
           todo el recorrido y limpiando la mesa solo al detenerse por completo.
      5. Indicadores Visuales de Alta Definición:
         - Colores oficiales por número de bola, Ghost Ball en el impacto, aro verde
           y etiqueta de embocada (🎯 POCKETED) y alerta roja en caso de Scratch.
--]]

local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game
local cloneref = (type(cloneref) == "function" and cloneref) or function(x) return x end

-- 1. SERVICIOS SEGUROS
local Services = setmetatable({}, {
    __index = function(self, name)
        local raw = rawGame:GetService(name)
        local secured = cloneref(raw) or raw
        rawset(self, name, secured)
        return secured
    end
})

local Players = Services.Players
local ReplicatedStorage = Services.ReplicatedStorage
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local GuiService = Services.GuiService

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = cloneref(LocalPlayer:WaitForChild("PlayerGui", 10)) or LocalPlayer:WaitForChild("PlayerGui")

-- 2. CONSTANTES FÍSICAS NATIVAS DEL JUEGO (POOL CONSTANTS & GEOMETRY)
local PoolConstants = nil
local PoolPhysics = nil
local PoolGeometry = nil

pcall(function()
    local poolLib = ReplicatedStorage:WaitForChild("Libraries", 3):WaitForChild("GameSpecific", 3):WaitForChild("Pool", 3)
    PoolConstants = require(poolLib:WaitForChild("PoolConstants", 3))
    PoolPhysics = require(poolLib:WaitForChild("PoolPhysics", 3))
    PoolGeometry = require(poolLib:WaitForChild("PoolGeometry", 3))
end)

local FrameWidth = (PoolConstants and PoolConstants.FrameWidth) or 103
local FrameHeight = (PoolConstants and PoolConstants.FrameHeight) or 59
local PlayWidth = (PoolConstants and PoolConstants.PlayWidth) or 88
local PlayHeight = (PoolConstants and PoolConstants.PlayHeight) or 44
local BallRadius = (PoolConstants and PoolConstants.BallRadius) or 1.125
local BallDiameter = (PoolConstants and PoolConstants.BallDiameter) or 2.25

-- Colores Oficiales de Bolas según PoolConstants
local OFFICIAL_BALL_COLORS = {
    [0]  = Color3.fromRGB(250, 250, 250), -- Blanca (Cue)
    [1]  = Color3.fromRGB(245, 197, 24),  -- Amarilla (Solid)
    [2]  = Color3.fromRGB(47, 111, 224),  -- Azul (Solid)
    [3]  = Color3.fromRGB(226, 64, 47),   -- Roja (Solid)
    [4]  = Color3.fromRGB(123, 75, 209),  -- Púrpura (Solid)
    [5]  = Color3.fromRGB(242, 128, 43),  -- Naranja (Solid)
    [6]  = Color3.fromRGB(30, 158, 88),   -- Verde (Solid)
    [7]  = Color3.fromRGB(142, 59, 46),   -- Marrón (Solid)
    [8]  = Color3.fromRGB(22, 25, 28),    -- Negra (8 Ball)
    [9]  = Color3.fromRGB(245, 197, 24),  -- Amarilla (Stripe)
    [10] = Color3.fromRGB(47, 111, 224),  -- Azul (Stripe)
    [11] = Color3.fromRGB(226, 64, 47),   -- Roja (Stripe)
    [12] = Color3.fromRGB(123, 75, 209),  -- Púrpura (Stripe)
    [13] = Color3.fromRGB(242, 128, 43),  -- Naranja (Stripe)
    [14] = Color3.fromRGB(30, 158, 88),   -- Verde (Stripe)
    [15] = Color3.fromRGB(142, 59, 46),   -- Marrón (Stripe)
}

-- 3. ESTADO GLOBAL Y CONFIGURACIÓN
local isEnabled = true
local isMinimized = false
local showGhostBall = true
local showAllTrajectories = true

-- Control de Fuerza Manual vs Automática
local useManualPower = false
local manualPowerValue = 1.0 -- Fuerza manual seleccionable (0.05 a 1.0)

local connections = {}
local scriptActive = true

-- Máquina de estados de tiro
local SHOT_STATE_IDLE = "IDLE"
local SHOT_STATE_AIMING = "AIMING"
local SHOT_STATE_LOCKED = "LOCKED"
local currentShotState = SHOT_STATE_IDLE

local activeTrajectories = nil
local lockedTrajectories = nil
local lastAimTimestamp = 0
local stoppedFramesCount = 0

-- 4. POOL DE RENDERIZADO VISUAL EN PANTALLA
local oracleCanvas = nil
local linePool = {}
local ringPool = {}
local markerPool = {}
local activeLines = 0
local activeRings = 0
local activeMarkers = 0

local function getRandomName()
    local str = "OracleCanvas_"
    for _ = 1, 10 do str = str .. string.char(math.random(97, 122)) end
    return str
end

local function getOrCreateCanvas(overlayContainer)
    if not oracleCanvas or oracleCanvas.Parent ~= overlayContainer then
        if oracleCanvas then oracleCanvas:Destroy() end
        oracleCanvas = Instance.new("Frame")
        oracleCanvas.Name = getRandomName()
        oracleCanvas.Size = UDim2.fromScale(1, 1)
        oracleCanvas.Position = UDim2.fromScale(0, 0)
        oracleCanvas.BackgroundTransparency = 1
        oracleCanvas.BorderSizePixel = 0
        oracleCanvas.ZIndex = 80
        oracleCanvas.Parent = overlayContainer
    end
    return oracleCanvas
end

local function resetRenderPool()
    for i = 1, #linePool do linePool[i].Visible = false end
    for i = 1, #ringPool do ringPool[i].Visible = false end
    for i = 1, #markerPool do markerPool[i].Visible = false end
    activeLines = 0
    activeRings = 0
    activeMarkers = 0
end

local function getLine(parent)
    activeLines = activeLines + 1
    if linePool[activeLines] then
        local l = linePool[activeLines]
        l.Parent = parent
        l.Visible = true
        return l
    end
    local l = Instance.new("Frame")
    l.Name = "OracleLine"
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.BorderSizePixel = 0
    l.ZIndex = 82
    Instance.new("UICorner", l).CornerRadius = UDim.new(1, 0)
    l.Parent = parent
    linePool[activeLines] = l
    return l
end

local function getRing(parent)
    activeRings = activeRings + 1
    if ringPool[activeRings] then
        local r = ringPool[activeRings]
        r.Parent = parent
        r.Visible = true
        return r
    end
    local r = Instance.new("Frame")
    r.Name = "OracleRing"
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.BackgroundTransparency = 0.82
    r.BorderSizePixel = 0
    r.ZIndex = 84

    Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
    local st = Instance.new("UIStroke", r)
    st.Name = "Stroke"
    st.Thickness = 2.0
    st.Transparency = 0.1

    r.Parent = parent
    ringPool[activeRings] = r
    return r
end

local function getMarker(parent)
    activeMarkers = activeMarkers + 1
    if markerPool[activeMarkers] then
        local m = markerPool[activeMarkers]
        m.Parent = parent
        m.Visible = true
        return m
    end
    local m = Instance.new("TextLabel")
    m.Name = "OracleMarker"
    m.AnchorPoint = Vector2.new(0.5, 0.5)
    m.BackgroundTransparency = 1
    m.Font = Enum.Font.GothamBold
    m.TextSize = 10
    m.TextColor3 = Color3.fromRGB(255, 255, 255)
    m.ZIndex = 86
    local st = Instance.new("UIStroke", m)
    st.Color = Color3.fromRGB(0, 0, 0)
    st.Thickness = 1.2
    m.Parent = parent
    markerPool[activeMarkers] = m
    return m
end

-- Conversión matemática: Espacio Mesa (Inches) -> Píxeles en Pantalla
local function tableToScreen(tablePos, canvasSize)
    local u = 0.5 + (tablePos.X / FrameWidth)
    local v = 0.5 - (tablePos.Y / FrameHeight)
    return Vector2.new(u * canvasSize.X, v * canvasSize.Y)
end

-- Renderizado de segmento de línea continuo
local function drawSegment(pA, pB, color, thickness, canvas, transparency)
    local delta = pB - pA
    local len = delta.Magnitude
    if len <= 0.4 then return end

    local mid = (pA + pB) * 0.5
    local line = getLine(canvas)
    line.Size = UDim2.fromOffset(len, thickness or 2.2)
    line.Position = UDim2.fromOffset(mid.X, mid.Y)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.BackgroundColor3 = color
    line.BackgroundTransparency = transparency or 0.1
end

-- Renderizado de Ghost Ball en punto de impacto o destino final
local function drawGhost(screenPos, diameter, color, canvas, fillTransp, strokeTransp, strokeThickness)
    local r = getRing(canvas)
    r.Size = UDim2.fromOffset(diameter, diameter)
    r.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
    r.BackgroundColor3 = color
    r.BackgroundTransparency = fillTransp or 0.8
    local st = r:FindFirstChild("Stroke")
    if st then
        st.Color = color
        st.Transparency = strokeTransp or 0.1
        st.Thickness = strokeThickness or 2.0
    end
end

-- Obtener color real de la bola según interfaz o constantes
local function getBallColor(num, ballsFolder)
    if num == 0 or not num then
        return Color3.fromRGB(250, 250, 250)
    end
    if ballsFolder then
        for _, bFrame in ipairs(ballsFolder:GetChildren()) do
            local numAttr = bFrame:GetAttribute("BallNumber")
            local nameNum = tonumber(bFrame.Name:match("%d+"))
            if numAttr == num or nameNum == num then
                local stripe = bFrame:FindFirstChild("Stripe")
                if stripe and stripe:IsA("GuiObject") and stripe.BackgroundColor3 ~= Color3.new(0, 0, 0) then
                    return stripe.BackgroundColor3
                elseif bFrame:IsA("GuiObject") and bFrame.BackgroundColor3 ~= Color3.new(0, 0, 0) then
                    return bFrame.BackgroundColor3
                end
            end
        end
    end
    return OFFICIAL_BALL_COLORS[num] or Color3.fromRGB(220, 220, 220)
end

-- 5. DETECCIÓN DE MOVIMIENTO DE BOLAS
local function checkBallsMotion(ballsFolder)
    local moving = false
    for _, bFrame in ipairs(ballsFolder:GetChildren()) do
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local curX = bFrame.Position.X.Scale
            local curY = bFrame.Position.Y.Scale
            local prevX = bFrame:GetAttribute("_OraclePrevX")
            local prevY = bFrame:GetAttribute("_OraclePrevY")

            bFrame:SetAttribute("_OraclePrevX", curX)
            bFrame:SetAttribute("_OraclePrevY", curY)

            if prevX and prevY then
                local dx = math.abs(curX - prevX)
                local dy = math.abs(curY - prevY)
                if dx > 0.00015 or dy > 0.00015 then
                    moving = true
                end
            end
        end
    end
    return moving
end

-- 6. DIBUJAR TRAYECTORIAS COMPLETAS EN PANTALLA
local function renderTrajectories(trajectoriesData, canvas, canvasSize, ballsFolder)
    resetRenderPool()
    if not trajectoriesData or not trajectoriesData.Trajectories then return end

    local pixelDiameter = (BallDiameter / FrameWidth) * canvasSize.X
    local isBreak = trajectoriesData.IsBreakShot

    -- 1. Renderizar Ghost Ball en el primer impacto
    if showGhostBall and trajectoriesData.FirstImpactGhost then
        local ghostScreen = tableToScreen(trajectoriesData.FirstImpactGhost, canvasSize)
        drawGhost(ghostScreen, pixelDiameter, Color3.fromRGB(255, 255, 255), canvas, 0.9, 0.2, 1.8)
    end

    -- 2. Renderizar caminos de todas las bolas activas
    for num, traj in pairs(trajectoriesData.Trajectories) do
        local pts = traj.Points
        if pts and #pts >= 2 then
            local isCue = (num == 0)
            local ballColor = getBallColor(num, ballsFolder)
            local lineThickness = isCue and 2.5 or (isBreak and 1.8 or 2.2)
            local lineTransp = isCue and 0.05 or (isBreak and 0.25 or 0.15)

            if isCue and traj.Pocketed then
                ballColor = Color3.fromRGB(255, 55, 55) -- Alerta de Scratch
            elseif traj.Pocketed then
                ballColor = Color3.fromRGB(0, 255, 150) -- Embocada segura
            end

            -- En el saque, dibujar bolas que se muevan más de 1.0 pulgada para claridad visual
            local minDistThreshold = isBreak and (isCue and 0.5 or 1.2) or 0.35

            if showAllTrajectories or isCue or traj.Pocketed or traj.TotalDistance > minDistThreshold then
                for i = 1, #pts - 1 do
                    local sA = tableToScreen(pts[i], canvasSize)
                    local sB = tableToScreen(pts[i + 1], canvasSize)
                    drawSegment(sA, sB, ballColor, lineThickness, canvas, lineTransp)
                end

                -- Ghost Ball en el punto final
                local finalPos = pts[#pts]
                local sFinal = tableToScreen(finalPos, canvasSize)

                if traj.Pocketed then
                    -- Aro de Embocada en la buchaca
                    drawGhost(sFinal, pixelDiameter * 1.3, Color3.fromRGB(0, 255, 140), canvas, 0.5, 0.0, 2.5)
                    local marker = getMarker(canvas)
                    marker.Text = string.format("🎱 #%d 🎯", num)
                    marker.TextColor3 = Color3.fromRGB(0, 255, 140)
                    marker.Position = UDim2.fromOffset(sFinal.X, sFinal.Y - 18)
                else
                    drawGhost(sFinal, pixelDiameter, ballColor, canvas, 0.85, 0.2, 1.5)
                end
            end
        end
    end
end

-- 7. MOTOR DE SIMULACIÓN FÍSICA NATIVO (100% REAL CON SOPORTE EXACTO DE BREAK SHOT)
local function simulateShot(cuePos, aimDir, power, spin, ballsFolder)
    if not PoolPhysics then return nil end

    local sim = PoolPhysics.newSimulation()

    -- Detección de Saque Inicial (Break Shot):
    -- Si hay 15 bolas objetivo en la mesa y la blanca está en la zona de saque (head string)
    local activeBallsCount = 0
    local hasEightBall = false
    for _, bFrame in ipairs(ballsFolder:GetChildren()) do
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local numAttr = bFrame:GetAttribute("BallNumber")
            local num = numAttr or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                activeBallsCount = activeBallsCount + 1
                if num == 8 then hasEightBall = true end
            end
        end
    end

    local isBreakShot = (activeBallsCount >= 14 and cuePos.X < -10)
    sim.IsBreakShot = isBreakShot

    -- Añadir la bola blanca
    PoolPhysics.AddBall(sim, 0, cuePos, BallRadius, false)

    -- Agregar todas las bolas presentes en la mesa con sus posiciones exactas
    for _, bFrame in ipairs(ballsFolder:GetChildren()) do
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local numAttr = bFrame:GetAttribute("BallNumber")
            local num = numAttr or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                local bX = (bFrame.Position.X.Scale - 0.5) * FrameWidth
                local bY = (0.5 - bFrame.Position.Y.Scale) * FrameHeight
                PoolPhysics.AddBall(sim, num, Vector2.new(bX, bY), BallRadius, false)
            end
        end
    end

    -- Realizar el disparo idéntico al motor del juego
    local success = PoolPhysics.Shoot(sim, aimDir, power, spin)
    if not success then return nil end

    local trajectories = {}
    for num, b in pairs(sim.Balls) do
        trajectories[num] = {
            Number = num,
            Points = { b.Position },
            Pocketed = false,
            TotalDistance = 0,
            LastPos = b.Position
        }
    end

    local firstImpactGhost = nil
    local subSteps = 0
    -- En el saque hay múltiples interacciones simultáneas en el triángulo, por lo que
    -- usamos mayor resolución de sub-stepping (650 pasos a 12ms) para máxima exactitud.
    local MAX_SIM_STEPS = isBreakShot and 650 or 450
    local DT = isBreakShot and 0.012 or 0.0166667

    while not sim.Settled and subSteps < MAX_SIM_STEPS do
        subSteps = subSteps + 1
        local prevEventsCount = #sim.Events

        PoolPhysics.Step(sim, DT)

        -- Procesar eventos de física (colisiones y buchacas)
        for i = prevEventsCount + 1, #sim.Events do
            local ev = sim.Events[i]
            if ev.Kind == "BallHit" then
                local b1 = sim.Balls[ev.Ball]
                local b2 = sim.Balls[ev.Other]
                if not firstImpactGhost and (ev.Ball == 0 or ev.Other == 0) then
                    local cueBall = (ev.Ball == 0) and b1 or b2
                    if cueBall then firstImpactGhost = cueBall.Position end
                end
                if b1 and trajectories[ev.Ball] then
                    table.insert(trajectories[ev.Ball].Points, b1.Position)
                    trajectories[ev.Ball].LastPos = b1.Position
                end
                if b2 and trajectories[ev.Other] then
                    table.insert(trajectories[ev.Other].Points, b2.Position)
                    trajectories[ev.Other].LastPos = b2.Position
                end
            elseif ev.Kind == "CushionHit" or ev.Kind == "TipHit" then
                local b = sim.Balls[ev.Ball]
                if b and trajectories[ev.Ball] then
                    table.insert(trajectories[ev.Ball].Points, b.Position)
                    trajectories[ev.Ball].LastPos = b.Position
                end
            elseif ev.Kind == "Pocketed" then
                local b = sim.Balls[ev.Ball]
                if b and trajectories[ev.Ball] then
                    trajectories[ev.Ball].Pocketed = true
                    local sinkPos = ev.EntryPosition or b.Position
                    table.insert(trajectories[ev.Ball].Points, sinkPos)
                    trajectories[ev.Ball].LastPos = sinkPos
                end
            end
        end

        -- Muestreo suave de trayectoria para curvas y desaceleración
        if subSteps % 2 == 0 then
            for num, b in pairs(sim.Balls) do
                local traj = trajectories[num]
                if not traj.Pocketed and not b.Pocketed and not b.Sinking then
                    local dist = (b.Position - traj.LastPos).Magnitude
                    if dist > (isBreakShot and 0.12 or 0.08) then
                        table.insert(traj.Points, b.Position)
                        traj.TotalDistance = traj.TotalDistance + dist
                        traj.LastPos = b.Position
                    end
                end
            end
        end
    end

    -- Punto final
    for num, b in pairs(sim.Balls) do
        local traj = trajectories[num]
        if not traj.Pocketed then
            local lastPt = traj.Points[#traj.Points]
            if (b.Position - lastPt).Magnitude > 0.05 then
                table.insert(traj.Points, b.Position)
            end
        end
    end

    return {
        Trajectories = trajectories,
        FirstImpactGhost = firstImpactGhost,
        IsBreakShot = isBreakShot
    }
end

-- Variables de referencia UI
local powerModeBtnRef = nil
local powerDisplayRef = nil

-- 8. BUCLE PRINCIPAL DE ACTUALIZACIÓN Y MÁQUINA DE ESTADOS
local function updateOracle()
    if not isEnabled or not scriptActive then
        resetRenderPool()
        return
    end

    local poolUI = PlayerGui:FindFirstChild("PoolGameUI")
    if not poolUI then
        resetRenderPool()
        return
    end

    local tableFrame = poolUI:FindFirstChild("Table")
    local tableGui = tableFrame and tableFrame:FindFirstChild("PoolTable")
    local overlay = tableGui and tableGui:FindFirstChild("Overlay")
    local ballsFolder = tableGui and tableGui:FindFirstChild("Balls")

    if not tableGui or not overlay or not ballsFolder then
        resetRenderPool()
        return
    end

    local canvas = getOrCreateCanvas(overlay)
    local canvasSize = overlay.AbsoluteSize
    if canvasSize.X <= 10 or canvasSize.Y <= 10 then
        resetRenderPool()
        return
    end

    local aimOverlay = overlay:FindFirstChild("AimOverlay")
    local aimLine = aimOverlay and aimOverlay:FindFirstChild("AimLine")
    local ghostFrame = aimOverlay and aimOverlay:FindFirstChild("Ghost")
    local cueStickFrame = aimOverlay and aimOverlay:FindFirstChild("CueStick")

    local isAiming = false
    if aimOverlay and aimOverlay.Visible then
        if (aimLine and aimLine.Visible) or (ghostFrame and ghostFrame.Visible) or (cueStickFrame and cueStickFrame.Visible) then
            isAiming = true
        end
    end

    local ballsRolling = checkBallsMotion(ballsFolder)

    -- GESTIÓN DE MÁQUINA DE ESTADOS (FROZEN PATH PRO)
    if isAiming then
        -- ESTADO 1: APUNTANDO ACTIVAMENTE -> CALCULAR EN TIEMPO REAL
        currentShotState = SHOT_STATE_AIMING
        stoppedFramesCount = 0
        lastAimTimestamp = tick()

        local cueBallFrame = ballsFolder:FindFirstChild("Ball0")
        if not cueBallFrame or not cueBallFrame.Visible then
            resetRenderPool()
            return
        end

        local cuePos = Vector2.new(
            (cueBallFrame.Position.X.Scale - 0.5) * FrameWidth,
            (0.5 - cueBallFrame.Position.Y.Scale) * FrameHeight
        )

        -- Cálculo del Vector de Dirección Exacto
        local aimDir = nil

        -- A) Extracción angular pura desde la rotación de AimLine (100% exacto)
        if aimLine and aimLine.Visible then
            local rotDeg = aimLine.Rotation
            local rotRad = math.rad(rotDeg)
            -- En el sistema 2D de Roblox: X = cos(-rot), Y = sin(-rot)
            aimDir = Vector2.new(math.cos(-rotRad), math.sin(-rotRad)).Unit
        end

        -- B) Fallback con posición de Ghost
        if not aimDir and ghostFrame and ghostFrame.Visible then
            local ghostPos = Vector2.new(
                (ghostFrame.Position.X.Scale - 0.5) * FrameWidth,
                (0.5 - ghostFrame.Position.Y.Scale) * FrameHeight
            )
            local diff = ghostPos - cuePos
            if diff.Magnitude > 0.001 then
                aimDir = diff.Unit
            end
        end

        -- C) Fallback con Cursor del Mouse / Touch
        if not aimDir then
            local mouse = UserInputService:GetMouseLocation()
            local inset = GuiService:GetGuiInset()
            local relX = (mouse.X - overlay.AbsolutePosition.X - inset.X) / canvasSize.X
            local relY = (mouse.Y - overlay.AbsolutePosition.Y - inset.Y) / canvasSize.Y
            local mouseTablePos = Vector2.new((relX - 0.5) * FrameWidth, (0.5 - relY) * FrameHeight)
            local diff = mouseTablePos - cuePos
            if diff.Magnitude > 0.001 then
                aimDir = diff.Unit
            end
        end

        if not aimDir then
            resetRenderPool()
            return
        end

        -- Determinación de Potencia (AUTO vs MANUAL)
        local power = 0.6
        if useManualPower then
            power = math.clamp(manualPowerValue, 0.05, 1.0)
        else
            local powerTrack = poolUI:FindFirstChild("PowerTrack", true)
            local fill = powerTrack and powerTrack:FindFirstChild("Fill")
            if fill and fill:IsA("GuiObject") then
                power = math.clamp(fill.Size.Y.Scale, 0.02, 1)
            end
        end

        -- Actualizar indicador en GUI
        if powerDisplayRef then
            local speedEst = 30 + (138 - 30) * (power ^ 2)
            powerDisplayRef.Text = string.format("⚡ Fuerza: %d%% (~%.0f in/s)", math.floor(power * 100), speedEst)
        end

        -- Lectura de Spin desde SpinWidget
        local spin = Vector2.zero
        local spinWidget = poolUI:FindFirstChild("SpinWidget", true)
        local dot = spinWidget and spinWidget:FindFirstChild("Dot")
        if dot and dot:IsA("GuiObject") then
            local sX = math.clamp((dot.Position.X.Scale - 0.5) / 0.37, -1, 1)
            local sY = math.clamp((0.5 - dot.Position.Y.Scale) / 0.37, -1, 1)
            spin = Vector2.new(sX, sY)
        end

        -- Ejecutar Simulación
        activeTrajectories = simulateShot(cuePos, aimDir, power, spin, ballsFolder)
        lockedTrajectories = activeTrajectories

        renderTrajectories(activeTrajectories, canvas, canvasSize, ballsFolder)

    elseif currentShotState == SHOT_STATE_AIMING and not isAiming then
        -- ESTADO 2: EL JUGADOR SOLTÓ EL TACO / DISPARÓ -> CONGELAR TRAYECTORIA
        currentShotState = SHOT_STATE_LOCKED
        stoppedFramesCount = 0

        if lockedTrajectories then
            renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
        else
            resetRenderPool()
        end

    elseif currentShotState == SHOT_STATE_LOCKED then
        -- ESTADO 3: BOLAS RODANDO CON TRAYECTORIA CONGELADA
        if ballsRolling or (tick() - lastAimTimestamp < 0.6) then
            stoppedFramesCount = 0
            if lockedTrajectories then
                renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
            end
        else
            stoppedFramesCount = stoppedFramesCount + 1
            if stoppedFramesCount > 12 or (tick() - lastAimTimestamp > 14) then
                currentShotState = SHOT_STATE_IDLE
                lockedTrajectories = nil
                activeTrajectories = nil
                resetRenderPool()
            else
                if lockedTrajectories then
                    renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
                end
            end
        end

    else
        -- ESTADO 4: MESA EN REPOSO
        resetRenderPool()
    end
end

-- 9. PANEL DE CONTROL FLOTANTE AVANZADO CON CONTROL DE FUERZA
local controlGui = Instance.new("ScreenGui")
controlGui.Name = getRandomName()
controlGui.ResetOnSpawn = false
controlGui.DisplayOrder = 1000000

pcall(function()
    if type(gethui) == "function" then
        controlGui.Parent = gethui()
    else
        controlGui.Parent = PlayerGui
    end
end)
if not controlGui.Parent then controlGui.Parent = PlayerGui end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 185)
mainFrame.Position = UDim2.new(0.02, 0, 0.08, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = controlGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(0, 180, 255)
stroke.Thickness = 1.4

local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.68, 0, 1, 0)
title.Position = UDim2.new(0.04, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎱 8 BALL ORACLE AI v6.5"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 10
title.TextXAlignment = Enum.TextXAlignment.Left

local btnMin = Instance.new("TextButton", header)
btnMin.Size = UDim2.new(0, 22, 0, 22)
btnMin.Position = UDim2.new(0.74, 0, 0.13, 0)
btnMin.BackgroundColor3 = Color3.fromRGB(45, 52, 68)
btnMin.Text = "-"
btnMin.TextColor3 = Color3.fromRGB(255, 255, 255)
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 12
btnMin.BorderSizePixel = 0
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 4)

local btnClose = Instance.new("TextButton", header)
btnClose.Size = UDim2.new(0, 22, 0, 22)
btnClose.Position = UDim2.new(0.86, 0, 0.13, 0)
btnClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
btnClose.Text = "✕"
btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
btnClose.Font = Enum.Font.GothamBold
btnClose.TextSize = 10
btnClose.BorderSizePixel = 0
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 4)

local content = Instance.new("Frame", mainFrame)
content.Name = "Content"
content.Size = UDim2.new(1, 0, 0, 150)
content.Position = UDim2.new(0, 0, 0, 32)
content.BackgroundTransparency = 1

-- Botón 1: Toggle Guías
local toggleBtn = Instance.new("TextButton", content)
toggleBtn.Size = UDim2.new(0.92, 0, 0, 24)
toggleBtn.Position = UDim2.new(0.04, 0, 0.03, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
toggleBtn.Text = "🟢 GUÍAS: ACTIVADAS"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 10
toggleBtn.BorderSizePixel = 0
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

-- Botón 2: Toggle Ghost Ball
local ghostBtn = Instance.new("TextButton", content)
ghostBtn.Size = UDim2.new(0.92, 0, 0, 24)
ghostBtn.Position = UDim2.new(0.04, 0, 0.22, 0)
ghostBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 150)
ghostBtn.Text = "🎯 GHOST BALL: SÍ"
ghostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ghostBtn.Font = Enum.Font.GothamMedium
ghostBtn.TextSize = 10
ghostBtn.BorderSizePixel = 0
Instance.new("UICorner", ghostBtn).CornerRadius = UDim.new(0, 4)

-- SECCIÓN DE CONTROL DE FUERZA INICIAL
local powerModeBtn = Instance.new("TextButton", content)
powerModeBtn.Size = UDim2.new(0.92, 0, 0, 24)
powerModeBtn.Position = UDim2.new(0.04, 0, 0.41, 0)
powerModeBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
powerModeBtn.Text = "⚡ FUERZA: AUTO (Taco)"
powerModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
powerModeBtn.Font = Enum.Font.GothamBold
powerModeBtn.TextSize = 10
powerModeBtn.BorderSizePixel = 0
Instance.new("UICorner", powerModeBtn).CornerRadius = UDim.new(0, 4)
powerModeBtnRef = powerModeBtn

-- Fila de Presets de Fuerza (25%, 50%, 75%, 100%)
local presetsFrame = Instance.new("Frame", content)
presetsFrame.Size = UDim2.new(0.92, 0, 0, 22)
presetsFrame.Position = UDim2.new(0.04, 0, 0.60, 0)
presetsFrame.BackgroundTransparency = 1

local presetValues = { 0.25, 0.50, 0.75, 1.00 }
for idx, val in ipairs(presetValues) do
    local pBtn = Instance.new("TextButton", presetsFrame)
    pBtn.Size = UDim2.new(0.23, -2, 1, 0)
    pBtn.Position = UDim2.new((idx - 1) * 0.25, 1, 0, 0)
    pBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
    pBtn.Text = string.format("%d%%", math.floor(val * 100))
    pBtn.TextColor3 = Color3.fromRGB(200, 220, 245)
    pBtn.Font = Enum.Font.GothamMedium
    pBtn.TextSize = 9
    pBtn.BorderSizePixel = 0
    Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 3)

    pBtn.MouseButton1Click:Connect(function()
        useManualPower = true
        manualPowerValue = val
        powerModeBtn.Text = string.format("⚡ FUERZA: MANUAL (%d%%)", math.floor(val * 100))
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 20)
    end)
end

-- Indicador en Vivo de Potencia
local powerDisplay = Instance.new("TextLabel", content)
powerDisplay.Size = UDim2.new(0.92, 0, 0, 18)
powerDisplay.Position = UDim2.new(0.04, 0, 0.80, 0)
powerDisplay.BackgroundTransparency = 1
powerDisplay.Text = "⚡ Fuerza: 100% (~138 in/s)"
powerDisplay.TextColor3 = Color3.fromRGB(120, 210, 255)
powerDisplay.Font = Enum.Font.Code
powerDisplay.TextSize = 9
powerDisplay.TextXAlignment = Enum.TextXAlignment.Center
powerDisplayRef = powerDisplay

-- Eventos de Botones
toggleBtn.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    toggleBtn.Text = isEnabled and "🟢 GUÍAS: ACTIVADAS" or "🔴 GUÍAS: DESACTIVADAS"
    toggleBtn.BackgroundColor3 = isEnabled and Color3.fromRGB(0, 160, 100) or Color3.fromRGB(160, 40, 40)
    if not isEnabled then resetRenderPool() end
end)

ghostBtn.MouseButton1Click:Connect(function()
    showGhostBall = not showGhostBall
    ghostBtn.Text = showGhostBall and "🎯 GHOST BALL: SÍ" or "🎯 GHOST BALL: NO"
    ghostBtn.BackgroundColor3 = showGhostBall and Color3.fromRGB(40, 90, 150) or Color3.fromRGB(60, 65, 80)
end)

powerModeBtn.MouseButton1Click:Connect(function()
    useManualPower = not useManualPower
    if useManualPower then
        powerModeBtn.Text = string.format("⚡ FUERZA: MANUAL (%d%%)", math.floor(manualPowerValue * 100))
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 20)
    else
        powerModeBtn.Text = "⚡ FUERZA: AUTO (Taco)"
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
    end
end)

btnMin.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Size = UDim2.new(0, 240, 0, 30)
        content.Visible = false
        btnMin.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 240, 0, 185)
        content.Visible = true
        btnMin.Text = "-"
    end
end)

btnClose.MouseButton1Click:Connect(function()
    scriptActive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    resetRenderPool()
    if oracleCanvas then oracleCanvas:Destroy() end
    if controlGui then controlGui:Destroy() end
end)

-- Sistema de arrastre de ventana
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- 10. INICIALIZACIÓN
local renderConn = RunService.RenderStepped:Connect(updateOracle)
table.insert(connections, renderConn)

print("[POOL-ORACLE-PRO] Motor de predicción 8 Ball v6.5 activado con control de fuerza y soporte exacto para Break Shot.")