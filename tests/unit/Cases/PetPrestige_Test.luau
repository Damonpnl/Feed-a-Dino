-- Phase 4D contracts. All enabled promotion/prestige values below are TEST ONLY.
local S=game.ReplicatedStorage.Shared
local PD,E,D=require(S.PlayerData),require(S.EvolutionCalculator),require(S.MonsterDefinitions)
local C,R,P,M=require(S.PetProgressionConfig),require(S.PetRarity),require(S.PrestigeCalculator),require(S.PetMultipliers)
local Store=require(game.ServerScriptService.Server.SessionStore)
local Rolls=require(game.ServerScriptService.Server.FeedRolls)
local function pet(form)
	local r=PD.createMonster(form or "ProtoRex") r.Growth=100 r.TotalGrowth=100 r.Flesh=100 r.Revision=1 return r
end
local function ascension()
	local d=PD.copy(C.Ascensions.ProtoRexMythic)
	d.RequirementsApproved=true d.Enabled=true d.Growth=100 d.MinRarity="Epic"
	d.Affinities={Flesh=100,Mineral=80} d.RequiredFamilies={"Primal"} d.RequiredTraits={"DormantMythic"}
	d.RequiredQualifications={"FixtureMastery"} d.RequiredTags={"ApexRex"}
	return d
end
local function qualified()
	local r=pet("AscendedRex") r.Rarity="Epic" r.Mineral=80 r.EvolutionFamilies.Primal=true
	r.LatentTraits.DormantMythic=true r.Qualifications.FixtureMastery=true r.LineageTags.ApexRex=true return r
end
local function awakening()
	local d=PD.copy(C.Awakenings.ProtoRexAwakening)
	d.RequirementsApproved=true d.Enabled=true d.Guaranteed=true d.Growth=100 d.MinRarity="Epic"
	d.Affinities={Flesh=100} d.RequiredTraits={"DormantMythic"} d.Catalysts={"CelestialCore"}
	return d
end
local function ascended()
	local r=qualified() r.Stage=5 r.EvolutionForm="MythicRex" r.Ascension={Id="ProtoRexMythic",State="Completed"} return r
end
return function(t)
	local e=t.expect
	-- New configuration is validated alongside the existing graph.
	t.test("4D definitions validate",function() e.equal(#R.validate(),0) e.equal(#P.validate(),0) e.equal(#M.validate(),0) end)
	-- Resource rarity and target form metadata never set pet rarity.
	t.test("Divine catalyst and ordinary evolution keep independent pet rarity",function()
		local r=pet() require(S.ResourceEffects).apply(r,require(S.ResourceDefinitions).get("InfernoCatalyst"),function() return 0 end)
		E.afterFeed(r) e.equal(r.Stage,1) e.equal(r.Rarity,"Common") e.falsy(r.Awakened)
		e.equal(r.EvolutionHistory[1].RarityAfter,"Common")
	end)
	-- There are no live promotion probabilities.
	t.test("unapproved promotion consumes no random ticket",function()
		e.equal(R.resolve(pet(),C.RarityRules.PromoteOne,function() error("must not roll") end),"Common")
	end)
	-- Deterministic configured advancement respects minimum eligibility.
	t.test("one-tier promotion checks stage rarity and family",function()
		local r=pet() local d={Enabled=true,Tiers=1,Chance=1,MinStage=1,MinRarity="Rare",RequiredFamily="Primal"}
		e.equal(R.resolve(r,d),"Common") r.Stage=1 r.Rarity="Rare"
		e.equal(R.resolve(r,d),"Rare") r.EvolutionFamilies.Primal=true e.equal(R.resolve(r,d),"Epic")
	end)
	-- Multi-tier promotion always needs explicit authorization.
	t.test("multi-tier promotion needs authorization",function()
		local d={Enabled=true,Tiers=2,Chance=1} e.falsy(R.validRule(d))
		d.AllowMultiple=true e.equal(R.resolve(pet(),d),"Rare")
	end)
	-- A lower ceiling prevents promotions but never downgrades a legitimate pet.
	t.test("rarity ceilings cannot demote existing pets",function()
		local r=pet() r.Rarity="Divine" e.equal(R.resolve(r,{Enabled=true,Tiers=1,Chance=1,Ceiling="Rare"}),"Divine")
		r.Rarity="Rare" e.equal(R.resolve(r,{Enabled=true,Tiers=1,Chance=1,Ceiling="Rare"}),"Rare")
		r.Rarity="Eternal" e.equal(R.resolve(r,{Enabled=true,Tiers=2,AllowMultiple=true,Chance=1}),"Divine")
	end)
	-- Chance boundaries use an injected RNG, not resource spawn weights.
	t.test("test probability boundary is deterministic",function()
		local d={Enabled=true,Tiers=1,Chance=0.25}
		e.equal(R.resolve(pet(),d,function() return 0.249 end),"Uncommon")
		e.equal(R.resolve(pet(),d,function() return 0.25 end),"Common")
	end)
	-- Malformed rules cannot create demotions or unapproved chances.
	t.test("invalid rarity rules fail closed",function()
		for _,d in {{Enabled=true,Tiers=-1},{Enabled=true,Tiers=1},{Enabled=true,Tiers=1,Chance=2},{Enabled=true,Tiers=1,Chance=0/0}} do e.falsy(R.validRule(d)) end
		local r=pet() r.Rarity="Unknown" e.falsy(E.valid(r))
	end)
	-- A real graph transition stores one accepted result and rejects choice replay.
	t.test("pending evolution resolves once and persists its rarity result",function()
		local edge=D.get("ProtoRex").Evolutions[1] local old=edge.RarityRule
		C.RarityRules.Fixture={Enabled=true,Tiers=1,Chance=0.25} edge.RarityRule="Fixture"
		local ok,err=pcall(function()
			local r=pet() r.Flora=100 E.afterFeed(r) local token=r.PendingEvolution.Token local calls=0
			local rng=function() calls+=1 return 0.1 end
			e.truthy(E.select(r,token,edge.Id,rng)) e.equal(r.Rarity,"Uncommon") e.equal(calls,1)
			e.falsy(E.select(r,token,edge.Id,rng)) e.equal(calls,1)
			local store=Store.new(Store.memoryAdapter()) local data=store:load("fixture") data.Monsters.ProtoRex=r
			e.truthy(store:release("fixture")) local saved=store:load("fixture").Monsters.ProtoRex
			e.equal(saved.Rarity,"Uncommon") e.equal(saved.EvolutionHistory[1].RarityBefore,"Common")
			e.falsy(E.select(saved,token,edge.Id,rng)) e.equal(calls,1)
		end)
		edge.RarityRule=old C.RarityRules.Fixture=nil assert(ok,err)
	end)
	-- Retry-stable tickets protect calculations rejected before consuming a GUID.
	t.test("discarded staged promotion reuses GUID ticket",function()
		local calls=0 local cache=Rolls.new(function() calls+=1 return 0.1 end)
		local rule={Enabled=true,Tiers=1,Chance=0.25}
		local first=R.resolve(pet(),rule,cache.forResource("guid"))
		e.equal(R.resolve(pet(),rule,cache.forResource("guid")),first) e.equal(calls,1)
	end)
	-- Approved isolated fixtures exercise the locked Stage 4 -> 5 framework.
	t.test("qualified ascension fixture is ready; disabled is only eligible",function()
		local d=ascension() e.equal(P.ascension(qualified(),d).State,"Ready")
		d.Enabled=false e.equal(P.ascension(qualified(),d).State,"Eligible")
	end)
	-- Each conjunct is independently required, including large-Growth cases.
	for _,key in {"Stage","EvolutionForm","Lineage","Growth","Rarity","Mineral","EvolutionFamilies","LatentTraits","Qualifications","LineageTags"} do
		t.test("ascension rejects incomplete "..key,function()
			local r=qualified() local invalid={Stage=3,EvolutionForm="ApexRex",Lineage="Wrong",Growth=99,Rarity="Rare",Mineral=79,
				EvolutionFamilies={},LatentTraits={},Qualifications={},LineageTags={}}
			r[key]=invalid[key] e.equal(P.ascension(r,ascension()).State,"Locked")
		end)
	end
	-- Default definitions cannot grant prestige even with a huge balance.
	t.test("live prestige stays locked and earned Growth survives",function()
		local r=qualified() r.Growth=1e12 r.TotalGrowth=1e12
		e.equal(P.ascension(r,C.Ascensions.ProtoRexMythic).State,"Locked")
		e.falsy(E.afterFeed(r)) e.equal(r.Stage,4) e.equal(r.Growth+r.GrowthReserve,1e12)
		e.falsy(P.planAwakening(ascended(),C.Awakenings.ProtoRexAwakening,"CelestialCore"))
	end)
	-- Completion requires persisted identity as well as a stage number.
	t.test("isolated approved ascension advances through existing graph once",function()
		local edge=D.get("AscendedRex").Evolutions[1]
		local oldLock,oldGrowth,oldConfig=edge.Locked,edge.Growth,C.Ascensions.ProtoRexMythic
		edge.Locked=false edge.Growth=100 C.Ascensions.ProtoRexMythic=ascension()
		local ok,err=pcall(function()
			local r=qualified() local id=r.PetId
			e.truthy(E.afterFeed(r)) e.equal(r.Stage,5) e.equal(r.Ascension.State,"Completed")
			e.equal(r.PetId,id) e.equal(r.Rarity,"Epic") e.equal(r.TotalGrowth,100)
			e.equal(#r.EvolutionHistory,1) e.falsy(E.afterFeed(r)) e.equal(#r.EvolutionHistory,1)
		end)
		edge.Locked,edge.Growth,C.Ascensions.ProtoRexMythic=oldLock,oldGrowth,oldConfig assert(ok,err)
	end)
	-- Completion requires persisted identity as well as a stage number.
	t.test("stage five alone is not completed ascension",function()
		local r=ascended() e.equal(P.ascension(r,ascension()).State,"Completed")
		r.Ascension={State="Locked"} e.equal(P.awakening(r,awakening(),"CelestialCore").State,"Locked")
	end)
	-- Separate awakening keeps species, stage, rarity and mutations intact.
	t.test("qualified awakening has separate persistent identity and no replay",function()
		local r=ascended() local before=PD.copy(r)
		e.truthy(P.planAwakening(r,awakening(),"CelestialCore"))
		e.equal(r.Stage,5) e.equal(r.Species,before.Species) e.equal(r.PetId,before.PetId) e.equal(r.Rarity,before.Rarity)
		e.equal(r.EvolutionForm,"MythicRex") e.equal(r.Awakening.Form,"AwakenedRexPlaceholder")
		e.falsy(P.planAwakening(r,awakening(),"CelestialCore")) e.equal(r.Revision,before.Revision+1)
		local store=Store.new(Store.memoryAdapter()) local d=store:load("a") d.Monsters.ProtoRex=r
		e.truthy(store:release("a")) e.deepEqual(store:load("a").Monsters.ProtoRex,r)
	end)
	-- Wrong catalysts, stages and lineages each reject without mutation.
	for _,key in {"catalyst","stage","lineage","trait","guarantee","enabled"} do
		t.test("awakening rejects "..key,function()
			local r,d,c=ascended(),awakening(),"CelestialCore"
			if key=="catalyst" then c="InfernoCatalyst" elseif key=="stage" then r.Stage=4
			elseif key=="lineage" then r.Lineage="Wrong" elseif key=="trait" then r.LatentTraits={}
			elseif key=="guarantee" then d.Guaranteed=false else d.Enabled=false end
			local before=PD.copy(r) e.falsy(P.planAwakening(r,d,c)) e.deepEqual(r,before)
		end)
	end
	-- Legacy opaque data is preserved and new state defaults are additive.
	t.test("legacy saves retain rarity and opaque prestige fields",function()
		local raw={Monsters={ProtoRex={Species="ProtoRex",Rarity="Eternal",Growth=7,Receipt="keep"}}}
		local d=PD.normalize(raw) local r=d.Monsters.ProtoRex
		e.equal(r.Rarity,"Eternal") e.equal(r.Receipt,"keep") e.equal(r.Ascension.State,"Locked") e.falsy(r.Awakened)
		e.deepEqual(PD.normalize(d),d)
	end)
	-- Existing gameplay gain values are identical across every retained form.
	t.test("malformed prestige fields are preserved but block evolution",function()
		local r=pet() r.Awakened="bad" e.falsy(E.valid(r))
		r.Awakened=false r.Ascension={State="Bogus"} e.falsy(E.valid(r))
		r.Ascension={State="Locked"} r.Awakened=true e.falsy(E.valid(r))
	end)
	-- Bad metadata must fail startup rather than silently multiply Cash or Power.
	t.test("invalid multiplier values and references fail validation",function()
		C.Multipliers.Mutation.Unknown={Income=0/0}
		local ok,errors=pcall(M.validate) C.Multipliers.Mutation.Unknown=nil
		e.truthy(ok) e.truthy(#errors>0)
	end)
	-- The old unknown-form economic fallback is retained.
	t.test("unknown saved form retains neutral multiplier fallback",function()
		local r=pet("SpiritDragon") r.EvolutionForm="Unknown" e.equal(M.resolve(r).TrainingMultiplier,1)
	end)
	-- Negative and non-finite factors never escape the centralized calculation.
	t.test("invalid multiplier calculation is rejected",function()
		local c=PD.copy(C.Multipliers) c.Rarity.Common={Income=0/0}
		e.throws(function() M.resolve(pet(),c) end)
	end)
	-- Existing gameplay gain values are identical across every retained form.
	t.test("neutral multiplier configuration preserves every form and legacy floor",function()
		for id,d in D.getAll() do local r=pet(id) local m=M.resolve(r)
			e.equal(m.TrainingMultiplier,d.BaseMultiplier) e.equal(m.IncomeMultiplier,d.BaseMultiplier)
		end
		local r=pet("SpiritDragon") r.EvolutionForm="ApexRex" e.equal(M.resolve(r).TrainingMultiplier,3)
	end)
	-- Future factors have separate channels and bounded unique mutation stacking.
	t.test("multiplier bound applies to the total product",function()
		local c=PD.copy(C.Multipliers) c.Max=10
		c.Rarity.Common={Income=100} c.Stage[0]={Income=0.1}
		e.equal(M.resolve(pet(),c).IncomeMultiplier,10)
	end)
	-- Future factors have separate channels and bounded unique mutation stacking.
	t.test("multiplier factors are centralized bounded and duplicate-safe",function()
		local c=PD.copy(C.Multipliers) c.Max=10 c.Rarity.Common={Income=2,Training=3}
		c.Stage[0]={Income=2} c.Mutation.Golden={Income=4,Training=2}
		c.Awakening.Fixture={Training=4}
		local r=pet() r.Mutations={"Golden","Golden"} r.Awakened=true r.Awakening={Id="Fixture"}
		local m=M.resolve(r,c) e.equal(m.IncomeMultiplier,10) e.equal(m.TrainingMultiplier,10)
		c.Max=100 m=M.resolve(r,c) e.equal(m.IncomeMultiplier,16) e.equal(m.TrainingMultiplier,24)
	end)
end
