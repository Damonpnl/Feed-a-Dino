--!strict

--[[
	Session-only Savannah quest tracking without quest markers.
	Rewards use completedUnclaimed until secured delivery succeeds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionQuestDefinitions = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionQuestDefinitions"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))

local WalletService = require(script.Parent.Parent.economy.WalletService)
local EconomyDebugService = require(script.Parent.Parent.economy.EconomyDebugService)
local SecuredMaterialInventoryService = require(script.Parent.SecuredMaterialInventoryService)

export type QuestRuntime = {
	questId: ExpeditionTypes.QuestId?,
	status: ExpeditionTypes.QuestStatus,
	progress: number,
	target: number,
	displayName: string,
	objectiveText: string,
	completedIds: { [ExpeditionTypes.QuestId]: boolean },
	unclaimedIds: { [ExpeditionTypes.QuestId]: boolean },
}

local ExpeditionQuestService = {}

local states: { [Player]: QuestRuntime } = {}
local updatedBindable = Instance.new("BindableEvent")
ExpeditionQuestService.Updated = updatedBindable.Event

local function emptyState(): QuestRuntime
	return {
		questId = nil,
		status = "Inactive",
		progress = 0,
		target = 0,
		displayName = "",
		objectiveText = "",
		completedIds = {},
		unclaimedIds = {},
	}
end

local function ensure(player: Player): QuestRuntime
	local state = states[player]
	if state == nil then
		state = emptyState()
		states[player] = state
	end
	return state
end

local function snapshot(state: QuestRuntime): QuestRuntime
	return {
		questId = state.questId,
		status = state.status,
		progress = state.progress,
		target = state.target,
		displayName = state.displayName,
		objectiveText = state.objectiveText,
		completedIds = state.completedIds,
		unclaimedIds = state.unclaimedIds,
	}
end

local function notify(player: Player)
	updatedBindable:Fire(player, snapshot(ensure(player)))
end

local function tryGrantRewards(player: Player, questId: ExpeditionTypes.QuestId): boolean
	local definition = ExpeditionQuestDefinitions.get(questId)
	if definition == nil then
		return false
	end

	local coinReward = definition.coinReward
	if typeof(coinReward) == "number" and coinReward > 0 then
		local ok = WalletService.addCoins(player, coinReward, "QuestReward:" .. questId)
		if ok then
			EconomyDebugService.recordQuestCoins(coinReward)
		end
		return ok
	end

	-- Legacy material rewards path (kept for empty-reward / future hybrid defs).
	local stacks: { [string]: number } = {}
	for _, reward in definition.rewards do
		if reward.feedId ~= nil and reward.amount ~= nil then
			stacks[reward.feedId] = (stacks[reward.feedId] or 0) + reward.amount
		end
	end
	if next(stacks) == nil then
		return true
	end
	local ok = SecuredMaterialInventoryService.addMany(player, stacks)
	return ok
end

local function completeQuest(player: Player, state: QuestRuntime)
	local questId = state.questId
	if questId == nil then
		return
	end

	state.status = "Completed"
	state.completedIds[questId] = true

	if tryGrantRewards(player, questId) then
		state.unclaimedIds[questId] = nil
	else
		state.status = "CompletedUnclaimed"
		state.unclaimedIds[questId] = true
	end

	state.questId = nil
	state.progress = 0
	state.target = 0
	state.displayName = ""
	state.objectiveText = ""
	notify(player)
end

function ExpeditionQuestService.getSnapshot(player: Player): QuestRuntime
	return snapshot(ensure(player))
end

function ExpeditionQuestService.retryUnclaimed(player: Player)
	local state = ensure(player)
	for questId, unclaimed in state.unclaimedIds do
		if unclaimed and tryGrantRewards(player, questId) then
			state.unclaimedIds[questId] = nil
			if state.status == "CompletedUnclaimed" then
				state.status = "Completed"
			end
		end
	end
	notify(player)
end

function ExpeditionQuestService.assignNextIfNeeded(player: Player): QuestRuntime
	local state = ensure(player)
	ExpeditionQuestService.retryUnclaimed(player)

	if state.questId ~= nil and state.status == "Active" then
		return snapshot(state)
	end

	for _, questId in ExpeditionQuestDefinitions.getOrderedIds() do
		if not state.completedIds[questId] and not state.unclaimedIds[questId] then
			local definition = ExpeditionQuestDefinitions.get(questId)
			if definition then
				state.questId = questId
				state.status = "Active"
				state.progress = 0
				state.target = definition.targetAmount
				state.displayName = definition.displayName
				state.objectiveText = definition.objectiveText
				notify(player)
				return snapshot(state)
			end
		end
	end

	state.questId = nil
	state.status = "Inactive"
	notify(player)
	return snapshot(state)
end

function ExpeditionQuestService.addProgress(player: Player, questId: ExpeditionTypes.QuestId, amount: number)
	local state = ensure(player)
	if state.questId ~= questId or state.status ~= "Active" then
		return
	end
	if amount <= 0 then
		return
	end

	state.progress = math.min(state.target, state.progress + amount)
	notify(player)

	if state.progress >= state.target then
		completeQuest(player, state)
	end
end

function ExpeditionQuestService.onInsectClusterGathered(player: Player, amount: number)
	ExpeditionQuestService.addProgress(player, "SavannahBugCollector", amount)
end

function ExpeditionQuestService.onCrystalOutcropGathered(player: Player)
	ExpeditionQuestService.addProgress(player, "SavannahCrystalSurvey", 1)
end

function ExpeditionQuestService.onWateringHoleDiscovered(player: Player)
	ExpeditionQuestService.addProgress(player, "SavannahWateringHole", 1)
end

function ExpeditionQuestService.clear(player: Player)
	states[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return ExpeditionQuestService
