# Phase 3 carry and guardian contract

Updated 2026-10-11. This supplements, rather than changes, the Phase 2 resource/spawn specification. No Phase 4 progression, prices, inventory or persistence schema is introduced.

## Carry integration

SpawnService remains the only proximity-prompt acquisition entry. It reconciles the field deadline, rate-limits, checks a living character/distance/availability, then asks ResourceService to check authoritative Power and claim the existing GUID. FieldState prevents two owners or two major resources per player. Later areas remain open; resource Power is the access gate, with no invented invisible area wall.

Each claim increments ClaimVersion on that record. After successful visual attachment, GuardianService acknowledges that version once through ResourceService, using the centralized resource rarity. Failed/replayed requests cannot disturb a guardian. A later legitimate recovery of the same GUID has a new version and may contribute again. No unbounded event-ID history is stored.

CarryService retains its public integration APIs. New forceDrop(player, character, reason) is the common manual/hazard/death/reset consequence. It verifies the exact carry character, clears presentation/speed, then returns the same authoritative record to the world. ResourceService floor-raycasts, falling back to the original node if over a void; if no safe floor can be resolved it releases the record instead of leaving an orphan.

Existing lifecycle policies are preserved: death/character removal drops at a valid floor; PlayerRemoving destroys a still-carried record. If CharacterRemoving already resolved it, the existing dropped record expires under the ordinary 20-second policy. Respawn callbacks disconnect prior humanoid listeners and verify character identity after waits. An old death/removal callback cannot clear a new carry session. Field reset preserves carried GUIDs and detaches old node reservations. Authorized feeding still uses consumeOwned exactly once; no banking system is added.

Movement has one server writer: CarryService.recalculateMovement, using the locked `16 * (1 - CarrySlowdown)` formula. Repeated requests never multiply modifiers. TrainingService changes Power, not movement speed; there is no existing movement-upgrade formula to integrate or invent. Keyboard G, gamepad B and the touch Drop button use the same rate-limited DropCarried remote. This is request validation, not a claim of complete character-physics anti-cheat.

## Guardian framework

GuardianConfig owns five hazard configurations. GuardianState explicitly permits SLEEPING → DISTURBED → WARNING → HAZARD → COOLDOWN → SLEEPING. Field reset is an explicit cancellation to SLEEPING and invalidates the activation. One server Heartbeat samples active encounters; sleeping/disturbed guardians do not run AI/pathfinding or maintain delay chains.

Common/Uncommon/Rare/Epic/Legendary/Mythic/Cosmic contribute 8/10/12/15/20/25/35. Threshold is 100. Secret, Eternal and Divine immediately wake. Meters are per area and shared by players. During WARNING/HAZARD/COOLDOWN, successful pickups are acknowledged but do not queue another attack. No decay; cooldown/reset returns to zero. These latter behaviors are explicit temporary defaults where the design was unspecified.

| Area | Hazard | Warning / active / cooldown seconds | Temporary footprint |
|---|---|---|---|
| Grasslands | Charge sweep | 1 / 1.2 / 8 | 90×16, moving 10-stud front |
| Swamp | Forward lunge | 0.9 / 0.8 / 8 | 48×26, moving 12-stud front |
| Jungle | Expanding filled-disc slam | 1.25 / 1.4 / 8 | Radius 40 |
| CrystalCave | Straight charge sweep | 0.75 / 0.9 / 8 | 110×18, moving 12-stud front |
| Volcano | Cross-lane fire sweep | 1.25 / 1.8 / 10 | 80×40, moving 8-stud front |

All dimensions/active durations/cooldowns are isolated graybox tuning, not permanent progression values. The attack frame locks at WARNING around the triggering acquisition, clamped to the inspected area's floor. The long axis follows that floor. Yellow footprint plus the starting strip telegraph the attack; the red moving strip/disc shows execution. Guardian body blocks remain at their resting positions: the moving hazard is the explicitly allowed equivalent sweep.

GuardianGeometry is shared by warning visuals and authoritative contact. Player root centers within the configured vertical interval are checked against swept geometry between server samples. Warning time and post-hazard time are clipped out; delayed frames do not extend the attack. Charge/lunge/fire use moving-box segment intersection; slam uses segment versus expanding-disc intersection. Each player can be affected once per activation, even if they recover or respawn during it. No Touched/client hit report, HP, damage, kill reward, knockback or ragdoll is used.

## Presentation and hooks

The existing UIController owns a minimal carry card (placeholder diamond icon, name, rarity, penalty), hidden when empty. Server-derived compact Power notifications use `NEED 25K POWER`; notices are rate-limited and expire after two seconds on the client.

EffectsController starts GuardianPresentation. Its local BindableEvent hooks are Wake, Warning, Attack, Cooldown, Sleep, SoundRequested, VFXRequested, CameraShake and ResourceDropped. They are presentation-only; none accepts server gameplay requests. Camera offset is briefly perturbed and restored rather than restoring a stale camera CFrame. Stop disconnects owned listeners and restores the camera. GuardianHud shows five replicated state/meters; world billboards retain the same information. No final animation/audio assets are required or fabricated.

## Repeatable tests

- Existing Studio unit runner: new GuardianState_Test, GuardianGeometry_Test and NumberFormat_Test plus all Phase 1/2 cases.
- Phase3Integration.server.luau + Phase3Presentation.client.luau: actual one-player service and paired UI checks; install client observer first. Test modifies only an isolated Studio session, restores Power/position, and intentionally respawns its player.
- Phase3Multiplayer.server.luau + Phase3Multiplayer.client.luau: opt-in two-real-client StudioTestService fixture, arguments `Phase3Multiplayer`. Server ends the session with a structured result. It intentionally disconnects one test client.
- FieldIntegration and FieldRuntimeSmoke: rerun the actual field cycle and drop expiry/refill regression checks after Phase 3 tests.

See PHASE3_RESULTS.md for executed results versus unavailable/not-tested checks; test source alone is not passing evidence.
