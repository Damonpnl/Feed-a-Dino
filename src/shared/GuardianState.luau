--!nonstrict
-- Deterministic encounter state. The server adapter supplies time and acquisition identity.
local Config = require(script.Parent.GuardianConfig)
local State = {}
State.__index = State
State.Transitions = {SLEEPING={DISTURBED=true}, DISTURBED={WARNING=true}, WARNING={HAZARD=true}, HAZARD={COOLDOWN=true}, COOLDOWN={SLEEPING=true}}
function State.new(config)
	return setmetatable({Config=config, State="SLEEPING", Disturbance=Config.Baseline, Activation=0, Deadline=nil, HazardStart=nil},State)
end
function State:transition(nextState, at, emit)
	assert(State.Transitions[self.State][nextState], "Illegal guardian transition")
	self.State = nextState
	if nextState=="WARNING" then self.Activation+=1 self.Deadline=at+self.Config.Warning
	elseif nextState=="HAZARD" then self.HazardStart=at self.Deadline=at+self.Config.Active
	elseif nextState=="COOLDOWN" then self.Deadline=at+self.Config.Cooldown
	elseif nextState=="SLEEPING" then self.Deadline=nil self.Disturbance=Config.Baseline end
	if emit then emit(nextState,at) end
end
function State:pickup(rarity, now, emit)
	local amount = Config.Disturbance[rarity]
	if not amount and not Config.Immediate[rarity] then return false end
	if self.State~="SLEEPING" and self.State~="DISTURBED" then return false end
	self.Disturbance = if Config.Immediate[rarity] then Config.Threshold else math.min(Config.Threshold,self.Disturbance+amount)
	if self.State=="SLEEPING" then self:transition("DISTURBED",now,emit) end
	if self.Disturbance>=Config.Threshold then self:transition("WARNING",now,emit) end
	return true
end
function State:step(now, emit, sample)
	-- Process swept contact before leaving HAZARD, even if an entire window elapsed
	-- between server frames. Never extend a hazard because a frame arrived late.
	if self.State=="WARNING" and now>=self.Deadline then self:transition("HAZARD",self.Deadline,emit) end
	if self.State=="HAZARD" then
		if sample then sample(self.HazardStart, math.min(now,self.Deadline)) end
		if now>=self.Deadline then self:transition("COOLDOWN",self.Deadline,emit) end
	end
	if self.State=="COOLDOWN" and now>=self.Deadline then self:transition("SLEEPING",self.Deadline,emit) end
end
function State:reset()
	self.State="SLEEPING" self.Disturbance=Config.Baseline self.Deadline=nil self.HazardStart=nil
	-- Generation also invalidates client hooks and active hit sets.
	self.Activation+=1
end
return State
