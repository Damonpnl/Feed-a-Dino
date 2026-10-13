-- Opt-in paired client observer; uses server-generated carry/Power/guardian updates.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local p=game.Players.LocalPlayer
local Presentation=require(p.PlayerScripts.Client.GuardianPresentation)
local checks=0 local seen={} local wakes,attacks,drops=0,0,0
local connections={}
local function check(v,m) assert(v,m) checks+=1 end
table.insert(connections,Presentation.Wake.Event:Connect(function() wakes+=1 end))
table.insert(connections,Presentation.Attack.Event:Connect(function() attacks+=1 end))
table.insert(connections,Presentation.ResourceDropped.Event:Connect(function() drops+=1 end))
local ok,failure=xpcall(function()
	script:SetAttribute("Ready",true)
	local deadline=os.clock()+220
	repeat
		local stage=p:GetAttribute("Phase3UIStage")
		local hud=p.PlayerGui:FindFirstChild("MonsterHud")
		if stage and not seen[stage] and hud then
			if stage=="PowerNotice" then
				check(hud.PowerNotice.Visible and hud.PowerNotice.Text==p:GetAttribute("PowerNotice"),"Authoritative formatted toast visible")
			elseif stage=="Carrying" then
				check(hud.CarryCard.Visible and string.find(hud.CarryCard.Text,p:GetAttribute("CarriedName"),1,true),"Carry card name")
				check(string.find(hud.CarryCard.Text,p:GetAttribute("CarriedRarity"),1,true),"Carry card rarity")
			elseif stage=="Empty" then check(not hud.CarryCard.Visible,"Empty carry card hidden") end
			seen[stage]=true
		end
		task.wait(0.1)
	until p:GetAttribute("Phase3UIStage")=="Done" or os.clock()>deadline
	check(seen.PowerNotice and seen.Carrying and seen.Empty,"All paired UI stages observed")
	check(wakes>=5 and attacks>=5,"All guardian wake/attack hooks")
	check(drops>=5,"Resource drop hooks")
	check(p.PlayerGui.GuardianHud.GuardianStatus.Text~="","Guardian meter/state HUD")
	Presentation.Stop()
	check(Presentation.GetStats().Connections==0 and not p.PlayerGui:FindFirstChild("GuardianHud"),"Presentation stop cleanup")
	Presentation.Start()
	check(Presentation.GetStats().Running,"Presentation restart")
end,debug.traceback)
for _,c in connections do c:Disconnect() end
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
if ok then print("[Phase3Presentation] PASS "..checks.." checks") else warn("[Phase3Presentation] "..failure) end
