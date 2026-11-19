--!strict
-- SNACK ATTACK: argument validation for every remote handler.
-- Exploiters control their client completely: they can fire any remote with any arguments
-- at any rate. Every handler treats its arguments as unknown and narrows them with these
-- helpers before touching game state. NaN fails every comparison, so range checks alone
-- never catch it: numbers are checked finite first.

local Validate = {}

function Validate.number(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" or not math.isfinite(value) then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

function Validate.integer(value: unknown, min: number, max: number): number?
	local n = Validate.number(value, min, max)
	if n and n == math.floor(n) then
		return n
	end
	return nil
end

function Validate.string(value: unknown, maxLength: number): string?
	if typeof(value) ~= "string" or #value > maxLength then
		return nil
	end
	if utf8.len(value) == nil then
		return nil -- invalid UTF-8, which datastores and labels refuse
	end
	return value
end

-- Only a real instance of the expected class that lives under a trusted container counts.
-- A table shaped like an instance ({ ClassName = "Part" }) is rejected by typeof.
function Validate.instanceIn(value: unknown, className: string, container: Instance): Instance?
	if typeof(value) ~= "Instance" then
		return nil
	end
	if not value:IsA(className) then
		return nil
	end
	if not value:IsDescendantOf(container) then
		return nil
	end
	return value
end

return Validate
