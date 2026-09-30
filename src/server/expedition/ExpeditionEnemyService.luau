--!strict

--[[
	Territorial Raptors spawn from enemy regions and use simple state AI.
	ExpeditionTemplates.TerritorialRaptor is a Model (no Humanoid); movement uses
	PivotTo on an anchored model placed against terrain via GetBoundingBox pivot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))
local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))
local RegionSamplingCalculator = require(Shared:WaitForChild("expedition"):WaitForChild("RegionSamplingCalculator"))

local PlacementService = require(script.Parent.PlacementService)
local RegionResolver = require(script.Parent.RegionResolver)

export type RaptorRecord = {
	model: Model,
	homePosition: Vector3,
	homeRegionPath: string,
	state: ExpeditionTypes.EnemyState,
	target: Player?,
	lastAttackAt: number,
	wanderTarget: Vector3?,
}

local ExpeditionEnemyService = {}

local enemyRandom = Random.new(ExpeditionConfig.EnemySeed)
local raptors: { RaptorRecord } = {}
local started = false
local zoneMembership: { [Player]: boolean } = {}
local bankMembership: { [Player]: boolean } = {}

local function ensurePrimaryPart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") and model.PrimaryPart:IsDescendantOf(model) then
		return model.PrimaryPart
	end

	local bboxCf, bboxSize = model:GetBoundingBox()
	local bottomCenter = bboxCf.Position - Vector3.new(0, bboxSize.Y * 0.5, 0)
	local best: BasePart? = nil
	local bestDistance = math.huge

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local distance = (descendant.Position - bottomCenter).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = descendant
			end
		end
	end

	if best ~= nil then
		model.PrimaryPart = best
	end
	return best
end

local function placeEnemyModel(model: Model, sample: ExpeditionTypes.PlacementSample, rng: Random)
	local yaw = rng:NextNumber(0, math.pi * 2)
	model:PivotTo(CFrame.new(sample.position) * CFrame.Angles(0, yaw, 0))

	local bboxCf, bboxSize = model:GetBoundingBox()
	local bottomY = bboxCf.Position.Y - (bboxSize.Y * 0.5)
	local lift = sample.position.Y - bottomY
	if math.abs(lift) > 0.01 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
	end
end

local function isValidWorldHeight(y: number): boolean
	return y > -50 and y < 500
end

local function isTrackedModel(model: Instance): boolean
	for _, record in raptors do
		if record.model == model then
			return true
		end
	end
	return false
end

local function readStoredHomePosition(model: Model): Vector3
	local stored = model:GetAttribute("HomePosition")
	if typeof(stored) == "Vector3" then
		return stored
	end
	return model:GetPivot().Position
end

local function rebuildRaptorRecords(parent: Folder)
	for _, child in parent:GetChildren() do
		if child:IsA("Model") and not isTrackedModel(child) then
			local pivotY = child:GetPivot().Position.Y
			if isValidWorldHeight(pivotY) then
				table.insert(raptors, {
					model = child,
					homePosition = readStoredHomePosition(child),
					homeRegionPath = "Rebuilt",
					state = "Idle",
					target = nil,
					lastAttackAt = 0,
					wanderTarget = nil,
				})
			else
				child:Destroy()
			end
		end
	end
end

local function purgeInvalidEnemies(parent: Folder)
	for _, child in parent:GetChildren() do
		if child:IsA("Model") then
			local y = child:GetPivot().Position.Y
			if not isValidWorldHeight(y) then
				child:Destroy()
			end
		end
	end
end

local function setAnchored(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
		end
	end
end

local function getPlayerRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function getPlayerHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function verticalSeparation(a: Vector3, b: Vector3): number
	return math.abs(a.Y - b.Y)
end

local function isValidTarget(player: Player): boolean
	if bankMembership[player] then
		return false
	end
	local humanoid = getPlayerHumanoid(player)
	local root = getPlayerRoot(player)
	if humanoid == nil or root == nil then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	return true
end

function ExpeditionEnemyService.setPlayerZoneState(player: Player, inSavannah: boolean, inBank: boolean)
	zoneMembership[player] = inSavannah
	bankMembership[player] = inBank
end

local function moveToward(model: Model, destination: Vector3, dt: number)
	local primary = ensurePrimaryPart(model)
	if primary == nil then
		return
	end

	local currentPivot = model:GetPivot()
	local current = currentPivot.Position
	local flatDestination = Vector3.new(destination.X, current.Y, destination.Z)
	local offset = flatDestination - current
	local distance = offset.Magnitude
	if distance < 0.5 then
		return
	end

	local step = math.min(distance, ExpeditionConfig.RaptorMoveSpeed * dt)
	local nextPos = current + offset.Unit * step
	local flatFacing = Vector3.new(offset.X, 0, offset.Z)
	if flatFacing.Magnitude > 0.01 then
		model:PivotTo(CFrame.lookAt(nextPos, nextPos + flatFacing.Unit))
	else
		model:PivotTo(CFrame.new(nextPos) * (currentPivot - currentPivot.Position))
	end
end

local function chooseWanderTarget(home: Vector3, rng: Random): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(5, ExpeditionConfig.RaptorWanderRadius)
	return home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function findTarget(raptor: RaptorRecord): Player?
	local primary = ensurePrimaryPart(raptor.model)
	if primary == nil then
		return nil
	end
	local origin = raptor.model:GetPivot().Position
	local best: Player? = nil
	local bestDistance = ExpeditionConfig.RaptorDetectionRadius

	for _, player in Players:GetPlayers() do
		if not isValidTarget(player) then
			continue
		end
		local root = getPlayerRoot(player)
		if root == nil then
			continue
		end
		local distance = RegionSamplingCalculator.horizontalDistance(root.Position, origin)
		local yDelta = verticalSeparation(root.Position, origin)
		if yDelta > ExpeditionConfig.RaptorMaxVerticalSeparation then
			continue
		end
		if distance <= bestDistance then
			bestDistance = distance
			best = player
		end
	end
	return best
end

local function thinkRaptor(raptor: RaptorRecord, dt: number, now: number)
	local primary = ensurePrimaryPart(raptor.model)
	if primary == nil then
		return
	end

	local position = raptor.model:GetPivot().Position
	if not isValidWorldHeight(position.Y) then
		placeEnemyModel(raptor.model, {
			position = raptor.homePosition,
			normal = Vector3.yAxis,
		}, enemyRandom)
		position = raptor.model:GetPivot().Position
	end

	local homeDistance = RegionSamplingCalculator.horizontalDistance(position, raptor.homePosition)

	if raptor.state == "Idle" then
		raptor.state = "Wander"
		raptor.wanderTarget = chooseWanderTarget(raptor.homePosition, enemyRandom)
	elseif raptor.state == "Wander" then
		local target = findTarget(raptor)
		if target then
			raptor.target = target
			raptor.state = "Alert"
		else
			local wander = raptor.wanderTarget or chooseWanderTarget(raptor.homePosition, enemyRandom)
			raptor.wanderTarget = wander
			moveToward(raptor.model, wander, dt)
			if RegionSamplingCalculator.horizontalDistance(position, wander) < 3 then
				raptor.wanderTarget = chooseWanderTarget(raptor.homePosition, enemyRandom)
			end
		end
	elseif raptor.state == "Alert" or raptor.state == "Chase" or raptor.state == "Attack" then
		local target = raptor.target
		if target == nil or not isValidTarget(target) then
			raptor.target = nil
			raptor.state = "Return"
			return
		end
		local root = getPlayerRoot(target)
		if root == nil then
			raptor.target = nil
			raptor.state = "Return"
			return
		end

		local distance = RegionSamplingCalculator.horizontalDistance(root.Position, position)
		local yDelta = verticalSeparation(root.Position, position)
		local raptorHomeDisp = RegionSamplingCalculator.horizontalDistance(position, raptor.homePosition)
		if
			distance > ExpeditionConfig.RaptorChaseRadius
			or raptorHomeDisp > ExpeditionConfig.RaptorMaxHomeDisplacement
			or yDelta > ExpeditionConfig.RaptorMaxVerticalSeparation
		then
			raptor.target = nil
			raptor.state = "Return"
			return
		end

		raptor.state = if distance <= ExpeditionConfig.RaptorAttackRange then "Attack" else "Chase"
		if raptor.state == "Chase" then
			moveToward(raptor.model, root.Position, dt)
		elseif raptor.state == "Attack" then
			if now - raptor.lastAttackAt >= ExpeditionConfig.RaptorAttackCooldown then
				local humanoid = getPlayerHumanoid(target)
				if humanoid and humanoid.Health > 0 then
					humanoid:TakeDamage(ExpeditionConfig.RaptorDamage)
					raptor.lastAttackAt = now
				end
			end
		end
	elseif raptor.state == "Return" then
		moveToward(raptor.model, raptor.homePosition, dt)
		if homeDistance < 4 then
			raptor.state = "Idle"
			raptor.wanderTarget = nil
		end
	end

	-- Never enter hub
	local hubDistance = RegionSamplingCalculator.horizontalDistance(position, ExpeditionConfig.HubCenter)
	if hubDistance < ExpeditionConfig.HubSafeRadius then
		raptor.state = "Return"
		raptor.target = nil
	end
end

local function spawnOne(regions: { ExpeditionTypes.RegionInfo }, exclusions: any, parent: Folder, placed: { Vector3 })
	local region = RegionResolver.selectRegion(regions, enemyRandom, true)
	if region == nil then
		return
	end

	local sample = PlacementService.sampleInRegion(
		region,
		enemyRandom,
		ExpeditionConfig.MaximumEnemySlopeDegrees,
		placed,
		ExpeditionConfig.MinimumEnemySpacing,
		exclusions,
		nil
	)
	if sample == nil then
		warn("[ExpeditionEnemyService] Failed to place TerritorialRaptor")
		return
	end
	if sample.position.Y < -50 or sample.position.Y > 500 then
		warn(string.format(
			"[ExpeditionEnemyService] Rejected TerritorialRaptor sample height Y=%.1f",
			sample.position.Y
		))
		return
	end

	local template = RegionResolver.resolveTemplate("TerritorialRaptor")
	if not template:IsA("Model") then
		warn("[ExpeditionEnemyService] TerritorialRaptor template must be a Model")
		return
	end

	local clone = template:Clone()
	assert(clone:IsA("Model"))
	clone.Name = "TerritorialRaptor"
	clone.Parent = parent
	ensurePrimaryPart(clone)
	setAnchored(clone)
	placeEnemyModel(clone, sample, enemyRandom)

	local pivotY = clone:GetPivot().Position.Y
	if not isValidWorldHeight(pivotY) then
		warn(string.format(
			"[ExpeditionEnemyService] TerritorialRaptor spawned at invalid height Y=%.1f; destroying",
			pivotY
		))
		clone:Destroy()
		return
	end

	clone:SetAttribute("HomePosition", sample.position)

	table.insert(placed, sample.position)
	table.insert(raptors, {
		model = clone,
		homePosition = sample.position,
		homeRegionPath = region.fullPath,
		state = "Idle",
		target = nil,
		lastAttackAt = 0,
		wanderTarget = nil,
	})
end

function ExpeditionEnemyService.spawnInitial()
	local parent = RegionResolver.getOrCreateGeneratedFolder("Enemies")
	purgeInvalidEnemies(parent)
	parent:ClearAllChildren()
	table.clear(raptors)

	local regions = RegionResolver.getEnemyRegions()
	local exclusions = RegionResolver.buildExclusions()
	local placed: { Vector3 } = {}

	for _ = 1, ExpeditionConfig.TerritorialRaptorMaxActive do
		spawnOne(regions, exclusions, parent, placed)
	end

	purgeInvalidEnemies(parent)
	rebuildRaptorRecords(parent)

	if #raptors < ExpeditionConfig.TerritorialRaptorMaxActive then
		warn(string.format(
			"[ExpeditionEnemyService] Spawned %d/%d TerritorialRaptors",
			#raptors,
			ExpeditionConfig.TerritorialRaptorMaxActive
		))
	else
		for _, record in raptors do
			print(string.format(
				"[ExpeditionEnemyService] TerritorialRaptor at %s",
				tostring(record.model:GetPivot().Position)
			))
		end
	end
end

function ExpeditionEnemyService.setRandom(rng: Random)
	enemyRandom = rng
end

function ExpeditionEnemyService.getCount(): number
	return #raptors
end

function ExpeditionEnemyService.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		for attempt = 1, 10 do
			if ExpeditionEnemyService.getCount() >= ExpeditionConfig.TerritorialRaptorMaxActive then
				break
			end
			ExpeditionEnemyService.spawnInitial()
			if ExpeditionEnemyService.getCount() >= ExpeditionConfig.TerritorialRaptorMaxActive then
				break
			end
			task.wait(0.25 + (attempt * 0.1))
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < ExpeditionConfig.RaptorThinkInterval then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for _, raptor in raptors do
			if raptor.model.Parent ~= nil then
				thinkRaptor(raptor, step, now)
			end
		end
	end)
end

return ExpeditionEnemyService
