--!strict
local Config = require(script.Parent.BillboardConfig)
local RarityStyles = require(script.Parent.RarityStyles)
local ModifierStyles = require(script.Parent.ModifierStyles)
local FieldConfig = require(script.Parent.FieldConfig)
local Effects = require(script.Parent.SpecialEffectDefinitions)

local Data = {}
export type Options = {
	DisplayName: string?, Rarity: string?, ValueText: string?, Modifier: string?,
	ObjectType: string?, Offset: Vector3?, NearDistance: number?, FarDistance: number?, MaxDistance: number?,
}

Data.Keys = { "DisplayName", "Rarity", "ValueText", "Modifier", "ObjectType", "Offset", "NearDistance", "FarDistance", "MaxDistance" }
local numericKeys = { NearDistance = true, FarDistance = true, MaxDistance = true }

function Data.valid(key: string, value: any): boolean
	if key == "Offset" then
		return typeof(value) == "Vector3" and value.Magnitude < 10000
	elseif numericKeys[key] then
		return typeof(value) == "number" and value == value and value > 0 and value < 10000
	end
	return typeof(value) == "string"
end

function Data.rarity(name: string?)
	for id, style in RarityStyles do
		if string.lower(id) == string.lower(name or "Common") then
			return style, id
		end
	end
	return RarityStyles.Common, "Common"
end

function Data.modifier(modifiers: string?)
	local best = nil
	for word in string.gmatch(modifiers or "", "[^,]+") do
		local normalized = string.lower(string.match(word, "^%s*(.-)%s*$") or word)
		for id, style in ModifierStyles do
			if normalized == string.lower(id) and (best == nil or style.Priority > best.Priority) then
				best = style
			end
		end
	end
	return best
end

function Data.distances(options: Options): (number, number)
	local preset = Config.ObjectTypes[options.ObjectType or "Feed"] or Config.ObjectTypes.Feed
	local near = options.NearDistance or preset.Near
	if options.MaxDistance then return math.min(near, options.MaxDistance), options.MaxDistance end
	return near, math.max(near + 1, options.FarDistance or preset.Far)
end

function Data.read(target: Instance): Options
	local options: any = {}
	for _, key in Data.Keys do
		local value = target:GetAttribute(Config.AttributePrefix .. key)
		if Data.valid(key, value) then
			options[key] = value
		end
	end
	return options
end

function Data.resource(definition): Options
	local rare = FieldConfig.RarePresentation[definition.Rarity]
	local effect = Effects[definition.SpecialEffect]
	return {
		DisplayName = definition.DisplayName,
		Rarity = definition.Rarity,
		ValueText = if definition.Growth > 0 then "+" .. tostring(definition.Growth) .. " Growth" else (if effect then effect.DisplayText else ""),
		Modifier = "",
		ObjectType = definition.ResourceType,
		Offset = definition.BillboardOffset,
		NearDistance = if rare then 120 else nil,
		FarDistance = if rare then rare.Distance else nil,
	}
end

return Data
