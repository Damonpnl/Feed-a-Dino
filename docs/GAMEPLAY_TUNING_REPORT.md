# Gameplay Tuning Report: Early-Game Pacing and Guardian Chase

Status: provisional tuning, measured in Studio with scripted runners. Not a human playtest.
Scope stops here; Phase 5 was not started.

## 1. Audit (before changes)

### Measured layout (Studio Play, `workspace.GeneratedGameplay`)

| Item | Value |
|---|---|
| Safe-zone boundary (`SafeZoneBoundary`) | X = 283.4 (along-axis 0) |
| T-Rex sleep point | along 298 (X 581); every guardian sleeps at the far end of its biome |
| Grasslands nodes, studs from safety | 66, 120, 174, 229, 283 |
| Guardian body | anchored 10 x 12 x 18 part, faces its movement |
| Player | R15, WalkSpeed 16, HipHeight 2.7, root 1.4 x 1.8 x 0.85 |
| Character joints | `AnimationConstraint` rig with paired `BallSocketConstraint`s (no `Motor6D`) |

### Original values and why the T-Rex was not threatening

| Rule | Original |
|---|---|
| First evolution | 50 Growth, branch affinity minimum 40 (10 Raw Meat trips) |
| Wake | 0.6 s (global) |
| Pursuit speed | flat 18 studs/s x rarity profile (1.00-1.09); ignored carry slowdown |
| Catch | none; only a successful signature hazard could drop the item |
| Cooldown | guardian stood still for the whole cooldown (8 s Grasslands Common) |
| Attacks | started within 32 studs, froze the guardian for Warning + Active (2.2 s for the Charge) |

Root causes found:

1. There was no catch at all. A guardian on top of a carrier did nothing.
2. The Charge lane is centred on the guardian and reaches only 45 studs ahead. A carrier
   running straight away at 16 studs/s outruns the sweep (it can only hit within about 5 studs).
   So every attack from 32 studs missed and handed the carrier about 35 studs while the guardian froze.
3. The guardian stopped for the entire cooldown.
4. Closing speed was about 2 studs/s from up to 232 studs away, so only geometry decided outcomes.

## 2. First evolution

| | Before | After |
|---|---|---|
| `GrowthStageDefinitions.Stages[0].GrowthRequired` | 50 | **25** |
| First-branch affinity minimum | hardcoded 40 | **`Stages[0].AffinityRequired = 20`** (same 80% dominance) |
| Later stages | 80 / 160 / 3000 | unchanged |
| Resource Growth values | unchanged | unchanged |

Halving only the Growth threshold would have made the 40-affinity branches unreachable,
so every pet would fall back to Juvenile Rex. The affinity minimum is now configurable
next to the threshold, and `EvolutionCalculator.validate` rejects an affinity minimum
above its stage's Growth requirement. `MonsterService`'s fallback threshold now reads the config.

Trips to the first evolution (one carry per trip): Raw Meat 5, Berries 5, Bone Chunk 4,
any Rare or better in the mix 2-3. Five Raw Meat give Flesh 25, which yields Fangling.

Save compatibility: existing pets above 25 Growth evolve on their next feed. Overflow is kept
in `GrowthReserve` and `TotalGrowth`, and the identity is unchanged. This is covered by a unit
test and by the existing Phase 4A/4D fixtures that seed a 45-Growth starter. Stage 1+ pets
are unaffected. Pending choices are rechecked against the (looser) requirements.

## 3. Pursuit (new behaviour)

Per guardian in `GuardianConfig.Areas` (all five currently identical, PROVISIONAL):

| Key | Value | Meaning |
|---|---|---|
| `Wake` | 0.8 s | delay before moving (validated 0.5-1.0) |
| `SpeedRatio` | 1.10 | engaged speed = 16 x (1 - worst carry slowdown) x 1.10 x rarity profile |
| `CatchUpRatio` | 1.75 | speed beyond 2 x EngageDistance; blends linearly to SpeedRatio at EngageDistance |
| `EngageDistance` | 30 studs | centre-to-root distance where catch-up ends |
| `CatchReach` | 5 studs | from the body box surface to the player root (about 4.3 studs to the torso surface) |

- The baseline is a fixed 16, never the player's live WalkSpeed, so future Speed upgrades make escape easier.
  The validated speed sweep below demonstrates this.
- Worst-case slowdown includes the item `CarrySlowdown` plus the maximum curse slowdown.
- Pursuit continues through cooldown. Attacks no longer cost the whole chase.
- Charge and Lunge: during the strike the body rides the lane's leading edge (forward only,
  runway-clamped). A dodged charge lands the guardian close behind instead of 35 studs behind.
  Hit geometry, telegraphs and fairness checks are unchanged.
- Pursuit ends only at the safe zone, item loss (catch, hazard, drop, bank), invalid character,
  or field reset, as before. After a catch the guardian retargets in the same frame, or returns home if none is left.
- The guardian never enters the safe zone. The existing runway clamp and entrance standoff are unchanged.
- Cross-player targeting and rarity-based speed (Phase 3B fixes) are unchanged.

## 4. Catch, knockback and recovery

- `GuardianService` validates on the server: the guardian is PURSUING or COOLDOWN; the
  player is a threatened carrier of that biome with the matching carry token, outside the safe zone,
  not recovering, and within `CatchReach` of the oriented body box (plus a vertical bound).
- One `CarryService.forceDrop(player, character, "GuardianCatch:<Area>")`. The drop keeps its GUID
  and 20-second expiry, and anyone can collect it.
- New `src/server/GuardianCatch.luau` (no RemoteEvents, no DataStores):
  - Server takes network ownership after the joints are released (splitting assemblies resets ownership).
  - `AnimationConstraint` joints are disabled so the rig's paired ball sockets hold the limbs.
    `Motor6D` rigs get temporary sockets. `PlatformStand` is set and `RequiresNeck` is off during the ragdoll.
  - Bounded launch: 34 studs/s away from the guardian + 26 studs/s up. Measured displacement was 12-15 studs on real clients.
  - Ragdoll 1.1 s, then stand up: joints restored, upright on the floor (raycast), velocity
    zeroed, `GettingUp`, ownership returned to the player.
  - Recovery 2.2 s: pickups are rejected (`SpawnService.pickup`), with no further catches or hazard consequences.
  - Cleanup on death, character removal/respawn, player removal, `resetAll`, and field reset.
- Hazard hits that drop an item apply the same consequence. Empty-handed bystanders are unaffected, as before.
- Client (`GuardianPresentation`, attribute-driven): red screen flash, stronger camera shake,
  "CAUGHT BY THE T-REX!" banner, a `Caught` presentation hook, and a local stand-up safeguard.
- No HP, combat, damage numbers or death rewards.

## 5. Test results

### Unit tests (Studio Play server)
327 / 327 pass. New cases cover the 25/20 thresholds, five Raw Meat feeds to Fangling, an
existing 45-Growth save, the affinity fallback, per-guardian config validation, slowdown-relative
speed, catch-up blending, oriented catch gap and bounded knockback.

### Real Studio Play, solo (`tests/GameplayTuning.server.luau`)
Catch verification: 23 / 23 checks. It covers:

- Raw Meat theft, wake 0.81-0.83 s, then pursuit.
- The body catch: exactly one drop, GUID retained, 20 s expiry.
- Ragdoll with joints released, then knockback.
- Pickup blocked during recovery.
- Joints, control and network ownership restored, and the player walks again.
- The drop can be re-collected and re-engages the owner guardian.
- The T-Rex returns home after its last target.

Scripted runners use real Humanoid locomotion via server `MoveTo`, straight to safety.
"Dodge" sidesteps 18 studs when a telegraph appears.

Round 1 (catch added, Charge still stationary):

| Start (studs from safety) | Runner | Outcome | Time | Closest gap |
|---|---|---|---|---|
| 66 / 120 / 174 / 229 / 283 | Straight, 16 | all escaped | 4.3-17.9 s | 193 / 97 / 25 / 23 / 9.2 |
| 174 / 229 | Dodge, 16 | escaped | 11.1 / 15.7 s | 25 / 18 |
| 283 | Dodge, 16 | hazard hit at 209 | 5.6 s | 9.2 |
| 229 | Prime Meat 15.7 / Ancient Bone 14.7 / Primal Catalyst 14.4 (cursed) | all escaped | 16-17 s | 15-17 |

Round 2 (final: Charge/Lunge body rides the sweep):

| Start | Runner | Outcome | Time | Where |
|---|---|---|---|---|
| 66 | Straight 16 | escaped | 4.3 s | guardian never closer than 193 |
| 120 | Straight 16 | escaped | 7.7 s | closest 97 |
| 174 | Straight 16 | escaped | 11.1 s | closest 25 |
| 229 | Straight 16 | escaped | 14.5 s | closest 14 |
| 283 | Straight 16 | **caught** | 10.9 s | 110 studs from safety |
| 174 | Dodge 16 | escaped | 11.1 s | closest 25 |
| 229 | Dodge 16 | **caught** | 9.8 s | 91 from safety |
| 283 | Dodge 16 | **hazard hit** | 5.6 s | 208 from safety |
| 229 | Prime Meat (2% slow) Dodge | **caught** | 9.7 s | 95 |
| 229 | Ancient Bone (8% slow) Dodge | **caught** | 9.8 s | 100 |
| 229 | Primal Catalyst (10% slow, cursed) Dodge | **caught** | 12.2 s | 70 |

Measured guardian speeds: catch-up peak 28.1-28.5 studs/s (1.75 x 16), engaged about 17.6.

Speed sweep: an anchored kinematic runner at a fixed speed against the unchanged T-Rex,
standing in for future Speed upgrades.

| Runner speed | from 174 | from 229 | from 283 |
|---|---|---|---|
| 14 | escaped (gap 16.6) | caught 11.8 s | caught 6.0 s |
| 16 | escaped (gap 26.5) | escaped (gap 15.2) | caught 13.2 s |
| 18 | escaped (gap 44) | escaped (gap 23) | escaped (gap 9.7) |
| 20 | escaped (gap 70) | escaped (gap 30) | escaped (gap 9.7) |

### Real two-client Studio test (`tests/GameplayTuningMultiplayer.server.luau`)
39 / 39 checks, passing on three consecutive runs. Characters are unanchored and client-owned. Covered:

- A is caught, with server-owned ragdoll physics and 12-15 studs of knockback.
- The T-Rex returns home.
- B collects A's drop during A's recovery, and the T-Rex re-engages on B.
- Recovering A cannot pick up. A gets control and ownership back and walks.
- A steals again. B reaches safety and the T-Rex switches straight to A.
- A reaches safety and the T-Rex returns and sleeps.
- Death during a ragdoll clears recovery; the respawn is free and unslowed.
- The T-Rex body never entered the safe zone. Resource uniqueness holds, with no server errors.

One earlier run failed at "B escapes with the carry". It was not reproduced in three reruns with
diagnostics. The likely cause is test timing: B waits outside the safe zone while the T-Rex closes in.

### Regression
These ran after the final source changes. "Play" means a real single-player Studio Play
server; "two-client" means `StudioTestService:ExecuteMultiplayerTestAsync(2)` with real clients.

| Test | Mode | Result |
|---|---|---|
| Unit suite | Play | 327 / 327 |
| Phase1Integration | Play | PASS 32 |
| Phase3Integration | Play | PASS 129 |
| Phase3BRunway | Play | PASS 42 |
| Phase3Rollback | Play | PASS 9 |
| FieldRuntimeSmoke | Play | PASS 14 |
| Phase4AIntegration (with its paired client fixture, real 300 s reset) | Play | PASS 33 |
| Phase4ACompatibility | Play | PASS 13 |
| Phase4CIntegration | Play | PASS 89 |
| Phase3Multiplayer | two-client | PASS 32 |
| Phase3BMultiplayer | two-client | PASS 119 |
| Phase4AMultiplayer | two-client | PASS 18 |
| Phase4BMultiplayer | two-client | PASS 11 |

Phase4DIntegration belongs to separate uncommitted Phase 4D work and was not run here.

Older tests assumed a guardian could only drop a carrier through a signature attack, and that a
hit player could re-pick at once. Those assumptions no longer hold, so these tests were updated.
The production behaviour they check is otherwise unchanged:

- `Phase3Integration`: a carrier anchored at the node is now body-caught before the attack. While
  waiting for the telegraph, the test keeps the carrier 22 studs from the guardian (outside catch
  reach, inside the 32-stud attack commit). After a hazard hit it asserts the recovery pickup lock,
  then releases recovery to exercise the hit-set guard. A cooldown body catch
  (`GuardianCatch:<area>`) is accepted; a second hazard drop still fails.
- `Phase3Multiplayer`: either guardian drop path is valid for two stationary carriers. It asserts the
  knockback was applied and that pickup stays locked while recovery is active.
- `Phase3BMultiplayer`: the stress section counts body catches and waits out recovery.
- `EvolutionStages_Test`, `GuardianState_Test` and `GuardianChase_Test`: read the 25 / 20 starter
  thresholds and per-guardian wake/speed from config, and cover the new behaviour.

The uncommitted Studio-memory edits in `Phase1Integration` and `Phase4AIntegration` come from another
session and were left untouched.

## 6. Limits of this evidence

- Every chase result above comes from scripted runners (perfect straight lines, instant
  start, a simple 18-stud sidestep). They are timing and geometry evidence, not human playtests.
  Humans lose time on the pickup prompt, camera and steering, and dodge better or worse than the script.
- The solo locomotion runs move a client-owned character through server `MoveTo`. The kinematic sweep moves an anchored character.
- Knockback feel, camera shake, flash and ragdoll look were checked by attribute and joint state,
  plus one viewport capture. They were not judged by a person.
- Disconnect during a ragdoll is handled in code (`PlayerRemoving`) but was not exercised by a test client.

## 7. Recommendations

1. Human playtest the Grasslands loop. The scripted result is that the two nodes nearest safety
   (66 and 120 studs) remain effectively safe, 174 gives visible pressure, and 229/283 are
   contested or caught. If every theft must feel dangerous, the next lever is the **sleep point**
   (a mid-biome home or a short patrol), not higher speed. Reaching a 66-stud thief from 232 studs
   away would need about 54 studs/s.
2. Tune per guardian after playtests. All five share one row today. Deeper biomes carry slower
   items, so their SpeedRatio may need to be lower than Grasslands'.
3. Jungle (Shockwave) and Volcano (FireSweep) still freeze for their telegraph. Consider a body
   movement rule for them if they feel passive.
4. Revisit first-evolution pacing (25) after watching new players. Later thresholds (80/160) now
   make up a larger share of the early curve.
5. Replace the placeholder box guardian with the real model, then re-measure `CatchReach`
   against its collision footprint.
