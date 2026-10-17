# Writable isolated Studio sessions

Date: 2026-10-16 (verification began October 15). Scope: session-backend fix only; no resource, economy, pet or evolution rules changed.

## Root cause

`FeedService.validate` rejects `not DataService.isWritable(player)` with
`Player data is not writable; item kept`, before touching ownership or rewards.
`BaseService.setupPlayer` correctly calls `DataService.load` before pet/base setup.
The failure was not a missing base or bad default PlayerData: DataService explicitly
constructed SessionStore with `{readOnly=RunService:IsStudio()}`. Even a successful
empty Studio load therefore produced `Status=StudioReadOnly, CanSave=false`.
The actual running player had `DataStatus=StudioReadOnly` before the fix.

## Fix and production protection

- `SessionStore.memoryAdapter()` creates a private per-adapter table and returns
  copying `get`/`update` functions. It uses no services, files or network. Cancelled
  transforms do not overwrite memory. The existing load/save/release/conflict
  engine remains the only session system.
- DataService selects that adapter **only when IsStudio() is true**. New sessions
  follow the existing legitimate `Missing`/`Loaded` writable states. Autosave and
  release save to memory only. A fresh Play server creates a fresh adapter.
- Studio cannot open the production store: `getStore()` now asserts `not studio`;
  the production update guard remains too. The production adapter is not selected
  in Studio, even with API access enabled.
- Published servers still use `MonsterProgress_v1`, keys `u_<UserId>`, GetAsync and
  UpdateAsync with the same optimistic conflict checks, retries, metadata and
  failure behavior. Failed/invalid loads and conflicts remain non-writable.
- `isWritable` was **not relaxed**. Its valid player/session/closing/CanSave/state
  checks remain unchanged. FeedService and all gameplay services are unchanged.
- The startup log explicitly identifies `StudioMemory`, writable temporary data,
  no production requests and reset-on-stop. `DataBackend=StudioMemory` is exposed
  as a player attribute and in status snapshots; this is a label, not permission.

## Verification

- Unit suite: **279/279 passed** (the current merged Phase 3B/4C baseline plus two
  memory-adapter tests). Covers independent keys, defensive copies, release/load,
  fresh-backend reset, conflicts, failed/malformed production-style loads, write
  retry, concurrent load/save, purchase/metadata preservation and all Phase 1–4
  pure contracts. Roblox's unit-test skill was used with the existing harness.
- `StudioMemoryFeeding`: **55 checks passed** using the **normal DataService and
  normal writable session**, with no status override or injected session. The
  fixture seeds runtime Raw Meat records only for repeatability. An actual MCP
  click on the native FEED button succeeded; ten feeds consumed ten original
  GUIDs once, each added exactly 5 Growth and 5 Flesh (no Floral/Mineral), and the
  same owned pet evolved into Fangling. Memory save succeeded and world invariants
  remained valid.
- Actual Stop → Play verified the previous 50 TotalGrowth/Fangling result reset
  to `ProtoRex`, `Growth=0`, `TotalGrowth=0`, `Status=Missing`, `Backend=StudioMemory`.
- Phase4AIntegration: **33/33 passed**, including the actual synchronized reset;
  paired Phase4APresentation: **7/7 passed**.
- Phase1Integration: **32/32 passed**; Phase4ACompatibility: **13/13 passed**.
- Phase4CIntegration: **89/89 passed**, covering catalyst/mutation transactions.
- Phase3Integration: **124/124 passed** (single player, current merged chase/debuff
  baseline); FieldRuntimeSmoke: **14/14 passed**.
- Phase4BIntegration: **34/34 passed**, paired Phase4BPresentation: **6/6 passed**;
  actual native Mossback selection accepted, forged/replayed choices rejected.
- Studio console inspected: no new gameplay-breaking errors. The message
  `Feed committed; pet presentation needs refresh` was intentionally induced by
  Phase4AIntegration's presentation-failure fixture; its publisher was restored.
  Studio was returned to Edit mode after verification, removing runtime fixtures.
- Rojo build and git diff --check passed.

Production-store isolation is established by the selected adapter containing no
DataStore operations, the defensive production-opening assertion, inspected
startup logs and successful actual Studio load/save/release. No live production
record was queried as a test. Published-server failure behavior is tested with
injected adapters, not by provoking failures against live saves.

## Changed files

Production: `src/server/DataService.luau`, `src/server/SessionStore.luau` only.
Tests: `tests/unit/Cases/SessionStore_Test.luau`, `tests/Phase1Integration.server.luau`,
`tests/Phase4AIntegration.server.luau`, new `tests/StudioMemoryFeeding.server.luau`.
Docs: this report and `docs/CURRENT_STATE.md`.

The two older integration assertions expecting ordinary Studio to be read-only
now assert the requested writable-memory behavior. Phase1 still explicitly tests
a failed-load/read-only feed rejection; all failure-state tests remain intact.
No branches or worktrees were reset; the already-merged Phase 3B code is preserved.

## Limitations

Studio progress intentionally does not persist between Play sessions. Rejoining
the same running test server can reload its memory record. Memory saves are not
evidence of cloud durability; production cloud saves were deliberately not tested.
The existing two-client multiplayer fixture was not rerun for this backend fix;
single-player integration results do not constitute multiplayer verification.
Existing progression gates still apply: carry a resource to your assigned base's
feeding point and resolve pending evolution choices when required.
