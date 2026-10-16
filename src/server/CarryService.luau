--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local ResourceCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceCatalog"))
local BillboardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BillboardData"))
local BillboardMetadata = require(script.Parent.BillboardMetadataService)
local ResourceVisuals = require(script.Parent.ResourceVisualService)
local ResourceService = require(script.Parent.ResourceService)
local Guard = require(script.Parent.InteractionGuard)
local Format = require(ReplicatedStorage.Shared.NumberFormat)
local CarryDebuff = require(ReplicatedStorage.Shared.CarryDebuff)

local CarryService = {}

local BASE_WALK_SPEED = 16

export type CarriedItem = {
	resourceId: string,
	areaId: string,
	token: string,
}

local carried: { [Player]: CarriedItem } = {}
local debuffs: { [Player]: CarryDebuff.Assignment } = {}
local curseStart: { [Player]: number } = {}
-- Keyed by resource token so a dropped item keeps its curse when recovered.
local assignments: { [string]: CarryDebuff.Assignment } = {}
local curseRandom = Random.new()
local visuals: { [Player]: Model } = {}
local carryCharacters: {[Player]: Model} = {}
local characterConnections: {[Player]: {RBXScriptConnection}} = {}
local dropRemote: RemoteEvent
local started = false

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

local function currentExtra(player: Player): number
	local start = curseStart[player]
	if start == nil then return 0 end
	return CarryDebuff.extraSlowdown(debuffs[player], workspace:GetServerTimeNow() - start)
end

local function currentApplied(player: Player): number
	local item = carried[player]
	if item == nil then
		return 0
	end
	local definition = ResourceCatalog.get(item.resourceId)
	local base = if definition ~= nil then definition.CarrySlowdown else 0
	return CarryDebuff.applied(base, currentExtra(player))
end

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	if carried[player] == nil then
		humanoid.WalkSpeed = BASE_WALK_SPEED
		return
	end
	local applied = currentApplied(player)
	humanoid.WalkSpeed = BASE_WALK_SPEED * (1 - applied)
	if visuals[player] ~= nil then
		player:SetAttribute("CarrySlowdown", applied)
		player:SetAttribute("CarryDebuff", currentExtra(player))
	end
end

local function pruneAssignments()
	for token in assignments do
		local record = ResourceService.getRecord(token)
		if not record or (record.State ~= "CARRIED" and record.State ~= "DROPPED") then
			assignments[token] = nil
		end
	end
end

local function attachVisual(player: Player): boolean
	clearVisual(player)
	local item = carried[player]
	local character = player.Character
	local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if item == nil or hrp == nil or not hrp:IsA("BasePart") then
		return false
	end
	local definition = ResourceCatalog.get(item.resourceId)
	if definition == nil then return false end
	local model = ResourceVisuals.create(definition, hrp.Position)
	-- Register immediately so SpawnService's protected rollback can also clean up
	-- a partial attachment if metadata or a custom asset fails later in this function.
	visuals[player] = model
	model.Name = "CarriedResource"
	model:PivotTo(hrp.CFrame * CFrame.new(0, 1.5, -2))
	local part = model.PrimaryPart
	if not part then model:Destroy() return false end
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
	player:SetAttribute("CarriedRarity", definition.Rarity)
	player:SetAttribute("CarrySlowdown", currentApplied(player))
	player:SetAttribute("CarryDebuff", currentExtra(player))
	local curse = debuffs[player]
	player:SetAttribute("CarryCurse", if curse and #curse.Effects > 0 then HttpService:JSONEncode(curse) else "")
	player:SetAttribute("CarryCurseTitle", if curse then curse.Title else "")
	player:SetAttribute("CarryCurseStart", curseStart[player] or 0)
	player:SetAttribute("CarriedInstanceId", item.token)
	return true
end

function CarryService.get(player: Player): CarriedItem?
	return if carried[player] then table.clone(carried[player]) else nil
end

-- Applied session slowdown right now: definition CarrySlowdown plus active curse slowdown.
-- Not persisted. get() still returns only resourceId, areaId, and token.
function CarryService.getAppliedSlowdown(player: Player): number
	return currentApplied(player)
end

-- Read-only curse view for the current carry: assignment plus server start time.
function CarryService.getCurse(player: Player): (CarryDebuff.Assignment?, number?)
	local curse = debuffs[player]
	if curse == nil then return nil, nil end
	return table.clone(curse), curseStart[player]
end

function CarryService.give(player: Player, resourceId: string, areaId: string, token: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player.Parent ~= Players or not character or not humanoid or humanoid.Health <= 0 then return false end
	local instance = ResourceService.getRecord(token)
	if not instance or instance.State ~= "CARRIED" or instance.OwnerUserId ~= player.UserId
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
		setStatus(player, Format.needPower(definition.PowerRequired))
		return false
	end

	pruneAssignments()
	local assignment = assignments[token]
	if assignment == nil or assignment.Rarity ~= definition.Rarity then
		assignment = CarryDebuff.assign(definition.Rarity, function() return curseRandom:NextNumber() end)
	end
	if assignment == nil then
		return false
	end
	assignments[token] = assignment
	carried[player] = {
		resourceId = resourceId,
		areaId = areaId,
		token = token,
	}
	debuffs[player] = assignment
	curseStart[player] = workspace:GetServerTimeNow()
	carryCharacters[player] = character
	if not attachVisual(player) then CarryService.drop(player) return false end
	setStatus(player, "Carrying " .. definition.DisplayName)
	return true
end

function CarryService.drop(player: Player): CarriedItem?
	local item = carried[player]
	if item == nil then
		return nil
	end
	carried[player] = nil
	debuffs[player] = nil
	curseStart[player] = nil
	carryCharacters[player] = nil
	clearVisual(player)
	applySpeed(player)
	player:SetAttribute("CarriedResourceId", "")
	player:SetAttribute("CarriedName", "")
	player:SetAttribute("CarriedAreaId", "")
	player:SetAttribute("CarriedRarity", "")
	player:SetAttribute("CarrySlowdown", 0)
	player:SetAttribute("CarryDebuff", 0)
	player:SetAttribute("CarryCurse", "")
	player:SetAttribute("CarryCurseTitle", "")
	player:SetAttribute("CarryCurseStart", 0)
	player:SetAttribute("CarriedInstanceId", "")
	return item
end

function CarryService.consume(player: Player): CarriedItem?
	return CarryService.drop(player)
end

function CarryService.consumeOwned(player: Player, token: string): boolean
	local item = carried[player]
	if not item or item.token ~= token or not ResourceService.consume(player, token) then return false end
	assignments[token] = nil
	local ok = pcall(CarryService.drop, player)
	if not ok then
		warn("[CarryService] Consume committed; retrying carry presentation cleanup")
		-- Core ownership is already cleared by drop before any presentation work.
		pcall(clearVisual, player)
		pcall(applySpeed, player)
	end
	return true
end

local function returnOrRelease(player: Player, item: CarriedItem, position: Vector3?)
	if position ~= nil and ResourceService.returnToWorld(item.areaId, item.resourceId, item.token, position, player.UserId) then return end
	-- Invalid/missing character geometry must not leave a ghost carried record.
	ResourceService.releaseToken(item.areaId, item.token)
end

-- One no-yield consequence path for input, guardians and character lifecycle.
-- An old character cannot resolve a newer character's carry session.
function CarryService.forceDrop(player: Player, character: Model?, reason: string): boolean
	if not character or carryCharacters[player] ~= character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local item = CarryService.drop(player)
	if not item then return false end
	returnOrRelease(player, item, if root and root:IsA("BasePart") then root.Position else nil)
	player:SetAttribute("DropReason", reason)
	player:SetAttribute("DropTick", workspace:GetServerTimeNow())
	return true
end

-- Sole server movement calculation: training changes Power, not WalkSpeed.
-- No movement upgrade formula exists; retain the locked 16 * (1 - slowdown).
CarryService.recalculateMovement = applySpeed

function CarryService.start()
	if started then return end
	started = true
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
		if not Guard.allow(player, "Drop", 0.2) then return end
		CarryService.forceDrop(player, player.Character, "Manual")
	end)

	local function hookCharacter(player: Player, character: Model)
		local prior = characterConnections[player]
		if prior then for _,connection in prior do connection:Disconnect() end end
		local connections: {RBXScriptConnection} = {}
		characterConnections[player] = connections
		local humanoid = character:WaitForChild("Humanoid", 10)
		if player.Parent ~= Players or player.Character ~= character or characterConnections[player] ~= connections then return end
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			table.insert(connections, humanoid.Died:Connect(function() CarryService.forceDrop(player, character, "Death") end))
			table.insert(connections, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if player.Character == character then applySpeed(player) end
			end))
			applySpeed(player)
		end
	end

	local function hookPlayer(player: Player)
		player.CharacterRemoving:Connect(function(character)
			CarryService.forceDrop(player, character, "CharacterRemoving")
		end)
		player.CharacterAdded:Connect(function(character) hookCharacter(player, character) end)
		if player.Character then task.spawn(hookCharacter, player, player.Character) end
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do hookPlayer(player) end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		for player, curse in debuffs do
			if CarryDebuff.isTimed(curse) then applySpeed(player) end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local connections = characterConnections[player]
		if connections then for _,connection in connections do connection:Disconnect() end end
		characterConnections[player] = nil
		local item = CarryService.drop(player)
		if item ~= nil then
			ResourceService.releaseToken(item.areaId, item.token)
		end
	end)
end

return CarryService
