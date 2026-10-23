-- Observes actual UI/replication; no local countdown/state substitutions.
assert(game:GetService("RunService"):IsStudio())
local p=game.Players.LocalPlayer local field=game.ReplicatedStorage:WaitForChild("WorldFieldState")
local ui=p.PlayerGui:WaitForChild("FieldAnnouncements")
local seen={} local rows={} local resetAt local deadline=os.clock()+30
local ok,err=xpcall(function()
	repeat
		task.wait(.25)
		local remaining=math.max(0,math.ceil(field:GetAttribute("NextResetAt")-workspace:GetServerTimeNow()))
		local reset=field:GetAttribute("Phase")=="Reset"
		local band=if reset then "Reset" elseif remaining<=10 then "10" elseif remaining<=30 then "30" elseif remaining<=60 then "60" else "Normal"
		local warning=ui.ClosureWarning local countdown=ui.ResetCountdown
		if (band~="Normal" or resetAt) and not seen[band] then
			-- Let the existing 0.2s UI refresh settle after a replicated clock change.
			task.wait(.25)
			if band=="Reset" then
				assert(countdown.Text=="RESOURCES RESETTING..." and warning.Visible and warning.Text:find("FORFEIT",1,true)) resetAt=os.clock()
			elseif band=="Normal" then
				assert(not warning.Visible and resetAt and os.clock()-resetAt>=9.4)
			else
				assert(warning.Visible and warning.Text:find(band,1,true) and warning.Text:find("LOSE YOUR CARRIED ITEM",1,true))
				local minutes,seconds=countdown.Text:match("(%d+):(%d+)")
				local current=math.ceil(field:GetAttribute("NextResetAt")-workspace:GetServerTimeNow())
				assert(minutes and math.abs(tonumber(minutes)*60+tonumber(seconds)-current)<=1,"Countdown drift")
			end
			seen[band]=true table.insert(rows,{Band=band,Text=warning.Text,TextFits=warning.TextFits})
			script:SetAttribute("Rows",game.HttpService:JSONEncode(rows))
		end
	until seen.Normal or os.clock()>deadline
	assert(seen["60"] and seen["30"] and seen["10"] and seen.Reset and seen.Normal,"Missing warning state")
end,debug.traceback)
script:SetAttribute("Result",if ok then "PASS" else err)
