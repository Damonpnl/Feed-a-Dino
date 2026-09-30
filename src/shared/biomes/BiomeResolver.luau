--!strict

--[[
	Pure concentric biome resolution with hysteresis.
	No Roblox services. Deterministic and unit-testable.
]]

local BiomeTypes = require(script.Parent.BiomeTypes)
local BiomeDefinitions = require(script.Parent.BiomeDefinitions)

local BiomeResolver = {}

export type ResolveInput = {
	position: Vector3?,
	previousBiomeId: BiomeTypes.BiomeId?,
	mapGeometry: BiomeTypes.MapGeometry?,
}

export type ResolveResult = {
	biomeId: BiomeTypes.BiomeId,
	distance: number,
	changed: boolean,
	previousBiomeId: BiomeTypes.BiomeId?,
}

local function horizontalDistance(position: Vector3, center: Vector3): number
	local dx = position.X - center.X
	local dz = position.Z - center.Z
	return math.sqrt(dx * dx + dz * dz)
end

function BiomeResolver.getHorizontalDistance(position: Vector3, mapCenter: Vector3): number
	return horizontalDistance(position, mapCenter)
end

--[[
	Hysteresis:
	- Enter Savannah when distance > hubExitThreshold.
	- Re-enter Hub only when distance < hubEnterThreshold.
	- OuterUnknown when distance > savannahOuterRadius.
	While previous is Savannah and distance is between enter/exit, stay Savannah.
]]
function BiomeResolver.resolve(input: ResolveInput): ResolveResult
	local geometry = input.mapGeometry or BiomeDefinitions.getMapGeometry()
	local previous = input.previousBiomeId

	if input.position == nil then
		local fallback: BiomeTypes.BiomeId = previous or "Hub"
		return {
			biomeId = fallback,
			distance = 0,
			changed = false,
			previousBiomeId = previous,
		}
	end

	local distance = horizontalDistance(input.position, geometry.mapCenter)
	local biomeId: BiomeTypes.BiomeId

	if distance > geometry.savannahOuterRadius then
		biomeId = "OuterUnknown"
	elseif previous == "Savannah" or previous == "OuterUnknown" then
		if distance < geometry.hubEnterThreshold then
			biomeId = "Hub"
		elseif distance > geometry.savannahOuterRadius then
			biomeId = "OuterUnknown"
		else
			biomeId = "Savannah"
		end
	else
		-- Hub or nil previous: enter Savannah only past exit threshold.
		if distance > geometry.hubExitThreshold then
			biomeId = "Savannah"
		else
			biomeId = "Hub"
		end
	end

	-- Outer band always wins.
	if distance > geometry.savannahOuterRadius then
		biomeId = "OuterUnknown"
	end

	return {
		biomeId = biomeId,
		distance = distance,
		changed = previous == nil or previous ~= biomeId,
		previousBiomeId = previous,
	}
end

function BiomeResolver.shouldTriggerTransition(
	previousBiomeId: BiomeTypes.BiomeId?,
	nextBiomeId: BiomeTypes.BiomeId,
	allowInitial: boolean
): boolean
	if previousBiomeId == nil then
		return allowInitial
	end
	return previousBiomeId ~= nextBiomeId
end

return BiomeResolver
