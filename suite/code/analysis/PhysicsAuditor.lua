--[[
    =============================================================================
    APEX SUITE - ADVANCED PHYSICS & MOVEMENT SECURITY AUDITOR
    =============================================================================
    Módulo especializado en análisis profundo de físicas de Roblox:
      1. Telemetría en Vivo de Físicas del Jugador (Velocidad, Fuerzas, Network Ownership, Estados)
      2. Auditoría Estática de Watchdogs y Anti-Cheats de Física (Speed, Fly, Noclip, Teleport)
      3. Detección de Controladores de Movimiento Personalizados (Dash, Vuelo, Vehículos, Constraints)
      4. Análisis de Vulnerabilidades de Red de Física (Remotes con CFrame/Position autoritativa del cliente)
      5. Generador de Scripts de Prueba de Físicas y Replicación
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local PhysicsAuditor = {}
PhysicsAuditor.__index = PhysicsAuditor
PhysicsAuditor.ClassName = "PhysicsAuditor"

PhysicsAuditor.RiskLevel = {
    CRITICAL = "CRITICAL", -- Remotes de posición autoritativos del cliente sin validación
    HIGH     = "HIGH",     -- Modificación de velocidad/fuerzas sin verificación
    MEDIUM   = "MEDIUM",   -- Watchdogs de cliente fácilmente eludibles
    LOW      = "LOW",      -- Físicas cosméticas / Ragdolls
}

function PhysicsAuditor.new(heuristicEngine, logger, capabilityManager, remoteAnalyzer)
    local self = setmetatable({}, PhysicsAuditor)
    self.Heuristic = heuristicEngine
    self.Logger = logger
    self.Caps = capabilityManager
    self.RemoteAnalyzer = remoteAnalyzer
    self.LocalPlayer = Players.LocalPlayer
    return self
end

function PhysicsAuditor:IsIgnoredCoreInstance(instance)
    local fullName = instance:GetFullName()
    if fullName:find("StarterPlayer%.StarterPlayerScripts%.PlayerModule")
       or fullName:find("StarterPlayer%.StarterPlayerScripts%.RbxCharacterSounds")
       or fullName:find("PlayerScriptsLoader")
       or fullName:find("ChatScript")
       or fullName:find("BubbleChat")
       or fullName:find("RobloxGui")
       or fullName:find("%.spec")
       or fullName:find("%.test")
       or fullName:find("Packages")
       or fullName:find("_Index")
       or fullName:find("Janitor")
       or fullName:find("Promise")
       or fullName:find("Vendor")
       or fullName:find("pkg") then
        return true
    end
    return false
end

-- =============================================================================
-- 1. TELEMETRÍA EN VIVO DE FÍSICAS DEL PERSONAJE
-- =============================================================================

function PhysicsAuditor:CapturePlayerPhysicsSnapshot()
    local snap = {
        Timestamp = tick(),
        IsAlive = false,
        Gravity = Workspace.Gravity,
        FallenPartsDestroyHeight = Workspace.FallenPartsDestroyHeight,
        WalkSpeed = 16,
        JumpPower = 50,
        JumpHeight = 7.2,
        MaxSlopeAngle = 89,
        AutoRotate = true,
        PlatformStand = false,
        Sit = false,
        HumanoidState = "None",
        Position = Vector3.zero,
        CFrame = CFrame.new(),
        LinearVelocity = Vector3.zero,
        AngularVelocity = Vector3.zero,
        SpeedMagnitude = 0,
        CanCollide = true,
        FloorMaterial = "None",
        ForcesDetected = {},
        NetworkOwnership = "Client",
    }

    pcall(function()
        local char = self.LocalPlayer.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")

        if hum then
            snap.IsAlive = (hum.Health > 0)
            snap.WalkSpeed = hum.WalkSpeed
            snap.JumpPower = hum.JumpPower
            snap.JumpHeight = hum.JumpHeight
            snap.MaxSlopeAngle = hum.MaxSlopeAngle
            snap.AutoRotate = hum.AutoRotate
            snap.PlatformStand = hum.PlatformStand
            snap.Sit = hum.Sit
            snap.FloorMaterial = hum.FloorMaterial.Name
            snap.HumanoidState = hum:GetState().Name
        end

        if hrp then
            snap.Position = hrp.Position
            snap.CFrame = hrp.CFrame
            snap.LinearVelocity = hrp.AssemblyLinearVelocity
            snap.AngularVelocity = hrp.AssemblyAngularVelocity
            snap.SpeedMagnitude = Vector2.new(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z).Magnitude
            snap.CanCollide = hrp.CanCollide

            -- Buscar fuerzas y constraints acoplados al HumanoidRootPart
            for _, child in ipairs(hrp:GetChildren()) do
                if child:IsA("BodyVelocity") or child:IsA("LinearVelocity") or child:IsA("VectorForce")
                   or child:IsA("BodyPosition") or child:IsA("AlignPosition") or child:IsA("BodyGyro")
                   or child:IsA("AlignOrientation") or child:IsA("BodyThrust") or child:IsA("Torque") then
                    table.insert(snap.ForcesDetected, {
                        Name = child.Name,
                        ClassName = child.ClassName,
                    })
                end
            end
        end
    end)

    return snap
end

-- =============================================================================
-- 2. AUDITORÍA ESTÁTICA DE WATCHDOGS Y ANTI-CHEATS DE FÍSICA EN SCRIPTS
-- =============================================================================

function PhysicsAuditor:AnalyzeScriptPhysicsRules(code, scriptPath)
    local findings = {}
    local summary = {
        HasSpeedWatchdog = false,
        HasFlyWatchdog = false,
        HasNoclipWatchdog = false,
        HasTeleportDetector = false,
        HasCustomMovement = false,
        HasPhysicsHook = false,
        PhysicsScore = 0,
    }

    if not code or #code == 0 then return summary, findings end

    local lineNum = 1
    for line in code:gmatch("[^\r\n]+") do
        if #line > 300 then line = line:sub(1, 300) end
        local lLower = line:lower()

        -- 1. Anti-Cheat de Velocidad (Speed Watchdog)
        if (lLower:find("magnitude") or lLower:find("distance")) and (lLower:find("walkspeed") or lLower:find("maxspeed") or lLower:find("speedlimit")) and (lLower:find("kick") or lLower:find("teleport") or lLower:find("rollback") or lLower:find("flag")) then
            summary.HasSpeedWatchdog = true
            summary.PhysicsScore = summary.PhysicsScore + 35
            table.insert(findings, {
                Type = "SPEED_WATCHDOG",
                Severity = "CRITICAL",
                Line = lineNum,
                Snippet = line:match("^%s*(.-)%s*$") or line,
                Description = "Watchdog de Velocidad: Compara desplazamiento delta con límite de WalkSpeed y aplica sanción/kick",
            })
        elseif (line:find("GetPropertyChangedSignal%s*%(%s*[\"']WalkSpeed[\"']%)") or line:find("GetPropertyChangedSignal%s*%(%s*[\"']JumpPower[\"']%)")) then
            summary.HasSpeedWatchdog = true
            summary.PhysicsScore = summary.PhysicsScore + 25
            table.insert(findings, {
                Type = "PROPERTY_LOCK",
                Severity = "HIGH",
                Line = lineNum,
                Snippet = line:match("^%s*(.-)%s*$") or line,
                Description = "Bloqueo de Propiedad: Escucha cambios en WalkSpeed/JumpPower para revertirlos o detectar spoofing",
            })
        end

        -- 2. Anti-Cheat de Vuelo / Gravedad (Fly / Void Watchdog)
        if (lLower:find("raycast") or lLower:find("findpartonray")) and (lLower:find("floormaterial") or lLower:find("ground") or lLower:find("freefall")) and (lLower:find("airtime") or lLower:find("flytime") or lLower:find("falltime")) then
            summary.HasFlyWatchdog = true
            summary.PhysicsScore = summary.PhysicsScore + 30
            table.insert(findings, {
                Type = "FLY_WATCHDOG",
                Severity = "HIGH",
                Line = lineNum,
                Snippet = line:match("^%s*(.-)%s*$") or line,
                Description = "Watchdog de Vuelo: Raycasting continuo hacia el suelo con acumulador de tiempo en el aire",
            })
        end

        -- 3. Anti-Cheat de Noclip / Colisión (Noclip Watchdog)
        if (lLower:find("raycast") or lLower:find("getpartsinpart")) and (lLower:find("cancollide") or lLower:find("lastpos") or lLower:find("oldpos")) and (lLower:find("wall") or lLower:find("hit") or lLower:find("solid")) then
            summary.HasNoclipWatchdog = true
            summary.PhysicsScore = summary.PhysicsScore + 35
            table.insert(findings, {
                Type = "NOCLIP_WATCHDOG",
                Severity = "CRITICAL",
                Line = lineNum,
                Snippet = line:match("^%s*(.-)%s*$") or line,
                Description = "Watchdog de Noclip: Raycasting proyectado entre la posición previa y actual para detectar traspaso de muros",
            })
        end

        -- 4. Detector de Teletransporte / Desplazamiento Anormal
        if (lLower:find("lastcframe") or lLower:find("prevpos") or lLower:find("lastpos")) and lLower:find("magnitude") and (lLower:find(">") or lLower:find(">=")) and (lLower:find("kick") or lLower:find("ban") or lLower:find("respawn")) then
            summary.HasTeleportDetector = true
            summary.PhysicsScore = summary.PhysicsScore + 40
            table.insert(findings, {
                Type = "TELEPORT_DETECTOR",
                Severity = "CRITICAL",
                Line = lineNum,
                Snippet = line:match("^%s*(.-)%s*$") or line,
                Description = "Detector de Teletransporte: Sanciona saltos de coordenadas que superen el umbral máximo de desplazamiento instantáneo",
            })
        end

        -- 5. Controladores de Movimiento Personalizados (Custom Movement / Dash / Physics)
        if line:find("LinearVelocity") or line:find("BodyVelocity") or line:find("VectorForce") or line:find("AlignPosition") or line:find("AssemblyLinearVelocity") then
            if lLower:find("dash") or lLower:find("dodge") or lLower:find("slide") or lLower:find("jump") or lLower:find("climb") or lLower:find("glide") or lLower:find("swim") or lLower:find("hook") then
                summary.HasCustomMovement = true
                table.insert(findings, {
                    Type = "CUSTOM_MOVEMENT",
                    Severity = "LOW",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Mecánica de Movimiento Personalizada (Dash / Slide / Glide / Impulso de Física)",
                })
            end
        end

        -- 6. Manipulación de Estados del Humanoid
        if line:find("ChangeState") or line:find("SetStateEnabled") then
            if lLower:find("physics") or lLower:find("ragdoll") or lLower:find("platformstanding") or lLower:find("freefall") then
                table.insert(findings, {
                    Type = "STATE_MANIPULATION",
                    Severity = "MEDIUM",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Control de Estados de Humanoid (ChangeState / SetStateEnabled)",
                })
            end
        end

        lineNum = lineNum + 1
    end

    if summary.PhysicsScore > 100 then summary.PhysicsScore = 100 end
    return summary, findings
end

-- =============================================================================
-- 3. AUDITORÍA DE RED DE FÍSICA (REMOTES DE POSICIÓN / MOVIMIENTO)
-- =============================================================================

function PhysicsAuditor:AuditPhysicsRemotes()
    local physicsRemotes = {}
    local keywords = { "move", "pos", "position", "cframe", "teleport", "dash", "velocity", "hitpos", "targetpos", "lookvector", "flight", "fly", "speed" }

    local s, allInstances = pcall(function() return game:GetDescendants() end)
    if not (s and allInstances) then return physicsRemotes end

    for _, inst in ipairs(allInstances) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
            local lowerName = inst.Name:lower()
            local isPhysicsRemote = false
            for _, kw in ipairs(keywords) do
                if lowerName:find(kw) then
                    isPhysicsRemote = true
                    break
                end
            end

            if isPhysicsRemote then
                local risk = PhysicsAuditor.RiskLevel.MEDIUM
                if lowerName:find("teleport") or lowerName:find("setcframe") or lowerName:find("setpos") or lowerName:find("setpos") then
                    risk = PhysicsAuditor.RiskLevel.CRITICAL
                elseif lowerName:find("dash") or lowerName:find("velocity") or lowerName:find("impulse") then
                    risk = PhysicsAuditor.RiskLevel.HIGH
                end

                table.insert(physicsRemotes, {
                    Remote = inst,
                    Name = inst.Name,
                    ClassName = inst.ClassName,
                    Path = inst:GetFullName(),
                    Risk = risk,
                    Recommendation = (risk == PhysicsAuditor.RiskLevel.CRITICAL)
                        and "Vulnerabilidad: El cliente puede enviar coordenadas directas. Probar teletransporte y desincronización de posición."
                        or "Revisar validación de velocidad y cooldowns en el servidor.",
                })
            end
        end
    end

    return physicsRemotes
end

-- =============================================================================
-- 4. AUDITORÍA GENERAL DE FÍSICAS DEL JUEGO
-- =============================================================================

function PhysicsAuditor:RunFullPhysicsAudit(onProgress)
    local report = {
        Timestamp = tick(),
        PlayerSnapshot = self:CapturePlayerPhysicsSnapshot(),
        PhysicsRemotes = self:AuditPhysicsRemotes(),
        PhysicsScripts = {},
        WatchdogsDetected = {},
        TotalScriptsScanned = 0,
        CriticalVulnerabilities = 0,
    }

    local targetContainers = {
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterPlayer"),
        game:GetService("ReplicatedStorage"),
        self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerGui"),
    }

    local queue = {}
    local function collect(parent)
        local s, d = pcall(function() return parent:GetDescendants() end)
        if s and d then
            for _, item in ipairs(d) do
                if item:IsA("LuaSourceContainer") and not self:IsIgnoredCoreInstance(item) then
                    table.insert(queue, item)
                end
            end
        end
    end

    for _, cont in ipairs(targetContainers) do
        if cont then collect(cont) end
    end

    report.TotalScriptsScanned = #queue
    local total = #queue
    local lastYield = tick()

    for idx, scriptInst in ipairs(queue) do
        if onProgress then
            pcall(onProgress, idx, total, "Auditando físicas en " .. scriptInst.Name)
        end

        local code = nil
        if self.Caps then
            code = self.Caps:SafeDecompile(scriptInst)
        else
            pcall(function() code = scriptInst.Source end)
        end

        if code and #code > 0 then
            local summary, findings = self:AnalyzeScriptPhysicsRules(code, scriptInst:GetFullName())
            if #findings > 0 or summary.PhysicsScore > 0 then
                local scriptEntry = {
                    Instance = scriptInst,
                    Name = scriptInst.Name,
                    ClassName = scriptInst.ClassName,
                    Path = scriptInst:GetFullName(),
                    Summary = summary,
                    Findings = findings,
                }
                table.insert(report.PhysicsScripts, scriptEntry)

                for _, f in ipairs(findings) do
                    if f.Severity == "CRITICAL" then
                        report.CriticalVulnerabilities = report.CriticalVulnerabilities + 1
                    end
                    if f.Type:find("WATCHDOG") or f.Type:find("DETECTOR") or f.Type:find("LOCK") then
                        table.insert(report.WatchdogsDetected, {
                            Script = scriptInst:GetFullName(),
                            Finding = f,
                        })
                    end
                end
            end
        end

        if tick() - lastYield > 0.010 then
            task.wait()
            lastYield = tick()
        end
    end

    return report
end

-- =============================================================================
-- 5. FORMATEADOR DE REPORTE Y GENERADOR DE STANDALONE TEST SCRIPT
-- =============================================================================

function PhysicsAuditor:FormatTextReport(auditReport)
    local lines = {}
    table.insert(lines, "=============================================================================")
    table.insert(lines, "🏃 APEX SUITE - REPORTE DE AUDITORÍA DE FÍSICAS & MOVIMIENTO")
    table.insert(lines, "=============================================================================")

    local snap = auditReport.PlayerSnapshot or {}
    table.insert(lines, "\n[1. ESTADO FÍSICO DEL JUGADOR EN VIVO]:")
    table.insert(lines, string.format("   • Gravedad del Workspace: %.1f | Caída Límite: %.1f", snap.Gravity or 196.2, snap.FallenPartsDestroyHeight or -500))
    table.insert(lines, string.format("   • WalkSpeed: %.1f | JumpPower: %.1f | JumpHeight: %.1f", snap.WalkSpeed or 16, snap.JumpPower or 50, snap.JumpHeight or 7.2))
    table.insert(lines, string.format("   • Velocidad Lineal: %s (Magnitud Horizontal: %.2f)", tostring(snap.LinearVelocity or Vector3.zero), snap.SpeedMagnitude or 0))
    table.insert(lines, string.format("   • Estado Humanoid: %s | Material Suelo: %s | Sentado: %s", snap.HumanoidState or "None", snap.FloorMaterial or "None", tostring(snap.Sit or false)))
    if snap.ForcesDetected and #snap.ForcesDetected > 0 then
        table.insert(lines, "   • Fuerzas/Constraints Activas en HRP:")
        for _, force in ipairs(snap.ForcesDetected) do
            table.insert(lines, string.format("      - [%s] %s", force.ClassName, force.Name))
        end
    end

    table.insert(lines, "\n[2. WATCHDOGS Y ANTI-CHEATS DE FÍSICA DETECTADOS]: " .. tostring(#auditReport.WatchdogsDetected))
    if #auditReport.WatchdogsDetected == 0 then
        table.insert(lines, "   ✅ No se detectaron watchdogs de física en el cliente.")
    else
        for idx, item in ipairs(auditReport.WatchdogsDetected) do
            table.insert(lines, string.format("   [%d] %s en '%s'", idx, item.Finding.Type, item.Script))
            table.insert(lines, string.format("       Línea %d: %s", item.Finding.Line, item.Finding.Description))
            table.insert(lines, string.format("       Código: %s", item.Finding.Snippet))
        end
    end

    table.insert(lines, "\n[3. REMOTES DE FÍSICA / MOVIMIENTO IDENTIFICADOS]: " .. tostring(#auditReport.PhysicsRemotes))
    for idx, rem in ipairs(auditReport.PhysicsRemotes) do
        local emoji = (rem.Risk == "CRITICAL" and "🚨") or (rem.Risk == "HIGH" and "⚔️") or "📡"
        table.insert(lines, string.format("   %s [%d] %s (%s)", emoji, idx, rem.Name, rem.Risk))
        table.insert(lines, string.format("       Ruta: %s", rem.Path))
        table.insert(lines, string.format("       Nota: %s", rem.Recommendation))
    end

    table.insert(lines, "\n[4. SCRIPTS CON CONTROLADORES O MECÁNICAS DE FÍSICA]: " .. tostring(#auditReport.PhysicsScripts))
    for idx, sEntry in ipairs(auditReport.PhysicsScripts) do
        table.insert(lines, string.format("   • [%d] %s (%s) | Score: %d | Hallazgos: %d",
            idx, sEntry.Name, sEntry.ClassName, sEntry.Summary.PhysicsScore, #sEntry.Findings))
    end

    table.insert(lines, "\n=============================================================================")
    return table.concat(lines, "\n")
end

function PhysicsAuditor:GenerateMovementTestScript()
    return [=[--[[
    =============================================================================
    APEX SUITE - STANDALONE PHYSICS & MOVEMENT TESTER
    =============================================================================
    Script parametrizado para evaluar el comportamiento de la física del juego
    y verificar la presencia de rollbacks o watchdogs en el servidor.
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Config = {
    TestWalkSpeed = 45,
    TestJumpPower = 90,
    FlightSpeed   = 50,
    NoclipActive  = false,
    FlyActive     = false,
}

-- 1. Prueba de WalkSpeed
local function applySpeed(speed)
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").WalkSpeed = speed
        print("[APEX PHYSICS] WalkSpeed establecido en: " .. tostring(speed))
    end
end

-- 2. Toggle Noclip Seguro
local noclipConn = nil
local function toggleNoclip(enable)
    Config.NoclipActive = enable
    if enable then
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
        print("[APEX PHYSICS] Noclip activado.")
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        print("[APEX PHYSICS] Noclip desactivado.")
    end
end

-- 3. Toggle Vuelo con LinearVelocity / BodyVelocity
local flyAttachment = nil
local flyVelocity = nil

local function toggleFly(enable)
    Config.FlyActive = enable
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if enable then
        flyAttachment = Instance.new("Attachment", hrp)
        flyVelocity = Instance.new("LinearVelocity")
        flyVelocity.MaxForce = math.huge
        flyVelocity.VectorVelocity = Vector3.zero
        flyVelocity.Attachment0 = flyAttachment
        flyVelocity.Parent = hrp
        print("[APEX PHYSICS] Vuelo activado.")
    else
        if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
        if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end
        print("[APEX PHYSICS] Vuelo desactivado.")
    end
end

print("[APEX PHYSICS] Standalone Movement Tester listo.")
]=]
end

return PhysicsAuditor
