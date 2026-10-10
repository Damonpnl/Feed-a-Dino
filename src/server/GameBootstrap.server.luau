--!strict

local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local FeedService = require(script.Parent.FeedService)
local GuardianService = require(script.Parent.GuardianService)
local MonsterService = require(script.Parent.MonsterService)
local SpawnService = require(script.Parent.SpawnService)
local TrainingService = require(script.Parent.TrainingService)

DataService.start()
Players.PlayerAdded:Connect(function(player)
	DataService.load(player)
end)
for _, player in Players:GetPlayers() do
	DataService.load(player)
end

MonsterService.start()
CarryService.start()
GuardianService.start()
SpawnService.start()
FeedService.start()
TrainingService.start()
BaseService.start()
