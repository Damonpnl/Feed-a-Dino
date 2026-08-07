--!strict

--[[
	Binds the StarterPack PDA Tool to the Research Tablet UI.
	Also listens to economy remotes for inventory/sell/wallet presentation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TabletConfig = require(Shared:WaitForChild("tablet"):WaitForChild("TabletConfig"))

local TabletUIController = require(script.Parent:WaitForChild("TabletUIController"))

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("EconomyRemotes", 30)
if remotesFolder == nil then
	warn("[TabletController] EconomyRemotes not found")
	return
end

TabletUIController.mount(remotesFolder)

local boundTool: Tool? = nil
local connections: { RBXScriptConnection } = {}
local isEquipped = false

local function disconnectAll()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function isPdaTool(instance: Instance): boolean
	if not instance:IsA("Tool") then
		return false
	end
	for _, candidate in TabletConfig.PdaToolCandidateNames do
		if instance.Name == candidate then
			return true
		end
	end
	return instance:GetAttribute("IsResearchTablet") == true
end

local function findPdaTool(): Tool?
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if isPdaTool(child) then
				return child :: Tool
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if isPdaTool(child) then
				return child :: Tool
			end
		end
	end
	return nil
end

local function bindTool(tool: Tool)
	if boundTool == tool then
		return
	end
	disconnectAll()
	boundTool = tool

	table.insert(connections, tool.Equipped:Connect(function()
		isEquipped = true
		TabletUIController.setEquipHint(true)
	end))

	table.insert(connections, tool.Unequipped:Connect(function()
		isEquipped = false
		TabletUIController.setEquipHint(false)
		TabletUIController.close()
	end))

	table.insert(connections, tool.Activated:Connect(function()
		if not isEquipped then
			return
		end
		TabletUIController.toggle()
	end))

	table.insert(connections, tool.Destroying:Connect(function()
		if boundTool == tool then
			boundTool = nil
			isEquipped = false
			disconnectAll()
			TabletUIController.close()
			TabletUIController.setEquipHint(false)
		end
	end))

	-- If already equipped when rebound.
	if tool.Parent == player.Character then
		isEquipped = true
		TabletUIController.setEquipHint(not TabletUIController.isOpen())
	end
end

local function rebind()
	local tool = findPdaTool()
	if tool then
		bindTool(tool)
	end
end

local function watchContainer(container: Instance)
	container.ChildAdded:Connect(function(child)
		if isPdaTool(child) then
			bindTool(child :: Tool)
		end
	end)
end

local function onCharacterAdded(character: Model)
	isEquipped = false
	TabletUIController.close()
	TabletUIController.setEquipHint(false)
	disconnectAll()
	boundTool = nil
	watchContainer(character)
	task.defer(rebind)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

local backpack = player:WaitForChild("Backpack")
watchContainer(backpack)
rebind()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and TabletUIController.isOpen() then
		TabletUIController.close()
	end
end)

local function bindRemote(name: string, handler: (...any) -> ())
	local remote = remotesFolder:WaitForChild(name, 10)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(handler)
	else
		warn("[TabletController] Missing remote " .. name)
	end
end

bindRemote("WalletUpdated", function(snapshot)
	TabletUIController.updateWallet(snapshot)
end)

bindRemote("InventoryUpdated", function(snapshot)
	TabletUIController.updateInventory(snapshot)
end)

bindRemote("SellSessionOpened", function(payload)
	TabletUIController.openSellSession(payload)
end)

bindRemote("SellSessionClosed", function()
	TabletUIController.closeSellSession()
end)

bindRemote("EconomyNotification", function(payload)
	TabletUIController.showNotification(payload)
	if typeof(payload) == "table" then
		local title = string.upper(tostring(payload.title or ""))
		if string.find(title, "SOLD", 1, true) or string.find(title, "FAIL", 1, true) then
			TabletUIController.showSaleFeedback(payload)
		end
	end
end)

-- Request initial snapshots once remotes are live.
task.defer(function()
	local openInv = remotesFolder:FindFirstChild("RequestOpenInventory")
	if openInv and openInv:IsA("RemoteEvent") then
		openInv:FireServer()
	end
end)

print("[TabletController] Research Tablet controller ready")
