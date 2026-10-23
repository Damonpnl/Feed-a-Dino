-- Opt-in existing prototype compatibility and precommit rollback. Disposable Studio data only.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server local Shared=game.ReplicatedStorage.Shared
local Data,Feed,Carry,Spawn,Resource,Guardian=require(S.DataService),require(S.FeedService),require(S.CarryService),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService)
local PD,Effects=require(Shared.PlayerData),require(Shared.ResourceEffects)
local p=game.Players:GetPlayers()[1] local data=Data.get(p)
local backup,oldStatus,oldApply=PD.copy(data),Data.getStatus,Effects.apply
local checks=0 local function check(v,m) assert(v,m) checks+=1 end
local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
local point=base:FindFirstChild("FeedingPoint",true)
local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
local function acquire()
	task.wait(0.21) Guardian.resetAll()
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do
		local id=m:GetAttribute("ResourceInstanceId") local r=Resource.getRecord(id)
		if r and r.AreaId=="Grasslands" and r.State=="AVAILABLE" then
			p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) assert(Spawn.pickup(p,id))
			p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) return id
		end
	end error("Missing available Grasslands resource")
end
local ok,failure=xpcall(function()
	Data.getStatus=function(player) return if player==p then {Status="Loaded",CanSave=true,Closing=false} else oldStatus(player) end
	data.Power=1e12 data.EquippedMonster="ProtoRex" data.Monsters={ProtoRex=PD.createMonster("ProtoRex"),Fangling=PD.createMonster("Fangling")}
	local proto=data.Monsters.ProtoRex proto.Growth=45 proto.TotalGrowth=45 proto.Flesh=45 proto.PetId="keep-owned-identity"
	local owned=data.Monsters.Fangling owned.Growth=71 owned.TotalGrowth=71
	p.Character.HumanoidRootPart.Anchored=true
	local id=acquire()
	local feeds=data.Stats.Feeds data.Stats.Feeds=0/0
	check(not Feed.preview(p,base,host).Available and Resource.owned(p,id),"NaN counter fails closed") data.Stats.Feeds=feeds
	local revision=proto.Revision proto.Revision="invalid"
	check(not Feed.preview(p,base,host).Available,"Invalid revision fails closed") proto.Revision=revision
	local preview=Feed.preview(p,base,host)
	check(preview.Available and preview.LegacyOutcome:find("Evolves into",1,true),"Same-form evolution previewed without replacing owned pet")
	Effects.apply=function() error("Intentional precommit calculation failure") end
	check(not Feed.confirm(p,preview.Ticket) and Resource.owned(p,id) and data.Monsters.ProtoRex==proto and proto.Growth==45,"Calculation failure retains item and pet")
	Effects.apply=oldApply preview=Feed.preview(p,base,host)
	check(Feed.confirm(p,preview.Ticket),"Retry after calculation failure succeeds")
	check(data.Monsters.Fangling==owned and owned.Growth==71 and data.EquippedMonster=="ProtoRex","Already-owned pet is never overwritten")
	check(data.Monsters.ProtoRex.Growth==preview.GrowthAfter and data.Monsters.ProtoRex.TotalGrowth==preview.Effect.After.TotalGrowth,"Evolution retains overflow and cumulative Growth")
	check(data.Monsters.ProtoRex.EvolutionForm=="Fangling","Form evolves while ownership remains stable")
	id=acquire() preview=Feed.preview(p,base,host)
	check(preview.Available,"Next-stage feed previews")
	check(Feed.confirm(p,preview.Ticket),"Existing automatic branch remains functional")
	local evolved=data.Monsters.ProtoRex
	check(data.EquippedMonster=="ProtoRex" and data.Monsters.Fangling==owned,"Stable owned keys retain both pets")
	check(evolved.Growth==preview.GrowthAfter and evolved.TotalGrowth==preview.Effect.After.TotalGrowth and evolved.PetId=="keep-owned-identity","Cumulative Growth and existing individual identifier survive")
	check(evolved.Revision==2 and not Feed.confirm(p,preview.Ticket),"Exactly two accepted revisions; no replay")
end,debug.traceback)
Effects.apply=oldApply Data.getStatus=oldStatus
if Carry.get(p) then Carry.forceDrop(p,p.Character,"Fixture cleanup") end
for k in data do data[k]=nil end for k,v in backup do data[k]=v end
require(S.MonsterService).publish(p)
p.Character.HumanoidRootPart.Anchored=false
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
