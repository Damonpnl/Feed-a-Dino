--!nonstrict
-- Server-only owner of resource records. No dependency on spawn/carry/guardian services.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local FieldState = require(Shared.FieldState)
local Resources = require(Shared.ResourceDefinitions)
local Areas = require(Shared.AreaDefinitions)
local Data = require(script.Parent.DataService)
local Format = require(Shared.NumberFormat)
local Guard = require(script.Parent.InteractionGuard)
local Territory = require(script.Parent.BiomeTerritory)
local Service = {}
local state, changed = nil, function() end
local lifecycle, stepping = nil, false
local nodePositions = {}
local rng = Random.new()
local placementRng = Random.new() -- separate stream: placement never consumes rarity rolls
local function now() return workspace:GetServerTimeNow() end
-- Node IDs stay the ownership/respawn slots; each fresh record gets its own radial position
-- in the guardian territory, separated from that biome's other uncarried resources.
local function place()
	for _,record in state.Records do
		if record.State~="AVAILABLE" or record.Position then continue end
		local occupied={}
		for _,other in state.Records do
			if other~=record and other.AreaId==record.AreaId and other.State~="CARRIED" and other.Position then table.insert(occupied,other.Position) end
		end
		record.Position=Territory.pick(record.AreaId,occupied,function() return placementRng:NextNumber() end)
		record.SpawnPosition=record.Position
	end
end
function Service.initialize(nodes, onChanged)
	assert(not state, "ResourceService already initialized")
	for _,node in nodes do if node.Marker then nodePositions[node.Id]=node.Marker.Position end end
	state = FieldState.new(nodes, function(low,high) return rng:NextInteger(low,high) end,
		function() return game:GetService("HttpService"):GenerateGUID(false) end)
	changed = onChanged
	state:start(now())
	place()
end
function Service.getRecord(id)
	local record = state and state.Records[id]
	return record and table.clone(record)
end
function Service.getSnapshot()
	if not state then return nil end
	local snapshot={Phase=state.Phase,Cycle=state.Cycle,Epoch=state.Epoch,NextResetAt=state.NextResetAt,ResetEndsAt=state.ResetEndsAt,Records={},Nodes={}}
	for id,r in state.Records do snapshot.Records[id]=table.clone(r) end
	for id,n in state.Nodes do snapshot.Nodes[id]=table.clone(n) end
	return snapshot
end
function Service.claim(player, id)
	Service.step()
	if not state or player.Parent~=Players then return nil end
	local r=state.Records[id]
	local d=r and Resources.get(r.ResourceId)
	local data=Data.get(player)
	-- Later areas are open for exploration; the locked resource Power requirement is the gate.
	if not r or not d or not Areas.get(r.AreaId) or not d.Launch or not data then return nil end
	if data.Power<d.PowerRequired then
		if Guard.allow(player,"PowerNotice",1) then
			player:SetAttribute("PowerNotice",Format.needPower(d.PowerRequired))
			player:SetAttribute("PowerNoticeTick",now())
			player:SetAttribute("StatusMessage",Format.needPower(d.PowerRequired))
		end
		return nil
	end
	if r.State=="DROPPED" and now()>=r.DropExpiresAt then Service.releaseToken(r.AreaId,id) return nil end
	return state:claim(id,player.UserId)
end
function Service.acknowledgePickup(player,id,version)
	Service.step()
	local r=state and state.Records[id]
	if not r or not Service.owned(player,id) or r.ClaimVersion~=version or r.GuardianClaimVersion==version then return nil end
	r.GuardianClaimVersion=version
	return table.clone(r)
end
function Service.rollbackClaim(id, userId, previous)
	if state then state:rollbackClaim(id,userId,previous) changed() end
end
function Service.owned(player, id)
	local r=state and state.Records[id]
	return r~=nil and r.State=="CARRIED" and r.OwnerUserId==player.UserId
end
function Service.consume(player,id)
	Service.step()
	if not Service.owned(player,id) then return false end
	state:release(id,now(),"CONSUMED")
	-- Presentation cannot turn a committed consume into an apparent failed transaction.
	task.defer(function()
		local ok = pcall(changed)
		if not ok then warn("[ResourceService] Consume committed; world presentation will retry on the next step") end
	end)
	return true
end
function Service.releaseToken(areaId,id)
	local r=state and state.Records[id]
	if not r or r.AreaId~=areaId then return false end
	state:release(id,now()) changed() return true
end
-- Used by the reset adapter even if a lifecycle callback has already detached the
-- carry presentation. The world record, not the visual table, owns the resource.
function Service.forfeitOwned(player)
	if not state then return false end
	local ids={}
	for id,r in state.Records do if r.State=="CARRIED" and r.OwnerUserId==player.UserId then table.insert(ids,id) end end
	for _,id in ids do state:release(id,now(),"DESTROYED") end
	if #ids>0 then changed() end
	return #ids>0
end
function Service.returnToWorld(areaId,resourceId,id,position,userId)
	Service.step()
	local r=state and state.Records[id]
	if not r or r.AreaId~=areaId or r.ResourceId~=resourceId or r.State~="CARRIED" or r.OwnerUserId~=userId then return false end
	if typeof(position)~="Vector3" or not (position.Magnitude<1e7) then return false end
	local params=RaycastParams.new()
	local excluded={}
	local generated=workspace:FindFirstChild("GeneratedGameplay")
	if generated then table.insert(excluded,generated) end
	for _,p in Players:GetPlayers() do if p.Character then table.insert(excluded,p.Character) end end
	params.FilterDescendantsInstances,params.FilterType=excluded,Enum.RaycastFilterType.Exclude
	local hit=workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-200,0),params)
	-- Never leave a drop floating over a void. A missing floor falls back to the
	-- original stable node; if neither location is valid the caller releases it.
	local fallback=r.SpawnPosition or nodePositions[r.OriginalNodeId]
	if not hit and fallback then hit=workspace:Raycast(fallback+Vector3.new(0,6,0),Vector3.new(0,-200,0),params) end
	if not hit then return false end
	local accepted=state:drop(id,userId,hit.Position,now())
	if accepted then changed() end
	return accepted
end
function Service.step()
	if not state or stepping then return nil,nil end
	stepping=true
	local before, cycle=state.Phase, state.Cycle
	local ok,err=xpcall(function()
		state:step(now())
		-- No yield: closure, forfeiture and evacuation precede any new transaction.
		if lifecycle then lifecycle(state, state.Cycle~=cycle) end
		place() changed()
	end,debug.traceback)
	stepping=false
	if not ok then error(err) end
	return before,state.Phase,state.Cycle~=cycle
end
function Service.setLifecycle(callback)
	assert(not lifecycle,"Field lifecycle already bound")
	lifecycle=callback
end
function Service.validate() return if state then state:validate() else {"Field is not running"} end

-- Studio fixture path. Replaces one available node with a launch definition and a new GUID.
-- It does not change spawn weights. Callers must already be inside an authorized dev session.
function Service.devReplace(areaId, resourceId, nodeId)
	if not state or state.Phase ~= "Normal" then return nil, "Field is not in a normal phase" end
	local definition = Resources.get(resourceId)
	if not definition or definition.Launch ~= true or definition.Area ~= areaId or not Areas.get(areaId) then
		return nil, "Resource is not a launch definition for that biome"
	end
	local node = nodeId and state.Nodes[nodeId]
	if nodeId and (not node or node.AreaId ~= areaId) then return nil, "Node is not in that biome" end
	if not node then
		local ids = {}
		for id, candidate in state.Nodes do if candidate.AreaId == areaId then table.insert(ids, id) end end
		table.sort(ids)
		for _, id in ids do
			local candidate = state.Nodes[id]
			local record = candidate.RecordId and state.Records[candidate.RecordId]
			if record and record.State == "AVAILABLE" then node = candidate break end
		end
	end
	if not node or not node.RecordId then return nil, "No available node" end
	local existing = state.Records[node.RecordId]
	if not existing or existing.State ~= "AVAILABLE" then return nil, "Node is not available" end
	state:release(existing.InstanceId, now(), "DESTROYED")
	node.RespawnAt = nil
	local record = state:create(node, resourceId, "DevTest")
	place()
	changed()
	return record.InstanceId
end

function Service.devRelease()
	if not state then return 0 end
	local ids = {}
	for id, record in state.Records do
		if record.SpawnReason == "DevTest" and record.State ~= "CARRIED" then table.insert(ids, id) end
	end
	for _, id in ids do state:release(id, now(), "DESTROYED") end
	if #ids > 0 then changed() end
	return #ids
end

return Service
