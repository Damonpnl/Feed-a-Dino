--!strict
local Definitions = require(script.Parent.ResourceDefinitions)
local AreaDefinitions = {}
export type PoolEntry = { Id: string, SpawnWeight: number }
export type AreaDefinition = {
	Id: string, DisplayName: string, Order: number, ZoneName: string,
	Guardian: string, GuardianDisplayName: string, ResourcePool: { PoolEntry },
}
local ordered: { AreaDefinition } = {}
local areas: { [string]: AreaDefinition } = {}
local function area(id: string, display: string, guardian: string, guardianDisplay: string, ids: { string })
	local pool = {}
	for _, resourceId in ids do
		local definition = Definitions.get(resourceId)
		assert(definition, resourceId)
		table.insert(pool, { Id = resourceId, SpawnWeight = definition.SpawnWeight })
	end
	local definition = {
		Id = id, DisplayName = display, Order = #ordered + 1, ZoneName = id,
		Guardian = guardian, GuardianDisplayName = guardianDisplay, ResourcePool = pool,
	}
	areas[id] = definition
	table.insert(ordered, definition)
end
area("Grasslands", "Grasslands", "TRex", "T-Rex", {"RawMeat", "Berries", "BoneChunk", "PrimeMeat", "WildHerbs", "GiantRib", "AncientBone", "PrimalCatalyst"})
area("Swamp", "Swamp", "Crocodile", "Giant Crocodile", {"SmallFish", "RottenMeat", "SporePod", "SwampMushroom", "VenomSac", "BogMarrow", "MutantLeech", "ToxicCatalyst"})
area("Jungle", "Jungle", "Gorilla", "Giant Gorilla", {"WildFruit", "GiantBeetle", "RareFlower", "ProteinRoot", "GoldenBanana", "RoyalJelly", "BeastHeart", "JungleHeart"})
area("CrystalCave", "Crystal Cave", "Triceratops", "Armored Triceratops", {"CrystalShard", "FossilMarrow", "MineralCore", "LivingGeode", "PrismaticCrystal", "FossilHeart", "CrystalCore", "CrystalCatalyst"})
area("Volcano", "Volcano", "Dragon", "Dragon", {"CharredMeat", "MagmaStone", "EmberHeart", "DragonScale", "DragonMeat", "FireCore", "DragonBlood", "InfernoCatalyst"})
function AreaDefinitions.get(id: string): AreaDefinition? return areas[id] end
function AreaDefinitions.getOrdered(): { AreaDefinition } return ordered end
return AreaDefinitions
