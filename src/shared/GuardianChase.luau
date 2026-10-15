--!strict
-- Pure pursuit, threat, and runway limits. No services and no resource rolls.
local Rarities = require(script.Parent.RarityDefinitions)

local Chase = {}

export type Profile = {
	Speed: number,
	Duration: number,
	Aggression: number,
	Threat: number,
	Alert: string?,
}

export type FloorSpan = {
	center: Vector3,
	axis: Vector3,
	longHalf: number,
	lateral: Vector3,
	lateralHalf: number,
	y: number,
}

export type Box = { Center: Vector3, Size: Vector3 }

export type Runway = {
	origin: Vector3,
	axis: Vector3,
	lateral: Vector3,
	-- Along-axis safe boundary: anything with along < entrance is inside the safe base zone.
	entrance: number,
	minAlong: number,
	maxAlong: number,
	halfWidth: number,
	surfaceY: number,
}

export type HazardShape = {
	Kind: string,
	Warning: number,
	Active: number,
	Length: number,
	Width: number,
	Front: number,
	Radius: number?,
}

export type Candidate = {
	Player: any,
	Rarity: string,
	StolenAt: number,
	Distance: number,
	Reachable: boolean,
	Initial: boolean,
	Position: Vector3,
}

-- Pursuit now lasts the whole runway, so speed and aggression scale gently: high rarities
-- already carry heavier base slowdown plus curses. Duration is the old encounter scale,
-- kept for callers; it no longer ends a valid chase.
Chase.Profiles = {
	Common = { Speed = 1.00, Duration = 1.00, Aggression = 1.00, Threat = 10 },
	Uncommon = { Speed = 1.00, Duration = 1.05, Aggression = 1.00, Threat = 15 },
	Rare = { Speed = 1.01, Duration = 1.10, Aggression = 1.05, Threat = 20 },
	Epic = { Speed = 1.02, Duration = 1.15, Aggression = 1.10, Threat = 30 },
	Legendary = { Speed = 1.03, Duration = 1.25, Aggression = 1.15, Threat = 45 },
	Mythic = { Speed = 1.05, Duration = 1.35, Aggression = 1.25, Threat = 60 },
	Cosmic = { Speed = 1.06, Duration = 1.45, Aggression = 1.30, Threat = 80 },
	Secret = {
		Speed = 1.07, Duration = 1.60, Aggression = 1.40, Threat = 110,
		Alert = "SECRET STOLEN!\nTHE GUARDIAN IS HUNTING YOU",
	},
	Eternal = {
		Speed = 1.08, Duration = 1.80, Aggression = 1.50, Threat = 160,
		Alert = "ETERNAL RESOURCE STOLEN!\nESCAPE THE GUARDIAN!",
	},
	Divine = {
		Speed = 1.09, Duration = 2.00, Aggression = 1.60, Threat = 220,
		Alert = "DIVINE STOLEN!\nTHE GUARDIAN WILL NOT GIVE UP EASILY",
	},
} :: { [string]: Profile }

-- Player walk is 16; guardians stay faster than any carrier, so escape depends on
-- dodging fair telegraphs rather than outrunning. Telegraph length is not scaled down.
Chase.Timing = {
	BasePursuitSpeed = 18,
	Wake = 0.6,
	BasePursuitDuration = 14,
	AttackDelay = 2.6,
	RecoveryFloor = 2.5,
	-- Return failsafe: RETURNING ends in SLEEPING at this deadline even if travel stalls.
	ReturnDuration = 90,
	ReturnSpeed = 32,
	DisengageHold = 0.6,
	EntranceStandoff = 10,
	HazardPad = 4,
	-- Logged safety cap, not a chase timer: ~3x the slowest Volcano-to-entrance walk.
	SafetyCap = 600,
	StuckWindow = 8,
	StuckDistance = 4,
	Spacing = 24,
	AttackStagger = 1.5,
	CrowdRadius = 120,
	DodgeSafety = 0.75,
	CursedDodgeSafety = 0.6,
	TargetUpdate = 0.5,
	SwitchThreshold = 25,
	InitialLock = 1.25,
	OverrideMargin = 80,
	InitialBonus = 100,
	ProximityBonus = 20,
	ProximityRange = 90,
	RecentBonus = 30,
	RecentWindow = 2.5,
	AttackCommit = 32,
	SafeMargin = 18,
	BasePad = 4,
}

function Chase.profile(rarity: string): Profile?
	return Chase.Profiles[rarity]
end

function Chase.stronger(current: string?, incoming: string): string?
	local nextProfile = Chase.Profiles[incoming]
	if not nextProfile then
		return nil
	end
	if not current or nextProfile.Threat > Chase.Profiles[current].Threat then
		return incoming
	end
	return current
end

function Chase.speed(rarity: string): number
	local profile = Chase.Profiles[rarity]
	return if profile then Chase.Timing.BasePursuitSpeed * profile.Speed else Chase.Timing.BasePursuitSpeed
end

function Chase.duration(rarity: string): number
	local profile = Chase.Profiles[rarity]
	return if profile then Chase.Timing.BasePursuitDuration * profile.Duration else Chase.Timing.BasePursuitDuration
end

function Chase.attackDelay(rarity: string): number
	local profile = Chase.Profiles[rarity]
	local aggression = if profile then profile.Aggression else 1
	return Chase.Timing.AttackDelay / math.max(aggression, 1)
end

function Chase.recovery(baseCooldown: number, rarity: string): number
	local profile = Chase.Profiles[rarity]
	local aggression = if profile then profile.Aggression else 1
	return math.max(Chase.Timing.RecoveryFloor, baseCooldown / math.max(aggression, 1))
end

function Chase.axes(surface: { u: Vector3, uHalf: number, v: Vector3, vHalf: number }): (Vector3, number, Vector3, number)
	local axis, longHalf = surface.u, surface.uHalf
	local lateral, lateralHalf = surface.v, surface.vHalf
	if longHalf < lateralHalf then
		axis, longHalf, lateral, lateralHalf = lateral, lateralHalf, axis, longHalf
	end
	if axis:Dot(Vector3.xAxis) < 0 then
		axis = -axis
	end
	lateral = axis:Cross(Vector3.yAxis)
	if lateral.Magnitude < 1e-4 then
		lateral = Vector3.zAxis
	end
	return axis.Unit, longHalf, lateral.Unit, lateralHalf
end

local function halfExtent(axis: Vector3, size: Vector3): number
	return math.abs(axis.X) * size.X / 2 + math.abs(axis.Y) * size.Y / 2 + math.abs(axis.Z) * size.Z / 2
end

-- The safe entrance is the base-side edge of the first field floor (verified to match the
-- base containment wall opening). An explicit marker along-coordinate overrides it.
-- A base box reaching past that edge pushes the entrance out by margin.
function Chase.runway(floors: { FloorSpan }, bases: { Box }, margin: number, entranceOverride: number?): Runway?
	local first = floors[1]
	if not first then
		return nil
	end
	local origin = first.center
	local axis = first.axis.Unit
	local lateral = first.lateral.Unit
	local minAlong, maxAlong = math.huge, -math.huge
	local halfWidth = math.huge
	for _, floor in floors do
		local along = (floor.center - origin):Dot(axis)
		minAlong = math.min(minAlong, along - floor.longHalf)
		maxAlong = math.max(maxAlong, along + floor.longHalf)
		halfWidth = math.min(halfWidth, floor.lateralHalf)
	end
	local entrance = entranceOverride or minAlong
	local midpoint = (minAlong + maxAlong) / 2
	for _, box in bases do
		local along = (box.Center - origin):Dot(axis)
		local hi = along + halfExtent(axis, box.Size)
		if hi < midpoint and hi + margin > entrance then
			entrance = hi + margin
		end
	end
	return {
		origin = origin,
		axis = axis,
		lateral = lateral,
		entrance = entrance,
		minAlong = entrance + Chase.Timing.EntranceStandoff,
		maxAlong = maxAlong,
		halfWidth = math.max(8, halfWidth - 10),
		surfaceY = first.y,
	}
end

function Chase.isSafe(runway: Runway, point: Vector3): boolean
	return (point - runway.origin):Dot(runway.axis) < runway.entrance
end

function Chase.along(runway: Runway, point: Vector3): number
	return (point - runway.origin):Dot(runway.axis)
end

function Chase.insideBox(point: Vector3, box: Box, pad: number): boolean
	local delta = point - box.Center
	return math.abs(delta.X) <= box.Size.X / 2 + pad
		and math.abs(delta.Y) <= box.Size.Y / 2 + pad + 8
		and math.abs(delta.Z) <= box.Size.Z / 2 + pad
end

function Chase.inBases(point: Vector3, bases: { Box }, pad: number): boolean
	for _, box in bases do
		if Chase.insideBox(point, box, pad) then
			return true
		end
	end
	return false
end

function Chase.clamp(runway: Runway, point: Vector3): Vector3
	local along = math.clamp(Chase.along(runway, point), runway.minAlong, runway.maxAlong)
	local side = (point - runway.origin):Dot(runway.lateral)
	side = math.clamp(side, -runway.halfWidth, runway.halfWidth)
	return runway.origin + runway.axis * along + runway.lateral * side + Vector3.yAxis * (point.Y - runway.origin.Y)
end

function Chase.onRunway(runway: Runway, point: Vector3, slack: number): boolean
	local along = Chase.along(runway, point)
	local side = math.abs((point - runway.origin):Dot(runway.lateral))
	return along >= runway.minAlong - slack
		and along <= runway.maxAlong + slack
		and side <= runway.halfWidth + 16 + slack
end

function Chase.stepToward(from: Vector3, goal: Vector3, speed: number, dt: number, runway: Runway): Vector3
	local dest = Chase.clamp(runway, goal)
	local flatFrom = Vector3.new(from.X, dest.Y, from.Z)
	local delta = dest - flatFrom
	local distance = delta.Magnitude
	if distance < 1e-3 then
		return Vector3.new(dest.X, from.Y, dest.Z)
	end
	local travel = math.min(distance, math.max(speed, 0) * math.clamp(dt, 0, 0.1))
	local nextPoint = Chase.clamp(runway, flatFrom + delta.Unit * travel)
	return Vector3.new(nextPoint.X, from.Y, nextPoint.Z)
end

function Chase.attackFrame(runway: Runway, fromPos: Vector3, toPos: Vector3): CFrame
	local axis = runway.axis
	if (toPos - fromPos):Dot(axis) < 0 then
		axis = -axis
	end
	local lateral = axis:Cross(Vector3.yAxis)
	if lateral.Magnitude < 1e-4 then
		lateral = runway.lateral
	end
	lateral = lateral.Unit
	local center = Chase.clamp(runway, fromPos)
	center = Vector3.new(center.X, runway.surfaceY, center.Z)
	return CFrame.fromMatrix(center, axis, Vector3.yAxis, lateral)
end

-- Along-runway reach of a hazard footprint from its frame center.
function Chase.footprintHalf(shape: HazardShape): number
	if shape.Kind == "Shockwave" then
		return shape.Radius or 0
	end
	return shape.Length / 2
end

-- Closest along-coordinate a hazard center may use so no footprint reaches the safe zone.
function Chase.attackMin(runway: Runway, shape: HazardShape): number
	return runway.entrance + Chase.footprintHalf(shape) + Chase.Timing.HazardPad
end

-- Seconds a target at a frame-local position has before the hazard can reach it.
function Chase.dodgeTime(shape: HazardShape, localPos: Vector3): number
	if shape.Kind == "Charge" or shape.Kind == "Lunge" then
		local start = -shape.Length / 2 + shape.Front / 2
		local travel = shape.Length - shape.Front
		local alpha = if travel > 0 then math.clamp((localPos.X - shape.Front / 2 - start) / travel, 0, 1) else 0
		return shape.Warning + alpha * shape.Active
	end
	return shape.Warning
end

-- Distance to leave the footprint (nil when already outside). Lanes are escaped
-- sideways along frame Z toward escapeSign; shockwaves radially.
function Chase.exitDistance(shape: HazardShape, localPos: Vector3, escapeSign: number): number?
	if shape.Kind == "Shockwave" then
		local radius = shape.Radius or 0
		local r = Vector3.new(localPos.X, 0, localPos.Z).Magnitude
		return if r <= radius then radius - r else nil
	end
	if math.abs(localPos.X) > shape.Length / 2 or math.abs(localPos.Z) > shape.Width / 2 then
		return nil
	end
	return shape.Width / 2 - localPos.Z * escapeSign
end

-- Builds a warning-locked frame that covers the target but always leaves an escape the
-- target can make at targetSpeed * safety, never reaches the safe zone, and stays on the
-- runway. Returns nil when no such frame exists (the guardian keeps pursuing instead).
function Chase.fairFrame(runway: Runway, shape: HazardShape, fromPos: Vector3, targetPos: Vector3, targetSpeed: number, safety: number): (CFrame?, number?)
	local base = Chase.attackFrame(runway, fromPos, targetPos)
	local minCenter = Chase.attackMin(runway, shape)
	if minCenter > runway.maxAlong then
		return nil
	end
	-- Frames may centre up to the floor edge (halfWidth + 10) so wall-huggers are not immune;
	-- footprint beyond the corridor walls is harmless.
	local sideLimit = runway.halfWidth + 10
	local function rebuild(center: Vector3): CFrame
		local along = math.clamp(Chase.along(runway, center), minCenter, runway.maxAlong)
		local side = math.clamp((center - runway.origin):Dot(runway.lateral), -sideLimit, sideLimit)
		local point = runway.origin + runway.axis * along + runway.lateral * side
		return CFrame.fromMatrix(Vector3.new(point.X, runway.surfaceY, point.Z), base.XVector, Vector3.yAxis, base.ZVector)
	end
	local speed = math.max(targetSpeed, 0) * safety
	-- Accept only frames whose escape fits the budget and whose exit point lies inside the walls.
	local function fair(frame: CFrame, sign: number): boolean
		local localPos = frame:PointToObjectSpace(targetPos)
		local exit = Chase.exitDistance(shape, localPos, sign)
		if exit == nil or exit > speed * Chase.dodgeTime(shape, localPos) + 1e-3 then
			return false
		end
		local flat = Vector3.new(localPos.X, 0, localPos.Z)
		local outward = if shape.Kind ~= "Shockwave" then Vector3.new(0, 0, sign)
			elseif flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
		local exitPoint = frame:PointToWorldSpace(flat + outward * (exit + 1))
		return math.abs((exitPoint - runway.origin):Dot(runway.lateral)) <= runway.halfWidth + 6
	end
	local frame = rebuild(base.Position)
	local localPos = frame:PointToObjectSpace(targetPos)
	if Chase.exitDistance(shape, localPos, 1) == nil then
		return nil
	end
	local allowed = speed * Chase.dodgeTime(shape, localPos)
	if shape.Kind == "Shockwave" then
		if fair(frame, 1) then
			return frame, 1
		end
		local flat = Vector3.new(localPos.X, 0, localPos.Z)
		local current = frame:VectorToWorldSpace(if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis)
		local offset = math.max((shape.Radius or 0) - allowed, 0)
		for _, outward in { current, -runway.axis, runway.axis } do
			local candidate = rebuild(targetPos - outward * offset)
			if fair(candidate, 1) then
				return candidate, 1
			end
		end
		return nil
	end
	local nearest = if localPos.Z >= 0 then 1 else -1
	for _, sign in { nearest, -nearest } do
		if fair(frame, sign) then
			return frame, sign
		end
		local wanted = sign * (shape.Width / 2 - allowed)
		local candidate = rebuild(frame:PointToWorldSpace(Vector3.new(0, 0, localPos.Z - wanted)))
		if fair(candidate, sign) then
			return candidate, sign
		end
	end
	return nil
end

-- Pushes a guardian away from nearby guardians so overlapping attacks stay readable.
-- bias breaks exact overlaps deterministically.
function Chase.separate(position: Vector3, others: { Vector3 }, spacing: number, runway: Runway, bias: number): Vector3
	local push = Vector3.zero
	for _, other in others do
		local delta = Vector3.new(position.X - other.X, 0, position.Z - other.Z)
		local distance = delta.Magnitude
		if distance < spacing then
			local direction = if distance > 1e-3 then delta.Unit else runway.lateral * (if bias >= 0 then 1 else -1)
			push += direction * (spacing - distance) * 0.5
		end
	end
	if push.Magnitude < 1e-4 then
		return position
	end
	local moved = Chase.clamp(runway, position + push)
	return Vector3.new(moved.X, position.Y, moved.Z)
end

function Chase.horizontal(a: Vector3, b: Vector3): number
	local delta = a - b
	return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function score(candidate: Candidate, now: number, lockUntil: number): number?
	local profile = Chase.Profiles[candidate.Rarity]
	if not profile or not candidate.Reachable then
		return nil
	end
	local proximity = Chase.Timing.ProximityBonus * (1 - math.clamp(candidate.Distance / Chase.Timing.ProximityRange, 0, 1))
	local recent = if now - candidate.StolenAt <= Chase.Timing.RecentWindow then Chase.Timing.RecentBonus else 0
	local initial = if candidate.Initial and now < lockUntil then Chase.Timing.InitialBonus else 0
	return profile.Threat + proximity + recent + initial
end

function Chase.select(candidates: { Candidate }, current: Candidate?, now: number, lockUntil: number): Candidate?
	local best: Candidate? = nil
	local bestScore = -math.huge
	local currentFresh: Candidate? = nil
	local currentScore: number? = nil
	for _, candidate in candidates do
		local value = score(candidate, now, lockUntil)
		if value then
			if value > bestScore then
				best, bestScore = candidate, value
			end
			if current and candidate.Player == current.Player then
				currentFresh, currentScore = candidate, value
			end
		end
	end
	if not best then
		return nil
	end
	if not currentFresh or not currentScore or not current then
		return best
	end
	if best.Player == currentFresh.Player then
		return currentFresh
	end
	if now < lockUntil and currentFresh.Initial then
		local rawBest = Chase.Profiles[best.Rarity].Threat
		local rawCurrent = Chase.Profiles[currentFresh.Rarity].Threat
		if rawBest < rawCurrent + Chase.Timing.OverrideMargin then
			return currentFresh
		end
	end
	if bestScore < currentScore + Chase.Timing.SwitchThreshold then
		return currentFresh
	end
	return best
end

function Chase.validate(): { string }
	local errors = {}
	local timing = Chase.Timing
	for _, key in { "BasePursuitSpeed", "Wake", "BasePursuitDuration", "AttackDelay", "ReturnDuration", "ReturnSpeed", "TargetUpdate", "AttackCommit", "SafeMargin",
		"DisengageHold", "EntranceStandoff", "HazardPad", "SafetyCap", "StuckWindow", "StuckDistance", "Spacing", "AttackStagger", "CrowdRadius",
		"DodgeSafety", "CursedDodgeSafety" } do
		local value = (timing :: any)[key]
		if type(value) ~= "number" or value ~= value or value <= 0 or value >= math.huge then
			table.insert(errors, "Invalid chase timing: " .. key)
		end
	end
	if timing.Wake > 0.8 or timing.Wake < 0.5 then
		table.insert(errors, "Wake duration left the 0.5-0.8 second band")
	end
	if timing.BasePursuitSpeed * (Chase.Profiles.Divine and Chase.Profiles.Divine.Speed or 1) >= 28 then
		table.insert(errors, "Divine pursuit speed is too high to remain escapable")
	end
	if timing.DodgeSafety > 1 or timing.CursedDodgeSafety > timing.DodgeSafety then
		table.insert(errors, "Dodge safety factors must not exceed real movement")
	end
	if timing.ReturnSpeed <= timing.BasePursuitSpeed then
		table.insert(errors, "Return travel must be faster than pursuit")
	end
	if timing.SafetyCap < 120 then
		table.insert(errors, "Safety cap is shorter than a full-runway escape")
	end
	for _, rarity in Rarities.Order do
		local profile = Chase.Profiles[rarity]
		if not profile then
			table.insert(errors, "Missing chase profile: " .. rarity)
			continue
		end
		if profile.Speed < 1 or profile.Duration < 1 or profile.Aggression < 1 or profile.Threat <= 0 then
			table.insert(errors, "Invalid chase profile: " .. rarity)
		end
	end
	if Chase.Profiles.Divine.Threat <= Chase.Profiles.Secret.Threat then
		table.insert(errors, "Divine threat must outrank Secret")
	end
	return errors
end

return Chase
