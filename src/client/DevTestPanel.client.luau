--!nonstrict
-- Studio-only side panel. It never builds outside Studio, and the server rejects every command
-- unless the Studio flag and an isolated memory session both allow it.
if not game:GetService("RunService"):IsStudio() then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
local remote = remotes and remotes:WaitForChild("DevTest", 10)
if not remote or not remote:IsA("RemoteFunction") then return end
local status = remote:InvokeServer({ Command = "Status" })
if type(status) ~= "table" or status.Ok ~= true then return end

local existing = playerGui:FindFirstChild("DevTestPanel")
if existing then existing:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "DevTestPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = playerGui

local function label(parent, text, height)
	local view = Instance.new("TextLabel")
	view.Size = UDim2.new(1, -8, 0, height or 18)
	view.BackgroundTransparency = 1
	view.Font = Enum.Font.Gotham
	view.TextSize = 13
	view.TextXAlignment = Enum.TextXAlignment.Left
	view.TextColor3 = Color3.fromRGB(235, 235, 235)
	view.Text = text
	view.TextWrapped = true
	view.Parent = parent
	return view
end
local function button(parent, text, callback)
	local view = Instance.new("TextButton")
	view.Size = UDim2.new(1, -8, 0, 26)
	view.BackgroundColor3 = Color3.fromRGB(48, 58, 72)
	view.Font = Enum.Font.GothamMedium
	view.TextSize = 13
	view.TextColor3 = Color3.fromRGB(240, 240, 240)
	view.Text = text
	view.AutoButtonColor = true
	view.Parent = parent
	view.Activated:Connect(callback)
	return view
end
local function field(parent, placeholder)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -8, 0, 26)
	box.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.TextColor3 = Color3.fromRGB(240, 240, 240)
	box.PlaceholderText = placeholder
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = parent
	return box
end

local banner = Instance.new("TextLabel")
banner.Name = "TestMode"
banner.Size = UDim2.fromOffset(150, 22)
banner.Position = UDim2.fromOffset(8, 8)
banner.BackgroundColor3 = Color3.fromRGB(150, 45, 35)
banner.Font = Enum.Font.GothamBold
banner.TextSize = 13
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Text = "TEST MODE"
banner.Parent = gui
local toggle = button(gui, "Dev panel", function() end)
toggle.Size = UDim2.fromOffset(150, 24)
toggle.Position = UDim2.fromOffset(8, 34)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Position = UDim2.fromOffset(8, 64)
panel.Size = UDim2.new(0, 320, 0.72, 0)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, 0, 0, 28)
tabs.BackgroundTransparency = 1
tabs.Parent = panel
local body = Instance.new("ScrollingFrame")
body.Position = UDim2.fromOffset(0, 30)
body.Size = UDim2.new(1, 0, 1, -118)
body.BackgroundTransparency = 1
body.ScrollBarThickness = 6
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new()
body.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingTop = UDim.new(0, 4)
pad.Parent = body
local readout = label(panel, "", 78)
readout.Position = UDim2.new(0, 6, 1, -82)
readout.Size = UDim2.new(1, -12, 0, 78)
readout.TextYAlignment = Enum.TextYAlignment.Top

local catalog, snap, armed = nil, nil, {}
local travelState = {}
local function call(command, args)
	local ok, result = pcall(function()
		return remote:InvokeServer({ Command = command, Args = args })
	end)
	if not ok or type(result) ~= "table" then readout.Text = "Command failed" return nil end
	if result.Error then readout.Text = result.Error else readout.Text = result.Message or "Done" end
	return result
end
local function confirm(command, args, view)
	local now = os.clock()
	if not armed[command] or now - armed[command] > 4 then
		armed[command] = now
		view.Text = "Click again to confirm"
		return
	end
	armed[command] = nil
	args = args or {}
	args.Confirm = true
	call(command, args)
	view.Text = command
end
local function numberBox(placeholder)
	return field(body, placeholder)
end
local function choice(values, current)
	local index = 1
	for i, value in values do if value == current then index = i end end
	local view = button(body, tostring(values[index]), function() end)
	view.Activated:Connect(function()
		index = index % #values + 1
		view.Text = tostring(values[index])
	end)
	return function() return values[index] end
end

local function clear()
	for _, child in body:GetChildren() do if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end end
end
local function showReadout()
	if not snap then return end
	local pet = snap.Pet
	readout.Text = string.format("%s (%d)  %s  %s\nPower %g   Cash %g   Tier %s   Slow %s\nSpeed %g  carry %g  override %s\n%s",
		snap.Name, snap.UserId, snap.Backend, snap.Base, snap.Power, snap.Cash, tostring(snap.TrainerTier),
		tostring(snap.SlowMode), snap.EffectiveSpeed or 0, snap.AppliedSlowdown or 0,
		if snap.SpeedOverride and snap.SpeedOverride >= 0 then tostring(snap.SpeedOverride) else "off",
		if pet then pet.Form .. " stage " .. pet.Stage .. " growth " .. pet.Growth else "No pet")
end

local pages = {}
function pages.Player()
	label(body, "Power, Cash and Speed use the live session. Speed overrides are not saved.")
	local power = numberBox("Power value")
	button(body, "Set Power", function() call("SetPower", { Value = tonumber(power.Text) }) end)
	button(body, "Add Power", function() call("AddPower", { Value = tonumber(power.Text) }) end)
	button(body, "Reset Power", function() call("ResetPower") end)
	local presets = {}
	for _, preset in catalog.Presets.Power do table.insert(presets, preset.Id) end
	local preset = choice(presets, "0")
	button(body, "Apply Power preset", function() call("SetPower", { Preset = preset() }) end)
	local cash = numberBox("Cash value")
	button(body, "Set Cash", function() call("SetCash", { Value = tonumber(cash.Text) }) end)
	button(body, "Add Cash", function() call("AddCash", { Value = tonumber(cash.Text) }) end)
	button(body, "Reset Cash", function() call("ResetCash") end)
	button(body, "Cash for next trainer", function() call("CashForNext") end)
	local speeds = {}
	for _, speed in catalog.Presets.Speed do table.insert(speeds, tostring(speed)) end
	local speed = choice(speeds, "16")
	button(body, "Override base speed", function() call("SetSpeedOverride", { Speed = tonumber(speed()) }) end)
	button(body, "Clear speed override", function() call("ClearOverrides") end)
	button(body, "Slow Mode on", function() call("SetSlowMode", { Enabled = true }) end)
	button(body, "Slow Mode off", function() call("SetSlowMode", { Enabled = false }) end)
	button(body, "Reset character", function() call("ResetCharacter") end)
end
function pages.Pets()
	label(body, "Changes keep the owned pet key. Invalid stage overrides are marked as fixtures.")
	local ids = {}
	for _, pet in catalog.Pets do table.insert(ids, pet.Id) end
	local pet = choice(ids, ids[1])
	button(body, "Equip owned pet", function() call("SelectPet", { Id = pet() }) end)
	button(body, "Create test pet", function() call("CreatePet", { Id = pet() }) end)
	local growth = numberBox("Growth")
	button(body, "Set Growth", function() call("SetGrowth", { Value = tonumber(growth.Text) }) end)
	local stage = choice({ "0", "1", "2", "3", "4", "5" }, "1")
	button(body, "Set stage from a real form", function() call("SetStage", { Stage = tonumber(stage()) }) end)
	button(body, "Force stage fixture", function() call("SetStage", { Stage = tonumber(stage()), Override = true }) end)
	local flesh, flora, mineral = numberBox("Flesh"), numberBox("Floral"), numberBox("Mineral")
	button(body, "Set affinities", function()
		call("SetAffinities", { Flesh = tonumber(flesh.Text) or 0, Flora = tonumber(flora.Text) or 0, Mineral = tonumber(mineral.Text) or 0 })
	end)
	local rarity = choice(catalog.Rarities, "Common")
	button(body, "Set rarity", function() call("SetRarity", { Rarity = rarity() }) end)
	local branch = field(body, "Branch id, blank for the eligible one")
	button(body, "Apply eligible evolution", function()
		local id = branch.Text
		call("ApplyEvolution", if id ~= "" then { BranchId = id } else {})
	end)
	local mutations = choice(catalog.Mutations, catalog.Mutations[1])
	button(body, "Add mutation", function() call("AddMutation", { Id = mutations() }) end)
	button(body, "Remove mutation", function() call("RemoveMutation", { Id = mutations() }) end)
	local family = choice(catalog.Families, catalog.Families[1])
	button(body, "Add catalyst family", function() call("SetFamily", { Id = family(), Enabled = true }) end)
	button(body, "Remove catalyst family", function() call("SetFamily", { Id = family(), Enabled = false }) end)
	local reset = button(body, "Reset pet", function() end)
	reset.Activated:Connect(function() confirm("ResetPet", {}, reset) end)
	label(body, "Eligible branches, ascension and awakening are in the readout after refresh.")
end
function pages.Items()
	local areas = {}
	for _, area in catalog.Areas do table.insert(areas, area.Id) end
	local area = choice(areas, "Grasslands")
	local resources = {}
	for _, item in catalog.Resources do table.insert(resources, item.Id) end
	local resource = choice(resources, "RawMeat")
	button(body, "Spawn in world", function() call("SpawnResource", { Area = area(), Resource = resource() }) end)
	button(body, "Give carried item", function() call("GiveResource", { Area = area(), Resource = resource() }) end)
	button(body, "Give Raw Meat", function() call("GivePreset", { Id = "RawMeat" }) end)
	button(body, "Give Ancient Bone", function() call("GivePreset", { Id = "AncientBone" }) end)
	button(body, "Give hybrid feed", function() call("GivePreset", { Id = "Hybrid" }) end)
	button(body, "Give Primal Catalyst", function() call("GivePreset", { Id = "Catalyst" }) end)
	button(body, "Give evolution feed", function() call("GivePreset", { Id = "Evolution" }) end)
	button(body, "Drop carry", function() call("DropCarry") end)
	button(body, "Clear carry", function() call("ClearCarry") end)
	button(body, "Feed preview", function()
		local result = call("FeedPreview")
		if result and result.Preview then gui:SetAttribute("FeedTicket", result.Preview.Ticket) readout.Text = result.Preview.Reason end
	end)
	button(body, "Confirm feed", function() call("FeedConfirm", { Ticket = gui:GetAttribute("FeedTicket") }) end)
	local reset = button(body, "Reset test resources", function() end)
	reset.Activated:Connect(function() confirm("ResetResources", {}, reset) end)
end
function pages.Trainers()
	local tiers = {}
	for _, trainer in catalog.Trainers do table.insert(tiers, tostring(trainer.Tier) .. " " .. trainer.Name) end
	local tier = choice(tiers, tiers[1])
	button(body, "Set tier", function() call("SetTrainerTier", { Tier = tonumber(string.match(tier(), "%d+")) }) end)
	button(body, "Give cash and buy next", function()
		call("CashForNext")
		call("BuyTrainer")
	end)
	button(body, "Buy next with current cash", function() call("BuyTrainer") end)
	button(body, "Start training", function() call("StartTraining") end)
	button(body, "Stop training", function() call("StopTraining") end)
	local reset = button(body, "Reset to tier 1", function() end)
	reset.Activated:Connect(function() confirm("ResetTrainer", {}, reset) end)
end
function pages.Guardians()
	local areas = {}
	for _, area in catalog.Areas do table.insert(areas, area.Id) end
	local area = choice(areas, "Grasslands")
	button(body, "Teleport to biome", function() call("Teleport", { Area = area() }) end)
	button(body, "Reset guardians", function() call("ResetGuardians") end)
	for _, kind in { "Ordinary", "Heavy", "Cursed", "Close", "Long" } do
		button(body, kind .. " theft", function() call("GuardianScenario", { Area = area(), Kind = kind }) end)
	end
	button(body, "Catch recovery", function() call("CatchRecovery", { Area = area() }) end)
	button(body, "Two carriers", function() call("TwoCarriers", { Area = area() }) end)
	button(body, "Reset scenario", function() call("ResetScenario") end)
	label(body, "Guardian state, distance, hazard and recovery refresh in the readout.")
end
function pages.Travel()
	label(body, "Human timing uses your controls. Scripted timing moves the character for you. They stay in separate lists.")
	local areas = {}
	for _, area in catalog.Areas do table.insert(areas, area.Id) end
	local area = choice(areas, "Grasslands")
	local kind = choice({ "Ordinary", "Heavy", "Cursed" }, "Ordinary")
	local speed = choice({ "16", "18", "22", "30" }, "16")
	local position = choice({ "Near", "Middle", "Far" }, "Middle")
	local running = false
	local startedAt, serverStart, pickupAt, wakeAt, safeAt, catches = nil, nil, nil, nil, nil, 0
	travelState.running = function() return running end
	travelState.sample = function()
		if not running or not startedAt or not player.Character then return end
		local carried = player:GetAttribute("CarriedInstanceId")
		if carried and carried ~= "" and not pickupAt then pickupAt = os.clock() end
		local boundary = workspace:FindFirstChild("SafeZoneBoundary", true)
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if boundary and rootPart and rootPart.Position.X < boundary.Position.X and not safeAt then safeAt = os.clock() end
		local guardiansFolder = workspace:FindFirstChild("GeneratedGameplay")
		guardiansFolder = guardiansFolder and guardiansFolder:FindFirstChild("Guardians")
		if guardiansFolder then
			for _, model in guardiansFolder:GetChildren() do
				local part = model:IsA("Model") and model.PrimaryPart
				local state = part and part:GetAttribute("GuardianState")
				if state == "WAKING" or state == "PURSUING" or state == "WARNING" or state == "HAZARD" then
					if not wakeAt then wakeAt = os.clock() end
				end
			end
		end
		local reason = tostring(player:GetAttribute("DropReason") or "")
		local dropped = player:GetAttribute("DropTick")
		if type(dropped) == "number" and serverStart and dropped >= serverStart and string.find(reason, "Guardian", 1, true) then catches = 1 end
	end
	button(body, "Start human timer", function()
		running = true
		startedAt, serverStart, pickupAt, wakeAt, safeAt, catches = os.clock(), workspace:GetServerTimeNow(), nil, nil, nil, 0
		readout.Text = "Human timer running"
	end)
	button(body, "Stop human timer", function()
		if not startedAt then return end
		running = false
		local now = os.clock()
		call("TravelSubmit", {
			Area = area(), Outbound = if pickupAt then pickupAt - startedAt else -1, Pickup = if pickupAt then pickupAt - startedAt else -1,
			Wake = if wakeAt then wakeAt - startedAt else -1,
			Chase = if wakeAt and safeAt then safeAt - wakeAt else -1,
			Safety = if safeAt then safeAt - startedAt else -1,
			ReturnBase = -1, RoundTrip = now - startedAt,
			Speed = snap and snap.EffectiveSpeed or 0,
			Result = if catches > 0 then "Catch" elseif safeAt then "Escape" else "Incomplete",
			Catches = catches,
		})
		startedAt = nil
	end)
	local run = button(body, "Run scripted cell", function() end)
	run.Activated:Connect(function()
		confirm("TravelScripted", { Area = area(), Kind = kind(), Speed = tonumber(speed()), Slow = snap and snap.SlowMode == true, Position = position() }, run)
	end)
	button(body, "Cancel scripted run", function() call("TravelCancel") end)
	button(body, "Clear measurements", function() call("TravelClear") end)
	local export = field(body, "Export appears here")
	export.TextEditable = true
	button(body, "Export JSON", function()
		local result = call("TravelExport")
		if result and result.Export then export.Text = result.Export readout.Text = "Select the box and copy" end
	end)
	local seed = numberBox("Seed")
	button(body, "Set recorded seed", function() call("SetSeed", { Seed = tonumber(seed.Text) }) end)
end
function pages.Scenarios()
	label(body, "Each scenario uses live definitions. Click twice to run it.")
	for _, id in catalog.Scenarios do
		local view = button(body, id, function() end)
		view.Activated:Connect(function() confirm("Scenario", { Id = id }, view) end)
	end
end

local names = { "Player", "Pets", "Items", "Trainers", "Guardians", "Travel", "Scenarios" }
local function render(name)
	clear()
	pages[name]()
end
for index, name in names do
	local tab = Instance.new("TextButton")
	tab.Size = UDim2.fromOffset(44, 24)
	tab.Position = UDim2.fromOffset(4 + (index - 1) * 45, 2)
	tab.BackgroundColor3 = Color3.fromRGB(36, 44, 56)
	tab.Font = Enum.Font.Gotham
	tab.TextSize = 11
	tab.TextColor3 = Color3.new(1, 1, 1)
	tab.Text = string.sub(name, 1, 4)
	tab.Parent = tabs
	tab.Activated:Connect(function() render(name) end)
end
toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible and not catalog then
		local result = call("Catalog")
		catalog = result and result.Catalog
		if catalog then render("Player") end
	end
end)
task.spawn(function()
	while gui.Parent do
		if panel.Visible then
			local ok, result = pcall(function() return remote:InvokeServer({ Command = "Snapshot" }) end)
			if ok and type(result) == "table" and result.Ok then
				snap = result
				local guardian = result.Guardians and result.Guardians[1]
				local extra = ""
				if guardian then
					extra = string.format("\n%s %s  dist %s  home %s  hazard %s  rec %.1f", guardian.Guardian, guardian.State,
						tostring(guardian.Distance), tostring(guardian.HomeDistance), guardian.Hazard, guardian.Recovery)
				end
				if result.Job and not result.Job.Done then extra ..= "\nScripted: " .. tostring(result.Job.Progress) end
				if result.Pet and result.Pet.Eligible and #result.Pet.Eligible > 0 then
					extra ..= "\nEligible: " .. table.concat(result.Pet.Eligible, ", ")
				end
				if result.Pet and result.Pet.Ascension then
					extra ..= "\nAscension " .. tostring(result.Pet.Ascension.State) .. "  Awakening " .. tostring(result.Pet.Awakening.State)
				end
				showReadout()
				readout.Text ..= extra
			end
		end
		task.wait(0.75)
		if travelState.sample then travelState.sample() end
	end
end)
print("[DevTest] panel ready for " .. player.Name)
