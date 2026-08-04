--!strict
-- Rojo-owned script. Source of truth: src/server/ConveyorService.server.luau
-- Mapped via default.project.json -> ServerScriptService.Server (src/server)
-- Do not edit this script directly in Studio; change the file and sync with Rojo.
-- rojo-sync-marker: ownership-confirmed

local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

print("ConveyorService started")

type SpawnWeightEntry = {
	feedId: string,
	weight: number,
}

type ValidatedSpawnEntry = {
	template: BasePart,
	feedId: string,
	weight: number,
}

-- Weighted pool keyed by canonical FeedId (not template instance name).
-- Specialized feeds are weighted high for development testing.
local SPAWN_WEIGHTS: { SpawnWeightEntry } = {
	{ feedId = "RawMeat", weight = 35 },
	{ feedId = "LeafBundle", weight = 15 },
	{ feedId = "CrystalChunk", weight = 15 },
	{ feedId = "InsectCluster", weight = 25 },
	{ feedId = "FungalCore", weight = 25 },
	{ feedId = "ObsidianShard", weight = 25 },
}

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

local function selectSpawnEntry(): ValidatedSpawnEntry
	local roll = rng:NextNumber(0, spawnPoolTotalWeight)
	local cumulative = 0

	for _, entry in spawnPool do
		cumulative += entry.weight
		if roll < cumulative then
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

	local collected = false
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
			prompt.ActionText = "Pick Up"
			prompt.ObjectText = feedId
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 12
			prompt.Parent = material
		end
		warn(string.format(
			"[ConveyorService] Template %s (FeedId=%s) had no ProximityPrompt; attached runtime clone for pickup",
			template.Name,
			feedId
		))
	end

	if prompt then
		prompt.Triggered:Connect(function(player)
			if collected then
				return
			end

			local character = player.Character
			if not character then
				return
			end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart or not rootPart:IsA("BasePart") then
				return
			end

			-- Find the right hand (R15) or right arm (R6).
			local rightHand = character:FindFirstChild("RightHand")
			if not rightHand or not rightHand:IsA("BasePart") then
				rightHand = character:FindFirstChild("Right Arm")
			end
			if not rightHand or not rightHand:IsA("BasePart") then
				return
			end

			-- Prevent players from carrying multiple items.
			if character:GetAttribute("CarryingItem") then
				return
			end

			collected = true
			tween:Cancel()

			prompt.Enabled = false

			material.Anchored = false
			material.CanCollide = false
			material.Massless = true

			-- Move the material into the player's right hand.
			material.CFrame = rightHand.CFrame * CFrame.new(0, -0.5, 0)

			-- Put it inside the character model.
			material.Parent = character
			material.Name = "CarriedMeat"
			character:SetAttribute("CarryingItem", true)

			local weld = Instance.new("WeldConstraint")
			weld.Name = "CarryWeld"
			weld.Part0 = rightHand
			weld.Part1 = material
			weld.Parent = material

			material.Destroying:Connect(function()
				if character:GetAttribute("CarryingItem") and character:FindFirstChild("CarriedMeat", true) == nil then
					character:SetAttribute("CarryingItem", nil)
				end
			end)

			print(string.format("%s picked up %s (FeedId=%s)", player.Name, template.Name, feedId))
		end)
	else
		warn(string.format("Spawned %s (FeedId=%s) is missing a ProximityPrompt", template.Name, feedId))
	end

	print(string.format("Spawned %s (FeedId=%s) on %s", template.Name, feedId, conveyorName))

	tween:Play()

	local completedConn
	completedConn = tween.Completed:Connect(function()
		if not collected and material then
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
