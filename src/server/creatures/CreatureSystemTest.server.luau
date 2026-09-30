--!strict

--[[
	Vertical-slice tests for Stage 0->1 and Stage 1->2 evolution.
	Forced rolls make Common/Uncommon Stage 0 outcomes deterministic.

	Roll policy under test (Stage 0 only):
	- Valid rolls are finite numbers in [0, 1).
	- Invalid rolls (NaN, inf, < 0, >= 1) are rejected.
	- roll < 0.30 → Uncommon; roll >= 0.30 → Common.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))
local FeedDefinitions = require(Creatures:WaitForChild("FeedDefinitions"))
local LineageDefinitions = require(Creatures:WaitForChild("LineageDefinitions"))
local StageConfig = require(Creatures:WaitForChild("StageConfig"))
local Stage2Routes = require(Creatures:WaitForChild("Stage2Routes"))
local ConveyorSpawnWeights = require(Creatures:WaitForChild("ConveyorSpawnWeights"))
local CreatureTypes = require(Creatures:WaitForChild("CreatureTypes"))

local CreatureState = require(script.Parent.CreatureState)
local FeedingService = require(script.Parent.FeedingService)
local CreatureVisualService = require(script.Parent.CreatureVisualService)

-- Common: at/above threshold. Uncommon: strictly below threshold.
local COMMON_ROLL = 0.30
local UNCOMMON_ROLL = 0.299999999
local BOUNDARY_COMMON_ROLL = 0.30
local JUST_BELOW_UNCOMMON_ROLL = 0.299999999

local function printState(label: string, state: CreatureState.CreatureState): ()
	local snapshot = CreatureState.getSnapshot(state)
	print(
		string.format(
			"[CreatureSystemTest] %s | lineage=%s rarity=%s stage=%d feeds=%d growth=%d/%d ready=%s family=%s",
			label,
			snapshot.lineageId,
			snapshot.rarity,
			snapshot.stage,
			snapshot.totalFeedsConsumed,
			snapshot.growthProgress,
			snapshot.requiredGrowth,
			tostring(snapshot.evolutionReady),
			tostring(snapshot.predictedEvolution.familyLabel)
		)
	)
end

local function feedToReadyFlesh(state: CreatureState.CreatureState): ()
	local feedSequence = { "RawMeat", "RawMeat", "RawMeat", "CrystalChunk", "LeafBundle" }
	for _, feedId in feedSequence do
		local result = FeedingService.applyFeed(state, feedId)
		assert(result.success == true, string.format("Expected feed %s to succeed", feedId))
	end
end

local function feedToReadyFlora(state: CreatureState.CreatureState): ()
	-- Use basic LeafBundle only so Stage 0 tests do not accumulate premium quality.
	for _ = 1, 5 do
		assert(FeedingService.applyFeed(state, "LeafBundle").success)
	end
end

local function feedToReadyMineral(state: CreatureState.CreatureState): ()
	for _ = 1, 3 do
		assert(FeedingService.applyFeed(state, "BoneFragments").success)
	end
	assert(FeedingService.applyFeed(state, "CrystalChunk").success)
	assert(FeedingService.applyFeed(state, "CrystalChunk").success)
end

assert(StageConfig.getRequiredGrowth(0) == 50, "Stage 0 required growth must be 50")
assert(StageConfig.getRequiredGrowth(1) == 100, "Stage 1 required growth must be 100")
assert(StageConfig.HERITAGE_TRANSFER_FRACTION == 0.25, "Heritage transfer must be 25%")
assert(StageConfig.HERITAGE_EFFECTIVE_WEIGHT == 0.25, "Heritage effective weight must be 0.25")

-- Definition coverage: juveniles + Stage 2 forms.
for _, lineageId in { "Fangling", "Bloodfang", "Mossback", "Thornhide", "Stonehide", "Crystalback" } do
	local def = LineageDefinitions.get(lineageId)
	assert(def ~= nil, "Missing lineage definition: " .. lineageId)
	assert(def.rarity ~= nil, "Lineage must declare rarity: " .. lineageId)
	assert(def.placeholderVisualProfileId ~= nil, "Lineage must declare visual profile: " .. lineageId)
	assert(def.familyId ~= nil, "Lineage must declare familyId: " .. lineageId)
	assert(def.stage == 1, "Juvenile forms must be stage 1: " .. lineageId)
end

local stage2Forms = {
	"Raptor",
	"VenomRaptor",
	"ArmoredTRex",
	"CarnivorousPlant",
	"Ent",
	"ForestGolem",
	"Ankylosaur",
	"MossGolem",
	"CrystalGolem",
}
for _, lineageId in stage2Forms do
	local def = LineageDefinitions.get(lineageId)
	assert(def ~= nil, "Missing Stage 2 definition: " .. lineageId)
	assert(def.stage == 2, "Stage 2 forms must be stage 2: " .. lineageId)
	assert(def.placeholderVisualProfileId == lineageId, "Stage 2 visual profile must match id: " .. lineageId)
	assert(def.familyId ~= nil, "Stage 2 must declare familyId: " .. lineageId)
	assert(def.deprecated == false, "Stage 2 deprecated flag expected false: " .. lineageId)
end

-- Frozen Stage 2 route table coverage.
local expectedRoutes = {
	{ parent = "Fangling", affinity = "Flesh", nextForm = "Raptor" },
	{ parent = "Fangling", affinity = "Flora", nextForm = "VenomRaptor" },
	{ parent = "Fangling", affinity = "Mineral", nextForm = "ArmoredTRex" },
	{ parent = "Bloodfang", affinity = "Flesh", nextForm = "Raptor" },
	{ parent = "Bloodfang", affinity = "Flora", nextForm = "VenomRaptor" },
	{ parent = "Bloodfang", affinity = "Mineral", nextForm = "ArmoredTRex" },
	{ parent = "Mossback", affinity = "Flesh", nextForm = "CarnivorousPlant" },
	{ parent = "Mossback", affinity = "Flora", nextForm = "Ent" },
	{ parent = "Mossback", affinity = "Mineral", nextForm = "ForestGolem" },
	{ parent = "Thornhide", affinity = "Flesh", nextForm = "CarnivorousPlant" },
	{ parent = "Thornhide", affinity = "Flora", nextForm = "Ent" },
	{ parent = "Thornhide", affinity = "Mineral", nextForm = "ForestGolem" },
	{ parent = "Stonehide", affinity = "Flesh", nextForm = "Ankylosaur" },
	{ parent = "Stonehide", affinity = "Flora", nextForm = "MossGolem" },
	{ parent = "Stonehide", affinity = "Mineral", nextForm = "CrystalGolem" },
	{ parent = "Crystalback", affinity = "Flesh", nextForm = "Ankylosaur" },
	{ parent = "Crystalback", affinity = "Flora", nextForm = "MossGolem" },
	{ parent = "Crystalback", affinity = "Mineral", nextForm = "CrystalGolem" },
}
for _, route in expectedRoutes do
	assert(
		Stage2Routes.resolve(route.parent, route.affinity) == route.nextForm,
		string.format("Route %s+%s must be %s", route.parent, route.affinity, route.nextForm)
	)
end

-- Roll policy checks: reject invalid / out-of-range; never clamp.
assert(EvolutionCalculator.validateRoll(0.5) == 0.5, "Valid mid-range roll should pass through")
assert(EvolutionCalculator.validateRoll(0) == 0, "Roll 0 is valid in [0, 1)")
assert(EvolutionCalculator.validateRoll(0.999) == 0.999, "Roll just below 1 is valid")
assert(EvolutionCalculator.validateRoll(1) == nil, "Roll 1 is outside [0, 1) and must be rejected")
assert(EvolutionCalculator.validateRoll(-0.01) == nil, "Negative rolls must be rejected")
assert(EvolutionCalculator.validateRoll(2) == nil, "Rolls > 1 must be rejected")
assert(EvolutionCalculator.validateRoll(0 / 0) == nil, "NaN rolls are rejected")
assert(EvolutionCalculator.validateRoll(math.huge) == nil, "Infinite rolls are rejected")

local invalidResolved = EvolutionCalculator.resolveJuvenilePromotion(
	{ Flesh = 40, Flora = 0, Mineral = 0 },
	50,
	"Common",
	0 / 0
)
assert(invalidResolved.eligible == false, "Invalid roll must not resolve")
assert(invalidResolved.reason == "InvalidRoll", "Expected InvalidRoll reason")

local outOfRangeResolved = EvolutionCalculator.resolveJuvenilePromotion(
	{ Flesh = 40, Flora = 0, Mineral = 0 },
	50,
	"Common",
	1
)
assert(outOfRangeResolved.eligible == false, "Out-of-range roll must not resolve")
assert(outOfRangeResolved.reason == "InvalidRoll", "Expected InvalidRoll for roll >= 1")

-- Boundary: exactly 0.30 remains Common Fangling.
local boundaryCommon = EvolutionCalculator.resolveJuvenilePromotion(
	{ Flesh = 40, Flora = 0, Mineral = 0 },
	50,
	"Common",
	BOUNDARY_COMMON_ROLL
)
assert(boundaryCommon.eligible == true, "Boundary 0.30 must resolve")
assert(boundaryCommon.rarity == "Common", "Boundary 0.30 must remain Common")
assert(boundaryCommon.lineageId == "Fangling", "Boundary 0.30 Flesh must be Fangling")
assert(boundaryCommon.promoted == false, "Boundary 0.30 is not a promotion")

-- Immediately below 0.30 promotes to Uncommon Bloodfang.
local justBelow = EvolutionCalculator.resolveJuvenilePromotion(
	{ Flesh = 40, Flora = 0, Mineral = 0 },
	50,
	"Common",
	JUST_BELOW_UNCOMMON_ROLL
)
assert(justBelow.eligible == true, "Just-below roll must resolve")
assert(justBelow.rarity == "Uncommon", "Just-below 0.30 must promote to Uncommon")
assert(justBelow.lineageId == "Bloodfang", "Just-below Flesh must be Bloodfang")
assert(justBelow.promoted == true, "Just-below must set promoted")

-- Existing feeding / growth / ready / bonus / invalid-feed path with forced Common Fangling
local creature = CreatureState.createProtoRex("test-creature-1", 12345)
printState("created ProtoRex", creature)
assert(CreatureState.getRarity(creature) == "Common", "Starter rarity must be Common")

feedToReadyFlesh(creature)
local readySnapshot = CreatureState.getSnapshot(creature)
assert(readySnapshot.growthProgress >= EvolutionCalculator.REQUIRED_GROWTH, "Expected growth threshold met")
assert(readySnapshot.evolutionReady == true, "Expected evolutionReady true")
assert(readySnapshot.predictedEvolution.familyLineageId == "Fangling", "Expected Flesh family Fangling")
assert(readySnapshot.predictedEvolution.familyLabel == "Flesh family", "Expected Flesh family label")
-- Pre-evolution prediction must not reveal Bloodfang.
assert(readySnapshot.predictedEvolution.familyLineageId ~= "Bloodfang", "Prediction must not reveal Uncommon form")

local bonus = FeedingService.applyFeed(creature, "BoneFragments")
assert(bonus.success == true, "Expected one FeedOneMore allowance while evolutionReady")
printState("after bonus BoneFragments", creature)

local blocked = FeedingService.applyFeed(creature, "RawMeat")
assert(blocked.success == false, "Expected feed blocked while evolutionReady with no bonus remaining")
assert(blocked.reason == "EvolutionReady", "Expected EvolutionReady rejection reason")

local beforeInvalid = CreatureState.getSnapshot(creature)
local invalid = FeedingService.applyFeed(creature, "NotARealFeed")
assert(invalid.success == false, "Expected invalid feed to fail")
assert(invalid.reason == "UnknownFeed", "Expected UnknownFeed reason")
local afterInvalid = CreatureState.getSnapshot(creature)
assert(afterInvalid.totalFeedsConsumed == beforeInvalid.totalFeedsConsumed, "Invalid feed must not increment feeds")
assert(afterInvalid.growthProgress == beforeInvalid.growthProgress, "Invalid feed must not change growth")

-- Capture stage affinities before evolution for heritage transfer asserts.
-- Sequence + bonus: F30 Fl10 M30.
local preEvoAffinities = CreatureState.getSnapshot(creature).stageAffinities
assert(preEvoAffinities.Flesh == 30 and preEvoAffinities.Flora == 10 and preEvoAffinities.Mineral == 30)

local confirmCommon = FeedingService.confirmJuvenileEvolution(creature, COMMON_ROLL)
assert(confirmCommon.success == true, "Expected confirmJuvenileEvolution success")
assert(confirmCommon.lineageId == "Fangling", "Forced Common roll must yield Fangling")
assert(confirmCommon.rarity == "Common", "Forced Common roll must keep Common rarity")
assert(confirmCommon.promoted == false, "Common retention is not a promotion")
assert(confirmCommon.stage == 1, "Expected stage 1 after evolution")

local evolved = CreatureState.getSnapshot(creature)
assert(evolved.lineageId == "Fangling", "Snapshot lineage must be Fangling")
assert(evolved.formId == "Fangling", "Snapshot formId must be Fangling")
assert(evolved.rarity == "Common", "Snapshot rarity must be Common")
assert(evolved.stage == 1, "Snapshot stage must be 1")
assert(evolved.growthProgress == 0, "Growth must reset after evolution")
assert(evolved.evolutionReady == false, "evolutionReady must clear after evolution")
assert(evolved.evolutionState == "Growing", "evolutionState must return to Growing")
assert(evolved.stageAffinities.Flesh == 0 and evolved.stageAffinities.Flora == 0 and evolved.stageAffinities.Mineral == 0, "Stage affinities must reset")
assert(evolved.heritageAffinities.Flesh == 7.5, "Heritage Flesh must receive 25%")
assert(evolved.heritageAffinities.Flora == 2.5, "Heritage Flora must receive 25%")
assert(evolved.heritageAffinities.Mineral == 7.5, "Heritage Mineral must receive 25%")
assert(evolved.requiredGrowth == 100, "Stage 1 required growth must be 100")
printState("after Common Fangling evolution", creature)

-- Forced Uncommon Bloodfang
local blood = CreatureState.createProtoRex("test-bloodfang", 2)
feedToReadyFlesh(blood)
local bloodConfirm = FeedingService.confirmJuvenileEvolution(blood, UNCOMMON_ROLL)
assert(bloodConfirm.success == true, "Expected Bloodfang confirm success")
assert(bloodConfirm.lineageId == "Bloodfang", "Forced Uncommon Flesh must yield Bloodfang")
assert(bloodConfirm.rarity == "Uncommon", "Expected Uncommon rarity")
assert(bloodConfirm.promoted == true, "Expected promotion flag")
printState("after Uncommon Bloodfang evolution", blood)

-- Flora Common / Uncommon
local moss = CreatureState.createProtoRex("test-moss", 3)
feedToReadyFlora(moss)
assert(CreatureState.getSnapshot(moss).predictedEvolution.familyLineageId == "Mossback")
local mossConfirm = FeedingService.confirmJuvenileEvolution(moss, COMMON_ROLL)
assert(mossConfirm.success and mossConfirm.lineageId == "Mossback" and mossConfirm.rarity == "Common")

local thorn = CreatureState.createProtoRex("test-thorn", 4)
feedToReadyFlora(thorn)
local thornConfirm = FeedingService.confirmJuvenileEvolution(thorn, UNCOMMON_ROLL)
assert(thornConfirm.success and thornConfirm.lineageId == "Thornhide" and thornConfirm.rarity == "Uncommon")

-- Mineral Common / Uncommon
local stone = CreatureState.createProtoRex("test-stone", 5)
feedToReadyMineral(stone)
assert(CreatureState.getSnapshot(stone).predictedEvolution.familyLineageId == "Stonehide")
local stoneConfirm = FeedingService.confirmJuvenileEvolution(stone, COMMON_ROLL)
assert(stoneConfirm.success and stoneConfirm.lineageId == "Stonehide" and stoneConfirm.rarity == "Common")

local crystal = CreatureState.createProtoRex("test-crystal", 6)
feedToReadyMineral(crystal)
local crystalConfirm = FeedingService.confirmJuvenileEvolution(crystal, UNCOMMON_ROLL)
assert(crystalConfirm.success and crystalConfirm.lineageId == "Crystalback" and crystalConfirm.rarity == "Uncommon")

-- Interaction surface cannot specify outcome: confirmJuvenileEvolution only accepts optional test roll.
assert(type(FeedingService.confirmJuvenileEvolution) == "function", "confirmJuvenileEvolution must remain server API")
assert(type(FeedingService.confirmEvolution) == "function", "confirmEvolution must be the stage-aware API")

---------------------------------------------------------------------------
-- Stage 1 -> Stage 2: pure calculator routes + service integration
---------------------------------------------------------------------------

local function emptyAffinities(): CreatureTypes.AffinityTotals
	return CreatureTypes.createEmptyAffinities()
end

local function emptyInfluences(): CreatureTypes.InfluenceTotals
	return CreatureTypes.createEmptyInfluences()
end

local function dominantStageAffinities(affinity: CreatureTypes.AffinityId): CreatureTypes.AffinityTotals
	local totals = emptyAffinities()
	totals[affinity] = 100
	return totals
end

local function stage1ResolveInput(
	formId: string,
	affinity: CreatureTypes.AffinityId,
	rarity: CreatureTypes.RarityId,
	growthProgress: number,
	stageInfluences: CreatureTypes.InfluenceTotals?,
	stageEvolutionQuality: number?,
	roll: number?
)
	return {
		formId = formId,
		stage = 1,
		rarity = rarity,
		stageAffinities = dominantStageAffinities(affinity),
		heritageAffinities = emptyAffinities(),
		stageInfluences = stageInfluences or emptyInfluences(),
		heritageInfluences = emptyInfluences(),
		stageEvolutionQuality = stageEvolutionQuality or 0,
		growthProgress = growthProgress,
		-- Default COMMON_ROLL keeps Common→Uncommon promotion false at quality 0.
		roll = if roll ~= nil then roll else COMMON_ROLL,
	}
end

local stage2ResolveCases = {
	{ parent = "Fangling", affinity = "Flesh" :: CreatureTypes.AffinityId, nextForm = "Raptor", rarity = "Common" :: CreatureTypes.RarityId },
	{ parent = "Fangling", affinity = "Flora", nextForm = "VenomRaptor", rarity = "Common" },
	{ parent = "Fangling", affinity = "Mineral", nextForm = "ArmoredTRex", rarity = "Common" },
	{ parent = "Bloodfang", affinity = "Mineral", nextForm = "ArmoredTRex", rarity = "Uncommon" },
	{ parent = "Mossback", affinity = "Flesh", nextForm = "CarnivorousPlant", rarity = "Common" },
	{ parent = "Mossback", affinity = "Flora", nextForm = "Ent", rarity = "Common" },
	{ parent = "Mossback", affinity = "Mineral", nextForm = "ForestGolem", rarity = "Common" },
	{ parent = "Thornhide", affinity = "Flora", nextForm = "Ent", rarity = "Uncommon" },
	{ parent = "Stonehide", affinity = "Flesh", nextForm = "Ankylosaur", rarity = "Common" },
	{ parent = "Stonehide", affinity = "Flora", nextForm = "MossGolem", rarity = "Common" },
	{ parent = "Stonehide", affinity = "Mineral", nextForm = "CrystalGolem", rarity = "Common" },
	{ parent = "Crystalback", affinity = "Mineral", nextForm = "CrystalGolem", rarity = "Uncommon" },
}

for _, case in stage2ResolveCases do
	local resolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(case.parent, case.affinity, case.rarity, 100))
	assert(resolved.eligible == true, "Stage 2 resolve must succeed for " .. case.parent .. "+" .. case.affinity)
	assert(resolved.nextFormId == case.nextForm, string.format(
		"%s+%s expected %s got %s",
		case.parent,
		case.affinity,
		case.nextForm,
		tostring(resolved.nextFormId)
	))
	assert(resolved.baseFormId == case.nextForm, "Base form must match normal route without influence")
	assert(resolved.nextStage == 2, "Stage must become 2")
	assert(resolved.rarity == case.rarity, "Stage 2 must preserve rarity for " .. case.parent)
	assert(resolved.promoted == false, "Stage 2 must not rarity-promote")
	assert(resolved.heritageTransfer ~= nil, "Heritage transfer required")
	local transfer = resolved.heritageTransfer :: CreatureTypes.AffinityTotals
	assert(transfer[case.affinity] == 25, "Heritage transfer must be 25% of dominant stage affinity")
	print(string.format(
		"[CreatureSystemTest] Stage2 route ok %s+%s -> %s (%s)",
		case.parent,
		case.affinity,
		case.nextForm,
		case.rarity
	))
end

-- Insufficient growth at Stage 1 (50 is not enough; need 100).
local shortGrowth = EvolutionCalculator.resolveEvolution(stage1ResolveInput("Fangling", "Flesh", "Common", 50))
assert(shortGrowth.eligible == false, "Stage 1 with 50 growth must fail")
assert(shortGrowth.reason == "InsufficientGrowth", "Expected InsufficientGrowth at Stage 1 with 50 growth")

-- Invalid parent form fails safely.
local invalidParent = EvolutionCalculator.resolveEvolution(stage1ResolveInput("ProtoRex", "Flesh", "Common", 100))
assert(invalidParent.eligible == false, "Invalid parent must fail")
assert(invalidParent.reason == "InvalidParentForm", "Expected InvalidParentForm")

-- Unsupported stage fails safely.
local unsupported = EvolutionCalculator.resolveEvolution({
	formId = "Raptor",
	stage = 2,
	rarity = "Common",
	stageAffinities = dominantStageAffinities("Flesh"),
	heritageAffinities = emptyAffinities(),
	stageInfluences = emptyInfluences(),
	heritageInfluences = emptyInfluences(),
	stageEvolutionQuality = 0,
	growthProgress = 100,
})
assert(unsupported.eligible == false, "Stage 2 evolution must be unsupported")
assert(unsupported.reason == "UnsupportedStage", "Expected UnsupportedStage")

local function feedToStage2Ready(state: CreatureState.CreatureState, feedId: string, count: number): ()
	for _ = 1, count do
		local result = FeedingService.applyFeed(state, feedId)
		assert(result.success == true, "Expected Stage 2 feed " .. feedId .. " to succeed")
	end
end

-- Full service path: Fangling -> Mineral -> ArmoredTRex, heritage/stage reset, rarity preserved.
local fangToArmor = CreatureState.createProtoRex("test-fang-armor", 20)
feedToReadyFlesh(fangToArmor)
assert(FeedingService.confirmJuvenileEvolution(fangToArmor, COMMON_ROLL).success)
local beforeStage2 = CreatureState.getSnapshot(fangToArmor)
assert(beforeStage2.formId == "Fangling")
assert(beforeStage2.requiredGrowth == 100)
-- 6 CrystalChunk = 108 growth, Mineral 120 — dominates even with Flesh heritage.
feedToStage2Ready(fangToArmor, "CrystalChunk", 6)
local predictedArmor = CreatureState.getSnapshot(fangToArmor)
assert(predictedArmor.evolutionReady == true, "Fangling must become evolutionReady for Stage 2")
assert(predictedArmor.predictedNextFormId == "ArmoredTRex", "Predicted Stage 2 form must be ArmoredTRex")
assert(predictedArmor.dominantEffectiveAffinity == "Mineral", "Dominant effective affinity must be Mineral")

local stageBeforeArmor = predictedArmor.stageAffinities
local heritageBeforeArmor = predictedArmor.heritageAffinities
local confirmArmor = FeedingService.confirmEvolution(fangToArmor, COMMON_ROLL)
assert(confirmArmor.success == true, "Stage 2 confirmEvolution must succeed")
assert(confirmArmor.formId == "ArmoredTRex", "Fangling+Mineral must become ArmoredTRex")
assert(confirmArmor.lineageId == "ArmoredTRex")
assert(confirmArmor.rarity == "Common", "Common Fangling must stay Common")
assert(confirmArmor.stage == 2, "Stage must be exactly 2")

local afterArmor = CreatureState.getSnapshot(fangToArmor)
assert(afterArmor.stage == 2)
assert(afterArmor.formId == "ArmoredTRex")
assert(afterArmor.rarity == "Common")
assert(afterArmor.growthProgress == 0)
assert(afterArmor.evolutionReady == false)
assert(afterArmor.evolutionState == "Growing")
assert(afterArmor.stageAffinities.Flesh == 0 and afterArmor.stageAffinities.Flora == 0 and afterArmor.stageAffinities.Mineral == 0)
assert(
	afterArmor.heritageAffinities.Flesh == heritageBeforeArmor.Flesh + stageBeforeArmor.Flesh * 0.25,
	"Heritage Flesh must accumulate 25% of stage"
)
assert(
	afterArmor.heritageAffinities.Flora == heritageBeforeArmor.Flora + stageBeforeArmor.Flora * 0.25,
	"Heritage Flora must accumulate 25% of stage"
)
assert(
	afterArmor.heritageAffinities.Mineral == heritageBeforeArmor.Mineral + stageBeforeArmor.Mineral * 0.25,
	"Heritage Mineral must accumulate 25% of stage"
)
assert(afterArmor.predictedNextFormId == nil or afterArmor.predictedEvolution.eligible == false, "Stage 2 has no further prediction")
printState("after Fangling->ArmoredTRex", fangToArmor)

-- Bloodfang Uncommon rarity preserved into ArmoredTRex.
local bloodToArmor = CreatureState.createProtoRex("test-blood-armor", 21)
feedToReadyFlesh(bloodToArmor)
assert(FeedingService.confirmJuvenileEvolution(bloodToArmor, UNCOMMON_ROLL).success)
feedToStage2Ready(bloodToArmor, "CrystalChunk", 6)
local bloodArmorConfirm = FeedingService.confirmEvolution(bloodToArmor, COMMON_ROLL)
assert(bloodArmorConfirm.success and bloodArmorConfirm.formId == "ArmoredTRex")
assert(bloodArmorConfirm.rarity == "Uncommon", "Uncommon Bloodfang must stay Uncommon at Stage 2")
assert(bloodArmorConfirm.stage == 2)

-- Mossback Flora -> Ent via service (basic LeafBundle avoids quality-driven promotion).
local mossToEnt = CreatureState.createProtoRex("test-moss-ent", 22)
feedToReadyFlora(mossToEnt)
assert(FeedingService.confirmJuvenileEvolution(mossToEnt, COMMON_ROLL).lineageId == "Mossback")
feedToStage2Ready(mossToEnt, "LeafBundle", 10)
assert(CreatureState.getSnapshot(mossToEnt).predictedNextFormId == "Ent")
local entConfirm = FeedingService.confirmEvolution(mossToEnt, COMMON_ROLL)
assert(entConfirm.success and entConfirm.formId == "Ent" and entConfirm.rarity == "Common")

-- Failed evolution must not mutate state (unsupported Stage 2).
local beforeFail = CreatureState.getSnapshot(fangToArmor)
local failConfirm = FeedingService.confirmEvolution(fangToArmor)
assert(failConfirm.success == false, "Stage 2 creature cannot evolve further")
assert(failConfirm.reason == "UnsupportedStage", "Expected UnsupportedStage failure")
local afterFail = CreatureState.getSnapshot(fangToArmor)
assert(afterFail.formId == beforeFail.formId, "Failed evolution must not change form")
assert(afterFail.stage == beforeFail.stage, "Failed evolution must not change stage")
assert(afterFail.growthProgress == beforeFail.growthProgress, "Failed evolution must not change growth")
assert(afterFail.stageAffinities.Mineral == beforeFail.stageAffinities.Mineral, "Failed evolution must not change stage affinities")
assert(afterFail.heritageAffinities.Mineral == beforeFail.heritageAffinities.Mineral, "Failed evolution must not change heritage")

-- confirmJuvenileEvolution rejects non-stage-0.
local notStageZero = FeedingService.confirmJuvenileEvolution(fangToArmor, COMMON_ROLL)
assert(notStageZero.success == false and notStageZero.reason == "NotStageZero")

---------------------------------------------------------------------------
-- Specialized feeds + Stage 2 influence variants
---------------------------------------------------------------------------

local insectDef = FeedDefinitions.get("InsectCluster")
assert(insectDef ~= nil and insectDef.influenceContribution ~= nil)
assert(insectDef.affinityContribution.Flesh == 8 and insectDef.growth == 10)
assert(insectDef.influenceContribution.Arthropod == 12)

local fungalDef = FeedDefinitions.get("FungalCore")
assert(fungalDef ~= nil and fungalDef.influenceContribution ~= nil)
assert(fungalDef.affinityContribution.Flora == 8 and fungalDef.growth == 10)
assert(fungalDef.influenceContribution.Fungal == 12)

local obsidianDef = FeedDefinitions.get("ObsidianShard")
assert(obsidianDef ~= nil and obsidianDef.influenceContribution ~= nil)
assert(obsidianDef.affinityContribution.Mineral == 8 and obsidianDef.growth == 10)
assert(obsidianDef.influenceContribution.Volcanic == 12)

-- Ordinary feeds produce no specialized influence.
local ordinary = CreatureState.createProtoRex("test-ordinary-influence", 30)
assert(FeedingService.applyFeed(ordinary, "RawMeat").success)
local ordinarySnap = CreatureState.getSnapshot(ordinary)
assert(ordinarySnap.stageInfluences.Arthropod == 0)
assert(ordinarySnap.stageInfluences.Fungal == 0)
assert(ordinarySnap.stageInfluences.Volcanic == 0)
assert(ordinarySnap.influenceStrengthLabel == "None")

-- InsectCluster adds Flesh, growth, and Arthropod.
local insectState = CreatureState.createProtoRex("test-insect-feed", 31)
assert(FeedingService.applyFeed(insectState, "InsectCluster").success)
local insectSnap = CreatureState.getSnapshot(insectState)
assert(insectSnap.stageAffinities.Flesh == 8)
assert(insectSnap.growthProgress == 10)
assert(insectSnap.stageInfluences.Arthropod == 12)
assert(insectSnap.influenceStrengthLabel == "Developing")

-- One InsectCluster does not qualify a specialized variant.
local oneClusterInfluences = { Arthropod = 12, Fungal = 0, Volcanic = 0 }
local oneAssess = EvolutionCalculator.assessStageInfluences(oneClusterInfluences)
assert(oneAssess.qualifies == false, "One InsectCluster must not qualify")
assert(oneAssess.strongestInfluenceScore == 12)
local oneVariant = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flesh",
	"Common",
	100,
	oneClusterInfluences
))
assert(oneVariant.nextFormId == "Raptor", "One InsectCluster must stay Raptor")
assert(oneVariant.qualifyingInfluenceId == nil)

-- Three InsectClusters: score 36 and share >= 0.60 qualifies.
local threeClusterInfluences = { Arthropod = 36, Fungal = 0, Volcanic = 0 }
local threeAssess = EvolutionCalculator.assessStageInfluences(threeClusterInfluences)
assert(threeAssess.qualifies == true, "Three InsectClusters must qualify")
assert(threeAssess.strongestInfluenceScore == 36)
assert(threeAssess.strongestInfluenceShare >= 0.60)
assert(threeAssess.influenceStrengthLabel == "Strong")
assert(threeAssess.qualifyingInfluenceId == "Arthropod")

-- Variant map: Raptor+Arthropod, Ent+Fungal, CrystalGolem+Volcanic.
local mantisResolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flesh",
	"Common",
	100,
	threeClusterInfluences
))
assert(mantisResolved.baseFormId == "Raptor")
assert(mantisResolved.nextFormId == "MantisRaptor")
assert(mantisResolved.qualifyingInfluenceId == "Arthropod")
print("[CreatureSystemTest] Variant ok Fangling+Flesh+Arthropod -> MantisRaptor")

local mushroomResolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Mossback",
	"Flora",
	"Common",
	100,
	{ Arthropod = 0, Fungal = 36, Volcanic = 0 }
))
assert(mushroomResolved.baseFormId == "Ent")
assert(mushroomResolved.nextFormId == "MushroomEnt")
assert(mushroomResolved.qualifyingInfluenceId == "Fungal")
print("[CreatureSystemTest] Variant ok Mossback+Flora+Fungal -> MushroomEnt")

local magmaResolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Stonehide",
	"Mineral",
	"Common",
	100,
	{ Arthropod = 0, Fungal = 0, Volcanic = 36 }
))
assert(magmaResolved.baseFormId == "CrystalGolem")
assert(magmaResolved.nextFormId == "MagmaGolem")
assert(magmaResolved.qualifyingInfluenceId == "Volcanic")
print("[CreatureSystemTest] Variant ok Stonehide+Mineral+Volcanic -> MagmaGolem")

-- Qualifying influence on unsupported base form leaves normal form unchanged.
local venomWithBugs = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flora",
	"Common",
	100,
	threeClusterInfluences
))
assert(venomWithBugs.baseFormId == "VenomRaptor")
assert(venomWithBugs.nextFormId == "VenomRaptor", "Unsupported base must keep normal form")
assert(venomWithBugs.qualifyingInfluenceId == "Arthropod")
print("[CreatureSystemTest] Unsupported variant mapping keeps VenomRaptor")

-- Equal mixed influences below threshold produce no variant.
local mixedLow = { Arthropod = 12, Fungal = 12, Volcanic = 12 }
local mixedLowAssess = EvolutionCalculator.assessStageInfluences(mixedLow)
assert(mixedLowAssess.qualifies == false)
local mixedLowResolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flesh",
	"Common",
	100,
	mixedLow
))
assert(mixedLowResolved.nextFormId == "Raptor")

-- Score 36 but share < 0.60 produces no variant.
local lowShare = { Arthropod = 36, Fungal = 30, Volcanic = 0 }
local lowShareAssess = EvolutionCalculator.assessStageInfluences(lowShare)
assert(lowShareAssess.strongestInfluenceScore == 36)
assert(lowShareAssess.strongestInfluenceShare < 0.60)
assert(lowShareAssess.qualifies == false)
local lowShareResolved = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flesh",
	"Common",
	100,
	lowShare
))
assert(lowShareResolved.nextFormId == "Raptor")
assert(lowShareResolved.qualifyingInfluenceId == nil)

-- Service path: stage influences reset after specialized evolution; heritage gets 20%.
local mantisService = CreatureState.createProtoRex("test-mantis-service", 32)
feedToReadyFlesh(mantisService)
assert(FeedingService.confirmJuvenileEvolution(mantisService, COMMON_ROLL).success)
for _ = 1, 10 do
	assert(FeedingService.applyFeed(mantisService, "InsectCluster").success)
end
local beforeMantis = CreatureState.getSnapshot(mantisService)
assert(beforeMantis.evolutionReady == true)
assert(beforeMantis.predictedBaseFormId == "Raptor")
assert(beforeMantis.predictedFinalFormId == "MantisRaptor")
assert(beforeMantis.stageInfluences.Arthropod == 120)
local confirmMantis = FeedingService.confirmEvolution(mantisService, COMMON_ROLL)
assert(confirmMantis.success == true)
assert(confirmMantis.formId == "MantisRaptor")
assert(confirmMantis.baseFormId == "Raptor")
assert(confirmMantis.qualifyingInfluenceId == "Arthropod")
assert(confirmMantis.rarity == "Common")
local afterMantis = CreatureState.getSnapshot(mantisService)
assert(afterMantis.stageInfluences.Arthropod == 0)
assert(afterMantis.stageInfluences.Fungal == 0)
assert(afterMantis.stageInfluences.Volcanic == 0)
assert(afterMantis.heritageInfluences.Arthropod == beforeMantis.heritageInfluences.Arthropod + 120 * 0.20)
printState("after Fangling->MantisRaptor", mantisService)

-- Failed feed / evolution must not mutate influence state.
local beforeFailInfluence = CreatureState.getSnapshot(mantisService)
local badFeed = FeedingService.applyFeed(mantisService, "NotARealFeed")
assert(badFeed.success == false and badFeed.reason == "UnknownFeed")
local afterBadFeed = CreatureState.getSnapshot(mantisService)
assert(afterBadFeed.stageInfluences.Arthropod == beforeFailInfluence.stageInfluences.Arthropod)
assert(afterBadFeed.heritageInfluences.Arthropod == beforeFailInfluence.heritageInfluences.Arthropod)
local badEvo = FeedingService.confirmEvolution(mantisService)
assert(badEvo.success == false)
local afterBadEvo = CreatureState.getSnapshot(mantisService)
assert(afterBadEvo.formId == beforeFailInfluence.formId)
assert(afterBadEvo.stageInfluences.Arthropod == beforeFailInfluence.stageInfluences.Arthropod)
assert(afterBadEvo.heritageInfluences.Arthropod == beforeFailInfluence.heritageInfluences.Arthropod)

-- Variant definition coverage.
for _, lineageId in { "MantisRaptor", "MushroomEnt", "MagmaGolem" } do
	local def = LineageDefinitions.get(lineageId)
	assert(def ~= nil and def.stage == 2, "Missing Stage 2 variant definition: " .. lineageId)
end

---------------------------------------------------------------------------
-- Premium feeds + evolution quality
---------------------------------------------------------------------------

local function approxEqual(actual: number, expected: number, epsilon: number): boolean
	return math.abs(actual - expected) <= epsilon
end

assert(StageConfig.MAX_QUALITY_PROMOTION_BONUS == 0.20)
assert(StageConfig.QUALITY_BONUS_SCALE == 40)
assert(StageConfig.BASE_PROMOTION_CHANCE == 0.30)

local primeDef = FeedDefinitions.get("PrimeMeat")
assert(primeDef ~= nil)
assert(primeDef.affinityContribution.Flesh == 18 and primeDef.growth == 16)
assert(primeDef.evolutionQuality == 5)
assert(primeDef.influenceContribution == nil)

local ancientDef = FeedDefinitions.get("AncientFruit")
assert(ancientDef ~= nil)
assert(ancientDef.affinityContribution.Flora == 18 and ancientDef.growth == 16)
assert(ancientDef.evolutionQuality == 5)
assert(ancientDef.influenceContribution == nil)

local livingDef = FeedDefinitions.get("LivingCrystal")
assert(livingDef ~= nil)
assert(livingDef.affinityContribution.Mineral == 18 and livingDef.growth == 16)
assert(livingDef.evolutionQuality == 5)
assert(livingDef.influenceContribution == nil)

-- Basic / specialized feeds contribute zero evolution quality.
for _, feedId in { "RawMeat", "LeafBundle", "CrystalChunk", "BoneFragments", "InsectCluster", "FungalCore", "ObsidianShard" } do
	local def = FeedDefinitions.get(feedId)
	assert(def ~= nil and def.evolutionQuality == 0, feedId .. " must have evolutionQuality 0")
end

assert(approxEqual(EvolutionCalculator.computeQualityPromotionBonus(0), 0, 1e-9))
assert(approxEqual(EvolutionCalculator.computeQualityPromotionBonus(10), 0.04, 1e-6))
assert(approxEqual(EvolutionCalculator.computeQualityPromotionBonus(20), 0.20 * 20 / 60, 1e-6))
assert(approxEqual(EvolutionCalculator.computeQualityPromotionBonus(40), 0.10, 1e-6))
assert(approxEqual(EvolutionCalculator.computeQualityPromotionBonus(80), 0.20 * 80 / 120, 1e-6))
assert(EvolutionCalculator.computeQualityPromotionBonus(1e9) <= 0.20)
assert(EvolutionCalculator.computeAdjustedPromotionChance(0.95, 0.20) == 1)

-- One / four premium feeds accumulate quality.
local qualityState = CreatureState.createProtoRex("test-quality", 40)
assert(FeedingService.applyFeed(qualityState, "PrimeMeat").success)
local q1 = CreatureState.getSnapshot(qualityState)
assert(q1.stageAffinities.Flesh == 18 and q1.growthProgress == 16)
assert(q1.stageEvolutionQuality == 5)
assert(q1.stageInfluences.Arthropod == 0)
for _ = 1, 3 do
	assert(FeedingService.applyFeed(qualityState, "PrimeMeat").success)
end
assert(CreatureState.getSnapshot(qualityState).stageEvolutionQuality == 20)

-- Failed / rejected feeds leave quality unchanged.
local beforeBadQ = CreatureState.getSnapshot(qualityState).stageEvolutionQuality
assert(FeedingService.applyFeed(qualityState, "NotARealFeed").success == false)
assert(CreatureState.getSnapshot(qualityState).stageEvolutionQuality == beforeBadQ)

-- Finish Stage 0 ready and evolve; quality resets.
-- Use a high roll so quality-boosted promotion odds do not change the form under test.
while not CreatureState.isEvolutionReady(qualityState) do
	assert(FeedingService.applyFeed(qualityState, "PrimeMeat").success)
end
local readyQuality = CreatureState.getSnapshot(qualityState).stageEvolutionQuality
assert(readyQuality > 0)
local stage0Confirm = FeedingService.confirmJuvenileEvolution(qualityState, 0.99)
assert(stage0Confirm.success)
assert(CreatureState.getSnapshot(qualityState).stageEvolutionQuality == 0, "Quality must reset after Stage 0 evolution")
assert(CreatureState.getSnapshot(qualityState).formId == "Fangling")

-- Quality does not change affinity route or specialized variant.
local routeKeepCommon = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling",
	"Flesh",
	"Common",
	100,
	{ Arthropod = 36, Fungal = 0, Volcanic = 0 },
	80,
	0.50
))
assert(routeKeepCommon.baseFormId == "Raptor")
assert(routeKeepCommon.nextFormId == "MantisRaptor")
assert(routeKeepCommon.rarity == "Common")
assert(routeKeepCommon.promoted == false)

-- Identical injected RNG between low and high quality thresholds.
local midRoll = 0.33 -- between 0.30 and ~0.3667 (quality 20)
local lowQ = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling", "Flesh", "Common", 100, nil, 0, midRoll
))
assert(lowQ.rarity == "Common" and lowQ.promoted == false, "Low quality must fail midRoll")
local highQ = EvolutionCalculator.resolveEvolution(stage1ResolveInput(
	"Fangling", "Flesh", "Common", 100, nil, 20, midRoll
))
assert(highQ.rarity == "Uncommon" and highQ.promoted == true, "Quality 20 must promote on midRoll")
print("[CreatureSystemTest] Quality promotion threshold ok midRoll=0.33")

-- Stage 2 quality reset after successful specialized evolution with premium feeds.
local premiumMantis = CreatureState.createProtoRex("test-premium-mantis", 41)
feedToReadyFlesh(premiumMantis)
assert(FeedingService.confirmJuvenileEvolution(premiumMantis, COMMON_ROLL).success)
for _ = 1, 3 do
	assert(FeedingService.applyFeed(premiumMantis, "InsectCluster").success)
end
for _ = 1, 5 do
	assert(FeedingService.applyFeed(premiumMantis, "PrimeMeat").success)
end
local beforePremMantis = CreatureState.getSnapshot(premiumMantis)
assert(beforePremMantis.evolutionReady == true)
assert(beforePremMantis.predictedFinalFormId == "MantisRaptor")
assert(beforePremMantis.stageEvolutionQuality == 25)
assert(beforePremMantis.stageInfluences.Arthropod == 36)
local premConfirm = FeedingService.confirmEvolution(premiumMantis, COMMON_ROLL)
assert(premConfirm.success and premConfirm.formId == "MantisRaptor")
assert(CreatureState.getSnapshot(premiumMantis).stageEvolutionQuality == 0, "Quality resets after Stage 2")
print("[CreatureSystemTest] Premium+Arthropod -> MantisRaptor quality reset ok")

local premiumMush = CreatureState.createProtoRex("test-premium-mush", 42)
feedToReadyFlora(premiumMush)
assert(FeedingService.confirmJuvenileEvolution(premiumMush, COMMON_ROLL).success)
for _ = 1, 3 do
	assert(FeedingService.applyFeed(premiumMush, "FungalCore").success)
end
for _ = 1, 5 do
	assert(FeedingService.applyFeed(premiumMush, "AncientFruit").success)
end
assert(CreatureState.getSnapshot(premiumMush).predictedFinalFormId == "MushroomEnt")
assert(FeedingService.confirmEvolution(premiumMush, COMMON_ROLL).formId == "MushroomEnt")
assert(CreatureState.getSnapshot(premiumMush).stageEvolutionQuality == 0)
print("[CreatureSystemTest] Premium+Fungal -> MushroomEnt ok")

local premiumMagma = CreatureState.createProtoRex("test-premium-magma", 43)
feedToReadyMineral(premiumMagma)
assert(FeedingService.confirmJuvenileEvolution(premiumMagma, COMMON_ROLL).success)
for _ = 1, 3 do
	assert(FeedingService.applyFeed(premiumMagma, "ObsidianShard").success)
end
for _ = 1, 5 do
	assert(FeedingService.applyFeed(premiumMagma, "LivingCrystal").success)
end
assert(CreatureState.getSnapshot(premiumMagma).predictedFinalFormId == "MagmaGolem")
assert(FeedingService.confirmEvolution(premiumMagma, COMMON_ROLL).formId == "MagmaGolem")
assert(CreatureState.getSnapshot(premiumMagma).stageEvolutionQuality == 0)
print("[CreatureSystemTest] Premium+Volcanic -> MagmaGolem ok")

-- Failed evolution leaves quality unchanged.
local failQ2 = CreatureState.createProtoRex("test-fail-q2", 45)
feedToReadyFlesh(failQ2)
assert(FeedingService.confirmJuvenileEvolution(failQ2, COMMON_ROLL).success)
assert(FeedingService.applyFeed(failQ2, "PrimeMeat").success)
local qBeforeFail = CreatureState.getSnapshot(failQ2).stageEvolutionQuality
local notReadyConfirm = FeedingService.confirmEvolution(failQ2, COMMON_ROLL)
assert(notReadyConfirm.success == false)
assert(CreatureState.getSnapshot(failQ2).stageEvolutionQuality == qBeforeFail, "Failed evolution must not clear quality")

---------------------------------------------------------------------------
-- Conveyor spawn weight pool (pure selector)
---------------------------------------------------------------------------

local pool = ConveyorSpawnWeights.getProductionPool()
assert(ConveyorSpawnWeights.validatePool(pool) == true)
assert(ConveyorSpawnWeights.getTotalWeight(pool) == 99, "Production total weight must be 99")
local cats = ConveyorSpawnWeights.getCategoryWeights(pool)
assert(cats.basic == 72 and cats.premium == 18 and cats.specialized == 9)
assert(cats.other == 0)

local ids = ConveyorSpawnWeights.getFeedIds(pool)
assert(#ids == 9)
local expectedIds = {
	RawMeat = true,
	LeafBundle = true,
	CrystalChunk = true,
	PrimeMeat = true,
	AncientFruit = true,
	LivingCrystal = true,
	InsectCluster = true,
	FungalCore = true,
	ObsidianShard = true,
}
for _, id in ids do
	assert(expectedIds[id] == true, "Unexpected feed in pool: " .. id)
end

-- Boundary rolls: [0,24)=RawMeat, [24,48)=LeafBundle, [48,72)=CrystalChunk,
-- [72,78)=PrimeMeat, [78,84)=AncientFruit, [84,90)=LivingCrystal,
-- [90,93)=InsectCluster, [93,96)=FungalCore, [96,99)=ObsidianShard
assert(ConveyorSpawnWeights.selectByRoll(pool, 0) == "RawMeat")
assert(ConveyorSpawnWeights.selectByRoll(pool, 23.999) == "RawMeat")
assert(ConveyorSpawnWeights.selectByRoll(pool, 24) == "LeafBundle")
assert(ConveyorSpawnWeights.selectByRoll(pool, 72) == "PrimeMeat")
assert(ConveyorSpawnWeights.selectByRoll(pool, 78) == "AncientFruit")
assert(ConveyorSpawnWeights.selectByRoll(pool, 84) == "LivingCrystal")
assert(ConveyorSpawnWeights.selectByRoll(pool, 90) == "InsectCluster")
assert(ConveyorSpawnWeights.selectByRoll(pool, 93) == "FungalCore")
assert(ConveyorSpawnWeights.selectByRoll(pool, 96) == "ObsidianShard")
assert(ConveyorSpawnWeights.selectByRoll(pool, 98.999) == "ObsidianShard")
assert(ConveyorSpawnWeights.selectByRoll(pool, 99) == nil, "Roll at total must be rejected")
assert(ConveyorSpawnWeights.selectByRoll(pool, -0.1) == nil)

local badPool = { { feedId = "RawMeat", weight = 0 } }
assert(select(1, ConveyorSpawnWeights.validatePool(badPool)) == false)
local negPool = { { feedId = "RawMeat", weight = -1 } }
assert(select(1, ConveyorSpawnWeights.validatePool(negPool)) == false)
local dupPool = {
	{ feedId = "RawMeat", weight = 1 },
	{ feedId = "RawMeat", weight = 1 },
}
assert(select(1, ConveyorSpawnWeights.validatePool(dupPool)) == false)
print("[CreatureSystemTest] Conveyor weight pool boundaries ok")

---------------------------------------------------------------------------
-- Creature visual spawning (isolated temp base — never pollutes live player bases)
---------------------------------------------------------------------------

local visualReport = CreatureVisualService.validateSetup(Workspace:WaitForChild("Bases"))
assert(visualReport.templatesFolderOk == true, "CreatureTemplates folder must exist")
assert(#visualReport.missingTemplates == 0, "All known forms must have templates")
assert(#visualReport.unknownTemplates == 0, "No unknown templates expected in MVP folder")
assert(#visualReport.invalidTemplateClasses == 0, "All templates must be Model or BasePart")
CreatureVisualService.printValidationReport(visualReport)

-- Live bases must expose CreatureSpawn markers, but visual mutation tests use a temp base.
for _, baseName in { "base01", "base02", "base03", "base04", "base05", "base06", "base07", "base08" } do
	local liveBase = Workspace.Bases:FindFirstChild(baseName)
	assert(liveBase ~= nil and liveBase:IsA("Model"), "Missing live base " .. baseName)
	local spawn = liveBase:FindFirstChild("CreatureSpawn")
	assert(spawn ~= nil and spawn:IsA("BasePart"), baseName .. " must have CreatureSpawn BasePart")
end

local visualTestBase = Instance.new("Model")
visualTestBase.Name = "CreatureVisualTestBase"
visualTestBase.Parent = Workspace
local visualTestSpawn = Instance.new("Part")
visualTestSpawn.Name = "CreatureSpawn"
visualTestSpawn.Anchored = true
visualTestSpawn.CanCollide = false
visualTestSpawn.Transparency = 1
visualTestSpawn.Size = Vector3.new(4, 1, 2)
visualTestSpawn.CFrame = CFrame.new(0, 500, 0)
visualTestSpawn.Parent = visualTestBase

local function assertSingleActive(base: Instance, expectedFormId: string, expectFallback: boolean): Instance
	assert(CreatureVisualService.countActiveCreatures(base) == 1, "Expected exactly one ActiveCreature")
	local active = CreatureVisualService.getActiveCreature(base)
	assert(active ~= nil, "Expected ActiveCreature instance")
	assert(active:GetAttribute("FormId") == expectedFormId, "FormId attribute mismatch for " .. expectedFormId)
	assert(active:GetAttribute("VisualFallback") == expectFallback, "VisualFallback mismatch for " .. expectedFormId)
	return active
end

local protoState = CreatureState.createProtoRex("visual-proto", 0)
local protoSnapshot = CreatureState.getSnapshot(protoState)
local protoVisual = CreatureVisualService.refreshVisual(visualTestBase, CreatureVisualService.requestFromSnapshot(protoSnapshot))
assert(protoVisual.success == true, "ProtoRex visual spawn must succeed")
assert(protoVisual.templateFormId == "ProtoRex", "ProtoRex must use ProtoRex template")
assert(protoVisual.visualFallback == false, "ProtoRex must not be fallback")
assertSingleActive(visualTestBase, "ProtoRex", false)

local refreshAgain = CreatureVisualService.refreshVisual(visualTestBase, CreatureVisualService.requestFromSnapshot(protoSnapshot))
assert(refreshAgain.success == true, "Repeated ProtoRex refresh must succeed")
assertSingleActive(visualTestBase, "ProtoRex", false)

local juvenileCases = {
	{ label = "Fangling", feed = feedToReadyFlesh, roll = COMMON_ROLL, formId = "Fangling" },
	{ label = "Bloodfang", feed = feedToReadyFlesh, roll = UNCOMMON_ROLL, formId = "Bloodfang" },
	{ label = "Mossback", feed = feedToReadyFlora, roll = COMMON_ROLL, formId = "Mossback" },
	{ label = "Thornhide", feed = feedToReadyFlora, roll = UNCOMMON_ROLL, formId = "Thornhide" },
	{ label = "Stonehide", feed = feedToReadyMineral, roll = COMMON_ROLL, formId = "Stonehide" },
	{ label = "Crystalback", feed = feedToReadyMineral, roll = UNCOMMON_ROLL, formId = "Crystalback" },
}

for _, case in juvenileCases do
	local state = CreatureState.createProtoRex("visual-" .. case.formId, 1)
	case.feed(state)
	local confirm = FeedingService.confirmJuvenileEvolution(state, case.roll)
	assert(confirm.success == true, "Expected confirm success for " .. case.label)
	assert(confirm.lineageId == case.formId, "Expected lineage " .. case.formId)
	local snapshot = CreatureState.getSnapshot(state)
	assert(snapshot.lineageId == case.formId, "State formId must remain " .. case.formId)
	local visual = CreatureVisualService.refreshVisual(visualTestBase, CreatureVisualService.requestFromSnapshot(snapshot))
	assert(visual.success == true, "Visual refresh must succeed for " .. case.formId)
	assert(visual.templateFormId == case.formId, "Template must be " .. case.formId)
	assert(visual.visualFallback == false, "Expected no fallback for " .. case.formId)
	assertSingleActive(visualTestBase, case.formId, false)
	print(string.format("[CreatureSystemTest] Visual ok form=%s template=%s", case.formId, tostring(visual.templateFormId)))
end

local stage2VisualCases = {
	{ parentFeed = feedToReadyFlesh, parentRoll = COMMON_ROLL, stage2Feed = "RawMeat", stage2Count = 10, formId = "Raptor" },
	{ parentFeed = feedToReadyFlesh, parentRoll = COMMON_ROLL, stage2Feed = "AncientFruit", stage2Count = 7, formId = "VenomRaptor" },
	{ parentFeed = feedToReadyFlesh, parentRoll = COMMON_ROLL, stage2Feed = "CrystalChunk", stage2Count = 6, formId = "ArmoredTRex" },
	{ parentFeed = feedToReadyFlora, parentRoll = COMMON_ROLL, stage2Feed = "RawMeat", stage2Count = 10, formId = "CarnivorousPlant" },
	{ parentFeed = feedToReadyFlora, parentRoll = COMMON_ROLL, stage2Feed = "AncientFruit", stage2Count = 7, formId = "Ent" },
	{ parentFeed = feedToReadyFlora, parentRoll = COMMON_ROLL, stage2Feed = "CrystalChunk", stage2Count = 6, formId = "ForestGolem" },
	{ parentFeed = feedToReadyMineral, parentRoll = COMMON_ROLL, stage2Feed = "RawMeat", stage2Count = 10, formId = "Ankylosaur" },
	{ parentFeed = feedToReadyMineral, parentRoll = COMMON_ROLL, stage2Feed = "AncientFruit", stage2Count = 7, formId = "MossGolem" },
	{ parentFeed = feedToReadyMineral, parentRoll = COMMON_ROLL, stage2Feed = "CrystalChunk", stage2Count = 6, formId = "CrystalGolem" },
	{ parentFeed = feedToReadyFlesh, parentRoll = COMMON_ROLL, stage2Feed = "InsectCluster", stage2Count = 10, formId = "MantisRaptor" },
	{ parentFeed = feedToReadyFlora, parentRoll = COMMON_ROLL, stage2Feed = "FungalCore", stage2Count = 10, formId = "MushroomEnt" },
	{ parentFeed = feedToReadyMineral, parentRoll = COMMON_ROLL, stage2Feed = "ObsidianShard", stage2Count = 10, formId = "MagmaGolem" },
}

for _, case in stage2VisualCases do
	local state = CreatureState.createProtoRex("visual-s2-" .. case.formId, 2)
	case.parentFeed(state)
	assert(FeedingService.confirmJuvenileEvolution(state, case.parentRoll).success)
	feedToStage2Ready(state, case.stage2Feed, case.stage2Count)
	local confirm = FeedingService.confirmEvolution(state, COMMON_ROLL)
	assert(confirm.success == true, "Stage 2 confirm must succeed for " .. case.formId)
	assert(confirm.formId == case.formId, "Expected Stage 2 form " .. case.formId)
	local snapshot = CreatureState.getSnapshot(state)
	local visual = CreatureVisualService.refreshVisual(visualTestBase, CreatureVisualService.requestFromSnapshot(snapshot))
	assert(visual.success == true, "Visual refresh must succeed for " .. case.formId)
	assert(visual.templateFormId == case.formId, "Template must be " .. case.formId)
	assert(visual.visualFallback == false, "Expected no fallback for " .. case.formId)
	assertSingleActive(visualTestBase, case.formId, false)
	print(string.format("[CreatureSystemTest] Stage2 visual ok form=%s", case.formId))
end

local missingFormId = "MissingForm_VisualTest"
local beforeMissingLineage = CreatureState.getSnapshot(crystal).lineageId
local missingRefresh = CreatureVisualService.refreshVisual(visualTestBase, {
	formId = missingFormId,
	rarity = "Common",
	stage = 1,
	ownerUserId = 0,
	creatureId = "missing-visual-test",
})
assert(missingRefresh.success == true, "Missing template should fall back successfully")
assert(missingRefresh.visualFallback == true, "Missing template must set visualFallback")
assert(missingRefresh.templateFormId == "ProtoRex", "Fallback template must be ProtoRex")
assert(missingRefresh.formId == missingFormId, "Authoritative formId must remain the requested missing id")
local missingActive = assertSingleActive(visualTestBase, missingFormId, true)
assert(missingActive:GetAttribute("FormId") == missingFormId, "ActiveCreature FormId must stay authoritative")
assert(CreatureState.getSnapshot(crystal).lineageId == beforeMissingLineage, "CreatureState must be unchanged by visual fallback")

local invalidBase = Instance.new("Model")
invalidBase.Name = "CreatureVisualInvalidBase"
invalidBase.Parent = Workspace
local invalidRefresh = CreatureVisualService.refreshVisual(invalidBase, {
	formId = "ProtoRex",
	rarity = "Common",
	stage = 0,
	ownerUserId = 0,
	creatureId = "invalid-base-test",
})
assert(invalidRefresh.success == false, "Invalid base must fail refresh")
assert(invalidRefresh.reason == "MissingCreatureSpawn", "Expected MissingCreatureSpawn")
assert(CreatureVisualService.countActiveCreatures(invalidBase) == 0, "Invalid base must not spawn visuals")
invalidBase:Destroy()

-- Cleanup isolated test base only. Never leave leftover visuals on live player bases.
visualTestBase:Destroy()

print("[CreatureSystemTest] ALL ASSERTIONS PASSED")
