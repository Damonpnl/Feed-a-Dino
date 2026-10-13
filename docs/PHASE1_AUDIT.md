# Phase 1 architecture audit

Baseline: repository commit `eb552c4`; open place 104154372052853. The user replaced FEED_A_PET_CONTEXT.md with FEED_A_PET_MASTER_CONTEXT.md before this task; preserve that change. Gameplay mechanics follow RESOURCE_SPECIFICATION.md where wording differs. This report records actual inspection, not implied implementation from design documents.

## Findings before changes

- All 40 resources and five pools already exist. Existing field cycle, carry, hazards, feed, training and billboard systems are reusable and must be preserved without new Phase 2 features.
- DataService correctly distinguishes successful nil loads from errors, but two startup paths call load concurrently, saves use SetAsync without serialization/conflict detection, and normalization drops unknown save fields. Studio API warnings describe failed requests, never empty cloud saves.
- Feeding/upgrades lack explicit server distance and request-frequency guards. Training has a cooldown but no explicit distance check. Carry drop is an unrestricted request; ownership is tracked but service dependencies form a lazy Spawn/Carry/Guardian cycle.
- Studio contains eleven exact duplicate scripts/modules: FieldState, ResourceDefinitions, FieldConfig, ResourceModelDefinitions, FieldRoller, SpecialEffectDefinitions, ResourceEffects, ResourceValidation, ResourceVisualService, FieldPresentation and FieldController. Duplicate FieldController can attach overlapping presentation lifecycles.
- Studio-only PlayerDataService has no DataStore calls: it adds a second leaderstats folder with Meat. FlyScript gives every player flight. SprintController writes WalkSpeed every rendered frame, overriding server carry slowdown. CarryAnimationHandler watches an attribute no active server publishes.
- No active receipt/gamepass/entitlement system or identifiers were found in repository code. No saved remotes exist; the active runtime contracts are DropCarried (client → server) and FieldRareSpawn (server → clients).
- The unused ServerStorage.ExpeditionTemplates.SoilBag.qPerfectionWeld script disguises dynamic MarketplaceService.GetProductInfo/PromptPurchase calls as welding. Its AutomaticModel attributes include asset ID 123823600358195. It is not a game receipt processor. Preserve its model/identifier and backup source; quarantine the script rather than execute it or invent a purchase migration.
- Workspace has 1,412 BaseParts; sorted path/CFrame/Size/Anchored/CanCollide digest is 1212267917 (DJB2 modulo 2^32, seed 5381, pipe-separated fields and no separator between sorted rows). Four bases, six zone blockouts and 25 launch nodes are present. No Workspace geometry changes are needed. `tools/VerifyPhase1Snapshot.luau` reproduces this read-only comparison.

## Dependency-aware classification

Paths below are repository-relative unless they start with a Studio service name. Direct consumers and migration decisions are explicit.

| Path/component | Responsibility | Class | Consumers / migration |
|---|---|---|---|
| src/server/DataService.luau | Save lifecycle, published stats | REFACTOR | Base, Bootstrap, Carry, Feed, Training, Monster, Guardian; single-flight loading, serialized conflict-safe saves, Studio isolation |
| src/shared/PlayerData.luau | Save defaults/normalization | REFACTOR | DataService, MonsterService, tests; preserve unknown fields and owned progress |
| src/server/GameBootstrap.server.luau | Service startup | REFACTOR | Sole runtime entry; remove second load owner and run definition validation |
| src/server/BaseService.luau | Base claim/spawn/player setup | REFACTOR | Bootstrap; owns initialization after DataService.load; cleanup connections |
| src/server/SpawnService.luau | Field lifecycle and world objects | REFACTOR | Bootstrap, existing tests; move authoritative record access to ResourceService and keep compatibility APIs |
| src/server/CarryService.luau | Carry visuals/state/drop | REFACTOR | Spawn, Feed, Guardian; use ResourceService, validate requests and clean character connections |
| src/server/FeedService.luau | Feed/evolution transaction | REFACTOR | Bootstrap, base prompts; retain name, validate owner/distance/frequency and stage effects before consuming |
| src/server/TrainingService.luau | Power and Cash upgrade transactions | REFACTOR | Bootstrap, base prompts; use centralized existing prototype values and guarded transactions |
| src/server/MonsterService.luau | Owned pet/progression/income | REFACTOR | Base, Feed, Training, Bootstrap; preserve existing target pet on evolution collision |
| src/server/GuardianService.luau | Noncombat hazard state | REFACTOR | Spawn, Bootstrap; replace reverse Spawn dependency; preserve prototype hazard behavior |
| src/server/ResourceVisualService.luau | Swappable resource model/VFX | KEEP | Spawn, Carry; no visual changes |
| src/server/BillboardMetadataService.luau | Server label attributes/tag | KEEP | Spawn, Carry, Guardian, Monster |
| src/server/ZoneGeometry.luau | Existing blockout markers/surfaces | KEEP | Spawn setup/Guardian; no saved geometry edits |
| src/server/MonsterLoopTest.server.luau | Always-running smoke test | REFACTOR | No game consumer; relocate outside production mapping as opt-in test |
| src/shared/ResourceDefinitions.luau | Single 40-resource + reserved-content table | KEEP | Feed/Catalyst views, areas, roller, effects, visuals; retain exact values |
| src/shared/FeedDefinitions.luau | Filtered feed view | KEEP | ResourceCatalog; same definition objects, no copied values |
| src/shared/CatalystDefinitions.luau | Filtered catalyst view | KEEP | ResourceCatalog; same definition objects |
| src/shared/ResourceCatalog.luau | Compatibility lookup | KEEP | Carry/Feed; retain interface |
| src/shared/ResourceTypes.luau | Resource schema | KEEP | Definition/view type imports |
| src/shared/RarityDefinitions.luau | Ten-tier identity/order | KEEP | Roller, validation, styles, presentation |
| src/shared/AreaDefinitions.luau | Five explicit weighted pools | KEEP | FieldState, Spawn, Guardian, validation |
| src/shared/MonsterDefinitions.luau | Existing stable pet IDs/tree | REFACTOR | Monster, Feed, evolution calculator; expose all definitions for cross-reference validation, retain aliases |
| src/shared/EvolutionCalculator.luau | Pure eligibility | KEEP | Feed and tests; preserve existing branch order |
| src/shared/FieldState.luau | Pure GUID/node lifecycle | KEEP | ResourceService; preserve verified cycle/cap semantics |
| src/shared/FieldRoller.luau | Explicit weighted selection | KEEP | FieldState/validation; no probability change |
| src/shared/FieldConfig.luau | Existing cycle/presentation configuration | KEEP | FieldState, visuals, client presentation |
| src/shared/ResourceValidation.luau | Resource/world checks | REFACTOR | Startup/tests; harden malformed-input validation |
| src/shared/ResourceEffects.luau | Pure growth/family application | KEEP | Feed; apply to staged copy |
| src/shared/SpecialEffectDefinitions.luau | Family/mutation hooks | KEEP | Effects, validation, billboard values |
| src/shared/ResourceModelDefinitions.luau | Explicit model placeholders | KEEP | Visuals/world validation |
| src/shared/BillboardConfig.luau | Existing UI sizing/budgets | KEEP | Renderer/metadata; add schema coverage through central validator |
| src/shared/BillboardData.luau | Metadata/options adapter | KEEP | Renderer/server metadata |
| src/shared/RarityStyles.luau | Presentation palette | KEEP | BillboardData; identity remains RarityDefinitions |
| src/shared/ModifierStyles.luau | Optional badge styles | KEEP | BillboardData |
| src/shared/TestModule.luau | Rojo hello-world probe | DELETE | No repository/Studio consumers or persistence references |
| src/client/BillboardController.client.luau | Starts world label renderer | KEEP | Role equivalent to WorldBillboardController; avoid rename-only churn |
| src/client/BillboardService.luau, BillboardView.luau | Label lifecycle/UI | KEEP | BillboardController; deduplicate Studio copies, no polish |
| src/client/CarryController.client.luau | G-to-drop input | KEEP | DropCarried; no client reward logic |
| src/client/EffectsController.client.luau | Existing hazard shake | KEEP | HazardTick attribute; no new effects |
| src/client/UIController.client.luau | Attribute-backed HUD | KEEP | Data/Monster/Carry server attributes |
| src/client/FieldController.client.luau, FieldPresentation.luau | Existing announcements/night | KEEP | FieldRareSpawn, WorldFieldState; remove duplicate Studio copies |
| tests/** | Opt-in unit/integration regression coverage | KEEP | Disabled UnitTestRunner / explicit Play injection only |
| tools/SetupResourceNodes.luau | Idempotent edit setup | KEEP | Manual use; do not run or move existing markers in this phase |
| default.project.json | Rojo roots/test mapping | KEEP | Existing mapping suffices; moving smoke test outside src/server removes its production startup |
| ServerScriptService.PlayerDataService | Duplicate Meat leaderstats | DELETE | No save calls, remotes, or active consumers; DataService owns stats |
| StarterPlayer.StarterPlayerScripts.FlyScript | Unrestricted debug flight | DELETE | Self-contained input/render loop; no save/entitlement dependencies |
| StarterPlayer.StarterPlayerScripts.SprintController | Client speed/stamina override | DELETE | Conflicts with finalized carry speed; no persisted or paid state |
| StarterPlayer.StarterCharacterScripts.CarryAnimationHandler | Obsolete attribute animation | DELETE | CarryingItem has no producer; animation feature deferred |
| ServerStorage.ExpeditionTemplates.SoilBag.qPerfectionWeld | Dynamic external purchase prompt | REFACTOR | Quarantine disabled; no current template consumers; original source archived |
| Workspace.Bases, ExpeditionZones, area, Ground, Terrain | Existing environment/blockout | KEEP | Base/ZoneGeometry/ResourceValidation; verify unchanged digest |
| Workspace.Shops.RobuxShop, SellStation | Static shop/NPC blockout | KEEP | No active purchase/sell consumers; retain art, document inert prompts |
| ServerStorage.MaterialTemplates, CreatureTemplates, EnvironmentTemplates, ExpeditionTemplates, ItemTemplates | Reusable art/templates | KEEP | No current legacy code consumers; preserve assets and identifiers |
| StarterPack.PDA, StarterGui.ScreenGui, Workspace.GeneratedExpedition | Legacy shell content | KEEP | Inert/unused; retain scene assets, no live systems depend on them |

## Unresolved design decisions (do not silently rebalance)

New Phase 1 modules: `SessionStore` owns injected save lifecycle/conflict handling; `ResourceService` owns server resource records/transactions; `InteractionGuard` owns shared request preconditions; `TrainerDefinitions` stores the locked ladder and explicitly retained legacy training configuration; `DefinitionValidation` validates cross-concept references without adding cycles. Their direct dependency graph is saved in `audit/phase1-dependencies.json`.

During live sync, five more identical duplicates appeared (TrainerDefinitions, DefinitionValidation, SessionStore, InteractionGuard, ResourceService). Sixteen redundant copies in total were removed. The final source comparison, unique-name check and unchanged-map fingerprint are reported in `PHASE1_RESULTS.md`; Rojo does not own the retained blockout geometry.

- Trainer multipliers are specified; prices, starting ownership and migration from TrainingLevel are not. Represent the ladder but leave purchases unavailable until specified. Preserve existing prototype costs/gains as explicitly labeled legacy configuration.
- Exact passive Cash rates and starter tree remain prototype values. No economy/pet-ID migration in Phase 1.
- Resource spec explicitly retains equal hybrid affinity split, 5% Mutant Leech roll, and carried Divine reservation; master context is less specific. Preserve finalized behavior and flag these prior assumptions for product confirmation before balancing.
- Master guardian disturbance/telegraph design differs from current prototype. Actual new encounters are a later phase; record the gap and preserve existing behavior during architecture work.
- Duplicate-species evolution has no approved merge/inventory rule. Reject an evolution that would overwrite an already owned target pet; preserve both existing records.
- No legitimate active purchase pipeline exists to exercise. No new monetization implementation or live purchase is authorized by this phase; preserve identifiers and unknown save data.

Studio-only source backups: `docs/audit/studio-before-phase1.json`. Git is the rollback source for repository edits. Acceptance evidence and final architecture will be recorded in `PHASE1_RESULTS.md`.
