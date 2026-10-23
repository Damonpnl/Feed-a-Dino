-- Opt-in Studio-only real-service transactions. Fixture rules are restored on exit.
assert(game:GetService("RunService"):IsStudio())
local S,H=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Feed,Carry,Resource,Spawn,Guardian,Monster=require(S.DataService),require(S.FeedService),require(S.CarryService),require(S.ResourceService),require(S.SpawnService),require(S.GuardianService),require(S.MonsterService)
local PD,State,C,D,R,E=require(H.PlayerData),require(H.FieldState),require(H.PetProgressionConfig),require(H.MonsterDefinitions),require(H.PetRarity),require(H.EvolutionCalculator)
local p=game.Players:GetPlayers()[1] local data=Data.get(p) local backup=PD.copy(data)
local oldStep,oldConsume,oldResolve=State.step,Carry.consumeOwned,R.resolve
local edge=D.get("ProtoRex").Evolutions[1] local oldRule=edge.RarityRule
local field,frame local checks=0
local function check(v,message) assert(v,message) checks+=1 script:SetAttribute("PassedChecks",checks) end
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Ordinary Studio session writable")
	State.step=function(self,...) field=self return oldStep(self,...) end
	local deadline=os.clock()+5 repeat task.wait(0.05) until field or os.clock()>deadline
	State.step=oldStep assert(field)
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")] local point=base:FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	frame=p.Character:GetPivot() p.Character.HumanoidRootPart.Anchored=true data.Power=1e12
	local function home() p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) end
	local function acquire(id)
		task.wait(0.22) Guardian.resetAll() assert(field.Phase=="Normal")
		local def=require(H.ResourceDefinitions).get(id) local node=field.Nodes[def.Area..":Node01"]
		if node.RecordId then Resource.releaseToken(def.Area,node.RecordId) end
		local r=field:create(node,id,"Phase4DTest") Resource.step()
		for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do
			if m:GetAttribute("ResourceInstanceId")==r.InstanceId then p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) break end
		end
		assert(Spawn.pickup(p,r.InstanceId)) home() return r.InstanceId
	end
	local function starter()
		local r=PD.createMonster("ProtoRex") r.PetId="4d-owned-pet" r.Growth=45 r.TotalGrowth=45 r.Flesh=45
		data.Monsters.ProtoRex=r data.EquippedMonster="ProtoRex" return r
	end
	-- An actual Divine resource does not set pet rarity, stage five or Awakening.
	starter() local id=acquire("InfernoCatalyst") local preview=Feed.preview(p,base,host)
	check(preview.Available and Feed.confirm(p,preview.Ticket),"Divine feed succeeds")
	local r=data.Monsters.ProtoRex
	check(r.Rarity=="Common" and r.Stage==1 and not r.Awakened,"Independent rarity/stage/Awakening")
	check(r.EvolutionHistory[1].RarityAfter=="Common" and r.PetId=="4d-owned-pet","Accepted rarity stored with same identity")
	check(not Resource.getRecord(id) and not Feed.confirm(p,preview.Ticket),"GUID and rarity cannot replay")
	-- Fixture-only probability tests the actual server ticket cache across consume failure.
	C.RarityRules.Phase4DFixture={Enabled=true,Tiers=1,Chance=0.5} edge.RarityRule="Phase4DFixture"
	starter() id=acquire("RawMeat") preview=Feed.preview(p,base,host)
	local draws={} R.resolve=function(record,rule,nextNumber)
		return oldResolve(record,rule,function() local value=nextNumber() table.insert(draws,value) return value end)
	end
	Carry.consumeOwned=function() return false end
	check(not Feed.confirm(p,preview.Ticket) and Resource.owned(p,id),"Failed consumption retains original GUID")
	check(data.Monsters.ProtoRex.Rarity=="Common" and data.Monsters.ProtoRex.Stage==0,"No partial promotion")
	local ticket=draws[1] check(type(ticket)=="number","Actual server rarity ticket sampled")
	Carry.consumeOwned=oldConsume preview=Feed.preview(p,base,host) draws={}
	local wins=0 for _=1,20 do task.spawn(function() if Feed.confirm(p,preview.Ticket) then wins+=1 end end) end
	check(wins==1 and draws[1]==ticket and #draws==1,"Concurrent retry consumes once and reuses ticket")
	r=data.Monsters.ProtoRex check(r.Rarity==(if ticket<0.5 then "Uncommon" else "Common"),"Accepted result matches authoritative ticket")
	check(r.EvolutionHistory[1].RarityAfter==r.Rarity and not Feed.confirm(p,preview.Ticket),"Result and history cannot reroll")
	R.resolve=oldResolve edge.RarityRule=oldRule C.RarityRules.Phase4DFixture=nil
	-- Huge progress plus launch catalyst flags still cannot obtain unreleased prestige.
	r=PD.createMonster("AscendedRex") r.Growth=1e9 r.TotalGrowth=1e9 r.Rarity="Divine"
	r.EvolutionFamilies.Inferno=true r.LatentTraits.Inferno=true data.Monsters.ProtoRex=r
	id=acquire("RawMeat") preview=Feed.preview(p,base,host)
	check(preview.Available and Feed.confirm(p,preview.Ticket),"Stage four still accepts ordinary Growth")
	r=data.Monsters.ProtoRex check(r.Stage==4 and not r.Awakened and r.Growth+r.GrowthReserve==1e9+5,"No prestige shortcut or lost progress")
	check(p:GetAttribute("AscensionState")=="Locked" and p:GetAttribute("Awakened")==false,"Server publishes locked prestige separately")
	check(p:GetAttribute("TrainingMultiplier")==2.5 and p:GetAttribute("IncomeMultiplier")==2.5,"Unchanged authoritative multiplier metadata")
	r.PendingEvolution={Token="forged",Source="AscendedRex",Stage=4,Revision=r.Revision,Candidates={"AscendedRex:MythicRex"}}
	check(not Monster.chooseEvolution(p,{PetKey="ProtoRex",Token="forged",BranchId="AscendedRex:MythicRex",Rarity="Divine"}),"Forged prestige choice rejected")
	r.PendingEvolution=nil
	check(Data.save(p),"Existing memory persistence saves new fields")
	check(#Spawn.validate()==0,"No duplicate world state")
end,debug.traceback)
State.step,Carry.consumeOwned,R.resolve=oldStep,oldConsume,oldResolve
edge.RarityRule=oldRule C.RarityRules.Phase4DFixture=nil
if Carry.get(p) then Carry.forceDrop(p,p.Character,"4D fixture cleanup") end
for key in data do data[key]=nil end for key,value in backup do data[key]=value end
Data.save(p) Monster.publish(p)
if frame and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase4DIntegration] PASS "..checks) else warn(failure) end
