-- Opt-in Studio fixture only. Real services/world GUIDs; injected in-memory SessionStore.
-- Explicitly seeds runtime field records, never catalog weights or production saves.
assert(game:GetService("RunService"):IsStudio())
local S,Shared=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Feed,Carry,Resource,Spawn,Guardian,Monster=require(S.DataService),require(S.FeedService),require(S.CarryService),require(S.ResourceService),require(S.SpawnService),require(S.GuardianService),require(S.MonsterService)
local PD,State,Effects,Store=require(Shared.PlayerData),require(Shared.FieldState),require(Shared.ResourceEffects),require(S.SessionStore)
local p=game.Players:GetPlayers()[1]
local oldGet,oldStatus,oldStep,oldApply,oldConsume=Data.get,Data.getStatus,State.step,Effects.apply,Carry.consumeOwned
local saved local session=Store.new({get=function() return PD.copy(saved) end,update=function(_,fn) saved=fn(saved) return PD.copy(saved) end})
local field,overrideStatus,base,host,frame
local checks=0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function current() return session:get("phase4c-fixture") end
local function home() p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) end
local function acquire(resourceId)
	task.wait(0.22) Guardian.resetAll()
	assert(field.Phase=="Normal","Run fixture outside reset")
	local d=require(Shared.ResourceDefinitions).get(resourceId)
	local node=field.Nodes[d.Area..":Node01"]
	if node.RecordId then Resource.releaseToken(d.Area,node.RecordId) end
	local r=field:create(node,resourceId,"Phase4CTest") Resource.step()
	local model for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==r.InstanceId then model=m end end
	assert(model,"Seeded world visual") p.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0))
	assert(Spawn.pickup(p,r.InstanceId),"Real pickup") home() return r.InstanceId
end
local ok,failure=xpcall(function()
	State.step=function(self,...) field=self return oldStep(self,...) end
	local deadline=os.clock()+5 repeat task.wait(0.05) until field or os.clock()>deadline
	State.step=oldStep assert(field,"Capture runtime fixture state")
	base=workspace.Bases[p:GetAttribute("AssignedBaseName")] local point=base:FindFirstChild("FeedingPoint",true)
	host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	frame=p.Character:GetPivot() p.Character.HumanoidRootPart.Anchored=true
	local data=session:load("phase4c-fixture") data.Power=1e12
	Data.get=function(player) return if player==p then current() else oldGet(player) end
	Data.getStatus=function(player) return if player==p then overrideStatus or session:status("phase4c-fixture") else oldStatus(player) end
	for id,family in {PrimalCatalyst="Primal",ToxicCatalyst="Toxic",JungleHeart="Beast",CrystalCatalyst="Crystal",FireCore="Fire",DragonBlood="Draconic",InfernoCatalyst="Inferno"} do
		data.Monsters.ProtoRex=PD.createMonster("ProtoRex") data.Monsters.ProtoRex.PetId="retained-pet-guid"
		local guid=acquire(id) local before=data.Stats.Feeds local preview=Feed.preview(p,base,host)
		check(preview.Available and preview.ResourceInstanceId==guid,id.." previews existing GUID")
		local wins=0 for _=1,20 do task.spawn(function() if Feed.confirm(p,preview.Ticket) then wins+=1 end end) end
		check(wins==1 and data.Stats.Feeds==before+1,id.." concurrent confirmation once")
		local r=data.Monsters.ProtoRex
		check(r.EvolutionFamilies[family] and r.LatentTraits[family] and r.SpecialEvolutions[family],id.." persisted effects")
		check(r.TotalGrowth==require(Shared.ResourceDefinitions).get(id).Growth and r.Stage<=1 and r.PetId=="retained-pet-guid",id.." exact growth and one stage")
		check(not Carry.get(p) and not Resource.getRecord(guid) and not Feed.confirm(p,preview.Ticket),id.." GUID consumed once")
		check(session:release("phase4c-fixture"),id.." save release") data=session:load("phase4c-fixture")
		check(data.Monsters.ProtoRex.EvolutionFamilies[family] and data.Monsters.ProtoRex.LatentTraits[family],id.." reload flags")
	end
	data.Monsters.ProtoRex=PD.createMonster("ProtoRex") local r=data.Monsters.ProtoRex local guid=acquire("PrimalCatalyst")
	r.Lineage="Other" check(not Feed.preview(p,base,host).Available and Resource.owned(p,guid),"Incompatible catalyst retained") r.Lineage="ProtoRex"
	for _,state in {"LoadFailed","InvalidData","StudioReadOnly","Conflict"} do
		overrideStatus={Status=state,CanSave=false,Closing=false} check(not Feed.preview(p,base,host).Available and Resource.owned(p,guid),state.." keeps catalyst")
	end overrideStatus=nil
	home() local preview=Feed.preview(p,base,host)
	p.Character:PivotTo(host.CFrame+Vector3.new(100,3,0)) check(not Feed.confirm(p,preview.Ticket) and Resource.owned(p,guid),"Moved confirmation retains item") home()
	preview=Feed.preview(p,base,host) r.LatentTraits.Test=true
	check(not Feed.confirm(p,preview.Ticket) and Resource.owned(p,guid),"Changed latent snapshot invalidates ticket")
	Carry.forceDrop(p,p.Character,"Fixture") Resource.releaseToken("Grasslands",guid)
	data.Monsters.ProtoRex=PD.createMonster("ProtoRex") guid=acquire("MutantLeech")
	local draws={} Effects.apply=function(record,definition,nextNumber)
		return oldApply(record,definition,function() local value=nextNumber() table.insert(draws,value) return value end)
	end
	preview=Feed.preview(p,base,host) draws={}
	Carry.consumeOwned=function() return false end
	check(not Feed.confirm(p,preview.Ticket) and Resource.owned(p,guid) and data.Monsters.ProtoRex.TotalGrowth==0,"Failed consume retains item and rewards")
	Carry.consumeOwned=oldConsume local first=draws[1]
	preview=Feed.preview(p,base,host) draws={}
	check(Feed.confirm(p,preview.Ticket) and draws[1]==first,"Retry reuses actual server RNG ticket")
	check(not Feed.confirm(p,preview.Ticket) and #draws==1,"Replay cannot roll again") Effects.apply=oldApply
	check(#Spawn.validate()==0,"World resource uniqueness after all feeds")
	check(p:GetAttribute("LatentTraits")~=nil,"Monster publishes catalyst state")
	-- Real special-form transactions and presentation, including a competing hybrid choice.
	for _,row in {
		{"PrimalCatalyst","Fangling","PrimalRex","Flesh"},
		{"ToxicCatalyst","Mossback","ToxicRex","Flora"},
		{"JungleHeart","Fangling","AlphaRex","Flesh"},
		{"CrystalCatalyst","Stonehide","CrystalWolf","Mineral"},
		{"FireCore","Fangling","MagmaRex","Flesh"},
		{"DragonBlood","Fangling","DraconicRex","Flesh"},
		{"InfernoCatalyst","Fangling","InfernoRex","Flesh"},
	} do
		local pet=PD.createMonster(row[2]) pet.PetId="special-owned-guid"
		pet.Growth=50 pet.TotalGrowth=50 pet[row[4]]=80
		if row[1]=="DragonBlood" then pet.Mineral=80 end
		data.Monsters.ProtoRex=pet data.EquippedMonster="ProtoRex"
		local id=acquire(row[1]) local plan=Feed.preview(p,base,host)
		check(plan.Available and Feed.confirm(p,plan.Ticket),row[1].." eligible special feed")
		local result=data.Monsters.ProtoRex
		if result.PendingEvolution then
			task.wait(0.22)
			assert(Monster.chooseEvolution(p,{PetKey="ProtoRex",Token=result.PendingEvolution.Token,BranchId=row[2]..":"..row[3]}),"Choose authored special branch")
			result=data.Monsters.ProtoRex
		end
		check(result.Stage==2 and result.EvolutionForm==row[3] and result.PetId=="special-owned-guid",row[3].." preserves identity and one stage")
		local visual=workspace.GeneratedGameplay.Monsters[p.Name.."_Monster"]
		check(visual:GetAttribute("EvolutionForm")==row[3] and p:GetAttribute("MonsterId")==row[3],row[3].." placeholder and UI update")
		check(not Resource.getRecord(id) and #Spawn.validate()==0,row[3].." consumed original GUID without duplicates")
	end
end,debug.traceback)
State.step,Effects.apply,Carry.consumeOwned=oldStep,oldApply,oldConsume
if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end
Data.get,Data.getStatus=oldGet,oldStatus
if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.Anchored=false if frame then p.Character:PivotTo(frame) end end
Monster.publish(p)
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase4CIntegration] PASS "..checks) else warn(failure) end
