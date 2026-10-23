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

-- Rare evacuation/spawn query only, never a per-frame proximity scan. A visitor
-- standing at the owner's spawn must not receive the evacuated character on top.
local function clearSpawn(base: Model, spawnPart: BasePart, character: Model, offset: number): Vector3?
	local exclusions: {Instance} = {character, spawnPart}
	local otherRoots: {BasePart} = {}
	for _, other in Players:GetPlayers() do
		local model=other.Character
		if model then
			table.insert(exclusions,model)
			local root=model:FindFirstChild("HumanoidRootPart")
			if model~=character and root and root:IsA("BasePart") then table.insert(otherRoots,root) end
		end
	end
	local ray=RaycastParams.new()
	ray.FilterDescendantsInstances=exclusions ray.RespectCanCollide=true
	local overlap=OverlapParams.new()
	overlap.FilterDescendantsInstances=exclusions overlap.RespectCanCollide=true
	local offsets={Vector3.zero}
	for _,distance in {8,16} do
		for _,direction in {Vector3.xAxis,-Vector3.xAxis,Vector3.zAxis,-Vector3.zAxis,
			Vector3.new(1,0,1),Vector3.new(1,0,-1),Vector3.new(-1,0,1),Vector3.new(-1,0,-1)} do
			table.insert(offsets,direction*distance)
		end
	end
	for _,delta in offsets do
		local point=spawnPart.Position+delta
		local hit=workspace:Raycast(point+Vector3.yAxis*8,-Vector3.yAxis*16,ray)
		if not hit or not hit.Instance:IsDescendantOf(base) or hit.Normal.Y<.8 then continue end
		local target=hit.Position+Vector3.yAxis*(offset+.1)
		local occupied=false
		for _,root in otherRoots do
			local difference=root.Position-target
			if Vector3.new(difference.X,0,difference.Z).Magnitude<6 and math.abs(difference.Y)<8 then occupied=true break end
		end
		if occupied then continue end
		local height=math.max(5,offset+2)
		local center=hit.Position+Vector3.yAxis*(height/2+.15)
		if #workspace:GetPartBoundsInBox(CFrame.new(center),Vector3.new(4,height,4),overlap)==0 then return target end
	end
	-- No unsafe fallback onto a visitor or solid geometry. Lockdown retries while
	-- closed; ownership has already been resolved even if a whole base is blocked.
	return nil
end

-- Non-yielding assigned-base evacuation; no shared fallback spawn or reassignment.
function BaseService.evacuate(player: Player, character: Model): boolean
	local base=assignedBases[player]
	if player.Character~=character or not base or base:GetAttribute("OwnerUserId")~=player.UserId then return false end
	local spawnPart=base:FindFirstChild("PlayerSpawn",true)
	local hrp=character:FindFirstChild("HumanoidRootPart")
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	if not spawnPart or not spawnPart:IsA("BasePart") or not hrp or not hrp:IsA("BasePart") then return false end
	local offset=if humanoid and humanoid.RigType==Enum.HumanoidRigType.R15 then humanoid.HipHeight+hrp.Size.Y/2 else 3
	local target=clearSpawn(base,spawnPart,character,offset)
	if not target then return false end
	character:PivotTo(CFrame.new(target))
	for _,part in character:GetDescendants() do if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero part.AssemblyAngularVelocity=Vector3.zero end end
	return true
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

	task.wait()

	-- Revalidate after both yields; a stale respawn must never move the new character.
	BaseService.evacuate(player,character)
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
