---
type: engineering
status: mixed
last_verified: 2026-10-21
source_paths:
  - src/shared/PlayerData.luau
  - src/server/DataService.luau
  - src/server/SessionStore.luau
  - src/server/FeedService.luau
  - src/server/TrainingService.luau
  - src/server/CarryService.luau
  - src/server/SpawnService.luau
  - src/server/DevTestService.luau
  - src/server/InteractionGuard.luau
  - src/shared/FieldState.luau
---

# Data, Networking and Persistence

## At a Glance

Progress saves under one DataStore, `MonsterProgress_v1`, keys `u_<UserId>`, through `DataService` and `SessionStore`. Studio never opens that store. Remotes live under `ReplicatedStorage.Remotes`, created by the owning service. The server publishes player state as attributes; the client renders them.

## Save Data

**VERIFIED IMPLEMENTATION.** `PlayerData.SaveData`:

- `Cash`, `Power`, `TrainerTier` (default 1), `SlowMode` (default false), `EquippedMonster` (default `ProtoRex`)
- `Monsters` keyed by species id (record fields in [[01 - Game Design/Pets, Feeding and Evolution]])
- `BaseUpgrades.TrainingLevel` (legacy floor), `DiscoveredAreas`, `Stats.Feeds`, `Stats.Evolutions`, `Stats.Trainings`

`PlayerData.normalize` fills defaults, keeps unknown inventory/receipt/entitlement fields, defaults a missing `TrainerTier` to 1, treats `SlowMode` as true only for boolean `true`, and falls back to ProtoRex when the equipped id has no record. Additive migration only; no store rename or reset.

**Not saved:** carried item and curses, guardian runtime state, field node occupancy, `CarryService` test base override, dev-panel travel rows and `DevTestFixture`.

**Field record** (`FieldState`, runtime only): GUID, area, resource id, node, rarity, state (`AVAILABLE`, `CARRIED`, `DROPPED`, `CONSUMED`, `DESTROYED`), spawn reason.

## Lifecycle and Recovery

- `BaseService` loads the player; `DataService.start` prepares the store and autosaves every 60 s (`AUTOSAVE_SECONDS`).
- `RunService:IsStudio()` selects `SessionStore.memoryAdapter()` (backend `StudioMemory`; discarded on Stop). `getStore()` never opens a DataStore in Studio. Published servers use `ProductionDataStore`.
- A failed or malformed production load becomes **read-only**; a successful nil is a new writable save. Concurrent loads share one request. `UpdateAsync` uses a full-record optimistic check; a conflict flips that session to read-only.
- Deploy note: older servers that still `SetAsync` the whole key cannot join the conflict protocol. Drain them before deploying. A live two-server rejoin test has not been recorded (UNKNOWN).

## Remote Contracts

| Remote | Kind | Client sends | Server does |
| --- | --- | --- | --- |
| `FeedInteraction` | RemoteEvent | `Preview`; `Confirm` + ticket; `Evolve` + pet key + token + branch id | Proximity/ticket checks, then feed or `MonsterService.chooseEvolution`; fires result table back |
| `TrainingInteraction` | RemoteEvent | `Start`, `Stop`, `Upgrade` + expected next tier | Distance check (12 studs), then train, stop, or purchase |
| `DropCarried` | RemoteEvent | nothing | Drops the server-owned item |
| `SetSlowMode` | RemoteEvent | boolean | Persists Slow Mode, recomputes WalkSpeed |
| `FieldRareSpawn` | RemoteEvent | server to client | Presentation only, never a grant |
| `DevTest` | RemoteFunction | `{Command, Args}` | Studio only; see [[02 - Engineering/Security, Testing and Diagnostics]] |

`InteractionGuard.allow` rate-limits feed requests (0.2 s). `ReplicatedStorage.WorldFieldState` is created by `SpawnService`.

**Published attributes** (server to client): `Power`, `Cash`, `TrainerTier`, `SlowMode`, `EffectiveMovementSpeed`, `CarriedResourceId`, `CarriedInstanceId`, `MonsterId`, `MonsterName`, `PetStage`, `PetStageLabel`, `GrowthReserve`, `PendingEvolution`, `OwnedPetKey`, `StatusMessage`. Guardian parts expose `GuardianState`, `AreaId`, `GuardianName`, `HazardKind`.

## Failure Modes

Bad feed or training requests are ignored or answered with a reason string; they do not grant anything. Over-distance prompts fail. A second carry is rejected. Non-finite or negative developer values are rejected by `DevTestProtocol` before a handler runs. A read-only session cannot save and accrues no Cash.

## Constraints and Invariants

- Server authoritative for ownership, validation, inventory, Cash, Power, rarity and mutation rolls, evolution, saves.
- Never trust client-provided rewards, positions as proof, or pet statistics.
- Do not add a second DataStore, a remote, or a save field without an explicit migration task. Do not store test overrides as progression. `TrainingLevel` is not a convertible trainer tier.

## Open Questions

Cloud rejoin behavior across servers; whether Index discovery will use `DiscoveredAreas` or a new field ([[05 - Development/Decisions and Open Questions]]).

## Related Notes and Source Files

[[02 - Engineering/Architecture and Module Map]], `docs/STUDIO_MEMORY_FEEDING_FIX.md`, tests `SessionStore_Test`, `Phase1Lifecycle`, `Phase3Rollback`.
