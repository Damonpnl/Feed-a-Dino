--!strict

--[[
	Creates server-owned expedition remotes under ReplicatedStorage.
	Clients receive state only; they never author rewards or zone changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))

local ExpeditionRemotes = {}

local REMOTE_NAMES = {
	"ZoneChanged",
	"FieldBagUpdated",
	"QuestUpdated",
	"ExpeditionNotification",
	"BankingSummary",
	"LossSummary",
	"EventAnnouncement",
}

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent } = {}

function ExpeditionRemotes.ensure(): Folder
	if folder and folder.Parent then
		return folder
	end

	local existing = ReplicatedStorage:FindFirstChild(ExpeditionConfig.RemotesFolderName)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = ExpeditionConfig.RemotesFolderName
		created.Parent = ReplicatedStorage
		folder = created
	end

	for _, name in REMOTE_NAMES do
		local remote = folder:FindFirstChild(name)
		if remote == nil then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		assert(remote:IsA("RemoteEvent"))
		remotes[name] = remote
	end

	return folder
end

function ExpeditionRemotes.get(name: string): RemoteEvent
	ExpeditionRemotes.ensure()
	local remote = remotes[name]
	assert(remote ~= nil, "Missing remote " .. name)
	return remote
end

function ExpeditionRemotes.fire(player: Player, name: string, ...: any)
	ExpeditionRemotes.get(name):FireClient(player, ...)
end

function ExpeditionRemotes.fireAll(name: string, ...: any)
	ExpeditionRemotes.get(name):FireAllClients(...)
end

return ExpeditionRemotes
