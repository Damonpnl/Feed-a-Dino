--!nonstrict

local MonsterDefinitions = {}
local Stages = require(script.Parent.GrowthStageDefinitions)

export type EvolutionOption = {
	Result: string,
	Requirements: { [string]: number },
	Catalyst: string?,
	Family: string?,
	Id: string?, Source: string?, SourceStage: number?, TargetStage: number?, Growth: number?,
	Dominant: string?, Fallback: boolean?, Locked: boolean?,
	RequiredLineage: string?, RequiredTags: {string}?, RequiredMutations: {string}?,
	MinRarity: string?, Probability: number?, Presentation: any?,
	RarityRule: string?, AscensionId: string?,
}

export type MonsterDefinition = {
	Id: string,
	DisplayName: string,
	BaseMultiplier: number,
	IncomeMultiplier: number?, TrainingMultiplier: number?,
	GrowthRequired: number,
	Rarity: string,
	Color: Color3,
	Evolutions: { EvolutionOption },
	Stage: number?, Lineage: string?, Visual: any?,
}

local monsters: { [string]: MonsterDefinition } = {
	ProtoRex = {
		Id = "ProtoRex",
		DisplayName = "Proto Rex",
		BaseMultiplier = 1,
		GrowthRequired = Stages.Stages[0].GrowthRequired,
		Rarity = "Common",
		Color = Color3.fromRGB(150, 140, 90),
		Evolutions = {
			{ Result = "Fangling", Requirements = { Flesh = Stages.Stages[0].AffinityRequired } },
			{ Result = "Mossback", Requirements = { Flora = Stages.Stages[0].AffinityRequired } },
			{ Result = "Stonehide", Requirements = { Mineral = Stages.Stages[0].AffinityRequired } },
		},
	},
	Fangling = {
		Id = "Fangling",
		DisplayName = "Fangling",
		BaseMultiplier = 1.5,
		GrowthRequired = Stages.Stages[1].GrowthRequired,
		Rarity = "Uncommon",
		Color = Color3.fromRGB(180, 70, 50),
		Evolutions = {
			{
				Result = "MagmaRex",
				Requirements = { Flesh = 80 },
				Catalyst = "FireCatalyst",
				Family = "Fire",
			},
		},
	},
	Mossback = {
		Id = "Mossback",
		DisplayName = "Mossback",
		BaseMultiplier = 1.5,
		GrowthRequired = Stages.Stages[1].GrowthRequired,
		Rarity = "Uncommon",
		Color = Color3.fromRGB(60, 130, 70),
		Evolutions = {
			{
				Result = "SpiritDragon",
				Requirements = { Flora = 80 },
				Catalyst = "SpiritEssence",
				Family = "Spirit",
			},
		},
	},
	Stonehide = {
		Id = "Stonehide",
		DisplayName = "Stonehide",
		BaseMultiplier = 1.5,
		GrowthRequired = Stages.Stages[1].GrowthRequired,
		Rarity = "Uncommon",
		Color = Color3.fromRGB(140, 140, 150),
		Evolutions = {
			{
				Result = "CrystalWolf",
				Requirements = { Mineral = 80 },
				Catalyst = "CrystalCatalyst",
				Family = "Crystal",
			},
		},
	},
	MagmaRex = {
		Id = "MagmaRex",
		DisplayName = "Magma T-Rex",
		BaseMultiplier = 2.5,
		GrowthRequired = Stages.Stages[2].GrowthRequired,
		Rarity = "Epic",
		Color = Color3.fromRGB(220, 70, 20),
		Evolutions = {},
	},
	CrystalWolf = {
		Id = "CrystalWolf",
		DisplayName = "Crystal Wolf",
		BaseMultiplier = 2.5,
		GrowthRequired = Stages.Stages[2].GrowthRequired,
		Rarity = "Epic",
		Color = Color3.fromRGB(160, 220, 255),
		Evolutions = {},
	},
	SpiritDragon = {
		Id = "SpiritDragon",
		DisplayName = "Spirit Dragon",
		BaseMultiplier = 3,
		GrowthRequired = Stages.FormOverrides.SpiritDragon,
		Rarity = "Legendary",
		Color = Color3.fromRGB(170, 255, 210),
		Evolutions = {},
	},
}

-- Existing stable form IDs and their metadata remain intact. New forms are
-- placeholders within this one lineage, not new independently awarded pets.
local legacyStages = {ProtoRex=0,Fangling=1,Mossback=1,Stonehide=1,MagmaRex=2,CrystalWolf=2,SpiritDragon=2}
local additions = {
	{"JuvenileRex","Juvenile Rex",1,1.5,Color3.fromRGB(150,140,90)},
	{"MatureRex","Mature Rex",2,2.5,Color3.fromRGB(155,125,75)},
	{"ArmoredRex","Armored Rex",2,2.5,Color3.fromRGB(130,110,100)},
	{"VenomRex","Venom Rex",2,2.5,Color3.fromRGB(95,145,70)},
	{"CrystalMossRex","Crystal Moss Rex",2,2.5,Color3.fromRGB(90,180,170)},
	{"PrimalRex","Primal Rex (placeholder)",2,2.5,Color3.fromRGB(145,70,45)},
	{"ToxicRex","Toxic Rex (placeholder)",2,2.5,Color3.fromRGB(130,170,45)},
	{"AlphaRex","Alpha Rex (placeholder)",2,2.5,Color3.fromRGB(165,105,45)},
	{"DraconicRex","Draconic Rex (placeholder)",2,2.5,Color3.fromRGB(170,60,80)},
	{"InfernoRex","Inferno Rex (placeholder)",2,2.5,Color3.fromRGB(245,100,20)},
	{"ApexRex","Apex Rex",3,2.5,Color3.fromRGB(170,110,65)},
	{"AscendedRex","Ascended Rex",4,2.5,Color3.fromRGB(210,185,110)},
	{"MythicRex","Mythic Ascension Rex (locked)",5,2.5,Color3.fromRGB(200,160,240)},
}
for _, row in additions do
	monsters[row[1]] = {Id=row[1],DisplayName=row[2],Stage=row[3],BaseMultiplier=row[4],
		GrowthRequired=Stages.Stages[row[3]].GrowthRequired,Rarity="Common",Color=row[5],Evolutions={}}
end
for id, definition in monsters do
	definition.Stage = definition.Stage or legacyStages[id]
	definition.GrowthRequired = Stages.FormOverrides[id] or Stages.Stages[definition.Stage].GrowthRequired
	definition.Lineage = "ProtoRex"
	-- Phase 5 metadata; preserve every existing multiplier, no new bonuses.
	definition.IncomeMultiplier = definition.BaseMultiplier
	definition.TrainingMultiplier = definition.BaseMultiplier
	definition.Visual = {ModelKey="Placeholder",Scale=Stages.Stages[definition.Stage].Scale}
end
for _, branch in monsters.ProtoRex.Evolutions do
	for affinity in branch.Requirements do branch.Dominant=affinity end
end
table.insert(monsters.ProtoRex.Evolutions,{Result="JuvenileRex",Requirements={},Fallback=true})
-- PROVISIONAL_BALANCE: hybrid minima of 80 each. Nonzero alone never qualifies.
for _, id in {"Fangling","Mossback","Stonehide","JuvenileRex"} do
	local edges = monsters[id].Evolutions
	table.insert(edges,{Result="MatureRex",Requirements={},Fallback=true})
	table.insert(edges,{Result="ArmoredRex",Requirements={Flesh=80,Mineral=80}})
	table.insert(edges,{Result="VenomRex",Requirements={Flesh=80,Flora=80}})
	table.insert(edges,{Result="CrystalMossRex",Requirements={Flora=80,Mineral=80}})
	-- PROVISIONAL: reuse the existing Stage-1 minima/multipliers, not final balance.
	for _,example in {
		{"PrimalRex","Primal",{Flesh=80}}, {"ToxicRex","Toxic",{Flora=80}},
		{"AlphaRex","Beast",{Flesh=80}}, {"DraconicRex","Draconic",{Flesh=80,Mineral=80}},
		{"InfernoRex","Inferno",{Flesh=80}},
	} do
		table.insert(edges,{Result=example[1],Family=example[2],Requirements=example[3]})
	end
end
for _, definition in monsters do
	if definition.Stage==2 then table.insert(definition.Evolutions,{Result="ApexRex",Requirements={}}) end
end
monsters.ApexRex.Evolutions = {{Result="AscendedRex",Requirements={}}}
monsters.AscendedRex.Evolutions = {{Result="MythicRex",Requirements={},Locked=true,AscensionId="ProtoRexMythic"}}
for id, definition in monsters do
	for _, branch in definition.Evolutions do
		branch.Id = id .. ":" .. branch.Result
		branch.Source,branch.SourceStage = id,definition.Stage
		branch.TargetStage = monsters[branch.Result].Stage
		branch.Growth = definition.GrowthRequired
		branch.RequiredLineage = "ProtoRex"
		branch.RarityRule = "Keep"
	end
end
MonsterDefinitions.LegacyStages = legacyStages

function MonsterDefinitions.get(id: string): MonsterDefinition?
	return monsters[id]
end

function MonsterDefinitions.getAll(): {[string]: MonsterDefinition} return monsters end
-- Historic IDs remain accepted by existing saves/tests; these are aliases, not launch resources.
MonsterDefinitions.CatalystAliases = {FireCatalyst="FireCore",SpiritEssence="SpiritEnergy"}

return MonsterDefinitions
