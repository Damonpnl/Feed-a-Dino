--!strict

--[[
	Starts rainforest environment scatter on server boot when configured.
	Development chat command: /regenrainforest
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RainforestScatterConfig = require(Shared:WaitForChild("environment"):WaitForChild("RainforestScatterConfig"))
local EnvironmentScatterService = require(script.Parent:WaitForChild("EnvironmentScatterService"))

if RainforestScatterConfig.GenerateOnStart then
	task.defer(function()
		EnvironmentScatterService.RegenerateRainforest()
	end)
end

local function bindPlayer(player: Player)
	player.Chatted:Connect(function(message)
		if not RainforestScatterConfig.Debug then
			return
		end
		if string.lower(message) == "/regenrainforest" then
			EnvironmentScatterService.RegenerateRainforest()
		end
	end)
end

for _, player in Players:GetPlayers() do
	bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)
