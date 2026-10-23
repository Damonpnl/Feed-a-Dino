-- Opt-in live-service geometry/telegraph tests; controlled kinematic placement, not human feel.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local D,C,R,G,Spawn,Catch=require(S.DataService),require(S.CarryService),require(S.ResourceService),require(S.GuardianService),require(S.SpawnService),require(S.GuardianCatch)
local State,PD,Config,Defs=require(H.FieldState),require(H.PlayerData),require(H.GuardianConfig),require(H.ResourceDefinitions)
local p=game.Players:GetPlayers()[1] local data=D.get(p) local backup=PD.copy(data) local origin=p.Character:GetPivot()
local field,deadline local original=State.step local checks,rows=0,{}
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.02) until os.clock()>stop return false end
local link
local ok,err=xpcall(function()
	State.step=function(self,...) field=self return original(self,...) end
	assert(waitFor(function() return field end,4)) State.step=original
	assert(waitFor(function() return field.Phase=="Normal" end,12)) deadline=field.NextResetAt field.NextResetAt=workspace:GetServerTimeNow()+10000
	for _,spec in {{"Grasslands","RawMeat"},{"Swamp","SmallFish"},{"Jungle","WildFruit"},{"CrystalCave","CrystalShard"},{"Volcano","CharredMeat"}} do
	for _,dodge in {false,true} do
		local area,id=spec[1],spec[2] local config=Config.Areas[area]
		-- A continuously retreating 35-stud hold can project the Gorilla beyond its
		-- bounded leap range; use a reachable intercept, still outside body-catch reach.
		local hold=if config.Kind=="Shockwave" then 25 else 35
		G.resetAll() Catch.release(p) data.Power=Defs.get(id).PowerRequired data.SlowMode=false D.publish(p)
		local root=p.Character.HumanoidRootPart root.Anchored=true
		local g for _,model in workspace.GeneratedGameplay.Guardians:GetChildren() do if model.PrimaryPart:GetAttribute("AreaId")==area then g=model.PrimaryPart end end
		p.Character:PivotTo(CFrame.new(g.Position-Vector3.new(hold,5,0)))
		local token,why=Spawn.devGrant(p,area,id,"none") assert(token,why)
		local hitsBefore=G.getSnapshot(area).HazardHits
		local health=p.Character.Humanoid.Health local warned,ended,wasActive=false,false,false local frame,warningStart local maxHeight=0 local changedFrame=false
		local observedWarning,warningDistance
		script:SetAttribute("Progress",area..(if dodge then " dodge" else " hit"))
		link=game:GetService("RunService").Heartbeat:Connect(function()
			local state=g:GetAttribute("GuardianState")
			if not warned and state~="WARNING" then
				-- Keep a controlled carrier outside body reach until a genuine telegraph.
				p.Character:PivotTo(CFrame.new(g.Position-Vector3.new(hold,5,0)))
			elseif not warned then
				warned=true frame=g:GetAttribute("HazardFrame") warningStart=G.getSnapshot(area).WarningAt
				warningDistance=(Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(g.Position.X,0,g.Position.Z)).Magnitude
				p.Character:PivotTo(frame*CFrame.new(0,3,0))
			elseif state=="WARNING" or state=="HAZARD" then
				if g:GetAttribute("HazardFrame")~=frame then changedFrame=true end
				maxHeight=math.max(maxHeight,g.Position.Y-G.getSnapshot(area).Home.Y)
				if dodge and workspace:GetServerTimeNow()-warningStart>=.25 then
					-- Deliberately outside the declared footprint; tests collision correspondence.
					p.Character:PivotTo(frame*CFrame.new(0,3,(if config.Kind=="Shockwave" then config.Radius else config.Width/2)+3))
				end
				if state=="HAZARD" then wasActive=true end
			elseif warned then ended=true end
			if warned and not observedWarning and (state=="HAZARD" or G.getSnapshot(area).HazardHits>hitsBefore) then
				observedWarning=workspace:GetServerTimeNow()-warningStart
			end
		end)
		check(waitFor(function() return warned end,12),area.." creates visible warning")
		check(waitFor(function() return ended end,config.Warning+config.Active+3),area.." resolves attack")
		link:Disconnect() link=nil
		check(not changedFrame,area.." committed attack did not re-aim")
		-- A hit at alpha zero can cancel the now-targetless attack before this observer's
		-- next Heartbeat. The server's hazard-hit counter is evidence of that active sample.
		check(wasActive or G.getSnapshot(area).HazardHits>hitsBefore,area.." entered active hazard")
		check(observedWarning and observedWarning>=config.Warning-.03 and observedWarning<=config.Warning+.15,area.." measured warning duration matches config")
		check(p.Character.Humanoid.Health==health,area.." no traditional damage")
		if dodge then check(C.get(p) and C.get(p).token==token,area.." outside warning footprint retains GUID")
		else
			local returned=R.getRecord(token)
			check(not C.get(p) and returned and returned.State=="DROPPED",area.." hit drops same GUID")
			check((returned.Position-returned.SpawnPosition).Magnitude<.1,area.." hit returns feed to original spawn")
		end
		if area=="Jungle" then check(maxHeight>5,"Gorilla has visible leap rather than instant teleport") end
		table.insert(rows,{Area=area,Dodged=dodge,Warning=config.Warning,ObservedWarning=observedWarning,WarningDistance=warningDistance,Active=config.Active,ObservedLeapHeight=maxHeight,Hit=not C.get(p)})
		script:SetAttribute("Rows",game.HttpService:JSONEncode(rows))
		G.resetAll() if C.get(p) then C.forceDrop(p,p.Character,"Ability fixture cleanup") end R.releaseToken(area,token)
		check(#Spawn.validate()==0,"No duplicate resources after "..area)
	end end
end,debug.traceback)
if link then link:Disconnect() end State.step=original G.resetAll()
if C.get(p) then C.forceDrop(p,p.Character,"Ability fixture cleanup") end
if deadline then field.NextResetAt=math.max(deadline,workspace:GetServerTimeNow()+1) end
for k in data do data[k]=nil end for k,v in backup do data[k]=v end D.publish(p) C.recalculateMovement(p)
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(origin) end
script:SetAttribute("Result",if ok then "PASS" else err) if not ok then warn(err) end
