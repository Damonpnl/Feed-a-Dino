--!nonstrict
local ServerStorage = game:GetService("ServerStorage")
local Shared = game.ReplicatedStorage.Shared
local Models = require(Shared.ResourceModelDefinitions)
local Rarities = require(Shared.RarityDefinitions)
local Config = require(Shared.FieldConfig)
local Visuals = {}
function Visuals.create(definition, position)
	local templates = ServerStorage:FindFirstChild("ResourceModels")
	local template = templates and templates:FindFirstChild(definition.ModelKey)
	local model = Instance.new("Model")
	model.Name = definition.DisplayName
	if template and (template:IsA("BasePart") or template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true)) then
		local copy = template:Clone()
		copy.Parent = model
	else
		local fallback = assert(Models[definition.ModelKey], "Missing model definition")
		assert(fallback.Placeholder, "Model template missing: " .. definition.ModelKey)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size, body.Color = fallback.Size, fallback.Color
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = model
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then child.Anchored, child.CanCollide = true, false end
		if child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") or child:IsA("BillboardGui") then child:Destroy() end
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	assert(model.PrimaryPart, "Resource template contains no parts")
	model:PivotTo(CFrame.new(position))
	local frame, size = model:GetBoundingBox()
	local bottom = frame.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, position.Y - bottom + 0.15, 0))
	return model
end
function Visuals.rare(model, rarity, burst)
	local presentation = Config.RarePresentation[rarity]
	if not presentation then return end
	local body = model.PrimaryPart
	local color = Rarities.getColor(rarity)
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "RarityAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 0.8
	aura.Rate = presentation.Aura * 8
	aura.Lifetime = NumberRange.new(1, 2)
	aura.Speed = NumberRange.new(0.5, 1.5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new(0.45)
	aura.Transparency = NumberSequence.new(0.35, 1)
	aura.Parent = body
	if presentation.BeamHeight > 0 then
		local base, top = Instance.new("Attachment"), Instance.new("Attachment")
		base.Name, top.Name = "RarityBeamBase", "RarityBeamTop"
		base.Parent, top.Parent = body, body
		top.Position = Vector3.new(0, presentation.BeamHeight, 0)
		local beam = Instance.new("Beam")
		beam.Name = "RarityBeacon"
		beam.Attachment0, beam.Attachment1 = base, top
		beam.FaceCamera, beam.LightEmission = true, 1
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new(0.45, 0.95)
		beam.Width0, beam.Width1 = 3, 1.5
		beam.Parent = body
	end
	if burst and presentation.Burst > 0 then
		local radial = aura:Clone()
		radial.Name, radial.Rate = "DivineBurst", 0
		radial.Speed, radial.SpreadAngle = NumberRange.new(12, 22), Vector2.new(360, 360)
		radial.Parent = body
		radial:Emit(presentation.Burst)
	end
end
return Visuals
