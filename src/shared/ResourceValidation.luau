--!nonstrict
local Areas = require(script.Parent.AreaDefinitions)
local Resources = require(script.Parent.ResourceDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Models = require(script.Parent.ResourceModelDefinitions)
local Effects = require(script.Parent.SpecialEffectDefinitions)
local Config = require(script.Parent.FieldConfig)
local Validation = {}
function Validation.config()
	local errors, seen, launchCount = {}, {}, 0
	local function check(ok, message) if not ok then table.insert(errors, message) end return ok end
	local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
	local function text(value) return type(value) == "string" and #value > 0 end
	local affinities = {Flesh=true, Floral=true, Mineral=true, Neutral=true, ["Flesh + Mineral"]=true, ["Flesh + Floral"]=true}
	check(Config.FIELD_CYCLE_SECONDS == 300 and Config.RESET_WINDOW_SECONDS == 10 and Config.NODES_PER_AREA == 5, "Invalid locked field timing/node configuration")
	check(#Areas.getOrdered() == 5, "Expected five launch areas")
	check(table.concat(Rarities.Order, ",") == "Common,Uncommon,Rare,Epic,Legendary,Mythic,Cosmic,Secret,Eternal,Divine", "Rarity order mismatch")
	for id, resource in Resources.getAll() do
		local label = tostring(id)
		if not check(type(resource) == "table", "Invalid resource definition: "..label) then continue end
		check(text(id) and id == resource.Id, "Resource ID/key mismatch: "..label)
		check(text(resource.DisplayName) and text(resource.Area), "Missing resource identity: "..label)
		check(type(resource.Launch) == "boolean", "Missing Launch flag: "..label)
		check(Rarities.isValid(resource.Rarity), "Invalid rarity: "..label)
		check(resource.ResourceType == "Feed" or resource.ResourceType == "Catalyst", "Invalid resource type: "..label)
		check(affinities[resource.Affinity] == true, "Invalid affinity: "..label)
		check(finite(resource.PowerRequired) and resource.PowerRequired >= 0 and finite(resource.Growth) and resource.Growth >= 0, "Invalid progression values: "..label)
		check(finite(resource.CarrySlowdown) and resource.CarrySlowdown >= 0 and resource.CarrySlowdown < 1, "Invalid slowdown: "..label)
		check(typeof(resource.BillboardOffset) == "Vector3" and resource.BillboardOffset.Magnitude < 10000, "Invalid billboard offset: "..label)
		check(Effects[resource.SpecialEffect] ~= nil, "Invalid effect: "..label)
		check(resource.ResourceType ~= "Catalyst" or resource.SpecialEffect ~= "None", "Catalyst has no effect: "..label)
		check(text(resource.ModelKey) and Models[resource.ModelKey] ~= nil, "Missing model/fallback: "..label)
		if check(type(resource.Affinities) == "table", "Missing affinity gains: "..label) then
			for affinity, value in resource.Affinities do
				check((affinity=="Flesh" or affinity=="Floral" or affinity=="Mineral") and finite(value) and value>=0, "Invalid affinity gain: "..label)
			end
		end
		if resource.Launch then
			launchCount += 1
			check(finite(resource.SpawnWeight) and resource.SpawnWeight > 0, "Nonpositive/invalid launch weight: "..label)
			check(Areas.get(resource.Area) ~= nil, "Invalid launch area: "..label)
		else check(resource.SpawnWeight == 0, "Reserved resource is enabled: "..label) end
	end
	local areaIds, orders = {}, {}
	for _, area in Areas.getOrdered() do
		if not check(type(area)=="table", "Invalid area definition") then continue end
		local label=tostring(area.Id)
		check(text(area.Id) and not areaIds[area.Id], "Duplicate/invalid area ID: "..label)
		if text(area.Id) then areaIds[area.Id]=true end
		check(text(area.DisplayName) and text(area.ZoneName) and text(area.Guardian) and text(area.GuardianDisplayName), "Missing area fields: "..label)
		check(finite(area.Order) and area.Order%1==0 and area.Order>=1 and area.Order<=5 and not orders[area.Order], "Invalid area order: "..label)
		if finite(area.Order) then orders[area.Order]=true end
		if not check(type(area.ResourcePool)=="table", "Missing resource pool: "..label) then continue end
		check(#area.ResourcePool == 8, "Expected eight Index resources in "..label)
		local total = 0
		for _, entry in area.ResourcePool do
			if not check(type(entry)=="table" and text(entry.Id), "Invalid pool entry: "..label) then continue end
			local resource = Resources.get(entry.Id)
			check(not seen[entry.Id], "Duplicate pool resource ID: "..entry.Id)
			seen[entry.Id] = true
			check(resource and resource.Launch and resource.Area == area.Id, "Invalid pool membership: "..entry.Id)
			if check(finite(entry.SpawnWeight) and entry.SpawnWeight > 0, "Invalid pool weight: "..entry.Id) then
				total += entry.SpawnWeight
				check(math.abs(entry.SpawnWeight*100-math.round(entry.SpawnWeight*100))<1e-8, "Weight exceeds hundredth precision: "..entry.Id)
				check(resource and entry.SpawnWeight==resource.SpawnWeight, "Weight mismatch: "..entry.Id)
			end
		end
		check(math.abs(total - 100) < 1e-8, "Exact pool weight must sum to 100: "..label)
	end
	check(launchCount == 40, "Expected 40 launch resources")
	for id, resource in Resources.getAll() do
		if type(resource)=="table" and resource.Launch then check(seen[id], "Launch resource missing from Index: "..tostring(id)) end
	end
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
