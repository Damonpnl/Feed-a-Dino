--!strict

--[[
	Pure presentation helpers for the Research Tablet Lineage app.
	No Roblox service access / no authoritative creature mutation.
]]

local Creatures = script.Parent.Parent:WaitForChild("creatures")
local LineageDefinitions = require(Creatures:WaitForChild("LineageDefinitions"))
local Stage2Routes = require(Creatures:WaitForChild("Stage2Routes"))
local StageConfig = require(Creatures:WaitForChild("StageConfig"))

local LineagePresentation = {}

local AFFINITY_ORDER = table.freeze({ "Flesh", "Flora", "Mineral" })
local INFLUENCE_ORDER = table.freeze({ "Arthropod", "Fungal", "Volcanic" })

local STATUS_TEXT: { [string]: string } = table.freeze({
	InsufficientGrowth = "More growth required",
	InsufficientAffinity = "Affinity profile not developed enough",
	EvolutionReady = "Evolution conditions met",
	UnsupportedStage = "MAX CURRENT STAGE",
	NotReady = "Not ready to evolve",
	NoRoute = "No evolution route available",
	InvalidParentForm = "Lineage data incomplete",
	AlreadyResolving = "Evolution in progress",
})

local RARITY_COLORS: { [string]: Color3 } = table.freeze({
	Common = Color3.fromRGB(200, 210, 215),
	Uncommon = Color3.fromRGB(90, 200, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 100, 255),
	Legendary = Color3.fromRGB(255, 180, 60),
	Mythic = Color3.fromRGB(255, 90, 140),
	Secret = Color3.fromRGB(255, 230, 120),
})

local warnedUnknownForms: { [string]: boolean } = {}

function LineagePresentation.prettifyId(id: string): string
	local withSpaces = string.gsub(id, "(%l)(%u)", "%1 %2")
	withSpaces = string.gsub(withSpaces, "(%u)(%u%l)", "%1 %2")
	return withSpaces
end

function LineagePresentation.getCreatureDisplayName(formId: string?): string
	if formId == nil or formId == "" then
		return "Unknown Specimen"
	end
	local definition = LineageDefinitions.get(formId)
	if definition ~= nil then
		return definition.displayName
	end
	if warnedUnknownForms[formId] ~= true then
		warnedUnknownForms[formId] = true
		warn("[LineagePresentation] Unknown creature formId=" .. formId)
	end
	return LineagePresentation.prettifyId(formId)
end

function LineagePresentation.getAffinityDisplayName(affinityId: string?): string
	if affinityId == nil or affinityId == "" then
		return "None"
	end
	return affinityId
end

function LineagePresentation.getInfluenceDisplayName(influenceId: string?): string
	if influenceId == nil or influenceId == "" then
		return "None"
	end
	return influenceId
end

function LineagePresentation.getEvolutionStatusText(reason: string?): string
	if reason == nil or reason == "" then
		return "Status unavailable"
	end
	return STATUS_TEXT[reason] or LineagePresentation.prettifyId(reason)
end

function LineagePresentation.getRarityText(rarity: string?): string
	if rarity == nil or rarity == "" then
		return "Unknown"
	end
	return rarity
end

function LineagePresentation.getRarityColor(rarity: string?): Color3
	if rarity == nil then
		return Color3.fromRGB(180, 190, 195)
	end
	return RARITY_COLORS[rarity] or Color3.fromRGB(180, 190, 195)
end

function LineagePresentation.getQualityLabel(quality: number): string
	if quality <= 0 then
		return "Standard"
	elseif quality < 20 then
		return "Improved"
	elseif quality < 40 then
		return "Better"
	end
	return "Excellent"
end

function LineagePresentation.getGrowthRatio(growth: number, requiredGrowth: number?, isTerminal: boolean): number
	if isTerminal or requiredGrowth == nil or requiredGrowth <= 0 then
		return 1
	end
	local ratio = growth / requiredGrowth
	if ratio ~= ratio then
		return 0
	end
	return math.clamp(ratio, 0, 1)
end

function LineagePresentation.formatGrowth(growth: number, requiredGrowth: number?, isTerminal: boolean): string
	if isTerminal then
		return "MAX CURRENT STAGE"
	end
	local required = requiredGrowth or 0
	return string.format("%d / %d", math.floor(growth), math.floor(required))
end

function LineagePresentation.sortedAffinityRows(totals: { [string]: number }?): { { id: string, value: number } }
	local rows = {}
	for _, affinityId in AFFINITY_ORDER do
		local value = if totals then (totals[affinityId] or 0) else 0
		table.insert(rows, { id = affinityId, value = value })
	end
	return rows
end

function LineagePresentation.sortedInfluenceRows(totals: { [string]: number }?): { { id: string, value: number } }
	local rows = {}
	for _, influenceId in INFLUENCE_ORDER do
		local value = if totals then (totals[influenceId] or 0) else 0
		table.insert(rows, { id = influenceId, value = value })
	end
	return rows
end

function LineagePresentation.formatHistoryConnector(entry: {
	routeAffinity: string?,
	specializedInfluence: string?,
}?): string
	if entry == nil then
		return "↓"
	end
	local affinity = entry.routeAffinity
	local influence = entry.specializedInfluence
	if affinity ~= nil and influence ~= nil then
		return string.format("↓ %s + %s", affinity, influence)
	elseif affinity ~= nil then
		return string.format("↓ %s", affinity)
	elseif influence ~= nil then
		return string.format("↓ %s", influence)
	end
	return "↓"
end

export type PublicRoute = {
	affinityId: string,
	formId: string,
	displayName: string,
}

function LineagePresentation.getPublicRoutesForForm(formId: string, stage: number): { PublicRoute }
	local routes: { PublicRoute } = {}
	if stage == 0 then
		for _, affinityId in AFFINITY_ORDER do
			local juvenile = LineageDefinitions.getJuvenileByAffinity(affinityId)
			if juvenile ~= nil then
				table.insert(routes, {
					affinityId = affinityId,
					formId = juvenile.id,
					displayName = juvenile.displayName,
				})
			end
		end
		return routes
	end

	if stage == 1 then
		local tableForForm = Stage2Routes.getRouteTable(formId)
		if tableForForm == nil then
			return routes
		end
		for _, affinityId in AFFINITY_ORDER do
			local nextFormId = tableForForm[affinityId]
			if nextFormId ~= nil then
				table.insert(routes, {
					affinityId = affinityId,
					formId = nextFormId,
					displayName = LineagePresentation.getCreatureDisplayName(nextFormId),
				})
			end
		end
	end
	return routes
end

function LineagePresentation.isTerminalStage(stage: number): boolean
	return not StageConfig.isSupportedEvolutionStage(stage)
end

return LineagePresentation
