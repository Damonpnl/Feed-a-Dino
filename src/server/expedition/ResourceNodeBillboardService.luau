--!strict

--[[
	SAB-style billboards for expedition resource nodes.
	Reuses MaterialBillboardService visuals with charge count instead of price.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MaterialBillboardService = require(script.Parent.Parent.materials.MaterialBillboardService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResourceNodeDefinitions = require(Shared:WaitForChild("expedition"):WaitForChild("ResourceNodeDefinitions"))

local ExpeditionTypes = require(Shared:WaitForChild("expedition"):WaitForChild("ExpeditionTypes"))

local ResourceNodeBillboardService = {}

function ResourceNodeBillboardService.attach(
	instance: Instance,
	nodeTypeId: ExpeditionTypes.NodeTypeId,
	charges: number
): BillboardGui?
	local feedId = ResourceNodeDefinitions.getBillboardFeedId(nodeTypeId)
	local displayName = ResourceNodeDefinitions.getBillboardDisplayName(nodeTypeId)
	local result = MaterialBillboardService.attachResourceNode(instance, feedId, displayName, charges)
	if not result.success then
		return nil
	end
	return result.billboard
end

function ResourceNodeBillboardService.updateCharges(billboard: BillboardGui?, charges: number)
	if billboard == nil then
		return
	end
	MaterialBillboardService.updateResourceCharges(billboard, charges)
end

return ResourceNodeBillboardService
