-- A utility to color, resize, or format strings using rich text.
local RTFTools = {}
local string = require(script.Parent.Parent.Extension.CSString)

function RTFTools.Color(str: string, color: Color3, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str 
	local r = string.format("%02x", math.floor(color.r * 255))
	local g = string.format("%02x", math.floor(color.g * 255))
	local b = string.format("%02x", math.floor(color.b * 255))

	return "<font color=\"#" .. r .. g .. b .. "\">" .. str .. "</font>"
end

function RTFTools.Size(str: string, size: number, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str
	return "<font size=\"" .. size .. "\">" .. str .. "</font>"
end

function RTFTools.Scale(str: string, elementSetTextSize: number, scale: number, escape: boolean?): string
	return RTFTools.Size(str, math.round(elementSetTextSize * scale), escape)
end

function RTFTools.Bold(str: string, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str
	return "<b>" .. str .. "</b>"
end

function RTFTools.Italics(str: string, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str
	return "<i>" .. str .. "</i>"
end

function RTFTools.Underline(str: string, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str
	return "<u>" .. str .. "</u>"
end

function RTFTools.Strike(str: string, escape: boolean?): string
	local str = escape and RTFTools.Escape(str) or str
	return "<s>" .. str .. "</s>"
end

function RTFTools.Escape(str: string): string
	return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end

-- Strips the content of the string so that it has no rich text elements.
-- Consider using `Label.Text = Label.ContentText` as ContentText already strips all tags.
function RTFTools.Strip(str: string): string
	local replacement = str:gsub("(</?.+>)", "")
	return replacement 
	-- Note: The variable assignment *is* actually useful here. gsub returns the amount of elements it destroyed as a second param
	-- This function specifies it only returns a string. Don't make it secretly return a number as a second value.
end

-- Strips out a tag of the given type. The input tag type should not contain the < or > symbols.
-- For example, to remove all bold text from the given string, call this method with a tag argument of "b"
-- If no tags were found, then the input string is returned.
function RTFTools.StripTag(str: string, tag: string, onlyIfOnStartAndEnd: boolean?): string
	if onlyIfOnStartAndEnd then
		local tagStart = "<" .. tag .. ">"
		local tagEnd = "</" .. tag .. ">"
		local startsWith, after = string.StartsWithGetAfter(str, tagStart)
		if startsWith then
			local endsWith, before = string.EndsWithGetBefore(after, tagEnd)
			if endsWith then
				return before
			end
		end
		return str
	else
		local format = "</?" .. string.EscapeLuaMagicChars(tag) .. ">"
		return str:gsub(format, string.Empty)
	end
end

table.freeze(RTFTools)
return RTFTools