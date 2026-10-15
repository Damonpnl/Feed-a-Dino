--!strict
local Definitions = require(script.Parent.ResourceDefinitions)
local Types = require(script.Parent.ResourceTypes)
local CatalystDefinitions = {}
export type CatalystDefinition = Types.ResourceDefinition
local items = {}
for id, definition in Definitions.getAll() do
	if definition.ResourceType == "Catalyst" then items[id] = definition end
end
function CatalystDefinitions.get(id: string): CatalystDefinition? return items[id] end
function CatalystDefinitions.getAll(): { [string]: CatalystDefinition } return items end
-- Behavior references the resource catalog; never duplicate economy/spawn values.
-- Provisional compatibility: the current ProtoRex lineage, stages 0–4. Unlocks
-- may be latent; graph eligibility still controls every eventual transformation.
local behaviors = {}
local families = {
	PrimalCatalyst={"Primal"}, ToxicCatalyst={"Toxic","Mutant"}, JungleHeart={"Beast","Alpha"},
	CrystalCatalyst={"Crystal"}, FireCore={"Fire"}, DragonBlood={"Draconic"}, InfernoCatalyst={"Inferno"},
	GiantSerum={"Titan"}, SpiritEnergy={"Spirit"}, CyberCore={"Cyber"}, VoidEssence={"Void"},
	BloodMoonShard={"BloodMoon"}, CelestialCore={"Celestial"},
}
for id, unlocked in families do
	local effects = {}
	for _, family in unlocked do table.insert(effects,{Kind="UnlockEvolutionFamily",Id=family}) end
	table.insert(effects,{Kind="AddLatentTrait",Id=unlocked[1]})
	table.insert(effects,{Kind="AddLineageTag",Id="Catalyst:"..unlocked[1]})
	table.insert(effects,{Kind="EnableSpecialEvolution",Id=unlocked[1]})
	behaviors[id]={Enabled=items[id].Launch,RequiredLineage="ProtoRex",MinStage=0,MaxStage=4,Effects=effects}
end
function CatalystDefinitions.getBehavior(id: string): any return behaviors[id] end
function CatalystDefinitions.getBehaviors(): any return behaviors end
return CatalystDefinitions
