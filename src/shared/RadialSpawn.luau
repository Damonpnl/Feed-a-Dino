--!strict
-- Pure guardian-territory geometry. No services: the caller supplies the measured floor
-- span, a probe for live geometry and the random source.
local Radial = {}

export type Span = { center: Vector3, axis: Vector3, lateral: Vector3, longHalf: number, lateralHalf: number, y: number }
export type Row = {
	HomeAlong: number, HomeLateral: number, Facing: string, MinRadius: number, MaxRadius: number,
	RearDepth: number, EndMargin: number, Clearance: number, Grid: number, LaneSide: number, LaneWidth: number, LaneMargin: number,
}
-- Along/lateral are floor-local studs from the floor centre; +along points away from safety.
export type Region = {
	Center: Vector3, Axis: Vector3, Lateral: Vector3, Y: number,
	Home: Vector3, HomeAlong: number, HomeLateral: number, Facing: Vector3,
	AlongMin: number, AlongMax: number, LatMin: number, LatMax: number,
	LaneMin: number?, LaneMax: number?, MinRadius: number, MaxRadius: number,
}

function Radial.region(row: Row, span: Span): Region
	local half = span.lateralHalf
	local laneWidth = if row.LaneSide == 0 then 0 else math.clamp(row.LaneWidth, 0, half * 2)
	-- Territory is the floor width minus the lane strip on LaneSide.
	local low, high = -half, half
	local laneMin, laneMax = nil, nil
	if row.LaneSide == 1 then high, laneMin, laneMax = half - laneWidth, half - laneWidth, half
	elseif row.LaneSide == -1 then low, laneMin, laneMax = -half + laneWidth, -half, -half + laneWidth end
	local homeAlong = -span.longHalf + row.HomeAlong * span.longHalf * 2
	local homeLateral = (low + high) / 2 + row.HomeLateral
	local flatCenter = Vector3.new(span.center.X, span.y, span.center.Z)
	local home = flatCenter + span.axis * homeAlong + span.lateral * homeLateral
	local facing = if row.Facing == "Far" then span.axis else -span.axis
	local edge = row.Clearance
	return {
		Center = flatCenter, Axis = span.axis, Lateral = span.lateral, Y = span.y,
		Home = home, HomeAlong = homeAlong, HomeLateral = homeLateral, Facing = facing,
		AlongMin = -span.longHalf + math.max(row.EndMargin, edge),
		AlongMax = math.min(span.longHalf - math.max(row.EndMargin, edge), homeAlong + row.RearDepth),
		LatMin = low + (if row.LaneSide == -1 then row.LaneMargin else edge),
		LatMax = high - (if row.LaneSide == 1 then row.LaneMargin else edge),
		LaneMin = laneMin, LaneMax = laneMax, MinRadius = row.MinRadius, MaxRadius = row.MaxRadius,
	}
end

function Radial.localOf(region: Region, point: Vector3): (number, number)
	local offset = point - region.Center
	return offset:Dot(region.Axis), offset:Dot(region.Lateral)
end

function Radial.distance(region: Region, point: Vector3): number
	local offset = point - region.Home
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

-- Territory rule without live geometry: annulus, biome ends, floor edges and lane.
function Radial.contains(region: Region, point: Vector3): boolean
	local along, lateral = Radial.localOf(region, point)
	local radius = Radial.distance(region, point)
	return radius >= region.MinRadius and radius <= region.MaxRadius
		and along >= region.AlongMin and along <= region.AlongMax
		and lateral >= region.LatMin and lateral <= region.LatMax
end

function Radial.inLane(region: Region, point: Vector3): boolean
	if not region.LaneMin or not region.LaneMax then return false end
	local _, lateral = Radial.localOf(region, point)
	return lateral >= region.LaneMin and lateral <= region.LaneMax
end

-- Grid of territory points centred on the home. probe(point) returns the validated ground
-- point or nil (walls, props, hazards, missing floor); it is the only live-geometry input.
function Radial.candidates(region: Region, step: number, probe: (Vector3) -> Vector3?): { Vector3 }
	local list = {}
	local reach = math.ceil(region.MaxRadius / step)
	for i = -reach, reach do
		for j = -reach, reach do
			local point = region.Home + region.Axis * (i * step) + region.Lateral * (j * step)
			if Radial.contains(region, point) then
				local ground = probe(point)
				if ground then table.insert(list, ground) end
			end
		end
	end
	return list
end

local function nearest(point: Vector3, occupied: { Vector3 }): number
	local best = math.huge
	for _, other in occupied do
		best = math.min(best, Vector3.new(point.X - other.X, 0, point.Z - other.Z).Magnitude)
	end
	return best
end

-- Uniform draw among candidates at least `separation` from every occupied point. If the
-- territory is saturated, the candidate farthest from its neighbours is used instead.
function Radial.pick(candidates: { Vector3 }, occupied: { Vector3 }, separation: number, nextNumber: () -> number): Vector3?
	local valid = {}
	local fallback, fallbackGap = nil, -math.huge
	for _, point in candidates do
		local gap = nearest(point, occupied)
		if gap >= separation then table.insert(valid, point)
		elseif gap > fallbackGap then fallback, fallbackGap = point, gap end
	end
	if #valid > 0 then return valid[math.clamp(math.floor(nextNumber() * #valid) + 1, 1, #valid)] end
	return fallback
end

return Radial
