---
type: design
status: mixed
last_verified: 2026-10-21
source_paths:
  - docs/CURRENT_STATE.md
  - docs/PHASE1_RESULTS.md
  - docs/FEED_A_PET_MASTER_CONTEXT.md
  - src/shared/FieldConfig.luau
---

# Monetization and LiveOps

## At a Glance

**No monetization is implemented.** There is no gamepass, developer product, or receipt pipeline in `src/`, no Robux shop UI, and no event system. Treat everything below the first section as proposal or reference.

## Current Implementation

**VERIFIED IMPLEMENTATION.**

- A search of `src/` found no `MarketplaceService` receipt handling or entitlement code (grep for `SellStation` and `RobuxShop` in `src/` also returns nothing).
- `docs/CURRENT_STATE.md`: "No legitimate receipt/gamepass pipeline was found in the repository or active place." An unused SoilBag template's external asset-purchase script is disabled and backed up.
- `PlayerData.normalize` preserves unknown inventory, receipt, and entitlement fields already on a raw record, so a future pipeline will not lose them.
- Studio scene contains two Studio-owned models, `Workspace.Shops.SellStation` and `Workspace.Shops.RobuxShop`, observed through Studio MCP on 2026-10-21. No Luau module references them. Their purpose and contents are UNKNOWN; do not wire them without an explicit task.
- Closest live "event" systems: the 300-second field reset and the rare-spawn announcement (`FieldRareSpawn`, `FieldConfig.RarePresentation`). Sound ids are empty.

## Confirmed Design

From `FEED_A_PET_MASTER_CONTEXT.md`: keep datastore compatibility and receipt handling safe; future events should reuse existing systems (event pools, banners, special catalysts) in Phase 9, after UI (Phase 6), art (7), and Index/onboarding (8). Exact event cadence is undecided. No price, pass list, or revenue model is confirmed.

Candidate Index rewards named in the master context (Power bonus, training multiplier, Cash boost, trail, title, base cosmetic, pet appearance, luck bonus) are design ideas for completion rewards, not monetization.

## Reference Observation (Steal an Egg)

Decoded keyframes and stills show: a Shop modal with a featured limited egg and Robux price buttons, a Passes section (growth and money multipliers), speed packs, money packs, a Limited tab in the Pet Index, countdown timers, and an in-game announcement banner for a coming biome ([[03 - Visual Design/Visual Reference Gallery]], Shop and Events). Prices appear on screen but are not recorded here, and no causal claim about revenue or retention is made.

## Proposal (not approved)

If monetization is ever specified, keep it server-side and out of progression integrity: receipts processed by one service, entitlements stored additively, nothing purchasable that bypasses carry validation. The owner must choose products first; do not add a shop because the reference game has one.

## Constraints and Invariants

- Do not add monetization, DataStores, or remotes without approval.
- Studio must never write production data ([[02 - Engineering/Data, Networking and Persistence]]).

## Open Questions

Which products exist, event cadence, Cash sinks, whether Index rewards are cosmetic or numeric ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[01 - Game Design/Progression and Economy]], [[04 - Reference Research/Steal an Egg Analysis]].
