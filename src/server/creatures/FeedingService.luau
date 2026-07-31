--!strict

--[[
	Server-side feed application against authoritative CreatureState.
	Predicts juvenile evolution; does not evolve, consume inventory, or use randomness.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local CreatureTypes = require(Creatures:WaitForChild("CreatureTypes"))
local FeedDefinitions = require(Creatures:WaitForChild("FeedDefinitions"))
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))

local CreatureState = require(script.Parent.CreatureState)

local FeedingService = {}

export type EvolutionResult = CreatureTypes.JuvenileEvolutionResult
export type FeedFailureReason = "UnknownFeed"

export type FeedResult = {
	success: boolean,
	reason: FeedFailureReason?,
	feedId: string?,
	updatedAffinities: CreatureTypes.AffinityTotals?,
	totalFeedsConsumed: number?,
	predictedEvolution: EvolutionResult?,
}

function FeedingService.applyFeed(state: CreatureState.CreatureState, feedId: string): FeedResult
	local feed = FeedDefinitions.get(feedId)
	if feed == nil then
		return {
			success = false,
			reason = "UnknownFeed",
			feedId = feedId,
			updatedAffinities = nil,
			totalFeedsConsumed = nil,
			predictedEvolution = nil,
		}
	end

	CreatureState.applyAffinityContribution(state, feed.affinityContribution)
	CreatureState.incrementFeedsConsumed(state)

	local snapshot = CreatureState.getSnapshot(state)
	local predictedEvolution = EvolutionCalculator.resolveJuvenileEvolution(snapshot.affinities)

	return {
		success = true,
		reason = nil,
		feedId = feed.id,
		updatedAffinities = snapshot.affinities,
		totalFeedsConsumed = snapshot.totalFeedsConsumed,
		predictedEvolution = predictedEvolution,
	}
end

return FeedingService
