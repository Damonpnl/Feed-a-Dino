--!strict
local Types = require(script.Parent.ResourceTypes)
local Definitions = {}
local all: { [string]: Types.ResourceDefinition } = {}
local function add(id: string, name: string, area: string, kind: Types.ResourceKind, rarity: string,
	affinity: Types.AffinityId, growth: number, power: number, weight: number, slowdown: number, effect: string?, launch: boolean?)
	assert(all[id] == nil, "Duplicate resource ID: " .. id)
	local affinities = {}
	-- Odd totals retain every point; the first listed affinity receives the remainder.
	if affinity == "Flesh + Mineral" then affinities = { Flesh = math.ceil(growth / 2), Mineral = math.floor(growth / 2) }
	elseif affinity == "Flesh + Floral" then affinities = { Flesh = math.ceil(growth / 2), Floral = math.floor(growth / 2) }
	elseif affinity ~= "Neutral" then affinities[affinity] = growth end
	all[id] = {
		Id = id, DisplayName = name, Area = area, ResourceType = kind, Rarity = rarity,
		Affinity = affinity, Affinities = affinities, Growth = growth, PowerRequired = power,
		SpawnWeight = weight, CarrySlowdown = slowdown, SpecialEffect = effect or "None",
		ModelKey = id, BillboardOffset = Vector3.new(0, 0.8, 0), Launch = launch ~= false,
	}
end
add("RawMeat", "Raw Meat", "Grasslands", "Feed", "Common", "Flesh", 5, 0, 34, 0)
add("Berries", "Berries", "Grasslands", "Feed", "Common", "Floral", 6, 0, 24, 0)
add("BoneChunk", "Bone Chunk", "Grasslands", "Feed", "Uncommon", "Mineral", 8, 50, 17, 0)
add("PrimeMeat", "Prime Meat", "Grasslands", "Feed", "Rare", "Flesh", 12, 120, 10, 0.02)
add("WildHerbs", "Wild Herbs", "Grasslands", "Feed", "Rare", "Floral", 12, 200, 7, 0.02)
add("GiantRib", "Giant Rib", "Grasslands", "Feed", "Epic", "Flesh", 18, 350, 4.5, 0.05)
add("AncientBone", "Ancient Bone", "Grasslands", "Feed", "Epic", "Mineral", 18, 500, 2.5, 0.08)
add("PrimalCatalyst", "Primal Catalyst", "Grasslands", "Catalyst", "Legendary", "Neutral", 30, 1000, 1, 0.10, "Primal")
add("SmallFish", "Small Fish", "Swamp", "Feed", "Uncommon", "Flesh", 22, 1500, 32, 0.05)
add("RottenMeat", "Rotten Meat", "Swamp", "Feed", "Rare", "Flesh", 28, 2200, 23, 0.05)
add("SporePod", "Spore Pod", "Swamp", "Feed", "Rare", "Floral", 30, 3000, 17, 0.06)
add("SwampMushroom", "Swamp Mushroom", "Swamp", "Feed", "Epic", "Floral", 38, 4500, 11, 0.08)
add("VenomSac", "Venom Sac", "Swamp", "Feed", "Epic", "Flesh", 45, 6500, 8, 0.10, "Toxin")
add("BogMarrow", "Bog Marrow", "Swamp", "Feed", "Legendary", "Flesh + Mineral", 55, 9000, 5, 0.12)
add("MutantLeech", "Mutant Leech", "Swamp", "Feed", "Mythic", "Neutral", 70, 14000, 3, 0.14, "MutationRoll")
add("ToxicCatalyst", "Toxic Catalyst", "Swamp", "Catalyst", "Cosmic", "Neutral", 100, 25000, 1, 0.18, "Toxic")
add("WildFruit", "Wild Fruit", "Jungle", "Feed", "Rare", "Floral", 75, 25000, 30, 0.08)
add("GiantBeetle", "Giant Beetle", "Jungle", "Feed", "Rare", "Flesh", 80, 35000, 23, 0.08)
add("RareFlower", "Rare Flower", "Jungle", "Feed", "Epic", "Floral", 95, 50000, 18, 0.10)
add("ProteinRoot", "Protein Root", "Jungle", "Feed", "Legendary", "Flesh + Floral", 110, 75000, 12, 0.12)
add("GoldenBanana", "Golden Banana", "Jungle", "Feed", "Legendary", "Floral", 125, 100000, 8, 0.13)
add("RoyalJelly", "Royal Jelly", "Jungle", "Feed", "Mythic", "Neutral", 150, 150000, 5, 0.15)
add("BeastHeart", "Beast Heart", "Jungle", "Feed", "Mythic", "Flesh", 180, 225000, 3, 0.18)
add("JungleHeart", "Jungle Heart", "Jungle", "Catalyst", "Secret", "Neutral", 250, 350000, 1, 0.22, "Beast")
add("CrystalShard", "Crystal Shard", "CrystalCave", "Feed", "Rare", "Mineral", 250, 350000, 29, 0.10)
add("FossilMarrow", "Fossil Marrow", "CrystalCave", "Feed", "Epic", "Flesh + Mineral", 300, 500000, 23, 0.12)
add("MineralCore", "Mineral Core", "CrystalCave", "Feed", "Legendary", "Mineral", 375, 750000, 18, 0.15)
add("LivingGeode", "Living Geode", "CrystalCave", "Feed", "Legendary", "Mineral", 450, 1000000, 13, 0.18)
add("PrismaticCrystal", "Prismatic Crystal", "CrystalCave", "Feed", "Mythic", "Mineral", 550, 1500000, 9, 0.20)
add("FossilHeart", "Fossil Heart", "CrystalCave", "Feed", "Cosmic", "Flesh + Mineral", 700, 2500000, 5, 0.24)
add("CrystalCore", "Crystal Core", "CrystalCave", "Feed", "Cosmic", "Mineral", 850, 4000000, 2.5, 0.28)
add("CrystalCatalyst", "Crystal Catalyst", "CrystalCave", "Catalyst", "Secret", "Neutral", 1200, 6000000, 0.5, 0.32, "Crystal")
add("CharredMeat", "Charred Meat", "Volcano", "Feed", "Epic", "Flesh", 1000, 6000000, 37.51, 0.18)
add("MagmaStone", "Magma Stone", "Volcano", "Feed", "Legendary", "Mineral", 1200, 8000000, 26.27, 0.20)
add("EmberHeart", "Ember Heart", "Volcano", "Feed", "Legendary", "Flesh", 1500, 12000000, 16.83, 0.22)
add("DragonScale", "Dragon Scale", "Volcano", "Feed", "Mythic", "Mineral", 1800, 18000000, 13.96, 0.25)
add("DragonMeat", "Dragon Meat", "Volcano", "Feed", "Cosmic", "Flesh", 2400, 30000000, 4.36, 0.30)
add("FireCore", "Fire Core", "Volcano", "Catalyst", "Secret", "Neutral", 3200, 50000000, 0.74, 0.35, "Fire")
add("DragonBlood", "Dragon Blood", "Volcano", "Catalyst", "Eternal", "Neutral", 4500, 80000000, 0.31, 0.40, "Draconic")
add("InfernoCatalyst", "Inferno Catalyst", "Volcano", "Catalyst", "Divine", "Neutral", 7000, 150000000, 0.02, 0.50, "Inferno")
-- Future-only definitions are disabled and cannot enter launch pools.
add("GiantSerum", "Giant Serum", "FutureEvent", "Catalyst", "Mythic", "Neutral", 0, 0, 0, 0, "Titan", false)
add("SpiritEnergy", "Spirit Energy", "FutureEvent", "Catalyst", "Cosmic", "Neutral", 0, 0, 0, 0, "Spirit", false)
add("CyberCore", "Cyber Core", "FutureEvent", "Catalyst", "Cosmic", "Neutral", 0, 0, 0, 0, "Cyber", false)
add("VoidEssence", "Void Essence", "FutureEvent", "Catalyst", "Secret", "Neutral", 0, 0, 0, 0, "Void", false)
add("BloodMoonShard", "Blood Moon Shard", "FutureEvent", "Catalyst", "Mythic", "Neutral", 0, 0, 0, 0, "BloodMoon", false)
add("CelestialCore", "Celestial Core", "FutureEvent", "Catalyst", "Eternal", "Neutral", 0, 0, 0, 0, "Celestial", false)
function Definitions.get(id: string): Types.ResourceDefinition? return all[id] end
function Definitions.getAll(): { [string]: Types.ResourceDefinition } return all end
return Definitions
