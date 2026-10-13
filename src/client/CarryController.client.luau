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
