-- Returns a factory that creates a function which returns an existing instance of an object, or returns a new instance of that object.
-- Sorry if that was confusing.
-- Example for help: 
-- local GetOrCreateFactory = require(this)
-- local GetOrCreateFolder = GetOrCreateFactory("Folder")
-- GetOrCreateFolder(game.ReplicatedStorage, "MyFolderName")

local function findOrCreate(parent, name, class)
	local obj = parent:FindFirstChild(name)
	if obj ~= nil then return obj end
	local obj = Instance.new(class)
	obj.Name = name
	obj.Parent = parent
	return obj
end

return function(class, Parent, Name)
	if not Parent or not Name then
		return function(parent, name)
			return findOrCreate(parent, name, class)
		end
	else
		return findOrCreate(Parent, Name, class)
	end
end