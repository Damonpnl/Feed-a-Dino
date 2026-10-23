local H=game.ReplicatedStorage.Shared
local M,C,D,PD=require(H.MovementCalculator),require(H.MovementConfig),require(H.CarryDebuff),require(H.PlayerData)
return function(t)
	local e=t.expect
	-- Each provisional milestone changes speed only at its exact threshold.
	for i,row in C.Milestones do
		t.test("milestone "..row.Power,function()
			e.equal(M.base(row.Power),row.Speed)
			e.equal(M.carryBase(row.Power),row.CarrySpeed)
			if i>1 then e.equal(M.base(row.Power-1),C.Milestones[i-1].Speed) end
		end)
	end
	-- Extreme valid Power saturates while malformed Power never grants fast movement.
	t.test("bounded and malformed Power",function()
		e.equal(M.base(9e15),72)
		for _,v in {-1,0/0,math.huge,"150000000",{}} do e.equal(M.base(v),16) end
		e.equal(M.base(nil),16)
	end)
	-- Precision mode suppresses only the progression base, not penalties.
	t.test("precision mode retains carry penalties",function()
		e.equal(M.effective(150e6,true,false,0,false),16)
		e.near(M.effective(150e6,true,true,0.3,false),11.2)
	end)
	-- The carrying cap is before combined percentage penalties, never a speed floor.
	t.test("progressing carry base precedes slowdown",function()
		e.equal(M.effective(150e6,false,true,0,false),52)
		e.near(M.effective(150e6,false,true,0.5,false),26)
		e.near(M.effective(0,false,true,0.5,false),11)
	end)
	-- Existing additive curse semantics and cap are unchanged.
	t.test("combined slowdown remains additive",function()
		e.near(M.effective(10000,false,true,D.applied(0.5,0.2),false),27*0.38)
	end)
	-- Input/momentum effects do not silently become numerical speed reductions.
	for _,id in {"InvertedControls","CursedMomentum"} do
		t.test(id.." retains numeric speed",function()
			local a={Rarity="Cosmic",Title="test",Effects={{Id=id,Tier="Strong",Extra=0,Normal=3,Active=2,Warning=1}}}
			e.equal(D.extraSlowdown(a,3.5),0)
			e.near(M.effective(10000,false,true,D.applied(0.1,D.extraSlowdown(a,3.5)),false),24.3)
		end)
	end
	-- A cyclic slowdown applies and expires without changing Power or the capped base.
	t.test("timed curse transitions",function()
		local a={Rarity="Mythic",Title="test",Effects={{Id="ShiftingWeight",Tier="Moderate",Extra=.14,Normal=3,Active=2,Warning=1}}}
		e.near(M.effective(10000,false,true,D.applied(.1,D.extraSlowdown(a,3.1)),false),27*.76)
		e.near(M.effective(10000,false,true,D.applied(.1,D.extraSlowdown(a,5.1)),false),27*.9)
	end)
	-- Slow Mode and Power cannot remove ragdoll movement suppression.
	t.test("ragdoll precedence",function()
		for _,slow in {false,true} do e.equal(M.effective(150e6,slow,false,0,true),0) end
		e.equal(M.effective(150e6,false,false,0,false),72)
	end)
	-- Additive preference migration never erases existing progression or opaque fields.
	t.test("old saves gain a boolean preference",function()
		local raw=PD.default() raw.SlowMode=nil raw.Power=10000 raw.Purchased={Keep=true}
		local out=PD.normalize(raw) e.equal(out.SlowMode,false) e.equal(out.Power,10000) e.truthy(out.Purchased.Keep)
		raw.SlowMode=true e.truthy(PD.normalize(raw).SlowMode)
		raw.SlowMode="true" e.equal(PD.normalize(raw).SlowMode,false)
	end)
	-- Preference persists in the existing session backend, not a second save system.
	t.test("memory rejoin restores preference and progression",function()
		local Store=require(game.ServerScriptService.Server.SessionStore)
		local s=Store.new(Store.memoryAdapter()) local d=s:load("movement")
		d.SlowMode=true d.Power=1e7 d.Cash=123.5 d.TrainerTier=4
		e.truthy(s:release("movement")) local r=s:load("movement")
		e.truthy(r.SlowMode) e.equal(r.Power,1e7) e.equal(r.Cash,123.5) e.equal(r.TrainerTier,4)
	end)
	-- All production milestones are ordered, bounded and centrally validated.
	t.test("movement configuration validates",function() e.equal(#M.validate(),0) end)
end
