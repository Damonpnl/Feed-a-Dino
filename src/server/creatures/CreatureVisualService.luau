--!strict

--[[
	Server-authoritative creature visual spawning and replacement.
	Templates come only from ServerStorage.CreatureTemplates.
	Clients never submit form names or placement.
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = Shared:WaitForChild("creatures")
local LineageDefinitions = require(Creatures:WaitForChild("LineageDefinitions"))

local CreatureVisualService = {}

local TEMPLATES_FOLDER_NAME = "CreatureTemplates"
local SPAWN_MARKER_NAME = "CreatureSpawn"
local ACTIVE_CREATURE_NAME = "ActiveCreature"
local PENDING_CREATURE_NAME = "ActiveCreature_Pending"
local FALLBACK_FORM_ID = "ProtoRex"

export type VisualRequest = {
	formId: string,
	rarity: string,
	stage: number,
	ownerUserId: number,
	creatureId: string,
}

export type RefreshFailureReason =
	"MissingTemplatesFolder"
	| "MissingCreatureSpawn"
	| "InvalidCreatureSpawn"
	| "MissingFallbackTemplate"
	| "InvalidTemplateClass"
	| "CloneFailed"
	| "Busy"

export type RefreshResult = {
	success: boolean,
	reason: RefreshFailureReason?,
	visual: Instance?,
	formId: string?,
	templateFormId: string?,
	visualFallback: boolean,
}

export type BaseSpawnValidation = {
	baseName: string,
	basePath: string,
	spawnOk: boolean,
	spawnClass: string?,
}

export type ValidationReport = {
	templatesFolderOk: boolean,
	unknownTemplates: { string },
	missingTemplates: { string },
	invalidTemplateClasses: { string },
	bases: { BaseSpawnValidation },
}

local refreshLocks: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function getTemplatesFolder(): Folder?
	local folder = ServerStorage:FindFirstChild(TEMPLATES_FOLDER_NAME)
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function isValidTemplateClass(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("BasePart")
end

local function findCreatureSpawn(base: Instance): BasePart?
	local spawn = base:FindFirstChild(SPAWN_MARKER_NAME)
	if spawn ~= nil and spawn:IsA("BasePart") then
		return spawn
	end
	return nil
end

local function collectNamedVisuals(base: Instance, name: string): { Instance }
	local found: { Instance } = {}
	for _, child in base:GetChildren() do
		if child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

local function configureClonePhysics(visual: Instance): ()
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = true
		return
	end

	if visual:IsA("Model") then
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
			end
		end
	end
end

local function applyVisualAttributes(
	visual: Instance,
	request: VisualRequest,
	visualFallback: boolean
): ()
	visual:SetAttribute("FormId", request.formId)
	visual:SetAttribute("Rarity", request.rarity)
	visual:SetAttribute("Stage", request.stage)
	visual:SetAttribute("OwnerUserId", request.ownerUserId)
	visual:SetAttribute("CreatureId", request.creatureId)
	visual:SetAttribute("VisualFallback", visualFallback)
end

local function resolveTemplate(formId: string): (Instance?, boolean, string?)
	local templates = getTemplatesFolder()
	if templates == nil then
		return nil, false, "MissingTemplatesFolder"
	end

	local requested = templates:FindFirstChild(formId)
	if requested ~= nil then
		if not isValidTemplateClass(requested) then
			warn(string.format(
				"[CreatureVisualService] Template %s has invalid class %s (need Model or BasePart)",
				requested:GetFullName(),
				requested.ClassName
			))
			return nil, false, "InvalidTemplateClass"
		end
		return requested, false, nil
	end

	warn(string.format(
		"[CreatureVisualService] Missing template for formId=%s; using fallback %s",
		formId,
		FALLBACK_FORM_ID
	))

	local fallback = templates:FindFirstChild(FALLBACK_FORM_ID)
	if fallback == nil then
		return nil, false, "MissingFallbackTemplate"
	end
	if not isValidTemplateClass(fallback) then
		return nil, false, "InvalidTemplateClass"
	end

	return fallback, true, nil
end

function CreatureVisualService.getActiveCreature(base: Instance): Instance?
	local active = base:FindFirstChild(ACTIVE_CREATURE_NAME)
	if active == nil then
		return nil
	end
	return active
end

function CreatureVisualService.countActiveCreatures(base: Instance): number
	return #collectNamedVisuals(base, ACTIVE_CREATURE_NAME)
end

function CreatureVisualService.validateSetup(basesFolder: Instance?): ValidationReport
	local templates = getTemplatesFolder()
	local unknownTemplates: { string } = {}
	local missingTemplates: { string } = {}
	local invalidTemplateClasses: { string } = {}
	local bases: { BaseSpawnValidation } = {}

	if templates ~= nil then
		for _, child in templates:GetChildren() do
			if not isValidTemplateClass(child) then
				table.insert(invalidTemplateClasses, child.Name)
			elseif LineageDefinitions.get(child.Name) == nil then
				table.insert(unknownTemplates, child.Name)
			end
		end
	end

	for _, definition in LineageDefinitions.getAll() do
		if templates == nil or templates:FindFirstChild(definition.id) == nil then
			table.insert(missingTemplates, definition.id)
		end
	end

	local folder = basesFolder or Workspace:FindFirstChild("Bases")
	if folder ~= nil then
		for _, base in folder:GetChildren() do
			if base:IsA("Model") then
				local spawn = base:FindFirstChild(SPAWN_MARKER_NAME)
				table.insert(bases, {
					baseName = base.Name,
					basePath = base:GetFullName(),
					spawnOk = spawn ~= nil and spawn:IsA("BasePart"),
					spawnClass = if spawn ~= nil then spawn.ClassName else nil,
				})
			end
		end
	end

	return {
		templatesFolderOk = templates ~= nil,
		unknownTemplates = unknownTemplates,
		missingTemplates = missingTemplates,
		invalidTemplateClasses = invalidTemplateClasses,
		bases = bases,
	}
end

function CreatureVisualService.printValidationReport(report: ValidationReport): ()
	print(string.format(
		"[CreatureVisualService] Validation: templatesFolderOk=%s unknown=%d missing=%d invalidClass=%d bases=%d",
		tostring(report.templatesFolderOk),
		#report.unknownTemplates,
		#report.missingTemplates,
		#report.invalidTemplateClasses,
		#report.bases
	))

	for _, name in report.unknownTemplates do
		warn("[CreatureVisualService] Template has no creature definition: " .. name)
	end
	for _, name in report.missingTemplates do
		warn("[CreatureVisualService] Creature definition missing template: " .. name)
	end
	for _, name in report.invalidTemplateClasses do
		warn("[CreatureVisualService] Template invalid class: " .. name)
	end
	for _, baseInfo in report.bases do
		print(string.format(
			"[CreatureVisualService] Base %s CreatureSpawn ok=%s class=%s",
			baseInfo.baseName,
			tostring(baseInfo.spawnOk),
			tostring(baseInfo.spawnClass)
		))
	end
end

function CreatureVisualService.refreshVisual(base: Instance, request: VisualRequest): RefreshResult
	if refreshLocks[base] == true then
		return {
			success = false,
			reason = "Busy",
			visual = nil,
			formId = request.formId,
			templateFormId = nil,
			visualFallback = false,
		}
	end

	refreshLocks[base] = true

	local ok, result = pcall(function(): RefreshResult
		if getTemplatesFolder() == nil then
			return {
				success = false,
				reason = "MissingTemplatesFolder",
				visual = nil,
				formId = request.formId,
				templateFormId = nil,
				visualFallback = false,
			}
		end

		local spawnMarker = base:FindFirstChild(SPAWN_MARKER_NAME)
		if spawnMarker == nil then
			return {
				success = false,
				reason = "MissingCreatureSpawn",
				visual = nil,
				formId = request.formId,
				templateFormId = nil,
				visualFallback = false,
			}
		end
		if not spawnMarker:IsA("BasePart") then
			return {
				success = false,
				reason = "InvalidCreatureSpawn",
				visual = nil,
				formId = request.formId,
				templateFormId = nil,
				visualFallback = false,
			}
		end

		local template, usedFallback, resolveReason = resolveTemplate(request.formId)
		if template == nil then
			local reason: RefreshFailureReason = if resolveReason == "MissingFallbackTemplate"
				then "MissingFallbackTemplate"
				elseif resolveReason == "InvalidTemplateClass" then "InvalidTemplateClass"
				else "MissingTemplatesFolder"
			return {
				success = false,
				reason = reason,
				visual = nil,
				formId = request.formId,
				templateFormId = nil,
				visualFallback = false,
			}
		end

		local cloneSuccess, clonedOrError = pcall(function()
			return template:Clone()
		end)
		if not cloneSuccess or typeof(clonedOrError) ~= "Instance" then
			return {
				success = false,
				reason = "CloneFailed",
				visual = nil,
				formId = request.formId,
				templateFormId = template.Name,
				visualFallback = usedFallback,
			}
		end

		local newVisual = clonedOrError :: Instance
		newVisual.Name = PENDING_CREATURE_NAME
		configureClonePhysics(newVisual)
		applyVisualAttributes(newVisual, request, usedFallback)

		-- Place using full CreatureSpawn CFrame (position + rotation) before parenting.
		newVisual:PivotTo(spawnMarker.CFrame)
		newVisual.Parent = base

		-- Only destroy previous visuals after the new one is successfully created and parented.
		for _, old in collectNamedVisuals(base, ACTIVE_CREATURE_NAME) do
			old:Destroy()
		end
		for _, pending in collectNamedVisuals(base, PENDING_CREATURE_NAME) do
			if pending ~= newVisual then
				pending:Destroy()
			end
		end

		newVisual.Name = ACTIVE_CREATURE_NAME

		-- Final sweep: never leave duplicates.
		for _, extra in collectNamedVisuals(base, ACTIVE_CREATURE_NAME) do
			if extra ~= newVisual then
				extra:Destroy()
			end
		end

		return {
			success = true,
			reason = nil,
			visual = newVisual,
			formId = request.formId,
			templateFormId = template.Name,
			visualFallback = usedFallback,
		}
	end)

	refreshLocks[base] = nil

	if not ok then
		warn("[CreatureVisualService] refreshVisual error: " .. tostring(result))
		return {
			success = false,
			reason = "CloneFailed",
			visual = nil,
			formId = request.formId,
			templateFormId = nil,
			visualFallback = false,
		}
	end

	return result :: RefreshResult
end

function CreatureVisualService.requestFromSnapshot(snapshot: {
	formId: string?,
	lineageId: string?,
	rarity: string,
	stage: number,
	ownerUserId: number,
	creatureId: string,
}): VisualRequest
	local formId = snapshot.formId or snapshot.lineageId
	assert(formId ~= nil, "Snapshot must include formId or lineageId")
	return {
		formId = formId,
		rarity = snapshot.rarity,
		stage = snapshot.stage,
		ownerUserId = snapshot.ownerUserId,
		creatureId = snapshot.creatureId,
	}
end

return CreatureVisualService
