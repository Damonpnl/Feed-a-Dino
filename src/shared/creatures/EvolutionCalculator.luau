--!strict

--[[
	Pure evolution calculation for MVP juvenile outcomes.
	No Roblox services. No randomness. Deterministic tie-breaking.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)
local LineageDefinitions = require(script.Parent.LineageDefinitions)

local EvolutionCalculator = {}

-- Configurable minimum total affinity required for juvenile evolution.
EvolutionCalculator.MINIMUM_TOTAL_AFFINITY = 30

-- Explicit priority. Do not rely on dictionary iteration order.
local AFFINITY_TIE_PRIORITY: { CreatureTypes.AffinityId } = table.freeze({
	"Flesh",
	"Flora",
	"Mineral",
})

function EvolutionCalculator.getTotalAffinity(affinityTotals: CreatureTypes.AffinityTotals): number
	return affinityTotals.Flesh + affinityTotals.Flora + affinityTotals.Mineral
end

function EvolutionCalculator.isEligible(affinityTotals: CreatureTypes.AffinityTotals): boolean
	return EvolutionCalculator.getTotalAffinity(affinityTotals) >= EvolutionCalculator.MINIMUM_TOTAL_AFFINITY
end

function EvolutionCalculator.getDominantAffinity(
	affinityTotals: CreatureTypes.AffinityTotals
): CreatureTypes.AffinityId
	local dominantAffinity: CreatureTypes.AffinityId = AFFINITY_TIE_PRIORITY[1]
	local highestValue = affinityTotals[dominantAffinity]

	for index = 2, #AFFINITY_TIE_PRIORITY do
		local affinityId = AFFINITY_TIE_PRIORITY[index]
		local value = affinityTotals[affinityId]
		if value > highestValue then
			dominantAffinity = affinityId
			highestValue = value
		end
	end

	return dominantAffinity
end

function EvolutionCalculator.resolveJuvenileEvolution(
	affinityTotals: CreatureTypes.AffinityTotals
): CreatureTypes.JuvenileEvolutionResult
	if not EvolutionCalculator.isEligible(affinityTotals) then
		return {
			eligible = false,
			reason = "InsufficientAffinity",
			dominantAffinity = nil,
			lineageId = nil,
		}
	end

	local dominantAffinity = EvolutionCalculator.getDominantAffinity(affinityTotals)
	local lineage = LineageDefinitions.getJuvenileByAffinity(dominantAffinity)
	assert(lineage ~= nil, "Missing juvenile lineage for dominant affinity")

	return {
		eligible = true,
		reason = nil,
		dominantAffinity = dominantAffinity,
		lineageId = lineage.id,
	}
end

return EvolutionCalculator
