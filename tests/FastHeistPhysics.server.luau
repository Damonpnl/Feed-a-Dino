-- Opt-in actual Humanoid physics, not anchored/teleported escape simulation.
-- Server-owned automation is NOT physical mobile input or human feel validation.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local D,C,R,G,Spawn,T=require(S.DataService),require(S.CarryService),require(S.ResourceService),require(S.GuardianService),require(S.SpawnService),require(S.BiomeTerritory)
local PD,State=require(H.PlayerData),require(H.FieldState)
local p=game.Players:GetPlayers()[1] local data=D.get(p) local backup=PD.copy(data) local origin=p.Character:GetPivot()
local root,h=p.Character.HumanoidRootPart,p.Character.Humanoid
local oldStep=State.step local field,deadline local checks,rows=0,{}
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function flat(a,b) return (Vector3.new(a.X,0,a.Z)-Vector3.new(b.X,0,b.Z)).Magnitude end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.02) until os.clock()>stop return false end
local function walk(goal)
	local start,last,distance=os.clock(),root.Position,0
	check(waitFor(function()
		h:MoveTo(goal) local current=root.Position distance+=flat(current,last) last=current
		return flat(current,goal)<2.5
	end,12),"Physics reaches waypoint")
	h:MoveTo(root.Position)
	return os.clock()-start,distance
end
local ok,err=xpcall(function()
	check(D.isWritable(p) and D.getStatus(p).Backend=="StudioMemory","Isolated writable memory")
	State.step=function(self,...) field=self return oldStep(self,...) end
	assert(waitFor(function() return field end,4)) State.step=oldStep
	assert(waitFor(function() return field.Phase=="Normal" end,12)) deadline=field.NextResetAt field.NextResetAt=workspace:GetServerTimeNow()+10000
	G.resetAll() root.Anchored=false root:SetNetworkOwner(nil)
	local safeX=workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
	local region=T.get("Grasslands").Region local start=Vector3.new(safeX+55,region.Home.Y+4,region.Center.Z)
	for _,power in {0,1000,10000,1e6,150e6} do
		data.Power=power data.SlowMode=false D.publish(p) C.recalculateMovement(p)
		p.Character:PivotTo(CFrame.new(start)) task.wait(.2)
		local speed=h.WalkSpeed local seconds,distance=walk(start+Vector3.xAxis*80)
		local achieved=distance/seconds
		check(achieved>speed*.7 and achieved<speed*1.15,"Achieved speed within bounded locomotion tolerance")
		table.insert(rows,{Kind="80StudPhysics",Power=power,Configured=speed,Achieved=achieved,Seconds=seconds,Distance=distance})
		script:SetAttribute("Rows",game.HttpService:JSONEncode(rows))
	end
	-- Repeated ninety-degree turns and a reversal at the highest candidate speed.
	for _,offset in {Vector3.new(40,0,0),Vector3.new(40,0,20),Vector3.new(0,0,20),Vector3.zero,Vector3.new(30,0,0),Vector3.zero} do walk(start+offset) end
	check(h.Health>0,"High-speed turns preserve character")
	-- Use an existing wall discovered by raycast; never add or rebuild geometry.
	local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances={p.Character,workspace.GeneratedGameplay} params.RespectCanCollide=true
	local wall=workspace:Raycast(root.Position,Vector3.zAxis*120,params)
	check(wall~=nil,"Existing wall found for collision trial")
	local before=root.Position h:MoveTo(before+Vector3.zAxis*120) task.wait(2) h:MoveTo(root.Position)
	check(root.Position.Z<=wall.Position.Z+1,"72 speed does not tunnel through existing wall")
	p.Character:PivotTo(CFrame.new(start)) task.wait(.22)
	local node=field.Nodes["Grasslands:Node01"] if node.RecordId then R.releaseToken("Grasslands",node.RecordId) end
	local r=field:create(node,"RawMeat","FastHeistPhysics") r.Position=start+Vector3.new(25,-4,0) r.SpawnPosition=r.Position R.step()
	C.prepareAssignment(r.InstanceId,{Rarity="Common",Title="",Effects={}})
	h:MoveTo(start+Vector3.xAxis*70)
	check(waitFor(function() return flat(root.Position,r.Position)<10 end,2),"Moving character enters pickup radius")
	check(Spawn.pickup(p,r.InstanceId),"Pickup succeeds during actual high-speed movement") G.resetAll()
	walk(start+Vector3.xAxis*70)
	local visual=p.Character:FindFirstChild("CarriedResource")
	check(visual and flat(root.CFrame:PointToObjectSpace(visual.PrimaryPart.Position),Vector3.new(0,1.5,-2))<.5,"Carried visual stays welded during fast movement")
	walk(Vector3.new(safeX-12,start.Y,start.Z))
	check(C.get(p) and C.get(p).token==r.InstanceId,"Physics safe-zone crossing preserves GUID")
	check(C.consumeOwned(p,r.InstanceId) and #Spawn.validate()==0,"One-time cleanup without duplicate")
end,debug.traceback)
State.step=oldStep G.resetAll() if C.get(p) then C.forceDrop(p,p.Character,"Physics cleanup") end
if deadline then field.NextResetAt=math.max(deadline,workspace:GetServerTimeNow()+1) end
for k in data do data[k]=nil end for k,v in backup do data[k]=v end D.publish(p) C.recalculateMovement(p)
h:MoveTo(root.Position) p.Character:PivotTo(origin) root:SetNetworkOwnershipAuto()
script:SetAttribute("Result",if ok then "PASS" else err) if not ok then warn(err) end
