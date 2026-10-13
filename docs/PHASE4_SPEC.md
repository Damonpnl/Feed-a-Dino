# PHASE 4: COMPREHENSIVE PET GROWTH, FEEDING & BRANCHING EVOLUTION SYSTEM

## PROJECT: FEED A PET

You are implementing Phase 4 of Feed a Pet, the game's central pet growth and evolution system.

This phase is especially important because **pet evolution is intended to be one of the deepest and most expandable systems in the game**, despite the deliberately simple resource-stealing gameplay.

The objective is to preserve much of the evolutionary depth envisioned in the earlier Creature Conveyor / Steal a Dino designs, while integrating it into the simplified Feed a Pet gameplay loop.

The end result must support:

- Persistent individual pets
- Multiple growth stages
- Visible physical growth
- Feed-driven development
- Three primary biological affinities
- Dominant-affinity evolution
- Hybrid-affinity evolution
- Multi-stage branching lineages
- Evolutionary rarity progression
- Ordinary mutations
- Catalyst-specific transformations
- Unusual and rare evolution conditions
- Extremely rare Mythic ascension
- A separate endgame Awakening system
- Persistent evolutionary history
- Data-driven addition of new pets, lineages, and transformations
- Future event-exclusive evolution families

Build a comprehensive, reusable evolution engine rather than an assortment of hardcoded feeding scripts.

However, do not attempt to create hundreds of final monster models or fully balance all late-game progression in this phase.

The core engine should support the full long-term design. Implement a complete playable starter lineage and representative test cases for advanced mechanics.

---

# 0. REQUIRED INSPECTION AND PROJECT SAFETY

Before modifying the repository:

1. Read `FEED_A_PET_MASTER_CONTEXT.md`.
2. Read the finalized resource definitions and 40 launch resource entries.
3. Read the Phase 1, Phase 2, and Phase 3 completion reports.
4. Inspect the current repository.
5. Inspect the active Roblox Studio place through official Studio MCP.
6. Inspect the existing `MonsterService`, `FeedService`, `DataService`, `ResourceService`, `CarryService`, `MonsterDefinitions`, `FeedDefinitions`, `CatalystDefinitions`, and relevant client modules.
7. Inspect existing tests, player save records, and pet ownership semantics.
8. Identify existing evolution, mutation, catalyst, and affinity code before writing replacements.

Phase 3 already established a functional and tested resource lifecycle.

DO NOT recreate that architecture.

In particular:

- Preserve server-authoritative resource GUIDs.
- Preserve the one-major-resource carry limit.
- Preserve the existing resource state machine.
- Preserve the field reset and dropped-resource behavior.
- Preserve the five established guardian systems.
- Preserve the 40 authoritative resource definitions.
- Preserve the existing save namespace and compatible pet IDs.
- Preserve all existing player-owned pets.
- Do not migrate live saves without an explicit, tested migration plan.
- Do not rebuild Phase 5 training/economy.
- Do not start final AI-generated 3D or final UI production.

The existing game has already undergone substantial architecture cleanup.

Prefer extending the current services instead of replacing them.

Before implementation, produce a short audit indicating which Phase 4 mechanics are:

- Already implemented and validated
- Implemented but incomplete
- Missing
- Incompatible with the intended expanded evolution design

Then implement Phase 4 incrementally.

Do not run destructive Studio or DataStore operations.

---

# 1. CORE GAMEPLAY PHILOSOPHY

Keep the player interaction extremely simple:

RUN OUT
→ STEAL FEED OR CATALYST
→ ESCAPE
→ RETURN TO BASE
→ FEED PET
→ PET GROWS
→ PET EVOLVES
→ PET BECOMES MORE VALUABLE
→ UNLOCK BETTER RESOURCES
→ REPEAT

The player should not need to understand complicated biological systems to play.

A beginner should be able to:

1. Grab Raw Meat.
2. Bring it home.
3. Feed their pet.
4. Watch its Growth increase.
5. Eventually see the pet transform.

Advanced players should gradually discover that feeding decisions influence the lineage, rarity, appearance, and transformations their pet develops.

Design for two layers of complexity.

**Surface layer:**

Simple, visible, satisfying feeding and evolution.

**Deep layer:**

Affinity specialization, hybridization, catalyst compatibility, rarity progression, rare mutations, ascension, Awakening, and long-term lineage optimization.

Do not add unnecessary gameplay steps between stealing a resource and feeding a pet.

---

# 2. DISTINGUISH THE DIMENSIONS OF PET PROGRESSION

A critical architectural requirement is that the following systems remain independent.

## A. Species

The recognizable biological foundation of a pet.

Examples:

Wolf, T-Rex, Gorilla, Crocodile, Bear, Spider, Dragon.

## B. Growth Stage

How far the individual pet has developed within its evolutionary progression.

Stages range from 0 through 5.

## C. Evolutionary Lineage

The actual evolutionary path taken.

For example:

Wolf
→ Dire Wolf
→ Blood Wolf
→ Bloodfang

Or:

Wolf
→ Stone Wolf
→ Crystal Wolf
→ Crystal Dire Wolf

## D. Rarity

The pet's independently tracked rarity tier.

Use the configured ten-tier rarity system where applicable:

Common
Uncommon
Rare
Epic
Legendary
Mythic
Cosmic
Secret
Eternal
Divine

Do not confuse the rarity of a feed item with the resulting rarity of a pet.

Do not treat Evolution Stage 5, which is associated with Mythic ascension in the earlier design, as automatically granting the Mythic rarity tier. These are separate concepts.

## E. Affinities

The accumulated biological directions created by feeding.

Flesh
Floral
Mineral

## F. Evolution Families

Special branch categories made available by rare catalysts or conditions.

Examples:

Fire
Crystal
Primal
Toxic
Draconic
Titan
Cyber
Spirit
Void

## G. Mutations

Additional traits or variants applied to a pet independently of ordinary evolution.

Examples:

Silver
Golden
Rainbow
Parasite
Blood Moon

## H. Awakening

A separate transformation beyond normal Stage 5 progression.

Awakening is NOT a normal growth stage.

It is an exceptionally rare endgame transformation system.

These dimensions may interact, but they must not be collapsed into one string or one rarity variable.

For example, a pet could conceptually have:

Species: Wolf
Stage: 4
EvolutionForm: Crystal Dire Wolf
Rarity: Legendary
DominantAffinity: Mineral
Mutation: Golden
EvolutionFamily: Crystal
Awakened: false

This information should remain individually queryable.

---

# 3. PERSISTENT PET DATA MODEL

Audit the current saved-pet structure before changing anything.

Extend it only where necessary.

The final design must conceptually support a structure similar to:

```lua
PetData = {
    PetId = "persistent-unique-id",

    Species = "Wolf",
    EvolutionForm = "Wolf",
    Stage = 0,

    Rarity = "Common",

    Growth = 0,
    TotalGrowth = 0,

    Affinities = {
        Flesh = 0,
        Floral = 0,
        Mineral = 0,
    },

    EvolutionFamilies = {},
    Mutations = {},

    CatalystHistory = {},
    EvolutionHistory = {},
    FeedHistory = {},

    LineageTags = {},
    LatentTraits = {},

    AscensionState = "Locked",
    Awakened = false,

    IncomeMultiplier = 1,
    TrainingMultiplier = 1,

    Revision = 0,
}
```

This is a conceptual schema, NOT an instruction to replace the existing save format with this exact table.

Preserve the current DataStore format and owned-pet identifiers.

The existing save system may store Floral as `Flora`.

Continue using the canonical persisted key established by the current project. Provide a compatibility mapping for gameplay/UI naming where necessary.

Do not create two divergent affinity values.

## Persistence principles

Every pet represents a persistent individual.

The system should retain:

- Original species
- Current form
- Growth stage
- Current growth
- Total accumulated growth
- Affinity totals
- Chosen evolution branches
- Catalyst unlocks
- Applicable mutations
- Evolution rarity
- Awakening status
- Permanent lineage traits
- Relevant evolution history

Use compact records rather than unbounded logs.

FeedHistory should preserve only what is necessary for later lineage calculations, such as cumulative amounts by affinity, notable feeds, and limited recent history.

It should not store every ordinary feed action forever.

Derived statistics should preferably be calculated from the authoritative saved attributes and definitions rather than redundantly persisted.

---

# 4. SIX-STAGE GROWTH SYSTEM

Implement support for six growth stages.

Use the following provisional stage labels:

| Stage | Identity | Function |
|---|---|---|
| 0 | Starter / Hatchling | Initial creature |
| 1 | Juvenile | First affinity specialization |
| 2 | Mature | Developed evolutionary lineage |
| 3 | Apex | Advanced branching / hybrid traits |
| 4 | Ascended | High-end specialized form |
| 5 | Mythic Ascension | Extremely rare prestige progression |

The exact player-facing names may be refined later. Preserve Stage IDs 0–5 internally.

Stage 5 must remain separate from Awakening.

## Stage advancement

Progress through stages should depend on configurable requirements such as:

- Growth
- Dominant affinity
- Secondary affinity
- Current evolution lineage
- Existing special traits
- Catalyst family eligibility
- Evolution rarity
- Stage-specific progression conditions

Stages should not automatically advance solely because a player's Growth value is extremely high.

Stage skips are not permitted unless an explicitly designed future mechanic allows them.

A Stage 0 pet receiving a high-level Volcano feed must not instantly become Stage 5.

## Growth requirements

Create a `GrowthStageDefinitions` or equivalent configuration.

For testing purposes, a progression might resemble:

Stage 0 → 1: 50 Growth
Stage 1 → 2: 200 Growth
Stage 2 → 3: 800 Growth
Stage 3 → 4: 3,000 Growth
Stage 4 → 5: advanced eligibility requirements

These values are illustrative test thresholds, not approved live balance numbers.

Use the current definitions where they already exist.

If no authoritative stage thresholds exist, isolate proposed values in one configuration, label them `PROVISIONAL_BALANCE`, and report them for approval.

## Growth overflow

Define explicit behavior when a resource provides more Growth than the current stage requires.

Recommended rules:

- Growth is credited exactly once.
- A single feed action can trigger at most one stage transition.
- Excess Growth can be tracked as bounded carryover, but may not automatically cause repeated stage transitions.
- Stage-gated traits and catalysts remain locked until the correct stage.
- Growth does not silently disappear because a threshold was reached.

Prevent numeric overflow and invalid negative Growth.

Test high-value late-game feeds on low-stage pets.

---

# 5. PHYSICAL GROWTH AND VISUAL DEVELOPMENT

Feeding should produce visible changes rather than only increasing a progress bar.

Each stage should be capable of changing:

- Apparent size
- Body proportions
- Silhouette
- Eyes or facial details
- Horns
- Claws
- Spikes
- Fur or skin material
- Crystal growths
- Vines
- Wings
- Aura
- Animation behavior
- Displayed pet name
- Idle animation
- Growth feedback

This should be driven by presentation definitions.

Do not require every evolution form to have its final Blender model during Phase 4.

Create a reusable `PetVisualController` or integrate the equivalent functionality into the existing presentation controller.

Support both:

1. Stage-specific model replacement.
2. Limited procedural transformations of a compatible base model.

Each form definition should reference its visual model or a placeholder.

Example:

```lua
Visual = {
    ModelKey = "Wolf_Stone",

    ScaleMultiplier = 1.25,

    MaterialVariant = "Mineral",

    AttachmentSet = {
        "CrystalSpikes",
    },

    AnimationSet = "HeavyQuadruped",

    EvolutionEffect = "CrystalBurst",
}
```

Do not force literal part-level morphing on incompatible or imported skinned meshes.

Where an asset does not support a procedural change, safely replace the model using a compatible placeholder.

The pet should remain properly positioned in its enclosure through transformation.

Use smooth growth/evolution feedback where possible.

---

# 6. PRIMARY AFFINITY SYSTEM

Preserve the original three-affinity system.

## Flesh

Associated with:

Muscle
Predation
Strength
Horns
Teeth
Claws
Regeneration
Aggressive morphology

Example outcomes:

Dire Wolf
Blood Wolf
Predator Rex
Titan Gorilla

## Floral

Associated with:

Plants
Fungus
Vines
Spores
Toxins
Parasites
Regeneration
Biological symbiosis

Example outcomes:

Thorn Wolf
Moss Crocodile
Spore Gorilla
Venom Spider

## Mineral

Associated with:

Armor
Bone
Stone
Crystal
Metal-like growth
Geological adaptation

Example outcomes:

Stone Wolf
Crystal Rex
Armored Gorilla
Crystal Triceratops

## Neutral

Neutral resources grant Growth or special effects without necessarily increasing the three main affinities.

Neutral is not a fourth ordinary affinity that competes for dominant status.

---

# 7. HOW FEEDING CHANGES AFFINITY

Use the authoritative 40-resource launch specification.

Do not invent different resource values.

Single-affinity resources should increase their configured affinity.

For example:

Ancient Bone:
Growth +18
Mineral +18

Raw Meat:
Growth +5
Flesh +5

Hybrid-affinity resources divide the configured affinity contribution between their listed affinities.

Example:

Fossil Marrow:
Growth +300
Flesh +150
Mineral +150

Maintain the established compatibility rule that hybrid resources split the Growth contribution evenly between their configured affinities.

For odd integers, use a deterministic rounding strategy that preserves the total rather than randomly losing or creating points.

The client preview must display the actual calculation.

Use a pure effect-calculation function shared by preview logic and authoritative consumption, with the server independently evaluating it.

Do not maintain separate hardcoded calculations for preview and feeding.

## Dominant affinity

Determine the pet's dominant affinity from accumulated totals.

The dominant affinity can influence early evolutionary branches.

Example:

Wolf with mostly Flesh
→ Dire Wolf

Wolf with mostly Mineral
→ Stone Wolf

Wolf with mostly Floral
→ Thorn Wolf

This must be configuration-driven.

Do not hardcode `if Flesh > Mineral` chains separately for each species.

Tie handling must be deterministic or use an explicit player choice.

---

# 8. HYBRID AFFINITY EVOLUTION

This is a major long-term feature.

Pets should be able to develop hybrid lineages when multiple affinities reach the relevant requirements.

Supported primary combinations:

## Flesh + Mineral

Biological direction:
Armored predators, bone armor, crystal claws, reinforced monsters.

Examples:

Armored Rex
Crystal Dire Wolf
Stone Gorilla

## Flesh + Floral

Biological direction:
Parasites, venomous predators, fungal carnivores, organic mutation.

Examples:

Venom Wolf
Spore Crocodile
Parasite Gorilla

## Floral + Mineral

Biological direction:
Living crystal plants, bark armor, mineral symbiosis.

Examples:

Crystal Thorn Wolf
Crystal Mossback
Geode Plant Beast

## Flesh + Floral + Mineral

Reserve support for extremely rare advanced hybrid lineages.

Do not automatically create a triple-hybrid form for every species.

Triple hybrids should require explicitly configured eligibility and appropriate evolutionary stages.

## Hybrid eligibility

Do not use the mere presence of two affinity values as sufficient proof.

A branch may require:

- Minimum Growth
- Minimum stage
- Minimum primary affinity
- Minimum secondary affinity
- Relative affinity balance
- Required evolution lineage
- Compatible catalyst
- Other configured conditions

Example:

```lua
Requirements = {
    MinStage = 2,

    Growth = 800,

    Affinities = {
        Flesh = 300,
        Mineral = 250,
    },

    RequiredFamily = "Armored",
}
```

All requirements must be validated declaratively.

---

# 9. MULTI-STAGE BRANCHING EVOLUTION

Create an explicit evolution graph.

Each form should know which forms it can evolve into.

The same recognizable base creature can eventually have several different evolutionary outcomes.

Example conceptual tree:

```text
                  WOLF
                    |
       +------------+------------+
       |            |            |
    DIRE WOLF    THORN WOLF   STONE WOLF
       |            |            |
    BLOOD WOLF   VENOM WOLF   CRYSTAL WOLF
       |            |            |
    BLOODFANG    SPORE WOLF   CRYSTAL DIRE WOLF
       |                         |
       +------- SPECIAL ---------+
                    |
              CATALYST FORMS
```

This demonstrates the architecture, not an instruction to create all these as launch-ready meshes.

The evolutionary family must remain recognizable.

Do not generate arbitrary creatures unrelated to the original species.

## Evolution graph requirements

Each evolution definition should support:

- Stable evolution ID
- Required current form
- Target form
- Source and target stages
- Minimum Growth
- Affinity conditions
- Catalyst conditions
- Mutation conditions where applicable
- Rarity requirements
- Special lineage requirements
- Priority or selection mode
- Optional probability rules
- Model reference
- Resulting multiplier metadata
- Evolution reveal metadata

Validate:

- All target IDs exist.
- No unintended cycles.
- No unintended stage skips.
- No unreachable required forms.
- No duplicate conflicting branch identifiers.
- All catalyst references are valid.
- All rarity references are valid.

Normal progression should preserve the same persistent pet identity.

An evolution does not create a new pet ownership record by default.

---

# 10. EVOLUTION SELECTION AND BRANCH CONFLICTS

A critical requirement is handling cases where several evolutions are simultaneously eligible.

Example:

A wolf has enough Flesh to become Dire Wolf, but also enough Mineral and the correct catalyst to become Crystal Wolf.

Do not arbitrarily select whichever branch happens to be first in an unordered table.

Use an explicit branch resolution policy.

Recommended hierarchy:

1. Explicitly selected eligible evolution.
2. Catalyst-specific branch when the catalyst was intentionally used.
3. Unique eligible normal branch.
4. Multiple eligible branches require a player choice.

If only one branch is eligible, the evolution may occur automatically.

If multiple branches are eligible, present an evolution-choice interface.

Example:

EVOLUTION AVAILABLE

DIRE WOLF
Flesh Evolution

CRYSTAL WOLF
Mineral Evolution

[CHOOSE]

Use a deterministic candidate ordering.

The server must validate the chosen result again when the player confirms.

## Pending evolution

Support a `PendingEvolution` state if necessary.

When a feed grants enough Growth but the player has multiple eligible branches:

- Apply the validated feed effects once.
- Preserve the pet's pending evolution choice.
- Do not consume another resource for selecting the branch.
- Do not automatically reroll the branch.
- Do not lose Growth or catalyst state.
- Ensure pending evolution survives reconnecting.

Prevent the client from choosing branches for which the pet is not eligible.

---

# 11. RESOURCE FEEDING TRANSACTION

Feeding is always server-authoritative.

The exact sequence should be:

1. Player approaches their own active pet at their assigned base.
2. Player is carrying one authoritative feed/catalyst.
3. Server validates base ownership and character proximity.
4. Server validates player session and pet ownership.
5. Server confirms the resource GUID is currently carried by this player.
6. Server resolves the resource definition.
7. Server calculates the complete effect.
8. Server checks whether the pet can receive that effect.
9. Server resolves possible evolution outcomes.
10. Server commits the accepted resource consumption and pet mutation once.
11. Server updates the saved session state through the established DataService path.
12. Server emits a compact result for the client.
13. Client displays feed/growth/evolution feedback.

Important:

**Never consume an item on the client.**

Do not trust client-supplied:

- Growth amounts
- Affinity amounts
- Rarity
- Mutation chance
- Evolution targets
- Multipliers
- Catalyst effects
- Pet ownership

Use the existing `ResourceService`, `CarryService`, and `FeedService` transaction APIs.

Where possible, derive the final pet state on a temporary immutable copy, validate it, and commit the state transition under the existing authoritative session/resource guards.

Do not claim durable cross-server atomicity unless the persistence system actually provides it.

Never create a second inventory implementation.

## Failed feeding

If feeding cannot proceed:

- Preserve the resource where possible.
- Do not give Growth.
- Do not apply partial catalyst effects.
- Do not accidentally evolve a pet.
- Return an accurate error.
- Leave authoritative state consistent.

## Duplicate requests

Repeated requests for the same resource GUID must not apply its effects more than once.

Support idempotency through existing resource consumption/state tracking.

---

# 12. FEED PREVIEW SYSTEM

Create a functional feeding preview.

Example:

ANCIENT BONE

Epic

+18 Growth
+18 Mineral

Wolf Growth
32 / 50 → 50 / 50

EVOLUTION READY

[FEED]

The example must update dynamically from the current active pet and resource.

The UI should also support:

- Single-affinity feeds
- Hybrid-affinity feeds
- Neutral Growth
- Special effect feeds
- Catalyst unlocks
- Mutation chances
- Rare branch eligibility
- Full-Growth conditions
- Locked transformations

Examples:

FOSSIL MARROW

+300 Growth
+150 Flesh
+150 Mineral

Or:

CRYSTAL CATALYST

Unlocks Crystal Evolution

Compatible Evolution Available

Or:

MUTANT LEECH

+70 Growth

5% Mutation Chance

The exact special-effect numbers must come from authoritative definitions.

The client must not invent or independently roll mutation outcomes.

## Preview validity

If the active pet, resource ownership, or other relevant state changes between preview and confirmation, the server must recalculate.

A stale preview must never grant outdated rewards.

Use temporary functional UI. Final polished visuals belong to Phase 6.

---

# 13. CATALYST FRAMEWORK

Catalysts must be implemented as a generic, data-driven effect system.

Do not write one custom feeding script per catalyst.

Each catalyst definition should specify its intended effect type.

Supported effect categories:

- UnlockEvolutionFamily
- AddLineageTag
- AddLatentTrait
- EnableSpecialEvolution
- SetEvolutionEligibility
- AttemptMutation
- AttemptAscension
- AttemptAwakening
- ForceEligibleBranch, only where explicitly permitted

One catalyst may have multiple configured effects.

## Launch catalysts

Integrate the existing launch catalyst definitions and preserve their current Growth values:

**Primal Catalyst**
Grasslands
Growth +30
Primal family

**Toxic Catalyst**
Swamp
Growth +100
Toxic/Mutant family

**Jungle Heart**
Jungle
Growth +250
Beast/Alpha family

**Crystal Catalyst**
Crystal Cave
Growth +1,200
Crystal family

**Fire Core**
Volcano
Growth +3,200
Fire family

**Dragon Blood**
Volcano
Growth +4,500
Draconic family

**Inferno Catalyst**
Volcano
Growth +7,000
Highest Inferno-family eligibility check

Do not change their existing rarities or spawning rules.

## Catalyst compatibility

Not every catalyst must work on every pet.

Compatibility may depend on:

- Species
- Current evolutionary form
- Stage
- Affinity totals
- Existing family unlocks
- Rarity
- Previous catalysts
- Special conditions

Create data-driven compatibility checks.

If a catalyst cannot affect the pet:

- Display an accurate explanation.
- Do not consume the catalyst merely because the player pressed Feed.
- Do not promise an evolution outcome that is unavailable.

## Persistent catalyst influence

A catalyst can unlock a future transformation without immediately evolving the pet.

Example:

Wolf receives Crystal Catalyst at an early stage.

The pet gains a persistent Crystal eligibility tag.

The player must still reach the appropriate evolution stage and affinity thresholds to use that branch.

Future evolution logic reads the stored tag.

This is important because high-level catalysts should have long-term value without allowing arbitrary stage skipping.

---

# 14. EARLY SPECIAL FEEDS AND LATENT TRAITS

Preserve the earlier idea that unusual resources can influence a pet before the relevant evolution stage.

Example:

A low-stage pet receives an advanced special feed.

The pet may gain:

- Normal Growth
- Compatible affinity
- A persistent latent trait
- A future lineage eligibility flag
- A mutation opportunity
- A visible dormant mark

However:

**Early rare resources must not automatically bypass stage requirements.**

Use configured stage-gated effects.

Advanced affinity systems such as Arcane, Abyssal, and Synthetic may be represented by future evolution-family tags rather than adding three more primary affinity meters during launch.

Where early advanced feeds require reduced efficiency or instability, support the mechanic through configuration.

Do not invent permanent instability penalties without an approved balancing definition.

---

# 15. PET RARITY PROGRESSION

Pet rarity should be a separate axis of progression.

A pet can evolve into another form without increasing rarity.

Example:

Common Wolf
→ Common Dire Wolf

Alternatively, under eligible conditions:

Common Wolf
→ Uncommon Dire Wolf

The evolution itself should remain visually meaningful even when rarity does not improve.

## Rarity promotion

Support configured rarity outcomes such as:

- Same rarity
- +1 rarity tier
- Rarely +2 tiers, if explicitly enabled

Rarity must never decrease through ordinary evolution.

Any higher-tier promotion must be limited by explicit configuration and progression gates.

Do not assume every evolution is guaranteed to improve rarity.

Do not create an unlimited reroll exploit.

The engine should support deterministic test RNG injection and a real server-authoritative random source.

A single eligible evolution transaction must resolve its rarity outcome once.

Retries or UI reopening must not reroll it.

## Important distinction

The resource's rarity may influence eligibility or quality where specified.

A Divine resource does not automatically create a Divine pet.

Pet rarity progression must use its own definitions.

Do not copy Steal an Egg's resource spawn probabilities into pet evolution-rarity calculations.

Where rarity-roll probabilities remain undecided, implement the configurable mechanism and use documented test values only.

---

# 16. MUTATION SYSTEM

Mutations are distinct from:

- Species
- Stage
- Rarity
- Evolution form
- Affinity
- Awakening

## Ordinary mutations

Reserve the ordinary mutation families:

Silver
Golden
Rainbow

These may influence:

- Visual appearance
- Income multiplier
- Training multiplier
- Particle effects
- Collection value

Do not hardcode one rarity per mutation.

## Special mutations

Support the following future special families:

Titan
Void
Cyber
Spirit
Blood Moon
Celestial
Parasite
Fire
Crystal
Draconic
Toxic/Mutant
Primal

Some of these may function primarily as evolution families instead of cosmetic mutation overlays.

Avoid representing the same transformation simultaneously as three different incompatible state types.

Define which family effects are:

- A permanent evolution branch
- A mutation overlay
- A temporary event modifier
- An Awakening transformation

## Mutation stacking

Allow compatible mutations to coexist.

For example:

Golden + Void

But enforce configuration-based compatibility rules.

Do not assume every special mutation can stack with every other mutation.

Prevent duplicate stacking of the same mutation.

Separate visual stacking rules from gameplay multiplier rules.

Keep total visual effects bounded so high-tier pets remain readable.

## Mutant Leech

Integrate the existing special mutation roll if present.

The previously established Mutant Leech behavior uses a 5% mutation roll.

Preserve that authoritative value if confirmed in the current definitions.

Roll once per successful feed transaction.

Do not reroll through repeated remote calls.

Do not silently override an existing mutation.

---

# 17. MYTHIC ASCENSION: STAGE 4 → 5

The earlier evolution design included an exceptionally rare high-end progression step before Awakening.

Restore this concept in the architecture.

**Stage 5 should represent a difficult, prestigious achievement.**

It must not be reached simply by repeatedly feeding ordinary resources until a number reaches zero or a progress bar fills.

Stage 4 → 5 should support several simultaneous requirements.

Examples:

- Advanced Growth requirement
- Affinity mastery requirement
- High evolution rarity or quality requirement
- Specific lineage completion
- Rare Ascension material
- Special eligibility tag
- Additional stage-specific conditions

These should be declarative predicates.

Do not embed a universal hardcoded `if Stage == 4` block filled with species-specific logic.

## Ascension attempts

Support an explicit ascension eligibility check.

Potential states:

Locked
Eligible
Ready
Completed

If attempts can fail probabilistically in a later design, the probability and consumption policy must be defined explicitly before enabling that mechanic.

For now, avoid inventing destructive failure odds.

An unapproved probability system must not consume extremely rare catalysts.

## Dormant potential

Support the earlier concept of dormant Mythic potential.

A pet can acquire an unusual trait or hidden eligibility before becoming capable of ascending.

That trait should:

- Be persistent
- Have an identifiable source
- Potentially influence future eligibility
- Not immediately grant full Stage 5 power

A rare material can reveal future potential without completing the transformation.

## Scope

Implement the necessary stage/eligibility system and representative tests.

Do not unlock broadly obtainable Stage 5 pets with placeholder thresholds.

Mark unresolved endgame balance as requiring approval.

---

# 18. AWAKENING SYSTEM

Awakening is separate from normal evolution.

This was a major part of the original design.

Awakening should be rarer and more restrictive than Stage 5 ascension.

Conceptual flow:

Normal pet
→ Multiple evolutions
→ Ascended lineage
→ Stage 5 Mythic Ascension
→ Special compatible catalyst
→ Awakening eligibility
→ Awakened transformation

Awakening should support requirements such as:

- Stage 5 completion
- Specific evolution lineage
- Compatible awakening catalyst
- Required affinity mastery
- Special mutation or dormant trait
- Rare world/event achievement
- Hidden or advanced conditions

Do not make Awakening a generic button every Stage 5 pet can immediately press.

A catalyst should not guarantee Awakening unless that catalyst's authoritative definition explicitly says so.

## Awakened pet state

Support:

Awakened flag
AwakeningFamily
AwakeningForm
AwakeningHistory or compact equivalent
Awakening-specific appearance
Awakening-specific multipliers/effects

An awakened form must remain linked to its original persistent pet.

## Presentation

Awakening should eventually have a substantially more dramatic reveal than ordinary evolution.

Phase 4 only needs functional hooks and placeholders.

## Availability

Design and test Awakening with isolated fixtures.

Do not enable unfinished awakening branches or placeholder success probabilities in the live loot loop.

---

# 19. SPECIAL CATALYST FAMILIES FOR FUTURE UPDATES

The game is expected to expand through recognizable special transformations.

Prepare the framework for future content, without adding these resources to the current launch spawn tables.

## Giant Serum

Supports Titan-style mutation or evolution.

Expected visual differences:

Major scale changes
Large muscle/body mass
Altered proportions
Distinctive silhouette

## Spirit Energy

Supports aura and supernatural energy forms.

Expected visual differences:

Energy aura
Glowing markings
Spectral elements
Special animations

## Cyber Core

Supports mechanical transformations.

Expected visual differences:

Mechanical limbs
Metal plating
Artificial joints
Glowing technological components

## Void Essence

Supports void or dimensional forms.

Expected visual differences:

Dark/prismatic materials
Void particles
Distorted silhouettes
Unusual eyes or markings

## Blood Moon Shard

Supports time-limited Blood Moon evolutions.

Examples:

Werewolf-type forms
Vampiric forms
Blood variants

## Celestial Core

Supports divine/celestial transformation families.

These future items must be separate from existing normal feeds and launch catalysts.

Do not add them to launch spawn pools or grant them automatically.

The agent should implement extensible effect handlers and test fixtures so new families can be integrated later without rewriting the feeding service.

---

# 20. CREATURE LINEAGE CONTENT

Preserve recognizable creature archetypes.

The game's creature roster should eventually support:

Wolf
Bear
Gorilla
Crocodile
T-Rex
Triceratops
Spider
Snake
Mammoth
Shark
Dragon

Roughly 70–80% of base creatures should remain instantly recognizable.

## Phase 4 implementation target

First inspect existing stable prototype pet IDs and forms.

Do not overwrite or rename those IDs simply to match these examples.

At minimum, implement:

### A. One fully playable starter lineage

Prefer the existing ProtoRex family if it is already integrated into player saves.

Support the full Stage 0–5 graph model.

Implement enough real progression to demonstrate:

- Multiple ordinary evolution stages
- An affinity-based branch
- A hybrid branch
- A catalyst-gated branch
- Persistent evolution history

Do not make the Stage 5 prestige outcome freely obtainable.

### B. Three affinity branch demonstrations

Flesh lineage
Floral lineage
Mineral lineage

They may share reusable assets/placeholder geometry, but must be separate valid evolution definitions.

### C. At least two hybrid branch demonstrations

Flesh + Mineral
Flesh + Floral

Validate Floral + Mineral through a third configuration/test fixture.

### D. At least three catalyst-family demonstrations

One basic catalyst family
One advanced catalyst family
One future special-family test fixture

### E. Mythic/Awakening eligibility fixtures

Verify that the system can evaluate rare endgame requirements without enabling unapproved, easily farmed prestige outcomes.

## Expansion architecture

Adding a new creature family should primarily require:

- Species definition
- Evolution graph
- Form definitions
- Branch requirements
- Compatible catalyst definitions
- Model keys
- Multiplier definitions
- Presentation references

It should not require a new feeding controller or cloned server service.

---

# 21. PET OWNERSHIP AND MULTIPLE PETS

The primary base interaction should continue using **one active pet**.

Do not accidentally introduce a complex inventory-management minigame into feeding.

However, the architecture should support future ownership of multiple pets.

Requirements:

- Each owned pet has a stable identity.
- Exactly one active pet receives ordinary feeding interactions.
- Feeding never mutates another player's pet.
- Equipping another pet cannot duplicate Growth or catalyst effects.
- Evolution preserves individual pet identity.
- Duplicate creature forms are handled safely.

The earlier prototype has a limitation where evolution into an already-owned species can be rejected.

Audit this behavior.

Do not silently destroy or overwrite an existing pet if a new evolution would produce a duplicate form.

Preferred long-term architecture is instance-based ownership, where multiple individual pets can share the same species/form definition.

However, if the existing datastore uses species-keyed ownership, do not force an unsafe migration during Phase 4.

Implement an explicit safe compatibility policy and report the migration needed for full duplicate ownership.

Catalysts must not be consumed for an invalid or blocked evolution.

Normal feeding should not permanently soft-lock a pet because its intended result is already owned.

---

# 22. PET MULTIPLIERS AND PHASE 5 INTEGRATION

Pet growth should affect future player progression.

The existing secondary gameplay loop is:

BETTER PET
→ BETTER TRAINING MULTIPLIER
→ MORE POWER
→ HEAVIER RESOURCES
→ BETTER FEED
→ BETTER PET

Pets may also increase passive Cash generation.

Phase 4 should produce authoritative pet multiplier metadata.

Recommended inputs:

- Evolution form
- Stage
- Rarity
- Mutations
- Awakening status

Use pure deterministic calculations from definitions.

Example conceptual formula:

```lua
TrainingMultiplier =
    FormBaseMultiplier
    * RarityMultiplier
    * MutationMultiplier
    * AwakeningMultiplier
```

This is an example formula only.

Do not introduce unapproved multiplier values or unrestricted exponential stacking.

The actual numbers should remain configurable and require balancing.

## Phase boundaries

Phase 4 may:

- Define pet multiplier metadata.
- Calculate multipliers.
- Update client-visible multiplier values.
- Expose stable APIs to TrainingService.

Phase 4 must NOT:

- Invent trainer prices.
- Rewrite the trainer tier system.
- Modify player Power gains without a specified Phase 5 change.
- Implement unrelated Cash stores.
- Add new currencies.

Ensure future Phase 5 code can consume pet multipliers without knowing detailed evolution internals.

---

# 23. FUNCTIONAL FEEDING AND EVOLUTION UI

Build temporary but complete functional UI.

Do not begin the final Figma/AI design phase.

Required components:

## Feeding panel

Displays:

- Resource name
- Resource rarity treatment
- Current active pet
- Growth increase
- Affinity increase
- Special catalyst effects
- Potential evolution eligibility
- Confirmation button

## Pet growth panel

Displays:

- Pet name
- Current form
- Current stage
- Current rarity
- Growth progress
- Flesh
- Floral
- Mineral
- Dominant affinity
- Special family unlocks
- Mutation indicators

## Evolution choice

If multiple branches are eligible:

- Show available forms.
- Show relevant requirements and benefits.
- Mark unavailable branches clearly.
- Permit one authorized selection.

## Evolution reveal

When evolution occurs:

1. Temporarily emphasize the pet.
2. Darken or blur the background slightly where appropriate.
3. Show the previous form.
4. Play a transformation effect.
5. Reveal the resulting form.
6. Show stage/rarity changes.
7. Show multiplier changes.
8. Return control to the player.

Use clear hooks for final animations, models, particles, sounds, and camera movement.

## Mutation reveal

For rare mutation results, support a separate result indication.

Do not play a massive cinematic for every ordinary feed.

## Mobile

The temporary UI must still be functional on mobile-sized screens.

Use native Roblox GUI instances and responsive constraints.

---

# 24. PERFORMANCE AND SYSTEM ARCHITECTURE

Keep the architecture comprehensible.

Possible responsibilities:

`MonsterDefinitions`
Stable species/forms and existing metadata.

`EvolutionDefinitions`
Evolution graph and requirements.

`GrowthStageDefinitions`
Stage progression conditions.

`CatalystDefinitions`
Catalyst effects and compatibility.

`MutationDefinitions`
Mutation types and rules.

`EvolutionResolver`
Pure evaluation of candidate branches and eligibility.

`PetGrowthService`
Growth and affinity calculations, or integration into existing MonsterService.

`MonsterService`
Authoritative pet state, evolution and ownership.

`FeedService`
Authoritative resource feeding transaction.

`PetVisualController`
Client-side pet appearance and transition presentation.

`EvolutionUIController`
Client-side feeding/evolution UI, possibly consolidated into existing UIController.

These are responsibility boundaries, not mandatory additional files.

Do not create redundant manager layers if the existing project already has appropriate modules.

## Performance requirements

- No permanent per-pet `RenderStepped` loops for evolution calculations.
- No unbounded pet history logs.
- No constant checking of every possible evolution each frame.
- Evaluate evolution when relevant pet state changes.
- Cache static definitions and validate them at startup.
- Avoid duplicate remote connections.
- Clean up model/presentation listeners.
- Keep mutation effects scalable across multiple pet models.
- Avoid unnecessary full-player-data replication.

---

# 25. EXPLICIT EVOLUTION RESOLUTION CONTRACT

Create a testable server-authoritative evolution resolver.

Conceptual API:

```lua
EvolutionResolver.GetEligibleForms(
    petState,
    definitions,
    context
)
```

Returns deterministic candidate forms with eligibility/rejection reasons.

```lua
EvolutionResolver.PreviewFeed(
    petState,
    resourceDefinition,
    context
)
```

Returns calculated Growth, affinity, applicable effects and possible outcomes without mutating state.

```lua
EvolutionResolver.ResolveEvolution(
    petState,
    selectedEvolutionId,
    context,
    rng
)
```

Resolves one eligible transformation.

```lua
EvolutionResolver.CheckAscension(
    petState,
    context
)
```

Returns eligibility and missing requirements.

```lua
EvolutionResolver.CheckAwakening(
    petState,
    catalystDefinition,
    context
)
```

Returns eligibility and missing requirements.

These are conceptual signatures.

Integrate equivalent behavior into existing modules where appropriate.

## Invariants

- An invalid evolution cannot occur.
- No unauthorized stage skipping.
- No ordinary rarity downgrade.
- No catalyst bypass without explicit configuration.
- No re-rolling one evolution transaction through retries.
- No arbitrary mutation from untrusted client input.
- No loss of pet identity.
- No mutation of unrelated pets.
- No consumption of a resource twice.

---

# 26. DETERMINISTIC TESTING REQUIREMENTS

Create unit and integration tests.

Do not rely solely on manual Studio playtesting.

## Feeding tests

Verify:

1. Raw Meat grants correct Growth and Flesh.
2. Ancient Bone grants correct Growth and Mineral.
3. Fossil Marrow splits hybrid affinity correctly.
4. Neutral resources do not grant an unintended core affinity.
5. Catalyst effects match centralized definitions.
6. A resource is consumed once.
7. Duplicate feeding attempts do not apply effects twice.
8. Client-supplied Growth values are ignored.
9. Feeding at another player's base is rejected.
10. Feeding while the resource is not carried is rejected.
11. Feeding during player death/reset does not duplicate effects.
12. Invalid pet ownership prevents consumption.

## Growth tests

Verify:

1. Growth accumulates correctly.
2. Stage thresholds work.
3. Threshold boundaries are correct.
4. Growth overflow follows the configured policy.
5. High-value feed does not allow multiple automatic stage skips.
6. Invalid/negative/nonnumeric values are rejected.
7. Reconnecting restores Growth.

## Affinity tests

Verify:

1. Flesh dominance is calculated correctly.
2. Floral dominance is calculated correctly.
3. Mineral dominance is calculated correctly.
4. Hybrid conditions are evaluated correctly.
5. Ties are handled deterministically or explicitly selected.
6. `Flora` compatibility is preserved.
7. Catalyst-family tags remain separate from primary affinities.

## Evolution tests

Verify:

1. One eligible branch evolves correctly.
2. Multiple eligible branches produce a valid choice state.
3. Invalid target selection fails.
4. Catalyst-gated branches remain locked without the catalyst.
5. Evolution preserves pet ID.
6. Evolution history updates.
7. The pet cannot evolve past valid configured stages.
8. Evolution cannot accidentally overwrite an owned pet.
9. Repeated requests cannot duplicate an evolution.
10. Rarity promotion resolves only once.
11. Rarity never decreases through ordinary evolution.
12. Target forms are present in validated definitions.

## Mutation tests

Verify:

1. Mutation probability uses server RNG.
2. Repeated remote calls do not reroll.
3. Duplicate mutations do not stack unintentionally.
4. Special mutations obey compatibility.
5. Mutation overlays do not overwrite species or rarity.
6. Mutant Leech behavior matches its authoritative configured chance.

## Ascension/Awakening tests

Verify:

1. Stage 5 requires all configured prerequisites.
2. Stage 4 cannot skip its final eligibility conditions.
3. Awakening remains separate from stage count.
4. Missing catalyst blocks Awakening.
5. Wrong lineage blocks Awakening.
6. Correct compatible state returns eligibility.
7. Rare stage/awakening outcomes cannot be farmed using provisional test conditions.

## Persistence tests

Verify:

1. Growth persists.
2. Affinities persist.
3. Catalyst unlocks persist.
4. Evolution stage persists.
5. Evolution form persists.
6. Rarity persists.
7. Mutation state persists.
8. Pending evolution persists.
9. Ascension status persists.
10. Existing saved prototype pets remain compatible.
11. Failed DataStore loads do not permit destructive overwrites.
12. Session failure does not create duplicated pet ownership.
13. Deferred save and reconnect paths behave safely.

Use the existing test harness and injected stores.

Do not access live production saves during testing.

---

# 27. ROBLOX STUDIO MCP PLAYTEST

Use official Roblox Studio MCP to test the actual game.

At minimum, perform a complete Grasslands pet progression demonstration.

Required sequence:

1. Start with a fresh test account or isolated test fixture.
2. Spawn at the correct base.
3. Approach a Grasslands resource.
4. Pick it up with valid Power.
5. Trigger the existing guardian system.
6. Escape to base.
7. Open feeding UI.
8. Preview the feed effects.
9. Feed the active pet.
10. Verify physical resource removal.
11. Verify Growth increases.
12. Verify affinity increases.
13. Repeat until a normal evolution becomes available.
14. Evolve the pet.
15. Verify form/stage change.
16. Verify pet multipliers update.
17. Verify the visual placeholder changes appropriately.
18. Verify save/rejoin restores pet state.

Additionally execute controlled test fixtures for:

- Hybrid evolution
- Catalyst-gated evolution
- Mutation roll
- Rarity promotion
- Stage 5 eligibility
- Awakening eligibility

Do not claim an endgame transformation is fully playable simply because an isolated eligibility test passed.

## Multiplayer

Where practical, verify with two real Studio clients:

- Players cannot feed each other's pets.
- Both players can evolve independently.
- Feeding one player's pet does not change the other's.
- A contested world resource can only be consumed by one player.
- Pet updates replicate only where appropriate.

Do not leave Studio in a multi-client test configuration that launches unexpected extra windows during ordinary manual Play.

Stop/clean up test clients after testing.

---

# 28. IMPLEMENTATION ORDER INSIDE PHASE 4

Do not attempt every subsystem simultaneously.

Implement in these internal steps.

## 4A: Existing pet-state audit and compatibility

- Inspect existing owned-pet data.
- Normalize stage, rarity, affinity and mutation access.
- Create backward-compatible defaults.
- Validate persistence.
- No gameplay behavior changes yet.

## 4B: Feeding and effect calculation

- Build unified feed effect resolver.
- Connect to Phase 3 carry resource consumption.
- Implement feeding interaction.
- Implement Growth and affinities.
- Implement feeding preview.
- Test exact-once consumption.

## 4C: Growth stages and evolution graph

- Implement Stage 0–5 framework.
- Define branching eligibility.
- Implement at least one real starter lineage.
- Add normal and hybrid branches.
- Implement evolution-choice behavior.
- Test stage transitions.

## 4D: Catalyst and mutation systems

- Integrate all launch catalysts.
- Implement persistent special-family tags.
- Implement mutation framework.
- Add selected real catalyst branches.
- Add future family fixtures.
- Test early latent traits and stage gates.

## 4E: Rarity, ascension and Awakening framework

- Implement distinct pet-rarity progression mechanics.
- Preserve nondecreasing ordinary rarity.
- Implement rarity roll determinism.
- Implement Stage 5 eligibility.
- Implement separate Awakening eligibility.
- Keep unapproved endgame outcomes disabled.
- Validate representative high-end branches.

## 4F: Gameplay integration and verification

- Functional pet UI.
- Functional evolution reveal.
- Placeholder visual transformation.
- Real Studio gameplay test.
- Multiplayer validation.
- Save/rejoin validation.
- Full regression tests for Phase 1–3.

After each internal step, run relevant tests and inspect errors before continuing.

If context or usage limits are approaching, stop at a coherent checkpoint, commit or preserve changes, and write a precise handoff report.

Do not leave partially modified ownership or save code without documenting it.

---

# 29. DEFINITION VALIDATION

Add startup validation for all pet and evolution definitions.

The validator must detect:

- Duplicate IDs
- Invalid species references
- Invalid target evolution forms
- Missing evolution stage definitions
- Invalid stage transitions
- Invalid affinity names
- Invalid rarity names
- Missing catalyst references
- Unknown mutation IDs
- Unreachable branches
- Unintended evolution cycles
- Invalid multiplier values
- Invalid probabilities
- Conflicting forced branches
- Impossible requirements
- Invalid asset model keys, with explicitly permitted placeholders
- Invalid Awakening references

Clearly report whether an invalid definition is launch content or a disabled future-only fixture.

Invalid launch content should fail loudly in development.

Future-only content must not accidentally become obtainable.

---

# 30. PHASE 4 ACCEPTANCE CRITERIA

Phase 4 is considered complete only when:

- [ ] Existing pet ownership and saves remain compatible.
- [ ] A pet can be fed using a legitimately carried world resource.
- [ ] Resource consumption is server-authoritative and exactly once.
- [ ] Growth is functional and persists.
- [ ] All three primary affinities are functional and persist.
- [ ] Hybrid feeds split configured affinity correctly.
- [ ] Stage 0–5 progression is supported by the evolution engine.
- [ ] At least one multi-stage starter lineage is playable.
- [ ] Dominant-affinity branching works.
- [ ] At least two hybrid branches work.
- [ ] Multiple simultaneous eligible branches are handled safely.
- [ ] Launch catalyst effects integrate with existing definitions.
- [ ] Catalyst family unlocks persist.
- [ ] Future special catalyst families are extensible without rewriting FeedingService.
- [ ] Mutation framework works independently of rarity.
- [ ] Pet rarity progression is independently configurable.
- [ ] No ordinary evolution causes rarity downgrade.
- [ ] Stage 5 Mythic Ascension conditions can be evaluated.
- [ ] Awakening conditions can be evaluated separately.
- [ ] Unapproved endgame content cannot be trivially unlocked.
- [ ] Evolution does not overwrite other owned pets.
- [ ] Evolution history and important latent traits persist.
- [ ] Functional feeding preview works.
- [ ] Functional evolution choice/reveal works.
- [ ] Pet models/placeholder visuals update correctly.
- [ ] Income/training multiplier metadata is available for Phase 5.
- [ ] New evolution forms can be added through definitions/assets without new bespoke services.
- [ ] RemoteEvent spam cannot duplicate rewards or reroll outcomes.
- [ ] Save/rejoin restores progression.
- [ ] Existing Phase 1–3 behavior still passes regression tests.
- [ ] Actual Studio playtests complete successfully.
- [ ] No new gameplay-breaking runtime errors are present.

Distinguish between:

PASSED
FAILED
BLOCKED
NOT TESTED

Do not claim a future content family is fully implemented merely because the data schema supports it.

---

# 31. FINAL DELIVERABLE

At completion, provide a comprehensive `PHASE4_REPORT.md`.

Include:

1. Executive implementation summary.
2. Files created, modified, and deleted.
3. Pet save schema and migration/compatibility details.
4. Feeding transaction design.
5. Growth and affinity calculations.
6. Evolution graph architecture.
7. Implemented starter lineages and branch examples.
8. Catalyst effects and compatibility.
9. Mutation and rarity handling.
10. Stage 5 Ascension design and enabled/disabled status.
11. Awakening design and enabled/disabled status.
12. Pet ownership and duplicate-form behavior.
13. UI and presentation implementation.
14. Tests performed and results.
15. Studio MCP playtest evidence.
16. Phase 1–3 regression results.
17. Unresolved design/balance questions.
18. Remaining placeholder models, sounds and animations.
19. Anything Phase 5 needs to know.
20. Phase 4 acceptance-criteria table.

Also create or update a concise `CURRENT_STATE.md` identifying the genuinely implemented and validated gameplay systems.

## FINAL PRIORITY

**Preserve the long-term depth of the original evolution concept while retaining the simplicity of the current Feed a Pet gameplay loop.**

The player should feel that every resource feeds into the long-term development of a persistent creature.

Two players beginning with the same starter pet should eventually be capable of obtaining fundamentally different evolutionary outcomes through their feeding decisions, affinities, catalysts, mutations and rare progression opportunities.

The game should support extensive future content expansion without requiring extensive new gameplay code for every pet.

Do not sacrifice evolutionary depth merely because the map and stealing interaction have been simplified.

Do not overengineer unrelated gameplay systems to achieve that depth.

Build an expandable, testable evolutionary foundation, implement a meaningful representative set of real content, and validate it against the existing game.

**Stop after Phase 4. Do not automatically begin Phase 5.**