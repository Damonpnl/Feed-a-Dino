--!strict

--[[
	Starts the Savannah expedition vertical slice once.
]]

local ExpeditionService = require(script.Parent:WaitForChild("ExpeditionService"))

ExpeditionService.start()
