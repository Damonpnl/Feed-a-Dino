--!nonstrict
-- Server-owned catch consequence: bounded knockback, short ragdoll, then a recovery
-- window that blocks pickups and repeat catches. The caller has already resolved the
-- carried item through CarryService.forceDrop. No damage, health, or rewards.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.GuardianConfig)
local Chase = require(game.ReplicatedStorage.Shared.GuardianChase)
local Catch = {}
local records = {}
local started = false
local function now() return workspace:GetServerTimeNow() end

-- Supports both Motor6D rigs and AnimationConstraint rigs (which ship with paired
-- BallSocketConstraints that only take effect once the animation joint is disabled).
local function ragdoll(character, record)
	for _,joint in character:GetDescendants() do
		if joint:IsA("AnimationConstraint") and joint.Name~="Root" and joint.Enabled then
			joint.Enabled=false
			table.insert(record.Joints, joint)
			local paired=joint.Parent and joint.Parent:FindFirstChild(joint.Name.."BallSocket")
			if not (paired and paired:IsA("BallSocketConstraint")) and joint.Attachment0 and joint.Attachment1 then
				local socket=Instance.new("BallSocketConstraint") socket.Name="GuardianRagdoll"
				socket.Attachment0=joint.Attachment0 socket.Attachment1=joint.Attachment1 socket.LimitsEnabled=true socket.UpperAngle=50
				socket.Parent=joint.Parent
				table.insert(record.Created, socket)
			end
		elseif joint:IsA("Motor6D") and joint.Name~="Root" and joint.Enabled and joint.Part0 and joint.Part1 then
			local a0=Instance.new("Attachment") a0.Name="GuardianRagdoll" a0.CFrame=joint.C0 a0.Parent=joint.Part0
			local a1=Instance.new("Attachment") a1.Name="GuardianRagdoll" a1.CFrame=joint.C1 a1.Parent=joint.Part1
			local socket=Instance.new("BallSocketConstraint") socket.Name="GuardianRagdoll"
			socket.Attachment0=a0 socket.Attachment1=a1 socket.LimitsEnabled=true socket.UpperAngle=50
			socket.TwistLimitsEnabled=true socket.TwistLowerAngle=-40 socket.TwistUpperAngle=40 socket.Parent=joint.Part0
			joint.Enabled=false
			table.insert(record.Joints, joint)
			table.insert(record.Created, a0) table.insert(record.Created, a1) table.insert(record.Created, socket)
		end
	end
	for _,part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name~="HumanoidRootPart" and not part:FindFirstAncestor("CarriedResource") and not part.CanCollide then
			part.CanCollide=true table.insert(record.Collided, part)
		end
	end
end

local function setOwner(character, owner)
	for _,part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then pcall(part.SetNetworkOwner, part, owner) end
	end
end

local function standingFrame(character, root, humanoid)
	local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances={character}
	local position=root.Position
	local hit=workspace:Raycast(position+Vector3.new(0,4,0), Vector3.new(0,-40,0), params)
	local y=if hit then hit.Position.Y+humanoid.HipHeight+root.Size.Y/2 else position.Y+2
	local look=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
	if look.Magnitude<1e-3 then look=Vector3.new(root.CFrame.UpVector.X,0,root.CFrame.UpVector.Z) end
	if look.Magnitude<1e-3 then look=Vector3.zAxis end
	local upright=Vector3.new(position.X,y,position.Z)
	return CFrame.lookAt(upright, upright+look.Unit)
end

-- Restores joints, collision, control and network ownership. Safe to call repeatedly
-- and on dead or removed characters.
local function standUp(player, record)
	if record.Standing then return end
	record.Standing=true
	for _,joint in record.Joints do if joint.Parent then joint.Enabled=true end end
	for _,instance in record.Created do instance:Destroy() end
	for _,part in record.Collided do if part.Parent then part.CanCollide=false end end
	table.clear(record.Joints) table.clear(record.Created) table.clear(record.Collided)
	local character=record.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.PlatformStand=false
		humanoid.RequiresNeck=record.RequiresNeck
	end
	if humanoid and root and character.Parent and humanoid.Health>0 and player.Character==character then
		if not root.Anchored then
			character:PivotTo(standingFrame(character, root, humanoid))
			for _,part in character:GetDescendants() do
				if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero part.AssemblyAngularVelocity=Vector3.zero end
			end
		end
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		if player.Parent==Players and not root.Anchored then setOwner(character, player) end
	end
	player:SetAttribute("GuardianRagdoll", false)
end

local function finish(player, record)
	if records[player]~=record then return end
	if record.Died then record.Died:Disconnect() end
	standUp(player, record)
	records[player]=nil
	if player.Parent==Players then player:SetAttribute("GuardianRecoverUntil", 0) end
end

function Catch.isRecovering(player)
	local record=records[player]
	return record~=nil and now()<record.Until
end

-- Applies the catch consequence once per recovery window. Returns false when the
-- player is already recovering or has no valid living character.
function Catch.apply(player, character, origin, facing, source)
	if Catch.isRecovering(player) or player.Character~=character then return false end
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health<=0 then return false end
	local previous=records[player]
	if previous then finish(player, previous) end
	local t=now()
	local tuning=Config.Catch
	local record={Character=character, Until=t+tuning.Recovery, Joints={}, Created={}, Collided={}, RequiresNeck=humanoid.RequiresNeck}
	records[player]=record
	player:SetAttribute("GuardianRecoverUntil", record.Until)
	player:SetAttribute("GuardianRagdoll", true)
	player:SetAttribute("GuardianCaughtBy", source)
	player:SetAttribute("GuardianCaughtTick", t)
	humanoid.RequiresNeck=false
	humanoid.PlatformStand=true
	ragdoll(character, record)
	if not root.Anchored then
		-- Releasing joints splits assemblies, which reverts them to automatic ownership.
		setOwner(character, nil)
		local launch=Chase.knockback(origin, root.Position, facing, tuning.Horizontal, tuning.Vertical)
		for _,part in character:GetDescendants() do
			if part:IsA("BasePart") and not part.Anchored then part.AssemblyLinearVelocity=launch end
		end
		root.AssemblyAngularVelocity=Vector3.new(launch.Z, 0, -launch.X).Unit*4
	end
	record.Died=humanoid.Died:Connect(function() finish(player, record) end)
	task.delay(tuning.Ragdoll, function() if records[player]==record then standUp(player, record) end end)
	task.delay(tuning.Recovery, function() finish(player, record) end)
	return true
end

function Catch.release(player)
	local record=records[player]
	if record then finish(player, record) end
end

function Catch.resetAll()
	for player in records do Catch.release(player) end
end

function Catch.getSnapshot(player)
	local record=records[player]
	return record and {Until=record.Until, Standing=record.Standing==true, Joints=#record.Joints} or nil
end

function Catch.start()
	if started then return end
	started=true
	local function hook(player)
		player.CharacterRemoving:Connect(function() Catch.release(player) end)
		player.CharacterAdded:Connect(function() Catch.release(player) end)
	end
	for _,player in Players:GetPlayers() do hook(player) end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player) Catch.release(player) end)
end

return Catch
