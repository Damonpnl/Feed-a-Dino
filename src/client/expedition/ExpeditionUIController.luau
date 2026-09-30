--!strict

--[[
	Minimal programmatic expedition HUD. No Studio UI assets required.
]]

local Players = game:GetService("Players")

local ExpeditionUIController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui: ScreenGui
local fieldBagFrame: Frame
local fieldBagLabel: TextLabel
local questFrame: Frame
local questLabel: TextLabel
local toastLabel: TextLabel

local function createLabel(parent: Instance, name: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Size = size
	label.Position = position
	label.Visible = false
	label.Parent = parent
	return label
end

function ExpeditionUIController.mount()
	local existing = playerGui:FindFirstChild("ExpeditionHud")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "ExpeditionHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	fieldBagFrame = Instance.new("Frame")
	fieldBagFrame.Name = "FieldBag"
	fieldBagFrame.BackgroundTransparency = 0.3
	fieldBagFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 18)
	fieldBagFrame.BorderSizePixel = 0
	fieldBagFrame.Size = UDim2.fromOffset(240, 180)
	fieldBagFrame.Position = UDim2.new(0, 20, 0.35, 0)
	fieldBagFrame.Visible = false
	fieldBagFrame.Parent = gui

	fieldBagLabel = Instance.new("TextLabel")
	fieldBagLabel.BackgroundTransparency = 1
	fieldBagLabel.Size = UDim2.fromScale(1, 1)
	fieldBagLabel.Font = Enum.Font.Gotham
	fieldBagLabel.TextSize = 15
	fieldBagLabel.TextColor3 = Color3.fromRGB(235, 245, 230)
	fieldBagLabel.TextXAlignment = Enum.TextXAlignment.Left
	fieldBagLabel.TextYAlignment = Enum.TextYAlignment.Top
	fieldBagLabel.TextWrapped = true
	fieldBagLabel.Parent = fieldBagFrame

	questFrame = Instance.new("Frame")
	questFrame.Name = "QuestTracker"
	questFrame.BackgroundTransparency = 0.3
	questFrame.BackgroundColor3 = Color3.fromRGB(22, 18, 12)
	questFrame.BorderSizePixel = 0
	questFrame.Size = UDim2.fromOffset(280, 80)
	questFrame.Position = UDim2.new(1, -300, 0.2, 0)
	questFrame.Visible = false
	questFrame.Parent = gui

	questLabel = Instance.new("TextLabel")
	questLabel.BackgroundTransparency = 1
	questLabel.Size = UDim2.fromScale(1, 1)
	questLabel.Font = Enum.Font.GothamBold
	questLabel.TextSize = 15
	questLabel.TextColor3 = Color3.fromRGB(255, 236, 200)
	questLabel.TextXAlignment = Enum.TextXAlignment.Left
	questLabel.TextYAlignment = Enum.TextYAlignment.Top
	questLabel.TextWrapped = true
	questLabel.Parent = questFrame

	toastLabel = createLabel(gui, "Toast", UDim2.fromOffset(360, 80), UDim2.new(0.5, -180, 0.72, 0))
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.TextYAlignment = Enum.TextYAlignment.Center
end

local function showToast(title: string, body: string, duration: number?)
	toastLabel.Text = title .. "\n" .. body
	toastLabel.Visible = true
	task.delay(duration or 3.5, function()
		if toastLabel.Text == title .. "\n" .. body then
			toastLabel.Visible = false
		end
	end)
end

function ExpeditionUIController.setInZone(inZone: boolean)
	fieldBagFrame.Visible = inZone
	if not inZone then
		questFrame.Visible = false
	end
end

function ExpeditionUIController.updateFieldBag(snapshot: any)
	local lines = { "FIELD BAG", "" }
	local materials = snapshot.materials or {}
	local keys = {}
	for feedId in materials do
		table.insert(keys, feedId)
	end
	table.sort(keys)
	for _, feedId in keys do
		table.insert(lines, string.format("%s ×%d", feedId, materials[feedId]))
	end
	if #keys == 0 then
		table.insert(lines, "(empty)")
	end
	table.insert(lines, "")
	table.insert(lines, string.format("%d ITEMS", snapshot.totalItems or 0))
	fieldBagLabel.Text = table.concat(lines, "\n")
end

function ExpeditionUIController.updateQuest(snapshot: any)
	if snapshot == nil or snapshot.questId == nil or snapshot.status ~= "Active" then
		questFrame.Visible = false
		return
	end
	questFrame.Visible = true
	questLabel.Text = string.format(
		"EXPEDITION QUEST\n%s\n%s: %d / %d",
		snapshot.displayName or "QUEST",
		snapshot.objectiveText or "Objective",
		snapshot.progress or 0,
		snapshot.target or 0
	)
end

function ExpeditionUIController.showNotification(payload: any)
	showToast(payload.title or "NOTICE", payload.body or "")
end

function ExpeditionUIController.showBankingSummary(payload: any)
	local lines = {}
	local materials = payload.materials or {}
	local keys = {}
	for feedId in materials do
		table.insert(keys, feedId)
	end
	table.sort(keys)
	for _, feedId in keys do
		table.insert(lines, string.format("%s ×%d", feedId, materials[feedId]))
	end
	if #lines == 0 then
		table.insert(lines, "(nothing to secure)")
	end
	showToast(payload.title or "LOOT SECURED", table.concat(lines, "\n"), 4)
	fieldBagFrame.Visible = false
end

function ExpeditionUIController.showLossSummary(payload: any)
	local lines = {}
	local materials = payload.materials or {}
	local keys = {}
	for feedId in materials do
		table.insert(keys, feedId)
	end
	table.sort(keys)
	for _, feedId in keys do
		table.insert(lines, string.format("%s ×%d dropped", feedId, materials[feedId]))
	end
	if #lines == 0 then
		table.insert(lines, "No materials dropped")
	end
	showToast(payload.title or "BAG DROPPED", table.concat(lines, "\n"), 4)
end

function ExpeditionUIController.showEventAnnouncement(payload: any)
	showToast(payload.title or "EVENT", payload.body or "", 5)
end

return ExpeditionUIController
