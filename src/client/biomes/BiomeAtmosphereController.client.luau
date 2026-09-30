--!strict

--[[
	Client-only concentric biome atmosphere controller.
	Detects Hub / Savannah / OuterUnknown by horizontal distance from map center,
	tweens dedicated biome post-processing, crossfades ambience, and shows titles.

	Lighting Atmosphere is a Roblox singleton — the existing Atmosphere is tweened.
	ColorCorrection / Bloom / SunRays use dedicated Biome* instances so unrelated
	Lighting effects remain untouched.

	OuterUnknown retains the previous atmosphere and ambience (no snap).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = Shared:WaitForChild("biomes")
local BiomeDefinitions = require(Biomes:WaitForChild("BiomeDefinitions"))
local BiomeResolver = require(Biomes:WaitForChild("BiomeResolver"))
local BiomeTypes = require(Biomes:WaitForChild("BiomeTypes"))

local player = Players.LocalPlayer
local geometry = BiomeDefinitions.getMapGeometry()

local COLOR_CORRECTION_NAME = "BiomeColorCorrection"
local BLOOM_NAME = "BiomeBloom"
local SUN_RAYS_NAME = "BiomeSunRays"
local SOUND_A_NAME = "BiomeAmbienceA"
local SOUND_B_NAME = "BiomeAmbienceB"
local GUI_NAME = "BiomeTransitionGui"

local currentBiomeId: BiomeTypes.BiomeId? = nil
local character: Model? = nil
local rootPart: BasePart? = nil
local characterConnections: { RBXScriptConnection } = {}
local pollToken = 0

local lightingTweens: { Tween } = {}
local audioTweens: { Tween } = {}
local titleTweens: { Tween } = {}
local titleToken = 0

local colorCorrection: ColorCorrectionEffect
local bloom: BloomEffect
local sunRays: SunRaysEffect
local atmosphere: Atmosphere

local ambienceA: Sound
local ambienceB: Sound
local activeAmbience: Sound
local inactiveAmbience: Sound
local activeAmbienceBiomeId: BiomeTypes.BiomeId? = nil

local screenGui: ScreenGui
local container: CanvasGroup
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local debugLabel: TextLabel?

local function cancelTweens(tweens: { Tween })
	for _, tween in tweens do
		tween:Cancel()
	end
	table.clear(tweens)
end

local function disconnectCharacterConnections()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
end

local function ensureLightingEffects()
	local existingCC = Lighting:FindFirstChild(COLOR_CORRECTION_NAME)
	if existingCC ~= nil and existingCC:IsA("ColorCorrectionEffect") then
		colorCorrection = existingCC
	else
		if existingCC ~= nil then
			existingCC:Destroy()
		end
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = COLOR_CORRECTION_NAME
		colorCorrection.Parent = Lighting
	end

	local existingBloom = Lighting:FindFirstChild(BLOOM_NAME)
	if existingBloom ~= nil and existingBloom:IsA("BloomEffect") then
		bloom = existingBloom
	else
		if existingBloom ~= nil then
			existingBloom:Destroy()
		end
		bloom = Instance.new("BloomEffect")
		bloom.Name = BLOOM_NAME
		bloom.Parent = Lighting
	end

	local existingRays = Lighting:FindFirstChild(SUN_RAYS_NAME)
	if existingRays ~= nil and existingRays:IsA("SunRaysEffect") then
		sunRays = existingRays
	else
		if existingRays ~= nil then
			existingRays:Destroy()
		end
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = SUN_RAYS_NAME
		sunRays.Parent = Lighting
	end

	local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if existingAtmosphere ~= nil then
		atmosphere = existingAtmosphere
	else
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "Atmosphere"
		atmosphere.Parent = Lighting
	end
end

local function ensureAmbienceSounds()
	local existingA = SoundService:FindFirstChild(SOUND_A_NAME)
	if existingA ~= nil and existingA:IsA("Sound") then
		ambienceA = existingA
	else
		if existingA ~= nil then
			existingA:Destroy()
		end
		ambienceA = Instance.new("Sound")
		ambienceA.Name = SOUND_A_NAME
		ambienceA.Parent = SoundService
	end

	local existingB = SoundService:FindFirstChild(SOUND_B_NAME)
	if existingB ~= nil and existingB:IsA("Sound") then
		ambienceB = existingB
	else
		if existingB ~= nil then
			existingB:Destroy()
		end
		ambienceB = Instance.new("Sound")
		ambienceB.Name = SOUND_B_NAME
		ambienceB.Parent = SoundService
	end

	for _, sound in { ambienceA, ambienceB } do
		sound.Looped = true
		sound.PlayOnRemove = false
		sound.RollOffMaxDistance = 0
		sound.RollOffMinDistance = 0
		sound.Volume = 0
	end

	activeAmbience = ambienceA
	inactiveAmbience = ambienceB
end

local function styleLabel(label: TextLabel, textSize: number, font: Enum.Font)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.15
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = false
end

local function ensureTitleGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing ~= nil and existing:IsA("ScreenGui") then
		screenGui = existing
	else
		if existing ~= nil then
			existing:Destroy()
		end
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.DisplayOrder = 40
		screenGui.Parent = playerGui
	end

	local existingContainer = screenGui:FindFirstChild("Container")
	if existingContainer ~= nil and existingContainer:IsA("CanvasGroup") then
		container = existingContainer
	else
		if existingContainer ~= nil then
			existingContainer:Destroy()
		end
		container = Instance.new("CanvasGroup")
		container.Name = "Container"
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.Position = UDim2.fromScale(0.5, 0.34)
		container.Size = UDim2.fromScale(0.7, 0.18)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.GroupTransparency = 1
		container.Visible = false
		container.Parent = screenGui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = container

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.LayoutOrder = 1
		title.Size = UDim2.new(1, 0, 0, 42)
		title.Parent = container
		styleLabel(title, 36, Enum.Font.FredokaOne)

		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.LayoutOrder = 2
		divider.Size = UDim2.fromOffset(72, 2)
		divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		divider.BackgroundTransparency = 0.35
		divider.BorderSizePixel = 0
		divider.Parent = container

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.LayoutOrder = 3
		subtitle.Size = UDim2.new(1, 0, 0, 24)
		subtitle.Parent = container
		styleLabel(subtitle, 18, Enum.Font.GothamMedium)
	end

	local titleChild = container:FindFirstChild("Title")
	local subtitleChild = container:FindFirstChild("Subtitle")
	assert(titleChild ~= nil and titleChild:IsA("TextLabel"), "Biome title missing")
	assert(subtitleChild ~= nil and subtitleChild:IsA("TextLabel"), "Biome subtitle missing")
	titleLabel = titleChild
	subtitleLabel = subtitleChild

	if BiomeDefinitions.DEBUG_ENABLED then
		local existingDebug = screenGui:FindFirstChild("DebugLabel")
		if existingDebug ~= nil and existingDebug:IsA("TextLabel") then
			debugLabel = existingDebug
		else
			local label = Instance.new("TextLabel")
			label.Name = "DebugLabel"
			label.AnchorPoint = Vector2.new(0, 1)
			label.Position = UDim2.new(0, 12, 1, -12)
			label.Size = UDim2.fromOffset(360, 90)
			label.BackgroundTransparency = 0.35
			label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
			label.TextColor3 = Color3.fromRGB(230, 230, 230)
			label.Font = Enum.Font.Code
			label.TextSize = 14
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.Text = ""
			label.Parent = screenGui
			debugLabel = label
		end
	end
end

local function applyDefinitionInstant(definition: BiomeTypes.BiomeDefinition)
	colorCorrection.TintColor = definition.colorCorrection.tintColor
	colorCorrection.Brightness = definition.colorCorrection.brightness
	colorCorrection.Contrast = definition.colorCorrection.contrast
	colorCorrection.Saturation = definition.colorCorrection.saturation

	atmosphere.Density = definition.atmosphere.density
	atmosphere.Offset = definition.atmosphere.offset
	atmosphere.Color = definition.atmosphere.color
	atmosphere.Decay = definition.atmosphere.decay
	atmosphere.Glare = definition.atmosphere.glare
	atmosphere.Haze = definition.atmosphere.haze

	bloom.Intensity = definition.bloom.intensity
	bloom.Size = definition.bloom.size
	bloom.Threshold = definition.bloom.threshold

	sunRays.Enabled = definition.sunRays.enabled
	sunRays.Intensity = definition.sunRays.intensity
	sunRays.Spread = definition.sunRays.spread
end

local function tweenLightingTo(definition: BiomeTypes.BiomeDefinition)
	cancelTweens(lightingTweens)

	local info = TweenInfo.new(
		definition.transitionDuration,
		BiomeDefinitions.LIGHTING_EASING_STYLE,
		BiomeDefinitions.LIGHTING_EASING_DIRECTION
	)

	local function track(instance: Instance, goals: { [string]: any })
		local tween = TweenService:Create(instance, info, goals)
		table.insert(lightingTweens, tween)
		tween:Play()
	end

	track(colorCorrection, {
		TintColor = definition.colorCorrection.tintColor,
		Brightness = definition.colorCorrection.brightness,
		Contrast = definition.colorCorrection.contrast,
		Saturation = definition.colorCorrection.saturation,
	})
	track(atmosphere, {
		Density = definition.atmosphere.density,
		Offset = definition.atmosphere.offset,
		Color = definition.atmosphere.color,
		Decay = definition.atmosphere.decay,
		Glare = definition.atmosphere.glare,
		Haze = definition.atmosphere.haze,
	})
	track(bloom, {
		Intensity = definition.bloom.intensity,
		Size = definition.bloom.size,
		Threshold = definition.bloom.threshold,
	})

	sunRays.Enabled = definition.sunRays.enabled
	track(sunRays, {
		Intensity = definition.sunRays.intensity,
		Spread = definition.sunRays.spread,
	})
end

local function crossfadeAmbience(definition: BiomeTypes.BiomeDefinition, biomeId: BiomeTypes.BiomeId)
	cancelTweens(audioTweens)

	local validId = BiomeDefinitions.isValidAmbientSoundId(definition.ambientSoundId)
	if not validId then
		-- Missing/placeholder IDs: fade out whatever is playing and leave silent.
		for _, sound in { activeAmbience, inactiveAmbience } do
			local tween = TweenService:Create(
				sound,
				TweenInfo.new(BiomeDefinitions.AUDIO_CROSSFADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Volume = 0 }
			)
			table.insert(audioTweens, tween)
			tween:Play()
		end
		activeAmbienceBiomeId = biomeId
		return
	end

	if activeAmbienceBiomeId == biomeId and activeAmbience.SoundId == definition.ambientSoundId then
		return
	end

	local incoming = inactiveAmbience
	local outgoing = activeAmbience

	incoming.SoundId = definition.ambientSoundId
	incoming.Volume = 0
	if not incoming.IsPlaying then
		local ok = pcall(function()
			incoming:Play()
		end)
		if not ok and BiomeDefinitions.DEBUG_ENABLED then
			warn("[BiomeAtmosphereController] Failed to play ambience for", biomeId)
		end
	end

	local fadeInfo = TweenInfo.new(
		BiomeDefinitions.AUDIO_CROSSFADE_SECONDS,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.InOut
	)
	local fadeIn = TweenService:Create(incoming, fadeInfo, { Volume = definition.ambientVolume })
	local fadeOut = TweenService:Create(outgoing, fadeInfo, { Volume = 0 })
	table.insert(audioTweens, fadeIn)
	table.insert(audioTweens, fadeOut)
	fadeIn:Play()
	fadeOut:Play()

	fadeOut.Completed:Once(function()
		if outgoing.Volume <= 0.001 then
			outgoing:Stop()
			outgoing.SoundId = ""
		end
	end)

	activeAmbience = incoming
	inactiveAmbience = outgoing
	activeAmbienceBiomeId = biomeId
end

local function playTitle(definition: BiomeTypes.BiomeDefinition)
	if not definition.showTitle then
		return
	end

	titleToken += 1
	local token = titleToken
	cancelTweens(titleTweens)

	local timing = definition.titleTiming
	titleLabel.Text = definition.displayName
	subtitleLabel.Text = definition.subtitle
	container.Visible = true
	container.GroupTransparency = 1
	container.Position = UDim2.new(0.5, 0, 0.34, timing.startOffsetY)

	local fadeIn = TweenService:Create(
		container,
		TweenInfo.new(timing.fadeInSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			GroupTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.34),
		}
	)
	table.insert(titleTweens, fadeIn)
	fadeIn:Play()

	task.spawn(function()
		fadeIn.Completed:Wait()
		if token ~= titleToken then
			return
		end
		task.wait(timing.holdSeconds)
		if token ~= titleToken then
			return
		end

		local fadeOut = TweenService:Create(
			container,
			TweenInfo.new(timing.fadeOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				GroupTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.34, timing.endOffsetY),
			}
		)
		table.insert(titleTweens, fadeOut)
		fadeOut:Play()
		fadeOut.Completed:Wait()
		if token ~= titleToken then
			return
		end
		container.Visible = false
	end)
end

local function resolvePresentationBiome(biomeId: BiomeTypes.BiomeId): BiomeTypes.BiomeId
	if biomeId == "OuterUnknown" and BiomeDefinitions.OUTER_UNKNOWN_RETAINS_PREVIOUS then
		if currentBiomeId ~= nil and currentBiomeId ~= "OuterUnknown" then
			return currentBiomeId
		end
		return "Hub"
	end
	return biomeId
end

local function transitionTo(biomeId: BiomeTypes.BiomeId, showTitle: boolean)
	-- OuterUnknown keeps the previous atmosphere/ambience; no title, no snap.
	if biomeId == "OuterUnknown" and BiomeDefinitions.OUTER_UNKNOWN_RETAINS_PREVIOUS then
		if BiomeDefinitions.DEBUG_ENABLED then
			print(string.format(
				"[BiomeAtmosphereController] Enter OuterUnknown; retaining presentation=%s",
				tostring(currentBiomeId)
			))
		end
		currentBiomeId = biomeId
		return
	end

	local presentationId = resolvePresentationBiome(biomeId)
	local definition = BiomeDefinitions.get(presentationId)
	if definition == nil then
		warn("[BiomeAtmosphereController] Missing definition for", presentationId)
		return
	end

	if BiomeDefinitions.DEBUG_ENABLED then
		print(string.format(
			"[BiomeAtmosphereController] Transition %s -> %s (presentation=%s)",
			tostring(currentBiomeId),
			biomeId,
			presentationId
		))
	end

	tweenLightingTo(definition)
	crossfadeAmbience(definition, presentationId)
	if showTitle and definition.showTitle then
		playTitle(definition)
	end

	currentBiomeId = biomeId
end

local function updateDebug(distance: number, resolved: BiomeResolver.ResolveResult)
	if debugLabel == nil then
		return
	end
	debugLabel.Text = string.format(
		"dist=%.1f\nbiome=%s\nprev=%s\nchanged=%s\nhubEnter=%.0f hubExit=%.0f outer=%.0f\nambience=%s",
		distance,
		resolved.biomeId,
		tostring(currentBiomeId),
		tostring(resolved.changed),
		geometry.hubEnterThreshold,
		geometry.hubExitThreshold,
		geometry.savannahOuterRadius,
		tostring(activeAmbienceBiomeId)
	)
end

local function pollOnce()
	if rootPart == nil or rootPart.Parent == nil then
		return
	end

	local resolved = BiomeResolver.resolve({
		position = rootPart.Position,
		previousBiomeId = currentBiomeId,
		mapGeometry = geometry,
	})

	updateDebug(resolved.distance, resolved)

	local allowInitial = BiomeDefinitions.SHOW_TITLE_ON_INITIAL_SPAWN
	if currentBiomeId == nil then
		-- Initial apply: set atmosphere without title unless configured.
		local presentationId = resolvePresentationBiome(resolved.biomeId)
		local definition = BiomeDefinitions.get(presentationId)
		if definition ~= nil then
			applyDefinitionInstant(definition)
			crossfadeAmbience(definition, presentationId)
		end
		currentBiomeId = resolved.biomeId
		if allowInitial and definition ~= nil and definition.showTitle then
			playTitle(definition)
		end
		return
	end

	if BiomeResolver.shouldTriggerTransition(currentBiomeId, resolved.biomeId, false) then
		transitionTo(resolved.biomeId, true)
	end
end

local function bindCharacter(newCharacter: Model)
	disconnectCharacterConnections()
	character = newCharacter
	rootPart = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	local ancestry = newCharacter.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			rootPart = nil
		end
	end)
	table.insert(characterConnections, ancestry)

	if rootPart ~= nil then
		local destroying = rootPart.Destroying:Connect(function()
			rootPart = nil
		end)
		table.insert(characterConnections, destroying)
	end
end

local function startPolling()
	pollToken += 1
	local token = pollToken
	task.spawn(function()
		while token == pollToken do
			pollOnce()
			task.wait(BiomeDefinitions.POLL_INTERVAL_SECONDS)
		end
	end)
end

ensureLightingEffects()
ensureAmbienceSounds()
ensureTitleGui()

-- Seed Hub look before character arrives.
local hubDefinition = BiomeDefinitions.get("Hub")
if hubDefinition ~= nil then
	applyDefinitionInstant(hubDefinition)
end

if player.Character ~= nil then
	bindCharacter(player.Character)
end

player.CharacterAdded:Connect(function(newCharacter)
	bindCharacter(newCharacter)
	-- Respawn keeps current biome id so the same biome title does not replay.
end)

startPolling()

if BiomeDefinitions.DEBUG_ENABLED then
	print("[BiomeAtmosphereController] Started", geometry)
end
