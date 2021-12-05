--!strict
--[[
	To use: local table = require(this)
	(Yes, override table.)

	Adds custom functions to the `table` value provided by roblox (in normal cases, this would simply modify `table`, but Roblox has disabled that so we need to use a proxy)
	
	NOTE: These do not support method style calls.
		local tbl = {}
		tbl:contains(thing)
		
		^ this will error.
		
	
	Implements a lot of methods, especially those that use predicates to select elements out of a table.
--]]

local RNG = Random.new()
local Table = {}
type Table<TKey, TValue> = {[TKey]: TValue}
type AnyTable = Table<any, any?>
type Predicate<T> = (T) -> (boolean)
type Func<TIn, TReturn> = (TIn) -> (TReturn)

-- Returns true if the table contains the specified value.
function Table.containsElement(tbl: AnyTable, value: any): boolean
	return Table.indexOf(tbl, value) ~= nil -- This is kind of cheatsy but it promises the best performance out of the little gizmos the module offers
	-- (so it's not *the best performance*, but of what is available here, it will try to work quickly). You should try to use table.find if you know it's an array.
end

-- Returns the key of the specified value, or nil if it could not be found. Unlike IndexOf, this searches every key in the table, not just ordinal indices (arrays)
-- This is inherently slower due to how lookups work, so if your table is structured like an array, use table.find
function Table.keyOf(tbl: AnyTable, value: any): any
	for index, obj in pairs(tbl) do
		if obj == value then
			return index
		end
	end
	return nil
end

-- A combo of table.find and table.keyOf -- This first attempts to find the ordinal index of your value, then attempts to find the lookup key if it can't find an ordinal index.
function Table.indexOf(tbl: AnyTable, value: any): any
	local fromFind = table.find(tbl, value)
	if fromFind then return fromFind end

	return Table.keyOf(tbl, value)
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Skips *n* objects in the table, and returns a new table that contains indices (n + 1) to (end of table)
function Table.skip<T>(tbl: {T}, amount: number): {T}
	return table.move(tbl, amount + 1, #tbl, 1, table.create(#tbl - amount)) :: any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Takes *n* objects from a table and returns a new table only containing those objects.
function Table.take<T>(tbl: {T}, amount: number): {T}
	return table.move(tbl, 1, amount, 1, table.create(amount)) :: any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Takes the range of entries in this table in the range [start, finish] and returns that range as a table.
function Table.range<T>(tbl: {T}, start: number, finish: number): {T}
	return table.move(tbl, start, finish, 1, table.create(finish - start + 1)) :: any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). An alias that calls table.skip(skip), and then takes [take] entries from the resulting table.
-- Unlike separately calling skip and take, this does both operations simultaneously.
function Table.skipAndTake<T>(tbl: {T}, skip: number, take: number): {T}
	return table.move(tbl, skip + 1, skip + take, 1, table.create(take)) :: any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Selects a random object out of tbl
function Table.random<T>(tbl: {T}): T
	return tbl[RNG:NextInteger(1, #tbl)]
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Merges all the given tables together.
function Table.joinArray<T>(...: {T}): {T}
	local tbls = {...}
	local at = 1
	local newTbl = {}
	for i = 1, #tbls do
		local tbl = tbls[i]
		table.move(tbl, 1, #tbl, at, newTbl)
		at += #tbl
	end
	return newTbl :: any
end

-- Joins multiple tables together. This does not require arrays.
-- For performance, if joining arrays, use joinArray
-- T is a table type (that is, the input parameter should be *some table*. Doesn't matter what, so long as its a table.)
function Table.join<T>(...: T): T
	local tbls = {...}
	local newTbl = {}
	for i = 1, #tbls do
		local subTbl: T = tbls[i]
		for index: any, value: any in pairs(subTbl::any) do
			newTbl[index] = value
		end
	end
	return newTbl::any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Removes the specified object from this array.
function Table.removeObject<T>(tbl: {T}, obj: T)
	local index = Table.indexOf(tbl, obj)
	if index then
		table.remove(tbl, index)
	end
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Iterates through the given table and returns all instances from which the given predicate function returns true as an array.
function Table.where<T>(tbl: {T}, predicate: Predicate<T>): {T}
	local result = {}
	for i = 1, #tbl do
		local object = tbl[i]
		if (predicate(object)) then
			table.insert(result, object)
		end
	end
	return result
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Iterates through the given table and returns the first occurrence from the table from which the given predicate function returns true. Returns default otherwise.
function Table.first<T>(tbl: {T}, predicate: Predicate<T>, default: T?): T?
	for i = 1, #tbl do
		local object = tbl[i]
		if (predicate(object)) then
			return object
		end
	end
	return default
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Iterates through the given table, and counts the amount of elements that meet the given requirement as defined by the predicate.
function Table.count<T>(tbl: {T}, predicate: Predicate<T>): number
	local count = 0
	for i = 1, #tbl do
		local object = tbl[i]
		if (predicate(object)) then
			count += 1
		end
	end
	return count
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Iterates through the given table, and runs the transformer function on all elements, populating a new table with the given data rather than modifying the original table.
-- If the transformer returns nil, it will be removed from the table.
function Table.transform<TIn, TOut>(tbl: {TIn}, transform: Func<TIn, TOut>): {TOut}
	local newTbl = table.create(#tbl)
	local actualIndex = 1
	for i = 1, #tbl do
		local element = tbl[i]
		local newElement = transform(element)
		if newElement == nil then continue end
		newTbl[actualIndex] = newElement
		actualIndex += 1
	end
	return newTbl
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Removes all elements from the given table who cause predicate to return TRUE.
function Table.removeWhere<T>(tbl: {T}, predicate: Predicate<T>): ()
	for i = #tbl, 1, -1 do
		local element = tbl[i]
		if predicate(element) then
			table.remove(tbl, i)
		end
	end
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Returns a shallow copy of this table, which is a copy of all first level entities by reference.
function Table.shallowCopyArray<T>(tbl: {T}): {T}
	local newTbl = table.create(#tbl)
	for i = 1, #tbl do
		newTbl[i] = tbl[i]
	end
	return newTbl
end

-- Supports dictionaries. Returns a shallow copy of this table, which is a copy of all first level entities by reference.
-- Prefer shallowCopyArray for ordered lists with no gaps and numeric indices, as it will be much faster
function Table.shallowCopy<T>(tbl: T): T
	local newTbl = {}
	for index, value in pairs(tbl::any) do
		newTbl[index] = value
	end
	return newTbl::any
end

function DeepCopyCycleSafe<T>(tbl: T, retainImmutability: boolean, exploredTables: {T}, indexMatchedEquals: {T})
	local newTbl = {}
	table.insert(exploredTables, tbl)
	table.insert(indexMatchedEquals, newTbl::any)
	for index: any, value: any in pairs(tbl::any) do
		if typeof(value) == "table" then
			local existingIndex = table.find(exploredTables, value)
			if existingIndex then
				newTbl[index] = indexMatchedEquals[existingIndex]::any -- Yes, use indexMatchedEquals here instead of exploredTables
				continue -- Do not allow it to continue below, freezing it now may cause problems.
			end

			local clonedSubTable = DeepCopyCycleSafe(value, retainImmutability, exploredTables, indexMatchedEquals)
			if retainImmutability and table.isfrozen(value) then
				table.freeze(clonedSubTable)
			end
			newTbl[index] = clonedSubTable :: any
		elseif typeof(value) == "Instance" then
			newTbl[index] = value:Clone() :: any
		else
			newTbl[index] = value :: any
		end
	end
	return newTbl
end

-- A "deep-ish" copy of a table. That is, it copies subtables and instances, but no other roblox primitive types
-- In most cases, these types are readonly anyway, but expect issues if you modify something like a RaycastParams instance in this table.
-- If retainImmutability is true, tables are checked for being frozen before being copied, and if they were frozen, then the copy is 
-- frozen as well.
-- If it's false, then the cloned table is fully mutable.
-- T is a table type (that is, the input parameter should be *some table*. Doesn't matter what, so long as its a table.)
function Table.deepishCopy<T>(tbl: T, retainImmutability: boolean?): T
	return DeepCopyCycleSafe(tbl, retainImmutability == true, {}, {}) :: any
end

-- ONLY SUPPORTS ORDINAL TABLES (ARRAYS). Returns a new table containing the identical elements to the given table, but in reverse order.
function Table.reverse<T>(tbl: {T}): {T}
	local newTbl = table.create(#tbl)
	for i = 1, #tbl do
		local obj = tbl[i]
		newTbl[(#tbl - i) + 1] = obj
	end
	return newTbl
end

-- Supports dictionaries. Returns whether or not the given table contains an object that satisfies the predicate.
function Table.contains(tbl: AnyTable, predicate: Predicate<any>): boolean
	for index, object in pairs(tbl) do
		if predicate(object) then
			return true
		end
	end
	return false
end

-- Creates a table with the given uniform capacity in the given amount of dimensions with the given optional default value
function Table.createMultiDim(amount: number, dimensions: number, defaultValue: any?): AnyTable
	if dimensions < 1 then
		error("Invalid value for parameter 'dimensions'. Must be greater than zero.", 2)
	end
	local container = table.create(amount)
	if dimensions == 1 and defaultValue then
		for i = 1, amount do
			container[i] = defaultValue
		end
	end
	for i = 1, dimensions - 1 do
		for j = 1, amount do
			container[j] = Table.createMultiDim(amount, dimensions - 1)
		end
	end
	return container
end

local function DeepFreezeCycleSafe<T>(tbl: T, exploredTables: {T})
	table.insert(exploredTables, tbl)
	for index: any, value: any in pairs(tbl::any) do
		if typeof(value) == "table" then
			if table.find(exploredTables, value) then continue end 
			-- ^ Don't need to set index, it's by reference, so once it's frozen then all references are frozen.
			DeepFreezeCycleSafe(value, exploredTables)
		end
	end
	table.freeze(tbl::any)
end

-- Does a "deep freeze", which recursively freezes this table and all child tables. This accomodates for cyclic references.
-- Similarly to table.freeze, this returns a reference to the input table.
-- T is a table type (that is, the input parameter should be *some table*. Doesn't matter what, so long as its a table.)
function Table.deepFreeze<T>(tbl: T): T
	DeepFreezeCycleSafe(tbl, {})
	return tbl
end

setmetatable(Table, {__index = table})
table.freeze(Table::any)
return Table
-- Return the custom Table library, and use the default Roblox "table" variable as the fallback.
