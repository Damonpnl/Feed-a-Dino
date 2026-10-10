--!nonstrict
-- One UI factory for all world labels. The manager supplies animation time.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BillboardConfig)
local Data = require(Shared.BillboardData)
local View = {}
View.__index = View

local function label(parent, name, y, height, maxSize)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(8, y)
	text.Size = UDim2.new(1, -16, 0, height)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = maxSize
	-- TextWrapped=false would also turn TextScaled off in Roblox.
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = ""
	text.ZIndex = 3
	text.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = maxSize
	constraint.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = 2.3
	stroke.Color = Color3.fromRGB(20, 15, 30)
	stroke.Parent = text
	return text, stroke
end

function View.new(parent)
	local self = setmetatable({}, View)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldTag"
	gui.Size = UDim2.fromOffset(Config.Width, Config.Height)
	gui.AlwaysOnTop = Config.AlwaysOnTop
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.Enabled = false
	gui.Parent = parent
	self.Gui = gui
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = gui
	self.Scale = Instance.new("UIScale")
	self.Scale.Parent = container
	self.Container = container
	-- The name leads the hierarchy while the stat remains close enough to read as one stack.
	self.NameLabel, self.NameStroke = label(container, "NameLabel", 8, 37, 34)
	self.ValueLabel, self.ValueStroke = label(container, "ValueLabel", 41, 27, 23)
	self.ValueStroke.Thickness = 2.5
	self.NameGradient = Instance.new("UIGradient")
	self.NameGradient.Rotation = 90
	self.NameGradient.Parent = self.NameLabel
	self.ValueGradient = Instance.new("UIGradient")
	self.ValueGradient.Rotation = 90
	self.ValueGradient.Parent = self.ValueLabel

	local badge = Instance.new("Frame")
	badge.Name = "ModifierBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 72)
	badge.Size = UDim2.fromOffset(130, 21)
	badge.BackgroundColor3 = Color3.fromRGB(25, 20, 38)
	badge.ZIndex = 2
	badge.Parent = container
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = badge
	self.BadgeStroke = Instance.new("UIStroke")
	self.BadgeStroke.Thickness = 1.2
	self.BadgeStroke.Parent = badge
	self.BadgeLabel, self.BadgeTextStroke = label(badge, "TextLabel", 0, 21, 15)
	self.BadgeTextStroke.Thickness = 1
	self.Badge = badge

	local glow = Instance.new("Frame")
	glow.Name = "GlowFrame"
	glow.Position = UDim2.new(0, 12, 0, 13)
	glow.Size = UDim2.new(1, -24, 0, 56)
	glow.ZIndex = 1
	glow.Parent = container
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Rotation = 90
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = glow
	self.Glow = glow

	self.Shine, self.ShineStroke = label(container, "ShineFrame", 8, 37, 34)
	self.Shine.ZIndex = 4
	self.ShineStroke.Enabled = false
	self.ShineGradient = Instance.new("UIGradient")
	self.ShineGradient.Rotation = 20
	self.ShineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
	})
	self.ShineGradient.Parent = self.Shine
	self.Sparks = {}
	for index = 1, 3 do
		local spark, outline = label(container, "Spark" .. index, 0, 16, 16)
		spark.Size = UDim2.fromOffset(16, 16)
		spark.Text = "✦"
		outline:Destroy()
		table.insert(self.Sparks, spark)
	end
	self.Icon = Instance.new("ImageLabel")
	self.Icon.Name = "RarityIcon"
	self.Icon.BackgroundTransparency = 1
	self.Icon.Position = UDim2.fromOffset(-15, 17)
	self.Icon.Size = UDim2.fromOffset(23, 23)
	self.Icon.Parent = container
	return self
end

function View:Update(options, fallbackName)
	local style, rarity = Data.rarity(options.Rarity)
	self.Style = style
	self.NameLabel.Text = string.upper(options.DisplayName or fallbackName)
	self.ValueLabel.Text = options.ValueText or ""
	self.ValueLabel.Visible = self.ValueLabel.Text ~= ""
	self.NameLabel.TextColor3 = if style.Gradient then Color3.new(1, 1, 1) else style.NameColor
	self.ValueLabel.TextColor3 = if style.ValueGradient then Color3.new(1, 1, 1) else style.ValueColor
	self.NameGradient.Enabled = style.Gradient ~= nil
	self.NameGradient.Color = style.Gradient or ColorSequence.new(style.NameColor)
	self.NameGradient.Rotation = style.GradientRotation or 90
	self.ValueGradient.Enabled = style.ValueGradient ~= nil
	self.ValueGradient.Color = style.ValueGradient or ColorSequence.new(style.ValueColor)
	self.ValueGradient.Rotation = style.GradientRotation or 90
	for _, stroke in { self.NameStroke, self.ValueStroke } do
		stroke.Color = style.StrokeColor
		stroke.Thickness = style.StrokeThickness
	end
	self.ValueStroke.Thickness = style.StrokeThickness * 1.08
	local modifier = Data.modifier(options.Modifier)
	self.BadgeLabel.Text = if modifier then modifier.Text else ""
	local badgeColor = if modifier then modifier.Color else style.NameColor
	self.BadgeLabel.TextColor3 = badgeColor
	self.BadgeStroke.Color = badgeColor
	self.HasBadge = modifier ~= nil
	self.Glow.BackgroundColor3 = style.GlowColor
	self.Shine.Text = self.NameLabel.Text
	self.Icon.Image = style.Icon
	for _, spark in self.Sparks do
		spark.TextColor3 = style.NameColor
	end
end

function View:Paint(opacity, scale, time, near, animated, flash)
	local style = self.Style
	local wave = if animated then math.sin(time * style.AnimationSpeed * 2) else 0
	self.Scale.Scale = scale * (1 + wave * style.AnimationIntensity)
	local fade = 1 - opacity
	self.NameLabel.TextTransparency = fade
	self.ValueLabel.TextTransparency = fade
	self.NameStroke.Transparency = fade
	self.ValueStroke.Transparency = fade
	self.Badge.Visible = near and self.HasBadge
	self.Badge.BackgroundTransparency = 1 - opacity * 0.9
	self.BadgeLabel.TextTransparency = fade
	self.BadgeTextStroke.Transparency = fade
	self.BadgeStroke.Transparency = 1 - opacity * 0.8
	self.Glow.Visible = near and style.Glow > 0
	self.Glow.BackgroundTransparency = 1 - opacity * math.min(0.5, style.Glow * (1 + wave * 0.2 + flash))
	self.NameGradient.Offset = Vector2.new(0, wave * 0.12)
	self.ValueGradient.Offset = Vector2.new(0, wave * 0.12)
	self.Shine.Visible = animated and style.Shine > 0
	self.Shine.TextTransparency = 1 - opacity * style.Shine
	self.ShineGradient.Offset = Vector2.new((time * 0.45 % 3) - 1.5, 0)
	self.Icon.Visible = near and self.Icon.Image ~= ""
	self.Icon.ImageTransparency = fade
	for index, spark in self.Sparks do
		spark.Visible = animated and index <= style.Particles
		if spark.Visible then
			local phase = time * 0.6 + index * 2.1
			spark.Position = UDim2.new(if index % 2 == 0 then 0.91 else 0.02, 0, 0, 18 + math.sin(phase) * 13 + index * 5)
			spark.Rotation = time * 15 + index * 45
			spark.TextTransparency = 1 - opacity * (0.3 + 0.5 * math.abs(math.sin(phase)))
		end
	end
end

function View:Destroy()
	self.Gui:Destroy()
end

return View
