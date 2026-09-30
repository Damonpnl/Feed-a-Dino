--!strict

--[[
	Publishes sanitized visual clones of ServerStorage.CreatureTemplates
	into ReplicatedStorage.CreaturePresentationTemplates for ViewportFrame use.
	Never moves authoritative templates out of ServerStorage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CreaturePresentationTemplateService = {}

local FOLDER_NAME = "CreaturePresentationTemplates"
local SOURCE_NAME = "CreatureTemplates"

local function sanitizeClone(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = false
		root.Massless = true
	end
end

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

function CreaturePresentationTemplateService.publish(): Folder
	local folder = ensureFolder()
	folder:ClearAllChildren()

	local source = ServerStorage:FindFirstChild(SOURCE_NAME)
	if source == nil then
		warn("[CreaturePresentationTemplateService] ServerStorage.CreatureTemplates missing")
		return folder
	end

	local published = 0
	for _, child in source:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			local clone = child:Clone()
			clone.Name = child.Name
			sanitizeClone(clone)
			clone.Parent = folder
			published += 1
		end
	end

	print(string.format(
		"[CreaturePresentationTemplateService] Published %d presentation templates",
		published
	))
	return folder
end

function CreaturePresentationTemplateService.start()
	CreaturePresentationTemplateService.publish()
end

return CreaturePresentationTemplateService
