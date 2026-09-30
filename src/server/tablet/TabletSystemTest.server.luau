--!strict

--[[
	Deterministic tablet registry / lineage presentation / PDA Tool checks.
]]

local StarterPack = game:GetService("StarterPack")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TabletConfig = require(Shared:WaitForChild("tablet"):WaitForChild("TabletConfig"))
local TabletAppRegistry = require(Shared:WaitForChild("tablet"):WaitForChild("TabletAppRegistry"))
local InventoryPresentation = require(Shared:WaitForChild("tablet"):WaitForChild("InventoryPresentation"))
local LineagePresentation = require(Shared:WaitForChild("tablet"):WaitForChild("LineagePresentation"))
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))

local CreatureState = require(script.Parent.Parent.creatures:WaitForChild("CreatureState"))
local FeedingService = require(script.Parent.Parent.creatures:WaitForChild("FeedingService"))
local TabletCreatureSnapshotService = require(script.Parent:WaitForChild("TabletCreatureSnapshotService"))
local TabletCreatureRemotes = require(script.Parent:WaitForChild("TabletCreatureRemotes"))

local function assertTrue(value: boolean, message: string)
	assert(value, message)
end

local function assertEq(a: any, b: any, message: string)
	assert(a == b, string.format("%s (got %s expected %s)", message, tostring(a), tostring(b)))
end

local function countNamed(parent: Instance, name: string): number
	local n = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			n += 1
		end
	end
	return n
end

-- Config
assertEq(TabletConfig.DefaultApp, "Inventory", "Default app Inventory")
assertEq(TabletConfig.LegacyMaterialsUiEnabled, false, "Legacy Materials UI disabled")
assertEq(TabletConfig.LegacySellPanelEnabled, false, "Legacy Sell panel disabled")

-- App registry
local inventory = TabletAppRegistry.get("Inventory")
local lineage = TabletAppRegistry.get("Lineage")
assertTrue(inventory ~= nil and inventory.enabled == true, "Inventory exists and enabled")
assertTrue(lineage ~= nil and lineage.enabled == true, "Lineage exists and enabled")
assertTrue(TabletAppRegistry.get("Expedition") ~= nil and TabletAppRegistry.get("Expedition").enabled == false, "Expedition placeholder")
assertTrue(TabletAppRegistry.get("Map") ~= nil and TabletAppRegistry.get("Map").enabled == false, "Map placeholder")
assertTrue(TabletAppRegistry.get("Codex") ~= nil and TabletAppRegistry.get("Codex").enabled == false, "Codex placeholder")
assertTrue(TabletAppRegistry.get("NotAnApp") == nil, "Unknown app fails safely")

local ordered = TabletAppRegistry.getOrdered()
assertEq(#ordered, 5, "Five apps registered")
assertEq(ordered[1].appId, "Inventory", "Inventory first")
assertEq(ordered[2].appId, "Lineage", "Lineage second")
for i = 2, #ordered do
	assertTrue(ordered[i - 1].order <= ordered[i].order, "App order deterministic")
end

-- PDA Tool
local pda = StarterPack:FindFirstChild("PDA")
assertTrue(pda ~= nil, "StarterPack.PDA exists")
assertTrue(pda:IsA("Tool"), "PDA is a Tool")
assertTrue(pda:FindFirstChild("Handle") ~= nil and pda.Handle:IsA("BasePart"), "PDA has Handle")
assertEq((pda :: Tool).RequiresHandle, true, "RequiresHandle true")

-- Rojo duplicate check
local shared = ReplicatedStorage:WaitForChild("Shared")
local client = StarterPlayer.StarterPlayerScripts:WaitForChild("Client")
local server = ServerScriptService:WaitForChild("Server")
assertEq(countNamed(shared, "tablet"), 1, "Exactly one Shared.tablet")
assertEq(countNamed(client, "tablet"), 1, "Exactly one client tablet folder")
assertEq(countNamed(server, "tablet"), 1, "Exactly one server tablet folder")
assertEq(countNamed(client.tablet, "TabletController"), 1, "Exactly one TabletController")

-- Inventory sorting sanity
local sampleMaterials: { [string]: number } = {}
for _, definition in MaterialEconomyDefinitions.getAll() do
	local presentation = FeedPresentationDefinitions.get(definition.feedId)
	if presentation and presentation.categoryId == "Basic" then
		sampleMaterials[definition.feedId] = 2
		break
	end
end
sampleMaterials["NotARealFeed"] = 99
local sorted = InventoryPresentation.sortedOwnedFeedIds(sampleMaterials)
for _, feedId in sorted do
	assertTrue(feedId ~= "NotARealFeed", "Unknown FeedId excluded")
end
assertEq(InventoryPresentation.displaySellTotal(150, 5), 750, "Canonical display total")

-- Lineage presentation helpers
assertEq(LineagePresentation.getCreatureDisplayName("MantisRaptor"), "Mantis Raptor", "Display name Mantis Raptor")
assertEq(LineagePresentation.getCreatureDisplayName("UnknownFormXYZ"), "Unknown Form XYZ", "Unknown prettify")
assertEq(LineagePresentation.getEvolutionStatusText("InsufficientGrowth"), "More growth required", "Growth status text")
assertEq(LineagePresentation.getEvolutionStatusText("InsufficientAffinity"), "Affinity profile not developed enough", "Affinity status text")
assertEq(LineagePresentation.getEvolutionStatusText("EvolutionReady"), "Evolution conditions met", "Ready status text")
assertEq(LineagePresentation.getGrowthRatio(72, 100, false), 0.72, "Growth ratio")
assertEq(LineagePresentation.getGrowthRatio(200, 100, false), 1, "Growth ratio clamped")
assertEq(LineagePresentation.formatGrowth(10, 50, true), "MAX CURRENT STAGE", "Terminal growth text")
assertTrue(LineagePresentation.isTerminalStage(2) == true, "Stage 2 terminal")
assertTrue(LineagePresentation.isTerminalStage(0) == false, "Stage 0 not terminal")

local stage0Routes = LineagePresentation.getPublicRoutesForForm("ProtoRex", 0)
assertTrue(#stage0Routes == 3, "Stage 0 has three public affinity routes")
local stage1Routes = LineagePresentation.getPublicRoutesForForm("Fangling", 1)
assertTrue(#stage1Routes == 3, "Fangling has three Stage 2 public routes")
for _, route in stage1Routes do
	assertTrue(route.formId ~= "MantisRaptor", "Public routes exclude specialized variants")
end

-- Creature history + snapshot authority (no remotes spoofing other players)
local creature = CreatureState.createProtoRex("tablet-test-creature", 1)
local history0 = CreatureState.getLineageHistory(creature)
assertEq(#history0, 1, "Initial history has ProtoRex")
assertEq(history0[1].formId, "ProtoRex", "Initial history form")

local emptyTablet = TabletCreatureSnapshotService.buildEmpty()
assertEq(emptyTablet.hasCreature, false, "Empty snapshot hasCreature false")

local tabletSnap = TabletCreatureSnapshotService.buildForState(creature)
assertEq(tabletSnap.hasCreature, true, "Snapshot has creature")
assertEq(tabletSnap.formId, "ProtoRex", "Snapshot form ProtoRex")
assertEq(tabletSnap.displayName, "Proto-Rex", "Snapshot display name")
assertEq(tabletSnap.growth, 0, "Initial growth 0")
assertEq(tabletSnap.requiredGrowth, 50, "Stage 0 required growth 50")
assertEq(tabletSnap.evolutionStatus.reason, "InsufficientGrowth", "Initial status growth")
assertTrue(tabletSnap.nextEvolution ~= nil, "Next evolution block present")
assertTrue(tabletSnap.nextEvolution.publicRoutes ~= nil, "Public routes present")
assertTrue(tabletSnap.adjustedPromotionChance == nil, "Secret promotion chance not exposed")
assertTrue(tabletSnap.predictedFinalFormId == nil, "Predicted final form not exposed on tablet snapshot")

-- Failed evolution appends nothing
local failed = FeedingService.confirmEvolution(creature)
assertTrue(failed.success == false, "Failed evolution expected")
assertEq(#CreatureState.getLineageHistory(creature), 1, "Failed evolution appends nothing")

-- Feed until ready (respect bonus-feed cap), then evolve Stage 0 -> 1
local feedAttempts = 0
while not CreatureState.isEvolutionReady(creature) and feedAttempts < 12 do
	feedAttempts += 1
	local feed = FeedingService.applyFeed(creature, "RawMeat")
	assertTrue(feed.success == true, "Feed RawMeat succeeds while growing")
end
assertTrue(CreatureState.isEvolutionReady(creature), "Creature becomes evolution ready")
local tabletReady = TabletCreatureSnapshotService.buildForState(creature)
assertEq(tabletReady.evolutionStatus.reason, "EvolutionReady", "Ready status after feeding")

local evolved = FeedingService.confirmEvolution(creature, 0.99)
assertTrue(evolved.success == true, "Stage 0 evolution succeeds")
local history1 = CreatureState.getLineageHistory(creature)
assertEq(#history1, 2, "History appends after Stage 0->1")
assertEq(history1[#history1].formId, CreatureState.getFormId(creature), "Current form is final history entry")
assertTrue(history1[#history1].routeAffinity ~= nil, "Route affinity recorded")

local afterEvolveTablet = TabletCreatureSnapshotService.buildForState(creature)
assertEq(afterEvolveTablet.formId, CreatureState.getFormId(creature), "Tablet snapshot follows evolution")
assertEq(afterEvolveTablet.evolutionQuality, 0, "Quality resets after evolution")
assertEq(#afterEvolveTablet.lineageHistory, 2, "Tablet history length 2")

-- Remotes exist
TabletCreatureRemotes.ensure()
assertTrue(TabletCreatureRemotes.get("RequestCreatureSnapshot") ~= nil, "RequestCreatureSnapshot exists")
assertTrue(TabletCreatureRemotes.get("CreatureSnapshotUpdated") ~= nil, "CreatureSnapshotUpdated exists")

-- Presentation templates published
local presentation = ReplicatedStorage:FindFirstChild("CreaturePresentationTemplates")
assertTrue(presentation ~= nil and presentation:IsA("Folder"), "Presentation templates folder exists")
assertTrue(presentation:FindFirstChild("ProtoRex") ~= nil, "ProtoRex presentation template")
assertTrue(presentation:FindFirstChild("MantisRaptor") ~= nil, "MantisRaptor presentation template")
local protoClone = presentation.ProtoRex
for _, d in protoClone:GetDescendants() do
	assertTrue(not d:IsA("BaseScript"), "No scripts in presentation clone")
	assertTrue(not d:IsA("ProximityPrompt"), "No prompts in presentation clone")
end

print("[TabletSystemTest] ALL ASSERTIONS PASSED")
print(string.format(
	"[TabletSystemTest] PDA=%s LineageEnabled=%s Templates=%d SharedTabletCopies=%d",
	pda:GetFullName(),
	tostring(lineage.enabled),
	#presentation:GetChildren(),
	countNamed(shared, "tablet")
))
