--!nonstrict
local Shared = game.ReplicatedStorage.Shared
local Roller = require(Shared.FieldRoller)
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Rarities = require(Shared.RarityDefinitions)
return function(t)
	local e = t.expect
	-- Every ticket in each pool agrees with its explicit weight, including fractional entries.
	t.test("exhaustively honors all 10000 tickets in each area", function()
		for _, area in Areas.getOrdered() do
			local counts = {}
			for ticket = 1, 10000 do
				local id = Roller.pick(area.ResourcePool, function() return ticket end)
				counts[id] = (counts[id] or 0) + 1
			end
			for _, entry in area.ResourcePool do e.equal(counts[entry.Id], math.round(entry.SpawnWeight * 100)) end
		end
	end)
	-- Exclusions renormalize eligible weights; they do not use rarity-derived probabilities.
	t.test("excludes chase resources from all mid-cycle rolls", function()
		local pool = Areas.get("Volcano").ResourcePool
		e.equal(Roller.tickets(pool, true), 9893)
		e.equal(Roller.pick(pool, function(_, high) return high end, true), "DragonMeat")
	end)
	-- A reset batch retains its highest Secret+ result and rerolls the others below Secret.
	t.test("keeps only the highest chase roll among five nodes", function()
		local tickets, index = {9894, 9968, 9999, 10000, 9998}, 0
		local results = Roller.area(Areas.get("Volcano").ResourcePool, 5, function(low)
			index += 1 return tickets[index] or low
		end, false)
		local chase, highest = 0, nil
		for _, id in results do if Rarities.isSecretPlus(Resources.get(id).Rarity) then chase += 1 highest = id end end
		e.equal(chase, 1) e.equal(highest, "InfernoCatalyst")
	end)
	-- Existing Divine ownership removes Divine from the eligible reset pool.
	t.test("honors the server-wide Divine reservation", function()
		local results = Roller.area(Areas.get("Volcano").ResourcePool, 5, function(_, high) return high end, true)
		for _, id in results do e.falsy(Resources.get(id).Rarity == "Divine") end
	end)
	-- Empty or exhausted pools must reject rolls predictably.
	t.test("rejects empty and excluded-only pools", function()
		e.throws(function() Roller.pick({}, function() return 1 end) end)
		e.throws(function() Roller.pick({{Id="InfernoCatalyst", SpawnWeight=1}}, function() return 1 end, true) end)
	end)
end
