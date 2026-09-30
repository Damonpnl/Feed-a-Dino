--!strict

--[[
	Spawns collectible SoilBag drops when a player dies with field-bag loot.
	Anyone may collect for DroppedBagLifetimeSeconds; owner gets client highlight via tag/attributes.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ExpeditionConfig = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionConfig"))

local FieldBagService = require(script.Parent.FieldBagService)
local PlacementService = require(script.Parent.PlacementService)
local RegionResolver = require(script.Parent.RegionResolver)
local MaterialBillboardService = require(script.Parent.Parent.materials.MaterialBillboardService)

export type DroppedBagRecord = {
	id: string,
	instance: Instance,
	adornee: BasePart,
	materials: { [string]: number },
	totalItems: number,
	ownerUserId: number,
	ownerName: string,
	expiresAt: number,
	billboard: BillboardGui?,
	prompt: ProximityPrompt,
	collecting: boolean,
}

local DroppedBagService = {}

local bagsById: { [string]: DroppedBagRecord } = {}
local bagsByInstance: { [Instance]: DroppedBagRecord } = {}
local nextId = 0
local started = false
local timerConnection: RBXScriptConnection? = nil

local function nextBagId(): string
	nextId += 1
	return string.format("DroppedBag_%d", nextId)
end

local function copyMaterials(source: { [string]: number }): { [string]: number }
	local copy: { [string]: number } = {}
	for feedId, amount in source do
		if amount > 0 then
			copy[feedId] = amount
		end
	end
	return copy
end

local function countMaterials(materials: { [string]: number }): number
	local total = 0
	for _, amount in materials do
		total += amount
	end
	return total
end

local function disableScripts(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
	if root:IsA("Script") or root:IsA("LocalScript") then
		(root :: any).Disabled = true
	end
end

local function resolveAdornee(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		local model = instance :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end
	end
	return nil
end

local function placeOnGround(instance: Instance, worldPosition: Vector3)
	local sample = PlacementService.sampleGroundAt(worldPosition, ExpeditionConfig.MaximumResourceSlopeDegrees)
	local ground = if sample ~= nil then sample.position else worldPosition

	local adornee = resolveAdornee(instance)
	local halfHeight = if adornee ~= nil then adornee.Size.Y * 0.5 else 1.2
	local target = Vector3.new(ground.X, ground.Y + halfHeight, ground.Z)

	if instance:IsA("Model") then
		(instance :: Model):PivotTo(CFrame.new(target))
	elseif instance:IsA("BasePart") then
		(instance :: BasePart):PivotTo(CFrame.new(target))
	end
end

local function destroyBag(record: DroppedBagRecord)
	bagsById[record.id] = nil
	bagsByInstance[record.instance] = nil
	if record.instance.Parent ~= nil then
		record.instance:Destroy()
	end
end

local function updateBillboardTimer(record: DroppedBagRecord)
	if record.billboard == nil or record.billboard.Parent == nil then
		return
	end
	local remaining = record.expiresAt - Workspace:GetServerTimeNow()
	MaterialBillboardService.setBottomLabelText(
		record.billboard,
		MaterialBillboardService.formatCountdown(remaining)
	)
end

local function tryCollect(player: Player, instance: Instance)
	local record = bagsByInstance[instance]
	if record == nil then
		return
	end
	if record.collecting then
		return
	end
	if Workspace:GetServerTimeNow() >= record.expiresAt then
		destroyBag(record)
		return
	end
	if countMaterials(record.materials) <= 0 then
		destroyBag(record)
		return
	end

	record.collecting = true
	record.prompt.Enabled = false

	FieldBagService.ensureForZone(player, "Savannah")
	local ok, reason = FieldBagService.addMany(player, record.materials)
	if not ok then
		warn(string.format(
			"[DroppedBagService] Collect failed for %s: %s",
			player.Name,
			tostring(reason)
		))
		record.collecting = false
		record.prompt.Enabled = true
		return
	end

	destroyBag(record)
end

function DroppedBagService.spawnFromDeath(
	player: Player,
	materials: { [string]: number },
	deathPosition: Vector3
): DroppedBagRecord?
	local stacks = copyMaterials(materials)
	local totalItems = countMaterials(stacks)
	if totalItems <= 0 then
		return nil
	end

	local template = RegionResolver.resolveTemplate(ExpeditionConfig.DroppedBagTemplateName)
	local clone = template:Clone()
	clone.Name = "DroppedSoilBag"
	disableScripts(clone)

	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = true
		clone.CanQuery = true
	elseif clone:IsA("Model") then
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = true
			end
		end
	end

	local parent = RegionResolver.getOrCreateGeneratedFolder(ExpeditionConfig.DroppedBagFolderName)
	clone.Parent = parent
	placeOnGround(clone, deathPosition)

	local adornee = resolveAdornee(clone)
	if adornee == nil then
		warn("[DroppedBagService] SoilBag clone has no BasePart adornee")
		clone:Destroy()
		return nil
	end

	local expiresAt = Workspace:GetServerTimeNow() + ExpeditionConfig.DroppedBagLifetimeSeconds
	local bagId = nextBagId()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Lost Bag"
	prompt.HoldDuration = ExpeditionConfig.DroppedBagPromptHoldDuration
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = adornee

	local billboardResult = MaterialBillboardService.attachCustom(clone, {
		displayName = "LOST BAG",
		categoryText = player.DisplayName,
		bottomText = MaterialBillboardService.formatCountdown(ExpeditionConfig.DroppedBagLifetimeSeconds),
		effectText = string.format("%d items", totalItems),
		maxDistance = ExpeditionConfig.DroppedBagBillboardMaxDistance,
		hideIcon = true,
	})

	clone:SetAttribute("DroppedBagId", bagId)
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone:SetAttribute("OwnerName", player.DisplayName)
	clone:SetAttribute("ExpiresAt", expiresAt)
	clone:SetAttribute("TotalItems", totalItems)
	CollectionService:AddTag(clone, ExpeditionConfig.DroppedBagCollectionServiceTag)

	local record: DroppedBagRecord = {
		id = bagId,
		instance = clone,
		adornee = adornee,
		materials = stacks,
		totalItems = totalItems,
		ownerUserId = player.UserId,
		ownerName = player.DisplayName,
		expiresAt = expiresAt,
		billboard = billboardResult.billboard,
		prompt = prompt,
		collecting = false,
	}
	bagsById[bagId] = record
	bagsByInstance[clone] = record

	prompt.Triggered:Connect(function(collector: Player)
		tryCollect(collector, clone)
	end)

	return record
end

function DroppedBagService.getCount(): number
	local count = 0
	for _ in bagsById do
		count += 1
	end
	return count
end

function DroppedBagService.start()
	if started then
		return
	end
	started = true

	local timerAccumulator = 0
	timerConnection = RunService.Heartbeat:Connect(function(dt)
		timerAccumulator += dt
		if timerAccumulator < 0.25 then
			return
		end
		timerAccumulator = 0

		local now = Workspace:GetServerTimeNow()
		local expired: { DroppedBagRecord } = {}
		for _, record in bagsById do
			if now >= record.expiresAt then
				table.insert(expired, record)
			else
				updateBillboardTimer(record)
			end
		end
		for _, record in expired do
			destroyBag(record)
		end
	end)

	Players.PlayerRemoving:Connect(function(_player)
		-- Drops persist after owner leaves so others can still loot.
	end)
end

function DroppedBagService.clearAllForTests()
	local snapshot: { DroppedBagRecord } = {}
	for _, record in bagsById do
		table.insert(snapshot, record)
	end
	for _, record in snapshot do
		destroyBag(record)
	end
end

return DroppedBagService
