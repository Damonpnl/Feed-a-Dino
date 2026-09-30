# Current State

Last updated: 2026-07-31

## Working

- Rojo is installed and connected to Studio.
- Roblox Studio MCP is connected to Cursor.
- Base models exist in Workspace.
- Bases contain an enclosure and adjacent lab.
- Base spawning works.
- Conveyors move.
- Players can interact with or pick up meat in some form.

## Unverified or incomplete

- Carrying meat back to the base
- Feed drop-off interaction
- Creature spawning
- Creature ownership
- Affinity storage
- Evolution calculation
- Evolution visuals
- Saving

## Current technical objective

Implement and test the data-only lineage architecture:

- CreatureTypes
- FeedDefinitions
- LineageDefinitions
- EvolutionCalculator

Do not connect it to Workspace yet.

## Known Studio paths

Populate these only after MCP inspection:

- Bases folder: `Workspace.Bases`
- Example base: `Workspace.Bases.base01`
- Conveyor folder: `Workspace.Conveyors`
- Feed item model: `Workspace.Conveyors.SpawnedMaterials` (folder; exact feed model names not yet verified)
- Enclosure model: `Workspace.Bases.base01.Model`
- Lab model: `Workspace.Bases.base01.Lab Room`
- Creature spawn marker: `Workspace.Bases.base01.PlayerSpawn`
- Feeding point: not yet identified via MCP inspection

## Current decisions

- Rojo owns code only.
- Workspace remains Studio-owned.
- First implementation has three affinities.
- Evolution is deterministic for the first test.
- No persistence or networking is being implemented yet.

## Open questions

- Exact growth threshold for juvenile evolution
- Whether affinity totals reset or persist after evolution
- How feed objects identify their Feed ID
- Whether feeding occurs through a ProximityPrompt, physical drop-off, or held-item interaction
