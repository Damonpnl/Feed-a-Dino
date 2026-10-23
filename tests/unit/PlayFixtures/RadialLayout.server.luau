-- Opt-in Studio Play fixture for centred guardians and radial resource spawning.
-- Attribute Mode = "Validate" (live placement, approach/pickup, travel, reset, respawn) or
-- "Escape" (kinematic runners from every node). Scripted runners: geometry/timing evidence only.
assert(game:GetService("RunService"):IsStudio())
local RunService, HttpService, Players = game:GetService("RunService"), game:GetService("HttpService"), game:GetService("Players")
local S, H = game.ServerScriptService.Server, game.ReplicatedStorage.Shared
local Data, Carry, Resource, Spawn, Guardian, Catch, Territory = require(S.DataService), require(S.CarryService), require(S.ResourceService),
	require(S.SpawnService), require(S.GuardianService), require(S.GuardianCatch), require(S.BiomeTerritory)
local PD, State, Chase, Layout, Radial, Areas, Resources, FieldConfig, Rarities = require(H.PlayerData), require(H.FieldState), require(H.GuardianChase),
	require(H.BiomeLayout), require(H.RadialSpawn), require(H.AreaDefinitions), require(H.ResourceDefinitions), require(H.FieldConfig), require(H.RarityDefinitions)
local p = Players:GetPlayers()[1]
local data = Data.get(p) local backup = PD.copy(data)
local mode = script:GetAttribute("Mode") or "Validate"
local checks, results, stats = 0, {}, {}
local function check(v, message) assert(v, message) checks += 1 script:SetAttribute("PassedChecks", checks) end
local function now() return workspace:GetServerTimeNow() end
local function waitFor(fn, timeout) local d = os.clock() + timeout repeat if fn() then return true end task.wait(0.05) until os.clock() > d return fn() end
local function root() return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function round(n, d) local m = 10 ^ (d or 1) return math.floor(n * m + 0.5) / m end
local field
local entranceX = workspace.GeneratedGameplay.SafeZoneBoundary.Position.X
local function guardianOf(areaId)
	for _, m in workspace.GeneratedGameplay.Guardians:GetChildren() do
		if m.PrimaryPart:GetAttribute("AreaId") == areaId then return m.PrimaryPart end
	end
end
local function physical(id)
	for _, m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId") == id then return m end end
end
local function slotted(areaId)
	local list = {}
	for _, r in Resource.getSnapshot().Records do if r.AreaId == areaId and r.State == "AVAILABLE" and r.NodeId then table.insert(list, r) end end
	table.sort(list, function(a, b) return a.NodeId < b.NodeId end)
	return list
end
local function runtimeFilter(extra)
	local list = { workspace.GeneratedGameplay }
	for _, pl in Players:GetPlayers() do if pl.Character then table.insert(list, pl.Character) end end
	for _, x in extra or {} do table.insert(list, x) end
	return list
end
local function boxesOverlap(cfA, sizeA, cfB, sizeB)
	local function extent(cf, size, axis) return math.abs(cf.RightVector:Dot(axis)) * size.X / 2 + math.abs(cf.UpVector:Dot(axis)) * size.Y / 2 + math.abs(cf.LookVector:Dot(axis)) * size.Z / 2 end
	for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		if math.abs((cfA.Position - cfB.Position):Dot(axis)) > extent(cfA, sizeA, axis) + extent(cfB, sizeB, axis) then return false end
	end
	return true
end
local function recover()
	waitFor(function() return not Catch.isRecovering(p) end, 4)
	if Carry.get(p) then Carry.forceDrop(p, p.Character, "Fixture cleanup") end
end
local function release(areaId, id) if id and Resource.getRecord(id) then Resource.releaseToken(areaId, id) end end

-- Placement invariants for every biome's five slotted resources.
local function verifyPlacement(label)
	local markerIds = {}
	for _, area in Areas.getOrdered() do
		for _, marker in workspace.ExpeditionZones[area.ZoneName].ResourceNodes:GetChildren() do markerIds[marker:GetAttribute("NodeId")] = area.Id end
	end
	local count = 0
	for id, node in field.Nodes do count += 1 check(markerIds[id] == node.AreaId, label .. ": stable node identity " .. id) end
	check(count == 25, label .. ": 25 nodes")
	for _, area in Areas.getOrdered() do
		local t = Territory.get(area.Id)
		local g = guardianOf(area.Id)
		local list = slotted(area.Id)
		local nodes = 0 for _, n in field.Nodes do if n.AreaId == area.Id then nodes += 1 end end
		check(nodes == 5 and #list == 5, label .. ": exactly five active nodes in " .. area.Id)
		check(g:GetAttribute("GuardianState") == "SLEEPING" and Chase.horizontal(g.Position, t.Region.Home) < 0.5, label .. ": guardian home " .. area.Id)
		check(g.CFrame.LookVector:Dot(t.Region.Facing) > 0.99, label .. ": guardian faces safety " .. area.Id)
		for i, r in list do
			local model = physical(r.InstanceId)
			check(model and Radial.contains(t.Region, r.Position) and not Radial.inLane(t.Region, r.Position), label .. ": inside territory " .. r.NodeId)
			local rayParams = RaycastParams.new() rayParams.FilterType = Enum.RaycastFilterType.Exclude rayParams.FilterDescendantsInstances = runtimeFilter()
			local hit = workspace:Raycast(r.Position + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), rayParams)
			check(hit and hit.Instance == t.Floor, label .. ": on own biome floor " .. r.NodeId)
			local cf, size = model:GetBoundingBox()
			local overlap = OverlapParams.new() overlap.FilterType = Enum.RaycastFilterType.Exclude overlap.FilterDescendantsInstances = runtimeFilter({ t.Floor })
			check(#workspace:GetPartBoundsInBox(cf, size + Vector3.new(0.2, 0, 0.2), overlap) == 0, label .. ": not inside solid geometry " .. r.NodeId)
			check(Radial.distance(t.Region, r.Position) >= t.Row.MinRadius and not boxesOverlap(cf, size, g.CFrame, g.Size), label .. ": clear of sleeping guardian " .. r.NodeId)
			for j, other in list do
				if j > i then check(Chase.horizontal(r.Position, other.Position) >= t.Row.Separation, label .. ": separation " .. r.NodeId .. "/" .. other.NodeId) end
			end
		end
	end
end

-- Real Humanoid locomotion from the through-lane to every resource, then a theft.
local function approachAll()
	local humanoid = p.Character.Humanoid
	root().Anchored = false
	for _, area in Areas.getOrdered() do
		local t = Territory.get(area.Id)
		local laneZ = t.Region.Center.Z + (t.Region.LaneMin + t.Region.LaneMax) / 2
		for _, r in slotted(area.Id) do
			Guardian.resetAll()
			local start = Vector3.new(r.Position.X, r.Position.Y + 3, laneZ)
			p.Character:PivotTo(CFrame.new(start))
			task.wait(0.4)
			local distance = Chase.horizontal(start, r.Position)
			humanoid:MoveTo(r.Position)
			local t0 = os.clock()
			local reached = waitFor(function() return Chase.horizontal(root().Position, r.Position) < 5 end, distance / 14 + 4)
			if not reached then humanoid:MoveTo(r.Position) reached = waitFor(function() return Chase.horizontal(root().Position, r.Position) < 5 end, 6) end
			check(reached, "walked from the lane to " .. r.NodeId .. " (" .. round(distance) .. " studs)")
			table.insert(stats, { Kind = "Approach", Node = r.NodeId, Distance = round(distance), Seconds = round(os.clock() - t0, 2) })
			task.wait(0.2)
			check(Spawn.pickup(p, r.InstanceId), "picked up " .. r.NodeId)
			local g = guardianOf(area.Id)
			check(waitFor(function() local s = g:GetAttribute("GuardianState") return s == "WAKING" or s == "PURSUING" end, 0.5), "theft at " .. r.NodeId .. " triggers pursuit")
			Carry.forceDrop(p, p.Character, "Fixture cleanup")
			release(area.Id, r.InstanceId)
			Guardian.resetAll()
			task.wait(0.2)
		end
	end
end

-- Walking through every biome without a carry must never wake its guardian.
local function travelThrough()
	local humanoid = p.Character.Humanoid
	root().Anchored = false
	local woke = false
	local watchers = {}
	for _, area in Areas.getOrdered() do
		local g = guardianOf(area.Id)
		table.insert(watchers, g:GetAttributeChangedSignal("GuardianState"):Connect(function() if g:GetAttribute("GuardianState") ~= "SLEEPING" then woke = true end end))
	end
	for _, area in Areas.getOrdered() do
		local home = Territory.get(area.Id).Region.Home
		local y = home.Y + 3
		-- Straight through the territory, brushing past the sleeping guardian at 9 studs.
		p.Character:PivotTo(CFrame.new(Vector3.new(home.X - 70, y, home.Z + 9)))
		task.wait(0.3)
		humanoid:MoveTo(Vector3.new(home.X + 70, y, home.Z + 9))
		waitFor(function() return Chase.horizontal(root().Position, Vector3.new(home.X + 70, y, home.Z + 9)) < 4 end, 12)
	end
	for _, c in watchers do c:Disconnect() end
	check(not woke, "ordinary travel past every guardian never triggers pursuit")
end

-- Phase 2 hard reset: carried loot survives, every node refills with fresh valid placements.
local function fieldReset()
	local list = slotted("Grasslands")
	local carried = list[1]
	root().Anchored = true
	p.Character:PivotTo(CFrame.new(carried.Position + Vector3.new(0, 3, 0)))
	task.wait(0.3)
	check(Spawn.pickup(p, carried.InstanceId), "carry before reset")
	local before = {}
	for id in Resource.getSnapshot().Records do before[id] = true end
	field.NextResetAt = now() + 0.3
	check(waitFor(function() return field.Phase == "Reset" end, 3), "reset window starts")
	check(waitFor(function() return field.Phase == "Normal" end, FieldConfig.RESET_WINDOW_SECONDS + 3), "field refills after the reset window")
	task.wait(0.4)
	local record = Resource.getRecord(carried.InstanceId)
	check(record and record.State == "CARRIED" and record.NodeId == nil, "carried resource survives reset, node detached")
	for _, r in Resource.getSnapshot().Records do
		if r.InstanceId ~= carried.InstanceId then check(not before[r.InstanceId] and r.SpawnReason == "HardReset", "fresh GUID after reset " .. r.NodeId) end
	end
	verifyPlacement("after reset")
	Carry.forceDrop(p, p.Character, "Fixture cleanup")
	release("Grasslands", carried.InstanceId)
	Guardian.resetAll()
end

-- Mid-cycle refill keeps the rarity timer, the node slot and the Secret+ restriction.
local function midCycle()
	local rng = Random.new(7)
	for _ = 1, 40 do
		local area = Areas.getOrdered()[rng:NextInteger(1, 5)]
		local list = slotted(area.Id)
		local victim = list[rng:NextInteger(1, #list)]
		local nodeId = victim.NodeId
		local delay = FieldConfig.RespawnSeconds[Resources.get(victim.ResourceId).Rarity]
		release(area.Id, victim.InstanceId)
		local node = field.Nodes[nodeId]
		if delay then check(node.RespawnAt and math.abs(node.RespawnAt - now() - delay) < 1, "respawn timer unchanged for " .. victim.ResourceId)
		else check(node.RespawnAt == nil, "chase-tier node never refills mid-cycle") field:create(node, victim.ResourceId, "Fixture") Resource.step() continue end
		node.RespawnAt = now()
		check(waitFor(function() return field.Nodes[nodeId].RecordId ~= nil end, 2), "node refills " .. nodeId)
		local fresh = Resource.getRecord(field.Nodes[nodeId].RecordId)
		local t = Territory.get(area.Id)
		check(fresh.InstanceId ~= victim.InstanceId and fresh.SpawnReason == "MidCycle" and fresh.NodeId == nodeId, "fresh GUID on the same node " .. nodeId)
		check(not Rarities.isSecretPlus(Resources.get(fresh.ResourceId).Rarity), "mid-cycle refill never rolls Secret+")
		check(fresh.Position and Radial.contains(t.Region, fresh.Position), "respawn inside territory " .. nodeId)
		task.wait(0.15)
		check(physical(fresh.InstanceId) ~= nil, "respawn has a world model " .. nodeId)
		for _, other in slotted(area.Id) do
			if other.InstanceId ~= fresh.InstanceId then check(Chase.horizontal(other.Position, fresh.Position) >= t.Row.Separation, "respawn separation " .. nodeId) end
		end
	end
end

-- Many simulated fills from the live candidate sets: separation, radius spread, saturation.
local function placementStats()
	for _, area in Areas.getOrdered() do
		local t = Territory.get(area.Id)
		local rng = Random.new(11)
		local minR, maxR, sumR, n, minSep = math.huge, 0, 0, 0, math.huge
		local sectors = {}
		for _ = 1, 400 do
			local placed = {}
			for _ = 1, 5 do
				local point = Territory.pick(area.Id, placed, function() return rng:NextNumber() end)
				for _, other in placed do minSep = math.min(minSep, Chase.horizontal(point, other)) end
				table.insert(placed, point)
				local r = Radial.distance(t.Region, point)
				minR, maxR, sumR, n = math.min(minR, r), math.max(maxR, r), sumR + r, n + 1
				local along, lateral = Radial.localOf(t.Region, point)
				local angle = math.atan2(lateral - t.Region.HomeLateral, along - t.Region.HomeAlong)
				local sector = math.floor((angle + math.pi) / (math.pi / 4)) % 8
				sectors[sector] = (sectors[sector] or 0) + 1
			end
		end
		local spread = {} for i = 0, 7 do table.insert(spread, sectors[i] or 0) end
		table.insert(stats, { Kind = "Placement", Area = area.Id, Candidates = #t.Candidates, MinRadius = round(minR), MeanRadius = round(sumR / n), MaxRadius = round(maxR),
			MinSeparation = round(minSep), Sectors = spread, HomeX = round(t.Region.Home.X), HomeZ = round(t.Region.Home.Z) })
		check(minSep >= t.Row.Separation, "400 simulated fills keep separation in " .. area.Id)
	end
end

local carriers = {
	Grasslands = { { "Ordinary", "RawMeat" }, { "Slowed", "AncientBone" }, { "Cursed", "PrimalCatalyst" } },
	Swamp = { { "Ordinary", "SmallFish" }, { "Slowed", "VenomSac" }, { "Cursed", "MutantLeech" } },
	Jungle = { { "Ordinary", "WildFruit" }, { "Slowed", "RareFlower" }, { "Cursed", "BeastHeart" } },
	CrystalCave = { { "Ordinary", "CrystalShard" }, { "Slowed", "FossilMarrow" }, { "Cursed", "PrismaticCrystal" } },
	-- Volcano has no curse-free resource slower than Charred Meat (already 18% slowdown).
	Volcano = { { "Ordinary", "CharredMeat" }, { "Cursed", "DragonScale" } },
}
local speeds = { 16, 18, 22, 30 }

-- One kinematic theft-to-outcome run. The runner moves at base * (live WalkSpeed / 16), so carry
-- and curse slowdowns scale every base speed. If it starts behind the guardian it first swings
-- wide on its side, then runs straight for safety.
local function trial(area, nodeId, position, carrier, resourceId, base, watchReturn)
	local g = guardianOf(area)
	local t = Territory.get(area)
	local node = field.Nodes[nodeId]
	local id, curseText = nil, ""
	for _ = 1, 10 do
		Guardian.resetAll() task.wait(0.25)
		if node.RecordId then release(area, node.RecordId) end
		local record = field:create(node, resourceId, "RadialLayout")
		record.Position, record.SpawnPosition = position, position
		Resource.step()
		local r = root() r.Anchored = true
		local away = Vector3.new(position.X - g.Position.X, 0, position.Z - g.Position.Z).Unit
		p.Character:PivotTo(CFrame.new(position + away * 1.5 + Vector3.new(0, 3, 0)))
		task.wait(0.2)
		assert(Spawn.pickup(p, record.InstanceId), "Pickup failed at " .. nodeId)
		local curse = Carry.getCurse(p)
		local cursed = curse ~= nil and #curse.Effects > 0
		if cursed == (carrier == "Cursed") then
			id = record.InstanceId
			if cursed then
				local names = {} for _, effect in curse.Effects do table.insert(names, effect.Id .. ":" .. effect.Tier) end
				curseText = table.concat(names, "+")
			end
			break
		end
		Carry.forceDrop(p, p.Character, "Fixture reroll")
		release(area, record.InstanceId)
	end
	assert(id, "Could not obtain a " .. carrier .. " carry at " .. nodeId)
	local humanoid = p.Character.Humanoid
	local start = root().Position
	local theftDistance = Chase.horizontal(g.Position, start)
	local drops = p:GetAttribute("DropTick")
	local t0, pursueAt = os.clock(), nil
	local outcome, minGap, attacks, lastState = "Timeout", math.huge, 0, nil
	local speedSum, speedSamples, guardianMinX = 0, 0, math.huge
	local side = if start.Z - g.Position.Z >= 0 then 1 else -1
	local wallLow, wallHigh = t.Region.Center.Z - 74, t.Region.Center.Z + 74
	local waypoint = nil
	if start.X > g.Position.X - 12 then waypoint = Vector3.new(g.Position.X - 6, start.Y, math.clamp(g.Position.Z + side * 50, wallLow, wallHigh)) end
	local connection = RunService.Heartbeat:Connect(function(dt)
		local rr = root() if not rr then return end
		local state = g:GetAttribute("GuardianState")
		if state ~= lastState then
			if state == "PURSUING" and not pursueAt then pursueAt = os.clock() - t0 end
			if state == "WARNING" then attacks += 1 end
			lastState = state
		end
		minGap = math.min(minGap, Chase.catchGap(g.CFrame, g.Size, rr.Position))
		guardianMinX = math.min(guardianMinX, g.Position.X)
		if Catch.isRecovering(p) then return end
		local goal = waypoint or Vector3.new(entranceX - 20, rr.Position.Y, rr.Position.Z)
		local flat = Vector3.new(goal.X - rr.Position.X, 0, goal.Z - rr.Position.Z)
		if waypoint and flat.Magnitude < 3 then waypoint = nil return end
		local speed = base * humanoid.WalkSpeed / 16
		speedSum += speed speedSamples += 1
		if flat.Magnitude > 0.5 then p.Character:PivotTo(CFrame.new(rr.Position + flat.Unit * math.min(flat.Magnitude, speed * dt))) end
	end)
	waitFor(function()
		if p:GetAttribute("DropTick") ~= drops then
			outcome = if tostring(p:GetAttribute("DropReason")):find("GuardianCatch", 1, true) then "Caught" else "HazardHit"
			return true
		end
		if not Carry.get(p) then outcome = "Lost" return true end
		local rr = root()
		if rr and rr.Position.X < entranceX then outcome = "Escaped" return true end
		return false
	end, 160)
	connection:Disconnect()
	local elapsed = os.clock() - t0
	local rr = root()
	local row = {
		Area = area, Node = nodeId, Carrier = carrier, Resource = resourceId, BaseSpeed = base,
		MeanSpeed = round(speedSamples > 0 and speedSum / speedSamples or 0, 2), Curse = curseText,
		TheftDistance = round(theftDistance), StartFromSafety = round(start.X - entranceX), Outcome = outcome,
		Seconds = round(elapsed, 2), PursueAt = pursueAt and round(pursueAt, 2) or -1,
		ChaseSeconds = pursueAt and round(elapsed - pursueAt, 2) or -1,
		CatchSeconds = if outcome == "Caught" or outcome == "HazardHit" then round(elapsed, 2) else -1,
		EndFromSafety = rr and round(rr.Position.X - entranceX) or -1, MinGap = round(minGap), Attacks = attacks,
		GuardianMinFromSafety = round(guardianMinX - entranceX),
	}
	if watchReturn then
		local r0 = os.clock()
		local slept = waitFor(function() return g:GetAttribute("GuardianState") == "SLEEPING" end, 120)
		row.ReturnSeconds = round(os.clock() - r0, 2)
		row.ReturnedHome = slept and Chase.horizontal(g.Position, t.Region.Home) <= 2 and g.CFrame.LookVector:Dot(t.Region.Facing) > 0.99
	end
	table.insert(results, row)
	script:SetAttribute("Results", HttpService:JSONEncode(results))
	script:SetAttribute("Progress", #results)
	recover()
	release(area, id)
	return row
end

local function escapeSweep()
	local fixed = {}
	for _, area in Areas.getOrdered() do
		for _, r in slotted(area.Id) do fixed[r.NodeId] = r.Position end
	end
	script:SetAttribute("Positions", HttpService:JSONEncode((function()
		local out = {} for nodeId, pos in fixed do out[nodeId] = { round(pos.X), round(pos.Z) } end return out end)()))
	local only = script:GetAttribute("Area")
	for _, area in Areas.getOrdered() do
		if only and only ~= area.Id then continue end
		local watched = false
		local nodes = {} for nodeId, n in field.Nodes do if n.AreaId == area.Id then table.insert(nodes, nodeId) end end
		table.sort(nodes)
		for _, nodeId in nodes do
			for _, pair in carriers[area.Id] do
				for _, base in speeds do
					local watch = not watched and pair[1] == "Ordinary" and base == 30
					local row = trial(area.Id, nodeId, fixed[nodeId], pair[1], pair[2], base, watch)
					if watch then
						watched = true
						check(row.ReturnedHome, "guardian returns to its home after a full chase in " .. area.Id)
					end
					check(row.GuardianMinFromSafety >= 0, "guardian never entered the safe zone (" .. area.Id .. ")")
					check(row.PursueAt > 0, "pursuit triggered from " .. nodeId)
				end
			end
		end
	end
end

local oldStep = State.step
local savedReset
local ok, failure = xpcall(function()
	State.step = function(self, ...) field = self return oldStep(self, ...) end
	check(waitFor(function() return field ~= nil end, 5), "Field captured")
	data.Power = 1e12
	if mode == "Validate" then
		check(field.Phase == "Normal" and field.NextResetAt - now() > 120, "enough cycle time left for validation")
		verifyPlacement("initial fill")
		placementStats()
		approachAll()
		travelThrough()
		midCycle()
		fieldReset()
	else
		-- Back-to-back sweeps can start inside a reset window; every node must be stocked first.
		check(waitFor(function()
			if field.Phase ~= "Normal" or field.NextResetAt - now() < 20 then return false end
			for _, area in Areas.getOrdered() do if #slotted(area.Id) < 5 then return false end end
			return true
		end, 120), "field is normal and fully stocked before the sweep")
		savedReset = field.NextResetAt
		field.NextResetAt = now() + 1e6
		escapeSweep()
	end
end, debug.traceback)
State.step = oldStep
if savedReset and field then field.NextResetAt = math.max(savedReset, now() + 1) end
Guardian.resetAll()
if Carry.get(p) then Carry.forceDrop(p, p.Character, "Fixture cleanup") end
for k in data do data[k] = nil end for k, v in backup do data[k] = v end
local r = root() if r then r.Anchored = false end
script:SetAttribute("Stats", HttpService:JSONEncode(stats))
script:SetAttribute("Result", if ok then "PASS" else failure)
if ok then print("[RadialLayout] PASS " .. checks .. " " .. mode) else warn(failure) end
