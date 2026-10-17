-- Opt-in real two-client StudioTestService fixture. Never mapped into production.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase3Multiplayer" then return end
local Server=game.ServerScriptService:WaitForChild("Server")
local Spawn,Carry,Resource,Data,Guardian=require(Server.SpawnService),require(Server.CarryService),require(Server.ResourceService),require(Server.DataService),require(Server.GuardianService)
local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds)
	local limit=os.clock()+seconds repeat if fn() then return true end task.wait(0.02) until os.clock()>limit return fn()
end
local function physical(id)
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then return m end end
end
local function go(p,id)
	local m=assert(physical(id)) p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0))
end
local function acquire(p,id)
	task.wait(0.17) go(p,id)
	local accepted=Spawn.pickup(p,id)
	if not accepted then
		local r=Resource.getRecord(id) local m=physical(id)
		warn("[Phase3Multiplayer diagnostic] "..game:GetService("HttpService"):JSONEncode({Player=p.Name,State=r and r.State,Owner=r and r.OwnerUserId,Distance=m and (p.Character.HumanoidRootPart.Position-m.PrimaryPart.Position).Magnitude,Health=p.Character.Humanoid.Health,Carry=Carry.get(p),Power=Data.get(p).Power}))
	end
	return accepted
end
local function parallel(a,b)
	local results={} local done=0
	task.spawn(function() results[1]=a() done+=1 end)
	task.spawn(function() results[2]=b() done+=1 end)
	assert(waitFor(function() return done==2 end,5),"Concurrent fixture completion")
	return results
end
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2]) and Spawn.getSnapshot()
	end,40),"Two actual Studio clients initialize")
	local ps=game.Players:GetPlayers() local a,b=ps[1],ps[2]
	-- BaseService performs a deferred spawn placement after data initialization.
	assert(waitFor(function() return a:GetAttribute("AssignedBaseName") and b:GetAttribute("AssignedBaseName") end,5))
	task.wait(1)
	check(a.UserId~=b.UserId,"Distinct player identities")
	for _,p in ps do Data.get(p).Power=1e12 p.Character.HumanoidRootPart.Anchored=true end
	Guardian.resetAll()
	local tokens={}
	for id,r in Spawn.getSnapshot().Records do if r.AreaId=="Grasslands" and r.State=="AVAILABLE" then table.insert(tokens,id) end end
	local first,second=tokens[1],tokens[2]
	go(a,first) go(b,first)
	local result=parallel(function() return Spawn.pickup(a,first) end,function() return Spawn.pickup(b,first) end)
	check((result[1] and not result[2]) or (result[2] and not result[1]),"Exactly one same-resource winner")
	local winner,loser=if result[1] then a else b,if result[1] then b else a
	check(Carry.get(winner) and not Carry.get(loser),"Loser cannot carry occupied record")
	check(Carry.forceDrop(winner,winner.Character,"Test"),"Winner drops")
	check(acquire(loser,first),"Other actual client recovers original GUID")
	check(Resource.getRecord(first).OwnerUserId==loser.UserId,"Recovery assigns new authoritative owner")
	Carry.forceDrop(loser,loser.Character,"Test") Guardian.resetAll()
	task.wait(0.17) go(a,first) go(b,second)
	local before=Guardian.getSnapshot("Grasslands").Activation
	result=parallel(function() return Spawn.pickup(a,first) end,function() return Spawn.pickup(b,second) end)
	check(result[1] and result[2],"Two different simultaneous pickups succeed")
	check(Guardian.getSnapshot("Grasslands").State~="SLEEPING","Shared guardian wakes for the biome")
	check(Guardian.getSnapshot("Grasslands").Disturbance==0,"No disturbance meter is required")
	check(#workspace.GeneratedGameplay.Guardians:GetChildren()==5,"One guardian model per biome")
	check(not Spawn.pickup(a,"fabricated-guid"),"Fabricated identity rejected")
	check(not Guardian.onPickup(a,first,Resource.getRecord(first).ClaimVersion),"Duplicate wake rejected")
	check(waitFor(function()
		local state=Guardian.getSnapshot("Grasslands").State
		return state=="WARNING" or state=="HAZARD"
	end,35),"One shared pursuit reaches an attack")
	local warning=Guardian.getSnapshot("Grasslands")
	check(warning.Activation==before+1,"One wake across both carriers")
	local hpA,hpB=a.Character.Humanoid.Health,b.Character.Humanoid.Health
	-- Front starts at negative local X, so contacts occur early in the window.
	a.Character.HumanoidRootPart.CFrame=warning.Frame*CFrame.new(-40,3,0)
	b.Character.HumanoidRootPart.CFrame=warning.Frame*CFrame.new(-40,3,2)
	check(waitFor(function() return not Carry.get(a) and not Carry.get(b) end,4),"Guardian drops both real carriers")
	check(a.Character.Humanoid.Health==hpA and b.Character.Humanoid.Health==hpB,"Both players survive")
	check(Resource.getRecord(first).State=="DROPPED" and Resource.getRecord(second).State=="DROPPED","Both same-GUID drops exist")
	local Catch=require(Server.GuardianCatch)
	-- A body catch during pursuit can drop B before the attack, so its recovery may already be over.
	check(b:GetAttribute("GuardianCaughtTick")~=nil,"Hit carrier received guardian knockback")
	check(not Catch.isRecovering(b) or not Spawn.pickup(b,first),"Hit carrier cannot re-pick during recovery")
	check(waitFor(function() return not Catch.isRecovering(b) end,3),"Hit carrier recovers")
	check(acquire(b,first),"Cross-player recovery after the guardian hit")
	local during=Guardian.getSnapshot("Grasslands").State
	check(during=="HAZARD" or during=="COOLDOWN" or during=="PURSUING","Lifecycle continues after a shared hit")
	local old=a.Character
	a.Character.HumanoidRootPart.Anchored=false
	task.spawn(function() a:LoadCharacterAsync() end)
	b:Kick("Phase 3 multiplayer disconnect fixture")
	check(waitFor(function() return b.Parent==nil and Data.get(b)==nil and not Carry.get(b) end,10),"Disconnect during hazard clears state")
	check(waitFor(function() return a.Character and a.Character~=old and a.Character:FindFirstChild("HumanoidRootPart") end,10),"Reset during hazard creates new character")
	check(not Carry.forceDrop(a,old,"StaleCallback"),"Old character consequence rejected")
	check(not Resource.getRecord(first) or Resource.getRecord(first).State=="DROPPED","Departed player cannot orphan ownership")
	check(#Spawn.validate()==0,"Multiplayer operations preserve uniqueness")
	-- Paired real client sends forged reward/position arguments to the existing drop remote.
	Guardian.resetAll()
	a.Character.HumanoidRootPart.Anchored=true
	check(acquire(a,second),"Remote-spam fixture pickup")
	local power,feeds=Data.get(a).Power,Data.get(a).Stats.Feeds
	a:SetAttribute("Phase3Spam",true)
	check(waitFor(function() return not Carry.get(a) end,5),"Actual client drop requests reach server")
	check(Resource.getRecord(second).State=="DROPPED" and #Spawn.validate()==0,"Client replay spam creates no duplicates")
	check(Data.get(a).Power==power and Data.get(a).Stats.Feeds==feeds,"Forged rewards ignored")
end,debug.traceback)
local result={Result=if ok then "PASS" else failure,PassedChecks=checks,Mode="Two actual Studio clients"}
script:SetAttribute("Result",result.Result) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3Multiplayer] PASS "..checks.." checks") else warn("[Phase3Multiplayer] "..failure) end
STS:EndTest(result)
