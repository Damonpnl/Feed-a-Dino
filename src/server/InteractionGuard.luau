--!strict
-- Common request preconditions. Rate limits are abuse controls, not progression values.
local Guard = {}
local requests: {[Player]: {[string]: number}} = {}
function Guard.allow(player: Player, action: string, interval: number): boolean
	if player.Parent ~= game:GetService("Players") then return false end
	local now = os.clock()
	local row = requests[player]
	if not row then row = {} requests[player] = row end
	if row[action] and now - row[action] < interval then return false end
	row[action] = now
	return true
end
function Guard.near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - position).Magnitude <= distance
end
function Guard.ownedBase(player: Player, base: Model, host: BasePart, distance: number): boolean
	return base.Parent == workspace:FindFirstChild("Bases") and host:IsDescendantOf(base)
		and base:GetAttribute("OwnerUserId") == player.UserId
		and player:GetAttribute("AssignedBaseName") == base.Name and Guard.near(player, host.Position, distance)
end
function Guard.clear(player: Player) requests[player] = nil end
game:GetService("Players").PlayerRemoving:Connect(Guard.clear)
return Guard
