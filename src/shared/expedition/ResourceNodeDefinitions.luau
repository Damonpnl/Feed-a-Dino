--!strict

--[[
	Immutable ordinary resource-node definitions for Savannah expeditions.
]]

local ExpeditionConfig = require(script.Parent.ExpeditionConfig)
local ExpeditionTypes = require(script.Parent.ExpeditionTypes)

export type ResourceNodeDefinition = ExpeditionTypes.ResourceNodeDefinition
export type NodeTypeId = ExpeditionTypes.NodeTypeId

local ResourceNodeDefinitions = {}

local definitions: { [NodeTypeId]: ResourceNodeDefinition } = {
	InsectNest = table.freeze({
		nodeTypeId = "InsectNest",
		templateName = "InsectNest",
		regionFolderName = ExpeditionConfig.InsectNestRegionFolderName,
		activeCount = ExpeditionConfig.InsectNestActiveCount,
		charges = 3,
		respawnMinSeconds = 75,
		respawnMaxSeconds = 105,
		promptActionText = "Gather",
		promptObjectText = "Insect Nest",
		holdDuration = ExpeditionConfig.PromptHoldDuration,
		guaranteedRewards = table.freeze({
			table.freeze({ feedId = "InsectCluster", amount = 1 }),
		}),
		weightedRewards = nil,
	}),
	AncientBush = table.freeze({
		nodeTypeId = "AncientBush",
		templateName = "AncientBush",
		regionFolderName = ExpeditionConfig.AncientBushRegionFolderName,
		activeCount = ExpeditionConfig.AncientBushActiveCount,
		charges = 4,
		respawnMinSeconds = 60,
		respawnMaxSeconds = 90,
		promptActionText = "Harvest",
		promptObjectText = "Ancient Bush",
		holdDuration = ExpeditionConfig.PromptHoldDuration,
		guaranteedRewards = nil,
		weightedRewards = table.freeze({
			table.freeze({ feedId = "LeafBundle", amount = 1, weight = 75 }),
			table.freeze({ feedId = "AncientFruit", amount = 1, weight = 25 }),
		}),
	}),
	CrystalOutcrop = table.freeze({
		nodeTypeId = "CrystalOutcrop",
		templateName = "CrystalOutcrop",
		regionFolderName = ExpeditionConfig.CrystalOutcropRegionFolderName,
		activeCount = ExpeditionConfig.CrystalOutcropActiveCount,
		charges = 3,
		respawnMinSeconds = 90,
		respawnMaxSeconds = 135,
		promptActionText = "Mine",
		promptObjectText = "Crystal Outcrop",
		holdDuration = ExpeditionConfig.PromptHoldDuration,
		guaranteedRewards = nil,
		weightedRewards = table.freeze({
			table.freeze({ feedId = "CrystalChunk", amount = 1, weight = 80 }),
			table.freeze({ feedId = "LivingCrystal", amount = 1, weight = 20 }),
		}),
	}),
	CrystalEruptionNode = table.freeze({
		nodeTypeId = "CrystalEruptionNode",
		templateName = "CrystalEruptionNode",
		regionFolderName = ExpeditionConfig.CrystalOutcropRegionFolderName,
		activeCount = 0,
		charges = 2,
		respawnMinSeconds = 0,
		respawnMaxSeconds = 0,
		promptActionText = "Mine",
		promptObjectText = "Crystal Eruption",
		holdDuration = ExpeditionConfig.PromptHoldDuration,
		guaranteedRewards = table.freeze({
			table.freeze({ feedId = "CrystalChunk", amount = 1 }),
		}),
		weightedRewards = nil,
	}),
}

table.freeze(definitions)

function ResourceNodeDefinitions.get(nodeTypeId: NodeTypeId): ResourceNodeDefinition?
	return definitions[nodeTypeId]
end

function ResourceNodeDefinitions.getOrdinaryNodes(): { ResourceNodeDefinition }
	return table.freeze({
		definitions.InsectNest,
		definitions.AncientBush,
		definitions.CrystalOutcrop,
	})
end

function ResourceNodeDefinitions.getBillboardFeedId(nodeTypeId: NodeTypeId): string
	local definition = definitions[nodeTypeId]
	if definition == nil then
		return "CrystalChunk"
	end
	if definition.guaranteedRewards and definition.guaranteedRewards[1] then
		return definition.guaranteedRewards[1].feedId
	end
	if definition.weightedRewards and definition.weightedRewards[1] then
		return definition.weightedRewards[1].feedId
	end
	return "CrystalChunk"
end

function ResourceNodeDefinitions.getBillboardDisplayName(nodeTypeId: NodeTypeId): string
	local definition = definitions[nodeTypeId]
	if definition == nil then
		return nodeTypeId
	end
	return definition.promptObjectText
end

function ResourceNodeDefinitions.rollWeightedReward(
	entries: { ExpeditionTypes.RewardEntry },
	rng: Random
): ExpeditionTypes.RewardEntry?
	local total = 0
	for _, entry in entries do
		total += entry.weight or 0
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.weight or 0
		if roll <= cumulative then
			return entry
		end
	end

	return entries[#entries]
end

return ResourceNodeDefinitions
