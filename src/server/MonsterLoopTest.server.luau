--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EvolutionCalculator = require(Shared:WaitForChild("EvolutionCalculator"))
local MonsterDefinitions = require(Shared:WaitForChild("MonsterDefinitions"))
local PlayerData = require(Shared:WaitForChild("PlayerData"))

local function assertEqual(actual: any, expected: any, label: string)
	if actual ~= expected then
		error(string.format("[MonsterLoopTest] %s expected %s got %s", label, tostring(expected), tostring(actual)))
	end
end

local proto = MonsterDefinitions.get("ProtoRex")
assert(proto ~= nil, "ProtoRex missing")

assertEqual(
	EvolutionCalculator.resolve(proto, 50, { Flesh = 40, Flora = 0, Mineral = 0 }, nil),
	"Fangling",
	"flesh evolution"
)
assertEqual(
	EvolutionCalculator.resolve(proto, 10, { Flesh = 40, Flora = 0, Mineral = 0 }, nil),
	nil,
	"growth gate"
)
assertEqual(
	EvolutionCalculator.resolve(proto, 50, { Flesh = 10, Flora = 0, Mineral = 40 }, nil),
	"Stonehide",
	"mineral evolution"
)

local fangling = MonsterDefinitions.get("Fangling")
assert(fangling ~= nil, "Fangling missing")
assertEqual(
	EvolutionCalculator.resolve(fangling, 80, { Flesh = 80, Flora = 0, Mineral = 0 }, nil),
	nil,
	"catalyst required"
)
assertEqual(
	EvolutionCalculator.resolve(fangling, 80, { Flesh = 80, Flora = 0, Mineral = 0 }, "FireCatalyst"),
	"MagmaRex",
	"fire catalyst"
)

local migrated = PlayerData.normalize({
	Cash = 12,
	inventory = { "obsolete" },
	Monsters = {
		ProtoRex = {
			Growth = 4,
			Flesh = 3,
			Mutations = { "Mutant", 5 },
		},
	},
})
assertEqual(migrated.Cash, 12, "cash kept")
assertEqual(migrated.Power, 0, "power default")
assertEqual(migrated.EquippedMonster, "ProtoRex", "starter equipped")
assertEqual(migrated.Monsters.ProtoRex.Growth, 4, "growth kept")
assertEqual(migrated.Monsters.ProtoRex.Mutations[1], "Mutant", "mutation kept")
assertEqual(#migrated.Monsters.ProtoRex.Mutations, 1, "bad mutation dropped")

local empty = PlayerData.normalize(nil)
assertEqual(empty.EquippedMonster, "ProtoRex", "nil save starter")

print("[MonsterLoopTest] PASS")
