--!strict

--[[
	Immutable feed definition data for the MVP lineage system.
	Optional influenceContribution is specialized and separate from affinities.
	evolutionQuality improves rarity-promotion odds; missing values normalize to 0.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local FeedDefinitions = {}

export type FeedDefinition = CreatureTypes.FeedDefinition

local function isFiniteNonNegative(value: number): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
end

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

local function normalizeEvolutionQuality(evolutionQuality: number?): number
	if evolutionQuality == nil then
		return 0
	end
	if not isFiniteNonNegative(evolutionQuality) then
		error("[FeedDefinitions] evolutionQuality must be a finite nonnegative number")
	end
	return evolutionQuality
end

local function defineFeed(
	id: string,
	displayName: string,
	affinityContribution: CreatureTypes.AffinityTotals,
	growth: number,
	evolutionQuality: number?,
	influenceContribution: { [string]: number }?
): CreatureTypes.FeedDefinition
	if not isFiniteNonNegative(growth) then
		error(string.format("[FeedDefinitions] Feed %s growth must be finite and nonnegative", id))
	end

	local definition: CreatureTypes.FeedDefinition = {
		id = id,
		displayName = displayName,
		affinityContribution = freezeAffinities(affinityContribution),
		growth = growth,
		evolutionQuality = normalizeEvolutionQuality(evolutionQuality),
		influenceContribution = if influenceContribution ~= nil
			then freezeInfluences(influenceContribution)
			else nil,
	}
	return table.freeze(definition)
end

local feeds: { [CreatureTypes.FeedId]: CreatureTypes.FeedDefinition } = {
	-- Basic affinity feeds (quality 0).
	RawMeat = defineFeed("RawMeat", "Raw Meat", { Flesh = 10, Flora = 0, Mineral = 0 }, 10, 0, nil),
	LeafBundle = defineFeed("LeafBundle", "Leaf Bundle", { Flesh = 0, Flora = 10, Mineral = 0 }, 10, 0, nil),
	CrystalChunk = defineFeed("CrystalChunk", "Crystal Chunk", { Flesh = 0, Flora = 0, Mineral = 20 }, 18, 0, nil),
	BoneFragments = defineFeed("BoneFragments", "Bone Fragments", { Flesh = 0, Flora = 0, Mineral = 10 }, 10, 0, nil),

	-- Premium affinity feeds (quality > 0, no specialized influence).
	PrimeMeat = defineFeed("PrimeMeat", "Prime Meat", { Flesh = 18, Flora = 0, Mineral = 0 }, 16, 5, nil),
	AncientFruit = defineFeed("AncientFruit", "Ancient Fruit", { Flesh = 0, Flora = 18, Mineral = 0 }, 16, 5, nil),
	LivingCrystal = defineFeed("LivingCrystal", "Living Crystal", { Flesh = 0, Flora = 0, Mineral = 18 }, 16, 5, nil),

	-- Specialized influence feeds (quality 0).
	InsectCluster = defineFeed(
		"InsectCluster",
		"Insect Cluster",
		{ Flesh = 8, Flora = 0, Mineral = 0 },
		10,
		0,
		{ Arthropod = 12 }
	),
	FungalCore = defineFeed(
		"FungalCore",
		"Fungal Core",
		{ Flesh = 0, Flora = 8, Mineral = 0 },
		10,
		0,
		{ Fungal = 12 }
	),
	ObsidianShard = defineFeed(
		"ObsidianShard",
		"Obsidian Shard",
		{ Flesh = 0, Flora = 0, Mineral = 8 },
		10,
		0,
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
