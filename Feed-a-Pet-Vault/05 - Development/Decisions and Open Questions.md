---
type: decision-register
status: mixed
last_verified: 2026-10-21
source_paths:
  - docs/CURRENT_STATE.md
  - docs/FEED_A_PET_MASTER_CONTEXT.md
  - docs/FAST_HEIST_TUNING_REPORT.md
  - docs/PHASE5B_REPORT.md
---

# Decisions and Open Questions

## At a Glance

One register for decisions and for what is still open. Source code wins on behavior; this note records why and who decided. The **Date** column is the modification date of the cited document (the docs do not log decision dates), not a meeting date. Record a new decision with [[07 - Templates/Architecture Decision Record]]; change one row here, do not rewrite the table.

**Approval column.** *Documented* means the cited doc or code states it as the design or the implemented rule; an individual owner approval is not recorded unless the cell says so. *Owner request* and *Owner (source: "Approved reset-policy change")* mean the source names the owner explicitly. *Provisional* means the docs mark the numbers provisional. Agent proposals are in the next table.

## Decisions

| ID | Topic | Decision | Approval | Source | Affects | Date |
| --- | --- | --- | --- | --- | --- | --- |
| DEC-001 | Name and loop | Product is Feed a Pet; loop is steal, escape, feed, train Power | Documented | `FEED_A_PET_MASTER_CONTEXT.md` | everything | 2026-10-09 |
| DEC-002 | Launch content | Five areas, eight resources per area design target, five nodes per area | Documented | `AreaDefinitions`, `ResourceDefinitions`, `RESOURCE_SPECIFICATION.md` | field, art | 2026-10-12 |
| DEC-003 | Rarity | Ten rarities in a fixed order | Documented | `RarityDefinitions.Order` | all content | 2026-10-09 |
| DEC-004 | Guardians | Hazards with catch effects, not HP combat | Documented | `GuardianConfig`, `GuardianCatch` | guardians | 2026-10-15 |
| DEC-005 | Authority | Server owns carry, feeding, evolution, cash, Power, saves | Documented | `00-project-core.mdc`, services | all | 2026-10-09 |
| DEC-006 | Studio saves | Studio uses memory sessions and never opens `MonsterProgress_v1` | Documented | `STUDIO_MEMORY_FEEDING_FIX.md`, `CURRENT_STATE.md` | persistence | 2026-10-16 |
| DEC-007 | Movement | Power-derived speed; Slow Mode precision speed 16 | Documented, numbers provisional | `PHASE5B_REPORT.md`, `MovementConfig` | movement, UI | 2026-10-19 |
| DEC-008 | Fast heist | Fast curve replaces the Phase 5B 16-32 curve | Owner request; not release-approved | `FAST_HEIST_TUNING_REPORT.md` | movement, guardians | 2026-10-21 |
| DEC-009 | Carry cap | Own column, then resource and curse penalties; max total slowdown 0.62 | Documented, provisional | `MovementConfig`, `CarryDebuff.MaxTotal` | carry | 2026-10-21 |
| DEC-010 | Reset lockdown | Carried items are forfeited if the carrier is still in the field at reset; all in-field players are evacuated | Owner (source: "Approved reset-policy change") | `FAST_HEIST_TUNING_REPORT.md`, `FieldLockdown` | field, carry | 2026-10-21 |
| DEC-011 | Rear spawn depth | Resources spawn no more than 24 studs behind the guardian | Documented | `BiomeLayout.RearDepth` | field layout | 2026-10-17 |
| DEC-012 | Trainers | Ten tiers; prices 0 through 16000 are provisional | Documented, provisional | `TrainerDefinitions.PriceStatus`, `PHASE5A_REPORT.md` | economy | 2026-10-18 |
| DEC-013 | Stage 5 | Stage 5 and Awakening stay locked until requirements are approved | Documented | `PetProgressionConfig`, `PHASE4B_REPORT.md` | evolution | 2026-10-13 |
| DEC-014 | Evolution rarity | Ordinary evolution keeps current pet rarity | Documented | branch `RarityRule = "Keep"`, `PHASE4D_REPORT.md` | evolution | 2026-10-17 |
| DEC-015 | Mutations | Only the Mutant overlay roll is active | Documented | `MutationDefinitions`, `PHASE4C_REPORT.md` | mutations | 2026-10-15 |
| DEC-016 | Monetization | No Robux pipeline in this repo | Verified absence | `CURRENT_STATE.md` | shop, passes | 2026-10-21 |
| DEC-017 | Art timing | Final art waits until gameplay feels right | Documented | master context | art | 2026-10-09 |
| DEC-018 | Dev panel | Developer panel is Studio-only and uses the memory backend | Documented | `DevTestService`, `DEVELOPER_TESTING_REPORT.md` | tooling | 2026-10-19 |
| DEC-019 | Naming | Leftover `Monster*` and `Feed a Dino` names stay until a rename task | Documented (project rule) | `CLAUDE.md` | code, Rojo | n/d |
| DEC-020 | Vault structure | 27-note vault in groups 00-06 plus templates; one vault only | Owner (task) | vault migration task | docs | 2026-10-21 |

## Agent Recommendations (not approved)

| ID | Recommendation | Why | Status |
| --- | --- | --- | --- |
| REC-001 | Test fast-heist escape rates with humans before release | Kinematic comparison C found almost no straight-line escapes; the report says that is not acceptable-difficulty evidence | open |
| REC-002 | Clean the three temporary `ServerStorage` folders before publish | Listed in [[05 - Development/Bugs and Test Status]] B-003 | open |
| REC-003 | Add a Feed a Pet screenshot capture routine for visual tasks | Studio MCP capture is agent-view only | open |

Do not implement a recommendation without owner approval.

## Open Questions

| ID | Question | Why it matters | Owner input needed? |
| --- | --- | --- | --- |
| Q-001 | Final Power to speed milestones and carry cap | Provisional; long loaded returns and CrystalCave difficulty were flagged in `PHASE5B_REPORT.md` | yes |
| Q-002 | Path length after five areas | Roadmap | yes |
| Q-003 | Cash uses beyond trainers | Economy sink design | yes |
| Q-004 | PvP versus world-only theft | Affects guardians and UI | yes |
| Q-005 | How many owned pets are displayed | Base layout, performance | yes |
| Q-006 | Final evolution UI | Phase 6 | yes |
| Q-007 | Are special catalysts always deterministic | Evolution balance | yes |
| Q-008 | Event cadence and live-content shape | Phase 9 | yes |
| Q-009 | Shop, passes, and Robux products | Monetization is zero today | yes |
| Q-010 | Which guardian does a Steal an Egg guardian chase (first or newest thief) | `05_prompt_review.md` argues from captions; video has no chase footage | no, reference only |
| Q-011 | Steal an Egg movement speed in studs per second | No measurement exists; do not estimate from a still | no |
| Q-012 | Mobile layout of Steal an Egg | Stills look desktop | no |
| Q-013 | Safe-zone PvP with a bat (REF-GD-042, REF-GD-043 not inspected) | PvP decision Q-004 | no |
| Q-014 | Which reference files match the current Steal an Egg build | The pack mixes wiki renders, guide sites, and one session's screenshots | no |
| Q-015 | Human escape rate at fast-heist speeds | Not established | yes, via playtest |

## Closed From Earlier Versions

- "Four mp4 clips have no inspected duration, frame, or audio" is closed for duration and frames: all four were decoded this pass. Audio remains uninspected. See [[04 - Reference Research/Reference Manifest]].
- "No Blender scene or MCP config in the repo" remains true; Blender is not installed.

## Related Notes

[[05 - Development/Current State and Roadmap]], [[05 - Development/Bugs and Test Status]], [[04 - Reference Research/Steal an Egg Analysis]], [[01 - Game Design/Monetization and LiveOps]].
