--!strict

--[[
	Attaches a reusable SAB-style MaterialBillboard to spawned conveyor materials.
	Created entirely in code (no Studio/Rojo UI template).
	Display-only: never mutates progression state or handles purchasing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local FeedPresentationDefinitions = require(Creatures:WaitForChild("FeedPresentationDefinitions"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))

local MaterialBillboardService = {}

MaterialBillboardService.BILLBOARD_NAME = "MaterialBillboard"

-- Centralized visual constants. Do not scatter these through construction helpers.
local BILLBOARD_CONFIG = table.freeze({
	size = UDim2.fromOffset(180, 125),
	maxDistance = 35,
	studsOffsetWorldSpace = Vector3.new(0, 2.75, 0),
	alwaysOnTop = true,
	lightInfluence = 0,
	clipsDescendants = false,

	iconSize = 36,
	listPadding = 1,

	nameHeight = 30,
	categoryHeight = 20,
	priceHeight = 24,
	effectHeight = 16,

	nameMaxTextSize = 26,
	nameMinTextSize = 12,
	categoryMaxTextSize = 18,
	categoryMinTextSize = 10,
	priceMaxTextSize = 21,
	priceMinTextSize = 12,
	effectMaxTextSize = 14,
	effectMinTextSize = 10,

	textStrokeColor = Color3.fromRGB(0, 0, 0),
	textStrokeTransparency = 0,
	effectStrokeTransparency = 0.15,

	priceBackgroundColor = Color3.fromRGB(20, 20, 24),
	priceBackgroundTransparency = 0.35,
	priceCornerRadius = 6,
	priceStrokeColor = Color3.fromRGB(0, 0, 0),
	priceStrokeThickness = 1,
	priceStrokeTransparency = 0.25,
	priceContainerWidth = 96,

	primaryFont = Enum.Font.FredokaOne,
	secondaryFont = Enum.Font.GothamBold,

	zIcon = 2,
	zText = 3,
	zPrice = 4,
})

export type AttachResult = {
	success: boolean,
	billboard: BillboardGui?,
	adornee: BasePart?,
	reason: string?,
	reusedExisting: boolean?,
}

local warnedMissingIcon: { [string]: boolean } = {}

local function isValidRbxAssetId(iconImage: string): boolean
	return FeedPresentationDefinitions.isValidIconImage(iconImage)
end

function MaterialBillboardService.formatPrice(price: number): string
	return FeedPresentationDefinitions.formatPrice(price)
end

function MaterialBillboardService.formatResourceCharges(charges: number): string
	if charges <= 0 then
		return "Depleted"
	end
	if charges == 1 then
		return "1 collect left"
	end
	return string.format("%d collects left", charges)
end

function MaterialBillboardService.setBottomLabelText(billboard: BillboardGui, text: string): boolean
	local root = billboard:FindFirstChild("Root")
	if root == nil or not root:IsA("Frame") then
		return false
	end
	local priceContainer = root:FindFirstChild("PriceContainer")
	if priceContainer == nil then
		return false
	end
	local priceLabel = priceContainer:FindFirstChild("PriceLabel")
	if priceLabel == nil or not priceLabel:IsA("TextLabel") then
		return false
	end
	priceLabel.Text = text
	return true
end

function MaterialBillboardService.setDisplayNameText(billboard: BillboardGui, text: string): boolean
	local root = billboard:FindFirstChild("Root")
	if root == nil or not root:IsA("Frame") then
		return false
	end
	local nameLabel = root:FindFirstChild("NameLabel")
	if nameLabel == nil or not nameLabel:IsA("TextLabel") then
		return false
	end
	nameLabel.Text = text
	return true
end

function MaterialBillboardService.setCategoryText(billboard: BillboardGui, text: string): boolean
	local root = billboard:FindFirstChild("Root")
	if root == nil or not root:IsA("Frame") then
		return false
	end
	local categoryLabel = root:FindFirstChild("CategoryLabel")
	if categoryLabel == nil or not categoryLabel:IsA("TextLabel") then
		return false
	end
	categoryLabel.Text = text
	categoryLabel.Visible = text ~= ""
	return true
end

function MaterialBillboardService.updateResourceCharges(billboard: BillboardGui, charges: number): boolean
	return MaterialBillboardService.setBottomLabelText(
		billboard,
		MaterialBillboardService.formatResourceCharges(charges)
	)
end

function MaterialBillboardService.getConfig()
	return BILLBOARD_CONFIG
end

-- Resolve the primary visual BasePart for BasePart or Model templates.
function MaterialBillboardService.resolveAdornee(materialInstance: Instance): BasePart?
	if materialInstance:IsA("BasePart") then
		return materialInstance
	end

	if materialInstance:IsA("Model") then
		local primary = materialInstance.PrimaryPart
		if primary ~= nil and primary:IsA("BasePart") and primary:IsDescendantOf(materialInstance) then
			return primary
		end

		local candidates: { BasePart } = {}
		for _, descendant in materialInstance:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(candidates, descendant)
			end
		end
		if #candidates == 0 then
			return nil
		end

		table.sort(candidates, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
		return candidates[1]
	end

	return nil
end

local function findExistingBillboard(materialInstance: Instance, adornee: BasePart): BillboardGui?
	local onMaterial = materialInstance:FindFirstChild(MaterialBillboardService.BILLBOARD_NAME)
	if onMaterial ~= nil and onMaterial:IsA("BillboardGui") then
		return onMaterial
	end
	local onAdornee = adornee:FindFirstChild(MaterialBillboardService.BILLBOARD_NAME)
	if onAdornee ~= nil and onAdornee:IsA("BillboardGui") then
		return onAdornee
	end
	return nil
end

local function addTextSizeConstraint(label: TextLabel, minSize: number, maxSize: number): ()
	local existing = label:FindFirstChildOfClass("UITextSizeConstraint")
	if existing ~= nil then
		existing.MinTextSize = minSize
		existing.MaxTextSize = maxSize
		return
	end
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local function styleMainLabel(
	label: TextLabel,
	font: Enum.Font,
	textColor: Color3,
	strokeTransparency: number,
	minSize: number,
	maxSize: number,
	zIndex: number
): ()
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = false
	label.RichText = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = BILLBOARD_CONFIG.textStrokeColor
	label.TextStrokeTransparency = strokeTransparency
	label.ZIndex = zIndex
	addTextSizeConstraint(label, minSize, maxSize)
end

local function buildBillboardTemplate(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = MaterialBillboardService.BILLBOARD_NAME
	billboard.Size = BILLBOARD_CONFIG.size
	billboard.StudsOffsetWorldSpace = BILLBOARD_CONFIG.studsOffsetWorldSpace
	billboard.AlwaysOnTop = BILLBOARD_CONFIG.alwaysOnTop
	billboard.LightInfluence = BILLBOARD_CONFIG.lightInfluence
	billboard.MaxDistance = BILLBOARD_CONFIG.maxDistance
	billboard.ClipsDescendants = BILLBOARD_CONFIG.clipsDescendants
	billboard.ResetOnSpawn = false
	billboard.Active = false

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = billboard

	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, BILLBOARD_CONFIG.listPadding)
	list.Parent = root

	local iconRow = Instance.new("Frame")
	iconRow.Name = "IconRow"
	iconRow.LayoutOrder = 1
	iconRow.Size = UDim2.fromOffset(BILLBOARD_CONFIG.iconSize, BILLBOARD_CONFIG.iconSize)
	iconRow.BackgroundTransparency = 1
	iconRow.BorderSizePixel = 0
	iconRow.Visible = false
	iconRow.ZIndex = BILLBOARD_CONFIG.zIcon
	iconRow.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = BILLBOARD_CONFIG.zIcon
	icon.Parent = iconRow

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.LayoutOrder = 2
	nameLabel.Size = UDim2.new(1, 0, 0, BILLBOARD_CONFIG.nameHeight)
	nameLabel.Parent = root
	styleMainLabel(
		nameLabel,
		BILLBOARD_CONFIG.primaryFont,
		Color3.fromRGB(255, 255, 255),
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.nameMinTextSize,
		BILLBOARD_CONFIG.nameMaxTextSize,
		BILLBOARD_CONFIG.zText
	)

	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Name = "CategoryLabel"
	categoryLabel.LayoutOrder = 3
	categoryLabel.Size = UDim2.new(1, 0, 0, BILLBOARD_CONFIG.categoryHeight)
	categoryLabel.Parent = root
	styleMainLabel(
		categoryLabel,
		BILLBOARD_CONFIG.primaryFont,
		Color3.fromRGB(210, 215, 225),
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.categoryMinTextSize,
		BILLBOARD_CONFIG.categoryMaxTextSize,
		BILLBOARD_CONFIG.zText
	)

	local priceContainer = Instance.new("Frame")
	priceContainer.Name = "PriceContainer"
	priceContainer.LayoutOrder = 4
	priceContainer.Size = UDim2.fromOffset(BILLBOARD_CONFIG.priceContainerWidth, BILLBOARD_CONFIG.priceHeight)
	priceContainer.BackgroundColor3 = BILLBOARD_CONFIG.priceBackgroundColor
	priceContainer.BackgroundTransparency = BILLBOARD_CONFIG.priceBackgroundTransparency
	priceContainer.BorderSizePixel = 0
	priceContainer.ZIndex = 1
	priceContainer.Parent = root

	local priceCorner = Instance.new("UICorner")
	priceCorner.CornerRadius = UDim.new(0, BILLBOARD_CONFIG.priceCornerRadius)
	priceCorner.Parent = priceContainer

	local priceStroke = Instance.new("UIStroke")
	priceStroke.Color = BILLBOARD_CONFIG.priceStrokeColor
	priceStroke.Thickness = BILLBOARD_CONFIG.priceStrokeThickness
	priceStroke.Transparency = BILLBOARD_CONFIG.priceStrokeTransparency
	priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	priceStroke.Parent = priceContainer

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.fromScale(1, 1)
	priceLabel.Parent = priceContainer
	styleMainLabel(
		priceLabel,
		BILLBOARD_CONFIG.primaryFont,
		Color3.fromRGB(255, 220, 40),
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.priceMinTextSize,
		BILLBOARD_CONFIG.priceMaxTextSize,
		BILLBOARD_CONFIG.zPrice
	)

	local effectLabel = Instance.new("TextLabel")
	effectLabel.Name = "EffectLabel"
	effectLabel.LayoutOrder = 5
	effectLabel.Size = UDim2.new(1, 0, 0, BILLBOARD_CONFIG.effectHeight)
	effectLabel.Parent = root
	styleMainLabel(
		effectLabel,
		BILLBOARD_CONFIG.secondaryFont,
		Color3.fromRGB(200, 200, 200),
		BILLBOARD_CONFIG.effectStrokeTransparency,
		BILLBOARD_CONFIG.effectMinTextSize,
		BILLBOARD_CONFIG.effectMaxTextSize,
		BILLBOARD_CONFIG.zText
	)

	return billboard
end

local function populateBillboard(
	billboard: BillboardGui,
	definition: FeedPresentationDefinitions.FeedPresentationDefinition
): ()
	-- Keep billboard properties synced to centralized config (including reused instances).
	billboard.Size = BILLBOARD_CONFIG.size
	billboard.StudsOffsetWorldSpace = BILLBOARD_CONFIG.studsOffsetWorldSpace
	billboard.AlwaysOnTop = BILLBOARD_CONFIG.alwaysOnTop
	billboard.LightInfluence = BILLBOARD_CONFIG.lightInfluence
	billboard.MaxDistance = BILLBOARD_CONFIG.maxDistance
	billboard.ClipsDescendants = BILLBOARD_CONFIG.clipsDescendants

	local root = billboard:FindFirstChild("Root")
	if root == nil or not root:IsA("Frame") then
		error("[MaterialBillboardService] Billboard missing Root frame")
	end

	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)

	local layout = root:FindFirstChild("Layout")
	assert(layout ~= nil and layout:IsA("UIListLayout"), "Missing vertical Layout")

	local iconRow = root:FindFirstChild("IconRow")
	local nameLabel = root:FindFirstChild("NameLabel")
	local categoryLabel = root:FindFirstChild("CategoryLabel")
	local priceContainer = root:FindFirstChild("PriceContainer")
	local effectLabel = root:FindFirstChild("EffectLabel")

	assert(iconRow ~= nil and iconRow:IsA("Frame"), "Missing IconRow")
	assert(nameLabel ~= nil and nameLabel:IsA("TextLabel"), "Missing NameLabel")
	assert(categoryLabel ~= nil and categoryLabel:IsA("TextLabel"), "Missing CategoryLabel")
	assert(priceContainer ~= nil and priceContainer:IsA("Frame"), "Missing PriceContainer")
	assert(effectLabel ~= nil and effectLabel:IsA("TextLabel"), "Missing EffectLabel")

	local icon = iconRow:FindFirstChild("Icon")
	local priceLabel = priceContainer:FindFirstChild("PriceLabel")
	assert(icon ~= nil and icon:IsA("ImageLabel"), "Missing Icon")
	assert(priceLabel ~= nil and priceLabel:IsA("TextLabel"), "Missing PriceLabel")

	local categoryStyle = FeedPresentationDefinitions.getCategoryStyle(definition.categoryId)
	local effectStyle = FeedPresentationDefinitions.getEffectStyle(definition.effectStyleId)

	styleMainLabel(
		nameLabel,
		BILLBOARD_CONFIG.primaryFont,
		categoryStyle.nameTextColor,
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.nameMinTextSize,
		BILLBOARD_CONFIG.nameMaxTextSize,
		BILLBOARD_CONFIG.zText
	)
	styleMainLabel(
		categoryLabel,
		BILLBOARD_CONFIG.primaryFont,
		categoryStyle.categoryTextColor,
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.categoryMinTextSize,
		BILLBOARD_CONFIG.categoryMaxTextSize,
		BILLBOARD_CONFIG.zText
	)
	styleMainLabel(
		priceLabel,
		BILLBOARD_CONFIG.primaryFont,
		categoryStyle.priceTextColor,
		BILLBOARD_CONFIG.textStrokeTransparency,
		BILLBOARD_CONFIG.priceMinTextSize,
		BILLBOARD_CONFIG.priceMaxTextSize,
		BILLBOARD_CONFIG.zPrice
	)
	styleMainLabel(
		effectLabel,
		BILLBOARD_CONFIG.secondaryFont,
		effectStyle.textColor,
		BILLBOARD_CONFIG.effectStrokeTransparency,
		BILLBOARD_CONFIG.effectMinTextSize,
		BILLBOARD_CONFIG.effectMaxTextSize,
		BILLBOARD_CONFIG.zText
	)

	nameLabel.Text = definition.displayName
	categoryLabel.Text = definition.categoryDisplayName
	local economyPrice = MaterialEconomyDefinitions.getPurchasePrice(definition.feedId)
	local price = if economyPrice ~= nil then economyPrice else definition.purchasePrice
	priceLabel.Text = FeedPresentationDefinitions.formatPrice(price)
	effectLabel.Text = definition.shortEffectLabel

	priceContainer.BackgroundColor3 = BILLBOARD_CONFIG.priceBackgroundColor
	priceContainer.BackgroundTransparency = BILLBOARD_CONFIG.priceBackgroundTransparency

	if isValidRbxAssetId(definition.iconImage) then
		icon.Image = definition.iconImage
		iconRow.Visible = true
	else
		icon.Image = ""
		iconRow.Visible = false
		if warnedMissingIcon[definition.feedId] ~= true then
			warnedMissingIcon[definition.feedId] = true
			warn(string.format(
				"[MaterialBillboardService] FeedId=%s has empty/invalid iconImage; hiding IconRow",
				definition.feedId
			))
		end
	end
end

function MaterialBillboardService.attach(materialInstance: Instance, feedId: string): AttachResult
	if typeof(materialInstance) ~= "Instance" then
		return { success = false, reason = "InvalidMaterialInstance" }
	end
	if typeof(feedId) ~= "string" or feedId == "" then
		return { success = false, reason = "InvalidFeedId" }
	end

	local definition = FeedPresentationDefinitions.get(feedId)
	if definition == nil then
		warn(string.format(
			"[MaterialBillboardService] No presentation definition for FeedId=%s; skipping billboard",
			feedId
		))
		return { success = false, reason = "MissingPresentation" }
	end

	local adornee = MaterialBillboardService.resolveAdornee(materialInstance)
	if adornee == nil then
		warn(string.format(
			"[MaterialBillboardService] No BasePart adornee for FeedId=%s on %s; skipping billboard",
			feedId,
			materialInstance:GetFullName()
		))
		return { success = false, reason = "MissingAdornee" }
	end

	local existing = findExistingBillboard(materialInstance, adornee)
	if existing ~= nil then
		existing.Adornee = adornee
		populateBillboard(existing, definition)
		return {
			success = true,
			billboard = existing,
			adornee = adornee,
			reusedExisting = true,
		}
	end

	local billboard = buildBillboardTemplate()
	billboard.Adornee = adornee
	billboard.Parent = materialInstance
	populateBillboard(billboard, definition)

	return {
		success = true,
		billboard = billboard,
		adornee = adornee,
		reusedExisting = false,
	}
end

function MaterialBillboardService.attachResourceNode(
	materialInstance: Instance,
	feedId: string,
	displayName: string,
	charges: number
): AttachResult
	local attachResult = MaterialBillboardService.attach(materialInstance, feedId)
	if not attachResult.success or attachResult.billboard == nil then
		return attachResult
	end

	local root = attachResult.billboard:FindFirstChild("Root")
	if root ~= nil and root:IsA("Frame") then
		local priceContainer = root:FindFirstChild("PriceContainer")
		if priceContainer ~= nil and priceContainer:IsA("Frame") then
			priceContainer.Size = UDim2.fromOffset(130, BILLBOARD_CONFIG.priceHeight)
		end
	end

	MaterialBillboardService.setDisplayNameText(attachResult.billboard, displayName)
	MaterialBillboardService.updateResourceCharges(attachResult.billboard, charges)
	return attachResult
end

export type CustomBillboardOptions = {
	displayName: string,
	categoryText: string?,
	bottomText: string?,
	effectText: string?,
	maxDistance: number?,
	hideIcon: boolean?,
}

function MaterialBillboardService.formatCountdown(remainingSeconds: number): string
	local seconds = math.max(0, math.ceil(remainingSeconds))
	local minutes = math.floor(seconds / 60)
	local rem = seconds % 60
	return string.format("%d:%02d", minutes, rem)
end

--[[
	Attach a SAB-style billboard with arbitrary labels (no FeedId required).
	Uses InsectCluster presentation as a structural seed, then overwrites text.
]]
function MaterialBillboardService.attachCustom(
	materialInstance: Instance,
	options: CustomBillboardOptions
): AttachResult
	local seedFeedId = "InsectCluster"
	local attachResult = MaterialBillboardService.attach(materialInstance, seedFeedId)
	if not attachResult.success or attachResult.billboard == nil then
		return attachResult
	end

	local billboard = attachResult.billboard
	if options.maxDistance ~= nil then
		billboard.MaxDistance = options.maxDistance
	end

	local root = billboard:FindFirstChild("Root")
	if root ~= nil and root:IsA("Frame") then
		if options.hideIcon ~= false then
			local iconRow = root:FindFirstChild("IconRow")
			if iconRow ~= nil and iconRow:IsA("GuiObject") then
				iconRow.Visible = false
			end
		end
		local effectLabel = root:FindFirstChild("EffectLabel")
		if effectLabel ~= nil and effectLabel:IsA("TextLabel") then
			if options.effectText ~= nil and options.effectText ~= "" then
				effectLabel.Visible = true
				effectLabel.Text = options.effectText
			else
				effectLabel.Visible = false
			end
		end
		local categoryLabel = root:FindFirstChild("CategoryLabel")
		if categoryLabel ~= nil and categoryLabel:IsA("TextLabel") then
			categoryLabel.Text = options.categoryText or ""
			categoryLabel.Visible = options.categoryText ~= nil and options.categoryText ~= ""
		end
		local priceContainer = root:FindFirstChild("PriceContainer")
		if priceContainer ~= nil and priceContainer:IsA("Frame") then
			priceContainer.Size = UDim2.fromOffset(110, BILLBOARD_CONFIG.priceHeight)
		end
	end

	MaterialBillboardService.setDisplayNameText(billboard, options.displayName)
	if options.bottomText ~= nil then
		MaterialBillboardService.setBottomLabelText(billboard, options.bottomText)
	end

	return attachResult
end

-- Test helper: clear one-time icon warning cache.
function MaterialBillboardService.clearIconWarningCacheForTests(): ()
	table.clear(warnedMissingIcon)
end

return MaterialBillboardService
