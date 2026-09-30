--!strict
-- Rojo-owned script. Source of truth: src/server/ConveyorService.server.luau
-- Mapped via default.project.json -> ServerScriptService.Server (src/server)
-- Do not edit this script directly in Studio; change the file and sync with Rojo.
-- rojo-sync-marker: ownership-confirmed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local ConveyorSpawnWeights = require(Creatures:WaitForChild("ConveyorSpawnWeights"))
local FeedPresentationDefinitions = require(Creatures:WaitForChild("FeedPresentationDefinitions"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local MaterialBillboardService = require(script.Parent:WaitForChild("materials"):WaitForChild("MaterialBillboardService"))
local ConveyorPurchaseService = require(script.Parent:WaitForChild("economy"):WaitForChild("ConveyorPurchaseService"))

print("ConveyorService started")
ConveyorPurchaseService.start()

type ValidatedSpawnEntry = {
	template: BasePart,
	feedId: string,
	weight: number,
}

-- Production pool from shared pure module (basic 24 / premium 6 / specialized 3).
local SPAWN_WEIGHTS = ConveyorSpawnWeights.getProductionPool()

local rng = Random.new()

local conveyorsFolder = workspace:FindFirstChild("Conveyors")
if not conveyorsFolder then
	error("Workspace is missing a folder named Conveyors")
end

local spawnedMaterials = conveyorsFolder:FindFirstChild("SpawnedMaterials")
if not spawnedMaterials then
	-- Fallback: check workspace directly in case it was moved
	spawnedMaterials = workspace:FindFirstChild("SpawnedMaterials")
end
if not spawnedMaterials then
	error("Conveyors folder is missing a child named SpawnedMaterials")
end

local templates = ServerStorage:FindFirstChild("MaterialTemplates")
if not templates then
	error("ServerStorage is missing a folder named MaterialTemplates")
end

local function isCanonicalFeedId(feedId: string): boolean
	if feedId == "" then
		return false
	end
	if string.find(feedId, "[%s\"']") ~= nil then
		return false
	end
	return true
end

local function findTemplateByFeedId(feedId: string): BasePart?
	for _, child in templates:GetChildren() do
		if child:IsA("BasePart") then
			local feedIdValue = child:GetAttribute("FeedId")
			if typeof(feedIdValue) == "string" and feedIdValue == feedId then
				return child
			end
		end
	end
	return nil
end

local function validateTemplateStructure(template: BasePart, expectedFeedId: string): boolean
	local feedIdValue = template:GetAttribute("FeedId")
	if typeof(feedIdValue) ~= "string" then
		warn(
			string.format(
				"[ConveyorService] Template %s is missing a string FeedId attribute",
				template:GetFullName()
			)
		)
		return false
	end

	if not isCanonicalFeedId(feedIdValue) then
		warn(
			string.format(
				"[ConveyorService] Template %s has malformed FeedId %q; use canonical IDs such as RawMeat",
				template:GetFullName(),
				feedIdValue
			)
		)
		return false
	end

	if feedIdValue ~= expectedFeedId then
		warn(
			string.format(
				"[ConveyorService] Template %s FeedId mismatch: expected %s, got %s",
				template:GetFullName(),
				expectedFeedId,
				feedIdValue
			)
		)
		return false
	end

	if template:FindFirstChildOfClass("ProximityPrompt") == nil then
		warn(
			string.format(
				"[ConveyorService] Template %s (FeedId=%s) is missing ProximityPrompt; conveyor pickup will not work until Studio adds one like Meat",
				template.Name,
				expectedFeedId
			)
		)
	end

	return true
end

local function buildSpawnPool(): ({ ValidatedSpawnEntry }, number)
	local pool: { ValidatedSpawnEntry } = {}
	local totalWeight = 0

	for _, entry in SPAWN_WEIGHTS do
		local template = findTemplateByFeedId(entry.feedId)
		if template == nil then
			warn(
				string.format(
					"[ConveyorService] No MaterialTemplates BasePart with FeedId=%s; skipping weighted entry",
					entry.feedId
				)
			)
			continue
		end

		if not validateTemplateStructure(template, entry.feedId) then
			continue
		end

		table.insert(pool, {
			template = template,
			feedId = entry.feedId,
			weight = entry.weight,
		})
		totalWeight += entry.weight
	end

	if totalWeight <= 0 or #pool == 0 then
		error("[ConveyorService] No valid MaterialTemplates entries available for weighted spawning")
	end

	return pool, totalWeight
end

local spawnPool, spawnPoolTotalWeight = buildSpawnPool()
local categories = ConveyorSpawnWeights.getCategoryWeights(SPAWN_WEIGHTS)
print(string.format(
	"[ConveyorService] Spawn pool ready total=%d basic=%d premium=%d specialized=%d entries=%d",
	spawnPoolTotalWeight,
	categories.basic,
	categories.premium,
	categories.specialized,
	#spawnPool
))

local function selectSpawnEntry(): ValidatedSpawnEntry
	-- Select by canonical FeedId via pure weighted selector, then map to validated template entry.
	local weightEntries: { ConveyorSpawnWeights.SpawnWeightEntry } = {}
	for _, entry in spawnPool do
		table.insert(weightEntries, { feedId = entry.feedId, weight = entry.weight })
	end
	local feedId = ConveyorSpawnWeights.selectWithRandom(weightEntries, rng)
	if feedId == nil then
		return spawnPool[#spawnPool]
	end
	for _, entry in spawnPool do
		if entry.feedId == feedId then
			return entry
		end
	end
	return spawnPool[#spawnPool]
end

local function checkConveyor(name: string): (Instance, BasePart, BasePart)
	local conveyor = conveyorsFolder:FindFirstChild(name)

	if not conveyor then
		error("Conveyors is missing " .. name)
	end

	local startPart = conveyor:FindFirstChild("Start")
	local endPart = conveyor:FindFirstChild("End")

	if not startPart or not startPart:IsA("BasePart") then
		error(name .. " is missing a Part named Start")
	end

	if not endPart or not endPart:IsA("BasePart") then
		error(name .. " is missing a Part named End")
	end

	print(name .. " passed setup checks")

	return conveyor, startPart, endPart
end

local _conveyorA, startA, endA = checkConveyor("conveyorA")
local _conveyorB, startB, endB = checkConveyor("conveyorB")

local SPAWN_INTERVAL = 3
local TRAVEL_TIME = 30

local function spawnMaterial(conveyorName: string, startPart: BasePart, endPart: BasePart)
	local selected = selectSpawnEntry()
	local template = selected.template
	local feedId = selected.feedId

	print(string.format("Attempting spawn on %s (FeedId=%s)", conveyorName, feedId))

	local material = template:Clone()
	material.Anchored = true
	material.CanCollide = false
	material.CFrame = startPart.CFrame
	material.Parent = spawnedMaterials

	local presentation = FeedPresentationDefinitions.get(feedId)
	local economy = MaterialEconomyDefinitions.get(feedId)
	if economy == nil then
		warn(string.format("[ConveyorService] Missing economy definition for FeedId=%s; destroying spawn", feedId))
		material:Destroy()
		return
	end

	-- Informational attributes only; purchase validation uses MaterialEconomyDefinitions.
	material:SetAttribute("FeedId", feedId)
	material:SetAttribute("PurchasePrice", economy.purchasePrice)
	if presentation ~= nil then
		material:SetAttribute("FeedCategory", presentation.categoryId)
		material:SetAttribute("DisplayName", presentation.displayName)
	end

	local purchased = false
	local tween = TweenService:Create(
		material,
		TweenInfo.new(TRAVEL_TIME, Enum.EasingStyle.Linear),
		{ CFrame = endPart.CFrame }
	)

	-- Runtime-only prompt for templates that lack one in Studio (does not mutate templates).
	local prompt = material:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		local meatTemplate = findTemplateByFeedId("RawMeat")
		local meatPrompt = if meatTemplate ~= nil then meatTemplate:FindFirstChildOfClass("ProximityPrompt") else nil
		if meatPrompt ~= nil and meatPrompt:IsA("ProximityPrompt") then
			prompt = meatPrompt:Clone()
			prompt.Parent = material
		else
			prompt = Instance.new("ProximityPrompt")
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 12
			prompt.Parent = material
		end
		warn(string.format(
			"[ConveyorService] Template %s (FeedId=%s) had no ProximityPrompt; attached runtime Buy prompt",
			template.Name,
			feedId
		))
	end

	local billboardResult = MaterialBillboardService.attach(material, feedId)
	if not billboardResult.success then
		warn(string.format(
			"[ConveyorService] Billboard attach failed for FeedId=%s reason=%s",
			feedId,
			tostring(billboardResult.reason)
		))
	end

	ConveyorPurchaseService.register(material, feedId, prompt, billboardResult.billboard)

	if prompt then
		prompt.Triggered:Connect(function(player)
			if purchased then
				return
			end
			if material.Parent == nil then
				return
			end

			local ok, reason = ConveyorPurchaseService.tryPurchase(player, material)
			if ok then
				purchased = true
				tween:Cancel()
				print(string.format("%s purchased %s (FeedId=%s)", player.Name, template.Name, feedId))
			else
				print(string.format(
					"%s failed purchase %s reason=%s",
					player.Name,
					feedId,
					tostring(reason)
				))
			end
		end)
	else
		warn(string.format("Spawned %s (FeedId=%s) is missing a ProximityPrompt", template.Name, feedId))
	end

	print(string.format("Spawned %s (FeedId=%s) on %s", template.Name, feedId, conveyorName))

	tween:Play()

	local completedConn
	completedConn = tween.Completed:Connect(function()
		local record = ConveyorPurchaseService.getRecord(material)
		local stillAvailable = record ~= nil and record.state == "Available"
		if stillAvailable and material.Parent ~= nil then
			material:Destroy()
		end
		if completedConn then
			completedConn:Disconnect()
		end
	end)
end

task.spawn(function()
	while true do
		spawnMaterial("ConveyorA", startA, endA)
		task.wait(SPAWN_INTERVAL)
	end
end)

task.spawn(function()
	task.wait(SPAWN_INTERVAL / 2)

	while true do
		spawnMaterial("ConveyorB", startB, endB)
		task.wait(SPAWN_INTERVAL)
	end
end)
