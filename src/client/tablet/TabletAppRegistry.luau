--!strict

--[[
	Client re-export of shared tablet app registry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

return require(Shared:WaitForChild("tablet"):WaitForChild("TabletAppRegistry"))
