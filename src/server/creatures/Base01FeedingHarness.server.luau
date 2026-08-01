--!strict

--[[
	Temporary Studio integration harness for base01 physical feeding.
	Player carries a validated feed item to FeedingPoint and presses the prompt.
	Development test only. No ownership, persistence, or real evolution.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local FeedDefinitions = require(Creatures:WaitForChild("FeedDefinitions"))

local CreatureState = require(script.Parent.CreatureState)
local FeedingService = require(script.Parent.FeedingService)

local BASE_PATH = "Workspace.Bases.base01"
local CREATURE_PLACEHOLDER_NAME = "CreaturePlaceholder"
local FEEDING_POINT_NAME = "FeedingPoint"
local PROMPT_NAME = "ProximityPrompt"
local CARRIED_ITEM_NAME = "CarriedMeat"
local CONSUMED_ATTRIBUTE = "Consumed"
local RESET_CHAT_COMMAND = "/resetbase01"

local bases = Workspace:WaitForChild("Bases")
local conveyors = Workspace:WaitForChild("Conveyors")
local spawnedMaterials = conveyors:WaitForChild("SpawnedMaterials")
local materialTemplates = ServerStorage:WaitForChild("MaterialTemplates")

local function waitForChildOfClass(parent: Instance, name: string, className: string): Instance
	local child = parent:WaitForChild(name)
	assert(child:IsA(className), string.format("%s.%s must be a %s", parent:GetFullName(), name, className))
	return child
end

local function findFeedingPointPart(feedingPointModel: Model): BasePart
	for _, child in feedingPointModel:GetChildren() do
		if child:IsA("BasePart") and child:FindFirstChild("FeedingPointLabel") ~= nil then
			return child
		end
	end

	local firstPart = feedingPointModel:FindFirstChildWhichIsA("BasePart", true)
	assert(firstPart ~= nil, "FeedingPoint has no BasePart for ProximityPrompt parenting")
	return firstPart
end

local function resolveProximityPrompt(feedingPointModel: Model, promptParent: BasePart): ProximityPrompt
	local existing = feedingPointModel:FindFirstChild(PROMPT_NAME)
	if existing ~= nil and existing:IsA("ProximityPrompt") then
		existing.Parent = promptParent
		return existing
	end

	local onPart = promptParent:FindFirstChild(PROMPT_NAME)
	if onPart ~= nil and onPart:IsA("ProximityPrompt") then
		return onPart
	end

	local created = Instance.new("ProximityPrompt")
	created.Name = PROMPT_NAME
	created.Parent = promptParent
	return created
end

-- Remove leftover cycling-test folders from earlier harness versions.
local function removeLegacyTestFeeds(feedingPointModel: Model): ()
	local legacy = feedingPointModel:FindFirstChild("DevTestFeeds")
	if legacy ~= nil then
		legacy:Destroy()
	end
end

local function normalizeFeedId(raw: string): string
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or raw
	local unquoted = string.match(trimmed, '^"(.*)"$') or string.match(trimmed, "^'(.*)'$")
	return unquoted or trimmed
end

local function isApprovedTemplateFeedId(feedId: string): boolean
	for _, template in materialTemplates:GetChildren() do
		if template:IsA("BasePart") then
			local templateFeedIdValue = template:GetAttribute("FeedId")
			if typeof(templateFeedIdValue) == "string" and normalizeFeedId(templateFeedIdValue) == feedId then
				return true
			end
		end
	end
	return false
end

local function isApprovedOrigin(item: Instance, character: Model): boolean
	-- Active spawned materials container used by ConveyorService.
	if item:IsDescendantOf(spawnedMaterials) then
		return true
	end

	-- Carried items are reparented under the character by ConveyorService.
	if item.Parent == character and item.Name == CARRIED_ITEM_NAME then
		return true
	end

	return false
end

export type FeedItemValidationFailure =
	"NoCarriedItem"
	| "NotBasePart"
	| "MissingFeedId"
	| "UnknownFeedId"
	| "UnapprovedOrigin"
	| "AlreadyConsumed"
	| "NotOwnedByPlayer"

export type FeedItemValidationResult = {
	ok: boolean,
	reason: FeedItemValidationFailure?,
	item: BasePart?,
	feedId: string?,
}

local function findCarriedFeedItem(character: Model): BasePart?
	local carried = character:FindFirstChild(CARRIED_ITEM_NAME)
	if carried ~= nil and carried:IsA("BasePart") then
		return carried
	end

	-- Fallback: any character BasePart with a FeedId attribute.
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("FeedId")) == "string" then
			return child
		end
	end

	return nil
end

local function validateCarriedFeedItem(player: Player): FeedItemValidationResult
	local character = player.Character
	if character == nil then
		return { ok = false, reason = "NoCarriedItem", item = nil, feedId = nil }
	end

	local item = findCarriedFeedItem(character)
	if item == nil then
		return { ok = false, reason = "NoCarriedItem", item = nil, feedId = nil }
	end

	if not item:IsA("BasePart") then
		return { ok = false, reason = "NotBasePart", item = nil, feedId = nil }
	end

	if item:GetAttribute(CONSUMED_ATTRIBUTE) == true then
		return { ok = false, reason = "AlreadyConsumed", item = item, feedId = nil }
	end

	if item.Parent ~= character then
		return { ok = false, reason = "NotOwnedByPlayer", item = item, feedId = nil }
	end

	if not isApprovedOrigin(item, character) then
		return { ok = false, reason = "UnapprovedOrigin", item = item, feedId = nil }
	end

	local feedIdValue = item:GetAttribute("FeedId")
	if typeof(feedIdValue) ~= "string" or feedIdValue == "" then
		return { ok = false, reason = "MissingFeedId", item = item, feedId = nil }
	end

	local feedId = normalizeFeedId(feedIdValue)
	if FeedDefinitions.get(feedId) == nil then
		return { ok = false, reason = "UnknownFeedId", item = item, feedId = feedId }
	end

	-- Must match an approved MaterialTemplates FeedId (server template system).
	if not isApprovedTemplateFeedId(feedId) then
		return { ok = false, reason = "UnapprovedOrigin", item = item, feedId = feedId }
	end

	return { ok = true, reason = nil, item = item, feedId = feedId }
end

local base01 = waitForChildOfClass(bases, "base01", "Model")
local creaturePlaceholder = waitForChildOfClass(base01, CREATURE_PLACEHOLDER_NAME, "BasePart") :: BasePart
local feedingPoint = waitForChildOfClass(base01, FEEDING_POINT_NAME, "Model") :: Model
removeLegacyTestFeeds(feedingPoint)

local feedingPointPart = findFeedingPointPart(feedingPoint)
local proximityPrompt = resolveProximityPrompt(feedingPoint, feedingPointPart)

proximityPrompt.Enabled = true
proximityPrompt.RequiresLineOfSight = false
proximityPrompt.MaxActivationDistance = 16
proximityPrompt.MaxIndicatorDistance = 40
proximityPrompt.HoldDuration = 0
proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
proximityPrompt.Style = Enum.ProximityPromptStyle.Default
proximityPrompt.ActionText = "Feed Item"
proximityPrompt.ObjectText = "base01 ProtoRex"

local consumedItemIds: { [string]: boolean } = {}
local creature = CreatureState.createProtoRex("base01-dev-creature", 0)

local function updatePlaceholderAttributes(
	snapshot: CreatureState.CreatureSnapshot,
	predictedLineageId: string
): ()
	creaturePlaceholder:SetAttribute("LineageId", snapshot.lineageId)
	creaturePlaceholder:SetAttribute("Stage", snapshot.stage)
	creaturePlaceholder:SetAttribute("FleshAffinity", snapshot.affinities.Flesh)
	creaturePlaceholder:SetAttribute("FloraAffinity", snapshot.affinities.Flora)
	creaturePlaceholder:SetAttribute("MineralAffinity", snapshot.affinities.Mineral)
	creaturePlaceholder:SetAttribute("PredictedLineageId", predictedLineageId)
end

local function resetBase01Creature(reason: string): ()
	creature = CreatureState.createProtoRex("base01-dev-creature", 0)
	local snapshot = CreatureState.getSnapshot(creature)
	updatePlaceholderAttributes(snapshot, "")
	print(string.format("[Base01FeedingHarness] Reset base01 creature (%s)", reason))
end

local initialSnapshot = CreatureState.getSnapshot(creature)
updatePlaceholderAttributes(initialSnapshot, "")

print(string.format(
	"[Base01FeedingHarness] Ready on %s. CreaturePlaceholder=%s FeedingPoint=%s PromptParent=%s ApprovedContainer=%s",
	BASE_PATH,
	creaturePlaceholder:GetFullName(),
	feedingPoint:GetFullName(),
	proximityPrompt.Parent and proximityPrompt.Parent:GetFullName() or "nil",
	spawnedMaterials:GetFullName()
))
print(string.format(
	"[Base01FeedingHarness] Dev reset: chat '%s' | Carry a FeedId item to FeedingPoint and press E",
	RESET_CHAT_COMMAND
))

proximityPrompt.Triggered:Connect(function(player: Player)
	local validation = validateCarriedFeedItem(player)
	if not validation.ok then
		warn(string.format(
			"[Base01FeedingHarness] Feed rejected for %s. reason=%s",
			player.Name,
			tostring(validation.reason)
		))
		return
	end

	local item = validation.item
	local feedId = validation.feedId
	assert(item ~= nil, "Validated item missing")
	assert(feedId ~= nil, "Validated feedId missing")

	local itemId = item.UniqueId

	if consumedItemIds[itemId] == true or item:GetAttribute(CONSUMED_ATTRIBUTE) == true then
		warn(string.format(
			"[Base01FeedingHarness] Feed rejected for %s. reason=AlreadyConsumed itemId=%s",
			player.Name,
			itemId
		))
		return
	end

	-- Mark before applying so a re-trigger cannot double-consume the same instance.
	item:SetAttribute(CONSUMED_ATTRIBUTE, true)
	consumedItemIds[itemId] = true

	local result = FeedingService.applyFeed(creature, feedId)
	if not result.success then
		-- Roll back consume markers if FeedingService rejects (unknown feed, etc.).
		item:SetAttribute(CONSUMED_ATTRIBUTE, false)
		consumedItemIds[itemId] = nil
		warn(string.format(
			"[Base01FeedingHarness] Feed rejected. feedId=%s reason=%s",
			tostring(result.feedId),
			tostring(result.reason)
		))
		return
	end

	local character = player.Character
	if character ~= nil then
		character:SetAttribute("CarryingItem", nil)
	end

	item:Destroy()

	local snapshot = CreatureState.getSnapshot(creature)
	local predicted = result.predictedEvolution
	assert(predicted ~= nil, "Expected predictedEvolution on successful feed")

	local predictedLineageId = predicted.lineageId or ""
	updatePlaceholderAttributes(snapshot, predictedLineageId)

	print(string.format(
		"[Base01FeedingHarness] Applied FeedId=%s from physical item | feeds=%d affinities={Flesh=%d, Flora=%d, Mineral=%d} predictedEligible=%s predictedLineage=%s dominant=%s",
		feedId,
		snapshot.totalFeedsConsumed,
		snapshot.affinities.Flesh,
		snapshot.affinities.Flora,
		snapshot.affinities.Mineral,
		tostring(predicted.eligible),
		tostring(predicted.lineageId),
		tostring(predicted.dominantAffinity)
	))
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		if string.lower(message) == RESET_CHAT_COMMAND then
			resetBase01Creature(player.Name)
		end
	end)
end)

for _, player in Players:GetPlayers() do
	player.Chatted:Connect(function(message: string)
		if string.lower(message) == RESET_CHAT_COMMAND then
			resetBase01Creature(player.Name)
		end
	end)
end
