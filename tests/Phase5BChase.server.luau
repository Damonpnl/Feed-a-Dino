-- Opt-in live-service kinematic runners; actual elapsed time, not human steering.
-- One near/front node per biome, two resources, precision vs progressed carrying.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Carry,Spawn,Resource,Guardian,Catch,Territory=require(S.DataService),require(S.CarryService),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService),require(S.GuardianCatch),require(S.BiomeTerritory)
local PD,State,Resources,Debuff,Chase=require(H.PlayerData),require(H.FieldState),require(H.ResourceDefinitions),require(H.CarryDebuff),require(H.GuardianChase)
local p=game.Players:GetPlayers()[1] local d=Data.get(p) local backup=PD.copy(d) local frame=p.Character:GetPivot()
local oldStep,oldAssign=State.step,Debuff.assign local field,savedReset local rows,checks={},0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.03) until os.clock()>stop return false end
local ok,failure=xpcall(function()
	State.step=function(self,...) field=self return oldStep(self,...) end
	assert(waitFor(function() return field~=nil end,5)) State.step=oldStep
	assert(waitFor(function() return field.Phase=="Normal" end,12)) savedReset=field.NextResetAt field.NextResetAt=workspace:GetServerTimeNow()+1e6
	local safeX=workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
	local specs={{"Grasslands","RawMeat","PrimalCatalyst"},{"Swamp","SmallFish","MutantLeech"},{"Jungle","WildFruit","BeastHeart"},{"CrystalCave","CrystalShard","PrismaticCrystal"},{"Volcano","CharredMeat","DragonScale"}}
	for _,row in specs do for _,slow in {true,false} do for i=2,3 do
		local area,id=row[1],row[i] local def=Resources.get(id) local t=Territory.get(area)
		local wanted=t.Region.Home+Vector3.new(-24,0,32) local pos=t.Candidates[1]
		for _,v in t.Candidates do if (v-wanted).Magnitude<(pos-wanted).Magnitude then pos=v end end
		Guardian.resetAll() Catch.release(p) if Carry.get(p) then Carry.forceDrop(p,p.Character,"Chase fixture") end
		d.Power=math.max(def.PowerRequired,10000) d.SlowMode=slow Data.publish(p) Carry.recalculateMovement(p)
		local node=field.Nodes[area..":Node01"] if node.RecordId then Resource.releaseToken(area,node.RecordId) end
		local r=field:create(node,id,"Phase5BChase") r.Position,r.SpawnPosition=pos,pos Resource.step()
		Debuff.assign=function(rarity) return {Rarity=rarity,Title="Chase fixture",Effects=if i==2 then {} else {{Id="HeavyBurden",Tier="Mild",Extra=.06}}} end
		local root=p.Character.HumanoidRootPart root.Anchored=true p.Character:PivotTo(CFrame.new(pos+Vector3.new(0,3,0))) task.wait(.22)
		check(Spawn.pickup(p,r.InstanceId),"Pickup "..area) Debuff.assign=oldAssign
		local g for _,m in workspace.GeneratedGameplay.Guardians:GetChildren() do if m.PrimaryPart:GetAttribute("AreaId")==area then g=m.PrimaryPart end end
		local began=os.clock() local outcome="Timeout" local minGap,minX,peak=math.huge,math.huge,0 local pursued=false local previous=g.Position
		local speed=p.Character.Humanoid.WalkSpeed
		script:SetAttribute("Progress",area.." "..id.." "..(if slow then "Precision" else "Progressed"))
		local connection=game:GetService("RunService").Heartbeat:Connect(function(dt)
			local state=g:GetAttribute("GuardianState") if state=="PURSUING" then pursued=true end
			if state=="PURSUING" or state=="COOLDOWN" then peak=math.max(peak,Chase.horizontal(previous,g.Position)/math.max(dt,.001)) end previous=g.Position
			minGap=math.min(minGap,Chase.catchGap(g.CFrame,g.Size,root.Position)) minX=math.min(minX,g.Position.X-safeX)
			if Carry.get(p) and not Catch.isRecovering(p) then p.Character:PivotTo(CFrame.new(root.Position-Vector3.xAxis*p.Character.Humanoid.WalkSpeed*dt)) end
		end)
		waitFor(function()
			if not Carry.get(p) then outcome=if tostring(p:GetAttribute("DropReason")):find("GuardianCatch",1,true) then "Caught" else "Hazard" return true end
			if root.Position.X<safeX then outcome="Escaped" return true end return false
		end,170)
		connection:Disconnect()
		check(pursued,"Guardian pursues") check(minX>=0,"Guardian stays outside safety") check(outcome~="Timeout","Bounded outcome")
		table.insert(rows,{Area=area,Resource=id,SlowMode=slow,Power=d.Power,Speed=speed,Outcome=outcome,Seconds=os.clock()-began,MinGap=minGap,GuardianMinFromSafety=minX,GuardianPeak=peak})
		script:SetAttribute("Rows",game:GetService("HttpService"):JSONEncode(rows))
		if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end Resource.releaseToken(area,r.InstanceId)
		Guardian.resetAll() check(#Spawn.validate()==0,"No orphan GUIDs")
	end end end
end,debug.traceback)
State.step,Debuff.assign=oldStep,oldAssign
Guardian.resetAll() if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end
if savedReset then field.NextResetAt=math.max(savedReset,workspace:GetServerTimeNow()+1) end
for k in d do d[k]=nil end for k,v in backup do d[k]=v end Data.publish(p) Carry.recalculateMovement(p)
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5BChase] PASS "..checks) else warn(failure) end
