-- Two actual Studio clients; isolated memory sessions, not cloud accounts.
local STS=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or STS:GetTestArgs()~="Phase5BMultiplayer" then return end
local S=game.ServerScriptService:WaitForChild("Server") local H=game.ReplicatedStorage:WaitForChild("Shared")
local Data,Carry,Catch,Spawn,Resource,Guardian=require(S.DataService),require(S.CarryService),require(S.GuardianCatch),require(S.SpawnService),require(S.ResourceService),require(S.GuardianService)
local State=require(H.FieldState) local oldStep=State.step local field local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.03) until os.clock()>stop return false end
local ok,failure=xpcall(function()
	check(waitFor(function() local ps=game.Players:GetPlayers(); return #ps==2 and ps[1].Character and ps[2].Character and Data.get(ps[1]) and Data.get(ps[2]) and ps[1]:GetAttribute("AssignedBaseName") and ps[2]:GetAttribute("AssignedBaseName") end,40),"Two real clients ready")
	task.wait(1) local ps=game.Players:GetPlayers() local a,b=ps[1],ps[2]
	Data.get(a).Power=1000 Data.get(b).Power=150e6
	for _,p in ps do Data.get(p).SlowMode=false Data.publish(p) Carry.recalculateMovement(p) end
	check(a.Character.Humanoid.WalkSpeed==26 and b.Character.Humanoid.WalkSpeed==72,"Independent Power-derived bases")
	check(Carry.setSlowMode(a,true) and a.Character.Humanoid.WalkSpeed==16 and b.Character.Humanoid.WalkSpeed==72,"Preference affects only sender")
	check(not Carry.setSlowMode(a,{Player=b,Enabled=true}) and not Data.get(b).SlowMode,"Forged cross-player target rejected")
	State.step=function(self,...) field=self return oldStep(self,...) end
	check(waitFor(function() return field~=nil end,5),"Existing field") State.step=oldStep
	local function grab(p,area,id)
		local n=field.Nodes[area..":Node01"] if n.RecordId then Resource.releaseToken(area,n.RecordId) end
		local r=field:create(n,id,"Phase5BMP") Resource.step()
		p.Character.HumanoidRootPart.Anchored=true
		for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==r.InstanceId then p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) end end
		check(Spawn.pickup(p,r.InstanceId),"Pickup "..area) return r.InstanceId
	end
	local ia=grab(a,"Grasslands","PrimeMeat") local ib=grab(b,"Swamp","SmallFish")
	check(math.abs(a.Character.Humanoid.WalkSpeed-16*.98)<.001 and math.abs(b.Character.Humanoid.WalkSpeed-52*.95)<.001,"Player-specific carry curve and penalties")
	check(Guardian.getSnapshot("Grasslands").State~="SLEEPING" and Guardian.getSnapshot("Swamp").State~="SLEEPING","Two area chases independent")
	local bSpeed=b.Character.Humanoid.WalkSpeed
	check(Carry.forceDrop(a,a.Character,"Test") and a.Character.Humanoid.WalkSpeed==16,"A drops with precision preference")
	check(Carry.get(b).token==ib and b.Character.Humanoid.WalkSpeed==bSpeed,"B carry unchanged")
	Guardian.resetAll()
	a.Character.HumanoidRootPart.Anchored=false
	check(Catch.apply(a,a.Character,a.Character:GetPivot().Position-Vector3.xAxis*10,Vector3.xAxis,"Fixture"),"A ragdolls on real client")
	task.wait(.25) Carry.setSlowMode(a,false)
	check(a.Character.Humanoid.WalkSpeed==0 and Catch.isRecovering(a) and b.Character.Humanoid.WalkSpeed==bSpeed,"Toggle cannot cancel recovery or affect B")
	check(waitFor(function() return not Catch.isRecovering(a) end,4),"Recovery completes")
	check(a.Character.Humanoid.WalkSpeed==26,"A recovers current Power base")
	a:LoadCharacterAsync() task.wait(.5)
	check(a.Character.Humanoid.WalkSpeed==26 and b.Character.Humanoid.WalkSpeed==bSpeed,"Respawn keeps independent movement")
	check(#Spawn.validate()==0,"Resource records remain unique")
	a:Kick("Disposable Phase5B disconnect")
	check(waitFor(function() return a.Parent==nil end,8),"Disconnect cleanup")
	check(Carry.get(b).token==ib and b.Character.Humanoid.WalkSpeed==bSpeed,"Survivor retains speed and carry")
	check(Data.save(b),"Surviving memory session saves")
end,debug.traceback)
State.step=oldStep
STS:EndTest({Result=if ok then "PASS" else failure,PassedChecks=checks,Mode="Two actual clients / StudioMemory"})
