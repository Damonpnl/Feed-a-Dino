--!nonstrict
-- Presentation hooks only: consumers may attach animation/audio/VFX without owning hits.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Areas = require(game.ReplicatedStorage.Shared.AreaDefinitions)
local Presentation = {}
for _,name in {"Wake","Warning","Attack","Cooldown","Disengage","Sleep","SoundRequested","VFXRequested","CameraShake","ResourceDropped"} do
	Presentation[name]=Instance.new("BindableEvent")
end
local connections, watched, gui, label = {}, {}, nil, nil
local partConnections = {}
local shakeUntil, shakeHumanoid, originalOffset = 0, nil, nil
local function restoreCamera()
	if shakeHumanoid and shakeHumanoid.Parent then shakeHumanoid.CameraOffset=originalOffset end
	shakeHumanoid,originalOffset=nil,nil
end
local function refresh()
	local lines={}
	for _,area in Areas.getOrdered() do
		local part=watched[area.Id]
		if part and part.Parent then
			local state=part:GetAttribute("GuardianState") or "SLEEPING"
			local rarity=part:GetAttribute("TargetRarity")
			local suffix=if rarity and rarity~="" and state~="SLEEPING" then " · "..rarity else ""
			table.insert(lines, area.GuardianDisplayName..": "..state..suffix)
		end
	end
	if label then label.Text=table.concat(lines,"\n") end
end
function Presentation.Start()
	if gui then return end
	local player=Players.LocalPlayer
	gui=Instance.new("ScreenGui") gui.Name="GuardianHud" gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")
	label=Instance.new("TextLabel") label.Name="GuardianStatus" label.AnchorPoint=Vector2.new(1,0) label.Position=UDim2.new(1,-12,0,150)
	label.Size=UDim2.new(0.35,0,0,125) label.BackgroundColor3=Color3.fromRGB(25,29,38) label.BackgroundTransparency=0.2
	label.TextColor3=Color3.new(1,1,1) label.TextSize=14 label.Font=Enum.Font.GothamMedium label.TextWrapped=true label.Parent=gui
	local hunt=Instance.new("TextLabel") hunt.Name="HuntNotice" hunt.AnchorPoint=Vector2.new(0.5,0) hunt.Position=UDim2.new(0.5,0,0,70)
	hunt.Size=UDim2.new(0.55,0,0,64) hunt.BackgroundColor3=Color3.fromRGB(70,20,16) hunt.BackgroundTransparency=0.15
	hunt.TextColor3=Color3.fromRGB(255,220,160) hunt.TextSize=20 hunt.Font=Enum.Font.GothamBold hunt.TextWrapped=true
	hunt.Visible=false hunt.Parent=gui
	local folder=workspace:WaitForChild("GeneratedGameplay"):WaitForChild("Guardians")
	local function unbind(part)
		local list=partConnections[part]
		if not list then return end
		for _,c in list do c:Disconnect() end
		partConnections[part]=nil
		local id=part:GetAttribute("AreaId")
		if watched[id]==part then watched[id]=nil end
		refresh()
	end
	local function bind(part)
		if not part:IsA("BasePart") then return end
		local areaId=part:GetAttribute("AreaId")
		if not areaId or watched[areaId]==part then return end
		if watched[areaId] then unbind(watched[areaId]) end
		watched[areaId]=part
		local list={} partConnections[part]=list
		local lastState=part:GetAttribute("GuardianState")
		table.insert(list,part:GetAttributeChangedSignal("GuardianState"):Connect(function()
			local state=part:GetAttribute("GuardianState")
			if state~=lastState then
				lastState=state
				if state=="WAKING" then Presentation.Wake:Fire(areaId,part)
				elseif state=="WARNING" then Presentation.Warning:Fire(areaId,part)
				elseif state=="HAZARD" then Presentation.Attack:Fire(areaId,part)
				elseif state=="COOLDOWN" then Presentation.Cooldown:Fire(areaId,part)
				-- Disengage animation hook: the server holds the guardian facing home for DisengageHold.
				elseif state=="RETURNING" then Presentation.Disengage:Fire(areaId,part)
				elseif state=="SLEEPING" then Presentation.Sleep:Fire(areaId,part) end
				Presentation.SoundRequested:Fire(areaId,state,part)
				Presentation.VFXRequested:Fire(areaId,state,part)
			end
			refresh()
		end))
		table.insert(list,part:GetAttributeChangedSignal("Disturbance"):Connect(refresh))
		refresh()
	end
	for _,part in folder:GetDescendants() do bind(part) end
	table.insert(connections,folder.DescendantAdded:Connect(bind))
	table.insert(connections,folder.DescendantRemoving:Connect(unbind))
	table.insert(connections,player:GetAttributeChangedSignal("DropTick"):Connect(function() Presentation.ResourceDropped:Fire(player:GetAttribute("DropReason")) end))
	table.insert(connections,player:GetAttributeChangedSignal("HuntNoticeTick"):Connect(function()
		hunt.Text=player:GetAttribute("HuntNotice") or ""
		hunt.Visible=hunt.Text~=""
		local shown=hunt.Text
		task.delay(3.5,function() if hunt.Parent and hunt.Text==shown then hunt.Visible=false end end)
	end))
	table.insert(connections,player:GetAttributeChangedSignal("HazardTick"):Connect(function()
		Presentation.CameraShake:Fire(0.2)
		restoreCamera()
		shakeHumanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if shakeHumanoid then originalOffset=shakeHumanoid.CameraOffset shakeUntil=os.clock()+0.2 end
	end))
	table.insert(connections,RunService.Heartbeat:Connect(function()
		if not shakeHumanoid then return end
		if os.clock()>=shakeUntil or not player.Character or shakeHumanoid.Parent~=player.Character then restoreCamera() return end
		shakeHumanoid.CameraOffset=originalOffset+Vector3.new(math.sin(os.clock()*70)*0.12,0,0)
	end))
end
function Presentation.Stop()
	for _,c in connections do c:Disconnect() end
	for _,list in partConnections do for _,c in list do c:Disconnect() end end
	partConnections={}
	connections={} watched={} restoreCamera()
	if gui then gui:Destroy() end gui,label=nil,nil
end
function Presentation.GetStats()
	local count=#connections
	for _,list in partConnections do count+=#list end
	return {Connections=count,Running=gui~=nil}
end
return Presentation
