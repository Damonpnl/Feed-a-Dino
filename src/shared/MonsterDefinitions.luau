--!strict

local MonsterDefinitions = {}

export type EvolutionOption = {
	Result: string,
	Requirements: { [string]: number },
	Catalyst: string?,
	Family: string?,
}

export type MonsterDefinition = {
	Id: string,
	DisplayName: string,
	BaseMultiplier: number,
	GrowthRequired: number,
	Rarity: string,
	Color: Color3,
	Evolutions: { EvolutionOption },
}

local monsters: { [string]: MonsterDefinition } = {
	ProtoRex = {
		Id = "ProtoRex",
		DisplayName = "Proto Rex",
		BaseMultiplier = 1,
		GrowthRequired = 50,
		Rarity = "Common",
		Color = Color3.fromRGB(150, 140, 90),
		Evolutions = {
			{ Result = "Fangling", Requirements = { Flesh = 40 } },
			{ Result = "Mossback", Requirements = { Flora = 40 } },
			{ Result = "Stonehide", Requirements = { Mineral = 40 } },
		},
	},
	Fangling = {
		Id = "Fangling",
		DisplayName = "Fangling",
		BaseMultiplier = 1.5,
		GrowthRequired = 80,
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
		GrowthRequired = 80,
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
		GrowthRequired = 80,
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
		GrowthRequired = 160,
		Rarity = "Epic",
		Color = Color3.fromRGB(220, 70, 20),
		Evolutions = {},
	},
	CrystalWolf = {
		Id = "CrystalWolf",
		DisplayName = "Crystal Wolf",
		BaseMultiplier = 2.5,
		GrowthRequired = 160,
		Rarity = "Epic",
		Color = Color3.fromRGB(160, 220, 255),
		Evolutions = {},
	},
	SpiritDragon = {
		Id = "SpiritDragon",
		DisplayName = "Spirit Dragon",
		BaseMultiplier = 3,
		GrowthRequired = 200,
		Rarity = "Legendary",
		Color = Color3.fromRGB(170, 255, 210),
		Evolutions = {},
	},
}

function MonsterDefinitions.get(id: string): MonsterDefinition?
	return monsters[id]
end

return MonsterDefinitions
