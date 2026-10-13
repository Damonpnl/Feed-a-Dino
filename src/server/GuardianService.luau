--!nonstrict
-- One authoritative framework, five configured hazards. No HP, damage or client hit reports.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.Shared
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Config = require(Shared.GuardianConfig)
local State = require(Shared.GuardianState)
local Geometry = require(Shared.GuardianGeometry)
local Zone = require(script.Parent.ZoneGeometry)
local ResourceService = require(script.Parent.ResourceService)
local Carry = require(script.Parent.CarryService)
local Metadata = require(script.Parent.BillboardMetadataService)
local Service = {}
local guardians, connection = {}, nil
local function now() return workspace:GetServerTimeNow() end
local function publish(r)
	local s=r.Engine
	for key,value in {GuardianState=s.State,Disturbance=s.Disturbance,Activation=s.Activation,StateEndsAt=s.Deadline or 0} do r.Part:SetAttribute(key,value) end
	Metadata:Update(r.Part,{ValueText=s.State.." · "..s.Disturbance.."/100"})
	r.Part.Color=if s.State=="HAZARD" then Color3.fromRGB(240,65,40) elseif s.State=="WARNING" or s.State=="DISTURBED" then Color3.fromRGB(235,175,55) else Color3.fromRGB(90,100,115)
end
local function clear(r)
	for _,name in {"Telegraph","Sweep","Direction"} do if r[name] then r[name]:Destroy() r[name]=nil end end
	r.Hits={} r.Samples={}
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
local function emit(r,state,at)
	if state=="WARNING" then
		clear(r) r.LastSample=at capture(r,at)
		indicator(r,"Telegraph",1,true)
		-- Start-edge strip and arrow clearly communicate sweep direction.
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
		indicator(r,"Sweep",0,false) r.Sweep.Color=Color3.fromRGB(255,60,35)
	elseif state=="COOLDOWN" or state=="SLEEPING" then clear(r) end
	publish(r)
end
local function sample(r,startTime,endTime,currentTime)
	local from=math.max(startTime,r.LastSample)
	if endTime<from then return end
	for _,p in Players:GetPlayers() do
		local c=p.Character local root=c and c:FindFirstChild("HumanoidRootPart") local h=c and c:FindFirstChildOfClass("Humanoid")
		local previous=r.Samples[p]
		if root and h and h.Health>0 and not r.Hits[p] then
			local pos=root.Position
			local old=if previous and previous.Character==c then previous.Position else pos
			local oldTime=if previous and previous.Character==c then previous.Time else currentTime
			local function at(t)
				return old:Lerp(pos,if currentTime>oldTime then math.clamp((t-oldTime)/(currentTime-oldTime),0,1) else 1)
			end
			if Geometry.hit(r.Config,r.Frame,at(from),at(endTime),(from-startTime)/r.Config.Active,(endTime-startTime)/r.Config.Active) then
				r.Hits[p]=true -- once per PLAYER per activation, even after re-acquisition/respawn
				p:SetAttribute("HazardTick",currentTime)
				Carry.forceDrop(p,c,"Guardian:"..r.AreaId)
			end
		end
	end
	r.LastSample=endTime
	indicator(r,"Sweep",math.clamp((endTime-startTime)/r.Config.Active,0,1),false)
end
local function frameAt(r,position)
	local floor=r.Floor local surface=Zone.surface(floor)
	local long,half,cross,crossHalf=surface.u,surface.uHalf,surface.v,surface.vHalf
	if half<crossHalf then long,half,cross,crossHalf=cross,crossHalf,long,half end
	-- Stable orientation along the inspected floor, not a hardcoded world axis.
	if long:Dot(Vector3.xAxis)>0 then long=-long end
	cross=long:Cross(Vector3.yAxis)
	local center=floor.Position+surface.normal*surface.half
	local delta=position-center
	local x=math.clamp(delta:Dot(long),-math.max(0,half-r.Config.Length/2-2),math.max(0,half-r.Config.Length/2-2))
	local z=math.clamp(delta:Dot(cross),-math.max(0,crossHalf-r.Config.Width/2-2),math.max(0,crossHalf-r.Config.Width/2-2))
	return CFrame.fromMatrix(center+long*x+cross*z,long,Vector3.yAxis,cross)
end
function Service.onPickup(player,id,version)
	local item=Carry.get(player)
	if not item or item.token~=id or player.Parent~=Players then return false end
	local record=ResourceService.getRecord(id)
	local r=record and guardians[record.AreaId]
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r or not root then return false end
	record=ResourceService.acknowledgePickup(player,id,version)
	if not record then return false end
	if r.Engine.State=="SLEEPING" or r.Engine.State=="DISTURBED" then r.Frame=frameAt(r,root.Position) end
	r.Engine:pickup(Resources.get(record.ResourceId).Rarity,now(),function(s,t) emit(r,s,t) end)
	publish(r)
	return true
end
function Service.resetAll()
	for _,r in guardians do clear(r) r.Engine:reset() publish(r) end
end
function Service.getSnapshot(areaId)
	local r=guardians[areaId] if not r then return nil end
	return {State=r.Engine.State,Disturbance=r.Engine.Disturbance,Activation=r.Engine.Activation,Deadline=r.Engine.Deadline,Frame=r.Frame,Kind=r.Config.Kind}
end
function Service.start()
	if connection then return end
	local errors=Config.validate() assert(#errors==0,table.concat(errors,"; "))
	local root=workspace:FindFirstChild("GeneratedGameplay")
	if not root then root=Instance.new("Folder") root.Name="GeneratedGameplay" root.Parent=workspace end
	local folder=Instance.new("Folder") folder.Name="Guardians" folder.Parent=root
	for _,area in Areas.getOrdered() do
		local floor=Zone.findFloor(Zone.getZone(area)) assert(floor,"Missing guardian floor: "..area.Id)
		local model=Instance.new("Model") model.Name=area.Guardian model.Parent=folder
		local part=Instance.new("Part") part.Name="Guardian" part.Size=Vector3.new(10,12,18) part.Anchored=true part.CanCollide=false part.CanTouch=false
		part.Position=Zone.guardianPoint(floor) part.Parent=model model.PrimaryPart=part
		part:SetAttribute("AreaId",area.Id) part:SetAttribute("GuardianName",area.GuardianDisplayName) part:SetAttribute("HazardKind",Config.Areas[area.Id].Kind)
		Metadata:Create(part,{DisplayName=area.GuardianDisplayName,Rarity="Common",ValueText="SLEEPING",ObjectType="Guardian"})
		local r={AreaId=area.Id,Part=part,Floor=floor,Config=Config.Areas[area.Id],Engine=State.new(Config.Areas[area.Id]),Hits={},Samples={},LastSample=0}
		r.Frame=frameAt(r,part.Position) guardians[area.Id]=r publish(r)
	end
	connection=RunService.Heartbeat:Connect(function()
		local t=now() local field=ResourceService.getSnapshot()
		-- Never execute a hazard on/after the synchronized field reset deadline.
		if field and (field.Phase=="Reset" or t>=field.NextResetAt) then
			for _,r in guardians do if r.Engine.State~="SLEEPING" then clear(r) r.Engine:reset() publish(r) end end
			return
		end
		for _,r in guardians do
			if r.Engine.State=="WARNING" or r.Engine.State=="HAZARD" or r.Engine.State=="COOLDOWN" then
				r.Engine:step(t,function(s,at) emit(r,s,at) end,function(a,b) sample(r,a,b,t) end)
				if r.Engine.State=="WARNING" or r.Engine.State=="HAZARD" then capture(r,t) end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) for _,r in guardians do r.Samples[p]=nil r.Hits[p]=nil end end)
end
return Service
