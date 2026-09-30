--!strict

--[[
	Deterministic material-economy vertical-slice tests.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Prevent duplicate Rojo/Studio copies from racing the same player state.
if ReplicatedStorage:FindFirstChild("__EconomySystemTestLock") then
	return
end
local lock = Instance.new("BoolValue")
lock.Name = "__EconomySystemTestLock"
lock.Parent = ReplicatedStorage

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MaterialEconomyDefinitions = require(Shared:WaitForChild("economy"):WaitForChild("MaterialEconomyDefinitions"))
local FeedPresentationDefinitions = require(Shared:WaitForChild("creatures"):WaitForChild("FeedPresentationDefinitions"))
local ConveyorSpawnWeights = require(Shared:WaitForChild("creatures"):WaitForChild("ConveyorSpawnWeights"))
local ExpeditionQuestDefinitions = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionQuestDefinitions"))

local WalletService = require(script.Parent:WaitForChild("WalletService"))
local EconomyDebugService = require(script.Parent:WaitForChild("EconomyDebugService"))
local EconomyRemotes = require(script.Parent:WaitForChild("EconomyRemotes"))
local ConveyorPurchaseService = require(script.Parent:WaitForChild("ConveyorPurchaseService"))
local NpcSellService = require(script.Parent:WaitForChild("NpcSellService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local SecuredMaterialInventoryService = require(script.Parent.Parent.expedition:WaitForChild("SecuredMaterialInventoryService"))
local FieldBagService = require(script.Parent.Parent.expedition:WaitForChild("FieldBagService"))
local ExpeditionQuestService = require(script.Parent.Parent.expedition:WaitForChild("ExpeditionQuestService"))

local function assertTrue(value: boolean, message: string)
	assert(value, message)
end

local function assertEq(a: any, b: any, message: string)
	assert(a == b, string.format("%s (got %s expected %s)", message, tostring(a), tostring(b)))
end

EconomyService.start()
EconomyRemotes.ensure()

-- Definition checks run immediately; player checks wait so expedition tests finish first.
-- 1-8 Economy definitions
local ids = MaterialEconomyDefinitions.getFeedIds()
assertEq(#ids, 9, "All nine feeds have economy definitions")
local seen: { [string]: boolean } = {}
for _, feedId in ids do
	assertTrue(seen[feedId] ~= true, "No duplicate FeedIds")
	seen[feedId] = true
end

local expectedPurchase = {
	RawMeat = 60,
	LeafBundle = 60,
	CrystalChunk = 60,
	PrimeMeat = 240,
	AncientFruit = 240,
	LivingCrystal = 240,
	InsectCluster = 360,
	FungalCore = 360,
	ObsidianShard = 360,
}
local expectedSell = {
	RawMeat = 25,
	LeafBundle = 25,
	CrystalChunk = 25,
	PrimeMeat = 100,
	AncientFruit = 100,
	LivingCrystal = 100,
	InsectCluster = 150,
	FungalCore = 150,
	ObsidianShard = 150,
}
for feedId, price in expectedPurchase do
	assertEq(MaterialEconomyDefinitions.getPurchasePrice(feedId), price, feedId .. " purchase price")
	assertEq(MaterialEconomyDefinitions.getNpcSellPrice(feedId), expectedSell[feedId], feedId .. " npc sell price")
	local def = MaterialEconomyDefinitions.get(feedId)
	assertTrue(def ~= nil and def.npcSellPrice < def.purchasePrice, feedId .. " sell < purchase")
	assertEq(FeedPresentationDefinitions.get(feedId).purchasePrice, price, feedId .. " presentation mirrors economy")
end

local negOk, negReason = MaterialEconomyDefinitions.validateRaw({
	feedId = "RawMeat",
	purchasePrice = -1,
	npcSellPrice = 25,
})
assertTrue(negOk == nil and negReason == "NegativePrice", "Negative price rejected")

local fracOk, fracReason = MaterialEconomyDefinitions.validateRaw({
	feedId = "RawMeat",
	purchasePrice = 60.5,
	npcSellPrice = 25,
})
assertTrue(fracOk == nil and fracReason == "FractionalPrice", "Fractional price rejected")

local coverageOk = MaterialEconomyDefinitions.validateLivePoolCoverage()
assertTrue(coverageOk, "Live pool covered by economy defs")

-- 9-16 Wallet
task.wait(2) -- let ExpeditionSystemTest finish mutating shared player quest/wallet state
EconomyDebugService.resetForTests()

local testPlayer = Players:GetPlayers()[1]
if testPlayer == nil then
	testPlayer = Players.PlayerAdded:Wait()
end
assertTrue(testPlayer ~= nil, "Need a player for wallet/inventory tests")
if testPlayer.Character == nil then
	local character = testPlayer.CharacterAdded:Wait()
	assertTrue(character ~= nil, "Need character for purchase carry tests")
end
task.wait(0.25)

-- Mute client economy events so playtests don't see fake purchases/sells/UI.
EconomyRemotes.setMuted(true)

local restored = false
local function restorePlayerAfterTests()
	if restored then
		return
	end
	restored = true
	NpcSellService.closeSession(testPlayer, true)
	SecuredMaterialInventoryService.clear(testPlayer)
	FieldBagService.clear(testPlayer)
	WalletService.setBalanceForTests(testPlayer, WalletService.STARTING_COINS)
	local liveCharacter = testPlayer.Character
	if liveCharacter then
		liveCharacter:SetAttribute("CarryingItem", nil)
		local carriedItem = liveCharacter:FindFirstChild("CarriedMeat")
		if carriedItem then
			carriedItem:Destroy()
		end
	end
	for _, child in Workspace:GetChildren() do
		if string.match(child.Name, "^EconomyTestMaterial_") then
			child:Destroy()
		end
	end
	EconomyRemotes.setMuted(false)
	EconomyRemotes.fire(testPlayer, "WalletUpdated", WalletService.getSnapshot(testPlayer))
	EconomyRemotes.fire(testPlayer, "InventoryUpdated", SecuredMaterialInventoryService.getSnapshot(testPlayer))
	EconomyRemotes.fire(testPlayer, "SellSessionClosed", {})
end

-- Always unmute/restore even if a later assert fails mid-suite.
task.delay(12, restorePlayerAfterTests)

WalletService.clearForTests(testPlayer)
WalletService.initializePlayer(testPlayer)
assertEq(WalletService.getBalance(testPlayer), 500, "Starting balance 500")

assertTrue(WalletService.addCoins(testPlayer, 50, "TestAdd"), "Add coins works")
assertEq(WalletService.getBalance(testPlayer), 550, "Balance after add")
assertTrue(WalletService.trySpend(testPlayer, 50, "TestSpend"), "Spend works")
assertEq(WalletService.getBalance(testPlayer), 500, "Balance after spend")

local beforeNeg = WalletService.getBalance(testPlayer)
assertTrue(not WalletService.addCoins(testPlayer, -5, "Bad"), "Negative add rejected")
assertTrue(not WalletService.trySpend(testPlayer, 1.5, "Bad"), "Fractional spend rejected")
assertTrue(not WalletService.trySpend(testPlayer, (0 / 0), "Bad"), "NaN rejected")
assertTrue(not WalletService.trySpend(testPlayer, math.huge, "Bad"), "Infinity rejected")
assertEq(WalletService.getBalance(testPlayer), beforeNeg, "Failed spend leaves balance unchanged")
assertTrue(not WalletService.trySpend(testPlayer, 999999, "TooMuch"), "Cannot go negative")
assertEq(WalletService.getBalance(testPlayer), beforeNeg, "Overspend unchanged")

-- 17-30 Conveyor purchase
local function makeMaterial(feedId: string): BasePart
	local part = Instance.new("Part")
	part.Name = "EconomyTestMaterial_" .. feedId
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Parent = Workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = part
	ConveyorPurchaseService.register(part, feedId, prompt, nil)
	return part
end

WalletService.setBalanceForTests(testPlayer, 500)
local raw = makeMaterial("RawMeat")
assertEq(MaterialEconomyDefinitions.getPurchasePrice("RawMeat"), 60, "RawMeat costs 60")
assertEq(MaterialEconomyDefinitions.getPurchasePrice("PrimeMeat"), 240, "PrimeMeat costs 240")
assertEq(MaterialEconomyDefinitions.getPurchasePrice("InsectCluster"), 360, "InsectCluster costs 360")

-- Ensure character exists for carry
if testPlayer.Character == nil then
	testPlayer:LoadCharacter()
	testPlayer.CharacterAdded:Wait()
end
local character = testPlayer.Character :: Model
character:SetAttribute("CarryingItem", nil)
local carried = character:FindFirstChild("CarriedMeat")
if carried then
	carried:Destroy()
end

local okBuy = ConveyorPurchaseService.tryPurchase(testPlayer, raw)
assertTrue(okBuy, "Successful RawMeat purchase")
assertEq(WalletService.getBalance(testPlayer), 440, "Purchase removes exact 60")
assertTrue(ConveyorPurchaseService.isOwner(testPlayer, raw), "Owner assigned")
assertTrue(raw:GetAttribute("IsPurchased") == true, "IsPurchased set")
assertTrue(not ConveyorPurchaseService.tryPurchase(testPlayer, raw), "Cannot purchase again")

local poor = makeMaterial("PrimeMeat")
WalletService.setBalanceForTests(testPlayer, 10)
local beforePoor = WalletService.getBalance(testPlayer)
character:SetAttribute("CarryingItem", nil)
local leftover = character:FindFirstChild("CarriedMeat")
if leftover then
	leftover:Destroy()
end
local okPoor, poorReason = ConveyorPurchaseService.tryPurchase(testPlayer, poor)
assertTrue(not okPoor and poorReason == "InsufficientFunds", "Insufficient funds fails")
assertEq(WalletService.getBalance(testPlayer), beforePoor, "Insufficient funds removes no coins")
assertEq(poor:GetAttribute("MaterialState"), "Available", "Material remains available")

-- Simultaneous purchase: first wins
WalletService.setBalanceForTests(testPlayer, 500)
character:SetAttribute("CarryingItem", nil)
local contested = makeMaterial("LeafBundle")
local firstOk = ConveyorPurchaseService.tryPurchase(testPlayer, contested)
assertTrue(firstOk, "First buyer wins")
local secondOk = ConveyorPurchaseService.tryPurchase(testPlayer, contested)
assertTrue(not secondOk, "Second buyer fails")

-- Ownership use check
assertTrue(ConveyorPurchaseService.canPlayerUse(testPlayer, contested), "Owner can use")
-- Fake non-owner attributes on a clone
local strangerPart = makeMaterial("CrystalChunk")
strangerPart:SetAttribute("IsPurchased", true)
strangerPart:SetAttribute("OwnerUserId", testPlayer.UserId + 999)
local strangerRecord = ConveyorPurchaseService.getRecord(strangerPart)
if strangerRecord then
	strangerRecord.state = "Purchased"
	strangerRecord.ownerUserId = testPlayer.UserId + 999
end
assertTrue(not ConveyorPurchaseService.canPlayerUse(testPlayer, strangerPart), "Non-owner cannot use")

-- Unknown feed cannot register/purchase via economy
assertTrue(MaterialEconomyDefinitions.get("NotAFeed") == nil, "Unknown feed has no economy def")

raw:Destroy()
poor:Destroy()
contested:Destroy()
strangerPart:Destroy()

-- 31-36 Inventory
SecuredMaterialInventoryService.clear(testPlayer)
assertTrue(SecuredMaterialInventoryService.addMaterial(testPlayer, "RawMeat", 3), "addMaterial works")
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 3, "Count 3")
assertTrue(SecuredMaterialInventoryService.removeMaterial(testPlayer, "RawMeat", 1), "removeMaterial works")
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 2, "Count 2")
assertTrue(not SecuredMaterialInventoryService.addMaterial(testPlayer, "RawMeat", -1), "Invalid amount fails")
assertTrue(not SecuredMaterialInventoryService.addMaterial(testPlayer, "NotAFeed", 1), "Unknown FeedId fails")
local snap = SecuredMaterialInventoryService.getSnapshot(testPlayer)
snap.materials.RawMeat = 999
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 2, "Snapshot cannot mutate server")

-- Expedition bank remains visible
FieldBagService.clear(testPlayer)
FieldBagService.addMaterial(testPlayer, "InsectCluster", 2)
FieldBagService.bankAll(testPlayer)
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "InsectCluster"), 2, "Banked materials visible")

-- 37-46 NPC selling
WalletService.setBalanceForTests(testPlayer, 0)
SecuredMaterialInventoryService.clear(testPlayer)
SecuredMaterialInventoryService.addMaterial(testPlayer, "RawMeat", 2)
SecuredMaterialInventoryService.addMaterial(testPlayer, "PrimeMeat", 1)
SecuredMaterialInventoryService.addMaterial(testPlayer, "InsectCluster", 1)

-- Unauthorized sell fails
assertTrue(not NpcSellService.sellOne(testPlayer, "RawMeat"), "Unauthorized sell fails")

-- Authorize silently for tests. Do NOT teleport the player or open client sell UI.
NpcSellService.authorizeSessionForTests(testPlayer)
assertTrue(NpcSellService.isSessionActive(testPlayer), "Test sell session authorized")

local beforeSell = WalletService.getBalance(testPlayer)
local ok1, _, payout1 = NpcSellService.sellOne(testPlayer, "RawMeat")
assertTrue(ok1 and payout1 == 25, "Sell one RawMeat = 25")
assertEq(WalletService.getBalance(testPlayer), beforeSell + 25, "Wallet +25")
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 1, "RawMeat left 1")

local okPrime, _, payoutPrime = NpcSellService.sellOne(testPlayer, "PrimeMeat")
assertTrue(okPrime and payoutPrime == 100, "Sell PrimeMeat = 100")

local okInsect, _, payoutInsect = NpcSellService.sellOne(testPlayer, "InsectCluster")
assertTrue(okInsect and payoutInsect == 150, "Sell InsectCluster = 150")

SecuredMaterialInventoryService.addMaterial(testPlayer, "RawMeat", 3)
local okStack, _, payoutStack = NpcSellService.sellAllOfType(testPlayer, "RawMeat")
assertTrue(okStack and payoutStack == 100, "Sell stack multiplies exactly")
-- After previous sellOne RawMeat left 1, plus add 3 = 4; 4*25=100
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 0, "Stack sold all")

assertTrue(not NpcSellService.sellOne(testPlayer, "RawMeat"), "Cannot sell more than owned")

NpcSellService.closeSession(testPlayer, true)
assertTrue(not NpcSellService.sellOne(testPlayer, "PrimeMeat"), "Sell outside session fails")

-- Field bag cannot be sold directly
FieldBagService.clear(testPlayer)
FieldBagService.addMaterial(testPlayer, "RawMeat", 5)
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 0, "Field bag not in secured")
assertTrue(not NpcSellService.sellOne(testPlayer, "RawMeat"), "Field-bag materials cannot be sold")

-- 47-51 Quests
local bugDef = ExpeditionQuestDefinitions.get("SavannahBugCollector")
assertEq(bugDef and bugDef.coinReward, 150, "Bug Collector 150 coins")
assertEq(ExpeditionQuestDefinitions.get("SavannahCrystalSurvey").coinReward, 250, "Crystal Survey 250")
assertEq(ExpeditionQuestDefinitions.get("SavannahWateringHole").coinReward, 100, "Watering Hole 100")

ExpeditionQuestService.clear(testPlayer)
WalletService.setBalanceForTests(testPlayer, 100)
local assigned = ExpeditionQuestService.assignNextIfNeeded(testPlayer)
assertEq(assigned.questId, "SavannahBugCollector", "Fresh quest assign Bug Collector")
local beforeQuest = WalletService.getBalance(testPlayer)
ExpeditionQuestService.onInsectClusterGathered(testPlayer, 3)
local afterQuest = WalletService.getBalance(testPlayer)
assertEq(afterQuest - beforeQuest, 150, "Quest reward grants coins")
local completed = ExpeditionQuestService.getSnapshot(testPlayer)
assertTrue(completed.completedIds.SavannahBugCollector == true, "Quest completed once")
ExpeditionQuestService.onInsectClusterGathered(testPlayer, 3)
assertEq(WalletService.getBalance(testPlayer), afterQuest, "Quest reward grants once")

-- 52-54 Recovery
WalletService.setBalanceForTests(testPlayer, 0)
FieldBagService.clear(testPlayer)
assertTrue(FieldBagService.addMaterial(testPlayer, "RawMeat", 2), "Zero coins can still gather into field bag")
assertTrue(FieldBagService.bankAll(testPlayer), "Zero coins can bank")
assertEq(SecuredMaterialInventoryService.getMaterialCount(testPlayer, "RawMeat"), 2, "Banked after zero-coin gather")
NpcSellService.authorizeSessionForTests(testPlayer)
local okRecover = NpcSellService.sellAllOfType(testPlayer, "RawMeat")
assertTrue(okRecover, "Can sell banked resources to regain coins")
assertTrue(WalletService.getBalance(testPlayer) > 0, "Regained coins")
NpcSellService.closeSession(testPlayer, true)

-- 58-59 Conveyor pool regression
local pool = ConveyorSpawnWeights.getProductionPool()
local total = 0
for _, entry in pool do
	total += entry.weight
end
assertEq(total, 99, "Conveyor weighted pool still totals 99")
assertEq(#ConveyorSpawnWeights.getFeedIds(pool), 9, "All nine materials still in pool")

restorePlayerAfterTests()

print("[EconomySystemTest] ALL ASSERTIONS PASSED")
print("[EconomySystemTest] Debug summary:\n" .. EconomyDebugService.getServerSummary())
print(string.format(
	"[EconomySystemTest] SellStation=%s InventoryTerminal=missing",
	tostring(NpcSellService.hasSellStation())
))
