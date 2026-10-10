--!strict
local BillboardService = require(script.Parent.BillboardService)
BillboardService:Start()
script.Destroying:Connect(function()
	BillboardService:Stop()
end)
