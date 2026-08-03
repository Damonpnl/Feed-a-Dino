--!strict

--[[
	Immutable feed definition data for the MVP lineage system.
	Optional influenceContribution is specialized and separate from affinities.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local FeedDefinitions = {}

export type FeedDefinition = CreatureTypes.FeedDefinition

local function freezeAffinities(contribution: CreatureTypes.AffinityTotals): CreatureTypes.AffinityTotals
	return table.freeze({
		Flesh = contribution.Flesh,
		Flora = contribution.Flora,
		Mineral = contribution.Mineral,
	})
end

local function freezeInfluences(contribution: { [string]: number }): CreatureTypes.InfluenceTotals
	local totals = CreatureTypes.createEmptyInfluences()
	for influenceId, amount in contribution do
		if not CreatureTypes.isValidInfluenceId(influenceId) then
			error(string.format("[FeedDefinitions] Unknown influence ID %q rejected", tostring(influenceId)))
		end
		if typeof(amount) ~= "number" then
			error(string.format("[FeedDefinitions] Influence %s must be a number", influenceId))
		end
		totals[influenceId :: CreatureTypes.InfluenceId] = amount
	end
	return table.freeze(totals)
end

local function defineFeed(
	id: string,
	displayName: string,
	affinityContribution: CreatureTypes.AffinityTotals,
	growth: number,
	influenceContribution: { [string]: number }?
): CreatureTypes.FeedDefinition
	local definition: CreatureTypes.FeedDefinition = {
		id = id,
		displayName = displayName,
		affinityContribution = freezeAffinities(affinityContribution),
		growth = growth,
		influenceContribution = if influenceContribution ~= nil
			then freezeInfluences(influenceContribution)
			else nil,
	}
	return table.freeze(definition)
end

local feeds: { [CreatureTypes.FeedId]: CreatureTypes.FeedDefinition } = {
	RawMeat = defineFeed("RawMeat", "Raw Meat", { Flesh = 10, Flora = 0, Mineral = 0 }, 10, nil),
	PrimeMeat = defineFeed("PrimeMeat", "Prime Meat", { Flesh = 20, Flora = 0, Mineral = 0 }, 18, nil),
	LeafBundle = defineFeed("LeafBundle", "Leaf Bundle", { Flesh = 0, Flora = 10, Mineral = 0 }, 10, nil),
	AncientFruit = defineFeed("AncientFruit", "Ancient Fruit", { Flesh = 0, Flora = 20, Mineral = 0 }, 18, nil),
	BoneFragments = defineFeed("BoneFragments", "Bone Fragments", { Flesh = 0, Flora = 0, Mineral = 10 }, 10, nil),
	CrystalChunk = defineFeed("CrystalChunk", "Crystal Chunk", { Flesh = 0, Flora = 0, Mineral = 20 }, 18, nil),
	InsectCluster = defineFeed(
		"InsectCluster",
		"Insect Cluster",
		{ Flesh = 8, Flora = 0, Mineral = 0 },
		10,
		{ Arthropod = 12 }
	),
	FungalCore = defineFeed(
		"FungalCore",
		"Fungal Core",
		{ Flesh = 0, Flora = 8, Mineral = 0 },
		10,
		{ Fungal = 12 }
	),
	ObsidianShard = defineFeed(
		"ObsidianShard",
		"Obsidian Shard",
		{ Flesh = 0, Flora = 0, Mineral = 8 },
		10,
		{ Volcanic = 12 }
	),
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
