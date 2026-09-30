--!strict

--[[
	Server-authoritative temporary expedition field bag.
	Death loss uses math.floor(stack * fieldLossFraction).
	Banking transfers atomically into secured inventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))
local FeedDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedDefinitions"))

local SecuredMaterialInventoryService = require(script.Parent.SecuredMaterialInventoryService)

export type FieldBagState = ExpeditionTypes.FieldBagState

local FieldBagService = {}

local bags: { [Player]: FieldBagState } = {}
local updatedBindable = Instance.new("BindableEvent")

FieldBagService.Updated = updatedBindable.Event

local function isPositiveInteger(amount: number): boolean
	return typeof(amount) == "number"
		and amount == amount
		and amount ~= math.huge
		and amount ~= -math.huge
		and amount > 0
		and amount == math.floor(amount)
end

local function emptyBag(zoneId: ExpeditionTypes.ZoneId?): FieldBagState
	return {
		zoneId = zoneId,
		materials = {},
		totalItems = 0,
		isBanking = false,
	}
end

local function recomputeTotal(bag: FieldBagState)
	local total = 0
	for _, amount in bag.materials do
		total += amount
	end
	bag.totalItems = total
end

local function notify(player: Player)
	updatedBindable:Fire(player, FieldBagService.getSnapshot(player))
end

function FieldBagService.getSnapshot(player: Player): FieldBagState
	local bag = bags[player]
	if bag == nil then
		return emptyBag(nil)
	end

	local materials: { [string]: number } = {}
	for feedId, amount in bag.materials do
		if amount > 0 then
			materials[feedId] = amount
		end
	end

	return {
		zoneId = bag.zoneId,
		materials = materials,
		totalItems = bag.totalItems,
		isBanking = bag.isBanking,
	}
end

function FieldBagService.ensureForZone(player: Player, zoneId: ExpeditionTypes.ZoneId)
	local bag = bags[player]
	if bag == nil then
		bags[player] = emptyBag(zoneId)
		notify(player)
		return
	end
	if bag.zoneId ~= zoneId then
		bag.zoneId = zoneId
		notify(player)
	end
end

function FieldBagService.addMaterial(player: Player, feedId: string, amount: number): (boolean, string?)
	if FeedDefinitions.get(feedId) == nil then
		return false, "UnknownFeedId"
	end
	if not isPositiveInteger(amount) then
		return false, "InvalidAmount"
	end

	local bag = bags[player]
	if bag == nil then
		bag = emptyBag(ExpeditionConfig.ZoneId :: ExpeditionTypes.ZoneId)
		bags[player] = bag
	end
	if bag.isBanking then
		return false, "Banking"
	end

	bag.materials[feedId] = (bag.materials[feedId] or 0) + amount
	recomputeTotal(bag)
	notify(player)
	return true, nil
end

function FieldBagService.addMany(player: Player, stacks: { [string]: number }): (boolean, string?)
	for feedId, amount in stacks do
		if FeedDefinitions.get(feedId) == nil then
			return false, "UnknownFeedId"
		end
		if not isPositiveInteger(amount) then
			return false, "InvalidAmount"
		end
	end

	local bag = bags[player]
	if bag == nil then
		bag = emptyBag(ExpeditionConfig.ZoneId :: ExpeditionTypes.ZoneId)
		bags[player] = bag
	end
	if bag.isBanking then
		return false, "Banking"
	end

	for feedId, amount in stacks do
		bag.materials[feedId] = (bag.materials[feedId] or 0) + amount
	end
	recomputeTotal(bag)
	notify(player)
	return true, nil
end

function FieldBagService.clear(player: Player)
	bags[player] = nil
	notify(player)
end

--[[
	Removes the entire field bag contents (for death drops).
	Returns a copy of the stacks that were taken.
]]
function FieldBagService.takeAllMaterials(player: Player): { [string]: number }
	local bag = bags[player]
	local taken: { [string]: number } = {}
	if bag == nil then
		return taken
	end

	for feedId, amount in bag.materials do
		if amount > 0 then
			taken[feedId] = amount
		end
	end

	bag.materials = {}
	bag.totalItems = 0
	notify(player)
	return taken
end

--[[
	Legacy fractional loss helper kept for tests / callers that still need it.
]]
function FieldBagService.applyDeathLoss(player: Player): { [string]: number }
	local bag = bags[player]
	local lost: { [string]: number } = {}
	if bag == nil then
		return lost
	end

	for feedId, amount in bag.materials do
		local loss = RegionSamplingCalculator.deathLossAmount(amount, ExpeditionConfig.FieldLossFraction)
		if loss > 0 then
			bag.materials[feedId] = amount - loss
			lost[feedId] = loss
			if bag.materials[feedId] <= 0 then
				bag.materials[feedId] = nil
			end
		end
	end

	recomputeTotal(bag)
	notify(player)
	return lost
end

function FieldBagService.bankAll(player: Player): (boolean, string?, { [string]: number }?)
	local bag = bags[player]
	if bag == nil or bag.totalItems <= 0 then
		return true, nil, {}
	end
	if bag.isBanking then
		return false, "AlreadyBanking", nil
	end

	bag.isBanking = true

	local stacks: { [string]: number } = {}
	for feedId, amount in bag.materials do
		if amount > 0 then
			stacks[feedId] = amount
		end
	end

	local ok, reason = SecuredMaterialInventoryService.addMany(player, stacks)
	if not ok then
		bag.isBanking = false
		return false, reason, nil
	end

	bag.materials = {}
	bag.totalItems = 0
	bag.isBanking = false
	bag.zoneId = nil
	notify(player)
	return true, nil, stacks
end

Players.PlayerRemoving:Connect(function(player)
	bags[player] = nil
end)

return FieldBagService
