--!strict

--[[
	Pure region sampling and placement validation helpers.
	No Roblox service access; injectable Random for deterministic tests.
]]

local RegionSamplingCalculator = {}

export type ExclusionVolumes = {
	bankZoneCFrame: CFrame?,
	bankZoneSize: Vector3?,
	wateringHoleCFrame: CFrame?,
	wateringHoleSize: Vector3?,
	zoneBoundaryCFrame: CFrame?,
	zoneBoundarySize: Vector3?,
	hubCenter: Vector3,
	hubSafeRadius: number,
	safeZoneExclusionRadius: number,
	landmarkExclusionRadius: number,
	basePositions: { Vector3 },
}

function RegionSamplingCalculator.slopeDegrees(normal: Vector3): number
	local clamped = math.clamp(normal.Unit:Dot(Vector3.yAxis), -1, 1)
	return math.deg(math.acos(clamped))
end

function RegionSamplingCalculator.horizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

function RegionSamplingCalculator.isWithinSpacing(
	candidate: Vector3,
	placed: { Vector3 },
	minimumSpacing: number
): boolean
	for _, existing in placed do
		if RegionSamplingCalculator.horizontalDistance(candidate, existing) < minimumSpacing then
			return false
		end
	end
	return true
end

function RegionSamplingCalculator.pointInOrientedBox(
	worldPoint: Vector3,
	boxCFrame: CFrame,
	boxSize: Vector3
): boolean
	local localPoint = boxCFrame:PointToObjectSpace(worldPoint)
	local half = boxSize * 0.5
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

-- ZoneBoundary vertical extents are visualization volumes; gameplay uses XZ membership.
function RegionSamplingCalculator.pointInOrientedBoxXZ(
	worldPoint: Vector3,
	boxCFrame: CFrame,
	boxSize: Vector3
): boolean
	local localPoint = boxCFrame:PointToObjectSpace(worldPoint)
	local half = boxSize * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
end

function RegionSamplingCalculator.sampleLocalPointInRegion(regionSize: Vector3, rng: Random): Vector3
	return Vector3.new(
		rng:NextNumber(-regionSize.X / 2, regionSize.X / 2),
		regionSize.Y / 2,
		rng:NextNumber(-regionSize.Z / 2, regionSize.Z / 2)
	)
end

function RegionSamplingCalculator.localPointToWorld(regionCFrame: CFrame, localPoint: Vector3): Vector3
	return regionCFrame:PointToWorldSpace(localPoint)
end

function RegionSamplingCalculator.isLocalPointInsideHalfExtents(localPoint: Vector3, regionSize: Vector3): boolean
	local halfX = regionSize.X / 2
	local halfZ = regionSize.Z / 2
	return math.abs(localPoint.X) <= halfX + 1e-4 and math.abs(localPoint.Z) <= halfZ + 1e-4
end

function RegionSamplingCalculator.regionArea(size: Vector3): number
	return math.max(size.X, 0) * math.max(size.Z, 0)
end

function RegionSamplingCalculator.selectAreaWeightedIndex(areas: { number }, rng: Random): number?
	local total = 0
	for _, area in areas do
		total += area
	end
	if total <= 0 or #areas == 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local cumulative = 0
	for index, area in areas do
		cumulative += area
		if roll <= cumulative then
			return index
		end
	end
	return #areas
end

function RegionSamplingCalculator.deathLossAmount(stackAmount: number, lossFraction: number): number
	if stackAmount <= 0 then
		return 0
	end
	return math.floor(stackAmount * lossFraction)
end

function RegionSamplingCalculator.passesExclusions(
	position: Vector3,
	exclusions: ExclusionVolumes,
	requireInsideZoneBoundary: boolean
): boolean
	if exclusions.bankZoneCFrame and exclusions.bankZoneSize then
		local expanded = exclusions.bankZoneSize + Vector3.new(
			exclusions.safeZoneExclusionRadius * 2,
			exclusions.bankZoneSize.Y,
			exclusions.safeZoneExclusionRadius * 2
		)
		if RegionSamplingCalculator.pointInOrientedBox(position, exclusions.bankZoneCFrame, expanded) then
			return false
		end
	end

	local hubDistance = RegionSamplingCalculator.horizontalDistance(position, exclusions.hubCenter)
	if hubDistance < exclusions.hubSafeRadius then
		return false
	end

	for _, basePosition in exclusions.basePositions do
		if RegionSamplingCalculator.horizontalDistance(position, basePosition) < exclusions.safeZoneExclusionRadius then
			return false
		end
	end

	if exclusions.wateringHoleCFrame and exclusions.wateringHoleSize then
		local landmarkExpanded = exclusions.wateringHoleSize + Vector3.new(
			exclusions.landmarkExclusionRadius * 2,
			exclusions.wateringHoleSize.Y,
			exclusions.landmarkExclusionRadius * 2
		)
		if RegionSamplingCalculator.pointInOrientedBox(position, exclusions.wateringHoleCFrame, landmarkExpanded) then
			return false
		end
	end

	if requireInsideZoneBoundary then
		if exclusions.zoneBoundaryCFrame and exclusions.zoneBoundarySize then
			if not RegionSamplingCalculator.pointInOrientedBoxXZ(
				position,
				exclusions.zoneBoundaryCFrame,
				exclusions.zoneBoundarySize
			) then
				return false
			end
		else
			-- Radial fallback when ZoneBoundary part is unavailable.
			local distance = RegionSamplingCalculator.horizontalDistance(position, exclusions.hubCenter)
			if distance < exclusions.hubSafeRadius then
				return false
			end
		end
	end

	return true
end

function RegionSamplingCalculator.alignCFrame(position: Vector3, normal: Vector3, yawRadians: number): CFrame
	local up = normal.Unit
	local reference = if math.abs(up:Dot(Vector3.yAxis)) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = up:Cross(reference).Unit
	local forward = right:Cross(up).Unit
	local base = CFrame.fromMatrix(position, right, up, -forward)
	return base * CFrame.Angles(0, yawRadians, 0)
end

return RegionSamplingCalculator
