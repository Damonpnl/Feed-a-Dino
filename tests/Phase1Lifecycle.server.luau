-- Opt-in Studio-only network/death/disconnect verification. Pair with Phase1Network.client.luau.
-- Ends by kicking the Studio test player; never run against a production server.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Server=game.ServerScriptService.Server
local Data=require(Server.DataService)
local Carry=require(Server.CarryService)
local Spawn=require(Server.SpawnService)
local Resource=require(Server.ResourceService)
local Resources=require(game.ReplicatedStorage.Shared.ResourceDefinitions)
local checks=0
local function check(value,message) assert(value,message) checks+=1 end
local function pickup(player,id,record)
	Data.get(player).Power=Resources.get(record.ResourceId).PowerRequired
	for _,model in workspace.GeneratedGameplay.Resources:GetChildren() do
		if model:GetAttribute("ResourceInstanceId")==id then
			player.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0))
			return Spawn.pickup(player,id)
		end
	end
	return false
end
local function awaitCondition(fn)
	local deadline=os.clock()+5
	repeat task.wait() until fn() or os.clock()>=deadline
	return fn()
end
local ok,failure=xpcall(function()
	local cycle=game.ServerScriptService:FindFirstChild("FieldIntegration")
	if cycle then repeat task.wait(0.1) until cycle:GetAttribute("Result") assert(cycle:GetAttribute("Result")=="PASS","Field test failed") end
	local player=game.Players:GetPlayers()[1]
	assert(player and player.Character,"Test player missing")
	local id,record
	for key,r in Spawn.getSnapshot().Records do if r.State=="AVAILABLE" and r.AreaId=="Swamp" then id,record=key,r break end end
	check(id~=nil and pickup(player,id,record),"Network fixture pickup")
	local power=Data.get(player).Power local feeds=Data.get(player).Stats.Feeds
	player:SetAttribute("Phase1NetworkReady",true)
	check(awaitCondition(function() return Carry.get(player)==nil end),"Client DropCarried reached server")
	check(Resource.getRecord(id) and Resource.getRecord(id).State=="DROPPED","Network drop preserves GUID")
	check(Data.get(player).Power==power and Data.get(player).Stats.Feeds==feeds and Data.get(player).Cash<1e9,"Forged client rewards ignored")
	check(#Spawn.validate()==0,"Remote spam creates no duplicate world resources")
	task.wait(0.3)
	check(pickup(player,id,record),"Reclaim before death")
	player.Character.Humanoid.Health=0
	check(awaitCondition(function() return not Carry.get(player) end),"Death clears carry")
	check(Resource.getRecord(id) and Resource.getRecord(id).State=="DROPPED","Death returns same GUID to world")
	check(#Spawn.validate()==0,"Death leaves consistent ownership")
	player:LoadCharacterAsync() task.wait(0.3)
	check(pickup(player,id,record),"Reclaim before disconnect")
	local base=workspace.Bases:FindFirstChild(player:GetAttribute("AssignedBaseName"))
	local departed=false
	local connection=game.Players.PlayerRemoving:Connect(function(leaving) if leaving==player then departed=true end end)
	player:Kick("Phase 1 Studio-only lifecycle verification completed.")
	check(awaitCondition(function() return departed and Data.get(player)==nil and not Carry.get(player) and base:GetAttribute("OwnerUserId")==nil end),"Disconnect clears session, carry and base")
	connection:Disconnect()
	local remaining=Resource.getRecord(id)
	check(not remaining or remaining.State=="DROPPED","Disconnected player retains no carried resource")
	check(#Spawn.validate()==0,"Disconnect leaves consistent world records")
	check(#workspace.GeneratedGameplay.Monsters:GetChildren()==0,"Disconnect removes pet visual")
end,debug.traceback)
script:SetAttribute("Result",if ok then "PASS" else failure)
script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase1Lifecycle] PASS "..checks.." checks") else warn("[Phase1Lifecycle] "..failure) end
