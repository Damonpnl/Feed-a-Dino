-- Opt-in single-player Studio service test for Phase 3B full-runway pursuit and carry curses.
-- Moves the anchored test character along the real runway; it exercises live services, not
-- human input. Restores Power and position; consumes at most one resource.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local RunService=game:GetService("RunService")
local LogService=game:GetService("LogService")
local Server=game.ServerScriptService.Server
local Spawn,Carry,Data,Guardian,Resource=require(Server.SpawnService),require(Server.CarryService),require(Server.DataService),require(Server.GuardianService),require(Server.ResourceService)
local Shared=game.ReplicatedStorage.Shared
local Resources,Areas,Config,Chase,Debuff=require(Shared.ResourceDefinitions),require(Shared.AreaDefinitions),require(Shared.GuardianConfig),require(Shared.GuardianChase),require(Shared.CarryDebuff)
local player=game.Players:GetPlayers()[1]
local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return true end task.wait(0.03) until os.clock()>=deadline
	return fn()
end
local function physical(id)
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then return m end end
end
local function available(area, predicate)
	local best,bestRow
	for id,r in Resource.getSnapshot().Records do
		if r.AreaId==area and r.State=="AVAILABLE" and physical(id) and (not predicate or predicate(r)) then
			if not bestRow or Resources.get(r.ResourceId).CarrySlowdown>Resources.get(bestRow.ResourceId).CarrySlowdown then best,bestRow=id,r end
		end
	end
	return best,bestRow
end
local root,anchored,originalPower,originalFrame
local function acquire(id)
	local m=assert(physical(id),"Missing model")
	root.CFrame=m.PrimaryPart.CFrame+Vector3.new(0,3,0)
	task.wait(0.17)
	return Spawn.pickup(player,id)
end
local function snapshot(area) return Guardian.getSnapshot(area) end
local entranceX
local monitor={MinX=math.huge,States={},Frames={}}
local function watch(area)
	monitor={MinX=math.huge,States={},Frames={},Area=area}
	local part
	for _,d in workspace.GeneratedGameplay.Guardians:GetDescendants() do if d.Name=="Guardian" and d:GetAttribute("AreaId")==area then part=d end end
	local c1=RunService.Heartbeat:Connect(function()
		monitor.MinX=math.min(monitor.MinX,part.Position.X)
		monitor.States[part:GetAttribute("GuardianState")]=true
	end)
	local c2=part:GetAttributeChangedSignal("HazardFrame"):Connect(function() table.insert(monitor.Frames,part:GetAttribute("HazardFrame")) end)
	return function() c1:Disconnect() c2:Disconnect() end
end
local function run(to, speed, onStep)
	local from=root.Position
	local goal=Vector3.new(to.X,from.Y,to.Z)
	local distance=(goal-from).Magnitude
	local travelled=0
	while travelled<distance do
		local dt=RunService.Heartbeat:Wait()
		travelled=math.min(distance,travelled+speed*dt)
		root.CFrame=CFrame.new(from:Lerp(goal,travelled/distance))
		if onStep and onStep() then return false end
	end
	return true
end
local failsafes={}
local logConnection=LogService.MessageOut:Connect(function(message)
	if string.find(message,"[GuardianService]",1,true) then table.insert(failsafes,message) end
end)
local ok,failure=xpcall(function()
	assert(waitFor(function() return player and player.Character and Data.get(player) and Resource.getSnapshot() end,10),"Initialization")
	originalPower=Data.get(player).Power originalFrame=player.Character:GetPivot()
	root=player.Character.HumanoidRootPart anchored=root.Anchored root.Anchored=true
	Data.get(player).Power=1e12
	Guardian.resetAll()
	local boundary=workspace.GeneratedGameplay:FindFirstChild("SafeZoneBoundary")
	check(boundary and not boundary.CanCollide and not boundary.CanTouch and not boundary.CanQuery,"Non-collidable runtime safe boundary exists")
	entranceX=boundary.Position.X
	check(math.abs(entranceX-283.07)<0.5,"Boundary aligned with the verified base entrance")
	local floorY=boundary.Position.Y-20+3

	-- A. Jungle pursuit across Swamp and Grasslands, boundary disengage, re-entry, return home.
	local home=snapshot("Jungle").Home
	local id=available("Jungle")
	local stop=watch("Jungle")
	check(acquire(id),"Jungle acquisition")
	check(snapshot("Jungle").State~="SLEEPING" and snapshot("Jungle").TargetUserId==player.UserId,"Owner biome guardian wakes and targets thief")
	for _,area in Areas.getOrdered() do
		if area.Id~="Jungle" then check(snapshot(area.Id).State=="SLEEPING",area.Id.." guardian stays independent") end
	end
	local stoppedEarly=false
	run(Vector3.new(300,floorY,-86),26,function()
		local s=snapshot("Jungle")
		if s.State=="RETURNING" or s.State=="SLEEPING" then stoppedEarly=true return true end
		return not Carry.get(player)
	end)
	check(not stoppedEarly and Carry.get(player),"Pursuit continues across biome boundaries with no timer stop")
	check(waitFor(function() return snapshot("Jungle").Position.X<633 end,40),"Guardian pursues beyond its biome into Grasslands")
	check(snapshot("Jungle").TargetUserId==player.UserId,"Target retained through biome transitions")
	run(Vector3.new(entranceX-14,floorY,-86),26)
	check(waitFor(function() return snapshot("Jungle").State=="RETURNING" end,8),"Crossing the safe entrance disengages the guardian")
	check(snapshot("Jungle").TargetUserId==nil and player:GetAttribute("GuardianEscapeTick"),"Target cleared and escape signalled")
	check(Carry.get(player) and Carry.get(player).token==id,"Escape does not bank or drop the carry")
	run(Vector3.new(entranceX+40,floorY,-86),26)
	task.wait(3)
	local s=snapshot("Jungle")
	check((s.State=="RETURNING" or s.State=="SLEEPING") and s.TargetUserId==nil,"Re-entry with the escaped carry does not re-aggro")
	run(Vector3.new(entranceX-14,floorY,-86),40)
	check(waitFor(function() return snapshot("Jungle").State=="SLEEPING" end,70),"Guardian returns and sleeps")
	check(Chase.horizontal(snapshot("Jungle").Position,home)<=2.5,"Guardian is at its home anchor")
	check(#failsafes==0,"No failsafe teleport or stuck disengage was logged: "..table.concat(failsafes," | "))
	check(monitor.MinX>=entranceX+Chase.Timing.EntranceStandoff-0.05,"Guardian never entered the safe zone")
	for _,frame in monitor.Frames do
		check(frame.Position.X-Chase.footprintHalf(Config.Areas.Jungle)>=entranceX-0.05,"Jungle footprint stayed outside the safe zone")
	end
	stop()

	-- B. Banking path: consumption clears every carry and curse modifier.
	check(Carry.consumeOwned(player,id),"Authorized consume of the escaped carry")
	check(player.Character.Humanoid.WalkSpeed==16 and player:GetAttribute("CarryCurse")=="" and player:GetAttribute("CarrySlowdown")==0,"Banking restores movement and clears curse")

	-- C. Mid-attack escape near the entrance: footprint excluded from the safe zone.
	Guardian.resetAll()
	local gid=available("Grasslands")
	stop=watch("Grasslands")
	check(acquire(gid),"Grasslands acquisition")
	run(Vector3.new(entranceX+17,floorY,-86),26)
	local tick=player:GetAttribute("HazardTick")
	check(waitFor(function() return snapshot("Grasslands").State=="WARNING" end,40),"Guardian telegraphs near the entrance")
	local frame=snapshot("Grasslands").Frame
	check(frame.Position.X-Chase.footprintHalf(Config.Areas.Grasslands)>=entranceX-0.05,"Telegraph footprint ends before the safe zone")
	root.CFrame=CFrame.new(entranceX-12,floorY,-86)
	check(waitFor(function() local st=snapshot("Grasslands").State return st=="RETURNING" or st=="SLEEPING" end,12),"Guardian disengages after mid-attack escape")
	check(Carry.get(player) and player:GetAttribute("HazardTick")==tick,"No hazard consequence inside the safe zone")
	check(monitor.MinX>=entranceX+Chase.Timing.EntranceStandoff-0.05,"Grasslands guardian never entered the safe zone")
	stop()
	check(Carry.forceDrop(player,player.Character,"Test"),"Drop the Grasslands carry")
	check(player.Character.Humanoid.WalkSpeed==16 and player:GetAttribute("CarryCurse")=="","Drop restores movement and clears curse")

	-- D. Curse persistence: re-pickup of a dropped item cannot reroll.
	Guardian.resetAll()
	local cursed,area
	for _,a in Areas.getOrdered() do
		local candidate=available(a.Id,function(r)
			local rarity=Resources.get(r.ResourceId).Rarity
			return rarity~="Common" and rarity~="Uncommon" and rarity~="Rare" and rarity~="Epic"
		end)
		if candidate then cursed,area=candidate,a.Id end
	end
	check(cursed~=nil,"Found a Legendary+ resource for curse checks")
	check(acquire(cursed),"Cursed acquisition")
	local first=player:GetAttribute("CarryCurse")
	local assignment,started=Carry.getCurse(player)
	check(first~="" and assignment and #assignment.Effects>=1 and started,"Server assigned and replicated a curse")
	check(player:GetAttribute("CarryCurseTitle")==assignment.Title,"Title replicated")
	check(math.abs(player.Character.Humanoid.WalkSpeed-16*(1-player:GetAttribute("CarrySlowdown")))<0.001,"Carry speed matches replicated slowdown")
	check(player:GetAttribute("CarrySlowdown")<=Debuff.MaxTotal+1e-6,"Slowdown cap respected")
	check(Carry.forceDrop(player,player.Character,"Test"),"Drop cursed carry")
	check(player:GetAttribute("CarryCurse")=="" and player.Character.Humanoid.WalkSpeed==16,"Dropped carry clears the curse")
	task.wait(0.2)
	check(acquire(cursed),"Recover the dropped item")
	check(player:GetAttribute("CarryCurse")==first,"Recovered item keeps its original curse (no reroll)")

	-- E. Death clears every modifier.
	Guardian.resetAll()
	root.Anchored=false
	local humanoid=player.Character.Humanoid
	humanoid.Health=0
	check(waitFor(function() return not Carry.get(player) end,3),"Death drops the carry")
	check(player:GetAttribute("CarryCurse")=="" and player:GetAttribute("CarrySlowdown")==0 and player:GetAttribute("CarryCurseTitle")=="","Death clears curse attributes")
	player:LoadCharacterAsync()
	check(waitFor(function() return player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.WalkSpeed==16 end,5),"Respawn has unmodified movement")
	root=player.Character:WaitForChild("HumanoidRootPart") anchored=false
	print(("[Phase3BRunway] curse area=%s json=%s"):format(area,first))
end,debug.traceback)
logConnection:Disconnect()
if player then
	if Carry.get(player) then Carry.forceDrop(player,player.Character,"TestCleanup") end
	if Data.get(player) and originalPower then Data.get(player).Power=originalPower Data.publish(player) end
	if root and root.Parent then root.Anchored=anchored or false end
	if player.Character and originalFrame then player.Character:PivotTo(originalFrame) end
end
Guardian.resetAll()
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3BRunway] PASS "..checks.." checks (single player, scripted movement)") else warn("[Phase3BRunway] "..failure) end
