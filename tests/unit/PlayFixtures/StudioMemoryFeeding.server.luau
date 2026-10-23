-- Opt-in normal Studio backend verification. No DataService/status/session overrides.
assert(game:GetService("RunService"):IsStudio())
local S,Shared=game.ServerScriptService.Server,game.ReplicatedStorage.Shared
local Data,Feed,Spawn,Carry,Resource,Guardian,Monster=require(S.DataService),require(S.FeedService),require(S.SpawnService),require(S.CarryService),require(S.ResourceService),require(S.GuardianService),require(S.MonsterService)
local State=require(Shared.FieldState)
local p=game.Players:GetPlayers()[1]
local checks=0 local function check(v,m) assert(v,m) checks+=1 script:SetAttribute("PassedChecks",checks) end
local field local oldStep=State.step local frame=p.Character:GetPivot()
local ok,failure=xpcall(function()
	check(Data.isWritable(p) and Data.getStatus(p).Backend=="StudioMemory","Normal Studio writable memory session")
	local data=Data.get(p)
	check(data.Monsters.ProtoRex.TotalGrowth==0 and data.Stats.Feeds==0,"Fresh Play defaults")
	-- Only seed test resources for repeatability; do not change catalog or progression.
	State.step=function(self,...) field=self return oldStep(self,...) end
	local deadline=os.clock()+5 repeat task.wait(0.05) until field or os.clock()>deadline
	State.step=oldStep assert(field)
	local base=workspace.Bases[p:GetAttribute("AssignedBaseName")]
	local point=base:FindFirstChild("FeedingPoint",true)
	local host=if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true)
	p.Character.HumanoidRootPart.Anchored=true
	for index=1,10 do
		task.wait(0.22) Guardian.resetAll()
		local node=field.Nodes["Grasslands:Node01"]
		if node.RecordId then Resource.releaseToken("Grasslands",node.RecordId) end
		local r=field:create(node,"RawMeat","StudioMemoryTest") Resource.step()
		local model for _,m in workspace.GeneratedGameplay.Resources:GetChildren() do if m:GetAttribute("ResourceInstanceId")==r.InstanceId then model=m break end end
		assert(model) p.Character:PivotTo(model.PrimaryPart.CFrame+Vector3.new(0,3,0))
		check(Spawn.pickup(p,r.InstanceId),"Raw Meat picked up at normal Power")
		p.Character:PivotTo(host.CFrame+Vector3.new(0,3,0))
		local preview=Feed.preview(p,base,host) check(preview.Available,"Ordinary preview is available")
		if index==1 then
			game.ReplicatedStorage.Remotes.FeedInteraction:FireClient(p,preview)
			script:SetAttribute("ReadyForClick",true)
			local untilTime=os.clock()+90 repeat task.wait(0.05) until data.Stats.Feeds==1 or os.clock()>untilTime
			check(data.Stats.Feeds==1,"Actual native FEED button succeeds")
		else check(Feed.confirm(p,preview.Ticket),"Subsequent feed succeeds") end
		local pet=data.Monsters.ProtoRex
		check(pet.TotalGrowth==5*index and pet.Flesh==5*index and pet.Flora==0 and pet.Mineral==0,"Exact Raw Meat Growth and affinities")
		check(not Resource.getRecord(r.InstanceId) and not Carry.get(p) and not Feed.confirm(p,preview.Ticket),"Original GUID consumed exactly once")
	end
	check(data.Monsters.ProtoRex.EvolutionForm=="Fangling" and data.Monsters.ProtoRex.Stage==1,"Ten ordinary feeds evolve pet")
	check(Data.save(p),"Save uses memory backend")
	check(#Spawn.validate()==0,"No duplicate world resources")
	Monster.publish(p)
end,debug.traceback)
State.step=oldStep
if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.Anchored=false p.Character:PivotTo(frame) end
script:SetAttribute("Result",if ok then "PASS" else failure)
if ok then print("[StudioMemoryFeeding] PASS "..checks) else warn(failure) end
