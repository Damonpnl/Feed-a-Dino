--!strict

--[[
	Authoritative runtime state for a single creature.
	No Instances, networking, or persistence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local CreatureTypes = require(Creatures:WaitForChild("CreatureTypes"))

local CreatureState = {}

export type CreatureState = {
	creatureId: string,
	ownerUserId: number,
	lineageId: string,
	stage: number,
	totalFeedsConsumed: number,
}

export type CreatureSnapshot = {
	creatureId: string,
	ownerUserId: number,
	lineageId: string,
	stage: number,
	affinities: CreatureTypes.AffinityTotals,
	totalFeedsConsumed: number,
}

-- Affinities are stored off-object so callers cannot mutate them through the state table.
local affinitiesByState: { [CreatureState]: CreatureTypes.AffinityTotals } = setmetatable({}, { __mode = "k" }) :: any

local function copyAffinities(affinities: CreatureTypes.AffinityTotals): CreatureTypes.AffinityTotals
	return {
		Flesh = affinities.Flesh,
		Flora = affinities.Flora,
		Mineral = affinities.Mineral,
	}
end

local function getInternalAffinities(state: CreatureState): CreatureTypes.AffinityTotals
	local affinities = affinitiesByState[state]
	assert(affinities ~= nil, "CreatureState affinities missing for state")
	return affinities
end

function CreatureState.createProtoRex(creatureId: string, ownerUserId: number): CreatureState
	local state: CreatureState = {
		creatureId = creatureId,
		ownerUserId = ownerUserId,
		lineageId = "ProtoRex",
		stage = 0,
		totalFeedsConsumed = 0,
	}
	affinitiesByState[state] = CreatureTypes.createEmptyAffinities()
	return state
end

function CreatureState.getAffinities(state: CreatureState): CreatureTypes.AffinityTotals
	return copyAffinities(getInternalAffinities(state))
end

function CreatureState.getSnapshot(state: CreatureState): CreatureSnapshot
	return {
		creatureId = state.creatureId,
		ownerUserId = state.ownerUserId,
		lineageId = state.lineageId,
		stage = state.stage,
		affinities = copyAffinities(getInternalAffinities(state)),
		totalFeedsConsumed = state.totalFeedsConsumed,
	}
end

function CreatureState.applyAffinityContribution(
	state: CreatureState,
	contribution: CreatureTypes.AffinityTotals
): ()
	local affinities = getInternalAffinities(state)
	affinities.Flesh += contribution.Flesh
	affinities.Flora += contribution.Flora
	affinities.Mineral += contribution.Mineral
end

function CreatureState.incrementFeedsConsumed(state: CreatureState): ()
	state.totalFeedsConsumed += 1
end

return CreatureState
