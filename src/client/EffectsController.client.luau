--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

player:GetAttributeChangedSignal("HazardTick"):Connect(function()
	if camera == nil then
		camera = workspace.CurrentCamera
	end
	if camera == nil then
		return
	end

	local origin = camera.CFrame
	task.spawn(function()
		for _ = 1, 6 do
			local shake = Vector3.new(math.random(-2, 2) / 8, math.random(-2, 2) / 8, 0)
			camera.CFrame = origin * CFrame.new(shake)
			task.wait(0.03)
		end
		camera.CFrame = origin
	end)
end)
