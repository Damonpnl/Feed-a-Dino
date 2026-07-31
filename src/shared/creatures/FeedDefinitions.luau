--!strict

--[[
	Immutable feed definition data for the MVP lineage system.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local FeedDefinitions = {}

export type FeedDefinition = CreatureTypes.FeedDefinition

local feeds: { [CreatureTypes.FeedId]: CreatureTypes.FeedDefinition } = {
	RawMeat = table.freeze({
		id = "RawMeat",
		displayName = "Raw Meat",
		affinityContribution = table.freeze({
			Flesh = 10,
			Flora = 0,
			Mineral = 0,
		}),
	}),
	PrimeMeat = table.freeze({
		id = "PrimeMeat",
		displayName = "Prime Meat",
		affinityContribution = table.freeze({
			Flesh = 20,
			Flora = 0,
			Mineral = 0,
		}),
	}),
	LeafBundle = table.freeze({
		id = "LeafBundle",
		displayName = "Leaf Bundle",
		affinityContribution = table.freeze({
			Flesh = 0,
			Flora = 10,
			Mineral = 0,
		}),
	}),
	AncientFruit = table.freeze({
		id = "AncientFruit",
		displayName = "Ancient Fruit",
		affinityContribution = table.freeze({
			Flesh = 0,
			Flora = 20,
			Mineral = 0,
		}),
	}),
	BoneFragments = table.freeze({
		id = "BoneFragments",
		displayName = "Bone Fragments",
		affinityContribution = table.freeze({
			Flesh = 0,
			Flora = 0,
			Mineral = 10,
		}),
	}),
	CrystalChunk = table.freeze({
		id = "CrystalChunk",
		displayName = "Crystal Chunk",
		affinityContribution = table.freeze({
			Flesh = 0,
			Flora = 0,
			Mineral = 20,
		}),
	}),
}

table.freeze(feeds)

function FeedDefinitions.get(feedId: CreatureTypes.FeedId): CreatureTypes.FeedDefinition?
	return feeds[feedId]
end

function FeedDefinitions.getAll(): { CreatureTypes.FeedDefinition }
	local result: { CreatureTypes.FeedDefinition } = {}
	for _, feed in feeds do
		table.insert(result, feed)
	end
	return table.freeze(result)
end

return FeedDefinitions
