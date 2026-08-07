--!strict

--[[
	Deterministic tablet registry / presentation / PDA Tool checks.
]]

local StarterPack = game:GetService("StarterPack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TabletConfig = require(Shared:WaitForChild("tablet"):WaitForChild("TabletConfig"))
local TabletAppRegistry = require(Shared:WaitForChild("tablet"):WaitForChild("TabletAppRegistry"))
local InventoryPresentation = require(Shared:WaitForChild("tablet"):WaitForChild("InventoryPresentation"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))

local function assertTrue(value: boolean, message: string)
	assert(value, message)
end

local function assertEq(a: any, b: any, message: string)
	assert(a == b, string.format("%s (got %s expected %s)", message, tostring(a), tostring(b)))
end

-- Config
assertEq(TabletConfig.DefaultApp, "Inventory", "Default app Inventory")
assertEq(TabletConfig.LegacyMaterialsUiEnabled, false, "Legacy Materials UI disabled")
assertEq(TabletConfig.LegacySellPanelEnabled, false, "Legacy Sell panel disabled")
assertTrue(TabletConfig.KeepStandaloneWalletHud == true, "Standalone wallet HUD kept")

-- App registry
local inventory = TabletAppRegistry.get("Inventory")
assertTrue(inventory ~= nil and inventory.enabled == true, "Inventory exists and enabled")
assertTrue(TabletAppRegistry.get("Lineage") ~= nil, "Lineage exists")
assertTrue(TabletAppRegistry.get("Expedition") ~= nil, "Expedition exists")
assertTrue(TabletAppRegistry.get("Map") ~= nil, "Map exists")
assertTrue(TabletAppRegistry.get("Codex") ~= nil, "Codex exists")
assertTrue(TabletAppRegistry.get("NotAnApp") == nil, "Unknown app fails safely")
assertTrue(TabletAppRegistry.isValidAppId("Inventory"), "Inventory valid")
assertTrue(not TabletAppRegistry.isValidAppId("NotAnApp"), "Unknown invalid")

local ordered = TabletAppRegistry.getOrdered()
assertEq(#ordered, 5, "Five apps registered")
for i = 2, #ordered do
	assertTrue(ordered[i - 1].order <= ordered[i].order, "App order deterministic")
end
assertEq(ordered[1].appId, "Inventory", "Inventory first")

-- PDA Tool
local pda = StarterPack:FindFirstChild("PDA")
assertTrue(pda ~= nil, "StarterPack.PDA exists")
assertTrue(pda:IsA("Tool"), "PDA is a Tool")
local handle = pda:FindFirstChild("Handle")
assertTrue(handle ~= nil and handle:IsA("BasePart"), "PDA has Handle")
assertEq((pda :: Tool).RequiresHandle, true, "RequiresHandle true")

-- Sorting / presentation helpers
local sampleMaterials: { [string]: number } = {}
local foundBasic, foundPremium, foundSpecialized = false, false, false
for _, definition in MaterialEconomyDefinitions.getAll() do
	local feedId = definition.feedId
	local presentation = FeedPresentationDefinitions.get(feedId)
	if presentation then
		if presentation.categoryId == "Basic" and not foundBasic then
			sampleMaterials[feedId] = 2
			foundBasic = true
		elseif presentation.categoryId == "Premium" and not foundPremium then
			sampleMaterials[feedId] = 1
			foundPremium = true
		elseif presentation.categoryId == "Specialized" and not foundSpecialized then
			sampleMaterials[feedId] = 3
			foundSpecialized = true
		end
	end
end
sampleMaterials["NotARealFeed"] = 99

local sorted = InventoryPresentation.sortedOwnedFeedIds(sampleMaterials)
assertTrue(#sorted >= 1, "Owned materials sort non-empty when economy feeds exist")
for _, feedId in sorted do
	assertTrue(feedId ~= "NotARealFeed", "Unknown FeedId excluded from inventory list")
	assertTrue((sampleMaterials[feedId] or 0) > 0, "Zero/unknown hidden")
end

if foundBasic and foundPremium then
	local firstCat = FeedPresentationDefinitions.get(sorted[1])
	assertTrue(firstCat ~= nil and firstCat.categoryId == "Basic", "Basic sorts before Premium")
end

assertEq(InventoryPresentation.displaySellTotal(150, 5), 750, "Canonical display total 5x150")
assertTrue(InventoryPresentation.requiresStackConfirm("InsectCluster") == true, "Specialized stack requires confirm")
assertTrue(InventoryPresentation.requiresStackConfirm("RawMeat") == false, "Basic stack skips confirm")

local depleted = table.clone(sampleMaterials)
local firstOwned = sorted[1]
if firstOwned then
	depleted[firstOwned] = 0
	local nextId = InventoryPresentation.nextSelectedAfterDeplete(depleted, firstOwned)
	if nextId ~= nil then
		assertTrue((depleted[nextId] or 0) > 0, "Advance selection after deplete")
	end
end

local emptyNext = InventoryPresentation.nextSelectedAfterDeplete({}, "RawMeat")
assertEq(emptyNext, nil, "Empty inventory clears selection")

print("[TabletSystemTest] ALL ASSERTIONS PASSED")
print(string.format(
	"[TabletSystemTest] PDA=%s RequiresHandle=%s LegacyMaterials=%s LegacySell=%s",
	pda:GetFullName(),
	tostring((pda :: Tool).RequiresHandle),
	tostring(TabletConfig.LegacyMaterialsUiEnabled),
	tostring(TabletConfig.LegacySellPanelEnabled)
))
