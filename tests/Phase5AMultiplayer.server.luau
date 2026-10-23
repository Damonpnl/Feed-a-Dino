-- Opt-in two real Studio clients. Ordinary StudioMemory backend; no cloud operations.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase5AMultiplayer" then return end
local S=game.ServerScriptService:WaitForChild("Server")
local Data,Training,Monster=require(S.DataService),require(S.TrainingService),require(S.MonsterService)
local PD=require(game.ReplicatedStorage.Shared.PlayerData)
local checks=0 local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds) local deadline=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>deadline return false end
local ok,failure=xpcall(function()
	check(waitFor(function()
		local ps=game.Players:GetPlayers()
		return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2])
			and ps[1]:GetAttribute("AssignedBaseName") and ps[2]:GetAttribute("AssignedBaseName")
	end,40),"Two actual clients ready")
	task.wait(1)
	local ps=game.Players:GetPlayers() local a,b=ps[1],ps[2]
	local function station(p) local base=workspace.Bases[p:GetAttribute("AssignedBaseName")] return base,base:FindFirstChild("TrainingStation",true) end
	local ba,sa=station(a) local bb,sb=station(b)
	check(ba~=bb and sa~=sb,"Separate owned bases/stations")
	for _,p in ps do
		local d=Data.get(p) d.Cash=25 d.Power=0 d.TrainerTier=1 d.BaseUpgrades.TrainingLevel=0
		d.Monsters={ProtoRex=PD.createMonster("ProtoRex")} d.EquippedMonster="ProtoRex" Monster.publish(p)
		local _,s=station(p) p.Character.HumanoidRootPart.Anchored=true p.Character:PivotTo(s.CFrame+Vector3.new(0,3,0))
	end
	check(not Training.train(a,bb,sb) and not Training.upgrade(a,bb,sb,2),"Cross-base calls rejected") task.wait(0.3)
	check(Training.train(a,ba,sa) and Training.train(b,bb,sb),"Both owners train independently")
	task.wait(1.1) check(Data.get(a).Power==10 and Data.get(b).Power==10,"One tick per owner")
	local wins=0 for _=1,50 do task.spawn(function() if Training.upgrade(a,ba,sa,2) then wins+=1 end end) end
	check(wins==1 and Data.get(a).TrainerTier==2 and Data.get(b).TrainerTier==1,"Concurrent purchase commits once, other player untouched")
	task.wait(0.3) check(not Training.upgrade(a,ba,sa,2),"Delayed replay rejected")
	check(sa:GetAttribute("TrainerTier")==2 and sb:GetAttribute("TrainerTier")==1,"Only owner's visual changes")
	local before=Data.get(a).Power
	b:Kick("Phase5A disposable disconnect test")
	check(waitFor(function() return b.Parent==nil and Data.get(b)==nil end,10),"Disconnect releases session")
	check(not Training.train(b,bb,sb) and not Training.upgrade(b,bb,sb,2),"Disconnected player cannot earn/spend")
	task.wait(1.1) check(Data.get(a).Power>before,"Other owner's tick survives disconnect")
	check(bb:GetAttribute("OwnerUserId")==nil and sb:GetAttribute("TrainerTier")==1,"Vacated station resets")
	check(Data.save(a),"Remaining player saves through memory backend")
end,debug.traceback)
STS:EndTest({Result=if ok then "PASS" else failure,PassedChecks=checks,Mode="Two actual clients / StudioMemory"})
