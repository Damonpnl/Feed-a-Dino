--!strict

--[[
	Simple creature name tag billboards styled like conveyor material name labels,
	slightly larger. Display-only — no lineage/progression data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LineageDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("LineageDefinitions"))

local CreatureNameTagService = {}

CreatureNameTagService.BILLBOARD_NAME = "CreatureNameTag"

local CONFIG = table.freeze({
	size = UDim2.fromOffset(220, 52),
	maxDistance = 80,
	studsOffsetWorldSpace = Vector3.new(0, 5.5, 0),
	alwaysOnTop = true,
	lightInfluence = 0,
	nameHeight = 42,
	nameMaxTextSize = 32,
	nameMinTextSize = 14,
	textColor = Color3.fromRGB(255, 255, 255),
	textStrokeColor = Color3.fromRGB(0, 0, 0),
	textStrokeTransparency = 0,
	primaryFont = Enum.Font.FredokaOne,
})

local function addTextSizeConstraint(label: TextLabel, minSize: number, maxSize: number)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint == nil then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = label
	end
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
end

local function styleNameLabel(label: TextLabel)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = CONFIG.primaryFont
	label.TextColor3 = CONFIG.textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.RichText = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = CONFIG.textStrokeColor
	label.TextStrokeTransparency = CONFIG.textStrokeTransparency
	addTextSizeConstraint(label, CONFIG.nameMinTextSize, CONFIG.nameMaxTextSize)
end

function CreatureNameTagService.getDisplayName(formId: string): string
	local definition = LineageDefinitions.get(formId)
	if definition ~= nil then
		return definition.displayName
	end
	return formId
end

function CreatureNameTagService.find(host: Instance): BillboardGui?
	local existing = host:FindFirstChild(CreatureNameTagService.BILLBOARD_NAME)
	if existing ~= nil and existing:IsA("BillboardGui") then
		return existing
	end
	return nil
end

function CreatureNameTagService.ensure(host: BasePart): BillboardGui
	local existing = CreatureNameTagService.find(host)
	if existing ~= nil then
		return existing
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = CreatureNameTagService.BILLBOARD_NAME
	billboard.Size = CONFIG.size
	billboard.StudsOffsetWorldSpace = CONFIG.studsOffsetWorldSpace
	billboard.AlwaysOnTop = CONFIG.alwaysOnTop
	billboard.LightInfluence = CONFIG.lightInfluence
	billboard.MaxDistance = CONFIG.maxDistance
	billboard.ResetOnSpawn = false
	billboard.Active = false
	billboard.Parent = host

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, CONFIG.nameHeight)
	nameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.Parent = root
	styleNameLabel(nameLabel)

	return billboard
end

function CreatureNameTagService.setName(billboard: BillboardGui, displayName: string)
	local root = billboard:FindFirstChild("Root")
	if root == nil then
		return
	end
	local nameLabel = root:FindFirstChild("NameLabel")
	if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
		nameLabel.Text = displayName
	end
end

function CreatureNameTagService.update(host: BasePart, formId: string)
	local billboard = CreatureNameTagService.ensure(host)
	CreatureNameTagService.setName(billboard, CreatureNameTagService.getDisplayName(formId))
end

function CreatureNameTagService.clear(host: BasePart)
	local billboard = CreatureNameTagService.find(host)
	if billboard ~= nil then
		CreatureNameTagService.setName(billboard, "")
	end
end

return CreatureNameTagService
