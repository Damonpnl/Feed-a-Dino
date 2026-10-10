--!nonstrict
-- Applies definition data to a pet record; RNG is injected for mutation rolls.
local Effects = require(script.Parent.SpecialEffectDefinitions)
local ResourceEffects = {}
function ResourceEffects.apply(record, definition, nextNumber)
	record.Growth += definition.Growth
	record.Flesh += definition.Affinities.Flesh or 0
	-- Keep the existing saved Flora field, while resource-facing affinity IDs use Floral.
	record.Flora += definition.Affinities.Floral or 0
	record.Mineral += definition.Affinities.Mineral or 0
	record.EvolutionFamilies = record.EvolutionFamilies or {}
	local effect = assert(Effects[definition.SpecialEffect], "Invalid special effect")
	if effect.Kind == "EvolutionFamily" then
		record.EvolutionFamilies[effect.Family] = true
		if effect.Family == "Toxic" then record.EvolutionFamilies.Mutant = true end
		if effect.Family == "Beast" then record.EvolutionFamilies.Alpha = true end
	elseif effect.Kind == "ProgressionTag" then
		record.EvolutionFamilies[effect.Family] = true
	elseif effect.Kind == "Mutation" and nextNumber() < effect.Chance then
		if not table.find(record.Mutations, effect.MutationId) then table.insert(record.Mutations, effect.MutationId) end
	end
end
return ResourceEffects
