--!strict

--[[
	Data-driven Stage 2 specialized variant map.
	Keyed by normal base form ID, then qualifying influence ID.
	Absent mappings leave the normal base form unchanged.
]]

local CreatureTypes = require(script.Parent.CreatureTypes)

local SpecializedVariantRoutes = {}

export type InfluenceVariantTable = { [CreatureTypes.InfluenceId]: CreatureTypes.FormId }

local variants: { [CreatureTypes.FormId]: InfluenceVariantTable } = table.freeze({
	Raptor = table.freeze({
		Arthropod = "MantisRaptor",
	}),
	Ent = table.freeze({
		Fungal = "MushroomEnt",
	}),
	CrystalGolem = table.freeze({
		Volcanic = "MagmaGolem",
	}),
})

function SpecializedVariantRoutes.getVariantTable(baseFormId: CreatureTypes.FormId): InfluenceVariantTable?
	return variants[baseFormId]
end

function SpecializedVariantRoutes.resolve(
	baseFormId: CreatureTypes.FormId,
	influenceId: CreatureTypes.InfluenceId
): CreatureTypes.FormId
	local byInfluence = variants[baseFormId]
	if byInfluence == nil then
		return baseFormId
	end
	local variantId = byInfluence[influenceId]
	if variantId == nil then
		return baseFormId
	end
	return variantId
end

function SpecializedVariantRoutes.getAll(): { [CreatureTypes.FormId]: InfluenceVariantTable }
	return variants
end

return SpecializedVariantRoutes
