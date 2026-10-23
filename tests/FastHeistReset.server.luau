-- Opt-in actual-service reset tests. Controlled cutoff, real ten-second closure.
-- Multiplayer mode must be launched with two actual Studio clients.
local Run=game:GetService("RunService") assert(Run:IsStudio())
local Test=game:GetService("StudioTestService")
if script:GetAttribute("Multiplayer") and Test:GetTestArgs()~="FastHeistReset" then return end
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local D,C,R,G,Spawn,Feed,Catch=require(S.DataService),require(S.CarryService),require(S.ResourceService),require(S.GuardianService),require(S.SpawnService),require(S.FeedService),require(S.GuardianCatch)
local State,PD=require(H.FieldState),require(H.PlayerData)
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.03) until os.clock()>stop return false end
local checks=0 local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local players,backups,frames={}, {}, {}
local field,deadline local original=State.step
local originalReturn=R.returnToWorld
local originalDrop=C.forceDrop
local function move(p,point) p.Character:PivotTo(CFrame.new(point+Vector3.new(0,4,0))) end
local function inside(p,area) move(p,G.getSnapshot(area).Home-Vector3.xAxis*60) end
local function base(p) return workspace.Bases[p:GetAttribute("AssignedBaseName")] end
local function safe(p) move(p,base(p):FindFirstChild("PlayerSpawn",true).Position) end
local function give(p)
	G.resetAll() Catch.release(p)
	local id,why=Spawn.devGrant(p,"Grasslands","RawMeat","none") assert(id,why) return id
end
local function cycle()
	field.NextResetAt=workspace:GetServerTimeNow()+.2
	local cutoff=field.NextResetAt
	assert(waitFor(function() return field.Phase=="Reset" end,2))
	return cutoff
end
local ok,err=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		if #ps<(script:GetAttribute("Multiplayer") and 2 or 1) then return false end
		for _,p in ps do if not D.get(p) or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") or not p:GetAttribute("AssignedBaseName") then return false end end
		players=ps return true
	end,45),"Actual players initialized")
	for _,p in players do backups[p]=PD.copy(D.get(p)) frames[p]=p.Character:GetPivot() D.get(p).Power=150e6 D.publish(p) end
	State.step=function(self,...) field=self return original(self,...) end
	assert(waitFor(function() return field end,3)) State.step=original
	assert(waitFor(function() return field.Phase=="Normal" end,12)) deadline=field.NextResetAt
	local a,b=players[1],players[2]
	local gates=workspace.GeneratedGameplay.FieldGates
	check(#gates:GetChildren()==5,"Five runtime biome gates")
	if b then
		-- Two actual clients race one real world model through normal pickup validation.
		local id,why=R.devReplace("Grasslands","RawMeat","Grasslands:Node01") assert(id,why)
		local record=R.getRecord(id) move(a,record.Position) move(b,record.Position)
		a.Character.HumanoidRootPart.Anchored=true b.Character.HumanoidRootPart.Anchored=true
		local wins=0 local winner,loser
		for _,p in {a,b} do task.spawn(function() if Spawn.pickup(p,id) then wins+=1 winner=p end end) end
		check(waitFor(function() return wins>0 end,2) and wins==1,"Concurrent real-client pickup has exactly one winner")
		loser=if winner==a then b else a
		check(C.get(winner).token==id and not C.get(loser) and R.owned(winner,id),"One authoritative owner after pickup race")
		local curse=winner:GetAttribute("CarryCurse") G.resetAll()
		check(C.forceDrop(winner,winner.Character,"Transfer fixture"),"Winning carrier drops original GUID")
		move(loser,R.getRecord(id).Position) task.wait(.22)
		check(Spawn.pickup(loser,id) and C.get(loser).token==id and loser:GetAttribute("CarryCurse")==curse,"Other client recovers same GUID and curse")
		check(C.consumeOwned(loser,id) and not C.consumeOwned(loser,id) and #Spawn.validate()==0,"Transfer cannot duplicate consumption")
		G.resetAll() safe(a) safe(b)
		-- Both clients are then threatened by ONE guardian. Catching A must promptly
		-- hand pursuit to B instead of returning home or duplicating A's drop.
		local home=G.getSnapshot("Grasslands").Home
		move(a,home-Vector3.yAxis*4) move(b,home-Vector3.xAxis*90)
		local first=assert(Spawn.devGrant(a,"Grasslands","RawMeat","none"))
		local second=assert(Spawn.devGrant(b,"Grasslands","PrimeMeat","none"))
		local health=a.Character.Humanoid.Health
		check(G.getSnapshot("Grasslands").TargetUserId==a.UserId,"First of two same-area thieves is initial target")
		check(waitFor(function() return not C.get(a) end,4),"Real body catch resolves first carrier")
		check(R.getRecord(first) and R.getRecord(first).State=="DROPPED" and a.Character.Humanoid.Health==health,"Catch drops original GUID without damage")
		check(waitFor(function() return G.getSnapshot("Grasslands").TargetUserId==b.UserId end,2),"Catch retargets second actual client")
		check(C.get(b) and C.get(b).token==second,"Retarget does not consume other carrier")
		G.resetAll() Catch.release(a)
		check(C.consumeOwned(b,second) and not C.consumeOwned(b,second),"Second carrier still consumes once")
		R.releaseToken("Grasslands",first) safe(a) safe(b)
		a.Character.HumanoidRootPart.Anchored=false b.Character.HumanoidRootPart.Anchored=false
	end
	-- Simultaneous inside/outside carriers: never infer multiplayer from a single player.
	local tokenA=give(a) inside(a,"Grasslands")
	local tokenB
	local visitorFrame
	if b then
		tokenB=give(b)
		-- A safe visitor deliberately occupies A's spawn; B must not be moved.
		move(b,base(a):FindFirstChild("PlayerSpawn",true).Position)
		b.Character.HumanoidRootPart.Anchored=true visitorFrame=b.Character:GetPivot()
	end
	local cutoff=cycle()
	check(not C.get(a) and not R.getRecord(tokenA),"Inside GUID permanently removed")
	check(not a.Character:FindFirstChild("CarriedResource"),"Inside attachment removed")
	check(a:GetAttribute("CarrySlowdown")==0 and a:GetAttribute("CarryCurse")=="","Inside debuff cleared")
	local spawn=base(a):FindFirstChild("PlayerSpawn",true)
	check((Vector3.new(a.Character.HumanoidRootPart.Position.X,0,a.Character.HumanoidRootPart.Position.Z)-Vector3.new(spawn.Position.X,0,spawn.Position.Z)).Magnitude<(if b then 24 else 5),"Own assigned base evacuation")
	check(not C.forceDrop(a,a.Character,"Replay") and not C.consumeOwned(a,tokenA),"Forfeit cannot be dropped or consumed")
	check(not Spawn.pickup(a,tokenA),"Forfeit cannot be recovered")
	if b then
		check(C.get(b) and C.get(b).token==tokenB and R.owned(b,tokenB),"Independent safe player retains GUID")
		check(base(a)~=base(b),"Distinct multiplayer bases")
		check((a.Character.HumanoidRootPart.Position-b.Character.HumanoidRootPart.Position).Magnitude>=6,"Crowded own spawn uses separated position")
		check((b.Character:GetPivot().Position-visitorFrame.Position).Magnitude<.1,"Safe visitor is not evacuated")
		b.Character.HumanoidRootPart.Anchored=false safe(b)
	end
	for _,gate in gates:GetChildren() do check(gate.CanCollide and gate:GetAttribute("Closed"),"Gate closed "..gate.Name) end
	for _,area in {"Grasslands","Swamp","Jungle","CrystalCave","Volcano"} do
		check(G.getSnapshot(area).State=="SLEEPING","Guardian reset "..area)
		inside(a,area)
		check(waitFor(function() return a.Character.HumanoidRootPart.Position.X<workspace.GeneratedGameplay.SafeZoneBoundary.Position.X end,1),"Closed entry rejected "..area)
	end
	check(field.Phase=="Reset" and workspace:GetServerTimeNow()<cutoff+10,"No early reopen")
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	check(workspace:GetServerTimeNow()>=cutoff+10,"Full ten-second window")
	for _,gate in gates:GetChildren() do check(not gate.CanCollide and not gate:GetAttribute("Closed"),"Gate reopened "..gate.Name) end
	local count=0 for _,r in field.Records do if r.State=="AVAILABLE" then count+=1 end end
	check(count==25,"Exactly 25 fresh resource slots")
	check(#Spawn.validate()==0,"No duplicate, orphan or node ownership errors")
	-- Real feed of the safely retained GUID, after reopening.
	local recipient=b or a local safeToken=tokenB
	if not b then
		safeToken=give(a) safe(a) cycle()
		check(C.get(a) and C.get(a).token==safeToken,"Solo safe-side carry survives reset")
		assert(waitFor(function() return field.Phase=="Normal" end,12))
	end
	local point=base(recipient):FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	move(recipient,host.Position)
	local data=D.get(recipient) local pet=data.Monsters[data.EquippedMonster] local growth=pet.TotalGrowth local flesh=pet.Flesh
	local preview=Feed.preview(recipient,base(recipient),host)
	check(preview.Available,"Retained carry has valid preview")
	check(Feed.confirm(recipient,preview.Ticket),"Retained carry feeds successfully")
	check(not Feed.confirm(recipient,preview.Ticket),"Retained feed cannot replay")
	pet=data.Monsters[data.EquippedMonster]
	check(pet.TotalGrowth==growth+5 and pet.Flesh==flesh+5 and not R.getRecord(safeToken),"Configured effects exactly once")
	-- A ragdoll during closure is restored before the assigned-base move.
	local lost=give(a) inside(a,"Jungle")
	Catch.apply(a,a.Character,G.getSnapshot("Jungle").Home,Vector3.xAxis,"Reset fixture")
	cycle()
	check(not R.getRecord(lost) and not Catch.isRecovering(a) and not a:GetAttribute("GuardianRagdoll"),"Ragdoll reset forfeits and clears recovery")
	check(not C.consumeOwned(a,lost) and #Spawn.validate()==0,"Repeated terminal operations remain empty")
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	-- Deterministically put the cutoff between visual detachment and the world drop.
	-- This exercises the authoritative record path when Carry.get is already empty.
	local racing=give(a) inside(a,"Grasslands")
	R.returnToWorld=function(...)
		field.NextResetAt=workspace:GetServerTimeNow()-.001
		R.returnToWorld=originalReturn
		return originalReturn(...)
	end
	check(not C.forceDrop(a,a.Character,"Cutoff race fixture"),"Forfeiture is not reported as a successful drop")
	check(field.Phase=="Reset" and not R.getRecord(racing) and not C.get(a),"Cutoff after detach forfeits authoritative GUID")
	check(a:GetAttribute("DropReason")=="FieldResetForfeit","Drop continuation preserves forfeiture feedback")
	check(#Spawn.validate()==0,"Cutoff race leaves no recoverable duplicate")
	local evacuated=a.Character:GetPivot() local activation=G.getSnapshot("Grasslands").Activation
	for _=1,5 do R.step() end
	check((a.Character:GetPivot().Position-evacuated.Position).Magnitude<.1 and G.getSnapshot("Grasslands").Activation==activation,"Repeated reset reconciliation does not re-evacuate safe player or restart guardians")
	local oldCharacter=a.Character
	a:LoadCharacterAsync()
	check(waitFor(function() return a.Character~=oldCharacter and a.Character:FindFirstChild("HumanoidRootPart") end,8),"Actual respawn during closure")
	inside(a,"Volcano")
	check(waitFor(function() return a.Character.HumanoidRootPart.Position.X<workspace.GeneratedGameplay.SafeZoneBoundary.Position.X end,1),"Respawn cannot bypass closure")
	check(not C.forceDrop(a,oldCharacter,"Stale character") and not C.get(a),"Old character cannot affect new session")
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	-- Safe at cutoff, then across the same plane while closed: the first resource
	-- reconciliation after entry owns the result, not a client crossing timestamp.
	local boundaryToken=give(a) G.resetAll()
	local lane=G.getRunway() local edge=lane.origin+lane.axis*lane.entrance
	a.Character.HumanoidRootPart.Anchored=true
	move(a,edge-lane.axis*.05) cycle()
	check(C.get(a) and C.get(a).token==boundaryToken,"Just-safe server position retains GUID at cutoff")
	move(a,edge+lane.axis*.05) R.step()
	check(not C.get(a) and not R.getRecord(boundaryToken),"Closed-plane crossing forfeits once on authoritative reconciliation")
	a.Character.HumanoidRootPart.Anchored=false
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	-- Deadline reached from inside a real hazard contact callback, not a later timer.
	inside(a,"Grasslands") a.Character.HumanoidRootPart.Anchored=true
	local hazardToken=give(a)
	check(waitFor(function()
		local s=G.getSnapshot("Grasslands")
		if s.State=="WARNING" then return true end
		move(a,s.Position-Vector3.xAxis*30)
	end,10),"Real hazard warning before cutoff race")
	local attack=G.getSnapshot("Grasslands") a.Character:PivotTo(attack.Frame*CFrame.new(0,3,0))
	C.forceDrop=function(player,character,reason,returnToSpawn)
		if reason=="Guardian:Grasslands" then
			field.NextResetAt=workspace:GetServerTimeNow()-.001
			C.forceDrop=originalDrop
		end
		return originalDrop(player,character,reason,returnToSpawn)
	end
	check(waitFor(function() return field.Phase=="Reset" end,4),"Hazard callback reconciles cutoff")
	check(not R.getRecord(hazardToken) and not C.get(a) and not Catch.isRecovering(a),"Hazard cutoff forfeits without post-reset catch")
	for _,model in workspace.GeneratedGameplay.Guardians:GetChildren() do
		check(not model:FindFirstChild("Sweep") and not model:FindFirstChild("Telegraph"),"Canceled hazard cannot recreate indicators")
	end
	a.Character.HumanoidRootPart.Anchored=false
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	-- Same reentrancy boundary for swept body catches, not only active hazards.
	local bodyToken=give(a)
	a.Character.HumanoidRootPart.Anchored=true
	move(a,G.getSnapshot("Grasslands").Home-Vector3.yAxis*4)
	C.forceDrop=function(player,character,reason,returnToSpawn)
		if reason=="GuardianCatch:Grasslands" then
			field.NextResetAt=workspace:GetServerTimeNow()-.001 C.forceDrop=originalDrop
		end
		return originalDrop(player,character,reason,returnToSpawn)
	end
	check(waitFor(function() return field.Phase=="Reset" end,4),"Body-catch callback reconciles cutoff")
	check(not R.getRecord(bodyToken) and not C.get(a) and not Catch.isRecovering(a),"Body cutoff cannot apply post-evacuation knockback")
	check(G.getSnapshot("Grasslands").State=="SLEEPING" and a:GetAttribute("DropReason")=="FieldResetForfeit","Body cutoff preserves reset state and feedback")
	a.Character.HumanoidRootPart.Anchored=false
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	for _,p in players do check(D.isWritable(p) and D.getStatus(p).Backend=="StudioMemory","No production backend") end
	if b then
		local departed=give(b) inside(b,"Swamp") cycle()
		b:Kick("Disposable fast-heist closed-field disconnect")
		check(waitFor(function() return b.Parent==nil end,8),"Actual disconnect during closure")
		check(not R.getRecord(departed) and not C.get(b) and #Spawn.validate()==0,"Departure leaves no carry owner or recoverable forfeit")
	end
end,debug.traceback)
State.step=original R.returnToWorld=originalReturn C.forceDrop=originalDrop
G.resetAll()
if field and deadline then field.NextResetAt=math.max(deadline,workspace:GetServerTimeNow()+15) end
for _,p in players do
	if p.Parent and backups[p] then
		if C.get(p) then C.forceDrop(p,p.Character,"Reset fixture cleanup") end
		local data=D.get(p) for k in data do data[k]=nil end for k,v in backups[p] do data[k]=v end D.publish(p) C.recalculateMovement(p)
		if p.Character then p.Character:PivotTo(frames[p]) end
	end
end
script:SetAttribute("Result",if ok then "PASS" else err)
if script:GetAttribute("Multiplayer") then Test:EndTest({Passed=ok,Checks=checks,Error=if ok then nil else err}) end
if ok then print("[FastHeistReset] PASS "..checks) else warn(err) end
