--!strict

--[[
	Terrain-conforming Wheat clump scatter.
	Clones the Wheat template into smaller independently aligned instances.
	Does not deform meshes or modify terrain.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WheatScatterConfig = require(Shared:WaitForChild("environment"):WaitForChild("WheatScatterConfig"))
local WheatScatterValidation = require(Shared:WaitForChild("environment"):WaitForChild("WheatScatterValidation"))

export type ScatterResult = {
	placed: number,
	attempted: number,
	rejected: number,
	seed: number,
	folderPath: string,
	templatePath: string,
}

export type ScatterOptions = {
	seed: number?,
	clearExisting: boolean?,
	clearLegacyGeneratedWheat: boolean?,
	placementAttempts: number?,
}

local WheatScatterService = {}

local TEMPLATE_SEARCH_ROOTS = {
	ServerStorage,
	ReplicatedStorage,
}

local function isTerrainHit(instance: Instance?): boolean
	return instance == Workspace.Terrain
end

local function getLegacyGeneratedFolderPaths(): { Instance }
	local folders: { Instance } = {}

	local environment = Workspace:FindFirstChild("Environment")
	if environment == nil then
		return folders
	end

	local ring1 = environment:FindFirstChild("Ring1")
	if ring1 == nil then
		return folders
	end

	local generatedFoliage = ring1:FindFirstChild("GeneratedFoliage")
	if generatedFoliage ~= nil then
		table.insert(folders, generatedFoliage)
	end

	local gapFill = ring1:FindFirstChild("GapFill")
	if gapFill ~= nil then
		local grass = gapFill:FindFirstChild("Grass")
		if grass ~= nil then
			table.insert(folders, grass)
		end
	end

	return folders
end

function WheatScatterService.resolveTemplate(): BasePart
	local matches: { BasePart } = {}

	for _, root in TEMPLATE_SEARCH_ROOTS do
		for _, descendant in root:GetDescendants() do
			if descendant.Name == WheatScatterConfig.TemplateName and descendant:IsA("BasePart") then
				table.insert(matches, descendant)
			end
		end
	end

	if #matches == 0 then
		for _, descendant in Workspace:GetDescendants() do
			if descendant.Name == WheatScatterConfig.TemplateName and descendant:IsA("BasePart") then
				local generatedRoot = Workspace:FindFirstChild(WheatScatterConfig.GeneratedRootFolderName)
				if generatedRoot ~= nil and generatedRoot:IsAncestorOf(descendant) then
					continue
				end
				table.insert(matches, descendant)
			end
		end
	end

	if #matches == 0 then
		error("[WheatScatterService] No Wheat template BasePart found in ServerStorage, ReplicatedStorage, or Workspace")
	end

	if #matches > 1 then
		local paths = table.create(#matches)
		for index, match in matches do
			paths[index] = match:GetFullName()
		end
		error(string.format(
			"[WheatScatterService] Multiple Wheat templates found; cannot select safely:\n%s",
			table.concat(paths, "\n")
		))
	end

	return matches[1]
end

function WheatScatterService.getGeneratedFolder(createIfMissing: boolean): Folder?
	local root = Workspace:FindFirstChild(WheatScatterConfig.GeneratedRootFolderName)
	if root == nil and createIfMissing then
		root = Instance.new("Folder")
		root.Name = WheatScatterConfig.GeneratedRootFolderName
		root.Parent = Workspace
	end

	if root == nil or not root:IsA("Folder") then
		return nil
	end

	local wheatFolder = root:FindFirstChild(WheatScatterConfig.GeneratedFolderName)
	if wheatFolder == nil and createIfMissing then
		wheatFolder = Instance.new("Folder")
		wheatFolder.Name = WheatScatterConfig.GeneratedFolderName
		wheatFolder.Parent = root
	end

	if wheatFolder == nil or not wheatFolder:IsA("Folder") then
		return nil
	end

	return wheatFolder
end

function WheatScatterService.clearGenerated(): number
	local folder = WheatScatterService.getGeneratedFolder(false)
	if folder == nil then
		return 0
	end

	local removed = #folder:GetChildren()
	folder:ClearAllChildren()
	return removed
end

function WheatScatterService.clearLegacyGeneratedWheat(): number
	local removed = 0

	for _, folder in getLegacyGeneratedFolderPaths() do
		for _, child in folder:GetChildren() do
			if child.Name == WheatScatterConfig.TemplateName and child:IsA("BasePart") then
				child:Destroy()
				removed += 1
			end
		end
	end

	return removed
end

function WheatScatterService.buildRaycastExclusions(generatedFolder: Folder?): { Instance }
	local exclusions: { Instance } = {}

	local environment = Workspace:FindFirstChild("Environment")
	if environment ~= nil then
		table.insert(exclusions, environment)
	end

	local bases = Workspace:FindFirstChild("Bases")
	if bases ~= nil then
		table.insert(exclusions, bases)
	end

	if generatedFolder ~= nil then
		table.insert(exclusions, generatedFolder)
	end

	return exclusions
end

function WheatScatterService.sampleGround(
	worldXZ: Vector3,
	raycastParams: RaycastParams
): WheatScatterValidation.GroundSample?
	local origin = Vector3.new(
		worldXZ.X,
		worldXZ.Y + WheatScatterConfig.RaycastHeight,
		worldXZ.Z
	)
	local result = Workspace:Raycast(origin, Vector3.new(0, -WheatScatterConfig.RaycastDepth, 0), raycastParams)
	if result == nil or not isTerrainHit(result.Instance) then
		return nil
	end

	return {
		position = result.Position,
		normal = result.Normal,
	}
end

function WheatScatterService.alignPartCFrame(position: Vector3, normal: Vector3, yawRadians: number): CFrame
	local up = normal.Unit
	local reference = math.abs(up:Dot(Vector3.yAxis)) > 0.99 and Vector3.xAxis or Vector3.yAxis
	local right = up:Cross(reference).Unit
	local forward = right:Cross(up).Unit
	local base = CFrame.fromMatrix(position, right, up, -forward)
	return base * CFrame.Angles(0, yawRadians, 0)
end

function WheatScatterService.applyScale(clone: BasePart, template: BasePart, scale: number)
	clone.Size = template.Size * scale

	local cloneMesh = clone:FindFirstChildOfClass("SpecialMesh")
	local templateMesh = template:FindFirstChildOfClass("SpecialMesh")
	if cloneMesh ~= nil and templateMesh ~= nil then
		cloneMesh.Scale = templateMesh.Scale * scale
	end
end

function WheatScatterService.samplePlacement(
	candidateXZ: Vector3,
	clumpRadius: number,
	raycastParams: RaycastParams
): (WheatScatterValidation.GroundSample?, { WheatScatterValidation.GroundSample? })
	local offsets = WheatScatterValidation.buildSampleOffsets(clumpRadius)
	local samples: { WheatScatterValidation.GroundSample? } = table.create(#offsets)
	local centerSample: WheatScatterValidation.GroundSample? = nil

	for index, offset in offsets do
		local samplePoint = Vector3.new(candidateXZ.X + offset.X, candidateXZ.Y, candidateXZ.Z + offset.Z)
		local sample = WheatScatterService.sampleGround(samplePoint, raycastParams)
		samples[index] = sample
		if index == 1 then
			centerSample = sample
		end
	end

	return centerSample, samples
end

function WheatScatterService.placeClump(
	template: BasePart,
	parent: Folder,
	cframe: CFrame,
	scale: number
): BasePart
	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = true
	clone.CFrame = cframe
	WheatScatterService.applyScale(clone, template, scale)
	clone:SetAttribute("GeneratedBy", WheatScatterConfig.GeneratedByAttribute)
	clone:SetAttribute("GeneratedVersion", WheatScatterConfig.GeneratedVersion)
	clone.Parent = parent
	return clone
end

function WheatScatterService.scatter(options: ScatterOptions?): ScatterResult
	local seed = if options and options.seed then options.seed else WheatScatterConfig.Seed
	local clearExisting = if options and options.clearExisting ~= nil then options.clearExisting else true
	local clearLegacy = if options and options.clearLegacyGeneratedWheat ~= nil
		then options.clearLegacyGeneratedWheat
		else WheatScatterConfig.ClearLegacyGeneratedWheat
	local maxAttempts = if options and options.placementAttempts
		then options.placementAttempts
		else WheatScatterConfig.PlacementAttempts

	local template = WheatScatterService.resolveTemplate()
	local generatedFolder = WheatScatterService.getGeneratedFolder(true)
	if generatedFolder == nil then
		error("[WheatScatterService] Failed to create generated Wheat folder")
	end

	generatedFolder:SetAttribute("GeneratedBy", WheatScatterConfig.GeneratedByAttribute)
	generatedFolder:SetAttribute("Version", WheatScatterConfig.GeneratedVersion)
	generatedFolder:SetAttribute("Seed", seed)

	if clearExisting then
		WheatScatterService.clearGenerated()
	end

	local legacyRemoved = 0
	if clearLegacy then
		legacyRemoved = WheatScatterService.clearLegacyGeneratedWheat()
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = WheatScatterService.buildRaycastExclusions(generatedFolder)

	local rng = Random.new(seed)
	local placedPositions: { Vector3 } = {}
	local placed = 0
	local rejected = 0

	local validationConfig: WheatScatterValidation.ValidationConfig = {
		MaxSlopeDegrees = WheatScatterConfig.MaxSlopeDegrees,
		MaxHeightDifference = WheatScatterConfig.MaxHeightDifference,
		MaxNormalDifferenceDegrees = WheatScatterConfig.MaxNormalDifferenceDegrees,
		RequireAllSamplesToHit = WheatScatterConfig.RequireAllSamplesToHit,
	}

	local center = WheatScatterConfig.RegionCenter
	local innerRadius = WheatScatterConfig.InnerRadius
	local outerRadius = WheatScatterConfig.OuterRadius
	local templateFootprint = math.max(template.Size.X, template.Size.Z)

	for _ = 1, maxAttempts do
		local angle = rng:NextNumber(0, math.pi * 2)
		local innerSq = innerRadius * innerRadius
		local outerSq = outerRadius * outerRadius
		local radius = math.sqrt(rng:NextNumber(innerSq, outerSq))
		local candidate = Vector3.new(
			center.X + math.cos(angle) * radius,
			center.Y,
			center.Z + math.sin(angle) * radius
		)

		if not WheatScatterValidation.isWithinSpacing(candidate, placedPositions, WheatScatterConfig.MinimumSpacing) then
			rejected += 1
			continue
		end

		local scale = rng:NextNumber(WheatScatterConfig.MinimumScale, WheatScatterConfig.MaximumScale)
		local clumpRadius = templateFootprint * scale * WheatScatterConfig.SampleRadiusMultiplier
		local centerSample, samples = WheatScatterService.samplePlacement(candidate, clumpRadius, raycastParams)

		if not WheatScatterValidation.validateGroundSamples(centerSample, samples, validationConfig) then
			rejected += 1
			continue
		end

		local yaw = math.rad(rng:NextNumber(0, WheatScatterConfig.RandomYawDegrees))
		local sinkOffset = centerSample.normal.Unit * WheatScatterConfig.SinkDepth
		local placementPosition = centerSample.position - sinkOffset
		local cframe = if WheatScatterConfig.AlignToSurfaceNormal
			then WheatScatterService.alignPartCFrame(placementPosition, centerSample.normal, yaw)
			else CFrame.new(placementPosition) * CFrame.Angles(0, yaw, 0)

		WheatScatterService.placeClump(template, generatedFolder, cframe, scale)
		table.insert(placedPositions, candidate)
		placed += 1
	end

	if legacyRemoved > 0 then
		print(string.format("[WheatScatterService] Cleared %d legacy generated Wheat instances", legacyRemoved))
	end

	print(string.format(
		"[WheatScatterService] Scatter complete placed=%d rejected=%d seed=%d folder=%s",
		placed,
		rejected,
		seed,
		generatedFolder:GetFullName()
	))

	return {
		placed = placed,
		attempted = maxAttempts,
		rejected = rejected,
		seed = seed,
		folderPath = generatedFolder:GetFullName(),
		templatePath = template:GetFullName(),
	}
end

return WheatScatterService
