--!strict

--[[
	Canonical material economy definitions.
	Single authoritative source for purchasePrice and npcSellPrice.
]]

local ConveyorSpawnWeights = require(script.Parent.Parent.creatures.ConveyorSpawnWeights)

local MaterialEconomyDefinitions = {}

export type MaterialEconomyDefinition = {
	feedId: string,
	purchasePrice: number,
	npcSellPrice: number,
	tradeableLater: boolean,
	sellableToNpc: boolean,
}

export type RawEconomyInput = {
	feedId: string,
	purchasePrice: number,
	npcSellPrice: number,
	tradeableLater: boolean?,
	sellableToNpc: boolean?,
}

local function isFiniteNumber(value: number): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: number): boolean
	if not isFiniteNumber(value) or value < 0 then
		return false
	end
	return value == math.floor(value)
end

function MaterialEconomyDefinitions.validateRaw(raw: RawEconomyInput): (MaterialEconomyDefinition?, string?)
	if typeof(raw.feedId) ~= "string" or raw.feedId == "" then
		return nil, "MissingFeedId"
	end
	if not isNonNegativeInteger(raw.purchasePrice) then
		if typeof(raw.purchasePrice) == "number" and raw.purchasePrice < 0 then
			return nil, "NegativePrice"
		end
		if typeof(raw.purchasePrice) == "number" and raw.purchasePrice ~= math.floor(raw.purchasePrice) then
			return nil, "FractionalPrice"
		end
		return nil, "InvalidPurchasePrice"
	end
	if not isNonNegativeInteger(raw.npcSellPrice) then
		if typeof(raw.npcSellPrice) == "number" and raw.npcSellPrice < 0 then
			return nil, "NegativePrice"
		end
		if typeof(raw.npcSellPrice) == "number" and raw.npcSellPrice ~= math.floor(raw.npcSellPrice) then
			return nil, "FractionalPrice"
		end
		return nil, "InvalidNpcSellPrice"
	end

	return table.freeze({
		feedId = raw.feedId,
		purchasePrice = raw.purchasePrice,
		npcSellPrice = raw.npcSellPrice,
		tradeableLater = if raw.tradeableLater == nil then true else raw.tradeableLater,
		sellableToNpc = if raw.sellableToNpc == nil then true else raw.sellableToNpc,
	}), nil
end

local function define(raw: RawEconomyInput): MaterialEconomyDefinition
	local definition, reason = MaterialEconomyDefinitions.validateRaw(raw)
	if definition == nil then
		error(string.format(
			"[MaterialEconomyDefinitions] Invalid definition for %s: %s",
			tostring(raw.feedId),
			tostring(reason)
		))
	end
	return definition
end

local definitions: { [string]: MaterialEconomyDefinition } = {
	RawMeat = define({
		feedId = "RawMeat",
		purchasePrice = 60,
		npcSellPrice = 25,
	}),
	LeafBundle = define({
		feedId = "LeafBundle",
		purchasePrice = 60,
		npcSellPrice = 25,
	}),
	CrystalChunk = define({
		feedId = "CrystalChunk",
		purchasePrice = 60,
		npcSellPrice = 25,
	}),
	PrimeMeat = define({
		feedId = "PrimeMeat",
		purchasePrice = 240,
		npcSellPrice = 100,
	}),
	AncientFruit = define({
		feedId = "AncientFruit",
		purchasePrice = 240,
		npcSellPrice = 100,
	}),
	LivingCrystal = define({
		feedId = "LivingCrystal",
		purchasePrice = 240,
		npcSellPrice = 100,
	}),
	InsectCluster = define({
		feedId = "InsectCluster",
		purchasePrice = 360,
		npcSellPrice = 150,
	}),
	FungalCore = define({
		feedId = "FungalCore",
		purchasePrice = 360,
		npcSellPrice = 150,
	}),
	ObsidianShard = define({
		feedId = "ObsidianShard",
		purchasePrice = 360,
		npcSellPrice = 150,
	}),
}

table.freeze(definitions)

do
	local pool = ConveyorSpawnWeights.getProductionPool()
	local poolIds = ConveyorSpawnWeights.getFeedIds(pool)
	for _, feedId in poolIds do
		if definitions[feedId] == nil then
			error(string.format(
				"[MaterialEconomyDefinitions] Live conveyor feed %s missing economy definition",
				feedId
			))
		end
	end
	local count = 0
	for _ in definitions do
		count += 1
	end
	if count ~= 9 then
		error(string.format("[MaterialEconomyDefinitions] Expected 9 definitions, got %d", count))
	end
end

function MaterialEconomyDefinitions.get(feedId: string): MaterialEconomyDefinition?
	return definitions[feedId]
end

function MaterialEconomyDefinitions.getPurchasePrice(feedId: string): number?
	local definition = definitions[feedId]
	if definition == nil then
		return nil
	end
	return definition.purchasePrice
end

function MaterialEconomyDefinitions.getNpcSellPrice(feedId: string): number?
	local definition = definitions[feedId]
	if definition == nil then
		return nil
	end
	return definition.npcSellPrice
end

function MaterialEconomyDefinitions.getAll(): { MaterialEconomyDefinition }
	local result: { MaterialEconomyDefinition } = {}
	for _, definition in definitions do
		table.insert(result, definition)
	end
	table.sort(result, function(a, b)
		return a.feedId < b.feedId
	end)
	return table.freeze(result)
end

function MaterialEconomyDefinitions.getFeedIds(): { string }
	local ids: { string } = {}
	for _, definition in MaterialEconomyDefinitions.getAll() do
		table.insert(ids, definition.feedId)
	end
	return table.freeze(ids)
end

function MaterialEconomyDefinitions.validateLivePoolCoverage(): (boolean, string?)
	local pool = ConveyorSpawnWeights.getProductionPool()
	for _, feedId in ConveyorSpawnWeights.getFeedIds(pool) do
		if definitions[feedId] == nil then
			return false, "MissingEconomyDefinition:" .. feedId
		end
	end
	return true, nil
end

return MaterialEconomyDefinitions
