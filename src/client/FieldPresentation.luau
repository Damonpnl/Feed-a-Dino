--!nonstrict
-- Server announcements and reset lighting; sound assets remain configurable hooks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.FieldConfig)
local Rarities = require(ReplicatedStorage.Shared.RarityDefinitions)
local Presentation = {}
local rareSpawned, soundRequested = Instance.new("BindableEvent"), Instance.new("BindableEvent")
Presentation.RareSpawned, Presentation.SoundRequested = rareSpawned.Event, soundRequested.Event
local running, connections, queue = false, {}, {}
local screen, label, frame, lightingTween, currentTween, savedLighting = nil, nil, nil, nil, nil, nil
local processing, worker = false, nil
local function phaseChanged(field)
	if lightingTween then lightingTween:Cancel() end
	if field:GetAttribute("Phase") == "Reset" then
		if not savedLighting then savedLighting = {ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness} end
		lightingTween = TweenService:Create(Lighting, TweenInfo.new(0.6), {ClockTime = 20, Brightness = 0.8})
	elseif savedLighting then
		lightingTween = TweenService:Create(Lighting, TweenInfo.new(0.6), savedLighting)
		local restoreTween = lightingTween
		task.delay(0.65, function()
			if running and lightingTween == restoreTween then savedLighting = nil end
		end)
	else return end
	lightingTween:Play()
end
local function announce(payload)
	local style = Config.RarePresentation[payload.Rarity]
	if not style then return end
	rareSpawned:Fire(payload)
	soundRequested:Fire(payload, style.SoundId, style.SoundVolume)
	if style.SoundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId, sound.Volume = style.SoundId, style.SoundVolume
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		Debris:AddItem(sound, 15)
	end
	table.insert(queue, {Payload = payload, Style = style})
	if processing then return end
	processing = true
	worker = task.spawn(function()
		while running and #queue > 0 do
			local entry = table.remove(queue, 1)
			local item = entry.Payload
			label.Text = entry.Style.Label .. "\n" .. item.DisplayName .. " · " .. item.AreaName
			label.TextColor3 = Rarities.getColor(item.Rarity)
			frame.Visible = true
			frame.BackgroundTransparency, label.TextTransparency = 1, 1
			currentTween = TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 0})
			currentTween:Play()
			frame.BackgroundTransparency = 0.2
			task.wait(if item.Rarity == "Divine" then 6 else 4)
			if not running then break end
			currentTween = TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 1})
			currentTween:Play()
			task.wait(0.25)
			if running then frame.Visible = false end
		end
		processing = false
		worker = nil
	end)
end
function Presentation:Start()
	if running then return end
	running = true
	screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn, screen.DisplayOrder = "FieldAnnouncements", false, 25
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.08)
	frame.Size = UDim2.new(0.9, 0, 0, 76)
	frame.BackgroundColor3 = Color3.fromRGB(22, 18, 35)
	frame.Visible, frame.Parent = false, screen
	local size = Instance.new("UISizeConstraint")
	size.MaxSize, size.Parent = Vector2.new(640, 76), frame
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 12) corner.Parent = frame
	label = Instance.new("TextLabel")
	label.Size, label.Position = UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6)
	label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.FredokaOne, true
	label.Parent = frame
	local bounds = Instance.new("UITextSizeConstraint") bounds.MinTextSize, bounds.MaxTextSize, bounds.Parent = 14, 30, label
	local outline = Instance.new("UIStroke") outline.Thickness, outline.Color, outline.Parent = 2, Color3.fromRGB(15, 10, 20), label
	local field = ReplicatedStorage:WaitForChild("WorldFieldState")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FieldRareSpawn")
	connections = {
		field:GetAttributeChangedSignal("Phase"):Connect(function() phaseChanged(field) end),
		remote.OnClientEvent:Connect(announce),
	}
	phaseChanged(field)
end
function Presentation:Stop()
	running = false
	if worker then task.cancel(worker) worker = nil end
	processing = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections) table.clear(queue)
	if lightingTween then lightingTween:Cancel() end
	if currentTween then currentTween:Cancel() end
	if savedLighting then Lighting.ClockTime, Lighting.Brightness = savedLighting.ClockTime, savedLighting.Brightness end
	savedLighting = nil
	if screen then screen:Destroy() end
	screen, frame, label, lightingTween, currentTween = nil, nil, nil, nil, nil
end
return Presentation
