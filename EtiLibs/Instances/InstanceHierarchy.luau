-- Written by EtiTheSpirit 18406183
-- Extended instance hierarchy controller

-- NOTE: This makes use of predicate functions.
-- That is, when you see a parameter named "predicate", it's a function that takes in an object then returns true or false based on if that object matches your needs.
-- An example of usage is:
--[[
FindFirstChildWhere(workspace, function (child)
	return child.Name == "Garbage" and child:IsA("BasePart")
end)
--]]

local HController = {}
local HttpService = game:GetService("HttpService")
local EtiLibs = script.Parent.Parent
local table = require(EtiLibs.Extension.Table)
local string = require(EtiLibs.Extension.CSString)
local Events = require(EtiLibs.Threading.Events)

-- Property Jargon
local PropChangedEvent = Instance.new("BindableEvent")
local PropChangedCallbacks = {}
local PropConnections = {}
PropChangedEvent.Event:Connect(function (evtGuid, obj)
	local callback = PropChangedCallbacks[evtGuid]
	if callback == nil then
		return
	end
	
	callback(obj)
end)
--

-- Climbs up the instance hierarchy until it finds an object containing the given object parameter as its child with the given name. 
-- Returns a reference to the parent, or nil if no such instance was found.
function HController.FindFirstAncestorContaining(object, name)
	while object and object.Parent do
		local target = object.Parent:FindFirstChild(name)
		if target then
			return target
		end

		object = object.Parent
	end
	return nil
end

-- Identical to FindFirstAncestorContaining, but uses FindFirstChildWhichIsA instead.
function HController.FindFirstAncestorContainingA(object, class)
	while object and object.Parent do
		local target = object.Parent:FindFirstChildWhichIsA(class)
		if target then
			return target
		end

		object = object.Parent
	end
	return nil
end

-- Searches the children of the given object and returns the first child from which the predicate returns TRUE.
function HController.FindFirstChildWhere(object, predicate, recursive)
	local objects;
	if recursive then
		objects = object:GetDescendants()
	else
		objects = object:GetChildren()
	end
	
	return table.first(objects, predicate)
end

-- Returns all children that the given predicate returns TRUE for.
function HController.GetChildrenWhere(parent, predicate)
	return table.where(parent:GetChildren(), predicate)
end

-- Returns all descendants that the given predicate returns TRUE for.
function HController.GetDescendantsWhere(parent, predicate)
	return table.where(parent:GetDescendants(), predicate)
end

function HController.HasAccessibleProperty(instance, property)
	local success = pcall(function ()
		local _ = instance[property]
	end)
	return success
end

-- Waits for an entire path. The path is defined as an ordered array of strings.
function HController.WaitForPath(parent: Instance, path: {string}, timeout: number?): Instance?
	local remainingTime: number? = timeout
	local nextSearch = parent
	for i = 1, path do
		local start = os.clock()
		nextSearch = parent:WaitForChild(path[i], remainingTime)
		if not nextSearch then 
			return nil -- means a timeout occurred
		end
		remainingTime -= (os.clock() - start)
		if remainingTime <= 0 then
			return nil
		end
	end
	return nextSearch
end

-- Similar to Instance:GetFullName() with the exception that this can return a name relative to a specific parent instance rather than DataModel (game)
function HController.GetFullNameRelativeTo(this: Instance, ancestor: Instance)
	if this == ancestor then return string.Empty end
	if not this:IsDescendantOf(ancestor) then
		error("Attempted to get the full name of " .. this:GetFullName() .. " relative to " .. ancestor:GetFullName() .. ", but they are not relatives!", 2)
	end
	
	local ancestorName = ancestor:GetFullName()
	return this:GetFullName():sub(#ancestorName + 2)
	-- The +2 removes a leading dot from this result string.
	-- ancestorName:sub(#ancestorName) will return the last character in that string (if it's Workspace, it'll return "e")
	-- So +1 will get rid of the last character in the string and move it one after, which puts the index on the dot between whatever.whatever
	-- A second +1 will move it to after that dot, giving the start of the name that we want.
	-- Just in case anyone wondered where +2 came from.
end

-- Returns a custom event that fires whenever the given property or properties on the given object or any of its ancestors changes.
-- Recurses up the hierarchy until it finds an object without at least one of the given properties.
-- The values for validProperties and validClasses can be strings or tables (of strings)

-- If the ancestry of the lowest object changes, the event will be disconnected and a warning will be logged, unless the object that changed is the highest level object.
-- (Basically, if the tree is broken, it disconnects)
function HController.ConnectPropertyChangedOnAncestors(object, callback, validProperties, validClasses)
	local eventGuid = HttpService:GenerateGUID()
	local connections = {}
	local topLevelObject = nil
	
	if typeof(validClasses) == "string" then
		validClasses = {validClasses}
	elseif typeof(validClasses) == "nil" then
		return
	end
	
	if typeof(validProperties) == "string" then
		validProperties = {validProperties}
	elseif typeof(validProperties) == "nil" then
		return
	end
	while true do
		if object == nil then return end
		local target = object -- This ref is necessary due to upvalue garbage.
		local ok = false
		for i = 1, #validClasses do
			if object:IsA(validClasses[i]) then
				ok = true
			end
			if ok then break end
		end
		if not ok then break end
		
		table.insert(connections, target.AncestryChanged:Connect(function (child, newParent)
			if child ~= topLevelObject then
				warn("Instance tree broken, disconnected ConnectPropertyChangedOnAncestors for " .. tostring(target))
				for i = 1, #connections do
					connections[i]:Disconnect()
				end
				PropChangedCallbacks[eventGuid] = nil
			end
		end))
		
		-- Find the first property that exists on this object.
		local property = table.first(validProperties, function (property) return HController.HasAccessibleProperty(object, property) end, nil)
		if property == nil then
			topLevelObject = object
			break
		end
		
		table.insert(connections, target:GetPropertyChangedSignal(property):Connect(function ()
			PropChangedEvent:Fire(eventGuid, target)
		end))
		
		object = object.Parent
	end
	
	PropConnections[eventGuid] = connections
	PropChangedCallbacks[eventGuid] = callback
	
	return eventGuid
end

function HController.DisconnectPropertyChangedOnAncestors(guid)
	local cons = PropConnections[guid]
	PropChangedCallbacks[guid] = nil
	if cons then
		for i = 1, #cons do
			cons[i]:Disconnect()
		end
	end
end

return HController