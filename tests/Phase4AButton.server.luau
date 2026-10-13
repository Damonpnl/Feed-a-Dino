-- Opt-in actual GUI-button test. Click FEED through the Studio MCP during Ready.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server
local Data,Feed,Spawn,Carry,Guardian=require(S.DataService),require(S.FeedService),require(S.SpawnService),require(S.CarryService),require(S.GuardianService)
local PD=require(game.ReplicatedStorage.Shared.PlayerData)
local player=game.Players:GetPlayers()[1]
local originalStatus=Data.getStatus
local data=Data.get(player) local original=PD.copy(data) local frame=player.Character:GetPivot()
local ok,failure=xpcall(function()
	data.Power=1e12 Guardian.resetAll()
	Data.getStatus=function(p) return if p==player then {Status="Missing",CanSave=true,Closing=false} else originalStatus(p) end
	local id
	for key,r in Spawn.getSnapshot().Records do if r.AreaId=="Grasslands" and r.State=="AVAILABLE" then id=key break end end
	assert(id,"Available resource")
	local model
	for _,v in workspace.GeneratedGameplay.Resources:GetChildren() do if v:GetAttribute("ResourceInstanceId")==id then model=v break end end
	player.Character.HumanoidRootPart.Anchored=true
	player.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0))
	assert(Spawn.pickup(player,id))
	local base=workspace.Bases[player:GetAttribute("AssignedBaseName")]
	local point=base:FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	player.Character:PivotTo(host.CFrame+Vector3.new(0,3,0))
	local preview=Feed.preview(player,base,host) assert(preview.Available)
	local before=data.Stats.Feeds
	game.ReplicatedStorage.Remotes.FeedInteraction:FireClient(player,preview)
	script:SetAttribute("Ready",true)
	local deadline=os.clock()+28
	repeat task.wait(0.05) until data.Stats.Feeds==before+1 or os.clock()>deadline
	assert(data.Stats.Feeds==before+1 and not Carry.get(player),"Actual confirm button did not consume")
end,debug.traceback)
Data.getStatus=originalStatus
for k in data do data[k]=nil end for k,v in original do data[k]=v end
require(S.MonsterService).publish(player)
player.Character.HumanoidRootPart.Anchored=false player.Character:PivotTo(frame)
script:SetAttribute("Result",if ok then "PASS" else failure)
