--!nonstrict
-- Adapter for ResourceService's existing epoch/phase, NOT a second reset clock.
-- Closed territory is the field side of the same authoritative guardian safe plane.
local Players=game:GetService("Players")
local Areas=require(game.ReplicatedStorage.Shared.AreaDefinitions)
local Chase=require(game.ReplicatedStorage.Shared.GuardianChase)
local Zone=require(script.Parent.ZoneGeometry)
local Guardian=require(script.Parent.GuardianService)
local Carry=require(script.Parent.CarryService)
local Catch=require(script.Parent.GuardianCatch)
local Base=require(script.Parent.BaseService)
local Lockdown={}
local gates, lane, closed = {}, nil, false

function Lockdown.initialize(parent)
	assert(not lane,"Lockdown already initialized")
	lane=Guardian.getRunway()
	assert(lane,"Field lockdown requires the existing guardian safe boundary")
	local folder=Instance.new("Folder") folder.Name="FieldGates" folder.Parent=parent
	for _,area in Areas.getOrdered() do
		local floor=assert(Zone.findFloor(Zone.getZone(area)))
		local surface=Zone.surface(floor)
		local axis,half,lateral,width=Chase.axes(surface)
		local point=floor.Position-axis*half
		if area.Id=="Grasslands" then point=lane.origin+lane.axis*lane.entrance end
		local gate=Instance.new("Part") gate.Name=area.Id gate.Anchored=true gate.CanTouch=false gate.CanQuery=false
		gate.Size=Vector3.new(2,32,width*2)
		gate.CFrame=CFrame.fromMatrix(Vector3.new(point.X,lane.surfaceY+16,point.Z),axis,Vector3.yAxis,lateral)
		gate.Material=Enum.Material.Neon gate.Color=Color3.fromRGB(255,80,40)
		gate.CanCollide=false gate.Transparency=1 gate:SetAttribute("Closed",false)
		local sign=Instance.new("BillboardGui") sign.Name="ClosureSign" sign.Size=UDim2.fromOffset(330,62) sign.MaxDistance=160 sign.AlwaysOnTop=true sign.Parent=gate
		local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=.25 label.BackgroundColor3=Color3.fromRGB(25,20,20)
		label.TextColor3=Color3.fromRGB(255,210,160) label.Font=Enum.Font.GothamBold label.TextSize=18 label.TextWrapped=true label.Parent=sign
		gate.Parent=folder table.insert(gates,{Part=gate,Label=label,Sign=sign})
	end
end

local function evacuate(player,cycle)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root or Chase.isSafe(lane,root.Position) then return end
	-- Terminal record removal is BEFORE control restoration/teleport. No drop, reward,
	-- compensation or pending recovery record. Repeated checks are idempotent.
	local forfeited=Carry.forfeit(player)
	Catch.release(player)
	if Base.evacuate(player,character) then
		player:SetAttribute("FieldEvacuatedCycle",cycle)
		player:SetAttribute("StatusMessage",if forfeited then "FIELD CLOSED — carried resource forfeited" else "FIELD CLOSED — returned to your base")
	end
end

function Lockdown.reconcile(state, resetOccurred)
	if not lane then return end
	local nextClosed=state.Phase=="Reset"
	if resetOccurred or (nextClosed and not closed) then
		-- Capture who is inside before resetAll can stand up/reposition ragdolls.
		for _,p in Players:GetPlayers() do evacuate(p,state.Cycle) end
		Guardian.resetAll()
	elseif nextClosed then
		-- Also catches joins, respawns, physics pushes and teleport entry while closed.
		for _,p in Players:GetPlayers() do evacuate(p,state.Cycle) end
	end
	local remaining=math.max(0,math.ceil(state.NextResetAt-workspace:GetServerTimeNow()))
	for _,g in gates do
		if nextClosed~=closed then
			g.Part.CanCollide=nextClosed g.Part.Transparency=if nextClosed then .4 else 1 g.Part:SetAttribute("Closed",nextClosed)
		end
		g.Sign.Enabled=nextClosed or remaining<=60
		local warning=if remaining<=10 then "10 SECOND FINAL WARNING" elseif remaining<=30 then "30 SECOND WARNING" else "60 SECOND WARNING"
		local text=if nextClosed then "FIELD CLOSED — RESETTING" else warning.."\nLEAVE THE FIELD OR LOSE YOUR CARRIED ITEM"
		if g.Label.Text~=text then g.Label.Text=text end
	end
	closed=nextClosed
end
return Lockdown
