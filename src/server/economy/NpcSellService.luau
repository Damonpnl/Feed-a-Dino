--!strict

--[[
	NPC material selling against secured inventory.
	Requires an active sell session opened near Workspace.Shops.SellStation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))

local WalletService = require(script.Parent.WalletService)
local EconomyDebugService = require(script.Parent.EconomyDebugService)
local EconomyRemotes = require(script.Parent.EconomyRemotes)
local SecuredMaterialInventoryService = require(script.Parent.Parent.expedition.SecuredMaterialInventoryService)

local NpcSellService = {}

local SESSION_RADIUS = 18
local activeSessions: { [Player]: boolean } = {}
local started = false

local function getSellStation(): Model?
	local shops = Workspace:FindFirstChild("Shops")
	if shops == nil then
		return nil
	end
	local station = shops:FindFirstChild("SellStation")
	if station ~= nil and station:IsA("Model") then
		return station
	end
	return nil
end

local function getStationPrimaryPosition(station: Model): Vector3?
	if station.PrimaryPart then
		return station.PrimaryPart.Position
	end
	local hrp = station:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	local part = station:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return part.Position
	end
	return nil
end

local function isNearSellStation(player: Player): boolean
	local station = getSellStation()
	if station == nil then
		return false
	end
	local stationPos = getStationPrimaryPosition(station)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if stationPos == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - stationPos).Magnitude <= SESSION_RADIUS
end

local function pushInventory(player: Player)
	EconomyRemotes.fire(player, "InventoryUpdated", SecuredMaterialInventoryService.getSnapshot(player))
end

local function pushWallet(player: Player)
	EconomyRemotes.fire(player, "WalletUpdated", WalletService.getSnapshot(player))
end

function NpcSellService.hasSellStation(): boolean
	return getSellStation() ~= nil
end

function NpcSellService.isSessionActive(player: Player): boolean
	return activeSessions[player] == true
end

function NpcSellService.openSession(player: Player): boolean
	if not isNearSellStation(player) then
		EconomyRemotes.fire(player, "EconomyNotification", {
			title = "TOO FAR",
			body = "Stand near the Material Buyer",
		})
		return false
	end
	activeSessions[player] = true
	EconomyRemotes.fire(player, "SellSessionOpened", {
		inventory = SecuredMaterialInventoryService.getSnapshot(player),
		wallet = WalletService.getSnapshot(player),
	})
	return true
end

--[[
	Authorizes sell transactions without proximity or client UI.
	Used only by EconomySystemTest so playtests are not teleported onto the shop.
]]
function NpcSellService.authorizeSessionForTests(player: Player)
	activeSessions[player] = true
end

function NpcSellService.closeSession(player: Player, silent: boolean?)
	if activeSessions[player] then
		activeSessions[player] = nil
		if silent ~= true then
			EconomyRemotes.fire(player, "SellSessionClosed", {})
		end
	end
end

local function authorizeSell(player: Player): (boolean, string?)
	if activeSessions[player] ~= true then
		return false, "NoSellSession"
	end
	if not isNearSellStation(player) then
		NpcSellService.closeSession(player)
		return false, "TooFar"
	end
	return true, nil
end

function NpcSellService.sellAmount(player: Player, feedId: string, amount: number): (boolean, string?, number?)
	local okAuth, authReason = authorizeSell(player)
	if not okAuth then
		return false, authReason, nil
	end

	local economy = MaterialEconomyDefinitions.get(feedId)
	if economy == nil or not economy.sellableToNpc then
		return false, "UnknownFeedId", nil
	end
	if typeof(amount) ~= "number" or amount ~= math.floor(amount) or amount <= 0 then
		return false, "InvalidAmount", nil
	end

	local owned = SecuredMaterialInventoryService.getMaterialCount(player, feedId)
	if owned < amount then
		return false, "InsufficientMaterials", nil
	end

	local unitPrice = economy.npcSellPrice
	local payout = unitPrice * amount

	local removed, removeReason = SecuredMaterialInventoryService.removeMaterial(player, feedId, amount)
	if not removed then
		return false, removeReason or "RemoveFailed", nil
	end

	local credited, creditReason = WalletService.addCoins(player, payout, "NpcSell:" .. feedId)
	if not credited then
		SecuredMaterialInventoryService.addMaterial(player, feedId, amount)
		pushInventory(player)
		return false, creditReason or "WalletCreditFailed", nil
	end

	EconomyDebugService.recordNpcSellCoins(payout, amount)
	pushInventory(player)
	pushWallet(player)
	EconomyRemotes.fire(player, "EconomyNotification", {
		title = "SOLD",
		body = string.format("%s x%d for $%d", feedId, amount, payout),
	})
	return true, nil, payout
end

function NpcSellService.sellOne(player: Player, feedId: string): (boolean, string?, number?)
	return NpcSellService.sellAmount(player, feedId, 1)
end

function NpcSellService.sellAllOfType(player: Player, feedId: string): (boolean, string?, number?)
	local count = SecuredMaterialInventoryService.getMaterialCount(player, feedId)
	if count <= 0 then
		return false, "InsufficientMaterials", nil
	end
	return NpcSellService.sellAmount(player, feedId, count)
end

local function configureSellStationPrompt()
	local station = getSellStation()
	if station == nil then
		warn("[NpcSellService] Workspace.Shops.SellStation missing; sell prompt not wired")
		return
	end

	local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		local torso = station:FindFirstChild("Torso", true)
		local parent = if torso and torso:IsA("BasePart") then torso else station:FindFirstChildWhichIsA("BasePart", true)
		if parent == nil then
			warn("[NpcSellService] SellStation has no BasePart for ProximityPrompt")
			return
		end
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = parent
	end

	prompt.ActionText = "Sell Materials"
	prompt.ObjectText = "Material Buyer"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		NpcSellService.openSession(player)
	end)
end

function NpcSellService.start()
	if started then
		return
	end
	started = true

	EconomyRemotes.ensure()
	configureSellStationPrompt()

	EconomyRemotes.get("RequestSell").OnServerEvent:Connect(function(player: Player, feedId: any)
		if typeof(feedId) ~= "string" then
			return
		end
		NpcSellService.sellOne(player, feedId)
	end)

	EconomyRemotes.get("RequestSellStack").OnServerEvent:Connect(function(player: Player, feedId: any)
		if typeof(feedId) ~= "string" then
			return
		end
		-- Premium/Specialized confirmation is client-side; server still validates session/prices.
		NpcSellService.sellAllOfType(player, feedId)
	end)

	EconomyRemotes.get("RequestCloseSellSession").OnServerEvent:Connect(function(player: Player)
		NpcSellService.closeSession(player)
	end)

	EconomyRemotes.get("RequestOpenInventory").OnServerEvent:Connect(function(player: Player)
		pushInventory(player)
		pushWallet(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activeSessions[player] = nil
	end)
end

return NpcSellService
