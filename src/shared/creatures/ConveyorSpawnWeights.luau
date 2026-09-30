--!strict

--[[
	Pure conveyor spawn weight pool and deterministic weighted selection.
	No Roblox services. Selection uses explicit cumulative ranges (not table iteration order).
]]

local ConveyorSpawnWeights = {}

export type SpawnWeightEntry = {
	feedId: string,
	weight: number,
}

-- Exact production pool. Total weight = 99.
local PRODUCTION_POOL: { SpawnWeightEntry } = table.freeze({
	table.freeze({ feedId = "RawMeat", weight = 24 }),
	table.freeze({ feedId = "LeafBundle", weight = 24 }),
	table.freeze({ feedId = "CrystalChunk", weight = 24 }),
	table.freeze({ feedId = "PrimeMeat", weight = 6 }),
	table.freeze({ feedId = "AncientFruit", weight = 6 }),
	table.freeze({ feedId = "LivingCrystal", weight = 6 }),
	table.freeze({ feedId = "InsectCluster", weight = 3 }),
	table.freeze({ feedId = "FungalCore", weight = 3 }),
	table.freeze({ feedId = "ObsidianShard", weight = 3 }),
})

local BASIC_FEED_IDS: { [string]: boolean } = table.freeze({
	RawMeat = true,
	LeafBundle = true,
	CrystalChunk = true,
})

local PREMIUM_FEED_IDS: { [string]: boolean } = table.freeze({
	PrimeMeat = true,
	AncientFruit = true,
	LivingCrystal = true,
})

local SPECIALIZED_FEED_IDS: { [string]: boolean } = table.freeze({
	InsectCluster = true,
	FungalCore = true,
	ObsidianShard = true,
})

local function isFiniteNonNegative(value: number): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

function ConveyorSpawnWeights.getProductionPool(): { SpawnWeightEntry }
	return PRODUCTION_POOL
end

function ConveyorSpawnWeights.validatePool(pool: { SpawnWeightEntry }): (boolean, string?)
	if typeof(pool) ~= "table" or #pool == 0 then
		return false, "EmptyPool"
	end

	local seen: { [string]: boolean } = {}
	for index, entry in pool do
		if typeof(entry) ~= "table" then
			return false, "InvalidEntry"
		end
		if typeof(entry.feedId) ~= "string" or entry.feedId == "" then
			return false, "InvalidFeedId"
		end
		if string.find(entry.feedId, "[%s\"']") ~= nil then
			return false, "MalformedFeedId"
		end
		if not isFiniteNonNegative(entry.weight) or entry.weight <= 0 then
			return false, "NonPositiveWeight"
		end
		if seen[entry.feedId] then
			return false, "DuplicateFeedId"
		end
		seen[entry.feedId] = true
		-- Keep index used so Luau strict is happy about loop var.
		local _ = index
	end

	return true, nil
end

function ConveyorSpawnWeights.getTotalWeight(pool: { SpawnWeightEntry }): number
	local total = 0
	for _, entry in pool do
		total += entry.weight
	end
	return total
end

function ConveyorSpawnWeights.getCategoryWeights(pool: { SpawnWeightEntry }): {
	basic: number,
	premium: number,
	specialized: number,
	other: number,
}
	local basic = 0
	local premium = 0
	local specialized = 0
	local other = 0
	for _, entry in pool do
		if BASIC_FEED_IDS[entry.feedId] then
			basic += entry.weight
		elseif PREMIUM_FEED_IDS[entry.feedId] then
			premium += entry.weight
		elseif SPECIALIZED_FEED_IDS[entry.feedId] then
			specialized += entry.weight
		else
			other += entry.weight
		end
	end
	return {
		basic = basic,
		premium = premium,
		specialized = specialized,
		other = other,
	}
end

function ConveyorSpawnWeights.getFeedIds(pool: { SpawnWeightEntry }): { string }
	local ids: { string } = {}
	for _, entry in pool do
		table.insert(ids, entry.feedId)
	end
	return ids
end

-- Deterministic selection: roll in [0, totalWeight). Cumulative ranges in pool order.
function ConveyorSpawnWeights.selectByRoll(pool: { SpawnWeightEntry }, roll: number): string?
	local ok, reason = ConveyorSpawnWeights.validatePool(pool)
	if not ok then
		return nil
	end
	local total = ConveyorSpawnWeights.getTotalWeight(pool)
	if typeof(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= total then
		return nil
	end

	local cumulative = 0
	for _, entry in pool do
		cumulative += entry.weight
		if roll < cumulative then
			return entry.feedId
		end
	end

	return pool[#pool].feedId
end

function ConveyorSpawnWeights.selectWithRandom(pool: { SpawnWeightEntry }, rng: Random): string?
	local ok = ConveyorSpawnWeights.validatePool(pool)
	if not ok then
		return nil
	end
	local total = ConveyorSpawnWeights.getTotalWeight(pool)
	local roll = rng:NextNumber(0, total)
	return ConveyorSpawnWeights.selectByRoll(pool, roll)
end

return ConveyorSpawnWeights
