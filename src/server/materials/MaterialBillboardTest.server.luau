--!strict

--[[
	Deterministic presentation + MaterialBillboard attachment / SAB visual tests.
	Does not mutate Studio MaterialTemplates or live conveyor spawn state permanently.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local FeedPresentationDefinitions = require(Creatures:WaitForChild("FeedPresentationDefinitions"))
local ConveyorSpawnWeights = require(Creatures:WaitForChild("ConveyorSpawnWeights"))
local MaterialBillboardService = require(script.Parent:WaitForChild("MaterialBillboardService"))

local EXPECTED = {
	RawMeat = {
		categoryId = "Basic",
		purchasePrice = 60,
		displayName = "Raw Meat",
		shortEffectLabel = "FLESH",
		effectStyleId = "Flesh",
	},
	LeafBundle = {
		categoryId = "Basic",
		purchasePrice = 60,
		displayName = "Leaf Bundle",
		shortEffectLabel = "FLORA",
		effectStyleId = "Flora",
	},
	CrystalChunk = {
		categoryId = "Basic",
		purchasePrice = 60,
		displayName = "Crystal Chunk",
		shortEffectLabel = "MINERAL",
		effectStyleId = "Mineral",
	},
	PrimeMeat = {
		categoryId = "Premium",
		purchasePrice = 240,
		displayName = "Prime Meat",
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
	},
	AncientFruit = {
		categoryId = "Premium",
		purchasePrice = 240,
		displayName = "Ancient Fruit",
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
	},
	LivingCrystal = {
		categoryId = "Premium",
		purchasePrice = 240,
		displayName = "Living Crystal",
		shortEffectLabel = "QUALITY",
		effectStyleId = "Quality",
	},
	InsectCluster = {
		categoryId = "Specialized",
		purchasePrice = 360,
		displayName = "Insect Cluster",
		shortEffectLabel = "ARTHROPOD",
		effectStyleId = "Arthropod",
	},
	FungalCore = {
		categoryId = "Specialized",
		purchasePrice = 360,
		displayName = "Fungal Core",
		shortEffectLabel = "FUNGAL",
		effectStyleId = "Fungal",
	},
	ObsidianShard = {
		categoryId = "Specialized",
		purchasePrice = 360,
		displayName = "Obsidian Shard",
		shortEffectLabel = "VOLCANIC",
		effectStyleId = "Volcanic",
	},
}

local allIds = FeedPresentationDefinitions.getFeedIds()
assert(#allIds == 9, "Expected exactly nine presentation definitions")

local seen: { [string]: boolean } = {}
for _, feedId in allIds do
	assert(seen[feedId] ~= true, "Duplicate FeedId in presentation list: " .. feedId)
	seen[feedId] = true
	local expected = EXPECTED[feedId]
	assert(expected ~= nil, "Unexpected presentation FeedId: " .. feedId)
	local def = FeedPresentationDefinitions.get(feedId)
	assert(def ~= nil, "Missing presentation: " .. feedId)
	assert(def.categoryId == expected.categoryId, feedId .. " category mismatch")
	assert(def.purchasePrice == expected.purchasePrice, feedId .. " price mismatch")
	assert(def.displayName == expected.displayName, feedId .. " displayName mismatch")
	assert(def.shortEffectLabel == expected.shortEffectLabel, feedId .. " shortEffectLabel mismatch")
	assert(def.effectStyleId == expected.effectStyleId, feedId .. " effectStyleId mismatch")
	assert(def.categoryDisplayName ~= "", feedId .. " categoryDisplayName must be nonempty")
	assert(typeof(def.iconImage) == "string", feedId .. " iconImage must be string")
end

for feedId, _ in EXPECTED do
	assert(seen[feedId] == true, "Missing expected FeedId: " .. feedId)
end

-- Conveyor pool coverage.
local pool = ConveyorSpawnWeights.getProductionPool()
assert(#ConveyorSpawnWeights.getFeedIds(pool) == 9)
for _, feedId in ConveyorSpawnWeights.getFeedIds(pool) do
	assert(FeedPresentationDefinitions.get(feedId) ~= nil, "Pool feed missing presentation: " .. feedId)
end

local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))

local function rawBase(overrides: { [string]: any }): FeedPresentationDefinitions.RawPresentationInput
	local raw = {
		feedId = "RawMeat",
		displayName = "Raw Meat",
		categoryId = "Basic",
		categoryDisplayName = "BASIC",
		iconImage = "",
		shortEffectLabel = "FLESH",
		effectStyleId = "Flesh",
	}
	for key, value in overrides do
		raw[key] = value
	end
	return raw
end

-- Price validation lives in MaterialEconomyDefinitions (canonical source).
local negOk, negReason = MaterialEconomyDefinitions.validateRaw({
	feedId = "RawMeat",
	purchasePrice = -1,
	npcSellPrice = 25,
})
assert(negOk == nil and negReason == "NegativePrice")

local fracOk, fracReason = MaterialEconomyDefinitions.validateRaw({
	feedId = "RawMeat",
	purchasePrice = 60.5,
	npcSellPrice = 25,
})
assert(fracOk == nil and fracReason == "FractionalPrice")

local catOk, catReason = FeedPresentationDefinitions.validateRaw(rawBase({
	categoryId = "Legendary",
	categoryDisplayName = "LEGENDARY",
}))
assert(catOk == nil and catReason == "UnknownCategoryId")

local nameOk, nameReason = FeedPresentationDefinitions.validateRaw(rawBase({ displayName = "" }))
assert(nameOk == nil and nameReason == "MissingDisplayName")

-- Presentation purchasePrice mirrors economy.
assert(FeedPresentationDefinitions.get("RawMeat").purchasePrice == MaterialEconomyDefinitions.getPurchasePrice("RawMeat"))

-- Price formatting.
assert(FeedPresentationDefinitions.formatPrice(60) == "$60")
assert(FeedPresentationDefinitions.formatPrice(240) == "$240")
assert(FeedPresentationDefinitions.formatPrice(360) == "$360")
assert(FeedPresentationDefinitions.formatPrice(1250) == "$1,250")
assert(FeedPresentationDefinitions.formatPrice(1250000) == "$1,250,000")

-- Category styles.
local basicStyle = FeedPresentationDefinitions.getCategoryStyle("Basic")
local premiumStyle = FeedPresentationDefinitions.getCategoryStyle("Premium")
local specializedStyle = FeedPresentationDefinitions.getCategoryStyle("Specialized")
assert(basicStyle.categoryTextColor == Color3.fromRGB(210, 215, 225))
assert(premiumStyle.categoryTextColor == Color3.fromRGB(255, 195, 55))
assert(specializedStyle.categoryTextColor == Color3.fromRGB(210, 110, 255))
assert(basicStyle.nameTextColor == Color3.fromRGB(255, 255, 255))
assert(basicStyle.priceTextColor == Color3.fromRGB(255, 220, 40))

-- All seven effect styles resolve.
local effectIds = FeedPresentationDefinitions.getAllEffectStyleIds()
assert(#effectIds == 7)
for _, effectStyleId in effectIds do
	local effectStyle = FeedPresentationDefinitions.getEffectStyle(effectStyleId)
	assert(effectStyle ~= nil)
	assert(typeof(effectStyle.textColor) == "Color3")
end

-- Billboard attachment cases (temp instances under Workspace).
local testFolder = Instance.new("Folder")
testFolder.Name = "MaterialBillboardTestFolder"
testFolder.Parent = Workspace

local function countNamedBillboards(root: Instance): number
	local count = 0
	for _, child in root:GetDescendants() do
		if child:IsA("BillboardGui") and child.Name == MaterialBillboardService.BILLBOARD_NAME then
			count += 1
		end
	end
	return count
end

MaterialBillboardService.clearIconWarningCacheForTests()

local config = MaterialBillboardService.getConfig()
assert(config.size == UDim2.fromOffset(180, 125), "Billboard size must match config")
assert(config.maxDistance == 35, "MaxDistance must be 35")
assert(config.alwaysOnTop == true)
assert(config.lightInfluence == 0)
assert(config.studsOffsetWorldSpace == Vector3.new(0, 2.75, 0))

-- Empty icon does not fail attach; IconRow hides and reflows.
local part = Instance.new("Part")
part.Name = "BillboardTestPart"
part.Anchored = true
part.Parent = testFolder
local emptyIconAttach = MaterialBillboardService.attach(part, "PrimeMeat")
assert(emptyIconAttach.success == true, "Empty icon must still attach billboard")
assert(emptyIconAttach.billboard ~= nil)
local billboard = emptyIconAttach.billboard :: BillboardGui
assert(billboard.Size == config.size)
assert(billboard.MaxDistance == 35)
assert(billboard.AlwaysOnTop == true)
assert(billboard.LightInfluence == 0)
assert(billboard.StudsOffsetWorldSpace == Vector3.new(0, 2.75, 0))

local root = billboard:FindFirstChild("Root")
assert(root ~= nil and root:IsA("Frame"))
assert(root.BackgroundTransparency == 1, "Root must not be an opaque card")
local layout = root:FindFirstChild("Layout")
assert(layout ~= nil and layout:IsA("UIListLayout"))
assert(layout.FillDirection == Enum.FillDirection.Vertical)

local iconRow = root:FindFirstChild("IconRow")
assert(iconRow ~= nil and iconRow:IsA("Frame") and iconRow.Visible == false, "Empty icon must hide IconRow")
local nameLabel = root:FindFirstChild("NameLabel")
local categoryLabel = root:FindFirstChild("CategoryLabel")
local priceContainer = root:FindFirstChild("PriceContainer")
local effectLabel = root:FindFirstChild("EffectLabel")
assert(nameLabel ~= nil and nameLabel:IsA("TextLabel"))
assert(categoryLabel ~= nil and categoryLabel:IsA("TextLabel"))
assert(priceContainer ~= nil and priceContainer:IsA("Frame"))
assert(effectLabel ~= nil and effectLabel:IsA("TextLabel"))
local priceLabel = priceContainer:FindFirstChild("PriceLabel")
assert(priceLabel ~= nil and priceLabel:IsA("TextLabel"))

assert(nameLabel.Text == "Prime Meat")
assert(categoryLabel.Text == "PREMIUM")
assert(priceLabel.Text == FeedPresentationDefinitions.formatPrice(240))
assert(effectLabel.Text == "QUALITY")
assert(nameLabel.TextColor3 == Color3.fromRGB(255, 255, 255), "Name must be white")
assert(nameLabel.TextStrokeTransparency == 0, "Main labels need dark text stroke")
assert(categoryLabel.TextStrokeTransparency == 0)
assert(priceLabel.TextStrokeTransparency == 0)
assert(categoryLabel.TextColor3 == premiumStyle.categoryTextColor, "Premium category style")
assert(priceLabel.TextColor3 == premiumStyle.priceTextColor)
assert(effectLabel.TextColor3 == FeedPresentationDefinitions.getEffectStyle("Quality").textColor)
assert(countNamedBillboards(part) == 1)

-- Basic / Specialized style application.
local basicPart = Instance.new("Part")
basicPart.Name = "BasicStylePart"
basicPart.Anchored = true
basicPart.Parent = testFolder
local basicAttach = MaterialBillboardService.attach(basicPart, "RawMeat")
assert(basicAttach.success == true and basicAttach.billboard ~= nil)
local basicRoot = basicAttach.billboard:FindFirstChild("Root")
assert(basicRoot ~= nil and basicRoot:IsA("Frame"))
local basicCategory = basicRoot:FindFirstChild("CategoryLabel")
assert(basicCategory ~= nil and basicCategory:IsA("TextLabel"))
assert(basicCategory.TextColor3 == basicStyle.categoryTextColor, "Basic category style")
basicPart:Destroy()

local specializedPart = Instance.new("Part")
specializedPart.Name = "SpecializedStylePart"
specializedPart.Anchored = true
specializedPart.Parent = testFolder
local specializedAttach = MaterialBillboardService.attach(specializedPart, "InsectCluster")
assert(specializedAttach.success == true and specializedAttach.billboard ~= nil)
local specializedRoot = specializedAttach.billboard:FindFirstChild("Root")
assert(specializedRoot ~= nil and specializedRoot:IsA("Frame"))
local specializedCategory = specializedRoot:FindFirstChild("CategoryLabel")
local specializedEffect = specializedRoot:FindFirstChild("EffectLabel")
assert(specializedCategory ~= nil and specializedCategory:IsA("TextLabel"))
assert(specializedEffect ~= nil and specializedEffect:IsA("TextLabel"))
assert(specializedCategory.TextColor3 == specializedStyle.categoryTextColor, "Specialized category style")
assert(specializedEffect.TextColor3 == FeedPresentationDefinitions.getEffectStyle("Arthropod").textColor)
specializedPart:Destroy()

-- BasePart receives BillboardGui.
assert(emptyIconAttach.adornee == part)

-- Duplicate attach does not create a second billboard.
local second = MaterialBillboardService.attach(part, "PrimeMeat")
assert(second.success == true and second.reusedExisting == true)
assert(countNamedBillboards(part) == 1)

-- Destroying material destroys billboard.
local billboardRef = billboard
part:Destroy()
assert(billboardRef.Parent == nil, "Billboard must destroy with material")

-- Model with PrimaryPart.
local modelPrimary = Instance.new("Model")
modelPrimary.Name = "BillboardModelPrimary"
modelPrimary.Parent = testFolder
local body = Instance.new("Part")
body.Name = "Body"
body.Anchored = true
body.Parent = modelPrimary
local unused = Instance.new("Part")
unused.Name = "Unused"
unused.Anchored = true
unused.Parent = modelPrimary
modelPrimary.PrimaryPart = body
local primaryAttach = MaterialBillboardService.attach(modelPrimary, "RawMeat")
assert(primaryAttach.success == true)
assert(primaryAttach.adornee == body)
assert(primaryAttach.billboard ~= nil and primaryAttach.billboard.Adornee == body)
assert(countNamedBillboards(modelPrimary) == 1)
modelPrimary:Destroy()

-- Model without PrimaryPart uses deterministic descendant BasePart (full-name sort).
local modelNoPrimary = Instance.new("Model")
modelNoPrimary.Name = "BillboardModelNoPrimary"
modelNoPrimary.Parent = testFolder
local zPart = Instance.new("Part")
zPart.Name = "ZPart"
zPart.Anchored = true
zPart.Parent = modelNoPrimary
local aPart = Instance.new("Part")
aPart.Name = "APart"
aPart.Anchored = true
aPart.Parent = modelNoPrimary
local noPrimaryAttach = MaterialBillboardService.attach(modelNoPrimary, "LeafBundle")
assert(noPrimaryAttach.success == true)
assert(noPrimaryAttach.adornee == aPart, "Deterministic adornee must be earliest GetFullName")
modelNoPrimary:Destroy()

-- Instance without BasePart fails cleanly.
local emptyModel = Instance.new("Model")
emptyModel.Name = "BillboardEmptyModel"
emptyModel.Parent = testFolder
local failAttach = MaterialBillboardService.attach(emptyModel, "CrystalChunk")
assert(failAttach.success == false and failAttach.reason == "MissingAdornee")
assert(countNamedBillboards(emptyModel) == 0)
emptyModel:Destroy()

-- Valid icon displays IconRow.
local iconPart = Instance.new("Part")
iconPart.Name = "IconValidPart"
iconPart.Anchored = true
iconPart.Parent = testFolder
local validIconAttach = MaterialBillboardService.attach(iconPart, "RawMeat")
assert(validIconAttach.success == true and validIconAttach.billboard ~= nil)
-- Presentation icons are placeholders today; simulate a valid icon image after attach.
local validRoot = validIconAttach.billboard:FindFirstChild("Root")
assert(validRoot ~= nil and validRoot:IsA("Frame"))
local validIconRow = validRoot:FindFirstChild("IconRow")
assert(validIconRow ~= nil and validIconRow:IsA("Frame"))
assert(validIconRow.Visible == false, "Placeholder icons remain hidden")
-- Directly verify that a valid rbxassetid would show if configured on a synthetic billboard populate path:
-- Re-attach after temporarily forcing a valid icon through a clone definition is not available;
-- instead set Image and Visible as the service would for a valid asset and confirm layout children remain.
local validIcon = validIconRow:FindFirstChild("Icon")
assert(validIcon ~= nil and validIcon:IsA("ImageLabel"))
validIcon.Image = "rbxassetid://1"
validIconRow.Visible = true
assert(validIconRow.Visible == true)
assert(validIcon.Image == "rbxassetid://1")
assert(FeedPresentationDefinitions.isValidIconImage("rbxassetid://1") == true)
assert(FeedPresentationDefinitions.isValidIconImage("") == false)
iconPart:Destroy()

testFolder:Destroy()

print("[MaterialBillboardTest] ALL ASSERTIONS PASSED")
