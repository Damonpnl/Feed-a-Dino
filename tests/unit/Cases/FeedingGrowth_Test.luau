-- Pure 4A effect/save contracts; no real players, network, RNG or DataStores.
local Shared=game.ReplicatedStorage.Shared
local Effects=require(Shared.ResourceEffects)
local Resources=require(Shared.ResourceDefinitions)
local PlayerData=require(Shared.PlayerData)
local Store=require(game.ServerScriptService.Server.SessionStore)
return function(t)
	local e=t.expect
	for id,definition in Resources.getAll() do
		if not definition.Launch then continue end
		-- Every launch resource preserves its configured total and affinity membership.
		t.test(id.." preview matches committed Growth and affinity",function()
			local record=PlayerData.createMonster("ProtoRex")
			local before=PlayerData.copy(record)
			local preview=Effects.resolve(record,definition)
			e.deepEqual(record,before)
			Effects.apply(record,definition,function() return 1 end)
			e.equal(record.Growth,definition.Growth) e.equal(record.TotalGrowth,definition.Growth)
			e.equal(record.Flesh,preview.Delta.Flesh) e.equal(record.Flora,preview.Delta.Floral) e.equal(record.Mineral,preview.Delta.Mineral)
			e.equal(record.Flesh+record.Flora+record.Mineral,if definition.Affinity=="Neutral" then 0 else definition.Growth)
			for name,value in {Flesh=record.Flesh,Floral=record.Flora,Mineral=record.Mineral} do
				if not string.find(definition.Affinity,name,1,true) then e.equal(value,0) end
				e.equal(value,math.floor(value))
			end
		end)
	end
	-- Odd hybrid rounding is deterministic and retains the full configured contribution.
	t.test("odd hybrid remainder goes to first listed affinity",function()
		local effect=Effects.resolve(PlayerData.createMonster("ProtoRex"),Resources.get("BogMarrow"))
		e.equal(effect.Delta.Flesh,28) e.equal(effect.Delta.Mineral,27)
	end)
	-- Explicit examples are independent of the implementation's affinity tables.
	t.test("locked examples grant exact values",function()
		for _,row in {{"RawMeat",5,5,0},{"AncientBone",18,0,18},{"FossilMarrow",300,150,150}} do
			local result=Effects.resolve(PlayerData.createMonster("ProtoRex"),Resources.get(row[1]))
			e.equal(result.Delta.Growth,row[2]) e.equal(result.Delta.Flesh,row[3]) e.equal(result.Delta.Mineral,row[4])
		end
	end)
	-- Old saves keep identifiers, Flora, unknown fields and a conservative cumulative baseline.
	t.test("legacy normalization preserves ownership and extensions",function()
		local raw={EquippedMonster="Mossback",Monsters={Mossback={Species="Mossback",Growth=13,Flora=81,
			PetId="owned-id",EvolutionForm="legacy-form",PurchaseId="keep",Stage=2,EvolutionHistory={{From="ProtoRex"}}}}}
		local record=PlayerData.normalize(raw).Monsters.Mossback
		e.equal(record.TotalGrowth,13) e.equal(record.Flora,81) e.equal(record.Floral,nil)
		e.equal(record.PetId,"owned-id") e.equal(record.EvolutionForm,"legacy-form") e.equal(record.PurchaseId,"keep")
		e.equal(record.Stage,2) e.deepEqual(record.EvolutionHistory,{{From="ProtoRex"}})
	end)
	-- Resetting current Growth for existing evolution never resets cumulative Growth.
	t.test("cumulative Growth survives a current Growth reset",function()
		local r=PlayerData.createMonster("ProtoRex") Effects.apply(r,Resources.get("RawMeat"),function() return 1 end)
		r.Growth=0 Effects.apply(r,Resources.get("AncientBone"),function() return 1 end)
		e.equal(r.Growth,18) e.equal(r.TotalGrowth,23)
	end)
	-- Corrupt numbers and precision exhaustion reject before mutation.
	t.test("invalid and exhausted numbers are rejected",function()
		for _,value in {-1,0/0,math.huge,"bad",1e308} do
			local r=PlayerData.createMonster("ProtoRex") r.Growth=value r.TotalGrowth=value
			e.throws(function() Effects.resolve(r,Resources.get("RawMeat")) end)
		end
	end)
	-- Releasing/reloading the real SessionStore restores exact fed state using a fake adapter.
	t.test("save and rejoin restore fed Growth and Flora without live saves",function()
		local saved
		local adapter={get=function() return PlayerData.copy(saved) end,update=function(_,fn) saved=fn(saved) return PlayerData.copy(saved) end}
		local s=Store.new(adapter) local d=s:load("u_fixture")
		Effects.apply(d.Monsters.ProtoRex,Resources.get("ProteinRoot"),function() return 1 end)
		e.truthy(s:release("u_fixture"))
		local restored=s:load("u_fixture").Monsters.ProtoRex
		e.equal(restored.Growth,110) e.equal(restored.TotalGrowth,110) e.equal(restored.Flesh,55) e.equal(restored.Flora,55)
	end)
end
