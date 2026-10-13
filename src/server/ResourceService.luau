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
local Service = {}
local state, changed = nil, function() end
local nodePositions = {}
local function now() return workspace:GetServerTimeNow() end
function Service.initialize(nodes, onChanged)
	assert(not state, "ResourceService already initialized")
	for _,node in nodes do if node.Marker then nodePositions[node.Id]=node.Marker.Position end end
	local rng = Random.new()
	state = FieldState.new(nodes, function(low,high) return rng:NextInteger(low,high) end,
		function() return game:GetService("HttpService"):GenerateGUID(false) end)
	changed = onChanged
	state:start(now())
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
function Service.returnToWorld(areaId,resourceId,id,position,userId)
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
	local fallback=nodePositions[r.OriginalNodeId]
	if not hit and fallback then hit=workspace:Raycast(fallback+Vector3.new(0,6,0),Vector3.new(0,-200,0),params) end
	if not hit then return false end
	local accepted=state:drop(id,userId,hit.Position,now())
	if accepted then changed() end
	return accepted
end
function Service.step()
	if not state then return nil,nil end
	local before, cycle=state.Phase, state.Cycle
	state:step(now()) changed()
	return before,state.Phase,state.Cycle~=cycle
end
function Service.validate() return if state then state:validate() else {"Field is not running"} end
return Service
