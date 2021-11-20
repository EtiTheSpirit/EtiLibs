--!strict
local Bit = {}

-- Converts a set of booleans to a set of flags.
-- Accepts up to 32 boolean values, or a table of up to 32 boolean values.
-- Orders using indexing. That is, args[1] translates to bit 0 (the LSB) and args[32] translates to bit 31 (the MSB).
-- In Layman's terms, it's mapped backwards.
-- {true, false, true, true} turns into 1101 (binary)
function Bit.toFlags(...: boolean): number
	local args = {...}
	if typeof(args[1]) == "table" then
		args = (args[1]::any) :: {boolean}
	end
	if #args > 32 then
		error("Flags would result in integer larger than 4 bytes. Cannot pack.", 2)
	end
	local intValue = 0
	for i = 1, #args do
		local bit = i - 1
		if args[i] == true then
			intValue = bit32.bor(intValue, bit32.lshift(1, bit))
		end
	end
	return intValue
end

-- Converts a 32 bit integer value to an array of 32 boolean values.
-- The array is able to be passed into something like Bit.ToFlags to recreate the value.
-- As a result, a binary value of 1 (all bits 0 except for the LSB) would result in an array where [1]=true, but every other value is false.
function Bit.fromFlags(value: number): {boolean}
	local result = table.create(32)
	for i = 1, 32 do
		local bit = i - 1
		result[i] = bit32.btest(value, bit32.lshift(1, bit))
	end
	return result
end

setmetatable(Bit, {__index = bit32})
table.freeze(Bit::any)
return Bit