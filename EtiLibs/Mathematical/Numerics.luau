-- Written by Eti the Spirit 18406183
-- Designed for use in Lands of Eyzira MMORPG -- Number Utility Module
-- Open Sourced after realizing my game is in development H E C C
-- And a lot of these tools aren't really groundbreaking anyway, so it doesn't hurt.

-- Will be undocumented.

local NumberTools = {}

local EtiLibs = script.Parent.Parent
local math = require(EtiLibs.Extension.Math)


-- Lower line has "B" for "Billion". Most people see 100B as 100 billion, and 100G as ... really good cell service?
-- This can be altered to suit your needs, for instance, if you want to start combining past the trillions, just erase the last four values.
-- Alternatively, you can add more or change them. They can also be any length.
local TRUNCATE_LABELS = {"k", "M", "B", "T", "P"}
local INFINITY = utf8.char(8734) -- Infinity symbol
-- In case edits in the future are desired.
--[[
	"Default" names.
	Thousand
	Million
	Billion
	Trillion
	Quadrillion
	Quintillion
	Sextillion
	Septillion
	
	Standard International names, which are chosen because the first letter is unique.
	Kilo
	Mega
	Giga
	Tera
	Peta
	Exa
	Zetta
	Yotta
--]]

local function GetTruncateLabel(size)
	--return TRUNCATE_LETTERS.sub(Size, Size)
	if size > 0 and size <= #TRUNCATE_LABELS then
		return TRUNCATE_LABELS[size]
	end
	return "*" -- Ambiguous Character
end

-- FormatPercentage
-- Accepts a numeric value from 0 to 1, and optionally a given number of maximum precision digits (the default being 3 digits).
-- Returns a string, e.g. 50% for 0.5
-- This also rounds the number, so if there's 0.14638, it will display as 14.64%
function NumberTools.FormatPercentage(percent)
	return string.format("%3.2f", percent * 100) .. "%"
end

-- TruncateNumber
-- Shortens numbers based on endings e.g. 1000 turns into 1K
-- This has unique behavior where numbers larger than the maximum unit letter will combine multiple values, e.g. 1KY is 1K * 1Y.
function NumberTools.TruncateNumber(number, placeCount)
	if number == math.huge then
		return INFINITY
	end
	
	--The PlaceCount is the amount of number places shown. If this is not set, it is 1.
	local placeCount = placeCount or 1
	local div = 3 --The 10^Div factor that this number will be tested to fit into.
	--NOTE. This starts as 3 so that the first test will see if it fits into 1000. This intentionally skips lower exponents.
	local count = 0
	local letterCount = 0 --If we're over 8 (the limit of the truncate letter pool), this will increase, allowing for things like "1KY" for 1000Y. It is tested by Count.
	local resultingValue = number / (10^div) --Test if the number can fit into this default div of 1k.
	if resultingValue < 1 then
		--The number isn't divisible by 1000 where it may form a value above 1K.
		resultingValue = math.roundPlaces(resultingValue * 1000, placeCount)
		return tostring(resultingValue)
	end

	while resultingValue >= 1 do
		letterCount = 1 + math.floor(count / #TRUNCATE_LABELS) -- This has to be here or else we'll have an extra letter. Basically, for every #TRUNCATE_LABELS counts, add one extra letter
		div = div + 3 -- +3 because that'll move it to the next letter-represented place, e.g. 1,000 to 1,000,000
		count = count + 1 -- increase the amount we moved up by
		resultingValue = number / (10^div) -- create a new value
	end
	local letterChain = ""
	resultingValue = math.roundPlaces(resultingValue * 1000, placeCount)

	repeat
		local letterIndex = math.clamp(count, 1, #TRUNCATE_LABELS)
		-- By limiting it to 8, we basically clamp values to the maximum letter we have.
		-- In this case, it's Y, or 1,000,000,000,000,000,000,000,000
		-- While this should be enough for the vast majority of cases, edge cases where a value is larger than that will cause the letter to still be Y.
		-- The script will then see that count is still > 0, so it will run this loop and append a second letter.
		-- Say the given value is that huge number * 1,000, it would come out as 1KY
		letterChain = GetTruncateLabel(letterIndex) .. letterChain
		count = count - #TRUNCATE_LABELS
	until count <= 0

	return tostring(resultingValue) .. letterChain
end

-- Given a number, this will add commas every three digits, so 2718391 will return as "2,718,391"
function NumberTools.WithCommas(value, useAltCommas, limitDecimalPlacesCount)
	local wholeComponent = tostring(math.floor(math.abs(value)))
	local decimalComponent = tostring(value - math.floor(value))
	local limitDecimalPlacesCount = limitDecimalPlacesCount or 2
	
	local comma = useAltCommas and "." or ","
	local period = useAltCommas and "," or "."
	
	local newString = ""
	local digits = 0
	for idx = #wholeComponent, 1, -1 do
		newString = wholeComponent:sub(idx, idx) .. newString
		digits += 1
		if digits == 3 and idx ~= 1 then
			newString = comma .. newString
			digits = 0
		end
	end
	
	if decimalComponent ~= "0" and #decimalComponent > 2 then
		-- ^ Looks for "0." ...
		newString = newString .. period .. decimalComponent:sub(3, 3 + math.min(#decimalComponent, limitDecimalPlacesCount))
	end
	
	if math.sign(value) == -1 then
		newString = "-" .. newString
	end
	
	return newString
end

-- Given a number of seconds, this will return a clock in hours:minutes:seconds
function NumberTools.SecondsToClock(seconds, noHours)
	if seconds <= 0 then
		warn("Something called SecondsToClock with negative time!")
		seconds = math.abs(seconds)
	end
	local hours = string.format("%02.f", math.floor(seconds / 3600));
	local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
	local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60));
	if noHours then
		mins = string.format("%02.f", math.floor(seconds / 60));
		return mins..":"..secs
	end
	return hours..":"..mins..":"..secs
end

return NumberTools