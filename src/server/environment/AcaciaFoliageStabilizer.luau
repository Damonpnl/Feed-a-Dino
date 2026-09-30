--!strict

--[[
	Stabilizes Acacia environment models so leaf MeshParts stay attached.
	Acacia templates had an unanchored leaf with no weld, causing leaves to fall at runtime.
]]

local AcaciaFoliageStabilizer = {}

local WELD_NAME = "FoliageLeafWeld"

function AcaciaFoliageStabilizer.isAcaciaModel(model: Instance): boolean
	return model:IsA("Model") and model.Name == "Acacia"
end

function AcaciaFoliageStabilizer.stabilize(model: Model): (boolean, string?)
	if not AcaciaFoliageStabilizer.isAcaciaModel(model) then
		return false, "NotAcacia"
	end

	local trunk = model:FindFirstChild("Tree Wood")
	local leaf = model:FindFirstChild("MeshPart")
	if trunk == nil or not trunk:IsA("BasePart") then
		return false, "MissingTrunk"
	end
	if leaf == nil or not leaf:IsA("BasePart") then
		return false, "MissingLeaf"
	end

	model.PrimaryPart = trunk
	trunk.Anchored = true
	leaf.Anchored = true

	for _, child in model:GetChildren() do
		if child:IsA("WeldConstraint") and child.Name == WELD_NAME then
			child:Destroy()
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Part0 = trunk
	weld.Part1 = leaf
	weld.Parent = model

	return true, nil
end

function AcaciaFoliageStabilizer.stabilizeAll(root: Instance): (number, number)
	local fixed = 0
	local failed = 0

	for _, descendant in root:GetDescendants() do
		if AcaciaFoliageStabilizer.isAcaciaModel(descendant) then
			local ok = AcaciaFoliageStabilizer.stabilize(descendant)
			if ok then
				fixed += 1
			else
				failed += 1
			end
		end
	end

	return fixed, failed
end

return AcaciaFoliageStabilizer
