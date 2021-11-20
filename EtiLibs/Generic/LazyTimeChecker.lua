--!strict
local LazyTimeChecker = {}
LazyTimeChecker.__index = LazyTimeChecker

-- Attempts to tick the timer forward, returning true if the last tick time was set and the tick should be considered successful,
-- and false if neither of those happened.
-- The interval of this timer can be modified with the numeric parameter.
function LazyTimeChecker:TryTick(intervalMultiplier: number?): boolean
	local self = self::Timer
	if (tick() - self.Last) >= self.Interval * (intervalMultiplier or 1) then
		self.Last = tick()
		return true
	end
	return false
end

function LazyTimeChecker.new(interval: number, treatLastAsNow: boolean?)
	local data = {
		Last = if treatLastAsNow then tick() else 0;
		Interval = interval;
	}
	return setmetatable(data, LazyTimeChecker)
end

export type Timer = typeof(LazyTimeChecker) & {
	Last: number,
	Interval: number
}

return LazyTimeChecker