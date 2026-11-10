-- ==========================================================
-- Ninja Legends auto clone by ghosts
-- ==========================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Carga de funciones nativas del juego para leer datos reales
local globalFunctions = require(ReplicatedStorage:WaitForChild("globalFunctions"))

-- ==========================================================
-- 1. CREACIÓN SEGURA DE INTERFAZ GRÁFICA
-- ==========================================================
local function getSecureGuiParent()
	local parentContainer = nil
	if typeof(gethui) == "function" then pcall(function() parentContainer = gethui() end) end
	if not parentContainer and typeof(cloneref) == "function" and CoreGui then
		pcall(function() parentContainer = cloneref(CoreGui) end)
	end
	if not parentContainer then
		parentContainer = player:WaitForChild("PlayerGui")
	end
	return parentContainer
end

local targetParent = getSecureGuiParent()

for _, child in ipairs(targetParent:GetChildren()) do
	if child:IsA("ScreenGui") and child:GetAttribute("ClonerUI_Active") then
		child:Destroy()
	end
end

local SPOOFED_GUI_NAME = "UI_" .. tostring(math.random(100000, 999999))
local screenGui = Instance.new("ScreenGui")
screenGui.Name = SPOOFED_GUI_NAME
screenGui:SetAttribute("ClonerUI_Active", true)
screenGui.ResetOnSpawn = false
screenGui.Parent = targetParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 440)
mainFrame.Position = UDim2.new(0.65, 0, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "🌟 Auto Cloner V6 (Pro)"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

-- Etiqueta de Capacidad (En vivo)
local capLabel = Instance.new("TextLabel")
capLabel.Size = UDim2.new(1, 0, 0, 20)
capLabel.Position = UDim2.new(0, 0, 0, 38)
capLabel.BackgroundTransparency = 1
capLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
capLabel.Text = "Capacidad: Calculando..."
capLabel.Font = Enum.Font.GothamBold
capLabel.TextSize = 12
capLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 55)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statusLabel.Text = "Esperando mascotas..."
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = mainFrame

local baseLabel = Instance.new("TextLabel")
baseLabel.Size = UDim2.new(1, -20, 0, 30)
baseLabel.Position = UDim2.new(0, 10, 0, 80)
baseLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
baseLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
baseLabel.Text = "Base: (Ninguna)"
baseLabel.Font = Enum.Font.GothamBold
baseLabel.TextSize = 12
baseLabel.Parent = mainFrame
Instance.new("UICorner", baseLabel).CornerRadius = UDim.new(0, 6)

local loadBtn = Instance.new("TextButton")
loadBtn.Size = UDim2.new(0.9, 0, 0, 35)
loadBtn.Position = UDim2.new(0.05, 0, 0, 120)
loadBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
loadBtn.Text = "🔄 Cargar Mascotas (Sin Equipar)"
loadBtn.Font = Enum.Font.GothamBold
loadBtn.TextSize = 13
loadBtn.Parent = mainFrame
Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 6)

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(0.9, 0, 0, 160)
invScroll.Position = UDim2.new(0.05, 0, 0, 165)
invScroll.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 6
invScroll.Parent = mainFrame
Instance.new("UICorner", invScroll).CornerRadius = UDim.new(0, 6)

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.43, 0, 0, 45)
startBtn.Position = UDim2.new(0.05, 0, 0, 340)
startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "▶ INICIAR"
startBtn.Font = Enum.Font.GothamBlack
startBtn.TextSize = 16
startBtn.Parent = mainFrame
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(0.43, 0, 0, 45)
pauseBtn.Position = UDim2.new(0.52, 0, 0, 340)
pauseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
pauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
pauseBtn.Text = "⏸ PAUSAR"
pauseBtn.Font = Enum.Font.GothamBlack
pauseBtn.TextSize = 16
pauseBtn.Parent = mainFrame
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 6)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.M then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			mainFrame.Visible = not mainFrame.Visible
		end
	end
end)

-- ==========================================================
-- 2. REFERENCIAS REALES DEL JUEGO
-- ==========================================================
local rEvents = ReplicatedStorage:WaitForChild("rEvents", 10)
local petCloneEvent = rEvents:WaitForChild("petCloneEvent")
local autoEvolveRemote = rEvents:WaitForChild("autoEvolveRemote")

local petsFolder = player:WaitForChild("petsFolder")
local equippedPets = player:WaitForChild("equippedPets")
local maxPetCapacity = player:WaitForChild("maxPetCapacity")

local cloningArea = workspace:FindFirstChild("cloningAreaCircle")
local circleInner = cloningArea and cloningArea:FindFirstChild("circleInner")

local autoActivo = false
local mascotaBaseObj = nil
local mascotaBaseClave = nil -- Llave (Nombre + Evolución) para auto-recuperación

-- ==========================================================
-- 3. LECTURA, FILTRADO Y AGRUPACIÓN DE MASCOTAS
-- ==========================================================

-- Filtra las mascotas que tienes equipadas actualmente
local function isEquipped(petObj)
	local success, result = pcall(function()
		return globalFunctions.checkIfPetIsEquipped(equippedPets, petObj)
	end)
	if success and result ~= nil then
		return result
	end
	
	-- Fallback con la estructura correcta de Ninja Legends
	for _, eq in ipairs(equippedPets:GetChildren()) do
		local petRef = eq:FindFirstChild("petReference")
		if petRef and petRef:IsA("ObjectValue") and petRef.Value == petObj then
			return true
		end
	end
	return false
end

-- Agrupa y cuenta las mascotas según su tipo y nivel de evolución
local function getGroupedPets()
	local groups = {}
	local totalUnequipped = 0
	
	for _, rarityFolder in ipairs(petsFolder:GetChildren()) do
		for _, petObj in ipairs(rarityFolder:GetChildren()) do
			if petObj:IsA("StringValue") and not isEquipped(petObj) then
				totalUnequipped += 1
				
				local petName = petObj.Name
				local evoName = "Normal"
				
				-- Obtener el nombre visual si está renombrado
				local visualName = petName
				local chosenNameObj = petObj:FindFirstChild("chosenName")
				if chosenNameObj and chosenNameObj.Value ~= "" then
					visualName = chosenNameObj.Value
				end
				
				-- Extraer evolución real usando la función del juego
				pcall(function()
					local highestEvo = globalFunctions.getHighestPetEvolution(petObj)
					if highestEvo then
						evoName = string.upper(highestEvo.Name)
					end
				end)
				
				-- Agrupar por Nombre Original + Evolución
				local claveUnica = petName .. "_" .. evoName
				
				if not groups[claveUnica] then
					groups[claveUnica] = {
						Object = petObj, -- Tomamos el primero que encontremos como representativo
						VisualName = visualName,
						OriginalName = petName,
						Evolution = evoName,
						Clave = claveUnica,
						Count = 1
					}
				else
					groups[claveUnica].Count += 1
				end
			end
		end
	end
	
	local sortedGroups = {}
	for _, grp in pairs(groups) do
		table.insert(sortedGroups, grp)
	end
	
	return sortedGroups, totalUnequipped
end

-- Actualiza la Interfaz y lista las mascotas agrupadas
local function cargarMascotas()
	for _, child in pairs(invScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	
	local petGroups, totalUnequipped = getGroupedPets()
	local yOffset = 0
	
	if #petGroups == 0 then
		statusLabel.Text = "❌ Sin mascotas disponibles (Todas equipadas o vacías)."
		return
	end
	
	statusLabel.Text = "Mascotas para clonar: " .. totalUnequipped
	
	for _, grp in ipairs(petGroups) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 40)
		btn.Position = UDim2.new(0, 5, 0, yOffset)
		
		-- Color verde si coincide con la clave seleccionada
		if mascotaBaseClave and grp.Clave == mascotaBaseClave then
			btn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
			-- Si la seleccionada actual fue destruida en fusión, la reemplazamos automáticamente
			mascotaBaseObj = grp.Object 
		else
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end
		
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		-- Formato rico: Nombre [Evolución] - xCantidad
		btn.Text = string.format("%s [%s]\nCantidad: x%d", grp.VisualName, grp.Evolution, grp.Count)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.Parent = invScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		
		btn.MouseButton1Click:Connect(function()
			mascotaBaseObj = grp.Object
			mascotaBaseClave = grp.Clave
			baseLabel.Text = "Base: " .. grp.VisualName .. " [" .. grp.Evolution .. "]"
			cargarMascotas() 
		end)
		
		yOffset += 45
	end
	
	invScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

loadBtn.MouseButton1Click:Connect(cargarMascotas)

-- ==========================================================
-- 4. BUCLE DE CAPACIDAD, CLONACIÓN Y EVOLUCIÓN
-- ==========================================================
-- Hilo paralelo para actualizar el texto de Capacidad en tiempo real
task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			local currentCap = globalFunctions.calculatePetCapacity(petsFolder)
			local maxCap = maxPetCapacity.Value
			
			if currentCap >= maxCap then
				capLabel.TextColor3 = Color3.fromRGB(255, 50, 50) -- Rojo si está lleno
			else
				capLabel.TextColor3 = Color3.fromRGB(0, 255, 255) -- Cyan si hay espacio
			end
			capLabel.Text = "Capacidad: " .. currentCap .. " / " .. maxCap
		end)
	end
end)

startBtn.MouseButton1Click:Connect(function()
	if autoActivo then return end 
	
	if not mascotaBaseObj or not mascotaBaseObj.Parent then
		baseLabel.Text = "¡ERROR: ELIGE UNA MASCOTA!"
		baseLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		task.wait(2)
		baseLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		if not mascotaBaseObj then baseLabel.Text = "Base: (Ninguna)" end
		return
	end
	
	autoActivo = true
	startBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
	pauseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	statusLabel.Text = "⚡ Activo (Auto Cloner & Evolve)"

	if circleInner and player.Character and player.Character.PrimaryPart then
		player.Character:PivotTo(circleInner.CFrame + Vector3.new(0, 3, 0))
	end
	
	task.spawn(function()
		while autoActivo do
			-- Búsqueda rápida de mascota base para clonar
			local baseExists = false
			local newObj = nil
			local petGroups, _ = getGroupedPets()
			
			for _, grp in ipairs(petGroups) do
				if grp.Clave == mascotaBaseClave then
					baseExists = true
					newObj = grp.Object
					break
				end
			end
			
			if not baseExists or not newObj then
				autoActivo = false
				statusLabel.Text = "❌ Te quedaste sin la mascota base."
				startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
				break
			end
			
			mascotaBaseObj = newObj
			
			-- 1. CLONAR SI HAY ESPACIO
			local maxCap = 100
			pcall(function() maxCap = maxPetCapacity.Value end)
			
			local currentCap = 0
			pcall(function() currentCap = globalFunctions.calculatePetCapacity(petsFolder) end)
			
			if currentCap < maxCap then
				if mascotaBaseObj and mascotaBaseObj.Parent then
					local clonePrice = 0
					local currentChi = 0
					
					pcall(function() 
						clonePrice = globalFunctions.calculatePetClonePrice(mascotaBaseObj)
						local chiObj = player:FindFirstChild("Chi")
						if chiObj then
							currentChi = chiObj.Value
						end
					end)
					
					if currentChi >= clonePrice then
						statusLabel.Text = "⚡ Clonando mascota base..."
						pcall(function() petCloneEvent:FireServer("clonePet", mascotaBaseObj) end)
					else
						autoActivo = false
						statusLabel.Text = "❌ Sin Chi suficiente para clonar. Detenido."
						startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
						break
					end
				else
					statusLabel.Text = "⚠️ Mascota base inválida, esperando refresco..."
				end
			else
				statusLabel.Text = "⏳ Inventario Lleno. Forzando fusión..."
			end
			
			-- Espera variable para evadir detección de macro (entre 0.15s y 0.25s)
			task.wait(math.random(150, 250) / 1000)
			
			local currentGroups, _ = getGroupedPets()
			for _, grp in ipairs(currentGroups) do
				local nextEvo = nil
				local reqCount = 999999
				
				pcall(function()
					nextEvo = globalFunctions.findPetNextEvolution(grp.Object)
					if nextEvo then
						local orders = ReplicatedStorage:FindFirstChild("evolutionOrders")
						if orders and orders:FindFirstChild(nextEvo.Name) then
							local petCountVal = orders[nextEvo.Name]:FindFirstChild("petCount")
							if petCountVal then
								reqCount = petCountVal.Value
							end
						end
					end
				end)
				
				if nextEvo then
					-- REGLA DE ORO: Si es la mascota que estamos clonando, EXIGIMOS que sobre 1.
					-- Si es cualquier otra mascota generada en el proceso, NO dejamos sobrante.
					local isBase = (grp.Clave == mascotaBaseClave)
					local targetCount = isBase and (reqCount + 1) or reqCount
					
					if grp.Count >= targetCount then
						pcall(function()
							local petNextEvolutionEvent = rEvents:FindFirstChild("petNextEvolutionEvent")
							if petNextEvolutionEvent then
								petNextEvolutionEvent:FireServer("evolvePet", grp.Object, nextEvo)
							end
						end)
					end
				end
			end
			
			-- Refrescar la UI silenciosamente a veces (solo visual)
			if math.random(1, 10) == 1 then
				cargarMascotas()
			end
			
			-- Espera variable al final del ciclo (entre 0.2s y 0.3s)
			task.wait(math.random(200, 300) / 1000)
		end
	end)
end)

pauseBtn.MouseButton1Click:Connect(function()
	if autoActivo then
		autoActivo = false
		statusLabel.Text = "⏸ Sistema en pausa."
		startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	end
end)