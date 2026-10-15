--!nonstrict
-- Pure compatibility and staged-copy effects. No services, remotes or random source.
local Catalysts=require(script.Parent.CatalystDefinitions)
local Monsters=require(script.Parent.MonsterDefinitions)
local Mutations=require(script.Parent.MutationDefinitions)
local SpecialEffects=require(script.Parent.SpecialEffectDefinitions)
local Effects={}
local kinds={UnlockEvolutionFamily=true,AddLineageTag=true,AddLatentTrait=true,
	EnableSpecialEvolution=true,AttemptMutation=true,ForceEligibleBranch=true}
local fields={UnlockEvolutionFamily="EvolutionFamilies",AddLineageTag="LineageTags",
	AddLatentTrait="LatentTraits",EnableSpecialEvolution="SpecialEvolutions"}
function Effects.compatible(record,behavior)
	if not behavior or not behavior.Enabled then return false,"Catalyst is disabled" end
	for _,field in fields do
		if record[field]~=nil then
			if type(record[field])~="table" then return false,"Invalid saved catalyst state" end
			for id,value in record[field] do
				if type(id)~="string" or type(value)~="boolean" then return false,"Invalid saved catalyst flag" end
			end
		end
	end
	local species=Monsters.get(record.Species)
	if not species or species.Lineage~=record.Lineage then return false,"Incompatible species" end
	if behavior.Species and not table.find(behavior.Species,record.Species) then return false,"Incompatible species" end
	if behavior.Forms and not table.find(behavior.Forms,record.EvolutionForm or record.Species) then return false,"Incompatible form" end
	if behavior.RequiredLineage and record.Lineage~=behavior.RequiredLineage then return false,"Incompatible lineage" end
	if type(record.Stage)~="number" or record.Stage%1~=0 or record.Stage<behavior.MinStage or record.Stage>behavior.MaxStage then return false,"Incompatible growth stage" end
	for affinity,minimum in behavior.Affinities or {} do
		if type(record[affinity])~="number" or not (record[affinity]>=minimum and record[affinity]<math.huge) then return false,"Catalyst affinity requirement" end
	end
	for _,condition in { {"RequiredFamilies","EvolutionFamilies"},{"RequiredTags","LineageTags"},
		{"RequiredTraits","LatentTraits"},{"RequiredSpecialEvolutions","SpecialEvolutions"} } do
		for _,id in behavior[condition[1]] or {} do
			if not (record[condition[2]] or {})[id] then return false,"Missing catalyst condition: "..id end
		end
	end
	for _,id in behavior.ForbiddenFamilies or {} do
		if (record.EvolutionFamilies or {})[id] then return false,"Incompatible previous unlock" end
	end
	return true
end
function Effects.apply(record,behavior,nextNumber)
	local ok,reason=Effects.compatible(record,behavior) assert(ok,reason)
	local forced
	for _,effect in behavior.Effects do
		assert(kinds[effect.Kind] and type(effect.Id)=="string","Unknown catalyst effect")
		local field=fields[effect.Kind]
		if field then
			record[field]=record[field] or {} record[field][effect.Id]=true
		elseif effect.Kind=="AttemptMutation" then
			assert(type(effect.Chance)=="number" and effect.Chance>=0 and effect.Chance<=1,"Invalid mutation chance")
			if Mutations.canApply(record,effect.Id) and nextNumber()<effect.Chance then Mutations.apply(record,effect.Id) end
		elseif effect.Kind=="ForceEligibleBranch" then
			assert(not forced,"Multiple forced branches") forced=effect.Id
		end
	end
	return forced -- caller MUST pass this to the normal evolution eligibility resolver
end
function Effects.validate()
	local errors={}
	local families={Mutant=true,Alpha=true} -- retained legacy family aliases, not mutation overlays
	for _,effect in SpecialEffects do if effect.Family then families[effect.Family]=true end end
	local function check(ok,message) if not ok then table.insert(errors,message) end end
	local function number(v) return type(v)=="number" and v>=0 and v<math.huge end
	for id,b in Catalysts.getBehaviors() do
		local d=Catalysts.get(id)
		if not d or b.Enabled~=d.Launch then table.insert(errors,"Launch mismatch: "..id) end
		check(number(b.MinStage) and number(b.MaxStage) and b.MinStage%1==0 and b.MaxStage%1==0 and b.MaxStage<=4 and b.MinStage<=b.MaxStage,"Invalid stage range: "..id)
		check(b.RequiredLineage==nil or b.RequiredLineage=="ProtoRex","Unknown lineage: "..id)
		for _,field in {"Species","Forms"} do for _,form in b[field] or {} do check(Monsters.get(form)~=nil,"Unknown compatible form: "..id) end end
		for affinity,minimum in b.Affinities or {} do check((affinity=="Flesh" or affinity=="Flora" or affinity=="Mineral") and number(minimum),"Invalid affinity: "..id) end
		for _,field in {"RequiredFamilies","ForbiddenFamilies"} do for _,family in b[field] or {} do check(families[family],"Unknown family condition: "..id) end end
		local seen={} local forced=0
		for _,effect in b.Effects do
			if not kinds[effect.Kind] or type(effect.Id)~="string" or effect.Id=="" then table.insert(errors,"Invalid effect: "..id) end
			local key=tostring(effect.Kind)..":"..tostring(effect.Id)
			check(not seen[key],"Duplicate effect: "..id) seen[key]=true
			if effect.Kind=="UnlockEvolutionFamily" then check(families[effect.Id],"Unknown family effect: "..id) end
			if effect.Kind=="AttemptMutation" then
				local m=Mutations.get(effect.Id)
				if not m or m.Kind~="Overlay" or type(effect.Chance)~="number" or not (effect.Chance>=0 and effect.Chance<=1) then table.insert(errors,"Invalid mutation: "..id) end
			elseif effect.Kind=="ForceEligibleBranch" then
				forced+=1 check(forced==1,"Multiple forced branches: "..id)
				local found=false
				for _,form in Monsters.getAll() do for _,edge in form.Evolutions do if edge.Id==effect.Id and not edge.Locked and edge.TargetStage<5 then found=true end end end
				if not found then table.insert(errors,"Invalid forced branch: "..id) end
			end
		end
	end
	return errors
end
return Effects
