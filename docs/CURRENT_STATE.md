# Current State

Last updated: 2026-10-15

**Product:** [Feed a Pet](FEED_A_PET_MASTER_CONTEXT.md) — compact steal → escape → feed → evolve loop on a long, narrow path. Use the master context for overarching intent and `RESOURCE_SPECIFICATION.md` for finalized resource mechanics. Current resource-system verification is recorded in [PHASE2_RESULTS.md](PHASE2_RESULTS.md); [PHASE1_RESULTS.md](PHASE1_RESULTS.md) retains the architecture audit and purchase-infrastructure limitations.

**Repo note:** Rojo project name and some module IDs (for example `MonsterService`, `MonsterDefinitions`) are legacy; new player-facing copy and docs should say **pet**, not rebuild old “Feed a Dino” conveyor/simulation identity.

**Resource authority:** [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md) owns the exact 40 launch resources, ten-rarity order, five-area pools and synchronized field rules. Older example tables are superseded.

**Phase 3:** Carry/guardian implementation and verification are recorded in [PHASE3_RESULTS.md](PHASE3_RESULTS.md), with temporary encounter tuning and lifecycle contracts in [PHASE3_GAMEPLAY.md](PHASE3_GAMEPLAY.md). All 17 Phase 3 criteria passed, including an actual two-client Studio test.

**Phase 4A:** Server-authoritative preview/confirmation and persistent current/cumulative Growth are implemented in the existing feeding/save services. See [PHASE4A_REPORT.md](PHASE4A_REPORT.md) for test evidence and outstanding checks. Existing prototype evolution/family/Leech behavior is preserved; no new stages, graphs or Phase 4B mechanics. Ordinary Studio sessions remain read-only, so feeding tests use explicitly injected in-memory sessions, never production saves.

**Phase 4B:** Supersedes the prototype evolution policy above with a data-driven Stage 0–5 framework (5 locked), one-stage transitions, Growth reserve, primary/hybrid branches and persistent choices. Owned keys/PetId remain stable while EvolutionForm changes; duplicate forms cannot overwrite another pet. See [PHASE4B_REPORT.md](PHASE4B_REPORT.md) for verification status, provisional thresholds, migration policy and 4C handoff. No full catalyst/rarity/Awakening system is added.

## North-star loops

**Phase 4C:** Catalyst compatibility, persisted latent/family unlocks, provisional special branches and retry-stable mutation tickets extend the existing feed transaction. See [PHASE4C_REPORT.md](PHASE4C_REPORT.md) for exact active/disabled content and verification. Only the retained 5% Mutant Leech roll is active; Stage 5 and Awakening remain locked/unimplemented. Phase 3B tests are archived outside active discovery and its gameplay remains isolated on Rojo port 34873; Phase 4 uses 34872.

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
| Shared definitions | `FeedDefinitions`, `CatalystDefinitions`, `MonsterDefinitions`, `AreaDefinitions`, `RarityDefinitions`, `TrainerDefinitions`, `BillboardConfig`; `DefinitionValidation` validates cross-references; `ResourceDefinitions` is the sole resource value table |
| Server services | `DataService` + injected `SessionStore`, `BaseService`, `ResourceService`, `CarryService`, `SpawnService`, `GuardianService`, `FeedService`, `MonsterService`, `TrainingService`, `InteractionGuard`, `ZoneGeometry`; sole bootstrap `GameBootstrap.server.luau` |
| Client | `UIController`, `CarryController` (G to drop), `EffectsController`, `BillboardController`/`BillboardService` (world labels), `FieldController`/`FieldPresentation` (existing field presentation); native ProximityPrompts handle interaction input |

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
| Evolution | `EvolutionCalculator` — deterministic eligible branches, persistent choices, overflow and one-stage transitions; see 4B report |
| Training multiplier | Equipped pet `BaseMultiplier` scales Power gain |
| Power training | `TrainingService` pad at base; Cash upgrades training level |
| Heavier loot after Power | e.g. Bone Chunk (`PowerRequired` 50), Giant Rib (`PowerRequired` 350) |

**Success condition (playtest):** New player can spawn, steal an item, survive a guardian telegraph, feed at base, evolve once, train Power, then carry something they could not carry at spawn (heavier/rarer pickup).

**Previous resource implementation validation (2026-10-09):** 84 deterministic unit cases, 18 real-cycle integration checks, 14 live resource checks and 85 client billboard assertions passed. These historical results are not a substitute for verifying the Phase 1 refactor. Current runs and limitations are listed in `PHASE1_RESULTS.md`. Tests do not replace a fresh-player balance/fun playthrough or a two-human multiplayer session. `MonsterLoopTest` is now opt-in under `tests/`, never automatic production startup.

## Synchronized field

Current Phase 2 rare presentation passes 17 client checks for announcement sizing, priority sound hooks, countdown, night lighting/restoration and Stop/Start cleanup. Nine additional VFX checks confirm Secret/Eternal/Divine aura/beacon/burst components. Fixture notifications were explicit tests, not changes to production spawn odds.

One server-wide field fills 25 nodes. Per the Phase 2 request, each 300-second period has 290 normal seconds and ten resetting seconds (first transition starts at server epoch+290, refill at +300). Clear uncarried items, cancel refill timers, reset disturbance/hazard callbacks, show the top-center reset message/night hook, then refill. Carried loot survives; its old node reservation detaches so it cannot steal a fresh node's ownership. Explicit resource states are AVAILABLE, CARRIED, DROPPED, CONSUMED and DESTROYED. See `PHASE2_RESULTS.md` for current verification; Phase 1 results remain a historical snapshot.

Consumption/destruction schedules a refill: Common–Rare 18s, Epic–Legendary 25s, Mythic/Cosmic 40s; chase items never refill mid-cycle. Mid-cycle rolls renormalize eligible weights below Secret. Hard-reset batches keep only their highest Secret+ per area. Divine is capped at one unconsumed record server-wide, including carried Divine to prevent later-drop collisions. No pity.

Drops retain GUID and node reservation, are immediately pickable, and expire after 20s. Server validates owner, distance, Power and single carry. Runtime validation detects duplicate/orphan IDs. See the resource spec for reset-boundary ownership details.

## Persistence

- DataStore: `MonsterProgress_v1` via `DataService`
- Fields: Cash, Power, equipped owned-pet key, Growth/TotalGrowth/Revision/affinities/mutations/rarity and `EvolutionFamilies`, Stage/EvolutionHistory, additive EvolutionForm/EvolutionVersion/GrowthReserve/Lineage/LineageTags/PendingEvolution, `BaseUpgrades.TrainingLevel`, `DiscoveredAreas`, simple `Stats`; Floral still writes saved `Flora`. Legacy species-named ownership keys remain stable even after the current form changes.
- Keys remain `u_<UserId>`; no reset, store rename or economy migration.
- Failed/malformed load → read-only fallback; successful nil → writable missing/new save. Concurrent loads share one request lifecycle.
- Serialized `UpdateAsync` uses full-record optimistic conflict checks; conflicting sessions become read-only. Unknown inventory/receipt/entitlement fields and key metadata are preserved.
- Studio performs no production DataStore reads or writes, regardless of API-access settings. Session tests use injected fake stores.
- Drain old servers before deploying: older `SetAsync` writers cannot participate in the new conflict protocol. A live two-server/cloud test has not been performed.

No legitimate receipt/gamepass pipeline was found in the repository or active place. An unused SoilBag template's external asset-purchase script is disabled and backed up; its asset ID/model are retained. End-to-end purchase/entitlement behavior cannot be certified without the intended pipeline and a safe test environment.

## Economy (minimal)

- **Power** — primary player progression gate for carry weight
- **Cash** — slow passive tick from pet multiplier; spends on training upgrade at base only
- No NPC sell loop, material banking, or multi-currency stack

## Explicitly out of scope (removed or not rebuilding)

Main conveyor acquisition, open-world gathering, expedition quests/bags/combat enemies, research tablet, NPC selling as core loop, material banking, weapons/HP combat, heavy inventory, lab/tycoon base management, per-feed/per-area bespoke server scripts.

Conveyor may return later only as an explicitly scoped **secondary** convenience—not the main loop.

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
- Final styling for evolution UI (functional persistent choices implemented in 4B)
- Special catalysts: always deterministic vs sometimes probabilistic
- Global/server event frequency and contest rules

**Resolved:** Game name is **Feed a Pet**; launch is exactly five areas with eight Index resources/five nodes each; drops are instantly contestable with a 20s expiry; rarity order and weights are explicit. Configured assumptions are 5% Mutant Leech mutation roll and equal hybrid affinity split.

## Agent workflow

Before large changes: read `FEED_A_PET_MASTER_CONTEXT.md` and the finalized resource specification, inspect `src/`, trace requires/remotes, and preserve saves/purchases. Run appropriate opt-in tests, inspect both Play consoles, and check for duplicate or dangling Studio instances after sync. Phase 3 replaces the old prototype guardian rules with rarity disturbance, threshold 100 and five telegraphed hazards. Existing trainer upgrade math, Cash rates and pet IDs remain preserved. The ten-tier trainer ladder is configured but not purchasable until pricing/ownership/migration rules are approved.
