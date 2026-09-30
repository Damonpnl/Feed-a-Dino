--!strict

--[[
	Owner-only Highlight on dropped SoilBags so the loser can find their bag from anywhere.
	Uses CollectionService tags + OwnerUserId attributes set by DroppedBagService.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))

local DroppedBagHighlightController = {}

local localPlayer = Players.LocalPlayer
local highlightsByInstance: { [Instance]: Highlight } = {}
local TAG = ExpeditionConfig.DroppedBagCollectionServiceTag

local function clearHighlight(instance: Instance)
	local highlight = highlightsByInstance[instance]
	if highlight ~= nil then
		highlightsByInstance[instance] = nil
		if highlight.Parent ~= nil then
			highlight:Destroy()
		end
	end
end

local function ensureOwnerHighlight(instance: Instance)
	local ownerUserId = instance:GetAttribute("OwnerUserId")
	if ownerUserId ~= localPlayer.UserId then
		clearHighlight(instance)
		return
	end

	if highlightsByInstance[instance] ~= nil then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "OwnerDroppedBagHighlight"
	highlight.Adornee = instance :: PVInstance
	highlight.FillColor = Color3.fromRGB(255, 196, 72)
	highlight.OutlineColor = Color3.fromRGB(255, 230, 140)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = instance
	highlightsByInstance[instance] = highlight
end

function DroppedBagHighlightController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		ensureOwnerHighlight(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		ensureOwnerHighlight(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		clearHighlight(instance)
	end)
end

return DroppedBagHighlightController
