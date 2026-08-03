--!strict

--[[
	Assigns each player a free base and moves them to PlayerSpawn.
	Publishes assignment via attributes for other server systems:
	- Player.AssignedBaseName = base.Name
	- Base.OwnerUserId = player.UserId
]]

local Players = game:GetService("Players")

local basesFolder = workspace:WaitForChild("Bases")

local assignedBases: { [Player]: Model } = {}
local occupiedBases: { [Model]: boolean } = {}

local function findFreeBase(): Model?
	local sortedBases: { Model } = {}
	for _, base in basesFolder:GetChildren() do
		if base:IsA("Model") then
			table.insert(sortedBases, base)
		end
	end
	table.sort(sortedBases, function(a, b)
		return a.Name < b.Name
	end)

	for _, base in sortedBases do
		if not occupiedBases[base] then
			return base
		end
	end

	return nil
end

local function clearBaseOwnership(base: Model): ()
	base:SetAttribute("OwnerUserId", nil)
end

local function claimBase(player: Player, base: Model): ()
	assignedBases[player] = base
	occupiedBases[base] = true
	player:SetAttribute("AssignedBaseName", base.Name)
	base:SetAttribute("OwnerUserId", player.UserId)
	print(player.Name .. " received " .. base.Name)
end

local function moveCharacterToBase(player: Player, character: Model): ()
	local base = assignedBases[player]

	if base == nil then
		local freeBase = findFreeBase()
		if freeBase == nil then
			warn("No free base available for " .. player.Name)
			return
		end
		claimBase(player, freeBase)
		base = freeBase
	end

	local spawnPart = base:FindFirstChild("PlayerSpawn")
	if spawnPart == nil or not spawnPart:IsA("BasePart") then
		warn(base.Name .. " is missing a Part named PlayerSpawn")
		return
	end

	local hrp = character:WaitForChild("HumanoidRootPart")
	if not hrp:IsA("BasePart") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- Brief yield to let the character fully assemble before moving it
	task.wait()

	local topY = spawnPart.Position.Y + spawnPart.Size.Y / 2

	local yOffset = 3 -- default for R6 (HRP is 3 studs above feet)
	if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15 then
		yOffset = humanoid.HipHeight + hrp.Size.Y / 2
	end

	character:PivotTo(CFrame.new(spawnPart.Position.X, topY + yOffset, spawnPart.Position.Z))

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	print(player.Name .. " moved to " .. base.Name)
end

local function setupPlayer(player: Player): ()
	player.CharacterAdded:Connect(function(character)
		if character:IsA("Model") then
			moveCharacterToBase(player, character)
		end
	end)

	if player.Character ~= nil and player.Character:IsA("Model") then
		moveCharacterToBase(player, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local base = assignedBases[player]
	if base ~= nil then
		occupiedBases[base] = nil
		clearBaseOwnership(base)
	end

	assignedBases[player] = nil
	player:SetAttribute("AssignedBaseName", nil)
end)
