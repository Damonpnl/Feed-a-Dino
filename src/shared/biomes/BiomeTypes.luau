--!strict

--[[
	Shared type contracts for the concentric biome atmosphere system.
	Contains no data and no Roblox service access.
]]

local BiomeTypes = {}

export type BiomeId = "Hub" | "Savannah" | "OuterUnknown"

export type ColorCorrectionConfig = {
	tintColor: Color3,
	brightness: number,
	contrast: number,
	saturation: number,
}

export type AtmosphereConfig = {
	density: number,
	offset: number,
	color: Color3,
	decay: Color3,
	glare: number,
	haze: number,
}

export type BloomConfig = {
	intensity: number,
	size: number,
	threshold: number,
}

export type SunRaysConfig = {
	intensity: number,
	spread: number,
	enabled: boolean,
}

export type TitleTiming = {
	fadeInSeconds: number,
	holdSeconds: number,
	fadeOutSeconds: number,
	startOffsetY: number,
	endOffsetY: number,
}

export type BiomeDefinition = {
	id: BiomeId,
	displayName: string,
	subtitle: string,
	showTitle: boolean,
	colorCorrection: ColorCorrectionConfig,
	atmosphere: AtmosphereConfig,
	bloom: BloomConfig,
	sunRays: SunRaysConfig,
	ambientSoundId: string,
	ambientVolume: number,
	transitionDuration: number,
	titleTiming: TitleTiming,
}

export type MapGeometry = {
	mapCenter: Vector3,
	hubEnterThreshold: number,
	hubExitThreshold: number,
	savannahOuterRadius: number,
}

return BiomeTypes
