-- Observe a real server reset without changing client phase or server time.
local player=game.Players.LocalPlayer
local field=game.ReplicatedStorage.WorldFieldState
local lighting=game:GetService("Lighting")
local originalClock,originalBrightness=lighting.ClockTime,lighting.Brightness
local passes=0
local function check(value,message) assert(value,message) passes+=1 end
local ok,failure=xpcall(function()
	while field:GetAttribute("Phase")~="Reset" do task.wait(0.05) end
	task.wait(0.8)
	check(player.PlayerGui.FieldAnnouncements.ResetCountdown.Text=="RESOURCES RESETTING...","Actual server reset text")
	check(math.abs(lighting.ClockTime-20)<0.01,"Actual server reset lighting hook")
	while field:GetAttribute("Phase")=="Reset" do task.wait(0.05) end
	task.wait(0.8)
	check(string.find(player.PlayerGui.FieldAnnouncements.ResetCountdown.Text,"RESOURCES RESET IN",1,true),"Actual reset returns to countdown")
	check(math.abs(lighting.ClockTime-originalClock)<0.01 and math.abs(lighting.Brightness-originalBrightness)<0.01,"Actual reset restores lighting")
	local service=require(player.PlayerScripts.Client.BillboardService)
	local stats=service:GetStats()
	check(stats.Retiring==0,"Reset billboard exits have cleaned up")
	check(stats.Connections==stats.Watchers+3,"Only one attribute watcher per target plus three manager connections")
end,debug.traceback)
script:SetAttribute("Result",if ok then "PASS" else failure)
script:SetAttribute("PassedChecks",passes)
if ok then print("[Phase2ResetObserver] PASS "..passes.." checks") else warn("[Phase2ResetObserver] "..failure) end
