--!nonstrict
-- One authoritative guardian per biome. Immediate wake, full-runway pursuit to the
-- server-validated safe entrance, fair swept hazards, server-validated body catches,
-- then a visible return home.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.Shared
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Config = require(Shared.GuardianConfig)
local State = require(Shared.GuardianState)
local Geometry = require(Shared.GuardianGeometry)
local Chase = require(Shared.GuardianChase)
local Aim = require(Shared.GuardianAim)
local Movement = require(Shared.MovementCalculator)
local Data = require(script.Parent.DataService)
local CarryDebuff = require(Shared.CarryDebuff)
local Zone = require(script.Parent.ZoneGeometry)
local Territory = require(script.Parent.BiomeTerritory)
local ResourceService = require(script.Parent.ResourceService)
local Carry = require(script.Parent.CarryService)
local Catch = require(script.Parent.GuardianCatch)
local Metadata = require(script.Parent.BillboardMetadataService)
local Service = {}
local guardians, connection = {}, nil
-- Earliest time any guardian may start a new telegraph on a player (attack stagger).
local attackFree = {}
local runway = nil
local function now() return workspace:GetServerTimeNow() end
local function publish(r)
	local s=r.Engine
	for key,value in {GuardianState=s.State,Disturbance=s.Disturbance,Activation=s.Activation,StateEndsAt=s.Deadline or 0,TargetRarity=s.Rarity or ""} do
		r.Part:SetAttribute(key,value)
	end
	local label = if s.Rarity and s.State~="SLEEPING" then s.State.." · "..s.Rarity else s.State
	Metadata:Update(r.Part,{ValueText=label})
	local chasing = s.State=="WAKING" or s.State=="PURSUING" or s.State=="WARNING" or s.State=="RETURNING"
	r.Part.Color=if s.State=="HAZARD" then Color3.fromRGB(240,65,40) elseif chasing then Color3.fromRGB(235,175,55) else Color3.fromRGB(90,100,115)
end
local function place(r, position, facing)
	local flat=facing and Vector3.new(facing.X,0,facing.Z)
	if flat and flat.Magnitude>1e-3 then
		r.Part.CFrame=CFrame.lookAt(position, position+flat.Unit)
	else
		r.Part.CFrame=r.Part.CFrame.Rotation+position
	end
end
local function clear(r)
	for _,name in {"Telegraph","Sweep","Direction"} do if r[name] then r[name]:Destroy() r[name]=nil end end
	r.Hits={} r.Samples={}
	r.CatchSamples={} r.CatchBody=nil r.LeapStart=nil
end
local function indicator(r,name,alpha,warning)
	local part=r[name]
	if not part then
		part=Instance.new("Part") part.Name=name part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false
		part.Material=Enum.Material.Neon part.Color=if warning then Color3.fromRGB(255,195,40) else Color3.fromRGB(255,60,35)
		part.Transparency=if warning then 0.65 else 0.3 part.Parent=r.Part.Parent r[name]=part
	end
	part.CFrame,part.Size,part.Shape=Geometry.visual(r.Config,r.Frame,alpha,warning)
end
local function capture(r,time)
	for _,p in Players:GetPlayers() do
		local c=p.Character local root=c and c:FindFirstChild("HumanoidRootPart")
		if root then r.Samples[p]={Character=c,Position=root.Position,Time=time} end
	end
end
local function notice(player, text)
	player:SetAttribute("HuntNotice", text)
	player:SetAttribute("HuntNoticeTick", now())
end
local function alert(player, rarity)
	local profile = Chase.profile(rarity)
	if profile and profile.Alert then notice(player, profile.Alert) end
end
local function emit(r,state,at)
	if state=="WAKING" then
		clear(r)
	elseif state=="PURSUING" then
		r.StuckRef=nil
	elseif state=="WARNING" then
		local aim = if r.Target then r.Target.Position else r.Part.Position + r.Runway.axis
		r.Frame = r.PendingFrame or Chase.attackFrame(r.Runway, r.Part.Position, aim)
		r.PendingFrame=nil
		clear(r) r.LastSample=at capture(r,at)
		r.Attempts=(r.Attempts or 0)+1
		r.WarningAt=at
		if r.Config.Kind=="Shockwave" then r.LeapStart=r.Part.Position end
		indicator(r,"Telegraph",1,true)
		indicator(r,"Sweep",0,false)
		r.Sweep.Color=Color3.fromRGB(255,230,120)
		local arrow=Instance.new("Part") arrow.Name="Direction" arrow.Anchored=true arrow.CanCollide=false arrow.CanTouch=false arrow.CanQuery=false
		arrow.Size=Vector3.new(1,1,1) arrow.Transparency=1 arrow.CFrame=r.Frame*CFrame.new(0,3,0) arrow.Parent=r.Part.Parent r.Direction=arrow
		Metadata:Create(arrow,{DisplayName=if r.Config.Kind=="Shockwave" then "SLAM ORIGIN" else "DODGE THE LANE",ValueText=r.Config.Kind,ObjectType="Guardian",Rarity="Common"})
		if r.Config.Kind~="Shockwave" then
			local cross=r.Config.Kind=="FireSweep"
			local length=if cross then r.Config.Width else r.Config.Length
			local function point(x,z) return r.Frame:PointToWorldSpace(if cross then Vector3.new(z,0.4,x) else Vector3.new(x,0.4,z)) end
			local tip=-length/2+14
			for _,pair in {{point(tip-10,0),point(tip,0)},{point(tip-3,-3),point(tip,0)},{point(tip-3,3),point(tip,0)}} do
				local line=Instance.new("Part") line.Name="Arrow" line.Anchored=true line.CanCollide=false line.CanTouch=false line.CanQuery=false
				line.Material=Enum.Material.Neon line.Color=Color3.fromRGB(255,240,150) line.Size=Vector3.new(0.5,0.25,(pair[2]-pair[1]).Magnitude)
				line.CFrame=CFrame.lookAt((pair[1]+pair[2])/2,pair[2]) line.Parent=arrow
			end
		end
		r.Part:SetAttribute("HazardFrame",r.Frame)
	elseif state=="HAZARD" then
		if r.LeapStart then place(r,Vector3.new(r.Frame.X,r.Home.Y,r.Frame.Z),r.Frame.Position-r.LeapStart) end
		indicator(r,"Sweep",0,false) r.Sweep.Color=Color3.fromRGB(255,60,35)
	elseif state=="COOLDOWN" then
		clear(r)
		-- A committed miss earns a short visible recovery before turning/pursuing.
		-- Body catch geometry remains active and unchanged; no player invulnerability.
		r.RecoverAt=at+r.Config.AttackRecovery r.Speed=0
		if r.AttackTarget then attackFree[r.AttackTarget]=at+Chase.Timing.AttackStagger end
		r.AttackTarget=nil
	elseif state=="RETURNING" then
		-- Disengage: stop attacking, drop stale commands, turn toward home before travelling.
		clear(r)
		if r.AttackTarget then attackFree[r.AttackTarget]=at+Chase.Timing.AttackStagger end
		r.Target=nil r.AttackTarget=nil r.PendingFrame=nil
		r.DisengageUntil=at+Chase.Timing.DisengageHold
		place(r, r.Part.Position, r.Home-r.Part.Position)
		r.Part:SetAttribute("DisengageTick",at)
	elseif state=="SLEEPING" then
		clear(r)
		if Chase.horizontal(r.Part.Position, r.Home)>2 then
			warn(("[GuardianService] %s return failsafe teleport from %s"):format(r.AreaId, tostring(r.Part.Position)))
		end
		place(r, r.Home, r.HomeFacing) r.Target=nil r.Threats={} r.EncounterStart=nil
	end
	publish(r)
end
local function sample(r,startTime,endTime,currentTime)
	local from=math.max(startTime,r.LastSample)
	if endTime<from then return end
	for _,p in Players:GetPlayers() do
		local c=p.Character local root=c and c:FindFirstChild("HumanoidRootPart") local h=c and c:FindFirstChildOfClass("Humanoid")
		local previous=r.Samples[p]
		if root and h and h.Health>0 and not r.Hits[p] and not Catch.isRecovering(p) and not Chase.isSafe(r.Runway, root.Position) then
			local pos=root.Position
			local old=if previous and previous.Character==c then previous.Position else pos
			local oldTime=if previous and previous.Character==c then previous.Time else currentTime
			local function at(t)
				return old:Lerp(pos,if currentTime>oldTime then math.clamp((t-oldTime)/(currentTime-oldTime),0,1) else 1)
			end
			if Geometry.hit(r.Config,r.Frame,at(from),at(endTime),(from-startTime)/r.Config.Active,(endTime-startTime)/r.Config.Active) then
				r.Hits[p]=true
				p:SetAttribute("HazardTick",currentTime)
				local dropped=Carry.forceDrop(p,c,"Guardian:"..r.AreaId,true)
				-- forceDrop reconciles the field clock. Reset may have cleared this attack,
				-- evacuated everyone and destroyed its indicators during that call.
				if r.Engine.State~="HAZARD" then return end
				if dropped then
					r.HazardHits=(r.HazardHits or 0)+1
					Catch.apply(p,c,r.Frame.Position,r.Frame.LookVector,r.AreaId)
				end
				r.Threats[p]=nil
				if r.Target and r.Target.Player==p then r.Target=nil end
			end
		end
	end
	r.LastSample=endTime
	indicator(r,"Sweep",math.clamp((endTime-startTime)/r.Config.Active,0,1),false)
end
local function rootOf(player)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health>0 then return root end
	return nil
end
-- Re-entry rule: crossing the safe boundary permanently ends this guardian's claim on
-- that carry. Only a new server-acknowledged pickup can create a new threat, so stepping
-- back and forth across the line cannot reset, re-aggro, or stall a guardian.
local function candidates(r, time)
	local list={}
	for player, threat in r.Threats do
		local item=Carry.get(player)
		local root=rootOf(player)
		if player.Parent~=Players or not item or item.token~=threat.Token or not root then
			r.Threats[player]=nil
			if r.Target and r.Target.Player==player then r.Target=nil end
		elseif Chase.isSafe(r.Runway, root.Position) then
			r.Threats[player]=nil
			if r.Target and r.Target.Player==player then r.Target=nil end
			player:SetAttribute("GuardianEscapeTick", time)
			notice(player, "SAFE ZONE REACHED\nTHE GUARDIAN TURNS BACK")
		else
			local position=root.Position
			local velocity=root.AssemblyLinearVelocity
			if threat.LastPosition and time>threat.LastTime then velocity=(position-threat.LastPosition)/(time-threat.LastTime) end
			threat.Velocity=velocity threat.LastPosition=position threat.LastTime=time
			table.insert(list,{
				Player=player, Rarity=threat.Rarity, StolenAt=threat.StolenAt, Position=position,
				Distance=Chase.horizontal(position, r.Part.Position),
				Reachable=not Chase.inBases(position, r.Bases, Chase.Timing.BasePad) and Chase.onRunway(r.Runway, position, 12),
				Initial=player==r.Initial and time<r.LockUntil,
			})
		end
	end
	return list
end
local function remember(r, player, rarity, token, time)
	r.Threats[player]={Rarity=rarity, StolenAt=time, Token=token}
	if r.Engine.State=="SLEEPING" or r.Engine.State=="RETURNING" then
		r.EncounterStart=time
		r.Initial=player
		r.LockUntil=time+Chase.Timing.InitialLock
		r.Target={Player=player, Rarity=rarity, Position=rootOf(player) and rootOf(player).Position or r.Part.Position, Initial=true}
	end
end
-- Worst-case slowdown of the current carry, including every assigned curse slowdown.
local function worstSlowdown(player)
	local item=Carry.get(player)
	local definition=item and Resources.get(item.resourceId)
	if not definition then return nil end
	return CarryDebuff.applied(definition.CarrySlowdown, CarryDebuff.maxExtra(Carry.getCurse(player)))
end
-- Worst-case carrier speed for the current carry, including every assigned curse slowdown.
local function carrierSpeed(player)
	local worst=worstSlowdown(player)
	if not worst then return 16, Chase.Timing.DodgeSafety end
	local curse=Carry.getCurse(player)
	local strong=false
	for _,effect in (curse and curse.Effects or {}) do if effect.Tier=="Strong" then strong=true end end
	local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local data=Data.get(player)
	local speed=Movement.effective(data and data.Power or 0,data and data.SlowMode==true,true,worst,false)
	if humanoid then speed=math.min(speed, humanoid.WalkSpeed) end
	return speed, if strong then Chase.Timing.CursedDodgeSafety else Chase.Timing.DodgeSafety
end
-- Overlapping guardians never telegraph on top of each other or chain onto one player.
local function attackClear(r, player, position, time)
	if time<(attackFree[player] or 0) then return false end
	for _,other in guardians do
		if other~=r and (other.Engine.State=="WARNING" or other.Engine.State=="HAZARD")
			and Chase.horizontal(other.Frame.Position, position)<Chase.Timing.CrowdRadius then
			return false
		end
	end
	return true
end
-- Body catch: only threatened carriers of this biome, outside the safe zone, not already
-- recovering. One forceDrop per catch; the threat ends so the guardian retargets at once.
local function catchCarriers(r, time)
	local body, size = r.Part.CFrame, r.Part.Size
	local previousBody=r.CatchBody or body
	r.CatchSamples=r.CatchSamples or {}
	for player, threat in r.Threats do
		local root=rootOf(player)
		local item=Carry.get(player)
		if not root or not item or item.token~=threat.Token or Chase.isSafe(r.Runway, root.Position) or Catch.isRecovering(player) then continue end
		local previous=r.CatchSamples[player]
		local old=if previous and previous.Character==player.Character and previous.Token==item.token then previous.Position else root.Position
		r.CatchSamples[player]={Position=root.Position,Character=player.Character,Token=item.token}
		local hit=false
		-- Four short arcs avoid tunnelling when the body turns between samples.
		for i=1,4 do
			local a,b=(i-1)/4,i/4
			if Geometry.catchSegment(previousBody:Lerp(body,a):PointToObjectSpace(old:Lerp(root.Position,a)),
				previousBody:Lerp(body,b):PointToObjectSpace(old:Lerp(root.Position,b)),size,r.Config.CatchReach,Config.Catch.VerticalReach) then hit=true break end
		end
		if not hit then continue end
		local character=player.Character
		local dropped=Carry.forceDrop(player, character, "GuardianCatch:"..r.AreaId, true)
		-- Drop reconciliation may have closed the field and reset this encounter.
		-- Do not apply a post-evacuation catch or resurrect its swept-body sample.
		if r.Engine.State~="PURSUING" and r.Engine.State~="COOLDOWN" then return end
		if dropped then
			Catch.apply(player, character, body.Position, body.LookVector, r.AreaId)
			notice(player, ("CAUGHT BY THE %s!\nYOUR RESOURCE WAS KNOCKED LOOSE"):format(string.upper(r.Part:GetAttribute("GuardianName") or "GUARDIAN")))
			r.Part:SetAttribute("CatchTick", time)
		end
		r.Threats[player]=nil
		if r.Target and r.Target.Player==player then r.Target=nil end
	end
	r.CatchBody=body
end
function Service.onPickup(player,id,version)
	local item=Carry.get(player)
	if not item or item.token~=id or player.Parent~=Players then return false end
	local record=ResourceService.getRecord(id)
	-- The owner guardian is the resource's spawn biome; ownership never transfers.
	local r=record and guardians[record.AreaId]
	local root=rootOf(player)
	if not r or not root then return false end
	record=ResourceService.acknowledgePickup(player,id,version)
	if not record then return false end
	local rarity=Resources.get(record.ResourceId).Rarity
	if not Chase.profile(rarity) then return false end
	local time=now()
	remember(r, player, rarity, id, time)
	alert(player, rarity)
	r.Engine:pickup(rarity, time, function(s,t) emit(r,s,t) end)
	publish(r)
	return true
end
function Service.resetAll()
	for _,r in guardians do
		clear(r)
		r.Engine:reset()
		r.Speed=0
		r.Threats={} r.Target=nil r.Initial=nil r.EncounterStart=nil r.AttackTarget=nil r.PendingFrame=nil
		place(r, r.Home, r.HomeFacing)
		publish(r)
	end
	table.clear(attackFree)
	Catch.resetAll()
end
function Service.getSnapshot(areaId)
	local r=guardians[areaId] if not r then return nil end
	local target=r.Target
	return {
		State=r.Engine.State, Disturbance=r.Engine.Disturbance, Activation=r.Engine.Activation,
		Deadline=r.Engine.Deadline, Frame=r.Frame, Kind=r.Config.Kind, Rarity=r.Engine.Rarity,
		TargetUserId=target and target.Player and target.Player.UserId or nil,
		Position=r.Part.Position, Home=r.Home, SafeEntrance=r.Runway.origin+r.Runway.axis*r.Runway.entrance,
		Attempts=r.Attempts or 0,HazardHits=r.HazardHits or 0,WarningAt=r.WarningAt, PursuitSpeed=r.Speed or 0,
	}
end
function Service.getRunway() return runway and table.clone(runway) end
local function boxes()
	local list={}
	local folder=workspace:FindFirstChild("Bases")
	if not folder then return list end
	for _,child in folder:GetChildren() do
		if child:IsA("Model") then
			local cf,size=child:GetBoundingBox()
			table.insert(list,{Center=cf.Position, Size=size})
		elseif child:IsA("BasePart") then
			table.insert(list,{Center=child.Position, Size=child.Size})
		end
	end
	return list
end
local function spans()
	local list={}
	for _,area in Areas.getOrdered() do
		local floor=Zone.findFloor(Zone.getZone(area))
		assert(floor,"Missing guardian floor: "..area.Id)
		local surface=Zone.surface(floor)
		local axis,longHalf,lateral,lateralHalf=Chase.axes(surface)
		table.insert(list,{
			center=floor.Position, axis=axis, longHalf=longHalf, lateral=lateral, lateralHalf=lateralHalf,
			y=(floor.Position+surface.normal*surface.half).Y, floor=floor, area=area,
		})
	end
	return list
end
-- A Studio-owned marker wins; otherwise the floor-edge entrance is used and a runtime,
-- non-collidable boundary volume is generated so the line is visible to tools and tests.
local function studioMarker(generated)
	for _,name in {"ExplorationExit","SafeZoneBoundary"} do
		local found=workspace:FindFirstChild(name,true)
		if found and found:IsA("BasePart") and not found:IsDescendantOf(generated) then return found end
	end
	return nil
end
local function boundaryVolume(parent, lane, lateralHalf)
	local part=Instance.new("Part") part.Name="SafeZoneBoundary"
	part.Anchored=true part.CanCollide=false part.CanTouch=false part.CanQuery=false part.Transparency=1
	part.Size=Vector3.new(2,40,lateralHalf*2)
	local center=lane.origin+lane.axis*lane.entrance
	part.CFrame=CFrame.fromMatrix(Vector3.new(center.X, lane.surfaceY+20, center.Z), lane.axis, Vector3.yAxis, lane.lateral)
	part:SetAttribute("EntranceAlong", lane.entrance)
	part.Parent=parent
	return part
end
local function others(r)
	local list={}
	for _,o in guardians do
		if o~=r and o.Engine.State~="SLEEPING" then table.insert(list,o.Part.Position) end
	end
	return list
end
local function retreat(r, reason)
	if reason then warn(("[GuardianService] %s disengage failsafe: %s"):format(r.AreaId, reason)) end
	return true
end
local function pursue(r, target, goalPos, distance, dt)
	local speed=Chase.speed(r.Engine.Rarity or "Common", r.Config, worstSlowdown(target.Player), distance)
	r.Speed=math.min(speed,(r.Speed or 0)+r.Config.Acceleration*math.clamp(dt,0,.1))
	speed=r.Speed
	local nextPos=Chase.stepToward(r.Part.Position, goalPos, speed, dt, r.Runway)
	nextPos=Chase.separate(nextPos, others(r), Chase.Timing.Spacing, r.Runway, r.Bias)
	place(r, nextPos, goalPos-nextPos)
	return nextPos
end
local function attackFrame(r,target,goal)
	local speed,safety=carrierSpeed(target.Player)
	local threat=r.Threats[target.Player]
	local frame=Aim.frame(r.Runway,r.Config,r.Part.Position,goal,threat and threat.Velocity or Vector3.zero,speed,safety)
	if not frame then return nil end
	-- Reject obstructed attack corridors/landing paths; do not attack through a wall.
	local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude
	local excluded={workspace.GeneratedGameplay}
	for _,p in Players:GetPlayers() do if p.Character then table.insert(excluded,p.Character) end end
	params.FilterDescendantsInstances=excluded params.RespectCanCollide=true
	local destination=if r.Config.Kind=="Shockwave" then frame.Position else frame:PointToWorldSpace(Vector3.new(r.Config.Length/2,0,0))
	destination=Vector3.new(destination.X,r.Part.Position.Y,destination.Z)
	local delta=destination-r.Part.Position
	if delta.Magnitude>0.01 and workspace:Blockcast(r.Part.CFrame,Vector3.new(8,8,8),delta,params) then return nil end
	return frame
end
function Service.start()
	if connection then return end
	local errors=Config.validate() assert(#errors==0,table.concat(errors,"; "))
	Catch.start()
	local root=workspace:FindFirstChild("GeneratedGameplay")
	if not root then root=Instance.new("Folder") root.Name="GeneratedGameplay" root.Parent=workspace end
	local folder=Instance.new("Folder") folder.Name="Guardians" folder.Parent=root
	local floorSpans=spans()
	local bases=boxes()
	local marker=studioMarker(root)
	local entrance=nil
	if marker and floorSpans[1] then entrance=(marker.Position-floorSpans[1].center):Dot(floorSpans[1].axis) end
	runway=Chase.runway(floorSpans, bases, Chase.Timing.SafeMargin, entrance)
	assert(runway,"Guardian runway could not be built")
	if not marker then boundaryVolume(root, runway, floorSpans[1].lateralHalf) end
	local byArea={}
	for _,span in floorSpans do byArea[span.area.Id]=span end
	for index,area in Areas.getOrdered() do
		local span=byArea[area.Id]
		local model=Instance.new("Model") model.Name=area.Guardian model.Parent=folder
		local part=Instance.new("Part") part.Name="Guardian" part.Size=Vector3.new(10,12,18) part.Anchored=true part.CanCollide=false part.CanTouch=false
		local homeFloor, facing=Territory.home(area.Id)
		local home=homeFloor+Vector3.new(0,8,0)
		assert(Chase.horizontal(Chase.clamp(runway, home), home)<0.5 and not Chase.isSafe(runway, home), "Guardian home outside the runway: "..area.Id)
		part.CFrame=CFrame.lookAt(home, home+facing) part.Parent=model model.PrimaryPart=part
		part:SetAttribute("AreaId",area.Id) part:SetAttribute("GuardianName",area.GuardianDisplayName) part:SetAttribute("HazardKind",Config.Areas[area.Id].Kind)
		Metadata:Create(part,{DisplayName=area.GuardianDisplayName,Rarity="Common",ValueText="SLEEPING",ObjectType="Guardian"})
		local r={
			AreaId=area.Id, Part=part, Floor=span.floor, Config=Config.Areas[area.Id], Engine=State.new(Config.Areas[area.Id]),
			Hits={}, Samples={}, LastSample=0, Home=part.Position, HomeFacing=facing, Runway=runway, Bases=bases, Threats={},
			Bias=if index%2==0 then 1 else -1,
		}
		r.Frame=Chase.attackFrame(runway, part.Position, part.Position+runway.axis)
		guardians[area.Id]=r publish(r)
	end
	connection=RunService.Heartbeat:Connect(function(dt)
		local t=now() local field=ResourceService.getSnapshot()
		if field and (field.Phase=="Reset" or t>=field.NextResetAt) then
			for _,r in guardians do
				if r.Engine.State~="SLEEPING" then
					clear(r) r.Engine:reset() r.Threats={} r.Target=nil r.EncounterStart=nil r.AttackTarget=nil r.PendingFrame=nil
					place(r, r.Home, r.HomeFacing) publish(r)
				end
			end
			return
		end
		for _,r in guardians do
			local engine=r.Engine
			if engine.State=="SLEEPING" then continue end
			-- Telegraphed attacks resolve only through their fair lane; body catches apply while chasing.
			if engine.State=="PURSUING" or engine.State=="COOLDOWN" then catchCarriers(r, t)
			else r.CatchBody=nil r.CatchSamples={} end
			local context={attack=false, pursue=false, retreat=false, home=false}
			if t>=(r.NextEval or 0) then
				r.NextEval=t+Chase.Timing.TargetUpdate
				r.Target=Chase.select(candidates(r,t), r.Target, t, r.LockUntil or 0)
			else
				local list=candidates(r,t)
				-- A target that escaped or was hit between evaluations must not make the guardian
				-- abandon another carrier it still threatens.
				if not r.Target and engine.State~="RETURNING" then r.Target=Chase.select(list, nil, t, r.LockUntil or 0) end
			end
			-- Pursuit profile follows the strongest carry still threatened, so a weaker carrier
			-- is never chased at an escaped/dropped/banked carrier's speed.
			local strongest=nil
			for _,threat in r.Threats do strongest=Chase.stronger(strongest, threat.Rarity) end
			if strongest and strongest~=engine.Rarity then engine.Rarity=strongest publish(r) end
			local target=r.Target
			local alive=target and target.Player and target.Player.Parent==Players and r.Threats[target.Player]
			local capped=r.EncounterStart and t-r.EncounterStart>Chase.Timing.SafetyCap
			if engine.State=="PURSUING" then
				if not alive then
					context.retreat=true
				elseif capped then
					context.retreat=retreat(r, "safety cap")
				else
					local goal=rootOf(target.Player)
					local goalPos=if goal then goal.Position else target.Position
					target.Position=goalPos
					local distance=Chase.horizontal(r.Part.Position, goalPos)
					local frame=nil
					if t>=(engine.Deadline or 0) and distance<=r.Config.AttackRange and attackClear(r, target.Player, goalPos, t) then
						frame=attackFrame(r,target,goalPos)
					end
					if frame then
						r.PendingFrame=frame r.AttackTarget=target.Player
						context.attack=true
					else
						local nextPos=pursue(r, target, goalPos, distance, dt)
						if not r.StuckRef or (nextPos-r.StuckRef).Magnitude>Chase.Timing.StuckDistance or distance<=Chase.Timing.AttackCommit*2 then
							r.StuckRef=nextPos r.StuckAt=t
						elseif t-r.StuckAt>Chase.Timing.StuckWindow then
							context.retreat=retreat(r, "stuck")
						end
					end
				end
			elseif engine.State=="WARNING" and r.LeapStart then
				-- A visible, committed leap during the latter warning; never a teleport to a
				-- newly sampled target. Landing and shockwave share the original telegraph.
				local alpha=math.clamp((t-r.WarningAt-.25)/(r.Config.Warning-.25),0,1)
				local landing=Vector3.new(r.Frame.X,r.Home.Y,r.Frame.Z)
				local point=r.LeapStart:Lerp(landing,alpha)+Vector3.yAxis*(4*r.Config.LeapHeight*alpha*(1-alpha))
				place(r,point,landing-r.LeapStart)
			elseif engine.State=="RETURNING" then
				if t>=(r.DisengageUntil or 0) then
					local nextPos=Chase.stepToward(r.Part.Position, r.Home, Chase.Timing.ReturnSpeed, dt, r.Runway)
					nextPos=Chase.separate(nextPos, others(r), Chase.Timing.Spacing, r.Runway, r.Bias)
					place(r, nextPos, r.Home-nextPos)
					if Chase.horizontal(nextPos, r.Home)<=2 then context.home=true end
				end
			elseif engine.State=="HAZARD" and (r.Config.Kind=="Charge" or r.Config.Kind=="Lunge") and engine.HazardStart then
				-- The body rides the lane's leading edge (forward only, runway-clamped) so a
				-- dodged charge still closes ground. Hit geometry stays the world-fixed lane.
				local c=r.Config
				local alpha=math.clamp((t-engine.HazardStart)/c.Active,0,1)
				local leading=-c.Length/2+c.Front+alpha*(c.Length-c.Front)
				local current=r.Frame:PointToObjectSpace(r.Part.Position).X
				local x=math.max(current, leading-r.Part.Size.Z/2)
				if x>current then
					local point=Chase.clamp(r.Runway, r.Frame:PointToWorldSpace(Vector3.new(x,0,0)))
					place(r, Vector3.new(point.X, r.Part.Position.Y, point.Z), r.Frame.XVector)
				end
			elseif engine.State=="COOLDOWN" then
				context.pursue=alive and not capped
				context.retreat=not context.pursue
				-- Brief attack recovery prevents an immediate rotating-body catch from
				-- negating a successful lane dodge. Pursuit resumes for the rest of cooldown.
				if context.pursue and t>=(r.RecoverAt or 0) then
					local goal=rootOf(target.Player)
					local goalPos=if goal then goal.Position else target.Position
					target.Position=goalPos
					pursue(r, target, goalPos, Chase.horizontal(r.Part.Position, goalPos), dt)
				end
			end
			-- If the committed target is gone, cancel rather than release a stale attack.
			if (engine.State=="WARNING" or engine.State=="HAZARD") and (not alive or not r.AttackTarget or not r.Threats[r.AttackTarget]) then
				local replacement=r.Target
				place(r,Vector3.new(r.Part.Position.X,r.Home.Y,r.Part.Position.Z),nil)
				engine:transition("RETURNING",t,function(s,at) emit(r,s,at) end)
				if replacement and r.Threats[replacement.Player] then
					r.Target=replacement engine:transition("PURSUING",t,function(s,at) emit(r,s,at) end)
				end
			else
				engine:step(t, function(s,at) emit(r,s,at) end, function(a,b) sample(r,a,b,t) end, context)
			end
			if engine.State=="PURSUING" or engine.State=="COOLDOWN" then catchCarriers(r,t) end
			if engine.State=="WARNING" or engine.State=="HAZARD" then capture(r,t) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		attackFree[p]=nil
		for _,r in guardians do
			r.Samples[p]=nil r.Hits[p]=nil r.Threats[p]=nil
			if r.Target and r.Target.Player==p then r.Target=nil end
			if r.AttackTarget==p then r.AttackTarget=nil end
			if r.Initial==p then r.Initial=nil end
		end
	end)
end
return Service
