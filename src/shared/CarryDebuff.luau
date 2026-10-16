--!strict
-- Data-driven carrying curses. Pure: randomness is injected, time is elapsed seconds.
-- ResourceDefinitions.CarrySlowdown stays the authoritative base slowdown.
-- Spawn weights are never read or written here.
local Rarities = require(script.Parent.RarityDefinitions)

local CarryDebuff = {}

export type Tier = "Mild" | "Moderate" | "Strong"
export type Effect = {
	Id: string,
	Tier: Tier,
	Extra: number,
	Normal: number?,
	Active: number?,
	Warning: number?,
}
export type Assignment = { Rarity: string, Title: string, Effects: { Effect } }
export type Phase = { State: string, Remaining: number }

type CycleRange = { Normal: { number }, Active: { number }, Warning: number }
type Definition = {
	Label: string,
	Kind: string,
	Tiers: { [string]: { Extra: number?, Weight: number } },
	Cycle: CycleRange?,
	Status: { Normal: string, Warning: string?, Active: string? },
	Enabled: boolean,
	Substitute: string?,
}

-- Kinds: Speed (static extra slowdown), SpeedCycle (extra slowdown only while Active),
-- Input (client move-vector inversion while Active), Momentum (client move smoothing),
-- Camera (client mild roll while Active), Vision (client peripheral vignette).
CarryDebuff.Catalog = {
	InvertedControls = {
		Label = "INVERTED CONTROLS", Kind = "Input", Enabled = true,
		Tiers = { Strong = { Weight = 1 } },
		Cycle = { Normal = { 3, 4 }, Active = { 1.5, 2 }, Warning = 1 },
		Status = { Normal = "CONTROLS INVERT IN %.1fs", Warning = "CONTROLS INVERT IN %.1fs", Active = "CONTROLS INVERTED %.1fs" },
	},
	HeavyBurden = {
		Label = "HEAVY BURDEN", Kind = "Speed", Enabled = true,
		Tiers = { Mild = { Extra = 0.06, Weight = 1 }, Moderate = { Extra = 0.10, Weight = 1 } },
		Status = { Normal = "MOVEMENT REDUCED" },
	},
	CursedMomentum = {
		Label = "CURSED MOMENTUM", Kind = "Momentum", Enabled = true,
		Tiers = { Moderate = { Weight = 1 } },
		Status = { Normal = "SLIPPERY FOOTING" },
	},
	ShiftingWeight = {
		Label = "SHIFTING WEIGHT", Kind = "SpeedCycle", Enabled = true,
		Tiers = { Mild = { Extra = 0.08, Weight = 1 }, Moderate = { Extra = 0.14, Weight = 1 } },
		Cycle = { Normal = { 3, 4 }, Active = { 2, 2.5 }, Warning = 1 },
		Status = { Normal = "WEIGHT SHIFTS IN %.1fs", Warning = "WEIGHT SHIFTS IN %.1fs", Active = "WEIGHT SHIFTED %.1fs" },
	},
	UnstableGrip = {
		Label = "UNSTABLE GRIP", Kind = "SpeedCycle", Enabled = true,
		Tiers = { Moderate = { Extra = 0.20, Weight = 1 } },
		Cycle = { Normal = { 4, 6 }, Active = { 0.6, 0.8 }, Warning = 0.75 },
		Status = { Normal = "GRIP SLIPS IN %.1fs", Warning = "GRIP SLIPS IN %.1fs", Active = "GRIP SLIPPING %.1fs" },
	},
	Disorientation = {
		Label = "DISORIENTATION", Kind = "Camera", Enabled = true,
		Tiers = { Strong = { Weight = 1 } },
		Cycle = { Normal = { 2.5, 3.5 }, Active = { 1.5, 2 }, Warning = 0.75 },
		Status = { Normal = "DIZZY IN %.1fs", Warning = "DIZZY IN %.1fs", Active = "DISORIENTED %.1fs" },
	},
	ObscuredVision = {
		Label = "OBSCURED VISION", Kind = "Vision", Enabled = true,
		Tiers = { Mild = { Weight = 1 } },
		Status = { Normal = "EDGES DARKENED" },
	},
	-- The project has no sprint mechanic; Shifting Weight is the documented substitute.
	ErraticSprint = {
		Label = "ERRATIC SPRINT", Kind = "SpeedCycle", Enabled = false, Substitute = "ShiftingWeight",
		Tiers = { Moderate = { Weight = 1 } },
		Status = { Normal = "" },
	},
} :: { [string]: Definition }

-- Primary: weighted tier choice. Chance: probability that any curse applies.
-- Secondary: optional Mild effect drawn only from the primary's compatible list.
CarryDebuff.Profiles = {
	Common = {}, Uncommon = {}, Rare = {},
	Epic = { Chance = 0.25, Primary = { Mild = 1 } },
	Legendary = { Primary = { Mild = 1 } },
	Mythic = { Primary = { Moderate = 1 } },
	Cosmic = { Primary = { Moderate = 1, Strong = 1 } },
	Secret = { Primary = { Strong = 1 } },
	Eternal = { Primary = { Strong = 1 }, Secondary = { Chance = 0.25 } },
	Divine = { Primary = { Strong = 1 }, Secondary = { Chance = 1 } },
} :: { [string]: { Chance: number?, Primary: { [string]: number }?, Secondary: { Chance: number }? } }

-- Curated strong + mild pairs. Two visual effects or two input effects never combine.
CarryDebuff.Compatible = {
	InvertedControls = { HeavyBurden = true, ShiftingWeight = true, ObscuredVision = true },
	Disorientation = { HeavyBurden = true, ShiftingWeight = true },
} :: { [string]: { [string]: boolean } }

-- Combined slowdown cap: 16 * (1 - 0.62) keeps carriers above 6 studs/s.
CarryDebuff.MaxTotal = 0.62

local tierOrder = { "Mild", "Moderate", "Strong" }

local function options(tier: string, filter: ((string) -> boolean)?): { { Id: string, Weight: number } }
	local list = {}
	local ids = {}
	for id in CarryDebuff.Catalog do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ids do
		local definition = CarryDebuff.Catalog[id]
		local tierData = definition.Tiers[tier]
		if definition.Enabled and tierData and (not filter or filter(id)) then
			table.insert(list, { Id = id, Weight = tierData.Weight })
		end
	end
	return list
end

local function pick<T>(list: { T }, weightOf: (T) -> number, rand: () -> number): T?
	local total = 0
	for _, item in list do total += weightOf(item) end
	if total <= 0 then return nil end
	local ticket = rand() * total
	for _, item in list do
		ticket -= weightOf(item)
		if ticket < 0 then return item end
	end
	return list[#list]
end

local function make(id: string, tier: Tier, rand: () -> number): Effect
	local definition = CarryDebuff.Catalog[id]
	local cycle = definition.Cycle
	local effect: Effect = { Id = id, Tier = tier, Extra = definition.Tiers[tier].Extra or 0 }
	if cycle then
		effect.Normal = cycle.Normal[1] + (cycle.Normal[2] - cycle.Normal[1]) * rand()
		effect.Active = cycle.Active[1] + (cycle.Active[2] - cycle.Active[1]) * rand()
		effect.Warning = cycle.Warning
	end
	return effect
end

local function title(rarity: string, effects: { Effect }): string
	if #effects == 0 then return "" end
	if Rarities.isSecretPlus(rarity) then return string.upper(rarity) .. " CURSE" end
	return "CURSED CARRY"
end

-- One assignment per resource record; callers must not reroll on re-pickup.
function CarryDebuff.assign(rarity: string, rand: () -> number): Assignment?
	local profile = CarryDebuff.Profiles[rarity]
	if not profile then return nil end
	local effects: { Effect } = {}
	local primary = profile.Primary
	if primary and (profile.Chance == nil or rand() < profile.Chance) then
		local tiers = {}
		for _, tier in tierOrder do
			if primary[tier] then table.insert(tiers, { Tier = tier, Weight = primary[tier] }) end
		end
		local chosenTier = pick(tiers, function(row) return row.Weight end, rand)
		local first = chosenTier and pick(options(chosenTier.Tier), function(row) return row.Weight end, rand)
		if chosenTier and first then
			table.insert(effects, make(first.Id, chosenTier.Tier :: Tier, rand))
			local secondary = profile.Secondary
			local allowed = CarryDebuff.Compatible[first.Id]
			if secondary and allowed and rand() < secondary.Chance then
				local second = pick(options("Mild", function(id) return allowed[id] == true end), function(row) return row.Weight end, rand)
				if second then table.insert(effects, make(second.Id, "Mild", rand)) end
			end
		end
	end
	return { Rarity = rarity, Title = title(rarity, effects), Effects = effects }
end

-- Cycle: Normal (last Warning seconds are a warning), then Active, repeating.
-- The first activation is always at least Normal seconds after pickup.
function CarryDebuff.phase(effect: Effect, elapsed: number): Phase
	local normal, active, warning = effect.Normal, effect.Active, effect.Warning
	if not normal or not active or not warning then
		return { State = "Static", Remaining = 0 }
	end
	local t = math.max(elapsed, 0) % (normal + active)
	if t < normal - warning then return { State = "Normal", Remaining = normal - t } end
	if t < normal then return { State = "Warning", Remaining = normal - t } end
	return { State = "Active", Remaining = normal + active - t }
end

function CarryDebuff.isActive(effect: Effect, elapsed: number): boolean
	local state = CarryDebuff.phase(effect, elapsed).State
	return state == "Active" or state == "Static"
end

function CarryDebuff.extraSlowdown(assignment: Assignment?, elapsed: number): number
	if not assignment then return 0 end
	local total = 0
	for _, effect in assignment.Effects do
		local kind = CarryDebuff.Catalog[effect.Id].Kind
		if kind == "Speed" or (kind == "SpeedCycle" and CarryDebuff.isActive(effect, elapsed)) then
			total += effect.Extra
		end
	end
	return total
end

function CarryDebuff.maxExtra(assignment: Assignment?): number
	if not assignment then return 0 end
	local total = 0
	for _, effect in assignment.Effects do total += effect.Extra end
	return total
end

function CarryDebuff.isTimed(assignment: Assignment?): boolean
	if not assignment then return false end
	for _, effect in assignment.Effects do
		if effect.Normal then return true end
	end
	return false
end

function CarryDebuff.status(effect: Effect, elapsed: number): string
	local definition = CarryDebuff.Catalog[effect.Id]
	local phase = CarryDebuff.phase(effect, elapsed)
	local template = definition.Status[phase.State] or definition.Status.Normal
	if string.find(template, "%", 1, true) then
		return string.format(template, phase.Remaining)
	end
	return template
end

function CarryDebuff.applied(baseSlowdown: number, extra: number): number
	local total = baseSlowdown + extra
	if total < 0 then return 0 end
	if total > CarryDebuff.MaxTotal then return CarryDebuff.MaxTotal end
	return total
end

function CarryDebuff.validate(): { string }
	local errors = {}
	local function fail(message: string) table.insert(errors, message) end
	for id, definition in CarryDebuff.Catalog do
		for tier, data in definition.Tiers do
			if tier ~= "Mild" and tier ~= "Moderate" and tier ~= "Strong" then fail("Invalid curse tier: " .. id) end
			local extra = data.Extra or 0
			if extra ~= extra or extra < 0 or extra > 0.3 or not (data.Weight > 0) then fail("Invalid curse values: " .. id) end
		end
		local cycle = definition.Cycle
		if cycle and not (cycle.Warning > 0 and cycle.Warning < cycle.Normal[1] and cycle.Normal[1] <= cycle.Normal[2]
			and cycle.Active[1] > 0 and cycle.Active[1] <= cycle.Active[2]) then
			fail("Invalid curse cycle: " .. id)
		end
		if definition.Kind == "Input" and cycle and cycle.Warning < 1 then fail("Inversion needs a 1 second warning") end
		if not definition.Enabled and not (definition.Substitute and CarryDebuff.Catalog[definition.Substitute]) then
			fail("Disabled curse needs a substitute: " .. id)
		end
	end
	for _, rarity in Rarities.Order do
		local profile = CarryDebuff.Profiles[rarity]
		if not profile then fail("Missing curse profile: " .. rarity) continue end
		for tier in profile.Primary or {} do
			if #options(tier) == 0 then fail("No enabled curse for " .. rarity .. " " .. tier) end
		end
	end
	for strong, list in CarryDebuff.Compatible do
		if not CarryDebuff.Catalog[strong] or not CarryDebuff.Catalog[strong].Tiers.Strong then fail("Compatibility root is not strong: " .. strong) end
		for id in list do
			local definition = CarryDebuff.Catalog[id]
			if not definition or not definition.Tiers.Mild or definition.Tiers.Strong then fail("Incompatible secondary: " .. id) end
			if definition and CarryDebuff.Catalog[strong] and definition.Kind == CarryDebuff.Catalog[strong].Kind then fail("Same-kind pair: " .. id) end
		end
	end
	for _, row in options("Strong") do
		if not CarryDebuff.Compatible[row.Id] then fail("Strong curse lacks a compatibility list: " .. row.Id) end
	end
	return errors
end

return CarryDebuff
