--!strict

-- Iteration-based RNG system.
-- Good for games with random rolls. Mostly used this to fix an exploit where people were using a RNG roll token, looking at the rewards they could pick from, and rejoining if they didn't like it to get fresh RNG.
-- Tracking iteration # in their save data and using this yields identical results so they can't do that anymore, it only gives them new results once they spend the token (rejoining wouldn't spend it)

local EtiLibs = script.Parent.Parent
local math = require(EtiLibs.Extension.Math)
local SpecialRNG = {}
SpecialRNG.__index = SpecialRNG

local RandomizerCache = {}
local NextIterations: {[number]: number} = {} -- Used to privately store iteration numbers in this module. Manually setting the iteration will cause serious problems considering this module is used for (lazy) security.
local Randomizers: {[number]: Random} = {} -- Same for ^

-- Returns the next iteration of this randomzier.
-- Note that this is relative to the current iteration value. If you used NumberFromIteration, that changes the iteration value and will affect the return value of this.
function SpecialRNG:NextIteration(): number
	local nextIteration: number = NextIterations[self.Seed]
	return self:NumberFromIteration(nextIteration)
end

-- Returns the random value associated with this randomizer's seed on its nth iteration
function SpecialRNG:NumberFromIteration(iterationNumber: number): number
	if self.Cache[iterationNumber] then
		return self.Cache[iterationNumber]
	end
	
	local nextIteration = NextIterations[self.Seed]
	local cycles = iterationNumber - nextIteration
	for i = 1, cycles do 
		self.Cache[nextIteration + (i - 1)] = Randomizers[self.Seed]:NextNumber()
	end
	
	NextIterations[self.Seed] = iterationNumber + 1
	self.Cache[iterationNumber] = Randomizers[self.Seed]:NextNumber()
	return self.Cache[iterationNumber]
end

-- Uses this randomizer to return an index in this table.
function SpecialRNG:RandomInTable(tbl: {[number]: any}, iterationNumber: number?): any
	if iterationNumber == nil then
		iterationNumber = NextIterations[self.Seed]
	end
	
	local value = self:NumberFromIteration(iterationNumber)
	return tbl[SpecialRNG.ToIntRange(value, 1, #tbl)]
end

-- Returns the iteration number that will be used to get the next random number.
function SpecialRNG:GetNextIteration(): number
	return NextIterations[self.Seed]
end

-- A utility function that converts a decimal value from 0 to 1 and scales it to the range of [min, max]
function SpecialRNG.ToIntRange(value, min, max)
	return math.clamp(math.round(math.map01to(value, min, max)), min, max)
end

-- Get an existing randomizer, or create a new one for the given seed.
function SpecialRNG.GetOrCreate(seed)
	if RandomizerCache[seed] then
		return RandomizerCache[seed]
	else
		local rng = {
			Cache = {},					-- A cache of stored values.
			Seed = seed,				-- The randomizer's seed
		}
		NextIterations[seed] = 0
		Randomizers[seed] = Random.new(seed)
		
		local mt = setmetatable(rng, SpecialRNG)
		RandomizerCache[seed] = mt
		return mt
	end
end

return SpecialRNG