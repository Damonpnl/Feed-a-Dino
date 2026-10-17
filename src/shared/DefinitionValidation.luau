--!nonstrict
-- Cross-definition validation is separate from immutable content and player runtime state.
local ResourceValidation = require(script.Parent.ResourceValidation)
local Resources = require(script.Parent.ResourceDefinitions)
local Monsters = require(script.Parent.MonsterDefinitions)
local Trainers = require(script.Parent.TrainerDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Effects = require(script.Parent.SpecialEffectDefinitions)
local Billboard = require(script.Parent.BillboardConfig)
local Styles = require(script.Parent.RarityStyles)
local Validation = {}
function Validation.config()
	local errors = ResourceValidation.config()
	for _,name in {"PetRarity","PrestigeCalculator","PetMultipliers"} do
		local ok,messages=pcall(function() return require(script.Parent[name]).validate() end)
		if ok then for _,message in messages do table.insert(errors,message) end
		else table.insert(errors,"Malformed "..name..": "..tostring(messages)) end
	end
	local catalystOK,catalystErrors=pcall(require(script.Parent.CatalystEffects).validate)
	if catalystOK then for _,message in catalystErrors do table.insert(errors,message) end
	else table.insert(errors,"Malformed catalyst behavior: "..tostring(catalystErrors)) end
	local ok,evolutionErrors=pcall(require(script.Parent.EvolutionCalculator).validate)
	if ok then for _,message in evolutionErrors do table.insert(errors,message) end
	else table.insert(errors,"Malformed evolution graph: "..tostring(evolutionErrors)) end
	for _,message in require(script.Parent.GuardianConfig).validate() do table.insert(errors,message) end
	local warnings = {"Trainer prices, initial ownership and TrainingLevel migration are unspecified; new trainer purchases remain disabled."}
	local function check(ok,message) if not ok then table.insert(errors,message) end return ok end
	local function number(v,min) return type(v)=="number" and v==v and v<math.huge and v> -math.huge and v>=min end
	local function text(v) return type(v)=="string" and #v>0 end
	local families={}
	for id,effect in Effects do
		check(text(effect.DisplayText) or effect.Kind=="None", "Missing effect label: "..id)
		check(effect.Kind=="None" or effect.Kind=="EvolutionFamily" or effect.Kind=="ProgressionTag" or effect.Kind=="Mutation", "Invalid effect kind: "..id)
		if effect.Family then families[effect.Family]=true end
		if effect.Kind=="Mutation" then check(text(effect.MutationId) and number(effect.Chance,0) and effect.Chance<=1, "Invalid mutation effect: "..id) end
	end
	for alias,target in Monsters.CatalystAliases do
		local resource=Resources.get(target)
		check(text(alias) and resource and resource.ResourceType=="Catalyst", "Invalid compatibility alias: "..alias)
	end
	local all=Monsters.getAll()
	for id,monster in all do
		if not check(type(monster)=="table", "Invalid pet definition: "..tostring(id)) then continue end
		check(text(id) and monster.Id==id and text(monster.DisplayName), "Invalid pet identity: "..id)
		check(number(monster.BaseMultiplier,0) and monster.BaseMultiplier>0 and number(monster.GrowthRequired,0), "Invalid pet progression: "..id)
		check(Rarities.isValid(monster.Rarity) and typeof(monster.Color)=="Color3", "Invalid pet style: "..id)
		if not check(type(monster.Evolutions)=="table", "Missing evolutions: "..id) then continue end
		local targets={}
		for _,evolution in monster.Evolutions do
			if not check(type(evolution)=="table", "Invalid evolution: "..id) then continue end
			check(all[evolution.Result] and not targets[evolution.Result], "Invalid/duplicate evolution target: "..id)
			if text(evolution.Result) then targets[evolution.Result]=true end
			if evolution.Family then check(families[evolution.Family], "Unknown evolution family: "..id) end
			if evolution.Catalyst then
				local catalyst=Resources.get(Monsters.CatalystAliases[evolution.Catalyst] or evolution.Catalyst)
				check(catalyst and catalyst.ResourceType=="Catalyst", "Unknown evolution catalyst: "..id)
			end
			if check(type(evolution.Requirements)=="table", "Missing requirements: "..id) then
				for affinity,amount in evolution.Requirements do check((affinity=="Flesh" or affinity=="Flora" or affinity=="Mineral") and number(amount,0), "Invalid evolution requirement: "..id) end
			end
		end
	end
	local ids={}
	check(#Trainers.getOrdered()==10, "Expected ten trainer tiers")
	for index,trainer in Trainers.getOrdered() do
		check(text(trainer.Id) and not ids[trainer.Id] and text(trainer.DisplayName), "Invalid/duplicate trainer identity")
		if text(trainer.Id) then ids[trainer.Id]=true end
		check(trainer.Tier==index and Rarities.isValid(trainer.Rarity), "Invalid trainer tier/rarity")
		check(number(trainer.Multiplier,0) and trainer.Multiplier>0, "Invalid trainer multiplier")
		check(type(trainer.Purchasable)=="boolean", "Missing trainer availability")
		check(trainer.Price==nil or number(trainer.Price,0), "Invalid trainer price")
		check(not trainer.Purchasable or number(trainer.Price,0), "Purchasable trainer needs an approved price")
	end
	for name,value in Trainers.Legacy do check(number(value,0) and value>0, "Invalid retained prototype trainer value: "..name) end
	check(text(Billboard.Tag) and text(Billboard.AttributePrefix) and typeof(Billboard.DefaultOffset)=="Vector3", "Invalid billboard identity/offset")
	check(type(Billboard.AlwaysOnTop)=="boolean", "Invalid billboard occlusion configuration")
	for _,name in {"DistanceInterval","BoundsInterval","AnimationInterval","EnterDuration","ExitDuration","Width","Height","MaxVisible","MaxAnimated"} do
		check(number(Billboard[name],0) and Billboard[name]>0,"Invalid billboard field: "..name)
	end
	check(number(Billboard.MinScale,0) and Billboard.MinScale<=1 and number(Billboard.Hysteresis,0), "Invalid billboard scale/hysteresis")
	check(number(Billboard.MaxAnimated,0) and number(Billboard.MaxVisible,0) and Billboard.MaxAnimated<=Billboard.MaxVisible and Billboard.MaxAnimated%1==0 and Billboard.MaxVisible%1==0, "Invalid billboard budgets")
	for id,preset in Billboard.ObjectTypes do check(number(preset.Near,0) and number(preset.Far,0) and preset.Far>preset.Near, "Invalid billboard distances: "..id) end
	for index,id in Rarities.Order do
		local rarity,style=Rarities.get(id),Styles[id]
		check(rarity and rarity.Priority==index and typeof(rarity.Color)=="Color3", "Invalid rarity metadata: "..id)
		check(style and style.Priority==index, "Missing/mismatched rarity style: "..id)
	end
	return errors,warnings
end
return Validation
