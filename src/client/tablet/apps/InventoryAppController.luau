--!strict

--[[
	Functional Inventory app for the Research Tablet.
	Presentation only — sells go through existing economy remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedDefinitions"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local InventoryPresentation = require(Shared:WaitForChild("tablet"):WaitForChild("InventoryPresentation"))

local InventoryAppController = {}

export type InventoryCallbacks = {
	requestSell: (feedId: string, stack: boolean) -> (),
	showToast: (title: string, body: string) -> (),
}

local page: Frame
local listFrame: ScrollingFrame
local detailFrame: Frame
local detailTitle: TextLabel
local detailBody: TextLabel
local sellHint: TextLabel
local sellOneBtn: TextButton
local sellStackBtn: TextButton
local confirmFrame: Frame
local confirmLabel: TextLabel
local emptyLabel: TextLabel

local callbacks: InventoryCallbacks
local remotesFolder: Folder?
local sellMode = false
local selectedFeedId: string? = nil
local inventorySnapshot = { materials = {} :: { [string]: number }, totalItems = 0 }
local pendingConfirm: { feedId: string, amount: number, payout: number }? = nil
local rowButtons: { [string]: TextButton } = {}

local function formatCoins(amount: number): string
	return FeedPresentationDefinitions.formatPrice(amount)
end

local function dominantAffinityText(feedId: string): string
	local def = FeedDefinitions.get(feedId :: any)
	if def == nil then
		return "Unknown"
	end
	local bestId = "Flesh"
	local best = -1
	for affinityId, amount in def.affinityContribution do
		if amount > best then
			best = amount
			bestId = affinityId
		end
	end
	if best <= 0 then
		return "None"
	end
	return string.format("%s +%d", bestId, best)
end

local function influenceText(feedId: string): string
	local def = FeedDefinitions.get(feedId :: any)
	if def == nil or def.influenceContribution == nil then
		return "None"
	end
	local parts = {}
	for influenceId, amount in def.influenceContribution do
		if amount > 0 then
			table.insert(parts, string.format("%s +%d", influenceId, amount))
		end
	end
	table.sort(parts)
	if #parts == 0 then
		return "None"
	end
	return table.concat(parts, ", ")
end

local function setSellControlsVisible(visible: boolean)
	sellOneBtn.Visible = visible
	sellStackBtn.Visible = visible
	sellHint.Visible = not visible
	if not visible then
		confirmFrame.Visible = false
		pendingConfirm = nil
	end
end

local function refreshDetail()
	if selectedFeedId == nil then
		detailTitle.Text = "SELECT A MATERIAL"
		detailBody.Text = "Choose an item from storage to inspect research data."
		setSellControlsVisible(false)
		sellHint.Visible = false
		return
	end

	local feedId = selectedFeedId
	local amount = inventorySnapshot.materials[feedId] or 0
	if amount <= 0 then
		selectedFeedId = nil
		refreshDetail()
		return
	end

	local presentation = FeedPresentationDefinitions.get(feedId)
	local economy = MaterialEconomyDefinitions.get(feedId)
	local displayName = if presentation then presentation.displayName else feedId
	local category = if presentation then presentation.categoryDisplayName else "?"
	local npc = if economy then economy.npcSellPrice else 0

	detailTitle.Text = string.upper(displayName)
	detailBody.Text = string.format(
		"%s\n\nOwned: %d\n\nPrimary Affinity:\n%s\n\nInfluence:\n%s\n\nNPC Value:\n%s each",
		category,
		amount,
		dominantAffinityText(feedId),
		influenceText(feedId),
		formatCoins(npc)
	)

	if sellMode then
		setSellControlsVisible(true)
		sellHint.Text = ""
	else
		setSellControlsVisible(false)
		sellHint.Visible = true
		sellHint.Text = "Visit a Material Buyer to sell this item."
	end
end

local function clearList()
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end
	table.clear(rowButtons)
end

local function rebuildList()
	clearList()
	local ids = InventoryPresentation.sortedOwnedFeedIds(inventorySnapshot.materials)
	emptyLabel.Visible = #ids == 0
	if #ids == 0 then
		emptyLabel.Text = if sellMode then "YOU HAVE NOTHING TO SELL" else "MATERIAL STORAGE EMPTY\n\nExplore the Savannah and return to the hub\nto secure gathered materials."
		selectedFeedId = nil
		refreshDetail()
		return
	end

	selectedFeedId = InventoryPresentation.nextSelectedAfterDeplete(inventorySnapshot.materials, selectedFeedId)

	for _, feedId in ids do
		local amount = inventorySnapshot.materials[feedId]
		local presentation = FeedPresentationDefinitions.get(feedId)
		local row = Instance.new("TextButton")
		row.Name = feedId
		row.Size = UDim2.new(1, -6, 0, 64)
		row.BackgroundColor3 = if feedId == selectedFeedId
			then Color3.fromRGB(28, 70, 78)
			else Color3.fromRGB(22, 30, 34)
		row.BorderSizePixel = 0
		row.AutoButtonColor = true
		row.Text = ""
		row.Parent = listFrame
		rowButtons[feedId] = row

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -16, 1, -8)
		label.Position = UDim2.fromOffset(8, 4)
		label.Font = Enum.Font.Gotham
		label.TextSize = 15
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(235, 245, 245)
		label.Text = string.format(
			"%s\n%s\nx%d",
			if presentation then presentation.displayName else feedId,
			if presentation then presentation.categoryDisplayName else "?",
			amount
		)
		label.Parent = row

		row.MouseButton1Click:Connect(function()
			selectedFeedId = feedId
			rebuildList()
		end)
	end

	refreshDetail()
end

local function openConfirm(feedId: string, amount: number, payout: number)
	pendingConfirm = { feedId = feedId, amount = amount, payout = payout }
	local presentation = FeedPresentationDefinitions.get(feedId)
	local name = if presentation then presentation.displayName else feedId
	confirmLabel.Text = string.format("Sell %d %s for %s?", amount, name, formatCoins(payout))
	confirmFrame.Visible = true
end

function InventoryAppController.mount(parent: Frame, folder: Folder, cbs: InventoryCallbacks): Frame
	remotesFolder = folder
	callbacks = cbs

	page = Instance.new("Frame")
	page.Name = "InventoryPage"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = parent

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -16, 0, 28)
	header.Position = UDim2.fromOffset(8, 4)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 20
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.fromRGB(120, 220, 230)
	header.Text = "MATERIAL STORAGE"
	header.Parent = page

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "MaterialList"
	listFrame.Size = UDim2.new(0.48, -12, 1, -44)
	listFrame.Position = UDim2.fromOffset(8, 36)
	listFrame.BackgroundColor3 = Color3.fromRGB(12, 18, 20)
	listFrame.BackgroundTransparency = 0.2
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.fromOffset(0, 0)
	listFrame.Parent = page

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 8)
	listCorner.Parent = listFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = listFrame

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.Parent = listFrame

	emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyState"
	emptyLabel.Size = UDim2.new(0.48, -12, 1, -44)
	emptyLabel.Position = UDim2.fromOffset(8, 36)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextSize = 16
	emptyLabel.TextWrapped = true
	emptyLabel.TextColor3 = Color3.fromRGB(170, 185, 190)
	emptyLabel.Visible = false
	emptyLabel.ZIndex = 2
	emptyLabel.Parent = page

	detailFrame = Instance.new("Frame")
	detailFrame.Name = "Detail"
	detailFrame.Size = UDim2.new(0.52, -16, 1, -44)
	detailFrame.Position = UDim2.new(0.48, 8, 0, 36)
	detailFrame.BackgroundColor3 = Color3.fromRGB(14, 22, 26)
	detailFrame.BackgroundTransparency = 0.15
	detailFrame.BorderSizePixel = 0
	detailFrame.Parent = page

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 8)
	detailCorner.Parent = detailFrame

	detailTitle = Instance.new("TextLabel")
	detailTitle.Size = UDim2.new(1, -20, 0, 30)
	detailTitle.Position = UDim2.fromOffset(10, 10)
	detailTitle.BackgroundTransparency = 1
	detailTitle.Font = Enum.Font.GothamBold
	detailTitle.TextSize = 20
	detailTitle.TextXAlignment = Enum.TextXAlignment.Left
	detailTitle.TextColor3 = Color3.fromRGB(230, 245, 245)
	detailTitle.Text = "SELECT A MATERIAL"
	detailTitle.Parent = detailFrame

	detailBody = Instance.new("TextLabel")
	detailBody.Size = UDim2.new(1, -20, 1, -160)
	detailBody.Position = UDim2.fromOffset(10, 46)
	detailBody.BackgroundTransparency = 1
	detailBody.Font = Enum.Font.Gotham
	detailBody.TextSize = 15
	detailBody.TextXAlignment = Enum.TextXAlignment.Left
	detailBody.TextYAlignment = Enum.TextYAlignment.Top
	detailBody.TextWrapped = true
	detailBody.TextColor3 = Color3.fromRGB(200, 215, 220)
	detailBody.Text = ""
	detailBody.Parent = detailFrame

	sellHint = Instance.new("TextLabel")
	sellHint.Size = UDim2.new(1, -20, 0, 36)
	sellHint.Position = UDim2.new(0, 10, 1, -120)
	sellHint.BackgroundTransparency = 1
	sellHint.Font = Enum.Font.Gotham
	sellHint.TextSize = 14
	sellHint.TextWrapped = true
	sellHint.TextColor3 = Color3.fromRGB(160, 180, 185)
	sellHint.Text = ""
	sellHint.Visible = false
	sellHint.Parent = detailFrame

	sellOneBtn = Instance.new("TextButton")
	sellOneBtn.Name = "SellOne"
	sellOneBtn.Size = UDim2.new(0.48, -8, 0, 40)
	sellOneBtn.Position = UDim2.new(0, 10, 1, -56)
	sellOneBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 110)
	sellOneBtn.Font = Enum.Font.GothamBold
	sellOneBtn.TextSize = 16
	sellOneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellOneBtn.Text = "SELL 1"
	sellOneBtn.Visible = false
	sellOneBtn.Parent = detailFrame
	local sellOneCorner = Instance.new("UICorner")
	sellOneCorner.CornerRadius = UDim.new(0, 8)
	sellOneCorner.Parent = sellOneBtn

	sellStackBtn = Instance.new("TextButton")
	sellStackBtn.Name = "SellStack"
	sellStackBtn.Size = UDim2.new(0.48, -8, 0, 40)
	sellStackBtn.Position = UDim2.new(0.52, 0, 1, -56)
	sellStackBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 140)
	sellStackBtn.Font = Enum.Font.GothamBold
	sellStackBtn.TextSize = 16
	sellStackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellStackBtn.Text = "SELL STACK"
	sellStackBtn.Visible = false
	sellStackBtn.Parent = detailFrame
	local sellStackCorner = Instance.new("UICorner")
	sellStackCorner.CornerRadius = UDim.new(0, 8)
	sellStackCorner.Parent = sellStackBtn

	confirmFrame = Instance.new("Frame")
	confirmFrame.Name = "Confirm"
	confirmFrame.Size = UDim2.new(1, -20, 0, 110)
	confirmFrame.Position = UDim2.new(0, 10, 1, -180)
	confirmFrame.BackgroundColor3 = Color3.fromRGB(20, 28, 32)
	confirmFrame.Visible = false
	confirmFrame.ZIndex = 5
	confirmFrame.Parent = detailFrame
	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmFrame

	confirmLabel = Instance.new("TextLabel")
	confirmLabel.Size = UDim2.new(1, -16, 0, 48)
	confirmLabel.Position = UDim2.fromOffset(8, 8)
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Font = Enum.Font.Gotham
	confirmLabel.TextSize = 15
	confirmLabel.TextWrapped = true
	confirmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	confirmLabel.ZIndex = 6
	confirmLabel.Parent = confirmFrame

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0.46, 0, 0, 32)
	confirmBtn.Position = UDim2.new(0.04, 0, 1, -40)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 100)
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Text = "CONFIRM"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.ZIndex = 6
	confirmBtn.Parent = confirmFrame

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.46, 0, 0, 32)
	cancelBtn.Position = UDim2.new(0.5, 0, 1, -40)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Text = "CANCEL"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.ZIndex = 6
	cancelBtn.Parent = confirmFrame

	sellOneBtn.MouseButton1Click:Connect(function()
		if not sellMode or selectedFeedId == nil then
			return
		end
		callbacks.requestSell(selectedFeedId, false)
	end)

	sellStackBtn.MouseButton1Click:Connect(function()
		if not sellMode or selectedFeedId == nil then
			return
		end
		local feedId = selectedFeedId
		local amount = inventorySnapshot.materials[feedId] or 0
		local economy = MaterialEconomyDefinitions.get(feedId)
		local unit = if economy then economy.npcSellPrice else 0
		if amount <= 0 then
			return
		end
		if InventoryPresentation.requiresStackConfirm(feedId) then
			openConfirm(feedId, amount, InventoryPresentation.displaySellTotal(unit, amount))
		else
			callbacks.requestSell(feedId, true)
		end
	end)

	confirmBtn.MouseButton1Click:Connect(function()
		local pending = pendingConfirm
		confirmFrame.Visible = false
		pendingConfirm = nil
		if pending == nil then
			return
		end
		if pending.amount <= 1 then
			callbacks.requestSell(pending.feedId, false)
		else
			callbacks.requestSell(pending.feedId, true)
		end
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		confirmFrame.Visible = false
		pendingConfirm = nil
	end)

	rebuildList()
	return page
end

function InventoryAppController.setSnapshot(snapshot: any)
	inventorySnapshot = snapshot or { materials = {}, totalItems = 0 }
	rebuildList()
end

function InventoryAppController.setSellMode(enabled: boolean)
	sellMode = enabled
	if not enabled then
		confirmFrame.Visible = false
		pendingConfirm = nil
	end
	rebuildList()
end

function InventoryAppController.isSellMode(): boolean
	return sellMode
end

function InventoryAppController.cancelConfirmation()
	pendingConfirm = nil
	if confirmFrame then
		confirmFrame.Visible = false
	end
end

function InventoryAppController.getSelectedFeedId(): string?
	return selectedFeedId
end

return InventoryAppController
