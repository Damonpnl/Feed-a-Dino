--!strict

--[[
	Read-only Lineage app for the Research Tablet.
	Displays server creature snapshots; never mutates creature state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LineagePresentation = require(Shared:WaitForChild("tablet"):WaitForChild("LineagePresentation"))

local LineageAppController = {}

local ACCENT = Color3.fromRGB(80, 210, 220)
local PANEL = Color3.fromRGB(14, 22, 26)
local TEXT = Color3.fromRGB(230, 240, 245)
local MUTED = Color3.fromRGB(160, 175, 180)

local page: Frame
local scroll: ScrollingFrame
local emptyLabel: TextLabel
local contentFrame: Frame
local viewport: ViewportFrame
local worldModel: WorldModel
local camera: Camera
local nameLabel: TextLabel
local stageRarityLabel: TextLabel
local growthLabel: TextLabel
local growthFill: Frame
local statusLabel: TextLabel
local profileLabel: TextLabel
local historyLabel: TextLabel
local nextLabel: TextLabel

local remotesFolder: Folder? = nil
local currentSnapshot: any = nil
local currentViewportFormId: string? = nil
local currentClone: Instance? = nil

local function ensureRemotes(): Folder?
	if remotesFolder and remotesFolder.Parent then
		return remotesFolder
	end
	local folder = ReplicatedStorage:FindFirstChild("TabletCreatureRemotes")
	if folder and folder:IsA("Folder") then
		remotesFolder = folder
		return folder
	end
	return nil
end

local function clearViewport()
	if currentClone ~= nil then
		currentClone:Destroy()
		currentClone = nil
	end
	currentViewportFormId = nil
end

local function fitCameraToInstance(target: Instance)
	local cf: CFrame
	local size: Vector3
	if target:IsA("Model") then
		cf, size = target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		cf = target.CFrame
		size = target.Size
	else
		local part = target:FindFirstChildWhichIsA("BasePart", true)
		if part == nil then
			return
		end
		cf = part.CFrame
		size = part.Size
	end

	local extent = math.max(size.X, size.Y, size.Z)
	local distance = math.max(4, extent * 1.8)
	local lookAt = cf.Position
	camera.CFrame = CFrame.new(lookAt + Vector3.new(distance * 0.75, distance * 0.45, distance * 0.85), lookAt)
	camera.FieldOfView = 35
end

local function setViewportForm(formId: string?)
	if formId == nil then
		clearViewport()
		return
	end
	if formId == currentViewportFormId and currentClone ~= nil then
		return
	end
	clearViewport()

	local folder = ReplicatedStorage:FindFirstChild("CreaturePresentationTemplates")
	local template = folder and folder:FindFirstChild(formId)
	if template == nil then
		nameLabel.Text = LineagePresentation.getCreatureDisplayName(formId)
		return
	end

	local clone = template:Clone()
	clone.Parent = worldModel
	currentClone = clone
	currentViewportFormId = formId
	fitCameraToInstance(clone)
end

local function setHasCreature(visible: boolean)
	emptyLabel.Visible = not visible
	contentFrame.Visible = visible
end

local function buildAffinityText(snapshot: any): string
	local lines = { "AFFINITIES" }
	for _, row in LineagePresentation.sortedAffinityRows(snapshot.stageAffinities) do
		table.insert(lines, string.format("%-8s %g", row.id, row.value))
	end
	local heritage = snapshot.heritageAffinities
	if heritage ~= nil then
		table.insert(lines, "")
		table.insert(lines, "HERITAGE")
		for _, row in LineagePresentation.sortedAffinityRows(heritage) do
			if row.value > 0 then
				table.insert(lines, string.format("%-8s %g", row.id, row.value))
			end
		end
	end
	return table.concat(lines, "\n")
end

local function buildProfileText(snapshot: any): string
	local dominant = LineagePresentation.getAffinityDisplayName(snapshot.dominantAffinity)
	local influence = LineagePresentation.getInfluenceDisplayName(snapshot.strongestInfluence)
	local qual = tostring(snapshot.influenceQualification or "None")
	local quality = tonumber(snapshot.evolutionQuality) or 0
	local qualityLabel = LineagePresentation.getQualityLabel(quality)

	local specializationLine = if qual == "None" or influence == "None"
		then "None"
		else string.format("%s · %s", influence, qual)

	return table.concat({
		"CURRENT PROFILE",
		string.format("Dominant Affinity     %s", dominant),
		string.format("Specialization       %s", specializationLine),
		string.format("Evolution Quality    %d (%s)", math.floor(quality), qualityLabel),
		"",
		buildAffinityText(snapshot),
	}, "\n")
end

local function buildHistoryText(snapshot: any): string
	local history = snapshot.lineageHistory
	if typeof(history) ~= "table" or #history == 0 then
		return "LINEAGE\nNo recorded history."
	end
	local lines = { "LINEAGE" }
	for index, entry in history do
		local display = entry.displayName or LineagePresentation.getCreatureDisplayName(entry.formId)
		local rarity = if entry.rarityAtStage then (" · " .. tostring(entry.rarityAtStage)) else ""
		table.insert(lines, string.format("%s%s", display, rarity))
		if index < #history then
			local nextEntry = history[index + 1]
			table.insert(lines, LineagePresentation.formatHistoryConnector(nextEntry))
		end
	end
	return table.concat(lines, "\n")
end

local function buildNextText(snapshot: any): string
	local nextInfo = snapshot.nextEvolution
	if nextInfo == nil then
		return "NEXT EVOLUTION\nContinue feeding and researching."
	end
	if nextInfo.isTerminal == true then
		return "NEXT EVOLUTION\nMAX CURRENT STAGE\nThis specimen has reached the current research ceiling."
	end

	local lines = { "NEXT EVOLUTION", "POSSIBLE NEXT FORMS" }
	local routes = nextInfo.publicRoutes
	if typeof(routes) == "table" then
		for _, route in routes do
			table.insert(lines, string.format(
				"%s → %s",
				tostring(route.affinityId),
				tostring(route.displayName or "???")
			))
		end
	end

	local specialized = tostring(nextInfo.specializedStatus or "None")
	table.insert(lines, "")
	table.insert(lines, "SPECIALIZED RESPONSE")
	if specialized == "ReadyHidden" then
		table.insert(lines, "Signal detected — identity classified")
	elseif specialized == "Developing" then
		table.insert(lines, "Developing")
	elseif specialized == "Undiscovered" then
		table.insert(lines, "Undiscovered")
	else
		table.insert(lines, "None")
	end

	table.insert(lines, "")
	table.insert(lines, "UNKNOWN RESEARCH DATA")
	table.insert(lines, "Hidden catalysts remain offline.")
	return table.concat(lines, "\n")
end

function LineageAppController.applySnapshot(snapshot: any)
	currentSnapshot = snapshot
	if typeof(snapshot) ~= "table" or snapshot.hasCreature ~= true then
		setHasCreature(false)
		clearViewport()
		return
	end

	setHasCreature(true)
	local formId = tostring(snapshot.formId or "")
	nameLabel.Text = tostring(snapshot.displayName or LineagePresentation.getCreatureDisplayName(formId))
	stageRarityLabel.Text = string.format(
		"Stage %s · %s",
		tostring(snapshot.stage),
		LineagePresentation.getRarityText(snapshot.rarity)
	)
	stageRarityLabel.TextColor3 = LineagePresentation.getRarityColor(snapshot.rarity)

	local isTerminal = snapshot.isTerminalStage == true
	local growth = tonumber(snapshot.growth) or 0
	local required = snapshot.requiredGrowth
	growthLabel.Text = "GROWTH  " .. LineagePresentation.formatGrowth(growth, required, isTerminal)
	local ratio = LineagePresentation.getGrowthRatio(growth, required, isTerminal)
	growthFill.Size = UDim2.new(ratio, 0, 1, 0)

	local status = snapshot.evolutionStatus
	local reason = if typeof(status) == "table" then status.reason else nil
	statusLabel.Text = "EVOLUTION STATUS\n" .. LineagePresentation.getEvolutionStatusText(reason)

	profileLabel.Text = buildProfileText(snapshot)
	historyLabel.Text = buildHistoryText(snapshot)
	nextLabel.Text = buildNextText(snapshot)

	setViewportForm(formId)
end

function LineageAppController.requestSnapshot()
	local folder = ensureRemotes()
	if folder == nil then
		return
	end
	local remote = folder:FindFirstChild("RequestCreatureSnapshot")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end

function LineageAppController.onShown()
	LineageAppController.requestSnapshot()
end

function LineageAppController.mount(parent: Frame): Frame
	ensureRemotes()

	page = Instance.new("Frame")
	page.Name = "LineagePage"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = parent

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -16, 0, 28)
	header.Position = UDim2.fromOffset(8, 4)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 20
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = ACCENT
	header.Text = "LINEAGE DATABASE"
	header.Parent = page

	emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyState"
	emptyLabel.Size = UDim2.new(1, -24, 1, -48)
	emptyLabel.Position = UDim2.fromOffset(12, 40)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextSize = 16
	emptyLabel.TextWrapped = true
	emptyLabel.TextColor3 = MUTED
	emptyLabel.Text = "NO ACTIVE SPECIMEN\n\nAssign or create a creature at your base\nto begin lineage analysis."
	emptyLabel.Visible = true
	emptyLabel.Parent = page

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ContentScroll"
	scroll.Size = UDim2.new(1, -12, 1, -40)
	scroll.Position = UDim2.fromOffset(6, 36)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = page

	contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, -8, 0, 0)
	contentFrame.AutomaticSize = Enum.AutomaticSize.Y
	contentFrame.BackgroundTransparency = 1
	contentFrame.Visible = false
	contentFrame.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = contentFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = contentFrame

	local specimen = Instance.new("Frame")
	specimen.Name = "SpecimenPanel"
	specimen.Size = UDim2.new(1, 0, 0, 210)
	specimen.BackgroundColor3 = PANEL
	specimen.BackgroundTransparency = 0.15
	specimen.BorderSizePixel = 0
	specimen.LayoutOrder = 1
	specimen.Parent = contentFrame
	local specimenCorner = Instance.new("UICorner")
	specimenCorner.CornerRadius = UDim.new(0, 8)
	specimenCorner.Parent = specimen

	local specimenTitle = Instance.new("TextLabel")
	specimenTitle.Size = UDim2.new(1, -16, 0, 22)
	specimenTitle.Position = UDim2.fromOffset(8, 6)
	specimenTitle.BackgroundTransparency = 1
	specimenTitle.Font = Enum.Font.GothamBold
	specimenTitle.TextSize = 14
	specimenTitle.TextXAlignment = Enum.TextXAlignment.Left
	specimenTitle.TextColor3 = ACCENT
	specimenTitle.Text = "CURRENT SPECIMEN"
	specimenTitle.Parent = specimen

	viewport = Instance.new("ViewportFrame")
	viewport.Name = "CreatureViewport"
	viewport.Size = UDim2.new(0.42, -12, 1, -70)
	viewport.Position = UDim2.fromOffset(8, 32)
	viewport.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
	viewport.BorderSizePixel = 0
	viewport.Parent = specimen
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 8)
	viewportCorner.Parent = viewport

	worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.58, -16, 0, 28)
	nameLabel.Position = UDim2.new(0.42, 8, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 22
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = TEXT
	nameLabel.Text = ""
	nameLabel.Parent = specimen

	stageRarityLabel = Instance.new("TextLabel")
	stageRarityLabel.Size = UDim2.new(0.58, -16, 0, 22)
	stageRarityLabel.Position = UDim2.new(0.42, 8, 0, 72)
	stageRarityLabel.BackgroundTransparency = 1
	stageRarityLabel.Font = Enum.Font.Gotham
	stageRarityLabel.TextSize = 16
	stageRarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	stageRarityLabel.TextColor3 = MUTED
	stageRarityLabel.Text = ""
	stageRarityLabel.Parent = specimen

	local growthPanel = Instance.new("Frame")
	growthPanel.Name = "GrowthPanel"
	growthPanel.Size = UDim2.new(0.58, -16, 0, 54)
	growthPanel.Position = UDim2.new(0.42, 8, 0, 110)
	growthPanel.BackgroundColor3 = Color3.fromRGB(18, 28, 34)
	growthPanel.BorderSizePixel = 0
	growthPanel.Parent = specimen
	local growthCorner = Instance.new("UICorner")
	growthCorner.CornerRadius = UDim.new(0, 6)
	growthCorner.Parent = growthPanel

	growthLabel = Instance.new("TextLabel")
	growthLabel.Size = UDim2.new(1, -12, 0, 20)
	growthLabel.Position = UDim2.fromOffset(6, 4)
	growthLabel.BackgroundTransparency = 1
	growthLabel.Font = Enum.Font.GothamBold
	growthLabel.TextSize = 13
	growthLabel.TextXAlignment = Enum.TextXAlignment.Left
	growthLabel.TextColor3 = TEXT
	growthLabel.Text = "GROWTH"
	growthLabel.Parent = growthPanel

	local growthTrack = Instance.new("Frame")
	growthTrack.Size = UDim2.new(1, -12, 0, 12)
	growthTrack.Position = UDim2.fromOffset(6, 30)
	growthTrack.BackgroundColor3 = Color3.fromRGB(30, 40, 46)
	growthTrack.BorderSizePixel = 0
	growthTrack.Parent = growthPanel
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = growthTrack

	growthFill = Instance.new("Frame")
	growthFill.Name = "Fill"
	growthFill.Size = UDim2.new(0, 0, 1, 0)
	growthFill.BackgroundColor3 = ACCENT
	growthFill.BorderSizePixel = 0
	growthFill.Parent = growthTrack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = growthFill

	local function makeTextPanel(name: string, order: number, minHeight: number): TextLabel
		local panel = Instance.new("Frame")
		panel.Name = name
		panel.Size = UDim2.new(1, 0, 0, minHeight)
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.BackgroundColor3 = PANEL
		panel.BackgroundTransparency = 0.15
		panel.BorderSizePixel = 0
		panel.LayoutOrder = order
		panel.Parent = contentFrame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = panel

		local label = Instance.new("TextLabel")
		label.Name = "Body"
		label.Size = UDim2.new(1, -16, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Position = UDim2.fromOffset(8, 8)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.TextColor3 = TEXT
		label.Text = ""
		label.Parent = panel

		local bottomPad = Instance.new("UIPadding")
		bottomPad.PaddingBottom = UDim.new(0, 10)
		bottomPad.Parent = panel
		return label
	end

	statusLabel = makeTextPanel("StatusPanel", 2, 56)
	profileLabel = makeTextPanel("ProfilePanel", 3, 140)
	historyLabel = makeTextPanel("HistoryPanel", 4, 100)
	nextLabel = makeTextPanel("NextPanel", 5, 120)

	return page
end

return LineageAppController
