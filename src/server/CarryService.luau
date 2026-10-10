--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local ResourceCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceCatalog"))
local BillboardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BillboardData"))
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local ResourceVisuals = require(script.Parent.ResourceVisualService)

local CarryService = {}

local BASE_WALK_SPEED = 16

export type CarriedItem = {
	resourceId: string,
	areaId: string,
	token: string,
}

local carried: { [Player]: CarriedItem } = {}
local visuals: { [Player]: Model } = {}
local dropRemote: RemoteEvent

local function setStatus(player: Player, message: string)
	player:SetAttribute("StatusMessage", message)
	task.delay(2.5, function()
		if player.Parent ~= nil and player:GetAttribute("StatusMessage") == message then
			player:SetAttribute("StatusMessage", "")
		end
	end)
end

local function clearVisual(player: Player)
	local visual = visuals[player]
	if visual ~= nil then
		visual:Destroy()
		visuals[player] = nil
	end
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	local item = carried[player]
	if item == nil then
		humanoid.WalkSpeed = BASE_WALK_SPEED
		return
	end
	local definition = ResourceCatalog.get(item.resourceId)
	local multiplier = if definition ~= nil then 1 - definition.CarrySlowdown else 1
	humanoid.WalkSpeed = BASE_WALK_SPEED * multiplier
end

local function attachVisual(player: Player)
	clearVisual(player)
	local item = carried[player]
	local character = player.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if item == nil or hrp == nil or not hrp:IsA("BasePart") then
		return
	end
	local definition = ResourceCatalog.get(item.resourceId)
	if definition == nil then return end
	local model = ResourceVisuals.create(definition, hrp.Position)
	model.Name = "CarriedResource"
	model:PivotTo(hrp.CFrame * CFrame.new(0, 1.5, -2))
	local part = model.PrimaryPart
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored, child.CanCollide, child.Massless = false, false, true
			if child ~= part then
				local joint = Instance.new("WeldConstraint")
				joint.Part0, joint.Part1, joint.Parent = part, child, part
			end
		end
	end
	model.Parent = character
	model:SetAttribute("ResourceInstanceId", item.token)
	BillboardMetadata:Create(model, BillboardData.resource(definition))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = part
	weld.Parent = part
	visuals[player] = model
	applySpeed(player)

	local displayName = if definition ~= nil then definition.DisplayName else item.resourceId
	player:SetAttribute("CarriedResourceId", item.resourceId)
	player:SetAttribute("CarriedName", displayName)
	player:SetAttribute("CarriedAreaId", item.areaId)
end

function CarryService.get(player: Player): CarriedItem?
	return carried[player]
end

function CarryService.give(player: Player, resourceId: string, areaId: string, token: string): boolean
	local instance = require(script.Parent.SpawnService).getRecord(token)
	if not instance or instance.State ~= "Carried" or instance.OwnerUserId ~= player.UserId
		or instance.ResourceId ~= resourceId or instance.AreaId ~= areaId then return false end
	if carried[player] ~= nil then
		setStatus(player, "Already carrying something")
		return false
	end
	local definition = ResourceCatalog.get(resourceId)
	if definition == nil then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	if data.Power < definition.PowerRequired then
		setStatus(player, "Need " .. tostring(definition.PowerRequired) .. " Power")
		return false
	end

	carried[player] = {
		resourceId = resourceId,
		areaId = areaId,
		token = token,
	}
	attachVisual(player)
	setStatus(player, "Carrying " .. definition.DisplayName)
	return true
end

function CarryService.drop(player: Player): CarriedItem?
	local item = carried[player]
	if item == nil then
		return nil
	end
	carried[player] = nil
	clearVisual(player)
	applySpeed(player)
	player:SetAttribute("CarriedResourceId", "")
	player:SetAttribute("CarriedName", "")
	player:SetAttribute("CarriedAreaId", "")
	return item
end

function CarryService.consume(player: Player): CarriedItem?
	return CarryService.drop(player)
end

function CarryService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		remotes = folder
	end
	local existing = remotes:FindFirstChild("DropCarried")
	if existing ~= nil and existing:IsA("RemoteEvent") then
		dropRemote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "DropCarried"
		created.Parent = remotes
		dropRemote = created
	end

	dropRemote.OnServerEvent:Connect(function(player)
		local character = player.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local position = if hrp ~= nil and hrp:IsA("BasePart") then hrp.Position else nil
		local item = CarryService.drop(player)
		if item ~= nil and position ~= nil then
			local SpawnService = require(script.Parent.SpawnService)
			SpawnService.returnToWorld(item.areaId, item.resourceId, item.token, position, player.UserId)
		elseif item ~= nil then
			require(script.Parent.SpawnService).releaseToken(item.areaId, item.token)
		end
	end)

	local function hookCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				local hrp = character:FindFirstChild("HumanoidRootPart")
				local position = if hrp ~= nil and hrp:IsA("BasePart") then hrp.Position else nil
				local item = CarryService.drop(player)
				if item ~= nil and position ~= nil then
					local SpawnService = require(script.Parent.SpawnService)
					SpawnService.returnToWorld(item.areaId, item.resourceId, item.token, position, player.UserId)
				elseif item ~= nil then
					require(script.Parent.SpawnService).releaseToken(item.areaId, item.token)
				end
			end)
		end
		task.defer(function()
			if carried[player] ~= nil then
				attachVisual(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
		if player.Character ~= nil then
			hookCharacter(player, player.Character)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local item = CarryService.drop(player)
		if item ~= nil then
			local SpawnService = require(script.Parent.SpawnService)
			SpawnService.releaseToken(item.areaId, item.token)
		end
	end)
end

return CarryService
