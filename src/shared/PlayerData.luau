--!strict

local PlayerData = {}

export type MonsterRecord = {
	Species: string,
	Growth: number,
	Flesh: number,
	Flora: number,
	Mineral: number,
	Mutations: { string },
	Rarity: string,
	EvolutionFamilies: { [string]: boolean },
}

export type SaveData = {
	Cash: number,
	Power: number,
	EquippedMonster: string,
	Monsters: { [string]: MonsterRecord },
	BaseUpgrades: {
		TrainingLevel: number,
	},
	DiscoveredAreas: { [string]: boolean },
	Stats: {
		Feeds: number,
		Evolutions: number,
		Trainings: number,
	},
}

local STARTER = "ProtoRex"

function PlayerData.createMonster(species: string, rarity: string?): MonsterRecord
	return {
		Species = species,
		Growth = 0,
		Flesh = 0,
		Flora = 0,
		Mineral = 0,
		Mutations = {},
		EvolutionFamilies = {},
		Rarity = if rarity ~= nil then rarity else "Common",
	}
end

function PlayerData.default(): SaveData
	return {
		Cash = 0,
		Power = 0,
		EquippedMonster = STARTER,
		Monsters = {
			[STARTER] = PlayerData.createMonster(STARTER, "Common"),
		},
		BaseUpgrades = {
			TrainingLevel = 0,
		},
		DiscoveredAreas = {
			Grasslands = true,
		},
		Stats = {
			Feeds = 0,
			Evolutions = 0,
			Trainings = 0,
		},
	}
end

local function finiteNumber(value: any, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

function PlayerData.normalize(raw: any): SaveData
	local data = PlayerData.default()
	if typeof(raw) ~= "table" then
		return data
	end

	data.Cash = math.max(0, finiteNumber(raw.Cash, 0))
	data.Power = math.max(0, finiteNumber(raw.Power, 0))

	if typeof(raw.EquippedMonster) == "string" and raw.EquippedMonster ~= "" then
		data.EquippedMonster = raw.EquippedMonster
	end

	data.Monsters = {}
	if typeof(raw.Monsters) == "table" then
		for species, record in raw.Monsters do
			if typeof(species) == "string" and typeof(record) == "table" then
				local mutations: { string } = {}
				if typeof(record.Mutations) == "table" then
					for _, mutation in record.Mutations do
						if typeof(mutation) == "string" then
							table.insert(mutations, mutation)
						end
					end
				end
				data.Monsters[species] = {
					Species = species,
					Growth = math.max(0, finiteNumber(record.Growth, 0)),
					Flesh = math.max(0, finiteNumber(record.Flesh, 0)),
					Flora = math.max(0, finiteNumber(record.Flora, 0)),
					Mineral = math.max(0, finiteNumber(record.Mineral, 0)),
					Mutations = mutations,
					EvolutionFamilies = {},
					Rarity = if typeof(record.Rarity) == "string" then record.Rarity else "Common",
				}
				if typeof(record.EvolutionFamilies) == "table" then
					for family, unlocked in record.EvolutionFamilies do
						if typeof(family) == "string" and unlocked == true then data.Monsters[species].EvolutionFamilies[family] = true end
					end
				end
			end
		end
	end

	if data.Monsters[data.EquippedMonster] == nil then
		data.EquippedMonster = STARTER
		data.Monsters[STARTER] = PlayerData.createMonster(STARTER, "Common")
	end

	if typeof(raw.BaseUpgrades) == "table" then
		data.BaseUpgrades.TrainingLevel = math.max(0, math.floor(finiteNumber(raw.BaseUpgrades.TrainingLevel, 0)))
	end

	if typeof(raw.DiscoveredAreas) == "table" then
		for areaId, discovered in raw.DiscoveredAreas do
			if typeof(areaId) == "string" and discovered == true then
				data.DiscoveredAreas[areaId] = true
			end
		end
	end

	if typeof(raw.Stats) == "table" then
		data.Stats.Feeds = math.max(0, math.floor(finiteNumber(raw.Stats.Feeds, 0)))
		data.Stats.Evolutions = math.max(0, math.floor(finiteNumber(raw.Stats.Evolutions, 0)))
		data.Stats.Trainings = math.max(0, math.floor(finiteNumber(raw.Stats.Trainings, 0)))
	end

	return data
end

return PlayerData
