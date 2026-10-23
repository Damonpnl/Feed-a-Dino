--!strict
-- Pure economy math. Services own sessions/time/transactions; UI never grants rewards.
local Config = require(script.Parent.EconomyConfig)
local Trainers = require(script.Parent.TrainerDefinitions)
local Economy = {}
function Economy.finite(value: any): boolean
	return type(value)=="number" and value==value and value>=0 and value<=Config.MaxNumber
end
function Economy.tier(value: any): boolean
	return Economy.finite(value) and value%1==0 and value>=1 and value<=#Trainers.getOrdered()
end
function Economy.rate(...: number): number
	local result=1
	for _,factor in {...} do
		if not Economy.finite(factor) then return 0 end
		result=math.min(Config.MaxRate,result*factor)
	end
	return result
end
function Economy.income(multiplier: number): number
	return Economy.rate(Config.BaseCashPerSecond,multiplier)
end
function Economy.training(tier: number, pet: number, legacyLevel: number?, boost: number?): number
	if not Economy.tier(tier) or not Economy.finite(pet) then return 0 end
	local gain=Economy.rate(Config.BaseTrainingGain,Trainers.getOrdered()[tier].Multiplier,pet)
	-- Never reinterpret or erase purchased TrainingLevel. Grandfather its old gain
	-- as a floor, not an extra stack/refund/new tier. New saves have level zero.
	if Economy.finite(legacyLevel) and (legacyLevel :: number)>0 then
		gain=math.max(gain,math.min(Config.MaxRate,Trainers.legacyGain(legacyLevel :: number,pet)))
	end
	return Economy.rate(gain,boost or Config.TemporaryBoost)
end
function Economy.add(balance: number, gain: number): number?
	if not Economy.finite(balance) or not Economy.finite(gain) then return nil end
	return balance+math.min(gain,Config.MaxNumber-balance)
end
function Economy.purchase(cash: number, current: number, target: any): (number?, string)
	if not Economy.finite(cash) or not Economy.tier(current) then return nil,"Invalid economy state" end
	if not Economy.tier(target) or target~=current+1 then return nil,"Stale or invalid trainer tier" end
	local definition=Trainers.getOrdered()[target]
	if not definition.Purchasable or not Economy.finite(definition.Price) then return nil,"Trainer unavailable" end
	if cash<(definition.Price :: number) then return nil,"Insufficient Cash" end
	return cash-(definition.Price :: number),"Purchased "..definition.DisplayName
end
function Economy.advance(progress: number, dt: number): (number, boolean)
	if not Economy.finite(dt) or not Economy.finite(progress) then return 0,false end
	local nextProgress=progress+math.min(dt,Config.MaxFrameCredit)
	if nextProgress>=Config.TickSeconds then return nextProgress%Config.TickSeconds,true end
	return nextProgress,false
end
function Economy.validate(): {string}
	local errors={}
	for key,value in Config do
		if not Economy.finite(value) or value<=0 then table.insert(errors,"Invalid economy config: "..key) end
	end
	if Config.TickSeconds~=1 or Config.MaxFrameCredit>Config.TickSeconds then table.insert(errors,"Invalid economy tick") end
	for i,definition in Trainers.getOrdered() do
		if not Economy.finite(definition.Price) or definition.Price%1~=0 or (i==1 and definition.Price~=0)
			or (i>1 and definition.Price<=0) then table.insert(errors,"Invalid trainer price: "..definition.Id) end
	end
	return errors
end
return Economy
