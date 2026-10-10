--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AreaDefinitions"))
local DataService = require(script.Parent.DataService)
local ZoneGeometry = require(script.Parent.ZoneGeometry)
local BillboardMetadata = require(script.Parent.BillboardMetadataService)

local GuardianService = {}

local WARN_AT = 3
local WARNING_SECONDS = 2
local COOLDOWN_SECONDS = 8
local HAZARD_RADIUS = 80
local KNOCKBACK_SPEED = 75

type Runtime = {
	areaId: string,
	state: string,
	disturbance: number,
	position: Vector3,
	part: BasePart,
	busy: boolean,
	generation: number,
}

local guardians: { [string]: Runtime } = {}

local function setState(runtime: Runtime, state: string)
	runtime.state = state
	BillboardMetadata:Update(runtime.part, { ValueText = state })
	if state == "SLEEPING" then
		runtime.part.Color = Color3.fromRGB(90, 90, 90)
	elseif state == "DISTURBED" or state == "WARNING" then
		runtime.part.Color = Color3.fromRGB(200, 140, 40)
	elseif state == "HAZARD" then
		runtime.part.Color = Color3.fromRGB(200, 40, 40)
	else
		runtime.part.Color = Color3.fromRGB(70, 90, 120)
	end
end

local function hazard(runtime: Runtime)
	local generation = runtime.generation
	setState(runtime, "HAZARD")
	local CarryService = require(script.Parent.CarryService)
	local SpawnService = require(script.Parent.SpawnService)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if hrp ~= nil and hrp:IsA("BasePart") then
			local offset = hrp.Position - runtime.position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= HAZARD_RADIUS then
				local direction = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, 1)
				local data = DataService.get(player)
				local power = if data ~= nil then data.Power else 0
				local resist = math.clamp(power / 200, 0, 0.5)
				hrp.AssemblyLinearVelocity = direction * KNOCKBACK_SPEED * (1 - resist) + Vector3.new(0, 45, 0)
				player:SetAttribute("HazardTick", os.clock())
				player:SetAttribute("StatusMessage", "The guardian roared")

				local item = CarryService.drop(player)
				if item ~= nil then
					SpawnService.returnToWorld(item.areaId, item.resourceId, item.token, hrp.Position, player.UserId)
				end
			end
		end
	end

	task.delay(1.2, function()
		if runtime.generation ~= generation then return end
		setState(runtime, "COOLDOWN")
		task.delay(COOLDOWN_SECONDS, function()
			if runtime.generation ~= generation then return end
			runtime.disturbance = 0
			runtime.busy = false
			setState(runtime, "SLEEPING")
		end)
	end)
end

function GuardianService.disturb(areaId: string, amount: number)
	local runtime = guardians[areaId]
	if runtime == nil or amount <= 0 then
		return
	end
	runtime.disturbance += amount
	if runtime.busy then
		return
	end
	if runtime.disturbance < WARN_AT then
		setState(runtime, "DISTURBED")
		return
	end

	runtime.busy = true
	local generation = runtime.generation
	setState(runtime, "WARNING")
	task.delay(WARNING_SECONDS, function()
		if guardians[areaId] == runtime and runtime.generation == generation then
			hazard(runtime)
		end
	end)
end

function GuardianService.resetAll()
	for _, runtime in guardians do
		runtime.generation += 1
		runtime.disturbance, runtime.busy = 0, false
		setState(runtime, "SLEEPING")
	end
end

function GuardianService.start()
	local root = workspace:FindFirstChild("GeneratedGameplay")
	if root == nil then
		local created = Instance.new("Folder")
		created.Name = "GeneratedGameplay"
		created.Parent = workspace
		root = created
	end
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = root

	for _, area in AreaDefinitions.getOrdered() do
		local zone = ZoneGeometry.getZone(area)
		local floor = if zone ~= nil then ZoneGeometry.findFloor(zone) else nil
		if floor == nil then
			continue
		end

		local position = ZoneGeometry.guardianPoint(floor)
		local part = Instance.new("Part")
		part.Name = area.Guardian
		part.Size = Vector3.new(10, 12, 18)
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = CFrame.new(position)
		part:SetAttribute("GuardianName", area.GuardianDisplayName)
		part.Parent = folder

		BillboardMetadata:Create(part, {
			DisplayName = area.GuardianDisplayName,
			Rarity = "Common",
			ValueText = "SLEEPING",
			ObjectType = "Guardian",
		})

		local runtime: Runtime = {
			areaId = area.Id,
			state = "SLEEPING",
			disturbance = 0,
			position = position,
			part = part,
			busy = false,
			generation = 0,
		}
		guardians[area.Id] = runtime
		setState(runtime, "SLEEPING")
	end
end

return GuardianService
