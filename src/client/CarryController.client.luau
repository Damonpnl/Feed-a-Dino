--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dropRemote = remotes:WaitForChild("DropCarried") :: RemoteEvent

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G and dropRemote:IsA("RemoteEvent") then
		dropRemote:FireServer()
	end
end)
