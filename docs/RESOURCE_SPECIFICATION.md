# Feed a Pet: authoritative resource and field specification

Updated 2026-10-10. This specification supersedes older example resource tables and spawn assumptions in the product context. The Phase 2 request explicitly places resetting in the final ten seconds of each 300-second period; that timing supersedes the older reset-at-300/finish-at-310 description. Resource values are unchanged. The game is **Feed a Pet**; legacy filesystem/Studio/module names do not change that identity.

## Rarities and configuration

Exactly: Common → Uncommon → Rare → Epic → Legendary → Mythic → Cosmic → Secret → Eternal → Divine.

`RarityDefinitions` owns order/identity; `RarityStyles` owns configurable presentation. Rarity never determines spawn probability. `ResourceDefinitions` owns resource values; `AreaDefinitions.ResourcePool` references explicit weights. `FeedDefinitions` and `CatalystDefinitions` are compatibility views, not separate sources of truth.

Every resource defines Id, DisplayName, ResourceType, Rarity, Area, Growth, Affinity, PowerRequired, SpawnWeight, CarrySlowdown, SpecialEffect, ModelKey and BillboardOffset. ModelKey equals Id; default offset is `(0, 0.8, 0)` above model bounds. SpecialEffect defaults to `None`. All following rows have `Launch = true` and positive weight. Each area has exactly eight Index resources and total weight **100**.

## Launch resource tables

Slowdown is fractional: carried speed = `16 * (1 - CarrySlowdown)`. Names below are DisplayName; IDs remove spaces.

### Grasslands — T-Rex

| Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Effect |
|---|---|---|---|---:|---:|---:|---:|---|
| Raw Meat | Feed | Common | Flesh | 5 | 0 | 34 | 0 | None |
| Berries | Feed | Common | Floral | 6 | 0 | 24 | 0 | None |
| Bone Chunk | Feed | Uncommon | Mineral | 8 | 50 | 17 | 0 | None |
| Prime Meat | Feed | Rare | Flesh | 12 | 120 | 10 | 0.02 | None |
| Wild Herbs | Feed | Rare | Floral | 12 | 200 | 7 | 0.02 | None |
| Giant Rib | Feed | Epic | Flesh | 18 | 350 | 4.5 | 0.05 | None |
| Ancient Bone | Feed | Epic | Mineral | 18 | 500 | 2.5 | 0.08 | None |
| Primal Catalyst | Catalyst | Legendary | Neutral | 30 | 1000 | 1 | 0.10 | Primal |

### Swamp — Giant Crocodile

| Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Effect |
|---|---|---|---|---:|---:|---:|---:|---|
| Small Fish | Feed | Uncommon | Flesh | 22 | 1500 | 32 | 0.05 | None |
| Rotten Meat | Feed | Rare | Flesh | 28 | 2200 | 23 | 0.05 | None |
| Spore Pod | Feed | Rare | Floral | 30 | 3000 | 17 | 0.06 | None |
| Swamp Mushroom | Feed | Epic | Floral | 38 | 4500 | 11 | 0.08 | None |
| Venom Sac | Feed | Epic | Flesh | 45 | 6500 | 8 | 0.10 | Toxin |
| Bog Marrow | Feed | Legendary | Flesh + Mineral | 55 | 9000 | 5 | 0.12 | None |
| Mutant Leech | Feed | Mythic | Neutral | 70 | 14000 | 3 | 0.14 | MutationRoll |
| Toxic Catalyst | Catalyst | Cosmic | Neutral | 100 | 25000 | 1 | 0.18 | Toxic |

### Jungle — Giant Gorilla

| Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Effect |
|---|---|---|---|---:|---:|---:|---:|---|
| Wild Fruit | Feed | Rare | Floral | 75 | 25000 | 30 | 0.08 | None |
| Giant Beetle | Feed | Rare | Flesh | 80 | 35000 | 23 | 0.08 | None |
| Rare Flower | Feed | Epic | Floral | 95 | 50000 | 18 | 0.10 | None |
| Protein Root | Feed | Legendary | Flesh + Floral | 110 | 75000 | 12 | 0.12 | None |
| Golden Banana | Feed | Legendary | Floral | 125 | 100000 | 8 | 0.13 | None |
| Royal Jelly | Feed | Mythic | Neutral | 150 | 150000 | 5 | 0.15 | None |
| Beast Heart | Feed | Mythic | Flesh | 180 | 225000 | 3 | 0.18 | None |
| Jungle Heart | Catalyst | Secret | Neutral | 250 | 350000 | 1 | 0.22 | Beast |

### CrystalCave — Armored Triceratops

| Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Effect |
|---|---|---|---|---:|---:|---:|---:|---|
| Crystal Shard | Feed | Rare | Mineral | 250 | 350000 | 29 | 0.10 | None |
| Fossil Marrow | Feed | Epic | Flesh + Mineral | 300 | 500000 | 23 | 0.12 | None |
| Mineral Core | Feed | Legendary | Mineral | 375 | 750000 | 18 | 0.15 | None |
| Living Geode | Feed | Legendary | Mineral | 450 | 1000000 | 13 | 0.18 | None |
| Prismatic Crystal | Feed | Mythic | Mineral | 550 | 1500000 | 9 | 0.20 | None |
| Fossil Heart | Feed | Cosmic | Flesh + Mineral | 700 | 2500000 | 5 | 0.24 | None |
| Crystal Core | Feed | Cosmic | Mineral | 850 | 4000000 | 2.5 | 0.28 | None |
| Crystal Catalyst | Catalyst | Secret | Neutral | 1200 | 6000000 | 0.5 | 0.32 | Crystal |

### Volcano — Dragon

| Resource | Type | Rarity | Affinity | Growth | Power | Weight | Slowdown | Effect |
|---|---|---|---|---:|---:|---:|---:|---|
| Charred Meat | Feed | Epic | Flesh | 1000 | 6000000 | 37.51 | 0.18 | None |
| Magma Stone | Feed | Legendary | Mineral | 1200 | 8000000 | 26.27 | 0.20 | None |
| Ember Heart | Feed | Legendary | Flesh | 1500 | 12000000 | 16.83 | 0.22 | None |
| Dragon Scale | Feed | Mythic | Mineral | 1800 | 18000000 | 13.96 | 0.25 | None |
| Dragon Meat | Feed | Cosmic | Flesh | 2400 | 30000000 | 4.36 | 0.30 | None |
| Fire Core | Catalyst | Secret | Neutral | 3200 | 50000000 | 0.74 | 0.35 | Fire |
| Dragon Blood | Catalyst | Eternal | Neutral | 4500 | 80000000 | 0.31 | 0.40 | Draconic |
| Inferno Catalyst | Catalyst | Divine | Neutral | 7000 | 150000000 | 0.02 | 0.50 | Inferno |

## Server-wide field lifecycle

Each launch area reads exactly five saved BasePart markers at `Workspace.ExpeditionZones.<Area>.ResourceNodes.Node01`–`Node05`, with unique `NodeId = <Area>:NodeXX` and matching AreaId. `tools/SetupResourceNodes.luau` is an idempotent edit-time setup utility; it preserves existing markers. AncientRuins remains scene content, not a launch pool. Runtime objects live in `Workspace.GeneratedGameplay.Resources`.

`FieldState` is a deterministic engine with injected time, random tickets and ID generation. `ResourceService` owns server GUID records, node ownership and authorized transactions; `SpawnService` owns physical objects, pickup distance checks and replication. Players do not get independent rolls. The field fills all 25 nodes on startup and uses one server epoch (not a cross-server global event). Each 300-second period has 290 normal seconds and ten resetting seconds: first reset starts at epoch+290, finishes at epoch+300, next starts at epoch+590. Deadlines derive from the epoch/period, not the arrival time of a delayed scheduler tick. Late ticks reconcile the current period without accumulating drift.

At hard reset: publish Reset, cancel pending node deadlines, remove all uncarried records/objects, invalidate guardian hazard callbacks and clear disturbance, transition to night for ten seconds, then batch-roll/refill all 25 nodes, announce chase items and resume Normal. `ReplicatedStorage.WorldFieldState` publishes Epoch, Phase, Cycle, NextResetAt and ResetEndsAt. A top-center client countdown reads server time: `RESOURCES RESET IN 4:32`, switching to `RESOURCES RESETTING...` during Reset. Clients change lighting/announcements only. Pickup reconciles the deadline before accepting an interaction between scheduler ticks.

Node timers start on **consumption/destruction**, not initial pickup. Carried/dropped items reserve their node until released. Eligible respawn delays depend on the removed resource: Common–Rare 18 seconds; Epic–Legendary 25 seconds; Mythic/Cosmic 40 seconds. Secret/Eternal/Divine have no mid-cycle refill. Mid-cycle rolls exclude those three and renormalize the remaining explicit weights. Pool tickets use hundredths of a weight: each launch pool has exactly 10,000 tickets, including Volcano's 0.02 entry.

One reset batch may create at most one Secret+ per area: retain the highest rarity among five initial draws and reroll other chase hits below Secret. The server allows at most one unconsumed Divine record from normal spawning. **Carried Divine reserves this cap too**, so a later drop cannot collide with a newer Divine. No pity system.

## Carry/drop ownership

Each item has one GUID across AVAILABLE → CARRIED → DROPPED, ending in CONSUMED or DESTROYED. Terminal state is set before the record leaves the active map; no unbounded tombstone table is kept. Repeated pickup/drop/release calls cannot clone it. World representation is removed before the carried representation is created; failed attachment rolls back to one world model. Runtime validation includes carried models as well as world models. Dropped objects are immediately contestable by another player, expire after exactly 20 seconds if not reclaimed, and keep their node reserved until expiry/consumption. Claiming a drop suspends its expiry while carried; dropping again sets a fresh 20-second deadline. Server distance, live character, single carry, Power, owner, area and resource checks gate transitions.

Hard reset preserves carried records, but detaches their old node reservation. The fresh node receives a new GUID; consuming/dropping the old carried item cannot free that fresh record. An old-cycle dropped item remains detached from the newly populated node. This is intentional to preserve both carried loot and the mandatory five fresh rolls per area.

## Affinity, effects and saves

Flesh/Floral/Mineral add affinity equal to Growth. Neutral adds growth without normal affinity. Hybrid resources split their total affinity gain evenly between the two affinities; they do not double it. Phase 4A explicitly requires deterministic integer remainder handling: the first listed affinity receives the odd point (Bog Marrow +28 Flesh / +27 Mineral). Existing fractional saved totals are retained. Floral writes the existing saved `Flora` field, avoiding a save-key migration.

`SpecialEffectDefinitions` and `ResourceEffects` apply persisted EvolutionFamilies flags. Primal, Crystal, Fire, Draconic and Inferno unlock/check their families; Toxic also unlocks Mutant; Beast also unlocks Alpha. Toxin adds its progression flag. **Configured implementation assumption:** Mutant Leech has a 5% roll for the existing Mutant mutation, with no duplicate entries. Existing supported evolution branches consume family compatibility; this task does not invent final species/models for every new family. Existing legacy catalyst-ID checks remain compatible.

Future-only entries: GiantSerum/Titan, SpiritEnergy/Spirit, CyberCore/Cyber, VoidEssence/Void, BloodMoonShard/BloodMoon, CelestialCore/Celestial. All are `Launch = false`, weight 0, absent from launch pools. Zero explicitly disables future content; it is not a placeholder launch probability. Their progression/rarity values must be balanced before enabling event pools.

## Presentation and asset slots

All world and carried resources receive shared client BillboardGui labels: display name, growth or effect, optional modifier/status. No automatic rarity word. Secret+ distances are 300/450/600 studs, subject to visibility/animation budgets and occlusion. Cosmic/Secret/Eternal/Divine styles extend the existing palette and animated gradients.

`ResourceModelDefinitions` explicitly declares graybox fallback coverage for every ModelKey. Add matching Model/BasePart templates in `ServerStorage.ResourceModels` to replace fallbacks for both world and carried visuals. Source templates are cloned; embedded scripts/prompts/old billboards are stripped. Final models are not supplied by this task.

Secret: compact 360px announcement and aura; Eternal: larger 500px announcement, aura and 120-stud beacon; Divine: major 640px area/item announcement, 180-stud beacon, radial 24-particle burst and special tag animation. Divine preempts lower-priority announcements/sounds. `FieldConfig.RarePresentation` configures priority, size, duration, intensity, labels, distances, SoundId and volume. `FieldPresentation.RareSpawned` / `SoundRequested` expose client hooks (sound includes priority). The announcement queue, recent-ID deduplication and active-sound list are bounded; Stop clears connections/UI/tweens/sounds and restores lighting. **SoundIds intentionally remain empty until valid audio assets are assigned**; volumes rise 0.5 → 0.7 → 1. Drops do not repeat the arrival announcement/burst.

## Validation and tests

Startup config/world validation rejects bad launch counts, duplicate IDs, invalid rarity/type/affinity/effect/model coverage, nonpositive launch weights, incorrect totals, negative Growth/Power, malformed slowdown, and missing/duplicate node markers. Runtime `SpawnService.validate()` detects node/record ownership violations and duplicate/orphan physical world IDs.

Build: `rojo build default.project.json -o <temporary-path>.rbxlx`.

In Studio **Play server**, enable the disabled `ServerScriptService.UnitTestRunner` once, or invoke `require(game.ServerStorage.UnitTest.RunUnitTest)(nil,20)`. The 114 cases cover all 40 exact resource rows, exhaustive weighted ticket counts, one million seeded random rolls, 1,000 reset/interaction orderings, chase limits, reset/drop/respawn ownership, family effects, malformed config/nodes, cross-definition validation and save lifecycle safety. They use injected time/randomness/storage and no production DataStores. Disable the runner after testing.

Opt-in live tests (temporary Script/LocalScript; stop Play to remove fixtures):

- `tests/FieldIntegration.server.luau`: real pickup/Power/drop rejection, a complete 300-second period with the final ten seconds resetting, boundary interaction rejection and carry preservation. Check count is 19 or 20 depending on whether the regular scheduler or the test's boundary request enters Reset first; both paths must reject reset pickups.
- `tests/FieldRuntimeSmoke.server.luau`: 14 checks of carried model/welds/slowdown, actual 20-second expiry and eligible node refill, external destruction and runtime uniqueness.
- `tests/BillboardSmoke.client.luau`: 88 assertions for all ten visual tiers, labels, MaxDistance, visibility, updates, budgets, direct Destroy watcher cleanup and zero owned connections after Stop; set Cleanup=true afterwards.
- `tests/FieldPresentationSmoke.client.luau`: 17 client checks; under PlayerScripts, wait for Ready=true, then send Secret, wait four seconds, send Eternal, wait 0.6 seconds, send Divine through the server `FieldRareSpawn` RemoteEvent (20s test deadline). Each fixture needs a distinct InstanceId plus DisplayName/AreaName. Checks escalating sizes, Divine preemption/priority hooks, countdown, night/restoration and Stop/Start cleanup. This does not alter weighted production probabilities.
- `tests/Phase1Integration.server.luau`: 31 real-service checks of save isolation, base/transaction guards, replay rejection, owned-pet preservation and character reset. Restores the test player's session data afterward.
- `tests/Phase1Lifecycle.server.luau` with `tests/Phase1Network.client.luau`: paired Studio-only lifecycle/network fixture. Install the LocalScript through the client DataModel's PlayerScripts (not the server), and the Script under ServerScriptService. The server waits for FieldIntegration when present, then tests client drop spam, death and cleanup. It intentionally kicks the Studio test player at the end; do not run during a user playthrough or against production. Stop Play to clear fixtures.

`tests/MonsterLoopTest.server.luau` remains an opt-in smoke test, excluded from production startup. `tests/Phase1Integration.server.luau` exercises real server transaction guards and character cleanup. `DataService` now uses an isolated read-only Studio session without requesting production DataStores; API-disabled load warnings are no longer expected. See `PHASE1_RESULTS.md` for current verification and limitations.
