--[[
	========================================================================
	INTELLIGENT DUMPER & REVERSE-ENGINEERING AUDITOR (STEALTH ENGINE)
	========================================================================
--]]

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local randomSeed = math.random(1000000, 9999999)
local SPOOFED_GUI_NAME = "SystemCacheContext_" .. tostring(randomSeed)

----------------------------------------------------------------------
-- ENTORNO SEGURO Y PROTEGIDO (ANTI-DETECCIÓN)
----------------------------------------------------------------------
local function getSecureGuiParent()
	local parentContainer = nil
	if typeof(gethui) == "function" then 
		pcall(function() parentContainer = gethui() end) 
	end
	if not parentContainer and typeof(cloneref) == "function" and CoreGui then
		pcall(function() parentContainer = cloneref(CoreGui) end)
	end
	if not parentContainer then
		parentContainer = LocalPlayer:WaitForChild("PlayerGui")
	end
	return parentContainer
end

local secureParent = getSecureGuiParent()
local oldGui = secureParent:FindFirstChild(SPOOFED_GUI_NAME)
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = SPOOFED_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999
screenGui.Parent = secureParent

----------------------------------------------------------------------
-- INTERFAZ PRINCIPAL
----------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 840, 0, 540)
mainFrame.Position = UDim2.new(0.5, -420, 0.5, -270)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
title.Text = "  🛡️ INTELLIGENT SCANNER & AUDITOR PRO"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -68, 0, 7)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

local floatWidget = Instance.new("TextButton")
floatWidget.Size = UDim2.new(0, 48, 0, 48)
floatWidget.Position = UDim2.new(0.02, 0, 0.45, 0)
floatWidget.BackgroundColor3 = Color3.fromRGB(40, 130, 85)
floatWidget.Text = "🛡️"
floatWidget.TextSize = 22
floatWidget.Visible = false
floatWidget.Active = true
floatWidget.Draggable = true
floatWidget.Parent = screenGui
Instance.new("UICorner", floatWidget).CornerRadius = UDim.new(1, 0)

minimizeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	floatWidget.Visible = true
end)
floatWidget.MouseButton1Click:Connect(function()
	floatWidget.Visible = false
	mainFrame.Visible = true
end)

-- Barra de Modos de Escaneo
local modeBar = Instance.new("Frame")
modeBar.Size = UDim2.new(1, -20, 0, 32)
modeBar.Position = UDim2.new(0, 10, 0, 48)
modeBar.BackgroundTransparency = 1
modeBar.Parent = mainFrame

local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.42, -15, 1, -95)
leftPanel.Position = UDim2.new(0, 10, 0, 85)
leftPanel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
leftPanel.Parent = mainFrame
Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 6)

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.58, -15, 1, -95)
rightPanel.Position = UDim2.new(0.42, 5, 0, 85)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = mainFrame

----------------------------------------------------------------------
-- CONTROLES DEL PANEL DERECHO
----------------------------------------------------------------------
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.68, -5, 0, 36)
startBtn.BackgroundColor3 = Color3.fromRGB(35, 130, 75)
startBtn.Text = "▶ EJECUTAR ESCANEO"
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 12
startBtn.Parent = rightPanel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0.32, 0, 0, 36)
copyBtn.Position = UDim2.new(0.68, 5, 0, 0)
copyBtn.BackgroundColor3 = Color3.fromRGB(45, 75, 140)
copyBtn.Text = "📋 COPIAR"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 12
copyBtn.Parent = rightPanel
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)

local progressContainer = Instance.new("Frame")
progressContainer.Size = UDim2.new(1, 0, 0, 24)
progressContainer.Position = UDim2.new(0, 0, 0, 42)
progressContainer.BackgroundColor3 = Color3.fromRGB(32, 35, 45)
progressContainer.Parent = rightPanel
Instance.new("UICorner", progressContainer).CornerRadius = UDim.new(0, 6)

local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(0, 190, 230)
progressBar.Parent = progressContainer
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 6)

local progressText = Instance.new("TextLabel")
progressText.Size = UDim2.new(1, 0, 1, 0)
progressText.BackgroundTransparency = 1
progressText.Text = "Sistema listo para auditar."
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.Font = Enum.Font.GothamBold
progressText.TextSize = 11
progressText.Parent = progressContainer

local previewBox = Instance.new("TextBox")
previewBox.Size = UDim2.new(1, 0, 1, -74)
previewBox.Position = UDim2.new(0, 0, 0, 74)
previewBox.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
previewBox.TextColor3 = Color3.fromRGB(210, 215, 225)
previewBox.Text = "Selecciona un modo de escaneo arriba y presiona EJECUTAR."
previewBox.TextXAlignment = Enum.TextXAlignment.Left
previewBox.TextYAlignment = Enum.TextYAlignment.Top
previewBox.Font = Enum.Font.Code
previewBox.TextSize = 11
previewBox.ClearTextOnFocus = false
previewBox.MultiLine = true
previewBox.TextEditable = false
previewBox.Parent = rightPanel
Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 6)

----------------------------------------------------------------------
-- BUSCADOR Y ÁRBOL VIRTUAL DEL PANEL IZQUIERDO
----------------------------------------------------------------------
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -36, 0, 28)
searchBox.Position = UDim2.new(0, 5, 0, 5)
searchBox.BackgroundColor3 = Color3.fromRGB(26, 28, 35)
searchBox.TextColor3 = Color3.fromRGB(230, 230, 235)
searchBox.PlaceholderText = "Filtrar por nombre o clase..."
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.ClearTextOnFocus = false
searchBox.Parent = leftPanel
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

local searchBtn = Instance.new("TextButton")
searchBtn.Size = UDim2.new(0, 28, 0, 28)
searchBtn.Position = UDim2.new(1, -32, 0, 5)
searchBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 110)
searchBtn.Text = "🔍"
searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBtn.Font = Enum.Font.Gotham
searchBtn.TextSize = 13
searchBtn.Parent = leftPanel
Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 6)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Size = UDim2.new(1, -10, 1, -40)
treeScroll.Position = UDim2.new(0, 5, 0, 36)
treeScroll.BackgroundTransparency = 1
treeScroll.ScrollBarThickness = 5
treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
treeScroll.Parent = leftPanel

local ROW_HEIGHT = 22
local INDENT_SIZE = 14
local VISIBLE_ROWS = 28

local flatTree = {}
local selectedNodes = {}
local expandedNodes = {}
local uiRows = {}
local rootNodes = {}
local isSearching = false
local searchResults = {}
local searchId = 0

local function hasChildrenSafe(obj)
	local s, c = pcall(function() return obj:GetChildren() end)
	return (s and c and #c > 0)
end

local function getChildrenSafe(obj)
	local s, c = pcall(function() return obj:GetChildren() end)
	return (s and c and c) or {}
end

local function updateVisibleTree()
	local canvasY = treeScroll.CanvasPosition.Y
	local startIndex = math.max(1, math.floor(canvasY / ROW_HEIGHT) + 1)
	
	for i = 1, VISIBLE_ROWS do
		local rowDataIndex = startIndex + i - 1
		local data = flatTree[rowDataIndex]
		local frame = uiRows[i]
		
		if data then
			frame.Frame.Visible = true
			frame.Frame.Position = UDim2.new(0, 0, 0, (rowDataIndex - 1) * ROW_HEIGHT)
			
			local xOffset = data.depth * INDENT_SIZE
			frame.ExpandBtn.Position = UDim2.new(0, xOffset, 0, 3)
			frame.CheckBtn.Position = UDim2.new(0, xOffset + 18, 0, 3)
			
			frame.NameLabel.Position = UDim2.new(0, xOffset + 38, 0, 0)
			frame.NameLabel.Size = UDim2.new(1, -(xOffset + 38), 1, 0)
			frame.NameLabel.Text = isSearching and data.obj:GetFullName() or data.obj.Name
			
			frame.ExpandBtn.Text = data.hasChildren and (data.isExpanded and "-" or "+") or ""
			frame.CheckBtn.Text = selectedNodes[data.obj] and "✓" or ""
			frame.NodeObj = data.obj
		else
			frame.Frame.Visible = false
		end
	end
end

local function rebuildFlatTree()
	table.clear(flatTree)
	if isSearching then
		for _, obj in ipairs(searchResults) do
			table.insert(flatTree, { obj = obj, depth = 0, hasChildren = false, isExpanded = false })
		end
	else
		local function traverse(nodeList, depth)
			for _, obj in ipairs(nodeList) do
				if obj.Name ~= "CorePackages" and obj.Name ~= "Terrain" then
					local isExpanded = expandedNodes[obj] or false
					local hasChild = hasChildrenSafe(obj)
					table.insert(flatTree, {
						obj = obj,
						depth = depth,
						hasChildren = hasChild,
						isExpanded = isExpanded
					})
					if isExpanded and hasChild then
						traverse(getChildrenSafe(obj), depth + 1)
					end
				end
			end
		end
		traverse(rootNodes, 0)
	end
	
	treeScroll.CanvasSize = UDim2.new(0, 1600, 0, #flatTree * ROW_HEIGHT)
	task.defer(updateVisibleTree)
end

local function performSearch(query)
	query = query:lower()
	searchId = searchId + 1
	local currentSearchId = searchId
	table.clear(searchResults)
	
	if query == "" then
		isSearching = false
		searchBtn.Text = "🔍"
		rebuildFlatTree()
		return
	end
	
	isSearching = true
	searchBtn.Text = "..."
	
	task.spawn(function()
		local processed = 0
		local function checkNode(node)
			local sName, name = pcall(function() return node.Name:lower() end)
			local sClass, className = pcall(function() return node.ClassName:lower() end)
			if sName and sClass then
				if string.find(name, query, 1, true) or string.find(className, query, 1, true) then
					table.insert(searchResults, node)
				end
			end
		end

		for _, root in ipairs(rootNodes) do
			if searchId ~= currentSearchId then return end
			checkNode(root)
			local s, descendants = pcall(function() return root:GetDescendants() end)
			if s and descendants then
				for _, child in ipairs(descendants) do
					if searchId ~= currentSearchId then return end
					processed = processed + 1
					if processed % 3000 == 0 then task.wait() end
					checkNode(child)
				end
			end
		end
		
		if searchId == currentSearchId then
			searchBtn.Text = "🔍"
			rebuildFlatTree()
		end
	end)
end

searchBtn.MouseButton1Click:Connect(function() performSearch(searchBox.Text) end)
searchBox.FocusLost:Connect(function(enter) if enter then performSearch(searchBox.Text) end end)

for i = 1, VISIBLE_ROWS do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Visible = false
	
	local expandBtn = Instance.new("TextButton")
	expandBtn.Size = UDim2.new(0, 16, 0, 16)
	expandBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
	expandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	expandBtn.Font = Enum.Font.Code
	expandBtn.TextSize = 13
	expandBtn.Parent = row
	
	local checkBtn = Instance.new("TextButton")
	checkBtn.Size = UDim2.new(0, 16, 0, 16)
	checkBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
	checkBtn.TextColor3 = Color3.fromRGB(0, 230, 150)
	checkBtn.Font = Enum.Font.GothamBold
	checkBtn.TextSize = 11
	checkBtn.Parent = row
	
	local nameLabel = Instance.new("TextButton")
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Parent = row
	
	local frameData = { Frame = row, ExpandBtn = expandBtn, CheckBtn = checkBtn, NameLabel = nameLabel, NodeObj = nil }
	
	expandBtn.MouseButton1Click:Connect(function()
		local obj = frameData.NodeObj
		if obj and hasChildrenSafe(obj) then
			expandedNodes[obj] = not expandedNodes[obj]
			rebuildFlatTree()
		end
	end)
	
	checkBtn.MouseButton1Click:Connect(function()
		local obj = frameData.NodeObj
		if obj then
			selectedNodes[obj] = not selectedNodes[obj] or nil
			updateVisibleTree()
		end
	end)
	
	row.Parent = treeScroll
	table.insert(uiRows, frameData)
end

treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleTree)

local commonServices = {"Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "RobloxReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer"}
for _, sName in ipairs(commonServices) do
	pcall(function()
		local srv = game:GetService(sName)
		if srv then table.insert(rootNodes, srv) end
	end)
end
rebuildFlatTree()

----------------------------------------------------------------------
-- MOTOR DE DECOMPILACIÓN Y EXTRACCIÓN
----------------------------------------------------------------------
local function safeDecompile(scriptObj)
	local src = nil
	if typeof(decompile) == "function" then
		pcall(function() src = decompile(scriptObj) end)
	end
	if not src and typeof(getscriptbytecode) == "function" then
		src = "-- [Bytecode extraído]"
	end
	return src or "-- [No se pudo decompilar el script]"
end

local function formatLuaValue(val)
	local t = typeof(val)
	if t == "string" then return string.format("%q", val)
	elseif t == "number" or t == "boolean" then return tostring(val)
	elseif t == "Vector3" then return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
	elseif t == "Color3" then return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
	elseif t == "UDim2" then return string.format("UDim2.new(%.3f, %d, %.3f, %d)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
	else return string.format("%q", tostring(val)) end
end

local lastDumpOutput = ""
local isProcessing = false

----------------------------------------------------------------------
-- MODOS DE ESCANEO INTELIGENTE
----------------------------------------------------------------------
local CurrentMode = "AntiCheat" -- "AntiCheat", "Economy", "Remotes", "Manual"

local function selectMode(modeName)
	CurrentMode = modeName
	for _, btn in ipairs(modeBar:GetChildren()) do
		if btn:IsA("TextButton") then
			if btn.Name == modeName then
				btn.BackgroundColor3 = Color3.fromRGB(45, 90, 160)
			else
				btn.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
			end
		end
	end
	previewBox.Text = "Modo seleccionado: " .. modeName .. "\nPresiona 'EJECUTAR ESCANEO' para comenzar el análisis automático."
end

local function createModeTab(name, label, posX)
	local tab = Instance.new("TextButton")
	tab.Name = name
	tab.Size = UDim2.new(0.24, -4, 1, 0)
	tab.Position = UDim2.new(posX, 0, 0, 0)
	tab.BackgroundColor3 = (name == CurrentMode) and Color3.fromRGB(45, 90, 160) or Color3.fromRGB(30, 33, 42)
	tab.Text = label
	tab.TextColor3 = Color3.fromRGB(240, 240, 245)
	tab.Font = Enum.Font.GothamBold
	tab.TextSize = 11
	tab.Parent = modeBar
	Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 6)
	tab.MouseButton1Click:Connect(function() selectMode(name) end)
end

createModeTab("AntiCheat", "🛡️ Anti-Cheat & Kicks", 0)
createModeTab("Economy", "🎰 Lógica & Ruleta", 0.25)
createModeTab("Remotes", "📡 Todos los Remotes", 0.50)
createModeTab("Manual", "🌲 Árbol Manual", 0.75)

local function runAntiCheatAudit()
	local report = {"-- [[ AUDITORÍA AUTOMÁTICA DE SEGURIDAD & ANTI-CHEAT ]] --\n"}
	table.insert(report, "-- Objetivo: Identificar Watchdogs, Integrity Checks y Causas de Kick\n")
	
	local suspiciousTargets = {}
	local keywords = {"integrity", "check", "anticheat", "security", "protect", "detection", "kick", "ban", "heartbeat", "analytic"}
	
	local locations = {
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
		game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts"),
		game:GetService("RobloxReplicatedStorage"),
		game:GetService("ReplicatedStorage")
	}
	
	for _, loc in ipairs(locations) do
		if loc then
			local s, descendants = pcall(function() return loc:GetDescendants() end)
			if s and descendants then
				for _, inst in ipairs(descendants) do
					local lowerName = inst.Name:lower()
					local lowerClass = inst.ClassName:lower()
					
					for _, kw in ipairs(keywords) do
						if string.find(lowerName, kw) or string.find(lowerClass, kw) then
							table.insert(suspiciousTargets, inst)
							break
						end
					end
				end
			end
		end
	end
	
	table.insert(report, string.format("-- Instancias Sospechosas Encontradas: %d\n", #suspiciousTargets))
	
	for idx, inst in ipairs(suspiciousTargets) do
		table.insert(report, string.format("-> [%s] %s (Ruta: %s)", inst.ClassName, inst.Name, inst:GetFullName()))
		if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			table.insert(report, "    [CÓDIGO EXTRAÍDO]:")
			table.insert(report, safeDecompile(inst))
		end
		table.insert(report, "")
	end
	
	return table.concat(report, "\n")
end

local function runEconomyAudit()
	local report = {"-- [[ ANÁLISIS DE RULETA, PROBABILIDADES Y ECONOMÍA ]] --\n"}
	local keywords = {"spin", "wheel", "roll", "luck", "chance", "mutation", "fuse", "trait", "shop", "item", "purchase"}
	local targets = {}
	
	local checkContainers = {
		game:GetService("ReplicatedStorage"),
		LocalPlayer:FindFirstChild("PlayerGui")
	}
	
	for _, cont in ipairs(checkContainers) do
		if cont then
			local s, desc = pcall(function() return cont:GetDescendants() end)
			if s and desc then
				for _, inst in ipairs(desc) do
					local lower = inst.Name:lower()
					for _, kw in ipairs(keywords) do
						if string.find(lower, kw) then
							table.insert(targets, inst)
							break
						end
					end
				end
			end
		end
	end
	
	table.insert(report, string.format("-- Elementos de Azar y Economía Encontrados: %d\n", #targets))
	for _, inst in ipairs(targets) do
		table.insert(report, string.format("-> [%s] %s (Ruta: %s)", inst.ClassName, inst.Name, inst:GetFullName()))
		if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			table.insert(report, "    [CÓDIGO FUENTE]:")
			table.insert(report, safeDecompile(inst))
		end
		table.insert(report, "")
	end
	return table.concat(report, "\n")
end

local function runRemotesAudit()
	local report = {"-- [[ MAPEO COMPLETO DE EVENTOS Y FUNCIONES REMOTAS ]] --\n"}
	local remoteList = {}
	
	local s, desc = pcall(function() return game:GetDescendants() end)
	if s and desc then
		for _, inst in ipairs(desc) do
			if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
				table.insert(remoteList, inst)
			end
		end
	end
	
	table.insert(report, string.format("-- Total de Remotes Detectados: %d\n", #remoteList))
	for _, remote in ipairs(remoteList) do
		table.insert(report, string.format("-> [%s] %s | Ruta: %s", remote.ClassName, remote.Name, remote:GetFullName()))
	end
	return table.concat(report, "\n")
end

----------------------------------------------------------------------
-- EJECUCIÓN GENERAL DE ESCANEO Y EXPORTACIÓN
----------------------------------------------------------------------
startBtn.MouseButton1Click:Connect(function()
	if isProcessing then return end
	isProcessing = true
	startBtn.Text = "⏳ PROCESANDO..."
	progressBar.Size = UDim2.new(0.5, 0, 1, 0)
	progressText.Text = "Extrayendo y descompilando datos..."
	
	task.spawn(function()
		local output = ""
		
		if CurrentMode == "AntiCheat" then
			output = runAntiCheatAudit()
		elseif CurrentMode == "Economy" then
			output = runEconomyAudit()
		elseif CurrentMode == "Remotes" then
			output = runRemotesAudit()
		elseif CurrentMode == "Manual" then
			local queue = {}
			for obj, isSel in pairs(selectedNodes) do
				if isSel then
					table.insert(queue, obj)
					local s, d = pcall(function() return obj:GetDescendants() end)
					if s and d then
						for _, child in ipairs(d) do table.insert(queue, child) end
					end
				end
			end
			
			local manualReport = {"-- [[ VOLCADO SELECTIVO MANUAL ]] --\n"}
			for _, inst in ipairs(queue) do
				table.insert(manualReport, string.format("-> [%s] %s (Ruta: %s)", inst.ClassName, inst.Name, inst:GetFullName()))
				if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
					table.insert(manualReport, "    [CÓDIGO]:")
					table.insert(manualReport, safeDecompile(inst))
				end
			end
			output = table.concat(manualReport, "\n")
		end
		
		lastDumpOutput = output
		progressBar.Size = UDim2.new(1, 0, 1, 0)
		progressText.Text = "¡Completado con éxito!"
		previewBox.Text = string.sub(output, 1, 15000) .. "\n\n-- [Muestra truncada en pantalla. Usa COPIAR o exporta para ver todo]"
		
		local fileName = "AutoAudit_" .. CurrentMode .. "_" .. os.time() .. ".txt"
		if typeof(writefile) == "function" then
			pcall(function() writefile(fileName, output) end)
			progressText.Text = "Guardado en archivo: " .. fileName
		end
		
		startBtn.Text = "▶ EJECUTAR ESCANEO"
		isProcessing = false
	end)
end)

copyBtn.MouseButton1Click:Connect(function()
	if lastDumpOutput ~= "" and typeof(setclipboard) == "function" then
		pcall(function() setclipboard(lastDumpOutput) end)
		copyBtn.Text = "✅ COPIADO"
		task.delay(1.5, function() copyBtn.Text = "📋 COPIAR" end)
	end
end)

-- Atajo de teclado (CTRL + D) para mostrar / ocultar
UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.D then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			mainFrame.Visible = not mainFrame.Visible
			if not mainFrame.Visible then floatWidget.Visible = false end
		end
	end
end)