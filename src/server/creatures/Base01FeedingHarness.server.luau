--!strict

--[[
	Temporary Studio integration harness for base01 feeding.
	Development test only. No ownership, persistence, or real evolution.
]]

local Workspace = game:GetService("Workspace")

local CreatureState = require(script.Parent.CreatureState)
local FeedingService = require(script.Parent.FeedingService)

local BASE_PATH = "Workspace.Bases.base01"
local CREATURE_PLACEHOLDER_NAME = "CreaturePlaceholder"
local FEEDING_POINT_NAME = "FeedingPoint"
local PROMPT_NAME = "ProximityPrompt"
local TEST_FEEDS_FOLDER_NAME = "DevTestFeeds"

-- Server-predefined feed cycle. Clients cannot supply arbitrary FeedIds.
local TEST_FEED_IDS = table.freeze({
	"RawMeat",
	"LeafBundle",
	"CrystalChunk",
})

local function waitForChildOfClass(parent: Instance, name: string, className: string): Instance
	local child = parent:WaitForChild(name)
	assert(child:IsA(className), string.format("%s.%s must be a %s", parent:GetFullName(), name, className))
	return child
end

local bases = Workspace:WaitForChild("Bases")
local base01 = waitForChildOfClass(bases, "base01", "Model")
local creaturePlaceholder = waitForChildOfClass(base01, CREATURE_PLACEHOLDER_NAME, "BasePart") :: BasePart
local feedingPoint = waitForChildOfClass(base01, FEEDING_POINT_NAME, "Model")
local proximityPrompt = waitForChildOfClass(feedingPoint, PROMPT_NAME, "ProximityPrompt") :: ProximityPrompt

local function ensureTestFeedInstances(): Folder
	local existing = feedingPoint:FindFirstChild(TEST_FEEDS_FOLDER_NAME)
	if existing ~= nil then
		assert(existing:IsA("Folder"), "DevTestFeeds must be a Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = TEST_FEEDS_FOLDER_NAME
	folder.Parent = feedingPoint

	for _, feedId in TEST_FEED_IDS do
		local feedInstance = Instance.new("Folder")
		feedInstance.Name = feedId
		feedInstance:SetAttribute("FeedId", feedId)
		feedInstance.Parent = folder
	end

	return folder
end

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

local function readFeedIdAttribute(feedInstance: Instance): string
	local feedIdValue = feedInstance:GetAttribute("FeedId")
	assert(typeof(feedIdValue) == "string", string.format("%s.FeedId must be a string attribute", feedInstance:GetFullName()))
	assert(feedIdValue ~= "", string.format("%s.FeedId must be non-empty", feedInstance:GetFullName()))
	return feedIdValue
end

local testFeedsFolder = ensureTestFeedInstances()
local creature = CreatureState.createProtoRex("base01-dev-creature", 0)
local nextFeedIndex = 1

local function getNextTestFeedInstance(): Instance
	local feedId = TEST_FEED_IDS[nextFeedIndex]
	local feedInstance = testFeedsFolder:FindFirstChild(feedId)
	assert(feedInstance ~= nil, string.format("Missing test feed Instance for %s", feedId))
	return feedInstance
end

local function refreshPromptText(): ()
	local nextFeedInstance = getNextTestFeedInstance()
	local nextFeedId = readFeedIdAttribute(nextFeedInstance)
	proximityPrompt.ActionText = "Feed " .. nextFeedId
	proximityPrompt.ObjectText = "base01 ProtoRex"
end

local initialSnapshot = CreatureState.getSnapshot(creature)
updatePlaceholderAttributes(initialSnapshot, "")
refreshPromptText()

print(string.format(
	"[Base01FeedingHarness] Ready on %s. CreaturePlaceholder=%s FeedingPoint=%s",
	BASE_PATH,
	creaturePlaceholder:GetFullName(),
	feedingPoint:GetFullName()
))

proximityPrompt.Triggered:Connect(function(_player: Player)
	local feedInstance = getNextTestFeedInstance()
	local feedId = readFeedIdAttribute(feedInstance)

	-- Server reads FeedId from the predefined test Instance. Prompt args are ignored.
	local result = FeedingService.applyFeed(creature, feedId)
	if not result.success then
		warn(string.format(
			"[Base01FeedingHarness] Feed rejected. feedId=%s reason=%s",
			tostring(result.feedId),
			tostring(result.reason)
		))
		return
	end

	local snapshot = CreatureState.getSnapshot(creature)
	local predicted = result.predictedEvolution
	assert(predicted ~= nil, "Expected predictedEvolution on successful feed")

	local predictedLineageId = predicted.lineageId or ""
	updatePlaceholderAttributes(snapshot, predictedLineageId)

	print(string.format(
		"[Base01FeedingHarness] Applied FeedId=%s from %s | feeds=%d affinities={Flesh=%d, Flora=%d, Mineral=%d} predictedEligible=%s predictedLineage=%s dominant=%s",
		feedId,
		feedInstance:GetFullName(),
		snapshot.totalFeedsConsumed,
		snapshot.affinities.Flesh,
		snapshot.affinities.Flora,
		snapshot.affinities.Mineral,
		tostring(predicted.eligible),
		tostring(predicted.lineageId),
		tostring(predicted.dominantAffinity)
	))

	nextFeedIndex += 1
	if nextFeedIndex > #TEST_FEED_IDS then
		nextFeedIndex = 1
	end
	refreshPromptText()
end)
