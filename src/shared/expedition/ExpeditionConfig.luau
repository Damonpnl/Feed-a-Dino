--!strict

--[[
	Frozen central configuration for Savannah expedition placement and loop.
]]

local BiomeDefinitions = require(script.Parent.Parent.biomes.BiomeDefinitions)

local geometry = BiomeDefinitions.getMapGeometry()

return table.freeze({
	ZoneId = "Savannah",
	DisplayName = "Savannah",
	RiskTier = 1,
	FieldLossFraction = 0.25,
	BankOnReturn = true,

	ExpeditionZonesFolderName = "ExpeditionZones",
	TemplatesFolderName = "ExpeditionTemplates",
	GeneratedRootFolderName = "GeneratedExpedition",
	RemotesFolderName = "ExpeditionRemotes",

	ResourceRegionsFolderName = "ResourceRegions",
	EnemyRegionsFolderName = "EnemySpawnRegion",
	ZoneBoundaryName = "ZoneBoundary",
	BankZoneName = "BankZone",
	WateringHoleName = "WateringHole",

	InsectNestRegionFolderName = "InsectNestRegion",
	AncientBushRegionFolderName = "AncientBushRegion",
	CrystalOutcropRegionFolderName = "CrystalOutcropRegion",

	ResourceSeed = 41001,
	EnemySeed = 41002,
	EventSeed = 41003,
	RewardSeed = 41004,

	RaycastHeight = 80,
	RaycastDepth = 220,
	MaximumPlacementAttempts = 80,

	MaximumResourceSlopeDegrees = 30,
	MaximumEnemySlopeDegrees = 28,
	MaximumEventSlopeDegrees = 25,

	MinimumNodeSpacing = 10,
	MinimumEnemySpacing = 35,
	MinimumEventNodeSpacing = 8,

	SafeZoneExclusionRadius = 35,
	LandmarkExclusionRadius = 12,
	HubSafeRadius = geometry.hubExitThreshold,
	HubCenter = geometry.mapCenter,

	WaterMaterialRejected = true,
	TerrainOnlyByDefault = true,

	NodeSinkDepth = 0.15,
	PromptHoldDuration = 1.25,

	ZonePollIntervalSeconds = 0.25,

	InsectNestActiveCount = 6,
	AncientBushActiveCount = 8,
	CrystalOutcropActiveCount = 5,
	TerritorialRaptorMaxActive = 3,

	RaptorDetectionRadius = 80,
	RaptorChaseRadius = 100,
	RaptorMaxHomeDisplacement = 110,
	RaptorAttackCooldown = 1.5,
	RaptorDamage = 12,
	RaptorWanderRadius = 40,
	RaptorMoveSpeed = 16,
	RaptorAttackRange = 14,
	RaptorMaxVerticalSeparation = 18,
	RaptorThinkInterval = 0.2,

	DroppedBagTemplateName = "SoilBag",
	DroppedBagFolderName = "DroppedBags",
	DroppedBagLifetimeSeconds = 300,
	DroppedBagPromptHoldDuration = 1.0,
	DroppedBagBillboardMaxDistance = 120,
	DroppedBagCollectionServiceTag = "ExpeditionDroppedBag",

	UseAreaWeightedRegionSelection = true,
})
