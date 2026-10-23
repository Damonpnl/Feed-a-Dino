local Shared=game.ReplicatedStorage.Shared
local Validation=require(Shared.DefinitionValidation)
local Monsters=require(Shared.MonsterDefinitions)
local Trainers=require(Shared.TrainerDefinitions)
local Billboard=require(Shared.BillboardConfig)
local function corrupted(object,key,value)
	local original=object[key] object[key]=value
	local ok,errors=pcall(Validation.config) object[key]=original
	assert(ok,errors) assert(#errors>0,"Invalid configuration was accepted")
end
return function(t)
	-- Every launch resource, area and cross-definition reference must be valid.
	t.test("launch configuration has no errors",function() t.expect.equal(#Validation.config(),0) end)
	-- Phase 5A explicitly authorizes labeled provisional prices; only Tier 1 is free.
	t.test("trainer prices are explicit and provisional",function()
		t.expect.equal(Trainers.PriceStatus,"PROVISIONAL_BALANCE")
		for i,trainer in Trainers.getOrdered() do t.expect.equal(trainer.Purchasable,i>1) t.expect.truthy(trainer.Price~=nil) end
	end)
	-- An unknown evolution result must fail validation.
	t.test("rejects missing evolution targets",function() corrupted(Monsters.get("ProtoRex").Evolutions[1],"Result","Missing") end)
	-- A trainer cannot become purchasable without an approved price.
	t.test("rejects unpriced purchasable trainers",function() corrupted(Trainers.getOrdered()[2],"Price",nil) end)
	-- Range validation includes malformed types and must return diagnostics, not crash.
	t.test("rejects malformed billboard budget",function() corrupted(Billboard,"MaxAnimated","invalid") end)
	-- Nonfinite progression cannot enter authoritative definitions.
	t.test("rejects nonfinite monster progression",function() corrupted(Monsters.get("ProtoRex"),"BaseMultiplier",math.huge) end)
end
