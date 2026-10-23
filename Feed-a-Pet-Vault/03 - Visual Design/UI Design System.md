---
type: visual
status: mixed
last_verified: 2026-10-21
source_paths:
  - src/client/UIController.client.luau
  - src/client/CarryController.client.luau
  - src/client/FieldPresentation.luau
  - src/client/GuardianPresentation.luau
  - src/client/DevTestPanel.client.luau
  - src/shared/RarityStyles.luau
  - src/shared/NumberFormat.luau
  - docs/FEED_A_PET_MASTER_CONTEXT.md
---

# UI Design System

## At a Glance

The live UI is a functional, code-built graybox HUD with no design-token module and no component library. The target look is CONFIRMED DESIGN only at the level of principles; no component spec or Figma output exists in the repo. Steal an Egg observations are PROPOSALS.

## A. Current Implementation

**VERIFIED IMPLEMENTATION** (read from `UIController.client.luau` and siblings, 2026-10-21).

| Element | Instance name | Geometry | Style |
| --- | --- | --- | --- |
| Pet panel | `Panel` in ScreenGui `MonsterHud` | 280 x 210 at offset (16, 56) | fill (20,22,28), transparency 0.25, `UICorner` 8, GothamMedium 16, white-ish text |
| Carry card | `CarryCard` | bottom-center, width scale 0.55, height 64, 70 px above bottom | fill (25,29,38), transparency 0.15, GothamBold 17 |
| Power notice | `PowerNotice` | top-center, 96 px down, width 0.65, height 42, hides after 2 s | fill (50,25,20), text (255,220,125), GothamBold 23 |
| Feed preview | `FeedPreview` | centered 0.9 x 0.75, `UISizeConstraint` max 440 x 340 | fill (25,29,38), FEED and CLOSE buttons 48 px, text colored by resource rarity |
| Evolution choice | `EvolutionChoice` | centered 0.9 x 0.7, max 480 x 420, scrolling list | 84 px buttons filled with the target form's `Color` |
| Economy panel | `EconomyPanel` | width scale 0.3, height 272, max 280 x 272, at (16, 280) | fill (25,29,38), Train and Upgrade buttons 40 px |
| Slow Mode / reset / guardian status | `MovementHud`, `FieldPresentation`, `GuardianStatus` | top-right and top-center text | plain text on dark fill |

Numbers use `NumberFormat.compact`; `NumberFormat.needPower` makes "NEED x POWER". World labels use `RarityStyles` (stroke 2.3, dark stroke 20,15,30). The carry line starts with a diamond glyph and "CARRYING". Buttons use `Activated`; keyboard G drops, V toggles Slow Mode.

**Observed live (Studio Play capture, 2026-10-21, not stored as a file):** the Studio-only `TEST MODE` label and `Dev panel` button sit at the top-left and overlap the top of the pet panel; the reset banner reads `RESOURCES RESET IN m:ss` with a red closure warning in the final 10 seconds; the guardian status list lists five guardians as SLEEPING. These are visible-only observations of a dev-session overlay, not a shipped layout.

## B. Target Visual Direction

CONFIRMED DESIGN (master context section 31): rounded chunky panels, strong hierarchy, bold readable text, dark strokes where useful, colorful gradients, large mobile-friendly buttons, compact footprint, minimal text, playful toy-like language; keep screens native Roblox instances, never flattened screenshots.

PROPOSAL from reference stills ([[03 - Visual Design/Visual Reference Gallery]]): thick black outlines, flat saturated buttons, huge outlined numbers (pink for the trained stat, green for cash), a left stack of Shop and Index buttons, round right-edge icons, a centered modal over a blurred world. Do not restyle `MonsterHud` unless a task says so.

## C. Design Tokens

**None implemented.** Values above are inline literals. Proposed token set when a redesign starts (PROPOSAL): background dark, panel dark, text, rarity colors (reuse `RarityDefinitions` colors), success green, warning amber, danger red, stroke. Rarity colors are the only shared palette in code.

## D. Component Standards

CONFIRMED DESIGN component list (not built): PrimaryButton, SecondaryButton, CloseButton, Panel, CurrencyDisplay, ResourceCard, PetCard, RarityText, Toast, Modal, ProgressBar, TabButton. Current code builds each element ad hoc with `Instance.new`.

## E. Responsive Principles

CONFIRMED DESIGN: mobile layout is designed explicitly, not scaled down from desktop. Use `UIScale`, `UIAspectRatioConstraint`, `UISizeConstraint`, `UIListLayout`, `UIGridLayout`, `UICorner`, `UIStroke`, `UIGradient`, `CanvasGroup`. **Current:** scale-plus-max sizing exists only on the economy, feed, and evolution panels; the pet panel is fixed 280 x 210. No phone or tablet layout was tested (UNKNOWN).

## F. Motion and Feedback

CONFIRMED DESIGN suggestions: modal open fade with scale 0.94 to 1.02 to 1.0, close 1.0 to 0.96, toast slide and fade, rare banner intensity rising with rarity. **Current:** only the 2-second toast timer and rare-spawn presentation (`FieldPresentation`, sounds empty).

## G. Implementation Constraints

- UI owns no authoritative progression; it fires remotes and reads server attributes ([[02 - Engineering/Data, Networking and Persistence]]).
- Keep `MonsterHud`, `MovementHud`, remote names, and attribute names stable.
- Desktop panels must not cover the runway view.
- Pipeline in the master context: functional UI, validate state, Figma concept, approve component language, convert where useful, wire to controllers, QA, capture desktop/tablet/phone with Studio MCP. None of the Figma steps have been done.

## Open Questions

Final evolution UI style, icon set, type scale, phone layout, whether Figma and Framewisp will be used ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[03 - Visual Design/UI Screens and Contracts]], [[03 - Visual Design/Art Direction]].
