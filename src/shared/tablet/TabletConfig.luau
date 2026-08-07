--!strict

--[[
	Immutable tablet presentation config.
]]

return table.freeze({
	DeviceTitle = "RESEARCH TABLET",
	DefaultApp = "Inventory" :: string,
	OpenTransitionSeconds = 0.2,
	CloseTransitionSeconds = 0.15,

	-- Prefer discovered Tool named PDA; fallback names if Studio renames slightly.
	PdaToolCandidateNames = table.freeze({ "PDA", "ResearchTablet", "Tablet" }),

	-- Legacy standalone economy panels (Materials button / Sell panel).
	LegacyMaterialsUiEnabled = false,
	LegacySellPanelEnabled = false,

	-- Keep compact outside-tablet wallet HUD.
	KeepStandaloneWalletHud = true,
})
