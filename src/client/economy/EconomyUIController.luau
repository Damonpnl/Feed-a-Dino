--!strict

--[[
	Wallet HUD, secured inventory UI, and NPC sell UI.
	Presentation only; all mutations go through server remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local TabletConfig = require(Shared:WaitForChild("tablet"):WaitForChild("TabletConfig"))

local EconomyUIController = {}

local legacyMaterialsEnabled = TabletConfig.LegacyMaterialsUiEnabled == true
local legacySellEnabled = TabletConfig.LegacySellPanelEnabled == true

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder: Folder? = nil
local gui: ScreenGui
local walletLabel: TextLabel
local materialsButton: TextButton
local inventoryFrame: Frame
local inventoryList: ScrollingFrame
local sellFrame: Frame
local sellList: ScrollingFrame
local confirmFrame: Frame
local confirmLabel: TextLabel
local toastLabel: TextLabel

local inventorySnapshot: any = { materials = {}, totalItems = 0 }
local sellSessionOpen = false
local pendingConfirm: { feedId: string, amount: number, payout: number }? = nil

local function formatCoins(amount: number): string
	return FeedPresentationDefinitions.formatPrice(amount)
end

local function getRemote(name: string): RemoteEvent?
	if remotesFolder == nil then
		return nil
	end
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function showToast(title: string, body: string)
	toastLabel.Text = title .. "\n" .. body
	toastLabel.Visible = true
	task.delay(3, function()
		if toastLabel.Text == title .. "\n" .. body then
			toastLabel.Visible = false
		end
	end)
end

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end
end

local function sortedFeedIds(materials: { [string]: number }): { string }
	local ids = {}
	for feedId, amount in materials do
		if amount > 0 then
			table.insert(ids, feedId)
		end
	end
	table.sort(ids)
	return ids
end

local function requiresConfirm(feedId: string): boolean
	local presentation = FeedPresentationDefinitions.get(feedId)
	if presentation == nil then
		return true
	end
	return presentation.categoryId == "Premium" or presentation.categoryId == "Specialized"
end

local function requestSell(feedId: string, stack: boolean)
	local remoteName = if stack then "RequestSellStack" else "RequestSell"
	local remote = getRemote(remoteName)
	if remote then
		remote:FireServer(feedId)
	end
end

local function openConfirm(feedId: string, amount: number, payout: number)
	pendingConfirm = { feedId = feedId, amount = amount, payout = payout }
	local presentation = FeedPresentationDefinitions.get(feedId)
	local name = if presentation then presentation.displayName else feedId
	confirmLabel.Text = string.format("Sell %d %s for %s?", amount, name, formatCoins(payout))
	confirmFrame.Visible = true
end

local function rebuildInventoryRows()
	clearChildren(inventoryList)
	local materials = inventorySnapshot.materials or {}
	local ids = sortedFeedIds(materials)
	if #ids == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.Size = UDim2.new(1, -8, 0, 48)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 15
		empty.TextColor3 = Color3.fromRGB(180, 180, 180)
		empty.Text = "No secured materials yet.\nBank expedition loot or buy from the conveyor."
		empty.TextWrapped = true
		empty.Parent = inventoryList
		return
	end
	for _, feedId in ids do
		local amount = materials[feedId]
		local presentation = FeedPresentationDefinitions.get(feedId)
		local economy = MaterialEconomyDefinitions.get(feedId)
		local row = Instance.new("Frame")
		row.Name = feedId
		row.Size = UDim2.new(1, -8, 0, 88)
		row.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
		row.BorderSizePixel = 0
		row.Parent = inventoryList

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -16, 1, -36)
		label.Position = UDim2.fromOffset(8, 4)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(240, 240, 240)
		label.TextWrapped = true
		label.Text = string.format(
			"%s\n%s\nx%d\nFeed Effect: %s\nSell: %s each",
			if presentation then presentation.displayName else feedId,
			if presentation then presentation.categoryDisplayName else "?",
			amount,
			if presentation then presentation.shortEffectLabel else "?",
			if economy then formatCoins(economy.npcSellPrice) else "$?"
		)
		label.Parent = row

		local sellOne = Instance.new("TextButton")
		sellOne.Name = "SellOne"
		sellOne.Size = UDim2.fromOffset(70, 26)
		sellOne.Position = UDim2.new(1, -156, 1, -30)
		sellOne.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
		sellOne.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellOne.Font = Enum.Font.GothamBold
		sellOne.TextSize = 12
		sellOne.Text = "Sell"
		sellOne.Parent = row
		sellOne.MouseButton1Click:Connect(function()
			if not sellSessionOpen then
				showToast("SELL STATION", "Use the Material Buyer to sell")
				return
			end
			if requiresConfirm(feedId) then
				local unit = if economy then economy.npcSellPrice else 0
				openConfirm(feedId, 1, unit)
			else
				requestSell(feedId, false)
			end
		end)

		local sellStack = Instance.new("TextButton")
		sellStack.Name = "SellStack"
		sellStack.Size = UDim2.fromOffset(78, 26)
		sellStack.Position = UDim2.new(1, -80, 1, -30)
		sellStack.BackgroundColor3 = Color3.fromRGB(90, 90, 140)
		sellStack.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellStack.Font = Enum.Font.GothamBold
		sellStack.TextSize = 12
		sellStack.Text = "Sell Stack"
		sellStack.Parent = row
		sellStack.MouseButton1Click:Connect(function()
			if not sellSessionOpen then
				showToast("SELL STATION", "Use the Material Buyer to sell")
				return
			end
			local unit = if economy then economy.npcSellPrice else 0
			if requiresConfirm(feedId) then
				openConfirm(feedId, amount, unit * amount)
			else
				requestSell(feedId, true)
			end
		end)
	end
end

local function rebuildSellRows()
	clearChildren(sellList)
	local materials = inventorySnapshot.materials or {}
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -8, 0, 28)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.TextColor3 = Color3.fromRGB(255, 230, 140)
	header.Text = "MATERIAL BUYER"
	header.Parent = sellList

	local ids = sortedFeedIds(materials)
	if #ids == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.Size = UDim2.new(1, -8, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 15
		empty.TextColor3 = Color3.fromRGB(180, 180, 180)
		empty.Text = "No materials to sell."
		empty.Parent = sellList
		return
	end

	for _, feedId in ids do
		local amount = materials[feedId]
		local presentation = FeedPresentationDefinitions.get(feedId)
		local economy = MaterialEconomyDefinitions.get(feedId)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 96)
		row.BackgroundColor3 = Color3.fromRGB(30, 28, 24)
		row.BorderSizePixel = 0
		row.Parent = sellList

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -16, 0, 54)
		label.Position = UDim2.fromOffset(8, 4)
		label.Font = Enum.Font.Gotham
		label.TextSize = 15
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.Text = string.format(
			"%s\nOwned: %d\nSell price: %s",
			if presentation then presentation.displayName else feedId,
			amount,
			if economy then formatCoins(economy.npcSellPrice) else "$?"
		)
		label.Parent = row

		local sellOne = Instance.new("TextButton")
		sellOne.Size = UDim2.fromOffset(90, 28)
		sellOne.Position = UDim2.fromOffset(8, 60)
		sellOne.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
		sellOne.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellOne.Font = Enum.Font.GothamBold
		sellOne.TextSize = 13
		sellOne.Text = "SELL 1"
		sellOne.Parent = row
		sellOne.MouseButton1Click:Connect(function()
			if requiresConfirm(feedId) then
				local unit = if economy then economy.npcSellPrice else 0
				openConfirm(feedId, 1, unit)
			else
				requestSell(feedId, false)
			end
		end)

		local sellStack = Instance.new("TextButton")
		sellStack.Size = UDim2.fromOffset(110, 28)
		sellStack.Position = UDim2.fromOffset(108, 60)
		sellStack.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
		sellStack.TextColor3 = Color3.fromRGB(255, 255, 255)
		sellStack.Font = Enum.Font.GothamBold
		sellStack.TextSize = 13
		sellStack.Text = "SELL STACK"
		sellStack.Parent = row
		sellStack.MouseButton1Click:Connect(function()
			local unit = if economy then economy.npcSellPrice else 0
			if requiresConfirm(feedId) then
				openConfirm(feedId, amount, unit * amount)
			else
				requestSell(feedId, true)
			end
		end)
	end
end

function EconomyUIController.mount(folder: Folder)
	remotesFolder = folder

	local existing = playerGui:FindFirstChild("EconomyHud")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "EconomyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	walletLabel = Instance.new("TextLabel")
	walletLabel.Name = "Wallet"
	walletLabel.Size = UDim2.fromOffset(140, 36)
	walletLabel.Position = UDim2.new(1, -160, 0, 16)
	walletLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	walletLabel.BackgroundTransparency = 0.25
	walletLabel.BorderSizePixel = 0
	walletLabel.Font = Enum.Font.FredokaOne
	walletLabel.TextSize = 22
	walletLabel.TextColor3 = Color3.fromRGB(255, 220, 40)
	walletLabel.Text = "$500"
	walletLabel.Parent = gui

	materialsButton = Instance.new("TextButton")
	materialsButton.Name = "MaterialsButton"
	materialsButton.Size = UDim2.fromOffset(110, 32)
	materialsButton.Position = UDim2.new(1, -160, 0, 58)
	materialsButton.BackgroundColor3 = Color3.fromRGB(40, 55, 70)
	materialsButton.BorderSizePixel = 0
	materialsButton.Font = Enum.Font.GothamBold
	materialsButton.TextSize = 14
	materialsButton.TextColor3 = Color3.fromRGB(240, 240, 240)
	materialsButton.Text = "Materials"
	materialsButton.Parent = gui
	materialsButton.MouseButton1Click:Connect(function()
		inventoryFrame.Visible = not inventoryFrame.Visible
		if inventoryFrame.Visible then
			local remote = getRemote("RequestOpenInventory")
			if remote then
				remote:FireServer()
			end
			rebuildInventoryRows()
		end
	end)

	local function closeInventory()
		inventoryFrame.Visible = false
	end

	local function closeSell()
		sellFrame.Visible = false
		confirmFrame.Visible = false
		pendingConfirm = nil
		sellSessionOpen = false
		local remote = getRemote("RequestCloseSellSession")
		if remote then
			remote:FireServer()
		end
	end

	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "Inventory"
	inventoryFrame.Size = UDim2.fromOffset(340, 460)
	inventoryFrame.Position = UDim2.new(1, -360, 0, 100)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	inventoryFrame.BackgroundTransparency = 0.1
	inventoryFrame.BorderSizePixel = 0
	inventoryFrame.Visible = false
	inventoryFrame.Parent = gui

	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(1, -100, 0, 28)
	invTitle.Position = UDim2.fromOffset(10, 6)
	invTitle.BackgroundTransparency = 1
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextSize = 18
	invTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
	invTitle.TextXAlignment = Enum.TextXAlignment.Left
	invTitle.Text = "SECURED MATERIALS"
	invTitle.Parent = inventoryFrame

	local invClose = Instance.new("TextButton")
	invClose.Name = "CloseX"
	invClose.Size = UDim2.fromOffset(28, 28)
	invClose.Position = UDim2.new(1, -34, 0, 4)
	invClose.Text = "X"
	invClose.Font = Enum.Font.GothamBold
	invClose.TextSize = 16
	invClose.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	invClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	invClose.Parent = inventoryFrame
	invClose.MouseButton1Click:Connect(closeInventory)

	inventoryList = Instance.new("ScrollingFrame")
	inventoryList.Size = UDim2.new(1, -12, 1, -86)
	inventoryList.Position = UDim2.fromOffset(6, 36)
	inventoryList.BackgroundTransparency = 1
	inventoryList.ScrollBarThickness = 6
	inventoryList.CanvasSize = UDim2.fromOffset(0, 0)
	inventoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	inventoryList.Parent = inventoryFrame

	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 6)
	invLayout.Parent = inventoryList

	local invBack = Instance.new("TextButton")
	invBack.Name = "BackButton"
	invBack.Size = UDim2.new(1, -20, 0, 36)
	invBack.Position = UDim2.new(0, 10, 1, -46)
	invBack.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	invBack.BorderSizePixel = 0
	invBack.Font = Enum.Font.GothamBold
	invBack.TextSize = 16
	invBack.TextColor3 = Color3.fromRGB(255, 255, 255)
	invBack.Text = "BACK"
	invBack.Parent = inventoryFrame
	invBack.MouseButton1Click:Connect(closeInventory)

	sellFrame = Instance.new("Frame")
	sellFrame.Name = "SellPanel"
	sellFrame.Size = UDim2.fromOffset(360, 500)
	sellFrame.Position = UDim2.new(0.5, -180, 0.5, -250)
	sellFrame.BackgroundColor3 = Color3.fromRGB(18, 16, 12)
	sellFrame.BackgroundTransparency = 0.05
	sellFrame.BorderSizePixel = 0
	sellFrame.Visible = false
	sellFrame.Parent = gui

	local sellClose = Instance.new("TextButton")
	sellClose.Name = "CloseX"
	sellClose.Size = UDim2.fromOffset(28, 28)
	sellClose.Position = UDim2.new(1, -34, 0, 4)
	sellClose.Text = "X"
	sellClose.Font = Enum.Font.GothamBold
	sellClose.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	sellClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellClose.Parent = sellFrame
	sellClose.MouseButton1Click:Connect(closeSell)

	sellList = Instance.new("ScrollingFrame")
	sellList.Size = UDim2.new(1, -12, 1, -56)
	sellList.Position = UDim2.fromOffset(6, 6)
	sellList.BackgroundTransparency = 1
	sellList.ScrollBarThickness = 6
	sellList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sellList.CanvasSize = UDim2.fromOffset(0, 0)
	sellList.Parent = sellFrame

	local sellLayout = Instance.new("UIListLayout")
	sellLayout.Padding = UDim.new(0, 8)
	sellLayout.Parent = sellList

	local sellBack = Instance.new("TextButton")
	sellBack.Name = "BackButton"
	sellBack.Size = UDim2.new(1, -20, 0, 36)
	sellBack.Position = UDim2.new(0, 10, 1, -46)
	sellBack.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	sellBack.BorderSizePixel = 0
	sellBack.Font = Enum.Font.GothamBold
	sellBack.TextSize = 16
	sellBack.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellBack.Text = "BACK"
	sellBack.Parent = sellFrame
	sellBack.MouseButton1Click:Connect(closeSell)

	confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "Confirm"
	confirmFrame.Size = UDim2.fromOffset(300, 140)
	confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -70)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	confirmFrame.BorderSizePixel = 0
	confirmFrame.Visible = false
	confirmFrame.ZIndex = 10
	confirmFrame.Parent = gui

	confirmLabel = Instance.new("TextLabel")
	confirmLabel.Size = UDim2.new(1, -20, 0, 60)
	confirmLabel.Position = UDim2.fromOffset(10, 12)
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Font = Enum.Font.Gotham
	confirmLabel.TextSize = 16
	confirmLabel.TextWrapped = true
	confirmLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	confirmLabel.Parent = confirmFrame

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.fromOffset(110, 32)
	confirmBtn.Position = UDim2.fromOffset(24, 90)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
	confirmBtn.Text = "CONFIRM"
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.Parent = confirmFrame
	confirmBtn.MouseButton1Click:Connect(function()
		local pending = pendingConfirm
		confirmFrame.Visible = false
		pendingConfirm = nil
		if pending == nil then
			return
		end
		if pending.amount <= 1 then
			requestSell(pending.feedId, false)
		else
			requestSell(pending.feedId, true)
		end
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(110, 32)
	cancelBtn.Position = UDim2.fromOffset(160, 90)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	cancelBtn.Text = "CANCEL"
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.Parent = confirmFrame
	cancelBtn.MouseButton1Click:Connect(function()
		confirmFrame.Visible = false
		pendingConfirm = nil
	end)

	toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.fromOffset(280, 70)
	toastLabel.Position = UDim2.new(0.5, -140, 0.12, 0)
	toastLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	toastLabel.BackgroundTransparency = 0.2
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextSize = 16
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.TextWrapped = true
	toastLabel.Visible = false
	toastLabel.Parent = gui

	-- Tablet owns inventory/sell UI when legacy flags are false.
	if not legacyMaterialsEnabled then
		materialsButton.Visible = false
		inventoryFrame.Visible = false
	end
	if not legacySellEnabled then
		sellFrame.Visible = false
		confirmFrame.Visible = false
	end
end

function EconomyUIController.updateWallet(snapshot: any)
	local coins = if typeof(snapshot) == "table" and typeof(snapshot.coins) == "number" then snapshot.coins else 0
	walletLabel.Text = formatCoins(coins)
end

function EconomyUIController.updateInventory(snapshot: any)
	inventorySnapshot = snapshot or { materials = {}, totalItems = 0 }
	if inventoryFrame.Visible then
		rebuildInventoryRows()
	end
	if sellFrame.Visible then
		rebuildSellRows()
	end
end

function EconomyUIController.openSellSession(payload: any)
	if payload and payload.wallet then
		EconomyUIController.updateWallet(payload.wallet)
	end
	if payload and payload.inventory then
		inventorySnapshot = payload.inventory
	end
	if not legacySellEnabled then
		-- TabletController owns Sell Mode presentation.
		return
	end
	sellSessionOpen = true
	sellFrame.Visible = true
	rebuildSellRows()
end

function EconomyUIController.closeSellSession()
	sellSessionOpen = false
	if legacySellEnabled then
		sellFrame.Visible = false
		confirmFrame.Visible = false
	end
end

function EconomyUIController.showNotification(payload: any)
	-- Avoid double toasts for sell notifications when tablet is handling them.
	if not legacySellEnabled then
		local title = string.upper(tostring(payload and payload.title or ""))
		if string.find(title, "SOLD", 1, true) or string.find(title, "MATERIAL BUYER", 1, true) then
			return
		end
	end
	showToast(payload.title or "ECONOMY", payload.body or "")
end

function EconomyUIController.showPurchaseResult(payload: any)
	if payload.success then
		showToast("PURCHASED", string.format("%s for %s", tostring(payload.feedId), formatCoins(payload.price or 0)))
	else
		local reason = tostring(payload.reason or "Failed")
		if reason == "InsufficientFunds" then
			showToast("NOT ENOUGH COINS", string.format("Need %s", formatCoins(payload.price or 0)))
		else
			showToast("BUY FAILED", reason)
		end
	end
end

return EconomyUIController
