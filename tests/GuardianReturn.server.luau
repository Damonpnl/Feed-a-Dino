-- Opt-in Studio integration: real body contact, recovery and unchanged manual drops.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server
local D,C,R,G,Spawn,Catch=require(S.DataService),require(S.CarryService),require(S.ResourceService),require(S.GuardianService),require(S.SpawnService),require(S.GuardianCatch)
local p=game.Players:GetPlayers()[1]
assert(D.isWritable(p) and D.getStatus(p).Backend=="StudioMemory")
local origin=p.Character:GetPivot() local root=p.Character.HumanoidRootPart
local checks=0 local token
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.03) until os.clock()>stop return false end
local ok,err=xpcall(function()
	check(not C.get(p),"Starts without carry")
	G.resetAll() Catch.release(p) root.Anchored=true
	local home=G.getSnapshot("Grasslands").Home
	p.Character:PivotTo(CFrame.new(home-Vector3.xAxis*60))
	token=assert(Spawn.devGrant(p,"Grasslands","RawMeat","none"))
	local spawn=R.getRecord(token).SpawnPosition
	local guardian
	for _,m in workspace.GeneratedGameplay.Guardians:GetChildren() do if m.PrimaryPart:GetAttribute("AreaId")=="Grasslands" then guardian=m.PrimaryPart end end
	check(waitFor(function() return guardian:GetAttribute("GuardianState")=="PURSUING" end,4),"Guardian pursues")
	p.Character:PivotTo(CFrame.new(guardian.Position))
	check(waitFor(function() return not C.get(p) end,2),"Actual body catch clears carry")
	local record=R.getRecord(token)
	check(record and record.State=="DROPPED" and (record.Position-spawn).Magnitude<.1,"Body catch returns same GUID to original spawn")
	check(tostring(p:GetAttribute("DropReason")):find("GuardianCatch:",1,true)~=nil,"Body catch path executed")
	check(not C.forceDrop(p,p.Character,"GuardianCatch:Grasslands",true),"Repeated hit cannot duplicate")
	G.resetAll() Catch.release(p)
	p.Character:PivotTo(CFrame.new(record.Position+Vector3.yAxis*3)) task.wait(.25)
	check(Spawn.pickup(p,token),"Returned feed remains collectible")
	G.resetAll()
	p.Character:PivotTo(CFrame.new(spawn+Vector3.new(-12,3,0)))
	check(C.forceDrop(p,p.Character,"Manual"),"Manual drop still works")
	check((R.getRecord(token).Position-spawn).Magnitude>5,"Manual drop stays near player instead of returning")
	check(#Spawn.validate()==0,"No duplicate models or records")
end,debug.traceback)
G.resetAll() Catch.release(p)
if C.get(p) then C.forceDrop(p,p.Character,"Fixture cleanup") end
if token then R.releaseToken("Grasslands",token) end
root.Anchored=false p.Character:PivotTo(origin)
script:SetAttribute("PassedChecks",checks)
script:SetAttribute("Result",if ok then "PASS" else err)
