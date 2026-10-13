# Phase 1 implementation and verification

Date: 2026-10-10. Repository baseline: `eb552c4`. Official Studio MCP target: Feed a Dino, place `104154372052853` (Feed a Pet product). No Phase 2 gameplay or visual polish was added.

**Overall: implementation delivered; 11/12 acceptance criteria passed, one blocked. Phase 1 is not fully certified.** Purchase/entitlement functionality cannot be verified because no legitimate pipeline is present in the inspected repository/place. Missing product choices are preserved as explicit blockers, not fabricated prices or migrations. The final evidence summary is [phase1-verification.json](audit/phase1-verification.json).

## 1. Repository and Studio audit

Read the master project context first, then the finalized resource specification, repository code/tests/configuration and Studio hierarchy. The user's pre-existing replacement of `FEED_A_PET_CONTEXT.md` with `FEED_A_PET_MASTER_CONTEXT.md` is preserved. Core-rule/current-state links now point to the master context.

The dependency-aware inventory, reasons and migration decisions are in [PHASE1_AUDIT.md](PHASE1_AUDIT.md). The source dependency graph is in [phase1-dependencies.json](audit/phase1-dependencies.json): 46 production files, 117 require expressions, zero unresolved expressions and zero dependency cycles. This checks the current static require forms, not arbitrary future dynamic loading.

The old conveyor/open-world/combat/sell/inventory architecture was already absent from the repository baseline. Static shops, NPC artwork, unused templates, PDA shell and the AncientRuins blockout are intentionally retained: scene assets are not proof that a corresponding legacy gameplay system is running. No saves, inventories, purchase IDs, terrain, models or map parts were deleted.

## 2. Kept, refactored and deleted

- **Kept:** all 40 launch resource values, five area pools, ten rarities, existing pure field engine/roller/effects/evolution logic, reusable models/templates, blockout, billboard/UI/field presentation and existing public service names.
- **Refactored:** DataService, PlayerData, GameBootstrap, BaseService, SpawnService, CarryService, FeedService, TrainingService, MonsterService, GuardianService, ResourceValidation and MonsterDefinitions. Localized validation/ownership/persistence changes preserve prototype gameplay and save IDs.
- **Added:** SessionStore, ResourceService, InteractionGuard, TrainerDefinitions, DefinitionValidation; deterministic save/configuration tests and opt-in real-service/network/lifecycle tests.
- **Deleted from repository:** unused `src/shared/TestModule.luau`. Moved `src/server/MonsterLoopTest.server.luau` to `tests/MonsterLoopTest.server.luau`, outside production startup. Existing Rojo roots remain unchanged.
- **Deleted from Studio:** the duplicate Meat leaderstats script `ServerScriptService.PlayerDataService`; unrestricted `FlyScript`; `SprintController`, which overwrote server carry slowdown every frame; and unconsumed-attribute `CarryAnimationHandler`. Removed 16 identical duplicate script/module copies: eleven existing duplicates and five additional new-module duplicates observed during sync. Remaining canonical sources were compared with repository contents.
- **Quarantined, not deleted:** `ServerStorage.ExpeditionTemplates.SoilBag.qPerfectionWeld`, an unused embedded script dynamically prompting purchase of external asset `123823600358195`. Disabled it; retained its template and identifier. It is not a developer-product receipt processor.

Deleted Studio-only sources and the quarantined source are recoverable from [studio-before-phase1.json](audit/studio-before-phase1.json). Repository history contains the removed probe and relocated test. Studio edits affect the open place; no cloud publication was performed.

## 3. Central definitions

| Definition | Authoritative responsibility / validation |
|---|---|
| RarityDefinitions | Existing ten-tier identity/order; validated metadata and style references, separate from probability |
| ResourceDefinitions | One value table for 40 launch resources and disabled future entries; exact rows verified against specification |
| FeedDefinitions / CatalystDefinitions | Filtered views of the same resource objects; no independent resource tables |
| AreaDefinitions | Five stable area IDs, ordered launch pools, eight references each, exact weight totals of 100 |
| MonsterDefinitions | Retained seven stable prototype pet IDs/tree; validated evolution targets, requirements, families and legacy catalyst aliases |
| TrainerDefinitions | Ten specified IDs/themes/multipliers, explicit typed schema; no invented prices. New tiers have Purchasable=false |
| BillboardConfig | Retained rendering configuration; identity, dimensions, intervals, budgets, scale and distance validation |

`ResourceValidation.config/world` and `DefinitionValidation.config` check required fields, types, finite ranges, uniqueness and cross-references. Startup fails visibly on invalid configuration. Runtime `SpawnService.validate()` checks physical records against authoritative ownership. Definition tables are distinct from mutable player/session state.

Unspecified trainer prices, initial ownership and migration from saved TrainingLevel remain blocked. The existing upgrade formula is named `TrainerDefinitions.Legacy` and remains in use, with no reinterpretation of existing saved levels as new tiers.

## 4. Resulting architecture

| Server responsibility | Implementation |
|---|---|
| Safe player loading/saving | DataService API over an injected, testable SessionStore; BaseService is the single player-initialization caller |
| Resource ownership/transactions | ResourceService owns the private FieldState and returns read snapshots; claim/consume/drop/release validate authoritative IDs and ownership |
| Spawn/world representation | SpawnService owns physical objects, distance checks, field publication and existing compatibility APIs |
| Carry and deposit | CarryService owns player carry state/visuals/speed, guarded client drop requests and death/character/disconnect cleanup |
| Guardian encounter | GuardianService retains existing noncombat prototype; depends on ResourceService, not back on SpawnService |
| Pet ownership/progression | MonsterService; evolution cannot overwrite an already-owned target pet |
| Feeding | Existing FeedService stages validated effects, consumes an owned GUID exactly once, then commits progression |
| Training/upgrades | TrainingService checks owned base/station, living player distance, funds and request frequency; computes all costs/gains server-side |
| Bases | BaseService guards initialization, assigns ownership, handles respawn and disconnect cleanup |

`InteractionGuard` centralizes proximity/ownership/rate preconditions, not gameplay economics. Invalid character positions fail proximity checks. Failed world-return operations release their record rather than leaving ghost carried ownership. There is no client-supplied reward, price, rarity, spawn roll or progression amount.

Client roles remain consolidated without rename-only wrappers: BillboardController/BillboardService provide the WorldBillboardController role; CarryController handles drop input; native ProximityPrompts provide interaction input; EffectsController and FieldPresentation render existing effects; UIController renders server attributes. No empty InteractionController or duplicated controller was added.

Only two runtime remotes exist, both traced to active consumers:

| Remote | Direction | Producer → consumer |
|---|---|---|
| Remotes.DropCarried | Client → server | CarryController → CarryService; payload values ignored, server ownership/position used |
| Remotes.FieldRareSpawn | Server → client | SpawnService → FieldPresentation; no reward/economy receiver |

No RemoteFunctions or orphaned remotes from deleted systems were found.

## 5. Persistence and monetization safety

- Same DataStore `MonsterProgress_v1`, same `u_<UserId>` keys; existing Flora, TrainingLevel, pet IDs and progression remain compatible. No reset or destructive schema migration.
- Successful nil reads are **Missing**, not failures. Read exceptions retry, then create **LoadFailed** read-only fallback sessions; malformed stored structures produce **InvalidData** read-only sessions. Neither can overwrite stored data.
- Concurrent loads share one request lifecycle. Saves serialize per session and snapshot data before yielding. UpdateAsync compares the full last-read/saved record; an intervening stored update cancels the stale write and marks the session read-only.
- Unknown inventory, receipt, entitlement and nested owned-pet fields are preserved. Existing key user IDs and metadata are passed through the update callback. Invalid equipped-pet pointers no longer replace an already-owned starter with a fresh record.
- Studio uses isolated read-only defaults and makes **no production DataStore requests**, even if Studio API access is enabled. Mock tests exercise success/failure/conflict paths. No live player data was reset, read or saved during this task.
- The implementation uses the documented UpdateAsync cancel/retry contract; the callback does not yield. [Roblox GlobalDataStore reference](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore)
- This is optimistic conflict protection, not a leased cross-server session lock. Drain older SetAsync-based servers before deployment; a legacy writer cannot participate in the new protocol. Live two-server handoff and cloud-outage behavior remain NOT TESTED.
- No legitimate ProcessReceipt/gamepass/entitlement implementation was found in current source, inspected Studio scripts or the searched Git history. Preserving opaque save fields is tested; an actual purchase flow is **BLOCKED**, not claimed functional. The quarantined external asset-prompt script is not a substitute for receipt infrastructure.

## 6. Tests and observed results

Official Studio MCP was used for hierarchy/source inspection, Play control, server/client execution and console inspection. Server stateful tests ran as normal temporary Scripts so they shared the game's actual ModuleScript state; client tests ran in the client DataModel. Test-only fixture state disappears on stopping Play.

| Verification | Result |
|---|---|
| Rojo build and git diff whitespace check | PASSED; temporary build outside repository, no whitespace errors |
| Unit suite | PASSED: 105/105, zero failures. Includes 15 SessionStore cases, six definition cases and the existing 84 resource cases |
| Exact pools | PASSED: all 40 rows, five pools and all 50,000 weighted tickets covered by deterministic tests |
| Module initialization | PASSED: 37 shared/server and three client modules required successfully; static graph has no cycles |
| Phase1Integration | PASSED: 31 live checks, repeated successfully on final service code; ownership, distance, Power, Cash, rate limiting, replay, snapshots, feeding, owned-pet preservation and character reset |
| FieldRuntimeSmoke | PASSED: 14 live checks, including real 20-second drop expiry, node refill, carry model/weld/slowdown and external destruction |
| MonsterLoopTest | PASSED in current Play session |
| FieldIntegration | PASSED: 18 checks across the actual 300-second reset, ten-second transition and carried record preservation |
| Phase1Lifecycle / Phase1Network | PASSED: 14 checks; 40 forged/replayed client drop requests, same-GUID drop, death, respawn and actual test-player disconnect; session/base/carry/pet visual cleanup verified |
| Client initialization | PASSED: one copy of each controller, MonsterHud and FieldAnnouncements present; both remotes match consumers |
| Blockout comparison | PASSED: 1,412 BaseParts and geometry digest 1212267917 match baseline; four bases, six zone blockouts and 25 launch nodes retained |
| Final Edit/source hygiene | PASSED: all 54 production/unit-source files match the repository; zero duplicate scripts, disabled unit runner, template quarantine intact, no GeneratedGameplay or temporary Play fixtures |

Test-development failures were investigated, not hidden: one fake-store fixture returned a value inconsistent with its stored baseline and correctly triggered conflict protection; the fixture was corrected. CharacterRemoving delivery is deferred, so the reset test now waits a bounded five seconds for cleanup (it passed). A test-injection command initially tried to access client-only PlayerScripts from the server; it was corrected to inject through the client DataModel. These were test/tool issues, not production startup exceptions. Final server/client console output contains successful startup, MonsterLoopTest, Phase1Integration, FieldIntegration and Phase1Lifecycle results, the explained test-injection error and the intentional test-player kick. No new game-script runtime errors or DataStore load warnings were observed. Studio was stopped and left in Edit mode.

The first final fingerprint calculation inserted newline separators between rows, unlike the original baseline. Reproducing the original serialization (sorted pipe-separated fields, rows concatenated without a separator, DJB2 seed 5381) gives the exact baseline digest. The read-only `tools/VerifyPhase1Snapshot.luau` makes this comparison reproducible. The fingerprint covers BasePart geometry/collision/anchoring; terrain was not mutated by any task action.

## 7. Acceptance criteria

| Criterion | Status | Evidence / limitation |
|---|---|---|
| Place loads without new runtime errors | PASSED | Clean bootstrap, definitions/world validation, server/client modules and live architecture checks |
| Obsolete systems removed or intentionally retained | PASSED | Dependency-aware audit; exact duplicates/debug scripts removed; assets retained with reasons |
| Five area definitions validate | PASSED | Startup checks and exact-pool unit cases |
| All 40 launch resources validate | PASSED | Exact-row tests, startup and world checks |
| Cross-references valid | PASSED | DefinitionValidation, negative schema tests and module initialization |
| Existing blockout intact | PASSED | Final Edit-mode 1,412-part count and 1212267917 geometry digest equal the baseline; no terrain edits |
| Progression/economic transactions server-authoritative | PASSED | Code trace and 31 live guard/transaction checks; client reward inputs unused |
| Successful/missing/failed loads handled safely | PASSED | Injected store tests, including no overwrite after failed/malformed load; no cloud test implied |
| Purchase and entitlement handling remains functional | BLOCKED | No legitimate pipeline exists in the inspected source/place; preserved-field tests cannot certify purchases |
| No orphaned remotes from deleted systems | PASSED | Entire live remote inventory contains only the two traced active events |
| Required modules initialize without cycles | PASSED | 117 static require expressions; 40 successful server/shared/client module requires |
| Studio playtest and console inspected | PASSED | Actual server/client sessions and console inspected; 31 architecture, 18 cycle, 14 resource-runtime and 14 lifecycle checks passed |

## 8. Remaining blockers and next phase

1. Identify the intended purchase/entitlement source or explicitly confirm monetization is absent for this milestone. A real pipeline needs a separate safe test plan; do not purchase products or create receipt rules speculatively.
2. Approve trainer prices, initial ownership and saved TrainingLevel migration before enabling new tiers. Confirm final Cash rates/starter roster before any economy/pet-ID migration.
3. Guardian disturbance/telegraph mechanics still use the existing prototype (1/3 disturbance, threshold 3, two-second warning), while master context describes rarity-based disturbance, threshold 100 and roughly 0.75–1.25-second telegraphs. This is documented, not silently rebalanced during architecture work.
4. An evolution into an already-owned species is safely rejected until a merge/multiple-pet ownership rule exists. Hybrid affinity splitting, 5% Mutant Leech rolls and carried Divine cap reservation follow the finalized resource specification.
5. Before production deployment: review/save the Studio-only cleanup, drain legacy save writers, and arrange an isolated published test universe for cloud persistence/multi-client handoff testing. Do not test against live saves.

Recommended Phase 2 starting point: use the validated architecture for the Grasslands acquisition/carry/guardian vertical slice, resolve the documented mechanics differences and run a real multiplayer contest/return-to-base playthrough. Keep existing resource values and map; defer economy migrations and polish until their own approved phases. **Phase 2 has not been started.**
