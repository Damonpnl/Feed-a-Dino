# Current State

Last updated: 2026-10-09

**Product:** [Feed a Pet](FEED_A_PET_CONTEXT.md) — compact steal → escape → feed → evolve loop on a long, narrow path. Use `FEED_A_PET_CONTEXT.md` as the authoritative product and implementation direction when it conflicts with older docs or legacy naming.

**Repo note:** Rojo project name and some module IDs (for example `MonsterService`, `MonsterDefinitions`) are legacy; new player-facing copy and docs should say **pet**, not rebuild old “Feed a Dino” conveyor/simulation identity.

**Resource authority:** [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md) owns the exact 40 launch resources, ten-rarity order, five-area pools and synchronized field rules. Older example tables are superseded.

## North-star loops

**Primary:** RUN OUT → GRAB ITEM → ESCAPE → FEED PET → EVOLVE → GET STRONGER → GO FARTHER

**Secondary:** BETTER PET → BETTER TRAINING MULTIPLIER → MORE POWER → HEAVIER / DEEPER LOOT → BETTER PET

## World (Studio-owned)

Area **blockouts are in place**. Code does not edit the saved place; it reads markers and zones.

| Asset | Path |
|-------|------|
| Four bases | `Workspace.Bases` (`Base1`–`Base4`) |
| Base markers | Under each base’s `NewBase`: `PlayerSpawn`, `CreatureSpawn`, `FeedingPoint` (with ProximityPrompt) |
| Linear path zones | `Workspace.ExpeditionZones`: `Grasslands`, `Swamp`, `Jungle`, `CrystalCave`, `Volcano`, `AncientRuins` |
| Resource node markers | Five saved `ResourceNodes.Node01`–`Node05` parts per launch area; 25 total, unique NodeId and matching AreaId |
| Runtime gameplay instances | Created at play: `Workspace.GeneratedGameplay` (resources, guardians, pet placeholders, training pads) |

Layout intent: four compact bases at the safe end; a long central corridor (+X in current blockouts) with progressively harder pockets—not an open-world Savannah.

## Launch areas

| Order | Area | Guardian | Resources / nodes |
|------:|------|----------|-------------------|
| 1 | Grasslands | T-Rex | 8 / 5 |
| 2 | Swamp | Giant Crocodile | 8 / 5 |
| 3 | Jungle | Giant Gorilla | 8 / 5 |
| 4 | CrystalCave | Armored Triceratops | 8 / 5 |
| 5 | Volcano | Dragon | 8 / 5 |

All five pools match the authoritative values and sum to 100. AncientRuins is preserved scene content, excluded from launch spawning. Guardians/resources are still swappable graybox models, not final art.

## Rojo codebase (simplified stack)

Modules live under `src/shared`, `src/server`, `src/client`. Obsolete conveyor, expedition, economy, tablet, biome, and old lineage trees are **removed from disk** (re-sync Rojo in Studio to drop stale instances under `Server` / `Shared` / `Client` if they still appear).

| Layer | Modules |
|-------|---------|
| Shared definitions | `FeedDefinitions`, `CatalystDefinitions`, `MonsterDefinitions`, `AreaDefinitions`, `RarityDefinitions`, `ResourceCatalog`, `ResourceTypes`, `EvolutionCalculator`, `PlayerData` |
| Server services | `DataService`, `BaseService`, `CarryService`, `SpawnService`, `GuardianService`, `FeedService`, `MonsterService`, `TrainingService`, `ZoneGeometry`; bootstrap `GameBootstrap.server.luau`; smoke `MonsterLoopTest.server.luau` |
| Client | `UIController`, `CarryController` (G to drop), `EffectsController` (hazard camera shake) |

Resource additions: `ResourceDefinitions`, `ResourceValidation`, `ResourceModelDefinitions`, `ResourceEffects`, `SpecialEffectDefinitions`, `FieldConfig`, `FieldRoller`, `FieldState`, server `ResourceVisualService`, and client `FieldPresentation` / `FieldController`. Rojo also maps a ServerStorage-only unit suite and a disabled server test runner.

Server-authoritative: carry, Power gates, feeding, evolution, Cash/Power, saves. One carried world resource at a time. Guardians use disturbance → warning → hazard (knockback + forced drop), not combat HP.

## Vertical slice (Grasslands) — checklist

Target from product context: validate **one** complete path before expanding every area’s content.

| Step | Implementation |
|------|----------------|
| Grasslands spawning | `SpawnService` + `AreaDefinitions.Grasslands` |
| Pickup + one-item carry | `SpawnService` / `CarryService`; Power check; carry speed multiplier |
| T-Rex guardian cycle | `GuardianService` (sleeping → disturbed → warning → hazard → cooldown) |
| Return + feed | `FeedService` on owned base `FeedingPoint` |
| Starter pet growth + Flesh/Flora/Mineral | `MonsterService` + `PlayerData`; starter **Proto Rex** |
| Evolution | `EvolutionCalculator` — e.g. Fangling / Mossback / Stonehide at growth + affinity thresholds |
| Training multiplier | Equipped pet `BaseMultiplier` scales Power gain |
| Power training | `TrainingService` pad at base; Cash upgrades training level |
| Heavier loot after Power | e.g. Bone Chunk (`PowerRequired` 50), Giant Rib (`PowerRequired` 350) |

**Success condition (playtest):** New player can spawn, steal an item, survive a guardian telegraph, feed at base, evolve once, train Power, then carry something they could not carry at spawn (heavier/rarer pickup).

**Verified through Roblox Studio MCP:** 84 deterministic unit cases pass; all 50,000 launch-pool tickets are exhaustively checked against exact weights. The real-cycle integration test passes 18 checks including Power rejection, duplicate/forged pickup rejection, same-ID drop/reclaim, the actual 300-second reset, ten-second transition, carried preservation and 25 fresh node IDs. A further 14 live runtime checks pass for swappable carried models, welds/slowdown, real drop expiry/refill and external destruction. All ten billboard tiers pass 85 client assertions. Client night lighting was observed. `MonsterLoopTest` and config/world validation pass. These checks do not replace a fresh-player balance/fun playthrough or a two-human multiplayer session.

## Synchronized field

Rare presentation also passes 12 client checks for all three announcement/sound hooks, Divine area/item text, night lighting/restoration and Stop/Start cleanup. Nine additional VFX checks confirm aura/beacon/burst components and extended billboard distances. Fixture notifications were explicit tests, not changes to production spawn odds.

One server-wide field fills 25 nodes. Every 300 seconds: clear uncarried items, cancel refill timers, reset disturbance/hazard callbacks, show ten seconds of client night lighting, then refill. Carried loot survives; its old node reservation detaches so it cannot steal a fresh node's ownership.

Consumption/destruction schedules a refill: Common–Rare 18s, Epic–Legendary 25s, Mythic/Cosmic 40s; chase items never refill mid-cycle. Mid-cycle rolls renormalize eligible weights below Secret. Hard-reset batches keep only their highest Secret+ per area. Divine is capped at one unconsumed record server-wide, including carried Divine to prevent later-drop collisions. No pity.

Drops retain GUID and node reservation, are immediately pickable, and expire after 20s. Server validates owner, distance, Power and single carry. Runtime validation detects duplicate/orphan IDs. See the resource spec for reset-boundary ownership details.

## Persistence

- DataStore: `MonsterProgress_v1` via `DataService`
- Fields: Cash, Power, equipped pet, per-species growth/affinities/mutations/rarity and `EvolutionFamilies`, `BaseUpgrades.TrainingLevel`, `DiscoveredAreas`, simple `Stats`; Floral still writes saved `Flora`
- Failed load → session defaults; that session does not overwrite save if load never succeeded (`canSave` false)

No monetization / receipt code in repo today.

## Economy (minimal)

- **Power** — primary player progression gate for carry weight
- **Cash** — slow passive tick from pet multiplier; spends on training upgrade at base only
- No NPC sell loop, material banking, or multi-currency stack

## Explicitly out of scope (removed or not rebuilding)

Main conveyor acquisition, open-world gathering, expedition quests/bags/combat enemies, research tablet, NPC selling as core loop, material banking, weapons/HP combat, heavy inventory, lab/tycoon base management, per-feed/per-area bespoke server scripts.

Conveyor may return later only as an optional **secondary** base convenience—not the main loop (`FEED_A_PET_CONTEXT.md` §13).

## Content pipeline (current phase)

Graybox placeholders only: part-based resources, guardian blocks, pet blob at `CreatureSpawn`, functional HUD. Final pets, props, and UI are expected via Blender MCP and AI UI **after** the Grasslands slice feels correct; code should keep swappable visuals.

All resource ModelKeys have explicit fallback definitions; templates in `ServerStorage.ResourceModels` replace both world and carried models. Secret/Eternal/Divine announcement, aura, beacon and burst hooks are wired. Their `FieldConfig.RarePresentation.SoundId` values remain empty pending valid audio assets. Six future catalysts are reserved/disabled outside launch pools. Family unlocks are saved; final new family species/models are not invented here.

## Open decisions (track in prototyping)

From product context — not settled in code/docs yet:

- Future path length cap beyond the five launch areas
- Whether Speed is trained separately or derived from Power
- Cash’s long-term shop/upgrades beyond training pad
- PvP theft vs contest over world spawns only
- How many owned pets vs one displayed pet
- Evolution UI when multiple branches qualify
- Special catalysts: always deterministic vs sometimes probabilistic
- Global/server event frequency and contest rules

**Resolved:** Game name is **Feed a Pet**; launch is exactly five areas with eight Index resources/five nodes each; drops are instantly contestable with a 20s expiry; rarity order and weights are explicit. Configured assumptions are 5% Mutant Leech mutation roll and equal hybrid affinity split.

## Agent workflow

Before large changes: read `FEED_A_PET_CONTEXT.md`, inspect `src/`, trace requires/remotes, prefer deleting dead architecture over layering. After substantial edits: run Play + `[MonsterLoopTest] PASS` in output, fix broken requires and dangling Studio instances after sync.
