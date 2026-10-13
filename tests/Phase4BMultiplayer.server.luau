-- Two actual Studio clients; no production persistence. Launch via StudioTestService.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase4BMultiplayer" then return end
local S=game.ServerScriptService:WaitForChild("Server")
local Data,Monster,Store=require(S.DataService),require(S.MonsterService),require(S.SessionStore)
local PD,E=require(game.ReplicatedStorage.Shared.PlayerData),require(game.ReplicatedStorage.Shared.EvolutionCalculator)
local saved={} local sessions=Store.new({get=function(k) return PD.copy(saved[k]) end,update=function(k,fn) saved[k]=fn(saved[k]) return PD.copy(saved[k]) end})
local get,status=Data.get,Data.getStatus local cleanup local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds) local untilTime=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>untilTime return false end
local function point(p)
	local b=workspace.Bases[p:GetAttribute("AssignedBaseName")] local v=b:FindFirstChild("FeedingPoint",true)
	return if v:IsA("BasePart") then v else v:FindFirstChildWhichIsA("BasePart",true)
end
local function makePending(p,revision)
	local d=Data.get(p) local r=PD.createMonster("ProtoRex") r.PetId="fixture:"..p.UserId
	r.Growth=100 r.TotalGrowth=100 r.Flesh=80 r.Flora=80 r.Revision=revision E.afterFeed(r)
	d.Monsters.ProtoRex=r
	return {PetKey="ProtoRex",Token=r.PendingEvolution.Token,BranchId="ProtoRex:Fangling"}
end
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2])
			and ps[1]:GetAttribute("AssignedBaseName") and ps[2]:GetAttribute("AssignedBaseName")
	end,40),"Two real players initialized") task.wait(1)
	local ps=game.Players:GetPlayers() local a,b=ps[1],ps[2]
	for _,p in ps do sessions:load(tostring(p.UserId)) p.Character.HumanoidRootPart.Anchored=true end
	Data.get=function(p) return sessions:get(tostring(p.UserId)) end
	Data.getStatus=function(p) return sessions:status(tostring(p.UserId)) end
	cleanup=game.Players.PlayerRemoving:Connect(function(p) sessions:release(tostring(p.UserId)) end)
	local ra,rb=makePending(a,1),makePending(b,2)
	a.Character:PivotTo(point(b).CFrame+Vector3.new(0,3,0))
	check(not Monster.chooseEvolution(a,ra),"Other base cannot authorize evolution")
	for _,p in ps do p.Character:PivotTo(point(p).CFrame+Vector3.new(0,3,0)) end task.wait(0.21)
	check(not Monster.chooseEvolution(a,rb),"Other pet's pending token rejected") task.wait(0.21)
	local wins={} task.spawn(function() wins[1]=Monster.chooseEvolution(a,ra) end) task.spawn(function() wins[2]=Monster.chooseEvolution(b,rb) end)
	check(wins[1] and wins[2],"Independent simultaneous evolutions")
	check(Data.get(a).Monsters.ProtoRex.PetId~=Data.get(b).Monsters.ProtoRex.PetId,"Distinct pet identities")
	check(Data.get(a).Stats.Evolutions==1 and Data.get(b).Stats.Evolutions==1,"Exactly one transition each") task.wait(0.21)
	check(not Monster.chooseEvolution(a,ra) and not Monster.chooseEvolution(b,rb),"Both replays rejected")
	local preserved=PD.copy(Data.get(a).Monsters.ProtoRex)
	local pending=makePending(b,3) local key=tostring(b.UserId)
	b:Kick("Phase4B isolated pending-choice disconnect test")
	check(waitFor(function() return b.Parent==nil and not Data.get(b) end,10),"Disconnected session released")
	check(not Monster.chooseEvolution(b,pending),"Disconnect cannot commit evolution")
	local restored=sessions:load(key).Monsters.ProtoRex
	check(restored.PendingEvolution.Token==pending.Token and restored.Stage==0,"Disconnect persisted identical pending choice")
	check(Data.get(a).Monsters.ProtoRex.PetId==preserved.PetId and Data.get(a).Monsters.ProtoRex.Revision==preserved.Revision,"Other player remains unchanged")
end,debug.traceback)
if cleanup then cleanup:Disconnect() end Data.get,Data.getStatus=get,status
STS:EndTest({Result=if ok then "PASS" else failure,PassedChecks=checks,Mode="Two actual Studio clients; isolated SessionStore"})
