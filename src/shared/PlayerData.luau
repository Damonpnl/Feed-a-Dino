--!strict

local PlayerData = {}
local Evolution = require(script.Parent.EvolutionCalculator)

export type MonsterRecord = {
	Species: string,
	Growth: number,
	TotalGrowth: number,
	Revision: number,
	Stage: number,
	EvolutionHistory: {any},
	Flesh: number,
	Flora: number,
	Mineral: number,
	Mutations: { string },
	Rarity: string,
	EvolutionFamilies: { [string]: boolean },
	PetId: string?, EvolutionForm: string?, EvolutionVersion: number?, GrowthReserve: number?,
	Lineage: string?, LineageTags: {[string]: boolean}?, PendingEvolution: any?,
	LatentTraits: {[string]: boolean}?, SpecialEvolutions: {[string]: boolean}?,
	Ascension: any?, Awakened: boolean?, Awakening: any?, Qualifications: {[string]: boolean}?,
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

-- Preserve fields owned by other versions/systems, including inventories and entitlements.
function PlayerData.copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = PlayerData.copy(item) end
	return result
end

function PlayerData.createMonster(species: string, rarity: string?): MonsterRecord
	local record = {
		Species = species,
		Growth = 0,
		TotalGrowth = 0,
		Revision = 0,
		Stage = 0,
		EvolutionHistory = {},
		Flesh = 0,
		Flora = 0,
		Mineral = 0,
		Mutations = {},
		EvolutionFamilies = {},
		Rarity = if rarity ~= nil then rarity else "Common",
	}
	Evolution.initialize(record,species)
	return record
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
	for key, value in raw do (data :: any)[key] = PlayerData.copy(value) end
	data.BaseUpgrades = if type(raw.BaseUpgrades) == "table" then PlayerData.copy(raw.BaseUpgrades) else {TrainingLevel=0}
	data.Stats = if type(raw.Stats) == "table" then PlayerData.copy(raw.Stats) else {Feeds=0,Evolutions=0,Trainings=0}
	data.DiscoveredAreas = if type(raw.DiscoveredAreas) == "table" then PlayerData.copy(raw.DiscoveredAreas) else {Grasslands=true}
	data.EquippedMonster = STARTER

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
					Species = if type(record.Species)=="string" then record.Species else species,
					Growth = math.max(0, finiteNumber(record.Growth, 0)),
					-- Historical pre-migration Growth spent on evolution is unknowable.
					TotalGrowth = math.max(0, finiteNumber(record.Growth, 0), finiteNumber(record.TotalGrowth, 0)),
					Revision = math.max(0, math.floor(finiteNumber(record.Revision, 0))),
					Stage = math.max(0, math.floor(finiteNumber(record.Stage, 0))),
					EvolutionHistory = if type(record.EvolutionHistory) == "table" then PlayerData.copy(record.EvolutionHistory) else {},
					Flesh = math.max(0, finiteNumber(record.Flesh, 0)),
					Flora = math.max(0, finiteNumber(record.Flora, 0)),
					Mineral = math.max(0, finiteNumber(record.Mineral, 0)),
					Mutations = mutations,
					EvolutionFamilies = {},
					Rarity = if typeof(record.Rarity) == "string" then record.Rarity else "Common",
				}
				for key, value in record do
					if (data.Monsters[species] :: any)[key] == nil then (data.Monsters[species] :: any)[key] = PlayerData.copy(value) end
				end
				if typeof(record.EvolutionFamilies) == "table" then
					for family, unlocked in record.EvolutionFamilies do
						if typeof(family) == "string" and unlocked == true then data.Monsters[species].EvolutionFamilies[family] = true end
					end
				end
				Evolution.initialize(data.Monsters[species],species)
			end
		end
	end

	if data.Monsters[data.EquippedMonster] == nil then
		data.EquippedMonster = STARTER
		if data.Monsters[STARTER] == nil then
			data.Monsters[STARTER] = PlayerData.createMonster(STARTER, "Common")
		end
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
