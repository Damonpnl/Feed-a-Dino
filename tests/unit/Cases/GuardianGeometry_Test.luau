local Config=require(game.ReplicatedStorage.Shared.GuardianConfig)
local Geometry=require(game.ReplicatedStorage.Shared.GuardianGeometry)
return function(t)
	-- Complete swept windows hit the center even when both sampled fronts miss it.
	for area,c in Config.Areas do
		t.test(area.." low FPS sweep catches center",function()
			local p=Vector3.new(0,3,0)
			t.expect.truthy(Geometry.hit(c,CFrame.identity,p,p,0,1))
		end)
		-- Regions must not hit outside the warning footprint or vertical extent.
		t.test(area.." outside and above are safe",function()
			for _,p in {Vector3.new(500,3,500),Vector3.new(0,c.Height+1,0),Vector3.new(0,-1,0)} do
				t.expect.falsy(Geometry.hit(c,CFrame.identity,p,p,0,1))
			end
		end)
	end
	-- The warning footprint exactly uses configured dimensions; active front starts inside it.
	t.test("warning and active geometry share frame and bounds",function()
		for _,c in Config.Areas do
			local f,size=Geometry.visual(c,CFrame.identity,1,true)
			t.expect.near(f.Position.Y,0.12)
			if c.Kind=="Shockwave" then t.expect.equal(size.Y,c.Radius*2)
			else t.expect.equal(size.X,c.Length) t.expect.equal(size.Z,c.Width) end
		end
	end)
	-- Motion crossing a charge front is detected without Touched callbacks.
	t.test("moving carrier crosses charge sweep",function()
		local c=Config.Areas.Grasslands
		t.expect.truthy(Geometry.hit(c,CFrame.identity,Vector3.new(40,3,0),Vector3.new(-40,3,0),0,1))
	end)
	-- Rotation/translation cannot change collision semantics.
	t.test("rotated warning frame preserves hit and miss",function()
		local c=Config.Areas.Volcano local f=CFrame.new(100,20,70)*CFrame.Angles(0,1.2,0)
		local hit=f:PointToWorldSpace(Vector3.new(0,3,0)) local miss=f:PointToWorldSpace(Vector3.new(100,3,0))
		t.expect.truthy(Geometry.hit(c,f,hit,hit,0,1)) t.expect.falsy(Geometry.hit(c,f,miss,miss,0,1))
	end)
	-- Shockwave is an expanding filled disc, not a full-radius instant hit.
	t.test("shockwave cannot reach outside its current radius",function()
		local c=Config.Areas.Jungle local p=Vector3.new(30,3,0)
		t.expect.falsy(Geometry.hit(c,CFrame.identity,p,p,0,0.5))
		t.expect.truthy(Geometry.hit(c,CFrame.identity,p,p,0.5,1))
	end)
end
