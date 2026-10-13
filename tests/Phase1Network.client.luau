-- Opt-in client counterpart to Phase1Lifecycle; arbitrary payloads must not reward or duplicate.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local player=game.Players.LocalPlayer
repeat task.wait(0.1) until player:GetAttribute("Phase1NetworkReady")
local remote=game.ReplicatedStorage.Remotes.DropCarried
for _=1,40 do remote:FireServer({ResourceId="InfernoCatalyst",Power=1e9,Cash=1e9,Position=Vector3.zero}) end
script:SetAttribute("SentRequests",40)
print("[Phase1Network] Sent 40 forged/replayed drop requests")
