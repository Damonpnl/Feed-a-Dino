-- Actual server-owned Humanoid MoveTo over the live blockout, not distance/speed estimates.
-- Guardians are reset after each acquisition to isolate travel cost; this is NOT escape evidence.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Carry,Spawn,Resource,Guardian,Territory=require(S.DataService),require(S.CarryService),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService),require(S.BiomeTerritory)
local PD,State,Resources,Debuff=require(H.PlayerData),require(H.FieldState),require(H.ResourceDefinitions),require(H.CarryDebuff)
local p=game.Players:GetPlayers()[1] local data=Data.get(p) local backup=PD.copy(data)
local original=p.Character:GetPivot() local oldStep,oldAssign=State.step,Debuff.assign local field,savedReset
local rows,checks={},0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function flat(a,b) return (Vector3.new(a.X,0,a.Z)-Vector3.new(b.X,0,b.Z)).Magnitude end
local function root() return p.Character.HumanoidRootPart end
local function publish() Data.publish(p) Carry.recalculateMovement(p) end
local function emit() script:SetAttribute("Rows",game:GetService("HttpService"):JSONEncode(rows)) end
local function walk(points)
	local started=os.clock() local distance=0 local last=root().Position
	for _,goal in points do
		local timeout=os.clock()+flat(root().Position,goal)/math.max(p.Character.Humanoid.WalkSpeed,1)*2+12
		repeat
			p.Character.Humanoid:MoveTo(goal) task.wait(.15)
			local pos=root().Position distance+=flat(pos,last) last=pos
			assert(p.Character.Humanoid.Health>0 and os.clock()<timeout,"Route blocked or character lost")
		until flat(root().Position,goal)<2.5
	end
	p.Character.Humanoid:MoveTo(root().Position)
	return os.clock()-started,distance
end
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Isolated session")
	State.step=function(self,...) field=self return oldStep(self,...) end
	local limit=os.clock()+5 repeat task.wait(.05) until field or os.clock()>limit State.step=oldStep assert(field)
	while field.Phase~="Normal" do task.wait(.1) end savedReset=field.NextResetAt field.NextResetAt=workspace:GetServerTimeNow()+1e6
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")] local station=base:FindFirstChild("TrainingStation",true)
	local home=station.Position+Vector3.new(0,4,0) local safeX=workspace.GeneratedGameplay.SafeZoneBoundary.Position.X-12
	local definitions={{"Grasslands","RawMeat","PrimalCatalyst"},{"Swamp","SmallFish","MutantLeech"},{"Jungle","WildFruit","BeastHeart"},{"CrystalCave","CrystalShard","PrismaticCrystal"},{"Volcano","CharredMeat","DragonScale"}}
	-- Short actual locomotion comparisons at requested unloaded milestone speeds.
	local lane=Territory.get("Grasslands").Region
	local laneZ=lane.Center.Z+(lane.LaneMin+lane.LaneMax)/2
	local gateZ=lane.Center.Z
	local insideX=safeX+36 -- Enter through the saved gate before joining the wall-side lane.
	for _,power in {0,10000,1000000,100000000} do
		data.Power=power data.SlowMode=false publish() Guardian.resetAll()
		p.Character:PivotTo(CFrame.new(insideX,home.Y,gateZ)) root():SetNetworkOwner(nil) task.wait(.2)
		local speed=p.Character.Humanoid.WalkSpeed local start=root().Position
		local seconds,distance=walk({start+Vector3.new(80,0,0)})
		table.insert(rows,{Kind="80StudComparison",Power=power,Speed=speed,Seconds=seconds,Distance=distance}) emit()
	end
	for _,row in definitions do
		local area,ordinary,heavy=row[1],row[2],row[3] local t=Territory.get(area)
		local target=t.Candidates[1] local goal=t.Region.Home-Vector3.xAxis*55
		for _,pos in t.Candidates do if flat(pos,goal)<flat(target,goal) then target=pos end end
		local location=target+Vector3.new(0,4,0)
		data.Power=Resources.get(ordinary).PowerRequired data.SlowMode=false publish() Guardian.resetAll()
		p.Character:PivotTo(CFrame.new(home)) root():SetNetworkOwner(nil) task.wait(.2)
		script:SetAttribute("Progress",area.." outbound")
		local outbound,distance=walk({Vector3.new(safeX,home.Y,home.Z),Vector3.new(safeX,home.Y,gateZ),Vector3.new(insideX,home.Y,gateZ),Vector3.new(insideX,home.Y,laneZ),Vector3.new(location.X,location.Y,laneZ),location})
		local outPower,outSpeed=data.Power,p.Character.Humanoid.WalkSpeed
		for i,id in {ordinary,heavy} do
			script:SetAttribute("Progress",area.." return "..id)
			data.Power=Resources.get(id).PowerRequired publish() Guardian.resetAll()
			local node=field.Nodes[area..":Node01"] if node.RecordId then Resource.releaseToken(area,node.RecordId) end
			local r=field:create(node,id,"Phase5BTravel") r.Position,r.SpawnPosition=target,target Resource.step()
			-- Deterministic fixture penalty, not a probability change. Heavy trials use an authored Mild burden.
			Debuff.assign=function(rarity) return {Rarity=rarity,Title="Travel fixture",Effects=if i==1 then {} else {{Id="HeavyBurden",Tier="Mild",Extra=.06}}} end
			p.Character:PivotTo(CFrame.new(location)) root():SetNetworkOwner(nil) task.wait(.22)
			check(Spawn.pickup(p,r.InstanceId),"Pickup "..id) Debuff.assign=oldAssign Guardian.resetAll()
			local speed=p.Character.Humanoid.WalkSpeed
			local returning,returnDistance=walk({Vector3.new(insideX,location.Y,location.Z),Vector3.new(insideX,location.Y,gateZ),Vector3.new(safeX,location.Y,gateZ)})
			check(Carry.get(p) and Carry.get(p).token==r.InstanceId,"Travel retains GUID")
			local safeSeconds=returning
			local final,finalDistance=walk({Vector3.new(safeX,home.Y,home.Z),home})
			table.insert(rows,{Kind="Travel",Area=area,Resource=id,Power=data.Power,OutboundPower=outPower,OutboundSpeed=outSpeed,CarrySpeed=speed,ExtraSlowdown=if i==1 then 0 else .06,OutboundSeconds=outbound,ToSafeSeconds=safeSeconds,ReturnSeconds=returning+final,RoundTripSeconds=outbound+returning+final,OutboundDistance=distance,ReturnDistance=returnDistance+finalDistance,ResourceX=target.X,ResourceZ=target.Z}) emit()
			check(Carry.consumeOwned(p,r.InstanceId),"Cleanup original GUID")
		end
	end
end,debug.traceback)
State.step,Debuff.assign=oldStep,oldAssign
if savedReset then field.NextResetAt=math.max(savedReset,workspace:GetServerTimeNow()+1) end
Guardian.resetAll() if Carry.get(p) then Carry.forceDrop(p,p.Character,"Travel cleanup") end
for k in data do data[k]=nil end for k,v in backup do data[k]=v end publish()
if p.Character then p.Character:PivotTo(original) root():SetNetworkOwnershipAuto() end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5BTravel] PASS "..checks) else warn(failure) end
