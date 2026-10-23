---
type: design
status: mixed
last_verified: 2026-10-21
source_paths:
  - src/shared/EconomyConfig.luau
  - src/shared/EconomyCalculator.luau
  - src/shared/TrainerDefinitions.luau
  - src/server/TrainingService.luau
  - src/shared/MovementConfig.luau
  - src/shared/MovementCalculator.luau
  - src/server/CarryService.luau
  - docs/PHASE5A_REPORT.md
  - docs/FAST_HEIST_TUNING_REPORT.md
---

# Progression and Economy

## At a Glance

Power gates carry weight and (through the speed curve) movement. Cash buys the next trainer tier. Training raises Power. The equipped pet multiplies both Cash income and training gain. Everything here is PROVISIONAL balance; `MovementConfig.Status` is `PROVISIONAL_BALANCE` and fast-heist tuning is not release-approved.

## Current Implementation

**VERIFIED IMPLEMENTATION** (2026-10-21). Two currencies, both server-owned.

- **Cash** accrues while the session is writable: `EconomyConfig.BaseCashPerSecond` (0.5) times the active pet's income multiplier, per second. No offline income, no NPC sell loop, no material bank, no second currency. `EconomyConfig.TemporaryBoost` is 1 (no live boost).
- **Power** accrues only while training at the owned station: `BaseTrainingGain` (5) times trainer multiplier times pet training multiplier, once per active second. `MaxFrameCredit` stops a stall from granting a catch-up burst.
- **Trainer tiers.** Cash buys the next tier only when the request is exactly the next tier and the player is within `InteractionDistance` (12 studs). `Economy.add` saturates at 2^53 - 1.
- **Station visual.** `TrainingService` refreshes `TrainerVisualService` from `TrainerTier`; stations are grayboxes under each base.

| Tier | Id | Multiplier | Provisional price (Cash) |
| ---: | --- | ---: | ---: |
| 1 | TrainingMat | 2 | 0 |
| 2 | WeightedSled | 5 | 25 |
| 3 | IronRig | 12 | 100 |
| 4 | PowerCage | 30 | 250 |
| 5 | GoldenGym | 80 | 500 |
| 6 | GravityChamber | 100 | 1000 |
| 7 | CosmicReactor | 200 | 2000 |
| 8 | AbyssChamber | 500 | 4000 |
| 9 | EternalForge | 1000 | 8000 |
| 10 | DivineReactor | 2000 | 16000 |

Prices are listed in `TrainerDefinitions` as provisional (`PriceStatus`). `BaseUpgrades.TrainingLevel` is a legacy paid floor and does not stack with tiers.

## Movement Progression

`MovementConfig.Milestones` are steps, not interpolation, mapping Power to unloaded speed and carrying base speed:

| Power | Unloaded | Carrying base |
| ---: | ---: | ---: |
| 0 | 22 | 22 |
| 1,000 | 26 | 24 |
| 10,000 | 30 | 27 |
| 100,000 | 36 | 30 |
| 1,000,000 | 44 | 35 |
| 10,000,000 | 54 | 41 |
| 100,000,000 | 64 | 47 |
| 150,000,000 | 72 | 52 |

Slow Mode uses `PrecisionSpeed` 16. Carrying applies the carry base, then resource and curse slowdown (cap 0.62). The older Phase 5B curve (16 to 32, carry cap 18) is historical; `docs/CURRENT_STATE.md` still describes both (D1 in [[05 - Development/Bugs and Test Status]]).

## Resource Power Requirements

`PowerRequired` per resource rises from 0 (Grasslands feed) to 150,000,000 (InfernoCatalyst). Heavier items need more Power and slow the carrier more; see [[01 - Game Design/Guardians and Carrying]] and [[01 - Game Design/Rarity and Content Catalog]].

## Confirmed Design

Short-term goal: one feed and evolution then a Power gain. Long-term goal: farther areas and higher tiers. Do not invent average progression times; none have been measured. Human escape rates at current speeds are unknown.

## Not Implemented

Prestige or rebirth (`PrestigeCalculator` exists, disabled), Index rewards, a Cash shop beyond trainers, boosts. See [[01 - Game Design/Monetization and LiveOps]].

## Constraints and Invariants

- Do not change `EconomyConfig`, trainer prices, or resource weights outside a balance task. Record old and new values in [[05 - Development/Decisions and Open Questions]].
- Cash and Power are never client-authoritative.

## Open Questions

Cash's long-term uses, final speed numbers, path length ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

`docs/PHASE5A_REPORT.md`, `docs/PHASE5B_REPORT.md` (historical), `docs/FAST_HEIST_TUNING_REPORT.md`, tests `Economy_Test`, `Movement_Test`, `FastHeist_Test`.
