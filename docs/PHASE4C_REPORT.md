# Phase 4C — Catalysts, mutation effects and special families

Date: 2026-10-15 (resumed from 2026-10-14). Scope: **Phase 4C only — implemented and verified within the isolated Studio test scope below.** No Phase 4D work started.

## Phase 3B isolation and prerequisite recovery

The original Studio baseline failed: 209 run / 205 passed / 4 missing-dependency failures. With explicit user approval, preserved all four newer test ModuleScripts **before** restoring the repository baseline. No Phase 3B gameplay was imported, no branches merged/reset, and neither place was saved over or published.

| Original location | Preserved Studio location | Disk backup |
|---|---|---|
| ServerStorage.UnitTest.Cases.GuardianState_Test | ServerStorage.Phase3BPreservedTests.GuardianState_Test | docs/audit/phase3b-preserved/GuardianState_Test.luau |
| ServerStorage.UnitTest.Cases.CarryDebuff_Test | ServerStorage.Phase3BPreservedTests.CarryDebuff_Test | docs/audit/phase3b-preserved/CarryDebuff_Test.luau |
| ServerStorage.UnitTest.Cases.GuardianChase_Test | ServerStorage.Phase3BPreservedTests.GuardianChase_Test | docs/audit/phase3b-preserved/GuardianChase_Test.luau |
| ServerStorage.UnitTest.Cases.GuardianJourney_Test | ServerStorage.Phase3BPreservedTests.GuardianJourney_Test | docs/audit/phase3b-preserved/GuardianJourney_Test.luau |

Each archived Studio module retains an OriginalPath attribute. The archive is outside UnitTest.Cases discovery; disk backups are outside all Rojo mappings. Restore only at an approved integration step, resolving the GuardianState_Test name conflict against the intended gameplay version first. Do not enable these tests against Phase 4's disturbance-based guardians.

Repository inventory: **13 case modules**. Original Edit inventory: **16 modules**, with 12 exact normalized-source matches, one conflicting GuardianState_Test and three extra Phase 3B cases. Only those four were moved; the repository GuardianState_Test was restored. All legitimate feeding/evolution tests remained unchanged. The full baseline then passed **225/225 before gameplay edits**. Inventory and original paths are also in [phase4c-isolation.json](audit/phase4c-isolation.json).

Rojo isolation evidence: Studio PID 32420 had two established localhost connections to original server PID 15028 on **34872**, none to **34873**. PID 27532 serves --port 34873. The 34872 API matched all 52 original production sources, and later all 55 updated Phase 4 production sources as this worktree changed. The 34873 server advertises GuardianChase/CarryDebuff; neither module was copied. The existing Rojo process does not include repository test sources in its served snapshot, so test-only synchronization used the MCP explicitly. No project mapping was changed.

## Implementation

Existing FeedService, MonsterService, ResourceEffects, CatalystDefinitions and EvolutionCalculator remain authoritative. No new inventory, resource identity, remotes, DataStores, or per-catalyst scripts.

- CatalystDefinitions remains a view of ResourceDefinitions, with separate behavior records referencing those resource IDs. Rarity, Growth, Power, weights, slowdown and launch pools are untouched.
- CatalystEffects supports UnlockEvolutionFamily, AddLineageTag, AddLatentTrait, EnableSpecialEvolution, AttemptMutation and explicitly configured ForceEligibleBranch.
- Compatibility supports species, current forms, lineage, stage, affinity minima, required/forbidden previous families, lineage tags, latent traits and enabled-special conditions. Invalid saved flags fail closed and are not erased.
- **Provisional compatibility policy:** known ProtoRex-lineage species, stages 0–4, with no new catalyst-consumption affinity cost. Branch affinity requirements remain separate. Repeated compatible catalysts still grant their catalog Growth; unlock flags are idempotent. This preserves prior feeding behavior rather than inventing a consumed-once item rule.
- Family/latent unlocks can occur before a branch is eligible. Graph selection still enforces Growth, affinities, source/target stage and pending choice. No catalyst bypasses Stage 5 locking.
- All effects are calculated on a staged copy; the existing non-yielding consume/commit path grants once. Rejected compatibility leaves the carried GUID untouched.
- FeedRolls stores injected server random tickets per existing world GUID/roll index. Failed calculations/consumption, fresh previews and owner changes reuse the same tickets while that GUID exists. Dead-record tickets are pruned on subsequent commits; this is not a durable inventory or journal. Previews use a no-win sentinel and never consume RNG.
- MonsterService publishes EvolutionFamilies, LatentTraits and SpecialEvolutions alongside existing mutation/form attributes. Existing native preview, rarity styling and persistent choice UI are reused.

## Launch catalyst behavior and branches

Each catalyst also persists its primary-family latent trait, enabled-special flag and Catalyst:<family> lineage tag. No launch catalyst performs a random transformation.

| Resource | Family flags | Usable Stage 1 → 2 branch |
|---|---|---|
| Primal Catalyst | Primal | Any existing juvenile → PrimalRex; Flesh >=80 |
| Toxic Catalyst | Toxic, legacy Mutant alias | Any existing juvenile → ToxicRex; Flora >=80 |
| Jungle Heart | Beast, legacy Alpha alias | Any existing juvenile → AlphaRex; Flesh >=80 |
| Crystal Catalyst | Crystal | Stonehide → existing CrystalWolf; Mineral >=80 |
| Fire Core | Fire | Fangling → existing MagmaRex; Flesh >=80 |
| Dragon Blood | Draconic | Any existing juvenile → DraconicRex; Flesh and Mineral >=80 each |
| Inferno Catalyst | Inferno | Any existing juvenile → InfernoRex; Flesh >=80 |

Existing juveniles: Fangling, Mossback, Stonehide, JuvenileRex. New named forms are **playable placeholders**, not approved final art/balance. They reuse Stage 2 multiplier 2.5 and the existing threshold 160, with source Growth cost 80. The example affinity minima reuse 4B's provisional 80. They continue through ApexRex → AscendedRex, with Stage 5 still locked. Existing special/hybrid candidates may coexist and produce the same persistent choice; no implicit catalyst priority or table-order selection.

No launch effect uses ForceEligibleBranch. Its test fixture proves it can select only an otherwise eligible next-stage branch; invalid or skipped-stage targets fail before resource consumption.

## Mutation taxonomy and probability

- Silver, Golden and Rainbow: supported cosmetic overlay definitions, exclusive Finish stacking group. **No acquisition source/probability or stat multiplier is invented.**
- Mutant: retained biological overlay; the **only active random mutation is Mutant Leech's existing 5%**, using the existing SpecialEffectDefinitions value. Roll <0.05 succeeds; exactly 0.05 fails. Already-present or incompatible mutations do not roll again.
- Finish and Biological overlays may coexist. Duplicate IDs and same-group stacks reject. Unknown legacy mutations are preserved but block new stacks until explicitly mapped.
- Fire, Crystal, Draconic, Toxic and Primal are permanent evolution families, not additional overlay rolls.
- Titan, Void, Cyber, Spirit, BloodMoon and Celestial are reserved family definitions, not simultaneously represented as new overlays. Parasite is a disabled reserved special overlay.
- Toxic's historic EvolutionFamilies.Mutant flag is only a compatibility alias; it does not grant the separate Mutations array's Mutant overlay.

Disabled future catalyst behavior examples: GiantSerum→Titan, SpiritEnergy→Spirit, CyberCore→Cyber, VoidEssence→Void, BloodMoonShard→BloodMoon, CelestialCore→Celestial. Existing Launch=false, zero weights and absence from launch pools remain intact. They reject live application. Enable only after balance/eligibility/forms/assets are approved; the legacy SpiritDragon branch remains valid for already-saved Spirit unlocks.

## Persistence and compatibility

DataService/SessionStore, MonsterProgress_v1 and u_<UserId> are unchanged. LatentTraits and SpecialEvolutions are additive maps initialized only when absent. Existing families, Flora, Growth/reserve/TotalGrowth, owned keys, PetId, Species, EvolutionForm, mutations, history and opaque purchase fields survive normalization and stage changes.

All atomicity claims are **server in-memory only**. World GUIDs and random tickets are not persisted; existing crash/autosave limitations remain. No production save was read, written or reset. Test save/reload uses the existing SessionStore with injected memory adapters, not cloud rejoin evidence. Continue the 4B deployment requirement to drain incompatible older writers.

## Tests

- Authoritative pre-change baseline: **225/225 PASSED** through official Studio MCP, after isolation.
- Final expanded unit suite: **255/255 PASSED** in fresh Studio Play sessions, including all 225 prior contracts and 30 new catalyst/mutation contracts. The earlier 252 run preceded three additional validation tests.
- Phase4CIntegration: **89/89 PASSED** using real server/carry/resource services and explicitly seeded runtime GUID records, not altered spawn probabilities. Covers seven catalysts, twenty competing confirmations per feed, unlock save/reload, incompatible lineage, failed sessions, stale traits, distance rejection, failed consume/retry RNG reuse, replay and world uniqueness. Final 28 checks exercise actual evolution into all seven compatible family forms, including selection of DraconicRex when a hybrid also qualifies, unchanged pet identity, and placeholder/UI attribute updates. Earlier 61-check runs passed before adding these seven real-form scenarios.
- Phase4APresentation: **7/7 PASSED** actual client preview and remote-replay checks.
- Phase4AIntegration: **33/33 PASSED**, including death/respawn and the actual synchronized reset boundary; carried loot survives and feeds exactly once during Reset.
- Phase4BIntegration: **34/34 PASSED**; Phase4BPresentation: **6/6 PASSED**, including an actual MCP mouse click selecting Mossback and forged/replayed client choices.
- Phase4ACompatibility: **13/13 PASSED**; Phase1Integration: **32/32 PASSED** after resuming on October 15.
- Phase3Integration: **155/155 PASSED**, all five hazards, authoritative Power/carry/drop/recovery, safe character reset and no duplicate world records. This is a single-player fixture, not multiplayer evidence.
- FieldRuntimeSmoke: **14/14 PASSED**, actual 20-second drop expiry, eligible refill with a fresh GUID, physical representation and slowdown/cleanup.
- Phase4AMultiplayer: **18/18 PASSED with two actual Studio clients**, contested pickup, recovery by another owner, independent simultaneous feeds, cross-owner/ticket rejection, replay and disconnect/save behavior. This is the existing general feeding regression; seven-catalyst permutations were tested by the single-player 4C fixture, not all repeated with two clients.
- Rojo build and git diff --check: **PASSED**.
- Final source audit: **70/70 production/unit sources match Studio**. Four archived Phase 3B tests match their disk backups; none is in active case discovery. Final network check shows Studio connected to 34872, not 34873.
- Final map audit: **1412 BaseParts**, geometry digest **1212267917**, **25 nodes**, **0 duplicate script paths**, **0 definition errors**, matching the existing baseline. The first final audit detected three identical new Phase 4C module duplicates caused by overlapping synchronization. Removed only redundant MutationDefinitions, CatalystEffects and FeedRolls instances after confirming identical source; canonical source remains in Studio and the repository. Fresh Play then passed 255 units and 89 integration checks.
- Server/client console output was inspected; no new gameplay-breaking errors were observed. Deliberate failed-commit/presentation fixtures are not production errors. Studio is left in Edit mode, UnitTestRunner disabled, runtime fixtures gone and the temporary multiplayer Script removed. No place was published or saved over.

## Acceptance status

| Requirement | Status | Evidence |
|---|---|---|
| Correct Phase 4 baseline and Phase 3B isolation | PASSED | 225 pre-change tests, separate archive/backups, port/source audits |
| Seven catalysts, compatible rejection and latent unlocks | PASSED | 30 new unit contracts and 89 real-service checks |
| Stage-gated usable special branches, one pet identity | PASSED | Seven real form transitions/choices and original 4B regression |
| Mutation taxonomy, stacking, deterministic approved probability | PASSED | Overlay/family separation, exclusive 5% boundary and duplicate tests |
| Retry-safe RNG and exactly-once resource consumption | PASSED | GUID ticket cache, injected failed consume, concurrent confirmation/replay tests |
| Unlock/trait save integrity and prior fields retained | PASSED (isolated store) | SessionStore release/reload, legacy/opaque-field tests; no live saves |
| Future examples remain disabled | PASSED | Six disabled-resource cases; unchanged launch catalog/pools |
| Phase 1–4B regressions | PASSED (listed scope) | Units, architecture, guardians, field, 4A/4B live client/server and two-client feeding checks above |
| Final source/map/console/build checks | PASSED | 70 source matches, unchanged map digest, no duplicate paths, build and fresh Play |
| Production cloud durability / physical devices / final art | NOT TESTED | Deliberately outside this isolated implementation scope |

## Files and handoff APIs

Created: src/shared/CatalystEffects.luau, src/shared/MutationDefinitions.luau, src/server/FeedRolls.luau, tests/unit/Cases/CatalystEffects_Test.luau, tests/Phase4CIntegration.server.luau, preservation backups/isolation audit and this report.

Modified: CatalystDefinitions, ResourceEffects, EvolutionCalculator, MonsterDefinitions, PlayerData, DefinitionValidation, FeedService, MonsterService. No repository gameplay/test file deleted; existing Phase 4 tests were not weakened.

APIs:
- CatalystDefinitions.getBehavior/getBehaviors: behavior configuration; get/getAll still return catalog resources.
- CatalystEffects.compatible(record, behavior) → boolean/reason; apply(staged, behavior, nextNumber) → optional forced branch ID; validate() → errors.
- ResourceEffects.canApply(record, definition) → compatibility/reason. resolve remains pure numeric client preview. apply returns the optional force ID.
- EvolutionCalculator.afterFeed(staged, optionalForcedBranchId) preserves one-stage/choice semantics. RequiredLatentTraits and RequiredSpecialEvolutions extend branch predicates.
- MutationDefinitions.get/getAll/canApply/apply separates overlays from families. No client mutation authority.
- FeedRolls.new(nextNumber).forResource(guid) produces a retry-stable random closure; prune(exists) removes dead GUID entries.

## Remaining limits

Final art, final catalyst compatibility/balance, additional mutation chances/acquisition sources, future event pools, Stage 5/Ascension and Awakening remain unimplemented by design. No Phase 4D work is authorized here. Cloud durability, physical mobile QA and actual production purchases are not claimed.
