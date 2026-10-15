-- Deterministic full-runway simulations over the measured corridor (no Workspace access).
-- These model a player who reacts after 0.2s and dodges along the telegraphed escape side;
-- they prove the attack geometry and timing are escapable, not that real players will dodge.
local Shared = game.ReplicatedStorage.Shared
local Chase = require(Shared.GuardianChase)
local State = require(Shared.GuardianState)
local Config = require(Shared.GuardianConfig)
local Geometry = require(Shared.GuardianGeometry)
local Debuff = require(Shared.CarryDebuff)
local Resources = require(Shared.ResourceDefinitions)

local DT = 1 / 20
local REACTION = 0.2
-- Measured floor centers and half lengths along +X; corridor centerline Z = -86.
local ZONES = {
	Grasslands = { 458, 175.3 }, Swamp = { 777.5, 143.8 }, Jungle = { 1064.5, 143.8 },
	CrystalCave = { 1351.5, 143.8 }, Volcano = { 1638.5, 143.8 },
}
local ORDER = { "Grasslands", "Swamp", "Jungle", "CrystalCave", "Volcano" }

local function makeRunway()
	local floors = {}
	for _, id in ORDER do
		local zone = ZONES[id]
		table.insert(floors, {
			center = Vector3.new(zone[1], -0.74, -86), axis = Vector3.xAxis, longHalf = zone[2],
			lateral = Vector3.zAxis, lateralHalf = 52.45, y = -0.24,
		})
	end
	local bases = { { Center = Vector3.new(177, 16, -120), Size = Vector3.new(72, 34, 89) } }
	return Chase.runway(floors, bases, Chase.Timing.SafeMargin)
end

local function hasStrong(assignment)
	for _, effect in assignment.Effects do
		if effect.Tier == "Strong" then return true end
	end
	return false
end

local function journey(areaId, resourceId, seed, side)
	local definition = Resources.get(resourceId)
	local rarity = definition.Rarity
	local rng = Random.new(seed)
	local assignment = Debuff.assign(rarity, function() return rng:NextNumber() end)
	local runway = makeRunway()
	local config = Config.Areas[areaId]
	local zone = ZONES[areaId]
	local home = Vector3.new(zone[1] + zone[2] * 0.7, 7.76, -86)
	local guardian = home
	local player = Vector3.new(zone[1] + zone[2] * 0.3, 2.76, -86 + side)
	local worst = Debuff.applied(definition.CarrySlowdown, Debuff.maxExtra(assignment))
	local safety = if hasStrong(assignment) then Chase.Timing.CursedDodgeSafety else Chase.Timing.DodgeSafety
	local engine = State.new(config)
	local result = {
		Rarity = rarity, Hits = 0, Attacks = 0, Escaped = false, MinGuardianX = math.huge,
		MinFootprintX = math.huge, SleptHome = false, ReturnTime = nil, EscapeTime = nil,
	}
	local frame, sign, pending, dodgeFrom, lastSample, disengageUntil, returnStart = nil, 1, nil, 0, 0, 0, 0
	local entranceX = runway.origin.X + runway.entrance
	local t = 0
	engine:pickup(rarity, 0)
	while t < 1500 do
		t += DT
		local before = player
		if not result.Escaped and result.Hits == 0 then
			local speed = 16 * (1 - Debuff.applied(definition.CarrySlowdown, Debuff.extraSlowdown(assignment, t)))
			local direction = Vector3.new(-1, 0, 0)
			local threatened = frame and (engine.State == "WARNING" or engine.State == "HAZARD")
			if threatened and t - dodgeFrom >= REACTION then
				local localPos = frame:PointToObjectSpace(player)
				if Chase.exitDistance(config, localPos, sign) then
					if config.Kind == "Shockwave" then
						local flat = Vector3.new(localPos.X, 0, localPos.Z)
						direction = frame:VectorToWorldSpace(if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis)
					else
						direction = frame:VectorToWorldSpace(Vector3.new(0, 0, sign))
					end
				end
			end
			local flat = Vector3.new(direction.X, 0, direction.Z).Unit
			player += flat * speed * DT
			player = Vector3.new(player.X, player.Y, math.clamp(player.Z, -86 - 50, -86 + 50))
			if Chase.isSafe(runway, player) then
				result.Escaped = true
				result.EscapeTime = t
			end
		end
		local valid = not result.Escaped and result.Hits == 0
		local context = { attack = false, pursue = false, retreat = false, home = false }
		if engine.State == "PURSUING" then
			if not valid then
				context.retreat = true
			else
				local candidate, candidateSign = nil, nil
				if t >= engine.Deadline and Chase.horizontal(guardian, player) <= Chase.Timing.AttackCommit then
					candidate, candidateSign = Chase.fairFrame(runway, config, guardian, player, 16 * (1 - worst), safety)
				end
				if candidate then
					pending = { candidate, candidateSign }
					context.attack = true
				else
					guardian = Chase.stepToward(guardian, player, Chase.speed(rarity), DT, runway)
				end
			end
		elseif engine.State == "RETURNING" then
			if t >= disengageUntil then
				guardian = Chase.stepToward(guardian, home, Chase.Timing.ReturnSpeed, DT, runway)
				if Chase.horizontal(guardian, home) <= 2 then context.home = true end
			end
		elseif engine.State == "COOLDOWN" then
			context.pursue = valid
			context.retreat = not valid
		end
		engine:step(t, function(state, at)
			if state == "WARNING" then
				frame, sign = pending[1], pending[2]
				dodgeFrom, lastSample = at, at
				result.Attacks += 1
				result.MinFootprintX = math.min(result.MinFootprintX, frame.Position.X - Chase.footprintHalf(config))
			elseif state == "RETURNING" then
				disengageUntil, returnStart = at + Chase.Timing.DisengageHold, at
			elseif state == "SLEEPING" then
				result.SleptHome = Chase.horizontal(guardian, home) <= 2
				result.ReturnTime = at - returnStart
			end
		end, function(a, b)
			local from = math.max(a, lastSample)
			if b < from or result.Hits > 0 then return end
			local function at(time) return before:Lerp(player, math.clamp((time - (t - DT)) / DT, 0, 1)) end
			if not Chase.isSafe(runway, at(b)) and Geometry.hit(config, frame, at(from), at(b), (from - a) / config.Active, (b - a) / config.Active) then
				result.Hits += 1
			end
			lastSample = b
		end, context)
		result.MinGuardianX = math.min(result.MinGuardianX, guardian.X)
		if engine.State == "SLEEPING" then break end
	end
	result.EntranceX = entranceX
	result.BiomeStartX = zone[1] - zone[2]
	return result
end

return function(t)
	local runway = makeRunway()
	t.test("measured runway entrance matches the base containment opening", function()
		t.expect.near(runway.origin.X + runway.entrance, 458 - 175.3, 0.01)
		t.expect.truthy(runway.origin.X + runway.minAlong > 283)
		t.expect.truthy(runway.origin.X + runway.maxAlong >= 1638.5 + 143.8 - 0.01)
	end)

	t.test("fair frames never reach the safe zone and always leave a reachable exit", function()
		local available, total = 0, 0
		for areaId, config in Config.Areas do
			for _, speed in { 16 * (1 - Debuff.MaxTotal), 8, 12, 16 } do
				for _, safety in { Chase.Timing.DodgeSafety, Chase.Timing.CursedDodgeSafety } do
					for alongX = 300, 1780, 37 do
						for _, side in { -48, -20, 0, 14, 47 } do
							local target = Vector3.new(alongX, 2.76, -86 + side)
							for _, offset in { Vector3.new(12, 0, 0), Vector3.new(25, 0, 8), Vector3.new(-10, 0, -6) } do
								local from = Chase.clamp(runway, target + offset)
								local frame, sign = Chase.fairFrame(runway, config, from, target, speed, safety)
								total += 1
								if frame then
									local localPos = frame:PointToObjectSpace(target)
									local exit = Chase.exitDistance(config, localPos, sign)
									t.expect.truthy(exit ~= nil)
									t.expect.truthy(exit <= speed * safety * Chase.dodgeTime(config, localPos) + 1e-3)
									t.expect.truthy(frame.Position.X - Chase.footprintHalf(config) >= runway.origin.X + runway.entrance)
									t.expect.truthy(math.abs(frame.Position.Z + 86) <= runway.halfWidth + 10 + 1e-3)
									local flat = Vector3.new(localPos.X, 0, localPos.Z)
									local outward = if config.Kind ~= "Shockwave" then Vector3.new(0, 0, sign)
										elseif flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
									local exitPoint = frame:PointToWorldSpace(flat + outward * exit)
									t.expect.truthy(math.abs(exitPoint.Z + 86) <= runway.halfWidth + 6 + 1e-3)
									available += 1
								end
							end
						end
					end
				end
				t.expect.truthy(areaId ~= nil)
			end
		end
		script:SetAttribute("FairAvailability", available / total)
	end)

	t.test("separation pushes overlapping guardians apart on the runway", function()
		local a = Vector3.new(900, 7.76, -86)
		local pushed = Chase.separate(a, { a }, Chase.Timing.Spacing, runway, 1)
		local other = Chase.separate(a, { a }, Chase.Timing.Spacing, runway, -1)
		t.expect.truthy(Chase.horizontal(pushed, other) > 1)
		t.expect.equal(Chase.separate(a, { a + Vector3.new(100, 0, 0) }, Chase.Timing.Spacing, runway, 1), a)
		local edge = Chase.separate(Vector3.new(294, 7.76, -86), { Vector3.new(300, 7.76, -86) }, Chase.Timing.Spacing, runway, 1)
		t.expect.truthy(edge.X >= runway.origin.X + runway.minAlong - 1e-3)
	end)

	-- Part D depth cases plus several rarities inside one biome. Walk speed is the only
	-- movement stat (16); no movement upgrade exists to vary.
	local cases = {
		{ "Grasslands", "RawMeat" }, { "Swamp", "BogMarrow" }, { "Jungle", "BeastHeart" },
		{ "CrystalCave", "CrystalCatalyst" }, { "Volcano", "InfernoCatalyst" },
		{ "Volcano", "CharredMeat" }, { "Volcano", "EmberHeart" }, { "Volcano", "DragonScale" },
		{ "Volcano", "DragonMeat" }, { "Volcano", "FireCore" }, { "Volcano", "DragonBlood" },
	}
	local summary = {}
	for _, case in cases do
		local areaId, resourceId = case[1], case[2]
		t.test(("journey %s %s escapes without unavoidable hits"):format(areaId, resourceId), function()
			local attacks, slowest = 0, 0
			for seed = 1, 4 do
				for _, side in { -30, 15 } do
					local r = journey(areaId, resourceId, seed, side)
					attacks += r.Attacks
					slowest = math.max(slowest, r.EscapeTime or 0)
					t.expect.truthy(r.Escaped)
					t.expect.equal(r.Hits, 0)
					t.expect.truthy(r.SleptHome)
					t.expect.truthy(r.ReturnTime ~= nil and r.ReturnTime < Chase.Timing.ReturnDuration)
					t.expect.truthy(r.MinFootprintX >= r.EntranceX)
					t.expect.truthy(r.MinGuardianX >= r.EntranceX + Chase.Timing.EntranceStandoff - 1e-3)
					if areaId ~= "Grasslands" then
						-- Pursuit continued past the guardian's own biome toward the entrance.
						t.expect.truthy(r.MinGuardianX < r.BiomeStartX)
					end
				end
			end
			if areaId ~= "Grasslands" then
				-- The simulation must actually exercise telegraphed attacks, not just outrun them.
				t.expect.truthy(attacks > 0)
			end
			table.insert(summary, ("%s/%s attacks=%d slowestEscape=%.0fs"):format(areaId, resourceId, attacks, slowest))
			script:SetAttribute("Summary", table.concat(summary, "\n"))
		end)
	end
end
