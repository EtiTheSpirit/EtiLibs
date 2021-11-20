--!strict
-- Unlike its previous iteration which had offsets for Sonaria's map, this is a general purpose module that will be included in the public
-- rendition of the libraries.
local Provider = {}
Provider.__index = Provider

local EtiLibs = script.Parent.Parent
local Vector = require(EtiLibs.Mathematical.Vector)

-- Returns whether or not the given value is a power of two, and if it is, what power it is.
local function IsPow2(value: number): (boolean, number)
	local isPow2 = bit32.band(value, value - 1) == 0
	if isPow2 then
		return isPow2, math.log(value, 2)
	end
	return false, 0
end

local function GetQuadrantCenter(position: Vector2, center: Vector2, quadrantSize: number): Vector2
	local x = position.X
	local y = position.Y
	local retX = center.X
	local retY = center.Y
	if x <= center.X then
		retX = center.X - quadrantSize / 2 -- Yes divide by 2. We're looking for points 3/4ths the way out (the center of a quadrant, or half of a half (when looking at one axis only))
	else
		retX = center.X + quadrantSize / 2
	end

	if y <= center.Y then
		retY = center.Y - quadrantSize / 2
	else
		retY = center.Y + quadrantSize / 2
	end

	return Vector2.new(retX, retY)
end

-- Returns the cell in the included resolution that the given position sits within.
-- Returns nil if the position is out of range.
function Provider:GetCell(objectPosition: Vector3): Vector2?
	if math.abs(objectPosition.X) > self.WorldRadius or math.abs(objectPosition.Z) > self.WorldRadius then
		return nil
	end
	
	local center = Vector2.new()
	local objectPos2D = Vector.CastTo2DXZ(objectPosition)
	local quadrantSize = self.WorldRadius
	for i = 1, self.Iterations do
		center = GetQuadrantCenter(objectPos2D, center, quadrantSize)
		quadrantSize /= 2
	end

	center += Vector2.new(self.WorldRadius, self.WorldRadius)
	center /= Vector2.new(self.WorldDiameter, self.WorldDiameter)
	local originAlignedCell = Vector2.new((self.Resolution::number + 1) - math.floor(center.X * self.Resolution), (self.Resolution + 1) - math.floor(center.Y * self.Resolution))
	return originAlignedCell + self.Offset
end

-- A helper method that can be used to get the nearest power of two for the given map size and where the grid cells 
-- on the map should be as close to a given stud size as possible.
function Provider.GetNearestPowerOfTwoForSize(worldSizeAcross: number, gridCellSizeStuds: number, preferMakeExtra: boolean?): number
	local subdivisions = worldSizeAcross / gridCellSizeStuds
	local baseValue = math.log(subdivisions, 2)
	if preferMakeExtra then
		baseValue = math.ceil(baseValue)
	else
		baseValue = math.round(baseValue)
	end
	return math.pow(2, baseValue) -- 2^x
end

-- Create a new cell-based location tracker with the given resolution on X and Z. The resolution MUST be a power of 2.
-- The map center offset can optionally be defined.
function Provider.new(worldSizeAcross: number, resolution: number, mapCenterOffset: Vector2?)
	local isPow2, log = IsPow2(resolution)
	if not isPow2 then
		error("Invalid resolution. Requires a power of 2 value (1, 2, 4, 8, 16, 32, 64, ...)", 2)
	end
	
	local obj = {
		Iterations = log;
		Resolution = resolution;
		WorldRadius = worldSizeAcross / 2;
		WorldDiameter = worldSizeAcross;
		Offset = mapCenterOffset or Vector2.new();
	}
	
	local mt = setmetatable(obj, Provider)
	table.freeze(mt::any)
	return mt
end

return Provider