--!strict

--[[
	Canonical feed presentation / planned-economy definitions for conveyor materials.
	Display-only for this slice: no purchasing or coin deduction.
	Prices and category labels are data-driven; never infer from FeedId text or model color.
]]

local ConveyorSpawnWeights = require(script.Parent.ConveyorSpawnWeights)
local MaterialEconomyDefinitions = require(script.Parent.Parent.economy.MaterialEconomyDefinitions)

local FeedPresentationDefinitions = {}

export type CategoryId = "Basic" | "Premium" | "Specialized"

export type EffectStyleId =
	"Flesh"
	| "Flora"
	| "Mineral"
	| "Quality"
	| "Arthropod"
	| "Fungal"
	| "Volcanic"

export type CategoryStyle = {
	categoryId: CategoryId,
	categoryTextColor: Color3,
	nameTextColor: Color3,
	priceTextColor: Color3,
	billboardAccentId: string,
}

export type EffectStyle = {
	effectStyleId: EffectStyleId,
	textColor: Color3,
}

export type FeedPresentationDefinition = {
	feedId: string,
	displayName: string,
	categoryId: CategoryId,
	categoryDisplayName: string,
	purchasePrice: number,
	iconImage: string,
	shortEffectLabel: string,
	effectStyleId: EffectStyleId,
	sortOrder: number,
	billboardAccentId: string,
}

export type RawPresentationInput = {
	feedId: string,
	displayName: string,
	categoryId: string,
	categoryDisplayName: string,
	iconImage: string,
	shortEffectLabel: string,
	effectStyleId: string,
	sortOrder: number?,
	billboardAccentId: string?,
}

-- Empty placeholder: hide ImageLabel at attach time. Replace per-feed via this module.
FeedPresentationDefinitions.ICON_PLACEHOLDER = ""

local VALID_CATEGORIES: { [string]: boolean } = table.freeze({
	Basic = true,
	Premium = true,
	Specialized = true,
})

local VALID_EFFECT_STYLES: { [string]: boolean } = table.freeze({
	Flesh = true,
	Flora = true,
	Mineral = true,
	Quality = true,
	Arthropod = true,
	Fungal = true,
	Volcanic = true,
})

-- SAB-style category text colors. No large card backgrounds.
local CATEGORY_STYLES: { [CategoryId]: CategoryStyle } = table.freeze({
	Basic = table.freeze({
		categoryId = "Basic" :: CategoryId,
		categoryTextColor = Color3.fromRGB(210, 215, 225),
		nameTextColor = Color3.fromRGB(255, 255, 255),
		priceTextColor = Color3.fromRGB(255, 220, 40),
		billboardAccentId = "Basic",
	}),
	Premium = table.freeze({
		categoryId = "Premium" :: CategoryId,
		categoryTextColor = Color3.fromRGB(255, 195, 55),
		nameTextColor = Color3.fromRGB(255, 255, 255),
		priceTextColor = Color3.fromRGB(255, 220, 40),
		billboardAccentId = "Premium",
	}),
	Specialized = table.freeze({
		categoryId = "Specialized" :: CategoryId,
		categoryTextColor = Color3.fromRGB(210, 110, 255),
		nameTextColor = Color3.fromRGB(255, 255, 255),
		priceTextColor = Color3.fromRGB(255, 220, 40),
		billboardAccentId = "Specialized",
	}),
})

local EFFECT_STYLES: { [EffectStyleId]: EffectStyle } = table.freeze({
	Flesh = table.freeze({
		effectStyleId = "Flesh" :: EffectStyleId,
		textColor = Color3.fromRGB(255, 90, 90),
	}),
	Flora = table.freeze({
		effectStyleId = "Flora" :: EffectStyleId,
		textColor = Color3.fromRGB(90, 220, 110),
	}),
	Mineral = table.freeze({
		effectStyleId = "Mineral" :: EffectStyleId,
		textColor = Color3.fromRGB(90, 210, 255),
	}),
	Quality = table.freeze({
		effectStyleId = "Quality" :: EffectStyleId,
		textColor = Color3.fromRGB(255, 205, 70),
	}),
	Arthropod = table.freeze({
		effectStyleId = "Arthropod" :: EffectStyleId,
		textColor = Color3.fromRGB(180, 240, 70),
	}),
	Fungal = table.freeze({
		effectStyleId = "Fungal" :: EffectStyleId,
		textColor = Color3.fromRGB(180, 120, 255),
	}),
	Volcanic = table.freeze({
		effectStyleId = "Volcanic" :: EffectStyleId,
		textColor = Color3.fromRGB(255, 120, 55),
	}),
})

local function isFiniteNumber(value: number): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonNegativeInteger(value: number): boolean
	if not isFiniteNumber(value) or value < 0 then
		return false
	end
	return value == math.floor(value)
end

-- Locale-independent integer currency formatting: 1250 -> "$1,250"
function FeedPresentationDefinitions.formatPrice(purchasePrice: number): string
	if not isNonNegativeInteger(purchasePrice) then
		error("[FeedPresentationDefinitions] formatPrice requires a nonnegative integer")
	end

	local digits = tostring(math.floor(purchasePrice))
	local withCommas = string.reverse(digits):gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(withCommas, 1, 1) == "," then
		withCommas = string.sub(withCommas, 2)
	end
	return "$" .. withCommas
end

function FeedPresentationDefinitions.getCategoryStyle(categoryId: CategoryId): CategoryStyle
	local style = CATEGORY_STYLES[categoryId]
	if style == nil then
		error(string.format("[FeedPresentationDefinitions] Unknown category style %q", tostring(categoryId)))
	end
	return style
end

function FeedPresentationDefinitions.getEffectStyle(effectStyleId: EffectStyleId): EffectStyle
	local style = EFFECT_STYLES[effectStyleId]
	if style == nil then
		error(string.format("[FeedPresentationDefinitions] Unknown effect style %q", tostring(effectStyleId)))
	end
	return style
end

function FeedPresentationDefinitions.getAllEffectStyleIds(): { EffectStyleId }
	return table.freeze({
		"Flesh" :: EffectStyleId,
		"Flora" :: EffectStyleId,
		"Mineral" :: EffectStyleId,
		"Quality" :: EffectStyleId,
		"Arthropod" :: EffectStyleId,
		"Fungal" :: EffectStyleId,
		"Volcanic" :: EffectStyleId,
	})
end

function FeedPresentationDefinitions.validateRaw(raw: RawPresentationInput): (FeedPresentationDefinition?, string?)
	if typeof(raw) ~= "table" then
		return nil, "InvalidRaw"
	end
	if typeof(raw.feedId) ~= "string" or raw.feedId == "" then
		return nil, "InvalidFeedId"
	end
	if string.find(raw.feedId, "[%s\"']") ~= nil then
		return nil, "MalformedFeedId"
	end
	if typeof(raw.displayName) ~= "string" or raw.displayName == "" then
		return nil, "MissingDisplayName"
	end
	if typeof(raw.categoryId) ~= "string" or VALID_CATEGORIES[raw.categoryId] ~= true then
		return nil, "UnknownCategoryId"
	end
	if typeof(raw.categoryDisplayName) ~= "string" or raw.categoryDisplayName == "" then
		return nil, "MissingCategoryDisplayName"
	end
	local economy = MaterialEconomyDefinitions.get(raw.feedId)
	if economy == nil then
		return nil, "MissingEconomyDefinition"
	end
	if typeof(raw.iconImage) ~= "string" then
		return nil, "InvalidIconImage"
	end
	if typeof(raw.shortEffectLabel) ~= "string" or raw.shortEffectLabel == "" then
		return nil, "MissingShortEffectLabel"
	end
	if typeof(raw.effectStyleId) ~= "string" or VALID_EFFECT_STYLES[raw.effectStyleId] ~= true then
		return nil, "UnknownEffectStyleId"
	end

	local categoryId = raw.categoryId :: CategoryId
	local effectStyleId = raw.effectStyleId :: EffectStyleId
	local style = CATEGORY_STYLES[categoryId]
	local definition: FeedPresentationDefinition = {
		feedId = raw.feedId,
		displayName = raw.displayName,
		categoryId = categoryId,
		categoryDisplayName = raw.categoryDisplayName,
		-- Mirrored from MaterialEconomyDefinitions (canonical price source).
		purchasePrice = economy.purchasePrice,
		iconImage = raw.iconImage,
		shortEffectLabel = raw.shortEffectLabel,
		effectStyleId = effectStyleId,
		sortOrder = if typeof(raw.sortOrder) == "number" then raw.sortOrder else 0,
		billboardAccentId = if typeof(raw.billboardAccentId) == "string" and raw.billboardAccentId ~= ""
			then raw.billboardAccentId
			else style.billboardAccentId,
	}
	return table.freeze(definition), nil
end

local function define(raw: RawPresentationInput): FeedPresentationDefinition
	local definition, reason = FeedPresentationDefinitions.validateRaw(raw)
	if definition == nil then
		error(string.format(
			"[FeedPresentationDefinitions] Invalid definition for %s: %s",
			tostring(raw.feedId),
			tostring(reason)
		))
	end
	return definition
end

local PLACEHOLDER = FeedPresentationDefinitions.ICON_PLACEHOLDER

local presentations: { [string]: FeedPresentationDefinition } = {
	RawMeat = define({
		feedId = "RawMeat",
		displayName = "Raw Meat",
		categoryId = "Basic",
		categoryDisplayName = "BASIC",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "FLESH",
		effectStyleId = "Flesh",
		sortOrder = 1,
	}),
	LeafBundle = define({
		feedId = "LeafBundle",
		displayName = "Leaf Bundle",
		categoryId = "Basic",
		categoryDisplayName = "BASIC",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "FLORA",
		effectStyleId = "Flora",
		sortOrder = 2,
	}),
	CrystalChunk = define({
		feedId = "CrystalChunk",
		displayName = "Crystal Chunk",
		categoryId = "Basic",
		categoryDisplayName = "BASIC",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "MINERAL",
		effectStyleId = "Mineral",
		sortOrder = 3,
	}),
	PrimeMeat = define({
		feedId = "PrimeMeat",
		displayName = "Prime Meat",
		categoryId = "Premium",
		categoryDisplayName = "PREMIUM",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
		sortOrder = 4,
	}),
	AncientFruit = define({
		feedId = "AncientFruit",
		displayName = "Ancient Fruit",
		categoryId = "Premium",
		categoryDisplayName = "PREMIUM",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
		sortOrder = 5,
	}),
	LivingCrystal = define({
		feedId = "LivingCrystal",
		displayName = "Living Crystal",
		categoryId = "Premium",
		categoryDisplayName = "PREMIUM",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
		sortOrder = 6,
	}),
	InsectCluster = define({
		feedId = "InsectCluster",
		displayName = "Insect Cluster",
		categoryId = "Specialized",
		categoryDisplayName = "SPECIALIZED",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "ARTHROPOD",
		effectStyleId = "Arthropod",
		sortOrder = 7,
	}),
	FungalCore = define({
		feedId = "FungalCore",
		displayName = "Fungal Core",
		categoryId = "Specialized",
		categoryDisplayName = "SPECIALIZED",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "FUNGAL",
		effectStyleId = "Fungal",
		sortOrder = 8,
	}),
	ObsidianShard = define({
		feedId = "ObsidianShard",
		displayName = "Obsidian Shard",
		categoryId = "Specialized",
		categoryDisplayName = "SPECIALIZED",
		iconImage = PLACEHOLDER,
		shortEffectLabel = "VOLCANIC",
		effectStyleId = "Volcanic",
		sortOrder = 9,
	}),
}

table.freeze(presentations)

-- Fail fast: every live conveyor pool feed must have presentation data.
do
	local pool = ConveyorSpawnWeights.getProductionPool()
	local poolIds = ConveyorSpawnWeights.getFeedIds(pool)
	if #poolIds ~= 9 then
		error(string.format("[FeedPresentationDefinitions] Expected 9 conveyor feeds, got %d", #poolIds))
	end
	for _, feedId in poolIds do
		if presentations[feedId] == nil then
			error(string.format("[FeedPresentationDefinitions] Missing presentation for conveyor feed %s", feedId))
		end
	end
	local presentationCount = 0
	for _ in presentations do
		presentationCount += 1
	end
	if presentationCount ~= 9 then
		error(string.format(
			"[FeedPresentationDefinitions] Expected exactly 9 presentation definitions, got %d",
			presentationCount
		))
	end
end

function FeedPresentationDefinitions.get(feedId: string): FeedPresentationDefinition?
	return presentations[feedId]
end

function FeedPresentationDefinitions.getAll(): { FeedPresentationDefinition }
	local result: { FeedPresentationDefinition } = {}
	for _, definition in presentations do
		table.insert(result, definition)
	end
	table.sort(result, function(a, b)
		if a.sortOrder == b.sortOrder then
			return a.feedId < b.feedId
		end
		return a.sortOrder < b.sortOrder
	end)
	return table.freeze(result)
end

function FeedPresentationDefinitions.getFeedIds(): { string }
	local ids: { string } = {}
	for _, definition in FeedPresentationDefinitions.getAll() do
		table.insert(ids, definition.feedId)
	end
	return table.freeze(ids)
end

function FeedPresentationDefinitions.isValidIconImage(iconImage: string): boolean
	if typeof(iconImage) ~= "string" or iconImage == "" then
		return false
	end
	return string.match(iconImage, "^rbxassetid://%d+$") ~= nil
end

return FeedPresentationDefinitions
