--!strict

--[[
	Immutable Crystal Eruption event definition.
	No EventSpawn marker Parts are required.
]]

local ExpeditionTypes = require(script.Parent.ExpeditionTypes)

export type EventDefinition = ExpeditionTypes.EventDefinition

local ExpeditionEventDefinitions = {}

local crystalEruption: EventDefinition = table.freeze({
	eventId = "CrystalEruption",
	displayName = "CRYSTAL ERUPTION",
	announcementBody = "A crystal eruption has appeared in the Savannah!",
	initialDelaySeconds = 120,
	intervalSeconds = 180,
	durationSeconds = 120,
	minNodes = 3,
	maxNodes = 5,
	charges = 2,
	livingCrystalBonusChance = 0.35,
})

function ExpeditionEventDefinitions.getCrystalEruption(): EventDefinition
	return crystalEruption
end

function ExpeditionEventDefinitions.get(eventId: ExpeditionTypes.EventId): EventDefinition?
	if eventId == "CrystalEruption" then
		return crystalEruption
	end
	return nil
end

return ExpeditionEventDefinitions
