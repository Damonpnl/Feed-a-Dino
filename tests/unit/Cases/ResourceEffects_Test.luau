--!nonstrict
local Shared=game.ReplicatedStorage.Shared
local Effects=require(Shared.ResourceEffects)
local Resources=require(Shared.ResourceDefinitions)
local PlayerData=require(Shared.PlayerData)
local Calculator=require(Shared.EvolutionCalculator)
local Monsters=require(Shared.MonsterDefinitions)
return function(t)
	local e=t.expect
	-- A hybrid resource splits its growth-sized affinity gain evenly.
	t.test("applies hybrid affinity without inventing a new saved Floral field",function()
		local r=PlayerData.createMonster("ProtoRex") Effects.apply(r,Resources.get("ProteinRoot"),function() return 1 end)
		e.equal(r.Growth,110) e.equal(r.Flesh,55) e.equal(r.Flora,55) e.equal(r.Mineral,0)
	end)
	-- Neutral catalysts add growth and unlock family compatibility without invented affinity.
	t.test("unlocks a catalyst family separately from neutral affinity",function()
		local r=PlayerData.createMonster("ProtoRex") Effects.apply(r,Resources.get("ToxicCatalyst"),function() return 1 end)
		e.truthy(r.EvolutionFamilies.Toxic) e.truthy(r.EvolutionFamilies.Mutant) e.equal(r.Flesh+r.Flora+r.Mineral,0)
	end)
	-- A low roll mutates; repeated hits cannot append a duplicate mutation.
	t.test("applies the configured small mutation chance without duplicates",function()
		local r=PlayerData.createMonster("ProtoRex") local d=Resources.get("MutantLeech")
		Effects.apply(r,d,function() return 0.01 end) Effects.apply(r,d,function() return 0.01 end)
		e.deepEqual(r.Mutations,{"Mutant"})
	end)
	-- The boundary is exclusive, so 0.05 is not a successful 5% roll.
	t.test("respects the mutation chance boundary",function()
		local r=PlayerData.createMonster("ProtoRex") Effects.apply(r,Resources.get("MutantLeech"),function() return 0.05 end)
		e.equal(#r.Mutations,0)
	end)
	-- Family compatibility can activate an existing Fire branch without a removed launch catalyst ID.
	t.test("checks existing evolution branches using the unlocked family",function()
		local r=PlayerData.createMonster("Fangling") r.Flesh=80
		Effects.apply(r,Resources.get("FireCore"),function() return 1 end)
		e.equal(Calculator.resolve(Monsters.get("Fangling"),r.Growth,r,nil,r.EvolutionFamilies),"MagmaRex")
	end)
	-- Old save fields survive, and only valid family flags are persisted.
	t.test("migrates evolution family flags while retaining old affinities",function()
		local data=PlayerData.normalize({Monsters={ProtoRex={Growth=7,Flora=9,EvolutionFamilies={Fire=true,Cyber=false,Bad="yes"}}}})
		e.equal(data.Monsters.ProtoRex.Flora,9) e.deepEqual(data.Monsters.ProtoRex.EvolutionFamilies,{Fire=true})
	end)
end
