local Shared=game.ReplicatedStorage.Shared
local E=require(Shared.EconomyCalculator)
local C=require(Shared.EconomyConfig)
local T=require(Shared.TrainerDefinitions)
local PD=require(Shared.PlayerData)
local Store=require(game.ServerScriptService.Server.SessionStore)
return function(t)
	local e=t.expect
	-- The starter retains the established Cash rate, without truncating evolved income.
	t.test("income uses its own fractional multiplier",function() e.equal(E.income(1),0.5) e.equal(E.income(1.5),0.75) e.equal(E.income(2.5),1.25) end)
	-- Every locked trainer multiplier participates in the one-second formula.
	for tier,multiplier in {2,5,12,30,80,100,200,500,1000,2000} do
		t.test("tier "..tier.." follows Power formula",function() e.equal(E.training(tier,1,0),5*multiplier) e.equal(E.training(tier,1.5,0),7.5*multiplier) end)
	end
	-- No configured boost means one; future injected factors use the same bounded math.
	t.test("boost factor defaults to one",function() e.equal(E.training(1,1,0),10) e.equal(E.training(1,1,0,2),20) end)
	-- Legitimate paid old levels survive without tier reinterpretation or double stacking.
	t.test("legacy training benefit is a floor",function() e.equal(E.training(1,1,100),205) e.equal(E.training(10,1,100),10000) end)
	-- Only a sequential affordable request may debit; exact price leaves zero Cash.
	for tier=2,10 do
		t.test("tier "..tier.." exact debit and replay protection",function()
			local cost=T.getOrdered()[tier].Price
			e.equal(E.purchase(cost,tier-1,tier),0)
			e.equal(E.purchase(cost-1,tier-1,tier),nil)
			e.equal(E.purchase(cost,tier,tier),nil)
		end)
	end
	-- Forged types, negative/NaN/infinite values cannot grant or spend currency.
	t.test("malformed economic input fails closed",function()
		for _,v in {-1,0/0,math.huge,"2",{}} do e.falsy(E.finite(v)) e.equal(E.purchase(v,1,2),nil) end
		for _,v in {0,11,1.5,"2",{}} do e.falsy(E.tier(v)) e.equal(E.purchase(1000,1,v),nil) end
		e.equal(E.purchase(1000,1,3),nil) e.equal(E.training(11,1,0),0)
	end)
	-- Saturation prevents overflow and never subtracts from a legitimate stored balance.
	t.test("high values stay finite",function() e.equal(E.add(C.MaxNumber-1,10000),C.MaxNumber) e.equal(E.add(-1,1),nil) e.equal(E.training(10,C.MaxNumber,0),C.MaxRate) end)
	-- Partial ticks never reward; exactly one elapsed second rewards once.
	t.test("one second tick is deterministic",function()
		local progress,count=0,0
		for _=1,8 do local due progress,due=E.advance(progress,0.125) if due then count+=1 end end
		e.equal(count,1) e.equal(progress,0)
	end)
	-- A delayed scheduler cannot catch up minutes of unvalidated activity.
	t.test("long stalls are capped",function() local p,due=E.advance(0,3600) e.equal(p,0.25) e.falsy(due) end)
	-- Repeated stop/start drops partial progress and cannot mint full ticks.
	t.test("short sessions never reward",function() for _=1,100 do local _,due=E.advance(0,0.1) e.falsy(due) end end)
	-- Old records gain only the free tier and keep opaque paid/owned pet data.
	t.test("additive save migration preserves paid fields",function()
		local raw=PD.default() raw.TrainerTier=nil raw.BaseUpgrades.TrainingLevel=37 raw.Entitlements={Paid=true}
		local data=PD.normalize(raw) e.equal(data.TrainerTier,1) e.equal(data.BaseUpgrades.TrainingLevel,37) e.truthy(data.Entitlements.Paid)
		e.deepEqual(data.Monsters,raw.Monsters)
	end)
	-- A malformed explicit tier is retained but blocked, not silently reset.
	t.test("invalid saved tiers are not erased",function() local raw=PD.default() raw.TrainerTier=99 local data=PD.normalize(raw) e.equal(data.TrainerTier,99) e.falsy(E.tier(data.TrainerTier)) end)
	-- Existing SessionStore persists all three economy fields and pet identities.
	t.test("save release and rejoin retain economy",function()
		local store=Store.new(Store.memoryAdapter()) local data=store:load("fixture")
		data.Cash=12.75 data.Power=150000000 data.TrainerTier=7
		local pets=PD.copy(data.Monsters) e.truthy(store:release("fixture")) local restored=store:load("fixture")
		e.equal(restored.Cash,12.75) e.equal(restored.Power,150000000) e.equal(restored.TrainerTier,7) e.deepEqual(restored.Monsters,pets)
	end)
	-- A new Studio backend has no previous Play's Cash or upgrades.
	t.test("fresh memory store resets economy",function() local s=Store.new(Store.memoryAdapter()) local d=s:load("fixture") e.equal(d.Cash,0) e.equal(d.Power,0) e.equal(d.TrainerTier,1) end)
	-- Configuration validation is reusable by startup and build/test tools.
	t.test("economy configuration validates",function() e.equal(#E.validate(),0) end)
end
