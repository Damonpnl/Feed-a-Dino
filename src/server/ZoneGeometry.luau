--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AreaDefinitions"))

local ZoneGeometry = {}

export type Surface = {
	normal: Vector3,
	half: number,
	u: Vector3,
	uHalf: number,
	v: Vector3,
	vHalf: number,
}

function ZoneGeometry.surface(part: BasePart): Surface
	local candidates = {
		{
			normal = part.CFrame.RightVector,
			half = part.Size.X / 2,
			u = part.CFrame.UpVector,
			uHalf = part.Size.Y / 2,
			v = part.CFrame.LookVector,
			vHalf = part.Size.Z / 2,
		},
		{
			normal = part.CFrame.UpVector,
			half = part.Size.Y / 2,
			u = part.CFrame.RightVector,
			uHalf = part.Size.X / 2,
			v = part.CFrame.LookVector,
			vHalf = part.Size.Z / 2,
		},
		{
			normal = part.CFrame.LookVector,
			half = part.Size.Z / 2,
			u = part.CFrame.RightVector,
			uHalf = part.Size.X / 2,
			v = part.CFrame.UpVector,
			vHalf = part.Size.Y / 2,
		},
	}

	local best = candidates[1]
	local bestDot = -math.huge
	for _, candidate in candidates do
		local dot = candidate.normal:Dot(Vector3.yAxis)
		if dot > bestDot then
			bestDot = dot
			best = candidate
		end
	end

	if bestDot < 0 then
		best = {
			normal = -best.normal,
			half = best.half,
			u = best.u,
			uHalf = best.uHalf,
			v = best.v,
			vHalf = best.vHalf,
		}
	end

	return best
end

function ZoneGeometry.worldUpThickness(part: BasePart): number
	local surface = ZoneGeometry.surface(part)
	return surface.half * 2
end

function ZoneGeometry.findFloor(zone: Instance): BasePart?
	local floor: BasePart? = nil
	local thinnest = math.huge
	for _, child in zone:GetChildren() do
		if child:IsA("BasePart") then
			local thickness = ZoneGeometry.worldUpThickness(child)
			if thickness < thinnest then
				thinnest = thickness
				floor = child
			end
		end
	end
	return floor
end

function ZoneGeometry.randomTopPoint(part: BasePart, rng: Random): Vector3
	local surface = ZoneGeometry.surface(part)
	local u = (rng:NextNumber() - 0.5) * surface.uHalf * 2 * 0.8
	local v = (rng:NextNumber() - 0.5) * surface.vHalf * 2 * 0.7
	return part.Position + surface.normal * (surface.half + 1.3) + surface.u * u + surface.v * v
end

function ZoneGeometry.getZone(area: AreaDefinitions.AreaDefinition): Instance?
	local root = workspace:FindFirstChild("ExpeditionZones")
	if root == nil then
		return nil
	end
	return root:FindFirstChild(area.ZoneName)
end

return ZoneGeometry
