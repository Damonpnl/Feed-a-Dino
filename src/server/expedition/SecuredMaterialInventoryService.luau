--!strict

--[[
	Session-only server-authoritative secured material inventory.
	No persistence. Compatible with later selling/feeding/saving.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedDefinitions"))

local SecuredMaterialInventoryService = {}

export type InventorySnapshot = {
	materials: { [string]: number },
	totalItems: number,
}

local inventories: { [Player]: { [string]: number } } = {}
local updatedBindable = Instance.new("BindableEvent")
SecuredMaterialInventoryService.Updated = updatedBindable.Event

local function notify(player: Player)
	updatedBindable:Fire(player, SecuredMaterialInventoryService.getSnapshot(player))
end

local function isPositiveInteger(amount: number): boolean
	return typeof(amount) == "number"
		and amount == amount
		and amount ~= math.huge
		and amount ~= -math.huge
		and amount > 0
		and amount == math.floor(amount)
end

local function ensure(player: Player): { [string]: number }
	local bag = inventories[player]
	if bag == nil then
		bag = {}
		inventories[player] = bag
	end
	return bag
end

function SecuredMaterialInventoryService.validateFeedId(feedId: string): boolean
	return FeedDefinitions.get(feedId) ~= nil
end

function SecuredMaterialInventoryService.getMaterialCount(player: Player, feedId: string): number
	local bag = inventories[player]
	if bag == nil then
		return 0
	end
	return bag[feedId] or 0
end

function SecuredMaterialInventoryService.hasMaterial(player: Player, feedId: string, amount: number): boolean
	if not isPositiveInteger(amount) then
		return false
	end
	return SecuredMaterialInventoryService.getMaterialCount(player, feedId) >= amount
end

function SecuredMaterialInventoryService.getSnapshot(player: Player): InventorySnapshot
	local bag = inventories[player] or {}
	local materials: { [string]: number } = {}
	local total = 0
	for feedId, amount in bag do
		if amount > 0 then
			materials[feedId] = amount
			total += amount
		end
	end
	return {
		materials = materials,
		totalItems = total,
	}
end

function SecuredMaterialInventoryService.addMaterial(player: Player, feedId: string, amount: number): (boolean, string?)
	if not SecuredMaterialInventoryService.validateFeedId(feedId) then
		return false, "UnknownFeedId"
	end
	if not isPositiveInteger(amount) then
		return false, "InvalidAmount"
	end

	local bag = ensure(player)
	bag[feedId] = (bag[feedId] or 0) + amount
	notify(player)
	return true, nil
end

function SecuredMaterialInventoryService.removeMaterial(player: Player, feedId: string, amount: number): (boolean, string?)
	if not SecuredMaterialInventoryService.validateFeedId(feedId) then
		return false, "UnknownFeedId"
	end
	if not isPositiveInteger(amount) then
		return false, "InvalidAmount"
	end

	local bag = ensure(player)
	local current = bag[feedId] or 0
	if current < amount then
		return false, "Insufficient"
	end

	local nextAmount = current - amount
	if nextAmount <= 0 then
		bag[feedId] = nil
	else
		bag[feedId] = nextAmount
	end
	notify(player)
	return true, nil
end

function SecuredMaterialInventoryService.addMany(
	player: Player,
	stacks: { [string]: number }
): (boolean, string?, { [string]: number }?)
	local applied: { [string]: number } = {}
	for feedId, amount in stacks do
		local ok, reason = SecuredMaterialInventoryService.addMaterial(player, feedId, amount)
		if not ok then
			for rollbackId, rollbackAmount in applied do
				SecuredMaterialInventoryService.removeMaterial(player, rollbackId, rollbackAmount)
			end
			return false, reason, nil
		end
		applied[feedId] = amount
	end
	return true, nil, applied
end

function SecuredMaterialInventoryService.clear(player: Player)
	inventories[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	SecuredMaterialInventoryService.clear(player)
end)

return SecuredMaterialInventoryService
