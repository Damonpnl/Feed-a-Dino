-- Opt-in paired actual client fixture. The only client input is the server's preview ticket.
assert(game:GetService("RunService"):IsStudio())
local player=game.Players.LocalPlayer
local remote=game.ReplicatedStorage.Remotes.FeedInteraction
local checks=0
local connection
connection=remote.OnClientEvent:Connect(function(payload)
	if not payload.Available then return end
	connection:Disconnect()
	local ok,failure=xpcall(function()
		task.wait(0.3)
		local panel=player.PlayerGui.MonsterHud.FeedPreview
		local function check(v,message) assert(v,message) checks+=1 end
		check(panel.Visible,"Preview visible")
		check(panel.Details.Text:find(payload.PetName,1,true),"Active pet name")
		check(panel.Details.Text:find("Growth:",1,true) and panel.Details.Text:find("Floral",1,true),"Growth and individual affinity preview")
		check(panel.Confirm.Text=="FEED","Functional confirm button")
		check(panel.AbsoluteSize.X<=440 and panel.AbsoluteSize.Y<=340,"Bounded responsive panel")
		script:SetAttribute("PreviewText",panel.Details.Text)
		-- Delay permits screen inspection; then exercise real remote replay protection.
		task.wait(3)
		for _=1,30 do remote:FireServer("Confirm",payload.Ticket,{Growth=1e30,PetId="forged"}) end
		task.wait(0.6)
		check(player:GetAttribute("CarriedInstanceId")=="","Consumed carry replicated")
		check(panel.Details.Text:find("Fed ",1,true),"Server success displayed")
	end,debug.traceback)
	script:SetAttribute("PassedChecks",checks)
	script:SetAttribute("Result",if ok then "PASS" else failure)
	if not ok then warn(failure) end
end)
script:SetAttribute("Ready",true)
