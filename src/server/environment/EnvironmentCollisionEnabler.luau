--!strict

--[[
	Ensures environment foliage and template parts participate in world collision.
	Generated foliage often spawns with CanCollide disabled.
]]

local EnvironmentCollisionEnabler = {}

function EnvironmentCollisionEnabler.enableCollision(root: Instance): (number, number)
	local changed = 0
	local alreadyOn = 0

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.CanCollide then
				alreadyOn += 1
			else
				descendant.CanCollide = true
				changed += 1
			end
		end
	end

	return changed, alreadyOn
end

function EnvironmentCollisionEnabler.enableKnownRoots(roots: { Instance }): (number, number)
	local totalChanged = 0
	local totalAlready = 0

	for _, root in roots do
		if root ~= nil then
			local changed, alreadyOn = EnvironmentCollisionEnabler.enableCollision(root)
			totalChanged += changed
			totalAlready += alreadyOn
		end
	end

	return totalChanged, totalAlready
end

return EnvironmentCollisionEnabler
