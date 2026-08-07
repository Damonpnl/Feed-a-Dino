--!strict

--[[
	Placeholder pages for disabled tablet apps.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TabletTypes = require(Shared:WaitForChild("tablet"):WaitForChild("TabletTypes"))
local TabletAppRegistry = require(script.Parent.Parent:WaitForChild("TabletAppRegistry"))

local PlaceholderAppController = {}

export type AppId = TabletTypes.AppId

function PlaceholderAppController.mount(parent: Frame, appId: AppId): Frame
	local definition = TabletAppRegistry.get(appId)
	local page = Instance.new("Frame")
	page.Name = appId .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.9, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(120, 220, 230)
	title.Text = if definition and definition.placeholderTitle
		then definition.placeholderTitle
		else string.upper(appId)
	title.Parent = page

	local coming = Instance.new("TextLabel")
	coming.Name = "ComingOnline"
	coming.AnchorPoint = Vector2.new(0.5, 0.5)
	coming.Position = UDim2.fromScale(0.5, 0.52)
	coming.Size = UDim2.new(0.9, 0, 0, 28)
	coming.BackgroundTransparency = 1
	coming.Font = Enum.Font.GothamBold
	coming.TextSize = 18
	coming.TextColor3 = Color3.fromRGB(200, 210, 215)
	coming.Text = "COMING ONLINE"
	coming.Parent = page

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.62)
	body.Size = UDim2.new(0.8, 0, 0, 48)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 15
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(160, 170, 175)
	body.Text = if definition and definition.placeholderBody
		then definition.placeholderBody
		else ""
	body.Parent = page

	return page
end

return PlaceholderAppController
