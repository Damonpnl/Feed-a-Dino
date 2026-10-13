-- Opt-in local stream-out/re-entry and effect cleanup checks, no server state changes.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer
local P=require(p.PlayerScripts.Client.GuardianPresentation)
local checks=0 local part
local function check(v,m) assert(v,m) checks+=1 end
local ok,failure=xpcall(function()
	P.Start()
	local base=P.GetStats().Connections
	local folder=workspace.GeneratedGameplay.Guardians
	part=Instance.new("Part") part.Name="Phase3StreamingFixture" part.Anchored=true part.Transparency=1 part.CanCollide=false
	part:SetAttribute("AreaId","StreamFixture") part:SetAttribute("GuardianState","SLEEPING")
	for _=1,20 do
		part.Parent=folder task.wait()
		check(P.GetStats().Connections==base+2,"Exactly one pair of instance listeners")
		part.Parent=nil task.wait()
		check(P.GetStats().Connections==base,"Stream-out releases instance listeners")
	end
	part:Destroy() part=nil
	local camera=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local offset=camera and camera.CameraOffset
	p:SetAttribute("HazardTick",workspace:GetServerTimeNow()) task.wait(0.05)
	P.Stop()
	check(P.GetStats().Connections==0 and not p.PlayerGui:FindFirstChild("GuardianHud"),"Stop leaves no listeners or HUD")
	check(not camera or camera.CameraOffset==offset,"Stop restores camera offset")
	P.Start() P.Start()
	check(P.GetStats().Connections==base,"Start is idempotent")
end,debug.traceback)
if part then part:Destroy() end
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3PresentationCleanup] PASS "..checks.." checks") else warn("[Phase3PresentationCleanup] "..failure) end
