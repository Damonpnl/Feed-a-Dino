--!strict

--[[
	Discovers Savannah region BaseParts with deterministic ordering.
	Supports nested folders. Non-BasePart descendants are ignored.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))

export type RegionInfo = ExpeditionTypes.RegionInfo

local RegionResolver = {}

local function collectBaseParts(root: Instance): { RegionInfo }
	local regions: { RegionInfo } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(regions, {
				part = descendant,
				fullPath = descendant:GetFullName(),
				area = RegionSamplingCalculator.regionArea(descendant.Size),
				depthTier = descendant:GetAttribute("DepthTier") :: number?,
				eventEligible = descendant:GetAttribute("EventEligible") :: boolean?,
				regionWeight = descendant:GetAttribute("RegionWeight") :: number?,
			})
		end
	end

	table.sort(regions, function(a, b)
		return a.fullPath < b.fullPath
	end)

	return regions
end

function RegionResolver.getSavannahFolder(): Folder
	local zones = Workspace:FindFirstChild(ExpeditionConfig.ExpeditionZonesFolderName)
	if zones == nil or not zones:IsA("Folder") then
		error("[RegionResolver] Missing Workspace.ExpeditionZones")
	end

	local savannah = zones:FindFirstChild(ExpeditionConfig.ZoneId)
	if savannah == nil or not savannah:IsA("Folder") then
		error("[RegionResolver] Missing Workspace.ExpeditionZones.Savannah")
	end

	return savannah
end

function RegionResolver.getZoneBoundary(): BasePart?
	local savannah = RegionResolver.getSavannahFolder()
	local boundary = savannah:FindFirstChild(ExpeditionConfig.ZoneBoundaryName)
	if boundary ~= nil and boundary:IsA("BasePart") then
		-- Studio asset is currently unanchored; pin it for the session only.
		boundary.Anchored = true
		return boundary
	end
	return nil
end

function RegionResolver.isInsideSavannah(position: Vector3): boolean
	local boundary = RegionResolver.getZoneBoundary()
	if boundary ~= nil then
		return RegionSamplingCalculator.pointInOrientedBoxXZ(position, boundary.CFrame, boundary.Size)
	end

	-- Fallback when ZoneBoundary is missing/fallen: concentric savannah ring.
	local distance = RegionSamplingCalculator.horizontalDistance(position, ExpeditionConfig.HubCenter)
	local BiomeDefinitions = require(Shared:WaitForChild("biomes"):WaitForChild("BiomeDefinitions"))
	local outer = BiomeDefinitions.getMapGeometry().savannahOuterRadius
	return distance >= ExpeditionConfig.HubSafeRadius and distance <= outer
end

function RegionResolver.getBankZone(): BasePart
	local savannah = RegionResolver.getSavannahFolder()
	local bank = savannah:FindFirstChild(ExpeditionConfig.BankZoneName)
	if bank == nil or not bank:IsA("BasePart") then
		error("[RegionResolver] Missing Savannah.BankZone")
	end
	return bank
end

function RegionResolver.getWateringHole(): BasePart
	local savannah = RegionResolver.getSavannahFolder()
	local hole = savannah:FindFirstChild(ExpeditionConfig.WateringHoleName)
	if hole == nil or not hole:IsA("BasePart") then
		error("[RegionResolver] Missing Savannah.WateringHole")
	end
	return hole
end

function RegionResolver.getResourceRegions(regionFolderName: string): { RegionInfo }
	local savannah = RegionResolver.getSavannahFolder()
	local resourceRoot = savannah:FindFirstChild(ExpeditionConfig.ResourceRegionsFolderName)
	if resourceRoot == nil then
		error("[RegionResolver] Missing Savannah.ResourceRegions")
	end

	local folder = resourceRoot:FindFirstChild(regionFolderName)
	if folder == nil then
		error(string.format("[RegionResolver] Missing resource region folder %s", regionFolderName))
	end

	local regions = collectBaseParts(folder)
	if #regions == 0 then
		error(string.format("[RegionResolver] No BasePart regions found under %s", folder:GetFullName()))
	end
	return regions
end

function RegionResolver.getEnemyRegions(): { RegionInfo }
	local savannah = RegionResolver.getSavannahFolder()
	local folder = savannah:FindFirstChild(ExpeditionConfig.EnemyRegionsFolderName)
	if folder == nil then
		error("[RegionResolver] Missing Savannah.EnemySpawnRegion")
	end

	local regions = collectBaseParts(folder)
	if #regions == 0 then
		error("[RegionResolver] No enemy region BaseParts found")
	end
	return regions
end

function RegionResolver.getEventEligibleRegions(): { RegionInfo }
	local savannah = RegionResolver.getSavannahFolder()
	local matches: { RegionInfo } = {}
	for _, descendant in savannah:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("EventEligible") == true then
			table.insert(matches, {
				part = descendant,
				fullPath = descendant:GetFullName(),
				area = RegionSamplingCalculator.regionArea(descendant.Size),
				depthTier = descendant:GetAttribute("DepthTier") :: number?,
				eventEligible = true,
				regionWeight = descendant:GetAttribute("RegionWeight") :: number?,
			})
		end
	end
	table.sort(matches, function(a, b)
		return a.fullPath < b.fullPath
	end)
	return matches
end

function RegionResolver.selectRegion(regions: { RegionInfo }, rng: Random, useAreaWeight: boolean): RegionInfo?
	if #regions == 0 then
		return nil
	end
	if not useAreaWeight then
		return regions[rng:NextInteger(1, #regions)]
	end

	local areas = table.create(#regions)
	for index, region in regions do
		local weight = region.regionWeight
		areas[index] = if typeof(weight) == "number" and weight > 0 then weight else region.area
	end
	local selected = RegionSamplingCalculator.selectAreaWeightedIndex(areas, rng)
	if selected == nil then
		return nil
	end
	return regions[selected]
end

function RegionResolver.resolveTemplate(templateName: string): Instance
	local root = ServerStorage:FindFirstChild(ExpeditionConfig.TemplatesFolderName)
	if root == nil then
		error("[RegionResolver] Missing ServerStorage.ExpeditionTemplates")
	end

	local direct = root:FindFirstChild(templateName)
	if direct ~= nil then
		return direct
	end

	for _, folderName in { "ResourceNodes", "Enemies", "Events" } do
		local folder = root:FindFirstChild(folderName)
		if folder ~= nil then
			local nested = folder:FindFirstChild(templateName)
			if nested ~= nil then
				return nested
			end
		end
	end

	error(string.format("[RegionResolver] Missing template %s", templateName))
end

function RegionResolver.getOrCreateGeneratedFolder(childName: string): Folder
	local root = Workspace:FindFirstChild(ExpeditionConfig.GeneratedRootFolderName)
	if root == nil then
		root = Instance.new("Folder")
		root.Name = ExpeditionConfig.GeneratedRootFolderName
		root.Parent = Workspace
	end

	local zoneFolder = root:FindFirstChild(ExpeditionConfig.ZoneId)
	if zoneFolder == nil then
		zoneFolder = Instance.new("Folder")
		zoneFolder.Name = ExpeditionConfig.ZoneId
		zoneFolder.Parent = root
	end

	local child = zoneFolder:FindFirstChild(childName)
	if child == nil then
		child = Instance.new("Folder")
		child.Name = childName
		child.Parent = zoneFolder
	end

	assert(child:IsA("Folder"))
	return child
end

function RegionResolver.buildBasePositions(): { Vector3 }
	local positions: { Vector3 } = {}
	local bases = Workspace:FindFirstChild("Bases")
	if bases == nil then
		return positions
	end

	for _, base in bases:GetChildren() do
		if base:IsA("Model") then
			local spawn = base:FindFirstChild("PlayerSpawn")
			if spawn ~= nil and spawn:IsA("BasePart") then
				table.insert(positions, spawn.Position)
			else
				table.insert(positions, base:GetPivot().Position)
			end
		end
	end
	return positions
end

function RegionResolver.buildExclusions(): RegionSamplingCalculator.ExclusionVolumes
	local bank = RegionResolver.getBankZone()
	local hole = RegionResolver.getWateringHole()
	local boundary = RegionResolver.getZoneBoundary()

	return {
		bankZoneCFrame = bank.CFrame,
		bankZoneSize = bank.Size,
		wateringHoleCFrame = hole.CFrame,
		wateringHoleSize = hole.Size,
		zoneBoundaryCFrame = if boundary then boundary.CFrame else nil,
		zoneBoundarySize = if boundary then boundary.Size else nil,
		hubCenter = ExpeditionConfig.HubCenter,
		hubSafeRadius = ExpeditionConfig.HubSafeRadius,
		safeZoneExclusionRadius = ExpeditionConfig.SafeZoneExclusionRadius,
		landmarkExclusionRadius = ExpeditionConfig.LandmarkExclusionRadius,
		basePositions = RegionResolver.buildBasePositions(),
	}
end

return RegionResolver
