--!strict

--[[
	Server-side feed application and stage-aware evolution confirmation.
	Clients cannot submit form, rarity, influence, or roll outcomes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local CreatureTypes = require(Creatures:WaitForChild("CreatureTypes"))
local FeedDefinitions = require(Creatures:WaitForChild("FeedDefinitions"))
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))
local StageConfig = require(Creatures:WaitForChild("StageConfig"))

local CreatureState = require(script.Parent.CreatureState)

local FeedingService = {}

export type FeedFailureReason = "UnknownFeed" | "EvolutionReady"

export type FeedResult = {
	success: boolean,
	reason: FeedFailureReason?,
	feedId: string?,
	updatedAffinities: CreatureTypes.AffinityTotals?,
	stageAffinities: CreatureTypes.AffinityTotals?,
	heritageAffinities: CreatureTypes.AffinityTotals?,
	stageInfluences: CreatureTypes.InfluenceTotals?,
	heritageInfluences: CreatureTypes.InfluenceTotals?,
	stageEvolutionQuality: number?,
	qualityPromotionBonus: number?,
	basePromotionChance: number?,
	adjustedPromotionChance: number?,
	totalFeedsConsumed: number?,
	growthProgress: number?,
	requiredGrowth: number?,
	evolutionReady: boolean?,
	bonusFeedRemaining: number?,
	rarity: CreatureTypes.RarityId?,
	predictedNextFormId: string?,
	predictedBaseFormId: string?,
	predictedFinalFormId: string?,
	strongestInfluenceId: CreatureTypes.InfluenceId?,
	influenceStrengthLabel: CreatureTypes.InfluenceStrengthLabel?,
	predictedEvolution: CreatureTypes.JuvenileEvolutionResult?,
}

export type ConfirmEvolutionFailureReason =
	"NotReady"
	| "NotStageZero"
	| "InsufficientAffinity"
	| "InsufficientGrowth"
	| "InvalidRoll"
	| "UnsupportedStage"
	| "InvalidParentForm"
	| "NoRoute"
	| "AlreadyResolving"

export type ConfirmEvolutionResult = {
	success: boolean,
	reason: ConfirmEvolutionFailureReason?,
	formId: string?,
	lineageId: string?,
	baseFormId: string?,
	rarity: CreatureTypes.RarityId?,
	promoted: boolean?,
	roll: number?,
	stage: number?,
	dominantEffectiveAffinity: CreatureTypes.AffinityId?,
	qualifyingInfluenceId: CreatureTypes.InfluenceId?,
	snapshot: CreatureState.CreatureSnapshot?,
}

local function createServerRoll(): number
	return Random.new():NextNumber()
end

local function mapResolveReason(reason: CreatureTypes.EvolutionIneligibilityReason?): ConfirmEvolutionFailureReason
	if reason == "InvalidRoll" then
		return "InvalidRoll"
	elseif reason == "InsufficientGrowth" then
		return "InsufficientGrowth"
	elseif reason == "InsufficientAffinity" then
		return "InsufficientAffinity"
	elseif reason == "UnsupportedStage" then
		return "UnsupportedStage"
	elseif reason == "InvalidParentForm" then
		return "InvalidParentForm"
	elseif reason == "NoRoute" then
		return "NoRoute"
	elseif reason == "AlreadyResolving" then
		return "AlreadyResolving"
	end
	return "NotReady"
end

local function snapshotFeedFields(snapshot: CreatureState.CreatureSnapshot): FeedResult
	return {
		success = false,
		reason = nil,
		feedId = nil,
		updatedAffinities = snapshot.stageAffinities,
		stageAffinities = snapshot.stageAffinities,
		heritageAffinities = snapshot.heritageAffinities,
		stageInfluences = snapshot.stageInfluences,
		heritageInfluences = snapshot.heritageInfluences,
		stageEvolutionQuality = snapshot.stageEvolutionQuality,
		qualityPromotionBonus = snapshot.qualityPromotionBonus,
		basePromotionChance = snapshot.basePromotionChance,
		adjustedPromotionChance = snapshot.adjustedPromotionChance,
		totalFeedsConsumed = snapshot.totalFeedsConsumed,
		growthProgress = snapshot.growthProgress,
		requiredGrowth = snapshot.requiredGrowth,
		evolutionReady = snapshot.evolutionReady,
		bonusFeedRemaining = snapshot.bonusFeedRemaining,
		rarity = snapshot.rarity,
		predictedNextFormId = snapshot.predictedNextFormId,
		predictedBaseFormId = snapshot.predictedBaseFormId,
		predictedFinalFormId = snapshot.predictedFinalFormId,
		strongestInfluenceId = snapshot.strongestInfluenceId,
		influenceStrengthLabel = snapshot.influenceStrengthLabel,
		predictedEvolution = snapshot.predictedEvolution,
	}
end

function FeedingService.applyFeed(state: CreatureState.CreatureState, feedId: string): FeedResult
	local feed = FeedDefinitions.get(feedId)
	if feed == nil then
		return {
			success = false,
			reason = "UnknownFeed",
			feedId = feedId,
		}
	end

	if not CreatureState.canAcceptFeed(state) then
		local blocked = snapshotFeedFields(CreatureState.getSnapshot(state))
		blocked.success = false
		blocked.reason = "EvolutionReady"
		blocked.feedId = feedId
		return blocked
	end

	local usedBonusFeed = CreatureState.isEvolutionReady(state)
	if usedBonusFeed then
		CreatureState.consumeBonusFeedAllowance(state)
	end

	CreatureState.applyAffinityContribution(state, feed.affinityContribution)
	if feed.influenceContribution ~= nil then
		CreatureState.applyInfluenceContribution(state, feed.influenceContribution)
	end
	if feed.evolutionQuality > 0 then
		CreatureState.applyEvolutionQuality(state, feed.evolutionQuality)
	end
	CreatureState.applyGrowth(state, feed.growth)
	CreatureState.incrementFeedsConsumed(state)

	local successFields = snapshotFeedFields(CreatureState.getSnapshot(state))
	successFields.success = true
	successFields.reason = nil
	successFields.feedId = feed.id
	return successFields
end

function FeedingService.confirmEvolution(
	state: CreatureState.CreatureState,
	optionalRoll: number?
): ConfirmEvolutionResult
	local before = CreatureState.getSnapshot(state)

	if CreatureState.getEvolutionState(state) == "Resolving" then
		return {
			success = false,
			reason = "AlreadyResolving",
			snapshot = before,
		}
	end

	if not StageConfig.isSupportedEvolutionStage(state.stage) then
		return {
			success = false,
			reason = "UnsupportedStage",
			snapshot = before,
		}
	end

	if not CreatureState.isEvolutionReady(state) then
		local reason: ConfirmEvolutionFailureReason = "NotReady"
		if not EvolutionCalculator.hasSufficientGrowthForStage(state.stage, before.growthProgress) then
			reason = "InsufficientGrowth"
		elseif not EvolutionCalculator.hasSufficientAffinityForStage(
			state.stage,
			before.stageAffinities,
			before.heritageAffinities
		) then
			reason = "InsufficientAffinity"
		end
		return {
			success = false,
			reason = reason,
			snapshot = before,
		}
	end

	-- Stage 0 and Stage 1 both roll rarity with injected/server RNG.
	local roll: number? = nil
	if state.stage == 0 or state.stage == 1 then
		roll = if optionalRoll ~= nil then optionalRoll else createServerRoll()
	end

	local resolved = EvolutionCalculator.resolveEvolution({
		formId = before.formId,
		stage = before.stage,
		rarity = before.rarity,
		stageAffinities = before.stageAffinities,
		heritageAffinities = before.heritageAffinities,
		stageInfluences = before.stageInfluences,
		heritageInfluences = before.heritageInfluences,
		stageEvolutionQuality = before.stageEvolutionQuality,
		growthProgress = before.growthProgress,
		roll = roll,
	})

	if not resolved.eligible
		or resolved.nextFormId == nil
		or resolved.nextStage == nil
		or resolved.rarity == nil
		or resolved.heritageTransfer == nil
		or resolved.heritageInfluenceTransfer == nil
	then
		return {
			success = false,
			reason = mapResolveReason(resolved.reason),
			roll = resolved.roll,
			snapshot = before,
		}
	end

	if not CreatureState.beginResolving(state) then
		return {
			success = false,
			reason = "AlreadyResolving",
			snapshot = CreatureState.getSnapshot(state),
		}
	end

	local applyOk, applyErr = pcall(function()
		CreatureState.applyEvolution(
			state,
			resolved.nextFormId :: string,
			resolved.nextStage :: number,
			resolved.rarity :: CreatureTypes.RarityId,
			resolved.heritageTransfer :: CreatureTypes.AffinityTotals,
			resolved.heritageInfluenceTransfer :: CreatureTypes.InfluenceTotals,
			resolved.dominantEffectiveAffinity,
			resolved.qualifyingInfluenceId
		)
	end)

	if not applyOk then
		CreatureState.abortResolving(state)
		warn("[FeedingService] Evolution apply failed: " .. tostring(applyErr))
		return {
			success = false,
			reason = "NoRoute",
			roll = resolved.roll,
			snapshot = CreatureState.getSnapshot(state),
		}
	end

	local snapshot = CreatureState.getSnapshot(state)
	return {
		success = true,
		reason = nil,
		formId = snapshot.formId,
		lineageId = snapshot.lineageId,
		baseFormId = resolved.baseFormId,
		rarity = snapshot.rarity,
		promoted = resolved.promoted,
		roll = resolved.roll,
		stage = snapshot.stage,
		dominantEffectiveAffinity = resolved.dominantEffectiveAffinity,
		qualifyingInfluenceId = resolved.qualifyingInfluenceId,
		snapshot = snapshot,
	}
end

function FeedingService.confirmJuvenileEvolution(
	state: CreatureState.CreatureState,
	optionalRoll: number?
): ConfirmEvolutionResult
	if state.stage ~= 0 then
		return {
			success = false,
			reason = "NotStageZero",
			snapshot = CreatureState.getSnapshot(state),
		}
	end
	return FeedingService.confirmEvolution(state, optionalRoll)
end

return FeedingService
