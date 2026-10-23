--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Format = require(game.ReplicatedStorage.Shared.NumberFormat)

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return 0
end

local function textAttribute(name: string): string
	local value = player:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end
	return ""
end

local gui = Instance.new("ScreenGui")
gui.Name = "MonsterHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BackgroundTransparency = 0.25
panel.Position = UDim2.fromOffset(16, 56)
panel.Size = UDim2.fromOffset(280, 210)
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(12, 8)
label.Size = UDim2.new(1, -24, 1, -16)
label.Font = Enum.Font.GothamMedium
label.TextColor3 = Color3.fromRGB(240, 240, 240)
label.TextSize = 16
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = true
label.Parent = panel

local carry = Instance.new("TextLabel")
carry.Name = "CarryCard"
carry.AnchorPoint = Vector2.new(0.5, 1)
carry.Position = UDim2.new(0.5, 0, 1, -70)
carry.Size = UDim2.new(0.55, 0, 0, 64)
carry.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
carry.BackgroundTransparency = 0.15
carry.TextColor3 = Color3.new(1, 1, 1)
carry.Font = Enum.Font.GothamBold
carry.TextSize = 17
carry.TextWrapped = true
carry.Parent = gui
local toast = Instance.new("TextLabel")
toast.Name = "PowerNotice"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 96)
toast.Size = UDim2.new(0.65, 0, 0, 42)
toast.BackgroundColor3 = Color3.fromRGB(50, 25, 20)
toast.TextColor3 = Color3.fromRGB(255, 220, 125)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 23
toast.Visible = false
toast.Parent = gui
local noticeGeneration = 0
player:GetAttributeChangedSignal("PowerNoticeTick"):Connect(function()
	noticeGeneration += 1
	local generation = noticeGeneration
	toast.Text = textAttribute("PowerNotice")
	toast.Visible = true
	task.delay(2, function() if generation == noticeGeneration then toast.Visible = false end end)
end)

local function refresh()
	local carried = textAttribute("CarriedName")
	carry.Visible = carried ~= ""
	carry.Text = "◆ CARRYING " .. carried .. " · " .. textAttribute("CarriedRarity")
		.. "\nMovement −" .. Format.compact(numberAttribute("CarrySlowdown") * 100) .. "% · Drop: G / button"
	local carriedLine = if carried ~= "" then "Carrying: " .. carried .. "  (G to drop)" else "Hands empty  (G drops)"
	local mutations = textAttribute("Mutations")
	local mutationLine = if mutations ~= "" then "\nMutation: " .. mutations else ""
	label.Text = string.format(
		"%s\nGrowth %d / %d\nFlesh %d   Flora %d   Mineral %d\nPower %d    Cash %d    x%.1f%s\n%s\n%s",
		textAttribute("MonsterName") .. " · " .. textAttribute("PetStageLabel"),
		math.floor(numberAttribute("Growth")),
		math.floor(numberAttribute("GrowthRequired")),
		math.floor(numberAttribute("Flesh")),
		math.floor(numberAttribute("Flora")),
		math.floor(numberAttribute("Mineral")),
		math.floor(numberAttribute("Power")),
		math.floor(numberAttribute("Cash")),
		numberAttribute("Multiplier"),
		mutationLine,
		carriedLine,
		textAttribute("StatusMessage")
	)
end

player.AttributeChanged:Connect(refresh)
refresh()

-- Phase 4A: presentation only; the server owns the preview ticket and revalidates confirmation.
local Shared = game.ReplicatedStorage.Shared
local ResourceEffects = require(Shared.ResourceEffects)
local Resources = require(Shared.ResourceDefinitions)
local Rarities = require(Shared.RarityDefinitions)
local feedRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FeedInteraction") :: RemoteEvent
local feedPanel = Instance.new("Frame")
feedPanel.Name = "FeedPreview"
feedPanel.AnchorPoint = Vector2.new(0.5, 0.5)
feedPanel.Position = UDim2.fromScale(0.5, 0.5)
feedPanel.Size = UDim2.new(0.9, 0, 0.75, 0)
feedPanel.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
feedPanel.Visible = false
feedPanel.ZIndex = 10
feedPanel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(440, 340)
limit.Parent = feedPanel
local details = Instance.new("TextLabel")
details.Name = "Details"
details.Position = UDim2.fromOffset(12, 8)
details.Size = UDim2.new(1, -24, 1, -76)
details.BackgroundTransparency = 1
details.TextColor3 = Color3.new(1,1,1)
details.Font = Enum.Font.GothamMedium
details.TextSize = 17
details.TextWrapped = true
details.TextScaled = true
details.ZIndex = 11
details.Parent = feedPanel
local textLimit = Instance.new("UITextSizeConstraint")
textLimit.MinTextSize,textLimit.MaxTextSize = 12,19
textLimit.Parent = details
local function button(name: string, text: string, x: number): TextButton
	local b = Instance.new("TextButton")
	b.Name,b.Text = name,text
	b.Position = UDim2.new(x, 8, 1, -58)
	b.Size = UDim2.new(0.5, -16, 0, 48)
	b.Font,b.TextSize = Enum.Font.GothamBold,18
	b.ZIndex,b.Parent = 11,feedPanel
	return b
end
local confirm = button("Confirm", "FEED", 0)
local close = button("Close", "CLOSE", 0.5)
local ticket: string? = nil
local generation = 0
local pending = false
local function invalidate()
	if not feedPanel.Visible or not ticket then return end
	ticket = nil
	confirm.Text = "REFRESH"
	details.Text ..= "\nState changed. Refresh the preview."
end
for _,attribute in {"CarriedInstanceId","MonsterId","Growth","Flora","Flesh","Mineral","DataStatus","AssignedBaseName"} do
	player:GetAttributeChangedSignal(attribute):Connect(invalidate)
end
player.CharacterRemoving:Connect(function() ticket=nil feedPanel.Visible=false end)
close.Activated:Connect(function() ticket=nil feedPanel.Visible=false end)
confirm.Activated:Connect(function()
	if pending then return end
	pending = true
	confirm.Text = "WAIT…"
	feedRemote:FireServer(if ticket then "Confirm" else "Preview",ticket)
	ticket = nil
	task.delay(2,function() if pending then pending=false confirm.Text="REFRESH" end end)
end)
feedRemote.OnClientEvent:Connect(function(payload)
	if payload.Kind=="Evolution" then return end
	generation += 1
	local current = generation
	pending,ticket = false,nil
	feedPanel.Visible = true
	confirm.Text = "REFRESH"
	details.TextColor3 = Color3.new(1,1,1)
	if payload.Available then
		local definition = Resources.get(payload.ResourceId)
		local ok,effect = pcall(ResourceEffects.resolve,payload.Pet,definition)
		if not ok or not definition then details.Text="Preview unavailable. Please refresh." return end
		ticket = payload.Ticket
		confirm.Text = "FEED"
		details.TextColor3 = Rarities.getColor(definition.Rarity)
		details.Text = string.format("%s · %s\n%s\nGrowth: %g → %g (+%g)\nFlesh +%g   Floral +%g   Mineral +%g\n%s\n%s",
			definition.DisplayName,definition.Rarity,payload.PetName,effect.BeforeGrowth,payload.GrowthAfter or effect.After.Growth,
			effect.Delta.Growth,effect.Delta.Flesh,effect.Delta.Floral,effect.Delta.Mineral,effect.SpecialDescription,
			(payload.LegacyOutcome or "") .. "\nGrowth reserve: " .. Format.compact(payload.GrowthReserveAfter or 0))
		task.delay(30,function() if generation==current then invalidate() end end)
	else
		details.Text = payload.Reason or "Feeding unavailable"
	end
end)

-- One native choice panel; attributes restore the same saved choice after reconnect.
local HttpService=game:GetService("HttpService")
local Monsters=require(Shared.MonsterDefinitions)
local choices=Instance.new("ScrollingFrame")
choices.Name="EvolutionChoice"
choices.AnchorPoint=Vector2.new(0.5,0.5)
choices.Position=UDim2.fromScale(0.5,0.5)
choices.Size=UDim2.fromScale(0.9,0.7)
choices.BackgroundColor3=Color3.fromRGB(25,29,38)
choices.AutomaticCanvasSize=Enum.AutomaticSize.Y
choices.CanvasSize=UDim2.new()
choices.ZIndex=20
choices.Visible=false
choices.Parent=gui
local choiceLimit=Instance.new("UISizeConstraint")
choiceLimit.MaxSize=Vector2.new(480,420)
choiceLimit.Parent=choices
local choiceLayout=Instance.new("UIListLayout")
choiceLayout.Padding=UDim.new(0,8)
choiceLayout.SortOrder=Enum.SortOrder.LayoutOrder
choiceLayout.Parent=choices
local title=Instance.new("TextLabel")
title.Name="Title"
title.Size=UDim2.new(1,-12,0,64)
title.TextColor3=Color3.new(1,1,1)
title.BackgroundTransparency=1
title.TextWrapped=true
title.TextSize=17
title.Font=Enum.Font.GothamBold
title.ZIndex=21
title.Parent=choices
local choiceBusy=false
local function refreshChoices()
	for _,child in choices:GetChildren() do if child:IsA("TextButton") then child:Destroy() end end
	choiceBusy=false
	local encoded=textAttribute("PendingEvolution")
	local ok,state=pcall(function() return HttpService:JSONDecode(encoded) end)
	choices.Visible=ok and type(state)=="table" and type(state.Candidates)=="table"
	if not choices.Visible then return end
	feedPanel.Visible=false
	title.Text="EVOLUTION CHOICE · "..textAttribute("PetStageLabel").."\nApproach your pet. Growth reserve: "..Format.compact(numberAttribute("GrowthReserve"))
	local petKey=textAttribute("OwnedPetKey")
	for index,id in state.Candidates do
		local definition=Monsters.get(state.Source)
		local edge
		for _,candidate in if definition then definition.Evolutions else {} do if candidate.Id==id then edge=candidate break end end
		if not edge then continue end
		local target=Monsters.get(edge.Result)
		if not target then continue end
		local b=Instance.new("TextButton")
		b.Name=target.Id b.LayoutOrder=index
		local requirements={}
		for _,key in {"Flesh","Flora","Mineral"} do
			if edge.Requirements[key] then table.insert(requirements,(if key=="Flora" then "Floral" else key).." "..tostring(edge.Requirements[key])) end
		end
		if edge.Family then table.insert(requirements,edge.Family.." family") end
		b.Size=UDim2.new(1,-12,0,84)
		b.Text=target.DisplayName.." · Stage "..tostring(edge.TargetStage).."\n"..tostring(edge.Growth).." Growth · x"..tostring(target.BaseMultiplier)
			.."\n"..table.concat(requirements," + ")
		b.TextSize=17 b.TextWrapped=true b.Font=Enum.Font.GothamBold
		b.BackgroundColor3=target.Color b.ZIndex=21 b.Parent=choices
		b.Activated:Connect(function()
			if choiceBusy then return end
			choiceBusy=true title.Text="Confirming evolution…"
			feedRemote:FireServer("Evolve",{PetKey=petKey,Token=state.Token,BranchId=id})
			task.delay(2,function() choiceBusy=false end)
		end)
	end
end
for _,attribute in {"PendingEvolution","OwnedPetKey","PetStageLabel","GrowthReserve"} do
	player:GetAttributeChangedSignal(attribute):Connect(refreshChoices)
end
feedRemote.OnClientEvent:Connect(function(payload)
	if payload.Kind~="Evolution" then return end
	choiceBusy=false
	if not payload.Success then title.Text=payload.Reason or "Evolution unavailable" end
end)
refreshChoices()

-- Phase 5A: one presentation panel and one remote; replicated rates are server-owned.
local Trainers=require(Shared.TrainerDefinitions)
local trainingRemote=game.ReplicatedStorage.Remotes:WaitForChild("TrainingInteraction") :: RemoteEvent
local economyPanel=Instance.new("Frame")
economyPanel.Name="EconomyPanel"
economyPanel.AnchorPoint=Vector2.new(0,0)
economyPanel.Position=UDim2.fromOffset(16,280)
economyPanel.Size=UDim2.new(0.3,0,0,272)
economyPanel.BackgroundColor3=Color3.fromRGB(25,29,38)
economyPanel.Parent=gui
local economyLimit=Instance.new("UISizeConstraint")
economyLimit.MaxSize=Vector2.new(280,272) economyLimit.Parent=economyPanel
local economyText=Instance.new("TextLabel")
economyText.Name="Details" economyText.Position=UDim2.fromOffset(10,8)
economyText.Size=UDim2.new(1,-20,1,-106) economyText.BackgroundTransparency=1
economyText.TextColor3=Color3.new(1,1,1) economyText.Font=Enum.Font.GothamMedium
economyText.TextSize=16 economyText.TextWrapped=true economyText.Parent=economyPanel
local function economyButton(name,y)
	local b=Instance.new("TextButton") b.Name=name b.Position=UDim2.new(0,8,1,y)
	b.Size=UDim2.new(1,-16,0,40) b.TextSize=16 b.TextWrapped=true b.Font=Enum.Font.GothamBold
	b.Parent=economyPanel return b
end
local trainButton=economyButton("Train",-94)
local upgradeButton=economyButton("Upgrade",-48)
local displayedTarget: number?=nil
local function refreshEconomy()
	local tier=numberAttribute("TrainerTier")
	local current=Trainers.getOrdered()[tier]
	local nextTier=Trainers.getOrdered()[tier+1]
	displayedTarget=if current and nextTier then tier+1 else nil
	local active=player:GetAttribute("TrainingActive")==true
	economyText.Text="Cash "..Format.compact(numberAttribute("Cash")).." · +"..Format.compact(numberAttribute("IncomePerSecond")).."/s"
		.."\nPower "..Format.compact(numberAttribute("Power")).." · +"..Format.compact(numberAttribute("TrainingGainPerSecond")).."/s training"
		.."\n"..(if current then "Tier "..tier.." · "..current.DisplayName.." x"..current.Multiplier else "Loading trainer…")
		.."\nPet training x"..Format.compact(numberAttribute("ActivePetTrainingMultiplier"))
		.."\n"..(if nextTier and current then "Next: "..nextTier.DisplayName.." x"..nextTier.Multiplier.." · "..Format.compact(nextTier.Price or 0).." Cash" else "Maximum trainer tier")
		.."\n"..textAttribute("StatusMessage")
	trainButton.Text=if active then "STOP TRAINING" else "START · approach your trainer"
	upgradeButton.Text=if displayedTarget then "BUY NEXT TRAINER" else "MAX TIER"
	upgradeButton.Active=displayedTarget~=nil
end
trainButton.Activated:Connect(function() trainingRemote:FireServer(if player:GetAttribute("TrainingActive") then "Stop" else "Start") end)
upgradeButton.Activated:Connect(function() if displayedTarget then trainingRemote:FireServer("Upgrade",displayedTarget) end end)
trainingRemote.OnClientEvent:Connect(function(action) if action=="Shop" then economyPanel.Visible=true refreshEconomy() end end)
player.AttributeChanged:Connect(refreshEconomy)
refreshEconomy()
