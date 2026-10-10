--!nonstrict
local Areas = require(script.Parent.AreaDefinitions)
local Resources = require(script.Parent.ResourceDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Models = require(script.Parent.ResourceModelDefinitions)
local Effects = require(script.Parent.SpecialEffectDefinitions)
local Roller = require(script.Parent.FieldRoller)
local Config = require(script.Parent.FieldConfig)
local Validation = {}
function Validation.config()
	local errors, seen, launchCount = {}, {}, 0
	local function check(ok, message) if not ok then table.insert(errors, message) end end
	local function nonnegative(value) return type(value) == "number" and value >= 0 and value < math.huge end
	local affinities = {Flesh=true, Floral=true, Mineral=true, Neutral=true, ["Flesh + Mineral"]=true, ["Flesh + Floral"]=true}
	check(#Areas.getOrdered() == 5, "Expected five launch areas")
	check(table.concat(Rarities.Order, ",") == "Common,Uncommon,Rare,Epic,Legendary,Mythic,Cosmic,Secret,Eternal,Divine", "Rarity order mismatch")
	for id, resource in Resources.getAll() do
		check(id == resource.Id, "Resource ID/key mismatch: " .. id)
		check(Rarities.isValid(resource.Rarity), "Invalid rarity: " .. id)
		check(resource.ResourceType == "Feed" or resource.ResourceType == "Catalyst", "Invalid resource type: " .. id)
		check(affinities[resource.Affinity] == true, "Invalid affinity: " .. id)
		check(nonnegative(resource.PowerRequired) and nonnegative(resource.Growth), "Invalid progression values: " .. id)
		check(nonnegative(resource.CarrySlowdown) and resource.CarrySlowdown < 1, "Invalid slowdown: " .. id)
		check(typeof(resource.BillboardOffset) == "Vector3", "Missing billboard offset: " .. id)
		check(Effects[resource.SpecialEffect] ~= nil, "Invalid effect: " .. id)
		check(resource.ResourceType ~= "Catalyst" or resource.SpecialEffect ~= "None", "Catalyst has no effect: " .. id)
		check(Models[resource.ModelKey] ~= nil, "Missing model/fallback: " .. id)
		if resource.Launch then
			launchCount += 1
			check(nonnegative(resource.SpawnWeight) and resource.SpawnWeight > 0, "Nonpositive/invalid launch weight: " .. id)
		else check(resource.SpawnWeight == 0, "Reserved resource is enabled: " .. id) end
	end
	for _, area in Areas.getOrdered() do
		check(#area.ResourcePool == 8, "Expected eight Index resources in " .. area.Id)
		check(Roller.tickets(area.ResourcePool) == 10000, "Pool must sum to 100: " .. area.Id)
		local total = 0
		for _, entry in area.ResourcePool do
			total += entry.SpawnWeight
			check(math.abs(entry.SpawnWeight * 100 - math.round(entry.SpawnWeight * 100)) < 1e-8, "Weight exceeds hundredth precision: " .. entry.Id)
			local resource = Resources.get(entry.Id)
			check(not seen[entry.Id], "Duplicate pool resource ID: " .. entry.Id)
			seen[entry.Id] = true
			check(resource and resource.Launch and resource.Area == area.Id, "Invalid pool membership: " .. entry.Id)
			check(entry.SpawnWeight > 0 and resource and entry.SpawnWeight == resource.SpawnWeight, "Weight mismatch: " .. entry.Id)
		end
		check(math.abs(total - 100) < 1e-8, "Exact pool weight must sum to 100: " .. area.Id)
	end
	check(launchCount == 40, "Expected 40 launch resources")
	for id, resource in Resources.getAll() do if resource.Launch then check(seen[id], "Launch resource missing from Index: " .. id) end end
	return errors
end
function Validation.world(zones, modelTemplates)
	local errors, nodes, seen = {}, {}, {}
	for _, area in Areas.getOrdered() do
		local zone = zones and zones:FindFirstChild(area.ZoneName)
		local folder = zone and zone:FindFirstChild("ResourceNodes")
		if not folder or #folder:GetChildren() ~= Config.NODES_PER_AREA then
			table.insert(errors, "Expected exactly five ResourceNodes in " .. area.Id)
		end
		if folder then
			for _, marker in folder:GetChildren() do
				local id = marker:GetAttribute("NodeId")
				if not marker:IsA("BasePart") or typeof(id) ~= "string" or id == "" or seen[id] or marker:GetAttribute("AreaId") ~= area.Id then
					table.insert(errors, "Invalid/duplicate node in " .. area.Id)
				else seen[id] = true table.insert(nodes, {Id = id, AreaId = area.Id, Marker = marker}) end
			end
		end
	end
	for _, resource in Resources.getAll() do
		local template = modelTemplates and modelTemplates:FindFirstChild(resource.ModelKey)
		local valid = template and (template:IsA("BasePart") or template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true))
		if not valid and not (Models[resource.ModelKey] and Models[resource.ModelKey].Placeholder) then
			table.insert(errors, "No model or explicit placeholder: " .. resource.ModelKey)
		end
	end
	return errors, nodes
end
return Validation
