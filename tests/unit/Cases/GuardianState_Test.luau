local Shared=game.ReplicatedStorage.Shared
local State=require(Shared.GuardianState)
local Config=require(Shared.GuardianConfig)
return function(t)
	-- Every normal rarity contributes its design-locked amount to an independent meter.
	for rarity,amount in {Common=8,Uncommon=10,Rare=12,Epic=15,Legendary=20,Mythic=25,Cosmic=35} do
		t.test(rarity.." disturbance",function()
			local s=State.new(Config.Areas.Grasslands)
			s:pickup(rarity,10)
			t.expect.equal(s.Disturbance,amount) t.expect.equal(s.State,"DISTURBED")
		end)
	end
	-- Secret, Eternal and Divine wake immediately, not through numeric rarity guesses.
	for _,rarity in {"Secret","Eternal","Divine"} do
		t.test(rarity.." immediately wakes",function()
			local s=State.new(Config.Areas.Volcano) s:pickup(rarity,10)
			t.expect.equal(s.State,"WARNING") t.expect.equal(s.Disturbance,100) t.expect.equal(s.Activation,1)
		end)
	end
	-- Crossing 100 once cannot queue overlapping or deferred attacks.
	t.test("threshold and simultaneous ordered pickups schedule one wake",function()
		local s=State.new(Config.Areas.Grasslands)
		for _=1,12 do s:pickup("Common",0) end
		t.expect.equal(s.Disturbance,96) t.expect.equal(s.State,"DISTURBED")
		for _=1,100 do s:pickup("Common",0) end
		t.expect.equal(s.Activation,1) t.expect.equal(s.Disturbance,100)
	end)
	-- Each configured guardian uses exact warning/active/cooldown deadlines.
	for area,c in Config.Areas do
		t.test(area.." legal timed lifecycle",function()
			local s=State.new(c) local order={}
			local emit=function(state) table.insert(order,state) end
			s:pickup("Secret",0,emit) s:step(c.Warning-0.001,emit)
			t.expect.equal(s.State,"WARNING")
			s:step(c.Warning,emit) t.expect.equal(s.State,"HAZARD")
			s:step(c.Warning+c.Active,emit) t.expect.equal(s.State,"COOLDOWN")
			s:step(c.Warning+c.Active+c.Cooldown,emit)
			t.expect.deepEqual(order,{"DISTURBED","WARNING","HAZARD","COOLDOWN","SLEEPING"})
			t.expect.equal(s.Disturbance,0)
		end)
	end
	-- Skipped frames sample the active interval once before ending it, never prolonging it.
	t.test("late frame clips hazard and completes cooldown",function()
		local s=State.new(Config.Areas.Grasslands) s:pickup("Secret",10)
		local interval s:step(100,nil,function(a,b) interval={a,b} end)
		t.expect.deepEqual(interval,{11,12.2}) t.expect.equal(s.State,"SLEEPING")
	end)
	-- Field reset cancels pending warnings without a later stale attack.
	t.test("reset invalidates pending attack",function()
		local s=State.new(Config.Areas.Grasslands) s:pickup("Secret",0) s:reset()
		local hits=0 s:step(100,nil,function() hits+=1 end)
		t.expect.equal(hits,0) t.expect.equal(s.State,"SLEEPING") t.expect.equal(s.Disturbance,0)
	end)
	-- Illegal transitions are rejected rather than silently skipping the warning.
	t.test("sleep cannot transition directly to hazard",function()
		local s=State.new(Config.Areas.Grasslands)
		t.expect.throws(function() s:transition("HAZARD",0) end)
	end)
	-- Independent area instances do not leak contributions.
	t.test("area meters independent and unknown rarity rejected",function()
		local a,b=State.new(Config.Areas.Swamp),State.new(Config.Areas.Jungle)
		a:pickup("Cosmic",0) t.expect.falsy(b:pickup("Forged",0))
		t.expect.equal(b.Disturbance,0) t.expect.equal(a.Disturbance,35)
	end)
end
