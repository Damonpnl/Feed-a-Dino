--!strict

--[[
	Client expedition controller. Listens to server remotes only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DroppedBagHighlightController = require(script.Parent:WaitForChild("DroppedBagHighlightController"))
local ExpeditionUIController = require(script.Parent:WaitForChild("ExpeditionUIController"))

ExpeditionUIController.mount()
DroppedBagHighlightController.start()

local remotesFolder = ReplicatedStorage:WaitForChild("ExpeditionRemotes", 30)
if remotesFolder == nil then
	warn("[ExpeditionController] ExpeditionRemotes not found")
	return
end

local function bind(name: string, handler: (...any) -> ())
	local remote = remotesFolder:WaitForChild(name, 10)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(handler)
	else
		warn("[ExpeditionController] Missing remote " .. name)
	end
end

bind("ZoneChanged", function(payload)
	ExpeditionUIController.setInZone(payload.inZone == true)
end)

bind("FieldBagUpdated", function(snapshot)
	ExpeditionUIController.updateFieldBag(snapshot)
end)

bind("QuestUpdated", function(snapshot)
	ExpeditionUIController.updateQuest(snapshot)
end)

bind("ExpeditionNotification", function(payload)
	ExpeditionUIController.showNotification(payload)
end)

bind("BankingSummary", function(payload)
	ExpeditionUIController.showBankingSummary(payload)
end)

bind("LossSummary", function(payload)
	ExpeditionUIController.showLossSummary(payload)
end)

bind("EventAnnouncement", function(payload)
	ExpeditionUIController.showEventAnnouncement(payload)
end)
