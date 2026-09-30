--!strict

--[[
	Deterministic tests for Wheat scatter validation and configuration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WheatScatterConfig = require(Shared:WaitForChild("environment"):WaitForChild("WheatScatterConfig"))
local WheatScatterValidation = require(Shared:WaitForChild("environment"):WaitForChild("WheatScatterValidation"))

local function assertTrue(value: boolean, message: string)
	assert(value, message)
end

local function assertFalse(value: boolean, message: string)
	assert(not value, message)
end

-- Config integrity
assert(WheatScatterConfig.TemplateName == "Wheat")
assert(WheatScatterConfig.GeneratedFolderName == "Wheat")
assert(WheatScatterConfig.Seed == 1337)
assert(WheatScatterConfig.MaxSlopeDegrees == 35)
assert(WheatScatterConfig.MinimumSpacing == 1.75)
assert(WheatScatterConfig.PlacementAttempts == 500)
assert(WheatScatterConfig.SampleRadiusMultiplier == 0.38)
assert(WheatScatterConfig.RequireAllSamplesToHit == true)
assert(WheatScatterConfig.AlignToSurfaceNormal == true)

-- Slope helpers
assertTrue(
	WheatScatterValidation.angleFromUp(Vector3.yAxis) < 0.001,
	"Up normal should have zero slope"
)
assertTrue(
	WheatScatterValidation.angleFromUp(Vector3.new(0, 1, 1).Unit) < 46,
	"45-degree slope should measure near 45"
)
assertTrue(
	WheatScatterValidation.angleFromUp(Vector3.new(0, 1, 1).Unit) > 44,
	"45-degree slope should measure near 45"
)

local validationConfig: WheatScatterValidation.ValidationConfig = {
	MaxSlopeDegrees = WheatScatterConfig.MaxSlopeDegrees,
	MaxHeightDifference = WheatScatterConfig.MaxHeightDifference,
	MaxNormalDifferenceDegrees = WheatScatterConfig.MaxNormalDifferenceDegrees,
	RequireAllSamplesToHit = WheatScatterConfig.RequireAllSamplesToHit,
}

local flatCenter: WheatScatterValidation.GroundSample = {
	position = Vector3.new(0, 10, 0),
	normal = Vector3.yAxis,
}
local flatSamples: { WheatScatterValidation.GroundSample? } = {
	flatCenter,
	{ position = Vector3.new(1, 10.1, 0), normal = Vector3.yAxis },
	{ position = Vector3.new(-1, 9.95, 0), normal = Vector3.yAxis },
}

assertTrue(
	WheatScatterValidation.validateGroundSamples(flatCenter, flatSamples, validationConfig),
	"Flat terrain samples should pass"
)

local steepCenter: WheatScatterValidation.GroundSample = {
	position = Vector3.new(0, 10, 0),
	normal = Vector3.new(0, 0.5, 0.866).Unit,
}
assertFalse(
	WheatScatterValidation.validateGroundSamples(steepCenter, { steepCenter }, validationConfig),
	"Steep center slope should fail"
)

local ridgeCenter: WheatScatterValidation.GroundSample = {
	position = Vector3.new(0, 10, 0),
	normal = Vector3.yAxis,
}
local ridgeSamples: { WheatScatterValidation.GroundSample? } = {
	ridgeCenter,
	{ position = Vector3.new(1, 11, 0), normal = Vector3.yAxis },
}
assertFalse(
	WheatScatterValidation.validateGroundSamples(ridgeCenter, ridgeSamples, validationConfig),
	"Height difference across ridge should fail"
)

local twistedSamples: { WheatScatterValidation.GroundSample? } = {
	ridgeCenter,
	{ position = Vector3.new(1, 10, 0), normal = Vector3.new(0.7, 0.7, 0).Unit },
}
assertFalse(
	WheatScatterValidation.validateGroundSamples(ridgeCenter, twistedSamples, validationConfig),
	"Normal mismatch across clump should fail"
)

assertFalse(
	WheatScatterValidation.validateGroundSamples(flatCenter, { flatCenter, nil }, validationConfig),
	"Missing sample should fail when RequireAllSamplesToHit is true"
)

-- Spacing
local placed = { Vector3.new(0, 0, 0) }
assertFalse(
	WheatScatterValidation.isWithinSpacing(Vector3.new(1, 0, 0), placed, 1.75),
	"Too-close candidate should fail spacing"
)
assertTrue(
	WheatScatterValidation.isWithinSpacing(Vector3.new(2, 0, 0), placed, 1.75),
	"Far-enough candidate should pass spacing"
)

local offsets = WheatScatterValidation.buildSampleOffsets(2)
assert(#offsets >= 5, "Sample offsets should include center and cardinal points")

print("[WheatScatterTest] ALL ASSERTIONS PASSED")
