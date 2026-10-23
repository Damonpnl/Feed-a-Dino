---
type: visual
status: mixed
last_verified: 2026-10-21
source_paths:
  - docs/FEED_A_PET_MASTER_CONTEXT.md
  - src/shared/ResourceModelDefinitions.luau
  - src/server/ResourceVisualService.luau
  - src/server/TrainerVisualService.luau
  - src/client/GuardianPresentation.luau
  - src/shared/MonsterDefinitions.luau
  - src/shared/GrowthStageDefinitions.luau
---

# Creatures and Asset Specifications

## At a Glance

Every Feed a Pet visual is a graybox today. This note is the single place for what each asset class must be, where it lives, and what exists. Tooling (Blender, import) is in [[02 - Engineering/Tooling and Build]]. Use [[07 - Templates/Asset Specification]] for a per-asset sheet. Style rules: [[03 - Visual Design/Art Direction]].

## Current Implementation

**VERIFIED IMPLEMENTATION** (source plus Studio MCP read, 2026-10-21).

- `ServerStorage.ResourceModels` does **not** exist in the open place. `ResourceVisualService` therefore builds fallback parts: `ResourceModelDefinitions` gives every `ModelKey` a 2.4-stud cube colored by rarity.
- `ServerStorage` holds legacy Studio-owned template folders: `CreatureTemplates` (19 Parts, including ProtoRex, Fangling, Mossback, Stonehide), `MaterialTemplates` (9), `ExpeditionTemplates` (6), `EnvironmentTemplates` (2), `ItemTemplates` (1). No file in `src/` references them (grep 2026-10-21); their role is UNKNOWN and they are not part of the launch pipeline.
- Guardians are `Model` instances under `Workspace.GeneratedGameplay.Guardians` containing one `Part` named `Guardian`, box about 10 x 12 x 18 studs. `GuardianPresentation` adds labels and state effects.
- The player's pet is a placeholder `Model` (`<UserName>_Monster`, one child) at `CreatureSpawn`.
- Trainer stations: a 6 x 6 flat `TrainingStation` Part with a `TrainerVisual` model (2 descendants) swapped by tier.

## Specification Table by Asset Class

Status key: graybox = exists as parts; none = no model; spec = confirmed design only.

| Class | Identity (ids) | Model location | Status | Scale | Rig / animation | Collision | Triangles (target) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pets | `ProtoRex` and forms | `Visual.ModelKey = "Placeholder"`; placeholder at `CreatureSpawn` | graybox | stage scale 1 to 2 (`GrowthStageDefinitions`) | none required yet | none specified | 2,000 to 6,000 |
| Evolution forms | ~20 ids in `MonsterDefinitions` ([[01 - Game Design/Rarity and Content Catalog]]) | none | none | per stage | none | none | 2,000 to 6,000 |
| Guardians | `TRex`, `Crocodile`, `Gorilla`, `Triceratops`, `Dragon` | `Workspace.GeneratedGameplay.Guardians.<Id>.Guardian` | graybox box | body box 10 x 12 x 18; `CatchReach` 5 from box surface | sleep, wake, charge/lunge/slam/fire, recover (spec) | gameplay body box, not decoration | 5,000 to 12,000 |
| Resources | 40 launch ids | `ServerStorage.ResourceModels` (absent) | graybox cubes | 2.4 stud fallback | none | pickup via server | 300 to 1,500 (complex 800 to 2,500) |
| Catalysts | `PrimalCatalyst`, `ToxicCatalyst`, `JungleHeart`, `CrystalCatalyst`, `FireCore`, `DragonBlood`, `InfernoCatalyst` | same | graybox | same | none | same | 800 to 2,500 |
| Training equipment | 10 trainer ids | `TrainerVisualService` swaps `TrainerVisual` | graybox | station 6 x 6 | none | none | not specified |
| Environment props | per-zone kit lists | Studio-owned | none | prop | none | per prop | 300 to 3,000 |
| Animations and VFX | guardian motions; rarity auras | Studio | spec / data-driven hooks | n/a | gameplay motions only | n/a | n/a |

Performance and format rules (CONFIRMED DESIGN): textures 512 x 512 for simple props, 1024 x 1024 for hero assets; keep rarity spectacle in Studio VFX instead of baking it into meshes; billboards and rare auras are distance-gated in `FieldConfig` (300, 450, 600 studs).

## Per-Class Notes

**Pets.** Silhouette: oversized head, simplified torso, chunky limbs, one defining feature per form. Final family art must not be invented ahead of approved family names (display names are placeholders). Stage scale should be applied to the model's root, not by editing mesh.

**Guardians.** Each must read instantly as its species. Collision stays a simple body box that matches `CatchReach` logic; decorative spikes must not affect gameplay. Required motions only: T-Rex sleep, wake, charge, recover; Crocodile sleep, wake, lunge/tail, recover; Gorilla idle or sleep, wake, slam, recover; Triceratops sleep, wake, charge, recover; Dragon sleep, wake, fire attack, recover.

**Resources and catalysts.** Valuable items should read by silhouette and material before text. Pivot at the carry grip; `ModelKey` per resource from `ResourceDefinitions`.

**Training equipment.** Base tier is a plain machine; higher tiers may become themed set pieces on the same machine shape (PROPOSAL; reference treadmill ladder below).

**Environment props** per zone are listed in [[03 - Visual Design/World Layout and Zones]].

## Visual References

REFERENCE OBSERVATION only, not Feed a Pet art. Each entry: image, reference ID, what it shows, adapt or not.

| Image | Reference | Shows | Adapt? |
| --- | --- | --- | --- |
| ![[Attachments/Creatures/sae-guardian-prehistoric-trex.png\|160]] | REF-WK-025 | Green faceted T-Rex with open mouth | silhouette clarity yes; model no |
| ![[Attachments/Creatures/sae-guardian-titan-gorilla.png\|160]] | REF-WK-027 | Crowned black gorilla, red eyes | scale and accent idea yes |
| ![[Attachments/Creatures/sae-guardian-volcano-hound.png\|160]] | REF-WK-028 | Multi-headed flame hound | no (not a Feed a Pet guardian) |
| ![[Attachments/Creatures/sae-guardian-forest-chicken-sleeping.png\|160]] | REF-WK-022 | Sleeping guardian with Z marks | sleep pose cue yes |
| ![[Attachments/Creatures/sae-pet-bear.png\|120]] | REF-WK-037 | Faceted bear pet, near-cubic | common-pet shape language |
| ![[Attachments/Resources/sae-treadmills-ranked.jpg\|240]] | REF-GD-058 | Treadmill tier ladder | tiered station idea yes |
| ![[Attachments/Resources/sae-egg-luminous.png\|140]] | REF-WK-007 | Glowing high-rarity object | glow and facet density only |

## Constraints and Invariants

- Do not rename gameplay ids to match art. Do not copy reference models or names.
- Final models are Studio-owned; Rojo registers keys only.
- No asset should depend on temporary mesh structure for gameplay.

## Open Questions

Final art bible, rig standard, per-pet silhouettes, whether `CreatureTemplates` should be retired ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[03 - Visual Design/Visual Reference Gallery]], [[02 - Engineering/Tooling and Build]].
