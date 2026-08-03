--!strict

--[[
	Shared per-player base session registry.
	ModuleScript cache ensures duplicate harness Scripts share the same tables.
]]

local PlayerBaseSessions = {}

PlayerBaseSessions.byPlayer = {} :: { [Player]: any }
PlayerBaseSessions.byBase = {} :: { [Model]: any }

function PlayerBaseSessions.getForPlayer(player: Player): any?
	return PlayerBaseSessions.byPlayer[player]
end

function PlayerBaseSessions.getForBase(base: Model): any?
	return PlayerBaseSessions.byBase[base]
end

function PlayerBaseSessions.set(player: Player, base: Model, session: any): ()
	PlayerBaseSessions.byPlayer[player] = session
	PlayerBaseSessions.byBase[base] = session
end

function PlayerBaseSessions.clear(player: Player): any?
	local session = PlayerBaseSessions.byPlayer[player]
	if session == nil then
		return nil
	end

	local base = session.base
	if typeof(base) == "Instance" and base:IsA("Model") then
		PlayerBaseSessions.byBase[base] = nil
	end
	PlayerBaseSessions.byPlayer[player] = nil
	return session
end

return PlayerBaseSessions
