--!strict
-- Authoritative metadata only. No server-created UI, remotes, or render loops.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BillboardConfig)
local Data = require(Shared.BillboardData)
local Service = {}

function Service:Update(target: Instance, patch: Data.Options)
	for _, key in Data.Keys do
		local value = (patch :: any)[key]
		if value ~= nil and Data.valid(key, value) then
			target:SetAttribute(Config.AttributePrefix .. key, value)
		end
	end
end

function Service:Create(target: Instance, options: Data.Options)
	self:Update(target, options)
	target:SetAttribute(Config.AttributePrefix .. "Enabled", true)
	CollectionService:AddTag(target, Config.Tag)
end

function Service:Show(target: Instance)
	target:SetAttribute(Config.AttributePrefix .. "Enabled", true)
end

function Service:Hide(target: Instance)
	target:SetAttribute(Config.AttributePrefix .. "Enabled", false)
end

function Service:Destroy(target: Instance)
	CollectionService:RemoveTag(target, Config.Tag)
	for _, key in Data.Keys do
		target:SetAttribute(Config.AttributePrefix .. key, nil)
	end
	target:SetAttribute(Config.AttributePrefix .. "Enabled", nil)
end

return Service
