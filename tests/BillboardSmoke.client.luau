-- Manual Studio client test. Inject as a LocalScript under PlayerScripts.
-- Set this script's Cleanup attribute to true after inspecting the showcase.
task.wait(1) -- Let MCP finish its camera-restoration guard before taking test camera control.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local Service = require(player.PlayerScripts.Client.BillboardService)
local Shared = game.ReplicatedStorage.Shared
local Data = require(Shared.BillboardData)
local Config = require(Shared.BillboardConfig)
local camera = workspace.CurrentCamera
local savedType, savedFrame, savedSubject = camera.CameraType, camera.CFrame, camera.CameraSubject
local origin = Vector3.new(0, 2000, 0)
local folder = Instance.new("Folder")
folder.Name = "BillboardSmokeFixtures"
folder.Parent = workspace
local fixtures = {}
local passes = 0
local function check(condition, message)
	assert(condition, message)
	passes += 1
end
local function settle()
	task.wait(Config.DistanceInterval + Config.EnterDuration + 0.12)
end
local function findGui(target)
	for _, gui in player.PlayerGui.WorldBillboards:GetChildren() do
		if gui:IsA("BillboardGui") and gui.Adornee == target then return gui end
	end
	return nil
end
local function create(name, rarity, position, modifier)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(3, 3, 3)
	part.Position = origin + position
	part.Color = Data.rarity(rarity).NameColor
	part.Parent = folder
	Service:Create(part, {DisplayName=name, Rarity=rarity, ValueText="+25 Growth", Modifier=modifier or "", ObjectType="Feed"})
	return part
end
local function cleanup()
	for _, target in folder:GetChildren() do Service:Destroy(target) end
	folder:Destroy()
	camera.CameraType, camera.CFrame, camera.CameraSubject = savedType, savedFrame, savedSubject
end

local ok, failure = xpcall(function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(origin + Vector3.new(0, 6, 70), origin + Vector3.new(0, 6, 0))
	for index, rarity in {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"} do
		local column = if index <= 4 then index - 2.5 else index - 6
		local row = if index <= 4 then 12 else -4
		local names = {"Raw Meat", "Giant Berry", "Crystal Shard", "Mutagen", "Dragon Heart", "Giant Serum", "Primordial Core"}
		local modifier = if index == 4 then "Mutated" elseif index == 6 then "Titan,Shiny" else ""
		fixtures[index] = create(names[index], rarity, Vector3.new(column * 36, row, 0), modifier)
	end
	settle()
	for index, part in fixtures do
		local gui = findGui(part)
		check(gui ~= nil and gui.Enabled, "Rarity fixture should render: " .. part.Name)
		check(gui.Container.NameLabel.Text == string.upper(part.Name), "Name mismatch")
		check(gui.Container.NameLabel.TextScaled, "Typography must retain TextScaled")
		check(gui.Container.NameLabel.TextBounds.Y > gui.Container.ValueLabel.TextBounds.Y, "Name should be larger than value")
		check(gui.Container.NameLabel.TextTransparency == 0, "Enter should finish opaque")
		check(gui.Container.NameLabel.Outline.Transparency == 0, "Outline should finish opaque")
		if index == 1 then check(not gui.Container.GlowFrame.Visible and not gui.Container.Spark1.Visible, "Common must stay simple") end
	end
	-- Bring high rarities into the near tier for badge assertions.
	Service:Update(fixtures[6], { NearDistance = 100 })
	settle()
	check(findGui(fixtures[6]).Container.ModifierBadge.TextLabel.Text == "TITAN", "Modifier priority")
	Service:Update(fixtures[6], { Modifier = "", ValueText = "250 Growth" })
	check(findGui(fixtures[6]).Container.ModifierBadge.TextLabel.Text == "", "Clearing modifier must not replace it with a rarity word")
	check(findGui(fixtures[6]).Container.NameLabel.Text == "GIANT SERUM", "Update must preserve name")
	Service:Hide(fixtures[1])
	check(findGui(fixtures[1]).Enabled, "Hide must retain GUI during fade")
	settle()
	check(not findGui(fixtures[1]).Enabled, "Hide must disable after fade")
	Service:Show(fixtures[1])
	settle()
	check(findGui(fixtures[1]).Enabled, "Show should reappear")
	local p = fixtures[6]
	Service:Update(p, { NearDistance = 30, FarDistance = 100 })
	settle()
	check(not findGui(p).Container.ModifierBadge.Visible and not findGui(p).Container.GlowFrame.Visible, "Medium must reduce detail")
	p.Position += Vector3.new(0, 0, -160)
	settle()
	check(not findGui(p).Enabled, "Far target must hide")
	p.Position -= Vector3.new(0, 0, -160)
	Service:Update(p, { NearDistance = 100, FarDistance = 120, Modifier = "Titan" })
	settle()
	check(findGui(p).Enabled, "Return from far must show")
	p.Position += Vector3.new(0, 0, 200)
	settle()
	check(not findGui(p).Enabled, "Behind camera must hide")
	p.Position -= Vector3.new(0, 0, 200)

	local tagged = create("Metadata Probe", "Common", Vector3.new(0, 0, 15))
	Service:Destroy(tagged)
	settle()
	tagged:SetAttribute("BillboardDisplayName", "Metadata Name")
	tagged:SetAttribute("BillboardValueText", "Server stat")
	CollectionService:AddTag(tagged, Config.Tag)
	settle()
	check(findGui(tagged).Container.NameLabel.Text == "METADATA NAME", "Metadata discovery")
	tagged:SetAttribute("BillboardValueText", "Updated stat")
	settle()
	check(findGui(tagged).Container.ValueLabel.Text == "Updated stat", "Live metadata update")
	local retiring = findGui(tagged)
	CollectionService:RemoveTag(tagged, Config.Tag)
	task.wait(0.04)
	check(retiring.Parent ~= nil, "Removed tag must finish its exit")
	settle()
	check(retiring.Parent == nil, "Removed tag must release GUI")
	CollectionService:AddTag(tagged, Config.Tag)
	settle()
	local deletedGui = findGui(tagged)
	tagged:Destroy()
	task.wait(0.04)
	check(deletedGui.Parent ~= nil, "Deleted target should retain detached fading GUI")
	settle()
	check(deletedGui.Parent == nil, "Deleted target GUI must be released")
	check(Service:GetStats().Retiring == 0, "Retiring entries leaked")
	local streamed = Instance.new("Model")
	streamed.Name = "Streaming Probe"
	streamed.Parent = folder
	streamed:SetAttribute("BillboardDisplayName", "Streamed Model")
	CollectionService:AddTag(streamed, Config.Tag)
	settle()
	local body = Instance.new("Part")
	body.Anchored = true
	body.Size = Vector3.new(4, 8, 4)
	body.CFrame = CFrame.new(origin + Vector3.new(0, 0, 20)) * CFrame.Angles(0, 0, math.rad(45))
	body.Parent = streamed
	settle()
	local streamedGui = findGui(body)
	check(streamedGui ~= nil and streamedGui.Enabled, "Streamed model should resolve late geometry without PrimaryPart")
	check(streamedGui.StudsOffsetWorldSpace.Y > 4.2, "Tag should clear rotated model bounds")
	streamed:Destroy()
	settle()
	check(streamedGui.Parent == nil, "Streamed model cleanup")
	check(Data.rarity("MYTHIC").Priority == 6, "Case-insensitive rarity")
	check(Data.rarity("Unrecognized").Priority == 1, "Unknown rarity fallback")
	check(Data.modifier("Unknown,Titan,Limited").Text == "LIMITED", "Highest supported modifier wins")
	check(not Data.valid("FarDistance", 0 / 0), "Reject NaN distances")
	check(not Data.valid("Offset", Vector3.new(math.huge, 0, 0)), "Reject infinite offsets")

	local burst = {}
	for index = 1, 85 do
		table.insert(burst, create("Budget " .. index, "Secret", Vector3.new((index % 5) - 2, 0, 30)))
	end
	settle()
	local stats = Service:GetStats()
	check(stats.Visible == Config.MaxVisible, "Visibility budget")
	check(stats.Animated == Config.MaxAnimated, "Animation budget")
	for _, target in burst do target:Destroy() end
	settle()
	check(Service:GetStats().Retiring == 0, "Burst cleanup")
	local before = Service:GetStats().Watchers
	Service:Stop()
	check(Service:GetStats().Tracked == 0 and Service:GetStats().Watchers == 0, "Stop releases entries and connections")
	check(Service:GetStats().Connections == 0, "Stop disconnects all owned connections")
	Service:Start()
	settle()
	check(Service:GetStats().Watchers == before, "Restart re-discovers exactly the tagged targets")
	local direct = create("Direct destroy", "Common", Vector3.new(0,0,10))
	CollectionService:AddTag(direct, Config.Tag) settle()
	local watchers = Service:GetStats().Watchers
	Service:Destroy(direct) settle()
	check(Service:GetStats().Watchers == watchers-1, "Direct Destroy disconnects attribute watcher")
	direct:Destroy()
	for index, part in fixtures do
		local rarity = ({"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"})[index]
		Service:Create(part, {DisplayName=part.Name, Rarity=rarity, ValueText=if index==7 then "??? Growth" else "+25 Growth", NearDistance=100,
			Modifier=if index==4 then "Mutated" elseif index==6 then "Titan" else ""})
	end
	settle()
	-- The authoritative ladder adds Cosmic, Eternal and Divine to the established fixtures.
	Service:Update(fixtures[1], {MaxDistance=110}) settle()
	check(findGui(fixtures[1]).MaxDistance == 110, "Explicit MaxDistance reaches BillboardGui")
	for index, rarity in {"Cosmic", "Eternal", "Divine"} do
		local part = create(rarity .. " Probe", rarity, Vector3.new((index - 2) * 36, -20, 0))
		Service:Update(part, {NearDistance=100, FarDistance=600})
		settle()
		local gui = findGui(part)
		check(gui ~= nil and gui.Enabled, rarity .. " should render")
		check(not gui.Container.ModifierBadge.Visible, rarity .. " must not show a rarity badge")
		check(Data.rarity(rarity).Priority == ({7, 9, 10})[index], rarity .. " has authoritative priority")
		check(gui.Container.ValueLabel.Outline.Thickness >= gui.Container.NameLabel.Outline.Thickness, "Stat outline should match name strength")
	end
end, debug.traceback)

script:SetAttribute("PassedAssertions", passes)
script:SetAttribute("Result", if ok then "PASS" else failure)
if not ok then cleanup() warn("[BillboardSmoke] " .. failure) return end
print("[BillboardSmoke] PASS " .. passes .. " assertions")
script:GetAttributeChangedSignal("Cleanup"):Connect(function()
	if script:GetAttribute("Cleanup") then cleanup() script:Destroy() end
end)
