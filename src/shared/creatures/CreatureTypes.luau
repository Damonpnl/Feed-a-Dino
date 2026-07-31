--!strict

--[[
	Shared type contracts for the creature lineage system.
	Contains no data and no Roblox service access.
]]

local CreatureTypes = {}

export type AffinityId = "Flesh" | "Flora" | "Mineral"
export type FeedId = string
export type LineageId = string
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type EvolutionIneligibilityReason = "InsufficientAffinity"

export type AffinityTotals = {
	Flesh: number,
	Flora: number,
	Mineral: number,
}

export type FeedDefinition = {
	id: FeedId,
	displayName: string,
	affinityContribution: AffinityTotals,
}

export type LineageDefinition = {
	id: LineageId,
	displayName: string,
	stage: number,
	rarity: RarityId,
	requiredDominantAffinity: AffinityId?,
}

export type JuvenileEvolutionResult = {
	eligible: boolean,
	reason: EvolutionIneligibilityReason?,
	dominantAffinity: AffinityId?,
	lineageId: LineageId?,
}

function CreatureTypes.createEmptyAffinities(): AffinityTotals
	return {
		Flesh = 0,
		Flora = 0,
		Mineral = 0,
	}
end

return CreatureTypes
