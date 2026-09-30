--!strict

--[[
	Server-owned economy remotes under ReplicatedStorage.EconomyRemotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyRemotes = {}

local FOLDER_NAME = "EconomyRemotes"

local SERVER_TO_CLIENT = {
	"WalletUpdated",
	"InventoryUpdated",
	"EconomyNotification",
	"SellSessionOpened",
	"SellSessionClosed",
	"PurchaseResult",
}

local CLIENT_TO_SERVER = {
	"RequestSell",
	"RequestSellStack",
	"RequestOpenInventory",
	"RequestCloseSellSession",
}

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent } = {}
local muted = false

--[[
	When muted, server->client economy events are suppressed.
	Used by EconomySystemTest so playtests don't see fake purchases/sells.
]]
function EconomyRemotes.setMuted(isMuted: boolean)
	muted = isMuted
end

function EconomyRemotes.isMuted(): boolean
	return muted
end

function EconomyRemotes.ensure(): Folder
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

function EconomyRemotes.get(name: string): RemoteEvent
	EconomyRemotes.ensure()
	local remote = remotes[name]
	assert(remote ~= nil, "Missing economy remote " .. name)
	return remote
end

function EconomyRemotes.fire(player: Player, name: string, ...: any)
	if muted then
		return
	end
	EconomyRemotes.get(name):FireClient(player, ...)
end

function EconomyRemotes.fireAll(name: string, ...: any)
	if muted then
		return
	end
	EconomyRemotes.get(name):FireAllClients(...)
end

return EconomyRemotes
