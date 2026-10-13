--!nonstrict
-- Disturbance/threshold are locked design. Geometry/durations below are temporary
-- graybox tuning, not permanent progression or economic values.
local Config = {
	Threshold = 100, Baseline = 0,
	Disturbance = {Common=8, Uncommon=10, Rare=12, Epic=15, Legendary=20, Mythic=25, Cosmic=35},
	Immediate = {Secret=true, Eternal=true, Divine=true},
	-- No decay. Pickups during WARNING/HAZARD/COOLDOWN are acknowledged but do not
	-- queue another attack. Cooldown and field reset clear disturbance to baseline.
	Areas = {
		Grasslands = {Kind="Charge", Warning=1, Active=1.2, Cooldown=8, Length=90, Width=16, Height=12, Front=10},
		Swamp = {Kind="Lunge", Warning=0.9, Active=0.8, Cooldown=8, Length=48, Width=26, Height=10, Front=12},
		Jungle = {Kind="Shockwave", Warning=1.25, Active=1.4, Cooldown=8, Length=80, Width=80, Height=10, Radius=40, Front=1},
		CrystalCave = {Kind="Charge", Warning=0.75, Active=0.9, Cooldown=8, Length=110, Width=18, Height=12, Front=12},
		Volcano = {Kind="FireSweep", Warning=1.25, Active=1.8, Cooldown=10, Length=80, Width=40, Height=14, Front=8},
	},
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
		if c.Kind~="Charge" and c.Kind~="Lunge" and c.Kind~="Shockwave" and c.Kind~="FireSweep" then table.insert(errors,"Invalid hazard: "..area.Id) end
		if c.Kind=="Shockwave" and (type(c.Radius)~="number" or not(c.Radius>0 and c.Radius<math.huge)) then table.insert(errors,"Invalid radius") end
	end
	return errors
end
for _,row in Config.Areas do table.freeze(row) end
table.freeze(Config.Areas) table.freeze(Config.Disturbance) table.freeze(Config.Immediate)
return table.freeze(Config)
