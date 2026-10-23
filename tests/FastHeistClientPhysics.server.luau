-- Opt-in client-owned physics observation. Drive W/A/S through Studio MCP after
-- Ready=true, then set Finish=true. Never substitutes anchored/MoveTo motion.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server
local D,C,G=require(S.DataService),require(S.CarryService),require(S.GuardianService)
local R=require(S.ResourceService)
local p=game.Players:GetPlayers()[1]
assert(D.isWritable(p) and D.getStatus(p).Backend=="StudioMemory" and not C.get(p))
local data=D.get(p) local oldPower,oldSlow=data.Power,data.SlowMode
local frame=p.Character:GetPivot() local root=p.Character.HumanoidRootPart
local rows={} local connection
local ok,err=xpcall(function()
	local readyDeadline=os.clock()+45
	repeat task.wait(.1) until (R.getSnapshot().Phase=="Normal" and R.getSnapshot().NextResetAt-workspace:GetServerTimeNow()>20) or os.clock()>readyDeadline
	assert(R.getSnapshot().Phase=="Normal" and R.getSnapshot().NextResetAt-workspace:GetServerTimeNow()>20,"Stable normal field for physics isolation")
	data.Power=150e6 data.SlowMode=false D.publish(p) C.recalculateMovement(p) G.resetAll()
	local lane=G.getRunway()
	p.Character:PivotTo(CFrame.new(lane.origin+lane.axis*(lane.entrance+65)+Vector3.yAxis*4))
	root.Anchored=false root:SetNetworkOwner(p)
	task.wait(.5)
	assert(root:GetNetworkOwner()==p,"Actual character must be client-owned")
	script:SetAttribute("Ready",true)
	local last=root.Position local at=os.clock() local distance=0 local started=at local maximum=0 local nextTrace=0
	connection=game:GetService("RunService").Heartbeat:Connect(function()
		local t=os.clock() local pos=root.Position
		local delta=Vector3.new(pos.X-last.X,0,pos.Z-last.Z).Magnitude
		distance+=delta maximum=math.max(maximum,delta/math.max(t-at,.001)) last=pos at=t
		if t>=nextTrace then
			table.insert(rows,{Time=t-started,X=pos.X,Z=pos.Z,WalkSpeed=p.Character.Humanoid.WalkSpeed}) nextTrace=t+.1
		end
	end)
	local deadline=os.clock()+90 repeat task.wait(.1) until script:GetAttribute("Finish") or os.clock()>deadline
	assert(script:GetAttribute("Finish"),"MCP input sequence did not complete")
	assert(root:GetNetworkOwner()==p and p.Character.Humanoid.Health>0,"Client ownership and health retained")
	assert(distance>80,"Actual keyboard movement must travel a meaningful distance")
	script:SetAttribute("Distance",distance) script:SetAttribute("Seconds",os.clock()-started)
	-- Replication bursts can exceed configured speed per server frame. Preserve the
	-- raw trace; do not label that burst an exploit or steady achieved velocity.
	script:SetAttribute("PeakSampleSpeed",maximum)
end,debug.traceback)
if connection then connection:Disconnect() end
script:SetAttribute("Rows",game.HttpService:JSONEncode(rows))
data.Power,data.SlowMode=oldPower,oldSlow D.publish(p) C.recalculateMovement(p)
if p.Character and root.Parent then p.Character:PivotTo(frame) root:SetNetworkOwnershipAuto() end
script:SetAttribute("Result",if ok then "PASS" else err)
