--!strict

--[[
	Pure placement helpers for procedural environment scatter.
	No Roblox service access; independently testable.
]]

local EnvironmentScatterValidation = {}

export type VolumeKind = "circle" | "box"

export type BoundaryVolume = {
	kind: VolumeKind,
	center: Vector3,
	radius: number?,
	cframe: CFrame?,
	size: Vector3?,
}

export type GroundSample = {
	position: Vector3,
	normal: Vector3,
	material: Enum.Material?,
}

export type RejectCounts = {
	outsideBiome: number,
	savannahInterior: number,
	transition: number,
	density: number,
	noTerrain: number,
	water: number,
	slope: number,
	exclusion: number,
	spacing: number,
	overlap: number,
	gameplay: number,
	invalidRegion: number,
}

export type CategoryId = "Vegetation" | "Rocks" | "SetPieces"

function EnvironmentScatterValidation.createRejectCounts(): RejectCounts
	return {
		outsideBiome = 0,
		savannahInterior = 0,
		transition = 0,
		density = 0,
		noTerrain = 0,
		water = 0,
		slope = 0,
		exclusion = 0,
		spacing = 0,
		overlap = 0,
		gameplay = 0,
		invalidRegion = 0,
	}
end

function EnvironmentScatterValidation.totalRejected(counts: RejectCounts): number
	return counts.outsideBiome
		+ counts.savannahInterior
		+ counts.transition
		+ counts.density
		+ counts.noTerrain
		+ counts.water
		+ counts.slope
		+ counts.exclusion
		+ counts.spacing
		+ counts.overlap
		+ counts.gameplay
		+ counts.invalidRegion
end

function EnvironmentScatterValidation.slopeDegrees(normal: Vector3): number
	local clamped = math.clamp(normal.Unit:Dot(Vector3.yAxis), -1, 1)
	return math.deg(math.acos(clamped))
end

function EnvironmentScatterValidation.horizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

function EnvironmentScatterValidation.isWithinSpacing(
	candidate: Vector3,
	placed: { Vector3 },
	minimumSpacing: number
): boolean
	for _, existing in placed do
		if EnvironmentScatterValidation.horizontalDistance(candidate, existing) < minimumSpacing then
			return false
		end
	end
	return true
end

function EnvironmentScatterValidation.pointInOrientedBoxXZ(
	worldPoint: Vector3,
	boxCFrame: CFrame,
	boxSize: Vector3
): boolean
	local localPoint = boxCFrame:PointToObjectSpace(worldPoint)
	local half = boxSize * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
end

function EnvironmentScatterValidation.distanceOutsideBoxXZ(
	worldPoint: Vector3,
	boxCFrame: CFrame,
	boxSize: Vector3
): number
	local localPoint = boxCFrame:PointToObjectSpace(worldPoint)
	local halfX = boxSize.X * 0.5
	local halfZ = boxSize.Z * 0.5
	local dx = math.abs(localPoint.X) - halfX
	local dz = math.abs(localPoint.Z) - halfZ
	if dx <= 0 and dz <= 0 then
		return -math.min(-dx, -dz)
	end
	local outsideX = math.max(dx, 0)
	local outsideZ = math.max(dz, 0)
	return math.sqrt(outsideX * outsideX + outsideZ * outsideZ)
end

function EnvironmentScatterValidation.contains(volume: BoundaryVolume, worldPoint: Vector3): boolean
	if volume.kind == "circle" then
		local radius = volume.radius or 0
		return EnvironmentScatterValidation.horizontalDistance(worldPoint, volume.center) <= radius
	end
	if volume.cframe == nil or volume.size == nil then
		return false
	end
	return EnvironmentScatterValidation.pointInOrientedBoxXZ(worldPoint, volume.cframe, volume.size)
end

function EnvironmentScatterValidation.signedDistanceOutside(volume: BoundaryVolume, worldPoint: Vector3): number
	if volume.kind == "circle" then
		local radius = volume.radius or 0
		return EnvironmentScatterValidation.horizontalDistance(worldPoint, volume.center) - radius
	end
	if volume.cframe == nil or volume.size == nil then
		return math.huge
	end
	return EnvironmentScatterValidation.distanceOutsideBoxXZ(worldPoint, volume.cframe, volume.size)
end

function EnvironmentScatterValidation.isInsideRainforest(
	worldPoint: Vector3,
	outer: BoundaryVolume,
	inner: BoundaryVolume
): boolean
	return EnvironmentScatterValidation.contains(outer, worldPoint)
		and not EnvironmentScatterValidation.contains(inner, worldPoint)
end

function EnvironmentScatterValidation.biomeDepthFactor(
	distanceFromSavannah: number,
	sparseDistance: number,
	moderateDistance: number
): number
	if distanceFromSavannah <= 0 then
		return 0
	end
	if distanceFromSavannah < sparseDistance then
		return 0.18
	end
	if distanceFromSavannah < moderateDistance then
		local alpha = (distanceFromSavannah - sparseDistance) / math.max(moderateDistance - sparseDistance, 0.001)
		return 0.18 + alpha * 0.47
	end
	local extra = math.clamp((distanceFromSavannah - moderateDistance) / 80, 0, 1)
	return 0.65 + extra * 0.35
end

function EnvironmentScatterValidation.densityNoise(x: number, z: number, seed: number, frequency: number): number
	local n1 = math.noise(x * frequency, seed * 0.013, z * frequency)
	local n2 = math.noise(x * frequency * 2.1, seed * 0.029 + 17.3, z * frequency * 2.1) * 0.5
	local n3 = math.noise(x * frequency * 4.3, seed * 0.047 + 41.8, z * frequency * 4.3) * 0.25
	local combined = (n1 + n2 + n3) / 1.75
	return math.clamp((combined + 1) * 0.5, 0, 1)
end

function EnvironmentScatterValidation.passesDensity(
	noiseValue: number,
	depthFactor: number,
	threshold: number
): boolean
	-- Deeper rainforest lowers the noise requirement; the savannah edge stays sparse.
	local required = threshold * (1.05 - 0.55 * math.clamp(depthFactor, 0, 1))
	return noiseValue >= required
end

function EnvironmentScatterValidation.isGameplayResourceName(name: string): boolean
	local blocked = {
		AncientBush = true,
		FungalGrowth = true,
		InsectNest = true,
		CrystalOutcrop = true,
		CrystalEruptionNode = true,
		TerritorialRaptor = true,
	}
	return blocked[name] == true
end

function EnvironmentScatterValidation.sampleAnnulusPoint(
	center: Vector3,
	innerRadius: number,
	outerRadius: number,
	rng: Random
): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local innerSq = innerRadius * innerRadius
	local outerSq = outerRadius * outerRadius
	local radius = math.sqrt(rng:NextNumber(innerSq, outerSq))
	return Vector3.new(center.X + math.cos(angle) * radius, center.Y, center.Z + math.sin(angle) * radius)
end

return EnvironmentScatterValidation
