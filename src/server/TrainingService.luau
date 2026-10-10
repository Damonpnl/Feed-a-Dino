--!strict

local DataService = require(script.Parent.DataService)
local MonsterService = require(script.Parent.MonsterService)

local TrainingService = {}

local TRAIN_COOLDOWN = 0.8
local BASE_GAIN = 5
local lastTrain: { [Player]: number } = {}

local function setStatus(player: Player, message: string)
	player:SetAttribute("StatusMessage", message)
end

local function train(player: Player)
	local now = os.clock()
	if now - (lastTrain[player] or 0) < TRAIN_COOLDOWN then
		return
	end
	local data = DataService.get(player)
	if data == nil then
		return
	end
	if player:GetAttribute("AssignedBaseName") == nil then
		return
	end

	lastTrain[player] = now
	local gain = math.floor(BASE_GAIN * MonsterService.getMultiplier(player)) + data.BaseUpgrades.TrainingLevel * 2
	gain = math.max(1, gain)
	data.Power += gain
	data.Stats.Trainings += 1
	DataService.publish(player)
	setStatus(player, "+" .. tostring(gain) .. " Power")
end

local function upgrade(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local level = data.BaseUpgrades.TrainingLevel
	local cost = 25 * (level + 1)
	if data.Cash < cost then
		setStatus(player, "Need " .. tostring(cost) .. " Cash")
		return
	end
	data.Cash -= cost
	data.BaseUpgrades.TrainingLevel = level + 1
	DataService.publish(player)
	setStatus(player, "Training level " .. tostring(level + 1))
end

local function ensureStation(base: Model): BasePart?
	local existing = base:FindFirstChild("TrainingStation", true)
	if existing ~= nil and existing:IsA("BasePart") then
		return existing
	end

	local spawn = base:FindFirstChild("PlayerSpawn", true)
	if spawn == nil or not spawn:IsA("BasePart") then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = "TrainingStation"
	part.Size = Vector3.new(6, 1, 6)
	part.Anchored = true
	part.CanCollide = true
	part.Color = Color3.fromRGB(90, 140, 200)
	part.CFrame = CFrame.new(spawn.Position + Vector3.new(10, 2, 0))
	part.Parent = spawn.Parent
	return part
end

function TrainingService.start()
	local bases = workspace:WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		if not base:IsA("Model") then
			continue
		end
		local station = ensureStation(base)
		if station == nil then
			warn("[TrainingService] " .. base.Name .. " has no PlayerSpawn")
			continue
		end

		local trainPrompt = Instance.new("ProximityPrompt")
		trainPrompt.Name = "TrainPrompt"
		trainPrompt.ActionText = "Train"
		trainPrompt.ObjectText = "Power"
		trainPrompt.RequiresLineOfSight = false
		trainPrompt.MaxActivationDistance = 10
		trainPrompt.Parent = station
		trainPrompt.Triggered:Connect(function(player)
			if base:GetAttribute("OwnerUserId") ~= player.UserId then
				return
			end
			train(player)
		end)

		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "UpgradePrompt"
		upgradePrompt.ActionText = "Upgrade"
		upgradePrompt.ObjectText = "Training"
		upgradePrompt.KeyboardKeyCode = Enum.KeyCode.F
		upgradePrompt.RequiresLineOfSight = false
		upgradePrompt.MaxActivationDistance = 10
		upgradePrompt.UIOffset = Vector2.new(0, 40)
		upgradePrompt.Parent = station
		upgradePrompt.Triggered:Connect(function(player)
			if base:GetAttribute("OwnerUserId") ~= player.UserId then
				return
			end
			upgrade(player)
		end)
	end
end

return TrainingService
