--!strict
-- Pure step milestones: no currency, saved speed, or independent runtime controller.
local Config=require(script.Parent.MovementConfig)
local Debuff=require(script.Parent.CarryDebuff)
local Movement={}
local function resolve(power: any, key: string): number
	if type(power)~="number" or power~=power or power<0 or power==math.huge then return Config.PrecisionSpeed end
	local speed=Config.PrecisionSpeed
	for _,row in Config.Milestones do
		if power<row.Power then break end
		speed=row[key]
	end
	return speed
end
function Movement.base(power: any): number return resolve(power,"Speed") end
function Movement.carryBase(power: any): number return resolve(power,"CarrySpeed") end
function Movement.effective(power: any, slow: boolean, carrying: boolean, applied: number, ragdolled: boolean): number
	if ragdolled then return 0 end -- PlatformStand also remains owned by GuardianCatch.
	local base=if slow then Config.PrecisionSpeed else Movement.base(power)
	if carrying then
		base=math.min(base,Movement.carryBase(power))
		if applied~=applied or applied==math.huge or applied==-math.huge then return 0 end
		return base*(1-math.clamp(applied,0,Debuff.MaxTotal))
	end
	return base
end
function Movement.validate(): {string}
	local errors={}
	local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
	local power,speed,carry=-1,0,0
	for _,row in Config.Milestones do
		if not finite(row.Power) or not finite(row.Speed) or not finite(row.CarrySpeed) or row.Power<=power or row.Speed<speed
			or row.Speed<=0 or row.Speed>Config.MaxSpeed or row.CarrySpeed<carry or row.CarrySpeed>row.Speed or row.CarrySpeed<Config.PrecisionSpeed then
			table.insert(errors,"Invalid movement milestone")
		end
		power,speed,carry=row.Power,row.Speed,row.CarrySpeed
	end
	if #Config.Milestones==0 or Config.Milestones[1].Power~=0 then
		table.insert(errors,"Missing initial movement milestone")
	end
	if not finite(Config.PrecisionSpeed) or Config.PrecisionSpeed<=0 or Config.PrecisionSpeed>Config.Milestones[1].Speed
		or not finite(Config.RequestInterval) or Config.RequestInterval<=0 then table.insert(errors,"Invalid movement limits") end
	return errors
end
return Movement
