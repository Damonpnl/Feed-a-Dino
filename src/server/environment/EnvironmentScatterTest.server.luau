--!strict

--[[
	Deterministic tests for rainforest scatter validation and config.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RainforestScatterConfig = require(Shared:WaitForChild("environment"):WaitForChild("RainforestScatterConfig"))
local EnvironmentScatterValidation = require(Shared:WaitForChild("environment"):WaitForChild("EnvironmentScatterValidation"))

local function assertTrue(value: boolean, message: string)
	assert(value, message)
end

local function assertFalse(value: boolean, message: string)
	assert(not value, message)
end

local function assertEq(a: any, b: any, message: string)
	assert(a == b, string.format("%s (got %s expected %s)", message, tostring(a), tostring(b)))
end

assertEq(RainforestScatterConfig.Seed, 84721, "Default rainforest seed")
assertEq(RainforestScatterConfig.SetPieces.TargetCount, 2, "Set piece target is 2")
assertTrue(RainforestScatterConfig.Vegetation.MaxSlopeDegrees == 32, "Vegetation slope default")
assertTrue(RainforestScatterConfig.Rocks.MaxSlopeDegrees == 45, "Rock slope default")
assertTrue(RainforestScatterConfig.SetPieces.MaxSlopeDegrees == 18, "Set piece slope default")
assertTrue(RainforestScatterConfig.SavannahTransitionBuffer == 12, "Transition buffer default")

assertTrue(EnvironmentScatterValidation.slopeDegrees(Vector3.yAxis) < 0.001, "Flat slope is zero")
assertTrue(EnvironmentScatterValidation.slopeDegrees(Vector3.new(0, 1, 1).Unit) > 44, "45-degree slope lower bound")
assertTrue(EnvironmentScatterValidation.slopeDegrees(Vector3.new(0, 1, 1).Unit) < 46, "45-degree slope upper bound")

local savannah: EnvironmentScatterValidation.BoundaryVolume = {
	kind = "circle",
	center = Vector3.zero,
	radius = 100,
}
local rainforest: EnvironmentScatterValidation.BoundaryVolume = {
	kind = "circle",
	center = Vector3.zero,
	radius = 200,
}

assertFalse(
	EnvironmentScatterValidation.isInsideRainforest(Vector3.new(50, 0, 0), rainforest, savannah),
	"Inside savannah is not rainforest"
)
assertTrue(
	EnvironmentScatterValidation.isInsideRainforest(Vector3.new(150, 0, 0), rainforest, savannah),
	"Annulus point is rainforest"
)
assertFalse(
	EnvironmentScatterValidation.isInsideRainforest(Vector3.new(250, 0, 0), rainforest, savannah),
	"Outside outer boundary is not rainforest"
)

local box: EnvironmentScatterValidation.BoundaryVolume = {
	kind = "box",
	center = Vector3.zero,
	cframe = CFrame.new(),
	size = Vector3.new(40, 20, 40),
}
assertTrue(EnvironmentScatterValidation.contains(box, Vector3.new(10, 100, 10)), "Box XZ membership ignores Y")
assertFalse(EnvironmentScatterValidation.contains(box, Vector3.new(30, 0, 0)), "Outside box XZ")
assertTrue(EnvironmentScatterValidation.signedDistanceOutside(box, Vector3.new(30, 0, 0)) > 0, "Outside box has positive distance")
assertTrue(EnvironmentScatterValidation.signedDistanceOutside(box, Vector3.zero) < 0, "Inside box has negative distance")

assertEq(EnvironmentScatterValidation.biomeDepthFactor(8, 15, 40), 0.18, "Sparse band factor")
assertTrue(EnvironmentScatterValidation.biomeDepthFactor(25, 15, 40) > 0.18, "Moderate band increases")
assertTrue(EnvironmentScatterValidation.biomeDepthFactor(80, 15, 40) > 0.9, "Deep rainforest near full density")
assertEq(EnvironmentScatterValidation.biomeDepthFactor(0, 15, 40), 0, "Savannah interior has zero depth")

local noiseA = EnvironmentScatterValidation.densityNoise(100, 200, 84721, 0.018)
local noiseB = EnvironmentScatterValidation.densityNoise(100, 200, 84721, 0.018)
local noiseC = EnvironmentScatterValidation.densityNoise(100, 200, 11111, 0.018)
assertEq(noiseA, noiseB, "Noise is deterministic for the same seed")
assertTrue(noiseA ~= noiseC, "Different seeds change noise")
assertTrue(noiseA >= 0 and noiseA <= 1, "Noise stays in 0-1")

assertTrue(
	EnvironmentScatterValidation.passesDensity(0.95, 1, 0.34),
	"High noise in deep rainforest passes"
)
assertFalse(
	EnvironmentScatterValidation.passesDensity(0.05, 0.18, 0.34),
	"Low noise on savannah edge fails"
)

assertTrue(EnvironmentScatterValidation.isGameplayResourceName("AncientBush"), "AncientBush blocked")
assertTrue(EnvironmentScatterValidation.isGameplayResourceName("InsectNest"), "InsectNest blocked")
assertFalse(EnvironmentScatterValidation.isGameplayResourceName("Fern01"), "Decorative plants allowed")

local placed = { Vector3.new(0, 0, 0) }
assertFalse(EnvironmentScatterValidation.isWithinSpacing(Vector3.new(2, 0, 0), placed, 3.2), "Close vegetation fails spacing")
assertTrue(EnvironmentScatterValidation.isWithinSpacing(Vector3.new(8, 0, 0), placed, 3.2), "Far vegetation passes spacing")

local rng = Random.new(84721)
local a = EnvironmentScatterValidation.sampleAnnulusPoint(Vector3.zero, 100, 200, rng)
local rng2 = Random.new(84721)
local b = EnvironmentScatterValidation.sampleAnnulusPoint(Vector3.zero, 100, 200, rng2)
assertEq(a, b, "Annulus sampling is deterministic")
local dist = EnvironmentScatterValidation.horizontalDistance(a, Vector3.zero)
assertTrue(dist >= 100 and dist <= 200, "Annulus sample stays in ring")

local counts = EnvironmentScatterValidation.createRejectCounts()
assertEq(EnvironmentScatterValidation.totalRejected(counts), 0, "Empty reject counts total 0")
counts.slope = 3
counts.density = 2
assertEq(EnvironmentScatterValidation.totalRejected(counts), 5, "Reject totals add")

local templates = ServerStorage:FindFirstChild("EnvironmentTemplates")
if templates ~= nil then
	local rainforestTemplates = templates:FindFirstChild("Rainforest")
	assertTrue(rainforestTemplates ~= nil, "ServerStorage.EnvironmentTemplates.Rainforest exists")
else
	warn("[EnvironmentScatterTest] ServerStorage.EnvironmentTemplates not present in this session")
end

print("[EnvironmentScatterTest] ALL ASSERTIONS PASSED")
