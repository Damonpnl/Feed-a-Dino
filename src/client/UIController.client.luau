--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return 0
end

local function textAttribute(name: string): string
	local value = player:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end
	return ""
end

local gui = Instance.new("ScreenGui")
gui.Name = "MonsterHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BackgroundTransparency = 0.25
panel.Position = UDim2.fromOffset(16, 16)
panel.Size = UDim2.fromOffset(280, 210)
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(12, 8)
label.Size = UDim2.new(1, -24, 1, -16)
label.Font = Enum.Font.GothamMedium
label.TextColor3 = Color3.fromRGB(240, 240, 240)
label.TextSize = 16
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.TextWrapped = true
label.Parent = panel

local function refresh()
	local carried = textAttribute("CarriedName")
	local carriedLine = if carried ~= "" then "Carrying: " .. carried .. "  (G to drop)" else "Hands empty  (G drops)"
	local mutations = textAttribute("Mutations")
	local mutationLine = if mutations ~= "" then "\nMutation: " .. mutations else ""
	label.Text = string.format(
		"%s\nGrowth %d / %d\nFlesh %d   Flora %d   Mineral %d\nPower %d    Cash %d    x%.1f%s\n%s\n%s",
		textAttribute("MonsterName"),
		math.floor(numberAttribute("Growth")),
		math.floor(numberAttribute("GrowthRequired")),
		math.floor(numberAttribute("Flesh")),
		math.floor(numberAttribute("Flora")),
		math.floor(numberAttribute("Mineral")),
		math.floor(numberAttribute("Power")),
		math.floor(numberAttribute("Cash")),
		numberAttribute("Multiplier"),
		mutationLine,
		carriedLine,
		textAttribute("StatusMessage")
	)
end

player.AttributeChanged:Connect(refresh)
refresh()
