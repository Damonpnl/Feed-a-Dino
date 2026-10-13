--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PlayerData = require(game.ReplicatedStorage.Shared.PlayerData)
local SessionStore = require(script.Parent.SessionStore)
local DataService = {}
local STORE_NAME = "MonsterProgress_v1"
local AUTOSAVE_SECONDS = 60
local started, closing = false, false
local store: DataStore? = nil
local function getStore(): DataStore
	if not store then store = DataStoreService:GetDataStore(STORE_NAME) end
	return store :: DataStore
end
-- Studio must never touch production saves, even when API access is enabled.
local studio = RunService:IsStudio()
local sessions = SessionStore.new({
	get = function(key)
		if studio then return nil end
		return getStore():GetAsync(key)
	end,
	update = function(key, transform)
		assert(not studio, "Studio production writes are disabled")
		return getStore():UpdateAsync(key, transform)
	end,
}, {readOnly=studio})
local function keyFor(player: Player): string return "u_" .. tostring(player.UserId) end

local function publishLeaderstats(player: Player, data: PlayerData.SaveData)
	local existingFolder = player:FindFirstChild("leaderstats")
	local leaderstats: Folder
	if existingFolder ~= nil and existingFolder:IsA("Folder") then
		leaderstats = existingFolder
	else
		if existingFolder ~= nil then
			existingFolder:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end

	local function stat(name: string, value: number)
		local existing = leaderstats:FindFirstChild(name)
		local numberValue: IntValue
		if existing ~= nil and existing:IsA("IntValue") then
			numberValue = existing
		else
			if existing ~= nil then
				existing:Destroy()
			end
			local created = Instance.new("IntValue")
			created.Name = name
			created.Parent = leaderstats
			numberValue = created
		end
		numberValue.Value = math.floor(value)
	end

	stat("Cash", data.Cash)
	stat("Power", data.Power)
end

function DataService.get(player: Player): PlayerData.SaveData?
	return sessions:get(keyFor(player))
end
function DataService.getStatus(player: Player)
	return sessions:status(keyFor(player))
end
function DataService.isWritable(player: Player): boolean
	local status = DataService.getStatus(player)
	return not closing and player.Parent == Players and status ~= nil and status.CanSave
		and not status.Closing and (status.Status == "Loaded" or status.Status == "Missing")
end
function DataService.publish(player: Player)
	local data = DataService.get(player)
	if not data or player.Parent ~= Players then return end
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Power", data.Power)
	publishLeaderstats(player, data)
end
function DataService.load(player: Player)
	if closing then return end
	sessions:load(keyFor(player))
	if player.Parent ~= Players then return end
	local status = sessions:status(keyFor(player))
	player:SetAttribute("DataStatus", status.Status)
	DataService.publish(player)
end
function DataService.save(player: Player)
	local ok, reason = sessions:save(keyFor(player))
	local status = sessions:status(keyFor(player))
	if status and player.Parent == Players then player:SetAttribute("DataStatus", status.Status) end
	return ok, reason
end
function DataService.release(player: Player)
	return sessions:release(keyFor(player))
end
function DataService.start()
	if started then return end
	started = true
	if studio then print("[DataService] Studio read-only session; no production DataStore requests.") end
	Players.PlayerRemoving:Connect(DataService.release)
	game:BindToClose(function()
		closing = true
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function() DataService.release(player) pending -= 1 end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.05) end
	end)
	task.spawn(function()
		while not closing do
			task.wait(AUTOSAVE_SECONDS)
			if closing then break end
			for _, player in Players:GetPlayers() do task.spawn(DataService.save, player) end
		end
	end)
end
return DataService
