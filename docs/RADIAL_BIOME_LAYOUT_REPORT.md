# Radial Biome Layout Report

Centered guardians and radial resource spawning for Grasslands, Swamp, Jungle, CrystalCave and Volcano.
All numbers below come from Studio MCP Play sessions on place 104154372052853 against the live blockout.
Runners are server-scripted (Humanoid `MoveTo` for approach, kinematic anchored runners for the escape sweep);
they do not dodge, so they are evidence about geometry and timing, not human playtests.

## Outcome

- Every guardian sleeps at a data-driven home in the middle of its biome, facing the base.
- Each biome still has exactly five Phase 2 nodes. Resources are placed on a 24–90 stud annulus around the
  guardian, and no resource may sit more than 24 studs behind the home (away from safety). Placement is
  validated against the live floor, walls and props, kept out of a 26-stud through-lane, and separated by at
  least 22 studs.
- That rear cap is the shipped rule. An earlier measurement with the full annulus (1,170 candidates, spawns up
  to 78 studs behind the guardian) escaped 209/280 trials. With `RearDepth = 24` (732 candidates) the same
  sweep escaped 236/280. Pursuit rules, carry speeds and guardian speeds were not changed.
- Theft triggered the existing Phase 3B pursuit from every measured spawn (280/280 trials). Guardians never
  entered the safe zone. Every watched guardian walked home and slept facing safety.
- No map change was needed. Every biome supports the requested radius with the rear cap. The remaining hard
  runs are slow carriers in CrystalCave, overtaken on the long runway, not deep spawns behind the guardian.

## What changed

| File | Change |
| --- | --- |
| `src/shared/BiomeLayout.luau` (new) | Frozen per-biome territory config, including `RearDepth`, and `Layout.validate`. |
| `src/shared/RadialSpawn.luau` (new) | Pure territory geometry. The far end of the sample region is clipped to `home + RearDepth`. |
| `src/server/BiomeTerritory.luau` (new) | Builds each territory once from the live floor; raycast + overlap probe per candidate. |
| `src/server/GuardianService.luau` | Guardian home and sleeping facing come from `BiomeTerritory.home`; every return-to-home path re-faces safety. |
| `src/server/ResourceService.luau` | New records without a position get one from `BiomeTerritory.pick` on a separate random stream. |
| `src/server/ZoneGeometry.luau` | Removed the unused `guardianPoint`. |
| `src/shared/DefinitionValidation.luau` | Validates `BiomeLayout` at startup. |
| `tests/unit/Cases/RadialSpawn_Test.luau` (new) | 10 unit tests, including the rear-depth cap. |
| `tests/RadialLayout.server.luau` (new) | Opt-in Play fixture: `Mode="Validate"` or `Mode="Escape"` (optional `Area`). Escape waits until the field is Normal and every biome has five stocked nodes. |
| `tests/Phase3Integration.server.luau` | Hold point stays on the floor (see Regressions). |
| `tests/Phase3BMultiplayer.server.luau` | Waits out catch recovery; carries the pre-reset item to safety (see Regressions). |

Not changed: `FieldState`, `SpawnService`, node markers, rarity pools, respawn timers, reset timing, Secret+
rules, `GuardianConfig`, `GuardianChase`, carry speeds, curses, Power, evolution. No Workspace edits, no new
remotes, no DataStore changes.

## Layout model

All five biomes use the same default row (`BiomeLayout.Areas`):

| Key | Value | Meaning |
| --- | --- | --- |
| `HomeAlong` | 0.5 | Home at the lengthwise center of the biome floor |
| `HomeLateral` | 0 | Home on the midline of the territory (the floor minus the lane) |
| `Facing` | `Entrance` | Sleeping guardian faces the base |
| `MinRadius` / `MaxRadius` | 24 / 90 | Resource annulus around the home |
| `RearDepth` | 24 | Maximum studs a resource may sit behind the home, along the biome, away from safety |
| `Separation` | 22 | Minimum resource-to-resource spacing |
| `EndMargin` | 12 | Keep-out from both biome ends |
| `Clearance` / `ClearanceHeight` | 4 / 7 | 8 x 7 x 8 box above each spawn must be empty (model plus pickup room) |
| `Grid` | 4 | Candidate grid step |
| `LaneSide` / `LaneWidth` / `LaneMargin` | +1 / 26 / 4 | Through-lane strip along the +Z wall, kept free of resources and the home |
| `MinCandidates` | 200 | Startup fails if the geometry supports fewer positions |

`Layout.GuardianClearance = 12` (sleeping body half-diagonal plus a resource half-size); validation requires
`MinRadius >= GuardianClearance + Clearance`. `RearDepth` must be between 0 and `MaxRadius`.

The map has no physical corridor, so the primary through-path is defined as data: the 26-stud lane along the
+Z wall. Ordinary travel down that lane, or even 9 studs past a sleeping guardian, never wakes it (verified).

Candidates are computed once at startup. A candidate is kept only if a downward ray hits that biome's own floor
with an upward normal and the clearance box overlaps nothing (generated gameplay and characters excluded).
The sample region stops at `home + RearDepth` on the far side, so the base side of the annulus is unchanged.
Resources are placed when a record has no position: initial fill, mid-cycle refill and the hard-reset refill.
The pick is uniform among candidates at least 22 studs from every other non-carried resource in the biome;
if a biome were ever saturated it falls back to the most isolated candidate. Node markers in Workspace remain
the identity and respawn slots; only the world position comes from the territory.

### Measured footprints and homes

Coordinates are world studs. "From safety" is the distance along the runway from the safe-zone boundary (X 283.4).

| Biome | Floor (X x Z) | Home (X, Z) | Home from safety | Territory lateral (from floor center) | Lane | Candidates |
| --- | --- | --- | --- | --- | --- | --- |
| Grasslands | 350.3 x 157.4 | 458.5, -99.2 | 175.1 | -74.7 .. 48.7 | 52.7 .. 78.7 | 732 |
| Swamp | 287.6 x 157.4 | 777.5, -99.2 | 494.1 | -74.7 .. 48.7 | 52.7 .. 78.7 | 732 |
| Jungle | 287.6 x 157.4 | 1064.5, -99.2 | 781.1 | -74.7 .. 48.7 | 52.7 .. 78.7 | 732 |
| CrystalCave | 287.6 x 157.4 | 1351.5, -99.2 | 1068.1 | -74.7 .. 48.7 | 52.7 .. 78.7 | 732 |
| Volcano | 287.6 x 157.4 | 1638.5, -99.2 | 1355.1 | -74.7 .. 48.7 | 52.7 .. 78.7 | 732 |

Without `RearDepth` each biome had 1,170 candidates. The 90-stud annulus fits inside every biome's ends, and
the probe rejected no grid points: the floors are flat and the blockout has no props inside the territories.
**No biome geometry is too small for the requested radius.** The binding limits are the side walls and the
24-stud rear cap. The territory reaches about 58 studs from the home towards -Z and 62 studs towards +Z (the
lane), so the full 90-stud radius is only available toward safety, along the length of the biome.

## Validate mode (Play, single player, with RearDepth): PASS, 894 checks

- Node identities match the Workspace markers; 5 nodes and 5 resources per biome; each guardian SLEEPING at home
  facing safety.
- Every resource is inside its territory, on its own floor, overlaps no solid geometry, is clear of the guardian
  body and at least 22 studs from the others. Verified on the initial fill and again after a hard reset.
- 400 simulated five-resource fills per biome, same seed: radius 24.0–89.9 (mean 55), minimum separation 22.6.
  Eight 45-degree sectors around the home, counted from straight back: 491, 280, 186, 33, 30, 190, 312, 478
  (2,000 placements). 1,561 (78%) sit on the base side of the home. The 439 behind it are out to the sides and
  at most 24 studs past the home; the two straight-back sectors hold 63 placements. Before the cap the same
  fills were 48% on the base side and 52% behind, mean radius 59.1.
- Real Humanoid locomotion from the lane reached all 25 resources, picked each up, and every pickup woke the
  guardian into pursuit. The uncapped run recorded approaches of 26.7–138.7 studs (1.6–14.6 s).
- Walking through every biome, 9 studs past each sleeping guardian, woke none of them.
- 40 mid-cycle release/refill rounds: respawn timers unchanged, same node slot and fresh GUID, refills never roll
  Secret+, every refill lands inside its territory with 22-stud separation and a world model.
- Hard reset: the carried resource survives with its node detached; every other node refills with a fresh GUID
  and a valid placement.

## Escape sweep (Play, single player): PASS on all invariants, 280 trials

Each node kept the position from its initial fill. Grasslands, Swamp, Jungle and CrystalCave ran three carriers
at base speeds 16, 18, 22 and 30 (60 trials). Volcano ran two (40 trials). The runner moves at
`base * live WalkSpeed / 16`, so the carry slowdown and curse slowdowns scale every base speed. A runner that
starts beside or behind the guardian first swings 50 studs to its side of the guardian, then runs straight for
safety. The guardian's speed rules are unchanged (1.10x the carrier's fixed baseline within 30 studs, 1.75x
beyond 60).

Carriers: Grasslands RawMeat / AncientBone / PrimalCatalyst; Swamp SmallFish / VenomSac / MutantLeech; Jungle
WildFruit / RareFlower / BeastHeart; CrystalCave CrystalShard / FossilMarrow / PrismaticCrystal; Volcano
CharredMeat / DragonScale. Volcano has no slowed-but-uncursed category, because no curse-free Volcano resource
is slower than Charred Meat (18% slowdown). Cursed trials rerolled the carry until a curse was actually assigned.

Invariants on every trial: pursuit began, the guardian stayed out of the safe zone, and one trial per biome
watched the return home. On the four biomes whose raw rows were kept, pursuit began 0.78–0.83 s after theft
(the 0.8 s wake). Grasslands' raw rows were not kept after a later Play restart; its fixture still passed the
pursuit check on all 60 trials. The closest any guardian came to safety was 14.7 studs (the standoff is 10).
Returns: Grasslands 3.5 s, Swamp 13.6 s, Jungle 21.2 s, CrystalCave 29.8 s, Volcano 37.9 s. Each ended
SLEEPING within 2 studs of home, facing safety.

### Escapes per biome, carrier and speed (out of 5 nodes), with RearDepth

| Biome | Carrier | 16 | 18 | 22 | 30 |
| --- | --- | --- | --- | --- | --- |
| Grasslands | Ordinary | 3 | 5 | 5 | 5 |
| | Slowed | 3 | 5 | 5 | 5 |
| | Cursed | 3 | 5 | 5 | 5 |
| Swamp | Ordinary | 3 | 5 | 5 | 5 |
| | Slowed | 1 | 5 | 5 | 5 |
| | Cursed | 2 | 5 | 5 | 5 |
| Jungle | Ordinary | 5 | 5 | 5 | 5 |
| | Slowed | 5 | 5 | 5 | 5 |
| | Cursed | 5 | 5 | 5 | 5 |
| CrystalCave | Ordinary | 0 | 0 | 5 | 5 |
| | Slowed | 0 | 0 | 5 | 5 |
| | Cursed | 1 | 3 | 4 | 5 |
| Volcano | Ordinary | 5 | 5 | 5 | 5 |
| | Cursed | 3 | 5 | 5 | 5 |

By speed across all biomes: 16: 39/70 (56%), 18: 58/70 (83%), 22: 69/70 (99%), 30: 70/70 (100%).
Total 236/280 escaped; 31 body catches, 13 hazard hits, no timeouts. The uncapped sweep was 209/280
(35/70, 47/70, 57/70, 70/70), with 46 body catches and 25 hazard hits.

### Per node, with RearDepth

"Offset" is the node's distance along the runway relative to the guardian home: negative is on the base side,
positive is behind the guardian. Escapes are out of 12 trials (8 in Volcano). Nothing is deeper than 24 studs
behind the home.

| Node | Theft distance | From safety | Offset | Escapes | Notes |
| --- | --- | --- | --- | --- | --- |
| Grasslands:Node01 | 50.2 | 125.7 | -49.4 | 12/12 | |
| Grasslands:Node02 | 68.1 | 117.9 | -57.2 | 12/12 | |
| Grasslands:Node03 | 37.7 | 171.0 | -4.1 | 9/12 | all carriers caught at 16, in 7–11 s |
| Grasslands:Node04 | 72.4 | 105.7 | -69.4 | 12/12 | |
| Grasslands:Node05 | 32.7 | 200.3 | +25.2 | 9/12 | caught at 16 in about 3.3 s; escaped at 18+ |
| Swamp:Node01 | 64.7 | 514.6 | +20.5 | 10/12 | ordinary and slowed caught at 16 (11–14 s) |
| Swamp:Node02 | 30.3 | 477.3 | -16.8 | 10/12 | ordinary and slowed caught at 16 (25–30 s) |
| Swamp:Node03 | 73.1 | 428.8 | -65.3 | 11/12 | cursed caught at 16 (27 s) |
| Swamp:Node04 | 34.5 | 460.6 | -33.5 | 10/12 | slowed and cursed caught at 16 (24–29 s) |
| Swamp:Node05 | 46.2 | 473.4 | -20.7 | 10/12 | slowed and cursed caught at 16 (23–27 s) |
| Jungle:Node01 | 58.8 | 723.6 | -57.5 | 12/12 | |
| Jungle:Node02 | 75.9 | 736.2 | -44.9 | 12/12 | |
| Jungle:Node03 | 45.5 | 781.1 | 0 | 12/12 | level with the guardian; all escaped |
| Jungle:Node04 | 89.6 | 711.9 | -69.2 | 12/12 | |
| Jungle:Node05 | 40.9 | 743.7 | -37.4 | 12/12 | |
| CrystalCave:Node01 | 61.5 | 1018.9 | -49.2 | 8/12 | ordinary and slowed caught at 16 and 18 |
| CrystalCave:Node02 | 35.7 | 1080.6 | +12.5 | 5/12 | hazard hits at 16–18; cursed also caught at 22 (6.0 s) |
| CrystalCave:Node03 | 81.6 | 986.6 | -81.5 | 6/12 | caught or hazard-hit at 16–18 |
| CrystalCave:Node04 | 68.1 | 1031.3 | -36.8 | 7/12 | hazard hits at 16; ordinary and slowed caught at 18 |
| CrystalCave:Node05 | 86.3 | 986.7 | -81.4 | 7/12 | caught at 16–18; cursed hazard-hit at 16 |
| Volcano:Node01 | 85.6 | 1277.7 | -77.4 | 8/8 | |
| Volcano:Node02 | 64.7 | 1334.6 | -20.5 | 7/8 | cursed hazard hit at 16 (46 s) |
| Volcano:Node03 | 61.6 | 1351.0 | -4.1 | 8/8 | |
| Volcano:Node04 | 42.7 | 1317.8 | -37.3 | 8/8 | |
| Volcano:Node05 | 54.1 | 1301.6 | -53.5 | 7/8 | cursed hazard hit at 16 (47 s) |

### Chase and catch timing, with RearDepth

- Speed-30 escapes (theft to safety): Swamp 15–21 s, Jungle 26–34 s, CrystalCave 37–47 s, Volcano 52–64 s.
  Grasslands' speed-30 band was not retained; its nodes are 106–200 studs from safety and its watched guardian
  was home in 3.5 s.
- A successful speed-16 escape takes up to 39 s from Swamp, 68 s from Jungle, 83 s from CrystalCave and 123 s
  from Volcano.
- Catches and hazard hits:
  - **About 3.3 s:** the one Grasslands node 25 studs behind the guardian, speed 16 only, caught while swinging past.
  - **7–30 s:** speed 16 in Grasslands and Swamp, overtaken after getting past the guardian (catch gap about 4.7).
  - **5–18 s:** CrystalCave at speeds 16–18, a mix of body catches and the 110-stud Charge (0.75 s warning).
    One cursed rear node was also caught at speed 22 in 6.0 s.
  - **46–47 s:** two Volcano cursed hazard hits at speed 16, gap 13.6, so the charge landed during the long run
    rather than a body catch. Volcano had no body catches.

### Where the capped spawns sit

| Spawn side | Trials | Escaped |
| --- | --- | --- |
| Base side (offset -12 or more toward safety) | 212 | 183 (86%) |
| Within 4 studs of the guardian, on the base side or level | 32 | 29 (91%) |
| Behind the guardian, +12 to +25 | 36 | 24 (67%) |

The three behind-the-guardian nodes are Grasslands:Node05 (+25, 9/12), Swamp:Node01 (+21, 10/12) and
CrystalCave:Node02 (+13, 5/12). The CrystalCave node is the weak one, and its losses are hazard hits and one
speed-22 catch, not the old 3-second swing-past at every speed up to 22.

## Rear depth

The first sweep used the full annulus. About half of those spawns landed behind the guardian. Grouped by side:

| Spawn side (no rear cap) | Trials | Escaped |
| --- | --- | --- |
| Base side (offset -12 or more toward safety) | 156 | 147 (94%) |
| Level with the guardian (Swamp:Node03) | 12 | 9 (75%) |
| Behind the guardian, +16 to +29 | 48 | 29 (60%) |
| Behind the guardian, +49 to +78 | 64 | 24 (38%) |

Deep rear spawns (+77) were caught within about 3 seconds at every speed up to 22. Only speed 30 reliably
escaped, because the thief had to pass a guardian that woke 0.8 s after the theft.

`RearDepth = 24` is the implemented choice. It keeps the base side of the annulus and cuts anything deeper
than 24 studs behind the home. The +49 to +78 group is gone. Moving the home deeper (`HomeAlong = 0.65`) was
not used: the guardian stays at the biome center. Guardian speeds were not raised to compensate for placement.

The uncapped per-node table is kept below so the comparison stays checkable.

### Uncapped per node (not the shipped layout)

| Node | Theft distance | From safety | Offset | Escapes | Notes |
| --- | --- | --- | --- | --- | --- |
| Grasslands:Node01 | 51.0 | 162.8 | -12 | 12/12 | closest guardian approach 5.1 studs (cursed, 16) |
| Grasslands:Node02 | 86.5 | 110.0 | -65 | 12/12 | |
| Grasslands:Node03 | 46.2 | 133.8 | -41 | 12/12 | |
| Grasslands:Node04 | 78.4 | 105.8 | -69 | 12/12 | |
| Grasslands:Node05 | 67.7 | 146.5 | -29 | 12/12 | |
| Swamp:Node01 | 33.7 | 523.4 | +29 | 10/12 | ordinary/slowed caught at 16 |
| Swamp:Node02 | 63.6 | 510.5 | +16 | 9/12 | all carriers caught at 16 |
| Swamp:Node03 | 37.5 | 494.1 | 0 | 9/12 | all carriers caught at 16 |
| Swamp:Node04 | 80.1 | 571.6 | +78 | 4/12 | caught about 2.8 s after theft at 16–22 |
| Swamp:Node05 | 55.2 | 469.4 | -25 | 10/12 | |
| Jungle:Node01 | 85.6 | 858.5 | +77 | 4/12 | caught about 3.0 s after theft at 16–22 |
| Jungle:Node02 | 86.3 | 699.7 | -81 | 12/12 | |
| Jungle:Node03 | 55.9 | 764.7 | -16 | 12/12 | |
| Jungle:Node04 | 41.7 | 739.6 | -42 | 12/12 | |
| Jungle:Node05 | 61.0 | 736.0 | -45 | 12/12 | |
| CrystalCave:Node01 | 59.7 | 1084.5 | +16 | 6/12 | hazard hit about 5 s after theft at 16–18 |
| CrystalCave:Node02 | 41.1 | 1097.2 | +29 | 4/12 | |
| CrystalCave:Node03 | 61.5 | 1117.3 | +49 | 3/12 | only speed 30 escapes |
| CrystalCave:Node04 | 89.3 | 1145.4 | +77 | 3/12 | only speed 30 escapes |
| CrystalCave:Node05 | 89.2 | 1003.0 | -65 | 6/12 | overtaken 10–18 s after theft at 16–18 |
| Volcano:Node01 | 82.5 | 1432.5 | +77 | 5/8 | ordinary lost at 16–22 |
| Volcano:Node02 | 49.7 | 1305.6 | -50 | 7/8 | |
| Volcano:Node03 | 41.1 | 1326.0 | -29 | 8/8 | |
| Volcano:Node04 | 91.4 | 1432.4 | +77 | 5/8 | |
| Volcano:Node05 | 66.0 | 1322.3 | -33 | 8/8 | |

Uncapped speed-30 escapes took Grasslands 3.6–4.4 s, Swamp 17–20 s, Jungle 27–32 s, CrystalCave 40–48 s and
Volcano 55–63 s. The closest a guardian came to safety in that sweep was 14.2 studs. Returns were 4.3, 13.6,
20.8, 30.6 and 38.2 s.

## Regressions (actual Studio Play / StudioTestService)

The suite below passed on the centered layout before `RearDepth` was added. After the cap, the unit suite,
RadialLayout Validate and the escape sweep were run again. The other Play fixtures were not repeated: the cap
only removes candidates farther than 24 studs behind the home, so the positions they can hit are a subset of
the annulus those fixtures already ran on.

| Fixture | Mode | Result |
| --- | --- | --- |
| Phase1Integration | Play, single player | PASS 32 |
| FieldRuntimeSmoke | Play | PASS 14 |
| FieldIntegration | Play, includes a field reset | PASS 20 |
| Phase3Integration | Play | PASS 127 (after fixture fix) |
| Phase3BRunway | Play | PASS 42 |
| Phase3Rollback | Play | PASS 9 |
| Phase4ACompatibility | Play | PASS 13 |
| Phase4AIntegration | Play with the Phase4APresentation client fixture, includes an actual reset | PASS 33 |
| Phase4CIntegration | Play | PASS 89 |
| Phase4DIntegration | Play | PASS 18 |
| StudioMemoryFeeding | Play, fresh session, real FEED button click | PASS 55 |
| GameplayTuning (Locomotion) | Play | PASS 23 |
| Phase3Multiplayer | Two actual Studio clients | PASS 32 |
| Phase3BMultiplayer | Two actual Studio clients | PASS 120 (after fixture fixes; no safe-zone, footprint or overlap intrusions, min guardian spacing 22.3) |
| Phase4AMultiplayer | Two actual Studio clients | PASS 18 |
| Phase4BMultiplayer | Two actual Studio clients | PASS 11 |
| GameplayTuningMultiplayer | Two actual Studio clients | PASS 39 |
| Unit suite (`RunUnitTest`, 10 RadialSpawn cases) | Play server, after the cap | 337 run, 337 passed |
| RadialLayout Validate | Play, after the cap | PASS 894 |
| RadialLayout Escape (one run per biome) | Play, after the cap | PASS x5 (280 trials) |

Two fixtures had assumptions about the old layout and were fixed in the test, not in gameplay code:

- **Phase3Integration** holds an anchored carrier 22 studs from the guardian until it telegraphs. With the
  guardian now approaching from the side, the push could leave the floor through the +Z wall (seen at Z +4.5).
  No fair attack lane exists to that point, so the telegraph never came. The hold point now stays on the floor
  and falls back to the safe-side direction.
- **Phase3BMultiplayer** had two problems:
  - Player B could be body-caught beside player A, and the first repeated pickup landed inside the 2.2 s catch
    recovery. The test now waits for recovery to end first.
  - The pre-reset theft stood still for 4.5 s, which is long enough for a centered guardian to catch it. The
    thief now carries the item into the safe zone, so the reset rather than a catch ends the carry.

Earlier failures in the first batch had other causes. StudioMemoryFeeding needs a fresh session and a real FEED
click. GameplayTuning failed only because StudioMemoryFeeding aborted while still carrying an item. Both pass
when run correctly.

Phase4APresentation's own client attributes could not be read back after the run (the LocalScript was gone from
PlayerGui). The server fixture's real-client check, "Real client remote spam consumes once", passed, and the
console showed no client warning.

Running escape fixtures back to back can start one inside a field reset. A crashed fixture then called
`field:create` during that reset, the refill hit "Node already occupied", and the SpawnService step loop died.
Only these fixtures create records directly. The escape fixture now waits until the field is Normal, the next
reset is more than 20 s away, and every biome has five available nodes. Production spawning was not changed.

## Remaining risks

- CrystalCave at speeds 16 and 18 is the balance question this layout still raises. Front-side nodes there
  escaped 28/48, and the one rear node escaped 5/12. Losses are the long runway plus the Charge, not deep
  spawns behind the guardian. Jungle, by contrast, escaped 60/60, including a node level with its guardian.
- Runners are scripted and never dodge. Human players with dodges should do better against telegraphed
  attacks. They still have to clear a guardian that wakes 0.8 s after a theft from 24 studs behind it; at
  speed 16 that Grasslands node was caught in about 3.3 s.
- Placement is uniform over the candidates, not over the annulus area. The rear cap and the side walls put
  most spawns on the base side and along the biome's length.
- Candidates are computed once at startup. Props added later in Studio are respected after the next server start;
  a prop moved at runtime is not.
- Every biome uses the same row. If a biome later gets props, hazards or a different corridor, give it its own
  row; startup will fail with a clear message if it can no longer support the radius.
