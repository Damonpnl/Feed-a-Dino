--!strict

--[[
	Data-driven Stage 1 -> Stage 2 evolution routes.
	Keyed by current juvenile form ID, then dominant effective affinity.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local Stage2Routes = {}

export type AffinityRouteTable = { [CreatureTypes.AffinityId]: CreatureTypes.LineageId }

local routes: { [CreatureTypes.LineageId]: AffinityRouteTable } = table.freeze({
	Fangling = table.freeze({
		Flesh = "Raptor",
		Flora = "VenomRaptor",
		Mineral = "ArmoredTRex",
	}),
	Bloodfang = table.freeze({
		Flesh = "Raptor",
		Flora = "VenomRaptor",
		Mineral = "ArmoredTRex",
	}),
	Mossback = table.freeze({
		Flesh = "CarnivorousPlant",
		Flora = "Ent",
		Mineral = "ForestGolem",
	}),
	Thornhide = table.freeze({
		Flesh = "CarnivorousPlant",
		Flora = "Ent",
		Mineral = "ForestGolem",
	}),
	Stonehide = table.freeze({
		Flesh = "Ankylosaur",
		Flora = "MossGolem",
		Mineral = "CrystalGolem",
	}),
	Crystalback = table.freeze({
		Flesh = "Ankylosaur",
		Flora = "MossGolem",
		Mineral = "CrystalGolem",
	}),
})

function Stage2Routes.getRouteTable(formId: CreatureTypes.LineageId): AffinityRouteTable?
	return routes[formId]
end

function Stage2Routes.resolve(
	formId: CreatureTypes.LineageId,
	dominantAffinity: CreatureTypes.AffinityId
): CreatureTypes.LineageId?
	local byAffinity = routes[formId]
	if byAffinity == nil then
		return nil
	end
	return byAffinity[dominantAffinity]
end

function Stage2Routes.getAll(): { [CreatureTypes.LineageId]: AffinityRouteTable }
	return routes
end

return Stage2Routes
