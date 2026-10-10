--!strict
local Definitions = require(script.Parent.ResourceDefinitions)
local Types = require(script.Parent.ResourceTypes)
local CatalystDefinitions = {}
export type CatalystDefinition = Types.ResourceDefinition
local items = {}
for id, definition in Definitions.getAll() do
	if definition.ResourceType == "Catalyst" then items[id] = definition end
end
function CatalystDefinitions.get(id: string): CatalystDefinition? return items[id] end
function CatalystDefinitions.getAll(): { [string]: CatalystDefinition } return items end
return CatalystDefinitions
