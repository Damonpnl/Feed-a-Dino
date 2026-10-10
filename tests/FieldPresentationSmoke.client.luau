-- Opt-in Play client test. After Ready=true, send Secret/Eternal/Divine fixtures via FieldRareSpawn.
task.wait(1)
local Players, Lighting = game:GetService("Players"), game:GetService("Lighting")
local player = Players.LocalPlayer
local Presentation = require(player.PlayerScripts.Client.FieldPresentation)
local field = game.ReplicatedStorage.WorldFieldState
local Config = require(game.ReplicatedStorage.Shared.FieldConfig)
local savedPhase, savedClock, savedBrightness = field:GetAttribute("Phase"), Lighting.ClockTime, Lighting.Brightness
local seen, sounds, connections, passes = {}, {}, {}, 0
local function check(ok, message) assert(ok, message) passes += 1 end
connections[1] = Presentation.RareSpawned:Connect(function(payload) seen[payload.Rarity] = payload end)
connections[2] = Presentation.SoundRequested:Connect(function(payload, id, volume) sounds[payload.Rarity] = {Id=id,Volume=volume} end)
script:SetAttribute("Ready",true)
local ok, failure = xpcall(function()
	local deadline = os.clock()+20
	while not (seen.Secret and seen.Eternal and seen.Divine) and os.clock()<deadline do task.wait(0.1) end
	for _, rarity in {"Secret","Eternal","Divine"} do
		check(seen[rarity] and seen[rarity].AreaName and seen[rarity].DisplayName, rarity .. " carries area/item name")
		check(sounds[rarity] and sounds[rarity].Volume==Config.RarePresentation[rarity].SoundVolume, rarity .. " sound hook has configured intensity")
	end
	local gui = player.PlayerGui:FindFirstChild("FieldAnnouncements")
	check(gui and gui.Frame.Visible, "announcement is visible")
	local deadline2 = os.clock()+15
	while not string.find(gui.Frame.TextLabel.Text,"Inferno Catalyst",1,true) and os.clock()<deadline2 do task.wait(0.1) end
	check(string.find(gui.Frame.TextLabel.Text,"DIVINE ARRIVAL",1,true) and string.find(gui.Frame.TextLabel.Text,"Volcano",1,true), "Divine major announcement includes area and item")
	-- Client-only phase fixture: no server field or resource state changes.
	field:SetAttribute("Phase","Reset") task.wait(0.8)
	check(math.abs(Lighting.ClockTime-20)<0.01 and math.abs(Lighting.Brightness-0.8)<0.01, "reset uses night lighting")
	field:SetAttribute("Phase","Normal") task.wait(0.8)
	check(math.abs(Lighting.ClockTime-savedClock)<0.01 and math.abs(Lighting.Brightness-savedBrightness)<0.01, "normal restores lighting")
	Presentation:Stop()
	check(not player.PlayerGui:FindFirstChild("FieldAnnouncements"), "Stop releases announcement GUI")
	Presentation:Start()
	local count=0 for _, child in player.PlayerGui:GetChildren() do if child.Name=="FieldAnnouncements" then count+=1 end end
	check(count==1, "Start recreates exactly one GUI")
end,debug.traceback)
for _, connection in connections do connection:Disconnect() end
field:SetAttribute("Phase",savedPhase)
Lighting.ClockTime, Lighting.Brightness = savedClock, savedBrightness
script:SetAttribute("Result",if ok then "PASS" else failure) script:SetAttribute("PassedChecks",passes)
if ok then print("[FieldPresentationSmoke] PASS " .. passes .. " checks") else warn("[FieldPresentationSmoke] " .. failure) end
