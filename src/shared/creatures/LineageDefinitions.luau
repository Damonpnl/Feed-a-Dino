--!strict

--[[
	Immutable lineage definition data for the MVP lineage system.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local LineageDefinitions = {}

export type LineageDefinition = CreatureTypes.LineageDefinition

local lineages: { [CreatureTypes.LineageId]: CreatureTypes.LineageDefinition } = {
	ProtoRex = table.freeze({
		id = "ProtoRex",
		displayName = "Proto-Rex",
		stage = 0,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = nil,
	}),
	Fangling = table.freeze({
		id = "Fangling",
		displayName = "Fangling",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
	}),
	Mossback = table.freeze({
		id = "Mossback",
		displayName = "Mossback",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
	}),
	Stonehide = table.freeze({
		id = "Stonehide",
		displayName = "Stonehide",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
	}),
}

table.freeze(lineages)

local juvenileByAffinity: { [CreatureTypes.AffinityId]: CreatureTypes.LineageId } = table.freeze({
	Flesh = "Fangling",
	Flora = "Mossback",
	Mineral = "Stonehide",
})

function LineageDefinitions.get(lineageId: CreatureTypes.LineageId): CreatureTypes.LineageDefinition?
	return lineages[lineageId]
end

function LineageDefinitions.getAll(): { CreatureTypes.LineageDefinition }
	local result: { CreatureTypes.LineageDefinition } = {}
	for _, lineage in lineages do
		table.insert(result, lineage)
	end
	return table.freeze(result)
end

function LineageDefinitions.getJuvenileByAffinity(affinityId: CreatureTypes.AffinityId): CreatureTypes.LineageDefinition?
	local lineageId = juvenileByAffinity[affinityId]
	if lineageId == nil then
		return nil
	end
	return lineages[lineageId]
end

return LineageDefinitions
