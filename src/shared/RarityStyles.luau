--!strict
-- Visual rarity is independent of gameplay odds and rewards.
local RarityDefinitions = require(script.Parent.RarityDefinitions)
local function gradient(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

local white = Color3.new(1, 1, 1)
local dark = Color3.fromRGB(20, 15, 30)
local function style(priority: number, color: Color3, colors: ColorSequence?, glow: number, speed: number, pulse: number, particles: number, rotation: number?)
	return {
		Priority = priority,
		NameColor = color,
		ValueColor = white,
		Gradient = colors,
		-- Keep stat treatment coordinated with the name at higher tiers.
		ValueGradient = if priority >= 4 then colors else nil,
		GradientRotation = rotation or 90,
		StrokeColor = dark,
		StrokeThickness = 2.3,
		GlowColor = color,
		Glow = glow,
		AnimationSpeed = speed,
		AnimationIntensity = pulse,
		Shine = if priority >= 5 then 0.35 else 0,
		Particles = particles,
		Icon = "",
	}
end

local Styles = {
	Common = style(1, Color3.fromRGB(245, 245, 248), nil, 0, 0, 0, 0),
	Uncommon = style(2, Color3.fromRGB(115, 255, 125), gradient(Color3.fromRGB(215, 255, 180), Color3.fromRGB(70, 220, 110)), 0, 0.3, 0, 0),
	Rare = style(3, Color3.fromRGB(100, 195, 255), gradient(Color3.fromRGB(180, 240, 255), Color3.fromRGB(60, 135, 255)), 0.06, 0.35, 0, 0),
	Epic = style(4, Color3.fromRGB(205, 120, 255), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 255)),
		ColorSequenceKeypoint.new(0.34, Color3.fromRGB(218, 125, 255)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(125, 48, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 150, 255)),
	}), 0.10, 0.65, 0.008, 0, 78),
	Legendary = style(5, Color3.fromRGB(255, 200, 65), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 195)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 205, 75)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(220, 112, 22)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 236, 120)),
	}), 0.16, 0.85, 0.014, 0, 78),
	Mythic = style(6, Color3.fromRGB(255, 90, 175), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 245)),
		ColorSequenceKeypoint.new(0.28, Color3.fromRGB(255, 105, 185)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(174, 36, 126)),
		ColorSequenceKeypoint.new(0.78, Color3.fromRGB(226, 67, 240)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 168, 228)),
	}), 0.22, 1, 0.021, 2, 72),
	Cosmic = style(7, Color3.fromRGB(125, 145, 255), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 235, 255)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 75, 200)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(190, 95, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 200, 255)),
	}), 0.25, 0.85, 0.02, 2, 65),
	Secret = style(8, Color3.fromRGB(160, 120, 230), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 195)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(100, 55, 140)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 235, 125)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(65, 174, 130)),
		ColorSequenceKeypoint.new(0.58, Color3.fromRGB(74, 145, 255)),
		ColorSequenceKeypoint.new(0.78, Color3.fromRGB(105, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 130, 255)),
	}), 0.28, 1.3, 0.025, 3, 68),
	Eternal = style(9, Color3.fromRGB(235, 210, 255), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(190, 135, 255)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(235, 215, 255)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	}), 0.36, 0.85, 0.028, 3, 80),
	Divine = style(10, Color3.fromRGB(255, 240, 175), ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 240, 170)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(235, 180, 75)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	}), 0.44, 1.1, 0.035, 3, 75),
}

for name, visual in Styles do
	visual.Priority = RarityDefinitions.priority(name)
	assert(visual.Priority > 0, "Unknown visual rarity: " .. name)
end

return Styles
