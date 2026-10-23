---
type: index
status: current
last_verified: 2026-10-21
---

# Task Router

Take one row. Read its source first, then the primary note only for an invariant. Open one visual only if the task is visual. Numbers live in Luau, not in notes. Skip the vault for self-contained edits.

Gallery = [[03 - Visual Design/Visual Reference Gallery]]. Verify = [[02 - Engineering/Security, Testing and Diagnostics]] unless noted.

| Task | Primary note | Source files / search terms | Visual | Verify |
| --- | --- | --- | --- | --- |
| Guardian AI | [[01 - Game Design/Guardians and Carrying]] | `GuardianService`, `GuardianState`, `GuardianChase`, `GuardianConfig`; also `CarryService` for safe-zone and carry invariants | Gallery: Guardians | `RunUnitTest("Guardian")` |
| Resource spawn, field reset | [[01 - Game Design/Resources and Field Resets]] | `ResourceDefinitions`, `FieldConfig`, `FieldRoller`, `ResourceService`, `FieldLockdown` | none | `Field`, `Resource` filters |
| Carrying, banking | [[01 - Game Design/Guardians and Carrying]] (support: Resources) | `CarryService`, `CarryDebuff`, `MovementConfig`, `SpawnService`; no bank exists, feeding is delivery | none | `Movement`, `CarryDebuff` |
| Feeding, evolution | [[01 - Game Design/Pets, Feeding and Evolution]] | `FeedService`, `EvolutionCalculator`, `MonsterDefinitions`, `GrowthStageDefinitions` | none | `Feeding`, `Evolution` |
| Economy, progression | [[01 - Game Design/Progression and Economy]] | `EconomyConfig`, `TrainerDefinitions`, `TrainingService` | none | `Economy` |
| Monetization | [[01 - Game Design/Monetization and LiveOps]] | none exists; confirm no `MarketplaceService` use | Gallery: Shop | review only |
| UI redesign | [[03 - Visual Design/UI Design System]] (support: Art Direction) | `UIController.client` | Gallery: UI | Studio Play |
| UI implementation | [[03 - Visual Design/UI Screens and Contracts]] (support: [[02 - Engineering/Data, Networking and Persistence]] for remote payloads) | `UIController.client`, `CarryController.client`, `FieldPresentation` | Gallery: UI | Studio Play |
| World or environment | [[03 - Visual Design/World Layout and Zones]] | `BiomeLayout`, `BiomeTerritory`, `ZoneGeometry`; inspect live paths via Studio MCP | Gallery: World | `RadialSpawn` |
| Guardian or pet model | [[03 - Visual Design/Creatures and Asset Specifications]] (support: Tooling and Build) | `ResourceModelDefinitions`, `GuardianPresentation`, `AreaDefinitions` | Gallery: Creatures | Studio visual check |
| Persistence debugging | [[02 - Engineering/Data, Networking and Persistence]] | `DataService`, `SessionStore`, `PlayerData` | none | `SessionStore` |
| Multiplayer testing | [[02 - Engineering/Security, Testing and Diagnostics]] | `tests/Phase*Multiplayer.server.luau` | none | those scripts |
| Release verification | [[05 - Development/Bugs and Test Status]] (support: Current State and Roadmap) | `docs/CURRENT_STATE.md` | none | full suite plus Play |

After a verified change, follow the update rules in [[06 - Agent Workflows/Agent Playbook]]. Image and clip IDs: [[04 - Reference Research/Reference Manifest]].
