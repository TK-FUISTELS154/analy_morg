--[[
	========================================================================
	SELECTIVE API-DRIVEN GAME DUMPER (VIRTUAL SCROLLING - DEX STYLE)
	========================================================================
--]]

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local randomSeed = math.random(100000, 999999)
local SPOOFED_GUI_NAME = "SelectiveDumper_" .. tostring(randomSeed)

local function getSecureGuiParent()
	local parentContainer = nil
	if typeof(gethui) == "function" then pcall(function() parentContainer = gethui() end) end
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
screenGui.Parent = secureParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 800, 0, 500)
mainFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
title.Text = " 📂 SELECTIVE DUMPER (VIRTUAL SCROLLING)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -70, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

local maximizeBtn = Instance.new("TextButton")
maximizeBtn.Size = UDim2.new(0, 50, 0, 50)
maximizeBtn.Position = UDim2.new(0.5, -25, 0, 10) -- Top center
maximizeBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
maximizeBtn.Text = "🔍"
maximizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
maximizeBtn.Font = Enum.Font.GothamBold
maximizeBtn.TextSize = 20
maximizeBtn.Visible = false
maximizeBtn.Active = true
maximizeBtn.Draggable = true
maximizeBtn.Parent = screenGui
Instance.new("UICorner", maximizeBtn).CornerRadius = UDim.new(1, 0) -- Circle

minimizeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	maximizeBtn.Visible = true
end)

maximizeBtn.MouseButton1Click:Connect(function()
	maximizeBtn.Visible = false
	mainFrame.Visible = true
end)

local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.4, -20, 1, -60)
leftPanel.Position = UDim2.new(0, 10, 0, 50)
leftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
leftPanel.Parent = mainFrame
Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 6)

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.6, -20, 1, -60)
rightPanel.Position = UDim2.new(0.4, 10, 0, 50)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = mainFrame

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -40, 0, 30)
searchBox.Position = UDim2.new(0, 5, 0, 5)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
searchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
searchBox.PlaceholderText = "🔎 Buscar... (Nombre/Clase)"
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.ClearTextOnFocus = false
searchBox.Parent = leftPanel
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

local searchBtn = Instance.new("TextButton")
searchBtn.Size = UDim2.new(0, 30, 0, 30)
searchBtn.Position = UDim2.new(1, -35, 0, 5)
searchBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
searchBtn.Text = "🔍"
searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBtn.Font = Enum.Font.Gotham
searchBtn.TextSize = 14
searchBtn.Parent = leftPanel
Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 6)

local treeScroll = Instance.new("ScrollingFrame")
treeScroll.Size = UDim2.new(1, -10, 1, -45)
treeScroll.Position = UDim2.new(0, 5, 0, 40)
treeScroll.BackgroundTransparency = 1
treeScroll.ScrollBarThickness = 6
treeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
treeScroll.Parent = leftPanel

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0.65, -5, 0, 40)
startBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
startBtn.Text = "▶ INICIAR ESCANEO"
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 12
startBtn.Parent = rightPanel
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(0.35, -5, 0, 40)
resetBtn.Position = UDim2.new(0.65, 5, 0, 0)
resetBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
resetBtn.Text = "🔄 NUEVO"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 12
resetBtn.Visible = false
resetBtn.Parent = rightPanel
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

local progressContainer = Instance.new("Frame")
progressContainer.Size = UDim2.new(1, 0, 0, 30)
progressContainer.Position = UDim2.new(0, 0, 0, 50)
progressContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
progressContainer.Parent = rightPanel
Instance.new("UICorner", progressContainer).CornerRadius = UDim.new(0, 6)

local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
progressBar.Parent = progressContainer
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 6)

local progressText = Instance.new("TextLabel")
progressText.Size = UDim2.new(1, 0, 1, 0)
progressText.BackgroundTransparency = 1
progressText.Text = "Esperando selección..."
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.Font = Enum.Font.GothamBold
progressText.TextSize = 12
progressText.Parent = progressContainer

local selectionPathLabel = Instance.new("TextLabel")
selectionPathLabel.Size = UDim2.new(1, 0, 0, 20)
selectionPathLabel.Position = UDim2.new(0, 0, 0, 90)
selectionPathLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
selectionPathLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
selectionPathLabel.Text = " Selecciona un objeto para ver su ruta completa..."
selectionPathLabel.TextXAlignment = Enum.TextXAlignment.Left
selectionPathLabel.Font = Enum.Font.GothamBold
selectionPathLabel.TextSize = 11
selectionPathLabel.Parent = rightPanel
Instance.new("UICorner", selectionPathLabel).CornerRadius = UDim.new(0, 6)

local previewBox = Instance.new("TextBox")
previewBox.Size = UDim2.new(1, 0, 1, -115)
previewBox.Position = UDim2.new(0, 0, 0, 115)
previewBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
previewBox.TextColor3 = Color3.fromRGB(200, 200, 200)
previewBox.Text = "Selecciona objetos en el árbol y presiona Iniciar.\nUsando Virtual Scrolling como Dex."
previewBox.TextXAlignment = Enum.TextXAlignment.Left
previewBox.TextYAlignment = Enum.TextYAlignment.Top
previewBox.Font = Enum.Font.Code
previewBox.TextSize = 11
previewBox.ClearTextOnFocus = false
previewBox.MultiLine = true
previewBox.TextEditable = false
previewBox.Parent = rightPanel
Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 6)

-- VIRTUAL SCROLLING LOGIC
local ROW_HEIGHT = 22
local INDENT_SIZE = 15
local VISIBLE_ROWS = 30 -- Número de frames físicos reciclables

local flatTree = {}
local selectedNodes = {}
local expandedNodes = {}
local uiRows = {}
local rootNodes = {}

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
			frame.CheckBtn.Position = UDim2.new(0, xOffset + 20, 0, 3)
			
			frame.NameLabel.Position = UDim2.new(0, xOffset + 40, 0, 0)
			frame.NameLabel.Size = UDim2.new(1, -(xOffset + 40), 1, 0)
			
			if isSearching then
				frame.NameLabel.Text = data.obj:GetFullName()
			else
				frame.NameLabel.Text = data.obj.Name
			end
			
			frame.ExpandBtn.Text = data.hasChildren and (data.isExpanded and "-" or "+") or ""
			frame.CheckBtn.Text = selectedNodes[data.obj] and "X" or ""
			
			frame.NodeObj = data.obj
		else
			frame.Frame.Visible = false
		end
	end
end

local isSearching = false
local searchResults = {}
local searchId = 0

local function rebuildFlatTree()
	table.clear(flatTree)
	
	if isSearching then
		for _, obj in ipairs(searchResults) do
			table.insert(flatTree, {
				obj = obj,
				depth = 0,
				hasChildren = false,
				isExpanded = false
			})
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
	
	treeScroll.CanvasSize = UDim2.new(0, 2000, 0, #flatTree * ROW_HEIGHT)
	treeScroll.CanvasPosition = Vector2.new(0, 0)
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

		local s, descendants = pcall(function() return game:GetDescendants() end)
		if s and descendants then
			for _, child in ipairs(descendants) do
				if searchId ~= currentSearchId then return end
				processed = processed + 1
				if processed % 5000 == 0 then task.wait() end
				checkNode(child)
			end
		else
			local function searchObj(obj)
				local sChild, c = pcall(function() return obj:GetChildren() end)
				if sChild and c then
					for _, child in ipairs(c) do
						if searchId ~= currentSearchId then return end
						processed = processed + 1
						if processed % 1000 == 0 then task.wait() end
						checkNode(child)
						searchObj(child)
					end
				end
			end
			for _, root in ipairs(rootNodes) do
				if searchId ~= currentSearchId then return end
				checkNode(root)
				searchObj(root)
			end
		end
		
		if searchId == currentSearchId then
			searchBtn.Text = "🔍"
			rebuildFlatTree()
		end
	end)
end

searchBtn.MouseButton1Click:Connect(function()
	performSearch(searchBox.Text)
end)

searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		performSearch(searchBox.Text)
	end
end)

-- Create the UI frame pool
for i = 1, VISIBLE_ROWS do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Visible = false
	
	local expandBtn = Instance.new("TextButton")
	expandBtn.Size = UDim2.new(0, 16, 0, 16)
	expandBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	expandBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	expandBtn.Font = Enum.Font.Code
	expandBtn.TextSize = 14
	expandBtn.Parent = row
	
	local checkBtn = Instance.new("TextButton")
	checkBtn.Size = UDim2.new(0, 16, 0, 16)
	checkBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	checkBtn.TextColor3 = Color3.fromRGB(0, 200, 0)
	checkBtn.Font = Enum.Font.GothamBold
	checkBtn.TextSize = 12
	checkBtn.Parent = row
	
	local nameLabel = Instance.new("TextButton")
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Parent = row
	
	local frameData = {
		Frame = row,
		ExpandBtn = expandBtn,
		CheckBtn = checkBtn,
		NameLabel = nameLabel,
		NodeObj = nil
	}
	
	expandBtn.MouseButton1Click:Connect(function()
		local obj = frameData.NodeObj
		if obj and hasChildrenSafe(obj) then
			expandedNodes[obj] = not expandedNodes[obj]
			rebuildFlatTree()
		end
	end)
	
	nameLabel.MouseButton1Click:Connect(function()
		local obj = frameData.NodeObj
		if obj then
			selectionPathLabel.Text = " " .. obj:GetFullName()
		end
	end)
	
	checkBtn.MouseButton1Click:Connect(function()
		local obj = frameData.NodeObj
		if obj then
			if selectedNodes[obj] then
				selectedNodes[obj] = nil
			else
				selectedNodes[obj] = true
			end
			updateVisibleTree()
		end
	end)
	
	row.Parent = treeScroll
	table.insert(uiRows, frameData)
end

treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleTree)

-- Init Tree Data
local success, children = pcall(function() return game:GetChildren() end)
if success and children then
	rootNodes = children
else
	local commonServices = {"Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "CoreGui", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Chat", "LocalizationService", "TestService"}
	for _, sName in ipairs(commonServices) do
		pcall(function()
			local srv = game:GetService(sName)
			if srv then table.insert(rootNodes, srv) end
		end)
	end
end

rebuildFlatTree()

-- DUMPER LOGIC
local function formatLuaValue(val)
	local t = typeof(val)
	if t == "string" then return string.format("%q", val)
	elseif t == "number" or t == "boolean" then return tostring(val)
	elseif t == "Vector3" then return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
	elseif t == "Color3" then return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
	elseif t == "UDim2" then return string.format("UDim2.new(%.3f, %d, %.3f, %d)", val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset)
	else return string.format("%q", tostring(val)) end
end

local function decompileScriptSource(scriptObj)
	local source = nil
	if typeof(decompile) == "function" then pcall(function() source = decompile(scriptObj) end) end
	if not source and typeof(getscriptbytecode) == "function" then source = "-- Bytecode extraído" end
	return source or "-- [No se pudo decompilar]"
end

local isDumping = false

startBtn.MouseButton1Click:Connect(function()
	if isDumping then return end
	
	local hasSelection = false
	for obj, isSelected in pairs(selectedNodes) do
		if isSelected then hasSelection = true break end
	end
	
	if not hasSelection then
		previewBox.Text = "¡Error! No has seleccionado ningún objeto en el árbol."
		return
	end
	
	isDumping = true
	startBtn.Text = "⏳ ESCANEANDO..."
	startBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	
	task.spawn(function()
		progressText.Text = "Descargando API Dump..."
		local success, version = pcall(function() return game:HttpGet("http://setup.roblox.com/versionQTStudio") end)
		version = (success and version) and version:gsub("%s+", "") or "version-0b83e4a36f6d45e4"
		
		local apiSuccess, apiJson = pcall(function() return game:HttpGet("http://setup.roblox.com/" .. version .. "-API-Dump.json") end)
		if not apiSuccess then
			progressText.Text = "Error descargando API Dump."
			isDumping = false
			return
		end
		
		local apiData = HttpService:JSONDecode(apiJson)
		local classes = {}
		for _, classData in ipairs(apiData.Classes) do
			local props = {}
			for _, member in ipairs(classData.Members) do
				if member.MemberType == "Property" and (member.Security and member.Security.Read == "None") then
					local tags = member.Tags or {}
					if not table.find(tags, "Hidden") and not table.find(tags, "NotScriptable") then
						table.insert(props, member.Name)
					end
				end
			end
			classes[classData.Name] = { Superclass = classData.Superclass, Properties = props }
		end
		
		local resolvedClasses = {}
		for className, _ in pairs(classes) do
			local props = {}
			local current = classes[className]
			while current do
				for _, prop in ipairs(current.Properties) do table.insert(props, prop) end
				if current.Superclass == "<<<ROOT>>>" then break end
				current = classes[current.Superclass]
			end
			resolvedClasses[className] = props
		end
		
		progressText.Text = "Preparando archivo en disco..."
		local fileName = "SelectiveDump_" .. os.time() .. ".txt"
		local canAppend = typeof(appendfile) == "function"
		
		if canAppend and typeof(writefile) == "function" then
			writefile(fileName, "-- [[ SELECTIVE API-DRIVEN ROBLOX DUMP ]] --\n")
		end
		
		local function serializeInstance(inst, depth)
			local className = inst.ClassName
			local indent = string.rep("  ", depth)
			local lines = {indent .. "-> [" .. className .. "] " .. inst.Name}
			local props = resolvedClasses[className]
			
			if props then
				for _, propName in ipairs(props) do
					if propName ~= "Parent" and propName ~= "Name" then
						local ok, val = pcall(function() return inst[propName] end)
						if ok and val ~= nil then
							table.insert(lines, indent .. "    ." .. propName .. " = " .. formatLuaValue(val))
						end
					end
				end
			end
			
			if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				table.insert(lines, indent .. "    [CÓDIGO FUENTE]:")
				table.insert(lines, decompileScriptSource(inst))
			end
			return table.concat(lines, "\n") .. "\n"
		end

		progressText.Text = "Iniciando escaneo..."
		
		local queue = {}
		local allDataBuffer = {}
		
		local function addNodeToQueue(node, depth)
			table.insert(queue, {node = node, depth = depth})
			local s, c = pcall(function() return node:GetChildren() end)
			if s and c then
				for _, child in ipairs(c) do
					addNodeToQueue(child, depth + 1)
				end
			end
		end
		
		for obj, isSelected in pairs(selectedNodes) do
			if isSelected then
				addNodeToQueue(obj, 0)
			end
		end
		
		local totalProcessed = 0
		local activeWorkers = 0
		local MAX_WORKERS = 8 
		local chunkBuffer = {}
		local chunkCounter = 0
		local isWriting = false
		local totalToProcess = #queue
		
		local function processQueue()
			while #queue > 0 do
				local item = table.remove(queue, 1)
				local node = item.node
				local depth = item.depth
				
				pcall(function()
					local serializedData = serializeInstance(node, depth)
					totalProcessed = totalProcessed + 1
					
					if canAppend then
						while isWriting do task.wait() end
						chunkCounter = chunkCounter + 1
						chunkBuffer[chunkCounter] = serializedData
						
						if chunkCounter >= 200 then
							isWriting = true
							appendfile(fileName, table.concat(chunkBuffer, ""))
							table.clear(chunkBuffer)
							chunkCounter = 0
							isWriting = false
							
							progressBar.Size = UDim2.new(math.clamp(totalProcessed / totalToProcess, 0, 1), 0, 1, 0)
							progressText.Text = string.format("Escaneados: %d / %d", totalProcessed, totalToProcess)
							previewBox.Text = "Procesando..."
						end
					else
						table.insert(allDataBuffer, serializedData)
						if totalProcessed % 500 == 0 then
							progressBar.Size = UDim2.new(math.clamp(totalProcessed / totalToProcess, 0, 1), 0, 1, 0)
							progressText.Text = string.format("Escaneados (Memoria): %d / %d", totalProcessed, totalToProcess)
						end
					end
				end)
				
				if totalProcessed % 50 == 0 then
					task.wait()
				end
			end
			activeWorkers = activeWorkers - 1
		end
		
		for i = 1, MAX_WORKERS do
			activeWorkers = activeWorkers + 1
			task.spawn(processQueue)
		end
		
		while activeWorkers > 0 do
			task.wait(0.1)
		end
		
		if canAppend then
			if chunkCounter > 0 then
				appendfile(fileName, table.concat(chunkBuffer, ""))
			end
		else
			if typeof(writefile) == "function" then
				progressText.Text = "Escribiendo archivo completo..."
				writefile(fileName, "-- [[ SELECTIVE API-DRIVEN ROBLOX DUMP ]] --\n" .. table.concat(allDataBuffer, ""))
			end
		end
		
		progressBar.Size = UDim2.new(1, 0, 1, 0)
		progressText.Text = "¡Completado!"
		previewBox.Text = "¡Escaneo selectivo exportado!\nGuardado como: " .. fileName
		
		startBtn.Text = "📋 EXPORTACIÓN LISTA"
		startBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		
		if typeof(setclipboard) == "function" and typeof(readfile) == "function" then
			pcall(function() setclipboard(readfile(fileName)) end)
			startBtn.Text = "✅ COPIADO AL PORTAPAPELES"
		end
		
		isDumping = false
		resetBtn.Visible = true
	end)
end)

-- TOGGLE GUI SHORTCUT (CTRL + D)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.D then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			mainFrame.Visible = not mainFrame.Visible
		end
	end
end)

resetBtn.MouseButton1Click:Connect(function()
	if isDumping then return end
	
	table.clear(selectedNodes)
	table.clear(expandedNodes)
	isSearching = false
	searchBox.Text = ""
	searchBtn.Text = "🔍"
	rebuildFlatTree()
	
	isDumping = false
	startBtn.Text = "▶ INICIAR ESCANEO"
	startBtn.BackgroundColor3 = Color3.fromRGB(46, 125, 50)
	resetBtn.Visible = false
	
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressText.Text = "Esperando selección..."
	previewBox.Text = "Selección borrada.\nPuedes iniciar un nuevo escaneo."
	selectionPathLabel.Text = " Selecciona un objeto para ver su ruta completa..."
end)

-- RESIZE HANDLE LOGIC
local resizeHandle = Instance.new("TextButton")
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
resizeHandle.Text = "↘"
resizeHandle.TextColor3 = Color3.fromRGB(30, 30, 35)
resizeHandle.Font = Enum.Font.GothamBold
resizeHandle.Parent = mainFrame
Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 6)

local isResizing = false
local dragStart, startSize

resizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isResizing = true
		dragStart = input.Position
		startSize = mainFrame.Size
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		mainFrame.Size = UDim2.new(
			0, math.max(600, startSize.X.Offset + delta.X),
			0, math.max(300, startSize.Y.Offset + delta.Y)
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isResizing = false
	end
end)
