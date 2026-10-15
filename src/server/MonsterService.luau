--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local MonsterDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterDefinitions"))
local PlayerData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerData"))
local Evolution = require(ReplicatedStorage.Shared.EvolutionCalculator)
local Stages = require(ReplicatedStorage.Shared.GrowthStageDefinitions)
local Guard = require(script.Parent.InteractionGuard)
local HttpService = game:GetService("HttpService")

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
	local definition = MonsterDefinitions.get(Evolution.form(record))
	if definition == nil then
		return 1
	end
	local original = MonsterDefinitions.get(record.Species)
	return math.max(definition.BaseMultiplier,if original then original.BaseMultiplier else 1)
end

function MonsterService.publish(player: Player)
	local data = DataService.get(player)
	local record = MonsterService.getRecord(player)
	if data == nil or record == nil then
		return
	end

	local definition = MonsterDefinitions.get(Evolution.form(record))
	local displayName = if definition ~= nil then definition.DisplayName else record.Species
	local growthRequired = if definition ~= nil then definition.GrowthRequired else 0
	local mutationText = table.concat(record.Mutations, ", ")

	player:SetAttribute("MonsterId", Evolution.form(record))
	player:SetAttribute("OwnedPetKey", data.EquippedMonster)
	player:SetAttribute("PetStage",record.Stage)
	player:SetAttribute("PetStageLabel",if Stages.Stages[record.Stage] then Stages.Stages[record.Stage].Label else "Unknown")
	player:SetAttribute("GrowthReserve",record.GrowthReserve or 0)
	player:SetAttribute("PendingEvolution",if type(record.PendingEvolution)=="table" then HttpService:JSONEncode(record.PendingEvolution) else "")
	player:SetAttribute("MonsterName", displayName)
	player:SetAttribute("Growth", record.Growth)
	player:SetAttribute("TotalGrowth", record.TotalGrowth)
	player:SetAttribute("GrowthRequired", growthRequired)
	player:SetAttribute("Flesh", record.Flesh)
	player:SetAttribute("Flora", record.Flora)
	player:SetAttribute("Mineral", record.Mineral)
	player:SetAttribute("Mutations", mutationText)
	player:SetAttribute("EvolutionFamilies",HttpService:JSONEncode(record.EvolutionFamilies))
	player:SetAttribute("LatentTraits",HttpService:JSONEncode(record.LatentTraits or {}))
	player:SetAttribute("SpecialEvolutions",HttpService:JSONEncode(record.SpecialEvolutions or {}))
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
	local definition = MonsterDefinitions.get(Evolution.form(record))
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
	local previous = if model and model:GetAttribute("EvolutionForm")~=Evolution.form(record) then model else nil
	if previous then model=nil end
	if model == nil then
		model = Instance.new("Model")
		model.Name = player.Name .. "_Monster"
		local part = Instance.new("Part")
		part.Name = "Body"
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		model.PrimaryPart = part
		model:SetAttribute("EvolutionForm",Evolution.form(record))
		visuals[player] = model
	end

	local body = model.PrimaryPart
	if body == nil then
		return
	end
	local stageScale = if definition and definition.Visual then definition.Visual.Scale else 1
	local threshold = if definition then definition.GrowthRequired else 50
	local scale = stageScale * (3 + math.clamp(record.Growth / threshold, 0, 1))
	body.Size = Vector3.new(scale, scale, scale * 1.4)
	body.Color = if definition ~= nil then definition.Color else Color3.fromRGB(180, 180, 180)
	local top = spawn.Position.Y + spawn.Size.Y / 2
	model:PivotTo(CFrame.new(spawn.Position.X, top + body.Size.Y / 2, spawn.Position.Z))
	model.Parent=generatedFolder()
	if previous then previous:Destroy() end

	local income = math.max(1, math.floor(MonsterService.getMultiplier(player))) / INCOME_SECONDS
	BillboardMetadata:Create(model, {
		DisplayName = if definition ~= nil then definition.DisplayName else record.Species,
		Rarity = record.Rarity,
		ValueText = string.format("%g/s · x%g Training", income, MonsterService.getMultiplier(player)),
		Modifier = table.concat(record.Mutations, ","),
		ObjectType = "Monster",
	})
end

function MonsterService.chooseEvolution(player: Player, request: any): (boolean, string)
	if not Guard.allow(player,"EvolutionChoice",0.2) then return false,"Please wait" end
	if type(request)~="table" then return false,"Invalid choice" end
	for _,key in {"PetKey","Token","BranchId"} do
		if type(request[key])~="string" or #request[key]>160 then return false,"Invalid choice" end
	end
	if not DataService.isWritable(player) then return false,"Player data is not writable" end
	local data = DataService.get(player)
	local record = MonsterService.getRecord(player)
	if not data or not record or request.PetKey~=data.EquippedMonster then return false,"Wrong active pet" end
	local baseName=player:GetAttribute("AssignedBaseName")
	local bases=workspace:FindFirstChild("Bases")
	local base=if type(baseName)=="string" and bases then bases:FindFirstChild(baseName) else nil
	local point=base and base:FindFirstChild("FeedingPoint",true)
	local host=point and (if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true))
	if not base or not host or not Guard.ownedBase(player,base,host,14) then return false,"Approach your own pet with a living character" end
	local count=data.Stats and data.Stats.Evolutions
	if type(count)~="number" or count<0 or count>=Stages.MaxNumber or count%1~=0 then return false,"Invalid evolution counter" end
	local staged=PlayerData.copy(record)
	local calculated,ok,reason=pcall(Evolution.select,staged,request.Token,request.BranchId)
	if not calculated then return false,"Evolution calculation failed; state kept" end
	if not ok then return false,reason end
	-- No yield between session validation, selection, and replacing this one owned record.
	data.Monsters[data.EquippedMonster]=staged
	data.Stats.Evolutions += 1
	local published=pcall(function() player:SetAttribute("StatusMessage",reason) MonsterService.publish(player) end)
	if not published then warn("[MonsterService] Evolution committed; presentation needs refresh") end
	return true,reason
end

function MonsterService.evolve(player: Player, nextForm: string): boolean
	-- Compatibility entry point now requires a real pending eligible choice.
	local data,record=DataService.get(player),MonsterService.getRecord(player)
	if not data or not record or not record.PendingEvolution then return false end
	return MonsterService.chooseEvolution(player,{PetKey=data.EquippedMonster,Token=record.PendingEvolution.Token,
		BranchId=Evolution.form(record)..":"..nextForm})
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
