# Feed a Pet

Roblox game (Luau, Rojo). Loop: steal one physical resource from a guarded field, escape the guardian, feed the pet, train Power so you can carry heavier loot farther. Product name is **Feed a Pet**. The repo folder is `Feed-a-Dino`, the Rojo project is `Feed a Dino`, and many modules say `Monster` (save key `MonsterProgress_v1`, HUD `MonsterHud`). Do not rename any of it unless asked.

Always-on rules are in `.cursor/rules/project-core.mdc`. This file is the short orientation for Claude Code; do not fork a second rule set.

## Orientation

| Path | Owner | Contents |
| --- | --- | --- |
| `src/shared` | Rojo | Definitions and pure calculators (no Roblox services) |
| `src/server` | Rojo | Services with authoritative live state (`GameBootstrap.server.luau` starts them) |
| `src/client` | Rojo | UI, input, presentation |
| `tests/unit` | Rojo | Pure unit cases mapped to `ServerStorage.UnitTest` |
| `tests/*.luau` | opt-in | Play fixtures and smoke scripts; never automatic |
| `docs/` | docs | Phase reports and `CURRENT_STATE.md` (partly stale, source wins) |
| Workspace, models, terrain, animation, lighting | Studio | Never edit unless asked |
| `Feed-a-Pet-Vault/` | docs | Obsidian knowledge base |
| `references/` | reference | Steal an Egg material, not a specification |

## Critical Invariants

- The server owns carry, feeding, inventory, affinity, evolution, rarity and mutation rolls, Cash, Power, upgrades, and saves. Clients request and render; never trust client values.
- One carried resource per player. The safe-zone boundary drops the guardian threat; it does not bank the item.
- A field reset forfeits loot for carriers still in the field and evacuates the field.
- Studio Play uses the temporary `StudioMemory` backend. Never open the production DataStore `MonsterProgress_v1` from Studio.
- Pure calculation modules take no Roblox services and are deterministic unless randomness is injected.
- Use stable string ids; keep display names separate. Preserve public module interfaces.
- Do not silently rename instances, move files, change the Rojo mapping, add RemoteEvents or DataStores, modify Workspace, add monetization, or expand scope. Ask first.
- Provisional tuning (speed milestones, carry cap, guardian baselines, trainer prices) is not release-approved. Do not rebalance without a balance task.

## Verified Commands

Windows PowerShell. Tools verified on 2026-10-21.

```
C:\Tools\Rojo\rojo.exe --version          # 7.7.0 (pinned in rokit.toml)
C:\Tools\Rojo\rojo.exe build default.project.json -o <temp>.rbxlx
C:\Tools\Rojo\rojo.exe serve              # standard workflow; not run in the vault audit
git status --short
```

Build to a temp path outside the repo (`build.rbxlx` is git-ignored but not authoritative). There is no linter, formatter config, or CI.

## Testing Expectations

- Unit suite: in Studio Play, run `require(game.ServerStorage.UnitTest.RunUnitTest)(nil, 30)` on the Server DataModel (or enable `UnitTestRunner`, which Rojo marks Disabled). Pass a case-name filter as the first argument.
- Last measured result: 402 passed, 0 failed, 23 modules (2026-10-21). Quote the count you saw, never this one.
- Play fixtures under `tests/` are opt-in; run one at a time and read the console of every client.
- After Rojo sync, check Studio for duplicate script instances.
- If you did not run a check, say so.

## Using the Vault

Never load the vault whole. Open `Feed-a-Pet-Vault/00 - Home/Task Router.md`, take the single row matching the task, read at most 2 to 4 notes, then read source. Skip the vault for self-contained edits. Workflow and documentation-update rules: `Feed-a-Pet-Vault/06 - Agent Workflows/Agent Playbook.md`.

Visual tasks: open one reference image, listed in `Feed-a-Pet-Vault/04 - Reference Research/Reference Manifest.md` or the gallery, never a folder. Studio screenshots are agent-view only; the 3D world rendered black in Play, so do not claim a visual check you could not make.

## Anti-Drift Rules

1. Current source beats notes and phase reports. Record disagreements in `Feed-a-Pet-Vault/05 - Development/Bugs and Test Status.md`.
2. Steal an Egg observations are reference only. Never present them as Feed a Pet features or copy their art, names, or numbers.
3. Do not paste live numbers from Luau into notes; point at the symbol.
4. Label claims: verified implementation, confirmed design, reference observation, proposal, unknown.
5. Do not write planning documents for small changes.
6. Do not commit, push, or switch branches unless asked. The main tree has a large uncommitted state.
7. Never copy `mcp.json` or any secret into the repo or vault.
8. Use an isolated git worktree only when two agents may edit the same service, and ask before touching the dirty main tree.

## After a Verified Change

Update only the one note whose contract changed, plus `docs/CURRENT_STATE.md` if status changed. Skip docs for behavior-preserving refactors.
