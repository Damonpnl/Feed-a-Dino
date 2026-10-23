---
type: reference-index
status: mixed
last_verified: 2026-10-21
source_paths:
  - references/reference
  - Feed-a-Pet-Vault/04 - Reference Research/Reference Manifest.csv
---

# Reference Manifest

## At a Glance

Index of the Steal an Egg reference pack under `references/reference` (255 files). **Reference only; originals are never moved or modified.** The complete machine-readable list with stable IDs is `Reference Manifest.csv` in this folder (columns: ID, FileName, Path, MediaType, Width, Height, DurationSec, Bytes, Category, InspectionStatus, ObservedContents, VaultPreview). Search it in Obsidian or with a text tool. To route a visual task, use [[00 - Home/Task Router]] and [[03 - Visual Design/Visual Reference Gallery]]; open one file, not a folder.

## ID Scheme

`REF-<folder>-<NNN>`, numbered in sorted-path order inside the folder: GD guides (63), IG ingame (20), VC ingame_clips (4), OF official (14), WK wiki (109), YS youtube_storyboards (29), YT youtube_thumbs (16). IDs stay stable while the pack is unchanged; adding files can shift later numbers, so cite filename with the ID.

## Counts (measured 2026-10-21 with ffprobe)

Categories (heuristic, from file names): UI 49, Video-derived 45, Resources 29, Guardians 27, World 22, Gameplay 19, Wiki misc 16, Training equipment 15, Marketing 14, Events 7, Creatures 6, Video 4, Cosmetics 2.
Inspection status: metadata-only 127, sampled-earlier-not-itemized 63, not-opened-this-pass 29, inspected-this-pass 25, inspected-earlier-session (not re-opened this pass) 7, inspected-this-pass (contact sheet plus keyframes) 4.
`metadata-only` means dimensions were read and the content was not viewed. Several wiki `.png` files hold WebP data; some guide `.webp` files cannot be opened by the agent file viewer, so Pillow or FFmpeg was used. A few wiki renders decode with artifacts (REF-WK-021 desert guardian, REF-WK-023 jungle guardian, REF-WK-058 flame treadmill; Pillow output showed streaking) and were not copied into the vault.

## Videos (decoded with FFmpeg)

All four clips: 1280 x 694. Each was inspected through a 12-frame contact sheet and selected keyframes (stored in `Attachments/Video-Keyframes`, JPEG 960 px wide). Audio was not examined. Keyframe time is a seek position in the original; do not infer motion or timing from a single frame.

| ID | File | Duration | What the clip shows | Keyframes |
| --- | --- | ---: | --- | --- |
| REF-VC-001 | `ingame_clips/clip1_base_pen_income_night_to_day_reset.mp4` | 62 s | Base pen, pets earning, floating `+$` popups, upgrade board, night and potion timers counting down, shop opening at the end | clip1-t003, t036, t057 |
| REF-VC-002 | `ingame_clips/clip2_shop_full_tour.mp4` | 140 s | Shop scrolled through Featured, Passes, Speed, speed packs, money packs, then the Index | clip2-t005, t028, t060, t105 |
| REF-VC-003 | `ingame_clips/clip3_pet_index.mp4` | 90 s | Pet Index pages (Forest 3/8, then another biome), claim bar, world and limited tabs | clip3-t010, t060, t075 |
| REF-VC-004 | `ingame_clips/clip4_announcements_admin_secret_spawn.mp4` | 35 s | Index open with a "NEW BIOME" event popup and top-of-screen server announcement banners | clip4-t015, t020 |

None of the clips shows guardian wake, pursuit, pickup, escape, or delivery. Those timings remain UNKNOWN ([[04 - Reference Research/Steal an Egg Analysis]]).

## Inspected Images

### UI

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-GD-062 | `guides/ui_slow_mode_allthings.webp` | 1280x720 | HUD with left Shop/Index/Slow Mode stack, bottom-left stats, lane | [[Attachments/UI/sae-ui-slow-mode-lane.jpg]] |
| REF-IG-002 | `ingame/ingame_002_shop_featured_extinction_egg.jpg` | 2560x1387 | Featured shop tab with a limited egg, odds, countdown, price buttons | [[Attachments/UI/sae-shop.jpg]] |
| REF-IG-010 | `ingame/ingame_010_index_forest_chicken.jpg` | 2560x1387 | Pet Index page with a forest slot and a chicken-like pet | [[Attachments/UI/sae-index.jpg]] |
| REF-IG-017 | `ingame/ingame_hud_bottomleft_speed_money.png` | 409x236 | Bottom-left HUD: speed and cash counters | [[Attachments/UI/sae-hud-speed-cash.png]] |
| REF-WK-079 | `wiki/ui__Pet.png` | 290x481 | Shop card: Legendary Brr Brr Patapim, income per second | [[Attachments/Creatures/sae-pet-card-patapim.png]] |
| REF-WK-094 | `wiki/ui__Zone_all.png` | 1572x786 | Lane view with ice-blue and lava-edged sections and a pet | [[Attachments/World/sae-zones-lane-overview.jpg]] |

### World

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-GD-035 | `guides/map_biome_map_eldorado.webp` | 1120x434 | Straight lane between brick walls, green floor, distant structure | [[Attachments/World/sae-lane-biome-view.jpg]] |
| REF-WK-102 | `wiki/zone__Forest.png` | 420x255 | Flat illustrated forest pond (index art) | [[Attachments/World/sae-zone-art-forest.jpg]] |
| REF-WK-103 | `wiki/zone__Jungle.png` | 420x280 | Flat illustrated jungle (index art) | [[Attachments/World/sae-zone-art-jungle.jpg]] |
| REF-WK-104 | `wiki/zone__Lake.png` | 420x280 | Flat illustrated lake and mountains (index art) | [[Attachments/World/sae-zone-art-lake.jpg]] |
| REF-WK-105 | `wiki/zone__Prehistoric.png` | 420x237 | Flat illustrated prehistoric valley (index art) | [[Attachments/World/sae-zone-art-prehistoric.jpg]] |
| REF-WK-106 | `wiki/zone__Snow.png` | 420x236 | Flat illustrated snow field (index art) | [[Attachments/World/sae-zone-art-snow.jpg]] |
| REF-WK-109 | `wiki/zone__Volcano.png` | 420x260 | Flat illustrated volcano and lava (index art) | [[Attachments/World/sae-zone-art-volcano.jpg]] |

### Gameplay

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-IG-001 | `ingame/ingame_001_spawn_base_overview.jpg` | 2560x1387 | Stud-floor pen with fence, upgrade board, pets with income text, full HUD | [[Attachments/World/sae-base-overview.jpg]] |
| REF-IG-014 | `ingame/ingame_frame_pen_pets_close.jpg` | 1280x694 | Close view of fenced pen: oversized pets, income popups, Upgrade Pen board, player list top right, left button stack | [[Attachments/World/sae-pen-close.jpg]] |

### Guardians

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-GD-027 | `guides/guardian_09_cosmic_dragon_ign.webp` | 1311x690 | Dark sleeping figure with halo and Z marks, stars | [[Attachments/Creatures/sae-guardian-cosmic-sleeping.jpg]] |
| REF-WK-021 | `wiki/guardian__DesertGuardian.png` | 1536x1024 | Sleeping scorpion (decoded with artifacts) |  |
| REF-WK-022 | `wiki/guardian__ForestGuardian.png` | 1536x1024 | Sleeping white chicken with Z marks | [[Attachments/Creatures/sae-guardian-forest-chicken-sleeping.png]] |
| REF-WK-023 | `wiki/guardian__JungleGuardian.png` | 1706x922 | Sleeping striped tiger (decoded with artifacts) |  |
| REF-WK-025 | `wiki/guardian__PrehistoricGuardian.png` | 1254x1254 | Green faceted T-Rex, open mouth | [[Attachments/Creatures/sae-guardian-prehistoric-trex.png]] |
| REF-WK-027 | `wiki/guardian__TitanTempleGuardian.png` | 1254x1254 | Crowned black gorilla with red eyes | [[Attachments/Creatures/sae-guardian-titan-gorilla.png]] |
| REF-WK-028 | `wiki/guardian__VolcanoGuardian.png` | 1254x1254 | Multi-headed black hound with flame crests | [[Attachments/Creatures/sae-guardian-volcano-hound.png]] |

### Creatures

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-WK-037 | `wiki/pet__Bear.png` | 281x420 | Brown faceted bear on black | [[Attachments/Creatures/sae-pet-bear.png]] |
| REF-WK-041 | `wiki/pet__King_Snake.png` | 420x419 | Green faceted spiky head with red tongue |  |

### Resources

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-WK-005 | `wiki/egg__Extinction_Egg.png` | 1254x1254 | Spiked red/orange egg with horns | [[Attachments/Resources/sae-egg-extinction.png]] |
| REF-WK-007 | `wiki/egg__Luminous_Egg.png` | 1254x1254 | Green tentacle-ringed glowing egg | [[Attachments/Resources/sae-egg-luminous.png]] |
| REF-WK-030 | `wiki/mutation__Golden.png` | 384x420 | Golden crystal icon, thick outline | [[Attachments/Resources/sae-mutation-golden-icon.png]] |

### Training equipment

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-GD-058 | `guides/treadmills_ranked_gameboost.webp` | 1448x818 | Ranked treadmill lineup, text overlay | [[Attachments/Resources/sae-treadmills-ranked.jpg]] |
| REF-WK-058 | `wiki/treadmill__Flame_Treadmill.png` | 512x512 | Treadmill render (decoded with artifacts) |  |

### Marketing

| ID | Path | Size | Observed | Vault preview |
| --- | --- | --- | --- | --- |
| REF-OF-008 | `official/game_icon_512.png` | 512x512 | Game icon | [[Attachments/Creatures/sae-icon.png]] |
| REF-OF-011 | `official/thumbnail_1_119722099122044_768x432.png` | 767x432 | Marketing thumbnail with a T-Rex and an egg | [[Attachments/Creatures/sae-thumb-trex-egg.png]] |
| REF-OF-013 | `official/thumbnail_3_77977678889221_768x432.png` | 767x432 | Marketing thumbnail with a yeti | [[Attachments/Creatures/sae-thumb-yeti.png]] |

## Not Itemized Here

The remaining images (guides, wiki, YouTube storyboards and thumbs, badges, passes, thumbnails) are listed in the CSV with `metadata-only`, `sampled-earlier-not-itemized`, or `not-opened-this-pass` status. Research text lives in `references/research/01_fandom_wiki.md` through `06_fixes_applied.md` and `raw/`; the wiki dump contains conflicting numbers by its own labels and none are Feed a Pet tuning.

## Constraints

Do not copy protected art. Do not delete or reorganize `references/`. Vault copies are small previews; originals stay authoritative.

## Related Notes

[[03 - Visual Design/Visual Reference Gallery]], [[05 - Development/Decisions and Open Questions]].
