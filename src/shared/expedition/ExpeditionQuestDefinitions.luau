--!strict

--[[
	Immutable Savannah expedition quest definitions.
	Coin rewards are granted via WalletService (no material rewards in this slice).
]]

local ExpeditionTypes = require(script.Parent.ExpeditionTypes)

export type QuestDefinition = ExpeditionTypes.QuestDefinition
export type QuestId = ExpeditionTypes.QuestId

local ExpeditionQuestDefinitions = {}

local orderedIds: { QuestId } = table.freeze({
	"SavannahBugCollector",
	"SavannahCrystalSurvey",
	"SavannahWateringHole",
})

local definitions: { [QuestId]: QuestDefinition } = {
	SavannahBugCollector = table.freeze({
		questId = "SavannahBugCollector",
		displayName = "BUG COLLECTOR",
		objectiveText = "Gather Insect Clusters",
		targetAmount = 3,
		coinReward = 150,
		rewards = table.freeze({}),
	}),
	SavannahCrystalSurvey = table.freeze({
		questId = "SavannahCrystalSurvey",
		displayName = "CRYSTAL SURVEY",
		objectiveText = "Mine Crystal Outcrops",
		targetAmount = 5,
		coinReward = 250,
		rewards = table.freeze({}),
	}),
	SavannahWateringHole = table.freeze({
		questId = "SavannahWateringHole",
		displayName = "WATERING HOLE",
		objectiveText = "Discover the Watering Hole",
		targetAmount = 1,
		coinReward = 100,
		rewards = table.freeze({}),
	}),
}

table.freeze(definitions)

function ExpeditionQuestDefinitions.get(questId: QuestId): QuestDefinition?
	return definitions[questId]
end

function ExpeditionQuestDefinitions.getOrderedIds(): { QuestId }
	return orderedIds
end

function ExpeditionQuestDefinitions.getAll(): { QuestDefinition }
	local result: { QuestDefinition } = {}
	for _, questId in orderedIds do
		table.insert(result, definitions[questId])
	end
	return table.freeze(result)
end

return ExpeditionQuestDefinitions
