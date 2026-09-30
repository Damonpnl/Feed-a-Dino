--!strict

--[[
	Research Tablet shell UI. Presentation only.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TabletConfig = require(Shared:WaitForChild("tablet"):WaitForChild("TabletConfig"))
local TabletTypes = require(Shared:WaitForChild("tablet"):WaitForChild("TabletTypes"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))

local TabletAppRegistry = require(script.Parent:WaitForChild("TabletAppRegistry"))
local InventoryAppController = require(script.Parent:WaitForChild("apps"):WaitForChild("InventoryAppController"))
local LineageAppController = require(script.Parent:WaitForChild("apps"):WaitForChild("LineageAppController"))
local PlaceholderAppController = require(script.Parent:WaitForChild("apps"):WaitForChild("PlaceholderAppController"))

local TabletUIController = {}

export type AppId = TabletTypes.AppId

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder: Folder? = nil
local gui: ScreenGui
local root: Frame
local tabletFrame: Frame
local walletLabel: TextLabel
local zoneLabel: TextLabel
local toastLabel: TextLabel
local navButtons: { [AppId]: TextButton } = {}
local pages: { [AppId]: Frame } = {}

local isOpen = false
local activeApp: AppId = "Inventory"
local lastActiveApp: AppId = "Inventory"
local sellMode = false
local walletBalance = 0
local uiScale: UIScale

local ACCENT = Color3.fromRGB(80, 210, 220)
local BG = Color3.fromRGB(10, 16, 20)
local NAV_BG = Color3.fromRGB(14, 22, 28)
local NAV_ACTIVE = Color3.fromRGB(24, 55, 62)

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

local function requestSell(feedId: string, stack: boolean)
	local remoteName = if stack then "RequestSellStack" else "RequestSell"
	local remote = getRemote(remoteName)
	if remote then
		remote:FireServer(feedId)
	end
end

local function showToast(title: string, body: string)
	toastLabel.Text = title .. "\n" .. body
	toastLabel.Visible = true
	task.delay(2.8, function()
		if toastLabel.Text == title .. "\n" .. body then
			toastLabel.Visible = false
		end
	end)
end

local function updateNavStyles()
	for appId, button in navButtons do
		local active = appId == activeApp
		button.BackgroundColor3 = if active then NAV_ACTIVE else Color3.fromRGB(18, 28, 34)
		button.TextColor3 = if active then ACCENT else Color3.fromRGB(200, 210, 215)
	end
end

local function showPage(appId: AppId)
	if not TabletAppRegistry.isValidAppId(appId) then
		return
	end
	activeApp = appId
	if not sellMode then
		lastActiveApp = appId
	end
	for id, page in pages do
		page.Visible = id == appId
	end
	updateNavStyles()
	if appId == "Lineage" then
		LineageAppController.onShown()
	end
end

local function tweenOpen(opening: boolean)
	local duration = if opening then TabletConfig.OpenTransitionSeconds else TabletConfig.CloseTransitionSeconds
	local targetScale = if opening then 1 else 0.94
	local targetTransparency = if opening then 0.15 else 1
	uiScale.Scale = if opening then 0.94 else 1
	root.Visible = true
	tabletFrame.BackgroundTransparency = if opening then 1 else 0.15

	local scaleTween = TweenService:Create(
		uiScale,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	)
	local fadeTween = TweenService:Create(
		tabletFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = targetTransparency }
	)
	scaleTween:Play()
	fadeTween:Play()
	if not opening then
		task.delay(duration, function()
			if not isOpen then
				root.Visible = false
			end
		end)
	end
end

function TabletUIController.mount(folder: Folder)
	remotesFolder = folder

	local existing = playerGui:FindFirstChild("TabletGui")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "TabletGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel = 0
	backdrop.Parent = root

	tabletFrame = Instance.new("Frame")
	tabletFrame.Name = "TabletFrame"
	tabletFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	tabletFrame.Position = UDim2.fromScale(0.5, 0.5)
	tabletFrame.Size = UDim2.fromScale(0.72, 0.78)
	tabletFrame.BackgroundColor3 = BG
	tabletFrame.BackgroundTransparency = 0.15
	tabletFrame.BorderSizePixel = 0
	tabletFrame.Parent = root

	local tabletCorner = Instance.new("UICorner")
	tabletCorner.CornerRadius = UDim.new(0, 16)
	tabletCorner.Parent = tabletFrame

	local tabletStroke = Instance.new("UIStroke")
	tabletStroke.Color = ACCENT
	tabletStroke.Thickness = 1.5
	tabletStroke.Transparency = 0.35
	tabletStroke.Parent = tabletFrame

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(320, 360)
	sizeConstraint.MaxSize = Vector2.new(1200, 900)
	sizeConstraint.Parent = tabletFrame

	uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = tabletFrame

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, -20, 0, 52)
	topBar.Position = UDim2.fromOffset(10, 10)
	topBar.BackgroundColor3 = Color3.fromRGB(16, 26, 32)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = tabletFrame
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = topBar

	local deviceTitle = Instance.new("TextLabel")
	deviceTitle.Name = "DeviceTitle"
	deviceTitle.Size = UDim2.new(0.4, 0, 1, 0)
	deviceTitle.Position = UDim2.fromOffset(14, 0)
	deviceTitle.BackgroundTransparency = 1
	deviceTitle.Font = Enum.Font.GothamBold
	deviceTitle.TextSize = 18
	deviceTitle.TextXAlignment = Enum.TextXAlignment.Left
	deviceTitle.TextColor3 = ACCENT
	deviceTitle.Text = TabletConfig.DeviceTitle
	deviceTitle.Parent = topBar

	zoneLabel = Instance.new("TextLabel")
	zoneLabel.Name = "CurrentZoneLabel"
	zoneLabel.Size = UDim2.new(0.25, 0, 1, 0)
	zoneLabel.Position = UDim2.fromScale(0.38, 0)
	zoneLabel.BackgroundTransparency = 1
	zoneLabel.Font = Enum.Font.Gotham
	zoneLabel.TextSize = 14
	zoneLabel.TextColor3 = Color3.fromRGB(170, 190, 195)
	zoneLabel.Text = "HUB"
	zoneLabel.Parent = topBar

	walletLabel = Instance.new("TextLabel")
	walletLabel.Name = "WalletLabel"
	walletLabel.Size = UDim2.new(0.2, 0, 1, 0)
	walletLabel.Position = UDim2.fromScale(0.62, 0)
	walletLabel.BackgroundTransparency = 1
	walletLabel.Font = Enum.Font.FredokaOne
	walletLabel.TextSize = 22
	walletLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	walletLabel.Text = "$0"
	walletLabel.Parent = topBar

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(84, 34)
	closeButton.Position = UDim2.new(1, -96, 0.5, -17)
	closeButton.BackgroundColor3 = Color3.fromRGB(50, 40, 45)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 15
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "CLOSE"
	closeButton.Parent = topBar
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	closeButton.MouseButton1Click:Connect(function()
		TabletUIController.close()
	end)

	local navigation = Instance.new("Frame")
	navigation.Name = "Navigation"
	navigation.Size = UDim2.new(0.2, -12, 1, -86)
	navigation.Position = UDim2.fromOffset(10, 72)
	navigation.BackgroundColor3 = NAV_BG
	navigation.BackgroundTransparency = 0.15
	navigation.BorderSizePixel = 0
	navigation.Parent = tabletFrame
	local navCorner = Instance.new("UICorner")
	navCorner.CornerRadius = UDim.new(0, 10)
	navCorner.Parent = navigation

	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.Parent = navigation
	local navPad = Instance.new("UIPadding")
	navPad.PaddingTop = UDim.new(0, 10)
	navPad.PaddingLeft = UDim.new(0, 8)
	navPad.PaddingRight = UDim.new(0, 8)
	navPad.Parent = navigation

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(0.8, -18, 1, -86)
	content.Position = UDim2.new(0.2, 6, 0, 72)
	content.BackgroundColor3 = Color3.fromRGB(12, 18, 22)
	content.BackgroundTransparency = 0.2
	content.BorderSizePixel = 0
	content.Parent = tabletFrame
	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 10)
	contentCorner.Parent = content

	for _, definition in TabletAppRegistry.getOrdered() do
		local button = Instance.new("TextButton")
		button.Name = definition.appId .. "Button"
		button.Size = UDim2.new(1, 0, 0, 44)
		button.BackgroundColor3 = Color3.fromRGB(18, 28, 34)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 15
		button.TextColor3 = Color3.fromRGB(200, 210, 215)
		button.Text = definition.displayName
		button.Parent = navigation
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = button
		navButtons[definition.appId] = button

		button.MouseButton1Click:Connect(function()
			if sellMode and definition.appId ~= "Inventory" then
				showToast("SELL MODE", "Finish at the Material Buyer first")
				return
			end
			showPage(definition.appId)
		end)

		if definition.appId == "Inventory" then
			pages.Inventory = InventoryAppController.mount(content, folder, {
				requestSell = requestSell,
				showToast = showToast,
			})
		elseif definition.appId == "Lineage" then
			pages.Lineage = LineageAppController.mount(content)
		else
			pages[definition.appId] = PlaceholderAppController.mount(content, definition.appId)
		end
	end

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 0)
	toastLabel.Position = UDim2.new(0.5, 0, 0, 72)
	toastLabel.Size = UDim2.fromOffset(280, 64)
	toastLabel.BackgroundColor3 = Color3.fromRGB(16, 24, 28)
	toastLabel.BackgroundTransparency = 0.1
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextSize = 15
	toastLabel.TextColor3 = Color3.fromRGB(235, 245, 245)
	toastLabel.TextWrapped = true
	toastLabel.Visible = false
	toastLabel.ZIndex = 20
	toastLabel.Parent = tabletFrame
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toastLabel

	showPage("Inventory")
	walletLabel.Text = formatCoins(walletBalance)
end

function TabletUIController.isOpen(): boolean
	return isOpen
end

function TabletUIController.getActiveApp(): AppId
	return activeApp
end

function TabletUIController.isSellMode(): boolean
	return sellMode
end

function TabletUIController.open(appId: AppId?)
	if gui == nil then
		return
	end
	local target = appId or lastActiveApp or "Inventory"
	if not TabletAppRegistry.isValidAppId(target) then
		target = "Inventory"
	end
	showPage(target :: AppId)
	if not isOpen then
		isOpen = true
		tweenOpen(true)
	end
end

function TabletUIController.close()
	if not isOpen then
		return
	end
	isOpen = false
	InventoryAppController.cancelConfirmation()
	tweenOpen(false)
end

function TabletUIController.toggle()
	if isOpen then
		TabletUIController.close()
	else
		TabletUIController.open(lastActiveApp)
	end
end

function TabletUIController.updateWallet(snapshot: any)
	local coins = if typeof(snapshot) == "table" and typeof(snapshot.coins) == "number" then snapshot.coins else 0
	walletBalance = coins
	if walletLabel then
		walletLabel.Text = formatCoins(coins)
	end
end

function TabletUIController.updateInventory(snapshot: any)
	InventoryAppController.setSnapshot(snapshot)
end

function TabletUIController.setZoneLabel(text: string)
	if zoneLabel then
		zoneLabel.Text = text
	end
end

function TabletUIController.openSellSession(payload: any)
	if payload and payload.wallet then
		TabletUIController.updateWallet(payload.wallet)
	end
	if payload and payload.inventory then
		TabletUIController.updateInventory(payload.inventory)
	end
	sellMode = true
	InventoryAppController.setSellMode(true)
	TabletUIController.open("Inventory")
	showToast("MATERIAL BUYER", "Sell Mode active")
end

function TabletUIController.closeSellSession()
	sellMode = false
	InventoryAppController.setSellMode(false)
	InventoryAppController.cancelConfirmation()
	if isOpen then
		showToast("SELL MODE", "Session closed")
	end
end

function TabletUIController.showNotification(payload: any)
	local title = if typeof(payload) == "table" then tostring(payload.title or "NOTICE") else "NOTICE"
	local body = if typeof(payload) == "table" then tostring(payload.body or "") else ""
	if isOpen then
		showToast(title, body)
	end
end

function TabletUIController.showSaleFeedback(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local title = tostring(payload.title or "")
	local body = tostring(payload.body or "")
	if string.find(string.upper(title), "SOLD", 1, true) then
		showToast("SOLD", body)
	elseif string.find(string.upper(title), "FAIL", 1, true) then
		showToast("SALE FAILED", body)
	else
		showToast(title, body)
	end
end

function TabletUIController.updateCreatureSnapshot(snapshot: any)
	LineageAppController.applySnapshot(snapshot)
end

return TabletUIController
