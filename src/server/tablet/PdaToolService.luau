--!strict

--[[
	Ensures StarterPack.PDA is a Tool with a Handle so clients can equip/activate it.
	Does not alter mesh art beyond unanchoring/welding for equip.
]]

local StarterPack = game:GetService("StarterPack")

local PdaToolService = {}

local function weldToHandle(tool: Tool, handle: BasePart)
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			if descendant:FindFirstChildOfClass("WeldConstraint") == nil then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = handle
			end
		end
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
end

function PdaToolService.ensureTool(): Tool?
	local existing = StarterPack:FindFirstChild("PDA")
	if existing == nil then
		warn("[PdaToolService] StarterPack.PDA missing")
		return nil
	end

	if existing:IsA("Tool") then
		local handle = existing:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			weldToHandle(existing, handle)
		end
		existing.RequiresHandle = true
		existing.CanBeDropped = false
		existing:SetAttribute("IsResearchTablet", true)
		return existing
	end

	if not existing:IsA("Model") then
		warn("[PdaToolService] StarterPack.PDA has unexpected class " .. existing.ClassName)
		return nil
	end

	local handle = existing:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		warn("[PdaToolService] PDA model missing Handle part")
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = "PDA"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Research Tablet"
	tool:SetAttribute("IsResearchTablet", true)

	for _, child in existing:GetChildren() do
		child.Parent = tool
	end
	weldToHandle(tool, handle)
	tool.Parent = StarterPack
	existing:Destroy()

	print("[PdaToolService] Converted StarterPack.PDA Model -> Tool")
	return tool
end

function PdaToolService.start()
	PdaToolService.ensureTool()
end

return PdaToolService
