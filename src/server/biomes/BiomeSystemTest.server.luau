--!strict

--[[
	Deterministic tests for concentric biome resolution and definition integrity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = Shared:WaitForChild("biomes")
local BiomeDefinitions = require(Biomes:WaitForChild("BiomeDefinitions"))
local BiomeResolver = require(Biomes:WaitForChild("BiomeResolver"))

local geometry = BiomeDefinitions.getMapGeometry()
local center = geometry.mapCenter

local function posAtDistance(distance: number): Vector3
	return Vector3.new(center.X + distance, 0, center.Z)
end

-- Definition coverage.
local all = BiomeDefinitions.getAll()
assert(#all == 3, "Expected Hub, Savannah, OuterUnknown")
assert(BiomeDefinitions.get("Hub") ~= nil)
assert(BiomeDefinitions.get("Savannah") ~= nil)
assert(BiomeDefinitions.get("OuterUnknown") ~= nil)

local hub = BiomeDefinitions.get("Hub") :: any
local savannah = BiomeDefinitions.get("Savannah") :: any
assert(hub.displayName == "RESEARCH COMPOUND")
assert(hub.subtitle == "Safe Zone")
assert(savannah.displayName == "SAVANNAH")
assert(savannah.subtitle == "Foundational Wilds")
assert(hub.showTitle == true)
assert(savannah.showTitle == true)
assert(BiomeDefinitions.get("OuterUnknown").showTitle == false)

-- Geometry sanity from Studio inspection.
assert(geometry.hubEnterThreshold < geometry.hubExitThreshold, "Hysteresis enter must be below exit")
assert(geometry.hubExitThreshold < geometry.savannahOuterRadius)
assert(math.abs(geometry.mapCenter.X - (-73.5045)) < 0.01)
assert(math.abs(geometry.mapCenter.Z - (-40.2813)) < 0.01)
assert(geometry.hubEnterThreshold == 460)
assert(geometry.hubExitThreshold == 480)
assert(geometry.savannahOuterRadius == 850)

-- 1. Inside hub -> Hub
local inside = BiomeResolver.resolve({
	position = posAtDistance(100),
	previousBiomeId = nil,
})
assert(inside.biomeId == "Hub", "Inside hub must resolve Hub")

-- 2. Beyond Savannah entry threshold -> Savannah
local enterSavannah = BiomeResolver.resolve({
	position = posAtDistance(geometry.hubExitThreshold + 1),
	previousBiomeId = "Hub",
})
assert(enterSavannah.biomeId == "Savannah", "Past hubExit must enter Savannah")

-- 3. Beyond Savannah outer radius -> OuterUnknown
local outer = BiomeResolver.resolve({
	position = posAtDistance(geometry.savannahOuterRadius + 10),
	previousBiomeId = "Savannah",
})
assert(outer.biomeId == "OuterUnknown", "Past outer radius must be OuterUnknown")

-- 4. Border hysteresis: between enter/exit while previously Savannah stays Savannah
local border = BiomeResolver.resolve({
	position = posAtDistance((geometry.hubEnterThreshold + geometry.hubExitThreshold) / 2),
	previousBiomeId = "Savannah",
})
assert(border.biomeId == "Savannah", "Hysteresis band must keep Savannah")

local borderFromHub = BiomeResolver.resolve({
	position = posAtDistance((geometry.hubEnterThreshold + geometry.hubExitThreshold) / 2),
	previousBiomeId = "Hub",
})
assert(borderFromHub.biomeId == "Hub", "Hysteresis band from Hub must keep Hub")

-- 5. Repeated updates inside same biome do not report a transition need
local stay = BiomeResolver.resolve({
	position = posAtDistance(120),
	previousBiomeId = "Hub",
})
assert(stay.biomeId == "Hub")
assert(stay.changed == false)
assert(BiomeResolver.shouldTriggerTransition("Hub", "Hub", false) == false)

-- 6. Returning below hub re-entry threshold resolves Hub
local reenter = BiomeResolver.resolve({
	position = posAtDistance(geometry.hubEnterThreshold - 1),
	previousBiomeId = "Savannah",
})
assert(reenter.biomeId == "Hub", "Below hubEnter must re-enter Hub")

-- 7. Missing character / position does not error and retains previous
local missing = BiomeResolver.resolve({
	position = nil,
	previousBiomeId = "Savannah",
})
assert(missing.biomeId == "Savannah")
assert(missing.changed == false)

local missingNil = BiomeResolver.resolve({
	position = nil,
	previousBiomeId = nil,
})
assert(missingNil.biomeId == "Hub")

-- 8. Missing ambience SoundId is treated as invalid (controller must not error)
assert(BiomeDefinitions.isValidAmbientSoundId("") == false)
assert(BiomeDefinitions.isValidAmbientSoundId("not-an-id") == false)
assert(BiomeDefinitions.isValidAmbientSoundId("rbxassetid://123") == true)
assert(BiomeDefinitions.isValidAmbientSoundId(hub.ambientSoundId) == false, "Placeholder ambience must be blank")

-- Initial spawn title policy
assert(BiomeDefinitions.SHOW_TITLE_ON_INITIAL_SPAWN == false)
assert(BiomeDefinitions.OUTER_UNKNOWN_RETAINS_PREVIOUS == true)
assert(BiomeResolver.shouldTriggerTransition(nil, "Hub", false) == false)
assert(BiomeResolver.shouldTriggerTransition(nil, "Hub", true) == true)
assert(BiomeResolver.shouldTriggerTransition("Hub", "Savannah", false) == true)

-- Distance helper
local d = BiomeResolver.getHorizontalDistance(posAtDistance(250), center)
assert(math.abs(d - 250) < 0.001)

print("[BiomeSystemTest] ALL ASSERTIONS PASSED")
