--!strict
local UTF8 = {}

-- Returns whether or not the given string is a valid UTF8 string.
function UTF8.isValid(str: string): boolean
	-- n.b. this is about 8x faster than pcalling one of Roblox's built in methods to check each grapheme in some capacity, the ones
	-- that raise an exception when they run into an invalid sequence.
	local currentByte = 0
	local expectedBytes = 1
	for i = 1, #str do
		local byte = string.byte(str:sub(i, i))
		if bit32.band(byte, 0b1000_0000) == 0 then
			-- Start of a 1 byte char (this is the whole char)
			-- binary: 0xxxxxxx
			-- Valid if we are not expecting any bytes (it's equal to 1, not 0)
			-- Or if the current byte value is equal to the expected byte value, which means we just got done reading
			-- a multi-byte char and are moving on.
			if expectedBytes == 1 or (currentByte == expectedBytes) then
				currentByte = 0
				expectedBytes = 1
				continue -- next iter
			end
		elseif bit32.band(byte, 0b1100_0000) == 0b1000_0000 then
			-- Continuation byte, we should be expecting 2 to 4 bytes, and the current byte should be >= 1
			-- binary: 10xxxxxx
			if currentByte > 0 then
				currentByte += 1
				if currentByte <= expectedBytes then
					-- make sure the amount that has been read is within what is expected
					continue
				end
			end
		elseif bit32.band(byte, 0b1110_0000) == 0b1100_0000 then
			-- Start of a 2 byte char. Only valid if we are not already expecting continuation bytes (currentByte is 0)
			-- binary: 110xxxxx
			if (currentByte == 0) or (currentByte == expectedBytes) then
				currentByte = 1
				expectedBytes = 2
				continue
			end
		elseif bit32.band(byte, 0b1111_0000) == 0b1110_0000 then
			-- Start of a 3 byte char. Only valid if we are not already expecting continuation bytes (currentByte is 0)
			-- binary: 1110xxxx
			if (currentByte == 0) or (currentByte == expectedBytes) then
				currentByte = 1
				expectedBytes = 3
				continue
			end
		elseif bit32.band(byte, 0b1111_1000) == 0b1111_0000 then
			-- Start of a 4 byte char. Only valid if we are not already expecting continuation bytes (currentByte is 0)
			-- binary: 11110xxx
			if (currentByte == 0) or (currentByte == expectedBytes) then
				currentByte = 1
				expectedBytes = 4
				continue
			end
		end
		return false
	end
	return true
end

setmetatable(UTF8, {__index = utf8})
table.freeze(UTF8::any)
return UTF8 