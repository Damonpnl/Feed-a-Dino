**FEED A PET**

*Cursor + Codex Comprehensive Project Context*

Authoritative implementation context for AI coding agents, gameplay systems, content architecture, and live updates

**Core principle: make the acquisition loop extremely simple, and put the depth into monsters, evolution, rarity, catalysts, and live updates.**

Project naming: use “Feed a Pet” in player-facing text, code comments, documentation, package names, and newly created identifiers. Do not introduce new references to the old working names. Legacy identifiers may remain temporarily only when renaming them would create unnecessary migration risk.

# 1. Executive Summary

Feed a Pet is a compact Roblox pet-collection and evolution game built around a linear risk/reward pathway. Players leave one of four bases, travel through increasingly dangerous themed areas, grab physical feeds and catalysts, escape recognizable guardian hazards, return to base, feed and evolve their pet, train their own Power, and then raid deeper zones for heavier and rarer resources. The pet roster can include animals, dinosaurs, mythic creatures, and monster transformations, while remaining visually recognizable.

| **Old Direction**                       | **New Direction**                                                  |
|-----------------------------------------|--------------------------------------------------------------------|
| Large creature/conveyor/simulation game | Compact steal, escape, feed, evolve loop                           |
| Expansive Savannah/open-world emphasis  | Long, narrow, highly legible progression path                      |
| Many intertwined economy systems        | One primary progression loop plus one supporting Power loop        |
| Dinosaurs as the full identity          | Recognizable monsters, animals, dinosaurs, mythic creatures        |
| Combat/enemy systems possible           | No traditional combat, guardians are hazards                       |
| Bespoke mechanics per zone              | Reusable data-driven area, resource, guardian, and monster systems |
| Polish before core validation           | Graybox vertical slice first, AI/Blender polish later              |

# 2. Cursor / Codex Operating Instructions

After each substantial implementation step, run the available checks/tests or at minimum inspect for Luau errors, broken requires, dangling remotes, and invalid references before continuing.

Keep code simple enough for another agent to understand quickly. Favor small services/modules, explicit state, typed Luau where useful, descriptive names, event-driven logic, and minimal dependency depth. Avoid unnecessary frameworks, excessive inheritance, giant manager scripts, and duplicated per-content scripts.

When deleting scripts, modules, remotes, tags, or attributes, first confirm they are not referenced by retained systems. Delete dead code instead of commenting it out. Use version control for history.

Do not spend engineering time on final art or polished UI while core systems are unstable. Environment and pet models will be produced through Blender MCP, and final interface work will be AI-assisted. Gameplay code should expose clean model, animation, VFX, SFX, and UI hooks so assets can be replaced without rewriting systems.

Keep progression server-authoritative. The client may request interactions and render feedback, but Power, inventory/carry state, feed consumption, evolution, currency, unlocks, and save data must be validated and mutated on the server.

Prefer configuration-driven content. New feeds, catalysts, pets, forms, guardians, and areas should usually be added through definitions and assets rather than new bespoke scripts. Shared systems should own behavior, while content definitions provide values and references.

Work vertically before working broadly. The first target is one complete playable slice: spawn -\> enter Grasslands -\> pick up a resource -\> carry it -\> trigger the T-Rex guardian hazard -\> return to base -\> feed the pet -\> apply growth/affinity -\> evolve -\> train Power -\> carry a previously inaccessible resource.

Before major changes, inspect the relevant repository area and trace dependencies. Remove obsolete architecture rather than layering the new game on top of legacy conveyor, open-world, combat, selling, banking, or lab-management systems. Preserve datastore compatibility and monetization receipt handling unless a migration is intentionally implemented.

This document is the implementation source of truth for Cursor, Codex, and other coding agents working on Feed a Pet. When repository code conflicts with this document because it belongs to the previous game direction, prefer this document unless the existing behavior is required for data integrity, purchases, or another explicitly preserved system.

# 3. North-Star Gameplay

**Primary loop:** RUN OUT -\> GRAB ITEM -\> ESCAPE -\> FEED MONSTER -\> EVOLVE -\> GET STRONGER -\> GO FARTHER

**Secondary loop:** BETTER MONSTER -\> BETTER TRAINING MULTIPLIER -\> MORE POWER -\> HEAVIER / DEEPER LOOT -\> BETTER MONSTER

The player should understand both loops within minutes. The map exists to create visible distance, risk, competition, and spectacle. The monster system carries most of the long-term depth.

# 4. World Layout

Use four player bases facing a long central pathway that is substantially longer than it is wide. The path is divided into visually distinct areas. Players should be able to see activity ahead and behind them, so encounters and valuable loot remain socially visible.

| **Principle**       | **Implementation**                                                                                                      |
|---------------------|-------------------------------------------------------------------------------------------------------------------------|
| Four bases          | Compact base plots at the safe end of the pathway                                                                       |
| Linear progression  | Areas ordered from low-risk to high-risk                                                                                |
| Narrow social space | Wide enough to dodge hazards, narrow enough that players cannot avoid everyone                                          |
| Risk by distance    | Farther zones have better resources and longer escape routes                                                            |
| Small biome pockets | Minor side alcoves/caves are fine, but avoid sprawling open-world layouts                                               |
| Expansion limit     | After roughly 6-8 permanent areas, prefer branches, portals, events, or alternate routes instead of endless road length |

# 5. Authoritative Launch Areas

Exactly five launch areas, eight Index resources each, five designated world nodes each. See [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md) for all 40 exact values and spawning rules; it supersedes previous example pools.

Guardians should be recognizable silhouettes, not arbitrary invented creatures. Each zone should have an obvious relationship between environment, guardian, and resource source.

| **Area**               | **Guardian**                              | **Natural Resource Logic**                       | **Key Feeds / Catalysts**                                            | **Progression Bias**       |
|------------------------|-------------------------------------------|--------------------------------------------------|----------------------------------------------------------------------|----------------------------|
| Grasslands             | T-Rex                                     | Fresh carcass / feeding ground                   | Raw Meat, Bone Chunk, Berries, Giant Rib, Ancient Bone, Primal Catalyst | Basic Flesh / Floral       |
| Swamp                  | Giant Crocodile                           | Fish pools, rotten carcasses, mushrooms, venom   | Small Fish, Rotten Meat, Venom Sac, Spore Pod, Toxic Catalyst       | Poison / Flesh / Floral    |
| Jungle                 | Giant Gorilla                             | Fruit grove, vines, flowers, insects             | Wild Fruit, Giant Beetle, Rare Flower, Jungle Heart                  | Floral / Strength / hybrid |
| Crystal Cave           | Armored Triceratops                       | Geodes, fossils, mineral growths                 | Crystal Shard, Fossil Marrow, Living Geode, Crystal Catalyst         | Mineral / armor            |
| Volcano                | Dragon                                    | Charred feeding ground, magma deposits           | Charred Meat, Ember Heart, Fire Core, Dragon Blood, Inferno Catalyst | Fire / high Flesh          |

Ancient/Rift endgame is future content, not a sixth launch pool. Preserve its existing scene blockout without spawning launch resources there.

# 6. Resource Design: Feeds and Catalysts

Do not label every world object generically as “Feed.” The system can treat them as feeds internally, but each pickup should look like a real object that belongs to the area.

| **Category**     | **Purpose**                                                         | **Examples**                                                         |
|------------------|---------------------------------------------------------------------|----------------------------------------------------------------------|
| Normal Feed      | Adds growth and/or one affinity                                     | Raw Meat, Wild Fruit, Crystal Shard, Spore Pod                       |
| Specialized Feed | Adds stronger affinity or a secondary effect                        | Venom Sac, Ember Heart, Fossil Marrow                                |
| Catalyst         | Unlocks/checks a branch                                             | Fire Core, Crystal Catalyst, Primal Catalyst                        |
| Special Catalyst | Unlocks transformation families                                    | Dragon Blood; future-only Giant Serum, Spirit Energy, Cyber Core, Void Essence |

Special catalysts should create meaningful model transformations, not just recolors. A Giant Serum should dramatically alter scale and proportions. A Cyber Core should produce mechanical parts. Dragon Blood should visibly add draconic traits.

# 7. Core Affinity System

Retain the existing three-affinity foundation, but treat the affinities as biological forces rather than dinosaur categories.

| **Affinity** | **Meaning**                                           | **Typical Visual Traits**                              |
|--------------|-------------------------------------------------------|--------------------------------------------------------|
| Flesh        | Predation, muscle, regeneration, horns, claws, mouths | Larger jaws, muscle, teeth, spikes, organic aggression |
| Floral       | Plants, fungus, poison, symbiosis, parasites          | Vines, blooms, spores, moss, toxins                    |
| Mineral      | Armor, bone, crystal, stone, metal-like growth        | Plates, geodes, crystal horns, rock armor              |
| Neutral      | Growth without normal affinity; catalyst family hooks | Family-specific traits                               |

Hybrid outcomes can combine affinities. Flesh + Mineral can create an armored brute. Flesh + Floral can create a parasitic predator. Floral + Mineral can create a living crystal/plant form. Special catalysts can override or redirect these branches.

Current hybrid resource affinity gains split Growth evenly between the two configured affinities. Floral remains stored as `Flora` for save compatibility. Special family unlocks persist separately in `EvolutionFamilies`.

# 8. Monster Roster Philosophy

Keep the base roster instantly recognizable. Roughly 70-80% of the roster should begin from familiar animals, dinosaurs, or mythic archetypes. Originality comes from evolution forms, mutation combinations, proportions, materials, and special catalysts.

| **Base Creature** | **Possible Forms**                                           |
|-------------------|--------------------------------------------------------------|
| Wolf              | Dire Wolf, Crystal Wolf, Spirit Wolf, Cyber Wolf, Void Wolf  |
| T-Rex             | Blood Rex, Armored Rex, Magma Rex, Titan Rex                 |
| Gorilla           | Titan Gorilla, Jungle Gorilla, Mutant Gorilla, Cyber Gorilla |
| Crocodile         | Swamp Crocodile, Mutant Crocodile, Crystal Crocodile         |
| Spider            | Thorn Spider, Crystal Spider, Void Spider, Blood Widow       |
| Dragon            | Fire Dragon, Spirit Dragon, Crystal Dragon, Void Dragon      |
| Bear              | Stone Bear, Cyber Bear, Frost Bear                           |
| Shark             | Megalodon, Abyss Shark, Cyber Shark                          |

# 9. Guardian Design Without Combat

Guardians are environmental threats, not enemies to kill. Players steal resources from a natural source near the guardian. Resource pickups raise disturbance until the guardian triggers a readable hazard.

| **State** | **Function**                                                                 |
|-----------|------------------------------------------------------------------------------|
| Sleeping  | Guardian is inactive, resources are available                                |
| Disturbed | Pickup activity increases a disturbance or wake meter                        |
| Warning   | Audio/animation/visual telegraph signals danger                              |
| Hazard    | Roar, stomp, charge, tail sweep, gas cloud, falling rocks, short chase, etc. |
| Cooldown  | Guardian settles, zone resets                                                |
| Sleeping  | Cycle begins again                                                           |

Hazards should primarily knock players back, slow them, or force them to drop carried items. Avoid HP bars, weapons, damage builds, kill rewards, and combat balancing unless the entire game direction later changes.

# 10. Power, Carrying, and Player Progression

Power is the main player-side progression stat. It determines what the player can physically carry and helps gate deeper resources naturally.

| **Stat / Mechanic**      | **Role**                                                            |
|--------------------------|---------------------------------------------------------------------|
| Power                    | Primary progression gate; determines which resources can be carried |
| Carry Weight Requirement | Each valuable resource has a minimum Power threshold                |
| Carry Speed Multiplier   | Large or rare loot can slow the carrier                             |
| Resistance               | Optional derivative of Power, reduces guardian knockback            |
| Speed                    | Secondary optimization stat, not the primary gate                   |
| Monster Multiplier       | Equipped/stronger monster increases training efficiency             |

A player can physically enter a later zone before they are ready, but the best loot there should be too heavy to carry. This is preferable to relying entirely on invisible walls.

# 11. Training Loop

Use a simple base training station rather than copying a treadmill literally. The training station can later receive a thematic model and animation. The equipped monster provides a training multiplier, closing the progression loop.

| **Example**              | **Effect**                                                 |
|--------------------------|------------------------------------------------------------|
| Starter monster          | x1 to x2 training multiplier                               |
| Mid-tier evolved monster | x10 to x25 multiplier                                      |
| Rare catalyst form       | x50+ multiplier                                            |
| Endgame mythic form      | Very high multiplier, balanced against progression economy |

# 12. Base Design

Keep bases functional and visually legible. Avoid rebuilding the old lab/tycoon complexity.

- Monster enclosure/display: shows the currently active monster and its visible evolution.

- Feeding point: consumes the carried resource and applies growth, affinity, or catalyst effects.

- Training station: converts active play into Power, modified by monster strength.

- Minimal upgrades: training efficiency, convenience, perhaps resource handling later.

- Optional passive cash display: only if Cash has a clear purpose.

- Safe return zone / spawn point.

# 13. Conveyor Decision

Remove the conveyor from the primary acquisition loop. The main game should be about physically leaving the base and stealing resources. If retained, the conveyor should become a minor secondary base upgrade, such as an automated basic-feed processor or passive convenience feature.

# 14. Economy

Keep the economy minimal. Avoid multiple redundant currencies. If Cash remains, monsters may produce passive Cash and Cash may upgrade training efficiency or base convenience. Power should remain the clearest player progression stat.

# 15. Live-Update Content Engine

The game should be built so that most updates are content additions rather than new systems. The reusable update formula is:

**NEW AREA + RECOGNIZABLE GUARDIAN + 3-5 FEEDS + 1-2 CATALYSTS + NEW FORMS**

| **Update Type**     | **Example**                        | **Why It Scales**                                          |
|---------------------|------------------------------------|------------------------------------------------------------|
| Permanent Area      | Frozen Wastes + Mammoth + Ice Core | Adds new progression depth and resource tier               |
| Special Catalyst    | Cyber Core                         | Creates new forms across many existing creatures           |
| Limited Event       | Blood Moon                         | Reuses existing areas with temporary rare drops and forms  |
| Server Event        | Meteor Crash                       | One contested pickup creates spectacle without a new biome |
| New Creature Family | Shark / Spider / Bear              | Expands collection without changing core systems           |
| New Mutation Family | Void / Spirit / Titan              | Multiplies existing roster through transformations         |

# 16. Example Update Roadmap

| **Phase**            | **Content**                                                                     |
|----------------------|---------------------------------------------------------------------------------|
| Launch               | Grasslands, Swamp, Jungle, Crystal Cave, Volcano; core evolution and Power loop |
| Update 1: Ice Age    | Frozen zone, Mammoth guardian, Frozen Meat, Ice Core, frost forms               |
| Update 2: Mutation   | Aberrant Lab, experiment guardian, Mutagen, hybrid forms                        |
| Update 3: Blood Moon | Temporary event, Blood Moon Shards, blood/werewolf/vampiric forms               |
| Update 4: Depths     | Ocean/Trench, Shark guardian, Leviathan Scale, aquatic forms                    |
| Update 5: Cyber      | Factory/tech area, robot guardian, Cyber Core, mechanical forms                 |
| Update 6: Rift       | Void area, serpent/dragon guardian, Void Catalyst, endgame forms                |

# 17. Technical Architecture

The implementation should be data-driven and small. Adding a feed, monster, catalyst, or area should generally involve definitions and assets, not new bespoke scripts.

| **System**        | **Responsibility**                                          |
|-------------------|-------------------------------------------------------------|
| DataService       | Player save/load, migration, authoritative persistent state |
| FeedService       | Resource consumption and feed effects                       |
| MonsterService    | Growth, affinities, evolution, active monster               |
| CarryService      | Pickup, carry validation, dropping, movement modifier       |
| SpawnService      | Area resource pools, weighted spawning, cleanup             |
| GuardianService   | Reusable disturbance state machine and hazards              |
| TrainingService   | Power gain and monster multiplier                           |
| BaseService       | Base ownership, feed point, training interaction            |
| UIController      | Client UI only, reads server-authoritative state            |
| EffectsController | Client visuals, sounds, camera effects, animations          |

Recommended shared definitions: FeedDefinitions, CatalystDefinitions, MonsterDefinitions, AreaDefinitions, and RarityDefinitions.

# 18. Suggested Data Schemas

| **Definition** | **Important Fields**                                                                                                           |
|----------------|--------------------------------------------------------------------------------------------------------------------------------|
| Resource (Feed/Catalyst) | Id, DisplayName, ResourceType, Rarity, Area, Growth, Affinity, PowerRequired, SpawnWeight, CarrySlowdown, SpecialEffect, ModelKey, BillboardOffset |
| Monster        | DisplayName, BaseMultiplier, GrowthRequired, Affinities, Evolutions, CompatibleCatalysts, Rarity                               |
| Area           | Order, Guardian, ResourcePool (explicit Id/SpawnWeight entries), progression values                                            |
| PlayerData     | Cash, Power, EquippedMonster, Monsters, BaseUpgrades, DiscoveredAreas, Stats                                                   |

# 19. AI-First Content Pipeline

Final 3D production is planned around Blender MCP, while UI will be generated/refined with AI. Therefore the game code should expose clean asset slots and avoid coupling gameplay logic to final models or interface layouts.

| **Pipeline Stage** | **Approach**                                                                     |
|--------------------|----------------------------------------------------------------------------------|
| Graybox            | Roblox parts and placeholder models; validate traversal and gameplay             |
| Creature Art       | Blender MCP, recognizable low-poly silhouettes, exaggerated defining traits      |
| Environment Kit    | Small reusable kit per biome: rocks, plants, arches, debris, resource props      |
| UI                 | Functional placeholder UI first, polished AI-assisted UI after systems stabilize |
| VFX/SFX            | Add after interactions and timing feel correct                                   |
| Content Scaling    | New models plugged into existing definitions and reusable services               |

Art direction: low-poly, chunky, readable on mobile, oversized distinguishing features, minimal texture complexity, coherent proportions and eyes across the roster.

# 20. Current Development Priority

The five-area resource/rarity/field specification is implemented in shared data and reusable services. Continue validating the Grasslands vertical slice for progression feel before adding final art or new systems.

- Grasslands resource spawning

- Eight Index resources (seven feeds plus Primal Catalyst) and five world nodes

- Pickup and one-item carry system

- Power requirement and carry slowdown

- T-Rex guardian disturbance cycle

- Return-to-base feeding interaction

- ProtoRex/starter monster growth and affinity

- One evolution result

- Monster training multiplier

- Power training

- One heavier item that becomes obtainable after progression

**Vertical-slice success condition:** a brand-new player can spawn, steal an item, experience a guardian hazard, return home, feed a monster, evolve it, train Power, and then successfully steal something they could not previously carry.

# 21. Systems to Remove or Avoid

- Main conveyor-based acquisition

- Large open-world/Savannah dependence

- NPC selling as a core step

- Complex gathering and material banking

- Multiple currencies without distinct purposes

- Combat, enemy HP, weapons, and kill progression

- Heavy storage/inventory management

- Large lab management systems

- Unique scripts for every feed, guardian, area, or monster

- Overly detailed models before graybox validation

- Endless path extension after the map becomes too long

- Random-looking original creatures whose silhouettes are not immediately recognizable

# 22. Product Heuristics

- If a feature adds steps between stealing an item and feeding/evolving a monster, it needs a strong reason to exist.

- Every valuable pickup should be visually understandable from a distance.

- Rarer resources should create more social exposure and a more dangerous escape.

- Every area must have a clear environmental explanation for why its resources are present.

- Guardians create tension through telegraphed hazards, not combat complexity.

- New content should multiply the existing roster whenever possible. A new catalyst that works across 15 creatures is more scalable than 15 isolated bespoke systems.

- Base creatures should be recognizable. Special forms provide originality.

- Keep early progression fast enough that players see an evolution quickly.

- Make high-value loot physically impressive: larger objects, glow, unique carry poses, visible announcements when appropriate.

- Validate feel with placeholders before spending time on polish.

# 23. Open Decisions to Resolve During Prototyping

- Future path length beyond the five launch areas.

- Whether Speed is trained separately or derived partly from Power.

- Whether monsters generate passive Cash, and what Cash uniquely buys.

- RESOLVED: dropped loot is immediately claimable and expires after 20 seconds.

- Whether players can steal from each other directly, or only compete over world resources.

- How many monsters a player can own versus actively display.

- How evolution choice is presented when multiple affinity branches are eligible.

- Whether special catalysts are always deterministic or sometimes probabilistic.

- How frequently global/server events occur and how contested they should be.

- RESOLVED: The game is named Feed a Pet.

- RESOLVED: launch uses five areas, 40 resources, exactly ten rarities, explicit weights totaling 100 per area, and a server-wide 300-second field cycle with a ten-second reset/night transition. Secret+ rolls have per-area/server caps and no pity. See [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md).

# 24. Compact Cursor / Codex Context

Use the following as the shortest reliable summary when handing the project to Cursor, Roblox Studio agents, Blender MCP, or another collaborator:

| PROJECT: Feed a Pet. Roblox game. Four player bases face a long, narrow pathway containing progressively harder themed areas. Players leave base, take a physical feed or catalyst from a natural resource source near a recognizable guardian, survive a non-combat hazard, return, and feed the item to their active pet. Feeds add growth and Flesh/Floral/Mineral affinity. Catalysts unlock or force transformation families such as Titan, Spirit, Cyber, Fire, Crystal, Mutant, or Void. Stronger evolved pets increase the player training multiplier. Training raises Power. Power gates heavier and rarer pickups, allowing deeper progression. The codebase should be small, data-driven, reusable, server-authoritative, and optimized for rapid AI-assisted content production. Use shared definitions for feeds, catalysts, pets, areas, rarities, and guardian configuration. Use reusable services for data, carrying, spawning, feeding, evolution, guardians, training, and bases. Do not rebuild the old conveyor-centric, expansive Savannah, NPC-selling, material-banking, combat, weapon, or heavy lab-management architecture. Build and validate one complete Grasslands vertical slice before implementing all areas. Final 3D is expected to come from Blender MCP and final UI from AI-assisted workflows, so gameplay code must remain decoupled from final assets. |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

The compact summary's vertical-slice advice concerns gameplay feel, not permission to replace the authoritative five-area tables. Required rarity order is Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic, Secret, Eternal, Divine. Read [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md) before changing any resource, node, drop or spawn behavior. Future-only catalysts stay outside launch pools.

*Document status: product context plus authoritative resource specification, updated 2026-10-09.*
