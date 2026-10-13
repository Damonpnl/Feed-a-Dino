--!nonstrict
-- Applies definition data to a pet record; RNG is injected for mutation rolls.
local Effects = require(script.Parent.SpecialEffectDefinitions)
local ResourceEffects = {}
local function validNumber(value)
	return type(value) == "number" and value >= 0 and value <= 9007199254740991
end
-- Pure, non-mutating preview. Both the client and authoritative commit use this.
function ResourceEffects.resolve(record, definition)
	assert(type(record) == "table" and type(definition) == "table", "Missing pet or resource")
	assert(validNumber(definition.Growth), "Invalid resource Growth")
	local effect = assert(Effects[definition.SpecialEffect], "Invalid special effect")
	local delta = {Growth=definition.Growth, Flesh=definition.Affinities.Flesh or 0,
		Floral=definition.Affinities.Floral or 0, Mineral=definition.Affinities.Mineral or 0}
	local after = {}
	for key, stored in {Growth="Growth", Flesh="Flesh", Floral="Flora", Mineral="Mineral"} do
		assert(validNumber(record[stored]) and validNumber(delta[key]), "Invalid pet/effect number")
		after[key] = record[stored] + delta[key]
		assert(validNumber(after[key]) and (delta[key] == 0 or after[key] > record[stored]), "Growth/affinity precision exhausted")
	end
	local total = record.TotalGrowth or record.Growth
	assert(validNumber(total) and total >= record.Growth, "Invalid cumulative Growth")
	after.TotalGrowth = total + delta.Growth
	assert(validNumber(after.TotalGrowth) and (delta.Growth == 0 or after.TotalGrowth > total), "Cumulative Growth precision exhausted")
	local description = effect.DisplayText
	if effect.Kind == "Mutation" then description = string.format("%g%% %s chance (existing prototype)", effect.Chance*100, effect.MutationId)
	elseif effect.Kind == "EvolutionFamily" then description = description .. " family eligibility; no guaranteed transformation" end
	return {Delta=delta, BeforeGrowth=record.Growth, After=after, SpecialDescription=description}
end
function ResourceEffects.apply(record, definition, nextNumber)
	local result = ResourceEffects.resolve(record, definition)
	record.Growth = result.After.Growth
	record.TotalGrowth = result.After.TotalGrowth
	record.Flesh = result.After.Flesh
	-- Keep the existing saved Flora field, while resource-facing affinity IDs use Floral.
	record.Flora = result.After.Floral
	record.Mineral = result.After.Mineral
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
