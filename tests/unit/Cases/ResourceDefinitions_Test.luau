--!nonstrict
local Shared = game.ReplicatedStorage.Shared
local Resources = require(Shared.ResourceDefinitions)
local Areas = require(Shared.AreaDefinitions)
local Roller = require(Shared.FieldRoller)
local Validation = require(Shared.ResourceValidation)
-- Independent expected launch tables from the user's authoritative specification.
local expected = {
	Grasslands = {
		{"RawMeat", "Common", 5, 0, 34, 0}, {"Berries", "Common", 6, 0, 24, 0},
		{"BoneChunk", "Uncommon", 8, 50, 17, 0}, {"PrimeMeat", "Rare", 12, 120, 10, 0.02},
		{"WildHerbs", "Rare", 12, 200, 7, 0.02}, {"GiantRib", "Epic", 18, 350, 4.5, 0.05},
		{"AncientBone", "Epic", 18, 500, 2.5, 0.08}, {"PrimalCatalyst", "Legendary", 30, 1000, 1, 0.10},
	},
	Swamp = {
		{"SmallFish", "Uncommon", 22, 1500, 32, 0.05}, {"RottenMeat", "Rare", 28, 2200, 23, 0.05},
		{"SporePod", "Rare", 30, 3000, 17, 0.06}, {"SwampMushroom", "Epic", 38, 4500, 11, 0.08},
		{"VenomSac", "Epic", 45, 6500, 8, 0.10}, {"BogMarrow", "Legendary", 55, 9000, 5, 0.12},
		{"MutantLeech", "Mythic", 70, 14000, 3, 0.14}, {"ToxicCatalyst", "Cosmic", 100, 25000, 1, 0.18},
	},
	Jungle = {
		{"WildFruit", "Rare", 75, 25000, 30, 0.08}, {"GiantBeetle", "Rare", 80, 35000, 23, 0.08},
		{"RareFlower", "Epic", 95, 50000, 18, 0.10}, {"ProteinRoot", "Legendary", 110, 75000, 12, 0.12},
		{"GoldenBanana", "Legendary", 125, 100000, 8, 0.13}, {"RoyalJelly", "Mythic", 150, 150000, 5, 0.15},
		{"BeastHeart", "Mythic", 180, 225000, 3, 0.18}, {"JungleHeart", "Secret", 250, 350000, 1, 0.22},
	},
	CrystalCave = {
		{"CrystalShard", "Rare", 250, 350000, 29, 0.10}, {"FossilMarrow", "Epic", 300, 500000, 23, 0.12},
		{"MineralCore", "Legendary", 375, 750000, 18, 0.15}, {"LivingGeode", "Legendary", 450, 1000000, 13, 0.18},
		{"PrismaticCrystal", "Mythic", 550, 1500000, 9, 0.20}, {"FossilHeart", "Cosmic", 700, 2500000, 5, 0.24},
		{"CrystalCore", "Cosmic", 850, 4000000, 2.5, 0.28}, {"CrystalCatalyst", "Secret", 1200, 6000000, 0.5, 0.32},
	},
	Volcano = {
		{"CharredMeat", "Epic", 1000, 6000000, 37.51, 0.18}, {"MagmaStone", "Legendary", 1200, 8000000, 26.27, 0.20},
		{"EmberHeart", "Legendary", 1500, 12000000, 16.83, 0.22}, {"DragonScale", "Mythic", 1800, 18000000, 13.96, 0.25},
		{"DragonMeat", "Cosmic", 2400, 30000000, 4.36, 0.30}, {"FireCore", "Secret", 3200, 50000000, 0.74, 0.35},
		{"DragonBlood", "Eternal", 4500, 80000000, 0.31, 0.40}, {"InfernoCatalyst", "Divine", 7000, 150000000, 0.02, 0.50},
	},
}
return function(t)
	local e = t.expect
	for areaId, entries in expected do
		-- All eight resources must match the authoritative values and Index order.
		for index, row in entries do
			t.test("matches " .. areaId .. " " .. row[1], function()
				local definition = Resources.get(row[1])
				e.truthy(definition)
				e.equal(definition.Area, areaId) e.equal(definition.Rarity, row[2])
				e.equal(definition.Growth, row[3]) e.equal(definition.PowerRequired, row[4])
				e.equal(definition.SpawnWeight, row[5]) e.equal(definition.CarrySlowdown, row[6])
				e.equal(Areas.get(areaId).ResourcePool[index].Id, row[1])
			end)
		end
		-- Decimal weights sum exactly using integer hundredths.
		t.test("has exactly 100 weight and eight entries in " .. areaId, function()
			e.equal(#Areas.get(areaId).ResourcePool, 8)
			e.equal(Roller.tickets(Areas.get(areaId).ResourcePool), 10000)
		end)
	end
	-- Validates required fields, effects, unique IDs and model fallback coverage.
	t.test("passes full configuration validation", function() e.equal(#Validation.config(), 0) end)
	-- Reserved resources cannot enter a normal launch pool.
	t.test("reserves future catalysts without spawn probabilities", function()
		for _, id in {"GiantSerum", "SpiritEnergy", "CyberCore", "VoidEssence", "BloodMoonShard", "CelestialCore"} do
			local resource = Resources.get(id) e.falsy(resource.Launch) e.equal(resource.SpawnWeight, 0)
		end
	end)
end
