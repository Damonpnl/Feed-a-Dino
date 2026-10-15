local Shared = game.ReplicatedStorage.Shared
local Debuff = require(Shared.CarryDebuff)
local Rarities = require(Shared.RarityDefinitions)
local Resources = require(Shared.ResourceDefinitions)
return function(t)
	local function seeded(seed)
		local rng = Random.new(seed)
		return function() return rng:NextNumber() end
	end
	local function constant(value)
		return function() return value end
	end

	t.test("catalog, profiles, and compatibility validate", function()
		t.expect.equal(#Debuff.validate(), 0)
		t.expect.equal(Debuff.assign("Forged", constant(0)), nil)
		t.expect.falsy(Debuff.Catalog.ErraticSprint.Enabled)
		t.expect.equal(Debuff.Catalog.ErraticSprint.Substitute, "ShiftingWeight")
	end)

	t.test("common through rare never assign a curse", function()
		for _, rarity in { "Common", "Uncommon", "Rare" } do
			for seed = 1, 50 do
				t.expect.equal(#Debuff.assign(rarity, seeded(seed)).Effects, 0)
			end
		end
	end)

	t.test("epic curse chance follows the configured 25 percent", function()
		t.expect.equal(#Debuff.assign("Epic", constant(0.2)).Effects, 1)
		t.expect.equal(#Debuff.assign("Epic", constant(0.3)).Effects, 0)
		local rand, hits, draws = seeded(7), 0, 20000
		for _ = 1, draws do
			if #Debuff.assign("Epic", rand).Effects > 0 then hits += 1 end
		end
		t.expect.near(hits / draws, Debuff.Profiles.Epic.Chance, 0.015)
	end)

	t.test("legendary through divine select valid tiers and compatible pairs", function()
		local seenCosmic, eternalPairs, eternalDraws = {}, 0, 4000
		for seed = 1, eternalDraws do
			local rand = seeded(seed)
			local legendary = Debuff.assign("Legendary", rand)
			t.expect.equal(#legendary.Effects, 1)
			t.expect.equal(legendary.Effects[1].Tier, "Mild")
			local mythic = Debuff.assign("Mythic", rand)
			t.expect.equal(#mythic.Effects, 1)
			t.expect.equal(mythic.Effects[1].Tier, "Moderate")
			local cosmic = Debuff.assign("Cosmic", rand)
			t.expect.equal(#cosmic.Effects, 1)
			seenCosmic[cosmic.Effects[1].Tier] = true
			local secret = Debuff.assign("Secret", rand)
			t.expect.equal(#secret.Effects, 1)
			t.expect.equal(secret.Effects[1].Tier, "Strong")
			local eternal = Debuff.assign("Eternal", rand)
			t.expect.equal(eternal.Effects[1].Tier, "Strong")
			if #eternal.Effects == 2 then eternalPairs += 1 end
			local divine = Debuff.assign("Divine", rand)
			t.expect.equal(#divine.Effects, 2)
			for _, pair in { eternal, divine } do
				local strong = 0
				for _, effect in pair.Effects do
					if effect.Tier == "Strong" then strong += 1 end
					t.expect.truthy(Debuff.Catalog[effect.Id].Enabled)
				end
				t.expect.equal(strong, 1)
				if pair.Effects[2] then
					t.expect.equal(pair.Effects[2].Tier, "Mild")
					t.expect.truthy(Debuff.Compatible[pair.Effects[1].Id][pair.Effects[2].Id])
				end
			end
			t.expect.equal(divine.Title, "DIVINE CURSE")
		end
		t.expect.truthy(seenCosmic.Moderate and seenCosmic.Strong)
		t.expect.near(eternalPairs / eternalDraws, Debuff.Profiles.Eternal.Secondary.Chance, 0.03)
	end)

	t.test("assignment is deterministic for an injected random source", function()
		for _, rarity in Rarities.Order do
			local a, b = Debuff.assign(rarity, seeded(42)), Debuff.assign(rarity, seeded(42))
			t.expect.deepEqual(a, b)
		end
	end)

	t.test("inversion always warns for one second before it activates", function()
		local rand = seeded(3)
		for _ = 1, 200 do
			local assignment = Debuff.assign("Secret", rand)
			local effect = assignment.Effects[1]
			if effect.Id == "InvertedControls" then
				t.expect.equal(Debuff.phase(effect, 0).State, "Normal")
				t.expect.equal(Debuff.phase(effect, effect.Normal - 1 + 0.01).State, "Warning")
				t.expect.near(Debuff.phase(effect, effect.Normal - 0.5).Remaining, 0.5, 1e-6)
				t.expect.equal(Debuff.phase(effect, effect.Normal + 0.01).State, "Active")
				t.expect.truthy(effect.Active >= 1.5 and effect.Active <= 2)
				t.expect.equal(Debuff.phase(effect, effect.Normal + effect.Active + 0.01).State, "Normal")
				t.expect.equal(Debuff.status(effect, effect.Normal - 1), "CONTROLS INVERT IN 1.0s")
			end
		end
	end)

	t.test("speed curses add only while active and stay under the cap", function()
		local heavy = { Rarity = "Mythic", Title = "CURSED CARRY", Effects = { { Id = "HeavyBurden", Tier = "Moderate", Extra = 0.10 } } }
		t.expect.near(Debuff.extraSlowdown(heavy, 5), 0.10, 1e-6)
		local shifting = { Id = "ShiftingWeight", Tier = "Mild", Extra = 0.08, Normal = 3, Active = 2, Warning = 1 }
		local cyc = { Rarity = "Legendary", Title = "CURSED CARRY", Effects = { shifting } }
		t.expect.equal(Debuff.extraSlowdown(cyc, 1), 0)
		t.expect.near(Debuff.extraSlowdown(cyc, 3.5), 0.08, 1e-6)
		t.expect.equal(Debuff.extraSlowdown(nil, 3), 0)
		t.expect.equal(Debuff.applied(0.50, 1), Debuff.MaxTotal)
		t.expect.truthy(16 * (1 - Debuff.MaxTotal) >= 6)
		local weights = {}
		for id, definition in Resources.getAll() do weights[id] = definition.SpawnWeight end
		for id, definition in Resources.getAll() do
			if Debuff.Profiles[definition.Rarity] then
				for seed = 1, 10 do
					local assignment = Debuff.assign(definition.Rarity, seeded(seed))
					local applied = Debuff.applied(definition.CarrySlowdown, Debuff.maxExtra(assignment))
					t.expect.truthy(applied + 1e-6 >= definition.CarrySlowdown)
					t.expect.truthy(applied <= Debuff.MaxTotal)
				end
			end
			t.expect.equal(definition.SpawnWeight, weights[id])
		end
	end)
end
