---
type: engineering
status: mixed
last_verified: 2026-10-21
source_paths:
  - tests/unit/RunUnitTest.luau
  - tests/unit/Cases
  - tests
  - src/server/DevTestService.luau
  - src/server/DevTestConfig.luau
  - src/shared/DevTestProtocol.luau
  - src/client/DevTestPanel.client.luau
  - docs/DEVELOPER_TESTING_REPORT.md
  - docs/PLAYTEST_CHECKLIST.md
  - docs/FAST_HEIST_TUNING_REPORT.md
---

# Security, Testing and Diagnostics

## At a Glance

The server is authoritative; tests are unit cases plus opt-in Play scripts; a Studio-only developer panel drives scenarios. This note separates tests that **exist** from tests that **passed**.

## Security Boundaries

**VERIFIED IMPLEMENTATION.** The server owns ownership, feeding validation, inventory consumption, affinity totals, evolution outcomes, rarity and mutation rolls, Cash, Power, upgrades, and persistence. Clients request and render.

Exploit-sensitive operations and their guards:

| Operation | Guard |
| --- | --- |
| Pickup | Claim record by GUID, then `CarryService.give`; owner, distance, Power, single-carry checks |
| Feed / evolve | Ticket bound to character, 30 s expiry, proximity, 0.2 s rate limit, pending-choice check |
| Train / upgrade | 12-stud distance, exact next-tier check |
| Drop / Slow Mode | Payload-free or boolean; server recomputes speed |
| Field closure | `FieldLockdown` re-evacuates every reconcile |
| Developer commands | Studio only; see below |

Client-written attributes do not change saves.

## Developer Testing Interface

Studio only (`docs/DEVELOPER_TESTING_REPORT.md`). The `DevTest` RemoteFunction exists only if `RunService:IsStudio()` and `DevTestConfig.Enabled`; each mutation also needs the `StudioMemory` backend, an allowed runner (`RunnerUserIds`, empty means everyone in that Studio server), and `DevTestProtocol.validate`. Command groups: Session, Player, Pets, Items, Trainers, Guardians, Travel, Scenarios. Destructive commands need `Args.Confirm == true`. Production remotes carry no cheat arguments. The panel (`DevTestPanel`, red `TEST MODE` label, **Dev panel** button) is a tool, not game HUD.

## Test Infrastructure

- **Unit cases:** 23 modules in `tests/unit/Cases` (Rojo: `ServerStorage.UnitTest`). Runner: `tests/unit/RunUnitTest.luau`, signature `(filter, timeout)`, returns `{run, passed, failed}`.
- **Opt-in Play scripts** in `tests/` (not startup scripts): phase integration (`Phase1` to `Phase5B`), multiplayer (`Phase3Multiplayer`, `Phase3BMultiplayer`, `Phase4AMultiplayer`, `Phase4BMultiplayer`, `Phase5AMultiplayer`, `Phase5BMultiplayer`, `GameplayTuningMultiplayer`), fast-heist (`FastHeistAbilities`, `Benchmark`, `ClientPhysics`, `Physics`, `Profile`, `Reset`, `Warnings`), field (`FieldIntegration`, `FieldRuntimeSmoke`, `RadialLayout`), `StudioMemoryFeeding`. `tests/UnitTestRunner.server.luau` is disabled in Rojo; do not enable it as shipped code.
- **Verified command** (Studio Play server, MCP `execute_luau` with `datamodel_type: Server`):
  `require(game.ServerStorage.UnitTest.RunUnitTest)(nil, 30)` for the full suite, or a name filter such as `"Guardian"`.
- MCP `execute_luau` loads modules in its own environment; read live player attributes or call real remotes instead of requiring `DataService`.

## Test Status

| Evidence | Result | Date | Nature |
| --- | --- | --- | --- |
| Full unit suite, live Play server (Studio instance `fdc70eea`) | **402 run, 402 passed, 0 failed**, 23 case modules | 2026-10-21 | measured in this vault pass |
| `docs/FAST_HEIST_TUNING_REPORT.md` | 402 passed, 0 failed | 2026-10-21 | report-cited, matches |
| `DevTestProtocol_Test` | 4 passed | 2026-10-19 | measured earlier in the dev-panel task |
| Multiplayer, cloud rejoin, mobile | not run in this pass | - | UNKNOWN |

Whether the open Studio place matched the files on disk was not independently compared; Rojo sync was assumed. Full detail: [[05 - Development/Bugs and Test Status]].

## Multiplayer Procedure

Two Studio clients are needed for `TwoCarriers` and the `*Multiplayer` scripts. Start Play with at least two players (Test tab, Local Server), run the script, read both consoles, and note duplicate or dangling Studio instances after sync. `docs/PLAYTEST_CHECKLIST.md` lists the manual human checks.

## Studio Diagnostics Workflow

1. `get_studio_state` to confirm mode (Edit or Play) before acting.
2. `execute_luau` for read-only inspection; do not write Workspace.
3. `get_console_output` after Play for warnings.
4. `screen_capture` returns the viewport image to the agent only (no file). In Play it rendered the HUD but the 3D world was black on 2026-10-21 (see [[03 - Visual Design/Visual Reference Gallery]]).

## Constraints and Invariants

- Never claim a pass you did not see. Cite the command and counts.
- Studio must never touch `MonsterProgress_v1`.
- Do not add test code to production startup.

## Open Questions

Does a published-server cloud rejoin pass? Human escape rates at current speeds? Mobile layout? ([[05 - Development/Decisions and Open Questions]])

## Related Notes and Source Files

[[02 - Engineering/Tooling and Build]], `docs/STUDIO_MEMORY_FEEDING_FIX.md`.
