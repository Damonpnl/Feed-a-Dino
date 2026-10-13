-- Opt-in actual Studio server/client integration. Only injected in-memory persistence.
assert(game:GetService("RunService"):IsStudio())
local S,Shared=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Monster,Feed,Spawn,Resource,Carry,Guardian=require(S.DataService),require(S.MonsterService),require(S.FeedService),require(S.SpawnService),require(S.ResourceService),require(S.CarryService),require(S.GuardianService)
local PD,E,Store=require(Shared.PlayerData),require(Shared.EvolutionCalculator),require(S.SessionStore)
local p=game.Players:GetPlayers()[1]
local originalGet,originalStatus=Data.get,Data.getStatus
local saved local sessions=Store.new({get=function() return PD.copy(saved) end,update=function(_,fn) saved=fn(saved) return PD.copy(saved) end})
local checks=0
local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,seconds) local untilTime=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>untilTime return false end
local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
local point=base:FindFirstChild("FeedingPoint",true)
local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
local frame=p.Character:GetPivot()
local overrideStatus
local function current() return sessions:get("4b-fixture") end
local function home() p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) end
local function acquire()
	task.wait(0.21) Guardian.resetAll()
	assert(waitFor(function() return Resource.getSnapshot().Phase~="Reset" end,12))
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do
		local id=m:GetAttribute("ResourceInstanceId") local r=Resource.getRecord(id)
		if r and r.State=="AVAILABLE" and r.AreaId=="Grasslands" then
			p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) assert(Spawn.pickup(p,id)) home() return id
		end
	end error("No Grasslands fixture resource")
end
local function request(r,id) return {PetKey="ProtoRex",Token=r.PendingEvolution.Token,BranchId=id or "ProtoRex:Fangling"} end
local function choose(r,id) task.wait(0.21) return Monster.chooseEvolution(p,request(r,id)) end
local function pending()
	local r=PD.createMonster("ProtoRex") r.PetId="same-owned-guid" r.Growth=100 r.TotalGrowth=100 r.Flesh=80 r.Flora=80 r.Revision=1
	E.afterFeed(r) current().Monsters.ProtoRex=r current().EquippedMonster="ProtoRex" return r
end
local ok,failure=xpcall(function()
	local d=sessions:load("4b-fixture") d.Power=1e12
	Data.get=function(player) return if player==p then current() else originalGet(player) end
	Data.getStatus=function(player) return if player==p then overrideStatus or sessions:status("4b-fixture") else originalStatus(player) end
	p.Character.HumanoidRootPart.Anchored=true home()
	d.Monsters.Fangling=PD.createMonster("Fangling") d.Monsters.Fangling.Growth=71 d.Monsters.Fangling.TotalGrowth=71
	local other=d.Monsters.Fangling
	local r=d.Monsters.ProtoRex r.PetId="same-owned-guid" r.Growth=49 r.TotalGrowth=49 r.Flesh=100
	Monster.publish(p) local oldVisual=workspace.GeneratedGameplay.Monsters[p.Name.."_Monster"]
	local id=acquire() local preview=Feed.preview(p,base,host)
	check(preview.Available and preview.LegacyOutcome:find("Fangling",1,true),"Pickup to evolution preview")
	check(Feed.confirm(p,preview.Ticket),"Authoritative feed evolves once")
	r=d.Monsters.ProtoRex
	check(r.Stage==1 and r.EvolutionForm=="Fangling" and r.PetId=="same-owned-guid" and r.Species=="ProtoRex","One stage and identity preserved")
	check(d.Monsters.Fangling==other and other.Growth==71 and d.EquippedMonster=="ProtoRex","Duplicate-form owned pet untouched")
	check(not Resource.getRecord(id) and not Carry.get(p),"Original resource GUID consumed")
	check(not Feed.confirm(p,preview.Ticket) and d.Stats.Evolutions==1,"Feed replay cannot evolve again")
	local visual=workspace.GeneratedGameplay.Monsters[p.Name.."_Monster"]
	check(visual~=oldVisual and oldVisual.Parent==nil and visual.PrimaryPart.Anchored and not visual.PrimaryPart.CanCollide,"Safe placeholder replacement")
	check(visual:GetAttribute("EvolutionForm")=="Fangling" and p:GetAttribute("PetStage")==1,"Form and stage replicated")
	check(Monster.getMultiplier(p)==1.5,"Existing form multiplier interface works")
	r=pending() id=acquire()
	check(not Feed.preview(p,base,host).Available and Resource.owned(p,id),"Pending choice blocks reroll and retains carried item")
	Carry.forceDrop(p,p.Character,"Fixture")
	check(sessions:release("4b-fixture"),"Pending choice persisted with existing store")
	d=sessions:load("4b-fixture") r=d.Monsters.ProtoRex
	check(r.PendingEvolution and r.PendingEvolution.Token=="1:ProtoRex" and r.PetId=="same-owned-guid","Pending token and identity restored")
	check(not choose(r,"ProtoRex:Stonehide") and r.Stage==0,"Ineligible selection rejected")
	p.Character:PivotTo(host.CFrame+Vector3.new(100,3,0))
	check(not choose(r),"Far choice rejected") home()
	for _,status in {"LoadFailed","InvalidData","StudioReadOnly","Conflict"} do
		overrideStatus={Status=status,CanSave=false,Closing=false} check(not choose(r),status.." choice rejected")
	end overrideStatus=nil
	task.wait(0.21) check(not Monster.chooseEvolution(p,{PetKey="Fangling",Token=r.PendingEvolution.Token,BranchId="ProtoRex:Fangling"}),"Forged ownership key rejected")
	task.wait(0.21) check(not Monster.chooseEvolution(p,{PetKey="ProtoRex",Token="forged",BranchId="ProtoRex:Fangling"}),"Forged token rejected")
	task.wait(0.21) check(not Monster.chooseEvolution(p,{PetKey={},Token={},BranchId={}}),"Malformed remote payload rejected")
	local req=request(r) local wins=0
	task.wait(0.21) for _=1,20 do task.spawn(function() if Monster.chooseEvolution(p,req) then wins+=1 end end) end
	check(wins==1 and d.Monsters.ProtoRex.Stage==1 and not d.Monsters.ProtoRex.PendingEvolution,"Concurrent choices commit once")
	check(d.Monsters.ProtoRex.Growth==50 and d.Monsters.ProtoRex.TotalGrowth==100,"Choice spends threshold and retains overflow")
	task.wait(0.21) check(not Monster.chooseEvolution(p,req),"Choice replay rejected")
	check(sessions:release("4b-fixture"),"Evolution persisted") d=sessions:load("4b-fixture")
	check(d.Monsters.ProtoRex.Stage==1 and d.Monsters.ProtoRex.EvolutionForm=="Fangling" and d.Monsters.ProtoRex.PetId=="same-owned-guid","Stage form and identity restored")
	-- Wait for a real MCP mouse click on the client button, then test real remote replay.
	r=pending() Monster.publish(p)
	local evolutionsBefore=d.Stats.Evolutions
	p:SetAttribute("Phase4BTest","Forgeries") script:SetAttribute("Progress","CLIENT_FORGERIES")
	task.wait(4)
	check(d.Monsters.ProtoRex.Stage==0 and d.Stats.Evolutions==evolutionsBefore,"Real client forged requests cannot evolve")
	script:SetAttribute("Progress","CLICK_MOSSBACK")
	check(waitFor(function() return d.Monsters.ProtoRex.Stage==1 end,150),"Actual client evolution button accepted")
	check(d.Monsters.ProtoRex.EvolutionForm=="Mossback" and d.Monsters.ProtoRex.PetId=="same-owned-guid","Client selection chooses only requested branch")
	task.wait(1)
	check(d.Stats.Evolutions==evolutionsBefore+1,"Real client selection replay cannot evolve again")
	check(#Spawn.validate()==0,"Carry/world invariants remain valid")
	r=pending() local reqBeforeDeath=request(r)
	p.Character.Humanoid.Health=0 task.wait(0.21)
	check(not Monster.chooseEvolution(p,reqBeforeDeath) and r.PendingEvolution~=nil,"Death cannot evolve or erase pending choice")
	local oldCharacter=p.Character p:LoadCharacterAsync()
	assert(waitFor(function() return p.Character~=oldCharacter and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end,10))
	task.wait(1) p.Character.HumanoidRootPart.Anchored=true home()
	check(choose(r),"Persisted choice usable after respawn with fresh live validation")
	check(d.Monsters.ProtoRex.Stage==1 and #d.Monsters.ProtoRex.EvolutionHistory==1,"Respawn produces no stale duplicate transition")
end,debug.traceback)
Data.get,Data.getStatus=originalGet,originalStatus
p:SetAttribute("Phase4BTest",nil)
if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end
if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
Monster.publish(p)
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase4BIntegration] PASS "..checks) else warn(failure) end
