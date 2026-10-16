# Phase 3B — full-runway pursuit, safe-zone boundary, rarity carry curses

Date: 2026-10-13. Worktree: `D:/Coding_projects/Roblox/Feed-a-Dino-phase3b`, branch `phase3b`, served by Rojo on `localhost:34873`. The original worktree and its `34872` session were not touched. Nothing was merged.

The tree contains the committed Phase 4A/4B sources from the `add4589` snapshot. They were not edited. Phase 4 compatibility after integration is **not** verified.

## Shared interfaces

Unchanged signatures: `CarryService.get`, `give`, `drop`, `consume`, `consumeOwned`, `forceDrop`, `recalculateMovement`, `start`; `GuardianService.onPickup`, `resetAll`, `getSnapshot`, `start`; all `ResourceService` calls. No new RemoteEvents, DataStores, or save fields.

Additive only:

- `CarryService.getAppliedSlowdown(player)` returns the live applied slowdown, including timed curse pulses.
- `CarryService.getCurse(player)` returns a copy of the assignment and its server start time.
- `GuardianService.getSnapshot` also returns `Position`, `Home`, and `SafeEntrance`.
- `GuardianPresentation` has a `Disengage` BindableEvent (animation hook only).

Not modified: `FeedService`, `MonsterService`, `DataService`, `PlayerData`, `EvolutionCalculator`, `MonsterDefinitions`, `ResourceEffects`, `ResourceDefinitions`, `ResourceService`, `SpawnService`, `UIController`.

## Already implemented before this addendum

- Any acknowledged pickup of a known rarity wakes that biome's guardian at once.
- Rarity pursuit profiles in `GuardianChase`, telegraphed hazards through `GuardianGeometry`, and `forceDrop` on hit (no health damage).
- A slowdown-only rarity carry debuff.
- `HuntNotice` for Secret, Eternal, and Divine.

## Added in this pass

### Pursuit (Part A)

- **Full runway.** Pursuit is no longer stopped by biome, radius, or a fixed timer. Encounters end only when the carrier escapes, no target remains, the encounter becomes invalid, or a stuck failsafe fires. The spawn biome's guardian owns the encounter. Guardians stay inside the runway corridor and never enter base boxes.
- **Safe-zone boundary.** The entrance is the Grasslands floor's min-X edge (X ≈ 283.07). It is pushed outward if a base box plus margin overlaps it. The server creates a non-colliding, invisible `GeneratedGameplay.SafeZoneBoundary` there for reference. Containment is decided by `GuardianChase.isSafe`, not by touch events. A carrier who crosses is dropped from the threat list, gets `GuardianEscapeTick`, and sees "SAFE ZONE REACHED / THE GUARDIAN TURNS BACK". Crossing does not bank the item.
- **Re-entry rule.** Walking back out with the same item does not re-aggro a returning guardian. Only a new acknowledged pickup creates a threat.
- **Hazards stay out of the safe zone.** Attacks are framed only where the whole footprint, plus `HazardPad` (4), lies beyond `entrance + EntranceStandoff` (10). Guardians do not camp the entrance.
- **Turn-back sequence.** Entering RETURNING clears pending attack frames and attack commands, sets `DisengageTick`, fires `Disengage`, holds for 0.6s while facing home, then travels home at `ReturnSpeed` and sleeps. Teleporting home happens only as a logged failsafe (`[GuardianService] <biome> return failsafe teleport`) after `ReturnDuration` (90s).
- **Fair frames.** An attack is placed only if the carrier can exit the footprint in at most `speed × safety × dodgeTime`. Safety is 0.75, or 0.6 when the carrier holds a strong curse. Speed is the worst-case cursed walk speed. Shockwaves try several centres, and lane hazards try both sides.
- **Coordination.** Guardians are independent. They keep 24 studs of spacing, attacks on one carrier are staggered by 1.5s, and an attack is skipped if another guardian is already attacking within 120 studs.
- **Separate safety timeouts.** `SafetyCap` is 600s per encounter. Stuck means less than 4 studs of movement in 8s while more than 64 studs from the target. Both log `[GuardianService] <biome> disengage failsafe: <reason>`.

### Curses (Parts B and C)

`CarryDebuff` is now a data-driven catalog. Assignment is server-only, once per carried item.

| Rarity | Curse |
|---|---|
| Common, Uncommon, Rare | none |
| Epic | 25% chance of one mild |
| Legendary | one mild |
| Mythic | one moderate |
| Cosmic | one moderate or strong |
| Secret | one strong |
| Eternal | one strong, plus 25% chance of a compatible mild |
| Divine | one strong plus a compatible mild |

| Effect | Tier | Behavior |
|---|---|---|
| Inverted Controls | strong | Cycles 3–4s normal, 1s warning ("CONTROLS INVERT IN 1.0s"), then 1.5–2s inverted |
| Heavy Burden | mild / moderate | +0.06 / +0.10 constant slowdown |
| Cursed Momentum | moderate | Acceleration ramp from 35% to 100% over 0.6s. Releasing input stops at once; there is no forced movement. |
| Shifting Weight | mild / moderate | Timed +0.08 / +0.14 slowdown pulses with a 1s warning |
| Unstable Grip | moderate | Brief +0.20 stumble pulses. The item is never dropped. |
| Disorientation | strong | Timed ±3° camera roll. With reduced motion on, this becomes the vignette instead. |
| Obscured Vision | mild | Edge vignette. Hidden when the player attribute `CurseVignetteDisabled` is true. |
| Erratic Sprint | disabled | There is no sprint mechanic, so it maps to Shifting Weight. |

- **Compatibility.** There is at most one strong effect per item. Inverted Controls can pair with Heavy Burden, Shifting Weight, or Obscured Vision. Disorientation can pair with Heavy Burden or Shifting Weight.
- **Total slowdown.** Clamped to 0.62, so walk speed never drops below about 6.1.
- **Persistence.** The assignment is stored per resource token. Dropping and re-picking the same item keeps its curse with no reroll. Banking, feeding, release, death, and field reset clear it. Nothing is saved.
- **Replication.** `CarryCurse` (JSON), `CarryCurseTitle`, and `CarryCurseStart` are set on the player. The client only presents them.
- **Banner examples.** "CURSED CARRY / ..." for Epic through Cosmic; "DIVINE CURSE / INVERTED CONTROLS + SHIFTING WEIGHT" for Secret and above.

**Client input path.** This Studio build uses the Input Action PlayerModule in `StarterPlayer`. Its `MoveAction` is driven by `BindToSimulation`, so overriding `Player:Move` has no effect. `CarryCursePresentation` instead scales `Vector2Scale` on every `MoveAction` binding except click-to-move. Those bindings cover keyboard, gamepad thumbstick, and both touch thumbsticks. Binding scales apply only on the next input event, so a held input is re-emitted with `InputAction:Fire` at the new scale. Original scales are restored when the curse ends. CoreScripts, chat, and menus are not touched. Older PlayerModules fall back to post-processing `GetMoveVector()`.

### Rebalance (Part D)

Pursuit speed multipliers now run from 1.00 (Common) to 1.09 (Divine), and aggression from 1.00 to 1.60. `validate` asserts that Divine speed stays under 28 and return speed stays above pursuit speed.

## Validation

### Unit tests (Studio, `ServerStorage.UnitTest`)

- Baseline before changes: 226/226.
- After: **247/247**, including the rewritten `CarryDebuff_Test`, extended `GuardianState_Test` and `GuardianChase_Test`, and new `GuardianJourney_Test`.

`GuardianJourney_Test` is a **simulation**, not a playtest. It runs 11 cases with 4 seeds × 2 lanes each, using a scripted carrier with 0.2s reaction. Depth cases are Common Grasslands, Legendary Swamp, Mythic Jungle, Secret CrystalCave, and Divine Volcano, plus each Volcano rarity. Every run asserts:

- the carrier escapes with 0 hits
- the guardian sleeps at home
- the return takes under 90s
- footprints and guardians stay outside the safe zone
- pursuit continues beyond the spawn biome

Attacks per 8 runs: Grasslands 0, Swamp 10, Jungle 22, CrystalCave 56, Volcano Divine 36, other Volcano rarities 24–32. The slowest Divine escape took 203s.

### Studio Play tests (port 34873)

| Script | Result | Covers |
|---|---|---|
| `tests/Phase3BRunway.server.luau` | 42 checks pass | Boundary instance; Jungle pursuit into Grasslands; disengage at the boundary; no re-aggro on re-entry; return and sleep with no failsafe logs; bank via `consumeOwned`; a Grasslands mid-attack escape with no hit; drop clears the curse; no reroll on re-pickup; death clears and respawn restores speed 16 |
| `tests/Phase3Integration.server.luau` | 124 checks pass | Existing Phase 3 flows with the new curse model |
| `tests/Phase3Rollback.server.luau` | 9 checks pass | Rollback paths |

Run Phase 3 Play scripts early in a fresh Play session. The field resets at 290s, which blocks pickup and resets guardians. One Integration failure came from crossing that reset, and the rerun passed.

`Phase3Integration` gained a 0.5s wait after respawn. Before that, its teleport raced the spawn placement.

### Multiplayer and race pass (2026-10-14)

Two `GuardianService` bugs were found and fixed in this pass:

- **Pursuit speed stuck high.** A guardian kept the speed profile of the strongest carry it had ever seen. So a Common carrier could still be chased at Legendary speed after the Legendary carrier escaped, dropped, or banked. The profile now follows the strongest carry the guardian still threatens.
- **Guardian gave up on a second carrier.** If the current target escaped, or was hit, between the 0.5s target updates, the guardian went to RETURNING. It did this even when another carrier from its biome was still threatened, so that carrier escaped free. Two-client testing exposed this. The guardian now picks a new target in the same frame. RETURNING behaviour is unchanged.

Every result below came from the fixed code (`GuardianService` 19,899 bytes). All 55 Rojo-owned scripts in Studio were checked against this worktree before and after the runs.

**Sync caveat.** During this pass, Studio was briefly connected to both Rojo servers. Port 34872 overwrote the Phase 3B scripts with the original worktree's code. One two-client attempt ran against that code. It failed to load `GuardianChase` and is discarded. After the user reconnected to 34873 only, a full 55-file check matched. Each two-client launch now aborts if Studio is not on the Phase 3B code. `Phase3BMultiplayer` also ends with an error, instead of hanging, if a Phase 3B module is missing.

| Test | Kind | Result |
|---|---|---|
| `tests/Phase3BMultiplayer.server.luau` (new) | Real Studio test: 2 actual clients, server-scripted movement | **120 checks pass** |
| `tests/Phase3Multiplayer.server.luau` + `.client.luau` | Real Studio test: 2 actual clients | **29 checks pass** |
| `tests/FieldRuntimeSmoke.server.luau` | Real Studio Play, single player, real 20s drop expiry and refill | **14 checks pass** |
| `tests/Phase3BRunway.server.luau` | Real Studio Play, single player, scripted movement | **42 checks pass** |
| `tests/Phase3Integration.server.luau` | Real Studio Play, single player | **124 checks pass** |
| `tests/Phase3Rollback.server.luau` | Real Studio Play, single player, fault injection | **9 checks pass** |
| `ServerStorage.UnitTest` | Unit tests and simulations, run in the Play server | **247/247** |

`Phase3BMultiplayer` covers:

1. **Simultaneous thefts from two biomes.** Two players pick up Jungle and Swamp items at the same moment. Each biome's guardian wakes exactly once and targets only its own thief; the other three stay asleep. Neither guardian ever targets the other biome's carrier. Both carriers cross the shared boundary still carrying. Each guardian goes to RETURNING only after its own carrier has crossed. Crossing neither banks nor drops either carry. Walking back out does not re-aggro either guardian. Both return home and sleep.
2. **Curse cleanup.** Banking A clears A's curse, slowdown and replicated attributes, and leaves B's carry and curse untouched. Dropping B clears B. A Legendary-or-better item dropped by A and recovered by B keeps the same curse and title. B banking it removes the record.
3. **Target switching and repeated pickups.** Two carriers come from one biome. The first thief is the initial target, and the guardian uses the strongest active carry's profile. When A reaches the safe zone, the guardian switches to B, keeps pursuing, and drops to B's speed profile. A stepping back beside B is never re-targeted. With no threats left, the guardian disengages. B then picks up the same item five times in a row. A guardian that was asleep wakes exactly once; one that was awake re-engages without a second wake. B becomes the target every time and the item's curse never changes. `ClaimVersion` increases on every pickup. Duplicate and stale `onPickup` acknowledgements are rejected. There is no curse residue afterwards and field uniqueness is preserved.
4. **Crowding stress, 45s.** Swamp and Jungle guardians converge on two neighbouring carriers, and every drop is re-picked immediately. Both guardians attacked (Swamp 2, Jungle 3). There were 8 hazard hits and 8 recoveries, with 0 rejected recoveries and 0 curse rerolls.
5. **Pickup within 4.5s of the 300-second reset.** The guardian wakes. When the reset begins, every guardian is asleep at home with no target. The carry and its curse are kept, uncarried records are removed, and pickups are rejected. No guardian woke during the reset window. A new-cycle pickup wakes only that biome's guardian, for the new thief. The previous-cycle carry still banks and cleans up.

Invariants sampled every frame across the whole run:
- no two guardians had overlapping live attacks
- no guardian entered the safe zone
- no hazard footprint reached the safe zone
- no failsafe was logged and there were no server errors

The closest two awake guardians came was 23.5 studs (target spacing 24). That spacing is a soft rule, and nothing failed because of it.

**What "real" means here.** The two-client tests use two actual Studio client processes and the real services, models and replication. The server script moves both characters, though, so they exercise no human input. Single-player Play tests do the same with one client. `GuardianJourney_Test` and the other unit cases are simulations.

### Integration with Phase 4C (2026-10-15)

Phase 3B (`44e6506`) was merged into `phase3-phase4a-snapshot` on top of Phase 4C (`ab9be8f`). The merge had no conflicts. `docs/CURRENT_STATE.md` was the only file both sides changed, and in different paragraphs. Phase 4C's `FeedService` uses only `CarryService.get` and `consumeOwned`, and Phase 3B kept both signatures. Phase 3B does not touch save data, pet records, or feeding. The four Phase 3B unit tests that Phase 4C had archived are back in active discovery. The `docs/audit/phase3b-preserved/` backups and the Studio `ServerStorage.Phase3BPreservedTests` archive remain only as audit records.

Every test below ran on the merged tree, served by Rojo on port 34872 only. All 77 Rojo-owned scripts in Studio matched the merged source before and after the runs.

| Test | Kind | Result |
|---|---|---|
| Unit suite | Unit tests and simulations | **277/277** |
| `Phase3BMultiplayer` | 2 actual clients, server-scripted movement | **120 pass** |
| `Phase3Multiplayer` | 2 actual clients | **29 pass** |
| `Phase4AMultiplayer` | 2 actual clients, injected fake persistence | **18 pass** |
| `Phase4BMultiplayer` | 2 actual clients, injected SessionStore | **11 pass** |
| `Phase4CIntegration` | Studio Play, single player | **89 pass** |
| `Phase4AIntegration` (with `Phase4APresentation` client) | Studio Play, includes a real field reset | **33 pass** |
| `Phase4ACompatibility` | Studio Play | **13 pass** |
| `Phase1Integration` | Studio Play | **32 pass** |
| `Phase3Integration` | Studio Play | **124 pass** |
| `Phase3BRunway` | Studio Play, scripted movement | **42 pass** |
| `Phase3Rollback` | Studio Play, fault injection | **9 pass** |
| `FieldRuntimeSmoke` | Studio Play | **14 pass** |
| `rojo build` | Build | **pass** |

Not run in this pass: `Phase4BIntegration` (it waits for a manual click on the evolution button), and the presentation-only client fixtures.

### Live keyboard input (simulated key events via Studio MCP, single client)

| Case | Result |
|---|---|
| No curse, hold W | moves forward (average dot with camera forward +1.000) |
| Inverted Controls active, hold W | moves backward (−1.000); banner "SECRET CURSE / INVERTED CONTROLS" |
| Inversion activates while W is held | forward until activation at +10.1s, then backward; stops on release |
| Cursed Momentum, hold W | 7.2 → 16.0 studs/s over 0.5s; ≈0 within 0.2s of release |
| Curse cleared | all bindings back to 1,1; banner hidden; forward at 16 |

### Not run or not verified

- **Gamepad.** The simulated `Thumbstick1Up` produced no movement even without a curse, so the tool cannot inject gamepad input. The gamepad binding is scaled with the others, but this is unverified.
- **Touch thumbsticks.** Unverified; no touch device was tested.
- **Human play feel.** Feel and difficulty with real players are unverified.
- **Disengage animation.** Only the hook exists; there is no animation.
- **Two humans.** The two-client runs move characters by script, so pursuit and curses have not been felt by two real players at once. Network latency beyond a local Studio session is also untested.
- **Hazards on bystanders.** A hazard can hit a carrier from another biome who stands inside its footprint. This is by design, and the stress run did not try to measure how often it happens.
- **Chat and menus while inverted.** Not exercised directly. The implementation never touches chat, menus, or CoreScripts.
- **Phase 4 integration.** Feeding while chased, and Phase 4 integration in general, are not verified until the branches are integrated.

## Files

Created:
- `src/client/CarryCursePresentation.luau`
- `tests/unit/Cases/GuardianJourney_Test.luau`
- `tests/Phase3BRunway.server.luau`
- `tests/Phase3BMultiplayer.server.luau` (two-client test, args `"Phase3BMultiplayer"`, not mapped by Rojo)

Rewritten or extended:
- `src/shared/CarryDebuff.luau`, `src/shared/GuardianChase.luau`
- `src/server/GuardianService.luau`, `src/server/CarryService.luau`
- `src/client/GuardianPresentation.luau`, `src/client/EffectsController.client.luau`
- `tests/unit/Cases/CarryDebuff_Test.luau`, `GuardianChase_Test.luau`, `GuardianState_Test.luau`
- `tests/Phase3Integration.server.luau`, `tests/Phase3Rollback.server.luau`
- this report
