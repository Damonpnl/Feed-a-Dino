--!strict

--[[
	Pure inventory presentation helpers for the Research Tablet.
	No Roblox service access / no player mutation.
]]

local FeedPresentationDefinitions = require(script.Parent.Parent:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))
local MaterialEconomyDefinitions = require(script.Parent.Parent:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))

local InventoryPresentation = {}

local CATEGORY_ORDER: { [string]: number } = {
	Basic = 1,
	Premium = 2,
	Specialized = 3,
}

function InventoryPresentation.categorySortKey(categoryId: string?): number
	if categoryId == nil then
		return 99
	end
	return CATEGORY_ORDER[categoryId] or 99
end

function InventoryPresentation.sortedOwnedFeedIds(materials: { [string]: number }): { string }
	local ids = {}
	for feedId, amount in materials do
		if amount > 0 and MaterialEconomyDefinitions.get(feedId) ~= nil then
			table.insert(ids, feedId)
		end
	end
	table.sort(ids, function(a, b)
		local pa = FeedPresentationDefinitions.get(a)
		local pb = FeedPresentationDefinitions.get(b)
		local ca = InventoryPresentation.categorySortKey(if pa then pa.categoryId else nil)
		local cb = InventoryPresentation.categorySortKey(if pb then pb.categoryId else nil)
		if ca ~= cb then
			return ca < cb
		end
		local na = if pa then pa.displayName else a
		local nb = if pb then pb.displayName else b
		return na < nb
	end)
	return ids
end

function InventoryPresentation.requiresStackConfirm(feedId: string): boolean
	local presentation = FeedPresentationDefinitions.get(feedId)
	if presentation == nil then
		return true
	end
	return presentation.categoryId == "Premium" or presentation.categoryId == "Specialized"
end

function InventoryPresentation.displaySellTotal(unitPrice: number, amount: number): number
	return math.max(0, math.floor(unitPrice)) * math.max(0, math.floor(amount))
end

function InventoryPresentation.nextSelectedAfterDeplete(
	materials: { [string]: number },
	previousFeedId: string?
): string?
	local ids = InventoryPresentation.sortedOwnedFeedIds(materials)
	if #ids == 0 then
		return nil
	end
	if previousFeedId ~= nil and (materials[previousFeedId] or 0) > 0 then
		return previousFeedId
	end
	return ids[1]
end

return InventoryPresentation
