-- Opt-in fresh Studio session. Controlled resource seeding, real services and native UI clicks.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Training,Monster,Feed,Spawn,Resource,Carry,Guardian=require(S.DataService),require(S.TrainingService),require(S.MonsterService),require(S.FeedService),require(S.SpawnService),require(S.ResourceService),require(S.CarryService),require(S.GuardianService)
local PD,State=require(H.PlayerData),require(H.FieldState)
local p=game.Players:GetPlayers()[1] local data=Data.get(p) local backup=PD.copy(data)
local checks,field=0,nil local oldStep=State.step local frame=p.Character:GetPivot()
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,seconds) local untilTime=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>untilTime return false end
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Normal writable memory backend")
	Training.stop(p) data.Cash=0 data.Power=0 data.TrainerTier=1 data.BaseUpgrades.TrainingLevel=0
	data.Monsters={ProtoRex=PD.createMonster("ProtoRex")} data.EquippedMonster="ProtoRex" data.Stats.Feeds=0
	Monster.publish(p)
	State.step=function(self,...) field=self return oldStep(self,...) end
	assert(waitFor(function() return field~=nil end,5)) State.step=oldStep
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
	local point=base:FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	local station=base:FindFirstChild("TrainingStation",true)
	p.Character.HumanoidRootPart.Anchored=true
	local function seed(id)
		task.wait(0.22) assert(field.Phase=="Normal","Run in a fresh field cycle")
		local node=field.Nodes["Grasslands:Node01"]
		if node.RecordId then Resource.releaseToken("Grasslands",node.RecordId) end
		local r=field:create(node,id,"Phase5ALoop") Resource.step()
		for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==r.InstanceId then p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) break end end
		return r.InstanceId
	end
	local id=seed("BoneChunk") check(not Spawn.pickup(p,id) and data.Power==0,"Bone Chunk initially too heavy")
	check(p:GetAttribute("PowerNotice")=="NEED 50 POWER","Authoritative compact requirement")
	for i=1,5 do
		id=seed("RawMeat") check(Spawn.pickup(p,id),"Steal Raw Meat "..i)
		check(Guardian.getSnapshot("Grasslands")~=nil,"Guardian framework remains present")
		p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0))
		local preview=Feed.preview(p,base,host) check(preview.Available,"Feed preview "..i)
		if i==1 then
			game.ReplicatedStorage.Remotes.FeedInteraction:FireClient(p,preview)
			script:SetAttribute("Step","CLICK_FEED")
			check(waitFor(function() return data.Stats.Feeds==1 end,90),"Native FEED click")
		else check(Feed.confirm(p,preview.Ticket),"Feed confirmed "..i) end
		check(not Resource.getRecord(id) and not Carry.get(p) and not Feed.confirm(p,preview.Ticket),"Consume once "..i)
	end
	check(data.Monsters.ProtoRex.EvolutionForm=="Fangling" and data.Monsters.ProtoRex.Flesh==25,"Five feeds evolve same pet")
	check(waitFor(function() return p:GetAttribute("IncomePerSecond")==0.75 end,2),"Evolution improves passive Cash")
	p.Character:PivotTo(station.CFrame+Vector3.new(0,3,0))
	script:SetAttribute("Step","EARN_CASH")
	check(waitFor(function() return data.Cash>=25 end,60),"Earn upgrade Cash naturally, no currency grant")
	script:SetAttribute("Step","CLICK_UPGRADE")
	check(waitFor(function() return data.TrainerTier==2 end,90),"Native upgrade click")
	check(station:GetAttribute("TrainerId")=="WeightedSled","Station visibly upgrades")
	script:SetAttribute("Step","CLICK_TRAIN")
	check(waitFor(function() return p:GetAttribute("TrainingActive")==true end,90),"Native training click")
	check(waitFor(function() return data.Power>=50 end,5),"Training reaches previously missing Power")
	Training.stop(p)
	id=seed("BoneChunk") check(Spawn.pickup(p,id),"Previously inaccessible Bone Chunk now carried")
	check(Carry.get(p).token==id and #Spawn.validate()==0,"Existing resource GUID/uniqueness preserved")
	p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0))
	script:SetAttribute("Step","COMPLETE")
end,debug.traceback)
State.step=oldStep Training.stop(p)
if Carry.get(p) then Carry.forceDrop(p,p.Character,"Phase5A test cleanup") end
for key in data do data[key]=nil end for key,value in backup do data[key]=value end
Monster.publish(p)
if p.Character then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5ALoop] PASS "..checks) else warn(failure) end
