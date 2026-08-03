--!strict

--[[
	Pure stage-aware evolution calculation.
	No Roblox services. No math.random. Deterministic when roll is injected.

	Effective affinity = stageAffinity + heritageAffinity * 0.25
	Stage 0 -> 1: affinity family + rarity roll (roll < 0.30 promotes).
	Stage 1 -> 2: parent form + dominant effective affinity via Stage2Routes,
	then optional specialized variant from qualifying stage influence.
	Rarity never decreases. Stage 2 preserves current rarity (no new roll).
]]

local CreatureTypes = require(script.Parent.CreatureTypes)
local LineageDefinitions = require(script.Parent.LineageDefinitions)
local StageConfig = require(script.Parent.StageConfig)
local Stage2Routes = require(script.Parent.Stage2Routes)
local SpecializedVariantRoutes = require(script.Parent.SpecializedVariantRoutes)

local EvolutionCalculator = {}

-- Back-compat exports for Stage 0 thresholds.
EvolutionCalculator.MINIMUM_TOTAL_AFFINITY = 30
EvolutionCalculator.REQUIRED_GROWTH = 50
EvolutionCalculator.UNCOMMON_PROMOTION_THRESHOLD = 0.30

local AFFINITY_TIE_PRIORITY: { CreatureTypes.AffinityId } = table.freeze({
	"Flesh",
	"Flora",
	"Mineral",
})

local INFLUENCE_TIE_PRIORITY: { CreatureTypes.InfluenceId } = table.freeze({
	"Arthropod",
	"Fungal",
	"Volcanic",
})

local FAMILY_LABELS: { [CreatureTypes.AffinityId]: string } = table.freeze({
	Flesh = "Flesh family",
	Flora = "Flora family",
	Mineral = "Mineral family",
})

export type EvolutionInput = {
	formId: CreatureTypes.FormId,
	stage: number,
	rarity: CreatureTypes.RarityId,
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals,
	stageInfluences: CreatureTypes.InfluenceTotals,
	heritageInfluences: CreatureTypes.InfluenceTotals,
	growthProgress: number,
	roll: number?,
}

export type InfluenceAssessment = {
	strongestInfluenceId: CreatureTypes.InfluenceId?,
	strongestInfluenceScore: number,
	strongestInfluenceShare: number,
	influenceStrengthLabel: CreatureTypes.InfluenceStrengthLabel,
	qualifyingInfluenceId: CreatureTypes.InfluenceId?,
	qualifies: boolean,
}

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function emptyInfluenceAssessment(): InfluenceAssessment
	return {
		strongestInfluenceId = nil,
		strongestInfluenceScore = 0,
		strongestInfluenceShare = 0,
		influenceStrengthLabel = "None",
		qualifyingInfluenceId = nil,
		qualifies = false,
	}
end

local function withInfluenceFields(
	prediction: {
		eligible: boolean,
		reason: CreatureTypes.EvolutionIneligibilityReason?,
		dominantEffectiveAffinity: CreatureTypes.AffinityId?,
		predictedNextFormId: CreatureTypes.FormId?,
		predictedBaseFormId: CreatureTypes.FormId?,
		predictedFinalFormId: CreatureTypes.FormId?,
		familyLabel: string?,
	},
	assessment: InfluenceAssessment
): CreatureTypes.EvolutionPrediction
	return {
		eligible = prediction.eligible,
		reason = prediction.reason,
		dominantEffectiveAffinity = prediction.dominantEffectiveAffinity,
		predictedNextFormId = prediction.predictedFinalFormId or prediction.predictedNextFormId,
		predictedBaseFormId = prediction.predictedBaseFormId,
		predictedFinalFormId = prediction.predictedFinalFormId or prediction.predictedNextFormId,
		familyLabel = prediction.familyLabel,
		strongestInfluenceId = assessment.strongestInfluenceId,
		strongestInfluenceScore = assessment.strongestInfluenceScore,
		strongestInfluenceShare = assessment.strongestInfluenceShare,
		influenceStrengthLabel = assessment.influenceStrengthLabel,
		qualifyingInfluenceId = assessment.qualifyingInfluenceId,
	}
end

function EvolutionCalculator.validateRoll(roll: number): number?
	if typeof(roll) ~= "number" or not isFiniteNumber(roll) then
		return nil
	end
	if roll < 0 or roll >= 1 then
		return nil
	end
	return roll
end

function EvolutionCalculator.clampRoll(roll: number): number?
	return EvolutionCalculator.validateRoll(roll)
end

function EvolutionCalculator.getTotalAffinity(affinityTotals: CreatureTypes.AffinityTotals): number
	return affinityTotals.Flesh + affinityTotals.Flora + affinityTotals.Mineral
end

function EvolutionCalculator.getTotalInfluence(influenceTotals: CreatureTypes.InfluenceTotals): number
	return influenceTotals.Arthropod + influenceTotals.Fungal + influenceTotals.Volcanic
end

function EvolutionCalculator.computeEffectiveAffinities(
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals
): CreatureTypes.AffinityTotals
	local weight = StageConfig.HERITAGE_EFFECTIVE_WEIGHT
	return {
		Flesh = stageAffinities.Flesh + heritageAffinities.Flesh * weight,
		Flora = stageAffinities.Flora + heritageAffinities.Flora * weight,
		Mineral = stageAffinities.Mineral + heritageAffinities.Mineral * weight,
	}
end

function EvolutionCalculator.computeHeritageTransfer(
	stageAffinities: CreatureTypes.AffinityTotals
): CreatureTypes.AffinityTotals
	local fraction = StageConfig.HERITAGE_TRANSFER_FRACTION
	return {
		Flesh = stageAffinities.Flesh * fraction,
		Flora = stageAffinities.Flora * fraction,
		Mineral = stageAffinities.Mineral * fraction,
	}
end

function EvolutionCalculator.computeHeritageInfluenceTransfer(
	stageInfluences: CreatureTypes.InfluenceTotals
): CreatureTypes.InfluenceTotals
	local fraction = StageConfig.HERITAGE_INFLUENCE_TRANSFER_FRACTION
	return {
		Arthropod = stageInfluences.Arthropod * fraction,
		Fungal = stageInfluences.Fungal * fraction,
		Volcanic = stageInfluences.Volcanic * fraction,
	}
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

function EvolutionCalculator.getInfluenceStrengthLabel(
	score: number,
	share: number,
	qualifies: boolean
): CreatureTypes.InfluenceStrengthLabel
	if score <= 0 then
		return "None"
	end
	if qualifies or (score >= StageConfig.INFLUENCE_QUALIFY_SCORE and share >= StageConfig.INFLUENCE_QUALIFY_SHARE) then
		return "Strong"
	end
	if score >= 12 then
		return "Developing"
	end
	return "Trace"
end

function EvolutionCalculator.assessStageInfluences(
	stageInfluences: CreatureTypes.InfluenceTotals
): InfluenceAssessment
	local total = EvolutionCalculator.getTotalInfluence(stageInfluences)
	if total <= 0 then
		return emptyInfluenceAssessment()
	end

	local strongestId: CreatureTypes.InfluenceId = INFLUENCE_TIE_PRIORITY[1]
	local strongestScore = stageInfluences[strongestId]

	for index = 2, #INFLUENCE_TIE_PRIORITY do
		local influenceId = INFLUENCE_TIE_PRIORITY[index]
		local score = stageInfluences[influenceId]
		if score > strongestScore then
			strongestId = influenceId
			strongestScore = score
		end
	end

	local share = strongestScore / total
	local qualifies = strongestScore >= StageConfig.INFLUENCE_QUALIFY_SCORE
		and share >= StageConfig.INFLUENCE_QUALIFY_SHARE

	return {
		strongestInfluenceId = if strongestScore > 0 then strongestId else nil,
		strongestInfluenceScore = strongestScore,
		strongestInfluenceShare = share,
		influenceStrengthLabel = EvolutionCalculator.getInfluenceStrengthLabel(strongestScore, share, qualifies),
		qualifyingInfluenceId = if qualifies then strongestId else nil,
		qualifies = qualifies,
	}
end

function EvolutionCalculator.resolveSpecializedVariant(
	baseFormId: CreatureTypes.FormId,
	stageInfluences: CreatureTypes.InfluenceTotals
): (CreatureTypes.FormId, CreatureTypes.InfluenceId?)
	local assessment = EvolutionCalculator.assessStageInfluences(stageInfluences)
	if not assessment.qualifies or assessment.qualifyingInfluenceId == nil then
		return baseFormId, nil
	end
	local finalFormId = SpecializedVariantRoutes.resolve(baseFormId, assessment.qualifyingInfluenceId)
	if LineageDefinitions.get(finalFormId) == nil then
		return baseFormId, assessment.qualifyingInfluenceId
	end
	return finalFormId, assessment.qualifyingInfluenceId
end

function EvolutionCalculator.hasSufficientAffinityForStage(
	stage: number,
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals
): boolean
	local minimum = StageConfig.getMinimumTotalAffinity(stage)
	if minimum == nil then
		return false
	end
	local effective = EvolutionCalculator.computeEffectiveAffinities(stageAffinities, heritageAffinities)
	return EvolutionCalculator.getTotalAffinity(effective) >= minimum
end

function EvolutionCalculator.hasSufficientGrowthForStage(stage: number, growthProgress: number): boolean
	local required = StageConfig.getRequiredGrowth(stage)
	if required == nil then
		return false
	end
	return growthProgress >= required
end

function EvolutionCalculator.hasSufficientAffinity(affinityTotals: CreatureTypes.AffinityTotals): boolean
	return EvolutionCalculator.getTotalAffinity(affinityTotals) >= EvolutionCalculator.MINIMUM_TOTAL_AFFINITY
end

function EvolutionCalculator.hasSufficientGrowth(growthProgress: number): boolean
	return growthProgress >= EvolutionCalculator.REQUIRED_GROWTH
end

function EvolutionCalculator.isEvolutionReady(
	affinityTotals: CreatureTypes.AffinityTotals,
	growthProgress: number
): boolean
	return EvolutionCalculator.hasSufficientAffinity(affinityTotals)
		and EvolutionCalculator.hasSufficientGrowth(growthProgress)
end

function EvolutionCalculator.isEvolutionReadyForStage(
	stage: number,
	stageAffinities: CreatureTypes.AffinityTotals,
	heritageAffinities: CreatureTypes.AffinityTotals,
	growthProgress: number
): boolean
	if not StageConfig.isSupportedEvolutionStage(stage) then
		return false
	end
	return EvolutionCalculator.hasSufficientGrowthForStage(stage, growthProgress)
		and EvolutionCalculator.hasSufficientAffinityForStage(stage, stageAffinities, heritageAffinities)
end

local function predictStage0(
	effective: CreatureTypes.AffinityTotals,
	assessment: InfluenceAssessment
): CreatureTypes.EvolutionPrediction
	if EvolutionCalculator.getTotalAffinity(effective) < EvolutionCalculator.MINIMUM_TOTAL_AFFINITY then
		return withInfluenceFields({
			eligible = false,
			reason = "InsufficientAffinity",
			dominantEffectiveAffinity = nil,
			predictedNextFormId = nil,
			predictedBaseFormId = nil,
			predictedFinalFormId = nil,
			familyLabel = nil,
		}, assessment)
	end

	local dominant = EvolutionCalculator.getDominantAffinity(effective)
	local familyLineageId = LineageDefinitions.getFamilyLineageId(dominant)
	assert(familyLineageId ~= nil, "Missing family lineage for dominant affinity")

	return withInfluenceFields({
		eligible = true,
		reason = nil,
		dominantEffectiveAffinity = dominant,
		predictedNextFormId = familyLineageId,
		predictedBaseFormId = familyLineageId,
		predictedFinalFormId = familyLineageId,
		familyLabel = FAMILY_LABELS[dominant],
	}, assessment)
end

local function predictStage1(
	formId: CreatureTypes.FormId,
	effective: CreatureTypes.AffinityTotals,
	stageInfluences: CreatureTypes.InfluenceTotals,
	assessment: InfluenceAssessment
): CreatureTypes.EvolutionPrediction
	if EvolutionCalculator.getTotalAffinity(effective) < (StageConfig.getMinimumTotalAffinity(1) or 30) then
		return withInfluenceFields({
			eligible = false,
			reason = "InsufficientAffinity",
			dominantEffectiveAffinity = nil,
			predictedNextFormId = nil,
			predictedBaseFormId = nil,
			predictedFinalFormId = nil,
			familyLabel = nil,
		}, assessment)
	end

	if Stage2Routes.getRouteTable(formId) == nil then
		return withInfluenceFields({
			eligible = false,
			reason = "InvalidParentForm",
			dominantEffectiveAffinity = nil,
			predictedNextFormId = nil,
			predictedBaseFormId = nil,
			predictedFinalFormId = nil,
			familyLabel = nil,
		}, assessment)
	end

	local dominant = EvolutionCalculator.getDominantAffinity(effective)
	local baseFormId = Stage2Routes.resolve(formId, dominant)
	if baseFormId == nil then
		return withInfluenceFields({
			eligible = false,
			reason = "NoRoute",
			dominantEffectiveAffinity = dominant,
			predictedNextFormId = nil,
			predictedBaseFormId = nil,
			predictedFinalFormId = nil,
			familyLabel = FAMILY_LABELS[dominant],
		}, assessment)
	end

	local finalFormId, qualifyingId = EvolutionCalculator.resolveSpecializedVariant(baseFormId, stageInfluences)
	local predictionAssessment = assessment
	if qualifyingId ~= nil then
		predictionAssessment = {
			strongestInfluenceId = assessment.strongestInfluenceId,
			strongestInfluenceScore = assessment.strongestInfluenceScore,
			strongestInfluenceShare = assessment.strongestInfluenceShare,
			influenceStrengthLabel = assessment.influenceStrengthLabel,
			qualifyingInfluenceId = qualifyingId,
			qualifies = true,
		}
	end

	return withInfluenceFields({
		eligible = true,
		reason = nil,
		dominantEffectiveAffinity = dominant,
		predictedNextFormId = finalFormId,
		predictedBaseFormId = baseFormId,
		predictedFinalFormId = finalFormId,
		familyLabel = FAMILY_LABELS[dominant],
	}, predictionAssessment)
end

function EvolutionCalculator.predictEvolution(input: EvolutionInput): CreatureTypes.EvolutionPrediction
	local effective = EvolutionCalculator.computeEffectiveAffinities(
		input.stageAffinities,
		input.heritageAffinities
	)
	local assessment = EvolutionCalculator.assessStageInfluences(input.stageInfluences)

	if input.stage == 0 then
		return predictStage0(effective, assessment)
	elseif input.stage == 1 then
		return predictStage1(input.formId, effective, input.stageInfluences, assessment)
	end

	return withInfluenceFields({
		eligible = false,
		reason = "UnsupportedStage",
		dominantEffectiveAffinity = nil,
		predictedNextFormId = nil,
		predictedBaseFormId = nil,
		predictedFinalFormId = nil,
		familyLabel = nil,
	}, assessment)
end

function EvolutionCalculator.resolveJuvenileEvolution(
	affinityTotals: CreatureTypes.AffinityTotals
): CreatureTypes.JuvenileEvolutionResult
	local prediction = predictStage0(affinityTotals, emptyInfluenceAssessment())
	return {
		eligible = prediction.eligible,
		reason = prediction.reason,
		dominantAffinity = prediction.dominantEffectiveAffinity,
		familyLineageId = prediction.predictedNextFormId,
		familyLabel = prediction.familyLabel,
	}
end

function EvolutionCalculator.resolveJuvenileEvolutionWithGrowth(
	affinityTotals: CreatureTypes.AffinityTotals,
	growthProgress: number
): CreatureTypes.JuvenileEvolutionResult
	if not EvolutionCalculator.hasSufficientGrowth(growthProgress) then
		return {
			eligible = false,
			reason = "InsufficientGrowth",
			dominantAffinity = nil,
			familyLineageId = nil,
			familyLabel = nil,
		}
	end
	return EvolutionCalculator.resolveJuvenileEvolution(affinityTotals)
end

local function ineligibleResolved(
	reason: CreatureTypes.EvolutionIneligibilityReason,
	roll: number?
): CreatureTypes.ResolvedEvolution
	return {
		eligible = false,
		reason = reason,
		dominantEffectiveAffinity = nil,
		nextFormId = nil,
		baseFormId = nil,
		nextStage = nil,
		rarity = nil,
		promoted = nil,
		roll = roll,
		heritageTransfer = nil,
		heritageInfluenceTransfer = nil,
		qualifyingInfluenceId = nil,
	}
end

local function resolveStage0(input: EvolutionInput): CreatureTypes.ResolvedEvolution
	local roll = input.roll
	if roll == nil then
		return ineligibleResolved("InvalidRoll", nil)
	end

	local validatedRoll = EvolutionCalculator.validateRoll(roll)
	if validatedRoll == nil then
		return ineligibleResolved("InvalidRoll", nil)
	end

	if not EvolutionCalculator.hasSufficientGrowthForStage(0, input.growthProgress) then
		return ineligibleResolved("InsufficientGrowth", validatedRoll)
	end

	if not EvolutionCalculator.hasSufficientAffinityForStage(0, input.stageAffinities, input.heritageAffinities) then
		return ineligibleResolved("InsufficientAffinity", validatedRoll)
	end

	local effective = EvolutionCalculator.computeEffectiveAffinities(
		input.stageAffinities,
		input.heritageAffinities
	)
	local dominant = EvolutionCalculator.getDominantAffinity(effective)
	local rolledRarity: CreatureTypes.RarityId = if validatedRoll < EvolutionCalculator.UNCOMMON_PROMOTION_THRESHOLD
		then "Uncommon"
		else "Common"
	local resultingRarity = CreatureTypes.maxRarity(input.rarity, rolledRarity)
	local lineage = LineageDefinitions.getJuvenileByAffinityAndRarity(dominant, resultingRarity)
	assert(lineage ~= nil, "Missing juvenile lineage for affinity/rarity pair")

	return {
		eligible = true,
		reason = nil,
		dominantEffectiveAffinity = dominant,
		nextFormId = lineage.id,
		baseFormId = lineage.id,
		nextStage = 1,
		rarity = resultingRarity,
		promoted = CreatureTypes.getRarityRank(resultingRarity) > CreatureTypes.getRarityRank(input.rarity),
		roll = validatedRoll,
		heritageTransfer = EvolutionCalculator.computeHeritageTransfer(input.stageAffinities),
		heritageInfluenceTransfer = EvolutionCalculator.computeHeritageInfluenceTransfer(input.stageInfluences),
		qualifyingInfluenceId = nil,
	}
end

local function resolveStage1(input: EvolutionInput): CreatureTypes.ResolvedEvolution
	if not EvolutionCalculator.hasSufficientGrowthForStage(1, input.growthProgress) then
		return ineligibleResolved("InsufficientGrowth", nil)
	end

	if Stage2Routes.getRouteTable(input.formId) == nil then
		return ineligibleResolved("InvalidParentForm", nil)
	end

	if not EvolutionCalculator.hasSufficientAffinityForStage(1, input.stageAffinities, input.heritageAffinities) then
		return ineligibleResolved("InsufficientAffinity", nil)
	end

	local effective = EvolutionCalculator.computeEffectiveAffinities(
		input.stageAffinities,
		input.heritageAffinities
	)
	local dominant = EvolutionCalculator.getDominantAffinity(effective)
	local baseFormId = Stage2Routes.resolve(input.formId, dominant)
	if baseFormId == nil or LineageDefinitions.get(baseFormId) == nil then
		return {
			eligible = false,
			reason = "NoRoute",
			dominantEffectiveAffinity = dominant,
			nextFormId = nil,
			baseFormId = nil,
			nextStage = nil,
			rarity = nil,
			promoted = nil,
			roll = nil,
			heritageTransfer = nil,
			heritageInfluenceTransfer = nil,
			qualifyingInfluenceId = nil,
		}
	end

	local finalFormId, qualifyingId = EvolutionCalculator.resolveSpecializedVariant(
		baseFormId,
		input.stageInfluences
	)

	return {
		eligible = true,
		reason = nil,
		dominantEffectiveAffinity = dominant,
		nextFormId = finalFormId,
		baseFormId = baseFormId,
		nextStage = 2,
		rarity = input.rarity,
		promoted = false,
		roll = nil,
		heritageTransfer = EvolutionCalculator.computeHeritageTransfer(input.stageAffinities),
		heritageInfluenceTransfer = EvolutionCalculator.computeHeritageInfluenceTransfer(input.stageInfluences),
		qualifyingInfluenceId = qualifyingId,
	}
end

function EvolutionCalculator.resolveEvolution(input: EvolutionInput): CreatureTypes.ResolvedEvolution
	if input.stage == 0 then
		return resolveStage0(input)
	elseif input.stage == 1 then
		return resolveStage1(input)
	end

	return ineligibleResolved("UnsupportedStage", nil)
end

function EvolutionCalculator.resolveJuvenilePromotion(
	affinityTotals: CreatureTypes.AffinityTotals,
	growthProgress: number,
	currentRarity: CreatureTypes.RarityId,
	roll: number
): CreatureTypes.ResolvedJuvenileEvolution
	local resolved = EvolutionCalculator.resolveEvolution({
		formId = "ProtoRex",
		stage = 0,
		rarity = currentRarity,
		stageAffinities = affinityTotals,
		heritageAffinities = CreatureTypes.createEmptyAffinities(),
		stageInfluences = CreatureTypes.createEmptyInfluences(),
		heritageInfluences = CreatureTypes.createEmptyInfluences(),
		growthProgress = growthProgress,
		roll = roll,
	})

	return {
		eligible = resolved.eligible,
		reason = resolved.reason,
		dominantAffinity = resolved.dominantEffectiveAffinity,
		lineageId = resolved.nextFormId,
		rarity = resolved.rarity,
		promoted = resolved.promoted,
		roll = resolved.roll,
	}
end

return EvolutionCalculator
