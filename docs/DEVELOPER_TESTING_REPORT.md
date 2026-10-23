# Developer testing report

Studio-only developer panel for Feed a Pet. It prepares temporary sessions so Cash, Power, trainers, pets, resources, guardians, and travel can be tested without grinding. Production progression rules are unchanged.

Validated in Roblox Studio Play on place `104154372052853` (studio `ab8a5866-173b-43bd-9540-0978752f13af`), player Gogodino35, 19 October 2026.

## 1. Implemented developer commands

One server `RemoteFunction`, `ReplicatedStorage.Remotes.DevTest`, created only when the session is authorized. The client sends `{Command, Args}`. The server allowlist is `src/shared/DevTestProtocol.luau`. Handlers in `src/server/DevTestService.luau` call the existing services.

| Area | Commands |
| --- | --- |
| Session | `Status`, `Snapshot`, `Catalog`, `SetSeed` |
| Player | `SetPower`, `AddPower`, `ResetPower`, `SetCash`, `AddCash`, `ResetCash`, `CashForNext`, `SetSlowMode`, `SetSpeedOverride`, `ClearOverrides`, `ResetCharacter` |
| Pets | `SelectPet`, `CreatePet`, `SetGrowth`, `SetStage`, `SetAffinities`, `SetRarity`, `ApplyEvolution`, `ResetPet`, `AddMutation`, `RemoveMutation`, `SetFamily` |
| Items | `SpawnResource`, `GiveResource`, `GivePreset`, `DropCarry`, `ClearCarry`, `FeedPreview`, `FeedConfirm`, `ResetResources` |
| Trainers | `SetTrainerTier`, `BuyTrainer`, `StartTraining`, `StopTraining`, `ResetTrainer` |
| Guardians | `Teleport`, `ResetGuardians`, `GuardianScenario`, `CatchRecovery`, `TwoCarriers`, `ResetScenario` |
| Travel | `TravelSubmit`, `TravelScripted`, `TravelCancel`, `TravelClear`, `TravelExport` |
| Scenarios | `Scenario` with ids `Fresh`, `FirstEvolution`, `Swamp`, `Jungle`, `CrystalCave`, `Volcano`, `Catalyst`, `MaxTraining` |

Power presets: 0, 1K, 10K, 100K, 350K, 1M, 6M, 10M, 100M, 150M.

Speed override presets: 16, 18, 20, 22, 26, 30, 32. The override lives in a server table on `CarryService` and is written to the attribute `DevTestBaseOverride` (`-1` when off). It is never copied into the save. Slow Mode still forces precision speed 16. While carrying, the base is still capped at 18 and then multiplied by the carry slowdown. Ragdoll still sets speed to 0. With no override, `CarryService` uses `MovementCalculator.effective` exactly as before.

`Scenario`, `ResetPet`, `ResetTrainer`, `ResetResources`, and `TravelScripted` require `Args.Confirm == true`. The panel asks for a second click within 4 seconds.

Item shortcuts: Raw Meat, Ancient Bone, Bog Marrow (hybrid), Primal Catalyst, and the lowest-power launch feed matching the pet's weakest affinity. World spawn weights are not edited. A grant replaces one available node through `ResourceService.devReplace` / `SpawnService.devGrant`, which assign a new GUID.

Guardian scenarios use the live chase: Ordinary, Heavy, Cursed, Close, and Long. Catch recovery calls `GuardianCatch.apply` after a real drop. Two carriers requires a second player already in that Studio server.

## 2. Studio-only authorization

All of the following must be true before a command mutates state:

1. `RunService:IsStudio()`.
2. `DevTestConfig.Enabled == true` (`src/server/DevTestConfig.luau`).
3. The invoking player's `UserId` is in `RunnerUserIds`, or that list is empty. An empty list means every player in this Studio server. A client cannot add itself.
4. `DataService` reports backend `StudioMemory` and the session is writable.
5. `DevTestProtocol.validate` accepts the command name and arguments.

`DevTest.start` returns without creating the remote unless both Studio and `Enabled` are true. Published servers therefore have no `DevTest` remote to invoke. The client panel also returns immediately outside Studio, which only hides the GUI. The server checks are the authorization.

The remote's player argument is the invoker supplied by Roblox. `TravelSubmit` always stores `Source = "Human"` on the server, even if the client sends `Scripted`. Unknown commands, non-finite numbers, negative Power, speed `999`, and a resource whose biome does not match are rejected before a handler runs. Mutations go through `DataService`, `CarryService`, `SpawnService`, `FeedService`, `TrainingService`, `EvolutionCalculator`, and `GuardianService`. Production remotes (`FeedInteraction`, `TrainingInteraction`, `SetSlowMode`, `DropCarried`) were not given cheat arguments.

`DataService.getStore` still asserts that Studio never opens `MonsterProgress_v1`. Studio sessions use `SessionStore.memoryAdapter()`. Stop discards that memory.

## 3. UI usage

`src/client/DevTestPanel.client.luau` builds one `ScreenGui` named `DevTestPanel` (`ResetOnSpawn = false`). It appears only after `Status` returns `Ok`.

- A red **TEST MODE** label, 150×22, stays at the top left whenever the panel is authorized.
- **Dev panel** (150×24) opens and closes the frame. The frame starts closed.
- The frame is 320 pixels wide and 72% of the screen height, anchored at `(8, 64)`. The body scrolls. Tabs are Player, Pets, Items, Trainers, Guardians, Travel, and Scenarios. Tab labels show the first four letters.
- Dropdowns are cycling buttons. Numbers are text boxes. Destructive actions need a second click.
- The readout polls a snapshot every 0.75 seconds while the frame is visible. It shows cash, power, speeds, carry, pet, trainer, and the first guardian.

In the measured Play viewport of 1467×582, the open frame was 320×377 at `(8, 64)`. The world view remains usable beside it.

## 4. Scenario setup

Scenarios read live definitions. Double-click the scenario in the Scenarios tab.

| Scenario | What it sets |
| --- | --- |
| Fresh | Cash 0, Power 0, trainer tier 1, Slow Mode off, default starter pet, Grasslands discovered, training level 0, feed/evolution/training stats 0. Drops a carried item and clears the speed override. |
| First Evolution | ProtoRex at growth 20 and flesh 15, Power 0, tier 1, then Raw Meat. |
| Swamp | Fangling, Power = `SmallFish.PowerRequired` (1500), tier 2. |
| Jungle | MatureRex, Power = `WildFruit.PowerRequired` (25000), tier 4. |
| Crystal Cave | ApexRex, Power = `CrystalShard.PowerRequired` (350000), tier 6. |
| Volcano | ApexRex, Power = `CharredMeat.PowerRequired` (6000000), tier 8. |
| Catalyst | Fangling at growth 80 and flesh 80, Primal family cleared, Power = `PrimalCatalyst.PowerRequired` (1000), then Primal Catalyst. |
| Maximum Training | Trainer tier 10, Power 150000000, Slow Mode off. |

Income can raise Cash above 0 within a few seconds of Play. Reset Cash again if a test needs exactly 0.

Pet stage changes prefer a real form in the same lineage so `Evolution.valid` stays true. `Override` is required to force a stage with no matching form, and that pet is marked `DevTestFixture`. The fixture exists only in the Studio memory session.

## 5. Test evidence

Server log:

- `[DataService] StudioMemory: writable temporary sessions; no production DataStore requests. Data resets when Play stops.`
- `[DevTest] Studio memory panel authorized`
- No DataStore errors.

`DevTestProtocol` unit tests, run inside that Play session: 4 run, 4 passed, 0 failed.

| Check | Result |
| --- | --- |
| Panel built and printed `panel ready` | Pass. Banner text `TEST MODE`. |
| Open frame coverage | 320×377 on a 1467×582 viewport, position `(8, 64)`. |
| `GrantCash` | Rejected: `Unknown command`. |
| `SetPower` with `math.huge` | Rejected: `Value must be a finite number`. |
| `SetSpeedOverride` 999 | Rejected: `Speed is not a test preset`. |
| `SetPower` 1000 | Power attribute 1000. Backend `StudioMemory`. |
| `SetTrainerTier` 4 | Station attribute tier 4, trainer id `PowerCage`, visual tier 4. |
| Speed override 22, then Slow Mode | Effective speed 22, then 16. `ClearOverrides` removed the override. |
| Give Raw Meat | Token `488cb2ef-95c9-4e28-8c3d-4607793f5fb8`. Drop cleared it. |
| Teleport Swamp | Root moved to about `(747.5, 3.8, -99.2)`, 30 studs from the Swamp home. |
| Evolution | Growth 25 and flesh 20 on the owned pet. `ApplyEvolution` returned `Evolves into Fangling`. Attributes became Fangling, stage 1. |
| Feed | Carried Raw Meat `825b1abe-cbc3-4d68-8063-d151b65c266f`. Preview ticket matched that GUID. Confirm returned `Fed Raw Meat`. |
| Guardian theft | Ordinary Grasslands theft of Berries. Guardian state `PURSUING`. Reset cleared the carry. |
| Catch recovery | `GuardianRagdoll=true`, `DropReason=GuardianCatch:Grasslands`, carry cleared. Reset returned the fixture to baseline. |
| Two carriers, one client | Rejected: `A second Studio client is required`. |
| Swamp scenario | Power 1500, trainer tier 2, pet Fangling. |
| Human row with client `Source=Scripted` | Stored as `Source=Human`. |
| Scripted Grasslands cell | See section 6. |

`BuyTrainer` and `StartTraining` / `StopTraining` call the existing training APIs after moving the character to the station. This session did not click those two buttons separately. Tier changes were verified through `SetTrainerTier` and the station visual.

## 6. Travel measurement methodology

Human and scripted rows are stored in separate lists. Export refuses to merge them into one success rate. The server overwrites any client-supplied source on a human submit.

**Human.** Press Start human timer, play, then Stop. The client samples every 0.75 seconds. Outbound and pickup are both the time from the start until a carried token appears. Wake is the time until a guardian enters pursuit, warning, or hazard. Chase is safety time minus wake. Result is Catch, Escape, or Incomplete. Return-to-base is not inferred for a human run (`ReturnBase = -1`).

**Scripted.** One confirmed cell walks an anchored character. This is kinematic fixture movement, not a human success. The route is:

1. Place the character on the assigned base `PlayerSpawn`.
2. Walk to the chosen node. Near, Middle, and Far are the closest, median, and farthest available nodes from the guardian home.
3. Grant the resource through `SpawnService.devGrant`. Ordinary and Heavy use an empty curse assignment. Cursed calls `CarryDebuff.assign` with a fixed roll of 0.
4. Walk toward the safe-zone boundary at the current `WalkSpeed`.
5. If the character crosses the boundary, walk back to `PlayerSpawn`.

Recorded clocks:

- `Outbound` / `Pickup`: spawn to the node, then the grant.
- `Wake`: theft until the guardian reaches `PURSUING`, `WARNING`, or `HAZARD`.
- `Safety`: theft until the safe-zone line. The clock stops at the crossing. The walk home does not extend it.
- `Chase`: safety minus wake.
- `ReturnBase`: duration of the walk from the line back to spawn.
- `RoundTrip`: spawn departure until the character is home again.
- `Speed`: effective speed while carrying, after the carry cap and slowdown. `RequestedSpeed` is the override that was asked for.

Corrected Grasslands cell, ordinary Berries, Middle, requested speed 30, Slow Mode off, seed 0:

| Field | Seconds |
| --- | --- |
| Outbound / pickup | 8.73 |
| Wake | 0.83 |
| Safety | 9.33 |
| Chase | 8.50 |
| Return to base | 6.37 |
| Round trip | 24.47 |
| Effective carrying speed | 18 |
| Result | Escape, 0 catches |

Outbound plus safety plus return is 24.43 seconds, matching the 24.47 second round trip within a few frames. Wake matches the 0.8 second guardian windup. Requested speed 30 became carrying speed 18 because the carry cap stayed in force.

The matrix is 5 biomes × speeds 16, 18, 22, 30 × ordinary, heavy, cursed × near, middle, far (180 cells). The panel runs one confirmed cell. It does not start the full matrix. Cancel is `TravelCancel`. A batch runner with progress already exists as the single-cell job; a multi-cell batch was not added, because an unattended 180-cell real-time run would take hours.

`SetSeed` stores a seed on the exported row. Production curse rolls and node placement are not reseeded. Forced `none` and `cursed` assignments make the scripted curse deterministic without touching those generators.

## 7. Exported data format

Travel → Export JSON fills a text box. Copy it from there. Shape:

```json
{
  "Note": "Human and Scripted rows are separate. Do not merge them into one success rate.",
  "Seed": 0,
  "Human": [
    {
      "Source": "Human",
      "UserId": 664814480,
      "At": 1792455134.06,
      "Area": "Grasslands",
      "Result": "Incomplete",
      "Catches": 0,
      "Outbound": 1.5,
      "Pickup": -1,
      "Wake": -1,
      "Chase": -1,
      "Safety": -1,
      "ReturnBase": -1,
      "RoundTrip": -1,
      "Speed": 16
    }
  ],
  "Scripted": [
    {
      "Source": "Scripted",
      "UserId": 664814480,
      "Area": "Grasslands",
      "Resource": "Berries",
      "Kind": "Ordinary",
      "Position": "Middle",
      "RequestedSpeed": 30,
      "Speed": 18,
      "Slow": false,
      "Seed": 0,
      "Result": "Escape",
      "Catches": 0,
      "Outbound": 8.73,
      "Pickup": 8.73,
      "Wake": 0.83,
      "Chase": 8.50,
      "Safety": 9.33,
      "ReturnBase": 6.37,
      "RoundTrip": 24.47
    }
  ]
}
```

`-1` means that clock was not observed. Each list keeps the latest 30 rows. `UserId` distinguishes clients in the same Studio server.

## 8. Limitations

- The panel and the remote exist only in Studio with `DevTestConfig.Enabled`. This session did not publish a live server. The published-server guarantee is the `start()` gate, `Protocol.allowed(false, ...) == false`, the `StudioMemory` requirement on every mutation, and the DataStore assert.
- Two Studio clients were not connected. `TwoCarriers` was rejected for the single player. Runner allowlists were unit-tested, not exercised with a second UserId in Play.
- `BuyTrainer` and start/stop training were not clicked in this Play session.
- The full 180-cell matrix was not run.
- Earlier Phase 2, 3B, 4, and 5 Play suites were not re-run for this change. The new protocol unit tests passed. Economy numbers, guardian speeds, and spawn weights were not edited. With no test override, walk speed still comes from `MovementCalculator.effective`.
- Human samples are 0.75 seconds apart. Rebuilding the Travel tab replaces the running timer closure.
- Scripted movement anchors the character and moves it on a straight line. It is a fixture, not player input. Cleanup unanchors, clears the override, restores the previous Slow Mode, and resets guardians.
- The recorded seed does not reseed production randomness.
- A successful test grant leaves `SpawnReason = "DevTest"` until Reset resources. Failed grants release the token and allow the normal respawn.
- `GivePreset` Evolution picks the cheapest launch feed for the pet's weakest affinity. It does not look up a specific branch ingredient.
- Stage 5 ascension and awakening still report Locked, because those requirements are not approved.
- Cash income continues during Play, so a Fresh scenario's cash does not stay at 0.
- `DevTestFixture` pets remain in the Studio memory save until Stop. They cannot reach `MonsterProgress_v1` from Studio.

## 9. Known issues

- The first client load failed to parse because an `if` expression included an extra `end`. That is fixed. The panel then built.
- An intermediate scripted row kept updating the safety clock during the walk home, so chase and safety included the return. The heartbeat now stops once the result is set. The 24.47 second row above is the corrected measurement. An earlier row with `Outbound = -1` is from before the outbound leg existed.
- A duplicate `DevTestProtocol_Test` module was present in the open Studio session and made the unit runner report 8 passes. The extra copy was removed. The rerun was 4 passes. If Rojo sync duplicates it again, delete the second module before trusting the count.
- Opening the panel from `execute_luau` set `Visible` directly. The on-screen button uses that same property. A hardware click on the button was not recorded.

## 10. Production gameplay

This work does not change trainer prices, power-to-speed milestones, guardian chase speeds, resource weights, evolution requirements, or DataStore names. Developer grants and speed overrides run only after the Studio memory check, and the speed override is discarded on leave and on Stop. No production remote can set arbitrary Cash, Power, mutations, or items.
