-- Opt-in disposable StudioMemory integration. Seeds records, never production saves.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Carry,Catch,Spawn,Resource,Guardian,Training=require(S.DataService),require(S.CarryService),require(S.GuardianCatch),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService),require(S.TrainingService)
local PD,M,C,State,Debuff=require(H.PlayerData),require(H.MovementCalculator),require(H.MovementConfig),require(H.FieldState),require(H.CarryDebuff)
local p=game.Players:GetPlayers()[1] local d=Data.get(p) local backup=PD.copy(d)
local frame=p.Character:GetPivot() local oldStep,oldAssign,oldStatus=State.step,Debuff.assign,Data.getStatus
local field,checks=nil,0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,seconds) local limit=os.clock()+seconds repeat if fn() then return true end task.wait(.03) until os.clock()>limit return false end
local function speed() return p.Character.Humanoid.WalkSpeed end
local function refresh() Data.publish(p) Carry.recalculateMovement(p) end
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Isolated writable session")
	Training.stop(p) d.SlowMode=false d.Power=0 refresh()
	check(speed()==22,"Fresh speed 22")
	for _,row in C.Milestones do
		d.Power=row.Power Data.publish(p)
		check(waitFor(function() return speed()==row.Speed end,1),"Published Power updates speed "..row.Power)
	end
	check(Carry.setSlowMode(p,true) and speed()==16 and d.Power==150e6,"Slow Mode preserves Power")
	task.wait(.22) check(Carry.setSlowMode(p,false) and speed()==72,"Disable restores derived speed")
	for _,v in {32,"true",{},p} do check(not Carry.setSlowMode(p,v) and not d.SlowMode,"Forged mode rejected") end
	task.wait(.22) Data.getStatus=function(who) return if who==p then {Status="Conflict",CanSave=false} else oldStatus(who) end
	check(not Carry.setSlowMode(p,true) and not d.SlowMode,"Read-only session cannot persist preference") Data.getStatus=oldStatus
	p:SetAttribute("Power",0) Carry.recalculateMovement(p)
	check(speed()==72 and d.Power==150e6,"Replicated display is not movement authority") refresh()
	p.Character.Humanoid.WalkSpeed=100
	check(waitFor(function() return speed()==72 end,1),"Only movement authority controls server WalkSpeed")
	State.step=function(self,...) field=self return oldStep(self,...) end
	check(waitFor(function() return field~=nil end,5),"Capture existing field") State.step=oldStep
	check(waitFor(function() return field.Phase=="Normal" end,12),"Outside reset")
	local function acquire(assignment)
		Guardian.resetAll() task.wait(.22)
		local node=field.Nodes["Grasslands:Node01"] if node.RecordId then Resource.releaseToken("Grasslands",node.RecordId) end
		local r=field:create(node,"PrimalCatalyst","Phase5BFixture") Resource.step()
		Debuff.assign=function() return assignment end
		for _,model in workspace.GeneratedGameplay.Resources:GetChildren() do if model:GetAttribute("ResourceInstanceId")==r.InstanceId then p.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0)) end end
		check(Spawn.pickup(p,r.InstanceId),"Real GUID pickup") Debuff.assign=oldAssign
		p.Character:PivotTo(frame) return r.InstanceId
	end
	p.Character.HumanoidRootPart.Anchored=true
	local id=acquire({Rarity="Legendary",Title="Fixture",Effects={{Id="HeavyBurden",Tier="Mild",Extra=.06}}})
	check(math.abs(speed()-52*.84)<.001,"Carry curve before additive item and curse penalty")
	task.wait(.22) check(Carry.setSlowMode(p,true) and math.abs(speed()-16*.84)<.001,"Slow Mode cannot remove penalties")
	check(Carry.get(p).token==id,"Toggle retains GUID")
	task.wait(.22) Carry.setSlowMode(p,false)
	check(Carry.forceDrop(p,p.Character,"Test") and speed()==72,"Drop restores Power base")
	check(Resource.getRecord(id).State=="DROPPED" and #Spawn.validate()==0,"Drop identity preserved") Resource.releaseToken("Grasslands",id)
	id=acquire({Rarity="Legendary",Title="Fixture",Effects={{Id="ShiftingWeight",Tier="Mild",Extra=.08,Normal=.4,Active=.4,Warning=.1}}})
	check(waitFor(function() return math.abs(speed()-52*.82)<.001 end,1),"Timed slowdown activates")
	check(waitFor(function() return math.abs(speed()-52*.9)<.001 end,1),"Timed slowdown expires")
	check(Carry.consumeOwned(p,id) and speed()==72 and not Resource.getRecord(id),"Consumption restores speed once")
	p.Character.HumanoidRootPart.Anchored=false
	check(Catch.apply(p,p.Character,p.Character:GetPivot().Position-Vector3.xAxis*10,Vector3.xAxis,"Phase5BFixture"),"Catch applies")
	check(waitFor(function() return speed()==0 end,.5),"Ragdoll suppresses locomotion")
	task.wait(.22) Carry.setSlowMode(p,true)
	check(speed()==0 and Catch.isRecovering(p),"Toggle cannot escape ragdoll")
	check(waitFor(function() return speed()==16 end,2),"Stand-up restores precision speed")
	check(Catch.isRecovering(p),"Remaining pickup recovery is preserved after stand-up")
	check(waitFor(function() return not Catch.isRecovering(p) end,2),"Recovery finishes")
	d.Power=1000 refresh() local oldCharacter=p.Character p:LoadCharacterAsync()
	check(waitFor(function() return p.Character~=oldCharacter and p.Character:FindFirstChildOfClass("Humanoid") and speed()==16 end,8),"Respawn restores saved Slow Mode")
	task.wait(.22) Carry.setSlowMode(p,false) check(speed()==26,"Respawn restores Power when mode disabled")
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")] local station=base:FindFirstChild("TrainingStation",true)
	p.Character.HumanoidRootPart.Anchored=true p.Character:PivotTo(station.CFrame+Vector3.new(0,3,0))
	d.Power=999 refresh() check(Training.train(p,base,station),"Start real training below milestone")
	check(waitFor(function() return d.Power>=1000 and speed()==26 end,2),"Training crosses milestone immediately")
	p.Character:PivotTo(station.CFrame+Vector3.new(50,3,0)) task.wait(.1) local power=d.Power task.wait(1.1)
	check(d.Power==power and not p:GetAttribute("TrainingActive"),"Leaving stops Power gains")
	task.wait(.22) Carry.setSlowMode(p,true) local cash,tier=d.Cash,d.TrainerTier
	check(Data.release(p),"Memory session release") Data.load(p) d=Data.get(p)
	check(d.SlowMode and d.Power==power and d.Cash==cash and d.TrainerTier==tier,"Rejoin restores all four fields")
	check(waitFor(function() return speed()==16 end,1),"Reload immediately restores movement")
	check(#Spawn.validate()==0,"No resource ownership regressions")
end,debug.traceback)
State.step,Debuff.assign,Data.getStatus=oldStep,oldAssign,oldStatus
Training.stop(p) Catch.release(p) if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end
d=Data.get(p) for k in d do d[k]=nil end for k,v in backup do d[k]=v end refresh()
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5BIntegration] PASS "..checks) else warn(failure) end
