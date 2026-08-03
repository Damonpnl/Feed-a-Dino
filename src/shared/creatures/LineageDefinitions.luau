--!strict

--[[
	Immutable lineage / form definition data.
	Stable IDs are separate from display names.
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
		familyId = "ProtoRex",
		placeholderVisualProfileId = "ProtoRex",
		deprecated = false,
	}),
	Fangling = table.freeze({
		id = "Fangling",
		displayName = "Fangling",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "Fangling",
		deprecated = false,
	}),
	Bloodfang = table.freeze({
		id = "Bloodfang",
		displayName = "Bloodfang",
		stage = 1,
		rarity = "Uncommon" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "Bloodfang",
		deprecated = false,
	}),
	Mossback = table.freeze({
		id = "Mossback",
		displayName = "Mossback",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "Mossback",
		deprecated = false,
	}),
	Thornhide = table.freeze({
		id = "Thornhide",
		displayName = "Thornhide",
		stage = 1,
		rarity = "Uncommon" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "Thornhide",
		deprecated = false,
	}),
	Stonehide = table.freeze({
		id = "Stonehide",
		displayName = "Stonehide",
		stage = 1,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "Stonehide",
		deprecated = false,
	}),
	Crystalback = table.freeze({
		id = "Crystalback",
		displayName = "Crystalback",
		stage = 1,
		rarity = "Uncommon" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "Crystalback",
		deprecated = false,
	}),
	Raptor = table.freeze({
		id = "Raptor",
		displayName = "Raptor",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "Raptor",
		deprecated = false,
	}),
	VenomRaptor = table.freeze({
		id = "VenomRaptor",
		displayName = "Venom Raptor",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "VenomRaptor",
		deprecated = false,
	}),
	ArmoredTRex = table.freeze({
		id = "ArmoredTRex",
		displayName = "Armored T. rex",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "ArmoredTRex",
		deprecated = false,
	}),
	CarnivorousPlant = table.freeze({
		id = "CarnivorousPlant",
		displayName = "Carnivorous Plant",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "CarnivorousPlant",
		deprecated = false,
	}),
	Ent = table.freeze({
		id = "Ent",
		displayName = "Ent",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "Ent",
		deprecated = false,
	}),
	ForestGolem = table.freeze({
		id = "ForestGolem",
		displayName = "Forest Golem",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "ForestGolem",
		deprecated = false,
	}),
	Ankylosaur = table.freeze({
		id = "Ankylosaur",
		displayName = "Ankylosaur",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "Ankylosaur",
		deprecated = false,
	}),
	MossGolem = table.freeze({
		id = "MossGolem",
		displayName = "Moss Golem",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "MossGolem",
		deprecated = false,
	}),
	CrystalGolem = table.freeze({
		id = "CrystalGolem",
		displayName = "Crystal Golem",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "CrystalGolem",
		deprecated = false,
	}),
	MantisRaptor = table.freeze({
		id = "MantisRaptor",
		displayName = "Mantis Raptor",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flesh" :: CreatureTypes.AffinityId?,
		familyId = "Fangling",
		placeholderVisualProfileId = "MantisRaptor",
		deprecated = false,
	}),
	MushroomEnt = table.freeze({
		id = "MushroomEnt",
		displayName = "Mushroom Ent",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Flora" :: CreatureTypes.AffinityId?,
		familyId = "Mossback",
		placeholderVisualProfileId = "MushroomEnt",
		deprecated = false,
	}),
	MagmaGolem = table.freeze({
		id = "MagmaGolem",
		displayName = "Magma Golem",
		stage = 2,
		rarity = "Common" :: CreatureTypes.RarityId,
		requiredDominantAffinity = "Mineral" :: CreatureTypes.AffinityId?,
		familyId = "Stonehide",
		placeholderVisualProfileId = "MagmaGolem",
		deprecated = false,
	}),
}

table.freeze(lineages)

local familyByAffinity: { [CreatureTypes.AffinityId]: CreatureTypes.LineageId } = table.freeze({
	Flesh = "Fangling",
	Flora = "Mossback",
	Mineral = "Stonehide",
})

local juvenileByAffinityAndRarity: {
	[CreatureTypes.AffinityId]: { [CreatureTypes.RarityId]: CreatureTypes.LineageId },
} = table.freeze({
	Flesh = table.freeze({
		Common = "Fangling",
		Uncommon = "Bloodfang",
	}),
	Flora = table.freeze({
		Common = "Mossback",
		Uncommon = "Thornhide",
	}),
	Mineral = table.freeze({
		Common = "Stonehide",
		Uncommon = "Crystalback",
	}),
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

function LineageDefinitions.getFamilyLineageId(affinityId: CreatureTypes.AffinityId): CreatureTypes.LineageId?
	return familyByAffinity[affinityId]
end

function LineageDefinitions.getJuvenileByAffinityAndRarity(
	affinityId: CreatureTypes.AffinityId,
	rarity: CreatureTypes.RarityId
): CreatureTypes.LineageDefinition?
	local byRarity = juvenileByAffinityAndRarity[affinityId]
	if byRarity == nil then
		return nil
	end
	local lineageId = byRarity[rarity]
	if lineageId == nil then
		return nil
	end
	return lineages[lineageId]
end

function LineageDefinitions.getJuvenileByAffinity(affinityId: CreatureTypes.AffinityId): CreatureTypes.LineageDefinition?
	return LineageDefinitions.getJuvenileByAffinityAndRarity(affinityId, "Common")
end

return LineageDefinitions
