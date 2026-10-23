local H=game.ReplicatedStorage.Shared
local Aim,G,Chase,C,M=require(H.GuardianAim),require(H.GuardianGeometry),require(H.GuardianChase),require(H.GuardianConfig),require(H.MovementCalculator)
return function(t)
	local e=t.expect
	-- A forged/teleport-sized observed velocity cannot create an unlimited leading attack.
	t.test("prediction bounds horizontal velocity and lead",function()
		local p=Vector3.new(100,3,0)
		e.near((Aim.predict(p,Vector3.new(1e6,100,0),100,30)-p).Magnitude,30)
		e.equal(Aim.predict(p,Vector3.zero,1,30),p)
		e.equal(Aim.predict(p,Vector3.new(0/0,0,0),1,30),p)
	end)
	-- Fast characters crossing between samples still hit; corner radius is NOT enlarged.
	t.test("swept catch crosses without endpoint overlap",function()
		e.truthy(G.catchSegment(Vector3.new(-50,0,0),Vector3.new(50,0,0),Vector3.new(10,12,18),5,8))
		e.falsy(G.catchSegment(Vector3.new(-50,0,14.01),Vector3.new(50,0,14.01),Vector3.new(10,12,18),5,8))
		e.falsy(G.catchSegment(Vector3.new(9,0,13),Vector3.new(9,0,13),Vector3.new(10,12,18),5,8))
		e.truthy(G.catchSegment(Vector3.new(8,0,13),Vector3.new(8,0,13),Vector3.new(10,12,18),5,8))
		e.falsy(G.catchSegment(Vector3.new(-50,14.01,0),Vector3.new(50,14.01,0),Vector3.new(10,12,18),5,8))
	end)
	-- Slow Mode is independent of the faster first milestone; all penalties remain applied.
	t.test("fresh and progressed carry curves never exceed unloaded",function()
		for _,power in {0,1000,10000,100000,1e6,1e7,1e8,150e6,9e15} do
			e.truthy(M.carryBase(power)<=M.base(power))
			e.equal(M.effective(power,true,false,0,false),16)
			e.near(M.effective(power,true,true,.5,false),8)
		end
	end)
	local lane={origin=Vector3.zero,axis=Vector3.xAxis,lateral=Vector3.zAxis,entrance=0,minAlong=10,maxAlong=1600,halfWidth=70,surfaceY=0}
	t.test("reset boundary equality is inside even above or beside the lane",function()
		e.falsy(Chase.isSafe(lane,Vector3.zero))
		e.falsy(Chase.isSafe(lane,Vector3.new(.001,1000,1000)))
		e.truthy(Chase.isSafe(lane,Vector3.new(-.001,1000,1000)))
	end)
	-- Baselines are fixed biome configuration, not supplied player Power/speed.
	t.test("biome pursuit progression stays fixed",function()
		local previous=0
		for _,id in {"Grasslands","Swamp","Jungle","CrystalCave","Volcano"} do
			local c=C.Areas[id] e.truthy(c.BaselineWalk>previous) previous=c.BaselineWalk
			e.near(Chase.speed("Common",c,.2,0),c.BaselineWalk*.8*c.SpeedRatio)
			e.truthy(Chase.speed("Divine",c,0,1000)<Chase.Timing.ReturnSpeed)
		end
	end)
	for id,c in C.Areas do
		-- Every hazard can form a bounded forecast; the returned footprint is committed data.
		t.test(id.." predicted frame stays on the field",function()
			local origin=Vector3.new(500,8,0) local target=Vector3.new(470,3,0)
			local frame=Aim.frame(lane,c,origin,target,Vector3.new(-22,0,0),30,.75)
			e.truthy(frame)
			e.truthy(frame.X-Chase.footprintHalf(c)>=0)
			e.truthy(math.abs(frame.Z)+(if c.Kind=="Shockwave" then c.Radius else c.Width/2)<=76)
			if c.Kind=="Shockwave" then e.truthy(Chase.horizontal(origin,frame.Position)<=c.LeapRange) end
		end)
	end
end
