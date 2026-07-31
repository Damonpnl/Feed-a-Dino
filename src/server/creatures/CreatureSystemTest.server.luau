--!strict

--[[
	Vertical-slice test for CreatureState + FeedingService.
	Runs once on server start and asserts expected affinity / evolution outcomes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))

local CreatureState = require(script.Parent.CreatureState)
local FeedingService = require(script.Parent.FeedingService)

local function affinitiesEqual(
	actual: { Flesh: number, Flora: number, Mineral: number },
	expectedFlesh: number,
	expectedFlora: number,
	expectedMineral: number
): boolean
	return actual.Flesh == expectedFlesh
		and actual.Flora == expectedFlora
		and actual.Mineral == expectedMineral
end

local function printState(label: string, state: CreatureState.CreatureState): ()
	local snapshot = CreatureState.getSnapshot(state)
	print(
		string.format(
			"[CreatureSystemTest] %s | lineage=%s stage=%d feeds=%d affinities={Flesh=%d, Flora=%d, Mineral=%d}",
			label,
			snapshot.lineageId,
			snapshot.stage,
			snapshot.totalFeedsConsumed,
			snapshot.affinities.Flesh,
			snapshot.affinities.Flora,
			snapshot.affinities.Mineral
		)
	)
end

local creature = CreatureState.createProtoRex("test-creature-1", 12345)
printState("created ProtoRex", creature)

local lastPredictedEvolution: FeedingService.EvolutionResult? = nil
local feedSequence = { "RawMeat", "LeafBundle", "CrystalChunk" }

for _, feedId in feedSequence do
	local result = FeedingService.applyFeed(creature, feedId)
	assert(result.success == true, string.format("Expected feed %s to succeed", feedId))
	assert(result.reason == nil, string.format("Expected no failure reason for %s", feedId))
	assert(result.feedId == feedId, string.format("Expected feedId %s in result", feedId))
	assert(result.updatedAffinities ~= nil, "Expected updatedAffinities after valid feed")
	assert(result.totalFeedsConsumed ~= nil, "Expected totalFeedsConsumed after valid feed")
	assert(result.predictedEvolution ~= nil, "Expected predictedEvolution after valid feed")

	lastPredictedEvolution = result.predictedEvolution
	printState(string.format("after %s", feedId), creature)
	print(
		string.format(
			"[CreatureSystemTest] predictedEvolution eligible=%s lineage=%s dominant=%s",
			tostring(result.predictedEvolution.eligible),
			tostring(result.predictedEvolution.lineageId),
			tostring(result.predictedEvolution.dominantAffinity)
		)
	)
end

local snapshotBeforeInvalid = CreatureState.getSnapshot(creature)
local invalidResult = FeedingService.applyFeed(creature, "NotARealFeed")

assert(invalidResult.success == false, "Expected invalid feed to fail")
assert(invalidResult.reason == "UnknownFeed", "Expected UnknownFeed reason")
assert(invalidResult.updatedAffinities == nil, "Invalid feed must not return updated affinities")
assert(invalidResult.totalFeedsConsumed == nil, "Invalid feed must not return totalFeedsConsumed")
assert(invalidResult.predictedEvolution == nil, "Invalid feed must not return predictedEvolution")

local snapshotAfterInvalid = CreatureState.getSnapshot(creature)
assert(
	snapshotAfterInvalid.totalFeedsConsumed == snapshotBeforeInvalid.totalFeedsConsumed,
	"Invalid feed must not increment totalFeedsConsumed"
)
assert(
	affinitiesEqual(
		snapshotAfterInvalid.affinities,
		snapshotBeforeInvalid.affinities.Flesh,
		snapshotBeforeInvalid.affinities.Flora,
		snapshotBeforeInvalid.affinities.Mineral
	),
	"Invalid feed must not change affinity totals"
)

local finalSnapshot = CreatureState.getSnapshot(creature)
assert(finalSnapshot.affinities.Flesh == 10, "Expected final Flesh affinity 10")
assert(finalSnapshot.affinities.Flora == 10, "Expected final Flora affinity 10")
assert(finalSnapshot.affinities.Mineral == 20, "Expected final Mineral affinity 20")
assert(finalSnapshot.totalFeedsConsumed == 3, "Expected totalFeedsConsumed 3")

assert(lastPredictedEvolution ~= nil, "Expected a predicted evolution from the final valid feed")
assert(lastPredictedEvolution.eligible == true, "Expected predicted evolution to be eligible")
assert(lastPredictedEvolution.lineageId == "Stonehide", "Expected predicted juvenile lineage Stonehide")
assert(lastPredictedEvolution.dominantAffinity == "Mineral", "Expected dominant affinity Mineral")

local recalculated = EvolutionCalculator.resolveJuvenileEvolution(finalSnapshot.affinities)
assert(recalculated.lineageId == "Stonehide", "Recalculated juvenile lineage must be Stonehide")

print("[CreatureSystemTest] ALL ASSERTIONS PASSED")
