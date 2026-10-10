--!strict
local Definitions = require(script.Parent.ResourceDefinitions)
local Types = require(script.Parent.ResourceTypes)
local FeedDefinitions = {}
export type FeedDefinition = Types.ResourceDefinition
local items = {}
for id, definition in Definitions.getAll() do
	if definition.ResourceType == "Feed" then items[id] = definition end
end
function FeedDefinitions.get(id: string): FeedDefinition? return items[id] end
function FeedDefinitions.getAll(): { [string]: FeedDefinition } return items end
return FeedDefinitions
