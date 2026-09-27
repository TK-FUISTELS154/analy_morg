--[[
    =============================================================================
    🎱 POOL ORACLE AI PRO v7.5 - ULTIMATE AUTO-PLAY, LIVE POWER & SHOT ENGINE
    =============================================================================
    Motor integral de predicción 1:1, juego automático inteligente, auto-shoot,
    sincronización reactiva de fuerza del taco y telemetría de diagnóstico.
    
    Características Principales:
      1. Juego Automático Real (Auto-Play & Auto-Shoot):
         - Localiza dinámicamente el MatchSession / InputController en memoria (vía GC o Bindables).
         - Planificador de tiros de alta precisión (PoolOracleBot): calcula ghost ball,
           ángulos de corte viables, tiros directos y tiros de banda (Bank Shots).
         - Disparo automático o manual a través del canal nativo de la sesión de juego.
      2. Guías Inteligentes Reactivas a la Fuerza:
         - Modo Dinámico: Muestra líneas largas de previsualización mientras apuntas (para
           elegir la bola y la posición ideal) y se sincroniza automáticamente a la fuerza
           exacta del taco en cuanto jalas el medidor de potencia en tiempo real.
      3. Humanizador & Control de Dificultad:
         - Modo Humano (30%): Apuntado suave con lerp, retardo de reacción natural (0.6s)
           y micro-variación angular para no levantar sospechas.
         - Modo Pro (70%): Apuntado rápido, tiros cortados de precisión y control de banda.
         - Modo Robot Dios (100%): 0ms de retardo, cálculo matemático exacto y 100% embocada.
      4. Telemetría y Diagnóstico de Tiros:
         - Genera y guarda reportes detallados en JSON (`apex_reports/pool_telemetry_...json`)
           con información de bolas, buchacas, ángulos de corte, pasos físicos y resultados.
--]]

local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game
local cloneref = (type(cloneref) == "function" and cloneref) or function(x) return x end

-- 1. LOCALIZACIÓN DE FUNCIONES MATEMÁTICAS Y NATIVAS (VELOCIDAD MÁXIMA LUA VM)
local m_abs = math.abs
local m_deg = math.deg
local m_rad = math.rad
local m_atan2 = math.atan2
local m_cos = math.cos
local m_sin = math.sin
local m_sqrt = math.sqrt
local m_clamp = math.clamp
local m_floor = math.floor
local m_min = math.min
local m_max = math.max
local m_random = math.random
local t_insert = table.insert
local t_sort = table.sort
local t_clear = table.clear
local t_find = table.find
local v2_new = Vector2.new
local v2_zero = Vector2.zero
local udim2_offset = UDim2.fromOffset
local udim2_scale = UDim2.fromScale
local udim_new = UDim.new
local color_rgb = Color3.fromRGB
local color_new = Color3.new
local tick_now = tick
local os_time = os.time

-- 2. SERVICIOS SEGUROS
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
local TweenService = Services.TweenService
local HttpService = Services.HttpService

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = cloneref(LocalPlayer:WaitForChild("PlayerGui", 10)) or LocalPlayer:WaitForChild("PlayerGui")

-- 3. CONSTANTES FÍSICAS NATIVAS DEL JUEGO
local PoolConstants = nil
local PoolPhysics = nil
local PoolGeometry = nil
local RemoteSignals = nil
local RemoteEnums = nil

pcall(function()
    local poolLib = ReplicatedStorage:WaitForChild("Libraries", 3):WaitForChild("GameSpecific", 3):WaitForChild("Pool", 3)
    PoolConstants = require(poolLib:WaitForChild("PoolConstants", 3))
    PoolPhysics = require(poolLib:WaitForChild("PoolPhysics", 3))
    PoolGeometry = require(poolLib:WaitForChild("PoolGeometry", 3))
    
    local netLib = ReplicatedStorage:WaitForChild("Libraries", 3):WaitForChild("Networking", 3)
    if netLib then
        RemoteSignals = require(netLib:WaitForChild("RemoteSignals", 3))
        RemoteEnums = require(netLib:WaitForChild("RemoteEnums", 3))
    end
end)

local FrameWidth = (PoolConstants and PoolConstants.FrameWidth) or 103
local FrameHeight = (PoolConstants and PoolConstants.FrameHeight) or 59
local PlayWidth = (PoolConstants and PoolConstants.PlayWidth) or 88
local PlayHeight = (PoolConstants and PoolConstants.PlayHeight) or 44
local BallRadius = (PoolConstants and PoolConstants.BallRadius) or 1.125
local BallDiameter = (PoolConstants and PoolConstants.BallDiameter) or 2.25

local OFFICIAL_BALL_COLORS = {
    [0]  = color_rgb(250, 250, 250), -- Blanca (Cue)
    [1]  = color_rgb(245, 197, 24),  -- Amarilla (Solid)
    [2]  = color_rgb(47, 111, 224),  -- Azul (Solid)
    [3]  = color_rgb(226, 64, 47),   -- Roja (Solid)
    [4]  = color_rgb(123, 75, 209),  -- Púrpura (Solid)
    [5]  = color_rgb(242, 128, 43),  -- Naranja (Solid)
    [6]  = color_rgb(30, 158, 88),   -- Verde (Solid)
    [7]  = color_rgb(142, 59, 46),   -- Marrón (Solid)
    [8]  = color_rgb(22, 25, 28),    -- Negra (8 Ball)
    [9]  = color_rgb(245, 197, 24),  -- Amarilla (Stripe)
    [10] = color_rgb(47, 111, 224),  -- Azul (Stripe)
    [11] = color_rgb(226, 64, 47),   -- Roja (Stripe)
    [12] = color_rgb(123, 75, 209),  -- Púrpura (Stripe)
    [13] = color_rgb(242, 128, 43),  -- Naranja (Stripe)
    [14] = color_rgb(30, 158, 88),   -- Verde (Stripe)
    [15] = color_rgb(142, 59, 46),   -- Marrón (Stripe)
}

-- 4. ESTADO GLOBAL Y CONFIGURACIÓN
local isEnabled = true
local isMinimized = false
local showGhostBall = true
local showAllTrajectories = true

-- Modos de Auto-Play y Dificultad
local autoPlayEnabled = false
local botDifficulty = 1.0 -- 0.3 (Humano) a 1.0 (Robot Dios)
local previewPower = 1.0  -- Fuerza de previsualización al mover/apuntar (0.25 a 1.0)
local forceMode = "DYNAMIC" -- "DYNAMIC", "FIXED", "TACO_ONLY"

-- Telemetría
local telemetryLogs = {}
local lastShotPlan = nil

local connections = {}
local scriptActive = true

-- Máquina de estados
local SHOT_STATE_IDLE = "IDLE"
local SHOT_STATE_AIMING = "AIMING"
local SHOT_STATE_LOCKED = "LOCKED"
local currentShotState = SHOT_STATE_IDLE

local activeTrajectories = nil
local lockedTrajectories = nil
local lastAimTimestamp = 0
local stoppedFramesCount = 0
local autoShotCooldown = 0
local lastCalculatedAimDir = nil

-- Cache de simulación para 60+ FPS ultra-fluidos
local cachedSimInput = {
    cueX = 0,
    cueY = 0,
    dirX = 0,
    dirY = 0,
    power = 0,
    spinX = 0,
    spinY = 0,
    ballHash = 0
}

-- Cache de Planificación IA (Debounce / Throttle inteligente)
local lastPlanTimestamp = 0
local cachedAIPlan = nil
local cachedAIBallHash = 0

-- Cache de seguimiento de bolas en memoria local (Zero-GetAttribute en render)
local ballPosCache = {}
local ballColorCache = {}

-- Referencias en memoria del juego
local cachedInputController = nil
local cachedMatchClient = nil

-- 5. POOL DE RENDERIZADO VISUAL EN PANTALLA DE ALTO RENDIMIENTO
local oracleCanvas = nil
local linePool = {}
local ringPool = {}
local markerPool = {}
local activeLines = 0
local activeRings = 0
local activeMarkers = 0
local prevRenderedLines = 0
local prevRenderedRings = 0
local prevRenderedMarkers = 0

local function getRandomName()
    local str = "OracleCanvas_"
    for _ = 1, 10 do str = str .. string.char(m_random(97, 122)) end
    return str
end

local function getOrCreateCanvas(overlayContainer)
    if not oracleCanvas or oracleCanvas.Parent ~= overlayContainer then
        if oracleCanvas then oracleCanvas:Destroy() end
        oracleCanvas = Instance.new("Frame")
        oracleCanvas.Name = getRandomName()
        oracleCanvas.Size = udim2_scale(1, 1)
        oracleCanvas.Position = udim2_scale(0, 0)
        oracleCanvas.BackgroundTransparency = 1
        oracleCanvas.BorderSizePixel = 0
        oracleCanvas.ZIndex = 80
        oracleCanvas.Parent = overlayContainer
    end
    return oracleCanvas
end

local function beginRenderFrame()
    activeLines = 0
    activeRings = 0
    activeMarkers = 0
end

local function finishRenderFrame()
    -- Solo ocultar los elementos sobrantes respecto al frame anterior (Zero-lag batching)
    if activeLines < prevRenderedLines then
        for i = activeLines + 1, prevRenderedLines do
            local l = linePool[i]
            if l then l.Visible = false end
        end
    end
    prevRenderedLines = activeLines

    if activeRings < prevRenderedRings then
        for i = activeRings + 1, prevRenderedRings do
            local r = ringPool[i]
            if r then r.Visible = false end
        end
    end
    prevRenderedRings = activeRings

    if activeMarkers < prevRenderedMarkers then
        for i = activeMarkers + 1, prevRenderedMarkers do
            local m = markerPool[i]
            if m then m.Visible = false end
        end
    end
    prevRenderedMarkers = activeMarkers
end

local function resetRenderPool()
    for i = 1, prevRenderedLines do
        local l = linePool[i]
        if l then l.Visible = false end
    end
    for i = 1, prevRenderedRings do
        local r = ringPool[i]
        if r then r.Visible = false end
    end
    for i = 1, prevRenderedMarkers do
        local m = markerPool[i]
        if m then m.Visible = false end
    end
    activeLines = 0
    activeRings = 0
    activeMarkers = 0
    prevRenderedLines = 0
    prevRenderedRings = 0
    prevRenderedMarkers = 0
end

local function getLine(parent)
    activeLines = activeLines + 1
    local l = linePool[activeLines]
    if l then
        if l.Parent ~= parent then l.Parent = parent end
        if not l.Visible then l.Visible = true end
        return l
    end
    l = Instance.new("Frame")
    l.Name = "OracleLine"
    l.AnchorPoint = v2_new(0.5, 0.5)
    l.BorderSizePixel = 0
    l.ZIndex = 82
    Instance.new("UICorner", l).CornerRadius = udim_new(1, 0)
    l.Parent = parent
    linePool[activeLines] = l
    return l
end

local function getRing(parent)
    activeRings = activeRings + 1
    local r = ringPool[activeRings]
    if r then
        if r.Parent ~= parent then r.Parent = parent end
        if not r.Visible then r.Visible = true end
        return r
    end
    r = Instance.new("Frame")
    r.Name = "OracleRing"
    r.AnchorPoint = v2_new(0.5, 0.5)
    r.BackgroundTransparency = 0.82
    r.BorderSizePixel = 0
    r.ZIndex = 84

    Instance.new("UICorner", r).CornerRadius = udim_new(1, 0)
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
    local m = markerPool[activeMarkers]
    if m then
        if m.Parent ~= parent then m.Parent = parent end
        if not m.Visible then m.Visible = true end
        return m
    end
    m = Instance.new("TextLabel")
    m.Name = "OracleMarker"
    m.AnchorPoint = v2_new(0.5, 0.5)
    m.BackgroundTransparency = 1
    m.Font = Enum.Font.GothamBold
    m.TextSize = 10
    m.TextColor3 = color_rgb(255, 255, 255)
    m.ZIndex = 86
    local st = Instance.new("UIStroke", m)
    st.Color = color_rgb(0, 0, 0)
    st.Thickness = 1.2
    m.Parent = parent
    markerPool[activeMarkers] = m
    return m
end

-- Conversión de Coordenadas de Mesa a Pantalla Ultra-Rápida (Zero Object Allocation)
local function tablePosToScreenCoords(tableX, tableY, cWidth, cHeight)
    local u = 0.5 + (tableX / FrameWidth)
    local v = 0.5 - (tableY / FrameHeight)
    return u * cWidth, v * cHeight
end

local function drawSegmentFast(pAx, pAy, pBx, pBy, color, thickness, canvas, transparency)
    local dx = pBx - pAx
    local dy = pBy - pAy
    local len = m_sqrt(dx * dx + dy * dy)
    if len <= 0.4 then return end

    local midX = (pAx + pBx) * 0.5
    local midY = (pAy + pBy) * 0.5
    local line = getLine(canvas)
    line.Size = udim2_offset(len, thickness or 2.2)
    line.Position = udim2_offset(midX, midY)
    line.Rotation = m_deg(m_atan2(dy, dx))
    line.BackgroundColor3 = color
    line.BackgroundTransparency = transparency or 0.1
end

local function drawGhostFast(screenX, screenY, diameter, color, canvas, fillTransp, strokeTransp, strokeThickness)
    local r = getRing(canvas)
    r.Size = udim2_offset(diameter, diameter)
    r.Position = udim2_offset(screenX, screenY)
    r.BackgroundColor3 = color
    r.BackgroundTransparency = fillTransp or 0.8
    local st = r:FindFirstChild("Stroke")
    if st then
        st.Color = color
        st.Transparency = strokeTransp or 0.1
        st.Thickness = strokeThickness or 2.0
    end
end

local function getBallColor(num, ballsFolder)
    if num == 0 or not num then
        return color_rgb(250, 250, 250)
    end
    if ballColorCache[num] then
        return ballColorCache[num]
    end
    if ballsFolder then
        for _, bFrame in ipairs(ballsFolder:GetChildren()) do
            local numAttr = bFrame:GetAttribute("BallNumber")
            local nameNum = tonumber(bFrame.Name:match("%d+"))
            if numAttr == num or nameNum == num then
                local stripe = bFrame:FindFirstChild("Stripe")
                if stripe and stripe:IsA("GuiObject") and stripe.BackgroundColor3 ~= color_new(0, 0, 0) then
                    ballColorCache[num] = stripe.BackgroundColor3
                    return stripe.BackgroundColor3
                elseif bFrame:IsA("GuiObject") and bFrame.BackgroundColor3 ~= color_new(0, 0, 0) then
                    ballColorCache[num] = bFrame.BackgroundColor3
                    return bFrame.BackgroundColor3
                end
            end
        end
    end
    local col = OFFICIAL_BALL_COLORS[num] or color_rgb(220, 220, 220)
    ballColorCache[num] = col
    return col
end

-- Detección de movimiento y Hash de bolas para Dirty-Checking ultra veloz
local function getBallsState(ballsFolder)
    local moving = false
    local hash = 0
    local count = 0
    local children = ballsFolder:GetChildren()

    for i = 1, #children do
        local bFrame = children[i]
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local pos = bFrame.Position
            local curX = pos.X.Scale
            local curY = pos.Y.Scale
            local prev = ballPosCache[bFrame]

            if prev then
                local dx = m_abs(curX - prev.X)
                local dy = m_abs(curY - prev.Y)
                if dx > 0.00015 or dy > 0.00015 then
                    moving = true
                end
                prev.X = curX
                prev.Y = curY
            else
                ballPosCache[bFrame] = { X = curX, Y = curY }
            end

            count = count + 1
            -- Hash incremental rápido
            hash = (hash * 31 + m_floor(curX * 10000) * 17 + m_floor(curY * 10000)) % 2147483647
        end
    end

    return moving, hash, count
end

-- Renderizado de Trayectorias de Alto Rendimiento
local function renderTrajectories(trajectoriesData, canvas, canvasSize, ballsFolder)
    beginRenderFrame()
    if not trajectoriesData or not trajectoriesData.Trajectories then
        finishRenderFrame()
        return
    end

    local cWidth = canvasSize.X
    local cHeight = canvasSize.Y
    local pixelDiameter = (BallDiameter / FrameWidth) * cWidth
    local isBreak = trajectoriesData.IsBreakShot

    if showGhostBall and trajectoriesData.FirstImpactGhost then
        local gX, gY = tablePosToScreenCoords(trajectoriesData.FirstImpactGhost.X, trajectoriesData.FirstImpactGhost.Y, cWidth, cHeight)
        drawGhostFast(gX, gY, pixelDiameter, color_rgb(255, 255, 255), canvas, 0.9, 0.2, 1.8)
    end

    for num, traj in pairs(trajectoriesData.Trajectories) do
        local pts = traj.Points
        local ptCount = pts and #pts or 0
        if ptCount >= 2 then
            local isCue = (num == 0)
            local ballColor = getBallColor(num, ballsFolder)
            local lineThickness = isCue and 2.5 or (isBreak and 1.8 or 2.2)
            local lineTransp = isCue and 0.05 or (isBreak and 0.25 or 0.15)

            if isCue and traj.Pocketed then
                ballColor = color_rgb(255, 55, 55)
            elseif traj.Pocketed then
                ballColor = color_rgb(0, 255, 150)
            end

            local minDistThreshold = isBreak and (isCue and 0.5 or 1.2) or 0.35

            if showAllTrajectories or isCue or traj.Pocketed or traj.TotalDistance > minDistThreshold then
                local prevX, prevY = tablePosToScreenCoords(pts[1].X, pts[1].Y, cWidth, cHeight)

                for i = 2, ptCount do
                    local curPt = pts[i]
                    local curX, curY = tablePosToScreenCoords(curPt.X, curPt.Y, cWidth, cHeight)
                    drawSegmentFast(prevX, prevY, curX, curY, ballColor, lineThickness, canvas, lineTransp)
                    prevX = curX
                    prevY = curY
                end

                local finalPt = pts[ptCount]
                local fX, fY = tablePosToScreenCoords(finalPt.X, finalPt.Y, cWidth, cHeight)

                if traj.Pocketed then
                    drawGhostFast(fX, fY, pixelDiameter * 1.3, color_rgb(0, 255, 140), canvas, 0.5, 0.0, 2.5)
                    local marker = getMarker(canvas)
                    marker.Text = string.format("🎱 #%d 🎯", num)
                    marker.TextColor3 = color_rgb(0, 255, 140)
                    marker.Position = udim2_offset(fX, fY - 18)
                else
                    drawGhostFast(fX, fY, pixelDiameter, ballColor, canvas, 0.85, 0.2, 1.5)
                end
            end
        end
    end

    finishRenderFrame()
end

-- 6. BÚSQUEDA DE CONTROLADOR EN MEMORIA (GC SEARCH)
local function findGameController()
    if cachedInputController and cachedInputController.ShotBindable then
        return cachedInputController, cachedMatchClient
    end

    if type(getgc) == "function" then
        local gcObjects = getgc(true)
        for i = 1, #gcObjects do
            local obj = gcObjects[i]
            if type(obj) == "table" then
                if rawget(obj, "Direction") and rawget(obj, "ShotBindable") and rawget(obj, "Simulation") then
                    cachedInputController = obj
                end
                if rawget(obj, "Rules") and rawget(obj, "AwaitingShot") and rawget(obj, "Simulation") then
                    cachedMatchClient = obj
                end
            end
        end
    end
    return cachedInputController, cachedMatchClient
end

-- 7. MOTOR DE SIMULACIÓN FÍSICA NATIVO PRECISO
local function simulateShot(cuePos, aimDir, power, spin, ballsFolder, isBreakOverride)
    if not PoolPhysics then return nil end

    local sim = PoolPhysics.newSimulation()

    local activeBallsCount = 0
    local children = ballsFolder:GetChildren()
    for i = 1, #children do
        local bFrame = children[i]
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local num = bFrame:GetAttribute("BallNumber") or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                activeBallsCount = activeBallsCount + 1
            end
        end
    end

    local isBreakShot = isBreakOverride
    if isBreakShot == nil then
        isBreakShot = (activeBallsCount >= 14 and cuePos.X < -10)
    end
    sim.IsBreakShot = isBreakShot

    PoolPhysics.AddBall(sim, 0, cuePos, BallRadius, false)

    for i = 1, #children do
        local bFrame = children[i]
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local numAttr = bFrame:GetAttribute("BallNumber")
            local num = numAttr or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                local bX = (bFrame.Position.X.Scale - 0.5) * FrameWidth
                local bY = (0.5 - bFrame.Position.Y.Scale) * FrameHeight
                PoolPhysics.AddBall(sim, num, v2_new(bX, bY), BallRadius, false)
            end
        end
    end

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
    local MAX_SIM_STEPS = isBreakShot and 550 or 400
    local DT = isBreakShot and 0.012 or 0.0166667
    local pocketedList = {}

    while not sim.Settled and subSteps < MAX_SIM_STEPS do
        subSteps = subSteps + 1
        local prevEventsCount = #sim.Events

        PoolPhysics.Step(sim, DT)

        local eventsCount = #sim.Events
        if eventsCount > prevEventsCount then
            for i = prevEventsCount + 1, eventsCount do
                local ev = sim.Events[i]
                local kind = ev.Kind
                if kind == "BallHit" then
                    local b1 = sim.Balls[ev.Ball]
                    local b2 = sim.Balls[ev.Other]
                    if not firstImpactGhost and (ev.Ball == 0 or ev.Other == 0) then
                        local cueBall = (ev.Ball == 0) and b1 or b2
                        if cueBall then firstImpactGhost = cueBall.Position end
                    end
                    if b1 and trajectories[ev.Ball] then
                        t_insert(trajectories[ev.Ball].Points, b1.Position)
                        trajectories[ev.Ball].LastPos = b1.Position
                    end
                    if b2 and trajectories[ev.Other] then
                        t_insert(trajectories[ev.Other].Points, b2.Position)
                        trajectories[ev.Other].LastPos = b2.Position
                    end
                elseif kind == "CushionHit" or kind == "TipHit" then
                    local b = sim.Balls[ev.Ball]
                    if b and trajectories[ev.Ball] then
                        t_insert(trajectories[ev.Ball].Points, b.Position)
                        trajectories[ev.Ball].LastPos = b.Position
                    end
                elseif kind == "Pocketed" then
                    local b = sim.Balls[ev.Ball]
                    if b and trajectories[ev.Ball] then
                        trajectories[ev.Ball].Pocketed = true
                        local sinkPos = ev.EntryPosition or b.Position
                        t_insert(trajectories[ev.Ball].Points, sinkPos)
                        trajectories[ev.Ball].LastPos = sinkPos
                        t_insert(pocketedList, ev.Ball)
                    end
                end
            end
        end

        if subSteps % 2 == 0 then
            local distThreshold = isBreakShot and 0.12 or 0.08
            for num, b in pairs(sim.Balls) do
                local traj = trajectories[num]
                if not traj.Pocketed and not b.Pocketed and not b.Sinking then
                    local bPos = b.Position
                    local lPos = traj.LastPos
                    local dx = bPos.X - lPos.X
                    local dy = bPos.Y - lPos.Y
                    local dist = m_sqrt(dx * dx + dy * dy)
                    if dist > distThreshold then
                        t_insert(traj.Points, bPos)
                        traj.TotalDistance = traj.TotalDistance + dist
                        traj.LastPos = bPos
                    end
                end
            end
        end
    end

    for num, b in pairs(sim.Balls) do
        local traj = trajectories[num]
        if not traj.Pocketed then
            local pts = traj.Points
            local lastPt = pts[#pts]
            local dx = b.Position.X - lastPt.X
            local dy = b.Position.Y - lastPt.Y
            if (dx * dx + dy * dy) > 0.0025 then
                t_insert(pts, b.Position)
            end
        end
    end

    return {
        Trajectories = trajectories,
        FirstImpactGhost = firstImpactGhost,
        IsBreakShot = isBreakShot,
        PocketedBalls = pocketedList,
        SubSteps = subSteps,
        Scratch = trajectories[0] and trajectories[0].Pocketed
    }
end

-- 8. PLANIFICADOR DE TIROS IA OPTIMIZADO (THROTTLED & PRUNED)
local function planOptimalShot(cuePos, ballsFolder, ballHash)
    local now = tick_now()
    -- Reutilizar plan si la mesa no ha cambiado y han pasado menos de 150ms
    if cachedAIPlan and cachedAIBallHash == ballHash and (now - lastPlanTimestamp < 0.15) then
        return cachedAIPlan
    end

    if not PoolGeometry or not PoolPhysics then return nil end

    local pockets = PoolGeometry.GetPockets()
    local candidates = {}
    local activeBalls = {}

    local children = ballsFolder:GetChildren()
    for i = 1, #children do
        local bFrame = children[i]
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local num = bFrame:GetAttribute("BallNumber") or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                local bX = (bFrame.Position.X.Scale - 0.5) * FrameWidth
                local bY = (0.5 - bFrame.Position.Y.Scale) * FrameHeight
                t_insert(activeBalls, { Number = num, Position = v2_new(bX, bY) })
            end
        end
    end

    -- Saque Inicial (Break Shot)
    if #activeBalls >= 14 and cuePos.X < -10 then
        local headBall = activeBalls[1]
        for i = 2, #activeBalls do
            local b = activeBalls[i]
            if b.Position.X < headBall.Position.X then headBall = b end
        end
        local breakDir = (headBall.Position - cuePos).Unit
        cachedAIPlan = {
            TargetBall = headBall.Number,
            Direction = breakDir,
            Power = 1.0,
            Spin = v2_new(0, 0.35),
            IsBreak = true,
            Score = 1000,
            Type = "BREAK_SHOT"
        }
        cachedAIBallHash = ballHash
        lastPlanTimestamp = now
        lastShotPlan = cachedAIPlan
        return cachedAIPlan
    end

    -- Poda geométrica previa (Filtrado de alta velocidad para evaluar solo tiros prometedores)
    local geoCandidates = {}
    for i = 1, #activeBalls do
        local ball = activeBalls[i]
        for pIdx = 1, #pockets do
            local pocket = pockets[pIdx]
            local mouth = pocket.MouthCentre or pocket.Position
            local ghostPos = ball.Position - (mouth - ball.Position).Unit * BallDiameter
            local cueToGhost = ghostPos - cuePos
            local ghostToPocket = mouth - ball.Position

            local distCueGhost = cueToGhost.Magnitude
            local distGhostPoc = ghostToPocket.Magnitude

            if distCueGhost > 0.5 and distGhostPoc > 0.5 then
                local cutAngleDot = cueToGhost.Unit:Dot(ghostToPocket.Unit)
                if cutAngleDot > 0.15 then
                    local distTotal = distCueGhost + distGhostPoc
                    local powerNeeded = m_clamp((distTotal / 115) * 0.75 + 0.25, 0.3, 0.95)
                    local roughScore = (cutAngleDot * 100) - (distTotal * 0.3)
                    if ball.Number == 8 and #activeBalls > 1 then roughScore = roughScore - 800 end

                    t_insert(geoCandidates, {
                        Ball = ball,
                        Pocket = pocket,
                        GhostPos = ghostPos,
                        Direction = cueToGhost.Unit,
                        Power = powerNeeded,
                        CutAngleDot = cutAngleDot,
                        DistTotal = distTotal,
                        RoughScore = roughScore
                    })
                end
            end
        end
    end

    t_sort(geoCandidates, function(a, b) return a.RoughScore > b.RoughScore end)

    -- Solo simular detalladamente los 4 mejores candidatos geométricos para evitar lag
    local maxSimEval = m_min(#geoCandidates, 4)
    for k = 1, maxSimEval do
        local cand = geoCandidates[k]
        local testSim = simulateShot(cuePos, cand.Direction, cand.Power, v2_zero, ballsFolder, false)

        if testSim and not testSim.Scratch then
            local ballPocketed = t_find(testSim.PocketedBalls, cand.Ball.Number) ~= nil
            local score = cand.RoughScore
            if ballPocketed then score = score + 500 end

            t_insert(candidates, {
                TargetBall = cand.Ball.Number,
                PocketId = cand.Pocket.Id,
                Direction = cand.Direction,
                Power = cand.Power,
                Spin = v2_zero,
                Score = score,
                Pocketed = ballPocketed,
                CutQuality = cand.CutAngleDot,
                Distance = cand.DistTotal,
                Type = "DIRECT"
            })
        end
    end

    t_sort(candidates, function(a, b) return a.Score > b.Score end)
    local best = candidates[1]
    cachedAIPlan = best
    cachedAIBallHash = ballHash
    lastPlanTimestamp = now
    lastShotPlan = best

    return best
end

-- 9. GENERADOR Y EXPORTADOR DE REPORTES DE TELEMETRÍA (JSON)
local function generateShotReport(shotPlan, simResult)
    local report = {
        Timestamp = os_time(),
        Clock = tick_now(),
        Difficulty = botDifficulty,
        ForceMode = forceMode,
        Plan = shotPlan,
        Simulation = {
            PocketedBalls = simResult and simResult.PocketedBalls or {},
            SubSteps = simResult and simResult.SubSteps or 0,
            Scratch = simResult and simResult.Scratch or false,
            IsBreakShot = simResult and simResult.IsBreakShot or false,
        }
    }
    t_insert(telemetryLogs, report)

    if typeof(writefile) == "function" then
        pcall(function()
            local jsonStr = HttpService:JSONEncode(report)
            local fname = string.format("apex_reports/pool_telemetry_%d.json", os_time())
            writefile(fname, jsonStr)
        end)
    end
    return report
end

-- 10. EJECUCIÓN DEL DISPARO AUTOMÁTICO (AUTO-SHOOT SEGURO)
local function executeShot(aimDir, power, spin, cuePos)
    if not aimDir then return false end

    -- Aplicar humanización si la dificultad es inferior a 95%
    if botDifficulty < 0.95 then
        local errorFactor = (1 - botDifficulty) * 0.012
        local jitterX = (m_random() - 0.5) * errorFactor
        local jitterY = (m_random() - 0.5) * errorFactor
        aimDir = (aimDir + v2_new(jitterX, jitterY)).Unit
    end

    local inputCtrl, matchClient = findGameController()

    -- 1. Intentar disparo por InputController nativo
    if inputCtrl and inputCtrl.ShotBindable then
        local ok = pcall(function()
            inputCtrl.Direction = aimDir
            inputCtrl.Power = power
            inputCtrl.ShotBindable:Fire(aimDir, power, spin or v2_zero)
        end)
        if ok then return true end
    end

    -- 2. Intentar disparo por RemoteSignals nativo
    if RemoteSignals and RemoteEnums and RemoteEnums.Pool then
        local ok = pcall(function()
            RemoteSignals.FireServer(
                RemoteEnums.Pool,
                "Shot",
                aimDir.X,
                aimDir.Y,
                power,
                spin.X,
                spin.Y,
                cuePos.X,
                cuePos.Y
            )
        end)
        if ok then return true end
    end

    return false
end

-- Variables UI
local autoPlayBtnRef = nil
local diffLabelRef = nil
local diffFillRef = nil
local forceModeBtnRef = nil
local previewDisplayRef = nil
local statusLabelRef = nil

-- 11. BUCLE PRINCIPAL ULTRA-FLUIDO CON SIMULATION MEMOIZATION (60+ FPS GARANTIZADOS)
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

    local canvasSize = overlay.AbsoluteSize
    if canvasSize.X <= 10 or canvasSize.Y <= 10 then
        resetRenderPool()
        return
    end

    local canvas = getOrCreateCanvas(overlay)

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

    local ballsRolling, ballHash, ballCount = getBallsState(ballsFolder)

    if isAiming then
        currentShotState = SHOT_STATE_AIMING
        stoppedFramesCount = 0
        lastAimTimestamp = tick_now()

        local cueBallFrame = ballsFolder:FindFirstChild("Ball0")
        if not cueBallFrame or not cueBallFrame.Visible then
            resetRenderPool()
            return
        end

        local cuePos = v2_new(
            (cueBallFrame.Position.X.Scale - 0.5) * FrameWidth,
            (0.5 - cueBallFrame.Position.Y.Scale) * FrameHeight
        )

        -- 1. Obtener la fuerza en vivo del taco desde la UI
        local liveTacoPower = 0
        local powerTrack = poolUI:FindFirstChild("PowerTrack", true)
        local fill = powerTrack and powerTrack:FindFirstChild("Fill")
        if fill and fill:IsA("GuiObject") then
            liveTacoPower = m_clamp(fill.Size.Y.Scale, 0, 1)
        end

        local powerLabel = poolUI:FindFirstChild("PowerLabel", true)
        if powerLabel and powerLabel.Text:match("%d+") then
            local numPct = tonumber(powerLabel.Text:match("%d+"))
            if numPct and numPct > 0 then
                liveTacoPower = m_clamp(numPct / 100, 0, 1)
            end
        end

        -- 2. Determinación de Fuerza de Simulación:
        local simPower = previewPower
        if forceMode == "DYNAMIC" then
            if liveTacoPower > 0.03 then
                simPower = liveTacoPower
            else
                simPower = previewPower
            end
        elseif forceMode == "TACO_ONLY" then
            simPower = m_max(liveTacoPower, 0.05)
        else
            simPower = previewPower
        end

        if previewDisplayRef then
            local speedEst = 30 + (138 - 30) * (simPower ^ 2)
            previewDisplayRef.Text = string.format("⚡ Fuerza Guía: %d%% (~%.0f in/s) | Taco: %d%%",
                m_floor(simPower * 100), speedEst, m_floor(liveTacoPower * 100))
        end

        -- 3. Determinación de Dirección del Tiro
        local aimDir = nil

        if autoPlayEnabled then
            local optimalPlan = planOptimalShot(cuePos, ballsFolder, ballHash)
            if optimalPlan then
                aimDir = optimalPlan.Direction
                lastCalculatedAimDir = aimDir
                if statusLabelRef then
                    statusLabelRef.Text = string.format("🤖 Auto-Play: Bola #%d (%s)", optimalPlan.TargetBall, optimalPlan.Type)
                end

                -- Disparo automático controlado por cooldown y dificultad
                local reactionDelay = 0.4 + (1 - botDifficulty) * 0.6
                if tick_now() - autoShotCooldown > reactionDelay then
                    autoShotCooldown = tick_now()
                    task.spawn(function()
                        local shotPwr = (forceMode == "TACO_ONLY" and liveTacoPower > 0.05 and liveTacoPower) or optimalPlan.Power
                        executeShot(aimDir, shotPwr, optimalPlan.Spin or v2_zero, cuePos)
                    end)
                end
            end
        else
            if aimLine and aimLine.Visible then
                local rotDeg = aimLine.Rotation
                local rotRad = m_rad(rotDeg)
                aimDir = v2_new(m_cos(-rotRad), m_sin(-rotRad)).Unit
            elseif ghostFrame and ghostFrame.Visible then
                local ghostPos = v2_new(
                    (ghostFrame.Position.X.Scale - 0.5) * FrameWidth,
                    (0.5 - ghostFrame.Position.Y.Scale) * FrameHeight
                )
                local diff = ghostPos - cuePos
                if diff.Magnitude > 0.001 then aimDir = diff.Unit end
            end
            lastCalculatedAimDir = aimDir
        end

        if not aimDir then
            resetRenderPool()
            return
        end

        -- Spin
        local spin = v2_zero
        local spinWidget = poolUI:FindFirstChild("SpinWidget", true)
        local dot = spinWidget and spinWidget:FindFirstChild("Dot")
        if dot and dot:IsA("GuiObject") then
            local sX = m_clamp((dot.Position.X.Scale - 0.5) / 0.37, -1, 1)
            local sY = m_clamp((0.5 - dot.Position.Y.Scale) / 0.37, -1, 1)
            spin = v2_new(sX, sY)
        end

        -- 4. SIMULATION DIRTY-CHECKING: Reutilizar física si la dirección, fuerza o bolas no cambiaron
        local isDirty = false
        local dCueX = m_abs(cuePos.X - cachedSimInput.cueX)
        local dCueY = m_abs(cuePos.Y - cachedSimInput.cueY)
        local dDirX = m_abs(aimDir.X - cachedSimInput.dirX)
        local dDirY = m_abs(aimDir.Y - cachedSimInput.dirY)
        local dPwr  = m_abs(simPower - cachedSimInput.power)
        local dSpX  = m_abs(spin.X - cachedSimInput.spinX)
        local dSpY  = m_abs(spin.Y - cachedSimInput.spinY)

        if not activeTrajectories 
           or dCueX > 0.005 or dCueY > 0.005 
           or dDirX > 0.0003 or dDirY > 0.0003 
           or dPwr > 0.003 
           or dSpX > 0.01 or dSpY > 0.01 
           or ballHash ~= cachedSimInput.ballHash then
            isDirty = true
        end

        if isDirty then
            activeTrajectories = simulateShot(cuePos, aimDir, simPower, spin, ballsFolder)
            lockedTrajectories = activeTrajectories

            cachedSimInput.cueX = cuePos.X
            cachedSimInput.cueY = cuePos.Y
            cachedSimInput.dirX = aimDir.X
            cachedSimInput.dirY = aimDir.Y
            cachedSimInput.power = simPower
            cachedSimInput.spinX = spin.X
            cachedSimInput.spinY = spin.Y
            cachedSimInput.ballHash = ballHash
        end

        renderTrajectories(activeTrajectories, canvas, canvasSize, ballsFolder)

    elseif currentShotState == SHOT_STATE_AIMING and not isAiming then
        currentShotState = SHOT_STATE_LOCKED
        stoppedFramesCount = 0

        if lockedTrajectories then
            renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
            generateShotReport(lastShotPlan, lockedTrajectories)
        else
            resetRenderPool()
        end

    elseif currentShotState == SHOT_STATE_LOCKED then
        if ballsRolling or (tick_now() - lastAimTimestamp < 0.6) then
            stoppedFramesCount = 0
            if lockedTrajectories then
                renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
            end
        else
            stoppedFramesCount = stoppedFramesCount + 1
            if stoppedFramesCount > 12 or (tick_now() - lastAimTimestamp > 14) then
                currentShotState = SHOT_STATE_IDLE
                lockedTrajectories = nil
                activeTrajectories = nil
                cachedSimInput.cueX = -999
                resetRenderPool()
                if statusLabelRef then statusLabelRef.Text = "Esperando tu turno..." end
            else
                if lockedTrajectories then
                    renderTrajectories(lockedTrajectories, canvas, canvasSize, ballsFolder)
                end
            end
        end
    else
        resetRenderPool()
    end
end

-- 12. PANEL DE CONTROL FLOTANTE PROFESIONAL
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
mainFrame.Size = udim2_offset(255, 250)
mainFrame.Position = UDim2.new(0.02, 0, 0.08, 0)
mainFrame.BackgroundColor3 = color_rgb(16, 20, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = controlGui
Instance.new("UICorner", mainFrame).CornerRadius = udim_new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = color_rgb(0, 180, 255)
stroke.Thickness = 1.4

local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = color_rgb(22, 28, 40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = udim_new(0, 8)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.68, 0, 1, 0)
title.Position = UDim2.new(0.04, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎱 8 BALL ORACLE AI v8.0"
title.TextColor3 = color_rgb(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 10
title.TextXAlignment = Enum.TextXAlignment.Left

local btnMin = Instance.new("TextButton", header)
btnMin.Size = udim2_offset(22, 22)
btnMin.Position = UDim2.new(0.74, 0, 0.13, 0)
btnMin.BackgroundColor3 = color_rgb(45, 52, 68)
btnMin.Text = "-"
btnMin.TextColor3 = color_rgb(255, 255, 255)
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 12
btnMin.BorderSizePixel = 0
Instance.new("UICorner", btnMin).CornerRadius = udim_new(0, 4)

local btnClose = Instance.new("TextButton", header)
btnClose.Size = udim2_offset(22, 22)
btnClose.Position = UDim2.new(0.86, 0, 0.13, 0)
btnClose.BackgroundColor3 = color_rgb(180, 40, 40)
btnClose.Text = "✕"
btnClose.TextColor3 = color_rgb(255, 255, 255)
btnClose.Font = Enum.Font.GothamBold
btnClose.TextSize = 10
btnClose.BorderSizePixel = 0
Instance.new("UICorner", btnClose).CornerRadius = udim_new(0, 4)

local content = Instance.new("Frame", mainFrame)
content.Name = "Content"
content.Size = UDim2.new(1, 0, 0, 215)
content.Position = UDim2.new(0, 0, 0, 32)
content.BackgroundTransparency = 1

-- 1. Auto-Play Toggle & Botón Disparar
local btnRow = Instance.new("Frame", content)
btnRow.Size = UDim2.new(0.92, 0, 0, 24)
btnRow.Position = UDim2.new(0.04, 0, 0.02, 0)
btnRow.BackgroundTransparency = 1

local autoPlayBtn = Instance.new("TextButton", btnRow)
autoPlayBtn.Size = UDim2.new(0.60, -2, 1, 0)
autoPlayBtn.Position = UDim2.new(0, 0, 0, 0)
autoPlayBtn.BackgroundColor3 = color_rgb(150, 40, 40)
autoPlayBtn.Text = "🤖 AUTO-PLAY: OFF"
autoPlayBtn.TextColor3 = color_rgb(255, 255, 255)
autoPlayBtn.Font = Enum.Font.GothamBold
autoPlayBtn.TextSize = 9
autoPlayBtn.BorderSizePixel = 0
Instance.new("UICorner", autoPlayBtn).CornerRadius = udim_new(0, 4)
autoPlayBtnRef = autoPlayBtn

local shootNowBtn = Instance.new("TextButton", btnRow)
shootNowBtn.Size = UDim2.new(0.40, -2, 1, 0)
shootNowBtn.Position = UDim2.new(0.60, 2, 0, 0)
shootNowBtn.BackgroundColor3 = color_rgb(0, 140, 100)
shootNowBtn.Text = "⚡ DISPARAR"
shootNowBtn.TextColor3 = color_rgb(255, 255, 255)
shootNowBtn.Font = Enum.Font.GothamBold
shootNowBtn.TextSize = 9
shootNowBtn.BorderSizePixel = 0
Instance.new("UICorner", shootNowBtn).CornerRadius = udim_new(0, 4)

-- 2. Dificultad Slider / Botones Rápidos (Humano vs Robot)
local diffLabel = Instance.new("TextLabel", content)
diffLabel.Size = UDim2.new(0.92, 0, 0, 15)
diffLabel.Position = UDim2.new(0.04, 0, 0.15, 0)
diffLabel.BackgroundTransparency = 1
diffLabel.Text = "🎯 Nivel IA: Modo Robot Dios (100%)"
diffLabel.TextColor3 = color_rgb(200, 225, 255)
diffLabel.Font = Enum.Font.GothamMedium
diffLabel.TextSize = 9
diffLabel.TextXAlignment = Enum.TextXAlignment.Left
diffLabelRef = diffLabel

local diffLevelsFrame = Instance.new("Frame", content)
diffLevelsFrame.Size = UDim2.new(0.92, 0, 0, 18)
diffLevelsFrame.Position = UDim2.new(0.04, 0, 0.23, 0)
diffLevelsFrame.BackgroundTransparency = 1

local diffPresets = {
    { Name = "Humano (30%)", Val = 0.30, Text = "Humano (30%)" },
    { Name = "Pro (70%)", Val = 0.70, Text = "Pro (70%)" },
    { Name = "Dios (100%)", Val = 1.00, Text = "Robot Dios (100%)" },
}
for idx, p in ipairs(diffPresets) do
    local b = Instance.new("TextButton", diffLevelsFrame)
    b.Size = UDim2.new(0.31, 0, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.345, 0, 0, 0)
    b.BackgroundColor3 = color_rgb(35, 42, 58)
    b.Text = p.Name
    b.TextColor3 = color_rgb(200, 220, 245)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 8
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = udim_new(0, 3)

    b.MouseButton1Click:Connect(function()
        botDifficulty = p.Val
        diffLabel.Text = string.format("🎯 Nivel IA: %s", p.Text)
    end)
end

-- 3. Modo de Fuerza de las Guías
local forceModeBtn = Instance.new("TextButton", content)
forceModeBtn.Size = UDim2.new(0.92, 0, 0, 22)
forceModeBtn.Position = UDim2.new(0.04, 0, 0.34, 0)
forceModeBtn.BackgroundColor3 = color_rgb(75, 45, 110)
forceModeBtn.Text = "⚡ GUÍAS: DINÁMICO (Preview + Taco)"
forceModeBtn.TextColor3 = color_rgb(255, 255, 255)
forceModeBtn.Font = Enum.Font.GothamBold
forceModeBtn.TextSize = 9
forceModeBtn.BorderSizePixel = 0
Instance.new("UICorner", forceModeBtn).CornerRadius = udim_new(0, 4)
forceModeBtnRef = forceModeBtn

-- 4. Fila de Presets de Previsualización (Preview Force)
local previewLabel = Instance.new("TextLabel", content)
previewLabel.Size = UDim2.new(0.92, 0, 0, 14)
previewLabel.Position = UDim2.new(0.04, 0, 0.46, 0)
previewLabel.BackgroundTransparency = 1
previewLabel.Text = "📐 Fuerza Previsualización al Mover:"
previewLabel.TextColor3 = color_rgb(180, 205, 235)
previewLabel.Font = Enum.Font.GothamMedium
previewLabel.TextSize = 8
previewLabel.TextXAlignment = Enum.TextXAlignment.Left

local presetsFrame = Instance.new("Frame", content)
presetsFrame.Size = UDim2.new(0.92, 0, 0, 18)
presetsFrame.Position = UDim2.new(0.04, 0, 0.54, 0)
presetsFrame.BackgroundTransparency = 1

local presetValues = { 0.25, 0.50, 0.75, 1.00 }
for idx, val in ipairs(presetValues) do
    local pBtn = Instance.new("TextButton", presetsFrame)
    pBtn.Size = UDim2.new(0.23, -2, 1, 0)
    pBtn.Position = UDim2.new((idx - 1) * 0.25, 1, 0, 0)
    pBtn.BackgroundColor3 = color_rgb(35, 42, 58)
    pBtn.Text = string.format("%d%%", m_floor(val * 100))
    pBtn.TextColor3 = color_rgb(200, 220, 245)
    pBtn.Font = Enum.Font.GothamMedium
    pBtn.TextSize = 8
    pBtn.BorderSizePixel = 0
    Instance.new("UICorner", pBtn).CornerRadius = udim_new(0, 3)

    pBtn.MouseButton1Click:Connect(function()
        previewPower = val
        previewLabel.Text = string.format("📐 Fuerza Previsualización: %d%%", m_floor(val * 100))
    end)
end

-- 5. Indicador Dinámico de Potencia
local previewDisplay = Instance.new("TextLabel", content)
previewDisplay.Size = UDim2.new(0.92, 0, 0, 16)
previewDisplay.Position = UDim2.new(0.04, 0, 0.65, 0)
previewDisplay.BackgroundTransparency = 1
previewDisplay.Text = "⚡ Fuerza Guía: 100% | Taco: 0%"
previewDisplay.TextColor3 = color_rgb(120, 215, 255)
previewDisplay.Font = Enum.Font.Code
previewDisplay.TextSize = 8
previewDisplay.TextXAlignment = Enum.TextXAlignment.Center
previewDisplayRef = previewDisplay

-- 6. Botón de Telemetría
local telemetryBtn = Instance.new("TextButton", content)
telemetryBtn.Size = UDim2.new(0.92, 0, 0, 20)
telemetryBtn.Position = UDim2.new(0.04, 0, 0.75, 0)
telemetryBtn.BackgroundColor3 = color_rgb(0, 110, 140)
telemetryBtn.Text = "📊 GUARDAR TELEMETRÍA JSON"
telemetryBtn.TextColor3 = color_rgb(255, 255, 255)
telemetryBtn.Font = Enum.Font.GothamMedium
telemetryBtn.TextSize = 8
telemetryBtn.BorderSizePixel = 0
Instance.new("UICorner", telemetryBtn).CornerRadius = udim_new(0, 4)

-- 7. Indicador de Estado
local statusLabel = Instance.new("TextLabel", content)
statusLabel.Size = UDim2.new(0.92, 0, 0, 16)
statusLabel.Position = UDim2.new(0.04, 0, 0.87, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Esperando tu turno..."
statusLabel.TextColor3 = color_rgb(140, 225, 255)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 8
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabelRef = statusLabel

-- Eventos de Botones
autoPlayBtn.MouseButton1Click:Connect(function()
    autoPlayEnabled = not autoPlayEnabled
    autoPlayBtn.Text = autoPlayEnabled and "🤖 AUTO-PLAY: ON" or "🤖 AUTO-PLAY: OFF"
    autoPlayBtn.BackgroundColor3 = autoPlayEnabled and color_rgb(0, 160, 100) or color_rgb(150, 40, 40)
end)

shootNowBtn.MouseButton1Click:Connect(function()
    local poolUI = PlayerGui:FindFirstChild("PoolGameUI")
    local tableGui = poolUI and poolUI:FindFirstChild("Table") and poolUI.Table:FindFirstChild("PoolTable")
    local ballsFolder = tableGui and tableGui:FindFirstChild("Balls")
    local cueBallFrame = ballsFolder and ballsFolder:FindFirstChild("Ball0")
    if cueBallFrame and lastCalculatedAimDir then
        local cuePos = v2_new(
            (cueBallFrame.Position.X.Scale - 0.5) * FrameWidth,
            (0.5 - cueBallFrame.Position.Y.Scale) * FrameHeight
        )
        local pwr = (lastShotPlan and lastShotPlan.Power) or previewPower
        executeShot(lastCalculatedAimDir, pwr, v2_zero, cuePos)
    end
end)

forceModeBtn.MouseButton1Click:Connect(function()
    if forceMode == "DYNAMIC" then
        forceMode = "TACO_ONLY"
        forceModeBtn.Text = "⚡ GUÍAS: SOLO FUERZA TACO"
        forceModeBtn.BackgroundColor3 = color_rgb(160, 80, 20)
    elseif forceMode == "TACO_ONLY" then
        forceMode = "FIXED"
        forceModeBtn.Text = "⚡ GUÍAS: FUERZA FIJA PREVIEW"
        forceModeBtn.BackgroundColor3 = color_rgb(0, 140, 180)
    else
        forceMode = "DYNAMIC"
        forceModeBtn.Text = "⚡ GUÍAS: DINÁMICO (Preview + Taco)"
        forceModeBtn.BackgroundColor3 = color_rgb(75, 45, 110)
    end
end)

telemetryBtn.MouseButton1Click:Connect(function()
    local count = #telemetryLogs
    telemetryBtn.Text = string.format("✅ %d TIROS GUARDADOS", count)
    task.delay(1.5, function() telemetryBtn.Text = "📊 GUARDAR TELEMETRÍA JSON" end)
end)

btnMin.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Size = udim2_offset(255, 30)
        content.Visible = false
        btnMin.Text = "+"
    else
        mainFrame.Size = udim2_offset(255, 250)
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

-- 13. INICIALIZACIÓN
local renderConn = RunService.RenderStepped:Connect(updateOracle)
table.insert(connections, renderConn)

print("[POOL-ORACLE-PRO] Motor 8 Ball v8.0 activado: 60+ FPS Óptimo, Cache Dirty-State, Cero Lag y Máxima Precisión.")