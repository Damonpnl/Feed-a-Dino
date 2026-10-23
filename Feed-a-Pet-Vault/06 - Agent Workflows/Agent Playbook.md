---
type: workflow
status: current
last_verified: 2026-10-21
source_paths:
  - CLAUDE.md
  - .cursor/rules/00-project-core.mdc
---

# Agent Playbook

## At a Glance

The procedure for any agent (Cursor or Claude Code) working on Feed a Pet. Hard rules (ownership, authority, no silent renames) live in `CLAUDE.md` and `.cursor/rules/`; this note does not repeat them. It adds the order of work, per-discipline guidance, and when documentation must change. Start from [[00 - Home/Task Router]]; never load the vault wholesale.

## The 11-Step Workflow

1. **Classify** the task: gameplay, UI, 3D asset, economy, persistence, QA, docs, or reference research.
2. **Route.** Open the matching Task Router row. If the task is self-contained (a typo, a local refactor), skip the vault.
3. **Read at most four notes** named by the row. Read more only for a named unresolved dependency.
4. **Inspect current source.** Source files beat notes and phase reports. If they disagree, source wins and the gap goes in [[05 - Development/Bugs and Test Status]].
5. **Inspect live Studio** with the Studio MCP when the task touches instances. Never invent an instance path. Check the Studio mode first; the Edit datamodel is unavailable while Play runs, and do not stop a Play session you did not start.
6. **State constraints and files** before editing: which modules change, which invariants apply, which are Studio-owned.
7. **List assumptions and missing information.** Ask for approval before renaming instances, moving files, changing the Rojo mapping, adding RemoteEvents, DataStores, monetization, or expanding scope.
8. **Implement the smallest complete vertical slice.** Preserve public module interfaces unless authorized.
9. **Verify.** Run the relevant unit filter or Play fixture, or say it was not run. Quote the pass count you saw.
10. **Update documentation** only if behavior, contract, or status changed (rules below).
11. **Summarize** changes, tests, residual risks, and the next step. For a user-facing change, fill [[07 - Templates/Implementation Handoff]].

## Gameplay Work

- Entry notes: [[01 - Game Design/Guardians and Carrying]], [[01 - Game Design/Resources and Field Resets]], [[02 - Engineering/Architecture and Module Map]].
- Pure calculators (`MovementCalculator`, `GuardianChase`, `GuardianState`, `FieldState`) take no Roblox services and are tested in `tests/unit/Cases`. Put new rules there first.
- Server services own live state. Clients render.
- Do not change `MovementConfig`, `GuardianConfig`, `EconomyConfig`, trainer prices, or resource weights unless the task is a balance task; record old and new values as a decision.
- Do not treat disturbance-meter values as live (D4).
- Check the invariants that most changes break: single carry, safe-zone boundary drops the threat but does not bank the item, reset forfeits items for carriers still in the field.

## UI Work

- Entry notes: [[03 - Visual Design/UI Screens and Contracts]], [[03 - Visual Design/UI Design System]], [[02 - Engineering/Data, Networking and Persistence]].
- The HUD is built in code in `UIController.client.luau` from server attributes and the existing remotes. A new screen reads attributes; it does not compute rewards or ownership.
- Steal an Egg looks are reference observations in [[04 - Reference Research/Steal an Egg Analysis]]; they are not a ticket to restyle.
- Check desktop and mobile layout. If you cannot capture a screenshot, say so; the Studio agent view renders the 3D world black in Play and cannot save files.

## Asset Work

- Entry notes: [[03 - Visual Design/Creatures and Asset Specifications]], [[03 - Visual Design/Art Direction]], [[03 - Visual Design/Visual Reference Gallery]].
- Studio owns models, packages, animation. Rojo owns code. Do not write models into Workspace from a script unless asked.
- Keep stable model keys and gameplay ids; display names are separate.
- Blender is not installed and no Blender MCP exists; do not promise a Blender step.
- Open one reference image, never a folder.

## When to Use an Isolated Git Worktree

Use a separate worktree when two agents may both edit `CarryService`, `GuardianService`, `PlayerData`, `DataService`, or `MovementConfig`, when an experiment may be thrown away, or when a long task must not disturb the dirty main tree. The main tree is large and uncommitted, so ask before any worktree command that touches it. Do not switch branches in place. Say which files you will touch before editing.

| Agent role | May edit | Needs a handoff to edit |
| --- | --- | --- |
| Gameplay | `src/server`, `src/shared` calculators | `UIController` layout, Studio models |
| UI | `src/client` | `PlayerData`, `DataService`, resource weights |
| 3D | Studio models, model keys | Server authority, remotes |
| QA | `tests/` | Production defaults in `src/` |
| Balance | Config modules | Save migrations |

## Documentation Rules

Update docs only after the behavior is in source and a check was run (or you said it was not).

1. A number, price, or ratio changed: do not paste it into a note; link the Luau symbol.
2. An invariant or contract changed: edit the single system note named by the Task Router.
3. A path in the Router is wrong: fix that one row.
4. Status changed: edit `docs/CURRENT_STATE.md` and the matching line in [[05 - Development/Current State and Roadmap]].
5. A decision changed: add or edit a row in [[05 - Development/Decisions and Open Questions]].
6. A bug or discrepancy was found: add it to [[05 - Development/Bugs and Test Status]].
7. Skip the vault for comments, renames inside a function, and behavior-preserving refactors.
8. Do not write a planning document for a small change. Refresh [[05 - Development/Vault Health]] only on a vault audit.
9. Mark evidence honestly: VERIFIED IMPLEMENTATION, CONFIRMED DESIGN, REFERENCE OBSERVATION, PROPOSAL, UNKNOWN. Set `last_verified` only when you verified the note.

## Common Failure Modes

- Trusting a phase report over source (the 16-32 speed curve and the "capped at 18" claim are both stale).
- Copying Steal an Egg numbers into configuration.
- Citing the historical 402 test count as your result.
- Editing a Studio-owned instance because it was convenient.

## Related Notes

[[00 - Home/Start Here]], [[05 - Development/Session Handoff]], [[02 - Engineering/Security, Testing and Diagnostics]].
