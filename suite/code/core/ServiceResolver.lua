--[[
    =============================================================================
    APEX SUITE - UNIVERSAL SERVICE & INSTANCE RESOLVER (ANTI-OBFUSCATION)
    =============================================================================
    Maneja la resolución de servicios e instancias críticas cuando los juegos
    ofuscan o renombran Workspace, Players, ReplicatedStorage, etc. a GUIDs.
    Resuelve por ClassName nativo en C++ con 4 niveles de fallback.
--]]

local ServiceResolver = {}
ServiceResolver.ClassName = "ServiceResolver"

local rawGame = (typeof(workspace) == "Instance" and workspace.Parent) or game

-- Comprobación pasiva de elevación (sin forzar GetService de CoreGui)
local isElevated = false
pcall(function()
    local cg = rawGame:FindFirstChild("CoreGui")
    if cg then
        local s = pcall(function() return cg:GetFullName() end)
        if s then isElevated = true end
    end
end)
ServiceResolver.IsElevated = isElevated

local rawCloneref = (type(cloneref) == "function" and cloneref) or nil
local function safeClone(inst)
    if not inst or not rawCloneref then return inst end
    local ok, cloned = pcall(rawCloneref, inst)
    if ok and cloned and (type(cloned) == "userdata" or typeof(cloned) == "Instance") then
        local valid = pcall(function() return cloned.ClassName end)
        if valid then return cloned end
    end
    return inst
end

function ServiceResolver.GetService(className)
    if not className then return nil end

    -- Fallback especial para Workspace
    if className == "Workspace" and typeof(workspace) == "Instance" then
        return workspace
    end

    -- Si no está elevado, proteger servicios restringidos de RobloxScriptSecurity
    if not ServiceResolver.IsElevated then
        if className == "CoreGui" or className == "RobloxReplicatedStorage" or className == "RobloxGui" then
            return nil
        end
    end

    -- Nivel 1: GetService oficial (resuelve por ClassName interno)
    local ok1, srv1 = pcall(function() return rawGame:GetService(className) end)
    if ok1 and srv1 then return safeClone(srv1) end

    -- Nivel 2: FindFirstChildOfClass
    local ok2, srv2 = pcall(function() return rawGame:FindFirstChildOfClass(className) end)
    if ok2 and srv2 then return safeClone(srv2) end

    -- Nivel 3: FindFirstChildWhichIsA
    local ok3, srv3 = pcall(function() return rawGame:FindFirstChildWhichIsA(className) end)
    if ok3 and srv3 then return safeClone(srv3) end

    -- Nivel 4: Búsqueda exhaustiva por ClassName en todos los hijos directos del DataModel
    local ok4, children = pcall(function() return rawGame:GetChildren() end)
    if ok4 and children then
        for _, child in ipairs(children) do
            local sOk, cName = pcall(function() return child.ClassName end)
            if sOk and cName == className then
                return safeClone(child)
            end
        end
    end

    return nil
end

function ServiceResolver.GetPlayers()
    return ServiceResolver.GetService("Players")
end

function ServiceResolver.GetLocalPlayer()
    local players = ServiceResolver.GetPlayers()
    if players then
        if players.LocalPlayer then return players.LocalPlayer end
        local ok, lp = pcall(function() return players:FindFirstChildOfClass("Player") end)
        if ok and lp then return lp end
    end
    return nil
end

function ServiceResolver.GetPlayerGui()
    local lp = ServiceResolver.GetLocalPlayer()
    if lp then
        return lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
    end
    return nil
end

function ServiceResolver.GetWorkspace()
    return ServiceResolver.GetService("Workspace") or workspace
end

function ServiceResolver.GetReplicatedStorage()
    return ServiceResolver.GetService("ReplicatedStorage")
end

function ServiceResolver.GetStarterPlayer()
    return ServiceResolver.GetService("StarterPlayer")
end

function ServiceResolver.GetReplicatedFirst()
    return ServiceResolver.GetService("ReplicatedFirst")
end

return ServiceResolver
