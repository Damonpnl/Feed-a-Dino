-- Pair with the client warning observer; actual replicated field clock and closure.
assert(game:GetService("RunService"):IsStudio())
local S=game.ServerScriptService.Server
local R,G,C,D=require(S.ResourceService),require(S.GuardianService),require(S.CarryService),require(S.DataService)
local State=require(game.ReplicatedStorage.Shared.FieldState)
local old=State.step local field,deadline
local p=game.Players:GetPlayers()[1]
local ok,err=xpcall(function()
	assert(D.getStatus(p).Backend=="StudioMemory" and not C.get(p)) G.resetAll()
	State.step=function(self,...) field=self return old(self,...) end
	local untilTime=os.clock()+4 repeat task.wait(.03) until field or os.clock()>untilTime assert(field) State.step=old
	while field.Phase~="Normal" do task.wait(.1) end deadline=field.NextResetAt
	for _,seconds in {59,29,9} do
		field.NextResetAt=workspace:GetServerTimeNow()+seconds R.step()
		script:SetAttribute("Progress",seconds) task.wait(1.5)
	end
	field.NextResetAt=workspace:GetServerTimeNow()+.2 R.step()
	local untilTime=os.clock()+13 repeat task.wait(.05) until field.Phase=="Reset" or os.clock()>untilTime
	assert(field.Phase=="Reset")
	repeat task.wait(.05) until field.Phase=="Normal" or os.clock()>untilTime
	assert(field.Phase=="Normal") task.wait(1)
end,debug.traceback)
State.step=old if field and deadline then field.NextResetAt=math.max(deadline,workspace:GetServerTimeNow()+60) R.step() end
script:SetAttribute("Result",if ok then "PASS" else err)
