# FEED A PET

## Master Cursor + Codex Project Context

**Document status:** Authoritative design and implementation context  
**Version:** 2.0  
**Updated:** 2026-10-09  
**Project name:** `Feed a Pet`

> This document supersedes the earlier `FEED_A_PET_CONTEXT.md` for new implementation work. When legacy repository behavior conflicts with this document because it belongs to the previous conveyor/open-world direction, prefer this document unless the legacy behavior is required for save integrity, purchases, receipts, or an explicitly preserved system.

---

# 1. Source-of-Truth Rules for Cursor, Codex, and Other Agents

Feed a Pet is now intentionally narrow. Do not re-expand it into the previous creature simulation, open-world, conveyor, lab-management, or combat-heavy design.

The core principle is:

**Make acquisition extremely simple. Put depth into pets, evolution, rarity, catalysts, Power progression, and live updates.**

When implementing:

- Inspect the repository and active Roblox Studio place before making major changes.
- Trace references before deleting scripts, modules, remotes, attributes, tags, or folders.
- Preserve datastore compatibility and monetization receipt handling unless a deliberate migration is implemented.
- Use Git/version control as history. Delete dead code instead of leaving large commented-out blocks.
- Keep progression server-authoritative.
- Keep content data-driven.
- Prefer shared services and definitions over one script per feed, area, guardian, or pet.
- Do not build final art before gameplay behavior is validated.
- Do not silently invent new systems when an existing specification is present in this document.
- After every substantial implementation step, run available tests/playtests and inspect for Luau errors, broken requires, dangling remotes, invalid references, memory leaks, or duplication exploits.

### Implementation-status language

Agents must distinguish these states:

- **DESIGN LOCKED**: this document specifies the intended behavior.
- **IMPLEMENTED**: the current repository contains the behavior.
- **VALIDATED**: the behavior has been tested and verified.

Never infer `IMPLEMENTED` or `VALIDATED` from this document alone. Inspect the repository and Studio place.

---

# 2. Executive Summary

Feed a Pet is a compact Roblox collection/evolution game built around a long, narrow, socially visible risk-reward path.

Players:

1. Leave one of four bases.
2. Run down a central pathway through progressively harder areas.
3. Take a physical feed or catalyst from a natural source near a recognizable guardian.
4. Survive a non-combat guardian hazard.
5. Return to base while carrying the item.
6. Feed the item to their active pet.
7. Increase Growth and/or affinity.
8. Evolve the pet into stronger or stranger forms.
9. Use the stronger pet to improve training and/or income.
10. Train Power.
11. Use higher Power to carry heavier, rarer resources farther down the path.
12. Repeat.

The roster is broader than dinosaurs. It may include animals, dinosaurs, mythic creatures, and recognizable monster archetypes. Base forms should remain immediately readable.

### Old direction vs current direction

| Old direction | Current Feed a Pet direction |
|---|---|
| Large creature/conveyor/simulation game | Compact steal, escape, feed, evolve loop |
| Expansive Savannah/open-world emphasis | Long, narrow, legible progression path |
| Many intertwined economy systems | One primary gameplay loop plus one supporting Power loop |
| Dinosaurs as the entire identity | Recognizable animals, dinosaurs, mythic creatures, monster forms |
| Combat possible | No traditional combat, guardians are hazards |
| Bespoke mechanics by zone | Reusable area/resource/guardian/pet systems |
| Polish before validation | Graybox vertical slice first, AI-assisted polish later |

---

# 3. North-Star Gameplay Loops

## Primary loop

**RUN OUT → GRAB ITEM → ESCAPE → FEED PET → EVOLVE → GET STRONGER → GO FARTHER**

## Secondary loop

**BETTER PET → BETTER TRAINING / INCOME → MORE POWER → HEAVIER / DEEPER LOOT → BETTER PET**

A new player should understand both loops within the first few minutes.

The map exists to create:

- visible distance,
- risk,
- competition,
- spectacle,
- readable progression,
- and social exposure around valuable loot.

The pet/evolution system carries most of the long-term depth.

---

# 4. World Layout

## Core geometry

Use **four player bases** at the safe end of one long central pathway.

The pathway should be substantially longer than it is wide. It should feel like a runway rather than an open world or a tight hallway.

Players should usually be able to see activity ahead and behind them. Valuable pickups should remain socially visible.

### Map principles

| Principle | Implementation |
|---|---|
| Four bases | Compact plots at the safe end of the path |
| Linear progression | Areas ordered from low-risk to high-risk |
| Narrow social space | Enough width to dodge hazards, not enough to avoid everyone |
| Risk by distance | Farther zones have better resources and longer return trips |
| Small biome pockets | Minor alcoves/caves are fine; avoid sprawling maps |
| Launch scope | Exactly five resource-enabled launch areas |
| Long-term expansion | After roughly 6–8 permanent areas, use branches, portals, transformations, and events instead of endless road extension |

## Launch areas

Exactly five launch resource areas:

1. Grasslands
2. Swamp
3. Jungle
4. Crystal Cave
5. Volcano

A future Ancient/Rift blockout may remain in the scene, but it is **not** a sixth launch resource pool.

---

# 5. Launch Area Identity

Each launch area contains:

- 1 recognizable guardian,
- exactly 5 designated ResourceNodes,
- exactly 8 Index resources,
- a natural visual explanation for why those resources exist there,
- a distinct progression bias,
- and one reusable guardian hazard configuration.

| Area | Guardian | Natural resource logic | Progression bias |
|---|---|---|---|
| Grasslands | T-Rex | Fresh carcass, feeding ground, bones, berries | Basic Flesh / Floral / Mineral |
| Swamp | Giant Crocodile | Fish pools, rotten carcasses, mushrooms, venom | Flesh / Floral / mutation |
| Jungle | Giant Gorilla | Fruit grove, roots, flowers, insects | Floral / strength / hybrid |
| Crystal Cave | Armored Triceratops | Geodes, fossils, mineral growths | Mineral / armor |
| Volcano | Dragon | Charred feeding ground, magma deposits, draconic remains | High Flesh / fire / endgame launch tier |

Guardians should be recognizable at a glance. Avoid arbitrary invented creatures for the main area guardians.

---

# 6. Authoritative Rarity System

## Rarity order

Use exactly this 10-tier order:

1. Common
2. Uncommon
3. Rare
4. Epic
5. Legendary
6. Mythic
7. Cosmic
8. Secret
9. Eternal
10. Divine

### Critical rule

**Rarity does not determine spawn probability.**

Spawn probability is always explicitly configured through `SpawnWeight` in the relevant area/event pool.

Do not implement logic such as:

```lua
if rarity == "Secret" then
    spawnChance = 0.1
end
```

Instead:

```lua
{
    Id = "FireCore",
    Rarity = "Secret",
    SpawnWeight = 0.74,
}
```

The same rarity can have different probabilities in different pools.

## Visual rarity identities

These are Feed a Pet art-direction rules, not probability rules.

| Rarity | Visual identity |
|---|---|
| Common | White/light gray, static |
| Uncommon | Green |
| Rare | Blue |
| Epic | Purple |
| Legendary | Orange/gold, subtle shine |
| Mythic | Magenta/crimson, animated gradient |
| Cosmic | Blue-purple galaxy treatment, subtle particles |
| Secret | Dark/prismatic, unusual animated gradient |
| Eternal | White-violet, stronger aura |
| Divine | Radiant white-gold, highest normal spectacle |

Do not make all rarities equally animated. Spectacle should escalate.

---

# 7. Resource Types

The system may internally call all world pickups resources. Player-facing items should look and sound like real objects from the world.

Do not label everything generically as “Feed.”

## Resource categories

| Category | Purpose | Examples |
|---|---|---|
| Normal Feed | Adds Growth and/or one affinity | Raw Meat, Berries, Crystal Shard |
| Specialized Feed | Stronger affinity or a secondary effect | Venom Sac, Fossil Marrow, Ember Heart |
| Catalyst | Unlocks/checks an evolution family | Primal Catalyst, Crystal Catalyst, Fire Core |
| Special Catalyst | Unlocks transformational families | Dragon Blood; future Giant Serum, Spirit Energy, Cyber Core, Void Essence |

## Required resource fields

Every collectible resource definition must support at least:

```lua
{
    Id = "AncientBone",
    DisplayName = "Ancient Bone",
    ResourceType = "Feed", -- Feed | Catalyst
    Rarity = "Epic",
    Area = "Grasslands",
    Growth = 18,
    Affinity = "Mineral", -- or multi-affinity representation
    PowerRequired = 500,
    SpawnWeight = 2.5,
    CarrySlowdown = 0.08,
    SpecialEffect = nil,
    ModelKey = "AncientBone",
    BillboardOffset = Vector3.new(0, 2.5, 0),
}
```

---

# 8. Authoritative Launch Resource Tables

These are the current design-locked launch values. Balance can be intentionally revised later, but agents must not improvise alternate tables without an explicit rebalance task.

## 8.1 Grasslands

**Guardian:** T-Rex  
**Pool total:** 100

| # | Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Special |
|---:|---|---|---|---|---:|---:|---:|---:|---|
| 1 | Raw Meat | Feed | Common | Flesh | 5 | 0 | 34 | 0 | |
| 2 | Berries | Feed | Common | Floral | 6 | 0 | 24 | 0 | |
| 3 | Bone Chunk | Feed | Uncommon | Mineral | 8 | 50 | 17 | 0 | |
| 4 | Prime Meat | Feed | Rare | Flesh | 12 | 120 | 10 | 0.02 | |
| 5 | Wild Herbs | Feed | Rare | Floral | 12 | 200 | 7 | 0.02 | |
| 6 | Giant Rib | Feed | Epic | Flesh | 18 | 350 | 4.5 | 0.05 | |
| 7 | Ancient Bone | Feed | Epic | Mineral | 18 | 500 | 2.5 | 0.08 | |
| 8 | Primal Catalyst | Catalyst | Legendary | Neutral | 30 | 1000 | 1 | 0.10 | Unlock/check Primal family |

## 8.2 Swamp

**Guardian:** Giant Crocodile  
**Pool total:** 100

| # | Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Special |
|---:|---|---|---|---|---:|---:|---:|---:|---|
| 1 | Small Fish | Feed | Uncommon | Flesh | 22 | 1,500 | 32 | 0.05 | |
| 2 | Rotten Meat | Feed | Rare | Flesh | 28 | 2,200 | 23 | 0.05 | |
| 3 | Spore Pod | Feed | Rare | Floral | 30 | 3,000 | 17 | 0.06 | |
| 4 | Swamp Mushroom | Feed | Epic | Floral | 38 | 4,500 | 11 | 0.08 | |
| 5 | Venom Sac | Feed | Epic | Flesh | 45 | 6,500 | 8 | 0.10 | Toxin progression/tag if supported |
| 6 | Bog Marrow | Feed | Legendary | Flesh + Mineral | 55 | 9,000 | 5 | 0.12 | |
| 7 | Mutant Leech | Feed | Mythic | Neutral | 70 | 14,000 | 3 | 0.14 | Small mutation roll |
| 8 | Toxic Catalyst | Catalyst | Cosmic | Neutral | 100 | 25,000 | 1 | 0.18 | Toxic/Mutant family |

## 8.3 Jungle

**Guardian:** Giant Gorilla  
**Pool total:** 100

| # | Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Special |
|---:|---|---|---|---|---:|---:|---:|---:|---|
| 1 | Wild Fruit | Feed | Rare | Floral | 75 | 25,000 | 30 | 0.08 | |
| 2 | Giant Beetle | Feed | Rare | Flesh | 80 | 35,000 | 23 | 0.08 | |
| 3 | Rare Flower | Feed | Epic | Floral | 95 | 50,000 | 18 | 0.10 | |
| 4 | Protein Root | Feed | Legendary | Flesh + Floral | 110 | 75,000 | 12 | 0.12 | |
| 5 | Golden Banana | Feed | Legendary | Floral | 125 | 100,000 | 8 | 0.13 | |
| 6 | Royal Jelly | Feed | Mythic | Neutral | 150 | 150,000 | 5 | 0.15 | |
| 7 | Beast Heart | Feed | Mythic | Flesh | 180 | 225,000 | 3 | 0.18 | |
| 8 | Jungle Heart | Catalyst | Secret | Neutral | 250 | 350,000 | 1 | 0.22 | Beast/Alpha family |

## 8.4 Crystal Cave

**Guardian:** Armored Triceratops  
**Pool total:** 100

| # | Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Special |
|---:|---|---|---|---|---:|---:|---:|---:|---|
| 1 | Crystal Shard | Feed | Rare | Mineral | 250 | 350,000 | 29 | 0.10 | |
| 2 | Fossil Marrow | Feed | Epic | Flesh + Mineral | 300 | 500,000 | 23 | 0.12 | |
| 3 | Mineral Core | Feed | Legendary | Mineral | 375 | 750,000 | 18 | 0.15 | |
| 4 | Living Geode | Feed | Legendary | Mineral | 450 | 1,000,000 | 13 | 0.18 | |
| 5 | Prismatic Crystal | Feed | Mythic | Mineral | 550 | 1,500,000 | 9 | 0.20 | |
| 6 | Fossil Heart | Feed | Cosmic | Flesh + Mineral | 700 | 2,500,000 | 5 | 0.24 | |
| 7 | Crystal Core | Feed | Cosmic | Mineral | 850 | 4,000,000 | 2.5 | 0.28 | |
| 8 | Crystal Catalyst | Catalyst | Secret | Neutral | 1,200 | 6,000,000 | 0.5 | 0.32 | Crystal family |

## 8.5 Volcano

**Guardian:** Dragon  
**Pool total:** 100

| # | Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Special |
|---:|---|---|---|---|---:|---:|---:|---:|---|
| 1 | Charred Meat | Feed | Epic | Flesh | 1,000 | 6,000,000 | 37.51 | 0.18 | |
| 2 | Magma Stone | Feed | Legendary | Mineral | 1,200 | 8,000,000 | 26.27 | 0.20 | |
| 3 | Ember Heart | Feed | Legendary | Flesh | 1,500 | 12,000,000 | 16.83 | 0.22 | |
| 4 | Dragon Scale | Feed | Mythic | Mineral | 1,800 | 18,000,000 | 13.96 | 0.25 | |
| 5 | Dragon Meat | Feed | Cosmic | Flesh | 2,400 | 30,000,000 | 4.36 | 0.30 | |
| 6 | Fire Core | Catalyst | Secret | Neutral | 3,200 | 50,000,000 | 0.74 | 0.35 | Fire family |
| 7 | Dragon Blood | Catalyst | Eternal | Neutral | 4,500 | 80,000,000 | 0.31 | 0.40 | Draconic family |
| 8 | Inferno Catalyst | Catalyst | Divine | Neutral | 7,000 | 150,000,000 | 0.02 | 0.50 | Highest Inferno family check |

---

# 9. World Resource Spawn System

## Global field cycle

Use a synchronized server-wide field cycle:

```lua
FIELD_CYCLE_SECONDS = 300
RESET_WINDOW_SECONDS = 10
RESOURCE_NODES_PER_AREA = 5
INDEX_RESOURCES_PER_AREA = 8
CARRY_CAPACITY = 1
```

Resources are **server-wide physical objects**, not per-player instances.

Each of the 5 ResourceNodes in an area may hold one world resource.

## Hard reset behavior

At the 300-second reset:

1. Enter a 10-second reset/night transition.
2. Stop scheduling new normal mid-cycle respawns.
3. Remove all uncarried field resources.
4. Reset area disturbance where appropriate.
5. Reroll all five nodes in every launch area using the explicit area pool.
6. Spawn new objects.
7. Trigger rare-item announcements and VFX.
8. Resume normal field state.

Carried resources are **not deleted** by the reset.

## Mid-cycle respawns

When an eligible resource leaves a node normally:

- Common through Rare: respawn after 18 seconds.
- Epic through Legendary: respawn after 25 seconds.
- Mythic and Cosmic: respawn after 40 seconds.
- Secret, Eternal, Divine: **no mid-cycle respawn**.

For a mid-cycle reroll:

- Temporarily exclude Secret/Eternal/Divine entries.
- Renormalize the remaining weights.

If a hard reset begins while a node respawn timer is pending, cancel that timer and let the reset own the node.

## Secret+ constraints

Secret, Eternal, and Divine are chase items.

### Secret spawn

- server announcement,
- unique sound hook,
- extended billboard range,
- aura.

### Eternal spawn

- stronger announcement,
- stronger sound,
- beam above the area,
- stronger aura.

### Divine spawn

- major server announcement,
- area name,
- item name,
- Divine sound hook,
- beam,
- radial burst,
- unique billboard animation.

### Caps

- At most one Secret+ result per area from a single hard-reset roll.
- If multiple Secret+ results roll across that area's five nodes, keep the highest rarity and reroll the others with Secret+ temporarily excluded.
- At most one Divine item from normal world spawning may exist server-wide at once.
- No world-spawn pity system at launch.

---

# 10. Resource Lifecycle and Dropped Items

Every spawned resource needs a unique server-side resource instance ID.

Recommended state machine:

```text
AVAILABLE
  ↓
CARRIED
  ↓
DROPPED
  ↓
CONSUMED / DESTROYED
```

Valid transitions must never duplicate the server record.

## Dropped-item behavior

When a guardian hazard forces a drop:

- detach the object safely,
- return it to a physical world state,
- allow any player to pick it up immediately,
- preserve the originating node relationship,
- expire the dropped item after 20 seconds if nobody takes it,
- once destroyed/consumed, schedule node respawn if that resource tier is eligible.

Test disconnects, resets, deaths, simultaneous pickups, and reset timing against this state machine.

---

# 11. Affinity System

Retain three core biological affinities plus Neutral.

| Affinity | Meaning | Typical visual traits |
|---|---|---|
| Flesh | Predation, muscle, regeneration, horns, claws, mouths | Larger jaws, muscle, teeth, spikes |
| Floral | Plants, fungus, poison, symbiosis, parasites | Vines, blooms, spores, moss, toxins |
| Mineral | Armor, bone, crystal, stone, metal-like growth | Plates, geodes, crystal horns, rock armor |
| Neutral | Growth without normal affinity, catalyst-family hooks | Family-specific |

Hybrid resources may grant multiple affinities.

Current compatibility rule: if the existing save schema stores Floral as `Flora`, retain that storage key until a deliberate migration is implemented.

Hybrid outcomes can combine forces:

- Flesh + Mineral → armored brute
- Flesh + Floral → parasitic/predatory organic form
- Floral + Mineral → living crystal/plant form

Special catalysts can redirect or override normal branches.

---

# 12. Pet Roster Philosophy

Base forms should be recognizable.

Roughly 70–80% of base creatures should begin from familiar animals, dinosaurs, or mythic archetypes.

Examples:

- Wolf
- Bear
- Gorilla
- Crocodile
- T-Rex
- Triceratops
- Spider
- Snake
- Mammoth
- Shark
- Dragon

Originality should primarily come from evolution forms, mutations, catalysts, materials, proportions, and combinations.

Examples:

| Base creature | Possible forms |
|---|---|
| Wolf | Dire Wolf, Crystal Wolf, Spirit Wolf, Cyber Wolf, Void Wolf |
| T-Rex | Blood Rex, Armored Rex, Magma Rex, Titan Rex |
| Gorilla | Titan Gorilla, Jungle Gorilla, Mutant Gorilla, Cyber Gorilla |
| Crocodile | Swamp Crocodile, Mutant Crocodile, Crystal Crocodile |
| Spider | Thorn Spider, Crystal Spider, Void Spider, Blood Widow |
| Dragon | Fire Dragon, Spirit Dragon, Crystal Dragon, Void Dragon |
| Bear | Stone Bear, Cyber Bear, Frost Bear |
| Shark | Megalodon, Abyss Shark, Cyber Shark |

Do not fill the launch roster with arbitrary fantasy names whose silhouettes do not communicate what they are.

---

# 13. Feeding and Evolution

## Active pet

Each base has one primary active pet at a time for the launch loop.

Recommended pet state:

```lua
{
    Species = "Wolf",
    EvolutionForm = "Wolf",
    Growth = 0,
    Flesh = 0,
    Floral = 0, -- or Flora for compatibility
    Mineral = 0,
    EvolutionFamilies = {},
    Mutations = {},
    IncomeMultiplier = 1,
    TrainingMultiplier = 1,
}
```

## Feeding flow

At the base:

1. Player brings a carried resource to the pet.
2. Client may preview effects.
3. Server validates the carried resource and ownership/state.
4. Server reads the authoritative resource definition.
5. Apply Growth.
6. Apply affinity changes.
7. Apply catalyst/special effects.
8. Check evolution eligibility.
9. Trigger evolution if requirements are satisfied.
10. Consume resource exactly once.
11. Persist pet changes.
12. Update client state/UI.

Do not hardcode catalyst names inside FeedingService.

## Evolution definitions

Evolutions should be declarative.

Example:

```lua
Wolf = {
    Evolutions = {
        {
            Result = "DireWolf",
            Requirements = {
                Growth = 100,
                Flesh = 60,
            },
        },
        {
            Result = "CrystalWolf",
            Requirements = {
                Growth = 100,
                Mineral = 60,
                CatalystTag = "Crystal",
            },
        },
    },
}
```

Special catalysts should create meaningful visual transformations, not simple recolors.

Examples:

- Giant Serum → major scale/proportion changes
- Cyber Core → mechanical components
- Dragon Blood → horns/scales/wings/draconic traits
- Spirit Energy → aura/energy-form traits
- Void Essence → void-material distortions

---

# 14. Mutations vs Rarity

Mutation is a separate dimension from rarity.

Do not encode things like `GoldenLegendaryVoid` as a rarity.

Recommended pet representation:

```lua
{
    Species = "Wolf",
    Rarity = "Legendary",
    Mutations = { "Golden", "Void" },
}
```

## Normal mutation family

Reserved normal mutation concepts:

- Silver
- Golden
- Rainbow

## Special mutation/evolution families

- Titan
- Void
- Cyber
- Spirit
- Blood Moon
- Celestial
- Parasite
- Fire
- Crystal
- Draconic
- Toxic/Mutant
- Primal

These can be unlocked by catalysts/events rather than being ordinary rarity states.

---

# 15. Guardian Design Without Combat

Guardians are environmental threats, not enemies to kill.

No launch system should require:

- HP bars,
- weapons,
- kill rewards,
- DPS builds,
- combat stats,
- attack combos.

## Shared state machine

```text
SLEEPING
  ↓
DISTURBED
  ↓
WARNING
  ↓
HAZARD
  ↓
COOLDOWN
  ↓
SLEEPING
```

## Disturbance values

Initial design values:

| Pickup rarity | Disturbance |
|---|---:|
| Common | +8 |
| Uncommon | +10 |
| Rare | +12 |
| Epic | +15 |
| Legendary | +20 |
| Mythic | +25 |
| Cosmic | +35 |
| Secret | Immediate wake |
| Eternal | Immediate wake |
| Divine | Immediate wake |

At 100 disturbance, the guardian wakes.

## Launch guardian hazards

| Area | Guardian | Hazard |
|---|---|---|
| Grasslands | T-Rex | Charge |
| Swamp | Giant Crocodile | Lunge / tail sweep |
| Jungle | Giant Gorilla | Ground-slam shockwave |
| Crystal Cave | Armored Triceratops | Straight-line charge |
| Volcano | Dragon | Telegraphed fire sweep |

Warning telegraphs should be approximately 0.75–1.25 seconds unless feel testing shows otherwise.

Hazard contact should primarily:

- force carried resource drop,
- knock the player back,
- optionally apply a short ragdoll/stagger,
- keep the player alive.

Expose hooks for:

- animation,
- sound,
- VFX,
- camera shake.

---

# 16. Power and Carrying

Power is the primary player-side progression stat.

It determines what the player can physically carry.

Do not rely exclusively on invisible area walls. A player may enter a later area before they are ready and discover that the loot there is too heavy.

Example feedback:

**NEED 6M POWER**

## Carry rules

Launch carry capacity:

```lua
CARRY_CAPACITY = 1
```

On pickup:

1. Server validates the world resource still exists and is `AVAILABLE`.
2. Server validates the player is not already carrying another major resource.
3. Server validates `Power >= PowerRequired`.
4. Transition server resource to `CARRIED`.
5. Attach/show the physical item on the character.
6. Apply CarrySlowdown.
7. Update Carry HUD.
8. Raise guardian disturbance.

Insufficient Power must not remove the item.

Carry state must be safe against reset, death, disconnect, teleport, and simultaneous pickup attempts.

---

# 17. Economy and Trainer Progression

Keep the economy simple.

## Core economic loop

**BETTER FEED → STRONGER PET → MORE CASH / TRAINING POWER → BETTER TRAINER → MORE POWER → HEAVIER RESOURCES**

If Cash remains, it should have a clear job such as trainer upgrades and convenience.

Avoid multiple redundant currencies at launch.

## Trainer ladder

Initial design-locked trainer multiplier ladder:

| Tier | Trainer | Rarity theme | Multiplier |
|---:|---|---|---:|
| 1 | Training Mat | Common | x2 |
| 2 | Weighted Sled | Uncommon | x5 |
| 3 | Iron Rig | Rare | x12 |
| 4 | Power Cage | Epic | x30 |
| 5 | Golden Gym | Legendary | x80 |
| 6 | Gravity Chamber | Mythic | x100 |
| 7 | Cosmic Reactor | Cosmic | x200 |
| 8 | Abyss Chamber | Secret | x500 |
| 9 | Eternal Forge | Eternal | x1000 |
| 10 | Divine Reactor | Divine | x2000 |

Prices belong in `TrainerDefinitions`, not scattered through scripts.

Power gain conceptually:

```text
PowerGain = BaseTrainingGain
          × TrainerMultiplier
          × ActivePetTrainingMultiplier
          × TemporaryBoosts
```

Start with a simple training tick, then tune feel.

---

# 18. Slow Mode

Slow Mode is a required launch-quality feature once progression can make movement too fast for precise interaction.

When enabled:

- use a normal precision movement speed,
- do not change saved Power,
- temporarily suppress high-speed movement scaling.

When disabled:

- restore the normal calculated movement behavior.

Expose a compact persistent HUD toggle.

---

# 19. Base Design

Keep bases functional and legible.

Launch base components:

- active pet enclosure/display,
- feeding interaction point,
- training station,
- minimal upgrade interaction,
- passive Cash display if Cash remains,
- safe return/spawn zone.

Do not rebuild the previous heavy lab-management/tycoon structure.

## Conveyor decision

The conveyor is removed from the primary acquisition loop.

If reintroduced later, it may only serve as a minor base automation/convenience feature such as basic-feed processing. It must not replace the core run-out-and-steal loop.

---

# 20. Billboard System

Billboard tags are a core visual language for resources, pets, catalysts, and chase drops.

## Required resource billboard hierarchy

```text
ITEM NAME
+STAT / EFFECT
optional modifier badge
```

Example:

```text
ANCIENT BONE
+18 Growth
```

Rarity should primarily be communicated visually. Do not print the rarity word on every normal resource unless a specific design requires it.

## Enter animation

Target approximately 0.15–0.25 seconds:

1. Start around 0.85 scale and high transparency.
2. Fade toward full opacity.
3. Scale slightly past 1.0, roughly 1.03.
4. Settle at 1.0.

## Exit animation

Target approximately 0.12–0.20 seconds:

1. Slight scale-down.
2. Fade text/stroke/glow.
3. Optional slight upward movement.
4. Destroy/disable only after tween completion.

## Distance behavior

Use centralized handling, not a RenderStepped connection per billboard.

Normal resources:

- Near: full tag and effects.
- Medium: name/stat with reduced effects.
- Far: simplified or hidden.
- Very far: disabled.

Secret+ may use longer ranges.

## Rarity escalation

- Common: static
- Rare: slightly alive
- Epic: noticeable
- Legendary: premium
- Mythic: special
- Cosmic: galaxy treatment
- Secret: unmistakably anomalous
- Eternal: stronger aura
- Divine: highest normal spectacle

Do not make common items visually noisy.

---

# 21. UI Surface Inventory

The launch implementation should plan for these native Roblox UI surfaces:

| UI | Purpose |
|---|---|
| Main HUD | Cash, Power, current multiplier |
| Resource Reset Timer | Countdown to the 5-minute field reset |
| Resource Billboard | Name + Growth/effect + rarity styling |
| Pet Billboard | Pet name, rarity/form, optional income |
| Area Sign | Area name + recommended Power + guardian |
| Carry HUD | Carried item, rarity styling, Power requirement/drop |
| Insufficient Power Toast | Fast `NEED X POWER` feedback |
| Feed Interaction | Preview Growth/affinity/catalyst effect |
| Pet Panel | Pet stats, affinities, multipliers, evolution state |
| Evolution Reveal | Cinematic old → new form result |
| Trainer Upgrade UI | Current tier, next tier, multiplier, price |
| Index | Areas, 8 entries per area, discovery state |
| Slow Mode Toggle | Precision movement |
| Settings | Music, SFX, VFX, accessibility/UI scale as needed |
| Boost HUD | Temporary boost timers if introduced |
| Rare Spawn Banner | Secret/Eternal/Divine world announcement |
| Event Banner | Future event state/countdown |
| Event Progress UI | Future deposits/progress/rewards |
| Special Catalyst UI | Requirements/outcome information where needed |
| Leaderboard | Power, income, discoveries if retained |

Mobile layout is not “desktop UI scaled down.” Design mobile-safe placement explicitly.

---

# 22. Index System

Each launch area has exactly 8 discoverable resources.

Example:

```text
GRASSLANDS                  5 / 8

Raw Meat             ✓
Berries               ✓
Bone Chunk            ✓
Prime Meat            ✓
Wild Herbs            ✓
???                   ?
???                   ?
???                   ?
```

A resource should count as discovered on the first successful acquisition/consumption event chosen by the final implementation, but the condition must be consistent and server-authoritative.

Area completion rewards should be relevant to Feed a Pet, for example:

- Power bonus,
- training multiplier,
- Cash boost,
- trail,
- title,
- base cosmetic,
- pet appearance,
- luck bonus.

Do not introduce combat weapons as Index rewards.

---

# 23. First-Time Experience

Avoid a long tutorial wall.

Use short contextual objectives:

1. **GRAB SOME FOOD**
2. **RETURN TO YOUR PET**
3. **FEED YOUR PET**
4. **TRAIN POWER**
5. **GRAB A HEAVIER ITEM**

Use arrows/highlights only when needed.

The player should experience the complete loop quickly.

---

# 24. Server Architecture

The codebase should remain small, readable, data-driven, and server-authoritative.

Recommended conceptual responsibility split:

| System | Responsibility |
|---|---|
| DataService | Save/load, migration, authoritative persistent state |
| ResourceService | Runtime resource records/state transitions |
| SpawnService | Area pools, weighted spawning, reset cycle, node cleanup |
| CarryService | Pickup validation, carrying, dropping, movement modifiers |
| GuardianService | Disturbance state machine and hazards |
| FeedingService | Resource consumption and feed effects |
| MonsterService | Pet state, Growth, affinities, evolution |
| TrainingService | Power gain and pet/trainer multipliers |
| BaseService | Base ownership, feeding point, training station |
| IndexService | Discovery state and completion rewards |
| UIController | Client presentation only |
| EffectsController | Client VFX/SFX/camera feedback |

Shared definitions should include:

- `RarityDefinitions`
- `FeedDefinitions` / `ResourceDefinitions`
- `CatalystDefinitions`
- `MonsterDefinitions`
- `AreaDefinitions`
- `TrainerDefinitions`
- `BillboardConfig`
- `ModifierStyles`

Do not force exact folder names if the repository already has a cleaner equivalent.

---

# 25. Validation Rules

Create config validation for at least:

- every launch area has exactly 8 Index resources,
- every launch area has exactly 5 ResourceNodes,
- all resource IDs are unique,
- rarity names are valid,
- `SpawnWeight > 0`,
- each normal area pool totals exactly 100,
- `PowerRequired >= 0`,
- `Growth >= 0`,
- every catalyst has a valid effect/family key,
- every model key resolves or intentionally uses a placeholder,
- no duplicate live server resource instance IDs,
- no invalid area references,
- no invalid evolution references,
- no orphan RemoteEvents from removed systems.

---

# 26. Systems to Remove or Avoid

Remove or avoid unless explicitly reintroduced:

- main conveyor-based acquisition,
- expansive Savannah/open-world dependence,
- NPC selling as a core progression step,
- complex gathering/material banking,
- multiple currencies without distinct purposes,
- combat, enemy HP, weapons, kill progression,
- heavy storage/inventory management,
- large lab-management systems,
- one script per feed,
- one script per guardian,
- one script per area,
- one script per pet,
- over-detailed final assets before gameplay validation,
- endless road extension,
- random-looking original creatures whose silhouettes are unclear,
- client-authoritative economy or progression,
- one RenderStepped connection per billboard/resource,
- permanent infinite tweens on dozens of common objects.

---

# 27. AI-First Development Toolchain

This section describes the preferred 2026 workflow. Tool availability changes over time, so verify versions during setup.

## 27.1 Roblox Studio MCP

Use the **official Roblox Studio MCP server** as the primary bridge between Cursor/Codex and the live Studio place.

Current official Studio MCP capabilities include reading/modifying the open place, editing scripts/instances, executing Luau, entering play mode, testing, and working with Studio through MCP-compatible clients.

Preferred setup:

1. Update Roblox Studio.
2. Open Assistant.
3. Open `Manage MCP Servers`.
4. Enable `Studio as MCP server`.
5. Use Quick Connect for Cursor and/or Codex CLI where available.
6. Verify the client can inspect the DataModel before allowing broad edits.

**Reference:** https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/mcp.md

## 27.2 Source control and filesystem

Use:

- Git for history/rollback,
- Rojo where appropriate to keep code/assets synchronized between filesystem workflows and Studio.

Agents should not treat the Studio DataModel and filesystem as two unrelated projects.

## 27.3 Blender

Preferred final 3D production:

- Blender 5.1+
- official Blender Lab MCP Server/add-on

Use Blender MCP for:

- modeling,
- cleanup,
- topology simplification,
- pivots/origins,
- transforms,
- UVs,
- rigging,
- animation setup,
- triangle-count inspection,
- batch export.

**Reference:** https://www.blender.org/lab/mcp-server/

## 27.4 Roblox AI asset tools

Use Roblox's current AI-assisted asset workflows where useful for fast iteration:

- mesh generation,
- texture generation,
- material generation,
- procedural generation exposed through Studio/Assistant tooling.

Use these primarily for rapid shapes, props, environment pieces, references, and first passes. Do not assume the first generated mesh is production-ready.

## 27.5 Figma Make

Use Figma Make for AI-assisted UI concept generation and rapid system design.

Good use cases:

- HUD concepts,
- Index layouts,
- evolution reveal,
- trainer panels,
- mobile layout exploration,
- component-system iteration.

**Reference:** https://www.figma.com/solutions/ai-ui-generator/

## 27.6 Framewisp

Use Framewisp when converting approved Figma structures into native Roblox UI instances.

It can produce native Roblox constructs such as Frames, TextLabels, TextButtons, ScrollingFrames, CanvasGroups, UICorners, UIStrokes, and UIGradients.

**Reference:** https://create.roblox.com/store/asset/95374365998986

## 27.7 UILint / UILint Solo

Use UILint tooling for responsive UI QA where available.

Check:

- text overflow,
- overlap,
- bad ZIndex,
- excessive Offset dependence,
- invisible unused elements,
- scaling problems,
- mobile layout issues.

## 27.8 Meshy (optional)

Meshy is optional, not required.

Potential uses:

- text/image-to-3D first passes,
- auto-rigging,
- texturing,
- Roblox Bridge upload workflow.

**Reference:** https://docs.meshy.ai/en/webapp/plugins/roblox/introduction

Use Blender/Roblox tools as the final authority for quality and optimization.

---

# 28. 3D Art Direction

## Style

Feed a Pet should be:

- stylized,
- low-poly,
- chunky,
- toy-like,
- bright,
- mobile-readable,
- silhouette-first.

### Creature rules

Recognizable archetypes must stay recognizable.

A T-Rex must instantly read as a T-Rex.  
A crocodile must instantly read as a crocodile.  
A gorilla must instantly read as a gorilla.  
A Triceratops must instantly read as a Triceratops.  
A dragon must instantly read as a dragon.

Suggested creature style:

- oversized head,
- simplified torso,
- chunky limbs,
- large readable eyes where appropriate,
- exaggerated defining features,
- minimal tiny geometry,
- clean silhouette,
- coherent proportion language across the roster.

## Initial triangle-budget guidance

These are targets, not absolute engine limits.

| Asset type | Suggested range |
|---|---:|
| Small feed | ~300–1,500 triangles |
| Complex feed/catalyst | ~800–2,500 |
| Environment prop | ~300–3,000 |
| Player pet | ~2,000–6,000 |
| Guardian | ~5,000–12,000 unless justified |

Prefer 512×512 textures for simple props. Use 1024×1024 when a hero asset materially benefits.

## Rarity VFX

Keep much of rarity spectacle in Studio rather than baking it permanently into the mesh.

Examples:

- Legendary: subtle gold glow
- Mythic: stronger colored glow
- Cosmic: galaxy-like particles
- Secret: dark/prismatic aura
- Eternal: white-violet aura
- Divine: white-gold aura + beam

This keeps the same model reusable across states.

---

# 29. Launch 3D Asset List

## Grasslands

Guardian:

- T-Rex

Resources:

- Raw Meat
- Berries
- Bone Chunk
- Prime Meat
- Wild Herbs
- Giant Rib
- Ancient Bone
- Primal Catalyst

Environment kit:

- grass clumps,
- rock variants,
- bone piles,
- dead log,
- small tree,
- large tree,
- feeding-ground carcass,
- sleeping spot.

## Swamp

Guardian:

- Giant Crocodile

Environment kit:

- mud rocks,
- dead tree,
- mushrooms,
- reeds,
- murky-water props,
- bones,
- logs.

Plus all eight Swamp resource models.

## Jungle

Guardian:

- Giant Gorilla

Environment kit:

- broadleaf plants,
- vines,
- rocks,
- giant roots,
- tree pieces,
- flowers,
- fallen logs.

Plus all eight Jungle resource models.

## Crystal Cave

Guardian:

- Armored Triceratops

Environment kit:

- crystal formations in several sizes,
- rock formations,
- fossil pieces,
- cave pillars,
- bone piles.

Plus all eight Crystal Cave resource models.

## Volcano

Guardian:

- Dragon

Environment kit:

- basalt,
- lava rocks,
- burned trees,
- bones,
- charred carcass,
- volcanic crystals,
- lava-edge props.

Plus all eight Volcano resource models.

---

# 30. Guardian Animation Scope

Do not create unnecessary animation libraries.

Launch guardians need only the motions required by gameplay.

| Guardian | Minimum animations |
|---|---|
| T-Rex | sleep, wake, charge, recover |
| Crocodile | sleep, wake, lunge/tail, recover |
| Gorilla | idle/sleep, wake, slam, recover |
| Triceratops | sleep, wake, charge, recover |
| Dragon | sleep, wake, fire attack, recover |

---

# 31. UI Art Direction

Feed a Pet UI should feel like a modern Roblox collection/simulator game without directly copying another title.

Use:

- rounded chunky panels,
- strong hierarchy,
- bold readable text,
- dark text strokes where useful,
- colorful gradients,
- large mobile-friendly buttons,
- compact HUD footprint,
- playful toy-like visual language,
- minimal unnecessary text.

Use a reusable component system:

- PrimaryButton
- SecondaryButton
- CloseButton
- Panel
- CurrencyDisplay
- ResourceCard
- PetCard
- RarityText
- Toast
- Modal
- ProgressBar
- TabButton

After Figma import, keep UI native rather than flattening screens into screenshots.

---

# 32. Recommended UI Implementation Pipeline

1. Build functional placeholder UI in Studio.
2. Validate data/state behavior.
3. Generate/iterate visual system in Figma Make.
4. Approve the component language.
5. Convert via Framewisp where useful.
6. Wire native GUI to existing client controllers.
7. Use `UIScale`, `UIAspectRatioConstraint`, `UISizeConstraint`, `UIListLayout`, `UIGridLayout`, `UICorner`, `UIStroke`, `UIGradient`, and `CanvasGroup` appropriately.
8. Run UILint/QA.
9. Use Studio MCP to capture/test desktop, tablet-like, and phone layouts.

Suggested interaction animations:

### Modal open

- fade in,
- scale 0.94 → 1.02 → 1.0.

### Modal close

- scale 1.0 → 0.96,
- fade out.

### Toast

- slide/fade in,
- short hold,
- fade upward/out.

### Rare banner

- animation intensity increases with rarity.

---

# 33. Live-Update Content Engine

The game should be updated primarily by adding content to reusable systems, not by adding one-off mechanics every week.

## Standard permanent-area update

A major permanent-area update should generally add:

- 1 new area,
- 1 recognizable guardian,
- exactly 8 new Index resources,
- 1 chase catalyst or equivalent high-value pickup,
- 1 or more compatible pet forms,
- 1 Index page,
- new art/VFX/audio,
- and optionally a new trainer/equipment tier if progression needs it.

## Event update

Events should reuse existing systems.

Example: Blood Moon

- Existing Swamp/Jungle visually transform.
- Event-specific resource pool activates.
- Blood Moon Shard can spawn.
- Existing pets gain compatible Blood forms.
- No combat system is added.

## Future special catalysts

These stay outside launch pools unless explicitly promoted to permanent content.

### Giant Serum

- Titan-style mutation/evolution family.
- Major size and proportion transformation.

### Spirit Energy

- Aura/energy transformation family.
- Serves the game-mechanical role of a chakra-like resource without depending on another franchise's naming.

### Cyber Core

- Mechanical/cyber transformations.

### Void Essence

- Void transformations.

### Blood Moon Shard

- Event-only Blood family.

### Celestial Core

- Celestial transformations.

Keep these concepts separate:

- Rarity
- SpawnWeight
- Event availability
- Mutation
- Evolution family

Do not encode them into one overloaded field.

---

# 34. Example Update Roadmap

| Phase | Content |
|---|---|
| Launch | Grasslands, Swamp, Jungle, Crystal Cave, Volcano; evolution + Power loop |
| Update 1: Ice Age | Frozen zone, Mammoth guardian, 8 resources, Ice Core, frost forms |
| Update 2: Mutation | Aberrant Lab, experiment/recognizable mutant guardian, 8 resources, Mutagen |
| Update 3: Blood Moon | Timed transformation of existing areas, Blood Moon Shard, blood forms |
| Update 4: Depths | Ocean/Trench, Shark guardian, 8 resources, Leviathan catalyst |
| Update 5: Cyber | Factory/tech area, robot/recognizable mechanical guardian, 8 resources, Cyber Core |
| Update 6: Rift | Void area, serpent/dragon guardian, 8 resources, Void Catalyst |

---

# 35. Product Heuristics

- If a feature adds steps between stealing an item and feeding/evolving a pet, it needs a strong reason to exist.
- Every valuable pickup should be visually understandable from a distance.
- Rarer resources should create more social exposure and a more dangerous escape.
- Every area must visually explain why its resources are present.
- Guardians create tension through telegraphed hazards, not combat complexity.
- New content should multiply the existing roster whenever possible.
- A catalyst that creates compatible forms across many pets is more scalable than many isolated one-off creatures.
- Base creatures should be recognizable.
- High-value loot should be physically impressive: larger models, stronger glow, unique carry poses, visible announcements.
- Keep early progression fast enough that a new player experiences meaningful pet growth/evolution quickly.
- Validate gameplay feel with placeholders before spending large amounts of time on polish.

---

# 36. Phased Implementation Plan

The phases below are the preferred execution order for Cursor/Codex. Do not automatically continue to the next phase if the current phase has not passed its acceptance criteria.

## Phase 0: Repository audit and context alignment

### Goal

Understand what currently exists and identify legacy architecture.

### Tasks

- Read this entire document.
- Inspect repository and Studio hierarchy.
- Classify major scripts/modules/remotes as KEEP, REFACTOR, DELETE.
- Identify datastore and monetization dependencies.
- Identify current implementation status of launch resources, spawning, carrying, guardians, feeding, evolution, training, UI, and art.
- Update a short `IMPLEMENTATION_STATUS.md` if useful.

### Acceptance criteria

- No major subsystem is assumed implemented without inspection.
- Legacy dependencies are mapped.
- Safe rollback point exists in Git.

---

## Phase 1: Core architecture and cleanup

### Goal

Remove obsolete old-game complexity and establish shared definitions/services.

### Primary tasks

- Remove/refactor conveyor-first acquisition.
- Remove unused open-world/Savannah dependencies.
- Remove obsolete material banking, selling chains, combat, weapons, heavy lab systems, dead prototype scripts, duplicate UI and unused remotes.
- Preserve data and monetization safety.
- Implement/normalize shared definitions.
- Add validation.

### Acceptance criteria

- Place loads without errors.
- All five launch areas validate.
- All 40 launch resources validate.
- Existing blockout remains intact.
- Save data loads safely.
- Progression is server-authoritative.
- No unused remotes remain from deleted systems.

---

## Phase 2: Resource spawning and world cycle

### Goal

Make the five areas produce physical resources correctly.

### Primary tasks

- Implement 300-second cycle and 10-second reset window.
- Validate 5 nodes per area.
- Weighted spawning using authoritative tables.
- Mid-cycle respawn rules.
- Secret+ exclusions/caps.
- Unique server resource IDs.
- Resource state lifecycle.
- Functional reset timer.
- Functional rarity billboards.
- Secret/Eternal/Divine announcement hooks.

### Acceptance criteria

- Weights statistically approximate configuration over many simulated rolls.
- No duplicate resources are possible.
- Carried resources survive resets.
- Secret+ never mid-cycle respawns.
- Respawn timers cancel safely at reset.
- Billboard cleanup leaves no leaked connections.

---

## Phase 3: Carrying and guardians

### Goal

Complete the core world-risk interaction.

### Primary tasks

- One-item carry limit.
- Server-side Power validation.
- Physical carry attachment.
- Carry slowdown.
- Carry HUD.
- Shared guardian state machine.
- T-Rex/Crocodile/Gorilla/Triceratops/Dragon hazard configs.
- Dropped resource handling.

### Acceptance criteria

Test:

- exact Power threshold,
- below-threshold rejection,
- simultaneous pickup attempts,
- drop from hazard,
- another player stealing a dropped item,
- player reset while carrying,
- disconnect while carrying,
- guardian wake from simultaneous pickups,
- immediate Secret+ wake,
- no duplication.

---

## Phase 4: Feeding, pet state, affinities, evolution

### Goal

Implement the game's identity loop.

### Primary tasks

- Base feeding interaction.
- Server-side consumption.
- Growth.
- Flesh/Floral/Mineral.
- Catalyst-family tags.
- One complete starter evolution family.
- Functional evolution reveal.
- Save/rejoin integrity.

### Acceptance criteria

- Resource consumed exactly once.
- Growth/affinity persist.
- Catalyst state persists.
- Evolution persists.
- Rejoin restores exact pet state.
- RemoteEvent spam cannot duplicate feeding/evolution.

---

## Phase 5: Cash, trainer, Power loop, Slow Mode

### Goal

Close the secondary progression loop.

### Primary tasks

- Passive Cash if retained.
- Trainer definitions and upgrade flow.
- Training Power gain.
- Pet training multiplier.
- Resource Power gating.
- Slow Mode.

### Acceptance criteria

A new save can:

1. steal a basic resource,
2. feed a pet,
3. improve the pet,
4. train Power,
5. upgrade training,
6. carry something previously inaccessible.

---

## Phase 6: UI system

### Goal

Replace placeholder UI with a cohesive AI-assisted native Roblox UI system.

### Primary tasks

- Generate/refine approved Figma design.
- Import/convert with Framewisp where useful.
- Keep native Roblox GUI instances.
- Wire to existing client state.
- Implement responsive desktop/mobile layouts.
- Add animation helpers.
- Run UILint/QA.

### Acceptance criteria

- Main launch UI surfaces exist.
- Mobile controls are usable.
- No text overflow or critical overlap.
- No UI owns authoritative progression logic.

---

## Phase 7: 3D art pass

### Goal

Replace blockout assets with coherent stylized content without changing gameplay architecture.

### Primary tasks

- Establish final art bible.
- Build/import five guardians.
- Build/import 40 launch resources.
- Build modular biome kits.
- Produce required guardian animations only.
- Apply collision, pivots, scaling, tags, and model keys.
- Add rarity VFX in Studio.

### Acceptance criteria

- Recognizable silhouettes.
- Mobile-appropriate complexity.
- Correct pivots/scale/collision.
- No gameplay logic depends on temporary mesh structure.

---

## Phase 8: Index, onboarding, audio, VFX, release polish

### Goal

Complete the launch-facing experience.

### Primary tasks

- Index.
- First-time objectives.
- Area signage.
- Rare announcements.
- SFX/VFX.
- Evolution polish.
- Reset transition.
- Performance audit.
- save/disconnect testing.
- multiplayer test.
- mobile test.

### Acceptance criteria

- New player understands loop quickly.
- Five areas function.
- 40 resources are discoverable.
- progression persists.
- no major duplication exploit.
- acceptable mobile performance.

---

## Phase 9: Live-content framework

### Goal

Make future updates mostly content configuration rather than new architecture.

### Primary tasks

- Generic EventDefinitions.
- Event-specific pools.
- Area visual transformations.
- Special catalysts.
- Compatible form tables.
- Event countdown/banner/progress hooks.

### Acceptance criteria

A future event can be added largely through:

- config,
- assets,
- UI content,
- VFX/audio,
- without a new bespoke gameplay service.

---

# 37. Current Vertical-Slice Target

Before broad implementation, the most important playable proof is:

**Spawn → Grasslands → pick up a resource → trigger T-Rex risk → return to base → feed pet → gain Growth/affinity → evolve → train Power → carry a previously inaccessible resource.**

The five-area data can already be design-locked while gameplay feel is validated through Grasslands first.

---

# 38. Open Decisions

The following are not fully locked and should not be silently decided by an agent unless the implementation task explicitly asks for a recommendation:

- Exact Cash production rates and trainer prices.
- Exact player movement-speed scaling outside Slow Mode.
- Whether Resistance becomes a visible stat or remains derived/internal.
- How many pets a player may own vs actively display.
- Evolution-choice UX when multiple branches are simultaneously eligible.
- Whether some special catalysts are deterministic or probabilistic.
- Exact global-event cadence.
- Whether direct player-to-player theft is ever added beyond competition over world resources.
- Final area-completion Index rewards.
- Exact starter pet roster and first evolution tree.

Resolved decisions:

- Game name is `Feed a Pet`.
- Launch uses five areas.
- Launch uses exactly 40 area resources.
- Each area has exactly eight Index resources.
- Each area has exactly five world ResourceNodes.
- Rarity order is Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret → Eternal → Divine.
- Spawn probability is explicit and separate from rarity.
- Field cycle is 300 seconds with a 10-second reset window.
- Secret+ does not mid-cycle respawn.
- Launch carry capacity is one major resource.
- Guardians are non-combat hazards.
- Conveyor is not part of the main acquisition loop.
- Power is the main carry/progression gate.
- Dropped loot is claimable and expires after 20 seconds.

---

# 39. Compact Agent Context

Use this when a coding agent needs the shortest reliable summary:

> **PROJECT: Feed a Pet.** Roblox game. Four player bases face a long, narrow path with five launch areas: Grasslands, Swamp, Jungle, Crystal Cave, Volcano. Each area has one recognizable non-combat guardian, exactly five physical world resource nodes, and exactly eight Index resources. Players run out, take a feed/catalyst, survive a guardian hazard, return to base, feed an active pet, gain Growth and Flesh/Floral/Mineral affinity, evolve the pet, train Power, and use higher Power to carry heavier/deeper resources. Launch rarity order is Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic, Secret, Eternal, Divine. Rarity is independent of SpawnWeight. The server uses a 300-second field cycle with a 10-second reset window. Secret/Eternal/Divine do not mid-cycle respawn and receive increasingly dramatic announcements. Carry capacity is one. Guardians do not have HP and are not fought. Stronger pets improve training/income. The codebase must stay small, data-driven, reusable, server-authoritative, and optimized for AI-assisted content production. Remove legacy conveyor/open-world/combat/material-banking/lab-management complexity unless explicitly preserved. Use official Roblox Studio MCP with Cursor/Codex, Git/Rojo, Blender 5.1+ with Blender Lab MCP for final 3D, Roblox AI asset tools for rapid generation, Figma Make + Framewisp + UILint for UI workflow, and Meshy only as an optional supplementary generator. Do not assume a feature is implemented simply because it appears in this context; inspect the repository and distinguish DESIGN LOCKED, IMPLEMENTED, and VALIDATED.**

---

# 40. External Tool References

Current tool references used when updating this document:

- Roblox Studio MCP: https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/mcp.md
- Blender Lab MCP Server: https://www.blender.org/lab/mcp-server/
- Blender 5.1: https://www.blender.org/releases/5-1/
- Figma Make AI UI generator: https://www.figma.com/solutions/ai-ui-generator/
- Framewisp Creator Store page: https://create.roblox.com/store/asset/95374365998986
- Meshy Roblox Bridge docs: https://docs.meshy.ai/en/webapp/plugins/roblox/introduction

---

# 41. Final Implementation Principle

Whenever there is a choice between preserving old complexity and implementing this loop cleanly, choose the clean loop unless doing so would break save integrity, purchases, or another explicitly preserved dependency.

**Feed a Pet should feel simple to play and deep to collect.**
