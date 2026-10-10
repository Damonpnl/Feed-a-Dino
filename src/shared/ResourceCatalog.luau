--!strict

local CatalystDefinitions = require(script.Parent.CatalystDefinitions)
local FeedDefinitions = require(script.Parent.FeedDefinitions)
local ResourceTypes = require(script.Parent.ResourceTypes)

local ResourceCatalog = {}

export type ResourceDefinition = ResourceTypes.ResourceDefinition

function ResourceCatalog.get(id: string): ResourceDefinition?
	local feed = FeedDefinitions.get(id)
	if feed ~= nil then
		return feed
	end
	return CatalystDefinitions.get(id)
end

function ResourceCatalog.getAll(): { [string]: ResourceDefinition }
	return require(script.Parent.ResourceDefinitions).getAll()
end

return ResourceCatalog
