--[[
    =============================================================================
    APEX SUITE - ADVANCED PLAYER PHYSICS & ANTI-CHEAT AUDITOR v4.5
    (EXCLUSIVE LOCALPLAYER & CHARACTER PHYSICS WATCHDOG ENGINE)
    =============================================================================
    Módulo ultra-optimizado y enfocado EXCLUSIVAMENTE en las físicas del jugador:
      1. Telemetría en Vivo de Físicas del LocalPlayer (HRP, Humanoid, Velocidades, Fuerzas, Raycast de Suelo)
      2. Auditoría Estricta de Anti-Cheats / Watchdogs de Física del Jugador (Speed, Fly, Noclip, Teleport, Property Locks)
      3. Detección de Remotes de Red Vinculados a Movimiento / Posición del Personaje
      4. Escaneo Quirúrgico: Solo analiza scripts del jugador (StarterPlayerScripts, Character, PlayerScripts, PlayerGui y Módulos de Movimiento)
      5. Generador de Scripts Standalone de Prueba de Físicas
--]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsAuditor = {}
PhysicsAuditor.__index = PhysicsAuditor
PhysicsAuditor.ClassName = "PhysicsAuditor"

PhysicsAuditor.RiskLevel = {
    CRITICAL = "CRITICAL", -- Remotes de teletransporte/posición autoritativa sin validación en servidor
    HIGH     = "HIGH",     -- Watchdogs de velocidad/vuelo/noclip en cliente que pueden causar kick/rollback
    MEDIUM   = "MEDIUM",   -- Bloqueos de propiedades de Humanoid o sincronización de estados
    LOW      = "LOW",      -- Mecánicas de movimiento personalizadas del jugador (Dash, Slide)
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
-- 1. TELEMETRÍA EN VIVO DE FÍSICAS DEL LOCALPLAYER
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
        HipHeight = 0,
        MaxSlopeAngle = 89,
        AutoRotate = true,
        PlatformStand = false,
        Sit = false,
        HumanoidState = "None",
        Position = Vector3.zero,
        CFrame = CFrame.new(),
        LinearVelocity = Vector3.zero,
        AngularVelocity = Vector3.zero,
        HorizontalSpeed = 0,
        VerticalSpeed = 0,
        CanCollide = true,
        FloorMaterial = "None",
        FloorDistance = nil,
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
            snap.HipHeight = hum.HipHeight
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
            snap.HorizontalSpeed = Vector2.new(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z).Magnitude
            snap.VerticalSpeed = hrp.AssemblyLinearVelocity.Y
            snap.CanCollide = hrp.CanCollide

            -- Probar raycast hacia el suelo desde el HRP
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { char }
            local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0), rayParams)
            if hit then
                snap.FloorDistance = (hrp.Position - hit.Position).Magnitude
            end

            -- Buscar fuerzas y constraints acoplados directamente al personaje
            for _, inst in ipairs(char:GetDescendants()) do
                if inst:IsA("BodyVelocity") or inst:IsA("LinearVelocity") or inst:IsA("VectorForce")
                   or inst:IsA("BodyPosition") or inst:IsA("AlignPosition") or inst:IsA("BodyGyro")
                   or inst:IsA("AlignOrientation") or inst:IsA("BodyThrust") or inst:IsA("Torque") then
                    table.insert(snap.ForcesDetected, {
                        Name = inst.Name,
                        ClassName = inst.ClassName,
                        ParentPart = inst.Parent and inst.Parent.Name or "Unknown",
                    })
                end
            end
        end
    end)

    return snap
end

-- =============================================================================
-- 2. AUDITORÍA ESTÁTICA EXCLUSIVA DE ANTI-CHEATS Y FÍSICAS DEL JUGADOR
-- =============================================================================

function PhysicsAuditor:AnalyzeScriptPhysicsRules(code, scriptPath)
    local findings = {}
    local summary = {
        HasSpeedWatchdog = false,
        HasFlyWatchdog = false,
        HasNoclipWatchdog = false,
        HasTeleportDetector = false,
        HasPropertyLock = false,
        HasCustomMovement = false,
        PhysicsScore = 0,
    }

    if not code or #code == 0 then return summary, findings end

    local lineNum = 1
    for line in code:gmatch("[^\r\n]+") do
        if #line > 300 then line = line:sub(1, 300) end
        local lLower = line:lower()

        -- Condición básica: la línea o contexto debe vincularse a movimiento / personaje
        local isPlayerContext = lLower:find("humanoid") or lLower:find("character") or lLower:find("rootpart")
            or lLower:find("hrp") or lLower:find("localplayer") or lLower:find("player")
            or lLower:find("walkspeed") or lLower:find("jumppower") or lLower:find("hipheight")
            or lLower:find("cframe") or lLower:find("position") or lLower:find("velocity")

        if isPlayerContext then
            -- 1. Anti-Cheat de Velocidad del Jugador (Speed Watchdog / Delta Magnitude)
            if (lLower:find("magnitude") or lLower:find("distance")) and (lLower:find("walkspeed") or lLower:find("maxspeed") or lLower:find("speedlimit") or lLower:find("maxdist") or lLower:find("delta")) and (lLower:find("kick") or lLower:find("teleport") or lLower:find("rollback") or lLower:find("flag") or lLower:find("ban") or lLower:find("punish")) then
                summary.HasSpeedWatchdog = true
                summary.PhysicsScore = summary.PhysicsScore + 40
                table.insert(findings, {
                    Type = "PLAYER_SPEED_WATCHDOG",
                    Severity = "CRITICAL",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Anti-Cheat de Velocidad: Verifica desplazamiento por frame del jugador y ejecuta kick/rollback si excede el límite",
                })
            -- Bloqueo de propiedades de Humanoid (WalkSpeed, JumpPower, HipHeight)
            elseif line:find("GetPropertyChangedSignal%s*%(%s*[\"']WalkSpeed[\"']%)") or line:find("GetPropertyChangedSignal%s*%(%s*[\"']JumpPower[\"']%)") or line:find("GetPropertyChangedSignal%s*%(%s*[\"']HipHeight[\"']%)") then
                summary.HasPropertyLock = true
                summary.PhysicsScore = summary.PhysicsScore + 30
                table.insert(findings, {
                    Type = "PLAYER_PROPERTY_LOCK",
                    Severity = "HIGH",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Bloqueo de Propiedades: Monitorea cambios en WalkSpeed/JumpPower/HipHeight del Humanoid para revertir o detectar spoofing",
                })
            end

            -- 2. Anti-Cheat de Vuelo / Gravedad del Jugador (Fly / Airtime Watchdog)
            if (lLower:find("raycast") or lLower:find("findpartonray") or lLower:find("floormaterial")) and (lLower:find("freefall") or lLower:find("air") or lLower:find("flying") or lLower:find("ground")) and (lLower:find("airtime") or lLower:find("flytime") or lLower:find("falltime") or lLower:find("tick") or lLower:find("time")) and (lLower:find("kick") or lLower:find("teleport") or lLower:find("kill") or lLower:find("damage") or lLower:find("flag")) then
                summary.HasFlyWatchdog = true
                summary.PhysicsScore = summary.PhysicsScore + 35
                table.insert(findings, {
                    Type = "PLAYER_FLY_WATCHDOG",
                    Severity = "HIGH",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Anti-Cheat de Vuelo: Raycasting constante hacia el suelo para calcular tiempo en el aire y detectar vuelo",
                })
            end

            -- 3. Anti-Cheat de Noclip / Colisión del Personaje (Noclip Watchdog)
            if (lLower:find("cancollide") or lLower:find("lastpos") or lLower:find("oldpos") or lLower:find("prevpos")) and (lLower:find("raycast") or lLower:find("getpartsinpart")) and (lLower:find("wall") or lLower:find("hit") or lLower:find("solid") or lLower:find("barrier")) and (lLower:find("kick") or lLower:find("rollback") or lLower:find("teleport") or lLower:find("respawn")) then
                summary.HasNoclipWatchdog = true
                summary.PhysicsScore = summary.PhysicsScore + 40
                table.insert(findings, {
                    Type = "PLAYER_NOCLIP_WATCHDOG",
                    Severity = "CRITICAL",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Anti-Cheat de Noclip: Compara trayectoria del personaje entre frames mediante raycast para sancionar traspaso de paredes",
                })
            end

            -- 4. Detector de Teletransporte / Salto de Coordenadas del Jugador
            if (lLower:find("lastcframe") or lLower:find("prevpos") or lLower:find("lastpos") or lLower:find("oldcframe")) and lLower:find("magnitude") and (lLower:find(">") or lLower:find(">=")) and (lLower:find("kick") or lLower:find("ban") or lLower:find("respawn") or lLower:find("rollback") or lLower:find("report")) then
                summary.HasTeleportDetector = true
                summary.PhysicsScore = summary.PhysicsScore + 45
                table.insert(findings, {
                    Type = "PLAYER_TELEPORT_DETECTOR",
                    Severity = "CRITICAL",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Detector de Teletransporte: Sanciona cambios instantáneos de posición que superen el desplazamiento físico posible",
                })
            end

            -- 5. Mecánicas de Movimiento Personalizadas del Jugador (Dash / Vuelo / Slide)
            if (line:find("LinearVelocity") or line:find("BodyVelocity") or line:find("VectorForce") or line:find("AssemblyLinearVelocity")) and (lLower:find("dash") or lLower:find("dodge") or lLower:find("slide") or lLower:find("glide") or lLower:find("doublejump") or lLower:find("sprint")) then
                summary.HasCustomMovement = true
                table.insert(findings, {
                    Type = "PLAYER_CUSTOM_MOVEMENT",
                    Severity = "LOW",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Mecánica de Movimiento del Jugador: Impulso de física o dash controlado por cliente",
                })
            end
        end

        lineNum = lineNum + 1
    end

    if summary.PhysicsScore > 100 then summary.PhysicsScore = 100 end
    return summary, findings
end

-- =============================================================================
-- 3. AUDITORÍA DE RED: REMOTES DE MOVIMIENTO / POSICIÓN DEL JUGADOR
-- =============================================================================

function PhysicsAuditor:AuditPhysicsRemotes()
    local physicsRemotes = {}
    local keywords = { "teleport", "setcframe", "setpos", "move", "dash", "sprint", "velocity", "flight", "fly", "jump", "slide", "roll", "position" }

    -- Escanear únicamente contenedores estándar de comunicación de red
    local searchContainers = {
        ReplicatedStorage,
        self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerScripts"),
        self.LocalPlayer and self.LocalPlayer.Character,
    }

    local visited = {}

    for _, container in ipairs(searchContainers) do
        if container then
            local s, items = pcall(function() return container:GetDescendants() end)
            if s and items then
                for _, inst in ipairs(items) do
                    if (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")) and not visited[inst] then
                        visited[inst] = true
                        local lowerName = inst.Name:lower()
                        local isMatch = false
                        for _, kw in ipairs(keywords) do
                            if lowerName:find(kw) then
                                isMatch = true
                                break
                            end
                        end

                        if isMatch then
                            local risk = PhysicsAuditor.RiskLevel.MEDIUM
                            local reco = "Revisar si este remoto valida la posición en el servidor."
                            if lowerName:find("teleport") or lowerName:find("setcframe") or lowerName:find("setpos") then
                                risk = PhysicsAuditor.RiskLevel.CRITICAL
                                reco = "🚨 Crítico: Remoto de coordenadas directas. Probar desincronización de posición y teletransporte."
                            elseif lowerName:find("dash") or lowerName:find("velocity") or lowerName:find("sprint") or lowerName:find("speed") then
                                risk = PhysicsAuditor.RiskLevel.HIGH
                                reco = "⚔️ Alto: Control de velocidad/impulso de movimiento."
                            end

                            table.insert(physicsRemotes, {
                                Remote = inst,
                                Name = inst.Name,
                                ClassName = inst.ClassName,
                                Path = inst:GetFullName(),
                                Risk = risk,
                                Recommendation = reco,
                            })
                        end
                    end
                end
            end
        end
    end

    return physicsRemotes
end

-- =============================================================================
-- 4. AUDITORÍA QUIRÚRGICA MULTIHILO ENFOCADA EN SCRIPTS DEL JUGADOR
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

    -- Contenedores QUIRÚRGICOS donde residen scripts del jugador y anti-cheats
    local targetContainers = {
        game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
        game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts"),
        self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerScripts"),
        self.LocalPlayer and self.LocalPlayer.Character,
        self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerGui"),
    }

    local queue = {}
    local visited = {}

    local function collectFrom(parent)
        if not parent then return end
        local s, d = pcall(function() return parent:GetDescendants() end)
        if s and d then
            for _, item in ipairs(d) do
                if item:IsA("LuaSourceContainer") and not visited[item] and not self:IsIgnoredCoreInstance(item) then
                    visited[item] = true
                    table.insert(queue, item)
                end
            end
        end
    end

    for _, cont in ipairs(targetContainers) do
        collectFrom(cont)
    end

    -- Módulos específicos de movimiento/seguridad en ReplicatedStorage
    pcall(function()
        local repDesc = ReplicatedStorage:GetDescendants()
        for _, item in ipairs(repDesc) do
            if item:IsA("ModuleScript") and not visited[item] and not self:IsIgnoredCoreInstance(item) then
                local nLower = item.Name:lower()
                if nLower:find("movement") or nLower:find("character") or nLower:find("controller")
                   or nLower:find("physics") or nLower:find("anticheat") or nLower:find("security")
                   or nLower:find("player") or nLower:find("dash") or nLower:find("combat") then
                    visited[item] = true
                    table.insert(queue, item)
                end
            end
        end
    end)

    report.TotalScriptsScanned = #queue
    local total = #queue
    if total == 0 then return report end

    -- =========================================================================
    -- MOTOR CONCURRENTE MULTIHILO (WORKER POOL CON 8 HILOS PARALELOS)
    -- =========================================================================
    local workerCount = math.min(8, math.max(2, #queue))
    local nextIndex = 1
    local completed = 0
    local activeWorkers = workerCount
    local startTime = tick()
    local lastProgressUpdate = 0
    local resultsLock = {}

    local function notifyProgress(currentInstName)
        local now = tick()
        if now - lastProgressUpdate >= 0.02 or completed == total then
            lastProgressUpdate = now
            local elapsed = math.max(now - startTime, 0.001)
            local speed = completed / elapsed
            local eta = (speed > 0) and ((total - completed) / speed) or 0
            if onProgress then
                pcall(onProgress, completed, total, currentInstName or "Finalizando...", elapsed, eta, speed)
            end
        end
    end

    local function workerLoop()
        local workerYield = tick()
        while true do
            local myIdx = nextIndex
            nextIndex = nextIndex + 1
            if myIdx > total then break end

            local scriptInst = queue[myIdx]
            if scriptInst then
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
                        table.insert(resultsLock, scriptEntry)
                    end
                end

                completed = completed + 1
                notifyProgress(scriptInst.Name)
            end

            if tick() - workerYield > 0.010 then
                task.wait()
                workerYield = tick()
            end
        end
        activeWorkers = activeWorkers - 1
    end

    for w = 1, workerCount do
        task.spawn(workerLoop)
    end

    while activeWorkers > 0 do
        task.wait()
    end

    notifyProgress("Completado")

    -- Consolidar resultados en el reporte
    for _, scriptEntry in ipairs(resultsLock) do
        table.insert(report.PhysicsScripts, scriptEntry)
        for _, f in ipairs(scriptEntry.Findings) do
            if f.Severity == "CRITICAL" then
                report.CriticalVulnerabilities = report.CriticalVulnerabilities + 1
            end
            if f.Type:find("WATCHDOG") or f.Type:find("DETECTOR") or f.Type:find("LOCK") then
                table.insert(report.WatchdogsDetected, {
                    Script = scriptEntry.Path,
                    Finding = f,
                })
            end
        end
    end

    if self.Logger then
        self.Logger:Info("PHYSICS", string.format(
            "Auditoría Multihilo de Físicas finalizada en %.2fs: %d scripts procesados, %d watchdogs encontrados.",
            tick() - startTime, total, #report.WatchdogsDetected
        ))
    end

    return report
end

-- =============================================================================
-- 5. FORMATEADOR DE REPORTE Y GENERADOR DE STANDALONE TEST SCRIPT
-- =============================================================================

function PhysicsAuditor:FormatTextReport(auditReport)
    local lines = {}
    table.insert(lines, "=============================================================================")
    table.insert(lines, "🏃 APEX SUITE - AUDITORÍA DE FÍSICAS DEL JUGADOR & ANTI-CHEATS")
    table.insert(lines, "=============================================================================")

    local snap = auditReport.PlayerSnapshot or {}
    table.insert(lines, "\n[1. ESTADO FÍSICO DEL LOCALPLAYER EN VIVO]:")
    table.insert(lines, string.format("   • Gravedad: %.1f | Caída Límite: %.1f", snap.Gravity or 196.2, snap.FallenPartsDestroyHeight or -500))
    table.insert(lines, string.format("   • WalkSpeed: %.1f | JumpPower: %.1f | JumpHeight: %.1f | HipHeight: %.2f", snap.WalkSpeed or 16, snap.JumpPower or 50, snap.JumpHeight or 7.2, snap.HipHeight or 0))
    table.insert(lines, string.format("   • Velocidad Horizontal: %.2f studs/s | Vertical: %.2f studs/s", snap.HorizontalSpeed or 0, snap.VerticalSpeed or 0))
    table.insert(lines, string.format("   • Estado Humanoid: %s | Suelo: %s | Distancia Suelo: %s", snap.HumanoidState or "None", snap.FloorMaterial or "None", snap.FloorDistance and string.format("%.2f studs", snap.FloorDistance) or "En el aire"))
    table.insert(lines, string.format("   • Sentado: %s | PlatformStand: %s | CanCollide HRP: %s", tostring(snap.Sit or false), tostring(snap.PlatformStand or false), tostring(snap.CanCollide or false)))
    
    if snap.ForcesDetected and #snap.ForcesDetected > 0 then
        table.insert(lines, "   • Fuerzas / Constraints activas en el personaje:")
        for _, force in ipairs(snap.ForcesDetected) do
            table.insert(lines, string.format("      - [%s] %s (en %s)", force.ClassName, force.Name, force.ParentPart))
        end
    end

    table.insert(lines, "\n[2. ANTI-CHEATS Y WATCHDOGS DE FÍSICA DEL JUGADOR]: " .. tostring(#auditReport.WatchdogsDetected))
    if #auditReport.WatchdogsDetected == 0 then
        table.insert(lines, "   ✅ No se detectaron trampas o watchdogs de física en el cliente del jugador.")
    else
        for idx, item in ipairs(auditReport.WatchdogsDetected) do
            table.insert(lines, string.format("   [%d] %s en '%s'", idx, item.Finding.Type, item.Script))
            table.insert(lines, string.format("       Línea %d: %s", item.Finding.Line, item.Finding.Description))
            table.insert(lines, string.format("       Código: %s", item.Finding.Snippet))
        end
    end

    table.insert(lines, "\n[3. REMOTES DE MOVIMIENTO / POSICIÓN DEL JUGADOR]: " .. tostring(#auditReport.PhysicsRemotes))
    if #auditReport.PhysicsRemotes == 0 then
        table.insert(lines, "   ℹ️ No se encontraron remotes con nombres explícitos de movimiento en el cliente.")
    else
        for idx, rem in ipairs(auditReport.PhysicsRemotes) do
            local emoji = (rem.Risk == "CRITICAL" and "🚨") or (rem.Risk == "HIGH" and "⚔️") or "📡"
            table.insert(lines, string.format("   %s [%d] %s (%s)", emoji, idx, rem.Name, rem.Risk))
            table.insert(lines, string.format("       Ruta: %s", rem.Path))
            table.insert(lines, string.format("       Nota: %s", rem.Recommendation))
        end
    end

    table.insert(lines, "\n[4. SCRIPTS DE CONTROL DE FÍSICA DEL JUGADOR]: " .. tostring(#auditReport.PhysicsScripts))
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
    APEX SUITE - STANDALONE PLAYER PHYSICS & MOVEMENT TESTER
    =============================================================================
    Script de prueba parametrizado para validar respuesta a cambios de física
    del jugador (WalkSpeed, Vuelo, Noclip, Teleport).
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Tester = {
    OriginalSpeed = 16,
    OriginalJump = 50,
    IsFlying = false,
    IsNoclipping = false,
    Connections = {},
}

function Tester.SetSpeed(newSpeed)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = newSpeed
        print(string.format("[APEX PHYSICS] WalkSpeed establecido en %.1f", newSpeed))
    end
end

function Tester.ToggleNoclip(enable)
    Tester.IsNoclipping = enable
    if enable then
        if Tester.Connections.Noclip then Tester.Connections.Noclip:Disconnect() end
        Tester.Connections.Noclip = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
        print("[APEX PHYSICS] Noclip Activado.")
    else
        if Tester.Connections.Noclip then
            Tester.Connections.Noclip:Disconnect()
            Tester.Connections.Noclip = nil
        end
        print("[APEX PHYSICS] Noclip Desactivado.")
    end
end

function Tester.ToggleFly(enable, speed)
    speed = speed or 50
    Tester.IsFlying = enable
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if enable then
        local att = hrp:FindFirstChild("ApexFlyAtt") or Instance.new("Attachment", hrp)
        att.Name = "ApexFlyAtt"
        local lv = hrp:FindFirstChild("ApexFlyVel") or Instance.new("LinearVelocity", hrp)
        lv.Name = "ApexFlyVel"
        lv.Attachment0 = att
        lv.MaxForce = math.huge
        lv.VectorVelocity = Vector3.zero
        print(string.format("[APEX PHYSICS] Vuelo Activado a %.1f studs/s.", speed))
    else
        local lv = hrp:FindFirstChild("ApexFlyVel")
        local att = hrp:FindFirstChild("ApexFlyAtt")
        if lv then lv:Destroy() end
        if att then att:Destroy() end
        print("[APEX PHYSICS] Vuelo Desactivado.")
    end
end

return Tester
]=]
end

return PhysicsAuditor
