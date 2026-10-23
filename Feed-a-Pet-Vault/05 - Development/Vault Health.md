---
type: status
status: current
last_verified: 2026-10-21
---

# Vault Health

## At a Glance

Measured on 2026-10-21 by script after the migration. Refresh this note only on a vault audit, not for local edits ([[06 - Agent Workflows/Agent Playbook]]).

## Measured Counts

| Metric | Value |
| --- | --- |
| Markdown notes | 33 (27 substantive, 6 templates) |
| Wikilinks | 233 total, 0 unresolved |
| Embeds | 57 total, 40 unique images, 0 unresolved |
| Attachments on disk | 40 images, 0 unreferenced |
| Notes not linked from any other note (excluding templates) | 0 |
| Mermaid diagrams | 7 (4 flowchart, 2 stateDiagram-v2, 1 sequenceDiagram); fences balanced; **not rendered** in Obsidian by the audit |
| Backticked file references checked against the repo | 106 exact filenames and paths, 0 missing (globs, extensions, and the user-level `mcp.json` excluded) |
| Frontmatter parsed | 33 of 33 valid YAML; `last_verified` present in all 27 substantive notes, absent by design in templates |
| Reference manifest rows | 255 (251 images, 4 videos) |
| Reference images itemized as inspected | 32 (25 this pass, 7 earlier) |
| Videos decoded | 4 of 4 (62, 140, 90, 35 s); keyframes stored: 12 |
| Stale phrases from the old vault (old note names, "FFmpeg unavailable") | 0 matches in the vault, `CLAUDE.md`, and `.cursor` |
| Word counts | Start Here and Task Router within their limits; the 27 notes range from 269 (Session Handoff) to 1,309 words (Reference Manifest; Vault Health itself is included in the 27) |

Word counts: the architecture notes are shorter than the 1,500 to 2,500 word target for complex architecture notes. I did not pad them; they point at source files for detail.

## Stale Claims Outside the Vault

These live in repo docs, not the vault; see [[05 - Development/Bugs and Test Status]]: D1 (speed prose in `docs/CURRENT_STATE.md`) and D6 (cap of 18 in `docs/DEVELOPER_TESTING_REPORT.md`).

## Visual Coverage Matrix

| Subject | Original reference available | Current Feed a Pet screenshot | Added to vault | Missing |
| --- | --- | --- | --- | --- |
| Main HUD | yes (REF-IG-017, REF-GD-062, clip keyframes) | no | yes | Feed a Pet HUD capture |
| UI screens (feed, evolve, trainer) | Index and shop only | no | yes | Feed a Pet screens; reference for evolution UI |
| World overview | yes (REF-IG-001, REF-IG-014, REF-GD-035) | no | yes | Feed a Pet overview capture |
| Zones | yes for six Steal an Egg biomes (flat art and one lane view) | no | yes | Swamp and crystal-cave reference; Feed a Pet zone captures |
| Guardians | yes (7 renders; no chase footage) | no | yes | Chase footage; Feed a Pet guardian previews |
| Pets | yes (bear, shop card) | no | yes | Feed a Pet pet previews |
| Resources | eggs and a mutation icon (not applicable content) | no | yes | Feed a Pet resource previews |
| Catalysts | none identified among inspected files | no | no | All |
| Training equipment | yes (treadmill ladder, REF-GD-058) | no | yes | Feed a Pet trainer previews |
| Other (marketing, icons) | yes | no | yes | none required |

**Why no Feed a Pet screenshots:** Studio MCP `screen_capture` returns an agent-only view and cannot save a file, and the 3D world rendered black in Play. No Feed a Pet image was synthesized. Blender previews are impossible (not installed).

## Retrieval Simulations (read-only, 2026-10-21)

Method: follow the Task Router row, count words of the notes it names, check that every cited source file exists. Words are a proxy; no token usage was measured because the tools expose none.

| Scenario | Notes loaded (words) | Source files named, all present | Gap found | Fix applied |
| --- | --- | --- | --- | --- |
| A. Change guardian pursuit, preserve carry and safe-zone invariants | Router, Guardians and Carrying, Resources and Field Resets (about 1,980) | 11 of 11 | The Guardian row did not name `CarryService`, where the carry invariants live | Row now lists `CarryService` |
| B. Polished evolution UI on existing contracts | Router, UI Screens and Contracts, Pets, Feeding and Evolution, UI Design System (about 2,860) | 8 of 8 | The UI row did not point to the remote payload note | Row now lists Data, Networking and Persistence as support |
| C. New creature model per art direction and pipeline | Router, Creatures and Asset Specifications, Art Direction, Tooling and Build (about 2,820) | 5 of 5 | Some Tooling content (Rojo workflow) is not needed; the note carries the Blender-not-installed constraint that is needed | none |

Traceability: every claim that cites a source resolves to an existing file. Verifiability: the guardian and evolution tasks have unit modules named in the Router; the model task has no automated check (Studio visual only).

## Known Limits of the Audit

- The simulations were reasoning exercises, not independent agent runs.
- Edit-mode Studio state was not inspected (Play was running).
- The earlier statement that FFmpeg was unavailable was wrong ([[05 - Development/Bugs and Test Status]] D8).
- Clip audio was not examined.

## Backups

The pre-migration vault copy (43 notes) is outside the repository at `D:\Coding_projects\Roblox\_vault_work\old_vault`. It is not part of the project and may be deleted when the owner is satisfied.

## Related Notes

[[00 - Home/Start Here]], [[05 - Development/Session Handoff]].
