--!strict
-- Locked multiplier ladder. Phase 5A prices are explicitly PROVISIONAL_BALANCE.
local Trainers = {}
export type TrainerDefinition = {Id: string, DisplayName: string, Tier: number, Rarity: string, Multiplier: number, Price: number?, Purchasable: boolean}
local ordered: {TrainerDefinition} = {
	{Id="TrainingMat",DisplayName="Training Mat",Tier=1,Rarity="Common",Multiplier=2,Purchasable=false},
	{Id="WeightedSled",DisplayName="Weighted Sled",Tier=2,Rarity="Uncommon",Multiplier=5,Purchasable=false},
	{Id="IronRig",DisplayName="Iron Rig",Tier=3,Rarity="Rare",Multiplier=12,Purchasable=false},
	{Id="PowerCage",DisplayName="Power Cage",Tier=4,Rarity="Epic",Multiplier=30,Purchasable=false},
	{Id="GoldenGym",DisplayName="Golden Gym",Tier=5,Rarity="Legendary",Multiplier=80,Purchasable=false},
	{Id="GravityChamber",DisplayName="Gravity Chamber",Tier=6,Rarity="Mythic",Multiplier=100,Purchasable=false},
	{Id="CosmicReactor",DisplayName="Cosmic Reactor",Tier=7,Rarity="Cosmic",Multiplier=200,Purchasable=false},
	{Id="AbyssChamber",DisplayName="Abyss Chamber",Tier=8,Rarity="Secret",Multiplier=500,Purchasable=false},
	{Id="EternalForge",DisplayName="Eternal Forge",Tier=9,Rarity="Eternal",Multiplier=1000,Purchasable=false},
	{Id="DivineReactor",DisplayName="Divine Reactor",Tier=10,Rarity="Divine",Multiplier=2000,Purchasable=false},
}
local byId: {[string]: TrainerDefinition} = {}
local provisionalPrices = {0,25,100,250,500,1000,2000,4000,8000,16000}
Trainers.PriceStatus = "PROVISIONAL_BALANCE"
for index,definition in ordered do
	definition.Price=provisionalPrices[index]
	definition.Purchasable=index>1
end
for _, definition in ordered do assert(not byId[definition.Id], "Duplicate trainer ID") byId[definition.Id] = definition end
function Trainers.get(id: string): TrainerDefinition? return byId[id] end
function Trainers.getOrdered(): {TrainerDefinition} return ordered end
-- Existing prototype behavior retained without reinterpreting saved TrainingLevel as a tier.
Trainers.Legacy = {BaseGain=5, GainPerLevel=2, UpgradeCostPerLevel=25, TrainCooldown=0.8}
function Trainers.legacyCost(level: number): number return Trainers.Legacy.UpgradeCostPerLevel * (level + 1) end
function Trainers.legacyGain(level: number, petMultiplier: number): number
	return math.max(1, math.floor(Trainers.Legacy.BaseGain * petMultiplier) + level * Trainers.Legacy.GainPerLevel)
end
return Trainers
