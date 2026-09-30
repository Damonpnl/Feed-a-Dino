--!strict

--[[
	Immutable rainforest environment scatter configuration.
	Biome membership is derived from existing ZoneBoundary objects when present.
]]

local BiomeDefinitions = require(script.Parent.Parent.biomes.BiomeDefinitions)

local geometry = BiomeDefinitions.getMapGeometry()

return table.freeze({
	BiomeId = "Rainforest",
	Seed = 84721,
	GenerateOnStart = true,
	Debug = true,

	GeneratedByAttribute = "EnvironmentScatterService",
	GeneratedVersion = 1,
	GeneratedFolderName = "GeneratedEnvironment",

	TemplateRootName = "EnvironmentTemplates",
	TemplateBiomeFolderName = "Rainforest",
	VegetationFolderCandidates = table.freeze({ "Vegetation", "Plants", "Foliage" }),
	RockFolderCandidates = table.freeze({ "Rocks", "Rock" }),
	SetPieceFolderCandidates = table.freeze({ "SetPieces", "SetPiece", "LargeTrees", "Trees" }),

	BiomeFolderCandidates = table.freeze({ "Biomes", "ExpeditionZones" }),
	SavannahFolderName = "Savannah",
	RainforestFolderName = "Rainforest",
	ZoneBoundaryName = "ZoneBoundary",
	ScatterExclusionsFolderName = "ScatterExclusions",
	ResourceRegionsFolderName = "ResourceRegions",
	EnemyRegionsFolderNames = table.freeze({ "EnemyRegions", "EnemySpawnRegion" }),

	MapCenter = geometry.mapCenter,
	FallbackSavannahRadius = geometry.savannahOuterRadius,
	FallbackRainforestOuterRadius = 1350,

	SavannahTransitionBuffer = 12,
	SparseDepthDistance = 15,
	ModerateDepthDistance = 40,

	RaycastHeight = 80,
	RaycastDepth = 220,
	YieldEveryAttempts = 40,

	CircleShapeTolerance = 0.12,

	Vegetation = table.freeze({
		Enabled = true,
		TargetCount = 380,
		MaxAttempts = 2000,
		MinScale = 0.80,
		MaxScale = 1.25,
		MaxSlopeDegrees = 32,
		DefaultSpacing = 3.2,
		DensityThreshold = 0.34,
		NoiseFrequency = 0.018,
		ExclusionClearance = 2.5,
		AlignToNormal = false,
		EmbedMin = 0,
		EmbedMax = 0.08,
		OverlapQuery = false,
	}),

	Rocks = table.freeze({
		Enabled = true,
		TargetCount = 70,
		MaxAttempts = 500,
		MinScale = 0.75,
		MaxScale = 1.40,
		MaxSlopeDegrees = 45,
		DefaultSpacing = 7.5,
		DensityThreshold = 0.28,
		NoiseFrequency = 0.012,
		ExclusionClearance = 5,
		AlignToNormal = true,
		EmbedMin = 0.08,
		EmbedMax = 0.40,
		ClusterChance = 0.28,
		ClusterMinExtra = 1,
		ClusterMaxExtra = 3,
		ClusterRadius = 9,
		OverlapQuery = true,
	}),

	SetPieces = table.freeze({
		Enabled = true,
		TargetCount = 2,
		MaxAttempts = 150,
		MinScale = 0.95,
		MaxScale = 1.08,
		MaxSlopeDegrees = 18,
		DefaultSpacing = 90,
		DensityThreshold = 0.22,
		NoiseFrequency = 0.008,
		ExclusionClearance = 18,
		AlignToNormal = false,
		EmbedMin = 0,
		EmbedMax = 0.15,
		MinDistanceFromSavannah = 55,
		OverlapQuery = true,
	}),
})
