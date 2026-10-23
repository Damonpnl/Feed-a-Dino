-- Opt-in Studio-only test of real services; no cloud access or persisted fixture data.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local Server=game.ServerScriptService.Server
local Data=require(Server.DataService)
local Spawn=require(Server.SpawnService)
local Carry=require(Server.CarryService)
local Feed=require(Server.FeedService)
local Training=require(Server.TrainingService)
local Monster=require(Server.MonsterService)
local Resource=require(Server.ResourceService)
local Shared=game.ReplicatedStorage.Shared
local PlayerData=require(Shared.PlayerData)
local Resources=require(Shared.ResourceDefinitions)
local Trainers=require(Shared.TrainerDefinitions)
local Economy=require(Shared.EconomyCalculator)
local player,original,frame,checks=nil,nil,nil,0
local originalStatus=Data.getStatus
local function check(value,message) assert(value,message) checks+=1 end
local function go(part) player.Character:PivotTo(part.CFrame+Vector3.new(0,3,0)) end
local function selectPickup()
	for id,record in Spawn.getSnapshot().Records do
		if record.State=="AVAILABLE" and record.AreaId=="Grasslands" then
			for _,model in workspace.GeneratedGameplay.Resources:GetChildren() do
				if model:GetAttribute("ResourceInstanceId")==id then return id,record,model.PrimaryPart end
			end
		end
	end
	error("No Grasslands pickup")
end
local ok,failure=xpcall(function()
	repeat task.wait() player=game.Players:GetPlayers()[1] until player and player.Character and Data.get(player) and player:GetAttribute("AssignedBaseName")
	local data=Data.get(player) original=PlayerData.copy(data) frame=player.Character:GetPivot()
	check(Data.getStatus(player).Backend=="StudioMemory" and Data.isWritable(player),"Studio writable memory isolation")
	check(Data.save(player),"Studio save uses the memory backend")
	local leaderstats=0 for _,child in player:GetChildren() do if child.Name=="leaderstats" then leaderstats+=1 end end
	check(leaderstats==1 and not player.leaderstats:FindFirstChild("Meat"),"Exactly one authoritative leaderstats")
	local base=workspace.Bases:FindFirstChild(player:GetAttribute("AssignedBaseName"))
	check(base and base:GetAttribute("OwnerUserId")==player.UserId,"Base assigned to player")
	local point=base:FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	local station=base:FindFirstChild("TrainingStation",true)
	local other for _,b in workspace.Bases:GetChildren() do if b~=base then other=b break end end
	local otherStation=other:FindFirstChild("TrainingStation",true)
	go(otherStation) check(not Training.train(player,other,otherStation),"Cannot train at unowned base")
	task.wait(0.81) player.Character:PivotTo(station.CFrame+Vector3.new(100,5,0))
	check(not Training.train(player,base,station),"Remote-distance training rejected")
	task.wait(0.81) go(station) local before=data.Power
	local expected=Economy.training(data.TrainerTier,Monster.getMultiplier(player),data.BaseUpgrades.TrainingLevel)
	check(Training.train(player,base,station),"Valid training accepted")
	task.wait(1.1) Training.stop(player)
	check(data.Power==before+expected,"Server calculated training gain")
	Training.train(player,base,station)
	check(not Training.train(player,base,station) and data.Power==before+expected,"Training spam cannot reward twice") Training.stop(player)
	data.Cash=0 check(not Training.upgrade(player,base,station,data.TrainerTier+1),"Insufficient Cash rejected")
	task.wait(0.26) data.Cash=1000 local tier=data.TrainerTier local cost=Trainers.getOrdered()[tier+1].Price
	check(Training.upgrade(player,base,station,tier+1),"Valid upgrade accepted")
	check(data.Cash==1000-cost and data.TrainerTier==tier+1,"Server calculated upgrade debit")
	check(not Training.upgrade(player,base,station,tier+1) and data.Cash==1000-cost,"Upgrade spam cannot debit twice")
	local id,record,part=selectPickup()
	data.Power=Resources.get(record.ResourceId).PowerRequired
	player.Character:PivotTo(part.CFrame+Vector3.new(100,5,0))
	check(not Spawn.pickup(player,id) and Resource.getRecord(id).State=="AVAILABLE","Far pickup rejected without consuming item")
	task.wait(0.16) go(part)
	check(Spawn.pickup(player,id),"Valid resource pickup")
	check(not Carry.give(player,"RawMeat","Grasslands","forged"),"Forged ownership rejected")
	check(not Feed.feed(player,base,host),"Far feeding rejected")
	check(Resource.owned(player,id) and Carry.get(player).token==id,"Rejected feed preserves ownership")
	local copy=Resource.getRecord(id) copy.OwnerUserId=0
	check(Resource.owned(player,id),"Read snapshot cannot mutate resource owner")
	task.wait(0.21) go(host)
	data.Monsters={ProtoRex=PlayerData.createMonster("ProtoRex")} data.EquippedMonster="ProtoRex"
	local feeds=data.Stats.Feeds
	-- Failure-state guards remain required even though ordinary Studio is writable.
	Data.getStatus=function(p) return if p==player then {Status="LoadFailed",CanSave=false,Closing=false} else originalStatus(p) end
	check(not Feed.feed(player,base,host),"Phase4A rejects read-only feeding without consuming")
	task.wait(0.21)
	-- Test-only writable status over disposable Studio data; production storage remains disabled.
	Data.getStatus=function(p) return if p==player then {Status="Missing",CanSave=true,Closing=false} else originalStatus(p) end
	check(Feed.feed(player,base,host),"Valid owned feed accepted")
	check(data.Monsters.ProtoRex.Growth==Resources.get(record.ResourceId).Growth,"Server definition sets growth")
	check(data.Stats.Feeds==feeds+1 and not Carry.get(player) and not Resource.getRecord(id),"Feed consumes exactly one GUID")
	check(not Feed.feed(player,base,host) and data.Stats.Feeds==feeds+1,"Duplicate feed cannot reward")
	local owned=PlayerData.createMonster("Fangling") owned.Growth=71 data.Monsters.Fangling=owned
	check(not Monster.evolve(player,"Fangling"),"Owned evolution target cannot be overwritten")
	check(data.Monsters.Fangling==owned and owned.Growth==71 and data.Monsters.ProtoRex~=nil,"Both owned records preserved")
	check(#Spawn.validate()==0,"Authoritative ownership remains consistent")
	id,record,part=selectPickup() data.Power=Resources.get(record.ResourceId).PowerRequired
	task.wait(0.16) go(part) check(Spawn.pickup(player,id),"Pickup before character reset")
	player:LoadCharacterAsync()
	-- CharacterRemoving listeners may be deferred until the next scheduler resumption.
	local deadline=os.clock()+5
	repeat task.wait() until not Carry.get(player) or os.clock()>=deadline
	check(not Carry.get(player),"Character reset clears carry state")
	check(Resource.getRecord(id)==nil or Resource.getRecord(id).State=="DROPPED","Reset leaves no ghost carried owner")
	check(#Spawn.validate()==0,"Post-reset record/world consistency")
	task.wait(0.2)
	check(player:GetAttribute("AssignedBaseName")==base.Name and base:GetAttribute("OwnerUserId")==player.UserId,"Respawn keeps one base assignment")
end,debug.traceback)
Data.getStatus=originalStatus
if player then Training.stop(player) end
if player and Data.get(player) and original then
	local data=Data.get(player) for key in data do data[key]=nil end for key,value in original do data[key]=value end
	Monster.publish(player)
end
if player and player.Character and frame then player.Character:PivotTo(frame) end
if player then local held=Carry.consume(player) if held then Resource.releaseToken(held.areaId,held.token) end end
script:SetAttribute("Result",if ok then "PASS" else failure)
script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase1Integration] PASS "..checks.." checks") else warn("[Phase1Integration] "..failure) end
