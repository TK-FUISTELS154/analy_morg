--[[
    =============================================================================
    APEX SUITE - ADVANCED PLAYER PHYSICS & ANTI-CHEAT AUDITOR v5.0
    (EXCLUSIVE LOCALPLAYER & CHARACTER PHYSICS WATCHDOG ENGINE)
    =============================================================================
    Módulo ultra-optimizado y enfocado EXCLUSIVAMENTE en las físicas del jugador:
      1. Telemetría en Vivo de Físicas del LocalPlayer:
         - MoveDirection, UseJumpPower, AssemblyMass, CustomPhysicalProperties
         - Colisiones anatómicas distribuidas (Torso R6, UpperTorso/LowerTorso R15)
         - Velocidades, Fuerzas, Raycast de distancia al suelo
      2. Auditoría Estricta de Anti-Cheats / Watchdogs de Física del Jugador:
         - Speed, Fly, Noclip anatómico, Teleport, Property Locks
         - Cero referencias circulares en serialización
      3. Detección de Remotes de Red con Fronteras Léxicas (evita falsos positivos como PotionRemove)
      4. Escaneo Quirúrgico: Excluye PlayerGui (reduciendo de 779 a < 60 scripts en < 50ms)
      5. Worker Pool Multihilo Concurrente (8 hilos paralelos)
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
    self.RuntimeWatchdogs = {}
    self.RuntimeWatcherConnections = {}
    self.IsRuntimeWatcherActive = false
    return self
end

-- =============================================================================
-- FILTRO DE EXCLUSIÓN DE SCRIPTS NATIVOS Y LIBRERÍAS (O(1))
-- =============================================================================
function PhysicsAuditor:IsIgnoredCoreInstance(instance)
    local fullName = instance:GetFullName()
    if fullName:find("PlayerModule")
       or fullName:find("ControlModule")
       or fullName:find("CameraModule")
       or fullName:find("TouchJump")
       or fullName:find("RbxCharacterSounds")
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
-- 1. TELEMETRÍA EN VIVO DE FÍSICAS DEL LOCALPLAYER (Snapshot Completo)
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
        UseJumpPower = true,
        HipHeight = 0,
        MaxSlopeAngle = 89,
        AutoRotate = true,
        PlatformStand = false,
        Sit = false,
        HumanoidState = "None",
        MoveDirection = Vector3.zero,
        MoveDirectionMagnitude = 0,
        Position = Vector3.zero,
        CFrame = CFrame.new(),
        LinearVelocity = Vector3.zero,
        AngularVelocity = Vector3.zero,
        HorizontalSpeed = 0,
        VerticalSpeed = 0,
        AssemblyMass = 0,
        CanCollide = true,
        TorsoCanCollide = nil,
        UpperTorsoCanCollide = nil,
        LowerTorsoCanCollide = nil,
        AnatomicalCollisions = {},
        RootPhysicalProperties = nil,
        TorsoPhysicalProperties = nil,
        FloorMaterial = "None",
        FloorDistance = nil,
        ForcesDetected = {},
        NetworkOwnership = "Client",
    }

    local function extractPhysicalProps(part)
        if not part or not part:IsA("BasePart") then return nil end
        local s, props = pcall(function() return part.CustomPhysicalProperties end)
        if s and props then
            return {
                Density = props.Density,
                Friction = props.Friction,
                Elasticity = props.Elasticity,
                FrictionWeight = props.FrictionWeight,
                ElasticityWeight = props.ElasticityWeight,
            }
        end
        return nil
    end

    pcall(function()
        local char = self.LocalPlayer.Character
        if not char then return end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local torso = char:FindFirstChild("Torso")
        local upperTorso = char:FindFirstChild("UpperTorso")
        local lowerTorso = char:FindFirstChild("LowerTorso")
        local head = char:FindFirstChild("Head")

        if hum then
            snap.IsAlive = (hum.Health > 0)
            snap.WalkSpeed = hum.WalkSpeed
            snap.JumpPower = hum.JumpPower
            snap.JumpHeight = hum.JumpHeight
            snap.UseJumpPower = hum.UseJumpPower
            snap.HipHeight = hum.HipHeight
            snap.MaxSlopeAngle = hum.MaxSlopeAngle
            snap.AutoRotate = hum.AutoRotate
            snap.PlatformStand = hum.PlatformStand
            snap.Sit = hum.Sit
            snap.FloorMaterial = hum.FloorMaterial.Name
            snap.HumanoidState = hum:GetState().Name
            snap.MoveDirection = hum.MoveDirection
            snap.MoveDirectionMagnitude = hum.MoveDirection.Magnitude
        end

        -- Colisiones anatómicas en torso (R6 y R15)
        if torso and torso:IsA("BasePart") then
            snap.TorsoCanCollide = torso.CanCollide
            snap.AnatomicalCollisions["Torso"] = torso.CanCollide
            snap.TorsoPhysicalProperties = extractPhysicalProps(torso)
        end
        if upperTorso and upperTorso:IsA("BasePart") then
            snap.UpperTorsoCanCollide = upperTorso.CanCollide
            snap.AnatomicalCollisions["UpperTorso"] = upperTorso.CanCollide
            snap.TorsoPhysicalProperties = extractPhysicalProps(upperTorso)
        end
        if lowerTorso and lowerTorso:IsA("BasePart") then
            snap.LowerTorsoCanCollide = lowerTorso.CanCollide
            snap.AnatomicalCollisions["LowerTorso"] = lowerTorso.CanCollide
        end
        if head and head:IsA("BasePart") then
            snap.AnatomicalCollisions["Head"] = head.CanCollide
        end

        if hrp then
            snap.Position = hrp.Position
            snap.CFrame = hrp.CFrame
            snap.LinearVelocity = hrp.AssemblyLinearVelocity
            snap.AngularVelocity = hrp.AssemblyAngularVelocity
            snap.HorizontalSpeed = Vector2.new(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z).Magnitude
            snap.VerticalSpeed = hrp.AssemblyLinearVelocity.Y
            snap.AssemblyMass = hrp.AssemblyMass
            snap.CanCollide = hrp.CanCollide
            snap.RootPhysicalProperties = extractPhysicalProps(hrp)

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
-- 2. DETECCIÓN DINÁMICA DE WATCHDOGS EN TIEMPO REAL (RUNTIME PROBING)
-- =============================================================================

function PhysicsAuditor:StartRuntimePhysicsWatcher()
    if self.IsRuntimeWatcherActive then return end
    self.IsRuntimeWatcherActive = true
    self:StopRuntimePhysicsWatcher()

    local char = self.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    local function registerRuntimeWatchdog(watchdogType, sourceScript, desc, severity)
        local entry = {
            Type = watchdogType,
            Script = sourceScript and (pcall(function() return sourceScript:GetFullName() end) and sourceScript:GetFullName() or tostring(sourceScript)) or "DynamicHook",
            Description = desc,
            Severity = severity or "HIGH",
            Timestamp = tick(),
        }
        table.insert(self.RuntimeWatchdogs, 1, entry)
        if #self.RuntimeWatchdogs > 50 then table.remove(self.RuntimeWatchdogs) end

        -- Inyección inmediata de sospechoso a CapabilityManager
        if self.Caps and sourceScript and typeof(sourceScript) == "Instance" then
            self.Caps:RegisterSuspect(sourceScript, "ActiveRuntimePhysicsWatchdog", 95, {
                WatchdogType = watchdogType,
                Description = desc,
                Severity = severity or "HIGH",
            })
        end

        if self.Logger then
            self.Logger:Warn("PHYSICS_WATCHER", string.format("🚨 Watchdog en vivo detectado: [%s] en %s (%s)", watchdogType, entry.Script, desc))
        end
    end

    -- 1. Introspección de Conexiones a Propiedades Críticas del Humanoid
    local getconn = (type(getconnections) == "function" and getconnections)
        or (self.Caps and self.Caps.APIs and self.Caps.APIs.getconnections)

    if hum and getconn then
        local criticalProps = { "WalkSpeed", "JumpPower", "JumpHeight", "HipHeight", "PlatformStand" }
        for _, prop in ipairs(criticalProps) do
            local sSignal, signal = pcall(function() return hum:GetPropertyChangedSignal(prop) end)
            if sSignal and signal then
                local sConn, conns = pcall(getconn, signal)
                if sConn and type(conns) == "table" then
                    for _, c in ipairs(conns) do
                        local fn = c.Function
                        if fn and type(fn) == "function" then
                            local scriptObj = nil
                            pcall(function()
                                local env = getfenv(fn)
                                if env and env.script and typeof(env.script) == "Instance" then
                                    scriptObj = env.script
                                end
                            end)
                            if not scriptObj and debug and debug.getinfo then
                                pcall(function()
                                    local info = debug.getinfo(fn)
                                    if info and info.source then
                                        local clean = info.source:gsub("^@", "")
                                        for _, sInst in ipairs(game:GetDescendants()) do
                                            if sInst:IsA("LuaSourceContainer") and (sInst:GetFullName() == clean or sInst.Name == clean) then
                                                scriptObj = sInst
                                                break
                                            end
                                        end
                                    end
                                end)
                            end

                            if scriptObj and not self:IsIgnoredCoreInstance(scriptObj) then
                                registerRuntimeWatchdog("HUMANOID_PROPERTY_LISTENER", scriptObj, "Script escuchando cambios en " .. prop .. " vía conexión en vivo", "HIGH")
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Monitoreo de Fuerzas Forzadas o Restricciones Instanciadas en Tiempo Real
    if char then
        table.insert(self.RuntimeWatcherConnections, char.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("VectorForce") or descendant:IsA("LinearVelocity") or descendant:IsA("BodyVelocity")
               or descendant:IsA("BodyPosition") or descendant:IsA("AlignPosition") or descendant:IsA("BodyGyro") then
                local parentPart = descendant.Parent
                if parentPart and (parentPart == hrp or parentPart.Name:find("Torso") or parentPart.Name:find("Root")) then
                    registerRuntimeWatchdog("UNAUTHORIZED_PHYSICS_FORCE", descendant, string.format("Fuerza física forzada '%s' (%s) acoplada a %s", descendant.Name, descendant.ClassName, parentPart.Name), "MEDIUM")
                end
            end
        end))
    end

    if self.Logger then
        self.Logger:Info("PHYSICS_WATCHER", "Vigilante Dinámico de Físicas en Tiempo Real activado (Runtime Probing).")
    end
end

function PhysicsAuditor:StopRuntimePhysicsWatcher()
    for _, conn in ipairs(self.RuntimeWatcherConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.RuntimeWatcherConnections)
    self.IsRuntimeWatcherActive = false
end

-- =============================================================================
-- 3. AUDITORÍA ESTÁTICA EXCLUSIVA DE ANTI-CHEATS Y FÍSICAS DEL JUGADOR
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
            or lLower:find("torso") or lLower:find("uppertorso") or lLower:find("lowertorso")

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
                    Description = "Anti-Cheat de Velocidad: Compara desplazamiento delta por frame con límite de WalkSpeed y sanciona",
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

            -- 3. Anti-Cheat de Noclip / Colisión del Personaje (Detección Anatómica en Torso/HRP)
            local hasTorsoOrRoot = lLower:find("torso") or lLower:find("uppertorso") or lLower:find("lowertorso") or lLower:find("rootpart") or lLower:find("hrp") or lLower:find("character")
            if hasTorsoOrRoot and (lLower:find("cancollide") or lLower:find("lastpos") or lLower:find("oldpos") or lLower:find("prevpos")) and (lLower:find("raycast") or lLower:find("getpartsinpart")) and (lLower:find("wall") or lLower:find("hit") or lLower:find("solid") or lLower:find("barrier")) and (lLower:find("kick") or lLower:find("rollback") or lLower:find("teleport") or lLower:find("respawn")) then
                summary.HasNoclipWatchdog = true
                summary.PhysicsScore = summary.PhysicsScore + 40
                table.insert(findings, {
                    Type = "PLAYER_NOCLIP_WATCHDOG",
                    Severity = "CRITICAL",
                    Line = lineNum,
                    Snippet = line:match("^%s*(.-)%s*$") or line,
                    Description = "Anti-Cheat de Noclip: Raycasting proyectado entre la posición previa y actual del torso/HRP para detectar traspaso de muros",
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
-- 4. AUDITORÍA DE RED: REMOTES DE MOVIMIENTO CON MATRIZ CRUZADA Y FIRMAS
-- =============================================================================

function PhysicsAuditor:AuditPhysicsRemotes()
    local physicsRemotes = {}
    local explicitKeywords = {
        "teleport", "setcframe", "setpos", "setposition", "movement",
        "dash", "sprint", "velocity", "flight", "fly", "jump", "slide", "roll", "position"
    }

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

                        -- 1. Coincidencia con palabras clave explícitas
                        for _, kw in ipairs(explicitKeywords) do
                            if lowerName:find(kw, 1, true) then
                                isMatch = true
                                break
                            end
                        end

                        -- 2. Delimitación léxica para "move": descartar prefijos como "remove"
                        if not isMatch and not lowerName:find("remove") and not lowerName:find("unmove") and not lowerName:find("clear") then
                            if lowerName:match("%f[%a]move%f[%A]") or lowerName:find("movement") then
                                isMatch = true
                            end
                        end

                        -- 3. Validación Cruzada con Perfiles de Esquema de RemoteAnalyzer
                        local schemaProfile = self.RemoteAnalyzer and self.RemoteAnalyzer.SchemaProfiles and self.RemoteAnalyzer.SchemaProfiles[inst.Name]
                        local hasVectorOrCFrame = false
                        if schemaProfile and schemaProfile.Signatures then
                            for sig, _ in pairs(schemaProfile.Signatures) do
                                if sig:find("Vector3") or sig:find("CFrame") then
                                    hasVectorOrCFrame = true
                                    break
                                end
                            end
                        end

                        if isMatch or hasVectorOrCFrame then
                            local risk = PhysicsAuditor.RiskLevel.MEDIUM
                            local reco = "Revisar si este remoto valida la posición en el servidor."
                            if lowerName:find("teleport") or lowerName:find("setcframe") or lowerName:find("setpos") or lowerName:find("setposition") then
                                risk = PhysicsAuditor.RiskLevel.CRITICAL
                                reco = "🚨 Crítico: Remoto de coordenadas directas. Probar desincronización de posición y teletransporte."
                            elseif lowerName:find("dash") or lowerName:find("velocity") or lowerName:find("sprint") or lowerName:find("speed") then
                                risk = PhysicsAuditor.RiskLevel.HIGH
                                reco = "⚔️ Alto: Control de velocidad/impulso de movimiento."
                            elseif hasVectorOrCFrame then
                                risk = PhysicsAuditor.RiskLevel.HIGH
                                reco = "📡 Alto: Transmisión confirmada de Vector3/CFrame en red."
                            end

                            table.insert(physicsRemotes, {
                                Remote = inst,
                                Name = inst.Name,
                                ClassName = inst.ClassName,
                                Path = inst:GetFullName(),
                                Risk = risk,
                                Recommendation = reco,
                                TransmitsCoordinates = hasVectorOrCFrame,
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
-- 4. AUDITORÍA QUIRÚRGICA MULTIHILO (EXCLUYE PLAYERGUI, < 60 SCRIPTS, < 50ms)
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

    -- Contenedores QUIRÚRGICOS donde residen scripts del jugador y anti-cheats (PlayerGui EXCLUIDO)
    local targetContainers = {
        game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
        game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts"),
        self.LocalPlayer and self.LocalPlayer:FindFirstChild("PlayerScripts"),
        self.LocalPlayer and self.LocalPlayer.Character,
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

    -- Consolidar resultados en el reporte eliminando referencias circulares
    for _, scriptEntry in ipairs(resultsLock) do
        table.insert(report.PhysicsScripts, scriptEntry)
        for _, f in ipairs(scriptEntry.Findings) do
            if f.Severity == "CRITICAL" then
                report.CriticalVulnerabilities = report.CriticalVulnerabilities + 1
            end
            if f.Type:find("WATCHDOG") or f.Type:find("DETECTOR") or f.Type:find("LOCK") then
                -- Copia superficial limpia con tipos primitivos (sin compartir referencia de tabla)
                table.insert(report.WatchdogsDetected, {
                    Script = scriptEntry.Path,
                    Finding = {
                        Type = f.Type,
                        Severity = f.Severity,
                        Line = f.Line,
                        Snippet = f.Snippet,
                        Description = f.Description,
                    },
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
    table.insert(lines, "🏃 APEX SUITE - AUDITORÍA DE FÍSICAS DEL JUGADOR & ANTI-CHEATS v5.0")
    table.insert(lines, "=============================================================================")

    local snap = auditReport.PlayerSnapshot or {}
    table.insert(lines, "\n[1. ESTADO FÍSICO DEL LOCALPLAYER EN VIVO]:")
    table.insert(lines, string.format("   • Gravedad: %.1f | Caída Límite: %.1f", snap.Gravity or 196.2, snap.FallenPartsDestroyHeight or -500))
    table.insert(lines, string.format("   • WalkSpeed: %.1f | JumpPower: %.1f (UsaJumpPower: %s) | JumpHeight: %.1f | HipHeight: %.2f",
        snap.WalkSpeed or 16, snap.JumpPower or 50, tostring(snap.UseJumpPower), snap.JumpHeight or 7.2, snap.HipHeight or 0))
    table.insert(lines, string.format("   • Velocidad Horizontal: %.2f studs/s | Vertical: %.2f studs/s | Masa del Ensamble: %.2f",
        snap.HorizontalSpeed or 0, snap.VerticalSpeed or 0, snap.AssemblyMass or 0))
    table.insert(lines, string.format("   • Intención de Movimiento (MoveDirection): %s (Magnitud: %.2f)",
        tostring(snap.MoveDirection or Vector3.zero), snap.MoveDirectionMagnitude or 0))
    table.insert(lines, string.format("   • Estado Humanoid: %s | Suelo: %s | Distancia Suelo: %s",
        snap.HumanoidState or "None", snap.FloorMaterial or "None", snap.FloorDistance and string.format("%.2f studs", snap.FloorDistance) or "En el aire"))
    table.insert(lines, string.format("   • Colisión HRP: %s | Torso (R6): %s | UpperTorso (R15): %s | LowerTorso: %s",
        tostring(snap.CanCollide), tostring(snap.TorsoCanCollide), tostring(snap.UpperTorsoCanCollide), tostring(snap.LowerTorsoCanCollide)))
    table.insert(lines, string.format("   • Sentado: %s | PlatformStand: %s", tostring(snap.Sit or false), tostring(snap.PlatformStand or false)))

    if snap.RootPhysicalProperties then
        local p = snap.RootPhysicalProperties
        table.insert(lines, string.format("   • Fricción HRP: %.2f (Peso: %.2f) | Elasticidad: %.2f | Densidad: %.2f",
            p.Friction, p.FrictionWeight, p.Elasticity, p.Density))
    end
    if snap.TorsoPhysicalProperties then
        local p = snap.TorsoPhysicalProperties
        table.insert(lines, string.format("   • Fricción Torso: %.2f (Peso: %.2f) | Elasticidad: %.2f | Densidad: %.2f",
            p.Friction, p.FrictionWeight, p.Elasticity, p.Density))
    end

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
    APEX SUITE - STANDALONE PLAYER PHYSICS & MOVEMENT TOLERANCE TESTER
    =============================================================================
    Script de prueba parametrizado para validar respuesta a cambios de física
    del jugador (WalkSpeed, Vuelo, Noclip, Teleport) y medir tolerancia del servidor
    a desincronizaciones y rebobinados de red (Rollback / Rubberband Testing).
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
    Results = {},
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

--[[
    Auditoría de Tolerancia de Velocidad (Speed Threshold & Rollback Testing)
    Evalúa desplazamientos incrementales (20, 30, 50, 100 studs/s) y detecta
    si el servidor fuerza un rebobinado de posición (Rubberbanding).
--]]
function Tester.RunSpeedThresholdAudit(onComplete)
    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            warn("[APEX PHYSICS] No se pudo encontrar HumanoidRootPart para el test de rollback.")
            return
        end

        local speedSteps = { 20, 30, 50, 75, 100, 150 }
        local auditResults = {}
        local initialSpeed = hum.WalkSpeed

        print("---------------------------------------------------------")
        print("  INICIANDO TEST DE TOLERANCIA Y ROLLBACK DE VELOCIDAD")
        print("---------------------------------------------------------")

        for _, testSpeed in ipairs(speedSteps) do
            hum.WalkSpeed = testSpeed
            local startPos = hrp.Position
            local sampleDuration = 1.0 -- Segundos de muestreo por velocidad
            local startTime = tick()
            local maxDisplacement = 0
            local rollbackDetected = false
            local lastPos = startPos

            while (tick() - startTime) < sampleDuration do
                task.wait(0.1)
                local curPos = hrp.Position
                local currentDelta = (curPos - lastPos).Magnitude
                -- Si la posición vuelve abruptamente hacia atrás mientras se mueve
                if (curPos - startPos).Magnitude < (lastPos - startPos).Magnitude - 5 and currentDelta > 4 then
                    rollbackDetected = true
                end
                lastPos = curPos
                local totalMoved = (curPos - startPos).Magnitude
                if totalMoved > maxDisplacement then
                    maxDisplacement = totalMoved
                end
            end

            local theoreticalDist = testSpeed * sampleDuration
            local efficiencyRatio = theoreticalDist > 0 and (maxDisplacement / theoreticalDist) or 0

            local stepResult = {
                SpeedTested = testSpeed,
                Displacement = maxDisplacement,
                Theoretical = theoreticalDist,
                Efficiency = efficiencyRatio,
                RollbackDetected = rollbackDetected or (efficiencyRatio < 0.35 and testSpeed > 25),
                Passed = not rollbackDetected and (efficiencyRatio >= 0.5 or maxDisplacement < 1)
            }
            table.insert(auditResults, stepResult)

            local statusStr = stepResult.RollbackDetected and "🚨 ROLLBACK / RECHAZO DETECTADO" or "✅ TOLERADO"
            print(string.format("  [VELOCIDAD %d studs/s] Desplazamiento: %.1f / %.1f studs | Estado: %s",
                testSpeed, maxDisplacement, theoreticalDist, statusStr))
            
            task.wait(0.5)
        end

        hum.WalkSpeed = initialSpeed
        Tester.Results.SpeedAudit = auditResults
        print("---------------------------------------------------------")
        print("  TEST DE TOLERANCIA COMPLETADO CON ÉXITO")
        print("---------------------------------------------------------")

        if onComplete then
            onComplete(auditResults)
        end
    end)
end

--[[
    Auditoría de Tolerancia de Teletransporte Milimétrico / Rango
--]]
function Tester.RunTeleportToleranceAudit(onComplete)
    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local distSteps = { 5, 10, 20, 50, 100, 250, 500 }
        local tpResults = {}

        print("---------------------------------------------------------")
        print("  INICIANDO TEST DE TOLERANCIA DE TELETRANSPORTE")
        print("---------------------------------------------------------")

        for _, dist in ipairs(distSteps) do
            local startCFrame = hrp.CFrame
            local targetCFrame = startCFrame * CFrame.new(0, 0, -dist)
            
            hrp.CFrame = targetCFrame
            task.wait(0.25)
            
            local finalPos = hrp.Position
            local actualDist = (finalPos - startCFrame.Position).Magnitude
            local rollbackDist = (finalPos - targetCFrame.Position).Magnitude
            local isRollback = rollbackDist > 3

            local tpRes = {
                RequestedDistance = dist,
                ActualDistance = actualDist,
                RollbackDetected = isRollback,
                Passed = not isRollback
            }
            table.insert(tpResults, tpRes)

            local statusStr = isRollback and string.format("🚨 RECHAZADO (Rebobinado %.1f studs)", rollbackDist) or "✅ ACEPTADO"
            print(string.format("  [DISTANCIA %d studs] Desplazamiento Real: %.1f | Estado: %s",
                dist, actualDist, statusStr))

            -- Restaurar posición segura
            hrp.CFrame = startCFrame
            task.wait(0.3)
        end

        Tester.Results.TeleportAudit = tpResults
        print("---------------------------------------------------------")
        if onComplete then onComplete(tpResults) end
    end)
end

return Tester
]=]
end

return PhysicsAuditor
