--!strict

--[[
	Bootstraps wallet, sell station, inventory sync, and economy remotes.
]]

local Players = game:GetService("Players")

local WalletService = require(script.Parent.WalletService)
local EconomyRemotes = require(script.Parent.EconomyRemotes)
local EconomyDebugService = require(script.Parent.EconomyDebugService)
local NpcSellService = require(script.Parent.NpcSellService)
local ConveyorPurchaseService = require(script.Parent.ConveyorPurchaseService)
local SecuredMaterialInventoryService = require(script.Parent.Parent.expedition.SecuredMaterialInventoryService)

local EconomyService = {}

local started = false

local function pushWallet(player: Player)
	EconomyRemotes.fire(player, "WalletUpdated", WalletService.getSnapshot(player))
end

local function pushInventory(player: Player)
	EconomyRemotes.fire(player, "InventoryUpdated", SecuredMaterialInventoryService.getSnapshot(player))
end

function EconomyService.start()
	if started then
		return
	end
	started = true

	EconomyRemotes.ensure()
	ConveyorPurchaseService.start()
	NpcSellService.start()

	WalletService.Updated:Connect(function(player, _snapshot)
		if player.Parent then
			pushWallet(player)
		end
	end)

	SecuredMaterialInventoryService.Updated:Connect(function(player, _snapshot)
		if player.Parent then
			pushInventory(player)
		end
	end)

	local function hookPlayer(player: Player)
		WalletService.initializePlayer(player)
		pushWallet(player)
		pushInventory(player)
	end

	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end
	Players.PlayerAdded:Connect(hookPlayer)

	print("[EconomyService] Material economy slice started")
	if not NpcSellService.hasSellStation() then
		warn("[EconomyService] SellStation missing at Workspace.Shops.SellStation")
	end
	print("[EconomyService] InventoryTerminal missing (HUD Materials button only)")
end

function EconomyService.getDebugSummary(): string
	return EconomyDebugService.getServerSummary()
end

return EconomyService
