--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local DataService = {}

local STORE_NAME = "MonsterProgress_v1"
local AUTOSAVE_SECONDS = 60

type Session = {
	data: PlayerData.SaveData,
	canSave: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local storeUnavailableLogged = false

local function dataStoreHint(errMsg: string): string
	local lower = string.lower(errMsg)
	if string.find(lower, "studio access", 1, true) or string.find(lower, "api services", 1, true) then
		return " Enable Game Settings → Security → Enable Studio Access to API Services, then restart Play."
	end
	if RunService:IsStudio() then
		return " DataStores often fail in Studio until API access is enabled (live servers use published place settings)."
	end
	return ""
end

local function getStore(): DataStore?
	if store ~= nil then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result ~= nil then
		store = result
		return result
	end
	if not storeUnavailableLogged then
		storeUnavailableLogged = true
		local detail = if ok then "GetDataStore returned nil" else tostring(result)
		warn("[DataService] DataStore unavailable (" .. STORE_NAME .. "): " .. detail .. dataStoreHint(detail))
	end
	return nil
end

local function getAsyncWithRetry(dataStore: DataStore, key: string): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		local errText = tostring(result)
		if string.find(string.lower(errText), "studio access", 1, true) then
			break
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false, lastErr
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

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

function DataService.publish(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	player:SetAttribute("Cash", session.data.Cash)
	player:SetAttribute("Power", session.data.Power)
	publishLeaderstats(player, session.data)
end

function DataService.get(player: Player): PlayerData.SaveData?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	return session.data
end

function DataService.load(player: Player)
	if sessions[player] ~= nil then
		return
	end

	local loaded: any = nil
	local canSave = false
	local key = keyFor(player)
	local dataStore = getStore()
	if dataStore ~= nil then
		local ok, result = getAsyncWithRetry(dataStore, key)
		if ok then
			loaded = result
			canSave = true
			-- Missing key is success (nil): new player, not a DataStore failure.
		else
			local errText = tostring(result)
			warn(
				"[DataService] Load failed for "
					.. player.Name
					.. " (userId="
					.. tostring(player.UserId)
					.. ", key="
					.. key
					.. "): "
					.. errText
					.. dataStoreHint(errText)
					.. " Session will not save (existing cloud data is not overwritten)."
			)
		end
	else
		warn(
			"[DataService] Load skipped for "
				.. player.Name
				.. " (no DataStore handle); session defaults only, will not save."
		)
	end

	sessions[player] = {
		data = PlayerData.normalize(loaded),
		canSave = canSave,
	}
	DataService.publish(player)
end

function DataService.save(player: Player)
	local session = sessions[player]
	if session == nil or not session.canSave then
		return
	end
	local dataStore = getStore()
	if dataStore == nil then
		return
	end

	local payload = session.data
	local ok, err = pcall(function()
		dataStore:SetAsync(keyFor(player), payload)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	sessions[player] = nil
end

function DataService.start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			DataService.save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				DataService.save(player)
			end
		end
	end)
end

return DataService
