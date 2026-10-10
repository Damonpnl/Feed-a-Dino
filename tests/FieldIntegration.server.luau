-- Opt-in Play integration test. Inject under ServerScriptService; waits for a real field cycle.
local Server = game.ServerScriptService.Server
local Spawn = require(Server.SpawnService)
local Carry = require(Server.CarryService)
local Data = require(Server.DataService)
local Resources = require(game.ReplicatedStorage.Shared.ResourceDefinitions)
local player = game.Players:GetPlayers()[1]
local passes = 0
local function check(ok, message) assert(ok, message) passes += 1 end
local originalFrame, originalPower
local function selectRecord(area)
	for id, record in Spawn.getSnapshot().Records do
		if record.AreaId == area and record.State == "World" then return id, record end
	end
	error("Missing world resource in " .. area)
end
local function goTo(id)
	for _, model in workspace.GeneratedGameplay.Resources:GetChildren() do
		if model:GetAttribute("ResourceInstanceId") == id then
			player.Character:PivotTo(model.PrimaryPart.CFrame + Vector3.new(0, 3, 0)) return
		end
	end
	error("Missing physical resource")
end
local ok, failure = xpcall(function()
	while not player or not player.Character or not Data.get(player) or not Spawn.getSnapshot() do
		task.wait(0.1) player=game.Players:GetPlayers()[1]
	end
	originalFrame, originalPower = player.Character:GetPivot(), Data.get(player).Power
	check(#Spawn.validate() == 0, "Initial runtime state must be valid")
	local id, record = selectRecord("Swamp")
	goTo(id) Data.get(player).Power = 0
	check(not Spawn.pickup(player,id), "Insufficient Power must reject pickup")
	check(Spawn.getRecord(id).State == "World", "Rejected pickup must preserve the record")
	Data.get(player).Power = Resources.get(record.ResourceId).PowerRequired
	check(Spawn.pickup(player,id), "Valid pickup must succeed")
	check(not Spawn.pickup(player,id), "Duplicate pickup must fail")
	check(not Carry.give(player,"RawMeat","Grasslands","forged-id"), "Forged record must fail")
	local item = Carry.drop(player)
	check(Spawn.returnToWorld(item.areaId,item.resourceId,item.token,player.Character:GetPivot().Position,player.UserId), "Drop must return the same record")
	check(Spawn.getRecord(id).State == "Dropped", "Dropped state must be authoritative")
	check(not Spawn.returnToWorld(item.areaId,item.resourceId,item.token,Vector3.zero,player.UserId), "Duplicate drop must fail")
	check(#Spawn.validate() == 0, "Drop must not duplicate a world ID")
	goTo(id) check(Spawn.pickup(player,id), "Dropped item must be pickable")
	local carried = Carry.get(player)
	local originalNode = Spawn.getRecord(id).NodeId
	player.Character:PivotTo(originalFrame)
	script:SetAttribute("Progress", "Waiting for the real 300-second reset")
	local initialCycle = Spawn.getSnapshot().Cycle
	while Spawn.getSnapshot().Cycle == initialCycle do task.wait(0.1) end
	check(Spawn.getSnapshot().Phase == "Reset", "Reset phase must publish")
	check(Spawn.getRecord(id).State == "Carried" and Carry.get(player).token == carried.token, "Reset must preserve carried loot")
	check(#workspace.GeneratedGameplay.Resources:GetChildren() == 0, "Reset must clear uncarried world resources")
	script:SetAttribute("Progress", "Observed reset; waiting for ten-second transition")
	while Spawn.getSnapshot().Phase == "Reset" do task.wait(0.1) end
	check(#workspace.GeneratedGameplay.Resources:GetChildren() == 25, "Hard reset must refill all 25 nodes")
	check(Spawn.getSnapshot().Nodes[originalNode].RecordId ~= id, "Reset node must own a fresh ID")
	Carry.consume(player) Spawn.releaseToken(record.AreaId,id)
	check(Spawn.getSnapshot().Nodes[originalNode].RecordId ~= nil, "Consuming old carry must not free the fresh node")
	check(#Spawn.validate() == 0, "Post-reset runtime state must be valid")
end,debug.traceback)
if player and Data.get(player) and originalPower then Data.get(player).Power = originalPower Data.publish(player) end
if player and player.Character and originalFrame then player.Character:PivotTo(originalFrame) end
if player then local held=Carry.consume(player) if held then Spawn.releaseToken(held.areaId,held.token) end end
script:SetAttribute("PassedChecks",passes)
script:SetAttribute("Result",if ok then "PASS" else failure)
script:SetAttribute("Progress","Complete")
if ok then print("[FieldIntegration] PASS " .. passes .. " checks") else warn("[FieldIntegration] " .. failure) end
