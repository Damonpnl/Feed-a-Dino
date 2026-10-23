-- Install before Phase5ALoop. Real client transport; no authoritative mutation.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer local checks=0
local function check(v,m) assert(v,m) checks+=1 end
local function waitFor(fn,seconds) local deadline=os.clock()+seconds repeat if fn() then return true end task.wait(0.05) until os.clock()>deadline return false end
local ok,failure=xpcall(function()
	local ui=p.PlayerGui:WaitForChild("MonsterHud"):WaitForChild("EconomyPanel")
	check(ui.Visible and ui:FindFirstChild("Train") and ui:FindFirstChild("Upgrade"),"Native economy controls")
	check(ui.Details.Text:find("Cash",1,true) and ui.Details.Text:find("Power",1,true),"Cash and Power HUD")
	check(waitFor(function() return p:GetAttribute("TrainerTier")==2 end,160),"Purchase replicated") task.wait(0.2)
	check(ui.Details.Text:find("Weighted Sled",1,true) and ui.Details.Text:find("Iron Rig",1,true),"Shop updates current and next tiers")
	local remote=game.ReplicatedStorage.Remotes.TrainingInteraction
	for _=1,50 do remote:FireServer("Upgrade",2) end task.wait(0.3)
	remote:FireServer("Upgrade",{Tier=10,Cash=1e12,Power=1e12}) task.wait(0.3)
	remote:FireServer("GiveCash",1e12) task.wait(0.3)
	check(p:GetAttribute("TrainerTier")==2,"Forged and replayed purchases cannot advance tier")
	check(waitFor(function() return p:GetAttribute("TrainingActive")==true end,90),"Actual native start replicated")
	check(ui.Train.Text=="STOP TRAINING","Training control updates")
	local before=p:GetAttribute("Power")
	for _=1,100 do remote:FireServer("Start",{PowerGain=1e12}) end task.wait(1.1)
	check(p:GetAttribute("Power")-before<=75,"Remote start spam never creates extra tick loops")
	check(p:GetAttribute("TrainingGainPerSecond")==37.5,"Evolved pet/trainer rate reaches client")
end,debug.traceback)
script:SetAttribute("PassedChecks",checks) script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[Phase5APresentation] PASS "..checks) else warn(failure) end
