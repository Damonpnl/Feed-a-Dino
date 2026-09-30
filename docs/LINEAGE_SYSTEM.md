# Lineage System Specification

## Central rule

A creature's accumulated feed affinities determine its evolution direction.

The MVP uses three affinities:

- Flesh
- Flora
- Mineral

## Initial feed definitions

| Feed ID | Display name | Affinity contribution |
|---|---|---|
| RawMeat | Raw Meat | Flesh +10 |
| PrimeMeat | Prime Meat | Flesh +20 |
| LeafBundle | Leaf Bundle | Flora +10 |
| AncientFruit | Ancient Fruit | Flora +20 |
| BoneFragments | Bone Fragments | Mineral +10 |
| CrystalChunk | Crystal Chunk | Mineral +20 |

## Initial creature stages

### Starter

| ID | Display name | Stage | Rarity |
|---|---|---:|---|
| ProtoRex | Proto-Rex | 0 | Common |

### Juvenile outcomes

| ID | Display name | Required dominant affinity |
|---|---|---|
| Fangling | Fangling | Flesh |
| Mossback | Mossback | Flora |
| Stonehide | Stonehide | Mineral |

## Evolution behavior

For the MVP:

1. Feed adds its affinity contribution to the creature.
2. Feeding also adds growth progress.
3. Evolution becomes available after a configured growth threshold.
4. The dominant affinity determines the juvenile result.
5. Ties are resolved deterministically using an explicit affinity priority.
6. No random evolution outcome is used yet.
7. Evolution calculation contains no Roblox service dependencies.

## Initial tie priority

Until a better design is tested:

1. Flesh
2. Flora
3. Mineral

This priority must be represented explicitly and must not depend on table iteration order.

## Future extension points

The architecture should eventually support:

- Primary and secondary affinity combinations
- Catalysts
- Mutation rolls
- Evolution probability forecasts
- Secret requirements
- Environmental conditions
- Limited event variants
- Creature traits
- Multiple stages
- Recipe discovery
- Server-first discoveries

These extension points should influence data design, but their gameplay must not be implemented during the MVP.
