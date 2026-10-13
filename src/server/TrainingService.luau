--!strict

local DataService = require(script.Parent.DataService)
local MonsterService = require(script.Parent.MonsterService)
local Trainers = require(game.ReplicatedStorage.Shared.TrainerDefinitions)
local Guard = require(script.Parent.InteractionGuard)

local TrainingService = {}

local started = false

local function setStatus(player: Player, message: string)
	player:SetAttribute("StatusMessage", message)
end

function TrainingService.train(player: Player, base: Model, station: BasePart): boolean
	if not Guard.allow(player, "Train", Trainers.Legacy.TrainCooldown)
		or station.Name ~= "TrainingStation" or not Guard.ownedBase(player, base, station, 12) then return false end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	if player:GetAttribute("AssignedBaseName") == nil then
		return false
	end

	local gain = Trainers.legacyGain(data.BaseUpgrades.TrainingLevel, MonsterService.getMultiplier(player))
	data.Power += gain
	data.Stats.Trainings += 1
	DataService.publish(player)
	setStatus(player, "+" .. tostring(gain) .. " Power")
	return true
end

function TrainingService.upgrade(player: Player, base: Model, station: BasePart): boolean
	if not Guard.allow(player, "Upgrade", 0.25)
		or station.Name ~= "TrainingStation" or not Guard.ownedBase(player, base, station, 12) then return false end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local level = data.BaseUpgrades.TrainingLevel
	local cost = Trainers.legacyCost(level)
	if data.Cash < cost then
		setStatus(player, "Need " .. tostring(cost) .. " Cash")
		return false
	end
	data.Cash -= cost
	data.BaseUpgrades.TrainingLevel = level + 1
	DataService.publish(player)
	setStatus(player, "Training level " .. tostring(level + 1))
	return true
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
	if started then return end
	started = true
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
			TrainingService.train(player, base, station)
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
			TrainingService.upgrade(player, base, station)
		end)
	end
end

return TrainingService
