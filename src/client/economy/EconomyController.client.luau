--!strict

--[[
	Client economy controller. Listens to EconomyRemotes only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyUIController = require(script.Parent:WaitForChild("EconomyUIController"))

local remotesFolder = ReplicatedStorage:WaitForChild("EconomyRemotes", 30)
if remotesFolder == nil then
	warn("[EconomyController] EconomyRemotes not found")
	return
end

EconomyUIController.mount(remotesFolder)

local function bind(name: string, handler: (...any) -> ())
	local remote = remotesFolder:WaitForChild(name, 10)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(handler)
	else
		warn("[EconomyController] Missing remote " .. name)
	end
end

bind("WalletUpdated", function(snapshot)
	EconomyUIController.updateWallet(snapshot)
end)

bind("InventoryUpdated", function(snapshot)
	EconomyUIController.updateInventory(snapshot)
end)

bind("EconomyNotification", function(payload)
	EconomyUIController.showNotification(payload)
end)

bind("SellSessionOpened", function(payload)
	EconomyUIController.openSellSession(payload)
end)

bind("SellSessionClosed", function()
	EconomyUIController.closeSellSession()
end)

bind("PurchaseResult", function(payload)
	EconomyUIController.showPurchaseResult(payload)
end)
