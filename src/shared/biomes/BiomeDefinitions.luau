--!strict

--[[
	Immutable biome presentation and map-geometry definitions.
	Radii were measured from Studio: Ground2 center, base extents, GeneratedFoliage range.
	No Roblox service access.
]]

local BiomeTypes = require(script.Parent.BiomeTypes)

local BiomeDefinitions = {}

export type BiomeId = BiomeTypes.BiomeId
export type BiomeDefinition = BiomeTypes.BiomeDefinition
export type MapGeometry = BiomeTypes.MapGeometry

-- Inspected from Workspace.Ring1.Ground2 Position.
-- Bases outer ~466; foliage starts ~489; foliage max ~833.
local MAP_GEOMETRY: MapGeometry = table.freeze({
	mapCenter = Vector3.new(-73.5045, 0, -40.2813),
	hubEnterThreshold = 460,
	hubExitThreshold = 480,
	savannahOuterRadius = 850,
})

local DEFAULT_TITLE_TIMING: BiomeTypes.TitleTiming = table.freeze({
	fadeInSeconds = 0.35,
	holdSeconds = 1.5,
	fadeOutSeconds = 0.6,
	startOffsetY = 18,
	endOffsetY = -14,
})

local function freezeColorCorrection(config: BiomeTypes.ColorCorrectionConfig): BiomeTypes.ColorCorrectionConfig
	return table.freeze({
		tintColor = config.tintColor,
		brightness = config.brightness,
		contrast = config.contrast,
		saturation = config.saturation,
	})
end

local function freezeAtmosphere(config: BiomeTypes.AtmosphereConfig): BiomeTypes.AtmosphereConfig
	return table.freeze({
		density = config.density,
		offset = config.offset,
		color = config.color,
		decay = config.decay,
		glare = config.glare,
		haze = config.haze,
	})
end

local function freezeBloom(config: BiomeTypes.BloomConfig): BiomeTypes.BloomConfig
	return table.freeze({
		intensity = config.intensity,
		size = config.size,
		threshold = config.threshold,
	})
end

local function freezeSunRays(config: BiomeTypes.SunRaysConfig): BiomeTypes.SunRaysConfig
	return table.freeze({
		intensity = config.intensity,
		spread = config.spread,
		enabled = config.enabled,
	})
end

local function defineBiome(raw: BiomeTypes.BiomeDefinition): BiomeTypes.BiomeDefinition
	return table.freeze({
		id = raw.id,
		displayName = raw.displayName,
		subtitle = raw.subtitle,
		showTitle = raw.showTitle,
		colorCorrection = freezeColorCorrection(raw.colorCorrection),
		atmosphere = freezeAtmosphere(raw.atmosphere),
		bloom = freezeBloom(raw.bloom),
		sunRays = freezeSunRays(raw.sunRays),
		ambientSoundId = raw.ambientSoundId,
		ambientVolume = raw.ambientVolume,
		transitionDuration = raw.transitionDuration,
		titleTiming = table.freeze({
			fadeInSeconds = raw.titleTiming.fadeInSeconds,
			holdSeconds = raw.titleTiming.holdSeconds,
			fadeOutSeconds = raw.titleTiming.fadeOutSeconds,
			startOffsetY = raw.titleTiming.startOffsetY,
			endOffsetY = raw.titleTiming.endOffsetY,
		}),
	})
end

-- Placeholder SoundIds: no biome ambience assets exist in the project yet.
-- Replace with real rbxassetid:// values when audio is available.
local AMBIENCE_PLACEHOLDER = ""

local biomes: { [BiomeTypes.BiomeId]: BiomeTypes.BiomeDefinition } = {
	Hub = defineBiome({
		id = "Hub",
		displayName = "RESEARCH COMPOUND",
		subtitle = "Safe Zone",
		showTitle = true,
		colorCorrection = {
			tintColor = Color3.fromRGB(255, 255, 255),
			brightness = 0,
			contrast = 0.02,
			saturation = 0,
		},
		atmosphere = {
			density = 0.28,
			offset = 0.25,
			color = Color3.fromRGB(199, 205, 214),
			decay = Color3.fromRGB(106, 112, 125),
			glare = 0,
			haze = 0.4,
		},
		bloom = {
			intensity = 0.2,
			size = 18,
			threshold = 1.4,
		},
		sunRays = {
			intensity = 0.01,
			spread = 0.08,
			enabled = true,
		},
		-- TODO: replace with hub lab/containment ambience asset
		ambientSoundId = AMBIENCE_PLACEHOLDER,
		ambientVolume = 0.35,
		transitionDuration = 2.0,
		titleTiming = DEFAULT_TITLE_TIMING,
	}),
	Savannah = defineBiome({
		id = "Savannah",
		displayName = "SAVANNAH",
		subtitle = "Foundational Wilds",
		showTitle = true,
		colorCorrection = {
			tintColor = Color3.fromRGB(255, 239, 205),
			brightness = 0.02,
			contrast = 0.07,
			saturation = -0.02,
		},
		atmosphere = {
			density = 0.38,
			offset = 0.2,
			color = Color3.fromRGB(214, 188, 145),
			decay = Color3.fromRGB(145, 118, 78),
			glare = 0.05,
			haze = 1.6,
		},
		bloom = {
			intensity = 0.35,
			size = 22,
			threshold = 1.15,
		},
		sunRays = {
			intensity = 0.03,
			spread = 0.12,
			enabled = true,
		},
		-- TODO: replace with savannah wind/insect ambience asset
		ambientSoundId = AMBIENCE_PLACEHOLDER,
		ambientVolume = 0.45,
		transitionDuration = 2.2,
		titleTiming = DEFAULT_TITLE_TIMING,
	}),
	-- OuterUnknown retains previous atmosphere in the controller; definition is a neutral fallback.
	OuterUnknown = defineBiome({
		id = "OuterUnknown",
		displayName = "UNKNOWN WILDS",
		subtitle = "Beyond the Ring",
		showTitle = false,
		colorCorrection = {
			tintColor = Color3.fromRGB(245, 245, 245),
			brightness = 0,
			contrast = 0,
			saturation = 0,
		},
		atmosphere = {
			density = 0.3,
			offset = 0.25,
			color = Color3.fromRGB(199, 199, 199),
			decay = Color3.fromRGB(106, 112, 125),
			glare = 0,
			haze = 0.8,
		},
		bloom = {
			intensity = 0.25,
			size = 20,
			threshold = 1.3,
		},
		sunRays = {
			intensity = 0.01,
			spread = 0.1,
			enabled = true,
		},
		ambientSoundId = AMBIENCE_PLACEHOLDER,
		ambientVolume = 0.2,
		transitionDuration = 2.0,
		titleTiming = DEFAULT_TITLE_TIMING,
	}),
}

table.freeze(biomes)

BiomeDefinitions.LIGHTING_EASING_STYLE = Enum.EasingStyle.Quad
BiomeDefinitions.LIGHTING_EASING_DIRECTION = Enum.EasingDirection.InOut
BiomeDefinitions.AUDIO_CROSSFADE_SECONDS = 2.5
BiomeDefinitions.POLL_INTERVAL_SECONDS = 0.15
-- OuterUnknown retains the previous atmosphere/audio rather than snapping to its fallback.
BiomeDefinitions.OUTER_UNKNOWN_RETAINS_PREVIOUS = true
BiomeDefinitions.SHOW_TITLE_ON_INITIAL_SPAWN = false
BiomeDefinitions.DEBUG_ENABLED = false

function BiomeDefinitions.getMapGeometry(): MapGeometry
	return MAP_GEOMETRY
end

function BiomeDefinitions.get(biomeId: BiomeTypes.BiomeId): BiomeTypes.BiomeDefinition?
	return biomes[biomeId]
end

function BiomeDefinitions.getAll(): { BiomeTypes.BiomeDefinition }
	return table.freeze({
		biomes.Hub,
		biomes.Savannah,
		biomes.OuterUnknown,
	})
end

function BiomeDefinitions.isValidBiomeId(value: string): boolean
	return biomes[value :: BiomeTypes.BiomeId] ~= nil
end

function BiomeDefinitions.isValidAmbientSoundId(soundId: string): boolean
	if typeof(soundId) ~= "string" or soundId == "" then
		return false
	end
	return string.match(soundId, "^rbxassetid://%d+$") ~= nil
end

return BiomeDefinitions
