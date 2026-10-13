--!nonstrict
-- Server announcements and reset lighting; sound assets remain configurable hooks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.FieldConfig)
local Rarities = require(ReplicatedStorage.Shared.RarityDefinitions)
local Presentation = {}
local rareSpawned, soundRequested = Instance.new("BindableEvent"), Instance.new("BindableEvent")
Presentation.RareSpawned, Presentation.SoundRequested = rareSpawned.Event, soundRequested.Event
local running, connections, queue = false, {}, {}
local screen, label, frame, lightingTween, currentTween, savedLighting = nil, nil, nil, nil, nil, nil
local processing, worker = false, nil
local countdown, sizeConstraint, textConstraint = nil, nil, nil
local currentPriority, countdownClock = 0, 0
local activeSounds, seen, seenOrder = {}, {}, {}
local function refreshCountdown(field)
	if not countdown then return end
	if field:GetAttribute("Phase") == "Reset" then countdown.Text = "RESOURCES RESETTING..." return end
	local remaining = math.max(0, math.ceil((field:GetAttribute("NextResetAt") or workspace:GetServerTimeNow()) - workspace:GetServerTimeNow()))
	countdown.Text = string.format("RESOURCES RESET IN %d:%02d", math.floor(remaining / 60), remaining % 60)
end
local function phaseChanged(field)
	refreshCountdown(field)
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
	if type(payload) ~= "table" or type(payload.InstanceId) ~= "string" or type(payload.DisplayName) ~= "string" or type(payload.AreaName) ~= "string" then return end
	local style = Config.RarePresentation[payload.Rarity]
	if not style or seen[payload.InstanceId] then return end
	seen[payload.InstanceId] = true table.insert(seenOrder, payload.InstanceId)
	if #seenOrder > 256 then seen[table.remove(seenOrder, 1)] = nil end
	rareSpawned:Fire(payload)
	soundRequested:Fire(payload, style.SoundId, style.SoundVolume, style.Priority)
	if style.Priority == 3 then for _, sound in activeSounds do sound:Destroy() end table.clear(activeSounds) end
	if style.SoundId ~= "" then
		for index = #activeSounds, 1, -1 do if not activeSounds[index].Parent then table.remove(activeSounds,index) end end
		if #activeSounds >= 20 then table.remove(activeSounds,1):Destroy() end
		local sound = Instance.new("Sound")
		sound.SoundId, sound.Volume = style.SoundId, style.SoundVolume
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		table.insert(activeSounds, sound)
		Debris:AddItem(sound, 15)
	end
	table.insert(queue, {Payload = payload, Style = style})
	table.sort(queue, function(a,b) return a.Style.Priority > b.Style.Priority end)
	if #queue > 20 then table.remove(queue) end
	-- Divine is never held behind a lower-priority announcement.
	if style.Priority == 3 and processing and currentPriority < 3 then
		if worker then task.cancel(worker) worker = nil end
		if currentTween then currentTween:Cancel() end
		processing = false
	end
	if processing then return end
	processing = true
	worker = task.spawn(function()
		while running and #queue > 0 do
			local entry = table.remove(queue, 1)
			local item = entry.Payload
			currentPriority = entry.Style.Priority
			sizeConstraint.MaxSize = Vector2.new(entry.Style.Width, entry.Style.Height)
			frame.Size = UDim2.new(0.9, 0, 0, entry.Style.Height)
			textConstraint.MaxTextSize = entry.Style.TextSize
			frame:SetAttribute("Rarity", item.Rarity)
			label.Text = entry.Style.Label .. "\n" .. item.DisplayName .. " · " .. item.AreaName
			label.TextColor3 = Rarities.getColor(item.Rarity)
			frame.Visible = true
			frame.BackgroundTransparency, label.TextTransparency = 1, 1
			currentTween = TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 0})
			currentTween:Play()
			frame.BackgroundTransparency = 0.2
			task.wait(entry.Style.Duration)
			if not running then break end
			currentTween = TweenService:Create(label, TweenInfo.new(0.2), {TextTransparency = 1})
			currentTween:Play()
			task.wait(0.25)
			if running then frame.Visible = false end
		end
		processing = false
		currentPriority = 0
		worker = nil
	end)
end
function Presentation:Start()
	if running then return end
	running = true
	screen = Instance.new("ScreenGui")
	screen.Name, screen.ResetOnSpawn, screen.DisplayOrder = "FieldAnnouncements", false, 25
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	countdown = Instance.new("TextLabel")
	countdown.Name = "ResetCountdown"
	countdown.AnchorPoint, countdown.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8)
	countdown.Size = UDim2.new(0.9, 0, 0, 32)
	countdown.BackgroundTransparency, countdown.TextSize = 0.3, 20
	countdown.BackgroundColor3, countdown.TextColor3 = Color3.fromRGB(20,22,28), Color3.new(1,1,1)
	countdown.Font, countdown.Parent = Enum.Font.GothamBold, screen
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 48)
	frame.Size = UDim2.new(0.9, 0, 0, 76)
	frame.BackgroundColor3 = Color3.fromRGB(22, 18, 35)
	frame.Visible, frame.Parent = false, screen
	local size = Instance.new("UISizeConstraint")
	sizeConstraint = size
	size.MaxSize, size.Parent = Vector2.new(640, 76), frame
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 12) corner.Parent = frame
	label = Instance.new("TextLabel")
	label.Size, label.Position = UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6)
	label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.FredokaOne, true
	label.Parent = frame
	local bounds = Instance.new("UITextSizeConstraint") bounds.MinTextSize, bounds.MaxTextSize, bounds.Parent = 14, 30, label
	textConstraint = bounds
	local outline = Instance.new("UIStroke") outline.Thickness, outline.Color, outline.Parent = 2, Color3.fromRGB(15, 10, 20), label
	local field = ReplicatedStorage:WaitForChild("WorldFieldState")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FieldRareSpawn")
	connections = {
		field:GetAttributeChangedSignal("Phase"):Connect(function() phaseChanged(field) end),
		remote.OnClientEvent:Connect(announce),
		RunService.Heartbeat:Connect(function(delta)
			countdownClock += delta
			if countdownClock >= 0.2 then countdownClock = 0 refreshCountdown(field) end
		end),
	}
	phaseChanged(field)
end
function Presentation:Stop()
	running = false
	if worker then task.cancel(worker) worker = nil end
	processing = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections) table.clear(queue)
	table.clear(seen) table.clear(seenOrder)
	for _, sound in activeSounds do sound:Destroy() end table.clear(activeSounds)
	currentPriority, countdownClock = 0, 0
	if lightingTween then lightingTween:Cancel() end
	if currentTween then currentTween:Cancel() end
	if savedLighting then Lighting.ClockTime, Lighting.Brightness = savedLighting.ClockTime, savedLighting.Brightness end
	savedLighting = nil
	if screen then screen:Destroy() end
	screen, frame, label, lightingTween, currentTween = nil, nil, nil, nil, nil
	countdown, sizeConstraint, textConstraint = nil, nil, nil
end
function Presentation:GetStats() return {Connections=#connections, Queued=#queue, Running=running, Priority=currentPriority} end
return Presentation
