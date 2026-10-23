--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dropRemote = remotes:WaitForChild("DropCarried") :: RemoteEvent

ContextActionService:BindAction("DropCarriedResource", function(_, state)
	if state == Enum.UserInputState.Begin and dropRemote:IsA("RemoteEvent") then
		dropRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.G, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("DropCarriedResource", "Drop")
ContextActionService:SetPosition("DropCarriedResource", UDim2.new(1, -160, 1, -160))
script.Destroying:Connect(function() ContextActionService:UnbindAction("DropCarriedResource") end)

-- Native button Activated supports mouse/touch; V is the precision-mode shortcut.
local player=game.Players.LocalPlayer
local slowRemote=remotes:WaitForChild("SetSlowMode") :: RemoteEvent
local gui=Instance.new("ScreenGui") gui.Name="MovementHud" gui.ResetOnSpawn=false
gui.Parent=player:WaitForChild("PlayerGui")
local button=Instance.new("TextButton") button.Name="SlowMode"
button.AnchorPoint=Vector2.new(1,0) button.Position=UDim2.new(1,-16,0,76)
button.Size=UDim2.fromOffset(190,44) button.TextSize=16 button.Font=Enum.Font.GothamBold
button.BackgroundColor3=Color3.fromRGB(35,42,54) button.TextColor3=Color3.new(1,1,1)
button.Parent=gui
local function layout()
	local narrow=gui.AbsoluteSize.X<600
	button.AnchorPoint=if narrow then Vector2.new(.5,1) else Vector2.new(1,0)
	button.Position=if narrow then UDim2.new(.5,0,1,-120) else UDim2.new(1,-16,0,76)
end
local resized=gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()
local function refresh()
	button.Text="SLOW MODE: "..(if player:GetAttribute("SlowMode")==true then "ON" else "OFF").." [V]"
end
local function toggle() slowRemote:FireServer(player:GetAttribute("SlowMode")~=true) end
button.Activated:Connect(toggle)
local changed=player:GetAttributeChangedSignal("SlowMode"):Connect(refresh)
ContextActionService:BindAction("ToggleSlowMode",function(_,state)
	if state==Enum.UserInputState.Begin then toggle() end
	return Enum.ContextActionResult.Sink
end,false,Enum.KeyCode.V)
refresh()
script.Destroying:Connect(function() changed:Disconnect() resized:Disconnect() gui:Destroy() ContextActionService:UnbindAction("ToggleSlowMode") end)
