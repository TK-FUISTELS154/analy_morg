--[[
    =============================================================================
    APEX SUITE - VIRTUAL TREE DATA STRUCTURE
    =============================================================================
    Estructura jerárquica aplanada para soportar Virtual Scrolling con miles
    de instancias sin caídas de FPS en la interfaz.
--]]

local VirtualTree = {}
VirtualTree.__index = VirtualTree
VirtualTree.ClassName = "VirtualTree"

function VirtualTree.new()
    local self = setmetatable({}, VirtualTree)
    self.RootNodes = {}
    self.ExpandedNodes = {}
    self.SelectedNodes = {}
    self.FlatList = {}
    self.FilterText = ""
    return self
end

function VirtualTree:SetRoots(rootList)
    self.RootNodes = rootList or {}
    self:Rebuild()
end

function VirtualTree:ToggleExpand(node)
    self.ExpandedNodes[node] = not self.ExpandedNodes[node]
    self:Rebuild()
end

function VirtualTree:ToggleSelect(node)
    self.SelectedNodes[node] = not self.SelectedNodes[node] or nil
end

function VirtualTree:SetFilter(text)
    self.FilterText = (text or ""):lower()
    self:Rebuild()
end

local function getChildrenSafe(instance)
    local success, children = pcall(function() return instance:GetChildren() end)
    return (success and children) or {}
end

function VirtualTree:Rebuild()
    self.FlatList = {}
    
    local function traverse(inst, depth)
        local isMatch = true
        if self.FilterText ~= "" then
            isMatch = string.find(inst.Name:lower(), self.FilterText) ~= nil or string.find(inst.ClassName:lower(), self.FilterText) ~= nil
        end
        
        local children = getChildrenSafe(inst)
        local hasChildren = #children > 0
        
        if isMatch or self.FilterText == "" then
            table.insert(self.FlatList, {
                Instance = inst,
                Depth = depth,
                HasChildren = hasChildren,
                IsExpanded = self.ExpandedNodes[inst] == true,
                IsSelected = self.SelectedNodes[inst] == true,
            })
        end
        
        if (self.ExpandedNodes[inst] or self.FilterText ~= "") and hasChildren then
            for _, child in ipairs(children) do
                traverse(child, depth + 1)
            end
        end
    end
    
    for _, root in ipairs(self.RootNodes) do
        traverse(root, 0)
    end
end

function VirtualTree:GetVisibleRange(startIndex, count)
    local result = {}
    local total = #self.FlatList
    local endIndex = math.min(startIndex + count - 1, total)
    
    for i = startIndex, endIndex do
        if self.FlatList[i] then
            table.insert(result, self.FlatList[i])
        end
    end
    
    return result, total
end

return VirtualTree
