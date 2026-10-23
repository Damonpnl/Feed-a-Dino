# Fast-paced heist tuning — implementation and verification

Started 2026-10-20; verification continued 2026-10-23. **Balance is provisional,
not approved for release.** Executed technical checks and unresolved gameplay-feel
questions are reported separately; unexecuted checks must not be inferred to pass.
Scope is the requested rebalance and approved reset lockdown, not Phase 6.

Verification resumed 2026-10-22. Latest source audit: **120 mapped sources including
the disabled runner**, zero missing/mismatched/duplicate paths, 1,412 saved BaseParts,
five ResourceNodes in each of five areas. Only port 34872 was listening; ordinary
`netstat` supplied this check because Windows process/TCP management queries were
permission-denied. No Phase 3B worktree was changed.

## Baseline and preservation

Original worktree `D:/Coding_projects/Roblox/Feed-a-Dino`, branch
`phase3-phase4a-snapshot`. Existing uncommitted Phase 4/5A/5B/radial and developer-panel
work is preserved. No branch merge/reset, map rebuild, publication, economy change,
resource value/weight change, or production DataStore access.

Official Studio MCP: Feed a Dino, place 104154372052853, session
`c4540824-243e-4fe9-963a-cb79a0040216`. Initial Edit inspection: 1,412 saved BaseParts,
116 mapped sources matched repository hashes, no duplicate mapped paths, unit runner
disabled. Pre-change Play unit suite: **392 passed, 0 failed**. `netstat` showed only
127.0.0.1:34872 listening (PID 23620); no 34873. PowerShell's TCP inventory was denied;
the ordinary netstat diagnostic and complete source comparison supplied the evidence.

Phase 5B reports/raw travel remain valid historical measurements. New matched A trials
rerun the current code including the developer-panel additions. Ordinary and heavy
resources use the same fixed territory candidate, actual resource-required Power,
empty / Mild HeavyBurden (+.06) assignments, straight-line anchored movement, and real
elapsed server time. This is **kinematic live-service automation**, not Humanoid physics
or a human escape rate. Reset clock is postponed only in the isolated fixture.
`tests/FastHeistBenchmark.server.luau` is opt-in, never shipped startup logic.

Comparison A: **10 completed trials, 8 escapes, 1 body catch, 1 hazard loss**; both
losses were CrystalCave. Raw data: `FAST_HEIST_A_RESULTS.json`. Sustained pursuit P50/P90
only include intervals whose two endpoints are PURSUING, excluding attack transitions.
Prior `GuardianPeak` observations were contaminated and are not used as pursuit speeds.
Comparison B was lost when Studio restarted and was rerun on 2026-10-21 using the
preserved old guardian sources: **10 escapes, zero attacks**, all ten invariant checks
passed. Comparison C restores the repository's retuned sources: **zero straight-line
escapes, one body catch, nine hazard losses**, all ten invariant checks passed. These
are deliberately non-dodging runners, NOT evidence of acceptable difficulty. Each C
trial had one warning/attack, with loss at 4.4–6.3 seconds. Dodge and progression trials
are required before recommending these provisional values. Raw B/C JSON is retained.

2026-10-21 current unit suite: **402 passed, zero failed/timeouts**. This includes a
new reset-inside-hazard-callback test. The live adapter now stops that callback after
reset reconciliation so it cannot recreate a canceled sweep or apply a post-reset
catch. Rojo build and whitespace check pass; pre-existing line-ending warnings remain.

## Reference research (not a speed calibration)

The [Roblox listing](https://www.roblox.com/games/107778070777162/Steal-An-Egg)
describes stealing eggs, collecting pets, earning income and training Speed. That is
source-backed loop context, not a physical-speed measurement. Multiple similarly named
listings exist; no exact current-build reproduction is claimed.

The [community guide](https://stealaneggwiki.net/guide) describes heavier eggs slowing
carriers and guardians creating return-trip risk. The
[GAMES.GG guide](https://games.gg/roblox/guides/steal-an-egg-speed-how-to-increase-speed-fast/)
reports displayed Speed progression thresholds and no-stealing night periods. These
are secondary/community descriptions, not authoritative engine configuration. No
published conversion from displayed Speed to studs/second was verified. No direct
in-game Steal an Egg timing was available through the connected development Studio.
Our proposed physical speeds and pacing targets are **design hypotheses** measured
in this game's own geometry, never inferred from millions of displayed Speed points.

## Provisional movement configuration

| Power | Unloaded | Carry base before penalties |
|---:|---:|---:|
| 0 | 22 | 22 |
| 1K | 26 | 24 |
| 10K | 30 | 27 |
| 100K | 36 | 30 |
| 1M | 44 | 35 |
| 10M | 54 | 41 |
| 100M | 64 | 47 |
| 150M+ | 72 | 52 |

For comparison, the old unloaded values at these same milestones were
16/17/18/20/22/26/30/32, with `min(unloaded,18)` carrying base. Both curves use
step milestones, not linear interpolation. Current effective carrying speed is
`min(SlowMode ? 16 : unloaded(Power), carryBase(Power)) * (1 - appliedSlowdown)`.
The existing CarryDebuff calculator combines the resource penalty and curse effects;
its bounds and probabilities are unchanged. Ragdoll takes precedence and returns 0.

Experimental user-requested curve; not final balance. Slow Mode remains 16 before
penalties, ragdoll remains zero. CarryService remains the sole WalkSpeed writer.
No saved speed, new currency, stamina, sprint or training system. Resource slowdowns
and curse definitions are unchanged. Developer overrides remain Studio-only and
respect the Power-derived carry ceiling; no override is persisted.

## Approved reset-policy change

The old unconditional carry-through-reset rule is superseded **only for carriers on
the field side of the existing authoritative safe plane**. Boundary equality is inside;
strictly behind the plane is safe. The plane intentionally spans lateral/vertical
out-of-bounds positions too, so jumping or leaving the lane is not an exemption.
Decision order is the server's first reconciliation at/after the cutoff, using its
observed current position, not a client timestamp or claimed crossing time.

ResourceService owns the existing 300-second period and ten-second Reset phase.
FieldLockdown is its adapter, not another timer: terminal GUID removal, carry/curse
cleanup, catch restoration, assigned-base evacuation, guardian cancellation and five
runtime gates. Transactions reconcile the clock before claim, consume or drop.
Safe carriers retain identity and can feed normally. Re-entry during closure is checked
each server heartbeat, including teleport/physics entry. No compensation or recoverable
drop is created for forfeiture. Runtime gates do not modify saved blockout assets.

## Executed verification and intermediate failures

Intermediate fairness trials are retained, not hidden: the initial shallow lane-edge
dodge runner lost all five ordinary resources to subsequent body catches. C2 adds
per-area post-attack recovery (0.65/0.75/0.85/0.9/0.8 seconds) before turning and
pursuing again; catch geometry remains active with the original reach. Four shallow
dodges still lost, while Volcano escaped after five attack/dodge moves in 50.2 seconds.
Wide diagonal body-clearing dodges are a separate fixture strategy, not a directly
matched claim of improved human success. All values remain provisional.

The first ability fixture passed charge/lunge hit and outside-footprint checks but
could not obtain a Gorilla warning: its continually retreating 35-stud hold could
project beyond the bounded leap range. The fixture now holds 25 studs for Gorilla,
still beyond body reach. Another run sampled past an alpha-zero lunge hit; its observer
now accepts the authoritative hazard-hit counter as proof of an active sample. Neither
failed/partial run is counted as a complete five-guardian pass.

The subsequent five-guardian geometry run passed **72 checks**: ten controlled
hit/outside-footprint cases, committed telegraphs, same-GUID drops, no health damage,
and actual Gorilla leap heights of approximately 18 studs. Outside-footprint placement
is instantaneous fixture positioning, NOT proof of a movement-based dodge. The earlier
failed geometry runs above remain retained for transparency.

The initial reset fixture passed **54 checks** using real ten-second closures. It
verified five gates, inside forfeiture, safe-side retention followed by a legitimate
Raw Meat feed (+5 Growth/+5 Flesh exactly once), ragdoll cleanup, repeated reconciliation,
actual respawn, closed-field reentry and two injected timing races: cutoff after
visual detachment, and cutoff inside an actual guardian hazard contact callback.
These initial results precede the added crowded-spawn separation and near-plane tests;
those additions must be verified separately.

Real server-owned Humanoid physics passed **27 checks**, including six high-speed
turn/reversal waypoints, a real wall collision, moving pickup, carried-weld alignment,
safe-plane crossing and original-GUID consumption. Short measured runs:

| Configured speed | Achieved studs/second | Measured distance | Seconds |
|---:|---:|---:|---:|
| 22 | 21.72 | 78.20 | 3.600 |
| 26 | 25.55 | 76.69 | 3.002 |
| 30 | 29.32 | 77.23 | 2.634 |
| 44 | 41.77 | 76.55 | 1.833 |
| 72 | 62.72 | 75.22 | 1.199 |

These short routes include starting/arrival effects; they are not estimates of
steady-state velocity or physical-mobile performance. No collision failure was
observed at 72 in this fixture, but human control quality remains unverified.

Actual resource/lockdown-step CPU profile: 601 calls over 10.02 seconds with one player,
mean 0.0869 ms, P50 0.0828 ms, P95 0.1154 ms, maximum 0.1558 ms. Heartbeat interval P95
was 18.04 ms. This includes the existing 25-node presentation update, not just gate
checks. No production-load, GPU, memory-leak or multi-player performance claim follows.
Raw evidence: `FAST_HEIST_VERIFICATION_RESULTS.json`.

Full real-Humanoid travel run completed **31 checks**. Guardians were reset immediately
after acquisition to isolate travel; these times do not include active combat-free
hazard avoidance. Fixed resources/waypoints match the historical travel methodology.

| Area | Old ordinary round trip | New ordinary | New heavy | New ordinary resource → safe |
|---|---:|---:|---:|---:|
| Grasslands | 51.4 s | 37.90 s | 39.31 s | 7.05 s |
| Swamp | 88.5 s | 60.98 s | 62.45 s | 20.96 s |
| Jungle | 118.2 s | 75.78 s | 79.04 s | 30.83 s |
| CrystalCave | 145.8 s | 85.46 s | 87.56 s | 39.00 s |
| Volcano | 179.5 s | 92.71 s | 93.23 s | 46.88 s |

Each biome's outbound uses its ordinary resource's entry Power; heavy return uses
that heavier resource's own requirement and Mild HeavyBurden +.06. Thus heavy round
trip is a controlled mixed-Power comparison, NOT a single character's continuous
playthrough. Raw positions, distances, speeds and full-return times are retained in
`FAST_HEIST_TRAVEL_RESULTS.json`. Grasslands and Volcano travel-only values fall within
the exploratory pacing bands without changing the map. Actual successful dodging
adds distance/time and is a separate balance experiment.

Initial regression queue: Phase 5B movement **46 checks passed**, Phase 1 **32 passed**.
Phase 3 stopped after 20 checks: the old radial 22-stud holding fixture was body-caught
before obtaining its Grasslands hazard telegraph. Failure evidence is retained in
`FAST_HEIST_REGRESSION_INITIAL_RESULTS.json`. Its hazard-only fixture now holds on the
safe-facing side at 35 studs (25 for the range-bounded Gorilla), as used in the successful
five-hazard fixture. No reward, collision, hazard outcome or identity assertion was
relaxed. Legacy 16-speed assertions run explicitly in Slow Mode; new normal-mode
movement tests cover the faster curve. Final fresh-Play rerun passed:

| Suite | Passed checks |
|---|---:|
| Pure unit cases (including exact reset-plane boundary) | 403 |
| Phase 3 integration (hazards/lifecycle, explicit Slow Mode) | 129 |
| Phase 4A feeding compatibility | 13 |
| Phase 4C catalysts/mutations | 89 |
| Phase 4D rarity/prestige protection | 18 |
| Phase 5A economy/trainers/persistence | 174 |
| Phase 1 integration | 32 |
| Phase 5B movement integration | 46 |
| Five-hazard geometry plus measured timing | 82 |
| Phase 4B evolution integration | 34 |
| Phase 4B client presentation/forgery/replay | 6 |

Evolution selection used the actual native Mossback button through Studio MCP mouse
input; no direct server choice substitution. The updated ability fixture measured
warning-to-activation intervals and checked them against each configured duration
with bounded scheduling tolerance. Raw per-area timings and all suite statuses:
`FAST_HEIST_REGRESSION_RESULTS.json`. These are executed automated checks, not human
gameplay judgments.

### Final progression and dodge comparisons

The final committed-window dodge fixture clears the Gorilla disk and waits until its
active window ends before returning through it. Earlier fixtures reentered the disk
too early; their failures remain in the raw results. No gameplay values changed for
this fixture correction. Results at ordinary-resource entry Power:

| Area | Outcome | Seconds | Attacks / survived active windows |
|---|---|---:|---:|
| Grasslands | Escaped | 7.26 | 1 / 1 |
| Swamp | Subsequent body catch | 10.00 | 1 / 1 |
| Jungle | Subsequent body catch | 7.07 | 1 / 1 |
| CrystalCave | Subsequent body catch | 11.30 | 1 / 1 |
| Volcano | Fourth hazard hit | 38.40 | 4 / 3 |

All five attacks have movement-based scripted avoidance evidence, but a successfully
dodged attack does not establish a fair full escape. These are single fixed routes,
not statistical human success rates. At 150M Power, all five ordinary routes escaped
without an attack in 2.93/9.53/15.83/22.33/31.23 seconds. In Slow Mode, all ten ordinary
and heavy straight-line routes lost in 2.17–4.80 seconds (six hazards, four catches).
The fixture's PASS means resource invariants and bounded completion passed, **not**
that those outcomes satisfy balance targets. Evidence:
`FAST_HEIST_PROGRESSION_RESULTS.json`, `FAST_HEIST_WINDOW_DODGE_RESULTS.json`.

### Client physics and reset presentation

Actual client-owned character physics passed using official MCP W/D/S/A keyboard
input at configured 72: 320.50 studs traveled, ownership retained, character alive.
The 20.32-second observation includes setup/idle time, so it is not a steady-speed
measurement. Server-frame peak 240.85 reflects replication bursts; it is not a claim
of a supported WalkSpeed or an anti-cheat verdict. Raw 184-sample trace:
`FAST_HEIST_CLIENT_PHYSICS_RESULTS.json`. Camera state was restored afterward.

Actual replicated 60/30/10 warnings, synchronized countdown (within one second),
full ten-second Reset and return to Normal passed both server and client observers.
The Studio device-simulator workflow checked iPhone 17 Pro landscape, actual viewport
750×381, game orientation Sensor, FieldAnnouncements CoreUISafeInsets. All warning
strings reported TextFits=true. MCP capture `FastHeistActualPhoneReset` showed the full
forfeit sentence and RESETTING countdown readable. The warning overlays the existing
upper-left placeholder pet HUD; whole-HUD mobile layout is not approved. The capture's
3D world remained black, so this is UI evidence only, not a 3D visual pass. Evidence:
`FAST_HEIST_WARNING_RESULTS.json`. Physical touch controls and portrait remain untested.
The device-simulator skill informed this verification, not gameplay changes.

## Guardian configuration and targeting

All values below are provisional. BaselineWalk is fixed by biome, **not** the target's
live Power. The existing rarity and burden profile still affects pursuit. Engaged and
far-distance ratios blend using the configured EngageDistance; acceleration is bounded.

| Area | Fixed base | Engaged / catch-up ratios | Wake | Acceleration | Attack range | Lead / max lead | Recovery |
|---|---:|---:|---:|---:|---:|---:|---:|
| Grasslands | 22 | 1.08 / 1.65 | .65 | 100 | 42 | .8 / 30 | .65 |
| Swamp | 24 | 1.12 / 1.8 | .6 | 120 | 40 | .75 / 32 | .75 |
| Jungle | 27 | 1.12 / 1.8 | .6 | 125 | 44 | .85 / 34 | .85 |
| CrystalCave | 30 | 1.07 / 1.7 | .65 | 120 | 46 | .85 / 38 | .9 |
| Volcano | 35 | 1.14 / 1.85 | .6 | 140 | 54 | .9 / 44 | .8 |

Prediction clamps horizontal observed velocity to 72, forecast time to 1.25 seconds,
and lead distance to the biome maximum. Warning footprints stay on the authoritative
runway, outside the safe zone, and pass a reaction-distance budget reserving 0.25
seconds. Obstruction checks reject unsuitable attack paths. Commitment is stored in
one frame and never steered during the active attack. The Gorilla visibly follows a
parabolic leap to that committed landing point; Dragon fire projects ahead along the
escape path. Swept catches use the existing rounded body-box reach of 5, not a larger
invisible rectangular catch volume. Short recovery holds pursuit motion, not immunity.

## Evacuation placement follow-up

`BaseService.evacuate` now checks bounded candidate positions next to the assigned
spawn against real collidable floor/headroom and other player roots. It never claims
another base or moves the visitor. The original point is preferred; nearby positions
are considered only when obstructed. No saved assets are moved. If every tested spot
is blocked, no unsafe fallback teleport occurs; the closed-field reconciliation retries.
Geometry inspection found valid original positions for all four existing bases.
The expanded **two-actual-client reset test passed 78 checks** on 2026-10-22.
It includes competing pickups of the same GUID (one winner), recovery by the other
client without curse reroll, a same-area body catch retargeting the second carrier,
independent base ownership, a safe visitor occupying the evacuee's spawn, separation
without moving that visitor, safe carry retained and fed, actual respawn/disconnect,
near-plane entry during closure, and both body/hazard callback races.
Raw evidence: `FAST_HEIST_RESET_MULTIPLAYER_RESULTS.json`. The carriers are real Studio
clients with server-controlled fixture positioning, not human/network-latency testing.

Independent Phase 5B multiplayer regression also passed **20 checks** with two actual
clients: different Power-derived speeds, per-player Slow Mode/penalties, forged
cross-player requests, independent carries/chases, ragdoll precedence, respawn,
disconnect and survivor memory save. Evidence:
`FAST_HEIST_MOVEMENT_MULTIPLAYER_RESULTS.json`.

The reentrant reset guard also covers swept body catches, not only hazards. A cutoff
during a drop must not overwrite `FieldResetForfeit`, claim a successful ordinary drop,
apply knockback after evacuation, or repopulate a stale swept-body sample. The drop
resolver now returns whether it actually resolved the record; a record already
forfeited by clock reconciliation returns false. Expanded actual-service tests cover
both callback paths and just-safe/just-inside crossings.

Human checklist per biome: approach feels fast, theft produces immediate pressure,
guardian closes visibly, warning is readable, sideways/direction-change dodge is
possible, misses reward skill, escape is satisfying, return isn't tedious, training
benefit is apparent, and another run feels appealing. **No human verdict recorded.**

## Scope and changed code

Heist-specific gameplay work is confined to MovementConfig/MovementCalculator,
GuardianConfig/GuardianChase/GuardianGeometry/GuardianState, the new pure GuardianAim,
CarryService, GuardianService, ResourceService, SpawnService, BaseService, the new
FieldLockdown adapter, and FieldPresentation. Existing Phase 4/5/radial changes in
other dirty files were not rolled back or reclassified as this task's work.
No new remote, DataStore, currency, resource ownership table or movement writer was
introduced. The only production WalkSpeed assignment remains in CarryService.

Opt-in fixtures: FastHeistBenchmark, FastHeistAbilities, FastHeistReset,
FastHeistPhysics, FastHeistClientPhysics, FastHeistProfile, FastHeistWarnings (server
and client), and FastHeist_Test. Earlier movement/guardian/reset assertions were
updated only where the approved curve, reset policy or hazard-isolation fixture
changed their premise. Root test files are authoritative; historical copies under
ServerStorage.UnitTest.PlayFixtures are not substituted for them.

## Explicit limitations

- Real human desktop/phone play and touch comfort have not been verified.
- Studio clients are local; hostile network latency, packet loss and production
  server load are not simulated. This is not a comprehensive anti-cheat solution.
- Actual late joining passed 13 checks: the second Studio client joined 0.616 seconds
  into the first client's real reset, initialized writable StudioMemory, and could not
  bypass closure. Full ten-second duration and resource integrity passed. This is not
  a third-client or production-latency test: `FAST_HEIST_JOIN_RESET_RESULTS.json`.
- Fully obstructing every candidate in a player's base returns no unsafe teleport;
  recovery once such an obstruction clears has not been stress-tested.
- Production DataStores are deliberately inaccessible. Memory save/reload and
  read-only/failure guards are tested; no live production save or cloud-rejoin test.
- Human reaction/visibility assumptions and all guardian movement values remain
  provisional. Low scripted escape rates alone do not establish good difficulty.

## Final technical handoff — 2026-10-23

Final Edit audit matched all 120 mapped sources with zero missing, duplicate or
mismatched paths; saved geometry remained 1,412 BaseParts and 25 resource nodes.
Rojo listened only on 34872. Build and `git diff --check` passed (existing CRLF
warnings only). See `FAST_HEIST_FINAL_AUDIT.json`. Studio is stopped, device simulation
is off/default, and the unit runner remains disabled. Only this task's tagged
temporary queue, fixture folder, client observer and late-join script were removed;
their repository fixtures remain. No gameplay modules or saved assets were deleted.
No branch switch, commit or publication occurred.

The latest returned Play console tail contains passing suite summaries and the MCP
camera-restoration notice, with no new gameplay error in that returned portion.
The tool truncates long history; this is not a claim that every historical entry was
clean. Earlier fixture failures are documented above. Root opt-in fixtures were used;
the older Phase3B full-duration multiplayer script was not claimed as a fresh full pass.

| Acceptance area | Status | Evidence / limit |
|---|---|---|
| Faster travel; increasing loaded/unloaded capability | PASSED (technical) | Curves, physics and measured five-biome travel; human responsiveness unverified |
| All five guardians at representative Power | PASSED (execution) | Matched A/B/C, entry, heavy, Slow Mode and high-Power trials |
| Committed predictive attacks and valid hit regions | PASSED (technical) | 82 checks, measured warnings and movement-based dodges |
| Fair, exciting, repeatable escapes | NOT TESTED (human) | Entry/high-Power extremes remain balance concerns |
| Warnings and synchronized countdown | PASSED | Actual client/server observers; landscape phone screenshot |
| Ten-second closure and five gates | PASSED | Reset and multiplayer fixtures |
| Own-base evacuation, inside forfeiture, safe retention | PASSED | Same-GUID lifecycle, safe feed, crowded spawn and cutoff races |
| Closed-field requests, joins, respawns, disconnects | PASSED (tested cases) | 78 reset, 20 movement multiplayer and 13 late-join checks |
| Feeding, evolution, Cash, training, memory persistence | PASSED | Listed Phase 1–5B regressions; production storage untouched |
| Source sync, map preservation, test cleanup | PASSED | Final 120-source audit, unchanged saved part/node counts, no task-tagged fixtures |
| Physical mobile, network abuse, production load | NOT TESTED | Simulator/localhost is not device, latency or comprehensive anti-cheat QA |

### Recommended remaining balance work (not silently applied)

1. Human-test entry-Power Swamp, Jungle and CrystalCave first. If the post-dodge body
   catch feels unavoidable, evaluate longer recovery or lower engaged pursuit one
   parameter at a time, preserving catch reach and committed warnings.
2. Confirm whether effortless ordinary-resource farming at 150M Power is the desired
   progression reward. Do not secretly scale guardians to player Power.
3. Test switching Slow Mode off before theft on real controls; it is precision
   control, not an escape boost. Do not weaken approved resource penalties.
4. Review warning/placeholder-HUD overlap, portrait and touch targets in a separately
   authorized UI pass. No final UI redesign was performed here.

Human instructions: use normal Studio Play (temporary StudioMemory); test ordinary
and heavy loot at actual required Power, first straight then dodging visible warnings.
Record ten attempts per biome using the checklist above; repeat at high Power and on
a physical phone. Record drops, escapes, warning readability and return-trip boredom
separately. The Studio-only developer panel may supply test state; do not use live
saves or treat seeded resources as natural spawn-frequency evidence.

**This tuning pass stops here.** Technical implementation and listed verification
are delivered; subjective balance/release approval remains pending. No Phase 6 started.
