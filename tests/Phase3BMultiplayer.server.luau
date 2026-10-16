-- Opt-in two-real-client StudioTestService fixture for Phase 3B (args "Phase3BMultiplayer").
-- Two actual Studio clients join; the server script moves their anchored characters, so this
-- exercises live services and replication, not human input. Never mapped into production.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase3BMultiplayer" then return end
local RunService=game:GetService("RunService")
local LogService=game:GetService("LogService")
local Server=game.ServerScriptService:WaitForChild("Server")
local Spawn,Carry,Resource,Data,Guardian=require(Server.SpawnService),require(Server.CarryService),require(Server.ResourceService),require(Server.DataService),require(Server.GuardianService)
local Shared=game.ReplicatedStorage.Shared
local loaded,Resources,Areas,Config,Chase=pcall(function()
	return require(Shared.ResourceDefinitions),require(Shared.AreaDefinitions),require(Shared.GuardianConfig),require(Shared:WaitForChild("GuardianChase",5))
end)
-- A session synced to a non-Phase-3B tree must end the test instead of hanging it.
if not loaded then STS:EndTest({Result="Phase 3B modules missing: "..tostring(Resources),PassedChecks=0}) return end
local checks=0
local notes={}
local function check(v,m) assert(v,m) checks+=1 end
local function now() return workspace:GetServerTimeNow() end
local function waitFor(fn,seconds)
	local limit=os.clock()+seconds repeat if fn() then return true end task.wait(0.03) until os.clock()>limit return fn()
end
local function physical(id)
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then return m end end
end
local function rarityOf(id) local r=Resource.getRecord(id) return r and Resources.get(r.ResourceId).Rarity end
local function threat(id) return Chase.Profiles[rarityOf(id)].Threat end
local function availableList(area)
	local list={}
	for id,r in Resource.getSnapshot().Records do
		if r.AreaId==area and r.State=="AVAILABLE" and physical(id) then table.insert(list,id) end
	end
	table.sort(list,function(x,y) return threat(x)>threat(y) end)
	return list
end
local function snapshot(area) return Guardian.getSnapshot(area) end
local function remaining() return Resource.getSnapshot().NextResetAt-now() end
local roots={}
local function acquire(p,id)
	task.wait(0.17)
	local m=physical(id) if not m then return false end
	roots[p].CFrame=m.PrimaryPart.CFrame+Vector3.new(0,3,0)
	return Spawn.pickup(p,id)
end
local function parallel(a,b)
	local results={} local done=0
	task.spawn(function() results[1]=a() done+=1 end)
	task.spawn(function() results[2]=b() done+=1 end)
	assert(waitFor(function() return done==2 end,5),"Concurrent fixture completion")
	return results
end
-- Moves several anchored roots toward their goals at one speed; onStep may abort.
local function runAll(moves,speed,onStep)
	local state={}
	for p,goal in moves do state[p]={From=roots[p].Position,Goal=goal,Done=0} end
	while true do
		local dt=RunService.Heartbeat:Wait()
		local finished=true
		for p,s in state do
			local distance=(s.Goal-s.From).Magnitude
			s.Done=math.min(distance,s.Done+speed*dt)
			roots[p].CFrame=CFrame.new(if distance>0 then s.From:Lerp(s.Goal,s.Done/distance) else s.Goal)
			if s.Done<distance then finished=false end
		end
		if onStep and onStep() then return false end
		if finished then return true end
	end
end
local function cleanCurse(p)
	return p:GetAttribute("CarryCurse")=="" and p:GetAttribute("CarryCurseTitle")=="" and p:GetAttribute("CarryCurseStart")==0
		and p:GetAttribute("CarrySlowdown")==0 and Carry.getCurse(p)==nil and p.Character.Humanoid.WalkSpeed==16
end

-- Global invariants sampled every frame for the whole fixture.
local entranceX,floorY
local monitor={Overlap={},SafeIntrusion={},FootprintIntrusion={},MinSpacing=math.huge,Attacks={},ResetWakes={}}
local logs={Guardian={},Errors={}}
local connections={}
table.insert(connections,LogService.MessageOut:Connect(function(message,kind)
	if string.find(message,"[GuardianService]",1,true) then table.insert(logs.Guardian,message) end
	if kind==Enum.MessageType.MessageError then table.insert(logs.Errors,message) end
end))
local function startMonitor()
	local ordered=Areas.getOrdered()
	for _,d in workspace.GeneratedGameplay.Guardians:GetDescendants() do
		if d.Name=="Guardian" and d:IsA("BasePart") then
			local area=d:GetAttribute("AreaId")
			monitor.Attacks[area]=0
			table.insert(connections,d:GetAttributeChangedSignal("HazardFrame"):Connect(function()
				local frame=d:GetAttribute("HazardFrame")
				monitor.Attacks[area]+=1
				if frame.Position.X-Chase.footprintHalf(Config.Areas[area])<entranceX-0.05 then
					table.insert(monitor.FootprintIntrusion,area)
				end
			end))
		end
	end
	table.insert(connections,RunService.Heartbeat:Connect(function()
		local field=Resource.getSnapshot()
		for i,x in ordered do
			local s=snapshot(x.Id)
			if s.State~="SLEEPING" and s.Position.X<entranceX+Chase.Timing.EntranceStandoff-0.05 then
				table.insert(monitor.SafeIntrusion,x.Id)
			end
			if field.Phase=="Reset" and s.State~="SLEEPING" then table.insert(monitor.ResetWakes,x.Id) end
			for j=i+1,#ordered do
				local o=snapshot(ordered[j].Id)
				if s.State~="SLEEPING" and o.State~="SLEEPING" then
					monitor.MinSpacing=math.min(monitor.MinSpacing,Chase.horizontal(s.Position,o.Position))
				end
				local activeS=s.State=="WARNING" or s.State=="HAZARD"
				local activeO=o.State=="WARNING" or o.State=="HAZARD"
				if activeS and activeO then
					local gap=Chase.horizontal(s.Frame.Position,o.Frame.Position)
					if gap<Chase.footprintHalf(Config.Areas[x.Id])+Chase.footprintHalf(Config.Areas[ordered[j].Id]) then
						table.insert(monitor.Overlap,("%s/%s %.1f"):format(x.Id,ordered[j].Id,gap))
					end
				end
			end
		end
	end))
end

local a,b
local originalPower={}
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2]) and Resource.getSnapshot()
	end,40),"Two actual Studio clients initialize")
	local ps=game.Players:GetPlayers() a,b=ps[1],ps[2]
	assert(waitFor(function() return a:GetAttribute("AssignedBaseName") and b:GetAttribute("AssignedBaseName") end,5))
	task.wait(1)
	check(a.UserId~=b.UserId,"Distinct player identities")
	for _,p in ps do
		originalPower[p]=Data.get(p).Power Data.get(p).Power=1e12
		roots[p]=p.Character.HumanoidRootPart roots[p].Anchored=true
	end
	Guardian.resetAll()
	local boundary=workspace.GeneratedGameplay:FindFirstChild("SafeZoneBoundary")
	check(boundary~=nil,"Shared safe-zone boundary exists")
	entranceX=boundary.Position.X floorY=boundary.Position.Y-20+3
	startMonitor()
	if remaining()<215 then
		table.insert(notes,"Waited for a fresh field cycle")
		check(waitFor(function() return Resource.getSnapshot().Phase=="Reset" end,remaining()+5),"Reach field reset before scenarios")
		check(waitFor(function() return Resource.getSnapshot().Phase=="Normal" end,15),"Fresh field cycle begins")
	end

	-- 1. Simultaneous thefts from different biomes, independent guardians, shared boundary.
	local jungleId,swampId=availableList("Jungle")[1],availableList("Swamp")[1]
	check(jungleId and swampId,"Jungle and Swamp each have an available resource")
	local beforeJ,beforeS=snapshot("Jungle").Activation,snapshot("Swamp").Activation
	local picked=parallel(function() return acquire(a,jungleId) end,function() return acquire(b,swampId) end)
	check(picked[1] and picked[2],"Simultaneous pickups in two biomes both succeed")
	check(snapshot("Jungle").Activation==beforeJ+1 and snapshot("Swamp").Activation==beforeS+1,"Each biome guardian wakes exactly once")
	check(snapshot("Jungle").TargetUserId==a.UserId and snapshot("Swamp").TargetUserId==b.UserId,"Each guardian targets its own biome's thief")
	for _,area in {"Grasslands","CrystalCave","Volcano"} do check(snapshot(area).State=="SLEEPING",area.." guardian stays asleep") end
	local crossTarget=0
	local escapedEarly=false
	-- Carriers arrive at different times, so each guardian's disengage is recorded on its own frame.
	local disengage={}
	local watch=RunService.Heartbeat:Connect(function()
		for area,p in {Jungle=a,Swamp=b} do
			if not disengage[area] and snapshot(area).State=="RETURNING" then disengage[area]={Safe=roots[p].Position.X<entranceX} end
		end
	end)
	runAll({[a]=Vector3.new(entranceX-14,floorY,-98),[b]=Vector3.new(entranceX-14,floorY,-74)},26,function()
		local j,s=snapshot("Jungle"),snapshot("Swamp")
		if j.TargetUserId==b.UserId or s.TargetUserId==a.UserId then crossTarget+=1 end
		if not Carry.get(a) or not Carry.get(b) then escapedEarly=true return true end
		return false
	end)
	check(not escapedEarly,"Both scripted carriers reach the safe zone still carrying (A drop="..tostring(a:GetAttribute("DropReason"))..", B drop="..tostring(b:GetAttribute("DropReason"))..")")
	check(crossTarget==0,"No guardian ever targeted the other biome's carrier")
	check(waitFor(function() return disengage.Jungle and disengage.Swamp end,8),"Both guardians disengage at the shared boundary")
	watch:Disconnect()
	check(disengage.Jungle.Safe and disengage.Swamp.Safe,"Each guardian disengaged only after its own carrier crossed the boundary")
	check(snapshot("Jungle").TargetUserId==nil and snapshot("Swamp").TargetUserId==nil,"Both targets cleared")
	check(a:GetAttribute("GuardianEscapeTick") and b:GetAttribute("GuardianEscapeTick"),"Both carriers received the escape signal")
	check(Carry.get(a).token==jungleId and Carry.get(b).token==swampId,"Crossing the boundary does not bank or drop either carry")
	runAll({[a]=Vector3.new(entranceX+40,floorY,-98),[b]=Vector3.new(entranceX+40,floorY,-74)},26)
	local reaggro=false
	local limit=os.clock()+3
	while os.clock()<limit do
		for _,area in {"Jungle","Swamp"} do
			local s=snapshot(area)
			if s.TargetUserId~=nil or (s.State~="RETURNING" and s.State~="SLEEPING") then reaggro=true end
		end
		task.wait(0.05)
	end
	check(not reaggro,"Re-entering the runway with escaped carries does not re-aggro either guardian")
	runAll({[a]=Vector3.new(entranceX-14,floorY,-98),[b]=Vector3.new(entranceX-14,floorY,-74)},40)
	check(waitFor(function() return snapshot("Jungle").State=="SLEEPING" and snapshot("Swamp").State=="SLEEPING" end,70),"Both guardians return and sleep")
	check(Chase.horizontal(snapshot("Jungle").Position,snapshot("Jungle").Home)<=2.5 and Chase.horizontal(snapshot("Swamp").Position,snapshot("Swamp").Home)<=2.5,"Both guardians are at their home anchors")

	-- 2. Curse cleanup: banking one carrier never touches the other; drop clears too.
	local curseB=b:GetAttribute("CarryCurse")
	local speedB=b.Character.Humanoid.WalkSpeed
	check(Carry.consumeOwned(a,jungleId),"Carrier A banks")
	check(cleanCurse(a),"Banking clears A's curse, slowdown, and replicated attributes")
	check(b:GetAttribute("CarryCurse")==curseB and Carry.get(b) and math.abs(b.Character.Humanoid.WalkSpeed-speedB)<0.25,"B's carry and curse are unaffected by A banking")
	check(Carry.forceDrop(b,b.Character,"Test"),"Carrier B drops")
	check(cleanCurse(b),"Dropping clears B's curse, slowdown, and replicated attributes")
	-- A dropped item keeps its server-assigned profile even when another player recovers it.
	Guardian.resetAll()
	local cursedId
	for _,area in Areas.getOrdered() do
		for _,id in availableList(area.Id) do
			if threat(id)>=Chase.Profiles.Legendary.Threat and (not cursedId or threat(id)>threat(cursedId)) then cursedId=id end
		end
	end
	if not cursedId then
		cursedId=availableList("Grasslands")[1]
		table.insert(notes,"No Legendary+ resource available; cross-player curse transfer used "..tostring(rarityOf(cursedId)))
	end
	check(acquire(a,cursedId),"A acquires the curse-transfer item ("..tostring(rarityOf(cursedId))..")")
	local curseJson,title=a:GetAttribute("CarryCurse"),a:GetAttribute("CarryCurseTitle")
	if threat(cursedId)>=Chase.Profiles.Legendary.Threat then check(curseJson~="","Legendary+ item has a server-assigned curse") end
	check(Carry.forceDrop(a,a.Character,"Test") and cleanCurse(a),"A drops; A's curse is cleared")
	check(acquire(b,cursedId),"B recovers A's dropped item")
	check(b:GetAttribute("CarryCurse")==curseJson and b:GetAttribute("CarryCurseTitle")==title,"Recovered item keeps its profile across players (no reroll)")
	check(Carry.consumeOwned(b,cursedId) and cleanCurse(b),"B banks; B's curse is cleared")
	check(not Resource.getRecord(cursedId),"Banked item is consumed and cannot be re-acquired")
	check(waitFor(function()
		for _,area in Areas.getOrdered() do local st=snapshot(area.Id).State if st~="SLEEPING" and st~="RETURNING" then return false end end
		return true
	end,10),"No guardian keeps pursuing after both carries ended")
	Guardian.resetAll()

	-- 3. Target switching between two carriers of one biome.
	check(remaining()>110,"Enough field time remains for target switching and stress ("..math.floor(remaining()).."s)")
	local switchArea,first,second
	for _,area in {"CrystalCave","Jungle","Swamp","Volcano","Grasslands"} do
		local list=availableList(area)
		if #list>=2 then switchArea,first,second=area,list[1],list[#list] break end
	end
	check(switchArea,"A biome has two available resources")
	check(acquire(a,first),"A steals first in "..switchArea)
	task.wait(0.05)
	check(acquire(b,second),"B steals second in "..switchArea)
	check(snapshot(switchArea).TargetUserId==a.UserId,"Initial thief is the first target")
	local strongest=if threat(first)>=threat(second) then rarityOf(first) else rarityOf(second)
	check(snapshot(switchArea).Rarity==strongest,"Pursuit profile is the strongest active carry")
	roots[a].CFrame=CFrame.new(entranceX-14,floorY,-86)
	check(waitFor(function() return snapshot(switchArea).TargetUserId==b.UserId end,2),"Guardian switches to B when A reaches the safe zone")
	local st=snapshot(switchArea).State
	check(st~="RETURNING" and st~="SLEEPING","Guardian keeps pursuing the remaining carrier")
	check(waitFor(function() return snapshot(switchArea).Rarity==rarityOf(second) end,1),"Pursuit profile drops to the remaining carrier's rarity ("..tostring(rarityOf(second))..")")
	roots[a].CFrame=CFrame.new(roots[b].Position+Vector3.new(0,0,10))
	local retarget=false
	limit=os.clock()+2
	while os.clock()<limit do if snapshot(switchArea).TargetUserId==a.UserId then retarget=true end task.wait(0.05) end
	check(not retarget,"Escaped A stepping back beside B is never re-targeted")
	roots[a].CFrame=CFrame.new(entranceX-14,floorY,-86)
	if Carry.get(b) then check(Carry.forceDrop(b,b.Character,"Test"),"B drops") end
	check(waitFor(function() local s=snapshot(switchArea).State return s=="RETURNING" or s=="SLEEPING" end,8),"No remaining threat: guardian disengages")
	-- Repeated pickups of the same item: profile kept, versions advance, stale acks rejected.
	local itemCurse=nil
	local versions={}
	for i=1,5 do
		local before=snapshot(switchArea)
		check(acquire(b,second),"Repeated pickup "..i)
		local after=snapshot(switchArea)
		if before.State=="SLEEPING" then
			check(after.Activation==before.Activation+1,"Pickup "..i.." wakes a sleeping guardian once")
		else
			check(after.Activation==before.Activation,"Pickup "..i.." re-engages without a second wake")
		end
		check(after.State~="SLEEPING" and after.State~="RETURNING","Pickup "..i.." re-engages the guardian")
		check(waitFor(function() return snapshot(switchArea).TargetUserId==b.UserId or not Carry.get(b) end,1),"Pickup "..i.." makes B the target")
		itemCurse=itemCurse or b:GetAttribute("CarryCurse")
		check(b:GetAttribute("CarryCurse")==itemCurse,"Pickup "..i.." keeps the item's curse")
		table.insert(versions,Resource.getRecord(second).ClaimVersion)
		if i>1 then check(versions[i]>versions[i-1],"ClaimVersion advances on pickup "..i) end
		check(not Guardian.onPickup(b,second,versions[i]),"Duplicate acknowledgement rejected on pickup "..i)
		if i>1 then check(not Guardian.onPickup(b,second,versions[i-1]),"Stale acknowledgement rejected on pickup "..i) end
		check(Carry.forceDrop(b,b.Character,"Test") or not Carry.get(b),"Drop after pickup "..i)
	end
	check(cleanCurse(b),"Repeated drops leave no curse residue")
	check(Carry.consumeOwned(a,first) and cleanCurse(a),"A banks its escaped carry")
	check(#Spawn.validate()==0,"Repeated pickups preserve uniqueness")
	Guardian.resetAll()

	-- 4. Two guardians converge on neighbouring carriers while drops are re-picked at once.
	local swampItem,jungleItem=availableList("Swamp")[1],availableList("Jungle")[1]
	check(swampItem and jungleItem,"Swamp and Jungle items for the crowding stress")
	picked=parallel(function() return acquire(a,swampItem) end,function() return acquire(b,jungleItem) end)
	check(picked[1] and picked[2],"Stress pickups succeed")
	local stationA=Vector3.new(snapshot("Swamp").Home.X-40,floorY,-96)
	local stationB=stationA+Vector3.new(0,0,20)
	roots[a].CFrame=CFrame.new(stationA) roots[b].CFrame=CFrame.new(stationB)
	local tokens={[a]=swampItem,[b]=jungleItem}
	local curses={[a]=a:GetAttribute("CarryCurse"),[b]=b:GetAttribute("CarryCurse")}
	local stress={Hits=0,Repicks=0,Rejected=0,CurseDrift=0}
	local attacksBefore={Swamp=monitor.Attacks.Swamp,Jungle=monitor.Attacks.Jungle}
	local stressEnd=os.clock()+45
	while os.clock()<stressEnd and remaining()>8 do
		for p,station in {[a]=stationA,[b]=stationB} do
			if not Carry.get(p) then
				if string.find(p:GetAttribute("DropReason") or "","Guardian:",1,true) then stress.Hits+=1 p:SetAttribute("DropReason","") end
				if acquire(p,tokens[p]) then
					stress.Repicks+=1
					if p:GetAttribute("CarryCurse")~=curses[p] then stress.CurseDrift+=1 end
				else
					stress.Rejected+=1
				end
				roots[p].CFrame=CFrame.new(station)
			end
		end
		task.wait(0.05)
	end
	table.insert(notes,("Stress: hits=%d repicks=%d rejected=%d swampAttacks=%d jungleAttacks=%d"):format(
		stress.Hits,stress.Repicks,stress.Rejected,monitor.Attacks.Swamp-attacksBefore.Swamp,monitor.Attacks.Jungle-attacksBefore.Jungle))
	check(monitor.Attacks.Swamp>attacksBefore.Swamp and monitor.Attacks.Jungle>attacksBefore.Jungle,"Both guardians attacked during the stress")
	check(stress.CurseDrift==0,"No curse reroll across repeated hazard drops and recoveries")
	check(stress.Rejected==0,"Every recovery of a dropped item was accepted")
	for p in tokens do
		if Carry.get(p) then check(Carry.consumeOwned(p,tokens[p]) and cleanCurse(p),"Stress carry banked and cleaned") end
	end
	check(#Spawn.validate()==0,"Stress preserves uniqueness")
	Guardian.resetAll()

	-- 5. Pickup a few seconds before the 300-second field reset.
	check(waitFor(function() return remaining()<=4.5 end,remaining()+2),"Approach the field reset")
	local resetId=availableList("Grasslands")[1] or availableList("Swamp")[1]
	check(resetId and acquire(a,resetId),"Pickup moments before the reset")
	local resetArea=Resource.getRecord(resetId).AreaId
	check(snapshot(resetArea).State~="SLEEPING","Guardian wakes before the reset")
	local resetCurse=a:GetAttribute("CarryCurse")
	check(waitFor(function() return Resource.getSnapshot().Phase=="Reset" end,8),"Field reset begins")
	check(waitFor(function()
		for _,area in Areas.getOrdered() do
			local s=snapshot(area.Id)
			if s.State~="SLEEPING" or s.TargetUserId~=nil or Chase.horizontal(s.Position,s.Home)>2.5 then return false end
		end
		return true
	end,1),"Reset puts every guardian to sleep at home with no target")
	check(Carry.get(a) and Carry.get(a).token==resetId and Resource.getRecord(resetId).State=="CARRIED","Reset preserves the carry")
	check(a:GetAttribute("CarryCurse")==resetCurse,"Reset preserves the carried item's curse")
	local any=nil
	for id,r in Resource.getSnapshot().Records do if r.State~="CARRIED" then any=id end end
	check(any==nil,"Reset removed every uncarried record")
	check(not Spawn.pickup(b,resetId),"Pickup requests are rejected during the reset")
	check(waitFor(function() return Resource.getSnapshot().Phase=="Normal" end,15),"Field refills after the reset")
	check(#monitor.ResetWakes==0,"No guardian woke during the reset window")
	local after=availableList("Grasslands")[1]
	local beforeG=snapshot("Grasslands").Activation
	check(after and acquire(b,after),"New-cycle pickup succeeds")
	check(snapshot("Grasslands").Activation==beforeG+1 and snapshot("Grasslands").TargetUserId==b.UserId,"New-cycle pickup wakes the guardian for B only")
	check(Carry.consumeOwned(a,resetId) and cleanCurse(a),"Carry from the previous cycle banks and cleans up")
	check(Carry.forceDrop(b,b.Character,"Test") and cleanCurse(b),"New-cycle carry drops and cleans up")
	check(#Spawn.validate()==0,"Reset race preserves uniqueness")

	-- Whole-run invariants.
	check(#monitor.Overlap==0,"No two guardians ever had overlapping live attacks: "..table.concat(monitor.Overlap,", "))
	check(#monitor.SafeIntrusion==0,"No guardian entered the safe zone: "..table.concat(monitor.SafeIntrusion,", "))
	check(#monitor.FootprintIntrusion==0,"No hazard footprint reached the safe zone: "..table.concat(monitor.FootprintIntrusion,", "))
	check(#logs.Guardian==0,"No guardian failsafe was logged: "..table.concat(logs.Guardian," | "))
	check(#logs.Errors==0,"No server errors: "..table.concat(logs.Errors," | "))
	table.insert(notes,("MinGuardianSpacing=%.1f"):format(monitor.MinSpacing))
end,debug.traceback)
for _,c in connections do c:Disconnect() end
for p,power in originalPower do
	if p.Parent then
		if Carry.get(p) then Carry.forceDrop(p,p.Character,"TestCleanup") end
		if Data.get(p) then Data.get(p).Power=power end
		if roots[p] and roots[p].Parent then roots[p].Anchored=false end
	end
end
Guardian.resetAll()
local result={Result=if ok then "PASS" else failure,PassedChecks=checks,Notes=table.concat(notes,"; "),Mode="Two actual Studio clients; server-scripted movement"}
script:SetAttribute("Result",result.Result) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3BMultiplayer] PASS "..checks.." checks; "..result.Notes) else warn("[Phase3BMultiplayer] "..failure) end
STS:EndTest(result)
