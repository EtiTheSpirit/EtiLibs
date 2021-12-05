--!strict
-- A queue, which is a first-in-first-out array.
-- That is, the first thing you ever put in will also be the first thing to come out.

-- NOTE: This is not optimized for large lists. Large lists (lists with 1000+ entries) may see substantial overhead.

local Queue = {}
Queue.__index = Queue

-- Add an item to the queue.
function Queue:Enqueue<T>(item: T)
	table.insert(self.Data, item)
end

-- Takes the next object in the queue and returns it, or returns nil of the queue is empty.
function Queue:Dequeue<T>(): T?
  -- TODO: Error when attempting to dequeue an empty queue, like how stack errors on pop?
	local item = self.Data[1]
	if item == nil then return nil end
	
	table.remove(self.Data, 1) -- TODO: Better solution for this? Large queues will have a hard time with this operation.
  -- TODO: Idea: Keep a general "offset" value on hand, use the offset instead of [1], then once the offset reaches a value like say, x, or y% of the queue's size,
  -- a single, bulk table.move call shifts everything back by 1 so the list doesn't infinitely expand, and so that it lets me dispose of dequeued entries behind the offset.
	return item
end

function Queue.new<T>(): Queue<T>
	local queue = {
		Data = {}
	} :: any -- Cast to any to make type checker quit complaining
	return setmetatable(queue, Queue)
end

export type Queue<T> = typeof(Queue) & {
	Data: {T}
}

return Queue
