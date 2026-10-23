-- Two actual clients join a fresh server; first join closes the field, second
-- must arrive within that real ten-second window. Does not prolong reset timing.
local Test=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() or Test:GetTestArgs()~="FastHeistJoinReset" then return end
local S=game.ServerScriptService:WaitForChild("Server")
local R,D,C,G=require(S.ResourceService),require(S.DataService),require(S.CarryService),require(S.GuardianService)
local State=require(game.ReplicatedStorage.Shared.FieldState)
local original=State.step local field local joins={} local cutoff local checks=0
local function waitFor(fn,t) local untilTime=os.clock()+t repeat if fn() then return true end task.wait(.03) until os.clock()>untilTime return false end
local function check(v,m) assert(v,m) checks+=1 end
State.step=function(self,...) field=self return original(self,...) end
local connection=game.Players.PlayerAdded:Connect(function(p)
	local phase=field and field.Phase
	table.insert(joins,{UserId=p.UserId,Phase=phase,At=workspace:GetServerTimeNow()})
	if #joins==1 and field then field.NextResetAt=workspace:GetServerTimeNow()-.001 cutoff=field.NextResetAt R.step() end
end)
local ok,err=xpcall(function()
	check(waitFor(function() return field end,10),"Existing field initialized before client join")
	check(waitFor(function() return #joins==2 end,45),"Two actual joins observed")
	check(joins[2].Phase=="Reset" and joins[2].At<cutoff+10,"Second client actually joined during closure")
	check(waitFor(function()
		for _,p in game.Players:GetPlayers() do if not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") or not D.get(p) or not p:GetAttribute("AssignedBaseName") then return false end end
		return #game.Players:GetPlayers()==2
	end,8),"Both late-initializing characters and sessions ready")
	check(R.getSnapshot().Phase=="Reset","Initialization did not bypass or prematurely finish closure")
	for _,p in game.Players:GetPlayers() do
		check(D.isWritable(p) and D.getStatus(p).Backend=="StudioMemory","Late join uses isolated memory")
		p.Character:PivotTo(CFrame.new(G.getSnapshot("Grasslands").Home+Vector3.yAxis*4))
		R.step()
		check(p.Character.HumanoidRootPart.Position.X<workspace.GeneratedGameplay.SafeZoneBoundary.Position.X,"New client's closed-field entry evacuated")
		check(not C.get(p) and p:GetAttribute("FieldEvacuatedCycle")~=nil,"New client has no stale ownership")
	end
	check(waitFor(function() return R.getSnapshot().Phase=="Normal" end,12),"Normal field resumes after closure")
	check(workspace:GetServerTimeNow()>=cutoff+10 and #R.validate()==0,"Full interval and resource integrity")
end,debug.traceback)
State.step=original connection:Disconnect()
Test:EndTest({Result=if ok then "PASS" else err,PassedChecks=checks,Joins=joins,Mode="Two actual clients; first join triggers real reset"})
