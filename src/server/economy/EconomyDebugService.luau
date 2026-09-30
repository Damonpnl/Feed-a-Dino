--!strict

--[[
	In-memory economy telemetry for development balancing.
	Not persisted.
]]

local EconomyDebugService = {}

local counters = {
	coinsFromQuests = 0,
	coinsFromNpcSelling = 0,
	coinsRemovedByPurchases = 0,
	materialsSoldToNpc = 0,
	materialsPurchasedFromConveyor = 0,
	purchaseFailuresInsufficientFunds = 0,
}

function EconomyDebugService.recordQuestCoins(amount: number)
	if typeof(amount) == "number" and amount > 0 then
		counters.coinsFromQuests += amount
	end
end

function EconomyDebugService.recordNpcSellCoins(amount: number, materialCount: number)
	if typeof(amount) == "number" and amount > 0 then
		counters.coinsFromNpcSelling += amount
	end
	if typeof(materialCount) == "number" and materialCount > 0 then
		counters.materialsSoldToNpc += materialCount
	end
end

function EconomyDebugService.recordPurchase(amount: number)
	if typeof(amount) == "number" and amount > 0 then
		counters.coinsRemovedByPurchases += amount
		counters.materialsPurchasedFromConveyor += 1
	end
end

function EconomyDebugService.recordPurchaseInsufficientFunds()
	counters.purchaseFailuresInsufficientFunds += 1
end

function EconomyDebugService.getCounters()
	return table.clone(counters)
end

function EconomyDebugService.getServerSummary(): string
	local created = counters.coinsFromNpcSelling + counters.coinsFromQuests
	local removed = counters.coinsRemovedByPurchases
	local net = created - removed
	local sign = if net >= 0 then "+" else ""
	return table.concat({
		"Coins created:",
		string.format("NPC selling: %s", tostring(counters.coinsFromNpcSelling)),
		string.format("Quests: %s", tostring(counters.coinsFromQuests)),
		"",
		"Coins removed:",
		string.format("Conveyor purchases: %s", tostring(counters.coinsRemovedByPurchases)),
		"",
		string.format("Net currency creation: %s%s", sign, tostring(net)),
		string.format("Materials sold to NPC: %s", tostring(counters.materialsSoldToNpc)),
		string.format("Materials purchased: %s", tostring(counters.materialsPurchasedFromConveyor)),
		string.format("Purchase failures (funds): %s", tostring(counters.purchaseFailuresInsufficientFunds)),
	}, "\n")
end

function EconomyDebugService.resetForTests()
	counters.coinsFromQuests = 0
	counters.coinsFromNpcSelling = 0
	counters.coinsRemovedByPurchases = 0
	counters.materialsSoldToNpc = 0
	counters.materialsPurchasedFromConveyor = 0
	counters.purchaseFailuresInsufficientFunds = 0
end

return EconomyDebugService
