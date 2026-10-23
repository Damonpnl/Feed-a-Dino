--!nonstrict
-- Server-only guardian territory per biome: the guardian home transform and the resource
-- spawn candidates, validated once against the live floor/walls/props. Owns no records.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.Shared
local Areas = require(Shared.AreaDefinitions)
local Layout = require(Shared.BiomeLayout)
local Radial = require(Shared.RadialSpawn)
local Chase = require(Shared.GuardianChase)
local Zone = require(script.Parent.ZoneGeometry)
local Territory = {}
local territories = nil

local function runtimeInstances()
	local list = {}
	local generated = workspace:FindFirstChild("GeneratedGameplay")
	if generated then table.insert(list, generated) end
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(list, player.Character) end
	end
	return list
end

-- Walkable means the downward ray lands on this biome's own floor facing up, and the
-- clearance box above it (model plus room to stand and pick up) touches nothing queryable.
local function probe(floor, row)
	local rayParams, overlap = RaycastParams.new(), OverlapParams.new()
	rayParams.FilterType, overlap.FilterType = Enum.RaycastFilterType.Exclude, Enum.RaycastFilterType.Exclude
	local size = Vector3.new(row.Clearance * 2, row.ClearanceHeight, row.Clearance * 2)
	return function(point)
		local list = runtimeInstances()
		rayParams.FilterDescendantsInstances = list
		local hit = workspace:Raycast(point + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), rayParams)
		if not hit or hit.Instance ~= floor or hit.Normal.Y < 0.9 then return nil end
		table.insert(list, floor)
		overlap.FilterDescendantsInstances = list
		if #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, row.ClearanceHeight / 2 + 0.2, 0)), size, overlap) > 0 then
			return nil
		end
		return hit.Position
	end
end

function Territory.build()
	if territories then return territories end
	local errors = Layout.validate()
	assert(#errors == 0, "[BiomeLayout] " .. table.concat(errors, "; "))
	local built = {}
	for _, area in Areas.getOrdered() do
		local floor = Zone.findFloor(Zone.getZone(area))
		assert(floor, "Missing biome floor: " .. area.Id)
		local surface = Zone.surface(floor)
		local axis, longHalf, lateral, lateralHalf = Chase.axes(surface)
		local row = Layout.Areas[area.Id]
		local span = { center = floor.Position, axis = axis, lateral = lateral, longHalf = longHalf,
			lateralHalf = lateralHalf, y = (floor.Position + surface.normal * surface.half).Y }
		local region = Radial.region(row, span)
		local candidates = Radial.candidates(region, row.Grid, probe(floor, row))
		assert(#candidates >= row.MinCandidates, ("[BiomeLayout] %s geometry supports only %d resource positions (need %d) for radius %d-%d")
			:format(area.Id, #candidates, row.MinCandidates, row.MinRadius, row.MaxRadius))
		built[area.Id] = { AreaId = area.Id, Floor = floor, Row = row, Region = region, Candidates = candidates }
	end
	territories = built
	return built
end

function Territory.get(areaId)
	return Territory.build()[areaId]
end

-- Guardian home floor point and the horizontal direction it faces while sleeping.
function Territory.home(areaId)
	local territory = Territory.get(areaId)
	return territory.Region.Home, territory.Region.Facing
end

function Territory.pick(areaId, occupied, nextNumber)
	local territory = Territory.get(areaId)
	return Radial.pick(territory.Candidates, occupied, territory.Row.Separation, nextNumber)
end

return Territory
