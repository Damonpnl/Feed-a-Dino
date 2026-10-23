--!strict

local errors = require(game.ReplicatedStorage.Shared.DefinitionValidation).config()
assert(#errors == 0, "[DefinitionValidation] " .. table.concat(errors, "; "))
print("[DefinitionValidation] PASS 5 areas, 40 launch resources, pet references, trainer ladder, billboard configuration")

local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local FeedService = require(script.Parent.FeedService)
local GuardianService = require(script.Parent.GuardianService)
local MonsterService = require(script.Parent.MonsterService)
local SpawnService = require(script.Parent.SpawnService)
local TrainingService = require(script.Parent.TrainingService)

DataService.start()

MonsterService.start()
CarryService.start()
GuardianService.start()
SpawnService.start()
FeedService.start()
TrainingService.start()
BaseService.start()
require(script.Parent.DevTestService).start()
