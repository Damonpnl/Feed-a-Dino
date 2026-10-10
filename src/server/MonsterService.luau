--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local MonsterDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterDefinitions"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))

local MonsterService = {}

local INCOME_SECONDS = 2
local visuals: { [Player]: Model } = {}

local function generatedFolder(): Folder
	local root = workspace:FindFirstChild("GeneratedGameplay")
	if root == nil then
		local created = Instance.new("Folder")
		created.Name = "GeneratedGameplay"
		created.Parent = workspace
		root = created
	end
	local monsters = root:FindFirstChild("Monsters")
	if monsters == nil or not monsters:IsA("Folder") then
		local created = Instance.new("Folder")
		created.Name = "Monsters"
		created.Parent = root
		monsters = created
	end
	return monsters :: Folder
end

local function findMarker(base: Model, name: string): BasePart?
	local marker = base:FindFirstChild(name, true)
	if marker ~= nil and marker:IsA("BasePart") then
		return marker
	end
	return nil
end

function MonsterService.getRecord(player: Player): PlayerData.MonsterRecord?
	local data = DataService.get(player)
	if data == nil then
		return nil
	end
	return data.Monsters[data.EquippedMonster]
end

function MonsterService.getMultiplier(player: Player): number
	local record = MonsterService.getRecord(player)
	if record == nil then
		return 1
	end
	local definition = MonsterDefinitions.get(record.Species)
	if definition == nil then
		return 1
	end
	return definition.BaseMultiplier
end

function MonsterService.publish(player: Player)
	local data = DataService.get(player)
	local record = MonsterService.getRecord(player)
	if data == nil or record == nil then
		return
	end

	local definition = MonsterDefinitions.get(record.Species)
	local displayName = if definition ~= nil then definition.DisplayName else record.Species
	local growthRequired = if definition ~= nil then definition.GrowthRequired else 0
	local mutationText = table.concat(record.Mutations, ", ")

	player:SetAttribute("MonsterId", record.Species)
	player:SetAttribute("MonsterName", displayName)
	player:SetAttribute("Growth", record.Growth)
	player:SetAttribute("GrowthRequired", growthRequired)
	player:SetAttribute("Flesh", record.Flesh)
	player:SetAttribute("Flora", record.Flora)
	player:SetAttribute("Mineral", record.Mineral)
	player:SetAttribute("Mutations", mutationText)
	player:SetAttribute("Multiplier", MonsterService.getMultiplier(player))
	player:SetAttribute("Rarity", record.Rarity)
	DataService.publish(player)
	MonsterService.refreshVisual(player)
end

function MonsterService.refreshVisual(player: Player)
	local record = MonsterService.getRecord(player)
	if record == nil then
		return
	end
	local definition = MonsterDefinitions.get(record.Species)
	local baseName = player:GetAttribute("AssignedBaseName")
	local bases = workspace:FindFirstChild("Bases")
	local base = if typeof(baseName) == "string" and bases ~= nil then bases:FindFirstChild(baseName) else nil
	if base == nil or not base:IsA("Model") then
		return
	end
	local spawn = findMarker(base, "CreatureSpawn")
	if spawn == nil then
		return
	end

	local model = visuals[player]
	if model == nil then
		model = Instance.new("Model")
		model.Name = player.Name .. "_Monster"
		local part = Instance.new("Part")
		part.Name = "Body"
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = generatedFolder()
		visuals[player] = model
	end

	local body = model.PrimaryPart
	if body == nil then
		return
	end
	local scale = 3 + math.clamp(record.Growth / 40, 0, 4)
	body.Size = Vector3.new(scale, scale, scale * 1.4)
	body.Color = if definition ~= nil then definition.Color else Color3.fromRGB(180, 180, 180)
	local top = spawn.Position.Y + spawn.Size.Y / 2
	model:PivotTo(CFrame.new(spawn.Position.X, top + body.Size.Y / 2, spawn.Position.Z))

	local income = math.max(1, math.floor(MonsterService.getMultiplier(player))) / INCOME_SECONDS
	BillboardMetadata:Create(model, {
		DisplayName = if definition ~= nil then definition.DisplayName else record.Species,
		Rarity = record.Rarity,
		ValueText = string.format("%g/s · x%g Training", income, MonsterService.getMultiplier(player)),
		Modifier = table.concat(record.Mutations, ","),
		ObjectType = "Monster",
	})
end

function MonsterService.evolve(player: Player, nextSpecies: string): boolean
	local data = DataService.get(player)
	local record = MonsterService.getRecord(player)
	local definition = MonsterDefinitions.get(nextSpecies)
	if data == nil or record == nil or definition == nil then
		return false
	end

	data.Monsters[record.Species] = nil
	record.Species = nextSpecies
	record.Growth = 0
	record.Rarity = definition.Rarity
	data.Monsters[nextSpecies] = record
	data.EquippedMonster = nextSpecies
	data.Stats.Evolutions += 1
	player:SetAttribute("StatusMessage", definition.DisplayName .. " evolved")
	MonsterService.publish(player)
	return true
end

function MonsterService.onBaseReady(player: Player)
	MonsterService.publish(player)
end

function MonsterService.start()
	Players.PlayerRemoving:Connect(function(player)
		local visual = visuals[player]
		if visual ~= nil then
			visual:Destroy()
			visuals[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(INCOME_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data ~= nil then
					local gain = math.max(1, math.floor(MonsterService.getMultiplier(player)))
					data.Cash += gain
					DataService.publish(player)
				end
			end
		end
	end)
end

return MonsterService
