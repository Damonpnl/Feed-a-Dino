--!nonstrict
-- Pure resolver. RNG must be supplied by the authoritative transaction, never UI.
local Rarities=require(script.Parent.RarityDefinitions)
local Config=require(script.Parent.PetProgressionConfig)
local Rarity={}
function Rarity.validRule(rule)
	return type(rule)=="table" and type(rule.Enabled)=="boolean"
		and type(rule.Tiers)=="number" and rule.Tiers>=0 and rule.Tiers%1==0 and rule.Tiers<#Rarities.Order
		and (rule.Tiers<=1 or rule.AllowMultiple==true)
		and (rule.Chance==nil or (type(rule.Chance)=="number" and rule.Chance>=0 and rule.Chance<=1))
		and (not rule.Enabled or rule.Tiers==0 or rule.Chance~=nil)
		and (rule.MinStage==nil or (type(rule.MinStage)=="number" and rule.MinStage>=0 and rule.MinStage<=5 and rule.MinStage%1==0))
		and (rule.MinRarity==nil or Rarities.isValid(rule.MinRarity))
		and (rule.RequiredFamily==nil or type(rule.RequiredFamily)=="string")
		and (rule.Ceiling==nil or Rarities.isValid(rule.Ceiling))
end
function Rarity.resolve(record,rule,nextNumber)
	assert(Rarities.isValid(record.Rarity),"Invalid saved pet rarity")
	assert(Rarity.validRule(rule),"Invalid pet rarity rule")
	assert(Rarities.isValid(Config.RarityCeiling),"Invalid global pet rarity ceiling")
	local before=record.Rarity
	if not rule.Enabled or rule.Tiers==0 or (rule.MinStage and record.Stage<rule.MinStage)
		or (rule.MinRarity and Rarities.priority(before)<Rarities.priority(rule.MinRarity))
		or (rule.RequiredFamily and not (record.EvolutionFamilies or {})[rule.RequiredFamily]) then return before end
	local ceiling=math.min(Rarities.priority(Config.RarityCeiling),Rarities.priority(rule.Ceiling or Config.RarityCeiling))
	local target=math.min(Rarities.priority(before)+rule.Tiers,ceiling)
	if target<=Rarities.priority(before) or rule.Chance==0 then return before end -- never demote old saves
	if rule.Chance<1 then
		assert(type(nextNumber)=="function","Rarity promotion requires server RNG")
		local ticket=nextNumber()
		assert(type(ticket)=="number" and ticket>=0 and ticket<1,"Invalid rarity ticket")
		if ticket>=rule.Chance then return before end
	end
	return Rarities.Order[target]
end
function Rarity.validate()
	local errors={}
	if not Rarities.isValid(Config.RarityCeiling) then table.insert(errors,"Invalid pet rarity ceiling") end
	for id,rule in Config.RarityRules do if not Rarity.validRule(rule) then table.insert(errors,"Invalid rarity rule: "..id) end end
	return errors
end
return Rarity
