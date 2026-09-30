--!strict

--[[
	Terrain placement sampling for expedition objects.
	Uses injectable Random and cached exclusion volumes.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))

local RegionResolver = require(script.Parent.RegionResolver)

export type PlacementResult = ExpeditionTypes.PlacementSample

local PlacementService = {}

local function buildRaycastParams(extraExclusions: { Instance }?): RaycastParams
	local exclusions: { Instance } = {}
	local folderNames = {
		"Environment",
		"Ring1",
		"Bases",
		"Conveyors",
		"area",
		ExpeditionConfig.ExpeditionZonesFolderName,
		ExpeditionConfig.GeneratedRootFolderName,
		"GeneratedEnvironment",
	}
	for _, name in folderNames do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclusions, folder)
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(exclusions, player.Character)
		end
	end
	if extraExclusions then
		for _, item in extraExclusions do
			table.insert(exclusions, item)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.IgnoreWater = ExpeditionConfig.WaterMaterialRejected
	return params
end

function PlacementService.sampleGroundAt(
	worldXZ: Vector3,
	maxSlopeDegrees: number,
	raycastParams: RaycastParams?
): PlacementResult?
	local params = raycastParams or buildRaycastParams(nil)
	-- Region volumes sit high above terrain; cast from above the candidate through to below ground.
	local origin = Vector3.new(worldXZ.X, worldXZ.Y + ExpeditionConfig.RaycastHeight, worldXZ.Z)
	local castDepth = ExpeditionConfig.RaycastHeight + ExpeditionConfig.RaycastDepth
	local result = Workspace:Raycast(origin, Vector3.new(0, -castDepth, 0), params)
	if result == nil then
		return nil
	end
	if ExpeditionConfig.TerrainOnlyByDefault and result.Instance ~= Workspace.Terrain then
		return nil
	end
	if ExpeditionConfig.WaterMaterialRejected and result.Material == Enum.Material.Water then
		return nil
	end
	if RegionSamplingCalculator.slopeDegrees(result.Normal) > maxSlopeDegrees then
		return nil
	end
	return {
		position = result.Position,
		normal = result.Normal,
	}
end

function PlacementService.sampleInRegion(
	region: ExpeditionTypes.RegionInfo,
	rng: Random,
	maxSlopeDegrees: number,
	placed: { Vector3 },
	minimumSpacing: number,
	exclusions: RegionSamplingCalculator.ExclusionVolumes,
	extraRaycastExclusions: { Instance }?
): PlacementResult?
	local params = buildRaycastParams(extraRaycastExclusions)

	for _ = 1, ExpeditionConfig.MaximumPlacementAttempts do
		local localPoint = RegionSamplingCalculator.sampleLocalPointInRegion(region.part.Size, rng)
		local worldPoint = RegionSamplingCalculator.localPointToWorld(region.part.CFrame, localPoint)
		local sample = PlacementService.sampleGroundAt(worldPoint, maxSlopeDegrees, params)
		if sample == nil then
			continue
		end
		if not RegionSamplingCalculator.passesExclusions(sample.position, exclusions, true) then
			continue
		end
		if not RegionSamplingCalculator.isWithinSpacing(sample.position, placed, minimumSpacing) then
			continue
		end
		return sample
	end

	return nil
end

function PlacementService.sampleInRegions(
	regions: { ExpeditionTypes.RegionInfo },
	rng: Random,
	maxSlopeDegrees: number,
	placed: { Vector3 },
	minimumSpacing: number,
	exclusions: RegionSamplingCalculator.ExclusionVolumes
): PlacementResult?
	for _ = 1, ExpeditionConfig.MaximumPlacementAttempts do
		local region = RegionResolver.selectRegion(regions, rng, ExpeditionConfig.UseAreaWeightedRegionSelection)
		if region == nil then
			return nil
		end
		local sample = PlacementService.sampleInRegion(
			region,
			rng,
			maxSlopeDegrees,
			placed,
			minimumSpacing,
			exclusions,
			nil
		)
		if sample ~= nil then
			return sample
		end
	end
	return nil
end

function PlacementService.sampleInsideZoneBoundary(
	rng: Random,
	maxSlopeDegrees: number,
	placed: { Vector3 },
	minimumSpacing: number,
	exclusions: RegionSamplingCalculator.ExclusionVolumes,
	preferFarFromBank: boolean
): PlacementResult?
	local boundary = RegionResolver.getZoneBoundary()
	local bank = RegionResolver.getBankZone()
	local params = buildRaycastParams(nil)
	local best: PlacementResult? = nil
	local bestDistance = -1
	local BiomeDefinitions = require(Shared:WaitForChild("biomes"):WaitForChild("BiomeDefinitions"))
	local outer = BiomeDefinitions.getMapGeometry().savannahOuterRadius

	for _ = 1, ExpeditionConfig.MaximumPlacementAttempts do
		local worldPoint: Vector3
		if boundary ~= nil then
			local localPoint = RegionSamplingCalculator.sampleLocalPointInRegion(boundary.Size, rng)
			worldPoint = RegionSamplingCalculator.localPointToWorld(boundary.CFrame, localPoint)
		else
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(ExpeditionConfig.HubSafeRadius + 40, outer)
			worldPoint = Vector3.new(
				ExpeditionConfig.HubCenter.X + math.cos(angle) * radius,
				80,
				ExpeditionConfig.HubCenter.Z + math.sin(angle) * radius
			)
		end

		local sample = PlacementService.sampleGroundAt(worldPoint, maxSlopeDegrees, params)
		if sample == nil then
			continue
		end
		if not RegionSamplingCalculator.passesExclusions(sample.position, exclusions, true) then
			continue
		end
		if not RegionSamplingCalculator.isWithinSpacing(sample.position, placed, minimumSpacing) then
			continue
		end

		if preferFarFromBank then
			local distance = RegionSamplingCalculator.horizontalDistance(sample.position, bank.Position)
			if distance > bestDistance then
				bestDistance = distance
				best = sample
			end
		else
			return sample
		end
	end

	return best
end

return PlacementService
