--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TestModule = require(Shared:WaitForChild("TestModule"))

print(TestModule.hello())
