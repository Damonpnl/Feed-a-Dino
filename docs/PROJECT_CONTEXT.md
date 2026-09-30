# Project Context

## Working concept

Players operate a compact creature research compound consisting of:

- One primary creature enclosure
- One adjoining laboratory
- Access to shared conveyor-fed resources
- Upgradeable feeding, incubation, research, storage, and containment equipment

Players acquire feed and biological materials from conveyors, carry them to their base, and feed a growing creature.

The creature's diet determines its lineage. It may develop from a dinosaur-like hatchling into dinosaurs, monsters, dragons, mythical creatures, mechanical creatures, corrupted creatures, or temporary trend variants.

## Core player fantasy

Raise a unique creature whose final form reflects the player's feeding decisions, rare discoveries, and risk-taking.

The player should feel:
- Ownership over the creature
- Curiosity about possible evolutions
- Envy when viewing other bases
- Excitement when rare feed appears
- Responsibility for the resulting lineage
- Motivation to attempt another lineage

## Core gameplay loop

1. Acquire feed or a catalyst from the shared conveyor.
2. Physically carry it to the player's base.
3. Feed it to the active creature or process it in the lab.
4. Add affinity values and growth progress.
5. Preview likely evolutionary directions.
6. Reach an evolution checkpoint.
7. Reveal a new lineage or mutation.
8. Keep growing, display, ascend, or eventually sell the creature.
9. Upgrade the compound to pursue harder lineages.

## MVP scope

The first vertical slice contains:

- One player base used for testing
- One neutral starter creature
- Three affinities: Flesh, Flora, Mineral
- Six basic feed definitions
- Three juvenile lineages
- Deterministic evolution selection
- One feed interaction
- One visible creature transformation
- No persistence initially

## Explicitly out of scope for the first vertical slice

- Trading
- Breeding
- PvP combat
- Base raiding
- Theft
- Auctions
- Trend variants
- Catalysts
- Mature and ascended lineages
- Mutation rolling
- DataStore persistence
- Monetization
- Multiple active creatures
- Complex UI
- Procedural creature generation

## Map and base direction

Each player base consists of:

- A visible dinosaur or creature enclosure
- A laboratory building beside it
- A feeding interaction point
- An incubator location
- A storage area
- An upgrade terminal location

Physical models remain Studio-owned.

Code must discover or be configured with exact instance paths after Studio MCP inspection. It must not assume names.

## Server target

Initial design target:
- Eight player bases per server
- Compact bases surrounding or facing a shared resource area
- Short travel distance between conveyor and base

The current prototype may not yet match the final layout.

## Technical stack

- Roblox Studio
- Rojo
- Cursor
- Roblox Studio MCP
- Git
- Typed Luau

## Architecture principles

- Server-authoritative gameplay
- Data-driven creature and feed definitions
- Pure evolution calculations
- Stable internal IDs
- Visual models separate from gameplay definitions
- Small vertical slices before broad content production
- Studio remains authoritative for physical world construction
- Filesystem remains authoritative for Rojo-managed code

## Product priorities

In order:

1. Feeding must feel immediate and satisfying.
2. Evolution must create anticipation and novelty.
3. Creatures must look meaningfully different.
4. Rare feed must create server-level excitement.
5. Other players' creatures must be visible and comparable.
6. The architecture must allow new lineages and trend variants to be added primarily through data and modular visual assets.
