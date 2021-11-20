--!strict
-- override math
-- local math = require(Path.To.ThisModule)

local Math = {}

Math.tau = math.pi * 2

-- Replacement for math.round that allows defining the number of places.
function Math.roundPlaces(number: number, places: number): number
	local places = places or 0
	local exponent = 10^places
	if places == 0 then
		return math.round(number)
	end
	return math.round(number * exponent) / exponent
end

-- Alias. clamp a value between 0 and 1.
function Math.clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- Returns whether or not the given value is not a number.
function Math.isNAN(value: number): boolean
	return value ~= value -- If the value is a number, it will always equal itself. NAN has a quirk where it does NOT equal itself. Use this.
end

-- Identical to clamp01, but assumes the given value is a ratio and may be the result of dividing zero by zero. Uses the given fallback value, or 0.
function Math.clampRatio01(value: number, retnIfNan: number?): number
	if Math.isNAN(value) then
		return retnIfNan or 0
	end
	return Math.clamp01(value)
end

-- Alias. Linear Interpolation from start -> goal by alpha%
function Math.lerp(start: number, goal: number, alpha: number): number
	return ((goal - start) * alpha) + start
end

-- Akin to lerp, but this adds/subtracts increment to start so that it approaches goal
-- Note that a negative increment will indeed cause backwards interpolation
-- If the distance between start and goal is less than the increment, then the goal itself will be returned
function Math.constinterp(start: number, goal: number, increment: number): number
	if start == goal then return goal end
	if math.abs(goal - start) < increment then return goal end
	if start > goal then
		return start - increment
	else
		return start + increment
	end
end

-- Interpolates from start => goal by the given increment. 
-- If the difference between the start and goal are less than the increment, then the goal is returned.
-- Unlike constinterp, this is designed for the express purpose of handling rotations in the range of [0, τ]
-- This also enforces that increment is a positive value, so unlike constinterp, repulsion cannot be performed.
-- Due to the rotation behaviors, this may return any value *equivalent* to the given rotation (not necessarily 
-- a linear transition based on increment), and so the receiver of this function's result should handle this appropriately.
function Math.constinterpRadians(start: number, goal: number, increment: number): number
	local increment = math.abs(increment)
	if start == goal then return goal end
	
	goal = Math.wrap(goal, 0, Math.tau)
	start = Math.wrap(start, 0, Math.tau)
	if start == goal then return goal end
	if math.abs(goal - start) < increment then return goal end
	
	local delta = math.abs(goal - start)
	if delta > math.pi then
		-- The angle difference is over 180.
		-- This means that it's actually *less* than 180 as far as the shortest path is concerned, so we need to rearrange it so it takes the
		-- short path instead of going around the entire circle.
		if goal > start then
			-- The goal is greater than start, for extreme example, start may be 5deg and goal may be 355deg
			-- addd Tau to goal so that it becomes 365deg, now it will go backwards to 355
			start += Math.tau
		else
			-- Similar case to above
			goal += Math.tau
		end
	end
	
	if start > goal then
		return start - increment
	else
		return start + increment
	end
end

-- Alias. Map a value from a range into another range, e.g. say I have a value that can range from 0 to 100, and I want to make that scale into 69 to 420, this can do it.
function Math.map(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	if outMin == outMax then return outMin end -- If the range is 0, then just return that value and don't waste time on the math.

	return (x - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
end

-- Maps a number in the range of [min, max] to the range of [0, 1]. This is the inverse of map01to
function Math.mapto01(x: number, min: number, max: number): number
	return (x - min) / (max - min)
end

-- Maps a number in the range of [0, 1] to the range of [min, max]. This is the inverse of mapto01
function Math.map01to(x: number, min: number, max: number): number
	local alt = max - min
	return (x * alt) + min
end

-- Wraps x into the given range.
-- For example, if the range is [0, 5], and x is 6, then the returned value is 1.
function Math.wrap(x: number, min: number, max: number): number
	local maxAdj = max - min
	local xAdj = x - min
	return (((xAdj % maxAdj) + maxAdj) % maxAdj) + min
end

setmetatable(Math, {__index = math})
table.freeze(Math::any)
return Math