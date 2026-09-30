--!strict

--[[
	Central configuration for terrain-conforming Wheat clump placement.
	Rigid Wheat parts cannot bend; many smaller aligned clumps follow local slope.
]]

local BiomeDefinitions = require(script.Parent.Parent.biomes.BiomeDefinitions)

local geometry = BiomeDefinitions.getMapGeometry()

return table.freeze({
	TemplateName = "Wheat",

	GeneratedRootFolderName = "GeneratedEnvironment",
	GeneratedFolderName = "Wheat",
	GeneratedByAttribute = "WheatScatterService",
	GeneratedVersion = 1,

	Seed = 1337,

	-- Savannah ring measured from map center (hub border ~466, foliage ~489–833).
	RegionCenter = geometry.mapCenter,
	InnerRadius = 490,
	OuterRadius = 840,

	RaycastHeight = 50,
	RaycastDepth = 120,

	MaxSlopeDegrees = 35,
	MaxHeightDifference = 0.55,
	MaxNormalDifferenceDegrees = 18,

	SinkDepth = 0.12,

	MinimumSpacing = 1.75,
	PlacementAttempts = 500,

	MinimumScale = 0.75,
	MaximumScale = 1.15,

	RandomYawDegrees = 360,

	SampleRadiusMultiplier = 0.38,

	RequireAllSamplesToHit = true,

	AlignToSurfaceNormal = true,

	-- When true, removes Wheat only from clearly generated folders before scatter.
	ClearLegacyGeneratedWheat = false,
})
