--!strict

--[[
	Data-driven tablet app registry (immutable presentation config).
]]

local TabletTypes = require(script.Parent:WaitForChild("TabletTypes"))

local TabletAppRegistry = {}

export type AppId = TabletTypes.AppId
export type AppDefinition = TabletTypes.AppDefinition

local apps: { [AppId]: AppDefinition } = {
	Inventory = table.freeze({
		appId = "Inventory" :: AppId,
		displayName = "Inventory",
		order = 1,
		enabled = true,
	}),
	Lineage = table.freeze({
		appId = "Lineage" :: AppId,
		displayName = "Lineage",
		order = 2,
		enabled = false,
		placeholderTitle = "LINEAGE DATABASE",
		placeholderBody = "Creature ancestry and evolution records will appear here.",
	}),
	Expedition = table.freeze({
		appId = "Expedition" :: AppId,
		displayName = "Expedition",
		order = 3,
		enabled = false,
		placeholderTitle = "EXPEDITION LOG",
		placeholderBody = "Field notes and expedition status will appear here.",
	}),
	Map = table.freeze({
		appId = "Map" :: AppId,
		displayName = "Map",
		order = 4,
		enabled = false,
		placeholderTitle = "REGIONAL MAP",
		placeholderBody = "Biome and landmark maps will appear here.",
	}),
	Codex = table.freeze({
		appId = "Codex" :: AppId,
		displayName = "Codex",
		order = 5,
		enabled = false,
		placeholderTitle = "CREATURE CODEX",
		placeholderBody = "Discovered forms and research entries will appear here.",
	}),
}

table.freeze(apps)

function TabletAppRegistry.get(appId: string): AppDefinition?
	return apps[appId :: AppId]
end

function TabletAppRegistry.isValidAppId(appId: string): boolean
	return apps[appId :: AppId] ~= nil
end

function TabletAppRegistry.getOrdered(): { AppDefinition }
	local result: { AppDefinition } = {}
	for _, definition in apps do
		table.insert(result, definition)
	end
	table.sort(result, function(a, b)
		if a.order == b.order then
			return a.appId < b.appId
		end
		return a.order < b.order
	end)
	return table.freeze(result)
end

return TabletAppRegistry
