--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local EvolutionCalculator = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EvolutionCalculator"))
local MonsterDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterDefinitions"))
local MonsterService = require(script.Parent.MonsterService)
local ResourceCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceCatalog"))
local ResourceEffects = require(ReplicatedStorage.Shared.ResourceEffects)

local FeedService = {}

local bound: { [Model]: boolean } = {}

local function feed(player: Player)
	local CarryService = require(script.Parent.CarryService)
	local SpawnService = require(script.Parent.SpawnService)
	local item = CarryService.get(player)
	if item == nil then
		player:SetAttribute("StatusMessage", "Carry something to feed")
		return
	end

	local definition = ResourceCatalog.get(item.resourceId)
	local data = DataService.get(player)
	local record = MonsterService.getRecord(player)
	if definition == nil or data == nil or record == nil then
		return
	end

	local instance = SpawnService.getRecord(item.token)
	if not instance or instance.State ~= "Carried" or instance.OwnerUserId ~= player.UserId then return end
	ResourceEffects.apply(record, definition, math.random)

	local monsterDefinition = MonsterDefinitions.get(record.Species)
	local catalystId = if definition.ResourceType == "Catalyst" then definition.Id else nil
	local nextSpecies = if monsterDefinition ~= nil
		then EvolutionCalculator.resolve(monsterDefinition, record.Growth, record, catalystId, record.EvolutionFamilies)
		else nil

	local areaId = item.areaId
	local token = item.token
	CarryService.consume(player)
	SpawnService.releaseToken(areaId, token)

	data.Stats.Feeds += 1
	if nextSpecies ~= nil and MonsterDefinitions.get(nextSpecies) ~= nil then
		MonsterService.evolve(player, nextSpecies)
	else
		player:SetAttribute("StatusMessage", "Fed " .. definition.DisplayName)
		MonsterService.publish(player)
	end
end

local function bindBase(base: Model)
	if bound[base] then
		return
	end
	local point = base:FindFirstChild("FeedingPoint", true)
	if point == nil then
		warn("[FeedService] " .. base.Name .. " is missing FeedingPoint")
		return
	end

	local host = point:FindFirstChildWhichIsA("BasePart", true)
	if host == nil then
		warn("[FeedService] " .. base.Name .. " FeedingPoint has no part")
		return
	end

	local prompt = point:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		local created = Instance.new("ProximityPrompt")
		created.Parent = host
		prompt = created
	elseif not prompt.Parent:IsA("BasePart") and not prompt.Parent:IsA("Attachment") then
		prompt.Parent = host
	end

	prompt.ActionText = "Feed"
	prompt.ObjectText = "Monster"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Triggered:Connect(function(player)
		if base:GetAttribute("OwnerUserId") ~= player.UserId then
			player:SetAttribute("StatusMessage", "This is not your monster")
			return
		end
		feed(player)
	end)
	bound[base] = true
end

function FeedService.start()
	local bases = workspace:WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		if base:IsA("Model") then
			bindBase(base)
		end
	end
end

return FeedService
