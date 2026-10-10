--!nonstrict
-- Server-wide field. Pure FieldState owns all IDs, node reservations and deadlines.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Validation = require(Shared.ResourceValidation)
local FieldState = require(Shared.FieldState)
local Config = require(Shared.FieldConfig)
local BillboardData = require(Shared.BillboardData)
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local Visuals = require(script.Parent.ResourceVisualService)
local Service = {}
local rng = Random.new()
local state, folder, field, rareRemote = nil, nil, nil, nil
local markers, worldModels, announced = {}, {}, {}
local running = false
local function now() return workspace:GetServerTimeNow() end

local function sync()
	for id, model in worldModels do
		local record = state.Records[id]
		if not record or record.State == "Carried" then worldModels[id] = nil model:Destroy() end
	end
	for id in announced do if not state.Records[id] then announced[id] = nil end end
	field:SetAttribute("Phase", state.Phase)
	field:SetAttribute("Cycle", state.Cycle)
	field:SetAttribute("NextResetAt", state.NextResetAt)
	field:SetAttribute("ResetEndsAt", state.ResetEndsAt)
	for _, node in state.Nodes do
		local marker = markers[node.Id]
		marker:SetAttribute("ResourceInstanceId", node.RecordId)
		marker:SetAttribute("RespawnAt", node.RespawnAt)
	end
	for id, record in state.Records do
		if record.State == "Carried" or worldModels[id] then continue end
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
			state:release(id, now())
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

function Service.getRecord(id)
	local record = state and state.Records[id]
	return record and table.clone(record)
end
function Service.getSnapshot()
	if not state then return nil end
	local snapshot = {Phase = state.Phase, Cycle = state.Cycle, NextResetAt = state.NextResetAt,
		ResetEndsAt = state.ResetEndsAt, Records = {}, Nodes = {}}
	for id, record in state.Records do snapshot.Records[id] = table.clone(record) end
	for id, node in state.Nodes do snapshot.Nodes[id] = table.clone(node) end
	return snapshot
end
function Service.validate()
	if not state then return {"Field is not running"} end
	local errors = state:validate()
	local seen = {}
	for _, model in folder:GetChildren() do
		local id = model:GetAttribute("ResourceInstanceId")
		local record = id and state.Records[id]
		if not id or seen[id] or not record or record.State == "Carried" then
			table.insert(errors, "Duplicate or orphan world resource: " .. model.Name)
		else seen[id] = true end
	end
	for id, record in state.Records do
		if record.State ~= "Carried" and not seen[id] then table.insert(errors, "Missing physical resource: " .. id) end
	end
	return errors
end
function Service.releaseToken(areaId, id)
	if not state then return false end
	local record = state.Records[id]
	if not record or record.AreaId ~= areaId then return false end
	state:release(id, now())
	sync()
	return true
end
function Service.returnToWorld(areaId, resourceId, id, position, ownerUserId)
	if not state then return false end
	local record = state.Records[id]
	if not record or record.AreaId ~= areaId or record.ResourceId ~= resourceId then return false end
	local params = RaycastParams.new()
	local excluded = {workspace.GeneratedGameplay}
	for _, player in Players:GetPlayers() do if player.Character then table.insert(excluded, player.Character) end end
	params.FilterDescendantsInstances = excluded
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -200, 0), params)
	local accepted = state:drop(id, ownerUserId, if hit then hit.Position else position, now())
	if accepted then sync() end
	return accepted
end
function Service.pickup(player, id)
	if not state or state.Phase ~= "Normal" then return false end
	local record, model = state.Records[id], worldModels[id]
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not record or not model or not hrp or not humanoid or humanoid.Health <= 0 then return false end
	if (hrp.Position - model.PrimaryPart.Position).Magnitude > 14 then return false end
	if record.State == "Dropped" and now() >= record.DropExpiresAt then
		state:release(id, now()) sync() return false
	end
	local CarryService = require(script.Parent.CarryService)
	if CarryService.get(player) then return false end
	local previous = state:claim(id, player.UserId)
	if not previous then return false end
	local ok, accepted = pcall(CarryService.give, player, record.ResourceId, record.AreaId, id)
	if not ok or not accepted then
		if not ok then CarryService.drop(player) end
		state:rollbackClaim(id, player.UserId, previous)
		if not ok then warn("[SpawnService] Carry failed: " .. tostring(accepted)) end
		return false
	end
	sync()
	local Guardian = require(script.Parent.GuardianService)
	Guardian.disturb(record.AreaId, if Resources.get(record.ResourceId).ResourceType == "Catalyst" then 3 else 1)
	local data = require(script.Parent.DataService).get(player)
	if data then data.DiscoveredAreas[record.AreaId] = true end
	return true
end
function Service.step()
	if not state then return end
	local before = state.Phase
	state:step(now())
	if before ~= state.Phase and state.Phase == "Reset" then require(script.Parent.GuardianService).resetAll() end
	sync()
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
	state = FieldState.new(nodes, function(low, high) return rng:NextInteger(low, high) end,
		function() return HttpService:GenerateGUID(false) end)
	for _, node in nodes do markers[node.Id] = node.Marker end
	state:start(now())
	running = true
	sync()
	print("[ResourceValidation] PASS 40 launch resources, 5 areas, 25 nodes")
	task.spawn(function()
		while running do task.wait(0.25) Service.step() end
	end)
end
return Service
