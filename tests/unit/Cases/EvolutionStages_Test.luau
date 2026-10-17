-- Pure 4B state/graph/save tests. No production stores or player mutations.
local Shared=game.ReplicatedStorage.Shared
local E,PD,D=require(Shared.EvolutionCalculator),require(Shared.PlayerData),require(Shared.MonsterDefinitions)
local Store=require(game.ServerScriptService.Server.SessionStore)
local Stages=require(Shared.GrowthStageDefinitions)
local FIRST,AFFINITY=Stages.Stages[0].GrowthRequired,Stages.Stages[0].AffinityRequired
local function pet(form,growth)
	local r=PD.createMonster(form or "ProtoRex") r.Growth=growth or FIRST r.TotalGrowth=r.Growth r.Revision=1 return r
end
return function(t)
	local e=t.expect
	t.test("complete reachable graph validates",function() e.equal(#E.validate(),0) end)
	t.test("first evolution is the provisional 25 Growth with a reachable 20 affinity minimum",function()
		e.equal(FIRST,25) e.equal(AFFINITY,20) e.equal(D.get("ProtoRex").GrowthRequired,25)
		for _,edge in D.get("ProtoRex").Evolutions do
			if not edge.Fallback then for _,value in edge.Requirements do e.equal(value,AFFINITY) end end
		end
		e.equal(Stages.Stages[1].GrowthRequired,80) e.equal(Stages.Stages[2].GrowthRequired,160)
	end)
	t.test("five Raw Meat feeds reach the first Flesh branch",function()
		local r=pet(nil,0)
		for _=1,4 do r.Growth+=5 r.TotalGrowth+=5 r.Flesh+=5 e.falsy(E.afterFeed(r)) e.equal(r.Stage,0) end
		r.Growth+=5 r.TotalGrowth+=5 r.Flesh+=5 e.truthy(E.afterFeed(r)) e.equal(r.EvolutionForm,"Fangling")
	end)
	t.test("existing saves above the new threshold keep all Growth on evolution",function()
		local r=pet(nil,45) r.Flesh=45 r.PetId="kept" e.truthy(E.afterFeed(r))
		e.equal(r.Stage,1) e.equal(r.EvolutionForm,"Fangling") e.equal(r.Growth+r.GrowthReserve,45-FIRST)
		e.equal(r.TotalGrowth,45) e.equal(r.PetId,"kept")
	end)
	for affinity,target in {Flesh="Fangling",Flora="Mossback",Mineral="Stonehide"} do
		t.test(affinity.." dominant branch",function()
			local r=pet() r[affinity]=AFFINITY e.truthy(E.afterFeed(r)) e.equal(r.EvolutionForm,target) e.equal(r.Stage,1)
		end)
	end
	t.test("threshold minus one cannot evolve; equality can",function()
		local r=pet(nil,FIRST-1) r.Flesh=AFFINITY e.falsy(E.afterFeed(r)) e.equal(r.Stage,0)
		r.Growth=FIRST r.TotalGrowth=FIRST e.truthy(E.afterFeed(r)) e.equal(r.Stage,1) e.equal(r.Growth,0)
	end)
	t.test("affinity below the minimum falls back instead of branching",function()
		local r=pet() r.Flesh=AFFINITY-1 e.truthy(E.afterFeed(r)) e.equal(r.EvolutionForm,"JuvenileRex")
	end)
	t.test("normal path advances one stage per action and stops at four",function()
		local r=pet(nil,10000)
		for stage=1,4 do e.truthy(E.afterFeed(r)) e.equal(r.Stage,stage) end
		e.falsy(E.afterFeed(r)) e.equal(r.Stage,4) e.equal(r.TotalGrowth,10000)
		e.equal(r.Growth+r.GrowthReserve,10000-FIRST-80-160-3000)
	end)
	t.test("high feed retains overflow without stage skipping",function()
		local r=pet(nil,7000) r.Flesh=100 e.truthy(E.afterFeed(r))
		e.equal(r.Stage,1) e.equal(r.Growth,80) e.equal(r.GrowthReserve,7000-FIRST-80) e.equal(r.TotalGrowth,7000)
	end)
	for _,pair in {{"Flesh","Mineral","ArmoredRex"},{"Flesh","Flora","VenomRex"},{"Flora","Mineral","CrystalMossRex"}} do
		t.test(pair[3].." explicit hybrid minima",function()
			local r=pet("JuvenileRex",80) r[pair[1]]=80 r[pair[2]]=79
			e.equal(E.candidates(r)[1].Result,"MatureRex")
			r[pair[2]]=80 e.equal(E.candidates(r)[1].Result,pair[3])
		end)
	end
	t.test("affinity ties create deterministic persistent choice",function()
		local r=pet(nil,100) r.Flesh=80 r.Flora=80
		e.falsy(E.afterFeed(r)) e.deepEqual(r.PendingEvolution.Candidates,{"ProtoRex:Fangling","ProtoRex:Mossback"})
		local before=PD.copy(r) e.throws(function() E.afterFeed(r) end) e.deepEqual(r,before)
		e.falsy(E.select(r,r.PendingEvolution.Token,"ProtoRex:Stonehide")) e.deepEqual(r,before)
		local token=r.PendingEvolution.Token e.truthy(E.select(r,token,"ProtoRex:Mossback"))
		e.equal(r.Stage,1) e.falsy(E.select(r,token,"ProtoRex:Fangling"))
	end)
	t.test("selection revalidates authoritative affinities",function()
		local r=pet() r.Flesh=AFFINITY r.Flora=AFFINITY E.afterFeed(r) r.Flora=0
		e.falsy(E.select(r,r.PendingEvolution.Token,"ProtoRex:Mossback")) e.equal(r.Stage,0)
	end)
	t.test("three-affinity requirements supported without granting a triple form",function()
		local r=pet("JuvenileRex",80) r.Flesh=80 r.Flora=80 r.Mineral=80
		e.equal(#E.candidates(r),3)
		local edge=PD.copy(D.get("JuvenileRex").Evolutions[2]) edge.Requirements={Flesh=80,Flora=80,Mineral=80}
		e.truthy(E.eligible(r,edge)) r.Mineral=79 e.falsy(E.eligible(r,edge))
	end)
	t.test("existing catalyst gate remains required",function()
		local r=pet("Fangling",80) r.Flesh=80
		e.equal(E.candidates(r)[1].Result,"MatureRex") r.EvolutionFamilies.Fire=true
		e.equal(E.candidates(r)[1].Result,"MagmaRex")
	end)
	t.test("rarity lineage and special predicates fail closed",function()
		local r=pet() r.Flesh=80 local edge=PD.copy(D.get("ProtoRex").Evolutions[1])
		edge.MinRarity="Epic" e.falsy(E.eligible(r,edge)) r.Rarity="Epic" e.truthy(E.eligible(r,edge))
		edge.RequiredTags={"ProtoRex"} e.falsy(E.eligible(r,edge)) r.LineageTags.ProtoRex=true
		edge.RequiredMutations={"Mutant"} e.falsy(E.eligible(r,edge)) r.Mutations={"Mutant"} e.truthy(E.eligible(r,edge))
		edge.Probability=0.5 e.falsy(E.eligible(r,edge))
	end)
	t.test("identity history unlocks mutations and rarity survive",function()
		local r=pet() r.Flesh=80 r.PetId="existing-guid" r.Rarity="Divine" r.EvolutionFamilies.Fire=true r.Mutations={"Golden"}
		E.afterFeed(r) e.equal(r.Species,"ProtoRex") e.equal(r.PetId,"existing-guid") e.equal(r.Rarity,"Divine")
		e.truthy(r.EvolutionFamilies.Fire) e.deepEqual(r.Mutations,{"Golden"}) e.equal(#r.EvolutionHistory,1)
	end)
	t.test("save rejoin retains pending choice and duplicate forms under stable keys",function()
		local saved local s=Store.new({get=function() return PD.copy(saved) end,update=function(_,fn) saved=fn(saved) return PD.copy(saved) end})
		local d=s:load("fixture") local r=pet(nil,100) r.Flesh=80 r.Flora=80 E.afterFeed(r)
		d.Monsters.ProtoRex=r d.Monsters.Fangling=pet("Fangling",71)
		local token=r.PendingEvolution.Token e.truthy(s:release("fixture")) d=s:load("fixture")
		e.equal(d.Monsters.ProtoRex.PendingEvolution.Token,token)
		e.truthy(E.select(d.Monsters.ProtoRex,token,"ProtoRex:Fangling"))
		e.equal(d.EquippedMonster,"ProtoRex") e.equal(d.Monsters.Fangling.Growth,71)
		e.truthy(s:release("fixture")) d=s:load("fixture")
		e.equal(d.Monsters.ProtoRex.Stage,1) e.equal(d.Monsters.ProtoRex.EvolutionForm,"Fangling")
		e.equal(d.Monsters.ProtoRex.PetId,"ProtoRex") e.equal(d.Monsters.ProtoRex.PendingEvolution,nil)
	end)
	t.test("legacy forms infer stages without changing ownership or unknown fields",function()
		local raw={EquippedMonster="MagmaRex",Monsters={MagmaRex={Species="MagmaRex",Stage=0,Growth=100,PetId="old-guid",Receipt="keep"}}}
		local d=PD.normalize(raw) local r=d.Monsters.MagmaRex
		e.equal(r.Stage,2) e.equal(r.EvolutionForm,"MagmaRex") e.equal(r.PetId,"old-guid") e.equal(r.Receipt,"keep")
		e.deepEqual(PD.normalize(d),d)
	end)
	t.test("unknown form and explicit conflicting stage are preserved but cannot evolve",function()
		local r=pet() r.EvolutionForm="unknown" e.falsy(E.valid(r))
		r.EvolutionForm="ProtoRex" r.Stage=3 e.falsy(E.valid(r))
	end)
	t.test("invalid reserve and precision overflow reject",function()
		for _,v in {-1,math.huge,0/0,"bad"} do local r=pet() r.GrowthReserve=v e.falsy(E.valid(r)) end
		local r=pet() r.GrowthReserve=9007199254740991 e.falsy(E.valid(r))
	end)
	t.test("unreachable prior lineage and duplicate branches are rejected",function()
		local edge=D.get("Fangling").Evolutions[1]
		edge.RequiredTags={"Stonehide"} e.truthy(#E.validate()>0) edge.RequiredTags=nil
		local old=edge.Id edge.Id=D.get("ProtoRex").Evolutions[1].Id
		e.truthy(#E.validate()>0) edge.Id=old
	end)
	t.test("locked prestige cannot be selected even with forged pending state",function()
		local r=pet("AscendedRex",1e6)
		r.PendingEvolution={Token="fake",Revision=r.Revision,Source="AscendedRex",Stage=4,Candidates={"AscendedRex:MythicRex"}}
		e.falsy(E.select(r,"fake","AscendedRex:MythicRex")) e.equal(r.Stage,4)
	end)
	t.test("mutually exclusive lineage ancestors cannot form a required branch",function()
		local edge=D.get("ApexRex").Evolutions[1] edge.RequiredTags={"Fangling","Mossback"}
		e.truthy(#E.validate()>0) edge.RequiredTags=nil
	end)
	for key,value in {Result="Missing",TargetStage=3,Growth=-1,Dominant="Neutral",MinRarity="Missing",Probability=2,RequiredLineage="Wolf"} do
		t.test("graph rejects "..key,function()
			local edge=D.get("ProtoRex").Evolutions[1] local old=edge[key] edge[key]=value
			local errors=E.validate() edge[key]=old e.truthy(#errors>0)
		end)
	end
end
