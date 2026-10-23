--!nonstrict
-- Sole Cash/Power scheduler. No per-character reward coroutine or client reward amount.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Data=require(script.Parent.DataService)
local Monster=require(script.Parent.MonsterService)
local Guard=require(script.Parent.InteractionGuard)
local Visuals=require(script.Parent.TrainerVisualService)
local Economy=require(Shared.EconomyCalculator)
local Config=require(Shared.EconomyConfig)
local Evolution=require(Shared.EvolutionCalculator)
local Training={}
local started=false
local training,clocks,stations,connections={},{},{},{}

local function validData(player)
	if not Data.isWritable(player) then return nil end
	local data=Data.get(player)
	if not data or not Economy.finite(data.Cash) or not Economy.finite(data.Power)
		or not Economy.tier(data.TrainerTier) or type(data.BaseUpgrades)~="table"
		or not Economy.finite(data.BaseUpgrades.TrainingLevel) then return nil end
	return data
end
local function rates(player,data)
	local pet=data and data.Monsters[data.EquippedMonster]
	if not pet or not Evolution.valid(pet) then return 0,0,0 end
	local multipliers=Monster.getMultipliers(player)
	return Economy.income(multipliers.IncomeMultiplier),
		Economy.training(data.TrainerTier,multipliers.TrainingMultiplier,data.BaseUpgrades.TrainingLevel),multipliers.TrainingMultiplier
end
local function stationFor(player)
	local name=player:GetAttribute("AssignedBaseName")
	local base=type(name)=="string" and workspace.Bases:FindFirstChild(name)
	return base,base and stations[base]
end
local function validStation(player,base,station)
	return base and station and stations[base]==station and station.Parent
		and Guard.ownedBase(player,base,station,Config.InteractionDistance)
end
function Training.stop(player)
	training[player]=nil
	if player.Parent==Players then player:SetAttribute("TrainingActive",false) end
end
function Training.train(player,base,station)
	if not Guard.allow(player,"Train",0.2) or not validStation(player,base,station) then return false end
	local data=validData(player)
	if not data then player:SetAttribute("StatusMessage","Player data is not writable or economy state is invalid") return false end
	local _,gain=rates(player,data)
	if gain<=0 or training[player] then return false end
	training[player]={Data=data,Character=player.Character,Base=base,Station=station,Progress=0}
	player:SetAttribute("TrainingActive",true)
	player:SetAttribute("StatusMessage","Training Power · leave the station or press STOP")
	return true
end
function Training.upgrade(player,base,station,target)
	if not Guard.allow(player,"Upgrade",0.25) or not validStation(player,base,station) then return false end
	local data=validData(player)
	if not data then player:SetAttribute("StatusMessage","Player data is not writable or economy state is invalid") return false end
	local cash,message=Economy.purchase(data.Cash,data.TrainerTier,target)
	if cash==nil then player:SetAttribute("StatusMessage",message) return false end
	-- No yield. Target tier is the expected version; replay cannot buy the next tier.
	data.Cash,data.TrainerTier=cash,target
	Data.publish(player)
	player:SetAttribute("TrainerTier",target)
	player:SetAttribute("StatusMessage",message)
	local ok=pcall(Visuals.update,station,target)
	if not ok then warn("[TrainingService] Trainer purchased; visual refresh will retry") end
	return true
end
function Training.request(player,action,target)
	if not Guard.allow(player,"TrainingRemote",0.15) then return false end
	local base,station=stationFor(player)
	if action=="Stop" then Training.stop(player) return true end
	if action=="Start" then return Training.train(player,base,station) end
	if action=="Upgrade" then return Training.upgrade(player,base,station,target) end
	return false
end
local function step(dt)
	for _,player in Players:GetPlayers() do
		local data=validData(player)
		local income,gain,petMultiplier=rates(player,data)
		local state=training[player]
		if state and (not data or state.Data~=data or state.Character~=player.Character
			or not validStation(player,state.Base,state.Station) or gain<=0) then Training.stop(player) state=nil end
		player:SetAttribute("IncomePerSecond",income)
		player:SetAttribute("TrainingGainPerSecond",gain)
		player:SetAttribute("ActivePetTrainingMultiplier",petMultiplier)
		if not data then clocks[player]=nil continue end
		player:SetAttribute("TrainerTier",data.TrainerTier)
		local clock=clocks[player]
		if not clock or clock.Data~=data then clock={Data=data,Progress=0} clocks[player]=clock end
		local cashTick=false
		if income>0 then clock.Progress,cashTick=Economy.advance(clock.Progress,dt) else clock.Progress=0 end
		local powerTick=false
		if state then state.Progress,powerTick=Economy.advance(state.Progress,dt) end
		if cashTick then data.Cash=Economy.add(data.Cash,income) end
		if powerTick then
			data.Power=Economy.add(data.Power,gain)
			if Economy.finite(data.Stats.Trainings) then data.Stats.Trainings=Economy.add(data.Stats.Trainings,1) end
		end
		if cashTick or powerTick then Data.publish(player) end
	end
	for base,station in stations do
		local owner=Players:GetPlayerByUserId(base:GetAttribute("OwnerUserId") or 0)
		local data=owner and Data.get(owner)
		local tier=if data and Economy.tier(data.TrainerTier) then data.TrainerTier else 1
		Visuals.update(station,tier)
	end
end
local function hook(player)
	if connections[player] then return end
	connections[player]={
		player.CharacterRemoving:Connect(function(character)
			if training[player] and training[player].Character==character then Training.stop(player) end
		end),
		player:GetAttributeChangedSignal("AssignedBaseName"):Connect(function() Training.stop(player) end),
	}
end
function Training.start()
	if started then return end
	started=true
	local remotes=game.ReplicatedStorage:WaitForChild("Remotes")
	local remote=remotes:FindFirstChild("TrainingInteraction")
	if not remote then remote=Instance.new("RemoteEvent") remote.Name="TrainingInteraction" remote.Parent=remotes end
	remote.OnServerEvent:Connect(Training.request)
	for _,base in workspace:WaitForChild("Bases"):GetChildren() do
		if not base:IsA("Model") then continue end
		local spawn=base:FindFirstChild("PlayerSpawn",true)
		if not spawn or not spawn:IsA("BasePart") then warn("[TrainingService] Missing PlayerSpawn: "..base.Name) continue end
		local station=base:FindFirstChild("TrainingStation",true)
		if not station then
			local placement=Visuals.stationCFrame(spawn)
			if not placement then warn("[TrainingService] No safe ground at "..base.Name) continue end
			station=Instance.new("Part") station.Name="TrainingStation"
			station.Anchored=true station.CanCollide=false station.CanTouch=false
			station.Size=Vector3.new(6,0.3,6)
			station.Color=Color3.fromRGB(100,140,160)
			station.CFrame=placement
			station.Parent=spawn.Parent
		end
		stations[base]=station
		local train=Instance.new("ProximityPrompt")
		train.Name="TrainPrompt" train.ActionText="Start / Stop training"
		train.RequiresLineOfSight=false train.MaxActivationDistance=10 train.Parent=station
		train.Triggered:Connect(function(player)
			if not validStation(player,base,station) then return end
			if training[player] then Training.stop(player) else Training.train(player,base,station) end
		end)
		local shop=Instance.new("ProximityPrompt")
		shop.Name="UpgradePrompt" shop.ActionText="Trainer shop" shop.KeyboardKeyCode=Enum.KeyCode.F
		shop.RequiresLineOfSight=false shop.MaxActivationDistance=10 shop.UIOffset=Vector2.new(0,40) shop.Parent=station
		shop.Triggered:Connect(function(player)
			if Guard.allow(player,"TrainerShop",0.3) and validStation(player,base,station) then remote:FireClient(player,"Shop") end
		end)
		base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			for player,state in training do if state.Base==base then Training.stop(player) end end
		end)
		Visuals.update(station,1)
	end
	Players.PlayerAdded:Connect(hook)
	for _,player in Players:GetPlayers() do hook(player) end
	Players.PlayerRemoving:Connect(function(player)
		Training.stop(player) clocks[player]=nil
		for _,connection in connections[player] or {} do connection:Disconnect() end
		connections[player]=nil
	end)
	RunService.Heartbeat:Connect(step)
end
return Training
