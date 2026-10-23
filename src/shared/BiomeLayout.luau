--!strict
-- Guardian territories. PROVISIONAL graybox values measured against the live blockout;
-- see docs/RADIAL_BIOME_LAYOUT_REPORT.md. Distances are studs on the biome floor.
-- HomeAlong: guardian home as a fraction of the biome length (0 = safe end, 1 = far end).
-- Lane: primary through-path strip along one long wall (LaneSide 1 = +lateral wall, world +Z
--   today; -1 = the other wall; 0 = no lane). Neither resources nor the home use it.
-- The home sits on the midline of the remaining territory, offset by HomeLateral.
-- Resources sample an annulus [MinRadius, MaxRadius] around the home, clipped by the biome
-- ends (EndMargin), the lane (LaneMargin), the floor edge and live geometry (Clearance box).
-- RearDepth: studs a resource may sit behind the home (away from safety, along the biome);
--   deeper thefts force the thief past a waking guardian and are rarely escapable.
export type Row = {
	HomeAlong: number, HomeLateral: number, Facing: string,
	MinRadius: number, MaxRadius: number, RearDepth: number, Separation: number, EndMargin: number,
	Clearance: number, ClearanceHeight: number, Grid: number,
	LaneSide: number, LaneWidth: number, LaneMargin: number, MinCandidates: number,
}
local function row(overrides: { [string]: any }?): Row
	local r: { [string]: any } = {
		HomeAlong = 0.5, HomeLateral = 0, Facing = "Entrance",
		MinRadius = 24, MaxRadius = 90, RearDepth = 24, Separation = 22, EndMargin = 12,
		Clearance = 4, ClearanceHeight = 7, Grid = 4,
		LaneSide = 1, LaneWidth = 26, LaneMargin = 4, MinCandidates = 200,
	}
	for key, value in overrides or {} do r[key] = value end
	return table.freeze(r) :: any
end

local Layout = {}
Layout.Areas = table.freeze({
	Grasslands = row(),
	Swamp = row(),
	Jungle = row(),
	CrystalCave = row(),
	Volcano = row(),
})
-- Guardian body half-diagonal (10 x 18 placeholder) plus a resource half-size; MinRadius must clear it.
Layout.GuardianClearance = 12

function Layout.validate(areas: { [string]: Row }?): { string }
	local rows: { [string]: Row } = areas or Layout.Areas :: any
	local errors = {}
	local function finite(v: any): boolean return type(v) == "number" and v == v and math.abs(v) < math.huge end
	for _, area in require(script.Parent.AreaDefinitions).getOrdered() do
		local r = rows[area.Id]
		if not r then table.insert(errors, "Missing biome layout: " .. area.Id) continue end
		for _, key in { "HomeAlong", "HomeLateral", "MinRadius", "MaxRadius", "RearDepth", "Separation", "EndMargin", "Clearance",
			"ClearanceHeight", "Grid", "LaneSide", "LaneWidth", "LaneMargin", "MinCandidates" } do
			if not finite((r :: any)[key]) then table.insert(errors, "Invalid biome layout " .. area.Id .. "." .. key) end
		end
		if #errors > 0 then continue end
		if r.HomeAlong <= 0 or r.HomeAlong >= 1 then table.insert(errors, "Guardian home must lie inside the biome: " .. area.Id) end
		if r.Facing ~= "Entrance" and r.Facing ~= "Far" then table.insert(errors, "Invalid guardian facing: " .. area.Id) end
		if r.MinRadius < Layout.GuardianClearance + r.Clearance then table.insert(errors, "Resources would overlap the sleeping guardian: " .. area.Id) end
		if r.MaxRadius <= r.MinRadius then table.insert(errors, "MaxRadius must exceed MinRadius: " .. area.Id) end
		if r.RearDepth < 0 or r.RearDepth > r.MaxRadius then table.insert(errors, "RearDepth must be between 0 and MaxRadius: " .. area.Id) end
		if r.Separation < r.Clearance * 2 then table.insert(errors, "Resource separation is smaller than the clearance box: " .. area.Id) end
		if r.Clearance <= 0 or r.ClearanceHeight <= 0 or r.Grid <= 0 or r.Grid > 8 then table.insert(errors, "Invalid clearance/grid: " .. area.Id) end
		if r.LaneSide ~= -1 and r.LaneSide ~= 0 and r.LaneSide ~= 1 then table.insert(errors, "Invalid lane side: " .. area.Id) end
		if r.LaneWidth < 0 or r.LaneMargin < 0 or r.EndMargin < 0 then table.insert(errors, "Negative lane/end margin: " .. area.Id) end
		if r.MinCandidates < 5 then table.insert(errors, "A biome must support at least five resource positions: " .. area.Id) end
	end
	return errors
end

return table.freeze(Layout)
