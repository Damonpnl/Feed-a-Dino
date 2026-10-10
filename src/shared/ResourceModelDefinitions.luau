--!strict
-- Explicit graybox fallback for each key; final templates go in ServerStorage.ResourceModels.
local Resources = require(script.Parent.ResourceDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local models = {}
for _, resource in Resources.getAll() do
	models[resource.ModelKey] = { Placeholder = true, Size = Vector3.new(2.4, 2.4, 2.4), Color = Rarities.getColor(resource.Rarity) }
end
return models
