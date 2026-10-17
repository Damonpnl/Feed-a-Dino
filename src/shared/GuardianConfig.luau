--!nonstrict
-- Disturbance/threshold are locked design. Geometry/durations below are temporary
-- graybox tuning, not permanent progression or economic values.
local Config = {
	Threshold = 100, Baseline = 0,
	Disturbance = {Common=8, Uncommon=10, Rare=12, Epic=15, Legendary=20, Mythic=25, Cosmic=35},
	Immediate = {Secret=true, Eternal=true, Divine=true},
	-- No decay. Pickups during WARNING/HAZARD/COOLDOWN are acknowledged but do not
	-- queue another attack. Cooldown and field reset clear disturbance to baseline.
	-- Pursuit (PROVISIONAL, measured in Studio; see docs/GAMEPLAY_TUNING_REPORT.md):
	-- Wake: seconds before moving. SpeedRatio: engaged speed as a multiple of the fixed
	-- baseline carry speed 16*(1-worst slowdown), never the player's live WalkSpeed, so
	-- future Speed upgrades make escape easier. CatchUpRatio applies from 2*EngageDistance
	-- and blends to SpeedRatio at EngageDistance (studs, centre to player root).
	-- CatchReach: studs from the guardian body box surface to the player root.
	Areas = {
		Grasslands = {Kind="Charge", Warning=1, Active=1.2, Cooldown=8, Length=90, Width=16, Height=12, Front=10,
			Wake=0.8, SpeedRatio=1.10, CatchUpRatio=1.75, EngageDistance=30, CatchReach=5},
		Swamp = {Kind="Lunge", Warning=0.9, Active=0.8, Cooldown=8, Length=48, Width=26, Height=10, Front=12,
			Wake=0.8, SpeedRatio=1.10, CatchUpRatio=1.75, EngageDistance=30, CatchReach=5},
		Jungle = {Kind="Shockwave", Warning=1.25, Active=1.4, Cooldown=8, Length=80, Width=80, Height=10, Radius=40, Front=1,
			Wake=0.8, SpeedRatio=1.10, CatchUpRatio=1.75, EngageDistance=30, CatchReach=5},
		CrystalCave = {Kind="Charge", Warning=0.75, Active=0.9, Cooldown=8, Length=110, Width=18, Height=12, Front=12,
			Wake=0.8, SpeedRatio=1.10, CatchUpRatio=1.75, EngageDistance=30, CatchReach=5},
		Volcano = {Kind="FireSweep", Warning=1.25, Active=1.8, Cooldown=10, Length=80, Width=40, Height=14, Front=8,
			Wake=0.8, SpeedRatio=1.10, CatchUpRatio=1.75, EngageDistance=30, CatchReach=5},
	},
	-- Catch consequence. Ragdoll ends before Recovery; pickup and further catches/hazard
	-- consequences stay blocked until Recovery. Launch speeds are studs/second.
	Catch = {Ragdoll=1.1, Recovery=2.2, Horizontal=34, Vertical=26, VerticalReach=8},
}
function Config.validate()
	local errors = {}
	for _, area in require(script.Parent.AreaDefinitions).getOrdered() do
		local c = Config.Areas[area.Id]
		if not c then table.insert(errors, "Missing guardian: "..area.Id) continue end
		for _,key in {"Warning","Active","Cooldown","Length","Width","Height","Front"} do
			local n=c[key]
			if type(n)~="number" or n~=n or n<=0 or n>=math.huge then table.insert(errors,"Invalid guardian "..area.Id.."."..key) end
		end
		if c.Warning<0.75 or c.Warning>1.25 then table.insert(errors,"Invalid warning duration: "..area.Id) end
		for _,key in {"Wake","SpeedRatio","CatchUpRatio","EngageDistance","CatchReach"} do
			local n=c[key]
			if type(n)~="number" or n~=n or n<=0 or n>=math.huge then table.insert(errors,"Invalid guardian "..area.Id.."."..key) end
		end
		if type(c.Wake)=="number" and (c.Wake<0.5 or c.Wake>1) then table.insert(errors,"Wake left the 0.5-1.0 second band: "..area.Id) end
		if type(c.SpeedRatio)=="number" and (c.SpeedRatio<1 or c.SpeedRatio>1.25) then table.insert(errors,"Engaged pursuit ratio outside 1.0-1.25: "..area.Id) end
		if type(c.CatchUpRatio)=="number" and type(c.SpeedRatio)=="number" and (c.CatchUpRatio<c.SpeedRatio or c.CatchUpRatio>2) then
			table.insert(errors,"Catch-up ratio must be between the engaged ratio and 2: "..area.Id)
		end
		if type(c.CatchReach)=="number" and (c.CatchReach<3 or c.CatchReach>8) then table.insert(errors,"Catch reach outside 3-8 studs: "..area.Id) end
		local chase=require(script.Parent.GuardianChase)
		if type(c.CatchUpRatio)=="number" and chase.Timing.BaselineWalk*c.CatchUpRatio*chase.Profiles.Divine.Speed>=chase.Timing.ReturnSpeed then
			table.insert(errors,"Return travel must be faster than the fastest pursuit: "..area.Id)
		end
		if c.Kind~="Charge" and c.Kind~="Lunge" and c.Kind~="Shockwave" and c.Kind~="FireSweep" then table.insert(errors,"Invalid hazard: "..area.Id) end
		if c.Kind=="Shockwave" and (type(c.Radius)~="number" or not(c.Radius>0 and c.Radius<math.huge)) then table.insert(errors,"Invalid radius") end
	end
	local catch=Config.Catch
	for _,key in {"Ragdoll","Recovery","Horizontal","Vertical","VerticalReach"} do
		local n=catch[key]
		if type(n)~="number" or n~=n or n<=0 or n>=math.huge then table.insert(errors,"Invalid guardian catch."..key) end
	end
	if catch.Ragdoll>=catch.Recovery or catch.Recovery>4 or catch.Horizontal>60 or catch.Vertical>50 then
		table.insert(errors,"Catch recovery must be short and bounded")
	end
	for _, message in require(script.Parent.GuardianChase).validate() do table.insert(errors, message) end
	for _, message in require(script.Parent.CarryDebuff).validate() do table.insert(errors, message) end
	return errors
end
for _,row in Config.Areas do table.freeze(row) end
table.freeze(Config.Areas) table.freeze(Config.Catch) table.freeze(Config.Disturbance) table.freeze(Config.Immediate)
return table.freeze(Config)
