--!strict

--[[
	Immutable per-stage evolution thresholds.
	Growth and affinity gates are looked up by current stage, not a global constant.
]]

local StageConfig = {}

export type StageEvolutionConfig = {
	requiredGrowth: number,
	minimumTotalAffinity: number,
	nextStage: number?,
}

local configs: { [number]: StageEvolutionConfig } = table.freeze({
	[0] = table.freeze({
		requiredGrowth = 50,
		minimumTotalAffinity = 30,
		nextStage = 1,
	}),
	[1] = table.freeze({
		requiredGrowth = 100,
		minimumTotalAffinity = 30,
		nextStage = 2,
	}),
})

-- Fraction of stage affinities transferred into heritage on successful evolution.
StageConfig.HERITAGE_TRANSFER_FRACTION = 0.25
-- Heritage weight when computing effective affinities for route selection.
StageConfig.HERITAGE_EFFECTIVE_WEIGHT = 0.25
-- Fraction of stage influences transferred into heritage on successful evolution.
-- Not used for variant qualification in this slice.
StageConfig.HERITAGE_INFLUENCE_TRANSFER_FRACTION = 0.20
-- Specialized influence qualification thresholds.
StageConfig.INFLUENCE_QUALIFY_SCORE = 36
StageConfig.INFLUENCE_QUALIFY_SHARE = 0.60

function StageConfig.get(stage: number): StageEvolutionConfig?
	return configs[stage]
end

function StageConfig.getRequiredGrowth(stage: number): number?
	local config = configs[stage]
	if config == nil then
		return nil
	end
	return config.requiredGrowth
end

function StageConfig.getMinimumTotalAffinity(stage: number): number?
	local config = configs[stage]
	if config == nil then
		return nil
	end
	return config.minimumTotalAffinity
end

function StageConfig.getNextStage(stage: number): number?
	local config = configs[stage]
	if config == nil then
		return nil
	end
	return config.nextStage
end

function StageConfig.isSupportedEvolutionStage(stage: number): boolean
	return configs[stage] ~= nil and configs[stage].nextStage ~= nil
end

return StageConfig
