-- Opt-in real services on ordinary StudioMemory. All temporary state restored.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Training,Monster=require(S.DataService),require(S.TrainingService),require(S.MonsterService)
local PD,E,T=require(H.PlayerData),require(H.EconomyCalculator),require(H.TrainerDefinitions)
local p=game.Players:GetPlayers()[1]
local data=Data.get(p) local backup=PD.copy(data) local oldStatus=Data.getStatus
local frame=p.Character:GetPivot() local checks=0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function pause() task.wait(0.3) end
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Isolated writable session")
	Training.stop(p)
	data.Monsters={ProtoRex=PD.createMonster("ProtoRex")} data.EquippedMonster="ProtoRex"
	data.TrainerTier=1 data.Power=0 data.BaseUpgrades.TrainingLevel=0
	Monster.publish(p)
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
	local station=base:FindFirstChild("TrainingStation",true)
	local function go() p.Character.HumanoidRootPart.Anchored=true p.Character:PivotTo(station.CFrame+Vector3.new(0,3,0)) end
	go() task.wait(0.2)
	local cash=data.Cash task.wait(2.1)
	check(data.Cash-cash>=1 and data.Cash-cash<=1.5,"One passive income scheduler at starter rate")
	check(data.Power==0,"Idle grants no Power")
	check(Training.train(p,base,station),"Valid start")
	check(data.Power==0,"Start itself grants no reward")
	for _=1,30 do Training.train(p,base,station) end
	task.wait(1.1) check(data.Power==10,"Exactly one server tick despite repeated starts")
	Training.stop(p) local power=data.Power task.wait(1.1) check(data.Power==power,"Stop ends gains")
	pause() go() Training.train(p,base,station)
	p.Character:PivotTo(station.CFrame+Vector3.new(50,3,0)) task.wait(1.1)
	check(data.Power==power and not p:GetAttribute("TrainingActive"),"Leaving stops training")
	check(not Training.train(p,base,station),"Distant start rejected")
	local other for _,b in workspace.Bases:GetChildren() do if b~=base then other=b break end end
	local otherStation=other:FindFirstChild("TrainingStation",true)
	pause() p.Character:PivotTo(otherStation.CFrame+Vector3.new(0,3,0))
	check(not Training.train(p,other,otherStation) and not Training.upgrade(p,other,otherStation,2),"Other base rejects training and purchase")
	go() pause() data.Cash=0
	check(not Training.upgrade(p,base,station,2) and data.TrainerTier==1,"Insufficient Cash keeps tier")
	for _,status in {"LoadFailed","InvalidData","Conflict","StudioReadOnly"} do
		Data.getStatus=function(player) return if player==p then {Status=status,CanSave=false} else oldStatus(player) end
		pause() local c,powerBefore=data.Cash,data.Power
		check(not Training.train(p,base,station) and not Training.upgrade(p,base,station,2),status.." rejects mutations")
		task.wait(1.1) check(data.Cash==c and data.Power==powerBefore,status.." earns nothing")
	end
	Data.getStatus=oldStatus
	go() pause() check(Training.train(p,base,station),"Restart after valid session")
	local originalStation=station local signatures={}
	for tier=1,10 do
		if tier>1 then
			pause() data.Cash=T.getOrdered()[tier].Price
			check(Training.upgrade(p,base,station,tier),"Buy tier "..tier)
			check(data.Cash==0 and data.TrainerTier==tier,"Exact debit tier "..tier)
			pause() local c=data.Cash check(not Training.upgrade(p,base,station,tier) and data.Cash==c,"Replay tier "..tier)
		end
		check(station==originalStation and p:GetAttribute("TrainingActive"),"Upgrade retains training session tier "..tier)
		local visual=station.TrainerVisual local parts=0 local names={}
		for _,v in visual:GetChildren() do
			if v:IsA("BasePart") then parts+=1 table.insert(names,v.Name)
				check(v.Anchored and not v.CanCollide,"Safe placeholder part "..tier) end
		end
		table.sort(names) local signature=table.concat(names,",")
		check(not signatures[signature] and parts<=20 and visual.PrimaryPart~=nil,"Distinct low-part silhouette "..tier) signatures[signature]=true
		check(station.TrainPrompt.Enabled and station.UpgradePrompt.Enabled and visual:GetAttribute("Tier")==tier,"Prompts/renderable model tier "..tier)
		local before=data.Power task.wait(1.1)
		local delta=data.Power-before local gain=E.training(tier,1,0)
		check(delta>=gain and delta<=gain*2,"Active tier "..tier.." grants configured ticks")
	end
	Training.stop(p) pause() data.TrainerTier=1 go()
	check(Training.train(p,base,station),"Start before pet change")
	data.Monsters.ProtoRex=PD.createMonster("Fangling") Monster.publish(p)
	local before=data.Power task.wait(1.1) Training.stop(p)
	check(data.Power-before==15 and p:GetAttribute("IncomePerSecond")==0.75,"Next tick uses evolved pet channels")
	pause() go() Training.train(p,base,station) base:SetAttribute("OwnerUserId",nil) task.wait(0.1)
	check(not p:GetAttribute("TrainingActive"),"Reassignment cancels training") base:SetAttribute("OwnerUserId",p.UserId)
	pause() Training.train(p,base,station) data.Power=9007199254740990 task.wait(1.1) Training.stop(p)
	check(data.Power==9007199254740991,"High Power saturates without overflow")
	pause() Training.train(p,base,station) p.Character.Humanoid.Health=0 task.wait(0.2)
	check(not p:GetAttribute("TrainingActive"),"Death stops training")
	local beforeDeath=data.Power p:LoadCharacterAsync() task.wait(1.2)
	check(data.Power==beforeDeath and not p:GetAttribute("TrainingActive"),"Respawn cannot resume old training")
	check(Data.save(p),"Ordinary memory save succeeds")
	Training.stop(p) local savedCash,savedPower,savedTier=data.Cash,data.Power,data.TrainerTier
	check(Data.release(p),"Session release") Data.load(p) data=Data.get(p)
	check(data.Cash==savedCash and data.Power==savedPower and data.TrainerTier==savedTier,"Same-backend reload preserves Cash Power Tier")
	check(data.Monsters.ProtoRex.EvolutionForm=="Fangling","Pet fields preserved across reload")
end,debug.traceback)
Data.getStatus=oldStatus Training.stop(p)
data=Data.get(p)
for key in data do data[key]=nil end for key,value in backup do data[key]=value end
Monster.publish(p) Data.save(p)
if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5AIntegration] PASS "..checks) else warn(failure) end
