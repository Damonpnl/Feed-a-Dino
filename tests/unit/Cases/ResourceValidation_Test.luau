local Shared = game.ReplicatedStorage.Shared
local Validation = require(Shared.ResourceValidation)
local Areas = require(Shared.AreaDefinitions)
local Resources = require(Shared.ResourceDefinitions)
local function world()
	local zones = Instance.new("Folder")
	for _, area in Areas.getOrdered() do
		local zone = Instance.new("Folder") zone.Name, zone.Parent = area.ZoneName, zones
		local nodes = Instance.new("Folder") nodes.Name, nodes.Parent = "ResourceNodes", zone
		for i = 1, 5 do
			local marker = Instance.new("Part") marker.Name, marker.Parent = "Node" .. i, nodes
			marker:SetAttribute("NodeId", area.Id .. ":" .. i) marker:SetAttribute("AreaId", area.Id)
		end
	end
	return zones
end
local function withWorld(fn)
	local zones = world()
	local ok, message = pcall(fn, zones)
	zones:Destroy()
	assert(ok, message)
end
return function(t)
	t.test("valid nodes and explicit placeholder coverage", function()
		withWorld(function(zones)
			local errors, nodes = Validation.world(zones, nil)
			t.expect.equal(#errors, 0) t.expect.equal(#nodes, 25)
		end)
	end)
	t.test("missing node rejects the world", function()
		withWorld(function(zones)
			zones.Grasslands.ResourceNodes.Node1:Destroy()
			t.expect.truthy(#Validation.world(zones, nil) > 0)
		end)
	end)
	t.test("duplicate node ID rejects the world", function()
		withWorld(function(zones)
			zones.Swamp.ResourceNodes.Node1:SetAttribute("NodeId", "Grasslands:1")
			t.expect.truthy(#Validation.world(zones, nil) > 0)
		end)
	end)
	t.test("wrong area rejects the world", function()
		withWorld(function(zones)
			zones.Swamp.ResourceNodes.Node1:SetAttribute("AreaId", "Grasslands")
			t.expect.truthy(#Validation.world(zones, nil) > 0)
		end)
	end)
	t.test("invalid affinity rejects config", function()
		local resource = Resources.get("RawMeat") local old = resource.Affinity
		resource.Affinity = "Invalid"
		local errors = Validation.config() resource.Affinity = old
		t.expect.truthy(#errors > 0)
	end)
	t.test("rounded ticket totals cannot hide wrong weight totals", function()
		local entry = Areas.get("Grasslands").ResourcePool[1]
		local resource = Resources.get(entry.Id) local old = entry.SpawnWeight
		entry.SpawnWeight, resource.SpawnWeight = old + 0.001, old + 0.001
		local errors = Validation.config()
		entry.SpawnWeight, resource.SpawnWeight = old, old
		t.expect.truthy(#errors > 0)
	end)
end
