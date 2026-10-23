---
type: visual
status: mixed
last_verified: 2026-10-21
source_paths:
  - src/client/UIController.client.luau
  - src/client/CarryController.client.luau
  - src/client/FieldPresentation.luau
  - src/client/GuardianPresentation.luau
  - src/client/BillboardView.luau
  - src/client/DevTestPanel.client.luau
  - src/server/FeedService.luau
  - src/server/TrainingService.luau
  - docs/FEED_A_PET_MASTER_CONTEXT.md
---

# UI Screens and Contracts

## At a Glance

Eleven surfaces are tracked. Implemented ones are code-built in `src/client`; planned ones come from the master context UI inventory (section 21). Navigation today is "walk to a prompt or press a HUD button"; there is no screen stack. Visual style: [[03 - Visual Design/UI Design System]]. Attribute and remote names: [[02 - Engineering/Data, Networking and Persistence]]. No stored screenshot of any Feed a Pet screen exists in the vault (Studio capture is agent-view only); the live HUD text was observed 2026-10-21.

Common to all implemented screens: server-published player attributes are the input; remotes are the output; the client never grants anything. Loading state is usually "attribute not yet set", which renders zeros or empty strings.

## Main HUD (pet panel)

- **Status:** implemented. **Purpose:** show the active pet and carry line. **Elements:** pet name and stage, Growth current/required, Flesh/Flora/Mineral, Power, Cash, multiplier, mutation line, carried line, status message.
- **Source:** `UIController.client.luau` (`Panel`). **Input:** `MonsterName`, `PetStageLabel`, `Growth`, `GrowthRequired`, `Flesh`, `Flora`, `Mineral`, `Power`, `Cash`, `Multiplier`, `Mutations`, `CarriedName`, `StatusMessage`. **Actions:** none. **Server:** none.
- **States:** refreshes on any player attribute change. **Layout:** fixed 280 x 210 at (16, 56); desktop-only tested. **Unresolved:** final HUD design, mobile placement.

## Carrying HUD

- **Status:** implemented. **Purpose:** tell the carrier what they hold and what it costs. **Elements:** `CarryCard` with name, rarity, movement penalty, drop hint; `PowerNotice` toast ("NEED x POWER"); `MovementHud` Slow Mode button; curse presentation.
- **Source:** `UIController` (`CarryCard`, `PowerNotice`), `CarryController.client.luau`, `CarryCursePresentation`, `EffectsController`. **Input:** `CarriedName`, `CarriedRarity`, `CarrySlowdown`, `PowerNotice`, `PowerNoticeTick`, `SlowMode`, `EffectiveMovementSpeed`.
- **Actions:** G or gamepad B fires `DropCarried`; V or the button fires `SetSlowMode` (boolean). **Server:** drops and recomputes speed. **Unresolved:** curse icons, mobile drop button.

## Feeding

- **Status:** implemented. **Purpose:** preview then confirm feeding. **Elements:** `FeedPreview` modal with resource name and rarity, Growth delta, affinity deltas, special effect text, growth reserve; FEED/REFRESH and CLOSE buttons.
- **Source:** `UIController` plus `FeedService`. **Remote:** `FeedInteraction` `Preview`, then `Confirm` + ticket. **Input:** payload with `Ticket`, `ResourceId`, `Pet`, `GrowthAfter`, `Reason`.
- **States:** WAIT while pending (2 s fallback); "Preview expired; preview again" on a bad or old ticket; invalidated (REFRESH) when carried item, growth, or base attributes change; ticket valid 30 s. **Unresolved:** final feed UX, animation.

## Evolution Selection

- **Status:** implemented, style "functional" per `CURRENT_STATE.md`. **Purpose:** choose a branch when `PendingEvolution` is set. **Elements:** title with stage and growth reserve; one 84 px button per candidate showing target name, stage, Growth, multiplier, requirements, tinted by form color.
- **Source:** `UIController` (`EvolutionChoice`, `refreshChoices`). **Input:** JSON `PendingEvolution` {Source, Candidates, Token}, `OwnedPetKey`, `PetStageLabel`, `GrowthReserve`. **Action:** `FeedInteraction` `Evolve` {PetKey, Token, BranchId}.
- **Server:** `MonsterService.chooseEvolution` requires pending choice and proximity; result `Kind="Evolution"`. **States:** "Confirming evolution..." then server reason on failure. **Unresolved:** reveal animation, final art, what each branch looks like.

## Pet Inventory

- **Status:** not implemented (CONFIRMED DESIGN: "Pet Panel" with stats, affinities, multipliers, evolution state). The save allows many pets; the base shows one at `CreatureSpawn`. **Unresolved:** owned-pet count. Reference: [[03 - Visual Design/Visual Reference Gallery]] (pen and index).

## Training

- **Status:** implemented. **Purpose:** start or stop training at the owned station. **Elements:** `Train` button ("START · approach your trainer" or "STOP TRAINING"); `TrainPrompt` proximity prompt on the station.
- **Source:** `UIController` (`EconomyPanel`), `TrainingService`. **Remote:** `TrainingInteraction` `Start`/`Stop`. **Input:** `TrainingActive`, `Power`, `TrainingGainPerSecond`. **Server:** 12-stud distance check.

## Economy and Upgrades

- **Status:** implemented. **Purpose:** show Cash and Power rates and buy the next trainer. **Elements:** `EconomyPanel` text (Cash, +income/s, Power, +training/s, tier name and multiplier, pet training multiplier, next tier and price); `Upgrade` button ("BUY NEXT TRAINER" or "MAX TIER"); `UpgradePrompt` on the station (key F).
- **Input:** `TrainerTier`, `Cash`, `IncomePerSecond`, `ActivePetTrainingMultiplier`. **Action:** `TrainingInteraction` `Upgrade` + expected next tier. **Server:** exact-next-tier and distance checks. **Unresolved:** icons, phone layout, panel/button overlap with the dev overlay in Studio.

## Shop

- **Status:** not implemented; no monetization ([[01 - Game Design/Monetization and LiveOps]]). Reference: Steal an Egg shop frames ([[03 - Visual Design/Visual Reference Gallery]]). A Studio-owned `Workspace.Shops.RobuxShop` model exists with unknown purpose.

## Collection / Index

- **Status:** not implemented. CONFIRMED DESIGN: area pages with eight entries each, discovery state, area-completion rewards; discovery rule must be server-authoritative. Reference: Steal an Egg index modal. **Unresolved:** discovery trigger, reward type, storage field.

## Rewards and Notifications

- **Status:** partly implemented. **Elements:** reset countdown (`RESOURCES RESET IN m:ss`) and closure warning; rare-spawn banners (`RARE FIND`, `ETERNAL ARRIVAL`, `DIVINE ARRIVAL`, sounds empty); guardian alerts and catch notice ("CAUGHT BY THE ..."); `StatusMessage` text; world billboards (`BillboardView`); `GuardianStatus` list.
- **Source:** `FieldPresentation`, `GuardianPresentation`, `Billboard*`. **Input:** `WorldFieldState`, `FieldRareSpawn`, guardian part attributes. **Unresolved:** audio, level-up and Index toasts.

## Developer Testing Interface

- **Status:** implemented, Studio only. **Elements:** red `TEST MODE` label, `Dev panel` button, 320 px frame (72% height) with seven tabs (Player, Pets, Items, Trainers, Guardians, Travel, Scenarios). **Source:** `DevTestPanel.client.luau`; remote `DevTest`. Not a player screen. Known cosmetic issue: it overlaps the top of the pet panel at the default viewport.

## Constraints and Invariants

Never trust UI state for grants. Keep remote and attribute names stable. Do not add a remote for a new screen without approval.

## Open Questions

Shop, Index, pet inventory, onboarding objectives, and mobile layout are all undefined ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[01 - Game Design/Pets, Feeding and Evolution]], [[01 - Game Design/Progression and Economy]], [[02 - Engineering/Security, Testing and Diagnostics]].
