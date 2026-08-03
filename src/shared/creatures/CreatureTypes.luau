--!strict

--[[
	Shared type contracts for the creature lineage system.
	Contains no data and no Roblox service access.
]]

local CreatureTypes = {}

export type AffinityId = "Flesh" | "Flora" | "Mineral"
export type InfluenceId = "Arthropod" | "Fungal" | "Volcanic"
export type FeedId = string
export type LineageId = string
export type FormId = LineageId
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type EvolutionStateId = "Growing" | "Ready" | "Resolving"
export type InfluenceStrengthLabel = "None" | "Trace" | "Developing" | "Strong"
export type EvolutionIneligibilityReason =
	"InsufficientAffinity"
	| "InsufficientGrowth"
	| "InvalidRoll"
	| "UnsupportedStage"
	| "InvalidParentForm"
	| "NoRoute"
	| "AlreadyResolving"
	| "NotReady"

export type AffinityTotals = {
	Flesh: number,
	Flora: number,
	Mineral: number,
}

export type InfluenceTotals = {
	Arthropod: number,
	Fungal: number,
	Volcanic: number,
}

export type FeedDefinition = {
	id: FeedId,
	displayName: string,
	affinityContribution: AffinityTotals,
	growth: number,
	-- Optional specialized influence contribution (not a core affinity).
	influenceContribution: InfluenceTotals?,
}

export type LineageDefinition = {
	id: LineageId,
	displayName: string,
	stage: number,
	rarity: RarityId,
	requiredDominantAffinity: AffinityId?,
	familyId: string,
	-- Stable visual / template key (not a display name).
	placeholderVisualProfileId: string,
	deprecated: boolean?,
}

-- Prediction shown before evolution resolves.
export type EvolutionPrediction = {
	eligible: boolean,
	reason: EvolutionIneligibilityReason?,
	dominantEffectiveAffinity: AffinityId?,
	-- Final predicted form (variant applied when qualified).
	predictedNextFormId: FormId?,
	predictedBaseFormId: FormId?,
	predictedFinalFormId: FormId?,
	familyLabel: string?,
	strongestInfluenceId: InfluenceId?,
	strongestInfluenceScore: number,
	strongestInfluenceShare: number,
	influenceStrengthLabel: InfluenceStrengthLabel,
	qualifyingInfluenceId: InfluenceId?,
}

-- Resolved evolution outcome from the pure calculator.
export type ResolvedEvolution = {
	eligible: boolean,
	reason: EvolutionIneligibilityReason?,
	dominantEffectiveAffinity: AffinityId?,
	nextFormId: FormId?,
	baseFormId: FormId?,
	nextStage: number?,
	rarity: RarityId?,
	promoted: boolean?,
	roll: number?,
	heritageTransfer: AffinityTotals?,
	heritageInfluenceTransfer: InfluenceTotals?,
	qualifyingInfluenceId: InfluenceId?,
}

-- Back-compat Stage 0 prediction shape used by older tests/harness paths.
export type JuvenileEvolutionResult = {
	eligible: boolean,
	reason: EvolutionIneligibilityReason?,
	dominantAffinity: AffinityId?,
	familyLineageId: LineageId?,
	familyLabel: string?,
}

export type ResolvedJuvenileEvolution = {
	eligible: boolean,
	reason: EvolutionIneligibilityReason?,
	dominantAffinity: AffinityId?,
	lineageId: LineageId?,
	rarity: RarityId?,
	promoted: boolean?,
	roll: number?,
}

local RARITY_RANK: { [RarityId]: number } = table.freeze({
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
})

local INFLUENCE_IDS: { InfluenceId } = table.freeze({
	"Arthropod",
	"Fungal",
	"Volcanic",
})

local VALID_INFLUENCE_IDS: { [string]: boolean } = table.freeze({
	Arthropod = true,
	Fungal = true,
	Volcanic = true,
})

function CreatureTypes.getInfluenceIds(): { InfluenceId }
	return INFLUENCE_IDS
end

function CreatureTypes.isValidInfluenceId(influenceId: string): boolean
	return VALID_INFLUENCE_IDS[influenceId] == true
end

function CreatureTypes.createEmptyAffinities(): AffinityTotals
	return {
		Flesh = 0,
		Flora = 0,
		Mineral = 0,
	}
end

function CreatureTypes.copyAffinities(affinities: AffinityTotals): AffinityTotals
	return {
		Flesh = affinities.Flesh,
		Flora = affinities.Flora,
		Mineral = affinities.Mineral,
	}
end

function CreatureTypes.createEmptyInfluences(): InfluenceTotals
	return {
		Arthropod = 0,
		Fungal = 0,
		Volcanic = 0,
	}
end

function CreatureTypes.copyInfluences(influences: InfluenceTotals): InfluenceTotals
	return {
		Arthropod = influences.Arthropod,
		Fungal = influences.Fungal,
		Volcanic = influences.Volcanic,
	}
end

function CreatureTypes.getRarityRank(rarity: RarityId): number
	return RARITY_RANK[rarity]
end

function CreatureTypes.maxRarity(a: RarityId, b: RarityId): RarityId
	if CreatureTypes.getRarityRank(a) >= CreatureTypes.getRarityRank(b) then
		return a
	end
	return b
end

return CreatureTypes
