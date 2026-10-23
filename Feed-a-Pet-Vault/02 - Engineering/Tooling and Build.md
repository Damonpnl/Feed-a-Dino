---
type: engineering
status: mixed
last_verified: 2026-10-21
source_paths:
  - default.project.json
  - CLAUDE.md
  - .cursor/rules
---

# Tooling and Build

## At a Glance

Code is Luau synced by Rojo into a Studio place; Cursor and Claude Code edit the files; the Roblox Studio MCP server inspects and tests the live place. Blender is **not** set up. This note lists what was verified operational on 2026-10-21 and what is not.

## Verified Operational

| Tool | Evidence | Notes |
| --- | --- | --- |
| Rojo 7.7.0 | `C:\Tools\Rojo\rojo.exe`; `rojo build default.project.json` built project "Feed a Dino" to an `.rbxlx` (about 739 KB) | Build verification used a temp output outside the repo |
| Git 2.55 | Two worktrees: `Feed-a-Dino` on `phase3-phase4a-snapshot` (`86228f2`) and `Feed-a-Dino-phase3b` on `phase3b` (`44e6506`) | Large uncommitted tree in the main worktree |
| Studio MCP (`user-Roblox_Studio`) | Live calls: `get_studio_state`, `execute_luau` (Edit/Client/Server), `screen_capture` | Configured in the user-level Cursor `mcp.json`; contains secrets, never copy it |
| FFmpeg / ffprobe | `C:\ffmpeg\bin\`, build N-121405 | Used to probe all 255 reference files and extract video keyframes |
| Python 3.13 with Pillow 11.3 | Used for image previews | Reads WebP, which the agent file viewer cannot (AVIF support not verified) |
| Cursor and Claude Code | `.cursor/rules/*.mdc`, root `CLAUDE.md` | Same rules for both tools |

## Not Configured

- **Blender**: not installed on this machine and no Blender MCP server in `mcp.json` (servers present: Roblox Studio, Dune, 21st-dev magic). The `art/` folder is empty. Any Blender-to-Roblox pipeline is a PROPOSAL.
- No CI, no linter config (Selene/StyLua) was found; `.gitignore` is 4 lines.
- No Studio plugin or script mirrors Studio-owned models into git.

## Rojo Sync Workflow

1. `rojo serve` (or `rojo build` for a file) from the repo root; connect the Studio plugin.
2. Only `src/shared`, `src/server`, `src/client`, and `tests/unit` map into the place. Everything else in the place is Studio-owned and saved in the `.rbxl`.
3. After sync, check for duplicate instances (a duplicated `DevTestProtocol_Test` once inflated the count to 8).
4. Do not change the Rojo mapping or project name without approval.

## Test Commands

See [[02 - Engineering/Security, Testing and Diagnostics]]. Short form: in Studio Play, `execute_luau` on the Server DataModel with `require(game.ServerStorage.UnitTest.RunUnitTest)(nil, 30)`.

## Asset Import and Export

**Verified hooks** (read from source):

- `ResourceModelDefinitions` gives each resource model key a fallback. A template in `ServerStorage.ResourceModels` (Studio-owned, not in Rojo) replaces both the world and carried model. `ResourceVisualService` builds the runtime parts.
- `TrainerVisualService.update(station, tier)` replaces the station's `TrainerVisual` child.
- Pet `Visual.ModelKey` is `Placeholder`; scale comes from the growth stage.
- Naming uses existing string ids (`RawMeat`, `ProtoRex`, `TRex`, `TrainingMat`). Do not rename ids to match concept art.

**Proposed pipeline** (UNKNOWN until a Blender setup exists): model to the silhouette in [[03 - Visual Design/Art Direction]]; keep a collision box matching `CatchReach` and the carry attachment, not decorative spikes; import as a Studio-owned model; register the key; leave Rojo code unchanged unless a key must be added. Performance notes already in code: billboards and rare auras are distance-gated (`FieldConfig`, 300/450/600 studs).

## Image and Video Tooling for the Vault

FFmpeg keyframe extraction (`-ss <t> -i clip.mp4 -frames:v 1`) and Pillow previews (max side 720 px). Original references are never moved or modified ([[04 - Reference Research/Reference Manifest]]).

## Constraints and Invariants

- Never copy `mcp.json` contents or API keys into the vault or repo.
- No new tool installs without approval.
- Never write to Studio-owned instances unless asked.

## Open Questions

Whether to add Blender and a Blender MCP; whether to add a linter and CI ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[02 - Engineering/Architecture and Module Map]], [[06 - Agent Workflows/Agent Playbook]].
