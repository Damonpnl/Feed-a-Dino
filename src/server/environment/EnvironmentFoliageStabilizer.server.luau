--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AcaciaFoliageStabilizer = require(script.Parent:WaitForChild("AcaciaFoliageStabilizer"))
local EnvironmentCollisionEnabler = require(script.Parent:WaitForChild("EnvironmentCollisionEnabler"))

local function getKnownRoots(): { Instance }
	local roots: { Instance } = {}

	local templates = ServerStorage:FindFirstChild("EnvironmentTemplates")
	if templates ~= nil then
		table.insert(roots, templates)
	end

	local environment = Workspace:FindFirstChild("Environment")
	if environment ~= nil then
		table.insert(roots, environment)
	end

	local ring1 = Workspace:FindFirstChild("Ring1")
	if ring1 ~= nil then
		for _, child in ring1:GetChildren() do
			if child:IsA("Model") and child.Name == "Acacia" then
				table.insert(roots, child)
			end
		end
	end

	return roots
end

local function stabilizeKnownRoots(): (number, number)
	local fixed = 0
	local failed = 0

	for _, root in getKnownRoots() do
		local f, n = AcaciaFoliageStabilizer.stabilizeAll(root)
		fixed += f
		failed += n
	end

	return fixed, failed
end

local fixedCount, failedCount = stabilizeKnownRoots()
if fixedCount > 0 or failedCount > 0 then
	print(string.format(
		"[EnvironmentFoliageStabilizer] Acacia stabilized fixed=%d failed=%d",
		fixedCount,
		failedCount
	))
end

local collisionChanged, collisionAlready = EnvironmentCollisionEnabler.enableKnownRoots(getKnownRoots())
if collisionChanged > 0 then
	print(string.format(
		"[EnvironmentFoliageStabilizer] Collision enabled changed=%d alreadyOn=%d",
		collisionChanged,
		collisionAlready
	))
end
