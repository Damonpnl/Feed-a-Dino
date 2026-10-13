-- Opt-in actual single-player Studio service test. Not a multi-client test.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Server=game.ServerScriptService.Server
local Spawn,Carry,Data,Guardian,Resource=require(Server.SpawnService),require(Server.CarryService),require(Server.DataService),require(Server.GuardianService),require(Server.ResourceService)
local Shared=game.ReplicatedStorage.Shared
local Resources,Areas,Config,Geometry,Format=require(Shared.ResourceDefinitions),require(Shared.AreaDefinitions),require(Shared.GuardianConfig),require(Shared.GuardianGeometry),require(Shared.NumberFormat)
local player=game.Players:GetPlayers()[1]
local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return true end task.wait(0.02) until os.clock()>=deadline
	return fn()
end
local function physical(id)
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then return m end end
end
local function available(area)
	for id,r in Resource.getSnapshot().Records do if r.AreaId==area and r.State=="AVAILABLE" then return id,r end end
	error("No available resource: "..area)
end
local function acquire(id)
	local m=assert(physical(id),"Missing model")
	player.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0))
	task.wait(0.17)
	return Spawn.pickup(player,id)
end
local function drop() return Carry.forceDrop(player,player.Character,"Test") end
local originalPower,originalFrame,root,anchored
local ok,failure=xpcall(function()
	assert(waitFor(function() return player and player.Character and Data.get(player) and Resource.getSnapshot() end,10),"Initialization")
	originalPower=Data.get(player).Power originalFrame=player.Character:GetPivot()
	root=player.Character.HumanoidRootPart anchored=root.Anchored root.Anchored=true
	Guardian.resetAll()
	check(#workspace.GeneratedGameplay.Guardians:GetChildren()==5,"Five guardians initialize")
	local id,record=available("Jungle") local def=Resources.get(record.ResourceId)
	Data.get(player).Power=def.PowerRequired-1
	check(not acquire(id),"Power minus one rejected")
	check(player:GetAttribute("PowerNotice")==Format.needPower(def.PowerRequired),"Authoritative compact requirement")
	local notice=player:GetAttribute("PowerNoticeTick")
	for _=1,20 do Spawn.pickup(player,id) end
	check(Resource.getRecord(id).State=="AVAILABLE" and Guardian.getSnapshot("Jungle").Disturbance==0,"Failed spam does not mutate resource or guardian")
	check(player:GetAttribute("PowerNoticeTick")==notice,"Failure notifications rate limited")
	script:SetAttribute("Progress","PowerNotice") player:SetAttribute("Phase3UIStage","PowerNotice") task.wait(0.5)
	Data.get(player).Power=def.PowerRequired
	check(acquire(id),"Exact Power succeeds")
	local visual=player.Character:FindFirstChild("CarriedResource")
	check(visual and visual:GetAttribute("ResourceInstanceId")==id and not physical(id),"One attached visual and same GUID")
	check(visual.PrimaryPart:FindFirstChildOfClass("WeldConstraint") and not visual.PrimaryPart.Anchored,"Visual welded and unanchored")
	check(math.abs(player.Character.Humanoid.WalkSpeed-16*(1-def.CarrySlowdown))<0.001,"Configured carry speed")
	check(player:GetAttribute("CarriedRarity")==def.Rarity and player:GetAttribute("CarriedInstanceId")==id,"Carry HUD attributes")
	player:SetAttribute("Phase3UIStage","Carrying") task.wait(0.5)
	check(not Guardian.onPickup(player,id,Resource.getRecord(id).ClaimVersion),"Repeated acquisition event rejected")
	check(not Guardian.onPickup(player,id,0),"Stale acquisition version rejected")
	check(not Carry.give(player,"InfernoCatalyst","Volcano","forged"),"Forged record rejected")
	local id2=available("Grasslands")
	check(not acquire(id2),"Second major resource rejected")
	check(drop() and not drop(),"Repeated force drop is idempotent")
	check(Resource.getRecord(id).State=="DROPPED" and physical(id),"Dropped resource keeps identity")
	check(player.Character.Humanoid.WalkSpeed==16 and not player.Character:FindFirstChild("CarriedResource"),"Drop restores speed and clears visual")
	player:SetAttribute("Phase3UIStage","Empty") task.wait(0.3)
	Guardian.resetAll()
	Data.get(player).Power=1e12
	for _,area in Areas.getOrdered() do
		local c=Config.Areas[area.Id]
		local token=available(area.Id)
		script:SetAttribute("Progress",area.Id.." hazard")
		local activation=Guardian.getSnapshot(area.Id).Activation
		-- Valid acquisitions of the same recoverable GUID accumulate independently.
		for _=1,15 do
			check(acquire(token),area.Id.." acquisition")
			if Guardian.getSnapshot(area.Id).State=="WARNING" then break end
			check(drop(),"Build disturbance via real drop/recovery")
		end
		local warning=Guardian.getSnapshot(area.Id)
		check(warning.State=="WARNING" and warning.Activation==activation+1,area.Id.." one awakening")
		check(warning.Deadline-workspace:GetServerTimeNow()<=c.Warning+0.05 and warning.Deadline-workspace:GetServerTimeNow()>c.Warning-0.2,"Warning duration")
		local model=workspace.GeneratedGameplay.Guardians:FindFirstChild(area.Guardian)
		local frame,size=Geometry.visual(c,warning.Frame,1,true)
		check(model.Telegraph.Size==size and (model.Telegraph.Position-frame.Position).Magnitude<0.001,"Telegraph matches authoritative geometry")
		root.CFrame=warning.Frame*CFrame.new(0,3,0)
		local health=player.Character.Humanoid.Health
		check(waitFor(function() return not Carry.get(player) end,c.Warning+c.Active+2),area.Id.." hit forces drop")
		check(Resource.getRecord(token).State=="DROPPED" and physical(token),"Hit preserves recoverable GUID")
		check(player.Character.Humanoid.Health==health and health>0,"Hazard causes no damage")
		check(player.Character.Humanoid.WalkSpeed==16 and player:GetAttribute("CarriedName")=="","Hazard clears speed/HUD")
		check(not drop(),"Duplicate contact/drop produces no resource")
		-- Reclaim during the SAME active window: this player must not be processed twice.
		check(acquire(token),"Recovery during hazard")
		root.CFrame=warning.Frame*CFrame.new(0,3,0)
		check(waitFor(function() return Guardian.getSnapshot(area.Id).State=="COOLDOWN" end,3),"Hazard reaches cooldown")
		check(Carry.get(player) and Carry.get(player).token==token,"Hit set prevents duplicate consequence after recovery")
		check(waitFor(function() return Guardian.getSnapshot(area.Id).State=="SLEEPING" end,c.Cooldown+1),"Returns to sleeping")
		check(Guardian.getSnapshot(area.Id).Disturbance==0,"Post-attack baseline restored")
		check(#Spawn.validate()==0,"No duplicate/orphan records")
		drop()
	end
	-- A real outside-footprint carrier retains the item through a full attack.
	Guardian.resetAll()
	local token=available("Grasslands")
	for _=1,15 do assert(acquire(token)) if Guardian.getSnapshot("Grasslands").State=="WARNING" then break end drop() end
	local warning=Guardian.getSnapshot("Grasslands")
	root.CFrame=warning.Frame*CFrame.new(0,3,35)
	check(waitFor(function() return Guardian.getSnapshot("Grasslands").State=="COOLDOWN" end,4),"Outside test attack completes")
	check(Carry.get(player) and Carry.get(player).token==token,"Outside carrier keeps resource")
	Guardian.resetAll()
	-- Character reset resolves the old session; explicitly replay its stale callback.
	local oldCharacter=player.Character
	root.Anchored=false
	player:LoadCharacterAsync()
	check(waitFor(function() return not Carry.get(player) and player.Character~=oldCharacter end,5),"Character reset clears old carry")
	check(Resource.getRecord(token) and Resource.getRecord(token).State=="DROPPED","Reset follows drop policy")
	root=player.Character:WaitForChild("HumanoidRootPart") root.Anchored=true
	check(acquire(token),"New character recovers drop")
	check(not Carry.forceDrop(player,oldCharacter,"StaleDeath"),"Old character callback cannot affect new session")
	check(Carry.get(player) and Carry.get(player).token==token,"New carry intact after stale callback")
	check(Carry.consumeOwned(player,token) and not Carry.consumeOwned(player,token),"Authorized consumption exactly once")
	check(Resource.getRecord(token)==nil and #Spawn.validate()==0,"Consumption leaves no orphan")
end,debug.traceback)
if player then
	if Carry.get(player) then drop() end
	if Data.get(player) and originalPower then Data.get(player).Power=originalPower Data.publish(player) end
	if player.Character and originalFrame then player.Character:PivotTo(originalFrame) end
	if root and root.Parent then root.Anchored=anchored or false end
	player:SetAttribute("Phase3UIStage","Done")
end
Guardian.resetAll()
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3Integration] PASS "..checks.." checks (single player)") else warn("[Phase3Integration] "..failure) end
