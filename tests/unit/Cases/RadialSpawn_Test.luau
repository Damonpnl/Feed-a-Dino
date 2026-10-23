local Shared=game.ReplicatedStorage.Shared
local Layout=require(Shared.BiomeLayout)
local Radial=require(Shared.RadialSpawn)
local Areas=require(Shared.AreaDefinitions)
-- Measured live blockout floor (Grasslands is longer; others are 287.6 x 157.4).
local span={center=Vector3.new(0,-1.1,0),axis=Vector3.xAxis,lateral=Vector3.zAxis,longHalf=143.8,lateralHalf=78.7,y=-0.24}
local function sequence(values) local i=0 return function() i+=1 return values[(i-1)%#values+1] end end
local function flat(p) return Vector3.new(p.X,0,p.Z) end
return function(t)
	t.test("every launch biome has a valid, independent territory row",function()
		t.expect.equal(#Layout.validate(),0)
		for _,area in Areas.getOrdered() do t.expect.truthy(Layout.Areas[area.Id]) end
	end)
	t.test("guardian home is centred along the biome, off the through-lane, facing safety",function()
		local region=Radial.region(Layout.Areas.Grasslands,span)
		t.expect.near(region.HomeAlong,0,1e-6)
		t.expect.near(region.HomeLateral,-13,1e-6)
		t.expect.falsy(Radial.inLane(region,region.Home))
		t.expect.near(region.Facing:Dot(-span.axis),1,1e-6)
		t.expect.near(region.Home.Y,span.y,1e-6)
	end)
	t.test("lane side is configurable and mirrors the home",function()
		local row=table.clone(Layout.Areas.Swamp) row.LaneSide=-1
		local region=Radial.region(row,span)
		t.expect.near(region.HomeLateral,13,1e-6)
		row.LaneSide=0
		t.expect.near(Radial.region(row,span).HomeLateral,0,1e-6)
	end)
	t.test("candidates respect annulus, biome ends, floor edges and the lane",function()
		local row=Layout.Areas.Jungle
		local region=Radial.region(row,span)
		local list=Radial.candidates(region,row.Grid,function(p) return p end)
		t.expect.truthy(#list>=row.MinCandidates)
		for _,p in list do
			local r=Radial.distance(region,p)
			local along,lateral=Radial.localOf(region,p)
			assert(r>=row.MinRadius and r<=row.MaxRadius,"annulus")
			assert(math.abs(along)<=span.longHalf-row.EndMargin,"biome ends")
			assert(along-region.HomeAlong<=row.RearDepth+1e-6,"rear depth")
			assert(lateral>=-span.lateralHalf+row.Clearance,"floor edge")
			assert(lateral<=span.lateralHalf-row.LaneWidth-row.LaneMargin,"lane")
			assert(not Radial.inLane(region,p),"in lane")
		end
	end)
	t.test("rear depth caps spawns behind the guardian and leaves the safe side untouched",function()
		local row=table.clone(Layout.Areas.Jungle)
		local function counts(depth)
			row.RearDepth=depth
			local region=Radial.region(row,span)
			local front,rear,deepest=0,0,-math.huge
			for _,p in Radial.candidates(region,row.Grid,function(q) return q end) do
				local offset=Radial.localOf(region,p)-region.HomeAlong
				if offset<0 then front+=1 else rear+=1 end
				deepest=math.max(deepest,offset)
			end
			return front,rear,deepest
		end
		local openFront,openRear=counts(row.MaxRadius)
		local front,rear,deepest=counts(24)
		t.expect.equal(front,openFront)
		t.expect.truthy(rear>0 and rear<openRear)
		t.expect.truthy(deepest<=24+1e-6)
		local _,none=counts(0)
		t.expect.truthy(none<=openRear and none<rear)
	end)
	t.test("irregular geometry: the probe removes blocked points instead of assuming a circle",function()
		local row=Layout.Areas.Volcano
		local region=Radial.region(row,span)
		local open=Radial.candidates(region,row.Grid,function(p) return p end)
		-- A wall/prop occupying the whole -lateral half of the territory.
		local blocked=Radial.candidates(region,row.Grid,function(p) if Radial.localOf(region,p)<0 then return nil end return p end)
		t.expect.truthy(#blocked>0 and #blocked<#open)
		for _,p in blocked do local along=Radial.localOf(region,p) assert(along>=0,"blocked point used") end
	end)
	t.test("five picks keep minimum separation and never overlap the home",function()
		local row=Layout.Areas.CrystalCave
		local region=Radial.region(row,span)
		local list=Radial.candidates(region,row.Grid,function(p) return p end)
		for seed=1,25 do
			local rng=Random.new(seed)
			local occupied={}
			for _=1,5 do table.insert(occupied,Radial.pick(list,occupied,row.Separation,function() return rng:NextNumber() end)) end
			for i,a in occupied do
				assert(Radial.distance(region,a)>=row.MinRadius,"overlaps guardian")
				for j,b in occupied do if i~=j then assert((flat(a)-flat(b)).Magnitude>=row.Separation,"separation") end end
			end
		end
	end)
	t.test("saturated territory falls back to the most isolated candidate",function()
		local list={Vector3.new(0,0,0),Vector3.new(10,0,0),Vector3.new(30,0,0)}
		local point=Radial.pick(list,{Vector3.new(0,0,0)},100,sequence({0.5}))
		t.expect.equal(point,Vector3.new(30,0,0))
		t.expect.equal(Radial.pick({},{},10,sequence({0.5})),nil)
	end)
	t.test("draws are uniform over valid candidates and deterministic for injected randomness",function()
		local list={Vector3.new(0,0,0),Vector3.new(50,0,0),Vector3.new(100,0,0)}
		t.expect.equal(Radial.pick(list,{},10,sequence({0})),list[1])
		t.expect.equal(Radial.pick(list,{},10,sequence({0.999})),list[3])
		t.expect.equal(Radial.pick(list,{Vector3.new(0,0,0)},10,sequence({0})),list[2])
	end)
	t.test("invalid layout rows are rejected",function()
		local original=Layout.Areas.Grasslands
		for _,bad in {{MinRadius=4},{MaxRadius=10},{HomeAlong=1},{LaneSide=2},{Separation=1},{Facing="Up"},{RearDepth=-1},{RearDepth=200}} do
			local row=table.clone(original) for k,v in bad do row[k]=v end
			local rows=table.clone(Layout.Areas) rows.Grasslands=row
			t.expect.truthy(#Layout.validate(rows)>0)
		end
	end)
end
