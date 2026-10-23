--!strict
-- Pure allowlist for the Studio developer panel. This module grants nothing.
-- The server still requires RunService:IsStudio(), DevTestConfig.Enabled, a writable
-- StudioMemory session, and the RemoteFunction's player argument.
local EconomyConfig = require(script.Parent.EconomyConfig)
local Areas = require(script.Parent.AreaDefinitions)
local Resources = require(script.Parent.ResourceDefinitions)
local Monsters = require(script.Parent.MonsterDefinitions)
local Mutations = require(script.Parent.MutationDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Trainers = require(script.Parent.TrainerDefinitions)
local Effects = require(script.Parent.SpecialEffectDefinitions)

local Protocol = {}

local POWER = {
	["0"] = 0, ["1K"] = 1000, ["10K"] = 10000, ["100K"] = 100000, ["350K"] = 350000,
	["1M"] = 1000000, ["6M"] = 6000000, ["10M"] = 10000000, ["100M"] = 100000000, ["150M"] = 150000000,
}
local SPEED = { [16] = true, [18] = true, [20] = true, [22] = true, [26] = true, [30] = true, [32] = true }
local SCENARIOS = {
	Fresh = true, FirstEvolution = true, Swamp = true, Jungle = true,
	CrystalCave = true, Volcano = true, Catalyst = true, MaxTraining = true,
}
local GUARDIAN_KINDS = { Ordinary = true, Heavy = true, Cursed = true, Close = true, Long = true }
local RESOURCE_KINDS = { Ordinary = true, Heavy = true, Cursed = true }
local POSITIONS = { Near = true, Middle = true, Far = true }
local TRAVEL_RESULTS = { Escape = true, Catch = true, Hazard = true, Incomplete = true }
local CONFIRM = { Scenario = true, ResetPet = true, ResetTrainer = true, ResetResources = true, TravelScripted = true }

local function finite(value: any, maximum: number?): boolean
	return type(value) == "number" and value == value and value >= 0 and value <= (maximum or EconomyConfig.MaxNumber)
end
local function text(value: any, limit: number): boolean
	return type(value) == "string" and #value > 0 and #value <= limit
end
local function area(value: any): boolean
	return text(value, 32) and Areas.get(value) ~= nil
end
local function resource(value: any): boolean
	if not text(value, 64) then return false end
	local definition = Resources.get(value)
	return definition ~= nil and definition.Launch == true
end

function Protocol.allowed(isStudio: any, enabled: any, userId: any, runners: any): boolean
	if isStudio ~= true or enabled ~= true or type(userId) ~= "number" then return false end
	if type(runners) ~= "table" then return false end
	local restricted = false
	for _, id in runners do
		restricted = true
		if id == userId then return true end
	end
	return not restricted
end

function Protocol.presets(): { [string]: any }
	local power, speed = {}, {}
	for id, value in POWER do table.insert(power, { Id = id, Value = value }) end
	table.sort(power, function(a, b) return a.Value < b.Value end)
	for value in SPEED do table.insert(speed, value) end
	table.sort(speed)
	return { Power = power, Speed = speed }
end

local function clean(command: string, args: any): (boolean, any)
	if args == nil then args = {} end
	if type(args) ~= "table" then return false, "Arguments must be a table" end
	if CONFIRM[command] and args.Confirm ~= true then return false, "Confirm the action" end
	if command == "Status" or command == "Snapshot" or command == "Catalog"
		or command == "ResetPower" or command == "ResetCash" or command == "CashForNext"
		or command == "ClearOverrides" or command == "ResetCharacter" or command == "DropCarry"
		or command == "ClearCarry" or command == "FeedPreview" or command == "StopTraining"
		or command == "StartTraining" or command == "BuyTrainer" or command == "ResetGuardians"
		or command == "ResetScenario" or command == "TravelCancel" or command == "TravelClear" or command == "TravelExport"
		or command == "ResetPet" or command == "ResetTrainer" or command == "ResetResources" then
		return true, {}
	end
	if command == "SetPower" or command == "SetCash" then
		if text(args.Preset, 8) then
			local value = POWER[args.Preset]
			if command == "SetCash" or value == nil then return false, "Unknown preset" end
			return true, { Value = value }
		end
		if not finite(args.Value) then return false, "Value must be a finite number" end
		return true, { Value = args.Value }
	end
	if command == "AddPower" or command == "AddCash" or command == "SetGrowth" then
		if not finite(args.Value) then return false, "Value must be a finite number" end
		return true, { Value = args.Value }
	end
	if command == "SetSlowMode" then
		if type(args.Enabled) ~= "boolean" then return false, "Enabled must be true or false" end
		return true, { Enabled = args.Enabled }
	end
	if command == "SetSpeedOverride" then
		if args.Speed == nil then return true, { Speed = nil } end
		if not SPEED[args.Speed] then return false, "Speed is not a test preset" end
		return true, { Speed = args.Speed }
	end
	if command == "SetSeed" then
		if type(args.Seed) ~= "number" or args.Seed % 1 ~= 0 or args.Seed < 0 or args.Seed > 1000000000 then
			return false, "Seed must be an integer from 0 to 1000000000"
		end
		return true, { Seed = args.Seed }
	end
	if command == "SelectPet" or command == "CreatePet" then
		if not text(args.Id, 64) or not Monsters.get(args.Id) then return false, "Unknown pet form" end
		return true, { Id = args.Id }
	end
	if command == "SetStage" then
		if type(args.Stage) ~= "number" or args.Stage % 1 ~= 0 or args.Stage < 0 or args.Stage > 5 then
			return false, "Stage must be 0 through 5"
		end
		return true, { Stage = args.Stage, Override = args.Override == true }
	end
	if command == "SetAffinities" then
		if not finite(args.Flesh) or not finite(args.Flora) or not finite(args.Mineral) then
			return false, "Affinities must be finite numbers"
		end
		return true, { Flesh = args.Flesh, Flora = args.Flora, Mineral = args.Mineral }
	end
	if command == "SetRarity" then
		if not text(args.Rarity, 32) or not Rarities.isValid(args.Rarity) then return false, "Unknown rarity" end
		return true, { Rarity = args.Rarity }
	end
	if command == "ApplyEvolution" then
		if args.BranchId ~= nil and not text(args.BranchId, 160) then return false, "Invalid branch" end
		return true, { BranchId = args.BranchId }
	end
	if command == "AddMutation" or command == "RemoveMutation" then
		local definition = text(args.Id, 32) and Mutations.get(args.Id)
		if not definition or definition.Kind ~= "Overlay" then return false, "Unknown mutation overlay" end
		return true, { Id = args.Id }
	end
	if command == "SetFamily" then
		local effect = text(args.Id, 32) and Effects[args.Id]
		if not effect or effect.Kind ~= "EvolutionFamily" then return false, "Unknown catalyst family" end
		if type(args.Enabled) ~= "boolean" then return false, "Enabled must be true or false" end
		return true, { Id = args.Id, Enabled = args.Enabled }
	end
	if command == "SpawnResource" or command == "GiveResource" then
		if not area(args.Area) or not resource(args.Resource) then return false, "Unknown launch resource" end
		if Resources.get(args.Resource).Area ~= args.Area then return false, "Resource is not from that biome" end
		return true, { Area = args.Area, Resource = args.Resource }
	end
	if command == "GivePreset" then
		if args.Id ~= "RawMeat" and args.Id ~= "AncientBone" and args.Id ~= "Hybrid"
			and args.Id ~= "Catalyst" and args.Id ~= "Evolution" then
			return false, "Unknown item shortcut"
		end
		return true, { Id = args.Id }
	end
	if command == "FeedConfirm" then
		if not text(args.Ticket, 64) then return false, "Invalid feed ticket" end
		return true, { Ticket = args.Ticket }
	end
	if command == "SetTrainerTier" then
		if not finite(args.Tier, #Trainers.getOrdered()) or args.Tier % 1 ~= 0 or args.Tier < 1 then
			return false, "Trainer tier is out of range"
		end
		return true, { Tier = args.Tier }
	end
	if command == "Teleport" or command == "CatchRecovery" or command == "TwoCarriers" then
		if not area(args.Area) then return false, "Unknown biome" end
		return true, { Area = args.Area }
	end
	if command == "GuardianScenario" then
		if not area(args.Area) or not GUARDIAN_KINDS[args.Kind] then return false, "Unknown guardian scenario" end
		local resourceKind = args.ResourceKind or "Ordinary"
		if not RESOURCE_KINDS[resourceKind] then return false, "Unknown resource kind" end
		return true, { Area = args.Area, Kind = args.Kind, ResourceKind = resourceKind }
	end
	if command == "TravelScripted" then
		if not area(args.Area) or not RESOURCE_KINDS[args.Kind] or not SPEED[args.Speed] or not POSITIONS[args.Position] then
			return false, "Incomplete scripted route"
		end
		if type(args.Slow) ~= "boolean" then return false, "Slow must be true or false" end
		return true, { Area = args.Area, Kind = args.Kind, Speed = args.Speed, Slow = args.Slow, Position = args.Position }
	end
	if command == "TravelSubmit" then
		local row = { Source = "Human" }
		for _, key in { "Outbound", "Pickup", "Wake", "Chase", "Safety", "ReturnBase", "RoundTrip", "Speed" } do
			local value = args[key]
			if value == nil then row[key] = -1
			elseif not finite(value, 100000) then return false, "Invalid travel time"
			else row[key] = value end
		end
		if not TRAVEL_RESULTS[args.Result] then return false, "Invalid travel result" end
		if type(args.Catches) ~= "number" or args.Catches % 1 ~= 0 or args.Catches < 0 or args.Catches > 99 then
			return false, "Invalid catch count"
		end
		row.Result, row.Catches = args.Result, args.Catches
		if args.Area ~= nil and not area(args.Area) then return false, "Unknown biome" end
		if args.Resource ~= nil and not resource(args.Resource) then return false, "Unknown resource" end
		row.Area, row.Resource = args.Area, args.Resource
		return true, row
	end
	if command == "Scenario" then
		if not SCENARIOS[args.Id] then return false, "Unknown scenario" end
		return true, { Id = args.Id }
	end
	return false, "Unknown command"
end

function Protocol.validate(command: any, args: any): (boolean, any)
	if type(command) ~= "string" or #command > 40 then return false, "Unknown command" end
	return clean(command, args)
end

Protocol.Scenarios = SCENARIOS
return Protocol
