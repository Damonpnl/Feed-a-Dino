local S=game.ReplicatedStorage.Shared
local PD,R,E,C,M=require(S.PlayerData),require(S.ResourceDefinitions),require(S.ResourceEffects),require(S.CatalystDefinitions),require(S.MutationDefinitions)
local CE,EC=require(S.CatalystEffects),require(S.EvolutionCalculator)
local Store=require(game.ServerScriptService.Server.SessionStore)
local Rolls=require(game.ServerScriptService.Server.FeedRolls)
return function(t)
	local e=t.expect
	-- Each launch catalyst grants only its documented flags and catalog Growth.
	for id,families in {PrimalCatalyst={"Primal"},ToxicCatalyst={"Toxic","Mutant"},JungleHeart={"Beast","Alpha"},
		CrystalCatalyst={"Crystal"},FireCore={"Fire"},DragonBlood={"Draconic"},InfernoCatalyst={"Inferno"}} do
		t.test(id.." unlocks latent families without skipping stages",function()
			local r=PD.createMonster("ProtoRex") local d=R.get(id)
			E.apply(r,d,function() error("Catalysts must not roll") end)
			for _,family in families do e.truthy(r.EvolutionFamilies[family]) end
			e.truthy(r.LatentTraits[families[1]]) e.truthy(r.SpecialEvolutions[families[1]])
			e.truthy(r.LineageTags["Catalyst:"..families[1]])
			e.equal(r.TotalGrowth,d.Growth) e.equal(r.Flesh+r.Flora+r.Mineral,0)
			e.equal(r.Stage,0) r.Revision+=1 EC.afterFeed(r) e.truthy(r.Stage<=1)
			e.equal(r.Species,"ProtoRex") e.equal(r.PetId,"ProtoRex") e.equal(r.Rarity,"Common")
		end)
	end
	-- Future examples never enter launch pools or become feedable.
	for _,id in {"GiantSerum","SpiritEnergy","CyberCore","VoidEssence","BloodMoonShard","CelestialCore"} do
		t.test(id.." remains disabled",function()
			local r=PD.createMonster("ProtoRex") local d=R.get(id)
			e.falsy(d.Launch) e.equal(d.SpawnWeight,0) e.falsy(C.getBehavior(id).Enabled)
			e.throws(function() E.apply(r,d,function() return 0 end) end) e.equal(r.Growth,0)
		end)
	end
	-- Explicit conditions gate eligibility without modifying the input record.
	t.test("species form lineage stage affinity and prior unlock gates",function()
		local r=PD.createMonster("Fangling") local b=PD.copy(C.getBehavior("PrimalCatalyst"))
		b.Species={"Fangling"} b.Forms={"Fangling"} b.MinStage=1 b.MaxStage=1
		b.Affinities={Flesh=80} b.RequiredFamilies={"Fire"} b.RequiredTraits={"Primal"}
		b.RequiredTags={"Catalyst:Fire"} b.RequiredSpecialEvolutions={"Primal"}
		e.falsy(CE.compatible(r,b)) r.Flesh=80 r.EvolutionFamilies.Fire=true r.LatentTraits.Primal=true
		r.LineageTags["Catalyst:Fire"]=true r.SpecialEvolutions.Primal=true e.truthy(CE.compatible(r,b))
		for key,value in {Species="Unknown",EvolutionForm="Stonehide",Lineage="Other",Stage=2,Flesh=79} do
			local wrong=PD.copy(r) wrong[key]=value e.falsy(CE.compatible(wrong,b))
		end
		b.ForbiddenFamilies={"Fire"} e.falsy(CE.compatible(r,b))
	end)
	-- Each active special family has a reachable, stage-gated example.
	for _,row in {{"Primal","Fangling","PrimalRex"},{"Toxic","Mossback","ToxicRex"},{"Beast","Fangling","AlphaRex"},
		{"Fire","Fangling","MagmaRex"},{"Crystal","Stonehide","CrystalWolf"},{"Draconic","Fangling","DraconicRex"},{"Inferno","Fangling","InfernoRex"}} do
		t.test(row[1].." branch requires growth and unlock",function()
			local r=PD.createMonster(row[2]) r.Flesh=80 r.Flora=80 r.Mineral=80
			local edge for _,b in require(S.MonsterDefinitions).get(row[2]).Evolutions do if b.Result==row[3] then edge=b end end
			e.truthy(edge) e.falsy(EC.eligible(r,edge)) r.Growth=80 r.TotalGrowth=80
			e.falsy(EC.eligible(r,edge)) r.EvolutionFamilies[row[1]]=true e.truthy(EC.eligible(r,edge))
			r.Stage=0 e.falsy(EC.eligible(r,edge))
		end)
	end
	-- Only eligible, explicitly configured force effects can bypass a choice, never a stage.
	t.test("forced branch reuses eligibility and refuses stage skipping",function()
		local r=PD.createMonster("ProtoRex") r.Flesh=80 r.Growth=50 r.TotalGrowth=50
		local b=PD.copy(C.getBehavior("PrimalCatalyst")) b.Effects={{Kind="ForceEligibleBranch",Id="ProtoRex:Fangling"}}
		local forced=CE.apply(r,b,function() error("No roll") end)
		e.truthy(EC.afterFeed(r,forced)) e.equal(r.Stage,1) e.equal(r.EvolutionForm,"Fangling")
		e.throws(function() EC.afterFeed(r,"Fangling:MagmaRex") end) e.equal(r.Stage,1)
	end)
	-- Mutation outcomes use the configured exclusive boundary and no duplicate insertion.
	t.test("Leech deterministic boundary and duplicate behavior",function()
		for _,roll in {0,0.049999,0.05,0.9999} do
			local r=PD.createMonster("ProtoRex") local calls=0
			E.apply(r,R.get("MutantLeech"),function() calls+=1 return roll end)
			e.equal(calls,1) e.equal(#r.Mutations,if roll<0.05 then 1 else 0)
			if roll<0.05 then E.apply(r,R.get("MutantLeech"),function() error("Already mutated") end) e.equal(#r.Mutations,1) end
		end
	end)
	-- Finish overlays are exclusive; a biological overlay can coexist, family forms cannot.
	t.test("mutation stacking does not change identity rarity stage or families",function()
		local r=PD.createMonster("ProtoRex") e.truthy(M.apply(r,"Silver")) e.falsy(M.apply(r,"Silver"))
		e.falsy(M.apply(r,"Golden")) e.falsy(M.apply(r,"Rainbow")) e.truthy(M.apply(r,"Mutant"))
		for _,id in {"Fire","Crystal","Draconic","Toxic","Primal","Titan","Void","Cyber","Spirit","BloodMoon","Celestial","Parasite"} do e.falsy(M.apply(r,id)) end
		e.equal(r.Rarity,"Common") e.equal(r.Stage,0) e.equal(r.Species,"ProtoRex") e.deepEqual(r.EvolutionFamilies,{})
	end)
	-- Failed transactions and resource ownership changes reuse the same server random ticket.
	t.test("same GUID retries never reroll; other GUIDs are independent",function()
		local calls=0 local rolls=Rolls.new(function() calls+=1 return calls/10 end)
		e.equal(rolls.forResource("a")(),0.1) e.equal(rolls.forResource("a")(),0.1) e.equal(calls,1)
		e.equal(rolls.forResource("b")(),0.2) rolls.prune(function(id) return id=="a" end)
		e.equal(rolls.forResource("a")(),0.1) e.equal(calls,2)
	end)
	-- Existing SessionStore serialization preserves unlocks and opaque legacy purchase data.
	t.test("save release and reload retain latent traits families and mutations",function()
		local saved local store=Store.new({get=function() return PD.copy(saved) end,update=function(_,fn) saved=fn(saved) return PD.copy(saved) end})
		local d=store:load("4c-test") d.Purchases={Preserved=true}
		local r=d.Monsters.ProtoRex E.apply(r,R.get("PrimalCatalyst"),function() return 1 end)
		M.apply(r,"Rainbow") r.PetId="unchanged-guid"
		e.truthy(store:release("4c-test")) local restored=store:load("4c-test")
		e.deepEqual(restored.Monsters.ProtoRex,r) e.truthy(restored.Purchases.Preserved)
	end)
	-- Static validation covers all authored launch and future behavior records.
	t.test("configured mutation effect uses injected RNG and preserves duplicates",function()
		local r=PD.createMonster("ProtoRex") local b=PD.copy(C.getBehavior("PrimalCatalyst"))
		b.Effects={{Kind="AttemptMutation",Id="Mutant",Chance=require(S.SpecialEffectDefinitions).MutationRoll.Chance}}
		CE.apply(r,b,function() return 0.01 end) e.deepEqual(r.Mutations,{"Mutant"})
		CE.apply(r,b,function() error("Duplicate must not roll") end) e.equal(#r.Mutations,1)
	end)
	-- Invalid saved traits reject without deleting the legacy value or awarding Growth.
	t.test("malformed saved catalyst flags fail closed without loss",function()
		local r=PD.createMonster("ProtoRex") r.LatentTraits={Unknown="preserve"}
		e.falsy(E.canApply(r,R.get("FireCore")))
		e.throws(function() E.apply(r,R.get("FireCore"),function() return 0 end) end)
		e.equal(r.TotalGrowth,0) e.equal(r.LatentTraits.Unknown,"preserve")
	end)
	-- Generic special branch conditions are enforced without implicit stage changes.
	t.test("latent and enabled-special predicates gate an otherwise eligible edge",function()
		local r=PD.createMonster("ProtoRex") r.Flesh=80 r.Growth=50 r.TotalGrowth=50
		local edge=PD.copy(require(S.MonsterDefinitions).get("ProtoRex").Evolutions[1])
		edge.RequiredLatentTraits={"Primal"} edge.RequiredSpecialEvolutions={"Primal"}
		e.falsy(EC.eligible(r,edge)) r.LatentTraits.Primal=true e.falsy(EC.eligible(r,edge))
		r.SpecialEvolutions.Primal=true e.truthy(EC.eligible(r,edge))
	end)
	t.test("catalyst and evolution definitions validate",function()
		e.equal(#CE.validate(),0) e.equal(#EC.validate(),0)
	end)
end
