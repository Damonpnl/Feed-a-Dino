# Phase 4A — feeding and persistent Growth

Date: 2026-10-12. Target: Feed a Dino place `104154372052853` (Feed a Pet product), official Studio MCP. **Phase 4A implemented and locally verified.** Studio is left in Edit mode; no publication or production-save access. Cloud durability and physical-device limitations remain explicit below. Phase 4B was not started.

## Scope and inspection

The latest explicit Phase 4A request governs scope. `PHASE4_SPEC.md` calls feeding its internal 4B; that numbering does not expand this task into its full evolution roadmap. Read master context, finalized resource specification, Phase 1–3 reports, lineage/current-state documents, existing services/definitions/save schema and actual Studio scripts/base feeding markers.

Before this phase: the GUID carry/guardian loop was verified in Phase 3. Feeding already staged effects, used the existing prototype evolution calculator and consumed carried records, but lacked confirmation, writable-session validation, cumulative Growth and exception-safe post-consumption presentation. Ownership remains species-keyed: seven existing prototype IDs, not a newly invented inventory or per-pet migration.

## Implemented changes

- Existing base prompt now opens a functional native preview, then requires confirmation. One new runtime `Remotes.FeedInteraction` RemoteEvent carries preview requests, server-issued tickets, confirmations and compact results. No client reward/resource/species values are trusted.
- Validate server session writability, living character within 14 studs of the assigned feeding point, base ownership, owned active pet, matching authoritative carried GUID/state/definition and valid finite progression/effects.
- One bounded preview per player, valid for 30 seconds. Binds session table, pet identity/snapshot, character, base/station, resource GUID and acquisition version. Pet changes, drop/recovery of the same GUID, character reset, expiry and replay reject without consuming. Confirmation revalidates and recalculates.
- `ResourceEffects.resolve` is shared pure math for preview and application. Every existing launch value remains unchanged. Hybrid affinities total Growth; odd remainders go to the first listed affinity (Bog Marrow: **28 Flesh + 27 Mineral**). Neutral grants no primary affinity. Historic fractional affinity totals are preserved.
- Current `Growth`, new `TotalGrowth` and `Revision` persist through the existing save architecture. Legacy `Flora` remains canonical; UI calls it Floral.
- Existing prototype automatic evolution, family tags and the existing 5% Mutant Leech behavior remain compatible. No new rolls, stages, evolution graphs, branch-choice UI, catalyst framework, economy or art were implemented. Preview describes prototype evolution/reset and special effects; opening it never rolls RNG.
- Native HUD panel shows resource name/rarity color, active pet, before/after Growth, individual gains, special-effect text, confirmation/refresh/close and unavailable reasons. Scaled layout is bounded to 440×340. No render loop was added.

## Transaction and failure guarantees

Validate and stage a copy before mutation. The existing `CarryService.consumeOwned` / `ResourceService.consume` path performs CARRIED → CONSUMED using the original GUID. Core resource removal, pet replacement and counters execute without yielding. World refresh is deferred; carry/pet presentation exceptions cannot turn committed consumption into an apparent failed reward. Replays cannot find the consumed GUID or valid ticket. The direct `FeedService.feed` API remains server-only compatibility functionality and uses the same validation/commit path; player inputs use preview/confirm.

This is **in-memory exact-once**, not a durable cross-server transaction. World carries are not persisted. A server crash before a successful autosave can lose recent Growth. SessionStore retains its full-record optimistic UpdateAsync conflict check, not a leased distributed lock or transactional journal. No new guarantee is claimed. Existing no-overwrite behavior on failed/invalid loads remains intact; failed save requests retain in-memory data for retry.

Field resets preserve carried GUIDs, including while feeding. No field phase restriction is added to feeding a legitimately carried item at home. Death/reset follows Phase 3's drop policy. On disconnect, a still-carried record is released; a character-removal drop that happened first remains eligible under its existing expiry policy.

## Save compatibility

Unchanged store: `MonsterProgress_v1`; keys: `u_<UserId>`. No live migrations, resets or store reads/writes were run.

| Field | Compatibility rule |
|---|---|
| Monsters / EquippedMonster / Species / Rarity | Existing species-keyed ownership and IDs retained; no overwrite of an already-owned evolution target |
| Growth | Existing current Growth; prototype evolution still resets it as before |
| TotalGrowth | Default `max(current Growth, valid stored TotalGrowth)`; increments on every accepted feed and survives prototype evolution |
| Flesh / Flora / Mineral | Existing persisted keys and totals retained; no divergent Floral save key |
| Revision | Nonnegative integer, default 0; incremented by successful feeding |
| Stage / EvolutionHistory | Additive defaults 0 / empty table, retaining existing values; no new stage transitions or unbounded log |
| EvolutionFamilies / Mutations | Existing fields and behavior retained |
| PetId / EvolutionForm / purchases / other fields | Existing opaque values preserved by deep copy/normalization; no replacement IDs generated |

Historic Growth spent before TotalGrowth existed cannot be reconstructed. Migration uses the conservative current-Growth baseline, not fabricated historical earnings. Invalid/precision-exhausted numeric effects reject before consumption; the representable upper bound is 2^53−1, not a new economic balance cap.

Ordinary Studio data intentionally remains read-only. Feeding is unavailable there unless an **opt-in test fixture** injects a writable in-memory SessionStore. Fixtures temporarily override server module accessors, restore them, and never bypass the production DataStore adapter's Studio prohibition. A live published save/rejoin test was neither attempted nor claimed.

## Files

Modified production: `src/server/FeedService.luau`, `DataService.luau`, `ResourceService.luau`, `CarryService.luau`, `MonsterService.luau`; `src/shared/PlayerData.luau`, `ResourceDefinitions.luau`, `ResourceEffects.luau`; `src/client/UIController.client.luau`.

Created tests: `tests/unit/Cases/FeedingGrowth_Test.luau`, `tests/Phase4AIntegration.server.luau`, `tests/Phase4APresentation.client.luau`, `tests/Phase4AMultiplayer.server.luau`, `tests/Phase4ACompatibility.server.luau`, `tests/Phase4AButton.server.luau`. Updated `tests/Phase1Integration.server.luau` to assert the new read-only rejection before explicitly injecting test-only writable status for its existing feed assertions.

Documentation: this report, CURRENT_STATE and the odd-remainder clarification in RESOURCE_SPECIFICATION. No production scripts/modules/assets deleted. Earlier uncommitted Phase 1–3 and user art/document changes are preserved.

## Actual test evidence

| Check | Status / evidence |
|---|---|
| Unit suite | **PASSED: 195/195**, zero failures, twice in Studio Play; 46 new pure calculation/normalization/save tests plus 149 prior cases |
| All 40 launch effects | **PASSED**, preview/application agreement, affinity membership, conserved hybrid total, Neutral zero, exact locked examples |
| Failed/missing/invalid/conflicting saves | **PASSED**, existing injected SessionStore cases; live feeding guards reject non-writable statuses |
| Phase4AIntegration | **PASSED: 33 checks**, actual game services; stale tickets, ownership/proximity/session, concurrent attempts, consumption/cleanup, fake save/reload, presentation failure, death/respawn and actual synchronized reset |
| Phase4APresentation | **PASSED: 7 checks**, actual client preview content/size/confirm state, 30 forged/replayed remote requests, replicated carry cleanup and success result |
| Phase4AMultiplayer | **PASSED: 18 checks**, two actual Studio clients: contested GUID, cross-player recovery, independent simultaneous feeds, cross-owner/ticket rejection and actual disconnect with isolated fake persistence |
| Phase1Integration regression | **PASSED: 32 checks**, training/upgrade/ownership/feeding/respawn plus read-only-feed rejection |
| Phase3Integration regression | **PASSED: 169 checks**, all five actual guardian hazards, carry/Power, recovery, character reset and consumption. Count varies with randomly spawned rarity/disturbance pickup iterations |
| FieldRuntimeSmoke regression | **PASSED: 14 checks**, actual drop expiry/refill, visual/weld/movement and uniqueness |
| Phase4ACompatibility | **PASSED: 12 checks**, invalid counters/revision, injected precommit failure/retry, owned-target protection, original automatic evolution, post-evolution preview, cumulative Growth/identity retention and replay |
| Actual Feed button / visual inspection | **PASSED**, official MCP mouse click on native Confirm button; server fixture confirms exactly one consumption. Captured/inspected 440×340 preview: Bone Chunk, Proto Rex, 0 → 8 Growth, +8 Mineral, rarity color, Feed/Close |
| Final source/map/build/console | **PASSED**, 64/64 source fingerprints match; zero duplicate scripts; 1,412 BaseParts, original digest 1212267917, 25 nodes, zero definition errors; Rojo build and whitespace check; final console shows clean initialization and successful resource regression |
| Published/cloud rejoin or two-server persistence | NOT TESTED — deliberately no production access; in-memory adapter round-trip is not cloud evidence |
| Physical mobile/gamepad testing / prolonged load | NOT TESTED |

The first 4A integration fixture assumed FeedingPoint was a Part; actual Studio uses a Model. The fixture now resolves its descendant BasePart, matching production code. The first multiplayer test expected no record after disconnect; inspection of the established Phase 3 lifecycle required accepting either release or an earlier eligible DROPPED record. Corrected assertions separately verify rejected confirmation, no carried owner and no extra reward. Neither failed fixture run is counted as a pass. The presentation-fault warning is intentional and verifies committed effects remain intact.

## Acceptance and 4B handoff

| 4A requirement | Status |
|---|---|
| Server-authoritative preview → confirmation → exact-once consume/effect | PASSED |
| Current/cumulative Growth and affinities, all hybrid/Neutral calculations | PASSED |
| Compatible persistence using existing SessionStore, no production saves accessed | PASSED (isolated adapters; cloud limits above) |
| Invalid ownership/distance/session/stale GUID rejection | PASSED |
| Reset/death/disconnect/concurrent request safety | PASSED |
| Native functional preview | PASSED (paired client plus actual MCP button click and visual inspection) |
| Existing Phase 1–3 regression / final clean place | PASSED (195 unit cases, 32 architecture, 169 guardian, 14 resource-runtime checks and final source/map verification) |

Handoff APIs:

- `ResourceEffects.resolve(record, definition)` → `{Delta, BeforeGrowth, After, SpecialDescription}`; pure, no mutation/RNG. Persist Floral via Flora.
- `ResourceEffects.apply(stagedRecord, definition, rng)` → existing effect application to a temporary copy; never call on authoritative data before commit.
- `FeedService.preview(player, base, host)` → availability/reason or server-bound ticket and compact presentation state.
- `FeedService.confirm(player, ticket)` → accepted boolean and reason; no client effect amounts accepted.
- `DataService.isWritable(player)` → current valid, non-closing writable session; existing `get/getStatus/save/release` remain.
- `MonsterService.getRecord/publish/getMultiplier` retained. `TotalGrowth` is now published with Growth.
- Existing `CarryService.consumeOwned` and resource GUID/state APIs remain the only ownership path.

Do not start 4B automatically. Full individual-pet ownership migration, approved growth stages/branch rules, new mutation/catalyst mechanics and production cloud testing require their own task. Existing purchase-infrastructure and trainer-pricing blockers remain unchanged from Phase 1. Graybox assets remain deliberate placeholders.
