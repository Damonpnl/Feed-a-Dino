--!strict

--[[
	Server-authoritative rainforest environment scatter.
	Discovers templates and ZoneBoundary objects at runtime.
	Does not spawn gameplay resources or modify Savannah systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RainforestScatterConfig = require(Shared:WaitForChild("environment"):WaitForChild("RainforestScatterConfig"))
local EnvironmentScatterValidation = require(Shared:WaitForChild("environment"):WaitForChild("EnvironmentScatterValidation"))

type CategoryId = EnvironmentScatterValidation.CategoryId
type BoundaryVolume = EnvironmentScatterValidation.BoundaryVolume
type RejectCounts = EnvironmentScatterValidation.RejectCounts
type GroundSample = EnvironmentScatterValidation.GroundSample

type CategoryConfig = {
	Enabled: boolean,
	TargetCount: number,
	MaxAttempts: number,
	MinScale: number,
	MaxScale: number,
	MaxSlopeDegrees: number,
	DefaultSpacing: number,
	DensityThreshold: number,
	NoiseFrequency: number,
	ExclusionClearance: number,
	AlignToNormal: boolean,
	EmbedMin: number,
	EmbedMax: number,
	OverlapQuery: boolean,
	ClusterChance: number?,
	ClusterMinExtra: number?,
	ClusterMaxExtra: number?,
	ClusterRadius: number?,
	MinDistanceFromSavannah: number?,
}

type TemplateInfo = {
	instance: Instance,
	name: string,
	weight: number,
	minScale: number,
	maxScale: number,
	minSpacing: number,
	footprint: number,
}

type ExclusionVolume = {
	cframe: CFrame,
	size: Vector3,
	clearance: number,
}

type ScatterContext = {
	seed: number,
	rng: Random,
	savannah: BoundaryVolume,
	rainforest: BoundaryVolume,
	exclusions: { ExclusionVolume },
	gameplayVolumes: { ExclusionVolume },
	raycastParams: RaycastParams,
	generatedRoot: Folder,
	placedPositions: { [CategoryId]: { Vector3 } },
	placedInstances: { Instance },
}

export type CategoryResult = {
	placed: number,
	target: number,
	attempted: number,
	rejected: RejectCounts,
}

export type ScatterResult = {
	seed: number,
	vegetation: CategoryResult,
	rocks: CategoryResult,
	setPieces: CategoryResult,
	folderPath: string,
}

local EnvironmentScatterService = {}

local GAMEPLAY_FOLDER_NAMES = {
	"GeneratedExpedition",
	"Bases",
	"Conveyors",
	"Shops",
}

local function findChildByNames(parent: Instance, names: { string }): Instance?
	for _, name in names do
		local child = parent:FindFirstChild(name)
		if child ~= nil then
			return child
		end
	end
	return nil
end

local function findFirstFolder(parent: Instance, names: { string }): Folder?
	local found = findChildByNames(parent, names)
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	if found ~= nil and found:IsA("Model") then
		return nil
	end
	return nil
end

function EnvironmentScatterService.findBiomeRoot(biomeName: string): Instance?
	for _, folderName in RainforestScatterConfig.BiomeFolderCandidates do
		local root = Workspace:FindFirstChild(folderName)
		if root ~= nil then
			local biome = root:FindFirstChild(biomeName)
			if biome ~= nil then
				return biome
			end
		end
	end
	return nil
end

local function isNearlyCircularPart(part: BasePart): boolean
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		return true
	end
	local x = part.Size.X
	local z = part.Size.Z
	local largest = math.max(x, z)
	if largest <= 0 then
		return false
	end
	return math.abs(x - z) / largest <= RainforestScatterConfig.CircleShapeTolerance
end

function EnvironmentScatterService.volumeFromPart(part: BasePart): BoundaryVolume
	if isNearlyCircularPart(part) then
		return {
			kind = "circle",
			center = part.Position,
			radius = math.min(part.Size.X, part.Size.Z) * 0.5,
			cframe = part.CFrame,
			size = part.Size,
		}
	end
	return {
		kind = "box",
		center = part.Position,
		cframe = part.CFrame,
		size = part.Size,
	}
end

function EnvironmentScatterService.resolveSavannahBoundary(): BoundaryVolume
	local savannah = EnvironmentScatterService.findBiomeRoot(RainforestScatterConfig.SavannahFolderName)
	if savannah ~= nil then
		local boundary = savannah:FindFirstChild(RainforestScatterConfig.ZoneBoundaryName)
		if boundary ~= nil and boundary:IsA("BasePart") then
			boundary.Anchored = true
			return EnvironmentScatterService.volumeFromPart(boundary)
		end
	end
	return {
		kind = "circle",
		center = RainforestScatterConfig.MapCenter,
		radius = RainforestScatterConfig.FallbackSavannahRadius,
	}
end

function EnvironmentScatterService.resolveRainforestBoundary(): BoundaryVolume
	local rainforest = EnvironmentScatterService.findBiomeRoot(RainforestScatterConfig.RainforestFolderName)
	if rainforest ~= nil then
		local boundary = rainforest:FindFirstChild(RainforestScatterConfig.ZoneBoundaryName)
		if boundary ~= nil and boundary:IsA("BasePart") then
			boundary.Anchored = true
			return EnvironmentScatterService.volumeFromPart(boundary)
		end
	end
	return {
		kind = "circle",
		center = RainforestScatterConfig.MapCenter,
		radius = RainforestScatterConfig.FallbackRainforestOuterRadius,
	}
end

local function collectPartVolumes(root: Instance?, extraClearance: number): { ExclusionVolume }
	local volumes: { ExclusionVolume } = {}
	if root == nil then
		return volumes
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(volumes, {
				cframe = descendant.CFrame,
				size = descendant.Size,
				clearance = extraClearance,
			})
		end
	end
	return volumes
end

local function appendVolumes(target: { ExclusionVolume }, source: { ExclusionVolume })
	for _, volume in source do
		table.insert(target, volume)
	end
end

function EnvironmentScatterService.collectExclusionVolumes(clearance: number): { ExclusionVolume }
	local volumes: { ExclusionVolume } = {}
	local rainforest = EnvironmentScatterService.findBiomeRoot(RainforestScatterConfig.RainforestFolderName)
	if rainforest ~= nil then
		local exclusions = rainforest:FindFirstChild(RainforestScatterConfig.ScatterExclusionsFolderName)
		appendVolumes(volumes, collectPartVolumes(exclusions, clearance))
	end
	return volumes
end

function EnvironmentScatterService.collectGameplayVolumes(clearance: number): { ExclusionVolume }
	local volumes: { ExclusionVolume } = {}
	local rainforest = EnvironmentScatterService.findBiomeRoot(RainforestScatterConfig.RainforestFolderName)
	if rainforest ~= nil then
		local resources = rainforest:FindFirstChild(RainforestScatterConfig.ResourceRegionsFolderName)
		appendVolumes(volumes, collectPartVolumes(resources, clearance))
		for _, folderName in RainforestScatterConfig.EnemyRegionsFolderNames do
			appendVolumes(volumes, collectPartVolumes(rainforest:FindFirstChild(folderName), clearance))
		end
	end

	for _, folderName in GAMEPLAY_FOLDER_NAMES do
		appendVolumes(volumes, collectPartVolumes(Workspace:FindFirstChild(folderName), clearance))
	end

	local expeditionZones = Workspace:FindFirstChild("ExpeditionZones")
	if expeditionZones ~= nil then
		local savannah = expeditionZones:FindFirstChild("Savannah")
		if savannah ~= nil then
			appendVolumes(volumes, collectPartVolumes(savannah:FindFirstChild("ResourceRegions"), clearance))
			appendVolumes(volumes, collectPartVolumes(savannah:FindFirstChild("EnemySpawnRegion"), clearance))
			local bank = savannah:FindFirstChild("BankZone")
			if bank ~= nil and bank:IsA("BasePart") then
				table.insert(volumes, { cframe = bank.CFrame, size = bank.Size, clearance = clearance })
			end
			local hole = savannah:FindFirstChild("WateringHole")
			if hole ~= nil and hole:IsA("BasePart") then
				table.insert(volumes, { cframe = hole.CFrame, size = hole.Size, clearance = clearance })
			end
		end
	end

	return volumes
end

local function hitsVolume(position: Vector3, volume: ExclusionVolume, extraClearance: number): boolean
	local clearance = volume.clearance + extraClearance
	local expanded = volume.size + Vector3.new(clearance * 2, volume.size.Y, clearance * 2)
	return EnvironmentScatterValidation.pointInOrientedBoxXZ(position, volume.cframe, expanded)
end

local function hitsAnyVolume(position: Vector3, volumes: { ExclusionVolume }, extraClearance: number): boolean
	for _, volume in volumes do
		if hitsVolume(position, volume, extraClearance) then
			return true
		end
	end
	return false
end

function EnvironmentScatterService.findTemplateRoot(): Instance?
	local templates = ServerStorage:FindFirstChild(RainforestScatterConfig.TemplateRootName)
	if templates == nil then
		return nil
	end
	local rainforest = templates:FindFirstChild(RainforestScatterConfig.TemplateBiomeFolderName)
	if rainforest ~= nil then
		return rainforest
	end
	return templates
end

local function estimateFootprint(instance: Instance): number
	if instance:IsA("Model") then
		local _cf, size = instance:GetBoundingBox()
		return math.max(size.X, size.Z)
	end
	if instance:IsA("BasePart") then
		return math.max(instance.Size.X, instance.Size.Z)
	end
	return 4
end

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" and value == value then
		return value
	end
	return fallback
end

function EnvironmentScatterService.collectTemplates(folderNames: { string }, category: CategoryConfig): { TemplateInfo }
	local templates: { TemplateInfo } = {}
	local root = EnvironmentScatterService.findTemplateRoot()
	if root == nil then
		return templates
	end

	local folder = findChildByNames(root, folderNames)
	if folder == nil then
		return templates
	end

	for _, child in folder:GetChildren() do
		if EnvironmentScatterValidation.isGameplayResourceName(child.Name) then
			continue
		end
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(templates, {
				instance = child,
				name = child.Name,
				weight = math.max(numberAttribute(child, "ScatterWeight", 1), 0.01),
				minScale = numberAttribute(child, "MinScale", category.MinScale),
				maxScale = numberAttribute(child, "MaxScale", category.MaxScale),
				minSpacing = numberAttribute(child, "MinSpacing", category.DefaultSpacing),
				footprint = estimateFootprint(child),
			})
		end
	end

	table.sort(templates, function(a, b)
		return a.name < b.name
	end)
	return templates
end

local function pickTemplate(templates: { TemplateInfo }, rng: Random): TemplateInfo?
	if #templates == 0 then
		return nil
	end
	local total = 0
	for _, template in templates do
		total += template.weight
	end
	local roll = rng:NextNumber(0, total)
	local cumulative = 0
	for _, template in templates do
		cumulative += template.weight
		if roll <= cumulative then
			return template
		end
	end
	return templates[#templates]
end

local function warnBadPivot(template: TemplateInfo)
	if not template.instance:IsA("Model") then
		return
	end
	local model = template.instance :: Model
	local boundsCf, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local localPivot = boundsCf:PointToObjectSpace(pivot.Position)
	local bottomY = -size.Y * 0.5
	if math.abs(localPivot.Y - bottomY) > math.max(6, size.Y * 0.45) then
		warn(string.format(
			"[EnvironmentScatterService] Template %s pivot may not be at ground contact (offsetY=%.1f)",
			template.name,
			localPivot.Y - bottomY
		))
	end
end

local function sanitizeClone(clone: Instance)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	if clone:IsA("BaseScript") or clone:IsA("ModuleScript") then
		clone:Destroy()
	end
end

local function applyScale(clone: Instance, scale: number)
	if clone:IsA("Model") then
		clone:ScaleTo(scale)
	elseif clone:IsA("BasePart") then
		clone.Size = clone.Size * scale
	end
end

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function EnvironmentScatterService.getGeneratedRoot(createIfMissing: boolean): Folder?
	local rainforest = EnvironmentScatterService.findBiomeRoot(RainforestScatterConfig.RainforestFolderName)
	if rainforest ~= nil then
		local existing = rainforest:FindFirstChild(RainforestScatterConfig.GeneratedFolderName)
		if existing ~= nil and existing:IsA("Folder") then
			return existing
		end
		if not createIfMissing then
			return nil
		end
		local folder = Instance.new("Folder")
		folder.Name = RainforestScatterConfig.GeneratedFolderName
		folder:SetAttribute("GeneratedBy", RainforestScatterConfig.GeneratedByAttribute)
		folder:SetAttribute("GeneratedVersion", RainforestScatterConfig.GeneratedVersion)
		folder.Parent = rainforest
		return folder
	end

	-- Keep rainforest output out of the Savannah wheat folder.
	local workspaceRoot = Workspace:FindFirstChild(RainforestScatterConfig.GeneratedFolderName)
	if workspaceRoot == nil and createIfMissing then
		workspaceRoot = Instance.new("Folder")
		workspaceRoot.Name = RainforestScatterConfig.GeneratedFolderName
		workspaceRoot.Parent = Workspace
	end
	if workspaceRoot == nil or not workspaceRoot:IsA("Folder") then
		return nil
	end

	local biomeFolder = workspaceRoot:FindFirstChild(RainforestScatterConfig.RainforestFolderName)
	if biomeFolder ~= nil and biomeFolder:IsA("Folder") then
		return biomeFolder
	end
	if not createIfMissing then
		return nil
	end
	local created = Instance.new("Folder")
	created.Name = RainforestScatterConfig.RainforestFolderName
	created:SetAttribute("GeneratedBy", RainforestScatterConfig.GeneratedByAttribute)
	created:SetAttribute("GeneratedVersion", RainforestScatterConfig.GeneratedVersion)
	created.Parent = workspaceRoot
	return created
end

function EnvironmentScatterService.ClearRainforest(): number
	local root = EnvironmentScatterService.getGeneratedRoot(false)
	if root == nil then
		return 0
	end
	if root:GetAttribute("GeneratedBy") ~= RainforestScatterConfig.GeneratedByAttribute then
		warn("[EnvironmentScatterService] Refusing to clear a folder not owned by the scatter system")
		return 0
	end
	local removed = 0
	for _, child in root:GetDescendants() do
		if child:GetAttribute("GeneratedBy") == RainforestScatterConfig.GeneratedByAttribute then
			removed += 1
		end
	end
	root:ClearAllChildren()
	return removed
end

local function buildRaycastParams(generatedRoot: Folder): RaycastParams
	local exclusions: { Instance } = { generatedRoot }
	for _, name in { "Environment", "Ring1", "Bases", "Conveyors", "area", "ExpeditionZones", "GeneratedExpedition", "Biomes" } do
		local instance = Workspace:FindFirstChild(name)
		if instance ~= nil and instance ~= generatedRoot and not generatedRoot:IsAncestorOf(instance) then
			table.insert(exclusions, instance)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.IgnoreWater = true
	return params
end

function EnvironmentScatterService.sampleGround(
	worldXZ: Vector3,
	raycastParams: RaycastParams
): GroundSample?
	local origin = Vector3.new(
		worldXZ.X,
		worldXZ.Y + RainforestScatterConfig.RaycastHeight,
		worldXZ.Z
	)
	local depth = RainforestScatterConfig.RaycastHeight + RainforestScatterConfig.RaycastDepth
	local result = Workspace:Raycast(origin, Vector3.new(0, -depth, 0), raycastParams)
	if result == nil then
		return nil
	end
	if result.Material == Enum.Material.Water then
		return {
			position = result.Position,
			normal = result.Normal,
			material = result.Material,
		}
	end
	local allowedGround = result.Instance == Workspace.Terrain
		or result.Instance:GetAttribute("ScatterGround") == true
	if not allowedGround then
		return nil
	end
	return {
		position = result.Position,
		normal = result.Normal,
		material = result.Material,
	}
end

local function uprightCFrame(position: Vector3, yaw: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

local function alignedCFrame(position: Vector3, normal: Vector3, yaw: number): CFrame
	local up = normal.Unit
	local reference = if math.abs(up:Dot(Vector3.yAxis)) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = up:Cross(reference).Unit
	local forward = right:Cross(up).Unit
	return CFrame.fromMatrix(position, right, up, -forward) * CFrame.Angles(0, yaw, 0)
end

local function overlapsExisting(position: Vector3, radius: number, existing: { Instance }): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = existing
	local parts = Workspace:GetPartBoundsInBox(
		CFrame.new(position),
		Vector3.new(radius * 2, 8, radius * 2),
		overlapParams
	)
	return #parts > 0
end

local function getCategoryConfig(categoryId: CategoryId): CategoryConfig
	if categoryId == "Vegetation" then
		return RainforestScatterConfig.Vegetation
	elseif categoryId == "Rocks" then
		return RainforestScatterConfig.Rocks
	end
	return RainforestScatterConfig.SetPieces
end

local function candidateAllowed(
	context: ScatterContext,
	categoryId: CategoryId,
	category: CategoryConfig,
	candidate: Vector3,
	rejects: RejectCounts
): (GroundSample?, number?)
	if not EnvironmentScatterValidation.contains(context.rainforest, candidate) then
		rejects.outsideBiome += 1
		return nil, nil
	end
	if EnvironmentScatterValidation.contains(context.savannah, candidate) then
		rejects.savannahInterior += 1
		return nil, nil
	end

	local distanceFromSavannah = EnvironmentScatterValidation.signedDistanceOutside(context.savannah, candidate)
	if categoryId == "SetPieces" then
		local minDistance = category.MinDistanceFromSavannah or 55
		if distanceFromSavannah < minDistance then
			rejects.transition += 1
			return nil, nil
		end
	elseif distanceFromSavannah < RainforestScatterConfig.SavannahTransitionBuffer then
		if categoryId == "Rocks" and distanceFromSavannah < RainforestScatterConfig.SavannahTransitionBuffer * 0.5 then
			rejects.transition += 1
			return nil, nil
		end
	end

	local depthFactor = EnvironmentScatterValidation.biomeDepthFactor(
		distanceFromSavannah,
		RainforestScatterConfig.SparseDepthDistance,
		RainforestScatterConfig.ModerateDepthDistance
	)
	local noise = EnvironmentScatterValidation.densityNoise(
		candidate.X,
		candidate.Z,
		context.seed,
		category.NoiseFrequency
	)
	if not EnvironmentScatterValidation.passesDensity(noise, depthFactor, category.DensityThreshold) then
		rejects.density += 1
		return nil, nil
	end

	if hitsAnyVolume(candidate, context.exclusions, category.ExclusionClearance) then
		rejects.exclusion += 1
		return nil, nil
	end
	if hitsAnyVolume(candidate, context.gameplayVolumes, category.ExclusionClearance) then
		rejects.gameplay += 1
		return nil, nil
	end

	local sample = EnvironmentScatterService.sampleGround(candidate, context.raycastParams)
	if sample == nil then
		rejects.noTerrain += 1
		return nil, nil
	end
	if sample.material == Enum.Material.Water then
		rejects.water += 1
		return nil, nil
	end
	if EnvironmentScatterValidation.slopeDegrees(sample.normal) > category.MaxSlopeDegrees then
		rejects.slope += 1
		return nil, nil
	end

	return sample, distanceFromSavannah
end

local function placeClone(
	context: ScatterContext,
	categoryId: CategoryId,
	category: CategoryConfig,
	template: TemplateInfo,
	sample: GroundSample,
	parent: Folder
): Instance?
	local scale = context.rng:NextNumber(template.minScale, math.max(template.minScale, template.maxScale))
	local yaw = math.rad(context.rng:NextNumber(0, 360))
	local embed = context.rng:NextNumber(category.EmbedMin, category.EmbedMax)
	local position = sample.position - Vector3.new(0, embed, 0)
	local cframe = if category.AlignToNormal
		then alignedCFrame(position, sample.normal, yaw)
		else uprightCFrame(position, yaw)

	local clone = template.instance:Clone()
	sanitizeClone(clone)
	if clone.Parent ~= nil or clone:IsA("BaseScript") then
		return nil
	end
	applyScale(clone, scale)
	if clone:IsA("Model") then
		(clone :: Model):PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		(clone :: BasePart).CFrame = cframe
		(clone :: BasePart).Anchored = true
	end
	clone:SetAttribute("GeneratedBy", RainforestScatterConfig.GeneratedByAttribute)
	clone:SetAttribute("GeneratedVersion", RainforestScatterConfig.GeneratedVersion)
	clone:SetAttribute("ScatterCategory", categoryId)
	clone.Parent = parent
	table.insert(context.placedInstances, clone)
	table.insert(context.placedPositions[categoryId], sample.position)
	return clone
end

local function tryPlace(
	context: ScatterContext,
	categoryId: CategoryId,
	category: CategoryConfig,
	templates: { TemplateInfo },
	parent: Folder,
	candidate: Vector3,
	rejects: RejectCounts
): boolean
	local sample = candidateAllowed(context, categoryId, category, candidate, rejects)
	if sample == nil then
		return false
	end

	local template = pickTemplate(templates, context.rng)
	if template == nil then
		rejects.invalidRegion += 1
		return false
	end

	local spacing = math.max(template.minSpacing, template.footprint * 0.35)
	if not EnvironmentScatterValidation.isWithinSpacing(sample.position, context.placedPositions[categoryId], spacing) then
		rejects.spacing += 1
		return false
	end
	if categoryId ~= "Vegetation" then
		if not EnvironmentScatterValidation.isWithinSpacing(sample.position, context.placedPositions.SetPieces, 18) then
			rejects.spacing += 1
			return false
		end
	end

	if category.OverlapQuery and overlapsExisting(sample.position, math.max(template.footprint * 0.35, 3), context.placedInstances) then
		rejects.overlap += 1
		return false
	end

	return placeClone(context, categoryId, category, template, sample, parent) ~= nil
end

local function scatterCategory(
	context: ScatterContext,
	categoryId: CategoryId,
	folderNames: { string }
): CategoryResult
	local category = getCategoryConfig(categoryId)
	local rejects = EnvironmentScatterValidation.createRejectCounts()
	local attempted = 0
	local placed = 0

	if not category.Enabled then
		return {
			placed = 0,
			target = category.TargetCount,
			attempted = 0,
			rejected = rejects,
		}
	end

	local templates = EnvironmentScatterService.collectTemplates(folderNames, category)
	if #templates == 0 then
		warn(string.format("[EnvironmentScatterService] No %s templates found under EnvironmentTemplates.Rainforest", categoryId))
		return {
			placed = 0,
			target = category.TargetCount,
			attempted = 0,
			rejected = rejects,
		}
	end

	if RainforestScatterConfig.Debug then
		for _, template in templates do
			warnBadPivot(template)
		end
	end

	local parent = ensureFolder(context.generatedRoot, categoryId)
	parent:SetAttribute("GeneratedBy", RainforestScatterConfig.GeneratedByAttribute)
	parent:SetAttribute("GeneratedVersion", RainforestScatterConfig.GeneratedVersion)
	local innerRadius = context.savannah.radius or RainforestScatterConfig.FallbackSavannahRadius
	local outerRadius = context.rainforest.radius or RainforestScatterConfig.FallbackRainforestOuterRadius
	if context.savannah.kind == "box" and context.savannah.size then
		innerRadius = math.max(context.savannah.size.X, context.savannah.size.Z) * 0.5
	end
	if context.rainforest.kind == "box" and context.rainforest.size then
		outerRadius = math.max(context.rainforest.size.X, context.rainforest.size.Z) * 0.5
	end
	innerRadius = math.max(innerRadius - 8, 0)
	outerRadius = math.max(outerRadius, innerRadius + 20)

	while placed < category.TargetCount and attempted < category.MaxAttempts do
		attempted += 1
		if attempted % RainforestScatterConfig.YieldEveryAttempts == 0 then
			task.wait()
		end

		local candidate = EnvironmentScatterValidation.sampleAnnulusPoint(
			RainforestScatterConfig.MapCenter,
			innerRadius,
			outerRadius,
			context.rng
		)

		if tryPlace(context, categoryId, category, templates, parent, candidate, rejects) then
			placed += 1

			local clusterChance = category.ClusterChance
			if clusterChance ~= nil and context.rng:NextNumber() < clusterChance then
				local extra = context.rng:NextInteger(category.ClusterMinExtra or 1, category.ClusterMaxExtra or 1)
				local radius = category.ClusterRadius or 8
				for _ = 1, extra do
					if placed >= category.TargetCount then
						break
					end
					local angle = context.rng:NextNumber(0, math.pi * 2)
					local offset = context.rng:NextNumber(2, radius)
					local clusterPoint = Vector3.new(
						candidate.X + math.cos(angle) * offset,
						candidate.Y,
						candidate.Z + math.sin(angle) * offset
					)
					if tryPlace(context, categoryId, category, templates, parent, clusterPoint, rejects) then
						placed += 1
					end
				end
			end
		end
	end

	return {
		placed = placed,
		target = category.TargetCount,
		attempted = attempted,
		rejected = rejects,
	}
end

local function printCategory(name: string, result: CategoryResult)
	local rejected = EnvironmentScatterValidation.totalRejected(result.rejected)
	print(string.format(
		"%s:\n%d/%d placed\n%d rejected  (density=%d slope=%d exclusion=%d spacing=%d terrain=%d water=%d biome=%d)",
		name,
		result.placed,
		result.target,
		rejected,
		result.rejected.density,
		result.rejected.slope,
		result.rejected.exclusion,
		result.rejected.spacing,
		result.rejected.noTerrain,
		result.rejected.water,
		result.rejected.outsideBiome + result.rejected.savannahInterior
	))
end

function EnvironmentScatterService.GenerateRainforest(seed: number?): ScatterResult
	local usedSeed = if seed ~= nil then seed else RainforestScatterConfig.Seed
	local generatedRoot = EnvironmentScatterService.getGeneratedRoot(true)
	if generatedRoot == nil then
		error("[EnvironmentScatterService] Failed to create GeneratedEnvironment folder")
	end

	generatedRoot:SetAttribute("GeneratedBy", RainforestScatterConfig.GeneratedByAttribute)
	generatedRoot:SetAttribute("GeneratedVersion", RainforestScatterConfig.GeneratedVersion)
	generatedRoot:SetAttribute("Seed", usedSeed)

	local savannah = EnvironmentScatterService.resolveSavannahBoundary()
	local rainforest = EnvironmentScatterService.resolveRainforestBoundary()

	local context: ScatterContext = {
		seed = usedSeed,
		rng = Random.new(usedSeed),
		savannah = savannah,
		rainforest = rainforest,
		exclusions = EnvironmentScatterService.collectExclusionVolumes(0),
		gameplayVolumes = EnvironmentScatterService.collectGameplayVolumes(6),
		raycastParams = buildRaycastParams(generatedRoot),
		generatedRoot = generatedRoot,
		placedPositions = {
			Vegetation = {},
			Rocks = {},
			SetPieces = {},
		},
		placedInstances = {},
	}

	-- Category-specific exclusion clearance is applied during hits by expanding each volume.
	context.exclusions = EnvironmentScatterService.collectExclusionVolumes(0)

	local vegetation = scatterCategory(context, "Vegetation", RainforestScatterConfig.VegetationFolderCandidates)
	local rocks = scatterCategory(context, "Rocks", RainforestScatterConfig.RockFolderCandidates)
	local setPieces = scatterCategory(context, "SetPieces", RainforestScatterConfig.SetPieceFolderCandidates)

	if setPieces.placed == 0 and RainforestScatterConfig.SetPieces.Enabled then
		warn("[EnvironmentScatterService] No valid rainforest set-piece locations found")
	end

	if RainforestScatterConfig.Debug then
		print("[EnvironmentScatterService] Rainforest Scatter Complete")
		print(string.format("Seed=%d folder=%s", usedSeed, generatedRoot:GetFullName()))
		printCategory("Vegetation", vegetation)
		printCategory("Rocks", rocks)
		printCategory("SetPieces", setPieces)
	end

	return {
		seed = usedSeed,
		vegetation = vegetation,
		rocks = rocks,
		setPieces = setPieces,
		folderPath = generatedRoot:GetFullName(),
	}
end

function EnvironmentScatterService.RegenerateRainforest(seed: number?): ScatterResult
	EnvironmentScatterService.ClearRainforest()
	return EnvironmentScatterService.GenerateRainforest(seed)
end

return EnvironmentScatterService
