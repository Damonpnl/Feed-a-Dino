-- Opt-in Play test. Exercises actual services/models; restores player state on completion.
local Server = game.ServerScriptService.Server
local Spawn, Carry, Data = require(Server.SpawnService), require(Server.CarryService), require(Server.DataService)
local Shared = game.ReplicatedStorage.Shared
local Resources, Config = require(Shared.ResourceDefinitions), require(Shared.FieldConfig)
local player = game.Players:GetPlayers()[1]
local originalPower, originalFrame, passes = nil, nil, 0
local function check(ok, message) assert(ok, message) passes += 1 end
local function physical(id)
	for _, model in workspace.GeneratedGameplay.Resources:GetChildren() do
		if model:GetAttribute("ResourceInstanceId") == id then return model end
	end
end
local ok, failure = xpcall(function()
	while not player or not player.Character or not Data.get(player) do task.wait(0.1) player=game.Players:GetPlayers()[1] end
	originalPower, originalFrame = Data.get(player).Power, player.Character:GetPivot()
	check(#Spawn.validate() == 0, "initial runtime validation")
	local id, record
	for key, value in Spawn.getSnapshot().Records do
		if value.AreaId == "Grasslands" and value.State == "World" then id, record = key, value break end
	end
	local definition = Resources.get(record.ResourceId)
	Data.get(player).Power = definition.PowerRequired
	player.Character:PivotTo(physical(id).PrimaryPart.CFrame + Vector3.new(0,3,0))
	check(Spawn.pickup(player,id), "pickup with updated visual")
	local visual = player.Character:FindFirstChild("CarriedResource")
	check(visual and visual:IsA("Model") and visual.PrimaryPart, "carry uses the swappable model")
	check(visual:GetAttribute("ResourceInstanceId") == id and not physical(id), "single world/carried representation")
	check(visual.PrimaryPart:FindFirstChildOfClass("WeldConstraint") ~= nil and not visual.PrimaryPart.Anchored, "carry is welded/unanchored")
	check(math.abs(player.Character.Humanoid.WalkSpeed-16*(1-definition.CarrySlowdown)) < 0.001, "configured slowdown")
	local item = Carry.drop(player)
	check(Spawn.returnToWorld(item.areaId,item.resourceId,item.token,player.Character:GetPivot().Position,player.UserId), "same-ID physical drop")
	check(physical(id) and Spawn.getRecord(id).State == "Dropped", "drop model and record")
	player.Character:PivotTo(originalFrame)
	script:SetAttribute("Progress", "Waiting for actual 20-second dropped expiry")
	while Spawn.getRecord(id) do task.wait(0.1) end
	check(not physical(id), "expired drop removed physically")
	local node = Spawn.getSnapshot().Nodes[record.NodeId]
	check(node.RecordId == nil and node.RespawnAt ~= nil, "expired eligible resource schedules refill")
	script:SetAttribute("Progress", "Waiting for actual node refill")
	while not Spawn.getSnapshot().Nodes[record.NodeId].RecordId do task.wait(0.1) end
	local freshId = Spawn.getSnapshot().Nodes[record.NodeId].RecordId
	check(freshId ~= id and physical(freshId), "refill has a new physical GUID")
	check(not require(Shared.RarityDefinitions).isSecretPlus(Resources.get(Spawn.getRecord(freshId).ResourceId).Rarity), "mid-cycle excludes chase")
	physical(freshId):Destroy()
	task.wait(0.1)
	check(not Spawn.getRecord(freshId) and Spawn.getSnapshot().Nodes[record.NodeId].RespawnAt, "external destruction releases/schedules exactly once")
	check(#Spawn.validate() == 0, "final ownership validation")
end,debug.traceback)
if player and Data.get(player) and originalPower then Data.get(player).Power=originalPower Data.publish(player) end
if player and player.Character and originalFrame then player.Character:PivotTo(originalFrame) end
if player then local held=Carry.consume(player) if held then Spawn.releaseToken(held.areaId,held.token) end end
script:SetAttribute("Result", if ok then "PASS" else failure)
script:SetAttribute("PassedChecks", passes) script:SetAttribute("Progress", "Complete")
if ok then print("[FieldRuntimeSmoke] PASS " .. passes .. " checks") else warn("[FieldRuntimeSmoke] " .. failure) end
