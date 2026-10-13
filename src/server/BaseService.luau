--!strict

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local MonsterService = require(script.Parent.MonsterService)

local BaseService = {}

local basesFolder = workspace:WaitForChild("Bases")

local assignedBases: { [Player]: Model } = {}
local occupiedBases: { [Model]: boolean } = {}
local initialized: {[Player]: boolean} = {}
local characterConnections: {[Player]: RBXScriptConnection} = {}
local started = false

local function findFreeBase(): Model?
	local sorted: { Model } = {}
	for _, base in basesFolder:GetChildren() do
		if base:IsA("Model") then
			table.insert(sorted, base)
		end
	end
	table.sort(sorted, function(a, b)
		return a.Name < b.Name
	end)
	for _, base in sorted do
		if not occupiedBases[base] then
			return base
		end
	end
	return nil
end

local function claimBase(player: Player, base: Model)
	assignedBases[player] = base
	occupiedBases[base] = true
	player:SetAttribute("AssignedBaseName", base.Name)
	base:SetAttribute("OwnerUserId", player.UserId)
	MonsterService.onBaseReady(player)
end

local function moveCharacterToBase(player: Player, character: Model)
	local base = assignedBases[player]
	if base == nil then
		local freeBase = findFreeBase()
		if freeBase == nil then
			warn("[BaseService] No free base for " .. player.Name)
			return
		end
		claimBase(player, freeBase)
		base = freeBase
	end

	local spawnPart = base:FindFirstChild("PlayerSpawn", true)
	if spawnPart == nil or not spawnPart:IsA("BasePart") then
		warn("[BaseService] " .. base.Name .. " is missing PlayerSpawn")
		return
	end

	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if hrp == nil or not hrp:IsA("BasePart") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	task.wait()

	local topY = spawnPart.Position.Y + spawnPart.Size.Y / 2
	local yOffset = 3
	if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15 then
		yOffset = humanoid.HipHeight + hrp.Size.Y / 2
	end

	character:PivotTo(CFrame.new(spawnPart.Position.X, topY + yOffset, spawnPart.Position.Z))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

local function setupPlayer(player: Player)
	if initialized[player] then return end
	initialized[player] = true
	DataService.load(player)
	if player.Parent ~= Players then initialized[player] = nil return end
	MonsterService.publish(player)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		moveCharacterToBase(player, character)
	end)
	if player.Character ~= nil then
		moveCharacterToBase(player, player.Character)
	end
end

function BaseService.start()
	if started then return end
	started = true
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if characterConnections[player] then characterConnections[player]:Disconnect() characterConnections[player] = nil end
		initialized[player] = nil
		local base = assignedBases[player]
		if base ~= nil then
			occupiedBases[base] = nil
			base:SetAttribute("OwnerUserId", nil)
		end
		assignedBases[player] = nil
	end)
end

return BaseService
