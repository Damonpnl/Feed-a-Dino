---
type: reference-analysis
status: mixed
last_verified: 2026-10-21
source_paths:
  - references/research/01_fandom_wiki.md
  - references/research/03_youtube_findings.md
  - references/research/05_prompt_review.md
  - references/reference/ingame_clips
  - references/reference/ingame
---

# Steal an Egg Analysis

## At a Glance

**REFERENCE ONLY.** Nothing here is a Feed a Pet requirement. The cited place id is `107778070777162` (from the local research notes). The game was updating weekly as of September 2026, so wiki numbers drift. Do not copy a wiki income, price, or speed number. Adaptation labels: **Existing** (Feed a Pet already does it), **Planned**, **Consider**, **Not applicable**, **Needs verification**. Image IDs: [[04 - Reference Research/Reference Manifest]]; visuals: [[03 - Visual Design/Visual Reference Gallery]].

## Evidence Base and Limits

Inspected this pass: four ingame clips decoded with FFmpeg (62, 140, 90, 35 s; 1280 x 694), contact sheets of all four, 12 keyframes, and 25 stills (plus 7 stills itemized from an earlier pass, per the manifest). The other 219 images are metadata-only (127), sampled in earlier contact sheets without itemized notes (63), or not opened (29). **The clips show base income, a shop tour, the pet index, and announcements; they contain no guardian chase, pickup, or carry footage.** Anything about chase timing, speed, wake rules, or PvP remains UNKNOWN from video. Caption-derived claims in `references/research/` are secondary. Never infer exact timing from isolated frames.

Format below: Observation · Evidence · Design purpose · Feed a Pet today · Adapt? · Preserve · Uncertain.

## Core Loop

Observation: steal an egg, carry it home while slowed, hatch a pet, earn cash, buy speed, go to a harder biome. · Evidence: local research header, HUD stills. · Purpose: a short risk loop feeding a collection loop. · Feed a Pet: same shape with different nouns (resource, guardian, feed, Cash, Power) ([[01 - Game Design/Game Vision and Core Loop]]). · Adapt: **Existing**; egg and hatch words **Not applicable**. · Preserve: evolving pets, Power not Speed. · Uncertain: first-session pacing.

## Area Progression

Observation: many themed biomes (forest, lake, desert, jungle, snow, volcano, prehistoric, cosmic, others) with one guardian each. · Evidence: wiki zone and guardian files, `map_biome_map` lane still. · Purpose: escalating risk and spectacle. · Feed a Pet: five fixed areas on one runway. · Adapt: **Consider** palette shifts at zone entrances. · Preserve: five launch areas, no sprawl. · Uncertain: actual biome unlock rules.

## Resource Acquisition

Observation: loot is eggs sold with odds in a shop and found at nests; rarity labels and a "limited" tab appear. · Evidence: shop and index frames. · Feed a Pet: physical field resources, no eggs ([[01 - Game Design/Resources and Field Resets]]). · Adapt: **Not applicable**. · Preserve: server-owned single carry.

## Guardians and Pursuit

Observation: one oversized sleeping creature per biome, startled poses in thumbnails, Z sleep marks. · Evidence: wiki renders, thumbnails. · Purpose: instantly readable hazard. · Feed a Pet: T-Rex, crocodile, gorilla, triceratops, dragon with a defined state machine ([[01 - Game Design/Guardians and Carrying]]). · Adapt: **Consider** sleep and size cues. · Preserve: Feed a Pet guardian roster and mechanics. · Uncertain: who the guardian chases and how fast. `05_prompt_review.md` argues a first-grabber rule from captions; **Needs verification**, and the Feed a Pet rule is whatever `GuardianService` does now.

## World Layout

Observation: brick-walled lanes with colored floors, a fenced stud pen at the base. · Evidence: `ingame_001`, lane stills. · Feed a Pet: bases at the safe end of one lane ([[03 - Visual Design/World Layout and Zones]]). · Adapt: **Existing** in concept. · Uncertain: true map scale.

## UI and HUD

Observation: left stack (Shop with notification dot, Index with badge, Slow Mode toggle); right icon column; bottom-left stats; bottom-right timers; thick outlines and huge numbers; centered modals over a blurred world. · Evidence: clip keyframes, `ingame_hud_*`. · Purpose: dense status with the world still visible. · Feed a Pet: functional dark HUD ([[03 - Visual Design/UI Design System]]). · Adapt: **Consider** for a later UI task. · Preserve: Power and Cash naming, server authority. · Uncertain: mobile layout (stills look desktop).

## Economy

Observation: each pet shows income per second; floating `+$` popups; an upgrade board with a large cost; very large numbers. · Evidence: clip1 frames. · Feed a Pet: Cash 0.5/s times pet multiplier, ten trainer tiers ([[01 - Game Design/Progression and Economy]]). · Adapt: **Not applicable** numbers; **Consider** popup feedback. · Uncertain: all balance.

## Progression

Observation: Index pages of eight slots, silhouettes for unknown pets, progress fraction, `CLAIM ALL` rewards (cash and speed icons). · Evidence: clip3 and clip4 frames. · Feed a Pet: no Index; design wants eight resources per area. · Adapt: **Consider** once an Index is scheduled. · Preserve: server-authoritative discovery.

## Monetization Presentation

Observation: shop sections Featured (limited egg with odds and countdown), Passes (growth and money multipliers), Speed (double speed, upgraded treadmill), speed and money packs; Robux price buttons. · Evidence: clip2 frames. · Feed a Pet: none ([[01 - Game Design/Monetization and LiveOps]]). · Adapt: **Not applicable** until the owner specifies products. · No price or revenue claim is made.

## Reward Feedback

Observation: green floating cash text, rarity-colored labels, "NEW" tags, claim buttons. · Feed a Pet: rarity billboards and rare banners exist ([[01 - Game Design/Rarity and Content Catalog]]). · Adapt: **Existing** in part.

## Social

Observation: shared pens in view, a small leaderboard still, server announcement text. · Evidence: `ingame_hud_leaderboard` (not reopened this pass), clip4 banner. · Feed a Pet: players share the field; no leaderboard. · Uncertain: PvP; `pvp_safe_zone` and `pvp_bat_ragdoll` stills (REF-GD-042, REF-GD-043) were **not** inspected.

## Events

Observation: an admin-started boss event announced in the top banner and chat ("Dr. Scramble's Mech", jump in the portal at spawn), a "NEW BIOME IS COMING" join-event popup with a date and a Notify Me button, and night and potion timers. The clip file name mentions a secret spawn; no secret-spawn announcement was seen in the extracted frames. · Evidence: clip1 and clip4 frames. · Feed a Pet: field reset timer and rare announcements only. · Adapt: **Consider** after the five-area loop is approved; cadence UNKNOWN.

## What Not to Take

Egg branding, brainrot pets, character, rarity names that differ from the locked ten, prices, Robux packs, the `+1 EQUIP` ladder, exact guardian speeds inferred from stills, protected art.

## Related Notes

[[04 - Reference Research/Reference Manifest]], [[05 - Development/Decisions and Open Questions]], [[03 - Visual Design/Art Direction]].
