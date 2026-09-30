--!strict

--[[
	Optional one-shot Wheat scatter runner for Studio generation.
	Set RUN_ON_START = true to populate Workspace.GeneratedEnvironment.Wheat on server boot.
	Does not modify the original template or terrain.
]]

local WheatScatterService = require(script.Parent:WaitForChild("WheatScatterService"))

local RUN_ON_START = false
local CLEAR_LEGACY_GENERATED_WHEAT = false

if RUN_ON_START then
	WheatScatterService.scatter({
		clearExisting = true,
		clearLegacyGeneratedWheat = CLEAR_LEGACY_GENERATED_WHEAT,
	})
end
