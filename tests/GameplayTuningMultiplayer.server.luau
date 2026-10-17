-- Opt-in two-real-client StudioTestService fixture for the guardian catch (args
-- "GameplayTuningMultiplayer"). Characters stay unanchored and client-owned so knockback,
-- network ownership and recovery are exercised on real clients. Movement is server-scripted
-- (PivotTo / Humanoid:MoveTo), not human input. Never mapped into production.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="GameplayTuningMultiplayer" then return end
local LogService=game:GetService("LogService")
local Server=game.ServerScriptService:WaitForChild("Server")
local Spawn,Carry,Resource,Data,Guardian,Catch=require(Server.SpawnService),require(Server.CarryService),require(Server.ResourceService),require(Server.DataService),require(Server.GuardianService),require(Server.GuardianCatch)
local Shared=game.ReplicatedStorage.Shared
local State,Config=require(Shared.FieldState),require(Shared.GuardianConfig)
local checks,notes=0,{}
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds)
	local limit=os.clock()+seconds repeat if fn() then return true end task.wait(0.03) until os.clock()>limit return fn()
end
local function physical(id)
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then return m end end
end
local function snapshot() return Guardian.getSnapshot("Grasslands") end
local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local errors={}
local logConn=LogService.MessageOut:Connect(function(message,kind)
	if kind==Enum.MessageType.MessageError then table.insert(errors,message) end
end)
local field local oldStep=State.step
State.step=function(self,...) field=self return oldStep(self,...) end
local function seed(nodeIndex)
	local node=field.Nodes[("Grasslands:Node%02d"):format(nodeIndex)]
	if node.RecordId then Resource.releaseToken("Grasslands",node.RecordId) end
	local record=field:create(node,"RawMeat","GameplayTuningMP") Resource.step()
	assert(waitFor(function() return physical(record.InstanceId)~=nil end,2),"Seeded model exists")
	return record.InstanceId
end
local function grab(p,id)
	task.wait(0.2)
	local m=physical(id) if not m then return false end
	p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0))
	task.wait(0.15)
	return Spawn.pickup(p,id)
end
local guardian,entranceX
local function catchHere(p)
	local body=guardian.CFrame
	local spot=body.Position+body.LookVector*(guardian.Size.Z/2+2)
	p.Character:PivotTo(CFrame.new(Vector3.new(spot.X,root(p).Position.Y,spot.Z)))
end
local function toSafety(p)
	local r=root(p)
	local start=Vector3.new(entranceX+6,r.Position.Y,r.Position.Z)
	p.Character:PivotTo(CFrame.new(start))
	local goal=Vector3.new(entranceX-20,r.Position.Y,r.Position.Z)
	local ok=waitFor(function() p.Character.Humanoid:MoveTo(goal) return root(p).Position.X<entranceX end,5)
	local h=p.Character.Humanoid
	return ok, ("from=%s now=%s recovering=%s stand=%s walk=%.1f owner=%s carry=%s"):format(tostring(start),tostring(root(p).Position),
		tostring(Catch.isRecovering(p)),tostring(h.PlatformStand),h.WalkSpeed,tostring(root(p):GetNetworkOwner()),tostring(Carry.get(p)~=nil))
end

local a,b
local originalPower={}
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2]) and Resource.getSnapshot()
	end,40),"Two actual Studio clients initialize")
	local ps=game.Players:GetPlayers() a,b=ps[1],ps[2]
	task.wait(1)
	check(waitFor(function() return field~=nil end,5),"Field captured")
	if Resource.getSnapshot().NextResetAt-workspace:GetServerTimeNow()<120 then
		table.insert(notes,"Waited for a fresh field cycle")
		check(waitFor(function() return Resource.getSnapshot().Phase=="Reset" end,130),"Reach field reset")
		check(waitFor(function() return Resource.getSnapshot().Phase=="Normal" end,15),"Fresh field cycle")
	end
	for _,p in ps do originalPower[p]=Data.get(p).Power Data.get(p).Power=1e12 end
	guardian=workspace.GeneratedGameplay.Guardians.TRex.Guardian
	entranceX=workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
	Guardian.resetAll()
	check(root(a):GetNetworkOwner()==a and root(b):GetNetworkOwner()==b,"Characters start client-owned")
	local minFront=math.huge
	local frontConn=game:GetService("RunService").Heartbeat:Connect(function()
		minFront=math.min(minFront,guardian.Position.X-guardian.Size.Z/2)
	end)

	-- 1. A steals Raw Meat, the T-Rex pursues and catches A: one drop, knockback, ragdoll.
	local first=seed(5)
	check(grab(a,first),"A steals Raw Meat in Grasslands")
	check(snapshot().TargetUserId==a.UserId,"T-Rex targets A")
	check(waitFor(function() return snapshot().State=="PURSUING" end,2),"T-Rex pursues")
	local drops=0 local dropConn=a:GetAttributeChangedSignal("DropTick"):Connect(function() drops+=1 end)
	catchHere(a)
	check(waitFor(function() return drops>0 end,1.5),"Server-validated catch on a real client")
	local caughtAt=root(a).Position
	check(a:GetAttribute("DropReason")=="GuardianCatch:Grasslands" and not Carry.get(a),"Catch drops through CarryService")
	check(Resource.getRecord(first).State=="DROPPED","Dropped record keeps the original GUID")
	check(a:GetAttribute("GuardianRagdoll")==true and a.Character.Humanoid.PlatformStand,"A is ragdolled")
	check(root(a):GetNetworkOwner()==nil,"Server owns the ragdoll physics")
	check(waitFor(function() return snapshot().State=="RETURNING" end,1.5),"T-Rex returns home after its last target")
	task.wait(0.35)
	local moved=Vector3.new(root(a).Position.X-caughtAt.X,0,root(a).Position.Z-caughtAt.Z).Magnitude
	check(moved>2 and moved<40,"Knockback on a real client is visible and bounded: "..math.floor(moved*10)/10)
	table.insert(notes,("KnockbackStuds=%.1f"):format(moved))

	-- 2. B collects A's drop during A's recovery; the owner guardian re-engages on B.
	local m=physical(first)
	check(m~=nil,"Dropped resource is physical in the world")
	b.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) task.wait(0.2)
	check(not Spawn.pickup(a,first),"Recovering A cannot pick up")
	check(Spawn.pickup(b,first) and Carry.get(b).token==first,"B collects A's dropped GUID")
	check(waitFor(function() return snapshot().TargetUserId==b.UserId and snapshot().State~="RETURNING" end,1),"T-Rex re-engages on B")
	-- Keep B out of reach while A's recovery is verified (B stays outside the safe zone).
	b.Character:PivotTo(CFrame.new(Vector3.new(entranceX+40,root(b).Position.Y,root(b).Position.Z)))

	-- 3. A recovers with control and network ownership restored.
	check(waitFor(function() return a:GetAttribute("GuardianRagdoll")==false end,Config.Catch.Ragdoll+0.5),"A's ragdoll ends")
	check(not a.Character.Humanoid.PlatformStand and root(a):GetNetworkOwner()==a,"A's control and ownership return")
	check(drops==1,"Exactly one drop for the catch")
	check(waitFor(function() return not Catch.isRecovering(a) end,Config.Catch.Recovery),"A's recovery ends")
	local before=root(a).Position
	a.Character.Humanoid:MoveTo(before+Vector3.new(-14,0,0))
	check(waitFor(function() return (root(a).Position-before).Magnitude>6 end,3),"A walks again on the client")

	-- 4. A steals again; B reaches safety and the T-Rex switches straight to A.
	local second=seed(2)
	check(grab(a,second),"A steals a second Raw Meat")
	local safeB,why=toSafety(b) check(safeB,"B reaches the safe zone: "..why)
	check(waitFor(function() return snapshot().TargetUserId==a.UserId end,0.6),"T-Rex switches to A immediately")
	check(b:GetAttribute("GuardianEscapeTick")~=nil and Carry.get(b),("B escapes with the carry: tick=%s carry=%s drop=%s"):format(
		tostring(b:GetAttribute("GuardianEscapeTick")),tostring(Carry.get(b)~=nil),tostring(b:GetAttribute("DropReason"))))
	local safeA,whyA=toSafety(a) check(safeA,"A reaches the safe zone: "..whyA)
	check(waitFor(function() return snapshot().State=="RETURNING" end,1.5),"T-Rex returns after the last carrier escapes")
	check(waitFor(function() return snapshot().State=="SLEEPING" end,30),"T-Rex is home and asleep")
	Carry.forceDrop(a,a.Character,"TestCleanup") Carry.forceDrop(b,b.Character,"TestCleanup")

	-- 5. Death during ragdoll never leaves a stuck character.
	Guardian.resetAll()
	local third=seed(5)
	check(grab(a,third),"A steals for the death case")
	check(waitFor(function() return snapshot().State=="PURSUING" end,2),"T-Rex pursues again")
	catchHere(a)
	check(waitFor(function() return Catch.isRecovering(a) end,1.5),"Second catch")
	a.Character.Humanoid.Health=0
	check(waitFor(function() return not Catch.isRecovering(a) end,1),"Death clears recovery")
	a:LoadCharacter()
	check(waitFor(function() return a.Character and a.Character:FindFirstChild("HumanoidRootPart") and a.Character.Humanoid.Health>0 end,10),"A respawns")
	task.wait(0.5)
	check(not a.Character.Humanoid.PlatformStand and a.Character.Humanoid.WalkSpeed==16 and a:GetAttribute("GuardianRagdoll")==false,"Respawned A is free and unslowed")
	check(not Spawn.pickup(a,"missing") and not Catch.isRecovering(a),"No recovery lock carries over")
	dropConn:Disconnect() frontConn:Disconnect()
	check(minFront>entranceX,"T-Rex body never entered the safe zone: "..math.floor(minFront-entranceX))
	check(#Spawn.validate()==0,"Resource uniqueness preserved")
	check(#errors==0,"No server errors: "..table.concat(errors," | "))
end,debug.traceback)
State.step=oldStep
logConn:Disconnect()
for p,power in originalPower do
	if p.Parent then
		if Carry.get(p) then Carry.forceDrop(p,p.Character,"TestCleanup") end
		if Data.get(p) then Data.get(p).Power=power end
	end
end
Guardian.resetAll()
local result={Result=if ok then "PASS" else failure,PassedChecks=checks,Notes=table.concat(notes,"; "),Mode="Two actual Studio clients; server-scripted movement"}
script:SetAttribute("Result",result.Result) script:SetAttribute("PassedChecks",checks)
if ok then print("[GameplayTuningMultiplayer] PASS "..checks.." checks; "..result.Notes) else warn("[GameplayTuningMultiplayer] "..failure) end
STS:EndTest(result)
