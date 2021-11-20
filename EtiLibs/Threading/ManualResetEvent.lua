--!strict
--[[
	ManualResetEvent. Inspired by C#'s System.Threading.ManualResetEventSlim class.
	
	Think of it like a Luau-based mutable boolean where you can wait until it is set to true.
	
	METHODS:
		- Set()		-- Sets the event's state to SET, and allows any code yielding from :Wait() to execute.
		- Reset()	-- Sets the event's state to RESET.
		- IsSet()	-- Returns true if the event's state is SET, and false if it is not.
		- Wait()	-- Causes the calling thread to yield until Set() is called. If the event is already set at the time this is called, it will do nothing.
--]]

local ManualResetEvent = {}
ManualResetEvent.__index = ManualResetEvent
ManualResetEvent.__tostring = function (obj)
	return string.format("ManualResetEvent[ID=%s, State=%s, WaitingEventHandles=%s]", tostring(obj.ID), obj.State and "SET" or "RESET", tostring(obj.WaitingEventHandles))
end

local EtiLibs = script.Parent.Parent
local Logger = require(EtiLibs.Generic.Logger).new(script.Name)
local EventObject = Instance.new("BindableEvent")
local LatestID = 0

-- Sets the state of this ManualResetEvent to TRUE, setting the event and allowing any waiting executions to complete.
function ManualResetEvent:Set()
	(self::ManualResetEvent).State = true
	EventObject:Fire(self.ID)
end

-- Sets the state of this ManualResetEvent to FALSE, resetting the event.
function ManualResetEvent:Reset()
	(self::ManualResetEvent).State = false
end

-- Returns whether or not this ManualResetEvent is set.
function ManualResetEvent:IsSet()
	return (self::ManualResetEvent).State
end

-- Yields until this ManualResetEvent has been set. If it is already set, it does nothing.
function ManualResetEvent:Wait()
	local self:ManualResetEvent = self::any -- For the type checker

	if self:IsSet() then return end
	self.WaitingEventHandles += 1
	while EventObject.Event:Wait() ~= self.ID do
		-- Run each time the event fires. If it's not our ID, run again.
		if self.State then
			Logger:Warn("WARNING: The ManualResetEvent update event ran, and while the event ID it ran for was not this event, this event's state was found as [SET]. Was the state manually modified (which you should NEVER do)? Was there an event desynchronization?")
			break
		end
	end
	self.WaitingEventHandles -= 1
end

function ManualResetEvent.new(state: boolean?): ManualResetEvent
	local evt = {
		State = (state == true),
		WaitingEventHandles = 0,
		ID = LatestID
	}
	LatestID += 1
	return setmetatable(evt, ManualResetEvent)::any
end

export type ManualResetEvent = typeof(ManualResetEvent) & {
	State: boolean,
	WaitingEventHandles: number,
	ID: number
}

return ManualResetEvent