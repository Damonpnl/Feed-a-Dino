--!strict
-- Only the highest-priority modifier badge is displayed; rarity stays intact.
local function badge(text: string, color: Color3, priority: number)
	return { Text = text, Color = color, Priority = priority }
end

return {
	Titan = badge("TITAN", Color3.fromRGB(255, 190, 100), 60),
	Mutated = badge("MUTATED", Color3.fromRGB(160, 255, 115), 50),
	Mutant = badge("MUTATED", Color3.fromRGB(160, 255, 115), 50),
	Void = badge("VOID", Color3.fromRGB(200, 155, 255), 90),
	Shiny = badge("SHINY", Color3.fromRGB(220, 255, 255), 30),
	Golden = badge("GOLDEN", Color3.fromRGB(255, 220, 85), 40),
	["Blood Moon"] = badge("BLOOD MOON", Color3.fromRGB(255, 110, 135), 80),
	Cyber = badge("CYBER", Color3.fromRGB(85, 235, 255), 65),
	Celestial = badge("CELESTIAL", Color3.fromRGB(220, 210, 255), 85),
	Limited = badge("LIMITED", Color3.fromRGB(255, 230, 150), 100),
}
