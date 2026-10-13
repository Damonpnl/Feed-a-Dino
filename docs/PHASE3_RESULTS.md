# Phase 3 — carry and guardian gameplay results

Verified 2026-10-11 through the official Roblox Studio MCP against Feed a Dino, place **104154372052853**. **Phase 3 acceptance: PASSED.** No Phase 4 implementation, publishing, live save access, new inventory, purchase flow or progression values were introduced.

## 1. Implemented features

The existing Phase 2 resource GUID/state engine now drives the complete pickup → carry → guardian disturbance → telegraphed hazard → forced drop → recovery loop. Successful acquisition is limited to one major resource, checks authoritative Power and live-character proximity, and preserves the resource record through carrying/dropping. Exact Power succeeds; one below fails without changing the resource.

CarryService owns the physical attachment, HUD attributes and the single configured movement calculation. It restores speed on resolution and guards character identity, including callbacks that arrive after respawn. Failed attachment rolls back to one original world model. Death/reset return valid drops; disconnect releases a still-carried resource, while an already-resolved drop retains normal expiry. Field resets preserve carried records.

GuardianService uses one shared state machine and five configurations: T-Rex charge, crocodile lunge, gorilla expanding slam, Triceratops charge and dragon cross-lane fire sweep. Warning footprints and active collision use the same geometry. Server-swept contact handles skipped frames, processes each player once per activation, and forces drops without damage, HP, weapons, knockback or kill rewards.

Minimal carry/guardian HUDs, authoritative compact Power toasts, keyboard/gamepad/touch drop input, camera feedback and reusable animation/audio/VFX hooks are integrated into the existing client architecture. Streaming removal/re-entry releases and recreates only the necessary guardian listeners.

## 2. Files changed in this phase

Paths are repository-relative. Existing uncommitted Phase 1/2 work, user context replacement and unrelated `art/` content were preserved.

**Created production modules:**

- `src/shared/GuardianConfig.luau` — locked disturbance plus isolated temporary encounter tuning and validation.
- `src/shared/GuardianState.luau` — deterministic legal transitions, deadlines and cancellation.
- `src/shared/GuardianGeometry.luau` — warning geometry and swept server contact calculations.
- `src/shared/NumberFormat.luau` — shared compact requirement formatting.
- `src/client/GuardianPresentation.luau` — state/meter HUD, presentation hooks, camera and streaming cleanup.

**Modified production modules/controllers:**

- `src/server/CarryService.luau` — character-bound lifecycle, common forceDrop path, attachment rollback, movement and carry attributes.
- `src/server/GuardianService.luau` — replaces the prototype radius attack/threshold with the shared framework.
- `src/server/ResourceService.luau` — once-per-acquisition acknowledgement, authoritative Power notice and accessible drop fallback.
- `src/server/SpawnService.luau` — notifies guardians only after completed acquisition.
- `src/shared/FieldState.luau` — monotonic per-record ClaimVersion; existing resource identity/ownership unchanged.
- `src/shared/DefinitionValidation.luau` — validates guardian configuration at startup.
- `src/client/CarryController.client.luau` — one context action for keyboard/gamepad/touch.
- `src/client/UIController.client.luau` — carry card and temporary Power notification.
- `src/client/EffectsController.client.luau` — starts/stops the reusable presentation module instead of restoring stale camera frames.

**Created tests:** GuardianState_Test, GuardianGeometry_Test and NumberFormat_Test under `tests/unit/Cases`; Phase3Integration, Phase3Presentation, Phase3Multiplayer server/client pair, Phase3PresentationCleanup and Phase3Rollback under `tests/`.

**Documentation:** this report, PHASE3_GAMEPLAY.md, CURRENT_STATE.md and `docs/audit/phase3-verification.json`.

**Deleted:** no repository source files in Phase 3. Removed five identical extra Studio ModuleScript copies (GuardianPresentation, GuardianConfig, GuardianState, GuardianGeometry, NumberFormat), retaining one repository-matching copy each. Those redundant copies are recoverable from their identical repository sources. Temporary multiplayer test scripts were removed; other Play fixtures disappeared on stopping tests.

## 3. Integration and guardian configuration

No second inventory or ownership implementation was added. ResourceService/FieldState remain authoritative. CarryService's existing `get`, `give`, `drop`, `consume` and `consumeOwned` integration remains compatible; `forceDrop(player, character, reason)` centralizes gameplay consequences. No new RemoteEvents were added: only existing DropCarried and FieldRareSpawn remain, both with active consumers.

After each claim, ClaimVersion increments on the same record. GuardianService validates that the player actually carries that GUID, then ResourceService acknowledges the version once. Replayed/stale notifications cannot disturb a guardian; legitimate recovery receives a new version. State mutation and pickup/visual rollback paths do not yield.

The legal sequence is SLEEPING → DISTURBED → WARNING → HAZARD → COOLDOWN → SLEEPING. Common through Cosmic add **8, 10, 12, 15, 20, 25, 35**; threshold **100**; Secret/Eternal/Divine wake immediately. Area meters are shared across players but independent of each other. Active/cooldown pickups cannot overlap or queue another awakening.

| Area | Hazard | Warning / active / cooldown (seconds) |
|---|---|---|
| Grasslands | Straight charge sweep | 1 / 1.2 / 8 |
| Swamp | Forward lunge | 0.9 / 0.8 / 8 |
| Jungle | Expanding filled-disc shockwave | 1.25 / 1.4 / 8 |
| CrystalCave | Independent straight charge | 0.75 / 0.9 / 8 |
| Volcano | Cross-lane fire sweep | 1.25 / 1.8 / 10 |

Unspecified footprint dimensions, active durations and cooldowns are explicitly temporary graybox tuning. Defaults: no disturbance decay, no queued wake while busy, reset to zero after cooldown/field reset. Full geometry, lifecycle policies and presentation-hook contracts are documented in [PHASE3_GAMEPLAY.md](PHASE3_GAMEPLAY.md).

## 4. Executed Studio tests

| Test | Result | Evidence scope |
|---|---|---|
| Unit suite | **149/149 PASSED** | Existing 114 Phase 1/2 cases plus 35 new state/geometry/format cases; rerun after final carry rollback fix |
| Phase3Integration | **175 checks PASSED** | Actual single-player server services: Power boundary, duplication, attachment/speed, all five real timed attacks, warning geometry, recovery within attack, outside-region safety, respawn/stale callback and consumption |
| Phase3Presentation | **10 checks PASSED** | Actual paired client: server Power toast, carry name/rarity/empty state, five wake/attack hooks, drop hooks and Stop/Start |
| Phase3Multiplayer | **26 checks PASSED** | **Two actual Studio clients**, distinct player IDs; simultaneous same/different-resource claims, cross-player recovery, shared disturbance, one awakening, both-carrier hazard hits, reset/disconnect during active hazard and forged client remote payloads |
| Phase3PresentationCleanup | **43 checks PASSED** | 20 client stream-out/re-entry cycles, exact listener counts, zero connections after Stop, camera restoration and idempotent Start |
| Phase3Rollback | **8 checks PASSED** | Intentional attachment failure: original record restored, no partial visual, no disturbance, later pickup succeeds, configured movement restored |
| FieldIntegration regression | **20 checks PASSED** | Actual synchronized reset boundary and ten-second transition; carried GUID survives; fresh nodes do not lose ownership |
| FieldRuntimeSmoke regression | **14 checks PASSED** | Actual 20-second drop expiry/refill, physical model/weld/speed, external cleanup and unique records |
| Phase1Lifecycle + Phase1Network regression | **14 checks PASSED** | 40 actual forged/replayed client drop requests, death, respawn and actual test-player disconnect; session/base/carry cleanup |
| Final source verification | **63/63 PASSED** | Normalized UTF-8 source byte lengths and DJB2 fingerprints match Studio; zero duplicate script paths after cleanup |
| Final world/config inspection | **PASSED** | 1,412 BaseParts, original geometry digest 1212267917, 25 nodes, zero definition errors; map unchanged |
| Rojo build / whitespace check | **PASSED** | Validation build outside repository; no whitespace errors |

The multiplayer test was launched through official MCP execution using Roblox's documented [StudioTestService.ExecuteMultiplayerTestAsync](https://create.roblox.com/docs/reference/engine/classes/StudioTestService), not simulated player tables. Its structured returned result was `{Result="PASS", PassedChecks=26, Mode="Two actual Studio clients"}`. This is automated local networking coverage, not two human playtesters or production latency/load testing.

The first multiplayer fixture attempt failed at cross-player recovery while initial base placement was still pending. The fixture was corrected to wait for both assignments/deferred placement and move players immediately before the request; the same recovery assertion then passed. A duplicate launch attempt was rejected because the first test was still running. Neither issue was hidden or counted as a pass.

Console inspection found no new gameplay-breaking errors. The rollback fixture intentionally emits `Carry failed: ... Intentional Phase3 rollback fixture`, demonstrating protected cleanup. Lifecycle fixtures intentionally kick test clients. DataService reported Studio read-only mode with **no production DataStore requests**. Existing trainer pricing/migration warning remains unrelated to this phase.

## 5. Acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| One-major-resource limit | **PASSED** | FieldState unit cases and live second-pickup rejection |
| Authoritative, correct Power requirements | **PASSED** | Exact / minus-one live checks; forged payload ignored; compact format unit/client checks |
| Atomic pickup/drop | **PASSED** | Two-client one-winner test, repeated drop rejection and rollback fixture |
| Carry visuals and slowdown | **PASSED** | Attached model/weld, one physical representation, configured speed and restoration |
| Carry HUD and insufficient-Power notifications | **PASSED** | Paired client assertions and captured HUD |
| Five guardians initialize | **PASSED** | Startup validation and actual five-instance check |
| Disturbance values match configuration | **PASSED** | Seven exact-rarity unit cases and multi-client summed contributions |
| Secret+ immediately wakes | **PASSED** | Separate deterministic Secret/Eternal/Divine state cases; server reads authoritative resource rarity |
| Reliable guardian transitions | **PASSED** | Five timed unit lifecycles and five live encounters; reset cancellation tests |
| Five server-authoritative hazards | **PASSED** | Five actual forced-drop encounters; swept/rotated/outside/height geometry unit cases |
| Hazard drops without traditional damage | **PASSED** | Health unchanged in all five encounters and both multiplayer carriers |
| Other players can collect drops | **PASSED** | Actual second-client recovery of original GUID, including recovery during hazard |
| Reset/disconnect safety | **PASSED** | Live respawn/stale-callback checks, death/disconnect regression and active-hazard multiplayer lifecycle |
| Field reset preserves carries | **PASSED** | Actual field-reset regression plus deterministic ownership tests |
| Concurrent interactions cannot duplicate | **PASSED** | Real two-client same/different-item requests; repeated payloads and runtime uniqueness validation |
| No new gameplay-breaking Studio errors | **PASSED** | Inspected play output; only explained intentional fault/kick messages |
| DataService and Phase 2 spawning remain functional | **PASSED** | Full unit suite, isolated persistence tests, real reset/drop/refill and session-cleanup regressions |

## 6. Handoff and remaining limits

Studio is left in Edit mode, automatic unit runner disabled, previous template quarantine intact, and no temporary gameplay/test scripts remain. The original blockout is unchanged. No publish or live-save operation was performed. No Phase 4 work was started.

Final guardian/resource models, animation clips, audio IDs and polished VFX remain placeholders/hooks by design. Physical mobile/gamepad play, prolonged load testing and production latency/physics exploitation are **NOT TESTED**. Existing missing purchase infrastructure and unspecified trainer prices/migration remain Phase 1 limitations; they were not modified or misrepresented as verified here.

The Roblox unit-test skill guided deterministic tests in the existing harness. Plugin-management guidance was used only to check the temporarily unavailable Studio connection; it required no plugin/permission changes. The requested model/reasoning setting could not be changed or verified through exposed tools, as disclosed before implementation.
