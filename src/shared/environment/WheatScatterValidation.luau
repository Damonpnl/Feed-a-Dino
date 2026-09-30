--!strict

--[[
	Pure placement validation helpers for Wheat scatter.
	No Roblox service access; independently testable.
]]

export type GroundSample = {
	position: Vector3,
	normal: Vector3,
}

export type ValidationConfig = {
	MaxSlopeDegrees: number,
	MaxHeightDifference: number,
	MaxNormalDifferenceDegrees: number,
	RequireAllSamplesToHit: boolean,
}

local WheatScatterValidation = {}

function WheatScatterValidation.angleFromUp(normal: Vector3): number
	local unit = normal.Unit
	local clamped = math.clamp(unit:Dot(Vector3.yAxis), -1, 1)
	return math.deg(math.acos(clamped))
end

function WheatScatterValidation.angleBetweenNormals(a: Vector3, b: Vector3): number
	local unitA = a.Unit
	local unitB = b.Unit
	local clamped = math.clamp(unitA:Dot(unitB), -1, 1)
	return math.deg(math.acos(clamped))
end

function WheatScatterValidation.isWithinSpacing(
	candidate: Vector3,
	placed: { Vector3 },
	minimumSpacing: number
): boolean
	for _, existing in placed do
		local delta = Vector2.new(candidate.X - existing.X, candidate.Z - existing.Z)
		if delta.Magnitude < minimumSpacing then
			return false
		end
	end
	return true
end

function WheatScatterValidation.validateGroundSamples(
	centerSample: GroundSample?,
	samples: { GroundSample? },
	config: ValidationConfig
): boolean
	if centerSample == nil then
		return false
	end

	if WheatScatterValidation.angleFromUp(centerSample.normal) > config.MaxSlopeDegrees then
		return false
	end

	local centerY = centerSample.position.Y
	local centerNormal = centerSample.normal

	for _, sample in samples do
		if sample == nil then
			if config.RequireAllSamplesToHit then
				return false
			end
			continue
		end

		if math.abs(sample.position.Y - centerY) > config.MaxHeightDifference then
			return false
		end

		if WheatScatterValidation.angleBetweenNormals(centerNormal, sample.normal) > config.MaxNormalDifferenceDegrees then
			return false
		end
	end

	return true
end

function WheatScatterValidation.buildSampleOffsets(radius: number): { Vector3 }
	return {
		Vector3.zero,
		Vector3.new(radius, 0, 0),
		Vector3.new(-radius, 0, 0),
		Vector3.new(0, 0, radius),
		Vector3.new(0, 0, -radius),
		Vector3.new(radius * 0.707, 0, radius * 0.707),
		Vector3.new(-radius * 0.707, 0, radius * 0.707),
	}
end

return WheatScatterValidation
