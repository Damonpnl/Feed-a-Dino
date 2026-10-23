-- Pair with Phase5BLoop. Real native mouse/V actions are supplied through Studio MCP.
local p=game.Players.LocalPlayer
local remote=game.ReplicatedStorage.Remotes:WaitForChild("SetSlowMode")
local checks=0 local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,t) local stop=os.clock()+t repeat if fn() then return true end task.wait(.05) until os.clock()>stop return false end
local ok,failure=xpcall(function()
	local button=p.PlayerGui:WaitForChild("MovementHud"):WaitForChild("SlowMode")
	check(button:IsA("TextButton") and button.Active and button.AbsoluteSize.Y>=44,"Native mouse/touch target")
	check(button.Text:find("OFF",1,true),"Initial preference reflected")
	for _,payload in {32,"true",{Power=150e6,Speed=100},{Player=p,Enabled=true}} do remote:FireServer(payload) task.wait(.22) end
	check(p:GetAttribute("SlowMode")==false,"Malformed remote payloads rejected")
	check(waitFor(function() return p:GetAttribute("Phase5BLoop")=="MODE_CLICK" end,240),"Gameplay loop reaches native mode test")
	script:SetAttribute("Step","CLICK_SLOW_MODE")
	check(waitFor(function() return p:GetAttribute("SlowMode")==true end,90),"Native click enables Slow Mode")
	check(button.Text:find("ON",1,true),"Mode UI updates")
	local power=p:GetAttribute("Power")
	for _=1,50 do remote:FireServer(true,150e6,100) end task.wait(.3)
	check(p:GetAttribute("SlowMode")==true and p:GetAttribute("Power")==power,"Retries are idempotent and ignore reward/speed extras")
	script:SetAttribute("Step","PRESS_V")
	check(waitFor(function() return p:GetAttribute("SlowMode")==false end,90),"Keyboard disables Slow Mode")
	check(p:GetAttribute("Power")==power,"Toggle never changes Power")
end,debug.traceback)
script:SetAttribute("PassedChecks",checks) script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5BPresentation] PASS "..checks) else warn(failure) end
