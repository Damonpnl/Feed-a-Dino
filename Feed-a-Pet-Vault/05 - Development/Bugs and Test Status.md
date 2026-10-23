---
type: status
status: mixed
last_verified: 2026-10-21
source_paths:
  - tests/unit/Cases
  - tests/unit/RunUnitTest.luau
  - tests/unit/PlayFixtures
  - docs/CURRENT_STATE.md
  - docs/DEVELOPER_TESTING_REPORT.md
  - docs/FAST_HEIST_TUNING_REPORT.md
---

# Bugs and Test Status

## At a Glance

**VERIFIED IMPLEMENTATION:** the unit suite reported **402 passed, 0 failed across 23 case modules** on 2026-10-21 (Studio instance `fdc70eea`, Play mode, via `UnitTestRunner`). Earlier the same day, `DevTestProtocol` reported 4 of 4. No other gameplay test was re-run during the vault work. Opt-in Play fixtures under `tests/` carry their own results in the phase reports; treat those as historical. An agent must cite its own run, not this number.

## Discrepancies Between Documents and Source

Source code wins. IDs `D1` to `D8` are stable; other notes link here.

| ID | What disagrees | Truth today | Action |
| --- | --- | --- | --- |
| D1 | `docs/CURRENT_STATE.md` Phase 5B paragraph describes speed milestones 16-32 and a carry cap of 18, while its header says fast-heist 22-72 supersedes it | `MovementConfig` holds the fast-heist curve (22-72 unloaded, 22-52 carrying, Slow Mode 16) | Docs owner: edit the paragraph or label it historical |
| D2 | Names: pet-facing "Pet", code-facing `Monster*`, Rojo project "Feed a Dino", `MonsterProgress_v1`, HUD `MonsterHud` | Intentional until a rename task | None |
| D3 | Older resource docs say carried loot survives a field reset | The lockdown forfeits loot while the carrier is inside the field and evacuates everyone ([[01 - Game Design/Resources and Field Resets]]) | Treat the fast-heist report as newer |
| D4 | `GuardianConfig` still holds the Phase 3 disturbance meter values (8, 10, 12, 15, 20, 25, 35; threshold 100) | **Inert.** Phase 3B wakes guardians immediately on theft; `PHASE3_RESULTS.md` describes the old model ([[01 - Game Design/Guardians and Carrying]]) | Do not tune these; decide later whether to delete |
| D5 | `MutationDefinitions` marks family ids `Enabled = false`, yet evolution reads `EvolutionFamilies` and catalyst tags | Both true; separate mechanisms | None |
| D6 | `docs/DEVELOPER_TESTING_REPORT.md` line 24 says the base speed is "capped at 18" while carrying | Stale; carrying uses its own milestone column and penalties | Docs owner |
| D7 | `FAST_HEIST_TUNING_REPORT.md`: kinematic comparison C found almost no straight-line escapes and says that is not acceptable-difficulty evidence | Live config is still the fast-heist config. Human escape rate unknown | Playtest (REC-001) |
| D8 | Earlier vault notes said FFmpeg was unavailable and the clips uninspected | Wrong. FFmpeg and ffprobe exist at `C:\ffmpeg\bin`; all four clips were decoded 2026-10-21 | Corrected in vault |

## Verified Defects and Hygiene Items

| ID | Item | Evidence | Severity | Next step |
| --- | --- | --- | --- | --- |
| B-001 | Guardian disturbance config is dead weight | See D4 | low | Owner decides |
| B-002 | Rare spawn `SoundId` values are empty | `docs/CURRENT_STATE.md` line on `FieldConfig.RarePresentation.SoundId` | low | Needs audio assets |
| B-003 | Three temporary folders exist in `ServerStorage`: `Phase3BPreservedTests`, `FastHeistFixturesTemporary`, `FastHeistRegressionsTemporary` | `execute_luau` listing of the running server DataModel on 2026-10-21 (Play copy of Edit state) | low | Confirm in Edit mode, then delete only with approval; they are Studio-owned |
| B-004 | Edit-mode state of Studio was not inspected this pass | Studio was in Play; Edit datamodel unavailable | info | Re-check after Play stops |

I did not verify any UI overlap defect this pass. `PHASE5A_REPORT.md` and `PHASE5B_REPORT.md` record overlap fixes for the training panel and Slow Mode button; no current screenshot confirms the final layout (see the visual gap in [[05 - Development/Vault Health]]).

## Untested or Unverified Areas

Fast-heist follow-up, 2026-10-23: 403 units and the documented Phase 1–5B regression
queue passed; actual two-client reset, movement and late-join fixtures passed 78/20/13
checks. Final Edit inspection matched 120 mapped sources and unchanged saved part/node
counts. Task-tagged automatic fixtures were removed, with repository sources retained.
The landscape phone reset warning fits and is readable but overlays the existing pet
HUD; 3D remains black in MCP captures. Full mobile layout and human encounter fairness
are not approved. See `docs/FAST_HEIST_TUNING_REPORT.md` and raw evidence there.

- Published-server DataStore persistence and two-server rejoin: not tested.
- Physical mobile layout and touch play: not tested (`PHASE5B_REPORT.md` says mobile QA is pending).
- Human escape rates at fast-heist speeds: not established.
- Fresh-player balance and fun playthrough: not performed (`CURRENT_STATE.md`).
- Studio 3D screenshots: the agent view rendered the world black in Play; no image stored.

## Test Infrastructure

| Layer | Where | How to run | Notes |
| --- | --- | --- | --- |
| Pure unit | `tests/unit/Cases/*_Test.luau` (23 modules) | `UnitTestRunner` is Disabled by default in `default.project.json`; enable it for a run | Includes Economy, Movement, FastHeist, GuardianChase, GuardianState, GuardianJourney, FieldState, FieldRoller, CarryDebuff, SessionStore, DevTestProtocol |
| Play fixtures | `tests/*.server.luau`, `tests/unit/PlayFixtures` | Opt-in; run one at a time in Play | Phase 1 through 5B plus fast-heist scripts; some need two Studio clients |
| Client smoke | `tests/*.client.luau` | Opt-in | Presentation and HUD checks |
| Developer panel | `DevTestService`, `DevTestConfig` | Studio only; memory backend | Never touches the production DataStore ([[02 - Engineering/Security, Testing and Diagnostics]]) |

Case-name lists should be read from the folder, not copied here. Read `tests/unit/RunUnitTest.luau` for how filters work.

## Rules

1. Report only a count you saw in the console.
2. Do not delete a test fixture to make a suite pass.
3. Opt-in Play scripts stay opt-in.
4. If a doc disagrees with source, add a row to the discrepancy table, not a second copy of the number.

## Related Notes

[[05 - Development/Current State and Roadmap]], [[05 - Development/Decisions and Open Questions]], [[02 - Engineering/Security, Testing and Diagnostics]].
