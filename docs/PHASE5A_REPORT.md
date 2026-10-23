# Phase 5A — Cash, trainers and Power

Date: 2026-10-18. Scope: Phase 5A only. Functional native UI and grayboxes, not final art.
No Speed progression, guardian tuning, resource rebalance, monetization, offline income,
production DataStore access, branch merge, or place publication.

## Inspection and integration

Read master context, CURRENT_STATE, finalized resource specification, 4A–4D reports,
gameplay tuning/radial layout reports, and the existing services, definitions and save
lifecycle. Branch `phase3-phase4a-snapshot`, original worktree
`D:/Coding_projects/Roblox/Feed-a-Dino`, initial HEAD `86228f2`. Existing uncommitted
Phase 4 report/test and radial-biome changes were preserved. DefinitionValidation's
radial validation remains intact; only economy validation/warning was extended.

Before edits, official Studio MCP ran **337/337 unit tests**. The old MonsterService
income loop used training multipliers, rounded earnings, and lacked a writable-session
check. TrainingService awarded Power per prompt trigger and sold unbounded legacy
TrainingLevel increments, also without checking writability. These paths were replaced
inside existing services, not supplemented by competing currency/persistence systems.

## Authoritative economy

One idempotently initialized TrainingService Heartbeat owns Cash and Power ticks.
There is no per-player or per-respawn reward coroutine. MonsterService no longer starts
an income loop. Each player has one session-bound Cash accumulator and, while training,
one character/base/station/session-bound training accumulator.

`Cash/sec = EconomyConfig.BaseCashPerSecond (0.5) × PetMultipliers.IncomeMultiplier`

`Power/sec = BaseTrainingGain (5) × trainer multiplier × active pet TrainingMultiplier × temporary boost (1)`

The two base values retain the old starter income (1 Cash / 2 seconds) and training
base. Fractional Cash/Power are retained. Phase 4D's separate channels, species floor,
rarity/stage/mutation/Awakening metadata and bounds are not erased or rebalanced.
ProtoRex produces 0.5 Cash/sec; Fangling produces 0.75; ordinary mature/apex/ascended
forms produce 1.25. Training with Tier 1 is respectively 10, 15, 25 Power/sec.
No new temporary boost acquisition exists; its centralized default is one.

Every heartbeat checks current writability, valid finite economy state, active owned
pet, and (for training) living current character, assigned base ownership, registered
station and 12-stud distance. Starting training awards nothing immediately. Repeated
starts cannot duplicate sessions or reset an active accumulator. Stop, leaving, death,
character replacement/removal, invalid session, session-table replacement, base ownership
change, or disconnect ends training. A new start discards unfinished tick credit.
Income can continue while dead if the session and active pet remain valid.

Ticks require one second of verified server time. Heartbeat credit is capped at 0.25s
per frame; long stalls deliberately under-credit instead of granting unvalidated catch-up
rewards. Rates cap at 1e12/sec and balances saturate at 2^53−1, technical safety bounds.
Invalid/nonfinite/negative balances, tiers or multipliers fail closed. No offline credit.

## Trainer ladder — PROVISIONAL_BALANCE

All prices live in TrainerDefinitions. Multipliers are the user-specified locked values.
Tier 1 is free initial ownership, not a repeatable purchase. Every purchase requests an
explicit expected next tier. The server validates distance, ownership, session, tier and
Cash, then commits Cash and TrainerTier without yielding. Replaying an accepted target
cannot buy another tier. No client reward, multiplier or balance is accepted.

| Tier | Trainer | Multiplier | Cash price | Power/sec (pet x1 / x2.5) | Seconds to earn price (pet x1 / x2.5) |
|---:|---|---:|---:|---:|---:|
| 1 | Training Mat | 2 | 0 | 10 / 25 | 0 / 0 |
| 2 | Weighted Sled | 5 | 25 | 25 / 62.5 | 50 / 20 |
| 3 | Iron Rig | 12 | 100 | 60 / 150 | 200 / 80 |
| 4 | Power Cage | 30 | 250 | 150 / 375 | 500 / 200 |
| 5 | Golden Gym | 80 | 500 | 400 / 1000 | 1000 / 400 |
| 6 | Gravity Chamber | 100 | 1000 | 500 / 1250 | 2000 / 800 |
| 7 | Cosmic Reactor | 200 | 2000 | 1000 / 2500 | 4000 / 1600 |
| 8 | Abyss Chamber | 500 | 4000 | 2500 / 6250 | 8000 / 3200 |
| 9 | Eternal Forge | 1000 | 8000 | 5000 / 12500 | 16000 / 6400 |
| 10 | Divine Reactor | 2000 | 16000 | 10000 / 25000 | 32000 / 12800 |

Cost times are incremental, starting with zero Cash, excluding travel/feeding. Total
cost is 31,875 Cash: 17h42m30s at pet x1 or 7h05m at x2.5. First upgrade is 50 seconds
at starter income or 33.34 seconds at juvenile income from zero. A first draft's much
higher prices were reduced before final validation; no approved resource/pet values changed.

## Progression measurements and remaining balance questions

Deterministic one-second calculation: zero Cash/Power, continuously train, buy the next
tier immediately when affordable, fixed pet multiplier, boost one, no legacy levels.
Recomputed in Studio using the actual EconomyCalculator; results matched the table.
These are optimistic time-at-station scenarios, not measured human progression or
free evolved pets. Actual players spend time stealing, escaping and feeding.

| Power requirement | Example | Fixed pet x1 | Fixed pet x2.5 |
|---:|---|---:|---:|
| 50 | Bone Chunk | 5s | 2s |
| 1K | Primal Catalyst | 70s | 28s |
| 1.5K | First Swamp resource | 90s | 36s |
| 25K | First Jungle resource | 575s (9m35s) | 230s (3m50s) |
| 350K | First CrystalCave resource | 2162s (36m02s) | 865s (14m25s) |
| 6M | First Volcano resource | 10765s (2h59m25s) | 4306s (1h11m46s) |
| 150M | Inferno Catalyst | 51553s (14h19m13s) | 20622s (5h43m42s) |

No mathematically impossible Power gap: even Tier 1 earns continuously and every
listed requirement is below arithmetic bounds. However, multi-hour late-game training
is a substantial pacing risk. Current Stage 2–4 form multipliers mostly stay at x2.5;
further evolution does not automatically accelerate the economy. Tier 6 doubles the
price for only a 25% trainer increase, inherited from the locked multiplier ladder.
Approve these prices and intended session lengths before release. This phase does not
silently improve approved resource requirements, guardian speeds or pet multipliers.

## Persistence and legacy compatibility

Existing Cash and Power remain in the same save. New `TrainerTier` defaults to 1 only
when absent. Explicit malformed tiers are retained but economy operations reject them.
`BaseUpgrades.TrainingLevel` is not reinterpreted, deleted, refunded, or incremented by
new purchases. For nonzero old levels the old `legacyGain(level, pet)` is a **minimum**
training gain before boosts, not an additional stacked bonus. The player uses the new
ladder when its formula exceeds that floor. This preserves purchased benefits without
fabricating a tier conversion or reducing legitimate Power/Cash/pet history.

DataService and SessionStore source, store `MonsterProgress_v1`, keys `u_<UserId>`,
failed-load/malformed/conflict protections, opaque entitlement fields, owned pet IDs,
Growth, Flora and evolution/catalyst/mutation fields remain unchanged. Ordinary Studio
uses the existing writable `StudioMemory` adapter, discarded after Stop. Published
cloud persistence was deliberately not accessed. Memory reload evidence is not a claim
of cloud durability. Autosave/crash loss and optimistic conflict limitations remain.
Drain old incompatible writers before deployment; rollback must retain additive fields.

## Grayboxes, UI and rendering investigation

TrainerVisualService builds ten distinct native-Part silhouettes: mat, runners/weights,
barbell rack, cage, bench/crowned gym, gravity chamber, orbital reactor, obelisks,
forge/chimney, and winged reactor. Models use 2–18 parts, no scripts/particles/animations,
anchored noncolliding decoration and one stable interaction part with two prompts.
Only its own runtime `TrainerVisual` is replaced on upgrade; the station, active
training session and prompts stay stable. Vacated bases return to Tier 1.

The legacy +10-stud spawn offset put the pad below FeedingPoint.Part: pad Y=0.4055,
feeding surface Y≈1.14–1.15. The smallest placement fix moves only the generated pad
to the inspected clear +20-stud apron and raycasts its floor height. All four sites
hit Workspace.Ground at Y=−0.538. Saved bases, map geometry and assets are untouched.

The reported missing world was broader than trainers: Play client had 1,451 parts,
1,419 nontransparent, zero LocalTransparencyModifier=1, normal Humanoid camera and
streaming. Edit rendered normally. Automatic graphics, ViewMode.None and no debug
overlays were found; no source called Set3dRenderingEnabled. Stop/Edit inspection/fresh
Play restored both normal-camera world rendering and screenshots without a persistent
graphics change. The transient engine/viewport trigger was **not conclusively identified**.
The MCP capability disallows Set3dRenderingEnabled; no bypass was attempted. The buried
trainer issue above is a separate confirmed placement defect and was fixed in code.
All ten models subsequently rendered in a settled native ViewportFrame gallery.
Fresh-Play inspection confirmed exactly one TrainingStation at each of the four bases,
with each pad's bottom flush against Workspace.Ground (zero burial). A normal-world
MCP capture visibly confirmed the mat beside, rather than under, the feeding platform.

UIController owns one Cash/Power/rate panel with current/next trainer, pet multiplier,
price, Start/Stop and Buy buttons. Existing server StatusMessage supplies failure text.
The new runtime TrainingInteraction RemoteEvent has one server handler and one client
consumer. The shop prompt opens this panel. No client economy calculations grant state.
Screenshot inspection caught overlap with guardian status; the panel now sits below the
pet HUD, and the carry card is slightly narrower. Desktop verified; phone/device QA is
not claimed. Final styling remains Phase 6.

## Test evidence

| Test | Actual result |
|---|---|
| Pre-change unit baseline | PASS 337/337 |
| Expanded unit suite | PASS 369/369: 32 new economy contracts, all earlier cases retained |
| Phase5AIntegration | PASS 174 checks again after final prices and placement correction |
| Phase5ALoop | PASS 37 checks, real StudioMemory services; actual MCP FEED, BUY, START clicks |
| Phase5APresentation | PASS 9 checks; real client forged/replayed purchase/start payloads |
| Phase5AMultiplayer | PASS 13 checks with two actual Studio clients; distinct stations, simultaneous training, 50 competing purchases, disconnect and surviving player's income/training |
| Phase4AIntegration / Presentation | PASS 33 server + 7 client, including actual field reset, death/recovery and feed replays |
| Phase1Integration | PASS 32, including the updated one-second training contract |
| Phase3Integration | PASS 129; all five hazards, recovery, GUID integrity and stale-character rejection |
| FieldRuntimeSmoke | PASS 14; actual 20-second dropped expiry, node refill and physical GUID cleanup |
| Phase4ACompatibility | PASS 13 |
| Phase4BIntegration / Presentation | PASS 34 server + 6 client; actual MCP Mossback choice click |
| Phase4CIntegration | PASS 89; first attempt hit its outside-reset precondition, then reran outside reset |
| Phase4DIntegration | PASS 18 |
| Ten model render inspection | PASS settled native preview of all ten actual model instances; 2–18 parts each |
| Final unit rerun | PASS 369/369 after final prices and placement correction |
| Rojo build / whitespace | PASS final build and git diff --check |
| Studio source inventory | PASS all 108 mapped scripts match repository source fingerprints; no duplicate mapped instances |
| Final regression status | PASS for the executed suites above; verification limits below remain explicit |

Full-loop fixture seeds only predictable resource GUID records and uses scripted
relocation, not a human escape/fun playtest. Starting from zero Cash/Power and a starter,
Bone Chunk initially rejects with NEED 50 POWER. Five Raw Meat feeds evolve Fangling;
natural passive earnings fund Weighted Sled; real one-second training enables Bone Chunk.
No test currency is granted in that loop. Separate integration seeds balances/tiers for
exhaustive boundaries. Two-client tests are genuine clients, not single-player stubs.

Console inspection found the previously documented Roblox CorePackages
FoundationProvider warnings and asset 203785492 type mismatch, not a new economy
script error. These existing platform/asset warnings were not changed. The temporary
gallery and injected test scripts are Play-only and are discarded on Stop.
Final Edit-mode audit after Stop: all 108 mapped scripts still match, no Phase5A
temporary fixture remains, UnitTestRunner is disabled, and the saved world retains
its original 1,412 BaseParts. No place save/publication or unrelated asset rebuild.

### Verification limits

- Production DataStore calls and published cloud rejoin: **NOT TESTED**, intentionally
  excluded. Existing SessionStore tests cover failure/conflict guards; real Studio
  DataService release/load covers economy and pet restoration in the memory backend.
- All ten model silhouettes rendered in a native preview. Integration verified every
  tier's enabled prompts, stable station, upgrade and active training ticks; ten separate
  human ProximityPrompt walks are **NOT TESTED**. Native UI Start/Buy/Feed were clicked.
- Mobile/small-screen layout and long-running production performance: **NOT TESTED**.
- Late-game pricing: **PROVISIONAL**, needs approval; no final pacing claim.
- Original global blank-render trigger: **UNRESOLVED**, no longer reproduces after
  Stop/Edit/fresh Play. Confirmed buried-pad defect: **FIXED** and visually verified.

## Files and Phase 5B handoff

Created production: `src/shared/EconomyConfig.luau`, `EconomyCalculator.luau`,
`src/server/TrainerVisualService.luau`.

Modified production: TrainerDefinitions, PlayerData, DefinitionValidation (localized),
MonsterService, TrainingService, UIController. No DataService/SessionStore, guardian,
carry, resource catalog, pet progression or movement changes by this phase.

Created tests: `tests/unit/Cases/Economy_Test.luau`, `tests/Phase5AIntegration.server.luau`,
`Phase5ALoop.server.luau`, `Phase5APresentation.client.luau`, `Phase5AMultiplayer.server.luau`.
Updated DefinitionValidation_Test and Phase1Integration for the explicitly changed
price and timed-training contracts; other assertions remain. No repository files deleted.
Identical extra Rojo-created copies of the three new production modules and Economy_Test
were removed only after exact source comparison; canonical files/instances remain.

APIs/state:
- `TrainingService.train(player, base, station)`, `stop(player)`,
  `upgrade(player, base, station, targetTier)` and guarded `request(player, action, target)`.
- `EconomyCalculator.income`, `training`, `purchase`, `add`, `advance`, `validate`: pure.
- `MonsterService.getMultipliers`: existing separate authoritative income/training channels.
- Saved Cash, Power, TrainerTier; legacy TrainingLevel unchanged.
- Replicated IncomePerSecond, TrainingGainPerSecond (potential while training),
  ActivePetTrainingMultiplier, TrainingActive, TrainerTier; existing Cash/Power/StatusMessage.
- `TrainingInteraction`: Start / Stop / Upgrade, with next-tier integer for Upgrade;
  server-to-client Shop. No reward quantities, timestamps or client boost values accepted.
- CarryService remains the sole movement authority. Phase 5B must integrate there,
  not write competing WalkSpeed loops. Guardian speed rules are unchanged.

**Stop after Phase 5A.** No Phase 5B implementation is included.
