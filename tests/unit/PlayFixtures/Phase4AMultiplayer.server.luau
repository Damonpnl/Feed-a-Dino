-- Opt-in two actual Studio clients; temporary injected SessionStore, never live saves.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase4AMultiplayer" then return end
local S=game.ServerScriptService:WaitForChild("Server")
local Data,Feed,Carry,Spawn,Resource,Guardian=require(S.DataService),require(S.FeedService),require(S.CarryService),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService)
local PD=require(game.ReplicatedStorage.Shared.PlayerData)
local Store=require(S.SessionStore)
local db={}
local sessions=Store.new({get=function(k) return PD.copy(db[k]) end,update=function(k,fn) db[k]=fn(db[k]) return PD.copy(db[k]) end})
local originalGet,originalStatus=Data.get,Data.getStatus
local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds) local deadline=os.clock()+seconds repeat if fn() then return true end task.wait(0.03) until os.clock()>deadline return false end
local function marker(p)
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
	local point=base:FindFirstChild("FeedingPoint",true)
	return base,if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
end
local function home(p) local _,host=marker(p) p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0)) end
local function go(p,id)
	for _,model in workspace.GeneratedGameplay.Resources:GetChildren() do
		if model:GetAttribute("ResourceInstanceId")==id then p.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0)) return end
	end error("Missing resource model")
end
local cleanup
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2])
			and ps[1]:GetAttribute("AssignedBaseName") and ps[2]:GetAttribute("AssignedBaseName")
	end,40),"Two actual clients ready")
	task.wait(1)
	local ps=game.Players:GetPlayers() local a,b=ps[1],ps[2]
	check(a.UserId~=b.UserId,"Distinct players")
	for _,p in ps do
		local d=sessions:load(tostring(p.UserId)) d.Power=1e12
		d.EquippedMonster="MagmaRex" d.Monsters.MagmaRex=PD.createMonster("MagmaRex")
		p.Character.HumanoidRootPart.Anchored=true
	end
	Data.get=function(p) return sessions:get(tostring(p.UserId)) end
	Data.getStatus=function(p) return sessions:status(tostring(p.UserId)) end
	cleanup=game.Players.PlayerRemoving:Connect(function(p) sessions:release(tostring(p.UserId)) end)
	Guardian.resetAll()
	local ids={} for id,r in Resource.getSnapshot().Records do if r.AreaId=="Grasslands" then table.insert(ids,id) end end
	go(a,ids[1]) go(b,ids[1])
	local wins={} task.spawn(function() wins[1]=Spawn.pickup(a,ids[1]) end) task.spawn(function() wins[2]=Spawn.pickup(b,ids[1]) end)
	check((wins[1] and not wins[2]) or (wins[2] and not wins[1]),"One contested resource winner")
	local winner,loser=if wins[1] then a else b,if wins[1] then b else a
	check(Carry.forceDrop(winner,winner.Character,"Fixture"),"Contest winner drops")
	task.wait(0.21) go(loser,ids[1]) check(Spawn.pickup(loser,ids[1]),"Other player recovers same GUID")
	go(winner,ids[2]) check(Spawn.pickup(winner,ids[2]),"Other player carries independent resource")
	home(a) home(b)
	local baseA,hostA=marker(a) local baseB,hostB=marker(b)
	check(not Feed.preview(a,baseB,hostB).Available and not Feed.preview(b,baseA,hostA).Available,"Cross-owner feeding rejected")
	local pa,pb=Feed.preview(a,baseA,hostA),Feed.preview(b,baseB,hostB)
	check(pa.Available and pb.Available,"Independent previews")
	check(not Feed.confirm(a,pb.Ticket) and not Feed.confirm(b,pa.Ticket),"Other player's ticket rejected")
	local results={}
	task.spawn(function() results[1]=Feed.confirm(a,pa.Ticket) end)
	task.spawn(function() results[2]=Feed.confirm(b,pb.Ticket) end)
	check(results[1] and results[2],"Simultaneous independent feeds succeed")
	check(Data.get(a).Stats.Feeds==1 and Data.get(b).Stats.Feeds==1,"One reward per owner")
	check(not Feed.confirm(a,pa.Ticket) and not Feed.confirm(b,pb.Ticket),"Both replays rejected")
	check(not Resource.getRecord(ids[1]) and not Resource.getRecord(ids[2]) and #Spawn.validate()==0,"Both original GUIDs consumed without duplicate")
	task.wait(0.21) Guardian.resetAll() go(b,ids[3]) check(Spawn.pickup(b,ids[3]),"Pickup before disconnect") home(b)
	local pending=Feed.preview(b,baseB,hostB)
	b:Kick("Phase4A isolated disconnect test")
	check(waitFor(function() return b.Parent==nil and not Carry.get(b) and not Data.get(b) end,10),"Disconnect clears carry and injected session")
	check(not Feed.confirm(b,pending.Ticket),"Disconnect confirmation cannot grant effects")
	local remaining=Resource.getRecord(ids[3])
	check(not remaining or (remaining.State=="DROPPED" and remaining.OwnerUserId==nil),"Disconnect leaves no carried owner; earlier character-removal drop remains eligible")
	check(db[tostring(b.UserId)].Stats.Feeds==1,"Fake disconnect save retains only legitimate prior feed")
end,debug.traceback)
if cleanup then cleanup:Disconnect() end
Data.get,Data.getStatus=originalGet,originalStatus
STS:EndTest({Result=if ok then "PASS" else failure,PassedChecks=checks,Mode="Two actual Studio clients; isolated fake persistence"})
