--!strict

--[[
	Authoritative runtime state for a single creature.
	Feeds update stageAffinities and stageInfluences only.
	On evolution, 25% of affinities and 20% of influences transfer to heritage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local CreatureTypes = require(Creatures:WaitForChild("CreatureTypes"))
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))
local StageConfig = require(Creatures:WaitForChild("StageConfig"))

local CreatureState = {}

export type CreatureState = {
	creatureId: string,
	ownerUserId: number,
	lineageId: string,
	stage: number,
	totalFeedsConsumed: number,
}

export type LineageHistoryEntry = {
	stage: number,
	formId: string,
	routeAffinity: CreatureTypes.AffinityId?,
	specializedInfluence: CreatureTypes.InfluenceId?,
	rarityAtStage: CreatureTypes.RarityId?,
}

export type CreatureSnapshot = {
	creatureId: string,
	ownerUserId: number,
	formId: string,
	lineageId: string,
	stage: number,
	rarity: CreatureTypes.RarityId,
	evolutionState: CreatureTypes.EvolutionStateId,
	-- Back-compat alias of stageAffinities for older harness/test code.
	affinities: CreatureTypes.AffinityTotals,
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals,
	stageInfluences: CreatureTypes.InfluenceTotals,
	heritageInfluences: CreatureTypes.InfluenceTotals,
	stageEvolutionQuality: number,
	qualityPromotionBonus: number,
	basePromotionChance: number,
	adjustedPromotionChance: number,
	totalFeedsConsumed: number,
	growthProgress: number,
	requiredGrowth: number,
	evolutionReady: boolean,
	bonusFeedRemaining: number,
	dominantEffectiveAffinity: CreatureTypes.AffinityId?,
	predictedNextFormId: string?,
	predictedBaseFormId: string?,
	predictedFinalFormId: string?,
	strongestInfluenceId: CreatureTypes.InfluenceId?,
	strongestInfluenceScore: number,
	strongestInfluenceShare: number,
	influenceStrengthLabel: CreatureTypes.InfluenceStrengthLabel,
	-- Stage 0 family / Stage 1+ next form, exposed in legacy prediction fields for tests.
	predictedEvolution: CreatureTypes.JuvenileEvolutionResult,
	lineageHistory: { LineageHistoryEntry },
}

type PrivateState = {
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals,
	stageInfluences: CreatureTypes.InfluenceTotals,
	heritageInfluences: CreatureTypes.InfluenceTotals,
	stageEvolutionQuality: number,
	rarity: CreatureTypes.RarityId,
	growthProgress: number,
	evolutionReady: boolean,
	evolutionState: CreatureTypes.EvolutionStateId,
	bonusFeedRemaining: number,
	lineageHistory: { LineageHistoryEntry },
}

local function copyLineageHistory(history: { LineageHistoryEntry }): { LineageHistoryEntry }
	local result: { LineageHistoryEntry } = {}
	for _, entry in history do
		table.insert(result, {
			stage = entry.stage,
			formId = entry.formId,
			routeAffinity = entry.routeAffinity,
			specializedInfluence = entry.specializedInfluence,
			rarityAtStage = entry.rarityAtStage,
		})
	end
	return result
end

local privateByState: { [CreatureState]: PrivateState } = setmetatable({}, { __mode = "k" }) :: any

local function copyAffinities(affinities: CreatureTypes.AffinityTotals): CreatureTypes.AffinityTotals
	return CreatureTypes.copyAffinities(affinities)
end

local function copyInfluences(influences: CreatureTypes.InfluenceTotals): CreatureTypes.InfluenceTotals
	return CreatureTypes.copyInfluences(influences)
end

local function getPrivate(state: CreatureState): PrivateState
	local privateState = privateByState[state]
	assert(privateState ~= nil, "CreatureState private data missing for state")
	return privateState
end

local function buildPrediction(state: CreatureState, privateState: PrivateState): CreatureTypes.EvolutionPrediction
	return EvolutionCalculator.predictEvolution({
		formId = state.lineageId,
		stage = state.stage,
		rarity = privateState.rarity,
		stageAffinities = privateState.stageAffinities,
		heritageAffinities = privateState.heritageAffinities,
		stageInfluences = privateState.stageInfluences,
		heritageInfluences = privateState.heritageInfluences,
		stageEvolutionQuality = privateState.stageEvolutionQuality,
		growthProgress = privateState.growthProgress,
		roll = nil,
	})
end

local function refreshEvolutionReady(state: CreatureState): ()
	local privateState = getPrivate(state)
	if privateState.evolutionState == "Resolving" then
		return
	end

	if not StageConfig.isSupportedEvolutionStage(state.stage) then
		privateState.evolutionReady = false
		privateState.bonusFeedRemaining = 0
		privateState.evolutionState = "Growing"
		return
	end

	local wasReady = privateState.evolutionReady
	local ready = EvolutionCalculator.isEvolutionReadyForStage(
		state.stage,
		privateState.stageAffinities,
		privateState.heritageAffinities,
		privateState.growthProgress
	)
	privateState.evolutionReady = ready
	privateState.evolutionState = if ready then "Ready" else "Growing"

	if ready and not wasReady then
		privateState.bonusFeedRemaining = 1
	elseif not ready then
		privateState.bonusFeedRemaining = 0
	end
end

function CreatureState.createProtoRex(creatureId: string, ownerUserId: number): CreatureState
	local state: CreatureState = {
		creatureId = creatureId,
		ownerUserId = ownerUserId,
		lineageId = "ProtoRex",
		stage = 0,
		totalFeedsConsumed = 0,
	}
	privateByState[state] = {
		stageAffinities = CreatureTypes.createEmptyAffinities(),
		heritageAffinities = CreatureTypes.createEmptyAffinities(),
		stageInfluences = CreatureTypes.createEmptyInfluences(),
		heritageInfluences = CreatureTypes.createEmptyInfluences(),
		stageEvolutionQuality = 0,
		rarity = "Common",
		growthProgress = 0,
		evolutionReady = false,
		evolutionState = "Growing",
		bonusFeedRemaining = 0,
		lineageHistory = {
			{
				stage = 0,
				formId = "ProtoRex",
				routeAffinity = nil,
				specializedInfluence = nil,
				rarityAtStage = "Common",
			},
		},
	}
	return state
end

function CreatureState.getFormId(state: CreatureState): string
	return state.lineageId
end

function CreatureState.getAffinities(state: CreatureState): CreatureTypes.AffinityTotals
	return copyAffinities(getPrivate(state).stageAffinities)
end

function CreatureState.getStageAffinities(state: CreatureState): CreatureTypes.AffinityTotals
	return copyAffinities(getPrivate(state).stageAffinities)
end

function CreatureState.getHeritageAffinities(state: CreatureState): CreatureTypes.AffinityTotals
	return copyAffinities(getPrivate(state).heritageAffinities)
end

function CreatureState.getStageInfluences(state: CreatureState): CreatureTypes.InfluenceTotals
	return copyInfluences(getPrivate(state).stageInfluences)
end

function CreatureState.getHeritageInfluences(state: CreatureState): CreatureTypes.InfluenceTotals
	return copyInfluences(getPrivate(state).heritageInfluences)
end

function CreatureState.getStageEvolutionQuality(state: CreatureState): number
	return getPrivate(state).stageEvolutionQuality
end

function CreatureState.getRarity(state: CreatureState): CreatureTypes.RarityId
	return getPrivate(state).rarity
end

function CreatureState.getGrowthProgress(state: CreatureState): number
	return getPrivate(state).growthProgress
end

function CreatureState.getEvolutionState(state: CreatureState): CreatureTypes.EvolutionStateId
	return getPrivate(state).evolutionState
end

function CreatureState.isEvolutionReady(state: CreatureState): boolean
	return getPrivate(state).evolutionReady
end

function CreatureState.getBonusFeedRemaining(state: CreatureState): number
	return getPrivate(state).bonusFeedRemaining
end

function CreatureState.canAcceptFeed(state: CreatureState): boolean
	local privateState = getPrivate(state)
	if privateState.evolutionState == "Resolving" then
		return false
	end
	if not privateState.evolutionReady then
		return true
	end
	return privateState.bonusFeedRemaining > 0
end

function CreatureState.getSnapshot(state: CreatureState): CreatureSnapshot
	local privateState = getPrivate(state)
	local stageAffinities = copyAffinities(privateState.stageAffinities)
	local heritageAffinities = copyAffinities(privateState.heritageAffinities)
	local stageInfluences = copyInfluences(privateState.stageInfluences)
	local heritageInfluences = copyInfluences(privateState.heritageInfluences)
	local prediction = buildPrediction(state, privateState)
	local requiredGrowth = StageConfig.getRequiredGrowth(state.stage) or 0

	return {
		creatureId = state.creatureId,
		ownerUserId = state.ownerUserId,
		formId = state.lineageId,
		lineageId = state.lineageId,
		stage = state.stage,
		rarity = privateState.rarity,
		evolutionState = privateState.evolutionState,
		affinities = stageAffinities,
		stageAffinities = stageAffinities,
		heritageAffinities = heritageAffinities,
		stageInfluences = stageInfluences,
		heritageInfluences = heritageInfluences,
		stageEvolutionQuality = privateState.stageEvolutionQuality,
		qualityPromotionBonus = prediction.qualityPromotionBonus,
		basePromotionChance = prediction.basePromotionChance,
		adjustedPromotionChance = prediction.adjustedPromotionChance,
		totalFeedsConsumed = state.totalFeedsConsumed,
		growthProgress = privateState.growthProgress,
		requiredGrowth = requiredGrowth,
		evolutionReady = privateState.evolutionReady,
		bonusFeedRemaining = privateState.bonusFeedRemaining,
		dominantEffectiveAffinity = prediction.dominantEffectiveAffinity,
		predictedNextFormId = prediction.predictedNextFormId,
		predictedBaseFormId = prediction.predictedBaseFormId,
		predictedFinalFormId = prediction.predictedFinalFormId,
		strongestInfluenceId = prediction.strongestInfluenceId,
		strongestInfluenceScore = prediction.strongestInfluenceScore,
		strongestInfluenceShare = prediction.strongestInfluenceShare,
		influenceStrengthLabel = prediction.influenceStrengthLabel,
		predictedEvolution = {
			eligible = prediction.eligible,
			reason = prediction.reason,
			dominantAffinity = prediction.dominantEffectiveAffinity,
			familyLineageId = prediction.predictedNextFormId,
			familyLabel = prediction.familyLabel,
		},
		lineageHistory = copyLineageHistory(privateState.lineageHistory),
	}
end

function CreatureState.getLineageHistory(state: CreatureState): { LineageHistoryEntry }
	return copyLineageHistory(getPrivate(state).lineageHistory)
end

function CreatureState.appendLineageHistory(state: CreatureState, entry: LineageHistoryEntry): ()
	local privateState = getPrivate(state)
	table.insert(privateState.lineageHistory, {
		stage = entry.stage,
		formId = entry.formId,
		routeAffinity = entry.routeAffinity,
		specializedInfluence = entry.specializedInfluence,
		rarityAtStage = entry.rarityAtStage,
	})
end

function CreatureState.applyAffinityContribution(
	state: CreatureState,
	contribution: CreatureTypes.AffinityTotals
): ()
	local affinities = getPrivate(state).stageAffinities
	affinities.Flesh += contribution.Flesh
	affinities.Flora += contribution.Flora
	affinities.Mineral += contribution.Mineral
	refreshEvolutionReady(state)
end

function CreatureState.applyInfluenceContribution(
	state: CreatureState,
	contribution: CreatureTypes.InfluenceTotals
): ()
	local influences = getPrivate(state).stageInfluences
	influences.Arthropod += contribution.Arthropod
	influences.Fungal += contribution.Fungal
	influences.Volcanic += contribution.Volcanic
end

function CreatureState.applyEvolutionQuality(state: CreatureState, qualityAmount: number): ()
	if typeof(qualityAmount) ~= "number" or qualityAmount ~= qualityAmount or qualityAmount <= 0 then
		return
	end
	local privateState = getPrivate(state)
	privateState.stageEvolutionQuality += qualityAmount
	if privateState.stageEvolutionQuality < 0 then
		privateState.stageEvolutionQuality = 0
	end
end

function CreatureState.applyGrowth(state: CreatureState, growthAmount: number): ()
	local privateState = getPrivate(state)
	privateState.growthProgress += growthAmount
	refreshEvolutionReady(state)
end

function CreatureState.consumeBonusFeedAllowance(state: CreatureState): ()
	local privateState = getPrivate(state)
	if privateState.bonusFeedRemaining > 0 then
		privateState.bonusFeedRemaining -= 1
	end
end

function CreatureState.incrementFeedsConsumed(state: CreatureState): ()
	state.totalFeedsConsumed += 1
end

function CreatureState.beginResolving(state: CreatureState): boolean
	local privateState = getPrivate(state)
	if privateState.evolutionState == "Resolving" then
		return false
	end
	if not privateState.evolutionReady then
		return false
	end
	privateState.evolutionState = "Resolving"
	return true
end

function CreatureState.abortResolving(state: CreatureState): ()
	local privateState = getPrivate(state)
	if privateState.evolutionState == "Resolving" then
		privateState.evolutionState = if privateState.evolutionReady then "Ready" else "Growing"
	end
end

function CreatureState.applyEvolution(
	state: CreatureState,
	nextFormId: string,
	nextStage: number,
	rarity: CreatureTypes.RarityId,
	heritageTransfer: CreatureTypes.AffinityTotals,
	heritageInfluenceTransfer: CreatureTypes.InfluenceTotals?,
	routeAffinity: CreatureTypes.AffinityId?,
	specializedInfluence: CreatureTypes.InfluenceId?
): ()
	local privateState = getPrivate(state)
	assert(privateState.evolutionState == "Resolving", "Evolution apply requires Resolving state")

	local effective = EvolutionCalculator.computeEffectiveAffinities(
		privateState.stageAffinities,
		privateState.heritageAffinities
	)
	local derivedRoute = routeAffinity or EvolutionCalculator.getDominantAffinity(effective)
	local derivedSpecialization = specializedInfluence

	local heritage = privateState.heritageAffinities
	heritage.Flesh += heritageTransfer.Flesh
	heritage.Flora += heritageTransfer.Flora
	heritage.Mineral += heritageTransfer.Mineral

	local influenceTransfer = heritageInfluenceTransfer
		or EvolutionCalculator.computeHeritageInfluenceTransfer(privateState.stageInfluences)
	local heritageInfluences = privateState.heritageInfluences
	heritageInfluences.Arthropod += influenceTransfer.Arthropod
	heritageInfluences.Fungal += influenceTransfer.Fungal
	heritageInfluences.Volcanic += influenceTransfer.Volcanic

	state.lineageId = nextFormId
	state.stage = nextStage
	privateState.rarity = rarity
	privateState.stageAffinities = CreatureTypes.createEmptyAffinities()
	privateState.stageInfluences = CreatureTypes.createEmptyInfluences()
	privateState.stageEvolutionQuality = 0
	privateState.growthProgress = 0
	privateState.evolutionReady = false
	privateState.bonusFeedRemaining = 0
	privateState.evolutionState = "Growing"

	table.insert(privateState.lineageHistory, {
		stage = nextStage,
		formId = nextFormId,
		routeAffinity = derivedRoute,
		specializedInfluence = derivedSpecialization,
		rarityAtStage = rarity,
	})
end

function CreatureState.applyJuvenileEvolution(
	state: CreatureState,
	lineageId: string,
	rarity: CreatureTypes.RarityId
): ()
	local privateState = getPrivate(state)
	if privateState.evolutionState ~= "Resolving" then
		local began = CreatureState.beginResolving(state)
		assert(began, "Cannot evolve while evolutionReady is false")
	end
	assert(state.stage == 0, "Juvenile evolution only applies at stage 0")

	local transfer = EvolutionCalculator.computeHeritageTransfer(privateState.stageAffinities)
	local influenceTransfer = EvolutionCalculator.computeHeritageInfluenceTransfer(privateState.stageInfluences)
	local effective = EvolutionCalculator.computeEffectiveAffinities(
		privateState.stageAffinities,
		privateState.heritageAffinities
	)
	local dominant = EvolutionCalculator.getDominantAffinity(effective)
	CreatureState.applyEvolution(state, lineageId, 1, rarity, transfer, influenceTransfer, dominant, nil)
end

return CreatureState
