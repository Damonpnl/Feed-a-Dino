-- Opt-in Studio Play measurement of Grasslands pursuit against the live T-Rex.
-- Scripted runners only: results are timing/geometry evidence, not human playtests.
-- Attributes: Mode = "Locomotion" (server Humanoid:MoveTo at the real carry WalkSpeed)
-- or "Kinematic" (anchored runner at fixed speeds standing in for future Speed upgrades).
assert(game:GetService("RunService"):IsStudio())
local RunService, HttpService = game:GetService("RunService"), game:GetService("HttpService")
local S, H = game.ServerScriptService.Server, game.ReplicatedStorage.Shared
local Data, Carry, Resource, Spawn, Guardian, Catch = require(S.DataService), require(S.CarryService), require(S.ResourceService), require(S.SpawnService), require(S.GuardianService), require(S.GuardianCatch)
local PD, State, Chase, Config = require(H.PlayerData), require(H.FieldState), require(H.GuardianChase), require(H.GuardianConfig)
local p = game.Players:GetPlayers()[1]
local data = Data.get(p) local backup = PD.copy(data)
local mode = script:GetAttribute("Mode") or "Locomotion"
local checks, results = 0, {}
local function check(v, message) assert(v, message) checks += 1 script:SetAttribute("PassedChecks", checks) end
local function now() return workspace:GetServerTimeNow() end
local field, frame
local guardian = workspace.GeneratedGameplay.Guardians.TRex.Guardian
local entranceX = workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
local function along(position) return position.X - entranceX end
local function waitFor(fn, timeout) local d = os.clock() + timeout repeat if fn() then return true end task.wait(0.05) until os.clock() > d return fn() end
local function root() return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end

local function seed(resourceId, nodeIndex)
	task.wait(0.22)
	Guardian.resetAll()
	assert(field.Phase == "Normal", "Field must be in Normal phase")
	local node = field.Nodes[("Grasslands:Node%02d"):format(nodeIndex)]
	if node.RecordId then Resource.releaseToken("Grasslands", node.RecordId) end
	local record = field:create(node, resourceId, "GameplayTuning") Resource.step()
	for _, model in workspace.GeneratedGameplay.Resources:GetChildren() do
		if model:GetAttribute("ResourceInstanceId") == record.InstanceId then return record.InstanceId, model end
	end
	error("Seeded resource has no world model")
end

-- Runs one theft-to-outcome trial. strategy: "Straight" or "Dodge"; speed only for Kinematic.
local function trial(resourceId, nodeIndex, strategy, speed)
	local id, model = seed(resourceId, nodeIndex)
	local r = root()
	local start = model.PrimaryPart.Position
	r.Anchored = mode == "Kinematic"
	p.Character:PivotTo(CFrame.new(start + Vector3.new(-2, 3, 0)))
	task.wait(0.35)
	assert(Spawn.pickup(p, id), "Pickup failed")
	local slowdown = p:GetAttribute("CarrySlowdown") or 0
	local carrySpeed = if mode == "Kinematic" then speed else p.Character.Humanoid.WalkSpeed
	local drops = p:GetAttribute("DropTick")
	local t0, pursueAt = os.clock(), nil
	local outcome, minGap, attacks, lastState = "Timeout", math.huge, 0, nil
	local catchAlong, catchTime, peak, samples = nil, nil, 0, {}
	local lastGuard, lastClock = guardian.Position, os.clock()
	local goalZ = r.Position.Z
	local dodgeUntil, dodgeGoal = 0, nil
	local humanoid = p.Character.Humanoid
	local nextMove = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local rr = root()
		if not rr then return end
		local state = guardian:GetAttribute("GuardianState")
		if state ~= lastState then
			if state == "PURSUING" and not pursueAt then pursueAt = os.clock() - t0 end
			if state == "WARNING" then
				attacks += 1
				if strategy == "Dodge" then
					local lane = guardian:GetAttribute("HazardFrame")
					local side = if lane then lane.RightVector else Vector3.zAxis
					local sign = if (rr.Position - guardian.Position):Dot(side) >= 0 then 1 else -1
					dodgeGoal = rr.Position + Vector3.new(side.X, 0, side.Z).Unit * sign * 18 + Vector3.new(-4, 0, 0)
					dodgeUntil = os.clock() + Config.Areas.Grasslands.Warning + Config.Areas.Grasslands.Active
				end
			end
			lastState = state
		end
		local gp = guardian.Position
		local elapsed = os.clock() - lastClock
		if elapsed > 0.2 then
			local v = Vector3.new(gp.X - lastGuard.X, 0, gp.Z - lastGuard.Z).Magnitude / elapsed
			if state == "PURSUING" or state == "COOLDOWN" then peak = math.max(peak, v) table.insert(samples, v) end
			lastGuard, lastClock = gp, os.clock()
		end
		minGap = math.min(minGap, Chase.catchGap(guardian.CFrame, guardian.Size, rr.Position))
		local goal = if os.clock() < dodgeUntil and dodgeGoal then dodgeGoal else Vector3.new(entranceX - 20, rr.Position.Y, goalZ)
		if mode == "Kinematic" then
			local flat = Vector3.new(goal.X - rr.Position.X, 0, goal.Z - rr.Position.Z)
			if flat.Magnitude > 0.5 then p.Character:PivotTo(CFrame.new(rr.Position + flat.Unit * math.min(flat.Magnitude, speed * dt))) end
		elseif os.clock() >= nextMove then
			humanoid:MoveTo(goal) nextMove = os.clock() + 0.25
		end
	end)
	local finished = waitFor(function()
		if p:GetAttribute("DropTick") ~= drops then
			outcome = if tostring(p:GetAttribute("DropReason")):find("GuardianCatch", 1, true) then "Caught" else "HazardHit"
			return true
		end
		if not Carry.get(p) then outcome = "Lost" return true end
		local rr = root()
		if rr and along(rr.Position) < 0 then outcome = "Escaped" return true end
		return false
	end, 45)
	local rr = root()
	catchTime = os.clock() - t0
	catchAlong = rr and along(rr.Position)
	connection:Disconnect()
	humanoid:MoveTo(rr.Position)
	local mean = 0 for _, v in samples do mean += v end mean = if #samples > 0 then mean / #samples else 0
	local row = {
		Mode = mode, Resource = resourceId, Strategy = strategy, Speed = math.floor(carrySpeed * 100) / 100,
		Slowdown = slowdown, Curse = p:GetAttribute("CarryCurse") or "", StartAlong = math.floor(along(start)), Outcome = outcome,
		Seconds = math.floor(catchTime * 100) / 100, EndAlong = catchAlong and math.floor(catchAlong) or -1,
		MinGap = math.floor(minGap * 10) / 10, PursueAt = pursueAt and math.floor(pursueAt * 100) / 100 or -1,
		GuardianPeak = math.floor(peak * 10) / 10, GuardianMean = math.floor(mean * 10) / 10, Attacks = attacks, Finished = finished,
		DroppedId = id,
	}
	table.insert(results, row)
	script:SetAttribute("Results", HttpService:JSONEncode(results))
	return row
end

local function recover()
	waitFor(function() return not Catch.isRecovering(p) end, 4)
	if Carry.get(p) then Carry.forceDrop(p, p.Character, "Fixture cleanup") end
	local r = root() if r then r.Anchored = false end
end

-- Full catch consequence: one drop, knockback/ragdoll, pickup lock, restored control.
local function verifyCatch()
	local id, model = seed("RawMeat", 1)
	local r = root() r.Anchored = false
	local body = guardian.CFrame
	local spot = body.Position + body.LookVector * (guardian.Size.Z / 2 + 6)
	p.Character:PivotTo(CFrame.new(Vector3.new(model.PrimaryPart.Position.X, model.PrimaryPart.Position.Y + 3, model.PrimaryPart.Position.Z)))
	task.wait(0.3)
	check(Spawn.pickup(p, id), "Raw Meat theft in Grasslands")
	check(waitFor(function() return guardian:GetAttribute("GuardianState") == "WAKING" end, 0.5), "T-Rex wakes on the theft")
	local woke = os.clock()
	check(waitFor(function() return guardian:GetAttribute("GuardianState") == "PURSUING" end, 2), "T-Rex begins pursuit")
	local wake = os.clock() - woke
	check(wake >= Config.Areas.Grasslands.Wake - 0.1 and wake <= Config.Areas.Grasslands.Wake + 0.25, "Wake delay matches config: " .. wake)
	local drops, startPos = 0, nil
	local dropConn = p:GetAttributeChangedSignal("DropTick"):Connect(function() drops += 1 end)
	body = guardian.CFrame
	spot = body.Position + body.LookVector * (guardian.Size.Z / 2 + 2)
	p.Character:PivotTo(CFrame.new(Vector3.new(spot.X, r.Position.Y, spot.Z)))
	check(waitFor(function() return drops > 0 end, 1.5), "Server-validated body catch")
	startPos = root().Position
	check(tostring(p:GetAttribute("DropReason")) == "GuardianCatch:Grasslands" and not Carry.get(p), "Catch resolves the carry through CarryService")
	local record = Resource.getRecord(id)
	check(record and record.State == "DROPPED" and record.InstanceId == id, "Dropped resource keeps its GUID")
	check(math.abs(record.DropExpiresAt - now() - 20) < 1.5, "20-second dropped expiry preserved")
	check(p:GetAttribute("GuardianRagdoll") == true and Catch.isRecovering(p), "Ragdoll and recovery start")
	local disabled = 0 for _, j in p.Character:GetDescendants() do if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and not j.Enabled then disabled += 1 end end
	check(disabled >= 10, "Joints released for ragdoll: " .. disabled)
	check(p.Character.Humanoid.PlatformStand, "Movement suspended during ragdoll")
	check(waitFor(function() return guardian:GetAttribute("GuardianState") == "RETURNING" end, 1.5), "T-Rex returns home after the last target")
	task.wait(0.4)
	local moved = Vector3.new(root().Position.X - startPos.X, 0, root().Position.Z - startPos.Z).Magnitude
	check(moved > 2 and moved < 40, "Knockback is visible and bounded: " .. math.floor(moved * 10) / 10)
	for _, m in workspace.GeneratedGameplay.Resources:GetChildren() do
		if m:GetAttribute("ResourceInstanceId") == id then
			p.Character:PivotTo(m.PrimaryPart.CFrame + Vector3.new(0, 3, 0)) break
		end
	end
	task.wait(0.2)
	check(not Spawn.pickup(p, id) and Resource.getRecord(id).State == "DROPPED", "Pickup disabled during recovery")
	check(waitFor(function() return p:GetAttribute("GuardianRagdoll") == false end, Config.Catch.Ragdoll + 0.5), "Ragdoll ends")
	local enabled = true for _, j in p.Character:GetDescendants() do if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and not j.Enabled then enabled = false end end
	check(enabled and not p.Character.Humanoid.PlatformStand and not p.Character:FindFirstChild("GuardianRagdoll", true), "Joints and control restored")
	check(root():GetNetworkOwner() == p, "Network ownership returned to the player")
	check(drops == 1, "Exactly one drop per catch")
	check(waitFor(function() return not Catch.isRecovering(p) end, Config.Catch.Recovery), "Recovery window ends")
	local before = root().Position
	p.Character.Humanoid:MoveTo(before + Vector3.new(-12, 0, 0))
	check(waitFor(function() return (root().Position - before).Magnitude > 6 end, 3), "Player walks again after recovery")
	task.wait(0.25)
	for _, m in workspace.GeneratedGameplay.Resources:GetChildren() do
		if m:GetAttribute("ResourceInstanceId") == id then p.Character:PivotTo(m.PrimaryPart.CFrame + Vector3.new(0, 3, 0)) break end
	end
	task.wait(0.25)
	check(Spawn.pickup(p, id), "Dropped GUID collectable after recovery")
	check(waitFor(function() return guardian:GetAttribute("GuardianState") ~= "RETURNING" and guardian:GetAttribute("GuardianState") ~= "SLEEPING" end, 1), "Re-stealing the drop re-engages the owner guardian")
	Carry.forceDrop(p, p.Character, "Fixture cleanup")
	dropConn:Disconnect()
end

local oldStep = State.step
local ok, failure = xpcall(function()
	State.step = function(self, ...) field = self return oldStep(self, ...) end
	check(waitFor(function() return field ~= nil end, 5), "Field captured")
	frame = p.Character:GetPivot()
	data.Power = 1e12
	if mode == "Locomotion" then
		verifyCatch() recover()
		for node = 1, 5 do trial("RawMeat", node, "Straight") recover() end
		for node = 3, 5 do trial("RawMeat", node, "Dodge") recover() end
		for _, id in { "PrimeMeat", "AncientBone", "PrimalCatalyst" } do trial(id, 4, "Dodge") recover() end
	else
		for _, speed in { 14, 16, 18, 20 } do
			for node = 3, 5 do trial("RawMeat", node, "Straight", speed) recover() end
		end
	end
end, debug.traceback)
State.step = oldStep
Guardian.resetAll()
if Carry.get(p) then Carry.forceDrop(p, p.Character, "Fixture cleanup") end
for k in data do data[k] = nil end for k, v in backup do data[k] = v end
local r = root() if r then r.Anchored = false end
if frame and p.Character then p.Character:PivotTo(frame) end
script:SetAttribute("Result", if ok then "PASS" else failure)
if ok then print("[GameplayTuning] PASS " .. checks .. " " .. mode) else warn(failure) end
