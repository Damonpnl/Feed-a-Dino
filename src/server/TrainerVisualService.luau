--!nonstrict
-- Runtime-only grayboxes; the interaction part remains stable through upgrades.
local Trainers=require(game.ReplicatedStorage.Shared.TrainerDefinitions)
local Rarities=require(game.ReplicatedStorage.Shared.RarityDefinitions)
local Visuals={}
function Visuals.stationCFrame(spawn)
	-- The legacy +10 offset is inside the saved FeedingPoint platform. +20 is
	-- the clear apron beside each of the four inspected bases, not a map edit.
	local position=spawn.Position+Vector3.new(20,0,0)
	local exclude={}
	local generated=workspace:FindFirstChild("GeneratedGameplay")
	if generated then table.insert(exclude,generated) end
	for _,player in game.Players:GetPlayers() do if player.Character then table.insert(exclude,player.Character) end end
	local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances=exclude
	local hit=workspace:Raycast(position+Vector3.new(0,50,0),Vector3.new(0,-100,0),params)
	if not hit or hit.Normal.Y<0.9 then return nil end
	return CFrame.new(position.X,hit.Position.Y+0.15,position.Z)
end
function Visuals.update(station, tier)
	local definition=assert(Trainers.getOrdered()[tier],"Unknown trainer tier")
	if station:GetAttribute("TrainerTier")==tier and station:FindFirstChild("TrainerVisual") then return end
	local model=Instance.new("Model") model.Name="TrainerVisual"
	local function block(name,x,y,z,sx,sy,sz,shape)
		local p=Instance.new("Part") p.Name=name p.Size=Vector3.new(sx,sy,sz)
		p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
		p.Material=Enum.Material.SmoothPlastic
		p.Color=if name=="Core" then Rarities.getColor(definition.Rarity) else Color3.fromRGB(115+tier*5,120+tier*4,125+tier*3)
		p.Shape=shape or Enum.PartType.Block p.CFrame=station.CFrame*CFrame.new(x,y,z) p.Parent=model
		if not model.PrimaryPart then model.PrimaryPart=p end
		return p
	end
	-- Equipment behind the pad leaves the same 6x6 interaction clearance in front.
	block("Platform",0,0,5,7,0.3,4)
	if tier==1 then
		block("Mat",0,0.3,5,5,0.25,3)
	elseif tier==2 then
		for _,x in {-2,2} do block("Runner",x,0.5,5,0.4,0.4,4) end
		block("Sled",0,0.8,5,4.5,0.4,3) block("Weights",0,1.5,5,2.5,1,2)
		block("Handle",0,2,3.5,4,0.3,0.3)
	elseif tier<=5 then
		for _,x in {-2.7,2.7} do block("Upright",x,3,4,0.5,6,0.5) end
		block("Barbell",0,3.2,3.8,6,0.3,0.3)
		for _,x in {-2.2,2.2} do block("Weight",x,3.2,3.8,0.6,1.8,1.8) end
		if tier>=4 then
			for _,x in {-2.7,2.7} do block("RearPost",x,3,6,0.5,6,0.5) block("TopRail",x,6,5,0.5,0.4,2.5) end
			block("Crossbar",0,6,4,6,0.4,0.4)
		end
		if tier==5 then block("Bench",0,1.3,5,2,0.5,3) block("Crown",0,6.6,5,2.5,0.7,1) end
	elseif tier==6 then
		for _,x in {-2.5,2.5} do block("ChamberWall",x,3.3,5,0.5,6.6,4) end
		block("Roof",0,6.8,5,5.5,0.5,4) block("Core",0,3.7,5,2,2,2,Enum.PartType.Ball)
	elseif tier==7 then
		block("Core",0,3.7,5,3,3,3,Enum.PartType.Ball)
		for _,angle in {0,math.pi/2} do for i=1,8 do
			local p=block("Orbit",0,0,5,0.4,1.8,0.4)
			p.CFrame=station.CFrame*CFrame.new(0,3.7,5)*CFrame.Angles(0,angle,i*math.pi/4)*CFrame.new(2.6,0,0)
		end end
	elseif tier==8 then
		for _,x in {-2.5,2.5} do block("Obelisk",x,4,5,1,8,1) end
		block("Lintel",0,7,5,5,1,1) block("Core",0,4,5,2,4,1,Enum.PartType.Ball)
	elseif tier==9 then
		block("Forge",0,1.8,5,5,3.5,3) block("Core",0,2,3.4,2.5,1.6,0.2)
		block("Chimney",1.7,5,5,1.2,4,1.2) block("Anvil",-1,4,5,3,0.5,1.4)
	else
		block("Pedestal",0,1.2,5,3,2,3) block("Core",0,4,5,3,3,3,Enum.PartType.Ball)
		for _,x in {-1,1} do local wing=block("Wing",x*2.7,4.5,5,1,4,2) wing.CFrame*=CFrame.Angles(0,0,-x*0.45) end
		block("Crown",0,7,5,4,0.5,1)
	end
	model:SetAttribute("TrainerId",definition.Id) model:SetAttribute("Tier",tier)
	local previous=station:FindFirstChild("TrainerVisual")
	if previous then previous:Destroy() end -- Only this service's replaceable runtime model.
	model.Parent=station station:SetAttribute("TrainerTier",tier) station:SetAttribute("TrainerId",definition.Id)
	for _,p in station:GetChildren() do if p:IsA("ProximityPrompt") then p.ObjectText=definition.DisplayName end end
end
return Visuals
