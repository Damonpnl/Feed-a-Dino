--!strict

--[[
	Per-player base feeding + stage-aware evolution harness (Stage 0–2).
	Binds to whichever base BaseService assigns (AssignedBaseName).
	Each base requires CreatureSpawn, PlayerSpawn, and FeedingPoint.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local FeedDefinitions = require(Creatures:WaitForChild("FeedDefinitions"))
local EvolutionCalculator = require(Creatures:WaitForChild("EvolutionCalculator"))

local CreatureState = require(script.Parent.CreatureState)
local FeedingService = require(script.Parent.FeedingService)
local CreatureVisualService = require(script.Parent.CreatureVisualService)
local CreatureNameTagService = require(script.Parent.CreatureNameTagService)
local PlayerBaseSessions = require(script.Parent.PlayerBaseSessions)
local ConveyorPurchaseService = require(script.Parent.Parent.economy.ConveyorPurchaseService)
local TabletCreatureSnapshotService = require(script.Parent.Parent.tablet:WaitForChild("TabletCreatureSnapshotService"))

local function notifyTabletLineage(player: Player)
	local ok, err = pcall(function()
		TabletCreatureSnapshotService.pushForPlayer(player)
	end)
	if not ok then
		warn("[PrototypeFeedingHarness] Tablet lineage push failed: " .. tostring(err))
	end
end

local CREATURE_SPAWN_NAME = "CreatureSpawn"
local PLAYER_SPAWN_NAME = "PlayerSpawn"
local FEEDING_POINT_NAME = "FeedingPoint"
local FEED_PROMPT_NAME = "ProximityPrompt"
local EVOLVE_PROMPT_NAME = "EvolveProximityPrompt"
local STATUS_BILLBOARD_NAME = "DevCreatureStatusBillboard"
local CARRIED_ITEM_NAME = "CarriedMeat"
local CONSUMED_ATTRIBUTE = "Consumed"
local ASSIGNED_BASE_ATTRIBUTE = "AssignedBaseName"
local RESET_CHAT_COMMAND = "/resetcreature"

local bases = Workspace:WaitForChild("Bases")
local conveyors = Workspace:WaitForChild("Conveyors")
local spawnedMaterials = conveyors:WaitForChild("SpawnedMaterials")
local materialTemplates = ServerStorage:WaitForChild("MaterialTemplates")

type BaseMarkers = {
	creatureSpawn: BasePart,
	playerSpawn: BasePart,
	feedingPoint: Model,
	feedingPointPart: BasePart,
}

type PlayerBaseSession = {
	player: Player,
	base: Model,
	markers: BaseMarkers,
	creature: CreatureState.CreatureState,
	feedPrompt: ProximityPrompt,
	evolvePrompt: ProximityPrompt,
	nameTagHost: BasePart,
	connections: { RBXScriptConnection },
}

local consumedItems: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function findFeedingPointPart(feedingPointModel: Model): BasePart?
	for _, child in feedingPointModel:GetChildren() do
		if child:IsA("BasePart") and child:FindFirstChild("FeedingPointLabel") ~= nil then
			return child
		end
	end

	local firstPart = feedingPointModel:FindFirstChildWhichIsA("BasePart", true)
	if firstPart ~= nil and firstPart:IsA("BasePart") then
		return firstPart
	end
	return nil
end

local function resolveBaseMarkers(base: Model): (BaseMarkers?, string?)
	local creatureSpawn = base:FindFirstChild(CREATURE_SPAWN_NAME)
	if creatureSpawn == nil or not creatureSpawn:IsA("BasePart") then
		return nil, "Missing CreatureSpawn BasePart"
	end

	local playerSpawn = base:FindFirstChild(PLAYER_SPAWN_NAME)
	if playerSpawn == nil or not playerSpawn:IsA("BasePart") then
		return nil, "Missing PlayerSpawn BasePart"
	end

	local feedingPoint = base:FindFirstChild(FEEDING_POINT_NAME)
	if feedingPoint == nil or not feedingPoint:IsA("Model") then
		return nil, "Missing FeedingPoint Model"
	end

	local feedingPointPart = findFeedingPointPart(feedingPoint)
	if feedingPointPart == nil then
		return nil, "FeedingPoint has no BasePart"
	end

	return {
		creatureSpawn = creatureSpawn,
		playerSpawn = playerSpawn,
		feedingPoint = feedingPoint,
		feedingPointPart = feedingPointPart,
	}, nil
end

local function clearOrphanVisuals(): ()
	for _, base in bases:GetChildren() do
		if not base:IsA("Model") then
			continue
		end

		local ownerUserId = base:GetAttribute("OwnerUserId")
		local hasOwner = typeof(ownerUserId) == "number"
		if hasOwner then
			continue
		end

		for _, child in base:GetChildren() do
			if child.Name == "ActiveCreature" or child.Name == "ActiveCreature_Pending" then
				print(string.format(
					"[PrototypeFeedingHarness] Clearing orphan visual on unoccupied %s (%s)",
					base.Name,
					child.Name
				))
				child:Destroy()
			end
		end
	end
end

local function validateAllBases(): ()
	for _, base in bases:GetChildren() do
		if base:IsA("Model") then
			local markers, err = resolveBaseMarkers(base)
			if markers == nil then
				warn(string.format("[PrototypeFeedingHarness] %s invalid: %s", base.Name, tostring(err)))
			else
				local feedPos = markers.feedingPointPart.Position
				local creaturePos = markers.creatureSpawn.Position
				local playerPos = markers.playerSpawn.Position
				print(string.format(
					"[PrototypeFeedingHarness] %s markers ok | CS-FP=%.1f PS-FP=%.1f",
					base.Name,
					(creaturePos - feedPos).Magnitude,
					(playerPos - feedPos).Magnitude
				))
			end
		end
	end
end

local function removeLegacyTestFeeds(feedingPointModel: Model): ()
	local legacy = feedingPointModel:FindFirstChild("DevTestFeeds")
	if legacy ~= nil then
		legacy:Destroy()
	end
end

local function resolveFeedProximityPrompt(feedingPointModel: Model, promptParent: BasePart): ProximityPrompt
	local existing = feedingPointModel:FindFirstChild(FEED_PROMPT_NAME)
	if existing ~= nil and existing:IsA("ProximityPrompt") then
		existing.Parent = promptParent
		return existing
	end

	local onPart = promptParent:FindFirstChild(FEED_PROMPT_NAME)
	if onPart ~= nil and onPart:IsA("ProximityPrompt") then
		return onPart
	end

	local created = Instance.new("ProximityPrompt")
	created.Name = FEED_PROMPT_NAME
	created.Parent = promptParent
	return created
end

local function ensureEvolvePrompt(host: BasePart): ProximityPrompt
	local existing = host:FindFirstChild(EVOLVE_PROMPT_NAME)
	if existing ~= nil and existing:IsA("ProximityPrompt") then
		return existing
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = EVOLVE_PROMPT_NAME
	prompt.ActionText = "Evolve"
	prompt.ObjectText = "Confirm Evolution"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 20
	prompt.MaxIndicatorDistance = 40
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Enabled = false
	prompt.Parent = host
	return prompt
end

local function removeLegacyStatusBillboard(host: BasePart)
	local legacy = host:FindFirstChild(STATUS_BILLBOARD_NAME)
	if legacy ~= nil then
		legacy:Destroy()
	end
end

local function updateNameTag(session: PlayerBaseSession, formId: string)
	removeLegacyStatusBillboard(session.nameTagHost)
	CreatureNameTagService.update(session.nameTagHost, formId)
end

local function configureFeedPrompt(feedPrompt: ProximityPrompt, baseName: string): ()
	feedPrompt.Enabled = true
	feedPrompt.RequiresLineOfSight = false
	feedPrompt.MaxActivationDistance = 16
	feedPrompt.MaxIndicatorDistance = 40
	feedPrompt.HoldDuration = 0
	feedPrompt.KeyboardKeyCode = Enum.KeyCode.G
	feedPrompt.Style = Enum.ProximityPromptStyle.Default
	feedPrompt.ActionText = "Feed Item"
	feedPrompt.ObjectText = baseName .. " Creature"
end

local function isCanonicalFeedId(feedId: string): boolean
	if feedId == "" then
		return false
	end
	if string.find(feedId, "[%s\"']") ~= nil then
		return false
	end
	return FeedDefinitions.get(feedId) ~= nil
end

local function isApprovedTemplateFeedId(feedId: string): boolean
	for _, template in materialTemplates:GetChildren() do
		if template:IsA("BasePart") then
			local templateFeedIdValue = template:GetAttribute("FeedId")
			if typeof(templateFeedIdValue) == "string" and templateFeedIdValue == feedId then
				return true
			end
		end
	end
	return false
end

local function isApprovedOrigin(item: Instance, character: Model): boolean
	if item:IsDescendantOf(spawnedMaterials) then
		return true
	end
	if item.Parent == character and item.Name == CARRIED_ITEM_NAME then
		return true
	end
	return false
end

export type FeedItemValidationFailure =
	"NoCarriedItem"
	| "NotBasePart"
	| "MissingFeedId"
	| "MalformedFeedId"
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
	local carried = character:FindFirstChild(CARRIED_ITEM_NAME, true)
	if carried ~= nil and carried:IsA("BasePart") then
		return carried
	end

	for _, child in character:GetDescendants() do
		if child:IsA("BasePart") and typeof(child:GetAttribute("FeedId")) == "string" then
			return child
		end
	end

	return nil
end

local function syncCarryingAttribute(character: Model): ()
	if findCarriedFeedItem(character) == nil and character:GetAttribute("CarryingItem") == true then
		character:SetAttribute("CarryingItem", nil)
	end
end

local function clearPlayerCarryState(player: Player): ()
	local character = player.Character
	if character == nil then
		return
	end

	syncCarryingAttribute(character)

	local carried = findCarriedFeedItem(character)
	if carried ~= nil then
		carried:Destroy()
	end

	character:SetAttribute("CarryingItem", nil)
end

local function validateCarriedFeedItem(player: Player): FeedItemValidationResult
	local character = player.Character
	if character == nil then
		return { ok = false, reason = "NoCarriedItem", item = nil, feedId = nil }
	end

	syncCarryingAttribute(character)

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

	if string.find(feedIdValue, "[%s\"']") ~= nil then
		return { ok = false, reason = "MalformedFeedId", item = item, feedId = feedIdValue }
	end

	if not isCanonicalFeedId(feedIdValue) then
		return { ok = false, reason = "UnknownFeedId", item = item, feedId = feedIdValue }
	end

	if not isApprovedTemplateFeedId(feedIdValue) then
		return { ok = false, reason = "UnapprovedOrigin", item = item, feedId = feedIdValue }
	end

	-- Purchased conveyor materials are owner-only.
	local isPurchased = item:GetAttribute("IsPurchased")
	if isPurchased == true then
		local ownerUserId = item:GetAttribute("OwnerUserId")
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil or ownerUserId ~= player.UserId then
			return { ok = false, reason = "NotOwnedByPlayer", item = item, feedId = feedIdValue }
		end
	elseif isPurchased == false then
		-- Unpurchased public listings cannot be fed.
		return { ok = false, reason = "UnapprovedOrigin", item = item, feedId = feedIdValue }
	end

	return { ok = true, reason = nil, item = item, feedId = feedIdValue }
end

local function refreshCreatureVisual(session: PlayerBaseSession, snapshot: CreatureState.CreatureSnapshot): boolean
	local result = CreatureVisualService.refreshVisual(
		session.base,
		CreatureVisualService.requestFromSnapshot(snapshot)
	)
	if not result.success then
		warn(string.format(
			"[PrototypeFeedingHarness] Visual refresh failed on %s formId=%s reason=%s",
			session.base.Name,
			snapshot.lineageId,
			tostring(result.reason)
		))
		return false
	end

	print(string.format(
		"[PrototypeFeedingHarness] %s visual formId=%s template=%s fallback=%s count=%d owner=%s",
		session.base.Name,
		tostring(result.formId),
		tostring(result.templateFormId),
		tostring(result.visualFallback),
		CreatureVisualService.countActiveCreatures(session.base),
		session.player.Name
	))
	return true
end

local function updateDevPresentation(session: PlayerBaseSession, snapshot: CreatureState.CreatureSnapshot): ()
	local spawn = session.markers.creatureSpawn
	local predictedForm = snapshot.predictedNextFormId or "Unknown"

	spawn:SetAttribute("FormId", snapshot.formId)
	spawn:SetAttribute("LineageId", snapshot.lineageId)
	spawn:SetAttribute("Rarity", snapshot.rarity)
	spawn:SetAttribute("Stage", snapshot.stage)
	spawn:SetAttribute("GrowthProgress", snapshot.growthProgress)
	spawn:SetAttribute("RequiredGrowth", snapshot.requiredGrowth)
	spawn:SetAttribute("StageFlesh", snapshot.stageAffinities.Flesh)
	spawn:SetAttribute("StageFlora", snapshot.stageAffinities.Flora)
	spawn:SetAttribute("StageMineral", snapshot.stageAffinities.Mineral)
	spawn:SetAttribute("HeritageFlesh", snapshot.heritageAffinities.Flesh)
	spawn:SetAttribute("HeritageFlora", snapshot.heritageAffinities.Flora)
	spawn:SetAttribute("HeritageMineral", snapshot.heritageAffinities.Mineral)
	spawn:SetAttribute("PredictedNextFormId", predictedForm)
	spawn:SetAttribute("PredictedBaseFormId", snapshot.predictedBaseFormId or "Unknown")
	spawn:SetAttribute("PredictedFinalFormId", snapshot.predictedFinalFormId or "Unknown")
	spawn:SetAttribute("StrongestInfluenceId", snapshot.strongestInfluenceId or "")
	spawn:SetAttribute("StrongestInfluenceScore", snapshot.strongestInfluenceScore)
	spawn:SetAttribute("StrongestInfluenceShare", snapshot.strongestInfluenceShare)
	spawn:SetAttribute("InfluenceStrengthLabel", snapshot.influenceStrengthLabel)
	spawn:SetAttribute("StageEvolutionQuality", snapshot.stageEvolutionQuality)
	spawn:SetAttribute("QualityPromotionBonus", snapshot.qualityPromotionBonus)
	spawn:SetAttribute("BasePromotionChance", snapshot.basePromotionChance)
	spawn:SetAttribute("AdjustedPromotionChance", snapshot.adjustedPromotionChance)
	spawn:SetAttribute("DominantEffectiveAffinity", snapshot.dominantEffectiveAffinity or "")
	spawn:SetAttribute("EvolutionReady", snapshot.evolutionReady)
	spawn:SetAttribute("EvolutionState", snapshot.evolutionState)

	-- Stage 0 and Stage 1 can evolve; Stage 2+ cannot in this slice.
	session.evolvePrompt.Enabled = snapshot.evolutionReady and snapshot.stage < 2
	if snapshot.evolutionReady and snapshot.predictedNextFormId ~= nil then
		session.evolvePrompt.ActionText = "Evolve (" .. snapshot.predictedNextFormId .. ")"
	else
		session.evolvePrompt.ActionText = "Evolve"
	end

	updateNameTag(session, snapshot.formId)
end

local function destroySession(player: Player): ()
	local session = PlayerBaseSessions.clear(player) :: PlayerBaseSession?
	if session == nil then
		return
	end

	for _, connection in session.connections do
		connection:Disconnect()
	end

	local active = CreatureVisualService.getActiveCreature(session.base)
	if active ~= nil then
		active:Destroy()
	end

	session.evolvePrompt.Enabled = false
	CreatureNameTagService.clear(session.nameTagHost)

	print(string.format(
		"[PrototypeFeedingHarness] Released session for %s on %s",
		player.Name,
		session.base.Name
	))
end

local function resetCreature(session: PlayerBaseSession, reason: string): ()
	session.creature = CreatureState.createProtoRex(
		string.format("creature-%s-%d", session.base.Name, session.player.UserId),
		session.player.UserId
	)
	local snapshot = CreatureState.getSnapshot(session.creature)
	refreshCreatureVisual(session, snapshot)
	updateDevPresentation(session, snapshot)
	notifyTabletLineage(session.player)
	print(string.format(
		"[PrototypeFeedingHarness] Reset creature on %s (%s)",
		session.base.Name,
		reason
	))
end

local function bindSession(player: Player, base: Model): ()
	if PlayerBaseSessions.getForPlayer(player) ~= nil then
		return
	end

	local existingOnBase = PlayerBaseSessions.getForBase(base) :: PlayerBaseSession?
	if existingOnBase ~= nil and existingOnBase.player ~= player then
		warn(string.format(
			"[PrototypeFeedingHarness] Base %s already bound to %s; skipping %s",
			base.Name,
			existingOnBase.player.Name,
			player.Name
		))
		return
	end

	local markers, err = resolveBaseMarkers(base)
	if markers == nil then
		warn(string.format(
			"[PrototypeFeedingHarness] Cannot bind %s to %s: %s",
			player.Name,
			base.Name,
			tostring(err)
		))
		return
	end

	removeLegacyTestFeeds(markers.feedingPoint)

	local feedPrompt = resolveFeedProximityPrompt(markers.feedingPoint, markers.feedingPointPart)
	configureFeedPrompt(feedPrompt, base.Name)
	-- Evolve/feed prompts stay on FeedingPoint so they remain reachable at the pad.
	local evolvePrompt = ensureEvolvePrompt(markers.feedingPointPart)
	removeLegacyStatusBillboard(markers.creatureSpawn)

	local creature = CreatureState.createProtoRex(
		string.format("creature-%s-%d", base.Name, player.UserId),
		player.UserId
	)

	local session: PlayerBaseSession = {
		player = player,
		base = base,
		markers = markers,
		creature = creature,
		feedPrompt = feedPrompt,
		evolvePrompt = evolvePrompt,
		nameTagHost = markers.creatureSpawn,
		connections = {},
	}

	PlayerBaseSessions.set(player, base, session)

	local snapshot = CreatureState.getSnapshot(creature)
	refreshCreatureVisual(session, snapshot)
	updateDevPresentation(session, snapshot)
	notifyTabletLineage(player)

	table.insert(session.connections, feedPrompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer ~= session.player then
			warn(string.format(
				"[PrototypeFeedingHarness] Feed rejected: %s is not owner of %s",
				triggeringPlayer.Name,
				session.base.Name
			))
			return
		end

		local validation = validateCarriedFeedItem(triggeringPlayer)
		if not validation.ok then
			warn(string.format(
				"[PrototypeFeedingHarness] Feed rejected for %s. reason=%s",
				triggeringPlayer.Name,
				tostring(validation.reason)
			))
			return
		end

		local item = validation.item
		local feedId = validation.feedId
		assert(item ~= nil, "Validated item missing")
		assert(feedId ~= nil, "Validated feedId missing")

		if consumedItems[item] == true or item:GetAttribute(CONSUMED_ATTRIBUTE) == true then
			warn(string.format(
				"[PrototypeFeedingHarness] Feed rejected for %s. reason=AlreadyConsumed item=%s",
				triggeringPlayer.Name,
				item:GetFullName()
			))
			return
		end

		item:SetAttribute(CONSUMED_ATTRIBUTE, true)
		consumedItems[item] = true

		local result = FeedingService.applyFeed(session.creature, feedId)
		if not result.success then
			item:SetAttribute(CONSUMED_ATTRIBUTE, false)
			consumedItems[item] = nil
			warn(string.format(
				"[PrototypeFeedingHarness] Feed rejected. feedId=%s reason=%s growth=%s ready=%s bonus=%s",
				tostring(result.feedId),
				tostring(result.reason),
				tostring(result.growthProgress),
				tostring(result.evolutionReady),
				tostring(result.bonusFeedRemaining)
			))
			return
		end

		local character = triggeringPlayer.Character
		if character ~= nil then
			character:SetAttribute("CarryingItem", nil)
		end

		if item:IsA("BasePart") then
			ConveyorPurchaseService.markConsumed(item)
		end
		item:Destroy()

		local feedSnapshot = CreatureState.getSnapshot(session.creature)
		updateDevPresentation(session, feedSnapshot)
		notifyTabletLineage(session.player)

		local predicted = result.predictedEvolution
		assert(predicted ~= nil, "Expected predictedEvolution on successful feed")

		print(string.format(
			"[PrototypeFeedingHarness] %s Applied FeedId=%s | feeds=%d growth=%d/%d rarity=%s predictedFamily=%s ready=%s",
			session.base.Name,
			feedId,
			feedSnapshot.totalFeedsConsumed,
			feedSnapshot.growthProgress,
			feedSnapshot.requiredGrowth,
			feedSnapshot.rarity,
			tostring(predicted.familyLabel),
			tostring(feedSnapshot.evolutionReady)
		))
	end))

	table.insert(session.connections, evolvePrompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer ~= session.player then
			warn(string.format(
				"[PrototypeFeedingHarness] Evolution rejected: %s is not owner of %s",
				triggeringPlayer.Name,
				session.base.Name
			))
			return
		end

		local confirm = FeedingService.confirmEvolution(session.creature)
		if not confirm.success then
			warn(string.format(
				"[PrototypeFeedingHarness] Evolution rejected for %s. reason=%s",
				triggeringPlayer.Name,
				tostring(confirm.reason)
			))
			return
		end

		local evolveSnapshot = confirm.snapshot
		assert(evolveSnapshot ~= nil, "Expected snapshot after confirmed evolution")
		assert(confirm.formId ~= nil or confirm.lineageId ~= nil, "Expected formId after confirmed evolution")
		assert(confirm.rarity ~= nil, "Expected rarity after confirmed evolution")

		local resolvedFormId = confirm.formId or confirm.lineageId
		assert(resolvedFormId ~= nil, "Resolved formId missing")

		refreshCreatureVisual(session, evolveSnapshot)
		updateDevPresentation(session, evolveSnapshot)
		notifyTabletLineage(session.player)
		session.evolvePrompt.Enabled = false
		session.evolvePrompt.ActionText = "Evolve"

		print(string.format(
			"[PrototypeFeedingHarness] %s Evolved form=%s rarity=%s stage=%s affinity=%s roll=%s promoted=%s",
			session.base.Name,
			resolvedFormId,
			confirm.rarity,
			tostring(confirm.stage),
			tostring(confirm.dominantEffectiveAffinity),
			tostring(confirm.roll),
			tostring(confirm.promoted)
		))
	end))

	print(string.format(
		"[PrototypeFeedingHarness] Bound %s -> %s CreatureSpawn=%s FeedingPoint=%s",
		player.Name,
		base:GetFullName(),
		markers.creatureSpawn:GetFullName(),
		markers.feedingPoint:GetFullName()
	))
end

local function tryBindPlayer(player: Player): ()
	local baseNameValue = player:GetAttribute(ASSIGNED_BASE_ATTRIBUTE)
	if typeof(baseNameValue) ~= "string" or baseNameValue == "" then
		return
	end

	local base = bases:FindFirstChild(baseNameValue)
	if base == nil or not base:IsA("Model") then
		warn(string.format(
			"[PrototypeFeedingHarness] Assigned base %s not found for %s",
			tostring(baseNameValue),
			player.Name
		))
		return
	end

	bindSession(player, base)
end

local function setupPlayer(player: Player): ()
	player.Chatted:Connect(function(message: string)
		if string.lower(message) ~= RESET_CHAT_COMMAND then
			return
		end

		local session = PlayerBaseSessions.getForPlayer(player) :: PlayerBaseSession?
		if session == nil then
			warn(string.format(
				"[PrototypeFeedingHarness] %s used %s but has no base session",
				player.Name,
				RESET_CHAT_COMMAND
			))
			return
		end

		clearPlayerCarryState(player)
		resetCreature(session, player.Name)
	end)

	player:GetAttributeChangedSignal(ASSIGNED_BASE_ATTRIBUTE):Connect(function()
		local baseNameValue = player:GetAttribute(ASSIGNED_BASE_ATTRIBUTE)
		if typeof(baseNameValue) ~= "string" or baseNameValue == "" then
			destroySession(player)
			return
		end
		tryBindPlayer(player)
	end)

	tryBindPlayer(player)
end

local validationReport = CreatureVisualService.validateSetup(bases)
CreatureVisualService.printValidationReport(validationReport)
validateAllBases()
clearOrphanVisuals()

print(string.format(
	"[PrototypeFeedingHarness] Multi-base mode. Collect E | Feed G | Evolve F | Reset chat '%s'",
	RESET_CHAT_COMMAND
))
print(string.format(
	"[PrototypeFeedingHarness] Thresholds: stage0 growth>=50 stage1 growth>=100 affinity>=30 uncommonPromote=roll<%.2f",
	EvolutionCalculator.UNCOMMON_PROMOTION_THRESHOLD
))
print("[PrototypeFeedingHarness] Waiting for BaseService AssignedBaseName on each player.")

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	destroySession(player)
end)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
