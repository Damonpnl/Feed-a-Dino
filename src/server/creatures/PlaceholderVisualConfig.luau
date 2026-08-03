--!strict

--[[
	DEPRECATED for runtime spawning.
	CreatureVisualService now clones ServerStorage.CreatureTemplates.
	Kept only as a reference for temporary color/size tuning.
]]

export type PlaceholderVisual = {
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	reflectance: number,
}

local PlaceholderVisualConfig = {}

local DEFAULT_VISUAL: PlaceholderVisual = table.freeze({
	size = Vector3.new(15.2, 26.2, 24.4),
	color = Color3.fromRGB(163, 162, 165),
	material = Enum.Material.Plastic,
	reflectance = 0,
})

local visualsByProfileId: { [string]: PlaceholderVisual } = table.freeze({
	ProtoRex = DEFAULT_VISUAL,
	Fangling = table.freeze({
		size = Vector3.new(18, 30, 28),
		color = Color3.fromRGB(200, 70, 70),
		material = Enum.Material.Neon,
		reflectance = 0.05,
	}),
	Bloodfang = table.freeze({
		size = Vector3.new(22, 34, 32),
		color = Color3.fromRGB(140, 20, 40),
		material = Enum.Material.ForceField,
		reflectance = 0.35,
	}),
	Mossback = table.freeze({
		size = Vector3.new(20, 28, 30),
		color = Color3.fromRGB(70, 150, 80),
		material = Enum.Material.Grass,
		reflectance = 0.02,
	}),
	Thornhide = table.freeze({
		size = Vector3.new(24, 32, 34),
		color = Color3.fromRGB(40, 110, 55),
		material = Enum.Material.LeafyGrass,
		reflectance = 0.25,
	}),
	Stonehide = table.freeze({
		size = Vector3.new(22, 26, 26),
		color = Color3.fromRGB(120, 120, 130),
		material = Enum.Material.Slate,
		reflectance = 0.05,
	}),
	Crystalback = table.freeze({
		size = Vector3.new(26, 30, 30),
		color = Color3.fromRGB(150, 110, 255),
		material = Enum.Material.Glass,
		reflectance = 0.55,
	}),
})

function PlaceholderVisualConfig.get(profileId: string): PlaceholderVisual
	return visualsByProfileId[profileId] or DEFAULT_VISUAL
end

return PlaceholderVisualConfig
