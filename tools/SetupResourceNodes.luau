-- Run once via Studio MCP in Edit. Idempotent; preserve already positioned nodes.
local Areas = require(game.ReplicatedStorage.Shared.AreaDefinitions)
local Geometry = require(game.ServerScriptService.Server.ZoneGeometry)
local created = {}
for _, area in Areas.getOrdered() do
	local zone = assert(Geometry.getZone(area), "Missing zone: " .. area.ZoneName)
	local floor = assert(Geometry.findFloor(zone), "Missing floor: " .. area.Id)
	local surface = Geometry.surface(floor)
	local folder = zone:FindFirstChild("ResourceNodes")
	if not folder then folder = Instance.new("Folder") folder.Name = "ResourceNodes" folder.Parent = zone end
	assert(folder:IsA("Folder") and #folder:GetChildren() <= 5, "Unexpected node collection: " .. area.Id)
	for index = 1, 5 do
		local name = string.format("Node%02d", index)
		local node = folder:FindFirstChild(name)
		if not node then
			node = Instance.new("Part")
			node.Name = name
			node.Size = Vector3.new(1, 0.2, 1)
			-- Stagger along the +X corridor, comfortably inside its floor margins.
			local along = (index - 3) * surface.uHalf * 0.31
			local across = (if index % 2 == 0 then 1 else -1) * surface.vHalf * 0.22
			node.Position = floor.Position + surface.normal * surface.half + surface.u * along + surface.v * across
			node.Anchored, node.CanCollide, node.CanTouch, node.CanQuery = true, false, false, false
			node.Transparency = 1
			node.Parent = folder
			table.insert(created, node:GetFullName())
		end
		assert(node:IsA("BasePart"), "Node is not a part")
		node:SetAttribute("NodeId", area.Id .. ":" .. name)
		node:SetAttribute("AreaId", area.Id)
	end
end
return {Created = created, TotalNodes = 25}
