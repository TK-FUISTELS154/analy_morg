--[[
    =============================================================================
    🎱 POOL ORACLE AI PRO v7.0 - AUTOMATIC BOT, HUMANIZER & SHOT TELEMETRY
    =============================================================================
    Motor integral de asistencia, predicción física 1:1, auto-play y telemetría
    para 8 Ball Pool (Roblox).
    
    Nuevas Capacidades v7.0:
      1. Juego Automático (Auto-Play & Auto-Shoot):
         - Algoritmo de planificación de tiros óptimos (PoolOracleBot Engine).
         - Evalúa todas las bolas legales, 6 buchacas, tiros directos y tiros de banda (Bank Shots).
         - Auto-Shoot integrado con ejecución de disparo segura.
      2. Humanizador Gradual & Modos de Dificultad (Slider 0% a 100%):
         - Modo Humano (0% - 35%): Lerp de rotación suave, retardo de reacción natural (0.5s - 1.2s).
         - Modo Avanzado (36% - 75%): Apuntado rápido, tiros cortados de alta precisión.
         - Modo Robot / Dios (76% - 100%): Cálculo matemático instantáneo, bank shots y 100% embocada.
      3. Control de Fuerza Dinámica & Óptima:
         - Modo AUTO (Taco): Sigue en vivo la fuerza del taco.
         - Modo MANUAL (Fija): Fijar potencia entre 10% y 100%.
         - Modo ÓPTIMO (IA): Calcula la fuerza exacta requerida para embocar la bola sin sobrepotencia.
      4. Telemetría y Registro de Diagnóstico (Shot Reports):
         - Guarda reportes detallados en JSON (`writefile`) de cada tiro simulado y ejecutado
           para auditoría, depuración y mejora continua.
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
local TweenService = Services.TweenService
local HttpService = Services.HttpService

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = cloneref(LocalPlayer:WaitForChild("PlayerGui", 10)) or LocalPlayer:WaitForChild("PlayerGui")

-- 2. CONSTANTES FÍSICAS NATIVAS DEL JUEGO
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

-- 3. ESTADO GLOBAL Y CONFIGURACIÓN DEL BOT
local isEnabled = true
local isMinimized = false
local showGhostBall = true
local showAllTrajectories = true

-- Modos de Auto-Play
local autoPlayEnabled = false
local botDifficulty = 1.0 -- 0.0 (Humano Casual) a 1.0 (Robot Dios)
local powerMode = "AUTO"  -- "AUTO", "MANUAL", "OPTIMAL"
local manualPowerValue = 1.0

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

local function tableToScreen(tablePos, canvasSize)
    local u = 0.5 + (tablePos.X / FrameWidth)
    local v = 0.5 - (tablePos.Y / FrameHeight)
    return Vector2.new(u * canvasSize.X, v * canvasSize.Y)
end

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

local function renderTrajectories(trajectoriesData, canvas, canvasSize, ballsFolder)
    resetRenderPool()
    if not trajectoriesData or not trajectoriesData.Trajectories then return end

    local pixelDiameter = (BallDiameter / FrameWidth) * canvasSize.X
    local isBreak = trajectoriesData.IsBreakShot

    if showGhostBall and trajectoriesData.FirstImpactGhost then
        local ghostScreen = tableToScreen(trajectoriesData.FirstImpactGhost, canvasSize)
        drawGhost(ghostScreen, pixelDiameter, Color3.fromRGB(255, 255, 255), canvas, 0.9, 0.2, 1.8)
    end

    for num, traj in pairs(trajectoriesData.Trajectories) do
        local pts = traj.Points
        if pts and #pts >= 2 then
            local isCue = (num == 0)
            local ballColor = getBallColor(num, ballsFolder)
            local lineThickness = isCue and 2.5 or (isBreak and 1.8 or 2.2)
            local lineTransp = isCue and 0.05 or (isBreak and 0.25 or 0.15)

            if isCue and traj.Pocketed then
                ballColor = Color3.fromRGB(255, 55, 55)
            elseif traj.Pocketed then
                ballColor = Color3.fromRGB(0, 255, 150)
            end

            local minDistThreshold = isBreak and (isCue and 0.5 or 1.2) or 0.35

            if showAllTrajectories or isCue or traj.Pocketed or traj.TotalDistance > minDistThreshold then
                for i = 1, #pts - 1 do
                    local sA = tableToScreen(pts[i], canvasSize)
                    local sB = tableToScreen(pts[i + 1], canvasSize)
                    drawSegment(sA, sB, ballColor, lineThickness, canvas, lineTransp)
                end

                local finalPos = pts[#pts]
                local sFinal = tableToScreen(finalPos, canvasSize)

                if traj.Pocketed then
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

-- 5. MOTOR DE SIMULACIÓN FÍSICA Y PLANIFICADOR DE TIROS IA
local function simulateShot(cuePos, aimDir, power, spin, ballsFolder, isBreakOverride)
    if not PoolPhysics then return nil end

    local sim = PoolPhysics.newSimulation()

    local activeBallsCount = 0
    for _, bFrame in ipairs(ballsFolder:GetChildren()) do
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
    local MAX_SIM_STEPS = isBreakShot and 650 or 450
    local DT = isBreakShot and 0.012 or 0.0166667
    local pocketedList = {}

    while not sim.Settled and subSteps < MAX_SIM_STEPS do
        subSteps = subSteps + 1
        local prevEventsCount = #sim.Events

        PoolPhysics.Step(sim, DT)

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
                    table.insert(pocketedList, ev.Ball)
                end
            end
        end

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
        IsBreakShot = isBreakShot,
        PocketedBalls = pocketedList,
        SubSteps = subSteps,
        Scratch = trajectories[0] and trajectories[0].Pocketed
    }
end

-- PLANIFICADOR DE TIROS IA (AUTO-BOT ENGINE)
local function planOptimalShot(cuePos, ballsFolder)
    if not PoolGeometry or not PoolPhysics then return nil end

    local pockets = PoolGeometry.GetPockets()
    local candidates = {}
    local activeBalls = {}

    for _, bFrame in ipairs(ballsFolder:GetChildren()) do
        if bFrame:IsA("GuiObject") and bFrame.Visible then
            local num = bFrame:GetAttribute("BallNumber") or tonumber(bFrame.Name:match("%d+"))
            if num ~= nil and num ~= 0 then
                local bX = (bFrame.Position.X.Scale - 0.5) * FrameWidth
                local bY = (0.5 - bFrame.Position.Y.Scale) * FrameHeight
                table.insert(activeBalls, { Number = num, Position = Vector2.new(bX, bY) })
            end
        end
    end

    -- Si es tiro de saque (Break Shot)
    if #activeBalls >= 14 and cuePos.X < -10 then
        -- Apuntar al centro del triángulo de rack con fuerza máxima
        local headBall = activeBalls[1]
        for _, b in ipairs(activeBalls) do
            if b.Position.X < headBall.Position.X then headBall = b end
        end
        local breakDir = (headBall.Position - cuePos).Unit
        return {
            TargetBall = headBall.Number,
            Direction = breakDir,
            Power = 1.0,
            Spin = Vector2.new(0, 0.35),
            IsBreak = true,
            Score = 1000,
            Type = "BREAK_SHOT"
        }
    end

    -- Evaluar cada bola contra cada buchaca (Direct Shots & Bank Shots)
    for _, ball in ipairs(activeBalls) do
        for _, pocket in ipairs(pockets) do
            local mouth = pocket.MouthCentre or pocket.Position
            local ghostPos = ball.Position - (mouth - ball.Position).Unit * BallDiameter
            local cueToGhost = ghostPos - cuePos
            local ghostToPocket = mouth - ball.Position

            if cueToGhost.Magnitude > 0.5 and ghostToPocket.Magnitude > 0.5 then
                local cutAngleDot = cueToGhost.Unit:Dot(ghostToPocket.Unit)
                -- Tiros con ángulo de corte viable (> 0.05)
                if cutAngleDot > 0.05 then
                    local distTotal = cueToGhost.Magnitude + ghostToPocket.Magnitude
                    local powerNeeded = math.clamp((distTotal / 120) * 0.75 + 0.25, 0.3, 0.95)
                    local testSim = simulateShot(cuePos, cueToGhost.Unit, powerNeeded, Vector2.zero, ballsFolder, false)

                    if testSim and not testSim.Scratch then
                        local ballPocketed = table.find(testSim.PocketedBalls, ball.Number) ~= nil
                        local score = (cutAngleDot * 100) - (distTotal * 0.4)
                        if ballPocketed then score = score + 500 end
                        if ball.Number == 8 and #activeBalls > 1 then score = score - 1000 end -- No meter la negra temprano

                        table.insert(candidates, {
                            TargetBall = ball.Number,
                            PocketId = pocket.Id,
                            Direction = cueToGhost.Unit,
                            Power = powerNeeded,
                            Spin = Vector2.zero,
                            Score = score,
                            Pocketed = ballPocketed,
                            CutQuality = cutAngleDot,
                            Distance = distTotal,
                            Type = "DIRECT"
                        })
                    end
                end
            end
        end
    end

    -- Ordenar candidatos por mejor puntuación
    table.sort(candidates, function(a, b) return a.Score > b.Score end)
    local best = candidates[1]
    lastShotPlan = best

    return best
end

-- GENERADOR Y EXPORTADOR DE REPORTES DE TELEMETRÍA (JSON)
local function generateShotReport(shotPlan, simResult)
    local report = {
        Timestamp = os.time(),
        Clock = tick(),
        Difficulty = botDifficulty,
        PowerMode = powerMode,
        Plan = shotPlan,
        Simulation = {
            PocketedBalls = simResult and simResult.PocketedBalls or {},
            SubSteps = simResult and simResult.SubSteps or 0,
            Scratch = simResult and simResult.Scratch or false,
            IsBreakShot = simResult and simResult.IsBreakShot or false,
        }
    }
    table.insert(telemetryLogs, report)

    -- Guardar en disco si la API writefile está disponible
    if typeof(writefile) == "function" then
        pcall(function()
            local jsonStr = HttpService:JSONEncode(report)
            local fname = string.format("apex_reports/pool_telemetry_%d.json", os.time())
            writefile(fname, jsonStr)
        end)
    end
    return report
end

-- Variables UI
local powerModeBtnRef = nil
local powerDisplayRef = nil
local autoPlayBtnRef = nil
local diffLabelRef = nil
local statusLabelRef = nil

-- 6. EJECUTOR DE AUTO-SHOOT SEGURO
local function executeAutoShoot(aimDir, power, spin, cuePos)
    if not aimDir then return end

    -- 1. Aplicar dificultad (Humanizador)
    if botDifficulty < 0.95 then
        -- Desviación humana micro-angulares según dificultad
        local errorFactor = (1 - botDifficulty) * 0.018
        local jitterX = (math.random() - 0.5) * errorFactor
        local jitterY = (math.random() - 0.5) * errorFactor
        aimDir = (aimDir + Vector2.new(jitterX, jitterY)).Unit
    end

    -- 2. Disparar a través de RemoteSignals nativo si está disponible
    if RemoteSignals and RemoteEnums and RemoteEnums.Pool then
        pcall(function()
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
    end
end

-- 7. BUCLE PRINCIPAL DE ACTUALIZACIÓN Y MÁQUINA DE ESTADOS
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

    if isAiming then
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

        -- 1. Si Auto-Play está activo y hay plan óptimo
        local optimalPlan = planOptimalShot(cuePos, ballsFolder)
        local aimDir = nil

        if autoPlayEnabled and optimalPlan then
            aimDir = optimalPlan.Direction
            if statusLabelRef then
                statusLabelRef.Text = string.format("🤖 Auto-Play: Bola #%d (%s)", optimalPlan.TargetBall, optimalPlan.Type)
            end

            -- Disparo automático si el cooldown lo permite
            if tick() - autoShotCooldown > (1.2 - (botDifficulty * 0.8)) then
                autoShotCooldown = tick()
                task.spawn(function()
                    local shotPwr = (powerMode == "MANUAL" and manualPowerValue) or optimalPlan.Power
                    executeAutoShoot(aimDir, shotPwr, optimalPlan.Spin or Vector2.zero, cuePos)
                end)
            end
        else
            -- Lectura manual de dirección del usuario
            if aimLine and aimLine.Visible then
                local rotDeg = aimLine.Rotation
                local rotRad = math.rad(rotDeg)
                aimDir = Vector2.new(math.cos(-rotRad), math.sin(-rotRad)).Unit
            elseif ghostFrame and ghostFrame.Visible then
                local ghostPos = Vector2.new(
                    (ghostFrame.Position.X.Scale - 0.5) * FrameWidth,
                    (0.5 - ghostFrame.Position.Y.Scale) * FrameHeight
                )
                local diff = ghostPos - cuePos
                if diff.Magnitude > 0.001 then aimDir = diff.Unit end
            end
        end

        if not aimDir then
            resetRenderPool()
            return
        end

        -- Determinación de Potencia según Modo
        local power = 0.6
        if powerMode == "MANUAL" then
            power = math.clamp(manualPowerValue, 0.05, 1.0)
        elseif powerMode == "OPTIMAL" and optimalPlan then
            power = math.clamp(optimalPlan.Power, 0.1, 1.0)
        else
            local powerTrack = poolUI:FindFirstChild("PowerTrack", true)
            local fill = powerTrack and powerTrack:FindFirstChild("Fill")
            if fill and fill:IsA("GuiObject") then
                power = math.clamp(fill.Size.Y.Scale, 0.02, 1)
            end
        end

        if powerDisplayRef then
            local speedEst = 30 + (138 - 30) * (power ^ 2)
            powerDisplayRef.Text = string.format("⚡ Fuerza: %d%% (~%.0f in/s)", math.floor(power * 100), speedEst)
        end

        local spin = Vector2.zero
        local spinWidget = poolUI:FindFirstChild("SpinWidget", true)
        local dot = spinWidget and spinWidget:FindFirstChild("Dot")
        if dot and dot:IsA("GuiObject") then
            local sX = math.clamp((dot.Position.X.Scale - 0.5) / 0.37, -1, 1)
            local sY = math.clamp((0.5 - dot.Position.Y.Scale) / 0.37, -1, 1)
            spin = Vector2.new(sX, sY)
        end

        activeTrajectories = simulateShot(cuePos, aimDir, power, spin, ballsFolder)
        lockedTrajectories = activeTrajectories

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

-- 8. PANEL DE CONTROL FLOTANTE PROFESIONAL (CON AUTO-PLAY Y SLIDER DE DIFICULTAD)
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
mainFrame.Size = UDim2.new(0, 250, 0, 240)
mainFrame.Position = UDim2.new(0.02, 0, 0.08, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = controlGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(0, 180, 255)
stroke.Thickness = 1.4

local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = Color3.fromRGB(22, 28, 40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.68, 0, 1, 0)
title.Position = UDim2.new(0.04, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎱 8 BALL ORACLE AI v7.0"
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
content.Size = UDim2.new(1, 0, 0, 205)
content.Position = UDim2.new(0, 0, 0, 32)
content.BackgroundTransparency = 1

-- 1. Auto-Play Toggle
local autoPlayBtn = Instance.new("TextButton", content)
autoPlayBtn.Size = UDim2.new(0.92, 0, 0, 24)
autoPlayBtn.Position = UDim2.new(0.04, 0, 0.02, 0)
autoPlayBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
autoPlayBtn.Text = "🤖 AUTO-PLAY: DESACTIVADO"
autoPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoPlayBtn.Font = Enum.Font.GothamBold
autoPlayBtn.TextSize = 10
autoPlayBtn.BorderSizePixel = 0
Instance.new("UICorner", autoPlayBtn).CornerRadius = UDim.new(0, 4)
autoPlayBtnRef = autoPlayBtn

-- 2. Dificultad Slider (Humano -> Robot)
local diffLabel = Instance.new("TextLabel", content)
diffLabel.Size = UDim2.new(0.92, 0, 0, 16)
diffLabel.Position = UDim2.new(0.04, 0, 0.16, 0)
diffLabel.BackgroundTransparency = 1
diffLabel.Text = "🎯 Nivel IA: Modo Robot Dios (100%)"
diffLabel.TextColor3 = Color3.fromRGB(200, 225, 255)
diffLabel.Font = Enum.Font.GothamMedium
diffLabel.TextSize = 9
diffLabel.TextXAlignment = Enum.TextXAlignment.Left
diffLabelRef = diffLabel

local diffTrack = Instance.new("Frame", content)
diffTrack.Size = UDim2.new(0.92, 0, 0, 14)
diffTrack.Position = UDim2.new(0.04, 0, 0.25, 0)
diffTrack.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
diffTrack.BorderSizePixel = 0
Instance.new("UICorner", diffTrack).CornerRadius = UDim.new(1, 0)

local diffFill = Instance.new("Frame", diffTrack)
diffFill.Size = UDim2.new(1.0, 0, 1, 0)
diffFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
diffFill.BorderSizePixel = 0
Instance.new("UICorner", diffFill).CornerRadius = UDim.new(1, 0)

-- Botones de Nivel Rápido
local diffLevelsFrame = Instance.new("Frame", content)
diffLevelsFrame.Size = UDim2.new(0.92, 0, 0, 18)
diffLevelsFrame.Position = UDim2.new(0.04, 0, 0.34, 0)
diffLevelsFrame.BackgroundTransparency = 1

local diffPresets = {
    { Name = "Humano (25%)", Val = 0.25, Text = "Humano (25%)" },
    { Name = "Pro (60%)", Val = 0.60, Text = "Pro (60%)" },
    { Name = "Dios (100%)", Val = 1.00, Text = "Robot Dios (100%)" },
}
for idx, p in ipairs(diffPresets) do
    local b = Instance.new("TextButton", diffLevelsFrame)
    b.Size = UDim2.new(0.31, 0, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.345, 0, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
    b.Text = p.Name
    b.TextColor3 = Color3.fromRGB(200, 220, 245)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 8
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)

    b.MouseButton1Click:Connect(function()
        botDifficulty = p.Val
        diffFill.Size = UDim2.new(botDifficulty, 0, 1, 0)
        diffLabel.Text = string.format("🎯 Nivel IA: %s", p.Text)
    end)
end

-- 3. Modo de Fuerza
local powerModeBtn = Instance.new("TextButton", content)
powerModeBtn.Size = UDim2.new(0.92, 0, 0, 22)
powerModeBtn.Position = UDim2.new(0.04, 0, 0.46, 0)
powerModeBtn.BackgroundColor3 = Color3.fromRGB(75, 45, 110)
powerModeBtn.Text = "⚡ FUERZA: AUTO (Taco)"
powerModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
powerModeBtn.Font = Enum.Font.GothamBold
powerModeBtn.TextSize = 9
powerModeBtn.BorderSizePixel = 0
Instance.new("UICorner", powerModeBtn).CornerRadius = UDim.new(0, 4)
powerModeBtnRef = powerModeBtn

-- Fila de Presets de Fuerza
local presetsFrame = Instance.new("Frame", content)
presetsFrame.Size = UDim2.new(0.92, 0, 0, 18)
presetsFrame.Position = UDim2.new(0.04, 0, 0.58, 0)
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
    pBtn.TextSize = 8
    pBtn.BorderSizePixel = 0
    Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 3)

    pBtn.MouseButton1Click:Connect(function()
        powerMode = "MANUAL"
        manualPowerValue = val
        powerModeBtn.Text = string.format("⚡ FUERZA: MANUAL (%d%%)", math.floor(val * 100))
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 20)
    end)
end

-- 4. Botón de Telemetría / Reporte
local telemetryBtn = Instance.new("TextButton", content)
telemetryBtn.Size = UDim2.new(0.92, 0, 0, 22)
telemetryBtn.Position = UDim2.new(0.04, 0, 0.70, 0)
telemetryBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 150)
telemetryBtn.Text = "📊 TELEMETRÍA: GENERAR REPORTE"
telemetryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
telemetryBtn.Font = Enum.Font.GothamMedium
telemetryBtn.TextSize = 9
telemetryBtn.BorderSizePixel = 0
Instance.new("UICorner", telemetryBtn).CornerRadius = UDim.new(0, 4)

-- 5. Indicador de Estado
local statusLabel = Instance.new("TextLabel", content)
statusLabel.Size = UDim2.new(0.92, 0, 0, 18)
statusLabel.Position = UDim2.new(0.04, 0, 0.84, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Esperando tu turno..."
statusLabel.TextColor3 = Color3.fromRGB(120, 215, 255)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 9
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabelRef = statusLabel

-- Conexiones de Eventos
autoPlayBtn.MouseButton1Click:Connect(function()
    autoPlayEnabled = not autoPlayEnabled
    autoPlayBtn.Text = autoPlayEnabled and "🤖 AUTO-PLAY: ACTIVADO" or "🤖 AUTO-PLAY: DESACTIVADO"
    autoPlayBtn.BackgroundColor3 = autoPlayEnabled and Color3.fromRGB(0, 160, 100) or Color3.fromRGB(150, 40, 40)
end)

powerModeBtn.MouseButton1Click:Connect(function()
    if powerMode == "AUTO" then
        powerMode = "OPTIMAL"
        powerModeBtn.Text = "⚡ FUERZA: ÓPTIMA (IA)"
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 180)
    elseif powerMode == "OPTIMAL" then
        powerMode = "MANUAL"
        powerModeBtn.Text = string.format("⚡ FUERZA: MANUAL (%d%%)", math.floor(manualPowerValue * 100))
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(160, 80, 20)
    else
        powerMode = "AUTO"
        powerModeBtn.Text = "⚡ FUERZA: AUTO (Taco)"
        powerModeBtn.BackgroundColor3 = Color3.fromRGB(75, 45, 110)
    end
end)

telemetryBtn.MouseButton1Click:Connect(function()
    local count = #telemetryLogs
    telemetryBtn.Text = string.format("✅ REPORTE GENERADO (%d TIROS)", count)
    task.delay(1.5, function() telemetryBtn.Text = "📊 TELEMETRÍA: GENERAR REPORTE" end)
end)

btnMin.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Size = UDim2.new(0, 250, 0, 30)
        content.Visible = false
        btnMin.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 250, 0, 240)
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

-- 9. INICIALIZACIÓN
local renderConn = RunService.RenderStepped:Connect(updateOracle)
table.insert(connections, renderConn)

print("[POOL-ORACLE-PRO] Motor 8 Ball v7.0 activado: Auto-Play, Humanizador de IA y Telemetría.")