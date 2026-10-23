# Phase 5B — Power speed and precision mode

Status: implementation and scoped Studio verification complete. Balance remains
provisional; untested conditions are explicitly listed below. Phase 6 not started.
Resumed verification: 2026-10-19.

## Architecture and provisional balance

The user selected fast unloaded traversal with a separate carrying-speed cap after
reviewing the previous radial sweep (56/83/99/100% scripted escape at base 16/18/22/30).
No guardian speed, catch, hazard, spawn or resource values are changed.

`MovementConfig` holds step milestones (no interpolation, unlimited linear scaling,
saved speed or separate currency):

| Power | Unloaded base |
|---:|---:|
| 0 | 16 |
| 1K | 17 |
| 10K | 18 |
| 100K | 20 |
| 1M | 22 |
| 10M | 26 |
| 100M | 30 |
| 150M+ | 32 |

All values and the **18 carrying-base cap are PROVISIONAL_BALANCE**. This cap was
chosen for evaluation because the earlier sweep still had failures at 18 but almost
none at 22. It is not proof that every biome is adequately difficult.

Order: derive base from authoritative saved Power → Slow Mode substitutes 16 →
while carrying cap base at 18 → multiply by `1 - CarryDebuff.applied(item, curse)`.
Existing additive penalties and 0.62 combined cap are preserved. The cap is not a
minimum final speed: a 50% resource at the carrying cap gives 9, not 18.
Ragdoll has final priority (WalkSpeed 0); existing PlatformStand, network ownership,
knockback and pickup/re-catch recovery remain owned by GuardianCatch. On stand-up,
current mode/Power is recalculated, while the remaining pickup recovery still applies.

CarryService is still the only production WalkSpeed writer. It reads DataService,
not client-supplied Power or replicated display attributes. Recalculation occurs on
Power publication, preference changes, spawn, pickup/drop/consume, recovery events,
and the existing 10 Hz timed-curse update. WalkSpeed is assigned only when changed.
No additional per-frame movement controller or temporary boost system was introduced.

Cursed Momentum remains acceleration/input handling; Inverted Controls remains
direction inversion. Neither is misinterpreted as a speed percentage. Camera/vision
effects are unchanged. No existing separate temporary speed modifier was found.

## Persistence and UI

Additive `SlowMode:boolean`, default false; existing save keys, Cash, Power, TrainerTier,
owned pets, legacy upgrades and unknown fields remain. Missing/malformed preference
normalizes false. No DataStore name, adapter, save conflict or load-failure code changed.
Studio uses the existing isolated memory backend; production cloud requests are excluded.

One `SetSlowMode` RemoteEvent accepts a boolean desired state only, rate limited to
0.2 seconds, writable session required. Repeated requests are idempotent, not repeated
toggles. Extra reward/speed/player arguments cannot choose another player's state.
CarryController owns the native 190×44 button (mouse/touch Activated) and V binding.
Neither input route writes WalkSpeed or saved Power locally.

## Test evidence

| Test | Status |
|---|---|
| Pre-change unit baseline | PASS 369/369 |
| Expanded unit suite | PASS 388/388 (19 new movement cases) |
| Phase5BIntegration | PASS 46, real services/StudioMemory: all thresholds, carry ordering, timed curse, mode/ragdoll, respawn, training crossing, leaving, memory reload |
| Phase5BLoop / Presentation | PASS 49 server + 9 client: real FEED/BUY/START/Slow Mode clicks and V key; earned Cash, five feeds, Fangling, trained 1,012.5 Power, actual Humanoid escape with Prime Meat and memory reload |
| Phase5BTravel | PASS 31; ten loaded routes and four unloaded speed comparisons, raw JSON retained |
| Phase5BChase | PASS 100 invariants across 20 trials; 14 escapes, 2 body catches, 4 hazard losses |
| Phase5BMultiplayer | PASS 20 with two actual Studio clients: independent Power/mode/carry/chases, recovery, respawn, departure and memory save |
| Earlier-phase integration regressions | PASS for the explicitly listed reruns below |
| Source/build | 111 mapped scripts match the repository in the running server; disabled unit runner confirmed. Rojo build and git diff --check pass |

One initial native-feed loop timed out waiting for its click; a fresh run was started.
Do not count that aborted run as a pass. No gameplay fix was inferred from that timeout.
An intermediate fixture omitted its final escape/mode section; it was corrected and
the entire loop rerun to obtain the 49/9 result, not accepted based on the shorter run.
Resource acquisition and return-to-feed use controlled relocation; the final heavier
resource escape uses unanchored server-owned Humanoid locomotion. This is automated
gameplay evidence, not a human's navigation or fun evaluation.

The native toggle was exercised on an iPhone 17 Pro simulator in landscape, with
TouchEnabled and a 190×44 text-fitting button. Portrait inspection revealed overlap;
CarryController now positions the toggle bottom-center above the touch controls on
narrow screens. Final portrait verification passed: viewport 401×778, button position
(105.5,556), size 190×44, TextFits true, TouchEnabled true. The game uses Sensor
orientation; MovementHud uses CoreUISafeInsets / IgnoreGuiInset=false. MCP's path-based
click missed because of a 58-pixel inset offset; an input probe and coordinate-corrected
click produced exactly one Activated event and server-confirmed SlowMode=true, Power=0.
This is simulated-device mouse input, not a physical-finger touch test. Roblox's device
simulator guidance informed the narrow-screen layout and verification. Default Studio
viewport restored. Existing broader HUD crowding remains Phase 6 work.

Travel uses actual server-owned Humanoid MoveTo on existing geometry. The first
route failed because it crossed the entrance wall beside the gate. Only fixture
waypoints were corrected to use the saved gate; no world asset was changed.
Travel runs reset guardians after pickup to isolate movement cost; chase evidence
comes from the separate chase fixture, not these unobstructed travel measurements.
For each biome the outbound route uses the ordinary resource's entry Power; that
same measured outbound leg is reused for the ordinary/heavier return comparison.
Each return uses its own resource's required Power. Thus the heavier round-trip
column is a controlled mixed-Power comparison, not a single fixed-Power playthrough.
Heavier trials inject one authored Mild HeavyBurden (+0.06); ordinary trials inject
no curse. Neither changes live curse probabilities. Waypoints use the existing gate
and through-lane; timings include acceleration/turns and a 2.5-stud arrival tolerance.

## Measured travel (seconds)

Actual Studio runs; methodology and mixed-Power comparison caveat above. Raw observations
are in `PHASE5B_TRAVEL_RESULTS.json`. PASS 31 checks across all five biomes.

| Area / resource | Out speed | Carry speed | Base → resource | Resource → safe | Full return | Round trip |
|---|---:|---:|---:|---:|---:|---:|
| Grasslands / RawMeat | 16 | 16.00 | 29.3 | 9.4 | 22.1 | 51.4 |
| Grasslands / PrimalCatalyst | 16 | 14.28 | 29.3 | 10.4 | 24.6 | 54.0 |
| Swamp / SmallFish | 17 | 16.15 | 46.7 | 29.1 | 41.7 | 88.5 |
| Swamp / MutantLeech | 17 | 14.40 | 46.7 | 32.5 | 46.5 | 93.3 |
| Jungle / WildFruit | 18 | 16.56 | 60.0 | 45.8 | 58.2 | 118.2 |
| Jungle / BeastHeart | 18 | 13.68 | 60.0 | 55.2 | 69.9 | 129.9 |
| CrystalCave / CrystalShard | 20 | 16.20 | 68.5 | 64.5 | 77.3 | 145.8 |
| CrystalCave / PrismaticCrystal | 20 | 13.32 | 68.5 | 78.1 | 93.2 | 161.7 |
| Volcano / CharredMeat | 22 | 14.76 | 75.6 | 90.1 | 103.9 | 179.5 |
| Volcano / DragonScale | 22 | 12.42 | 75.6 | 106.9 | 123.1 | 198.7 |

80-stud comparisons: speed 16 → 4.95s, 18 → 4.50s, 22 → 3.70s, 30 → 2.68s.
At ordinary entry Power, unloaded bases are 16 / 17 / 18 / 20 / 22 across the five
areas. The carrying cap only changes the latter two of these entry-speed bases.
Phase 5A's measured-calculator scenario reaches 350K in 14m25s and 6M in 1h11m46s
with a fixed x2.5 pet and continuous training/purchases; travel is additional time.
Thus later Speed convenience does not by itself resolve the existing progression-time risk.

## Guardian comparison

PASS 100 invariants across 20 actual live-service trials. One deterministic near/front
candidate per biome, straight-line anchored runners using the actual effective WalkSpeed;
no human dodging. Power is max(resource requirement, 10K), held equal between modes.
Precision uses base 16; progressed carrying uses cap 18. Ordinary has no curse; heavier
has controlled Mild HeavyBurden. This is not a statistical sample of the full spawn pool.

| Area / resource | Precision: speed, outcome, seconds | Progressed: speed, outcome, seconds |
|---|---|---|
| Grasslands / RawMeat | 16.00, Escaped, 9.5 | 18.00, Escaped, 8.4 |
| Grasslands / PrimalCatalyst | 13.44, Escaped, 11.3 | 15.12, Escaped, 10.0 |
| Swamp / SmallFish | 15.20, Escaped, 30.9 | 17.10, Escaped, 27.5 |
| Swamp / MutantLeech | 12.80, Caught, 22.4 | 14.40, Escaped, 32.7 |
| Jungle / WildFruit | 14.72, Escaped, 51.5 | 16.56, Escaped, 45.7 |
| Jungle / BeastHeart | 12.16, Escaped, 62.3 | 13.68, Escaped, 55.4 |
| CrystalCave / CrystalShard | 14.40, Hazard, 5.2 | 16.20, Caught, 9.0 |
| CrystalCave / PrismaticCrystal | 11.84, Hazard, 5.5 | 13.32, Hazard, 7.0 |
| Volcano / CharredMeat | 13.12, Escaped, 101.5 | 14.76, Escaped, 90.2 |
| Volcano / DragonScale | 11.04, Hazard, 31.2 | 12.42, Escaped, 107.2 |

Overall: 14 escapes, 2 body catches, 4 hazard losses; no timeouts, duplicate/orphan GUIDs,
or guardian safe-zone intrusions. Precision escaped 6/10, progressed 8/10. Do not compare
these percentages as if they were the earlier 280-trial random-node sweep. Raw observations
are in `PHASE5B_CHASE_RESULTS.json`. Its `GuardianPeak` includes attack-transition movement
and is NOT evidence of sustained pursuit velocity. Runway regression verifies continued
pursuit, disengagement and return; controlled low-frame-rate velocity measurement is not run.

Balance recommendations (not applied): keep the cap provisional; test human dodging against
CrystalCave's charge before approving its warning/charge geometry or a biome-specific pursuit
adjustment. All four straight-line Crystal trials lost, while all four Jungle trials escaped.
Review Jungle/Volcano threat separately rather than raising every guardian's speed with Power.
A heavy curse is not universally harder across different rarities because existing pursuit
also uses resource/curse and rarity metadata. Long capped returns need a separately approved
pacing decision; no map shortening, sprint, stamina or guardian retuning was added.

## Earlier-phase regressions rerun

| Fixture | Checks | Status |
|---|---:|---|
| Phase3Integration | 128 | PASS |
| Phase3BRunway | 42 | PASS |
| Phase4DIntegration | 18 | PASS |
| Phase1Integration | 32 | PASS |
| Phase4CIntegration | 89 | PASS |
| FieldRuntimeSmoke | 14 | PASS |
| Phase4ACompatibility | 13 | PASS |
| Phase5AIntegration | 174 | PASS |
| RadialLayout Validate | 894 | PASS on fresh-cycle rerun |
| StudioMemoryFeeding | 55 | PASS, actual native FEED click |
| Phase3Rollback | 9 | PASS, intentional partial-visual fault injection |
| Phase4BIntegration / Presentation | 34 server / 6 client | PASS, actual Mossback choice and forged/replayed requests |
| GameplayTuning Locomotion | 23 | PASS, physical catch/recovery plus eleven actual Humanoid runner outcomes |
| Phase3BMultiplayer | 123 | PASS on safe-side fixture rerun, two actual clients; minimum guardian spacing 23.8 studs |

RadialLayout initially stopped before validation because fewer than 120 seconds
remained in the current field cycle. A fresh Play rerun passed; the failed
precondition is retained as evidence and not counted as a pass.
The final unit rerun again passed 388/388 after the 111-script Edit source audit.
GameplayTuning's isolated runner session postponed the field timer only while that
fixture ran, restoring it afterwards; reset behavior is tested separately by the
radial, field and multiplayer fixtures. No production timer configuration changed.
The first legacy two-client Phase3B run stopped after 10 checks: the arbitrary
highest-threat Jungle spawn sent its straight-line runner through a guardian body.
Its independent-pursuit/disengagement scenario now selects the existing farthest
safe-side spawn with an explicit precondition, instead of assuming every random
rear spawn is escapable. No resource is moved or rerolled and no gameplay tuning is
changed. That failed run is not counted as a pass; the revised fixture was rerun.
The rerun passed all 123 checks: stress recorded 17 hits and 17 re-picks, eight
Swamp and six Jungle body catches, with no overlapping attacks or safe-zone/hazard
footprint intrusions. The real synchronized reset retained the carried GUID/curse.

## Files

New production: shared MovementConfig and MovementCalculator.
Modified: CarryService (existing authority), DataService (publish preference only),
PlayerData (additive preference), DefinitionValidation, CarryController (native input/UI).
GuardianService/GuardianChase/GuardianCatch, CarryDebuff and resource definitions are
not changed by this phase. Prior dirty Phase 4/5A/radial work is preserved.

New opt-in tests: Movement_Test, Phase5BIntegration, Phase5BLoop,
Phase5BPresentation, Phase5BMultiplayer, Phase5BTravel, Phase5BChase.
Phase3Integration's post-hazard movement assertion now checks the centralized
recovery-aware result instead of requiring 16 during a ragdoll. Other pre-existing
changes to that file are retained. Legacy movement fixtures run in Slow Mode to
retain their intended precision-16 baseline; new 5B fixtures cover progressed speed.
Phase3BMultiplayer changes only its first scenario's resource selection/precondition
as described above; all earlier uncommitted fixes in that file remain.
Documentation: PHASE5B_REPORT, CURRENT_STATE, and raw PHASE5B_TRAVEL_RESULTS /
PHASE5B_CHASE_RESULTS JSON. Deleted repository/gameplay files: none. Temporary Play
fixtures are not production startup scripts; the mapped unit runner remains disabled.

## Remaining approval boundaries

Handoff APIs: `MovementCalculator.base(Power)` and
`effective(Power, SlowMode, carrying, appliedSlowdown, ragdolled)` are pure;
`CarryService.recalculateMovement(player)` remains the runtime integration point.
`CarryService.setSlowMode(player, boolean)` validates the existing writable session
and request limiter. Replicated `BaseMovementSpeed` / `EffectiveMovementSpeed` /
`SlowMode` are presentation state, never authoritative client inputs. Movement speed
is derived, not saved; only the preference is added to the existing save record.

The carrying cap limits escape-speed growth after 10K Power; later training improves
unloaded traversal but not the capped carry base. Long loaded returns may therefore
remain tedious. Raising that cap without biome-specific encounter adjustments could
recreate the near-universal escapes seen at 22+. Guardian tuning requires separate
approval, not silent dynamic scaling to each player's speed.

Server-owned speed calculations and validated remotes are not a complete movement
anti-cheat: Roblox client-owned character physics can still require a separate
position/velocity validation system. No such out-of-scope system is claimed here.

No human fun/difficulty playtest or production-cloud durability claim is made.
Persistence evidence is an existing-backend save/release/load plus deterministic
SessionStore tests, not a real network reconnect into the same running Studio server.
Two-client departure cleanup was executed; production cross-server persistence and
physical mobile-device input remain NOT TESTED. Studio data is intentionally discarded
when Play stops. Existing Roblox CorePackages/UIBlox provider and legacy asset-type
warnings remain outside this movement change; they are not reported as a clean console.

## Final verification and boundaries

| Requirement | Status / evidence |
|---|---|
| Bounded Power-derived movement, one writer | PASSED — 19 new unit cases, 46 integration checks, source inspection |
| Persistent precision mode, carry/curse/recovery ordering | PASSED — integration, memory reload, 49/9 progression/UI loop, native mouse/V and simulated-phone checks |
| Multiplayer isolation and exploit handling | PASSED — 20 Phase5B checks with two clients; 123 legacy guardian checks on the corrected scenario |
| All-biome travel and guardian comparison | PASSED — 31 travel checks, 100 chase invariants; raw evidence retained |
| Earlier systems remain functional | PASSED for the listed regression fixtures and 388-unit suite; not a claim that every historical presentation fixture was rerun |
| Final economy/difficulty balance | BLOCKED on design approval / human playtesting; cap 18 and milestones remain provisional |
| Real network rejoin, production cloud durability, physical mobile and forced low-FPS QA | NOT TESTED; scoped substitutes/limitations above |

Final Edit audit: 111 mapped sources match normalized repository content, no duplicate
mapped paths, UnitTestRunner disabled, 1,412 saved BaseParts and 25 ResourceNode IDs.
The only Rojo listener inspected was 34872; none on 34873. The original worktree and
separate Phase3B worktree were not reset or merged. Rojo build and diff whitespace
validation passed. The temporary multiplayer Script was removed, Play stopped, and
device simulation restored to `default` with landscape orientation. No saved place
was overwritten/published. Fresh Play after prior tests showed StudioMemory, zero
Power/Growth and SlowMode=false, confirming temporary session reset.
