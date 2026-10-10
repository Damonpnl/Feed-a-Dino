--!strict
-- Explicit pool weights only. Integer hundredths avoid floating-point boundary drift.
local Resources = require(script.Parent.ResourceDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Roller = {}
function Roller.tickets(pool, excludeSecretPlus: boolean?, excludeDivine: boolean?): number
	local total = 0
	for _, entry in pool do
		local resource = Resources.get(entry.Id)
		if resource and (not excludeSecretPlus or not Rarities.isSecretPlus(resource.Rarity))
			and (not excludeDivine or resource.Rarity ~= "Divine") then
			total += math.round(entry.SpawnWeight * 100)
		end
	end
	return total
end
function Roller.pick(pool, nextInteger: (number, number) -> number, excludeSecretPlus: boolean?, excludeDivine: boolean?): string
	local total = Roller.tickets(pool, excludeSecretPlus, excludeDivine)
	assert(total > 0, "Resource pool has no eligible tickets")
	local ticket = nextInteger(1, total)
	assert(ticket >= 1 and ticket <= total, "Injected roll outside eligible pool")
	local cursor = 0
	for _, entry in pool do
		local resource = Resources.get(entry.Id)
		if resource and (not excludeSecretPlus or not Rarities.isSecretPlus(resource.Rarity))
			and (not excludeDivine or resource.Rarity ~= "Divine") then
			cursor += math.round(entry.SpawnWeight * 100)
			if ticket <= cursor then return entry.Id end
		end
	end
	error("Weighted roll did not resolve")
end
function Roller.area(pool, count: number, nextInteger: (number, number) -> number, divineReserved: boolean): { string }
	local results = {}
	local best, highest = nil, 0
	for index = 1, count do
		local id = Roller.pick(pool, nextInteger, false, divineReserved)
		results[index] = id
		local rarity = Resources.get(id).Rarity
		if Rarities.isSecretPlus(rarity) and Rarities.priority(rarity) > highest then
			best, highest = index, Rarities.priority(rarity)
		end
	end
	for index, id in results do
		if index ~= best and Rarities.isSecretPlus(Resources.get(id).Rarity) then
			results[index] = Roller.pick(pool, nextInteger, true, true)
		end
	end
	return results
end
return Roller
