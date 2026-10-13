local Shared=game.ReplicatedStorage.Shared
local State=require(Shared.FieldState)
local Areas=require(Shared.AreaDefinitions)
local Resources=require(Shared.ResourceDefinitions)
local Roller=require(Shared.FieldRoller)
local function make()
	local nodes,serial={},0
	for _,area in Areas.getOrdered() do for i=1,5 do table.insert(nodes,{Id=area.Id..":"..i,AreaId=area.Id}) end end
	local s=State.new(nodes,function(low) return low end,function() serial+=1 return "phase2-"..serial end)
	s:start(1000) return s
end
return function(t)
	-- Probabilities are measured on raw weighted rolls, before deliberate Secret+ batch caps.
	for index,area in Areas.getOrdered() do
		t.test("200000 seeded rolls approximate "..area.Id.." weights",function()
			local rng=Random.new(20261010+index) local counts={} local n=200000
			for _=1,n do local id=Roller.pick(area.ResourcePool,function(a,b) return rng:NextInteger(a,b) end) counts[id]=(counts[id] or 0)+1 end
			local maxZ=0
			for _,entry in area.ResourcePool do
				local p=entry.SpawnWeight/100 local expected=n*p local actual=counts[entry.Id] or 0
				local z=math.abs(actual-expected)/math.sqrt(n*p*(1-p)) maxZ=math.max(maxZ,z)
				t.expect.truthy(actual>0 and z<6)
			end
			print(string.format("[Phase2Statistics] %s n=%d maxZ=%.3f",area.Id,n,maxZ))
		end)
	end
	-- Startup is anchored to this server's epoch; repeated initialization cannot repopulate nodes.
	t.test("startup establishes period and rejects duplicate initialization",function()
		local s=make() t.expect.equal(s.Epoch,1000) t.expect.equal(s.NextResetAt,1290)
		t.expect.throws(function() s:start(1010) end)
	end)
	-- A lagged scheduler must not lengthen a reset or shift future periods.
	t.test("late tick reconciles the current period without timer drift",function()
		local s=make() s:step(1350)
		t.expect.equal(s.Phase,"Normal") t.expect.equal(s.ResetEndsAt,1300) t.expect.equal(s.NextResetAt,1590)
		s:step(2195) t.expect.equal(s.Phase,"Reset") t.expect.equal(s.ResetEndsAt,2200)
		s:step(2801) t.expect.equal(s.Phase,"Normal") t.expect.equal(s.NextResetAt,3090)
		t.expect.equal(#s:validate(),0)
	end)
	-- Terminal state is explicit on the retired record; it no longer owns a live ID/node.
	t.test("consumed and destroyed records are terminal and idempotent",function()
		local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId local record=s.Records[id]
		s:claim(id,1) t.expect.truthy(s:release(id,1001,"CONSUMED")) t.expect.equal(record.State,"CONSUMED")
		t.expect.falsy(s:release(id,1002,"DESTROYED")) t.expect.equal(record.State,"CONSUMED")
		local record2=s.Records[s.Nodes["Grasslands:2"].RecordId] s:step(1290)
		t.expect.equal(record2.State,"DESTROYED") t.expect.equal(next(s.Records),nil)
	end)
	-- Requests on both sides of the reset boundary cannot create duplicate ownership.
	t.test("1000 reset interaction orderings preserve ownership",function()
		for i=1,1000 do
			local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId
			if i%2==0 then s:claim(id,1) s:step(1290) s:drop(id,1,Vector3.zero,1290)
			else s:step(1290) t.expect.falsy(s:claim(id,1)) end
			t.expect.falsy(s:claim(id,2)) t.expect.equal(#s:validate(),0)
			s:step(1300) local fresh=node.RecordId
			if s.Records[id] then s:claim(id,2) s:release(id,1300,"CONSUMED") end
			t.expect.equal(node.RecordId,fresh) t.expect.equal(#s:validate(),0)
		end
	end)
end
