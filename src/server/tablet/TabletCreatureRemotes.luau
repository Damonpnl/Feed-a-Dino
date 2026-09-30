--!strict

--[[
	Read-only creature snapshot remotes for Research Tablet Lineage app.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TabletCreatureRemotes = {}

local FOLDER_NAME = "TabletCreatureRemotes"

local SERVER_TO_CLIENT = {
	"CreatureSnapshotUpdated",
}

local CLIENT_TO_SERVER = {
	"RequestCreatureSnapshot",
}

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent } = {}

function TabletCreatureRemotes.ensure(): Folder
	if folder and folder.Parent then
		return folder
	end

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end

	for _, name in SERVER_TO_CLIENT do
		local remote = folder:FindFirstChild(name)
		if remote == nil then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		assert(remote:IsA("RemoteEvent"))
		remotes[name] = remote
	end

	for _, name in CLIENT_TO_SERVER do
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

function TabletCreatureRemotes.get(name: string): RemoteEvent
	TabletCreatureRemotes.ensure()
	local remote = remotes[name]
	assert(remote ~= nil, "Missing tablet creature remote " .. name)
	return remote
end

function TabletCreatureRemotes.fire(player: Player, name: string, ...: any)
	TabletCreatureRemotes.get(name):FireClient(player, ...)
end

return TabletCreatureRemotes
