--!nonstrict
-- Centralized client renderer. One heartbeat, bounded effects, no looping tweens.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BillboardConfig)
local Data = require(Shared.BillboardData)
local View = require(script.Parent.BillboardView)
local Service = {}
local entries, watchers, connections = {}, {}, {}
local root = nil
local distanceClock, animationClock, clock = 0, 0, 0
local appeared = Instance.new("BindableEvent")
local disappeared = Instance.new("BindableEvent")
-- Hooks fire once per visibility transition. Subscribe to add local SFX/VFX.
Service.Appeared = appeared.Event
Service.Disappeared = disappeared.Event

local function remove(entry)
	if entry.view then entry.view:Destroy() end
	if entry.anchor then entry.anchor:Destroy() end
	entries[entry.target] = nil
end

local function setVisible(entry, visible)
	if entry.visible == visible then return end
	entry.visible = visible
	entry.fromOpacity = entry.opacity
	entry.transitionAt = clock
	if visible then
		entry.view:Paint(entry.opacity, 0.85 * entry.distanceScale, clock, entry.near, false, 0)
		entry.view.Gui.Enabled = true
		appeared:Fire(entry.target, table.clone(entry.options))
	else
		if entry.view and entry.opacity <= 0 then entry.view.Gui.Enabled = false end
		disappeared:Fire(entry.target, table.clone(entry.options))
	end
end

local function readBounds(entry)
	local target = entry.target
	local part = if target:IsA("BasePart") then target else target:FindFirstChildWhichIsA("BasePart", true)
	if target:IsA("Model") then part = target.PrimaryPart or part end
	if not part then return false end -- Streaming can deliver metadata before the geometry.
	local frame, size = part.CFrame, part.Size
	if target:IsA("Model") then frame, size = target:GetBoundingBox() end
	local halfHeight = (math.abs(frame.RightVector.Y) * size.X
		+ math.abs(frame.UpVector.Y) * size.Y + math.abs(frame.LookVector.Y) * size.Z) / 2
	entry.part = part
	entry.offset = frame.Position + Vector3.new(0, halfHeight, 0) - part.Position
		+ (entry.options.Offset or Config.DefaultOffset)
	entry.boundsAt = clock
	return true
end

local function detach(entry)
	-- Keep a fading tag alive when a pickup/streamed model disappears immediately.
	if entry.view and entry.position and not entry.anchor then
		local anchor = Instance.new("Attachment")
		anchor.Name = "BillboardExitAnchor"
		anchor.Parent = workspace.Terrain
		anchor.WorldPosition = entry.position
		entry.anchor = anchor
		entry.view.Gui.Adornee = anchor
		entry.view.Gui.StudsOffsetWorldSpace = Vector3.zero
	end
end

function Service:Create(target: Instance, options: Data.Options)
	assert(root, "Call BillboardService:Start() on the client first")
	assert(target:IsA("Model") or target:IsA("BasePart"), "Billboard target must be a Model or BasePart")
	local entry = entries[target]
	if entry and entry.retiring then
		remove(entry)
		entry = nil
	end
	if not entry then
		entry = {
			target = target, options = {}, enabled = true, visible = false,
			opacity = 0, fromOpacity = 0, transitionAt = clock, boundsAt = -math.huge,
			view = nil, retiring = false, position = nil, distanceScale = 1,
		}
		entries[target] = entry
	end
	self:Update(target, options)
	return entry.view and entry.view.Gui
end

function Service:Update(target: Instance, patch: Data.Options)
	local entry = entries[target]
	if not entry or entry.retiring then return end
	for _, key in Data.Keys do
		local value = patch[key]
		if value ~= nil and Data.valid(key, value) then entry.options[key] = value end
	end
	entry.style = Data.rarity(entry.options.Rarity)
	entry.boundsAt = -math.huge
	if entry.view then entry.view:Update(entry.options, target.Name) end
	distanceClock = Config.DistanceInterval
end

function Service:Show(target: Instance)
	local entry = entries[target]
	if entry and not entry.retiring then entry.enabled = true end
	distanceClock = Config.DistanceInterval
end

function Service:Hide(target: Instance)
	local entry = entries[target]
	if entry then
		entry.enabled = false
		setVisible(entry, false)
	end
end

function Service:Destroy(target: Instance)
	local entry = entries[target]
	if not entry or entry.retiring then return end
	entry.retiring = true
	detach(entry)
	setVisible(entry, false)
	if entry.opacity <= 0 then remove(entry) end
end

local function hydrate(target)
	local entry = entries[target]
	if entry then entry.options = {} end -- Removed attributes must clear prior values.
	Service:Create(target, Data.read(target))
	if target:GetAttribute(Config.AttributePrefix .. "Enabled") == false then
		Service:Hide(target)
	else
		Service:Show(target)
	end
end

local function watch(target)
	if watchers[target] or not (target:IsA("Model") or target:IsA("BasePart")) then return end
	local watcher = { dirty = false }
	watchers[target] = watcher
	watcher.connection = target.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, #Config.AttributePrefix) == Config.AttributePrefix then watcher.dirty = true end
	end)
	hydrate(target)
end

local function unwatch(target)
	local watcher = watchers[target]
	if watcher then
		watcher.connection:Disconnect()
		watchers[target] = nil
	end
	Service:Destroy(target)
end

local function distanceUpdate()
	local camera = workspace.CurrentCamera
	for target, watcher in watchers do
		if watcher.dirty then
			watcher.dirty = false
			hydrate(target)
		end
	end
	local candidates = {}
	for target, entry in entries do
		entry.selected = false
		entry.animated = false
		if entry.retiring then continue end
		if not target:IsDescendantOf(workspace) then
			Service:Destroy(target)
			continue
		end
		if not camera or not entry.enabled then continue end
		if not entry.part or not entry.part:IsDescendantOf(target) and entry.part ~= target
			or clock - entry.boundsAt >= Config.BoundsInterval then
			if not readBounds(entry) then continue end
		end
		entry.position = entry.part.Position + entry.offset
		local distance = (camera.CFrame.Position - entry.position).Magnitude
		local near, far = Data.distances(entry.options)
		local screen = camera:WorldToViewportPoint(entry.position)
		local viewport = camera.ViewportSize
		local withinScreen = screen.Z > 0 and screen.X >= -Config.Width / 2
			and screen.X <= viewport.X + Config.Width / 2 and screen.Y >= -Config.Height and screen.Y <= viewport.Y + Config.Height
		local limit = if entry.visible then far + Config.Hysteresis else far
		if distance > limit or not withinScreen then continue end
		entry.near = distance <= near
		entry.distance = distance
		entry.distanceScale = math.clamp(1 - distance / far * (1 - Config.MinScale), Config.MinScale, 1)
		table.insert(candidates, entry)
	end
	-- Prefer premium tags; within a rarity, prefer the closest objects.
	table.sort(candidates, function(a, b)
		if a.style.Priority ~= b.style.Priority then return a.style.Priority > b.style.Priority end
		return a.distance < b.distance
	end)
	local animated = 0
	for index, entry in candidates do
		if index > Config.MaxVisible then break end
		entry.selected = true
		if not entry.view then
			entry.view = View.new(root)
			entry.view:Update(entry.options, entry.target.Name)
		end
		entry.view.Gui.Adornee = entry.part
		-- The entire tag sits above the object's top, including the optional badge.
		entry.view.Gui.StudsOffsetWorldSpace = entry.offset
		if entry.near and entry.style.AnimationSpeed > 0 and animated < Config.MaxAnimated then
			entry.animated = true
			animated += 1
		end
		setVisible(entry, true)
	end
	for _, entry in entries do
		if not entry.selected then setVisible(entry, false) end
	end
end

local function animate()
	for _, entry in entries do
		if not entry.view or (not entry.visible and entry.opacity <= 0) then continue end
		local duration = if entry.visible then Config.EnterDuration else Config.ExitDuration
		local progress = math.clamp((clock - entry.transitionAt) / duration, 0, 1)
		local eased = 1 - (1 - progress) ^ 3
		entry.opacity = entry.fromOpacity + ((if entry.visible then 1 else 0) - entry.fromOpacity) * eased
		local scale = 1
		if entry.visible then
			-- 0.85 -> 1.03 -> 1 in 220ms, with no per-tag Tween connections.
			if progress < 0.7 then scale = 0.85 + 0.18 * (1 - (1 - progress / 0.7) ^ 3)
			else scale = 1.03 - 0.03 * ((progress - 0.7) / 0.3) end
		else
			scale = 1 - 0.1 * eased
		end
		entry.view:Paint(entry.opacity, scale * entry.distanceScale, clock, entry.near,
			entry.animated and entry.visible, if entry.visible then (1 - progress) * 1.5 else 0)
		if not entry.visible and progress >= 1 then
			entry.view.Gui.Enabled = false
			if entry.retiring then remove(entry) end
		end
	end
end

function Service:Start()
	if root then return end
	assert(RunService:IsClient(), "BillboardService renders on the client")
	root = Instance.new("Folder")
	root.Name = "WorldBillboards"
	root.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	connections = {
		CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(watch),
		CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(unwatch),
		RunService.Heartbeat:Connect(function(delta)
			clock += delta
			distanceClock += delta
			animationClock += delta
			if distanceClock >= Config.DistanceInterval then
				distanceClock = 0
				distanceUpdate()
			end
			if animationClock >= Config.AnimationInterval then
				animationClock = 0
				animate()
			end
		end),
	}
	for _, target in CollectionService:GetTagged(Config.Tag) do watch(target) end
end

function Service:Stop()
	for _, connection in connections do connection:Disconnect() end
	for _, watcher in watchers do watcher.connection:Disconnect() end
	for _, entry in entries do
		if entry.view then entry.view:Destroy() end
		if entry.anchor then entry.anchor:Destroy() end
	end
	table.clear(entries)
	table.clear(watchers)
	table.clear(connections)
	if root then root:Destroy() end
	root = nil
	distanceClock, animationClock, clock = 0, 0, 0
end

function Service:GetStats()
	local stats = { Tracked = 0, Visible = 0, Animated = 0, Retiring = 0, Watchers = 0 }
	for _, entry in entries do
		stats.Tracked += 1
		if entry.visible then stats.Visible += 1 end
		if entry.animated and entry.visible then stats.Animated += 1 end
		if entry.retiring then stats.Retiring += 1 end
	end
	for _ in watchers do stats.Watchers += 1 end
	return stats
end

return Service
