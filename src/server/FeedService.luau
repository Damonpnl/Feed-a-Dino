--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local EvolutionCalculator = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EvolutionCalculator"))
local MonsterDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonsterDefinitions"))
local MonsterService = require(script.Parent.MonsterService)
local ResourceCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceCatalog"))
local ResourceEffects = require(ReplicatedStorage.Shared.ResourceEffects)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local CarryService = require(script.Parent.CarryService)
local ResourceService = require(script.Parent.ResourceService)
local Guard = require(script.Parent.InteractionGuard)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local rng=Random.new()
local rolls=require(script.Parent.FeedRolls).new(function() return rng:NextNumber() end)
local rarityRolls=require(script.Parent.FeedRolls).new(function() return rng:NextNumber() end)

local FeedService = {}

local bound: { [Model]: boolean } = {}
local previews = {}
local started = false
local remote
local function validCounter(value)
	return type(value)=="number" and value>=0 and value<9007199254740991 and value==math.floor(value)
end

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k,v in a do if not same(v,b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local function validate(player, base, host)
	if not DataService.isWritable(player) then return nil, "Player data is not writable; item kept" end
	if not base or not host or not Guard.ownedBase(player, base, host, 14) then return nil, "Approach your own feeding point with a living character" end
	local point = base:FindFirstChild("FeedingPoint", true)
	if not point or not (host == point or host:IsDescendantOf(point)) then return nil, "Invalid feeding point" end
	local item = CarryService.get(player)
	if not item then return nil, "Carry a resource to your pet" end
	local world = ResourceService.getRecord(item.token)
	if not world or not ResourceService.owned(player,item.token) or world.ResourceId ~= item.resourceId then return nil, "Resource is no longer carried by you" end
	local definition = ResourceCatalog.get(world.ResourceId)
	local data = DataService.get(player)
	local record = data and data.Monsters[data.EquippedMonster]
	if not record or not EvolutionCalculator.valid(record) then return nil, "No compatible owned active pet" end
	if record.PendingEvolution then return nil,"Choose your pending evolution at your pet first; item kept" end
	if not definition or not definition.Launch then return nil, "Resource cannot be fed" end
	local checked,compatible,compatibilityReason=pcall(ResourceEffects.canApply,record,definition)
	if not checked then return nil,"Invalid catalyst compatibility; item kept" end
	if not compatible then return nil,compatibilityReason.."; item kept" end
	local ok,effect = pcall(ResourceEffects.resolve,record,definition)
	if not ok then return nil, "Invalid pet or resource effects; item kept" end
	if type(record.Mutations)~="table" or type(record.EvolutionFamilies)~="table" or not validCounter(record.Revision or 0) then return nil,"Invalid pet state; item kept" end
	if type(data.Stats)~="table" or not validCounter(data.Stats.Feeds) or not validCounter(data.Stats.Evolutions) then return nil,"Invalid progression counters; item kept" end
	return {Data=data,Record=record,PetId=data.EquippedMonster,Item=item,World=world,Definition=definition,Effect=effect}
end

function FeedService.preview(player, base, host)
	previews[player] = nil
	local context,reason = validate(player,base,host)
	if not context then return {Available=false,Reason=reason} end
	local ticket = HttpService:GenerateGUID(false)
	local projected = PlayerData.copy(context.Record)
	local applied,forced = pcall(ResourceEffects.apply,projected,context.Definition,function() return 1 end) -- preview never rolls
	if not applied then return {Available=false,Reason="Invalid catalyst effects; item kept"} end
	projected.Revision += 1
	-- Preview never samples randomness or promises a probabilistic promotion.
	local planned,_,outcome = pcall(EvolutionCalculator.afterFeed,projected,forced,function() return 0.9999999999999999 end)
	if not planned then return {Available=false,Reason="Invalid evolution state; item kept"} end
	previews[player] = {Ticket=ticket,Expires=os.clock()+30,Character=player.Character,Base=base,Host=host,
		Data=context.Data,Record=context.Record,Snapshot=PlayerData.copy(context.Record),PetId=context.PetId,
		Token=context.Item.token,ClaimVersion=context.World.ClaimVersion}
	return {Available=true,Ticket=ticket,ResourceId=context.Definition.Id,ResourceInstanceId=context.Item.token,
		PetName=MonsterDefinitions.get(EvolutionCalculator.form(context.Record)).DisplayName,
		Pet={Growth=context.Record.Growth,TotalGrowth=context.Record.TotalGrowth,Flesh=context.Record.Flesh,
			Flora=context.Record.Flora,Mineral=context.Record.Mineral},
		GrowthAfter=projected.Growth,GrowthReserveAfter=projected.GrowthReserve,
		Effect=context.Effect,LegacyOutcome=outcome,Reason="Confirm to feed. Preview expires in 30 seconds."}
end

local function commit(player, context)
	-- No yield from validation through record removal and pet/counter assignment.
	-- All fallible calculations happen on a copy before either authoritative state changes.
	local staged = PlayerData.copy(context.Record)
	rolls.prune(function(id) return ResourceService.getRecord(id)~=nil end)
	rarityRolls.prune(function(id) return ResourceService.getRecord(id)~=nil end)
	local evolved = false
	local ok = pcall(function()
		local nextNumber=rolls.forResource(context.Item.token)
		local forced=ResourceEffects.apply(staged,context.Definition,nextNumber)
		staged.Revision = (staged.Revision or 0) + 1
		assert(staged.Revision < math.huge and staged.Revision > (context.Record.Revision or 0))
		evolved = EvolutionCalculator.afterFeed(staged,forced,rarityRolls.forResource(context.Item.token))
	end)
	if not ok then return false, "Effect calculation failed; item kept" end
	local data = context.Data
	if not CarryService.consumeOwned(player,context.Item.token) then return false, "Resource is no longer carried by you" end
	data.Monsters[context.PetId] = staged -- ownership key never changes when a form changes
	if evolved then
		data.Stats.Evolutions += 1
	end
	data.Stats.Feeds += 1
	previews[player] = nil
	local published = pcall(function()
		player:SetAttribute("StatusMessage", "Fed " .. context.Definition.DisplayName)
		MonsterService.publish(player)
	end)
	if not published then warn("[FeedService] Feed committed; pet presentation needs refresh") end
	return true, "Fed " .. context.Definition.DisplayName
end

function FeedService.confirm(player, ticket)
	local pending = previews[player]
	if type(ticket) ~= "string" or #ticket > 64 or not pending or pending.Ticket ~= ticket then return false, "Preview expired; preview again" end
	previews[player] = nil -- one attempt, including rejected/stale confirmations
	if pending.Expires < os.clock() or player.Character ~= pending.Character then return false, "Preview expired; preview again" end
	local context,reason = validate(player,pending.Base,pending.Host)
	if not context then return false,reason end
	if context.Data ~= pending.Data or context.Record ~= pending.Record or context.PetId ~= pending.PetId
		or context.Item.token ~= pending.Token or context.World.ClaimVersion ~= pending.ClaimVersion
		or not same(context.Record,pending.Snapshot) then return false, "Pet or resource changed; preview again" end
	return commit(player,context)
end

function FeedService.feed(player: Player, base: Model, host: BasePart): boolean
	-- Server-only compatibility entry point. Player input always uses preview + confirm.
	if not Guard.allow(player,"Feed",0.2) then return false end
	local context = validate(player,base,host)
	if not context then return false end
	return commit(player,context)
end

local function bindBase(base: Model)
	if bound[base] then
		return
	end
	local point = base:FindFirstChild("FeedingPoint", true)
	if point == nil then
		warn("[FeedService] " .. base.Name .. " is missing FeedingPoint")
		return
	end

	local host = if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart", true)
	if host == nil then
		warn("[FeedService] " .. base.Name .. " FeedingPoint has no part")
		return
	end

	local prompt = point:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		local created = Instance.new("ProximityPrompt")
		created.Parent = host
		prompt = created
	elseif not prompt.Parent:IsA("BasePart") and not prompt.Parent:IsA("Attachment") then
		prompt.Parent = host
	end

	prompt.ActionText = "Feed"
	prompt.ObjectText = "Pet"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Triggered:Connect(function(player)
		if base:GetAttribute("OwnerUserId") ~= player.UserId then
			player:SetAttribute("StatusMessage", "This is not your monster")
			return
		end
		if Guard.allow(player,"FeedPreview",0.2) then remote:FireClient(player,FeedService.preview(player,base,host)) end
	end)
	bound[base] = true
end

function FeedService.start()
	if started then return end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remote = remotes:FindFirstChild("FeedInteraction")
	if not remote then remote = Instance.new("RemoteEvent") remote.Name="FeedInteraction" remote.Parent=remotes end
	assert(remote:IsA("RemoteEvent"), "FeedInteraction must be a RemoteEvent")
	remote.OnServerEvent:Connect(function(player,action,ticket)
		if not Guard.allow(player,"FeedRequest",0.2) then return end
		if action == "Evolve" then
			local ok,reason = MonsterService.chooseEvolution(player,ticket)
			remote:FireClient(player,{Kind="Evolution",Success=ok,Reason=reason})
		elseif action == "Confirm" then
			local ok,reason = FeedService.confirm(player,ticket)
			remote:FireClient(player,{Available=false,Success=ok,Reason=reason})
		elseif action == "Preview" then
			local name = player:GetAttribute("AssignedBaseName")
			local base = type(name)=="string" and workspace.Bases:FindFirstChild(name)
			local point = base and base:FindFirstChild("FeedingPoint",true)
			local host = point and (if point:IsA("BasePart") then point else point:FindFirstChildWhichIsA("BasePart",true))
			remote:FireClient(player,FeedService.preview(player,base,host))
		end
	end)
	Players.PlayerRemoving:Connect(function(player) previews[player]=nil end)
	local bases = workspace:WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		if base:IsA("Model") then
			bindBase(base)
		end
	end
end

return FeedService
