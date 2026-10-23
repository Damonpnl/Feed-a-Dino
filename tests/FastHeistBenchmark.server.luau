-- Opt-in matched A/B/C fixture. Real elapsed server time, anchored scripted runners,
-- NOT human/physics feel. Run against each source revision before changing the next.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Carry,Spawn,R,G,C,T=require(S.DataService),require(S.CarryService),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService),require(S.GuardianCatch),require(S.BiomeTerritory)
local State,PD,Defs,Chase=require(H.FieldState),require(H.PlayerData),require(H.ResourceDefinitions),require(H.GuardianChase)
local p=game.Players:GetPlayers()[1]
local d=Data.get(p) local backup=PD.copy(d) local origin=p.Character:GetPivot()
local original=State.step local field,deadline local rows={}
local function waitFor(fn,seconds) local stop=os.clock()+seconds repeat if fn() then return true end task.wait(.03) until os.clock()>stop return false end
local ok,err=xpcall(function()
	State.step=function(self,...) field=self return original(self,...) end
	assert(waitFor(function() return field end,5)) State.step=original
	assert(waitFor(function() return field.Phase=="Normal" end,12))
	deadline=field.NextResetAt field.NextResetAt=workspace:GetServerTimeNow()+10000
	local safeX=workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
	for _,spec in {{"Grasslands","RawMeat","PrimalCatalyst"},{"Swamp","SmallFish","MutantLeech"},{"Jungle","WildFruit","BeastHeart"},{"CrystalCave","CrystalShard","PrismaticCrystal"},{"Volcano","CharredMeat","DragonScale"}} do
	for index=2,(script:GetAttribute("Heavy") and 3 or 2) do
		local area,id=spec[1],spec[index] local def=Defs.get(id)
		local territory=T.get(area) local wanted=territory.Region.Home+Vector3.new(-24,0,32) local pos=territory.Candidates[1]
		for _,v in territory.Candidates do if (v-wanted).Magnitude<(pos-wanted).Magnitude then pos=v end end
		G.resetAll() C.release(p) if Carry.get(p) then Carry.forceDrop(p,p.Character,"Benchmark cleanup") end
		d.Power=script:GetAttribute("PowerOverride") or def.PowerRequired d.SlowMode=script:GetAttribute("SlowMode")==true Data.publish(p) Carry.recalculateMovement(p)
		local node=field.Nodes[area..":Node01"] if node.RecordId then R.releaseToken(area,node.RecordId) end
		local r=field:create(node,id,"FastHeistBenchmark") r.Position,r.SpawnPosition=pos,pos R.step()
		Carry.prepareAssignment(r.InstanceId,{Rarity=def.Rarity,Title="Controlled",Effects=if index==2 then {} else {{Id="HeavyBurden",Tier="Mild",Extra=.06}}})
		local root=p.Character.HumanoidRootPart root.Anchored=true p.Character:PivotTo(CFrame.new(pos+Vector3.new(0,3,0))) task.wait(.22)
		assert(Spawn.pickup(p,r.InstanceId),"Pickup failed")
		local g for _,m in workspace.GeneratedGameplay.Guardians:GetChildren() do if m.PrimaryPart:GetAttribute("AreaId")==area then g=m.PrimaryPart end end
		local began=os.clock() local samples={} local attacks=0 local firstThreat=nil local minGap=math.huge local outcome="Timeout"
		local dodgeGoal,warningAt local dodges=0 local radialDodge=false local dodgeHolding=false local survivedAttacks=0
		local priorPos,priorState=g.Position,g:GetAttribute("GuardianState")
		local mode=script:GetAttribute("Mode") or "Unknown" local speed=p.Character.Humanoid.WalkSpeed
		script:SetAttribute("Progress",mode.." "..area.." "..id)
		local heartbeat=game:GetService("RunService").Heartbeat:Connect(function(dt)
			local state=g:GetAttribute("GuardianState")
			-- Both endpoints must be continuous pursuit, never attack/return transitions.
			if state=="PURSUING" and priorState==state then table.insert(samples,Chase.horizontal(priorPos,g.Position)/math.max(dt,.001)) end
			if state=="WARNING" and priorState~=state then
				attacks+=1 warningAt=os.clock() dodgeHolding=false
				if script:GetAttribute("Dodge") then
					local config=require(H.GuardianConfig).Areas[area] local frame=g:GetAttribute("HazardFrame")
					local localPos=frame:PointToObjectSpace(root.Position)
					-- Clear the physical guardian as well as the thin warning lane; a
					-- lane-edge sidestep is not a body dodge when the guardian turns.
					local radius=math.max(if config.Kind=="Shockwave" then config.Radius else config.Width/2,math.sqrt(g.Size.X^2+g.Size.Z^2)/2+config.CatchReach+8)
					local sign=if localPos.Z>=0 then 1 else -1
					local goal=frame:PointToWorldSpace(Vector3.new(localPos.X,3,sign*(radius+3)))
					if math.abs(goal.Z-territory.Region.Center.Z)>70 then goal=frame:PointToWorldSpace(Vector3.new(localPos.X,3,-sign*(radius+3))) end
					radialDodge=config.Kind=="Shockwave"
					if radialDodge then
						local away=Vector3.new(localPos.X,0,localPos.Z)
						if away.Magnitude<.01 then away=-Vector3.xAxis end
						goal=frame:PointToWorldSpace(away.Unit*(config.Radius+3)+Vector3.yAxis*3)
					end
					dodgeGoal=goal
				end
			end
			if priorState=="HAZARD" and state=="COOLDOWN" and Carry.get(p) then survivedAttacks+=1 end
			local gap=Chase.catchGap(g.CFrame,g.Size,root.Position) minGap=math.min(minGap,gap)
			if not firstThreat and gap<=30 then firstThreat=os.clock()-began end
			priorPos,priorState=g.Position,state
			if Carry.get(p) and not C.isRecovering(p) then
				local direction=-Vector3.xAxis
				if dodgeGoal and os.clock()-warningAt>=.25 then
					local delta=Vector3.new(if radialDodge then dodgeGoal.X-root.Position.X else 0,0,dodgeGoal.Z-root.Position.Z)
					if delta.Magnitude<=1 then dodgeGoal=nil dodges+=1 dodgeHolding=radialDodge else direction=if radialDodge then delta.Unit else (-Vector3.xAxis+delta.Unit).Unit end
				end
				-- Clearing a shockwave's edge and immediately running back through its
				-- still-active disk is not a completed dodge. Hold the reached safe point
				-- until the committed window ends; later body-catch risk remains enabled.
				if dodgeHolding and (state=="WARNING" or state=="HAZARD") then direction=Vector3.zero else dodgeHolding=false end
				p.Character:PivotTo(CFrame.new(root.Position+direction*p.Character.Humanoid.WalkSpeed*dt))
			end
		end)
		waitFor(function()
			if not Carry.get(p) then outcome=if tostring(p:GetAttribute("DropReason")):find("GuardianCatch",1,true) then "Caught" else "Hazard" return true end
			if root.Position.X<safeX then outcome="Escaped" return true end return false
		end,170)
		heartbeat:Disconnect() table.sort(samples)
		table.insert(rows,{Mode=mode,Area=area,Resource=id,Power=d.Power,Speed=speed,Position={pos.X,pos.Y,pos.Z},Outcome=outcome,Seconds=os.clock()-began,
			ThreatSeconds=firstThreat or -1,MinGap=minGap,Attempts=attacks,CompletedDodgeMoves=dodges,SurvivedAttacks=survivedAttacks,PursuitSamples=#samples,
			PursuitP50=samples[math.max(1,math.ceil(#samples*.5))] or 0,PursuitP90=samples[math.max(1,math.ceil(#samples*.9))] or 0})
		script:SetAttribute("Rows",game.HttpService:JSONEncode(rows))
		if Carry.get(p) then Carry.forceDrop(p,p.Character,"Benchmark cleanup") end R.releaseToken(area,r.InstanceId) G.resetAll()
		assert(#Spawn.validate()==0,"Resource identity failure") assert(outcome~="Timeout","Benchmark timeout")
	end end
end,debug.traceback)
State.step=original G.resetAll() if Carry.get(p) then Carry.forceDrop(p,p.Character,"Benchmark cleanup") end
if deadline then field.NextResetAt=math.max(deadline,workspace:GetServerTimeNow()+1) end
for k in d do d[k]=nil end for k,v in backup do d[k]=v end Data.publish(p) Carry.recalculateMovement(p)
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(origin) end
script:SetAttribute("Result",if ok then "PASS" else err)
if not ok then warn(err) end
