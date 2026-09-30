--!strict

--[[
	Orchestrates Savannah zone detection, banking, quests, notifications, and remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))

local DroppedBagService = require(script.Parent.DroppedBagService)
local ExpeditionEnemyService = require(script.Parent.ExpeditionEnemyService)
local ExpeditionEventService = require(script.Parent.ExpeditionEventService)
local ExpeditionQuestService = require(script.Parent.ExpeditionQuestService)
local ExpeditionRemotes = require(script.Parent.ExpeditionRemotes)
local FieldBagService = require(script.Parent.FieldBagService)
local RegionResolver = require(script.Parent.RegionResolver)
local ResourceNodeService = require(script.Parent.ResourceNodeService)

local ExpeditionService = {}

type PlayerZoneState = {
	inSavannah: boolean,
	inBank: boolean,
	inWateringHole: boolean,
	discoveredWateringHole: boolean,
}

local playerStates: { [Player]: PlayerZoneState } = {}
local started = false

local function getState(player: Player): PlayerZoneState
	local state = playerStates[player]
	if state == nil then
		state = {
			inSavannah = false,
			inBank = false,
			inWateringHole = false,
			discoveredWateringHole = false,
		}
		playerStates[player] = state
	end
	return state
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function pushFieldBag(player: Player)
	ExpeditionRemotes.fire(player, "FieldBagUpdated", FieldBagService.getSnapshot(player))
end

local function pushQuest(player: Player)
	ExpeditionRemotes.fire(player, "QuestUpdated", ExpeditionQuestService.getSnapshot(player))
end

local function enterSavannah(player: Player)
	local state = getState(player)
	state.inSavannah = true
	FieldBagService.ensureForZone(player, "Savannah")
	local quest = ExpeditionQuestService.assignNextIfNeeded(player)

	ExpeditionRemotes.fire(player, "ZoneChanged", {
		zoneId = "Savannah",
		inZone = true,
		inBank = state.inBank,
	})

	pushFieldBag(player)
	pushQuest(player)
	ExpeditionEnemyService.setPlayerZoneState(player, true, state.inBank)
end

local function exitSavannah(player: Player)
	local state = getState(player)
	state.inSavannah = false
	state.inBank = false

	ExpeditionRemotes.fire(player, "ZoneChanged", {
		zoneId = "Savannah",
		inZone = false,
		inBank = false,
	})
	pushFieldBag(player)
	ExpeditionEnemyService.setPlayerZoneState(player, false, false)
end

local function bankPlayer(player: Player)
	local ok, reason, stacks = FieldBagService.bankAll(player)
	if not ok then
		warn(string.format("[ExpeditionService] Banking failed for %s: %s", player.Name, tostring(reason)))
		return
	end

	ExpeditionRemotes.fire(player, "BankingSummary", {
		title = "LOOT SECURED",
		materials = stacks or {},
	})

	local state = getState(player)
	state.inSavannah = false
	state.inBank = false

	ExpeditionRemotes.fire(player, "ZoneChanged", {
		zoneId = "Savannah",
		inZone = false,
		inBank = false,
		banked = true,
	})
	pushFieldBag(player)
	ExpeditionEnemyService.setPlayerZoneState(player, false, false)
end

local function discoverWateringHole(player: Player)
	local state = getState(player)
	if state.discoveredWateringHole then
		return
	end
	state.discoveredWateringHole = true

	ExpeditionRemotes.fire(player, "ExpeditionNotification", {
		title = "LANDMARK DISCOVERED",
		body = "WATERING HOLE",
		kind = "Landmark",
	})
	ExpeditionQuestService.onWateringHoleDiscovered(player)
	pushQuest(player)
end

local function handleDeath(player: Player)
	local state = getState(player)
	if not state.inSavannah then
		return
	end

	local root = getRoot(player)
	local deathPosition = if root ~= nil then root.Position else ExpeditionConfig.HubCenter
	local lost = FieldBagService.takeAllMaterials(player)
	if next(lost) ~= nil then
		DroppedBagService.spawnFromDeath(player, lost, deathPosition)
	end

	ExpeditionRemotes.fire(player, "LossSummary", {
		title = "BAG DROPPED",
		materials = lost,
	})

	state.inSavannah = false
	state.inBank = false
	ExpeditionRemotes.fire(player, "ZoneChanged", {
		zoneId = "Savannah",
		inZone = false,
		inBank = false,
		died = true,
	})
	pushFieldBag(player)
	ExpeditionEnemyService.setPlayerZoneState(player, false, false)
end

local function pollPlayer(player: Player, bank: BasePart, wateringHole: BasePart)
	local root = getRoot(player)
	if root == nil then
		return
	end

	local position = root.Position
	local inBoundary = RegionResolver.isInsideSavannah(position)
	local inBank = RegionSamplingCalculator.pointInOrientedBox(position, bank.CFrame, bank.Size)
	local inHole = RegionSamplingCalculator.pointInOrientedBox(position, wateringHole.CFrame, wateringHole.Size)
	local state = getState(player)

	if inBank and (state.inSavannah or FieldBagService.getSnapshot(player).totalItems > 0) then
		if not state.inBank then
			state.inBank = true
			ExpeditionEnemyService.setPlayerZoneState(player, state.inSavannah, true)
			bankPlayer(player)
		end
		return
	end

	if inBoundary and not state.inSavannah then
		enterSavannah(player)
	elseif (not inBoundary) and state.inSavannah and not inBank then
		exitSavannah(player)
	end

	state.inBank = inBank
	ExpeditionEnemyService.setPlayerZoneState(player, state.inSavannah, state.inBank)

	if inHole and state.inSavannah then
		discoverWateringHole(player)
	end
	state.inWateringHole = inHole
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				handleDeath(player)
			end)
		end
	end)

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				handleDeath(player)
			end)
		end
	end
end

function ExpeditionService.start()
	if started then
		return
	end
	started = true

	ExpeditionRemotes.ensure()

	ResourceNodeService.onGathered(function(player, result)
		if not result.success or result.rewards == nil then
			return
		end

		if result.nodeTypeId == "InsectNest" then
			local amount = result.rewards.InsectCluster or 0
			if amount > 0 then
				ExpeditionQuestService.onInsectClusterGathered(player, amount)
			end
		elseif result.nodeTypeId == "CrystalOutcrop" then
			ExpeditionQuestService.onCrystalOutcropGathered(player)
		end

		pushFieldBag(player)
		pushQuest(player)
	end)

	FieldBagService.Updated:Connect(function(player, _snapshot)
		if player.Parent then
			pushFieldBag(player)
		end
	end)

	ExpeditionQuestService.Updated:Connect(function(player, _snapshot)
		if player.Parent then
			pushQuest(player)
		end
	end)

	ExpeditionEventService.onAnnounce(function(title, body)
		ExpeditionRemotes.fireAll("EventAnnouncement", {
			title = title,
			body = body,
		})
	end)

	ResourceNodeService.start()
	ExpeditionEnemyService.start()
	ExpeditionEventService.start()
	DroppedBagService.start()

	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end
	Players.PlayerAdded:Connect(hookPlayer)
	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
		FieldBagService.clear(player)
		ExpeditionQuestService.clear(player)
	end)

	-- Pin ZoneBoundary for the session if present (Studio asset is currently unanchored).
	RegionResolver.getZoneBoundary()
	local bank = RegionResolver.getBankZone()
	local wateringHole = RegionResolver.getWateringHole()

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				pollPlayer(player, bank, wateringHole)
			end
			task.wait(ExpeditionConfig.ZonePollIntervalSeconds)
		end
	end)

	print("[ExpeditionService] Savannah expedition slice started")
end

function ExpeditionService.startCrystalEruptionNow(): boolean
	return ExpeditionEventService.startCrystalEruptionNow()
end

return ExpeditionService
