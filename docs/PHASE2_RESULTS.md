# Phase 2 — world resource system

Verified 2026-10-10 using the official Roblox Studio MCP against Feed a Dino, place 104154372052853. **Phase 2 PASSED.** Studio is left in Edit mode; no publishing or production DataStore requests were performed. Phase 3 was not started.

## Implemented and preserved

- The server owns 25 stable-ID nodes across five launch areas and the existing 40 resource definitions. Configuration, weights, economic values, access gates and persistence identifiers were preserved.
- A 300-second server-wide period contains **290 normal seconds followed by 10 resetting seconds**. This follows the latest request's “final 10 seconds,” superseding the earlier 300+10 interpretation. Startup establishes the server epoch and populates nodes; delayed ticks reconcile against scheduled boundaries. Separate servers do not share a global epoch.
- Resource records use AVAILABLE, CARRIED, DROPPED, CONSUMED and DESTROYED. Terminal transitions remove active records without accumulating tombstones. Reset clears uncarried records and timers; carried records survive with old node reservations detached.
- Pickup reconciles an overdue reset before validating requests. Successful claims remove the world representation before creating the carried representation. Ownership, distance, Power, availability and existing interaction guards remain server-side; GUIDs survive drops.
- Mid-cycle spawning excludes Secret+, preserves configured refill delays and renormalizes eligible weights. Existing highest-rare-per-area and server-wide Divine restrictions remain intact. Placeholder models remain replaceable through the existing model definitions/templates.
- Reusable billboards retain display name, stat/growth, rarity, modifier, enter/exit transitions, dynamic updates and centralized distance/effect management. Explicit MaxDistance is supported. Direct destruction now releases its metadata watcher; shutdown releases all owned connections.
- A top-center countdown displays `RESOURCES RESET IN m:ss`, switching to `RESOURCES RESETTING...` during the transition. Lighting hooks restore prior values on cleanup.
- Secret/Eternal/Divine announcements use widths 360/500/640 and increasing priority. Divine preempts lower-priority announcements; queues, deduplication and audio cleanup are bounded. Eternal/Divine beam hooks and Divine burst/high-priority sound hooks are wired. Sound IDs remain empty pending legitimate audio assets, as permitted by the requested hook scope.

Primary changes: shared FieldState, FieldConfig, ResourceValidation and BillboardData; server ResourceService, SpawnService and CarryService integration; client BillboardService and FieldPresentation. No new persistence schema or purchase behavior was introduced in Phase 2. Existing Phase 1 changes and unrelated user edits were preserved.

## Test evidence

| Test | Actual result |
|---|---|
| Studio unit suite | **114/114 PASS**, including configuration, field state, persistence fake-store cases and nine new Phase 2 cases |
| Weighted simulation | **1,000,000 rolls PASS**: 200,000 seeded uncapped rolls per area; every resource observed; all frequencies within six standard deviations |
| Existing exact weighted-ticket checks | **50,000 tickets PASS** as part of the unit suite |
| Reset/claim interleavings | **1,000 orderings PASS** in the Phase 2 unit suite |
| FieldIntegration, actual server Script | **20 checks PASS**, including an actual 300-second cycle, carried-item survival and reset-boundary/replay rejection |
| FieldRuntimeSmoke, actual server Script | **14 checks PASS**, including actual drop expiry, refill, carried visuals and cleanup |
| BillboardSmoke, actual client LocalScript | **88 assertions PASS**, including all rarity/modifier coverage, MaxDistance, dynamic metadata and connection cleanup |
| FieldPresentationSmoke, actual client LocalScript | **17 checks PASS**, including countdown text, reset lighting, announcement sizing/priority hooks and Stop/Start cleanup |
| ResourceVisualService fixtures | **9 checks PASS** for Secret/Eternal/Divine aura, beam and burst components |
| Final Edit-mode definition/world validation | **0 errors**, five areas, 40 resources, 25 nodes |
| Final source comparison | **55/55 files match** repository sources; no duplicate script paths or temporary test scripts |
| Blockout preservation | **1,412 BaseParts**, geometry digest **1212267917**, identical to the Phase 1 baseline |

Maximum absolute frequency Z scores: Grasslands 1.641, Swamp 1.191, Jungle 1.493, CrystalCave 1.907, Volcano 1.448. Statistical rolls exercise the raw weighted picker; separate deterministic tests cover batch rarity caps and mid-cycle exclusions.

The final Studio console contained definition/resource validation passes and the four live smoke/integration passes above, with no runtime errors. DataService explicitly reported a Studio read-only session with no production DataStore requests. Presentation fixtures exercised reset text/lighting locally without changing server spawn odds; server integration separately crossed the real reset boundary.

## Phase acceptance

| Requirement | Status and evidence |
|---|---|
| Startup identifies stable nodes and populates five areas | **PASSED** — world validation and live runtime checks |
| All eight-resource pools sum correctly and approximate configured weights | **PASSED** — validation, exact tickets and seeded simulation |
| Unique IDs; never two physical models per active record | **PASSED** — claim ordering, live world/carried validation, duplicate/replay tests |
| Carried resource survives hard reset | **PASSED** — actual-cycle server integration |
| Secret+ never mid-cycle respawns | **PASSED** — deterministic eligibility and field tests |
| Pending node timers cancel on reset | **PASSED** — field state and boundary tests |
| Dropped state, expiry, cleanup and node ownership work | **PASSED** — unit and live runtime tests |
| Reset/interacting cannot duplicate an item | **PASSED** — 1,000 orderings and live boundary/replay checks |
| Billboard functionality and zero leaked owned connections after cleanup | **PASSED** — 88 client assertions |
| Countdown, transition hooks and tiered rare announcements | **PASSED** — 17 client checks and nine VFX checks |
| Studio playtests and console inspected; blockout intact | **PASSED** — live results and final Edit-mode verification |

## Limits and handoff

- `tests/Phase2ResetObserver.client.luau` is an additional opt-in observer written before the usage interruption but **NOT RUN**. It is not counted in the passes above; reset behavior is already covered by the actual server cycle plus client presentation tests.
- No two-human multiplayer/load test or production DataStore test is claimed. Purchase infrastructure was not added or certified: the pre-existing Phase 1 limitation remains documented in PHASE1_RESULTS.md.
- Trainer purchase pricing/migration remains unspecified and disabled; final validation reports this existing warning, not a resource-system error.
- UnitTestRunner remains disabled, the previously quarantined template purchase script remains disabled, and no GeneratedGameplay runtime folder or smoke-test fixtures remain in Edit mode.
- Next work requires a separate request. A fresh-player balance/fun playthrough and multiplayer contention testing are useful follow-ups; no later-phase features were started.
