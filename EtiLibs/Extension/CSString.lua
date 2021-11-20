--!strict
--[[
	CSString. A C#-based String library.
	
	Intended to override string:
		local string = require(Path.To.ThisModule)
--]]
local CSFmt = {}
local EtiLibs = script.Parent.Parent
local table = require(EtiLibs.Extension.Table)

-- These characters do something functional in string.gsub, and need to be escaped.
local LUA_MEANINGFUL_CHARS = {"^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?"}

-- Non-breaking soft hyphen. Appears invisible under the vast majority of text renderers.
local INVISIBLE = utf8.char(0xAD)

-- Given a string with the "magic characters" as they are called (see ^), this will escape each instance of those characters.
function CSFmt.EscapeLuaMagicChars(str: string): string
	local newStr = ""
	-- can't use gsub
	for i = 1, #str do
		local char = str:sub(i, i)
		if table.find(LUA_MEANINGFUL_CHARS, char) then
			newStr ..= "%" .. char
		else
			newStr ..= char
		end
	end
	return newStr
end

-- Identical to C#'s string.Format, where the format string is expected to have zero-based argument indices.
-- Example: Format("My name is {0}, and I like {1}.", "joe", 12345) will come out as "My name is joe, and I like 12345"
function CSFmt.csFormat(str: string, ...: any?): string
	local args = {...}

	for i = 1, #args do
		local fmtReplacement = tostring(args[i])
		-- temporary hack:
		local start, finish = fmtReplacement:find("{%d}")
		if start ~= nil and finish ~= nil then
			local digit = fmtReplacement:sub(start + 1, finish - 1)
			fmtReplacement = fmtReplacement:gsub("{%d}", "{" .. INVISIBLE .. digit .. "}")
		end

		local fmtTarget = "{" .. tostring(i - 1) .. "}" -- {0}, {1}, ...
		str = CSFmt.csReplace(str, fmtTarget, fmtReplacement)--str:gsub(fmtTarget, fmtReplacement)
	end
	return CSFmt.csReplace(str, INVISIBLE, "")
end

-- Identical to C#'s interpolated string format: $"Hello, world! My name is {someVarNameHere}! I like {someOtherVarNameHere}."
-- The varargs is one or more dictionaries containing {someVarNameHere = "Desired value", ...}
-- Errors if any keys are not strings.
function CSFmt.interp(str: string, ...: {[string]: any}): string
	local argArray = table.join(...)
	for argName: string, argValue in pairs(argArray) do
		if typeof(argName) ~= "string" then
			error("Cannot have a non-string key.", 2)
		end
		str = CSFmt.csReplace(str, "{" .. argName .. "}", tostring(argValue))
	end
	return str
end

-- Returns true if the given string starts with the given text.
function CSFmt.startsWith(str: string, text: string): boolean
	if #str < #text then return false end
	return str:sub(1, #text) == text
end

-- Returns true if the given string ends with the given text.
function CSFmt.endsWith(str: string, text: string): boolean
	if #str < #text then return false end
	return str:sub(#str - #text + 1, #str) == text
end

-- Returns true if the given string contains the given text. Ignores all format options.
function CSFmt.contains(str: string, text: string): boolean
	return string.find(str, CSFmt.EscapeLuaMagicChars(text)) ~= nil
end

-- Returns two values, one being if the string starts with the given text, and the other being the string with all content after that given text, or the actual string itself if it doesn't start with it.
function CSFmt.startsWithGetAfter(str: string, text: string): (boolean, string)
	if CSFmt.startsWith(str, text) then
		return true, str:sub(#text + 1)
	end
	return false, str
end

-- ^ but all text before the given text.
function CSFmt.endsWithGetBefore(str: string, text: string): (boolean, string)
	if CSFmt.endsWith(str, text) then
		return true, str:sub(1, #str - #text)
	end
	return false, str
end

-- Replaces all occurrences of text with substitute. Unlike gsub, this does not use any special formatting.
function CSFmt.csReplace(str: string, text: string, substitute: string): string
	if text == substitute then
		return str
	end
	if not string.find(str, CSFmt.EscapeLuaMagicChars(text)) then
		-- string.find is faster than me manually searching and then having no results afaik
		return str
	end
	local newStr = ""
	local charIndex = 1
	local limit = #str - #text + 1

	while charIndex <= limit do
		local seg = str:sub(charIndex, charIndex + #text - 1)
		if seg == text then
			newStr ..= substitute
			charIndex += #text
			continue
		end
		newStr ..= str:sub(charIndex, charIndex)
		charIndex += 1
	end

	if charIndex <= #str then
		newStr ..= str:sub(charIndex, #str)
	end
	
	return newStr
end

-- C# style Substring, albeit one-indexed, which takes in the index of the first character then the length of the text to grab.
function CSFmt.csSubstring(str: string, start: number, length: number): string
	return str:sub(start, start + length)
end

-- Returns true if the input string is nil or has no characters.
function CSFmt.isNilOrEmpty(str: string?): boolean
	return str == nil or #str == 0
end

-- Returns true if isNilOrEmpty returns true, but also if the string is only composed of whitespace like " \t  " or newlines (\r and \n)
function CSFmt.isNilOrWhitespace(str: string?): boolean
	if not str then return true end
	local repl, count = (str::string):gsub("%s+", ""):gsub("[\r\n]+", "")
	if CSFmt.isNilOrEmpty(repl) then return true end
	return false
end


-- Translates a string into an array of single characters. Note that the length of a single character may be greater than 1 depending on the UTF8 sequence
-- it uses. For example, emojis will generally take two chars (but can take a theoretical infinite amount due to the linking rules)
-- take a look at this gordon  ‍👨‍👨‍👨‍👩‍👩‍👩‍👩‍👩‍👩‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦‍👦
-- ^ is one grapheme but takes up *176* chars (the length of that string using # or :len() is 176)
function CSFmt.toCharArray(str: string): {string}
	local array = table.create(#str)
	for first, last in utf8.graphemes(str) do 
		table.insert(array, str:sub(first, last)) 
	end
	return array
end

-- STRICTLY ACCEPTS AN ARRAY OF CHARS, NOT STRINGS
-- Splits the given string by the given chararacter a given number of times (if no limit is defined, then it is limitless)
-- If the input splitBy param is a single string, it will be split into its character components.
function CSFmt.csSplit(str: string, splitBy: string | {string}, limit: number?)
	local retn = table.create(limit or 0, "")

	local limit: number = limit or math.huge
	local strChars = CSFmt.toCharArray(str)
	local current = 0

	if typeof(splitBy) == "string" then
		splitBy = CSFmt.toCharArray(splitBy)
	elseif typeof(splitBy) == "table" then
		local newSplitBy = {}
		for i = 1, #splitBy do
			local splitStr: string = (splitBy::{string})[i]
			for start, finish in utf8.graphemes(splitStr) do
				local char = splitStr:sub(start, finish)
				table.insert(newSplitBy, char)
			end
		end
	end

	for i = 1, #strChars do
		-- for every character in the input string, go through it, see if that character can't be found in the split array
		local char = strChars[i]
		local idx = table.find(splitBy, char)
		if idx then
			current += 1
			if current == limit then
				retn[current+1] = str:sub(i + 1)
				return retn
			end
			continue
		end
		retn[current+1] ..= char
	end

	return retn
end

CSFmt.Empty = ""
setmetatable(CSFmt, {__index = string})
table.freeze(CSFmt::any)

return CSFmt