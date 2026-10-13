-- Read-only Edit-mode verification of the Phase 1 handoff snapshot, not gameplay startup.
-- Run with the Studio MCP. Future intentional map changes require a new approved baseline.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local rows, duplicates, paths = {}, {}, {}
for _, part in workspace:GetDescendants() do
	if part:IsA("BasePart") then
		table.insert(rows, part:GetFullName() .. "|" .. tostring(part.CFrame) .. "|" .. tostring(part.Size)
			.. "|" .. tostring(part.Anchored) .. "|" .. tostring(part.CanCollide))
	end
end
table.sort(rows)
local serialized = table.concat(rows, "")
local digest = 5381
for index = 1, #serialized do digest = (digest * 33 + serialized:byte(index)) % 4294967296 end
for _, instance in game:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		local path = instance:GetFullName()
		if paths[path] then table.insert(duplicates, path) end
		paths[path] = true
	end
end
local errors, warnings = require(game.ReplicatedStorage.Shared.DefinitionValidation).config()
local worldErrors, nodes = require(game.ReplicatedStorage.Shared.ResourceValidation).world(
	workspace:FindFirstChild("ExpeditionZones"), game.ServerStorage:FindFirstChild("ResourceModels"))
for _, message in worldErrors do table.insert(errors, message) end
assert(#rows == 1412 and digest == 1212267917, "Blockout differs from Phase 1 baseline")
assert(#duplicates == 0, "Duplicate script paths remain")
assert(#errors == 0, table.concat(errors, "; "))
assert(game.ServerScriptService.UnitTestRunner.Disabled, "Test runner must remain disabled")
assert(game.ServerStorage.ExpeditionTemplates.SoilBag.qPerfectionWeld.Disabled, "Template quarantine missing")
assert(not workspace:FindFirstChild("GeneratedGameplay"), "Runtime fixture remained in Edit")
return {BaseParts=#rows, GeometryDigest=digest, Nodes=#nodes, DuplicateScripts=#duplicates, DefinitionErrors=#errors, Warnings=warnings}
