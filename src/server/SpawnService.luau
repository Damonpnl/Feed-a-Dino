--!nonstrict
-- Server-wide spawning/presentation. ResourceService owns authoritative record transactions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Validation = require(Shared.ResourceValidation)
local ResourceService = require(script.Parent.ResourceService)
local Guard = require(script.Parent.InteractionGuard)
local Config = require(Shared.FieldConfig)
local BillboardData = require(Shared.BillboardData)
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local Visuals = require(script.Parent.ResourceVisualService)
local Service = {}
local folder, field, rareRemote = nil, nil, nil
local markers, worldModels, announced = {}, {}, {}
local running = false
local function now() return workspace:GetServerTimeNow() end

local function sync()
	local state = ResourceService.getSnapshot()
	if not state then return end
	for id, model in worldModels do
		local record = state.Records[id]
		if not record or record.State == "CARRIED" then worldModels[id] = nil model:Destroy() end
	end
	for id in announced do if not state.Records[id] then announced[id] = nil end end
	field:SetAttribute("Phase", state.Phase)
	field:SetAttribute("Epoch", state.Epoch)
	field:SetAttribute("Cycle", state.Cycle)
	field:SetAttribute("NextResetAt", state.NextResetAt)
	field:SetAttribute("ResetEndsAt", state.ResetEndsAt)
	for _, node in state.Nodes do
		local marker = markers[node.Id]
		marker:SetAttribute("ResourceInstanceId", node.RecordId)
		marker:SetAttribute("RespawnAt", node.RespawnAt)
	end
	for id, record in state.Records do
		if record.State == "CARRIED" or worldModels[id] then continue end
		local definition = Resources.get(record.ResourceId)
		local marker = record.NodeId and markers[record.NodeId]
		local position = record.Position or (marker and marker.Position)
		assert(position, "Resource has no world position")
		local model = Visuals.create(definition, position)
		model:SetAttribute("ResourceId", record.ResourceId)
		model:SetAttribute("ResourceInstanceId", id)
		model:SetAttribute("Token", id) -- compatibility alias; still one server record
		model:SetAttribute("AreaId", record.AreaId)
		model:SetAttribute("NodeId", record.OriginalNodeId)
		model:SetAttribute("ResourceState", record.State)
		BillboardMetadata:Create(model, BillboardData.resource(definition))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab"
		prompt.ObjectText = definition.DisplayName .. (if definition.PowerRequired > 0 then " · Power " .. tostring(definition.PowerRequired) else "")
		prompt.RequiresLineOfSight, prompt.MaxActivationDistance = false, 12
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(player) Service.pickup(player, id) end)
		worldModels[id] = model
		model.Destroying:Connect(function()
			-- External destruction is consumption too. Internal sync removes ownership first.
			if worldModels[id] ~= model then return end
			worldModels[id] = nil
			ResourceService.releaseToken(record.AreaId, id)
			task.defer(sync)
		end)
		model.Parent = folder
		local firstSpawn = not announced[id]
		Visuals.rare(model, definition.Rarity, firstSpawn)
		if firstSpawn and Config.RarePresentation[definition.Rarity] then
			local area = Areas.get(record.AreaId)
			rareRemote:FireAllClients({
				InstanceId = id, ResourceId = record.ResourceId, DisplayName = definition.DisplayName,
				Rarity = definition.Rarity, AreaId = record.AreaId, AreaName = area.DisplayName,
			})
		end
		announced[id] = true
	end
end

-- Compatibility APIs retain existing test/integration callers.
Service.getRecord = ResourceService.getRecord
Service.getSnapshot = ResourceService.getSnapshot
Service.releaseToken = ResourceService.releaseToken
Service.returnToWorld = ResourceService.returnToWorld
function Service.validate()
	local state = ResourceService.getSnapshot()
	if not state then return {"Field is not running"} end
	local errors = ResourceService.validate()
	local seen = {}
	for _, model in folder:GetChildren() do
		local id = model:GetAttribute("ResourceInstanceId")
		local record = id and state.Records[id]
		if not id or seen[id] or not record or record.State == "CARRIED" then
			table.insert(errors, "Duplicate or orphan world resource: " .. model.Name)
		else seen[id] = true end
	end
	for id, record in state.Records do
		if record.State ~= "CARRIED" and not seen[id] then table.insert(errors, "Missing physical resource: " .. id) end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		local model = player.Character and player.Character:FindFirstChild("CarriedResource")
		if model then
			local id = model:GetAttribute("ResourceInstanceId")
			local record = id and state.Records[id]
			if not record or record.State ~= "CARRIED" or record.OwnerUserId ~= player.UserId or seen[id] then
				table.insert(errors, "Duplicate/orphan carried model")
			else seen[id] = true end
		end
	end
	for id, record in state.Records do
		if record.State == "CARRIED" and not seen[id] then table.insert(errors, "Missing carried model: " .. id) end
	end
	return errors
end
function Service.pickup(player, id)
	Service.step() -- Reconcile the exact deadline before accepting an interaction between timer ticks.
	local state = ResourceService.getSnapshot()
	if not state or state.Phase ~= "Normal" or type(id) ~= "string" then return false end
	if not Guard.allow(player, "Pickup", 0.15) then return false end
	if require(script.Parent.GuardianCatch).isRecovering(player) then return false end
	local record, model = state.Records[id], worldModels[id]
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not record or not model or not hrp or not humanoid or humanoid.Health <= 0 then return false end
	if not Guard.near(player, model.PrimaryPart.Position, 14) then return false end
	if record.State == "DROPPED" and now() >= record.DropExpiresAt then
		ResourceService.releaseToken(record.AreaId, id) return false
	end
	local CarryService = require(script.Parent.CarryService)
	if CarryService.get(player) then return false end
	local previous = ResourceService.claim(player, id)
	if not previous then return false end
	-- Remove the world representation before CarryService creates the carried one.
	-- A rejected claim is rolled back and sync recreates the world representation.
	sync()
	local ok, accepted = pcall(CarryService.give, player, record.ResourceId, record.AreaId, id)
	if not ok or not accepted then
		if not ok then CarryService.drop(player) end
		ResourceService.rollbackClaim(id, player.UserId, previous)
		if not ok then warn("[SpawnService] Carry failed: " .. tostring(accepted)) end
		return false
	end
	sync()
	local Guardian = require(script.Parent.GuardianService)
	Guardian.onPickup(player, id, ResourceService.getRecord(id).ClaimVersion)
	local data = require(script.Parent.DataService).get(player)
	if data then data.DiscoveredAreas[record.AreaId] = true end
	return true
end
function Service.step()
	local _, _, resetOccurred = ResourceService.step()
	if resetOccurred then require(script.Parent.GuardianService).resetAll() end
end
function Service.start()
	if running then return end
	local errors = Validation.config()
	local worldErrors, nodes = Validation.world(workspace:FindFirstChild("ExpeditionZones"), game.ServerStorage:FindFirstChild("ResourceModels"))
	for _, message in worldErrors do table.insert(errors, message) end
	assert(#errors == 0, "[ResourceValidation] " .. table.concat(errors, "; "))
	local root = workspace:FindFirstChild("GeneratedGameplay")
	if not root then root = Instance.new("Folder") root.Name = "GeneratedGameplay" root.Parent = workspace end
	folder = Instance.new("Folder") folder.Name = "Resources" folder.Parent = root
	field = Instance.new("Folder") field.Name = "WorldFieldState" field.Parent = ReplicatedStorage
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then remotes = Instance.new("Folder") remotes.Name = "Remotes" remotes.Parent = ReplicatedStorage end
	rareRemote = remotes:FindFirstChild("FieldRareSpawn")
	if not rareRemote then rareRemote = Instance.new("RemoteEvent") rareRemote.Name = "FieldRareSpawn" rareRemote.Parent = remotes end
	for _, node in nodes do markers[node.Id] = node.Marker end
	ResourceService.initialize(nodes, sync)
	running = true
	sync()
	print("[ResourceValidation] PASS 40 launch resources, 5 areas, 25 nodes")
	task.spawn(function()
		while running do task.wait(0.25) Service.step() end
	end)
end
return Service
