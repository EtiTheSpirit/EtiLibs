local Time = {}

-- Returns the current UTC time as the number of seconds since epoch.
-- Optionally includes a decimal component for milliseconds.
function Time.UTCNow(noMillis: boolean?)
	local nowUTC = DateTime.now():ToUniversalTime() -- Returns a table
	local asNow = DateTime.fromUniversalTime(nowUTC.Year, nowUTC.Month, nowUTC.Day, nowUTC.Hour, nowUTC.Minute, nowUTC.Second, nowUTC.Millisecond)
	-- ^ Casts that table back into a DateTime object.
	
	local secondsSinceEpoch = asNow.UnixTimestamp
	if noMillis then
		return secondsSinceEpoch
	end
	
	local millisSinceEpoch = asNow.UnixTimestampMillis
	return millisSinceEpoch / 1000
end

return Time