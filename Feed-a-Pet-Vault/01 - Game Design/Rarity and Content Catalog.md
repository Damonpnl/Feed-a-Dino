---
type: catalog
status: mixed
last_verified: 2026-10-21
source_paths:
  - src/shared/RarityDefinitions.luau
  - src/shared/RarityStyles.luau
  - src/shared/AreaDefinitions.luau
  - src/shared/ResourceDefinitions.luau
  - src/shared/CatalystDefinitions.luau
  - src/shared/MonsterDefinitions.luau
  - src/shared/TrainerDefinitions.luau
  - src/shared/FieldConfig.luau
  - docs/RESOURCE_SPECIFICATION.md
---

# Rarity and Content Catalog

## At a Glance

Ten rarities in one fixed order. Forty launch resources across five areas, six reserved future catalysts, ten trainer tiers, and a ProtoRex-rooted evolution catalog. This note indexes ids; exact numbers (growth, `PowerRequired`, weights, slowdown) stay in `ResourceDefinitions.luau`.

## Rarity Tiers

**VERIFIED IMPLEMENTATION.** `RarityDefinitions.Order`: Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic, Secret, Eternal, Divine. Priority is the 1-based index; Secret and above are `SecretPlus` (priority 8 or more). Rarity does not set spawn odds; each resource carries its own `SpawnWeight`.

| Tier | Name color (RGB) | Treatment (`RarityStyles`) |
| --- | --- | --- |
| Common | 245,245,248 | plain, no glow |
| Uncommon | 115,255,125 | name gradient |
| Rare | 100,195,255 | name gradient, faint glow |
| Epic | 205,120,255 | value gradient, stronger glow |
| Legendary | 255,200,65 | shine begins |
| Mythic | 255,90,175 | shine, glow |
| Cosmic | 125,145,255 | galaxy treatment (design) |
| Secret | 160,120,230 | rare announcement `RARE FIND` |
| Eternal | 235,210,255 | `ETERNAL ARRIVAL`, beam |
| Divine | 255,240,175 | `DIVINE ARRIVAL`, beam and burst |

Stroke is dark `20,15,30`, thickness 2.3, for every tier. `FieldConfig.RarePresentation` holds announcement sizes and aura/beam/burst numbers; all `SoundId` values are empty. Icons are empty strings.

## Resources by Area

Ids in definition order; the last in each area is its catalyst (Volcano has three catalysts at the end).

| Area | Resource ids (rarity) |
| --- | --- |
| Grasslands | RawMeat (Common), Berries (Common), BoneChunk (Uncommon), PrimeMeat (Rare), WildHerbs (Rare), GiantRib (Epic), AncientBone (Epic), PrimalCatalyst (Legendary) |
| Swamp | SmallFish (Uncommon), RottenMeat (Rare), SporePod (Rare), SwampMushroom (Epic), VenomSac (Epic), BogMarrow (Legendary), MutantLeech (Mythic), ToxicCatalyst (Cosmic) |
| Jungle | WildFruit (Rare), GiantBeetle (Rare), RareFlower (Epic), ProteinRoot (Legendary), GoldenBanana (Legendary), RoyalJelly (Mythic), BeastHeart (Mythic), JungleHeart (Secret, catalyst Beast) |
| CrystalCave | CrystalShard (Rare), FossilMarrow (Epic), MineralCore (Legendary), LivingGeode (Legendary), PrismaticCrystal (Mythic), FossilHeart (Cosmic), CrystalCore (Cosmic), CrystalCatalyst (Secret) |
| Volcano | CharredMeat (Epic), MagmaStone (Legendary), EmberHeart (Legendary), DragonScale (Mythic), DragonMeat (Cosmic), FireCore (Secret), DragonBlood (Eternal), InfernoCatalyst (Divine) |

Future (launch flag false, area `FutureEvent`): GiantSerum, SpiritEnergy, CyberCore, VoidEssence, BloodMoonShard, CelestialCore.

Resource model keys have fallback definitions in `ResourceModelDefinitions`; templates in `ServerStorage.ResourceModels` (Studio-owned) replace them if present. Final art: none ([[03 - Visual Design/Creatures and Asset Specifications]]).

## Guardians

T-Rex (Grasslands), Giant Crocodile (Swamp), Giant Gorilla (Jungle), Armored Triceratops (CrystalCave), Dragon (Volcano). Ids `TRex`, `Crocodile`, `Gorilla`, `Triceratops`, `Dragon`.

## Species and Forms

`MonsterDefinitions` ids: ProtoRex, Fangling, Mossback, Stonehide, MagmaRex, CrystalWolf, SpiritDragon, plus generated lineage forms (JuvenileRex, MatureRex, ArmoredRex, VenomRex, CrystalMossRex, PrimalRex, ToxicRex, AlphaRex, DraconicRex, InfernoRex, ApexRex, AscendedRex, MythicRex). Branch logic: [[01 - Game Design/Pets, Feeding and Evolution]]. Model reference for all: `Placeholder`.

## Trainer Tiers

Ten ids in `TrainerDefinitions`: TrainingMat, WeightedSled, IronRig, PowerCage, GoldenGym, GravityChamber, CosmicReactor, AbyssChamber, EternalForge, DivineReactor, each tied to a rarity from Common to Divine. Prices are provisional ([[01 - Game Design/Progression and Economy]]).

## Mutations and Special Content

Silver, Golden, Rainbow (definitions only), Mutant (acquisition on), Parasite (disabled). Awakening and Ascension are locked. No unique-form art exists. `SpecialEffectDefinitions` and `CatalystEffects` hold effect data; read them before inventing effects.

## Restrictions

- Ids are stable strings; display names stay separate.
- Do not add a resource without a definition row, an area pool entry (or an explicit non-launch flag), and `DefinitionValidation` still passing (asserts five areas and 40 launch resources).
- REFERENCE OBSERVATION: Steal an Egg rarity names, eggs, and mutation names (Fractured, Scrambled, Sakura) are not Feed a Pet content.

## Related Notes and Source Files

[[01 - Game Design/Resources and Field Resets]], [[03 - Visual Design/Art Direction]], `docs/RESOURCE_SPECIFICATION.md` (authoritative for the 40 rows).
