--!strict

--[[
	Shared tablet presentation types. No Roblox service access.
]]

local TabletTypes = {}

export type AppId = "Inventory" | "Lineage" | "Expedition" | "Map" | "Codex"

export type AppDefinition = {
	appId: AppId,
	displayName: string,
	order: number,
	enabled: boolean,
	placeholderTitle: string?,
	placeholderBody: string?,
}

export type TabletPresentationState = {
	isEquipped: boolean,
	isOpen: boolean,
	activeApp: AppId,
	sellMode: boolean,
	sellSessionAuthorized: boolean,
	walletBalance: number,
	inventorySnapshot: {
		materials: { [string]: number },
		totalItems: number,
	},
}

return TabletTypes
