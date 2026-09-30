--!strict

--[[
	Server-authoritative conveyor material purchase + ownership.
	Purchase validation never trusts client-visible price attributes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))

local WalletService = require(script.Parent.WalletService)
local EconomyDebugService = require(script.Parent.EconomyDebugService)
local EconomyRemotes = require(script.Parent.EconomyRemotes)
local SecuredMaterialInventoryService = require(script.Parent.Parent.expedition.SecuredMaterialInventoryService)
local MaterialBillboardService = require(script.Parent.Parent.materials.MaterialBillboardService)

export type MaterialState = "Available" | "PurchasePending" | "Purchased" | "Consumed"

export type MaterialRecord = {
	instance: BasePart,
	feedId: string,
	state: MaterialState,
	ownerUserId: number?,
	purchasedAt: number?,
	carried: boolean,
	billboard: BillboardGui?,
	prompt: ProximityPrompt?,
}

local ConveyorPurchaseService = {}

local ABANDON_SECONDS = 120
local records: { [BasePart]: MaterialRecord } = {}
local started = false

local function notifyPurchase(player: Player, success: boolean, reason: string?, feedId: string?, price: number?)
	EconomyRemotes.fire(player, "PurchaseResult", {
		success = success,
		reason = reason,
		feedId = feedId,
		price = price,
	})
end

local function markBillboardOwned(record: MaterialRecord)
	if record.billboard == nil then
		return
	end
	local presentation = FeedPresentationDefinitions.get(record.feedId)
	local displayName = if presentation ~= nil then presentation.displayName else record.feedId
	MaterialBillboardService.setDisplayNameText(record.billboard, displayName)
	MaterialBillboardService.setCategoryText(record.billboard, "OWNED")
	MaterialBillboardService.setBottomLabelText(record.billboard, "")
	local root = record.billboard:FindFirstChild("Root")
	if root and root:IsA("Frame") then
		local priceContainer = root:FindFirstChild("PriceContainer")
		if priceContainer and priceContainer:IsA("GuiObject") then
			priceContainer.Visible = false
		end
		local effectLabel = root:FindFirstChild("EffectLabel")
		if effectLabel and effectLabel:IsA("GuiObject") then
			effectLabel.Visible = false
		end
	end
end

function ConveyorPurchaseService.register(
	material: BasePart,
	feedId: string,
	prompt: ProximityPrompt?,
	billboard: BillboardGui?
)
	local economy = MaterialEconomyDefinitions.get(feedId)
	assert(economy ~= nil, "Missing economy definition for " .. feedId)

	material:SetAttribute("FeedId", feedId)
	material:SetAttribute("PurchasePrice", economy.purchasePrice)
	material:SetAttribute("IsPurchased", false)
	material:SetAttribute("OwnerUserId", nil)
	material:SetAttribute("MaterialState", "Available")

	if prompt then
		local presentation = FeedPresentationDefinitions.get(feedId)
		prompt.ActionText = "Buy"
		prompt.ObjectText = if presentation ~= nil then presentation.displayName else feedId
		prompt.Enabled = true
	end

	records[material] = {
		instance = material,
		feedId = feedId,
		state = "Available",
		ownerUserId = nil,
		purchasedAt = nil,
		carried = false,
		billboard = billboard,
		prompt = prompt,
	}

	material.Destroying:Connect(function()
		records[material] = nil
	end)
end

function ConveyorPurchaseService.getRecord(material: BasePart): MaterialRecord?
	return records[material]
end

function ConveyorPurchaseService.isOwner(player: Player, material: BasePart): boolean
	local record = records[material]
	if record == nil then
		-- Fallback for materials registered only via attributes (hot path).
		local ownerId = material:GetAttribute("OwnerUserId")
		local purchased = material:GetAttribute("IsPurchased") == true
		return purchased and ownerId == player.UserId
	end
	return record.state == "Purchased" and record.ownerUserId == player.UserId
end

function ConveyorPurchaseService.canPlayerUse(player: Player, material: BasePart): boolean
	local record = records[material]
	if record == nil then
		local purchased = material:GetAttribute("IsPurchased")
		if purchased == true then
			return material:GetAttribute("OwnerUserId") == player.UserId
		end
		-- Unpurchased public materials should not be usable for feed after this slice.
		return false
	end
	return record.state == "Purchased" and record.ownerUserId == player.UserId
end

function ConveyorPurchaseService.markCarried(material: BasePart, carried: boolean)
	local record = records[material]
	if record then
		record.carried = carried
	end
end

function ConveyorPurchaseService.markConsumed(material: BasePart)
	local record = records[material]
	if record then
		record.state = "Consumed"
		material:SetAttribute("MaterialState", "Consumed")
	end
end

local function attachToCharacter(player: Player, material: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	if character:GetAttribute("CarryingItem") then
		return false
	end

	local rightHand = character:FindFirstChild("RightHand")
	if rightHand == nil or not rightHand:IsA("BasePart") then
		rightHand = character:FindFirstChild("Right Arm")
	end
	if rightHand == nil or not rightHand:IsA("BasePart") then
		return false
	end

	material.Anchored = false
	material.CanCollide = false
	material.Massless = true
	material.CFrame = rightHand.CFrame * CFrame.new(0, -0.5, 0)
	material.Parent = character
	material.Name = "CarriedMeat"
	character:SetAttribute("CarryingItem", true)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = rightHand
	weld.Part1 = material
	weld.Parent = material

	material.Destroying:Connect(function()
		if character.Parent and character:GetAttribute("CarryingItem") and character:FindFirstChild("CarriedMeat", true) == nil then
			character:SetAttribute("CarryingItem", nil)
		end
	end)

	return true
end

function ConveyorPurchaseService.tryPurchase(player: Player, material: BasePart): (boolean, string?)
	if player.Parent == nil then
		return false, "InvalidPlayer"
	end
	if material.Parent == nil then
		return false, "MissingMaterial"
	end

	local record = records[material]
	if record == nil then
		return false, "UnregisteredMaterial"
	end
	if record.state ~= "Available" then
		return false, "Unavailable"
	end

	local feedId = record.feedId
	local economy = MaterialEconomyDefinitions.get(feedId)
	if economy == nil then
		return false, "UnknownFeedId"
	end

	local price = economy.purchasePrice
	record.state = "PurchasePending"
	material:SetAttribute("MaterialState", "PurchasePending")

	if not WalletService.canAfford(player, price) then
		record.state = "Available"
		material:SetAttribute("MaterialState", "Available")
		EconomyDebugService.recordPurchaseInsufficientFunds()
		notifyPurchase(player, false, "InsufficientFunds", feedId, price)
		EconomyRemotes.fire(player, "EconomyNotification", {
			title = "NOT ENOUGH COINS",
			body = string.format("Need $%d", price),
		})
		return false, "InsufficientFunds"
	end

	local spent, spendReason = WalletService.trySpend(player, price, "ConveyorPurchase:" .. feedId)
	if not spent then
		record.state = "Available"
		material:SetAttribute("MaterialState", "Available")
		EconomyDebugService.recordPurchaseInsufficientFunds()
		notifyPurchase(player, false, spendReason or "InsufficientFunds", feedId, price)
		return false, spendReason
	end

	-- Ownership assignment + carry. Refund on failure.
	record.ownerUserId = player.UserId
	record.state = "Purchased"
	record.purchasedAt = os.clock()
	record.carried = false
	material:SetAttribute("IsPurchased", true)
	material:SetAttribute("OwnerUserId", player.UserId)
	material:SetAttribute("MaterialState", "Purchased")
	material:SetAttribute("PurchasePrice", price)

	if record.prompt then
		record.prompt.Enabled = false
	end
	markBillboardOwned(record)

	local carriedOk = attachToCharacter(player, material)
	if not carriedOk then
		WalletService.addCoins(player, price, "ConveyorPurchaseRefund:" .. feedId)
		record.state = "Available"
		record.ownerUserId = nil
		record.purchasedAt = nil
		material:SetAttribute("IsPurchased", false)
		material:SetAttribute("OwnerUserId", nil)
		material:SetAttribute("MaterialState", "Available")
		if record.prompt then
			record.prompt.Enabled = true
		end
		notifyPurchase(player, false, "CarryFailed", feedId, price)
		return false, "CarryFailed"
	end

	record.carried = true
	EconomyDebugService.recordPurchase(price)
	notifyPurchase(player, true, nil, feedId, price)
	return true, nil
end

local function recoverAbandoned(record: MaterialRecord)
	local material = record.instance
	if material.Parent == nil then
		records[material] = nil
		return
	end
	if record.state ~= "Purchased" or record.ownerUserId == nil then
		return
	end
	if record.carried then
		-- Still attached to a character; only recover if character gone.
		local parent = material.Parent
		if parent and parent:IsA("Model") and Players:GetPlayerFromCharacter(parent) then
			return
		end
	end

	local owner = Players:GetPlayerByUserId(record.ownerUserId)
	local feedId = record.feedId
	if owner then
		local ok = SecuredMaterialInventoryService.addMaterial(owner, feedId, 1)
		if ok then
			EconomyRemotes.fire(owner, "InventoryUpdated", SecuredMaterialInventoryService.getSnapshot(owner))
			EconomyRemotes.fire(owner, "EconomyNotification", {
				title = "MATERIAL STORED",
				body = string.format("%s returned to inventory", feedId),
			})
		end
	end

	record.state = "Consumed"
	material:Destroy()
	records[material] = nil
end

function ConveyorPurchaseService.start()
	if started then
		return
	end
	started = true

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, record in records do
			if
				record.state == "Purchased"
				and record.purchasedAt ~= nil
				and (now - record.purchasedAt) >= ABANDON_SECONDS
			then
				-- Prefer inventory recovery for abandoned purchased materials.
				if not record.carried then
					recoverAbandoned(record)
				else
					local parent = record.instance.Parent
					local stillHeld = parent ~= nil
						and parent:IsA("Model")
						and Players:GetPlayerFromCharacter(parent) ~= nil
					if not stillHeld then
						record.carried = false
						recoverAbandoned(record)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for material, record in records do
			if record.ownerUserId == player.UserId and record.state == "Purchased" then
				recoverAbandoned(record)
			elseif material.Parent == nil then
				records[material] = nil
			end
		end
	end)
end

return ConveyorPurchaseService
