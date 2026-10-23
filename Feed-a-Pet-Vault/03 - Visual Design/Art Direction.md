---
type: visual
status: mixed
last_verified: 2026-10-21
source_paths:
  - docs/FEED_A_PET_MASTER_CONTEXT.md
  - docs/CURRENT_STATE.md
  - src/shared/RarityStyles.luau
  - src/client/UIController.client.luau
---

# Art Direction

## At a Glance

Three layers, kept separate here: what is **in the game now** (graybox), what is **confirmed design** (`FEED_A_PET_MASTER_CONTEXT.md` sections 28 and 31), and what is a **proposal** distilled from Steal an Egg reference stills. Nothing from the reference is approved. Do not copy its models, UI skins, names, or branding.

## Current Implementation

**VERIFIED IMPLEMENTATION.** Live art is graybox: part-built resources (`ResourceVisualService`), block guardians, a pet blob at `CreatureSpawn`, graybox trainer stations, and a dark coded HUD. No final model, texture, or Blender file exists in the repo (`art/` is empty). `docs/CURRENT_STATE.md`: final pets, props, and UI come after the Grasslands slice feels right. No Feed a Pet screenshot is stored in this vault: Studio's `screen_capture` returns image data only to the agent and rendered a black world in Play (2026-10-21). The HUD text was readable; see [[03 - Visual Design/UI Screens and Contracts]].

## Confirmed Design

- **Style:** stylized, low-poly, chunky, toy-like, bright, mobile-readable, silhouette-first.
- **Creatures:** archetypes must read instantly (a T-Rex reads as a T-Rex). Oversized head, simplified torso, chunky limbs, large readable eyes where appropriate, exaggerated defining features, minimal tiny geometry, one coherent proportion language across the roster.
- **Triangle guidance** (targets, not limits): small feed 300 to 1,500; complex feed or catalyst 800 to 2,500; environment prop 300 to 3,000; player pet 2,000 to 6,000; guardian 5,000 to 12,000. Textures 512 x 512 for simple props, 1024 x 1024 for hero assets.
- **Rarity VFX** live in Studio, not baked into meshes: Legendary subtle gold glow, Mythic stronger colored glow, Cosmic galaxy particles, Secret dark prismatic aura, Eternal white-violet aura, Divine white-gold aura with a beam. Do not make Common visually noisy.
- **UI:** modern Roblox collection-game feel without copying another title: rounded chunky panels, strong hierarchy, bold text, dark strokes, colorful gradients, large mobile-friendly buttons, compact HUD, minimal text ([[03 - Visual Design/UI Design System]]).
- **Animation scope:** only gameplay-needed motions (sleep, wake, charge or attack, recover). See [[03 - Visual Design/Creatures and Asset Specifications]].

## Palette and Shape Language

Implemented rarity name colors are the only coded palette ([[01 - Game Design/Rarity and Content Catalog]]); HUD panels use two dark fills (20,22,28 and 25,29,38). **No approved environment palette exists.** The per-zone differentiation below is PROPOSAL, derived from area identity in the master context:

| Zone | Natural logic (confirmed) | Proposed color anchor |
| --- | --- | --- |
| Grasslands | carcass, berries, bones | saturated greens, warm bone tan |
| Swamp | fish, mushrooms, venom | murky teal and olive, toxic accents |
| Jungle | fruit, roots, flowers | deep greens with bright flower colors |
| Crystal Cave | geodes, fossils, minerals | cool blues and violets, glowing crystal |
| Volcano | charred ground, magma | black basalt, orange and red glow |

## Reference-Derived Proposals

REFERENCE OBSERVATION turned PROPOSAL (not approved):

- **Silhouette first.** Guardian stills show one oversized creature with one strong accent (teeth, flame, crown). Common pets read almost cubic; guardians are larger and more sculpted. Keep the five Feed a Pet guardians (T-Rex, crocodile, gorilla, triceratops, dragon); do not import the reference's chicken, yeti, or hellhound.
- **Resources read before text.** The valuable object should be recognizable by silhouette and material, with the billboard second. Feed a Pet uses meat, plants, bones, and catalysts, not eggs.
- **Bright ground and simple fences.** Lighting must stay bright enough that a stolen item and a chasing guardian read at distance.
- **HUD contrast.** The reference uses thick dark outlines, huge outlined numbers, and a left button stack. Keep the current dark HUD until a UI task is commissioned.

## Visual References (compact moodboard)

Reference stills, **not** Feed a Pet art:

| | | |
| --- | --- | --- |
| ![[Attachments/Creatures/sae-guardian-prehistoric-trex.png\|180]] | ![[Attachments/Creatures/sae-guardian-titan-gorilla.png\|180]] | ![[Attachments/Creatures/sae-guardian-volcano-hound.png\|180]] |
| REF-WK-025: faceted T-Rex guardian | REF-WK-027: crowned gorilla guardian | REF-WK-028: multi-headed flame hound |
| ![[Attachments/World/sae-lane-biome-view.jpg\|180]] | ![[Attachments/UI/sae-hud-speed-cash.png\|180]] | ![[Attachments/Resources/sae-egg-extinction.png\|180]] |
| REF-GD-035: straight lane between brick walls | REF-IG-017: outlined speed and cash numbers | REF-WK-005: ornate rarity object (an egg, not a Feed a Pet item) |

Feed a Pet's own in-game visuals are graybox; there is no image of them in this vault ([[03 - Visual Design/Visual Reference Gallery]] explains the gap).

## Constraints and Invariants

- Do not copy Steal an Egg models, UI skins, names, or branding.
- Keep `ResourceModels` keys and gameplay ids; art never renames ids.
- Rarity VFX stay data-driven (`RarityStyles`, `FieldConfig.RarePresentation`).

## Open Questions

Approved palette, typography, outline weight, environment kits, and whether a UI redesign is commissioned ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[03 - Visual Design/World Layout and Zones]], [[02 - Engineering/Tooling and Build]], [[04 - Reference Research/Steal an Egg Analysis]].
