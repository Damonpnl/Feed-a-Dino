-- Opt-in Studio fault injection for partial visual attachment; never writes saves.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server
local Spawn,Carry,Data,Guardian,Metadata=require(S.SpawnService),require(S.CarryService),require(S.DataService),require(S.GuardianService),require(S.BillboardMetadataService)
local p=game.Players:GetPlayers()[1] local checks=0
local originalCreate,originalPower,originalFrame=Metadata.Create,Data.get(p).Power,p.Character:GetPivot()
local function check(v,m) assert(v,m) checks+=1 end
local ok,failure=xpcall(function()
	Guardian.resetAll()
	local id,r
	for key,row in Spawn.getSnapshot().Records do if row.State=="AVAILABLE" and row.AreaId=="Grasslands" then id,r=key,row break end end
	Data.get(p).Power=1e12
	for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==id then p.Character:PivotTo(m.PrimaryPart.CFrame+Vector3.new(0,3,0)) end end
	Metadata.Create=function(self,target,options)
		if target.Name=="CarriedResource" then error("Intentional Phase3 rollback fixture") end
		return originalCreate(self,target,options)
	end
	check(not Spawn.pickup(p,id),"Failed attachment rejects pickup")
	Metadata.Create=originalCreate
	check(not Carry.get(p) and not p.Character:FindFirstChild("CarriedResource"),"Partial attachment completely removed")
	check(Spawn.getRecord(id).State=="AVAILABLE" and #Spawn.validate()==0,"One original world record restored")
	check(Guardian.getSnapshot("Grasslands").Disturbance==0,"Failed attachment cannot disturb guardian")
	task.wait(0.17)
	check(Spawn.pickup(p,id),"Normal pickup succeeds after rollback")
	local expected=16*(1-require(game.ReplicatedStorage.Shared.ResourceDefinitions).get(r.ResourceId).CarrySlowdown)
	p.Character.Humanoid.WalkSpeed=200 task.wait()
	check(math.abs(p.Character.Humanoid.WalkSpeed-expected)<0.001,"Single movement writer reasserts configured speed")
	check(Carry.forceDrop(p,p.Character,"Test"),"Cleanup normal carry")
	check(p.Character.Humanoid.WalkSpeed==16,"No permanent speed modifier")
end,debug.traceback)
Metadata.Create=originalCreate
if Carry.get(p) then Carry.forceDrop(p,p.Character,"TestCleanup") end
Data.get(p).Power=originalPower Data.publish(p) p.Character:PivotTo(originalFrame) Guardian.resetAll()
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3Rollback] PASS "..checks.." checks") else warn("[Phase3Rollback] "..failure) end
