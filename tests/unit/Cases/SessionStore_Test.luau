-- Save contracts tested with an in-memory adapter; no network, players, or live saves.
local Store = require(game.ServerScriptService.Server.SessionStore)
local PlayerData = require(game.ReplicatedStorage.Shared.PlayerData)
local function fixture(initial, options)
	local db = {value=PlayerData.copy(initial),reads=0,writes=0}
	local adapter = {
		get=function() db.reads+=1 return PlayerData.copy(db.value) end,
		update=function(_, transform)
			db.writes+=1
			local value,ids,metadata=transform(PlayerData.copy(db.value),{
				GetUserIds=function() return {123} end, GetMetadata=function() return {version="existing"} end,
			})
			if value~=nil then db.value=PlayerData.copy(value) db.ids,db.metadata=ids,metadata end
			return value
		end,
	}
	options=options or {} options.wait=options.wait or function() end options.log=function() end
	return Store.new(adapter,options),db,adapter
end
return function(t)
	-- A genuinely absent save can safely become a new save.
	t.test("missing data is writable and saved",function()
		local s,db=fixture(nil) s:load("u_1")
		t.expect.equal(s:status("u_1").Status,"Missing")
		s:get("u_1").Cash=25 t.expect.truthy(s:save("u_1")) t.expect.equal(db.value.Cash,25)
	end)
	-- Successful loads retain progression, purchases and fields owned by other systems.
	t.test("existing save and unknown ownership fields survive round trip",function()
		local raw=PlayerData.default() raw.Cash=48 raw.Inventory={PaidEgg=2} raw.Receipts={purchase=true}
		raw.BaseUpgrades.PaidSlot=true raw.Monsters.ProtoRex.PurchaseId="existing"
		local s,db=fixture(raw) s:load("u_1") t.expect.truthy(s:save("u_1"))
		t.expect.deepEqual(db.value,raw) t.expect.equal(s:status("u_1").Status,"Loaded")
	end)
	-- A stale equipped pointer must never reset an already-owned starter.
	t.test("invalid equipped ID does not erase owned starter progress",function()
		local raw=PlayerData.default() raw.EquippedMonster="Missing" raw.Monsters.ProtoRex.Growth=80
		local s=fixture(raw) local data=s:load("u_1")
		t.expect.equal(data.EquippedMonster,"ProtoRex") t.expect.equal(data.Monsters.ProtoRex.Growth,80)
	end)
	-- Exhausted read retries cannot turn an outage into an empty writable save.
	t.test("failed loads remain read only through save and release",function()
		local s,db,adapter=fixture({Cash=100}) adapter.get=function() db.reads+=1 error("offline") end
		s:load("u_1") s:get("u_1").Cash=999
		t.expect.equal(db.reads,3) t.expect.equal(s:status("u_1").Status,"LoadFailed")
		t.expect.falsy(s:save("u_1")) s:release("u_1") t.expect.equal(db.writes,0) t.expect.equal(db.value.Cash,100)
	end)
	-- Malformed persisted containers are quarantined instead of normalized destructively.
	t.test("invalid stored structure is never overwritten",function()
		for _,raw in {"bad",{Monsters="bad"},{Monsters={ProtoRex=7}},{Stats=1}} do
			local s,db=fixture(raw) s:load("u_1")
			t.expect.equal(s:status("u_1").Status,"InvalidData") t.expect.falsy(s:save("u_1")) t.expect.equal(db.writes,0)
		end
	end)
	-- Studio sessions must not call even the injected write API.
	t.test("read only mode cannot write",function()
		local s,db=fixture(nil,{readOnly=true}) s:load("u_1")
		t.expect.equal(s:status("u_1").Status,"StudioReadOnly") s:release("u_1") t.expect.equal(db.writes,0)
	end)
	-- The full record, including unknown ownership fields, participates in conflict detection.
	t.test("newer stored ownership blocks stale save",function()
		local s,db=fixture({Cash=10,Entitlements={}}) s:load("u_1") db.value.Entitlements.Paid=true
		t.expect.falsy(s:save("u_1")) t.expect.equal(s:status("u_1").Status,"Conflict")
		t.expect.truthy(db.value.Entitlements.Paid) t.expect.falsy(s:save("u_1")) t.expect.equal(db.writes,1)
	end)
	-- A callback retried by UpdateAsync must recheck the newly supplied value.
	t.test("retried transform rejects intervening update",function()
		local s,db,adapter=fixture({Cash=10}) s:load("u_1")
		adapter.update=function(_,fn) fn(db.value) db.value={Cash=50} return fn(db.value) end
		t.expect.falsy(s:save("u_1")) t.expect.equal(db.value.Cash,50)
	end)
	-- GetUserIds and metadata must be carried through an UpdateAsync transform.
	t.test("preserves DataStore metadata and user ids",function()
		local s,db=fixture(nil) s:load("u_1") s:save("u_1")
		t.expect.deepEqual(db.ids,{123}) t.expect.deepEqual(db.metadata,{version="existing"})
	end)
	-- A later save compares against the preceding successful write, not the initial load.
	t.test("successive saves advance the conflict baseline",function()
		local s,db=fixture(nil) s:load("u_1") s:get("u_1").Cash=1 t.expect.truthy(s:save("u_1"))
		s:get("u_1").Cash=2 t.expect.truthy(s:save("u_1")) t.expect.equal(db.value.Cash,2)
	end)
	-- Read retries that eventually succeed still load the actual record.
	t.test("transient read failure recovers without default overwrite",function()
		local s,db,adapter=fixture({Cash=80}) local read=adapter.get
		adapter.get=function(key) if db.reads==0 then db.reads=1 error("temporary") end return read(key) end
		t.expect.equal(s:load("u_1").Cash,80) t.expect.equal(db.reads,2)
	end)
	-- Failed writes retain in-memory progress for a later attempt.
	t.test("write failure can be retried later",function()
		local s,db,adapter=fixture(nil) local write=adapter.update s:load("u_1") s:get("u_1").Cash=70
		adapter.update=function() error("offline") end t.expect.falsy(s:save("u_1"))
		adapter.update=write t.expect.truthy(s:save("u_1")) t.expect.equal(db.value.Cash,70)
	end)
	-- Deterministic coroutine suspension represents two concurrent load callers.
	t.test("concurrent loads make one request and share one session",function()
		local s,db,adapter=fixture(nil,{wait=coroutine.yield})
		adapter.get=function() db.reads+=1 coroutine.yield() return {Cash=20} end
		local a,b
		local first=coroutine.create(function() a=s:load("u_1") end)
		local second=coroutine.create(function() b=s:load("u_1") end)
		assert(coroutine.resume(first)) assert(coroutine.resume(second))
		t.expect.equal(db.reads,1) t.expect.equal(s:get("u_1"),nil)
		assert(coroutine.resume(first)) assert(coroutine.resume(second)) t.expect.equal(a,b)
	end)
	-- A yielded save uses an immutable snapshot and serializes later callers.
	t.test("concurrent saves serialize immutable snapshots",function()
		local s,db,adapter=fixture(nil,{wait=coroutine.yield}) local write=adapter.update local calls=0
		s:load("u_1") s:get("u_1").Cash=1
		adapter.update=function(key,fn) calls+=1 coroutine.yield() return write(key,fn) end
		local first=coroutine.create(function() assert(s:save("u_1")) end)
		local second=coroutine.create(function() assert(s:save("u_1")) end)
		assert(coroutine.resume(first)) s:get("u_1").Cash=2 assert(coroutine.resume(second)) t.expect.equal(calls,1)
		assert(coroutine.resume(first)) t.expect.equal(db.value.Cash,1)
		assert(coroutine.resume(second)) assert(coroutine.resume(second)) t.expect.equal(db.value.Cash,2)
	end)
	-- Disconnect during a read waits for the result before one final save.
	t.test("release during load saves once and removes session",function()
		local s,db,adapter=fixture({Cash=30},{wait=coroutine.yield})
		adapter.get=function() coroutine.yield() return {Cash=30} end
		local first=coroutine.create(function() s:load("u_1") end)
		local closing=coroutine.create(function() assert(s:release("u_1")) end)
		assert(coroutine.resume(first)) assert(coroutine.resume(closing)) assert(coroutine.resume(first)) assert(coroutine.resume(closing))
		t.expect.equal(db.value.Cash,30) t.expect.equal(db.writes,1) t.expect.equal(s:get("u_1"),nil)
	end)
end
