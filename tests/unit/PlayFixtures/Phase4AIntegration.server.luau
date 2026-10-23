-- Opt-in Play fixture. Injects a fake SessionStore behind DataService accessors for this player only.
-- Never calls a production store or changes the default Studio read-only policy.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local S=game.ServerScriptService.Server
local Data,Feed,Carry,Resource,Spawn,Guardian= require(S.DataService),require(S.FeedService),require(S.CarryService),require(S.ResourceService),require(S.SpawnService),require(S.GuardianService)
local PD=require(game.ReplicatedStorage.Shared.PlayerData)
local Defs=require(game.ReplicatedStorage.Shared.ResourceDefinitions)
local Store=require(S.SessionStore)
local player=game.Players:GetPlayers()[1]
local get,status=Data.get,Data.getStatus
local db,writes=nil,0
local adapter={get=function() return PD.copy(db) end,update=function(_,fn) writes+=1 local nextValue=fn(PD.copy(db)) if nextValue then db=PD.copy(nextValue) end return PD.copy(nextValue) end}
local session=Store.new(adapter)
local key="isolated_phase4a"
local overrideStatus
local checks=0
local function check(v,message) assert(v,message) checks+=1 script:SetAttribute("PassedChecks",checks) end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>deadline return false
end
local function current() return session:get(key) end
local base,host,originalFrame
local function home() player.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) end
local function acquire(id)
	task.wait(0.21)
	Guardian.resetAll()
	local model
	for _,v in workspace.GeneratedGameplay.Resources:GetChildren() do if v:GetAttribute("ResourceInstanceId")==id then model=v break end end
	assert(model,"World model")
	player.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0))
	assert(Spawn.pickup(player,id),"Pickup") home()
end
local function available()
	for id,r in Resource.getSnapshot().Records do if r.State=="AVAILABLE" then return id end end
	error("No resource available")
end
local ok,failure=xpcall(function()
	assert(waitFor(function() return player and player.Character and Data.get(player) and player:GetAttribute("AssignedBaseName") end,10))
	task.wait(1)
	base=workspace.Bases[player:GetAttribute("AssignedBaseName")]
	host=base:FindFirstChild("FeedingPoint",true)
	if not host:IsA("BasePart") then host=host:FindFirstChildWhichIsA("BasePart",true) end
	originalFrame=player.Character:GetPivot() player.Character.HumanoidRootPart.Anchored=true
	home()
	check(Data.isWritable(player) and Data.getStatus(player).Backend=="StudioMemory","Ordinary Studio uses writable temporary memory")
	local data=session:load(key)
	data.Power=1e12 data.EquippedMonster="MagmaRex"
	data.Monsters.MagmaRex=PD.createMonster("MagmaRex","Epic")
	data.Monsters.MagmaRex.PetId="legacy-owned-id"
	Data.get=function(p) return if p==player then current() else get(p) end
	Data.getStatus=function(p) return if p==player then overrideStatus or session:status(key) else status(p) end
	check(Data.isWritable(player),"Missing fake save is writable")
	local id=available() acquire(id)
	local item=Carry.get(player) local definition=Defs.get(item.resourceId)
	local preview=Feed.preview(player,base,host)
	check(preview.Available and preview.ResourceInstanceId==id,"Owned live resource previews")
	check(current().Monsters.MagmaRex.Growth==0 and Resource.owned(player,id),"Preview has no effects")
	local other for _,b in workspace.Bases:GetChildren() do if b~=base then other=b break end end
	local otherHost=other:FindFirstChild("FeedingPoint",true)
	if not otherHost:IsA("BasePart") then otherHost=otherHost:FindFirstChildWhichIsA("BasePart",true) end
	check(not Feed.preview(player,other,otherHost).Available,"Other base rejected")
	player.Character:PivotTo(host.CFrame+Vector3.new(100,3,0))
	check(not Feed.preview(player,base,host).Available,"Distance rejected") home()
	for _,state in {"StudioReadOnly","LoadFailed","InvalidData","Conflict","Loading"} do
		overrideStatus={Status=state,CanSave=false,Closing=false}
		check(not Feed.preview(player,base,host).Available and Resource.owned(player,id),state.." keeps item")
	end
	overrideStatus={Status="Loaded",CanSave=true,Closing=true}
	check(not Feed.preview(player,base,host).Available,"Closing rejects feed") overrideStatus=nil
	current().EquippedMonster="MissingPet"
	check(not Feed.preview(player,base,host).Available,"Missing owned pet rejected") current().EquippedMonster="MagmaRex"
	preview=Feed.preview(player,base,host)
	current().Monsters.MagmaRex.Flesh+=1
	check(not Feed.confirm(player,preview.Ticket) and Resource.owned(player,id),"Stale pet snapshot rejected")
	preview=Feed.preview(player,base,host)
	check(Carry.forceDrop(player,player.Character,"Fixture"),"Drop works before confirmation")
	acquire(id)
	check(not Feed.confirm(player,preview.Ticket),"Same GUID new acquisition rejects old ticket")
	preview=Feed.preview(player,base,host)
	check(not Feed.confirm(player,"forged-guid") and not Feed.confirm(player,{}),"Invalid payloads cannot claim")
	local before=PD.copy(current().Monsters.MagmaRex)
	local wins=0
	for _=1,20 do task.spawn(function() if Feed.confirm(player,preview.Ticket) then wins+=1 end end) end
	check(wins==1,"Twenty simultaneous tasks grant exactly once")
	local record=current().Monsters.MagmaRex
	check(record.TotalGrowth==before.TotalGrowth+definition.Growth and record.Growth==preview.GrowthAfter
		and record.GrowthReserve==preview.GrowthReserveAfter,"Exact Growth once, including Phase 4B overflow/one-stage plan")
	check(record.Flesh==before.Flesh+(definition.Affinities.Flesh or 0) and record.Flora==before.Flora+(definition.Affinities.Floral or 0)
		and record.Mineral==before.Mineral+(definition.Affinities.Mineral or 0),"Exact affinity once")
	check(not Resource.getRecord(id) and not Carry.get(player),"Authoritative resource consumed")
	check(not player.Character:FindFirstChild("CarriedResource") and player.Character.Humanoid.WalkSpeed==16 and player:GetAttribute("CarriedInstanceId")=="","Carry visual movement HUD cleared")
	local expected=PD.copy(record)
	check(session:release(key) and writes==1,"Existing SessionStore saves fake session")
	check(not Data.isWritable(player) and not Feed.confirm(player,preview.Ticket),"Released session cannot replay")
	session:load(key)
	check(session:status(key).Status=="Loaded" and current().Monsters.MagmaRex.TotalGrowth==expected.TotalGrowth
		and current().Monsters.MagmaRex.Flora==expected.Flora and current().Monsters.MagmaRex.PetId=="legacy-owned-id","Rejoin restores Growth affinity and owned ID")
	-- Actual server/client transport and visible native UI; paired client fixture sends confirmation spam.
	id=available() acquire(id)
	local remote=game.ReplicatedStorage.Remotes.FeedInteraction
	local feedCount=current().Stats.Feeds
	preview=Feed.preview(player,base,host)
	script:SetAttribute("Progress","Client preview")
	remote:FireClient(player,preview)
	assert(waitFor(function() return current().Stats.Feeds==feedCount+1 end,45),"Client confirmation did not arrive")
	task.wait(0.5)
	check(current().Stats.Feeds==feedCount+1 and not Resource.getRecord(id),"Real client remote spam consumes once")
	-- Presentation exceptions after the core transaction cannot turn success into lost rewards.
	id=available() acquire(id) preview=Feed.preview(player,base,host)
	local Monster=require(S.MonsterService) local publish=Monster.publish
	Monster.publish=function() error("Intentional presentation fixture") end
	local accepted=Feed.confirm(player,preview.Ticket) Monster.publish=publish
	check(accepted and not Resource.getRecord(id),"Presentation failure preserves committed result")
	Monster.publish(player)
	-- Death and respawn invalidate a previous confirmation, preserving the Phase 3 drop policy.
	id=available() acquire(id) preview=Feed.preview(player,base,host)
	local oldCharacter=player.Character local total=current().Monsters.MagmaRex.TotalGrowth
	oldCharacter.Humanoid.Health=0
	check(not Feed.confirm(player,preview.Ticket),"Dead character cannot confirm")
	assert(waitFor(function() return not Carry.get(player) end,5))
	check(Resource.getRecord(id).State=="DROPPED" and current().Monsters.MagmaRex.TotalGrowth==total,"Death drops same GUID without reward")
	player:LoadCharacterAsync()
	assert(waitFor(function() return player.Character~=oldCharacter and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,10))
	task.wait(1) player.Character.HumanoidRootPart.Anchored=true home()
	check(not Feed.confirm(player,preview.Ticket),"Old character preview cannot affect respawn")
	-- Carry through the actual synchronized reset; feeding carried loot remains allowed in Reset.
	id=available() acquire(id)
	script:SetAttribute("Progress","Waiting for actual reset")
	assert(waitFor(function() return Resource.getSnapshot().Phase=="Reset" end,310),"Reset deadline")
	check(Resource.owned(player,id),"Actual reset preserves carried GUID")
	preview=Feed.preview(player,base,host)
	check(preview.Available and Feed.confirm(player,preview.Ticket),"Feed during reset succeeds exactly once")
	check(not Feed.confirm(player,preview.Ticket) and #Spawn.validate()==0,"Reset replay cannot duplicate")
end,debug.traceback)
Data.get,Data.getStatus=get,status
if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
	player.Character.HumanoidRootPart.Anchored=false
	if originalFrame then player.Character:PivotTo(originalFrame) end
end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase4AIntegration] PASS "..checks) else warn(failure) end
