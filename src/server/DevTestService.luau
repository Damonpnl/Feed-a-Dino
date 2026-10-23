--!nonstrict
-- Studio-only developer commands. Every mutation goes through an existing service or the
-- same player-data fields those services already own. Nothing here opens a DataStore.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage.Shared
local Protocol = require(Shared.DevTestProtocol)
local Config = require(script.Parent.DevTestConfig)
local Data = require(script.Parent.DataService)
local Carry = require(script.Parent.CarryService)
local Spawn = require(script.Parent.SpawnService)
local Resource = require(script.Parent.ResourceService)
local Guardian = require(script.Parent.GuardianService)
local Catch = require(script.Parent.GuardianCatch)
local Monster = require(script.Parent.MonsterService)
local Training = require(script.Parent.TrainingService)
local Feed = require(script.Parent.FeedService)
local Visuals = require(script.Parent.TrainerVisualService)
local Territory = require(script.Parent.BiomeTerritory)
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local Monsters = require(Shared.MonsterDefinitions)
local Mutations = require(Shared.MutationDefinitions)
local Effects = require(Shared.SpecialEffectDefinitions)
local Evolution = require(Shared.EvolutionCalculator)
local Prestige = require(Shared.PrestigeCalculator)
local Progression = require(Shared.PetProgressionConfig)
local Economy = require(Shared.EconomyCalculator)
local Trainers = require(Shared.TrainerDefinitions)
local Movement = require(Shared.MovementCalculator)
local GuardianConfig = require(Shared.GuardianConfig)
local Chase = require(Shared.GuardianChase)
local PlayerData = require(Shared.PlayerData)
local Rarities = require(Shared.RarityDefinitions)

local DevTest = {}
local started = false
local jobs, rows, samples, seeds = {}, {}, {}, {}

local function accepted(player)
	return Protocol.allowed(RunService:IsStudio(), Config.Enabled == true, player and player.UserId, Config.RunnerUserIds)
		and player.Parent == Players
end
local function fail(message) return { Ok = false, Error = message } end
local function done(message, extra)
	local result = { Ok = true, Message = message }
	if extra then for key, value in extra do result[key] = value end end
	return result
end
local function requireData(player)
	local status = Data.getStatus(player)
	if not status or status.Backend ~= "StudioMemory" then return nil, "Developer commands only run in an isolated Studio memory session" end
	if not Data.isWritable(player) then return nil, "Session is not writable" end
	local data = Data.get(player)
	if not data then return nil, "No session" end
	return data
end
local function record(player)
	local data = Data.get(player)
	local key = data and data.EquippedMonster
	return data, key, data and data.Monsters[key]
end
local function root(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local part = character and character:FindFirstChild("HumanoidRootPart")
	if not part or not humanoid or humanoid.Health <= 0 then return nil end
	return part, humanoid, character
end
local function pivot(player, position)
	local part = root(player)
	if not part or typeof(position) ~= "Vector3" or position.Magnitude > 1e6 then return false end
	part.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	return true
end
local function baseOf(player)
	local name = player:GetAttribute("AssignedBaseName")
	local bases = workspace:FindFirstChild("Bases")
	local base = type(name) == "string" and bases and bases:FindFirstChild(name)
	return base, name
end
local function stationOf(player)
	local base = baseOf(player)
	local station = base and base:FindFirstChild("TrainingStation", true)
	return base, station
end
local function entranceX()
	local generated = workspace:FindFirstChild("GeneratedGameplay")
	local marker = generated and generated:FindFirstChild("SafeZoneBoundary")
	if not (marker and marker:IsA("BasePart")) then marker = workspace:FindFirstChild("SafeZoneBoundary", true) end
	return marker and marker:IsA("BasePart") and marker.Position.X or nil
end
local function pickResource(areaId, kind)
	local list = {}
	for _, definition in Resources.getAll() do
		if definition.Launch and definition.Area == areaId and definition.ResourceType == "Feed" then table.insert(list, definition) end
	end
	table.sort(list, function(a, b) return a.PowerRequired < b.PowerRequired or (a.PowerRequired == b.PowerRequired and a.Id < b.Id) end)
	if kind == "Heavy" then
		local best
		for _, definition in list do if not best or definition.CarrySlowdown > best.CarrySlowdown then best = definition end end
		return best
	end
	if kind == "Cursed" then
		local best
		for _, definition in Resources.getAll() do
			local profile = definition.Launch and definition.Area == areaId and require(Shared.CarryDebuff).Profiles[definition.Rarity]
			if profile and profile.Primary and (not best or definition.PowerRequired > best.PowerRequired) then best = definition end
		end
		return best
	end
	return list[1]
end
local function nodesFor(areaId)
	local snap, guardian = Resource.getSnapshot(), Guardian.getSnapshot(areaId)
	local home = guardian and guardian.Home
	local list = {}
	if not snap or not home then return list end
	for id, node in snap.Nodes do
		if node.AreaId == areaId and node.RecordId then
			local item = snap.Records[node.RecordId]
			if item and item.State == "AVAILABLE" and item.Position then
				table.insert(list, { Id = id, Position = item.Position, Distance = Chase.horizontal(item.Position, home) })
			end
		end
	end
	table.sort(list, function(a, b) return a.Distance < b.Distance or (a.Distance == b.Distance and a.Id < b.Id) end)
	return list
end
local function band(list, position)
	if #list == 0 then return nil end
	if position == "Near" then return list[1] end
	if position == "Far" then return list[#list] end
	return list[math.ceil(#list / 2)]
end
local function remember(player, source, row)
	local bucket = rows[player]
	if not bucket then bucket = { Human = {}, Scripted = {} } rows[player] = bucket end
	local list = bucket[source]
	row.Source, row.UserId, row.At = source, player.UserId, workspace:GetServerTimeNow()
	table.insert(list, row)
	while #list > 30 do table.remove(list, 1) end
end

local function catalog()
	local resources, pets, families, areas = {}, {}, {}, {}
	for _, area in Areas.getOrdered() do
		table.insert(areas, { Id = area.Id, Name = area.DisplayName, Guardian = area.GuardianDisplayName })
		for _, entry in area.ResourcePool do
			local definition = Resources.get(entry.Id)
			table.insert(resources, { Id = definition.Id, Name = definition.DisplayName, Area = area.Id,
				Power = definition.PowerRequired, Slowdown = definition.CarrySlowdown, Rarity = definition.Rarity, Kind = definition.ResourceType })
		end
	end
	for id, definition in Monsters.getAll() do
		table.insert(pets, { Id = id, Name = definition.DisplayName, Stage = definition.Stage })
	end
	table.sort(pets, function(a, b) return a.Stage < b.Stage or (a.Stage == b.Stage and a.Id < b.Id) end)
	for id, effect in Effects do
		if effect.Kind == "EvolutionFamily" then table.insert(families, id) end
	end
	table.sort(families)
	local mutations = {}
	for id, definition in Mutations.getAll() do
		if definition.Kind == "Overlay" and definition.Enabled then table.insert(mutations, id) end
	end
	table.sort(mutations)
	local trainers = {}
	for _, definition in Trainers.getOrdered() do
		table.insert(trainers, { Tier = definition.Tier, Name = definition.DisplayName, Price = definition.Price, Multiplier = definition.Multiplier })
	end
	return { Areas = areas, Resources = resources, Pets = pets, Families = families, Mutations = mutations,
		Rarities = Rarities.Order, Trainers = trainers, Presets = Protocol.presets(),
		Scenarios = { "Fresh", "FirstEvolution", "Swamp", "Jungle", "CrystalCave", "Volcano", "Catalyst", "MaxTraining" } }
end

local function guardians(player)
	local list, now = {}, os.clock()
	local part = root(player)
	for _, area in Areas.getOrdered() do
		local snap = Guardian.getSnapshot(area.Id)
		local config = GuardianConfig.Areas[area.Id]
		local achieved = 0
		if snap then
			local previous = samples[area.Id]
			if previous then
				local dt = now - previous.Time
				if dt > 0.05 then achieved = Chase.horizontal(snap.Position, previous.Position) / dt end
			end
			samples[area.Id] = { Position = snap.Position, Time = now }
		end
		local recovery = Catch.getSnapshot(player)
		table.insert(list, {
			Area = area.Id, Guardian = area.GuardianDisplayName, State = snap and snap.State or "Missing",
			TargetUserId = snap and snap.TargetUserId or 0, Hazard = config and config.Kind or "",
			SpeedRatio = config and config.SpeedRatio or 0, CatchUpRatio = config and config.CatchUpRatio or 0,
			CatchReach = config and config.CatchReach or 0, Achieved = math.floor(achieved * 10 + 0.5) / 10,
			Distance = if snap and part then math.floor(Chase.horizontal(snap.Position, part.Position) * 10 + 0.5) / 10 else -1,
			HomeDistance = if snap then math.floor(Chase.horizontal(snap.Position, snap.Home) * 10 + 0.5) / 10 else -1,
			Recovery = if recovery then math.max(0, recovery.Until - workspace:GetServerTimeNow()) else 0,
		})
	end
	return list
end

local function snapshot(player)
	local status, data = Data.getStatus(player), Data.get(player)
	local _, key, pet = record(player)
	local carried = Carry.get(player)
	local definition = carried and Resources.get(carried.resourceId)
	local curse = Carry.getCurse(player)
	local multipliers = Monster.getMultipliers(player)
	local eligible = {}
	if pet and Evolution.valid(pet) then
		for _, branch in Evolution.candidates(pet) do table.insert(eligible, branch.Id .. " -> " .. branch.Result) end
	end
	local form = pet and Monsters.get(Evolution.form(pet))
	local ascension = pet and Prestige.ascension(pet, Progression.Ascensions.ProtoRexMythic)
	local awakening = pet and Prestige.awakening(pet, Progression.Awakenings.ProtoRexAwakening)
	local identities = {}
	for _, other in Players:GetPlayers() do table.insert(identities, { UserId = other.UserId, Name = other.Name }) end
	local bucket, job = rows[player] or { Human = {}, Scripted = {} }, jobs[player]
	return {
		Ok = true, UserId = player.UserId, Name = player.Name, Players = identities,
		Backend = status and status.Backend or "None", Writable = Data.isWritable(player),
		Session = status and status.Status or "None",
		Cash = data and data.Cash or 0, Power = data and data.Power or 0,
		TrainerTier = data and data.TrainerTier or 0, SlowMode = data and data.SlowMode == true,
		Base = player:GetAttribute("AssignedBaseName") or "",
		UnloadedSpeed = Movement.base(data and data.Power or 0),
		EffectiveSpeed = player:GetAttribute("EffectiveMovementSpeed") or 0,
		SpeedOverride = player:GetAttribute("DevTestBaseOverride") or -1,
		AppliedSlowdown = Carry.getAppliedSlowdown(player),
		Carry = if carried then { Id = carried.resourceId, Name = definition and definition.DisplayName or carried.resourceId,
			Power = definition and definition.PowerRequired or 0, Token = carried.token,
			Curse = curse and curse.Title or "" } else nil,
		Pet = if pet then { Key = key, Form = Evolution.form(pet), Stage = pet.Stage, Growth = pet.Growth,
			Reserve = pet.GrowthReserve or 0, Flesh = pet.Flesh, Flora = pet.Flora, Mineral = pet.Mineral,
			Rarity = pet.Rarity, Mutations = pet.Mutations, Families = pet.EvolutionFamilies,
			Eligible = eligible, Pending = pet.PendingEvolution, Fixture = pet.DevTestFixture == true,
			Training = multipliers.TrainingMultiplier, Income = Economy.income(multipliers.IncomeMultiplier),
			Ascension = ascension, Awakening = awakening, Required = form and form.GrowthRequired or 0 } else nil,
		Train = { Gain = player:GetAttribute("TrainingGainPerSecond") or 0, Income = player:GetAttribute("IncomePerSecond") or 0,
			Pet = player:GetAttribute("ActivePetTrainingMultiplier") or 0, Active = player:GetAttribute("TrainingActive") == true },
		Guardians = guardians(player), LastPursuit = player:GetAttribute("DevTestLastPursuit") or "",
		Human = bucket.Human, Scripted = bucket.Scripted,
		Job = if job then { Done = job.Done == true, Progress = job.Progress or "", Error = job.Error } else nil,
		Seed = seeds[player] or 0,
	}
end

local function grant(player, areaId, resourceId, curseMode, nodeId)
	local part = nodesFor(areaId)
	return Spawn.devGrant(player, areaId, resourceId, curseMode, nodeId), part
end

local function runScripted(player, args, state)
	local data = requireData(player)
	if not data then error("Session is not an isolated writable Studio memory session") end
	local definition = pickResource(args.Area, args.Kind)
	if not definition then error("No matching launch resource") end
	if data.Power < definition.PowerRequired then error("Power is below " .. definition.DisplayName .. " (" .. definition.PowerRequired .. ")") end
	local node = band(nodesFor(args.Area), args.Position)
	if not node then error("No available node") end
	local previousSlow = data.SlowMode == true
	local part = root(player)
	if not part then error("No living character") end
	Carry.setTestBaseOverride(player, args.Speed)
	if data.SlowMode ~= args.Slow then Carry.setSlowMode(player, args.Slow) end
	local connection
	local function cleanup()
		if connection then connection:Disconnect() connection = nil end
		if part then part.Anchored = false end
		Carry.setTestBaseOverride(player, nil)
		if Data.get(player) and Data.get(player).SlowMode ~= previousSlow then Carry.setSlowMode(player, previousSlow) end
		pcall(Guardian.resetAll)
	end
	local ok, err = xpcall(function()
		if Carry.get(player) then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
		local line = entranceX()
		if not line then error("Safe-zone boundary is missing") end
		local base = baseOf(player)
		local spawn = base and base:FindFirstChild("PlayerSpawn", true)
		if not spawn or not pivot(player, spawn.Position) then error("Player spawn is unavailable") end
		part.Anchored = true
		local t0 = os.clock()
		while not state.Cancel and os.clock() - t0 < 90 and Chase.horizontal(part.Position, node.Position) > 8 do
			local flat = Vector3.new(node.Position.X - part.Position.X, 0, node.Position.Z - part.Position.Z)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local speed = humanoid and humanoid.WalkSpeed or args.Speed
			local dt = task.wait()
			if flat.Magnitude > 0.5 then part.CFrame = CFrame.new(part.Position + flat.Unit * math.min(flat.Magnitude, speed * dt)) end
			state.Progress = "Outbound"
		end
		if state.Cancel then error("Cancelled") end
		if Chase.horizontal(part.Position, node.Position) > 8 then error("Could not reach the resource") end
		local outbound = os.clock() - t0
		local id, grantError = Spawn.devGrant(player, args.Area, definition.Id, if args.Kind == "Cursed" then "cursed" else "none", node.Id)
		if not id then error(grantError or "Grant failed") end
		local theft = os.clock()
		local serverT0 = workspace:GetServerTimeNow()
		local woke, safeAt, result = nil, nil, "Incomplete"
		connection = RunService.Heartbeat:Connect(function(dt)
			if state.Cancel or not part.Parent or result ~= "Incomplete" then return end
			local guardian = Guardian.getSnapshot(args.Area)
			local guardianState = guardian and guardian.State
			if not woke and (guardianState == "PURSUING" or guardianState == "WARNING" or guardianState == "HAZARD") then
				woke = os.clock() - theft
			end
			local dropped = player:GetAttribute("DropTick")
			if type(dropped) == "number" and dropped >= serverT0 then
				local reason = tostring(player:GetAttribute("DropReason"))
				result = if string.find(reason, "GuardianCatch", 1, true) then "Catch" else "Hazard"
				return
			end
			if part.Position.X < line then safeAt = os.clock() - theft result = "Escape" return end
			local goal = Vector3.new(line - 20, part.Position.Y, part.Position.Z)
			local flat = goal - part.Position
			local speed = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			speed = speed and speed.WalkSpeed or args.Speed
			if flat.Magnitude > 0.5 then part.CFrame = CFrame.new(part.Position + flat.Unit * math.min(flat.Magnitude, speed * dt)) end
		end)
		local deadline = os.clock() + 120
		while not state.Cancel and result == "Incomplete" and os.clock() < deadline do
			state.Progress = string.format("Running %.0fs", os.clock() - theft)
			task.wait(0.2)
		end
		local returnAt
		if result == "Escape" and not state.Cancel then
			local base = baseOf(player)
			local spawn = base and base:FindFirstChild("PlayerSpawn", true)
			local back = os.clock()
			while spawn and not state.Cancel and os.clock() - back < 90 and Chase.horizontal(part.Position, spawn.Position) > 8 do
				local flat = Vector3.new(spawn.Position.X - part.Position.X, 0, spawn.Position.Z - part.Position.Z)
				local speed = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				speed = speed and speed.WalkSpeed or args.Speed
				local dt = task.wait()
				if flat.Magnitude > 0.5 then part.CFrame = CFrame.new(part.Position + flat.Unit * math.min(flat.Magnitude, speed * dt)) end
				state.Progress = "Returning"
			end
			if spawn and Chase.horizontal(part.Position, spawn.Position) <= 8 then returnAt = os.clock() - back end
		end
		local row = { Area = args.Area, Resource = definition.Id, Kind = args.Kind, Position = args.Position,
			Speed = player:GetAttribute("EffectiveMovementSpeed") or 0, RequestedSpeed = args.Speed, Slow = args.Slow,
			Outbound = outbound, Pickup = outbound, Wake = woke or -1, Chase = if woke and (safeAt or result ~= "Escape") then (safeAt or (os.clock() - theft)) - woke else -1,
			Safety = safeAt or -1, ReturnBase = returnAt or -1, RoundTrip = os.clock() - t0,
			Result = if state.Cancel then "Incomplete" else result, Catches = if result == "Catch" then 1 else 0, Seed = seeds[player] or 0 }
		remember(player, "Scripted", row)
		player:SetAttribute("DevTestLastPursuit", result .. " " .. args.Area .. " " .. definition.Id)
		state.Progress = result
	end, debug.traceback)
	cleanup()
	if not ok then error(err) end
end

local handlers = {}
function handlers.Status() return done("Developer testing is authorized") end
function handlers.Snapshot(player) return snapshot(player) end
function handlers.Catalog() return done("Catalog", { Catalog = catalog() }) end
function handlers.SetSeed(player, args) seeds[player] = args.Seed return done("Seed " .. args.Seed) end

local function economy(player, mutate)
	local data, reason = requireData(player)
	if not data then return fail(reason) end
	local message = mutate(data)
	if type(message) ~= "string" then return message end
	Data.publish(player)
	Carry.recalculateMovement(player)
	return done(message)
end
function handlers.SetPower(player, args)
	return economy(player, function(data) data.Power = args.Value return "Power set" end)
end
function handlers.AddPower(player, args)
	return economy(player, function(data)
		local value = Economy.add(data.Power, args.Value)
		if not value then return fail("Power could not be added") end
		data.Power = value return "Power added"
	end)
end
function handlers.ResetPower(player) return economy(player, function(data) data.Power = 0 return "Power reset" end) end
function handlers.SetCash(player, args) return economy(player, function(data) data.Cash = args.Value return "Cash set" end) end
function handlers.AddCash(player, args)
	return economy(player, function(data)
		local value = Economy.add(data.Cash, args.Value)
		if not value then return fail("Cash could not be added") end
		data.Cash = value return "Cash added"
	end)
end
function handlers.ResetCash(player) return economy(player, function(data) data.Cash = 0 return "Cash reset" end) end
function handlers.CashForNext(player)
	return economy(player, function(data)
		local definition = Trainers.getOrdered()[data.TrainerTier + 1]
		if not definition then return fail("Already at the final trainer") end
		local need = definition.Price - data.Cash
		if need > 0 then data.Cash = Economy.add(data.Cash, need) end
		return "Cash covers " .. definition.DisplayName
	end)
end
function handlers.SetSlowMode(player, args)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	if not Carry.setSlowMode(player, args.Enabled) then return fail("Slow Mode was rejected") end
	return done(if args.Enabled then "Slow Mode on" else "Slow Mode off")
end
function handlers.SetSpeedOverride(player, args)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	if not Carry.setTestBaseOverride(player, args.Speed) then return fail("Speed override was rejected") end
	return done(if args.Speed then "Base speed override " .. args.Speed else "Speed override cleared")
end
function handlers.ClearOverrides(player)
	Carry.setTestBaseOverride(player, nil)
	return done("Test movement override cleared")
end
function handlers.ResetCharacter(player)
	player:LoadCharacter()
	return done("Character reset")
end

local function mutatePet(player, mutate)
	local data, reason = requireData(player)
	if not data then return fail(reason) end
	local key = data.EquippedMonster
	local pet = data.Monsters[key]
	if not pet then return fail("No active pet") end
	local message = mutate(data, pet, key)
	if type(message) ~= "string" then return message end
	Monster.publish(player)
	return done(message)
end
function handlers.SelectPet(player, args)
	return mutatePet(player, function(data)
		if not data.Monsters[args.Id] then return fail("That pet is not owned") end
		data.EquippedMonster = args.Id return "Equipped " .. args.Id
	end)
end
function handlers.CreatePet(player, args)
	return mutatePet(player, function(data)
		if data.Monsters[args.Id] then return fail("That form is already owned") end
		local definition = Monsters.get(args.Id)
		data.Monsters[args.Id] = PlayerData.createMonster(args.Id, definition.Rarity)
		data.EquippedMonster = args.Id
		return "Created " .. definition.DisplayName
	end)
end
function handlers.SetGrowth(player, args)
	return mutatePet(player, function(_, pet)
		pet.Growth = args.Value
		pet.TotalGrowth = math.max(pet.TotalGrowth or 0, pet.Growth + (pet.GrowthReserve or 0))
		if Evolution.valid(pet) then Evolution.boundGrowth(pet) end
		return "Growth updated"
	end)
end
function handlers.SetStage(player, args)
	return mutatePet(player, function(_, pet)
		local chosen
		for id, definition in Monsters.getAll() do
			if definition.Stage == args.Stage and definition.Lineage == (pet.Lineage or "ProtoRex") then
				if id == Evolution.form(pet) then chosen = definition break end
				chosen = chosen or definition
			end
		end
		if chosen then
			pet.EvolutionForm, pet.Stage, pet.DevTestFixture = chosen.Id, chosen.Stage, nil
			return "Stage set through " .. chosen.DisplayName
		end
		if not args.Override then return fail("No matching form; turn on override for an invalid fixture") end
		pet.Stage, pet.DevTestFixture = args.Stage, true
		return "Stage forced as a temporary test fixture"
	end)
end
function handlers.SetAffinities(player, args)
	return mutatePet(player, function(_, pet)
		pet.Flesh, pet.Flora, pet.Mineral = args.Flesh, args.Flora, args.Mineral
		return "Affinities updated"
	end)
end
function handlers.SetRarity(player, args)
	return mutatePet(player, function(_, pet) pet.Rarity = args.Rarity return "Rarity set" end)
end
function handlers.ApplyEvolution(player, args)
	return mutatePet(player, function(data, pet, key)
		if not Evolution.valid(pet) then return fail("Pet state is not valid for evolution") end
		local staged = PlayerData.copy(pet)
		if pet.PendingEvolution then
			local branchId = args.BranchId or pet.PendingEvolution.Candidates[1]
			local ok, reason = Evolution.select(staged, pet.PendingEvolution.Token, branchId, function() return 0.5 end)
			if not ok then return fail(reason) end
			data.Monsters[key] = staged
			data.Stats.Evolutions += 1
			return reason
		end
		local evolved, message
		local calculated = pcall(function()
			evolved, message = Evolution.afterFeed(staged, args.BranchId, function() return 0.5 end)
		end)
		if not calculated then return fail("That evolution is not eligible") end
		data.Monsters[key] = staged
		if evolved then data.Stats.Evolutions += 1 end
		return if message and message ~= "" then message else "Evolution state updated"
	end)
end
function handlers.ResetPet(player)
	return mutatePet(player, function(data, pet, key)
		local fresh = PlayerData.createMonster(pet.Species or key, "Common")
		fresh.PetId = pet.PetId
		data.Monsters[key] = fresh
		return "Pet reset"
	end)
end
function handlers.AddMutation(player, args)
	return mutatePet(player, function(_, pet)
		local ok, reason = Mutations.apply(pet, args.Id)
		return if ok then "Mutation added" else fail(reason)
	end)
end
function handlers.RemoveMutation(player, args)
	return mutatePet(player, function(_, pet)
		local nextList = {}
		for _, id in pet.Mutations do if id ~= args.Id then table.insert(nextList, id) end end
		if #nextList == #pet.Mutations then return fail("Mutation is not present") end
		pet.Mutations = nextList
		return "Mutation removed"
	end)
end
function handlers.SetFamily(player, args)
	return mutatePet(player, function(_, pet)
		pet.EvolutionFamilies[Effects[args.Id].Family] = if args.Enabled then true else nil
		return if args.Enabled then "Family added" else "Family removed"
	end)
end

local function clearDevCarry(player)
	local carried = Carry.get(player)
	local item = carried and Resource.getRecord(carried.token)
	if item and item.SpawnReason == "DevTest" and player.Character then
		Carry.forceDrop(player, player.Character, "DevTestCleanup")
	end
end
function handlers.SpawnResource(player, args)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	local id, reason = Resource.devReplace(args.Area, args.Resource)
	return if id then done("Spawned " .. args.Resource, { Token = id }) else fail(reason)
end
function handlers.GiveResource(player, args)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	if Carry.get(player) and player.Character then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	local id, reason = Spawn.devGrant(player, args.Area, args.Resource, "natural")
	return if id then done("Carrying " .. args.Resource, { Token = id }) else fail(reason)
end
function handlers.GivePreset(player, args)
	local area, resourceId = "Grasslands", args.Id
	if args.Id == "Hybrid" then area, resourceId = "Swamp", "BogMarrow"
	elseif args.Id == "Catalyst" then area, resourceId = "Grasslands", "PrimalCatalyst"
	elseif args.Id == "Evolution" then
		local _, _, pet = record(player)
		local affinity = "Flesh"
		if pet then
			local best = pet.Flesh
			if pet.Flora < best then affinity, best = "Floral", pet.Flora end
			if pet.Mineral < best then affinity = "Mineral" end
		end
		local chosen
		for _, definition in Resources.getAll() do
			if definition.Launch and definition.ResourceType == "Feed" and (definition.Affinity == affinity or string.find(definition.Affinity, affinity, 1, true)) then
				if not chosen or definition.PowerRequired < chosen.PowerRequired then chosen = definition end
			end
		end
		if not chosen then return fail("No evolution feed is defined") end
		area, resourceId = chosen.Area, chosen.Id
	end
	return handlers.GiveResource(player, { Area = area, Resource = resourceId })
end
function handlers.DropCarry(player)
	if not player.Character or not Carry.forceDrop(player, player.Character, "DevTestDrop") then return fail("Nothing to drop") end
	return done("Dropped")
end
function handlers.ClearCarry(player)
	clearDevCarry(player)
	if Carry.get(player) and player.Character then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	return done("Carry cleared")
end
function handlers.FeedPreview(player)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	local base = baseOf(player)
	local point = base and base:FindFirstChild("FeedingPoint", true)
	local host = point and (if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart", true))
	if not host or not pivot(player, host.Position) then return fail("Feeding point is unavailable") end
	local preview = Feed.preview(player, base, host)
	return if preview.Available then done(preview.Reason, { Preview = preview }) else fail(preview.Reason or "Preview unavailable")
end
function handlers.FeedConfirm(player, args)
	local ok, reason = Feed.confirm(player, args.Ticket)
	return if ok then done(reason) else fail(reason)
end
function handlers.ResetResources(player)
	clearDevCarry(player)
	return done("Released " .. Resource.devRelease() .. " test resources")
end

function handlers.SetTrainerTier(player, args)
	local result = economy(player, function(data) data.TrainerTier = args.Tier return "Trainer tier " .. args.Tier end)
	if not result.Ok then return result end
	local _, station = stationOf(player)
	if station then pcall(Visuals.update, station, args.Tier) end
	player:SetAttribute("TrainerTier", args.Tier)
	return result
end
function handlers.BuyTrainer(player)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	local data = Data.get(player)
	local base, station = stationOf(player)
	if not station or not pivot(player, station.Position) then return fail("Training station is unavailable") end
	local target = data.TrainerTier + 1
	if not Training.upgrade(player, base, station, target) then return fail(player:GetAttribute("StatusMessage") or "Purchase was rejected") end
	return done(player:GetAttribute("StatusMessage") or "Purchased")
end
function handlers.StartTraining(player)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	local base, station = stationOf(player)
	if not station or not pivot(player, station.Position) then return fail("Training station is unavailable") end
	if not Training.train(player, base, station) then return fail(player:GetAttribute("StatusMessage") or "Training was rejected") end
	return done("Training")
end
function handlers.StopTraining(player)
	Training.stop(player)
	return done("Training stopped")
end
function handlers.ResetTrainer(player)
	return handlers.SetTrainerTier(player, { Tier = 1 })
end

function handlers.Teleport(player, args)
	local territory = Territory.get(args.Area)
	if not territory or not pivot(player, territory.Region.Home + Vector3.new(-30, 0, 0)) then return fail("Teleport failed") end
	return done("Teleported to " .. args.Area)
end
function handlers.ResetGuardians()
	Guardian.resetAll()
	return done("Guardians reset")
end
local function launchTheft(player, args, positionName)
	local data, reason = requireData(player)
	if not data then return fail(reason) end
	local definition = pickResource(args.Area, args.ResourceKind or "Ordinary")
	if not definition then return fail("No matching launch resource") end
	if data.Power < definition.PowerRequired then return fail("Power is below " .. definition.PowerRequired) end
	local node = band(nodesFor(args.Area), positionName)
	if not node then return fail("No available node") end
	if Carry.get(player) and player.Character then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	local start = node.Position
	if args.Kind == "Close" then
		local snap = Guardian.getSnapshot(args.Area)
		if not snap then return fail("Guardian is missing") end
		start = snap.Home + Vector3.new(-18, 0, 0)
	end
	if not pivot(player, start) then return fail("Teleport failed") end
	local id, grantError = Spawn.devGrant(player, args.Area, definition.Id, if args.ResourceKind == "Cursed" or args.Kind == "Cursed" then "cursed" else "none", node.Id)
	if not id then return fail(grantError or "Grant failed") end
	player:SetAttribute("DevTestLastPursuit", "Theft " .. definition.Id)
	return done("Theft started: " .. definition.DisplayName, { Token = id })
end
function handlers.GuardianScenario(player, args)
	args.ResourceKind = if args.Kind == "Heavy" or args.Kind == "Cursed" then args.Kind else (args.ResourceKind or "Ordinary")
	local position = if args.Kind == "Long" then "Far" elseif args.Kind == "Close" then "Near" else "Middle"
	return launchTheft(player, args, position)
end
function handlers.CatchRecovery(player, args)
	local launched = handlers.GuardianScenario(player, { Area = args.Area, Kind = "Ordinary", ResourceKind = "Ordinary" })
	if not launched.Ok then return launched end
	local character = player.Character
	local snap = Guardian.getSnapshot(args.Area)
	if character and Carry.get(player) then Carry.forceDrop(player, character, "GuardianCatch:" .. args.Area, true) end
	if not snap or not Catch.apply(player, character, snap.Position, Vector3.new(-1, 0, 0), args.Area) then
		return fail("Catch recovery could not start")
	end
	player:SetAttribute("DevTestLastPursuit", "CatchRecovery " .. args.Area)
	return done("Catch recovery started")
end
function handlers.TwoCarriers(player, args)
	local others = {}
	for _, other in Players:GetPlayers() do if other ~= player then table.insert(others, other) end end
	if #others == 0 then return fail("A second Studio client is required") end
	local nodeList = nodesFor(args.Area)
	if #nodeList < 2 then return fail("Need two available nodes") end
	local definition = pickResource(args.Area, "Ordinary")
	if not definition then return fail("No ordinary resource") end
	local other = others[1]
	if Carry.get(player) and player.Character then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	if Carry.get(other) then return fail("The second client is already carrying something") end
	if not pivot(player, nodeList[1].Position) then return fail("Teleport failed") end
	local first, firstError = Spawn.devGrant(player, args.Area, definition.Id, "none", nodeList[1].Id)
	if not first then return fail(firstError or "Grant failed") end
	if not pivot(other, nodeList[2].Position) then return fail("Could not place the second client") end
	local second, reason = Spawn.devGrant(other, args.Area, definition.Id, "none", nodeList[2].Id)
	if not second then return fail("Second client: " .. (reason or "grant failed")) end
	return done("Two carriers: " .. player.Name .. " (" .. player.UserId .. ") and " .. other.Name .. " (" .. other.UserId .. ")")
end
function handlers.ResetScenario(player)
	local job = jobs[player]
	if job then job.Cancel = true end
	Carry.setTestBaseOverride(player, nil)
	if player.Character and Carry.get(player) then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	Resource.devRelease()
	Guardian.resetAll()
	player:SetAttribute("DevTestLastPursuit", "")
	return done("Scenario reset")
end
function handlers.TravelSubmit(player, args)
	if not requireData(player) then return fail("Session is not an isolated writable Studio memory session") end
	remember(player, "Human", args)
	return done("Human measurement stored")
end
function handlers.TravelScripted(player, args)
	if jobs[player] and not jobs[player].Done then return fail("A scripted test is already running") end
	local state = { Done = false, Cancel = false, Progress = "starting" }
	jobs[player] = state
	task.spawn(function()
		local ok, err = pcall(runScripted, player, args, state)
		state.Done = true
		if not ok then state.Error = tostring(err) state.Progress = "Failed" end
	end)
	return done("Scripted route started")
end
function handlers.TravelCancel(player)
	local job = jobs[player]
	if job then job.Cancel = true end
	return done("Cancel requested")
end
function handlers.TravelClear(player)
	rows[player] = { Human = {}, Scripted = {} }
	return done("Measurements cleared")
end
function handlers.TravelExport(player)
	local bucket = rows[player] or { Human = {}, Scripted = {} }
	return done("Export", { Export = HttpService:JSONEncode({ Human = bucket.Human, Scripted = bucket.Scripted, Seed = seeds[player] or 0,
		Note = "Human and Scripted rows are separate. Do not merge them into one success rate." }) })
end

local function ensurePet(data, id)
	if data.Monsters[id] then data.EquippedMonster = id return end
	data.Monsters[id] = PlayerData.createMonster(id, Monsters.get(id).Rarity)
	data.EquippedMonster = id
end
function handlers.Scenario(player, args)
	local data, reason = requireData(player)
	if not data then return fail(reason) end
	if player.Character and Carry.get(player) then Carry.forceDrop(player, player.Character, "DevTestCleanup") end
	Carry.setTestBaseOverride(player, nil)
	local id = args.Id
	if id == "Fresh" then
		local fresh = PlayerData.default()
		data.Cash, data.Power, data.TrainerTier, data.SlowMode = 0, 0, 1, false
		data.EquippedMonster, data.Monsters = fresh.EquippedMonster, fresh.Monsters
		data.DiscoveredAreas = { Grasslands = true }
		data.BaseUpgrades.TrainingLevel = 0
		data.Stats = { Feeds = 0, Evolutions = 0, Trainings = 0 }
	elseif id == "FirstEvolution" then
		ensurePet(data, "ProtoRex")
		local pet = data.Monsters[data.EquippedMonster]
		pet.Growth, pet.TotalGrowth, pet.Flesh, pet.Flora, pet.Mineral = 20, math.max(pet.TotalGrowth or 0, 20), 15, 0, 0
		data.Power, data.Cash, data.TrainerTier, data.SlowMode = 0, 0, 1, false
	elseif id == "Swamp" then
		ensurePet(data, "Fangling")
		data.Power, data.TrainerTier = Resources.get("SmallFish").PowerRequired, 2
	elseif id == "Jungle" then
		ensurePet(data, "MatureRex")
		data.Power, data.TrainerTier = Resources.get("WildFruit").PowerRequired, 4
	elseif id == "CrystalCave" then
		ensurePet(data, "ApexRex")
		data.Power, data.TrainerTier = Resources.get("CrystalShard").PowerRequired, 6
	elseif id == "Volcano" then
		ensurePet(data, "ApexRex")
		data.Power, data.TrainerTier = Resources.get("CharredMeat").PowerRequired, 8
	elseif id == "Catalyst" then
		ensurePet(data, "Fangling")
		local pet = data.Monsters.Fangling
		pet.Growth, pet.GrowthReserve = 80, 0
		pet.TotalGrowth = math.max(pet.TotalGrowth or 0, 80)
		pet.Flesh, pet.EvolutionFamilies.Primal = 80, nil
		if Evolution.valid(pet) then Evolution.boundGrowth(pet) end
		data.Power = Resources.get("PrimalCatalyst").PowerRequired
	elseif id == "MaxTraining" then
		data.TrainerTier, data.Power, data.SlowMode = 10, 150000000, false
	end
	Data.publish(player)
	Carry.recalculateMovement(player)
	Monster.publish(player)
	local _, station = stationOf(player)
	if station then pcall(Visuals.update, station, data.TrainerTier) end
	player:SetAttribute("TrainerTier", data.TrainerTier)
	if id == "FirstEvolution" then
		local granted = handlers.GivePreset(player, { Id = "RawMeat" })
		if not granted.Ok then return granted end
	elseif id == "Catalyst" then
		local granted = handlers.GivePreset(player, { Id = "Catalyst" })
		if not granted.Ok then return granted end
	end
	return done("Scenario " .. id)
end

function DevTest.start()
	if started then return end
	started = true
	if not Protocol.allowed(RunService:IsStudio(), Config.Enabled == true, 0, Config.RunnerUserIds) and not RunService:IsStudio() then
		return
	end
	if not RunService:IsStudio() or Config.Enabled ~= true then
		print("[DevTest] disabled")
		return
	end
	local remotes = game.ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then remotes = Instance.new("Folder") remotes.Name = "Remotes" remotes.Parent = game.ReplicatedStorage end
	local remote = remotes:FindFirstChild("DevTest")
	if remote then remote:Destroy() end
	remote = Instance.new("RemoteFunction")
	remote.Name = "DevTest"
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, request)
		if not accepted(player) then return fail("Unauthorized") end
		if type(request) ~= "table" then return fail("Bad request") end
		local ok, cleaned = Protocol.validate(request.Command, request.Args)
		if not ok then return fail(cleaned) end
		local handler = handlers[request.Command]
		if not handler then return fail("Unknown command") end
		local ran, result = pcall(handler, player, cleaned)
		if not ran then warn("[DevTest] " .. tostring(result)) return fail("Command failed") end
		return result
	end
	Players.PlayerRemoving:Connect(function(player)
		local job = jobs[player]
		if job then job.Cancel = true end
		jobs[player], rows[player], seeds[player] = nil, nil, nil
		Carry.setTestBaseOverride(player, nil)
	end)
	print("[DevTest] Studio memory panel authorized")
end

return DevTest
