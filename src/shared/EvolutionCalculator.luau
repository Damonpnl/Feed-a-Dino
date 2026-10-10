--!strict

local MonsterDefinitions = require(script.Parent.MonsterDefinitions)

local EvolutionCalculator = {}

export type AffinitySnapshot = {
	Flesh: number,
	Flora: number,
	Mineral: number,
}

function EvolutionCalculator.resolve(
	definition: MonsterDefinitions.MonsterDefinition,
	growth: number,
	affinities: AffinitySnapshot,
	catalystId: string?,
	families: { [string]: boolean }?
): string?
	if growth < definition.GrowthRequired then
		return nil
	end

	for _, evolution in definition.Evolutions do
		local familyUnlocked = evolution.Family ~= nil and families ~= nil and families[evolution.Family] == true
		if evolution.Catalyst ~= nil and evolution.Catalyst ~= catalystId and not familyUnlocked then
			continue
		end
		if evolution.Catalyst == nil and evolution.Family ~= nil and not familyUnlocked then continue end

		local met = true
		for affinity, amount in evolution.Requirements do
			local current = 0
			if affinity == "Flesh" then
				current = affinities.Flesh
			elseif affinity == "Flora" then
				current = affinities.Flora
			elseif affinity == "Mineral" then
				current = affinities.Mineral
			end
			if current < amount then
				met = false
				break
			end
		end

		if met then
			return evolution.Result
		end
	end

	return nil
end

return EvolutionCalculator
