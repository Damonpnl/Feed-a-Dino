# Current State

Last updated: 2026-10-23

**Product:** [Feed a Pet](FEED_A_PET_MASTER_CONTEXT.md) — compact steal → escape → feed → evolve loop on a long, narrow path. Use the master context for overarching intent and `RESOURCE_SPECIFICATION.md` for finalized resource mechanics. Current resource-system verification is recorded in [PHASE2_RESULTS.md](PHASE2_RESULTS.md); [PHASE1_RESULTS.md](PHASE1_RESULTS.md) retains the architecture audit and purchase-infrastructure limitations.

**Repo note:** Rojo project name and some module IDs (for example `MonsterService`, `MonsterDefinitions`) are legacy; new player-facing copy and docs should say **pet**, not rebuild old “Feed a Dino” conveyor/simulation identity.

**Resource authority:** [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md) owns the exact 40 launch resources, ten-rarity order, five-area pools and synchronized field rules. Older example tables are superseded.

**Phase 3:** Carry/guardian implementation and verification are recorded in [PHASE3_RESULTS.md](PHASE3_RESULTS.md). Phase 3B immediate wake, full-runway pursuit to the safe-zone boundary, and rarity carry curses are in [PHASE3B_RESULTS.md](PHASE3B_RESULTS.md). That file also covers the 2026-10-14 two-client race pass and its two `GuardianService` fixes. Phase 4 feeding/evolution interfaces were not modified. Phase 3B was merged with Phase 4C on 2026-10-15 and the combined tree was retested; see "Integration with Phase 4C" in PHASE3B_RESULTS.md.

**Phase 4A:** Server-authoritative preview/confirmation and persistent current/cumulative Growth are implemented in the existing feeding/save services. See [PHASE4A_REPORT.md](PHASE4A_REPORT.md) for historical test evidence. **Studio testing update (2026-10-15):** ordinary Play now uses writable, temporary `StudioMemory` sessions through the existing SessionStore. Gameplay works without a fixture; data resets when Play stops. Production DataStore access remains prohibited in Studio. Published-server failure/conflict guards are unchanged. See [STUDIO_MEMORY_FEEDING_FIX.md](STUDIO_MEMORY_FEEDING_FIX.md).

**Phase 4B:** Supersedes the prototype evolution policy above with a data-driven Stage 0–5 framework (5 locked), one-stage transitions, Growth reserve, primary/hybrid branches and persistent choices. Owned keys/PetId remain stable while EvolutionForm changes; duplicate forms cannot overwrite another pet. See [PHASE4B_REPORT.md](PHASE4B_REPORT.md) for verification status, provisional thresholds, migration policy and 4C handoff. No full catalyst/rarity/Awakening system is added.

## North-star loops

**Guardian feed return (2026-10-23):** guardian body catches and attack hits now send
the carried feed back to its original radial spawn position, retaining its GUID and
curse. It stays collectible under the existing dropped-resource lifetime. Manual/death
drops and reset forfeiture are unchanged. See `GUARDIAN_RETURN_RESULTS.json` for the
targeted Studio verification; earlier phase reports describe the old hit-location drop.

**Fast-heist tuning (IMPLEMENTED / BALANCE PROVISIONAL):** the user's approved tuning pass supersedes the
historical Phase 5B speed/carry-cap balance below. Current provisional unloaded
milestones span 22–72; carrying bases span 22–52 before unchanged weight/curse penalties.
Slow Mode remains 16. Fixed biome pursuit baselines, bounded predictive hazards and
short post-attack recovery are under evaluation, not final balance. The approved
reset policy now forfeits carried GUIDs only for players inside the authoritative
field boundary, evacuates them to their own bases, and closes five runtime gates for
the existing ten-second reset window. Safe-side carriers keep their items.
See [FAST_HEIST_TUNING_REPORT.md](FAST_HEIST_TUNING_REPORT.md) for executed evidence,
failed/intermediate trials and outstanding checks. Do not infer release readiness
from the older phase reports. No Phase 6, economy or resource-value changes.
Latest evidence: 403 unit cases passed; full real-Humanoid travel passed (ordinary
round trips ~38/61/76/85/93 seconds); two-client reset/crowded-spawn/race coverage
passed 78 checks and independent multiplayer movement passed 20. The final Phase 1–5B
regression queue passed; actual late-join reset coverage passed 13 checks. Client-owned
keyboard physics and replicated reset warnings passed, including landscape phone-sized
warning verification. All 120 mapped sources match Studio; temporary test runners were
removed and Studio returned to Edit/default viewport. Entry-Power dodge routes still
often end in subsequent body catches, whereas 150M ordinary routes escape without
attacks. Human fairness/touch testing and balance approval remain pending.

**Phase 5A:** Server-ticked active-pet Cash, timed base training, ten Cash-purchased trainer tiers and native grayboxes/UI are implemented. See [PHASE5A_REPORT.md](PHASE5A_REPORT.md) for 369 passing unit tests, real Studio integration/UI/two-client evidence, provisional prices and retained legacy TrainingLevel floor. TrainerTier is additive; StudioMemory and production save guards remain unchanged. Earlier-phase regression suites passed; cloud persistence and full mobile QA remain untested.

**Phase 5B:** Power-derived movement and persistent Slow Mode are implemented and verified in the existing CarryService authority; see [PHASE5B_REPORT.md](PHASE5B_REPORT.md). Evidence includes 388 passing unit cases, real progression/UI and two-client tests, all-biome travel/chase measurements and earlier-phase regressions. The user chose fast unloaded travel with a separate carrying cap: provisional milestones 16–32, carrying-base cap 18 before existing resource/curse penalties, precision speed 16. Final balance still needs approval: long loaded returns and CrystalCave difficulty remain concerns. Guardian tuning and resource requirements are unchanged. Real network/cloud rejoin and physical-mobile QA remain untested. Phase 6 is not started.

**Phase 4D:** Independent pet rarity resolution, disabled Ascension/Awakening eligibility and centralized income/training metadata extend the existing evolution transaction. All live rarity rules retain the current rarity; prestige remains disabled pending approved requirements. See [PHASE4D_REPORT.md](PHASE4D_REPORT.md) for verification, additive save fields and Phase 5 handoff. No economy values are changed.

**Phase 4C:** Catalyst compatibility, persisted latent/family unlocks, provisional special branches and retry-stable mutation tickets extend the existing feed transaction. See [PHASE4C_REPORT.md](PHASE4C_REPORT.md) for exact active/disabled content and verification. Only the retained 5% Mutant Leech roll is active; Stage 5 and Awakening remain locked/unimplemented. Phase 3B is now merged into this branch, its unit tests are back in active discovery, and Rojo serves the combined tree on port 34872 only.

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
| Runtime gameplay instances | Created at play: `Workspace.GeneratedGameplay` (resources, guardians, pet placeholders); one `TrainingStation` beneath each base's `NewBase` |

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
| Client | `UIController`, `CarryController` (G to drop, V/native button for Slow Mode), `EffectsController`, `BillboardController`/`BillboardService` (world labels), `FieldController`/`FieldPresentation` (existing field presentation); native ProximityPrompts handle interaction input |

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
| Power training | `TrainingService`: one-second active training at owned station; Cash purchases sequential TrainerTier upgrades |
| Heavier loot after Power | e.g. Bone Chunk (`PowerRequired` 50), Giant Rib (`PowerRequired` 350) |

**Success condition (playtest):** New player can spawn, steal an item, survive a guardian telegraph, feed at base, evolve once, train Power, then carry something they could not carry at spawn (heavier/rarer pickup).

**Previous resource implementation validation (2026-10-09):** 84 deterministic unit cases, 18 real-cycle integration checks, 14 live resource checks and 85 client billboard assertions passed. These historical results are not a substitute for verifying the Phase 1 refactor. Current runs and limitations are listed in `PHASE1_RESULTS.md`. Tests do not replace a fresh-player balance/fun playthrough or a two-human multiplayer session. `MonsterLoopTest` is now opt-in under `tests/`, never automatic production startup.

## Synchronized field

Current Phase 2 rare presentation passes 17 client checks for announcement sizing, priority sound hooks, countdown, night lighting/restoration and Stop/Start cleanup. Nine additional VFX checks confirm Secret/Eternal/Divine aura/beacon/burst components. Fixture notifications were explicit tests, not changes to production spawn odds.

One server-wide field fills 25 nodes. Each 300-second period has 290 normal seconds and ten resetting seconds (first transition starts at server epoch+290, refill at +300). Clear uncarried items, cancel refill timers, reset guardian/hazard callbacks, show the top-center reset message/night hook, then refill. The approved fast-heist policy supersedes unconditional carry preservation: inside carriers forfeit their authoritative GUID before evacuation; safe-side carried loot survives and detaches its old node reservation. Explicit resource states remain AVAILABLE, CARRIED, DROPPED, CONSUMED and DESTROYED. `PHASE2_RESULTS.md` records historical spawning verification; the fast-heist report owns current lockdown verification.

Consumption/destruction schedules a refill: Common–Rare 18s, Epic–Legendary 25s, Mythic/Cosmic 40s; chase items never refill mid-cycle. Mid-cycle rolls renormalize eligible weights below Secret. Hard-reset batches keep only their highest Secret+ per area. Divine is capped at one unconsumed record server-wide, including carried Divine to prevent later-drop collisions. No pity.

Drops retain GUID and node reservation, are immediately pickable, and expire after 20s. Server validates owner, distance, Power and single carry. Runtime validation detects duplicate/orphan IDs. See the resource spec for reset-boundary ownership details.

## Persistence

- DataStore: `MonsterProgress_v1` via `DataService`
- Fields: Cash, Power, TrainerTier, SlowMode (additive boolean, default false), equipped owned-pet key, Growth/TotalGrowth/Revision/affinities/mutations/rarity and `EvolutionFamilies`, Stage/EvolutionHistory, additive EvolutionForm/EvolutionVersion/GrowthReserve/Lineage/LineageTags/PendingEvolution, `BaseUpgrades.TrainingLevel`, `DiscoveredAreas`, simple `Stats`; Floral still writes saved `Flora`. Legacy species-named ownership keys remain stable even after the current form changes.
- Keys remain `u_<UserId>`; no reset or store rename. Missing TrainerTier defaults to free tier 1; paid legacy TrainingLevel remains a nonstacking gain floor, not a tier conversion.
- Failed/malformed load → read-only fallback; successful nil → writable missing/new save. Concurrent loads share one request lifecycle.
- Serialized `UpdateAsync` uses full-record optimistic conflict checks; conflicting sessions become read-only. Unknown inventory/receipt/entitlement fields and key metadata are preserved.
- Studio performs no production DataStore reads or writes, regardless of API-access settings. Session tests use injected fake stores.
- Drain old servers before deploying: older `SetAsync` writers cannot participate in the new conflict protocol. A live two-server/cloud test has not been performed.

No legitimate receipt/gamepass pipeline was found in the repository or active place. An unused SoilBag template's external asset-purchase script is disabled and backed up; its asset ID/model are retained. End-to-end purchase/entitlement behavior cannot be certified without the intended pipeline and a safe test environment.

## Economy (Phase 5A)

- **Power** — primary player progression gate for carry weight
- **Cash** — 0.5 × active-pet income multiplier per second, writable sessions only; buys next trainer tier at own base
- **Training** — 5 × trainer multiplier × pet training multiplier per one-second active tick; legacy paid TrainingLevel remains a nonstacking minimum gain
- **TrainerTier** — additive persisted 1–10, first tier free; centralized provisional Cash prices and native graybox station upgrades
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
- Final Power-to-Speed milestones and carrying cap (Power-derived architecture selected in Phase 5B)
- Cash’s long-term shop/upgrades beyond training pad
- PvP theft vs contest over world spawns only
- How many owned pets vs one displayed pet
- Final styling for evolution UI (functional persistent choices implemented in 4B)
- Special catalysts: always deterministic vs sometimes probabilistic
- Global/server event frequency and contest rules

**Resolved:** Game name is **Feed a Pet**; launch is exactly five areas with eight Index resources/five nodes each; drops are instantly contestable with a 20s expiry; rarity order and weights are explicit. Configured assumptions are 5% Mutant Leech mutation roll and equal hybrid affinity split.

## Agent workflow

Before large changes: read `FEED_A_PET_MASTER_CONTEXT.md` and the finalized resource specification, inspect `src/`, trace requires/remotes, and preserve saves/purchases. Run appropriate opt-in tests, inspect both Play consoles, and check for duplicate or dangling Studio instances after sync. Current Phase 3B guardians pursue after theft; see gameplay tuning/radial reports. Phase 5A enables the requested trainer ladder using explicitly provisional prices, retaining paid legacy TrainingLevel benefits and pet IDs. Do not infer later phases are authorized.
