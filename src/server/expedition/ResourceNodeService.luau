--!strict

--[[
	Spawns and manages Savannah resource nodes at random validated region positions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))
local ResourceNodeDefinitions = require(Shared:WaitForChild("expedition"):WaitForChild("ResourceNodeDefinitions"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))

local FieldBagService = require(script.Parent.FieldBagService)
local PlacementService = require(script.Parent.PlacementService)
local RegionResolver = require(script.Parent.RegionResolver)
local ResourceNodeBillboardService = require(script.Parent.ResourceNodeBillboardService)

export type GatherResult = {
	success: boolean,
	reason: string?,
	rewards: { [string]: number }?,
	nodeTypeId: ExpeditionTypes.NodeTypeId?,
	depleted: boolean?,
}

export type NodeRecord = {
	id: string,
	nodeTypeId: ExpeditionTypes.NodeTypeId,
	instance: Instance,
	prompt: ProximityPrompt,
	billboard: BillboardGui?,
	charges: number,
	state: ExpeditionTypes.NodeState,
	position: Vector3,
	isEventNode: boolean,
}

local ResourceNodeService = {}

local resourceRandom = Random.new(ExpeditionConfig.ResourceSeed)
local rewardRandom = Random.new(ExpeditionConfig.RewardSeed)

local nodesByInstance: { [Instance]: NodeRecord } = {}
local activePositions: { Vector3 } = {}
local nextId = 0
local gatherCallbacks: { (Player, GatherResult) -> () } = {}
local started = false

local function nextNodeId(): string
	nextId += 1
	return string.format("node_%d", nextId)
end

local function getPrimaryPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function setWorldCFrame(instance: Instance, cframe: CFrame)
	if instance:IsA("BasePart") then
		instance.CFrame = cframe
	elseif instance:IsA("Model") then
		instance:PivotTo(cframe)
	end
end

local function rebuildActivePositions()
	table.clear(activePositions)
	for _, record in nodesByInstance do
		if record.state ~= "Depleted" and record.state ~= "Respawning" then
			table.insert(activePositions, record.position)
		end
	end
end

function ResourceNodeService.onGathered(callback: (Player, GatherResult) -> ())
	table.insert(gatherCallbacks, callback)
end

function ResourceNodeService.getActivePositions(): { Vector3 }
	return activePositions
end

function ResourceNodeService.getActiveCount(nodeTypeId: ExpeditionTypes.NodeTypeId): number
	local count = 0
	for _, record in nodesByInstance do
		if record.nodeTypeId == nodeTypeId and record.state ~= "Depleted" and record.state ~= "Respawning" then
			count += 1
		end
	end
	return count
end

local function rollRewards(
	definition: ResourceNodeDefinitions.ResourceNodeDefinition,
	rng: Random,
	isEventNode: boolean
): { [string]: number }
	local rewards: { [string]: number } = {}

	if definition.guaranteedRewards then
		for _, entry in definition.guaranteedRewards do
			rewards[entry.feedId] = (rewards[entry.feedId] or 0) + entry.amount
		end
	end

	if definition.weightedRewards then
		local rolled = ResourceNodeDefinitions.rollWeightedReward(definition.weightedRewards, rng)
		if rolled then
			rewards[rolled.feedId] = (rewards[rolled.feedId] or 0) + rolled.amount
		end
	end

	if isEventNode then
		local eventDefs = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionEventDefinitions"))
		local event = eventDefs.getCrystalEruption()
		if rng:NextNumber() < event.livingCrystalBonusChance then
			rewards.LivingCrystal = (rewards.LivingCrystal or 0) + 1
		end
	end

	return rewards
end

local function destroyNode(record: NodeRecord)
	nodesByInstance[record.instance] = nil
	if record.instance.Parent ~= nil then
		record.instance:Destroy()
	end
	rebuildActivePositions()
end

local function spawnNode(
	definition: ResourceNodeDefinitions.ResourceNodeDefinition,
	sample: PlacementService.PlacementResult,
	parent: Folder,
	template: Instance,
	isEventNode: boolean,
	rng: Random
): NodeRecord
	local clone = template:Clone()
	clone.Name = definition.templateName

	local yaw = rng:NextNumber(0, math.pi * 2)
	local sink = sample.normal.Unit * ExpeditionConfig.NodeSinkDepth
	local cframe = RegionSamplingCalculator.alignCFrame(sample.position - sink, sample.normal, yaw)
	setWorldCFrame(clone, cframe)

	local primary = getPrimaryPart(clone)
	assert(primary ~= nil, "Resource node missing BasePart")
	if clone:IsA("Model") and clone.PrimaryPart == nil then
		clone.PrimaryPart = primary
	end
	if primary:IsA("BasePart") then
		primary.Anchored = true
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = definition.promptActionText
	prompt.ObjectText = definition.promptObjectText
	prompt.HoldDuration = definition.holdDuration
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary

	clone:SetAttribute("NodeTypeId", definition.nodeTypeId)
	clone:SetAttribute("IsEventNode", isEventNode)
	clone.Parent = parent

	local record: NodeRecord = {
		id = nextNodeId(),
		nodeTypeId = definition.nodeTypeId,
		instance = clone,
		prompt = prompt,
		billboard = ResourceNodeBillboardService.attach(clone, definition.nodeTypeId, definition.charges),
		charges = definition.charges,
		state = "Available",
		position = sample.position,
		isEventNode = isEventNode,
	}
	nodesByInstance[clone] = record
	rebuildActivePositions()

	prompt.Triggered:Connect(function(player: Player)
		ResourceNodeService.tryGather(player, clone)
	end)

	return record
end

function ResourceNodeService.tryGather(player: Player, nodeInstance: Instance): GatherResult
	local record = nodesByInstance[nodeInstance]
	if record == nil then
		return { success = false, reason = "UnknownNode" }
	end
	if record.state ~= "Available" then
		return { success = false, reason = "Unavailable" }
	end
	if record.charges <= 0 then
		return { success = false, reason = "Depleted" }
	end

	record.state = "GatherPending"

	local definition = ResourceNodeDefinitions.get(record.nodeTypeId)
	if definition == nil then
		record.state = "Available"
		return { success = false, reason = "MissingDefinition" }
	end

	local rewards = rollRewards(definition, rewardRandom, record.isEventNode)
	for feedId, amount in rewards do
		local ok, reason = FieldBagService.addMaterial(player, feedId, amount)
		if not ok then
			record.state = "Available"
			return { success = false, reason = reason or "FieldBagRejected" }
		end
	end

	record.charges -= 1
	ResourceNodeBillboardService.updateCharges(record.billboard, record.charges)
	local depleted = record.charges <= 0
	if depleted then
		record.state = "Depleted"
		record.prompt.Enabled = false
	else
		record.state = "Available"
	end

	local result: GatherResult = {
		success = true,
		rewards = rewards,
		nodeTypeId = record.nodeTypeId,
		depleted = depleted,
	}

	for _, callback in gatherCallbacks do
		callback(player, result)
	end

	if depleted then
		local positionSnapshot = record.position
		local nodeTypeId = record.nodeTypeId
		local isEvent = record.isEventNode
		destroyNode(record)

		if not isEvent then
			local delaySeconds = resourceRandom:NextNumber(definition.respawnMinSeconds, definition.respawnMaxSeconds)
			task.delay(delaySeconds, function()
				ResourceNodeService.respawnOne(nodeTypeId, positionSnapshot)
			end)
		end
	end

	return result
end

function ResourceNodeService.respawnOne(nodeTypeId: ExpeditionTypes.NodeTypeId, _previousPosition: Vector3?)
	local definition = ResourceNodeDefinitions.get(nodeTypeId)
	if definition == nil or definition.activeCount <= 0 then
		return
	end
	if ResourceNodeService.getActiveCount(nodeTypeId) >= definition.activeCount then
		return
	end

	local regions = RegionResolver.getResourceRegions(definition.regionFolderName)
	local exclusions = RegionResolver.buildExclusions()
	local sample = PlacementService.sampleInRegions(
		regions,
		resourceRandom,
		ExpeditionConfig.MaximumResourceSlopeDegrees,
		activePositions,
		ExpeditionConfig.MinimumNodeSpacing,
		exclusions
	)
	if sample == nil then
		warn(string.format("[ResourceNodeService] Failed to respawn %s", nodeTypeId))
		return
	end

	local template = RegionResolver.resolveTemplate(definition.templateName)
	local parent = RegionResolver.getOrCreateGeneratedFolder("ResourceNodes")
	spawnNode(definition, sample, parent, template, false, resourceRandom)
end

function ResourceNodeService.spawnInitial()
	local parent = RegionResolver.getOrCreateGeneratedFolder("ResourceNodes")
	parent:ClearAllChildren()
	table.clear(nodesByInstance)
	rebuildActivePositions()

	local exclusions = RegionResolver.buildExclusions()

	for _, definition in ResourceNodeDefinitions.getOrdinaryNodes() do
		local regions = RegionResolver.getResourceRegions(definition.regionFolderName)
		local template = RegionResolver.resolveTemplate(definition.templateName)

		for _ = 1, definition.activeCount do
			local sample = PlacementService.sampleInRegions(
				regions,
				resourceRandom,
				ExpeditionConfig.MaximumResourceSlopeDegrees,
				activePositions,
				ExpeditionConfig.MinimumNodeSpacing,
				exclusions
			)
			if sample == nil then
				warn(string.format("[ResourceNodeService] Could not place all %s nodes", definition.nodeTypeId))
				break
			end
			spawnNode(definition, sample, parent, template, false, resourceRandom)
		end
	end
end

function ResourceNodeService.spawnEventNode(
	sample: PlacementService.PlacementResult,
	parent: Folder
): NodeRecord?
	local definition = ResourceNodeDefinitions.get("CrystalEruptionNode")
	if definition == nil then
		return nil
	end

	local template: Instance
	local ok, resolved = pcall(function()
		return RegionResolver.resolveTemplate("CrystalEruptionNode")
	end)
	if ok then
		template = resolved
	else
		-- Placeholder until ServerStorage.ExpeditionTemplates.CrystalEruptionNode exists.
		template = RegionResolver.resolveTemplate("CrystalOutcrop")
	end

	local record = spawnNode(definition, sample, parent, template, true, resourceRandom)
	record.instance.Name = "CrystalEruptionNode"
	record.instance:SetAttribute("NodeTypeId", "CrystalEruptionNode")
	record.instance:SetAttribute("EventNodeId", "CrystalEruption")
	local primary = getPrimaryPart(record.instance)
	if primary then
		primary.Color = Color3.fromRGB(180, 80, 255)
	end
	return record
end

function ResourceNodeService.clearEventNodes()
	local toDestroy: { NodeRecord } = {}
	for _, record in nodesByInstance do
		if record.isEventNode then
			table.insert(toDestroy, record)
		end
	end
	for _, record in toDestroy do
		record.prompt.Enabled = false
		destroyNode(record)
	end
end

function ResourceNodeService.setRandom(rng: Random)
	resourceRandom = rng
end

function ResourceNodeService.setRewardRandom(rng: Random)
	rewardRandom = rng
end

function ResourceNodeService.start()
	if started then
		return
	end
	started = true
	ResourceNodeService.spawnInitial()
end

return ResourceNodeService
