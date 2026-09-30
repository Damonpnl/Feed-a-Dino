--!strict

--[[
	Crystal Eruption event without EventSpawn markers.
	Location priority: EventEligible regions -> CrystalOutcrop regions -> ZoneBoundary fallback.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local ExpeditionEventDefinitions = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionEventDefinitions"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))

local PlacementService = require(script.Parent.PlacementService)
local RegionResolver = require(script.Parent.RegionResolver)
local ResourceNodeService = require(script.Parent.ResourceNodeService)

local ExpeditionEventService = {}

local eventRandom = Random.new(ExpeditionConfig.EventSeed)
local active = false
local locationSource = "None"
local started = false
local announceCallback: ((string, string) -> ())? = nil

function ExpeditionEventService.onAnnounce(callback: (string, string) -> ())
	announceCallback = callback
end

function ExpeditionEventService.getLocationSource(): string
	return locationSource
end

function ExpeditionEventService.isActive(): boolean
	return active
end

local function sortCrystalRegionsByDepth(regions: { any }, bankPosition: Vector3)
	table.sort(regions, function(a, b)
		local aTier = a.depthTier or 0
		local bTier = b.depthTier or 0
		if aTier ~= bTier then
			return aTier > bTier
		end
		local aDist = RegionSamplingCalculator.horizontalDistance(a.part.Position, bankPosition)
		local bDist = RegionSamplingCalculator.horizontalDistance(b.part.Position, bankPosition)
		if aDist ~= bDist then
			return aDist > bDist
		end
		return a.fullPath < b.fullPath
	end)
end

local function chooseCenter(): (any?, string)
	local exclusions = RegionResolver.buildExclusions()
	local bank = RegionResolver.getBankZone()
	local placed = ResourceNodeService.getActivePositions()

	local eligible = RegionResolver.getEventEligibleRegions()
	if #eligible > 0 then
		local sample = PlacementService.sampleInRegions(
			eligible,
			eventRandom,
			ExpeditionConfig.MaximumEventSlopeDegrees,
			placed,
			ExpeditionConfig.MinimumNodeSpacing,
			exclusions
		)
		if sample then
			return sample, "EventEligibleRegion"
		end
	end

	local crystalRegions = RegionResolver.getResourceRegions(ExpeditionConfig.CrystalOutcropRegionFolderName)
	sortCrystalRegionsByDepth(crystalRegions, bank.Position)
	local sample = PlacementService.sampleInRegions(
		crystalRegions,
		eventRandom,
		ExpeditionConfig.MaximumEventSlopeDegrees,
		placed,
		ExpeditionConfig.MinimumNodeSpacing,
		exclusions
	)
	if sample then
		return sample, "CrystalOutcropRegion"
	end

	local fallback = PlacementService.sampleInsideZoneBoundary(
		eventRandom,
		ExpeditionConfig.MaximumEventSlopeDegrees,
		placed,
		ExpeditionConfig.MinimumNodeSpacing,
		exclusions,
		true
	)
	if fallback then
		return fallback, "ZoneBoundaryFallback"
	end

	return nil, "None"
end

local function spawnCluster(center: Vector3): number
	local definition = ExpeditionEventDefinitions.getCrystalEruption()
	local exclusions = RegionResolver.buildExclusions()
	local parent = RegionResolver.getOrCreateGeneratedFolder("Events")
	local nodeCount = eventRandom:NextInteger(definition.minNodes, definition.maxNodes)
	local placed = table.clone(ResourceNodeService.getActivePositions())
	local spawned = 0

	for index = 1, nodeCount do
		local angle = (index / nodeCount) * math.pi * 2 + eventRandom:NextNumber(-0.2, 0.2)
		local radius = eventRandom:NextNumber(6, 14)
		local candidate = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local sample = PlacementService.sampleGroundAt(candidate, ExpeditionConfig.MaximumEventSlopeDegrees, nil)
		if sample == nil then
			continue
		end
		if not RegionSamplingCalculator.passesExclusions(sample.position, exclusions, true) then
			continue
		end
		if not RegionSamplingCalculator.isWithinSpacing(sample.position, placed, ExpeditionConfig.MinimumEventNodeSpacing) then
			continue
		end

		local record = ResourceNodeService.spawnEventNode(sample, parent)
		if record then
			table.insert(placed, sample.position)
			spawned += 1
		end
	end

	return spawned
end

function ExpeditionEventService.endEvent()
	if not active then
		return
	end
	ResourceNodeService.clearEventNodes()
	active = false
end

function ExpeditionEventService.startCrystalEruptionNow(): boolean
	if active then
		return false
	end

	local definition = ExpeditionEventDefinitions.getCrystalEruption()
	local parent = RegionResolver.getOrCreateGeneratedFolder("Events")
	parent:ClearAllChildren()

	for _ = 1, ExpeditionConfig.MaximumPlacementAttempts do
		local centerSample, source = chooseCenter()
		if centerSample == nil then
			continue
		end

		locationSource = source
		local spawned = spawnCluster(centerSample.position)
		if spawned >= definition.minNodes then
			active = true
			if announceCallback then
				announceCallback(definition.displayName, definition.announcementBody)
			end
			task.delay(definition.durationSeconds, function()
				ExpeditionEventService.endEvent()
			end)
			return true
		end

		ResourceNodeService.clearEventNodes()
		parent:ClearAllChildren()
	end

	warn("[ExpeditionEventService] Crystal Eruption placement failed cleanly")
	locationSource = "None"
	return false
end

function ExpeditionEventService.setRandom(rng: Random)
	eventRandom = rng
end

function ExpeditionEventService.start()
	if started then
		return
	end
	started = true

	local definition = ExpeditionEventDefinitions.getCrystalEruption()
	task.spawn(function()
		task.wait(definition.initialDelaySeconds)
		while true do
			ExpeditionEventService.startCrystalEruptionNow()
			while active do
				task.wait(1)
			end
			task.wait(definition.intervalSeconds)
		end
	end)
end

return ExpeditionEventService
