--!nonstrict
-- Deterministic encounter state. The server adapter supplies time, targets, and movement.
local Config = require(script.Parent.GuardianConfig)
local Chase = require(script.Parent.GuardianChase)
local State = {}
State.__index = State
State.Transitions = {
	SLEEPING = { WAKING = true },
	WAKING = { PURSUING = true },
	PURSUING = { WARNING = true, RETURNING = true },
	WARNING = { HAZARD = true, RETURNING = true },
	HAZARD = { COOLDOWN = true, RETURNING = true },
	COOLDOWN = { PURSUING = true, RETURNING = true },
	RETURNING = { SLEEPING = true, PURSUING = true },
}
function State.new(config)
	return setmetatable({
		Config = config, State = "SLEEPING", Disturbance = Config.Baseline,
		Activation = 0, Deadline = nil, HazardStart = nil, Rarity = nil,
	}, State)
end
function State:transition(nextState, at, emit)
	assert(State.Transitions[self.State][nextState], "Illegal guardian transition")
	self.State = nextState
	local rarity = self.Rarity or "Common"
	if nextState == "WAKING" then
		self.Activation += 1
		self.Deadline = at + Chase.wake(self.Config)
	elseif nextState == "PURSUING" then
		self.Deadline = at + Chase.attackDelay(rarity)
	elseif nextState == "WARNING" then
		self.Deadline = at + self.Config.Warning
	elseif nextState == "HAZARD" then
		self.HazardStart = at
		self.Deadline = at + self.Config.Active
	elseif nextState == "COOLDOWN" then
		self.Deadline = at + Chase.recovery(self.Config.Cooldown, rarity)
	elseif nextState == "RETURNING" then
		self.Deadline = at + Chase.Timing.ReturnDuration
	elseif nextState == "SLEEPING" then
		self.Deadline = nil
		self.HazardStart = nil
		self.Rarity = nil
		self.Disturbance = Config.Baseline
	end
	if emit then emit(nextState, at) end
end
function State:pickup(rarity, now, emit)
	local chosen = Chase.stronger(self.Rarity, rarity)
	if not chosen then return false end
	self.Rarity = chosen
	-- Any known rarity wakes a sleeper. Active attacks are not restarted.
	if self.State == "SLEEPING" then
		self:transition("WAKING", now, emit)
	elseif self.State == "RETURNING" then
		self:transition("PURSUING", now, emit)
	end
	return true
end
function State:step(now, emit, sample, context)
	context = context or {}
	local attacked = false
	for _ = 1, 8 do
		if self.State == "WAKING" and now >= self.Deadline then
			self:transition("PURSUING", self.Deadline, emit)
		elseif self.State == "PURSUING" then
			if context.retreat then
				self:transition("RETURNING", now, emit)
			elseif context.attack or (context.attack == nil and now >= self.Deadline) then
				if attacked then break end
				self:transition("WARNING", if context.attack then now else self.Deadline, emit)
			else
				break
			end
		elseif self.State == "WARNING" and now >= self.Deadline then
			self:transition("HAZARD", self.Deadline, emit)
		elseif self.State == "HAZARD" then
			if sample then sample(self.HazardStart, math.min(now, self.Deadline)) end
			-- Contact can reconcile the reset cutoff synchronously; never finish a stale attack.
			if self.State~="HAZARD" then break end
			if now >= self.Deadline then
				attacked = true
				self:transition("COOLDOWN", self.Deadline, emit)
			else
				break
			end
		elseif self.State == "COOLDOWN" and now >= self.Deadline then
			if context.pursue and not context.retreat then
				self:transition("PURSUING", self.Deadline, emit)
			else
				self:transition("RETURNING", self.Deadline, emit)
			end
		elseif self.State == "RETURNING" and (context.home or now >= self.Deadline) then
			self:transition("SLEEPING", if context.home then now else self.Deadline, emit)
		else
			break
		end
	end
end
function State:reset()
	self.State = "SLEEPING"
	self.Disturbance = Config.Baseline
	self.Deadline = nil
	self.HazardStart = nil
	self.Rarity = nil
	self.Activation += 1
end
return State
