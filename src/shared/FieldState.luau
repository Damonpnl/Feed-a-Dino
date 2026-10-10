--!nonstrict
-- Pure authoritative state machine: injected clock/roll/IDs, no Roblox services or timers.
local Config = require(script.Parent.FieldConfig)
local Areas = require(script.Parent.AreaDefinitions)
local Resources = require(script.Parent.ResourceDefinitions)
local Roller = require(script.Parent.FieldRoller)
local State = {}
State.__index = State

function State.new(nodes, nextInteger, generateId)
	local self = setmetatable({Records = {}, Nodes = {}, Phase = "Normal", Cycle = 0,
		NextResetAt = 0, ResetEndsAt = 0, NextInteger = nextInteger, GenerateId = generateId}, State)
	for _, node in nodes do
		assert(not self.Nodes[node.Id], "Duplicate node ID: " .. node.Id)
		self.Nodes[node.Id] = {Id = node.Id, AreaId = node.AreaId, RecordId = nil, RespawnAt = nil}
	end
	return self
end
function State:divineReserved()
	-- Reservation survives carrying, preventing an old Divine drop from colliding with a fresh Divine.
	for _, record in self.Records do
		if Resources.get(record.ResourceId).Rarity == "Divine" then return true end
	end
	return false
end
function State:create(node, resourceId, reason)
	assert(node.RecordId == nil, "Node already occupied")
	local id = self.GenerateId()
	assert(not self.Records[id], "Duplicate resource instance ID")
	local record = {InstanceId = id, ResourceId = resourceId, AreaId = node.AreaId,
		NodeId = node.Id, OriginalNodeId = node.Id, Cycle = self.Cycle, State = "World", SpawnReason = reason}
	self.Records[id] = record
	node.RecordId, node.RespawnAt = id, nil
	return record
end
function State:fill()
	for _, area in Areas.getOrdered() do
		local nodes = {}
		for _, node in self.Nodes do if node.AreaId == area.Id then table.insert(nodes, node) end end
		table.sort(nodes, function(a, b) return a.Id < b.Id end)
		local results = Roller.area(area.ResourcePool, #nodes, self.NextInteger, self:divineReserved())
		for index, node in nodes do self:create(node, results[index], "HardReset") end
	end
end
function State:start(now)
	self.Cycle = 1
	self.NextResetAt = now + Config.FIELD_CYCLE_SECONDS
	self:fill()
end
function State:beginReset(now)
	if self.Phase == "Reset" then return false end
	self.Phase = "Reset"
	self.Cycle += 1
	self.ResetEndsAt = now + Config.RESET_WINDOW_SECONDS
	repeat self.NextResetAt += Config.FIELD_CYCLE_SECONDS until self.NextResetAt > now
	for id, record in self.Records do
		if record.State == "Carried" then record.NodeId = nil
		else self.Records[id] = nil end
	end
	for _, node in self.Nodes do node.RecordId, node.RespawnAt = nil, nil end
	return true
end
function State:claim(id, userId)
	for _, held in self.Records do if held.State == "Carried" and held.OwnerUserId == userId then return nil end end
	local record = self.Records[id]
	if self.Phase ~= "Normal" or not record or (record.State ~= "World" and record.State ~= "Dropped") then return nil end
	local previous = record.State
	record.State, record.OwnerUserId = "Carried", userId
	return previous
end
function State:rollbackClaim(id, userId, previous)
	local record = self.Records[id]
	if record and record.State == "Carried" and record.OwnerUserId == userId then
		record.State, record.OwnerUserId = previous, nil
	end
end
function State:drop(id, userId, position, now)
	local record = self.Records[id]
	if not record or record.State ~= "Carried" or record.OwnerUserId ~= userId then return false end
	-- Fresh resources are paused during reset, but a carried item can still be dropped safely.
	record.State, record.OwnerUserId = "Dropped", nil
	record.Position = position
	record.DropExpiresAt = now + Config.DROPPED_DESPAWN_SECONDS
	return true
end
function State:release(id, now)
	local record = self.Records[id]
	if not record then return false end
	self.Records[id] = nil
	local node = record.NodeId and self.Nodes[record.NodeId]
	if node and node.RecordId == id then
		node.RecordId = nil
		local delay = Config.RespawnSeconds[Resources.get(record.ResourceId).Rarity]
		node.RespawnAt = if self.Phase == "Normal" and delay then now + delay else nil
	end
	return true
end
function State:step(now)
	if self.Phase == "Normal" and now >= self.NextResetAt then
		self:beginReset(now)
		return
	end
	if self.Phase == "Reset" and now >= self.ResetEndsAt then
		self:fill()
		self.Phase = "Normal"
	end
	local expired = {}
	for id, record in self.Records do
		if record.State == "Dropped" and now >= record.DropExpiresAt then table.insert(expired, id) end
	end
	for _, id in expired do self:release(id, now) end
	if self.Phase ~= "Normal" then return end
	for _, node in self.Nodes do
		if not node.RecordId and node.RespawnAt and now >= node.RespawnAt then
			local area = Areas.get(node.AreaId)
			self:create(node, Roller.pick(area.ResourcePool, self.NextInteger, true, true), "MidCycle")
		end
	end
end
function State:validate()
	local errors, owners, divine = {}, {}, 0
	for id, record in self.Records do
		if id ~= record.InstanceId then table.insert(errors, "Resource ID mismatch") end
		if record.State == "Carried" then
			if not record.OwnerUserId or owners[record.OwnerUserId] then table.insert(errors, "Duplicate/invalid carrier") end
			owners[record.OwnerUserId] = true
		end
		if Resources.get(record.ResourceId).Rarity == "Divine" then divine += 1 end
		local node = record.NodeId and self.Nodes[record.NodeId]
		if record.NodeId and (not node or node.RecordId ~= id) then table.insert(errors, "Broken node ownership") end
	end
	for _, node in self.Nodes do
		local record = node.RecordId and self.Records[node.RecordId]
		if node.RecordId and (not record or record.NodeId ~= node.Id) then table.insert(errors, "Dangling node resource") end
	end
	if divine > 1 then table.insert(errors, "More than one Divine reservation") end
	return errors
end
return State
