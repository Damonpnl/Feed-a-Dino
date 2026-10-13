# Phase 4B — Multi-stage Growth and branching evolution

Date: 2026-10-13. Scope: 4B only. See the verification table below for tested scope and limitations.

## Pre-change gate and audit

Read the master context, lineage/current-state documents, 4A report and full Phase 4 specification. The user's newer 4A/4B/4C/4D boundaries supersede the older numbering inside PHASE4_SPEC.md.

Before modifying gameplay, the official Studio MCP ran **195/195 unit tests**, **33/33 Phase4AIntegration checks** (including actual synchronized reset), **7/7 client presentation checks**, **12/12 prototype compatibility checks**, and **18/18 checks with two actual Studio clients**. All used ordinary read-only Studio sessions or explicitly injected in-memory SessionStore adapters, never production saves.

Already working: authoritative GUID consumption, feeding preview/confirmation, persistent Growth/affinities, guardian/carry lifecycle. Incompatible prototype behavior: first matching evolution won, current Growth was erased, and evolution renamed a species-keyed ownership entry, blocking duplicate forms. Missing: real stages, overflow, persistent choices, graph validation, stage visuals.

## Implemented graph

All edges live in MonsterDefinitions; EvolutionCalculator is the sole pure resolver.

| Source stage/forms | Targets and conditions |
|---|---|
| 0 ProtoRex | Fangling (Flesh >=40 and dominant), Mossback (Flora >=40 and dominant), Stonehide (Mineral >=40 and dominant); otherwise JuvenileRex |
| 1 Fangling, Mossback, Stonehide, JuvenileRex | ArmoredRex (Flesh+Mineral >=80 each), VenomRex (Flesh+Flora >=80 each), CrystalMossRex (Flora+Mineral >=80 each); otherwise MatureRex |
| Existing Stage 1 catalyst branches | Fangling → MagmaRex (Flesh80 + Fire), Mossback → SpiritDragon (Flora80 + Spirit), Stonehide → CrystalWolf (Mineral80 + Crystal); existing IDs/families retained, no new catalyst effects |
| 2 MatureRex, hybrids, retained legacy advanced forms | ApexRex |
| 3 ApexRex | AscendedRex |
| 4 AscendedRex | MythicRex configured but **locked**, regardless of Growth |
| 5 MythicRex | Framework only; no outgoing edge; no Awakening implementation |

Fallback is explicit: the normal branch is considered only when no specialized branch qualifies. Ties count as co-dominant and yield a choice, not table-order selection. Candidates sort by stable branch ID. All qualifying specialized branches remain choices; no implicit catalyst priority. Triple-affinity predicates work, but no triple form is granted. Probability is accepted as validated metadata; any value other than 1 is unavailable pending an approved future policy, never rerolled.

## Provisional values and overflow

GrowthStageDefinitions centralizes labels, sizes and thresholds. Retained prototype costs: 0→1=50, 1→2=80, 2→3=160 (SpiritDragon retains its 200 exception). **PROVISIONAL_BALANCE:** 3→4=3000 from the specification's illustrative threshold; all new hybrid minima=80 per required affinity. Stage 4/5's 3000 is a storage/display cap, not prestige eligibility. New placeholder form multipliers reuse existing 1.5/2.5 tiers; no new rarity rolls or trainer values. The original species multiplier is a floor for retained legacy pets. Ordinary transitions preserve saved rarity.

Each feed or choice can advance exactly one stage; the resolver never loops through stages. A transition spends only its source threshold. Current Growth is bounded to the form's threshold; all remaining legitimate progress stays in GrowthReserve. TotalGrowth never decreases. Growth plus reserve and individual counters are constrained by the existing exact-number ceiling (2^53−1); exhausted or malformed calculations reject without consuming. Further progression needs a subsequent feed/explicit pending choice, not a reconnect or UI reopen.

## Ownership/save compatibility

DataStore `MonsterProgress_v1`, keys `u_<UserId>`, SessionStore conflict handling and DataService remain unchanged. `EquippedMonster` and keys in `Monsters` now identify stable owned slots, never the changing form. Existing Species and PetId remain unchanged. `EvolutionForm`, `EvolutionVersion=1`, GrowthReserve, Lineage, LineageTags and PendingEvolution are additive. Missing IDs use the existing owner-scoped ownership key; existing GUIDs are not regenerated. No new pet acquisition/equip system is introduced.

Legacy records without a form/version infer their known prototype stage only when Stage was zero/absent (4A previously defaulted all forms to zero). Explicit unknown form IDs or incompatible nonzero stages are preserved and fail closed for feeding/evolution, not silently reset. Unknown save fields, catalyst unlocks, mutations, Flora and history survive normalization. Form changes replace only the same owned slot; another Fangling remains untouched when ProtoRex's current form becomes Fangling. Old servers must be drained before deployment: older species-renaming writers cannot safely interpret the additive form semantics. Rolling back requires retaining the new fields and a planned reader, not running older writers on upgraded saves.

Pending choices store the source form/stage/revision, stable candidate IDs and token. They survive SessionStore release/load. Feeding while pending is deliberately blocked with the carried resource retained; it cannot regenerate choices. Selection revalidates writable session, active owned key, living character at the assigned feeding point, token/revision, membership and current graph predicates. Selection costs no resource. No new inventory, journal, or claim of cross-server durable atomicity.

## APIs for Phase 4C

- `EvolutionCalculator.initialize(record, ownedKey)`: additive migration on normalized/new records.
- `form(record)`, `valid(record)`, `candidates(record)`, `eligible(record, edge)`: pure queries; eligibility includes rejection reason.
- `afterFeed(stagedRecord)`: bounded overflow plus one automatic transition or saved choice. Call only on a copied, validated record; caller increments feed revision first.
- `select(stagedRecord, token, branchId)`: revalidates and applies one saved choice, increments revision, preserves identity/history/traits.
- Graph fields: Id, Source, Result, SourceStage, TargetStage, Growth, Requirements (saved `Flora`), Dominant, Family, RequiredLineage, RequiredTags (prior forms), RequiredMutations, MinRarity, Probability, Fallback, Locked. Form Visual metadata drives placeholders.
- `MonsterService.chooseEvolution(player, {PetKey,Token,BranchId})`: guarded authoritative choice transaction. Old `evolve` entry point now requires a real pending choice.
- Existing `FeedInteraction` remote accepts `Evolve` with that payload in addition to Preview/Confirm. No additional remote. Responses use `Kind="Evolution"`; client cannot send rewards or pet state.
- Replicated attributes: OwnedPetKey, MonsterId (current form), PetStage, PetStageLabel, GrowthReserve, PendingEvolution. Existing multiplier/carry/HUD attributes remain available.

The native choice panel uses one handler per disposable button, destroyed when state changes. No new frame loops. Stage/form changes safely replace the anchored placeholder at the existing CreatureSpawn marker; final creature art, animations and evolution cinematics remain placeholders.

## Files

Created: `src/shared/GrowthStageDefinitions.luau`, `tests/unit/Cases/EvolutionStages_Test.luau`, `tests/Phase4BIntegration.server.luau`, `tests/Phase4BMultiplayer.server.luau`, `tests/Phase4BPresentation.client.luau`, this report.

Modified: MonsterDefinitions, EvolutionCalculator, PlayerData, DefinitionValidation, FeedService, MonsterService, UIController; 4A integration's current-Growth assertion now compares the authoritative stage/overflow preview, and 4A compatibility assertions now require stable ownership rather than species-key renaming. Effect totals/exact-once/save/carry safeguards were not weakened. No repository files deleted. One identical Rojo-created duplicate GrowthStageDefinitions instance was removed from Studio; canonical source remains recoverable in the repository.

## Verification

- Final synchronized post-change unit run: **225/225 passed** (195 retained +30 new). Includes all 40 feed effects, hybrid splitting, stage thresholds, overflow, identity, persistent choices, malformed graphs, mutually exclusive lineage requirements and forged Stage 5 selection.
- Final Phase4BIntegration: **34/34 passed** using real server services and an isolated SessionStore. Includes feeding/evolution, duplicate forms, exact-once commits, overflow, ownership/proximity/session rejection, save/reload, death/respawn and a real MCP mouse click selecting Mossback.
- Phase4BPresentation: **6/6 passed** on the actual client. Three forged selection payloads, 20 malformed requests, actual button selection, and 30 replay requests were exercised. Choice UI was inspected in a screenshot; form/stage/cost/affinity requirements are readable and the panel clears after success.
- Post-change 4A regression: **33/33 server**, **7/7 client**, **13/13 updated compatibility** checks passed. Actual field reset preserves the carried GUID and feeding during reset consumes it once. The additional compatibility check confirms an owned same-form pet is untouched.
- Phase 1 integration: **32/32 passed**. Phase 3 carry/guardian integration: **155/155 passed** (count varies with spawned rarity/encounter paths). Field runtime smoke: **14/14 passed**, including actual dropped-resource expiry and node refill.
- Build: `rojo build` passed; `git diff --check` passed (only existing CRLF notices).
- First post-change 4A integration attempt timed out because its client listener was installed after the preview. Retried with the client listener first and passed; the timeout is not counted as a pass. The final new unit module was explicitly synced into Edit mode after discovering it was absent there; 225 is the fresh-Play result, not an earlier cached run.
- Phase4BMultiplayer: **11/11 passed with two actual Studio clients**, including simultaneous independent evolutions, ownership/token rejection, replay rejection, disconnect session release and identical pending-choice restoration through the injected store.
- Final source audit: **66/66 repository production/unit sources match Studio** by normalized UTF-8 byte length and digest. No duplicate script paths. Definition validation has zero errors. Saved map remains **1412 BaseParts**, geometry digest **1212267917**, **25 ResourceNodes**, matching the pre-4B baseline.
- Server/client output inspected during testing: no new gameplay-breaking errors. The deliberate 4A presentation-exception fixture verifies committed rewards survive presentation failure; it is not a gameplay defect. Normal Studio remains read-only. Play stopped, multiplayer clients closed by StudioTestService, temporary saved multiplayer fixture/result attribute removed, unit runner remains disabled.

## Acceptance status

| Requirement | Status | Evidence |
|---|---|---|
| 4A passes before gameplay edits | PASSED | Pre-change unit, live server/client, compatibility and two-client results above |
| Six-stage engine; Stage 5 locked; Awakening separate | PASSED | Pure stage path and forged-prestige tests; no Stage 5 granting code |
| One-stage transitions, exact thresholds and retained overflow | PASSED | Unit boundary/7000-Growth/normal-path tests and authoritative feed/choice integration |
| Three primary directions and at least two hybrids | PASSED | Three dominant branches and three configured hybrid branches, each with minimum-boundary tests |
| Declarative graph and invalid/cyclic/skipping/unreachable requirements rejected | PASSED | Startup validation and corruption/ancestry tests; all ordinary edges advance exactly one stage |
| Deterministic eligibility and persistent multi-branch selection | PASSED | Sorted IDs, tie/choice tests, SessionStore release/load and disconnect restoration |
| Authoritative ownership, proximity, sessions and forged/repeated requests | PASSED | 34 server +6 client checks and 11 actual multiplayer checks |
| Same individual pet and duplicate-form ownership preserved | PASSED | Legacy migration, unknown-field preservation, unchanged second Fangling, existing PetId round trips |
| Stage/form/choice persistence | PASSED (isolated store) | Existing SessionStore serialization, load/release, conflict and failed-load suites; no cloud requests |
| Safe placeholder replacement, scaling and UI updates | PASSED | Live model/attachment assertions, real mouse selection and screenshot inspection; final art intentionally absent |
| Phase 1–3 and feeding regression behavior | PASSED | 225 units, 32 Phase1, 155 Phase3, 14 field-runtime, 33+7 feeding and 13 compatibility checks |
| Repository/Studio consistency and blockout preservation | PASSED | 66 matched sources, no duplicates, unchanged geometry digest and node count |
| Production cloud save/rejoin and multi-server durability | NOT TESTED | Deliberately excluded to avoid production saves; existing optimistic persistence limitations unchanged |
| Physical mobile devices and final asset quality | NOT TESTED | Functional desktop UI verified; device QA and final art remain later work |

Phase 4B is complete within the requested isolated-test scope. **Do not start 4C automatically.** Remaining design approvals: provisional stage/hybrid values, final art, future catalyst compatibility/selection policy, and Stage 5 eligibility in 4D. Existing unknown/conflicting legacy form records are preserved but blocked from evolution pending an explicit mapping; tests cover this fail-closed behavior. No observed test save required such a mapping. Deploy only after draining older writers and reviewing the additive migration policy.

No production cloud save/rejoin, purchase pipeline, physical mobile-device test, or final-art validation is claimed. In-memory persistence tests establish existing SessionStore serialization/migration behavior, not a distributed durable transaction.
