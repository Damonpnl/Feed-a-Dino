-- Pair with Phase4BIntegration before its run. Actual client transport; no reward inputs.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer
local remote=game.ReplicatedStorage.Remotes.FeedInteraction
local connection
connection=p:GetAttributeChangedSignal("Phase4BTest"):Connect(function()
	if p:GetAttribute("Phase4BTest")~="Forgeries" then return end
	connection:Disconnect()
	local checks=0 local function check(v,m) assert(v,m) checks+=1 end
	local ok,failure=xpcall(function()
		task.wait(0.2)
		local panel=p.PlayerGui.MonsterHud.EvolutionChoice
		check(panel.Visible and panel:FindFirstChild("Fangling") and panel:FindFirstChild("Mossback"),"Persistent choice UI visible")
		check(panel.AbsoluteSize.X<=480 and panel.AbsoluteSize.Y<=420,"Choice UI bounded")
		local cost=require(game.ReplicatedStorage.Shared.GrowthStageDefinitions).Stages[0].GrowthRequired
		check(panel.Mossback.Text:find("Stage 1",1,true) and panel.Mossback.Text:find(tostring(cost).." Growth",1,true),"Choice displays stage and configured cost")
		local state=game:GetService("HttpService"):JSONDecode(p:GetAttribute("PendingEvolution"))
		local request={PetKey=p:GetAttribute("OwnedPetKey"),Token=state.Token,BranchId="ProtoRex:Mossback"}
		remote:FireServer("Evolve",{PetKey=request.PetKey,Token="forged",BranchId=request.BranchId}) task.wait(0.3)
		remote:FireServer("Evolve",{PetKey="not-owned",Token=request.Token,BranchId=request.BranchId}) task.wait(0.3)
		remote:FireServer("Evolve",{PetKey=request.PetKey,Token=request.Token,BranchId="ProtoRex:MythicRex"}) task.wait(0.3)
		for _=1,20 do remote:FireServer("Evolve",{PetKey={},Token={},BranchId={}}) end
		script:SetAttribute("ReadyForClick",true)
		local deadline=os.clock()+140 repeat task.wait(0.1) until p:GetAttribute("PetStage")==1 or os.clock()>deadline
		check(p:GetAttribute("MonsterId")=="Mossback","Mouse selection replicated to client")
		for _=1,30 do remote:FireServer("Evolve",request) end task.wait(0.5)
		check(p:GetAttribute("PetStage")==1 and p:GetAttribute("MonsterId")=="Mossback","Client replay leaves form and stage unchanged")
		check(not panel.Visible,"Choice panel clears on success")
	end,debug.traceback)
	script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",checks)
end)
