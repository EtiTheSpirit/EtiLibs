--!strict
-- A stack, which is a first-in-last-out array.
-- That is, the first thing you ever put in will be the last thing to come out.

local Stack = {}
Stack.__index = Stack

local DEFAULT_SIZE = 256

function Stack:Push<T>(item: T)
	if #self.Data >= DEFAULT_SIZE then
		-- use GE because of multithreaded access in the future (idk if it'll be a problem, but ConcurrentStack<T> should resolve that anyway.)
		error("Stack overflow.")
	end
	table.insert(self.Data, item)
end

function Stack:Pop<T>(): T?
	local index = #self.Data
	if index == 0 then
		error("Attempt to pop an object off of an empty stack.", 2)
	end
	
	local last = self.Data[index]
	table.remove(self.Data, index)
	return last
end

function Stack.new<T>(alloc: number?): Stack<T>
	local stack = {
		AllocationSpace = alloc or DEFAULT_SIZE,
		Data = table.create(alloc or DEFAULT_SIZE)
	} :: any -- Cast to any to make type checker quit complaining.
	setmetatable(stack, Stack)
	table.freeze(stack)
	return stack::any
end

export type Stack<T> = typeof(Stack) & {
	Data: {T}
}

return Stack
