-- Opt-in isolated Studio sampling. Measures ResourceService.step including lockdown
-- and presentation sync. No claim about production concurrency or GPU performance.
assert(game:GetService("RunService"):IsStudio())
local R=require(game.ServerScriptService.Server.ResourceService)
local old=R.step local samples={} local frames={} local started=os.clock()
R.step=function(...)
	local at=os.clock() local a,b,c=old(...)
	table.insert(samples,(os.clock()-at)*1000)
	return a,b,c
end
local connection=game:GetService("RunService").Heartbeat:Connect(function(dt) table.insert(frames,dt*1000) end)
task.wait(10)
R.step=old connection:Disconnect()
table.sort(samples) table.sort(frames)
local function quantile(values,q) return values[math.max(1,math.ceil(#values*q))] or 0 end
local sum=0 for _,v in samples do sum+=v end
script:SetAttribute("Rows",game.HttpService:JSONEncode({Calls=#samples,Duration=os.clock()-started,MeanMs=sum/math.max(1,#samples),P50Ms=quantile(samples,.5),P95Ms=quantile(samples,.95),MaxMs=quantile(samples,1),FrameP95Ms=quantile(frames,.95),Players=#game.Players:GetPlayers()}))
script:SetAttribute("Result","PASS")
