local Shared = game.ReplicatedStorage.Shared
local Chase = require(Shared.GuardianChase)
local Resources = require(Shared.ResourceDefinitions)
return function(t)
	local function candidate(player, rarity, distance, initial)
		return {
			Player = player, Rarity = rarity, StolenAt = 0, Distance = distance,
			Reachable = true, Initial = initial, Position = Vector3.zero,
		}
	end
	t.test("common and divine both have escapable configured pursuit", function()
		t.expect.truthy(Chase.speed("Common") > 16)
		t.expect.truthy(Chase.speed("Divine") > Chase.speed("Common"))
		t.expect.truthy(Chase.speed("Divine") < 22)
		t.expect.truthy(Chase.Timing.ReturnSpeed > Chase.speed("Divine"))
		t.expect.truthy(Chase.duration("Divine") > Chase.duration("Epic"))
		t.expect.truthy(Chase.attackDelay("Divine") < Chase.attackDelay("Common"))
		t.expect.truthy(Chase.attackDelay("Divine") > 0.5)
		t.expect.equal(#Chase.validate(), 0)
	end)
	t.test("initial thief is preferred until a much higher rarity overrides", function()
		local common = candidate("thief", "Common", 20, true)
		local uncommon = candidate("other", "Uncommon", 20, false)
		local chosen = Chase.select({ common, uncommon }, nil, 0, 1.25)
		t.expect.equal(chosen.Player, "thief")
		local divine = candidate("divine", "Divine", 30, false)
		chosen = Chase.select({ common, divine }, common, 0.2, 1.25)
		t.expect.equal(chosen.Player, "divine")
	end)
	t.test("target switching keeps a small lead and drops unreachable players", function()
		local current = candidate("a", "Rare", 10, false)
		local close = candidate("b", "Rare", 8, false)
		t.expect.equal(Chase.select({ current, close }, current, 5, 0).Player, "a")
		local mythic = candidate("m", "Mythic", 12, false)
		t.expect.equal(Chase.select({ current, mythic }, current, 5, 0).Player, "m")
		local gone = candidate("a", "Rare", 10, false)
		gone.Reachable = false
		local other = candidate("b", "Common", 40, false)
		t.expect.equal(Chase.select({ gone, other }, current, 5, 0).Player, "b")
		t.expect.equal(Chase.select({ gone }, current, 5, 0), nil)
	end)
	t.test("full runway stops at the verified safe entrance, before bases", function()
		local axis, lateral = Vector3.xAxis, Vector3.zAxis
		local floors = {
			{ center = Vector3.new(458, 0, -86), axis = axis, longHalf = 175, lateral = lateral, lateralHalf = 52, y = 4 },
			{ center = Vector3.new(1638, 0, -86), axis = axis, longHalf = 144, lateral = lateral, lateralHalf = 52, y = 4 },
		}
		local bases = { { Center = Vector3.new(177, 16, -120), Size = Vector3.new(72, 34, 89) } }
		local runway = Chase.runway(floors, bases, 18)
		t.expect.near(runway.entrance, 283 - 458, 0.01)
		t.expect.truthy(Chase.isSafe(runway, Vector3.new(282, 3, -86)))
		t.expect.falsy(Chase.isSafe(runway, Vector3.new(284, 3, -86)))
		local nearBase = Chase.clamp(runway, Vector3.new(100, 8, -86))
		t.expect.near(nearBase.X, 283 + Chase.Timing.EntranceStandoff, 0.01)
		local marked = Chase.runway(floors, bases, 18, 300 - 458)
		t.expect.near(marked.entrance, 300 - 458, 0.01)
		local far = Chase.clamp(runway, Vector3.new(4000, 8, -86))
		t.expect.near(far.X, 1638 + 144, 0.01)
		t.expect.truthy(Chase.inBases(Vector3.new(177, 16, -120), bases, 4))
		t.expect.falsy(Chase.inBases(nearBase, bases, 4))
		t.expect.truthy(Chase.onRunway(runway, Vector3.new(300, 8, -86), 12))
		local home = Vector3.new(500, 12, -86)
		local stepped = Chase.stepToward(home, Vector3.new(100, 8, -86), 18, 0.1, runway)
		t.expect.truthy(stepped.X < home.X)
		t.expect.truthy(stepped.X >= nearBase.X - 0.01)
	end)
	t.test("chase configuration does not alter resource spawn weights", function()
		local weights = {}
		for id, definition in Resources.getAll() do weights[id] = definition.SpawnWeight end
		require(Shared.GuardianChase)
		require(Shared.CarryDebuff)
		for id, definition in Resources.getAll() do
			t.expect.equal(definition.SpawnWeight, weights[id])
		end
	end)
end
