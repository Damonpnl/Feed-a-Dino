# Monster evolution

Resource affinities are Flesh, Floral, Mineral and Neutral, plus configured hybrids. Floral is saved as `Flora` for compatibility. Normal affinity gain equals Growth; hybrid gain splits evenly, and Neutral adds no normal affinity. See [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md).

Evolution is data on the current monster. An option is chosen when:

1. Growth is at least `GrowthRequired`.
2. Every affinity requirement is met.
3. If the option lists a catalyst/family, the consumed legacy catalyst ID matches or its configured evolution family has been unlocked in the pet's saved `EvolutionFamilies`.

Phase 4B replaces the prototype first-match rule. Eligible specialized branches sort by stable ID: one advances automatically; multiple become a persistent player choice. A configured normal fallback applies only if no specialized branch qualifies. Dominant-affinity ties can qualify multiple branches. Hybrid minima must be met explicitly. See [PHASE4B_REPORT.md](PHASE4B_REPORT.md) for the graph and provisional balance.

Each feed/choice advances at most one stage and spends only the source threshold. Excess Growth remains in `GrowthReserve`; cumulative `TotalGrowth`, affinities, families, mutations and the same owned pet identity survive. Owned map keys and `EquippedMonster` do not change; `EvolutionForm` changes instead. Stage 5 is locked pending 4D; Awakening is separate and not implemented.

The starter is Proto Rex.

Phase 4C extends family compatibility and adds provisional PrimalRex, ToxicRex,
AlphaRex, DraconicRex and InfernoRex Stage 2 branches. See
[PHASE4C_REPORT.md](PHASE4C_REPORT.md) for exact predicates, disabled content,
mutation taxonomy and API details. Family unlocks and latent traits do not bypass
stage or affinity requirements; pending choices remain authoritative.

| Result | Requirements |
|---|---|
| Fangling | Flesh 40, growth 50 |
| Mossback | Flora 40, growth 50 |
| Stonehide | Mineral 40, growth 50 |
| Magma T-Rex | Fangling, Flesh 80, growth 80, Fire family (Fire Core; legacy FireCatalyst also compatible) |
| Crystal Wolf | Stonehide, Mineral 80, growth 80, Crystal Catalyst |
| Spirit Dragon | Mossback, Flora 80, growth 80, Spirit family (future-only Spirit Energy; legacy SpiritEssence compatible) |

`src/shared/EvolutionCalculator.luau` is pure and has no Roblox service calls.

The legacy forms above remain valid IDs. Ordinary paths now also provide JuvenileRex → MatureRex → ApexRex → AscendedRex, with ArmoredRex, VenomRex and CrystalMossRex hybrid alternatives at Stage 2. No new catalyst effects or rarity roll systems were introduced.
