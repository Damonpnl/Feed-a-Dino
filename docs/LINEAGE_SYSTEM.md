# Monster evolution

Resource affinities are Flesh, Floral, Mineral and Neutral, plus configured hybrids. Floral is saved as `Flora` for compatibility. Normal affinity gain equals Growth; hybrid gain splits evenly, and Neutral adds no normal affinity. See [RESOURCE_SPECIFICATION.md](RESOURCE_SPECIFICATION.md).

Evolution is data on the current monster. An option is chosen when:

1. Growth is at least `GrowthRequired`.
2. Every affinity requirement is met.
3. If the option lists a catalyst/family, the consumed legacy catalyst ID matches or its configured evolution family has been unlocked in the pet's saved `EvolutionFamilies`.

The first matching option in the list wins. Growth resets on evolution. Affinities and family flags stay. New catalysts persist/check compatibility hooks; this task does not author new species/models for every family.

The starter is Proto Rex.

| Result | Requirements |
|---|---|
| Fangling | Flesh 40, growth 50 |
| Mossback | Flora 40, growth 50 |
| Stonehide | Mineral 40, growth 50 |
| Magma T-Rex | Fangling, Flesh 80, growth 80, Fire family (Fire Core; legacy FireCatalyst also compatible) |
| Crystal Wolf | Stonehide, Mineral 80, growth 80, Crystal Catalyst |
| Spirit Dragon | Mossback, Flora 80, growth 80, Spirit family (future-only Spirit Energy; legacy SpiritEssence compatible) |

`src/shared/EvolutionCalculator.luau` is pure and has no Roblox service calls.
