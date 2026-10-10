--!nonstrict
local Shared = game.ReplicatedStorage.Shared
local State = require(Shared.FieldState)
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Rarities = require(Shared.RarityDefinitions)
local function make(high)
	local nodes, serial = {}, 0
	for _, area in Areas.getOrdered() do
		for index = 1, 5 do table.insert(nodes, {Id=area.Id .. ":" .. index, AreaId=area.Id}) end
	end
	local state = State.new(nodes, function(low, upper) return if high then upper else low end,
		function() serial += 1 return "test-" .. serial end)
	state:start(0)
	return state
end
local function count(records) local total=0 for _ in records do total+=1 end return total end
return function(t)
	local e = t.expect
	-- Initial field is global, full, and has no duplicate resource IDs.
	t.test("initializes exactly five resources per launch area", function()
		local s=make() e.equal(count(s.Records),25) e.equal(#s:validate(),0) e.equal(s.NextResetAt,300)
		for _, area in Areas.getOrdered() do local n=0 for _,r in s.Records do if r.AreaId==area.Id then n+=1 end end e.equal(n,5) end
	end)
	-- Hard reset begins at 300, never one moment before it.
	t.test("enters a ten-second reset at the 300-second boundary", function()
		local s=make() s:step(299.99) e.equal(s.Phase,"Normal")
		s:step(300) e.equal(s.Phase,"Reset") e.equal(count(s.Records),0)
		s:step(309.99) e.equal(count(s.Records),0)
		s:step(310) e.equal(s.Phase,"Normal") e.equal(count(s.Records),25) e.equal(s.NextResetAt,600)
	end)
	-- A future respawn loses ownership when the hard reset takes over its node.
	t.test("cancels pending mid-cycle respawns at reset", function()
		local s=make() local node=s.Nodes["Grasslands:1"] s:release(node.RecordId,295)
		e.equal(node.RespawnAt,313) s:step(300) e.equal(node.RespawnAt,nil)
		s:step(310) local resetId=node.RecordId s:step(320) e.equal(node.RecordId,resetId) e.equal(count(s.Records),25)
	end)
	-- Carried loot survives and cannot free the newly occupied reset node when consumed.
	t.test("preserves carried resources across reset without stealing fresh node ownership", function()
		local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId
		e.equal(s:claim(id,1),"World") s:step(300) e.equal(s.Records[id].State,"Carried") e.equal(s.Records[id].NodeId,nil)
		s:step(310) e.equal(count(s.Records),26) local fresh=node.RecordId
		s:release(id,311) e.equal(node.RecordId,fresh) e.equal(node.RespawnAt,nil) e.equal(#s:validate(),0)
	end)
	-- A contested resource can be claimed only once, and one carrier cannot hold two records.
	t.test("rejects duplicate pickup and a second carried resource", function()
		local s=make() local id=s.Nodes["Grasslands:1"].RecordId
		e.truthy(s:claim(id,1)) e.falsy(s:claim(id,2)) e.falsy(s:claim(s.Nodes["Grasslands:2"].RecordId,1))
		e.equal(#s:validate(),0)
	end)
	-- Drop/reclaim is a state transition on the same ID and occupied node.
	t.test("preserves ID and node occupancy when another player takes a drop", function()
		local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId
		s:claim(id,1) e.falsy(s:drop(id,2,Vector3.zero,1)) e.truthy(s:drop(id,1,Vector3.zero,1))
		e.equal(node.RecordId,id) e.equal(s:claim(id,2),"Dropped") e.equal(s.Records[id].OwnerUserId,2)
		e.equal(count(s.Records),25) e.equal(#s:validate(),0)
	end)
	-- Exactly twenty seconds after dropping, removal schedules the source rarity's respawn.
	t.test("expires abandoned drops at twenty seconds", function()
		local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId
		s:claim(id,1) s:drop(id,1,Vector3.zero,2) s:step(21.99) e.truthy(s.Records[id])
		s:step(22) e.falsy(s.Records[id]) e.equal(node.RespawnAt,40) s:step(40) e.truthy(node.RecordId)
	end)
	-- Failed carry validation may roll back a claim without duplicating or deleting the world record.
	t.test("rolls a failed claim back to its previous physical state", function()
		local s=make() local id=s.Nodes["Grasslands:1"].RecordId local previous=s:claim(id,1)
		s:rollbackClaim(id,1,previous) e.equal(s.Records[id].State,"World") e.equal(s.Records[id].OwnerUserId,nil)
		e.equal(#s:validate(),0)
	end)
	-- Chase resources leave a vacant node until reset after consumption or drop expiry.
	t.test("never respawns Secret+ mid-cycle", function()
		local s=make(true) local node=s.Nodes["Jungle:1"] e.equal(Resources.get(s.Records[node.RecordId].ResourceId).Rarity,"Secret")
		s:release(node.RecordId,1) e.equal(node.RespawnAt,nil) s:step(299) e.equal(node.RecordId,nil)
	end)
	-- Divine remains reserved while carried, including through a reset and later drop.
	t.test("limits Divine across reset and old-carried drops", function()
		local s=make(true) local id=s.Nodes["Volcano:1"].RecordId e.equal(Resources.get(s.Records[id].ResourceId).Rarity,"Divine")
		s:claim(id,1) s:step(300) s:step(310) s:drop(id,1,Vector3.zero,311)
		local n=0 for _,record in s.Records do if Resources.get(record.ResourceId).Rarity=="Divine" then n+=1 end end
		e.equal(n,1) e.equal(#s:validate(),0)
	end)
	-- A runtime reset blocks pickups, even if a carried item is dropped during its transition.
	t.test("blocks pickup during reset", function()
		local s=make() local id=s.Nodes["Grasslands:1"].RecordId s:claim(id,1) s:step(300)
		s:drop(id,1,Vector3.zero,301) e.falsy(s:claim(id,2)) s:step(310) e.truthy(s:claim(id,2))
	end)
	-- Duplicate release is idempotent and cannot schedule a second timer.
	t.test("does not reschedule an already-consumed resource", function()
		local s=make() local node=s.Nodes["Grasslands:1"] local id=node.RecordId
		e.truthy(s:release(id,1)) e.falsy(s:release(id,10)) e.equal(node.RespawnAt,19)
	end)
	-- Each allowed tier uses its prescribed delay; a refill's roll excludes every chase resource.
	for _, row in {{"RawMeat",18},{"BoneChunk",18},{"PrimeMeat",18},{"GiantRib",25},{"PrimalCatalyst",25},{"MutantLeech",40},{"ToxicCatalyst",40}} do
		t.test("uses the specified respawn delay for " .. row[1], function()
			local s=make(true) local definition=Resources.get(row[1]) local node=s.Nodes[definition.Area .. ":1"]
			s:release(node.RecordId,0) local record=s:create(node,row[1],"HardReset") s:release(record.InstanceId,1)
			e.equal(node.RespawnAt,1+row[2]) s:step(1+row[2]-0.01) e.equal(node.RecordId,nil)
			s:step(1+row[2]) e.truthy(node.RecordId) e.falsy(Rarities.isSecretPlus(Resources.get(s.Records[node.RecordId].ResourceId).Rarity))
		end)
	end
	-- ID generation and node designation must not silently accept collisions.
	t.test("rejects duplicate node designations", function()
		e.throws(function() State.new({{Id="a",AreaId="Grasslands"},{Id="a",AreaId="Grasslands"}},function() return 1 end,function() return "id" end) end)
	end)
end
