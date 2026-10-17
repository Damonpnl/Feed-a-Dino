# Phase 4D — pet rarity, Ascension and Awakening framework

Date: 2026-10-16. Phase 4D only. No Phase 5 economy/trainer work, live prestige
release, production DataStore access, place publication or final art.

## Inspection and baseline

Read the master context, finalized resource specification, lineage/current-state
documents, 4A–4C reports and relevant Phase 4 specification sections. Inspected
MonsterDefinitions, EvolutionCalculator, PlayerData, feeding/choice transactions,
rarity definitions, mutations/catalysts, retry-stable FeedRolls and multiplier
consumers. The current tree includes the approved Phase 3B merge and the separate,
uncommitted Studio-memory feeding fix; both are preserved.

Official Studio MCP identified Feed a Dino place 104154372052853. Before Phase 4D
gameplay edits, the existing suite passed **279/279** in Play. The disabled unit
runner and existing shared/server hierarchy were inspected. Roblox's unit-test
skill guided contract tests using the existing repository harness.

## Rarity

`RarityDefinitions` remains the only ten-tier ordering. `PetProgressionConfig`
references its highest tier (Divine) as the pet ceiling; no separate lower ceiling
existed in the inspected code. Individual promotion rules can set a lower ceiling.
Neither ceiling can demote a legitimate saved pet already above it.

`PetRarity.resolve` is pure and supports keep, one-tier, and explicitly authorized
multi-tier promotion, minimum source stage/rarity, family eligibility, explicit
chance, and injected server RNG. Invalid tiers/chances/ceilings reject. Every live
graph edge uses **Keep**. PromoteOne is disabled with no assumed probability.
All enabled promotion chances in tests are fixture-only, restored on completion.

EvolutionCalculator resolves the result within its existing staged one-stage
transition and stores RarityBefore/RarityAfter/RarityRule in EvolutionHistory.
Target-form display metadata and resource rarity never assign the pet's rarity.
FeedService retains its original GUID consume/commit path. A separate domain of
the existing FeedRolls cache supplies retry-stable rarity tickets, so mutation
draw counts cannot shift rarity tickets. Preview does not draw server RNG.
MonsterService uses a bounded per-player pending-choice ticket cache; forged
tokens cannot evict an authoritative choice's ticket. Successful choices clear
the cache, replay fails existing token/stage/revision checks, and disconnect
cleans it up. No client-supplied rarity or probability is accepted.

Guarantees remain server-memory exact-once, not cross-server durable atomicity.
Committed rarity/history survive normal saves; world GUID/ticket caches do not
survive server crashes. Existing autosave/crash limitations are unchanged.

## Ascension and Awakening

`PrestigeCalculator` evaluates declarative definitions. Required predicates cover
source form/stage, lineage, Growth including reserve, rarity, affinity mastery,
family unlocks, latent traits, prior lineage tags, qualification flags and optional
compatible catalyst IDs. Unknown or malformed persisted prestige state is kept
but fails closed rather than being reset into an obtainable transformation.

States:

- **Locked:** incomplete requirements, wrong source, or unapproved definition.
- **Eligible:** all configured requirements met, but release/success authorization
  is disabled. It does not grant or consume anything.
- **Ready:** all requirements met and explicitly enabled; Awakening additionally
  requires an explicit Guaranteed rule. No invented failure probabilities.
- **Completed:** matching persisted completion identity (and Stage 5/form for
  Ascension). A stage number alone is not proof of completed Ascension.

The AscendedRex → MythicRex edge references ProtoRexMythic. It remains Locked,
and its prestige definition is Enabled=false, RequirementsApproved=false. The
existing 3000 stage storage cap is **not** an approved prestige threshold. No
live Growth, mastery, minimum rarity, qualifying catalyst or special qualification
values were invented. Large Growth and launch catalyst flags cannot bypass this.

ProtoRexAwakening is a disabled definition with a separate
AwakenedRexPlaceholder presentation reference, not a seventh Growth stage or a
new owned pet. It has no compatible catalyst IDs, no approved requirements, and
Guaranteed=false. No launch catalyst grants Awakening. `planAwakening` is a pure
staged-copy handoff API, not wired to a live remote or resource-consumption path.
Future release must connect it to the existing authorized consume transaction
after approving the definition and catalyst policy, not call it on live data.

Additive saved fields: Ascension (state/accepted definition/revision), Awakened,
Awakening (identity/form/family/revision/presentation), and Qualifications. Existing
LatentTraits provide dormant eligibility storage; no new latent trait acquisition
odds/source were invented. Species, PetId, owned keys, form, stage, rarity,
mutations, Growth/reserve/history, Flora and opaque purchase fields are preserved.
Unknown historic prestige fields are not discarded. Store name, keys, session
engine and production failure/conflict protections are unchanged by Phase 4D.
Readiness is derived on demand; the saved Ascension record defaults to Locked
and is marked Completed only by an accepted graph transition. UI reads the
derived AscensionState, not a cached eligibility flag.

## Multipliers and presentation handoff

MonsterDefinitions now explicitly exposes IncomeMultiplier and TrainingMultiplier,
equal to each existing BaseMultiplier. `PetMultipliers.resolve` combines form,
the retained legacy-species floor, rarity, stage, unique mutations and Awakening
through separate Income/Training channels with configurable saturation bounds.
All new modifier maps are empty (neutral x1). Bounds 1 through 2^53−1 are technical
guards, not new approved economic balance. Unknown forms retain the old x1 fallback.

`MonsterService.getMultipliers(player)` returns the two authoritative values;
the existing getMultiplier API continues returning TrainingMultiplier. Current
training and Cash callers, prices, rates and trainer definitions are unchanged.
Phase 5 can adopt the separate income API when authorized. Publish now exposes
IncomeMultiplier, TrainingMultiplier, AscensionState, Awakened and Awakening
alongside existing independent Rarity/PetStage/MonsterId/Mutations attributes.
Final Awakening models/reveals and new prestige UI are intentionally absent.

## Verification

- Pre-change baseline: **279/279 passed** through Studio MCP.
- New Phase4DIntegration: **18/18 passed**, ordinary StudioMemory session, actual
  server services and seeded runtime GUID records. Divine feed independence,
  accepted rarity/history, failed consumption without partial reward, actual
  server RNG retry reuse, twenty concurrent confirmations committing once,
  unreleased prestige rejection, multiplier attributes, save and world invariants.
- Expanded unique unit suite: **318/318 passed** in fresh Studio Play after
  duplicate cleanup (279 prior contracts +39 Phase 4D cases). Covers deterministic
  promotion/ceiling boundaries, retry and persisted-result replay, every prestige
  predicate, a qualified fixture advancing through the existing Stage 4→5 graph,
  separate Awakening/save restoration, malformed state, and multiplier bounds.
- Phase4AIntegration **33/33**, paired client **7/7**, Phase4CIntegration **89/89**,
  Phase1Integration **32/32**, and Phase4ACompatibility **13/13** passed.

The first expanded run passed 345 executions, but synchronization had created an
identical duplicate of each new shared module and the test module. That number
includes the new cases twice and is **not** the unique-case count. Cleanup was
initially blocked by safety review; the user explicitly approved removing only
the five identical extra copies. All five were removed after checking identical
Source; canonical modules and repository files remain. The 318 count above is
the fresh nonduplicated run, not a mathematical adjustment of the old run.

The first serialized Phase3Integration attempt stopped at 14 checks with
`No available resource: Grasslands`: earlier feeding fixtures had consumed that
field's resources. This attempt is not counted as a pass; the regression was
restarted with a fresh Play field rather than altering gameplay spawn rules.

## Files

Created production: PetProgressionConfig, PetRarity, PrestigeCalculator,
PetMultipliers under src/shared.

Modified production: src/shared/MonsterDefinitions.luau, EvolutionCalculator.luau,
PlayerData.luau (type additions), DefinitionValidation.luau;
src/server/FeedService.luau and MonsterService.luau.

Created tests: tests/unit/Cases/PetPrestige_Test.luau and
tests/Phase4DIntegration.server.luau. Documentation: this report, CURRENT_STATE
and LINEAGE_SYSTEM. No repository files deleted. DataService/SessionStore and
their test edits in the working tree belong to the preceding Studio-memory fix,
not Phase 4D.

## Remaining approvals and limitations

Approve promotion eligibility/chances, prestige Growth/mastery/rarity and special
qualifications, catalyst consumption/success policy, final Awakening forms/assets,
and non-neutral multiplier values before enabling them. These are intentionally
disabled content, not silently chosen balance. Startup validation rejects live
prestige enabling in this phase; release must deliberately update that guard.

No production cloud persistence, actual multiplayer session, physical-device
QA, or final-art validation is claimed for this phase. Isolated memory save/reload
tests are not evidence of cloud durability. Phase 5 is not started.
