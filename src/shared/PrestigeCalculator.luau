--!nonstrict
-- Declarative, pure eligibility. No resource consumption, remotes or live grants.
local Config=require(script.Parent.PetProgressionConfig)
local Rarities=require(script.Parent.RarityDefinitions)
local Max=require(script.Parent.GrowthStageDefinitions).MaxNumber
local Prestige={}
local function number(n) return type(n)=="number" and n>=0 and n<=Max end
local function result(state,reason) return {State=state,Ready=state=="Ready",Reason=reason} end
function Prestige.validState(record)
	if record.Awakened~=nil and type(record.Awakened)~="boolean" then return false end
	if record.Qualifications~=nil and type(record.Qualifications)~="table" then return false end
	if record.Ascension~=nil and (type(record.Ascension)~="table"
		or not ({Locked=true,Eligible=true,Ready=true,Completed=true})[record.Ascension.State]) then return false end
	if record.Awakened==true and (type(record.Awakening)~="table" or type(record.Awakening.Id)~="string"
		or type(record.Awakening.Form)~="string" or type(record.Awakening.Family)~="string") then return false end
	return true
end
function Prestige.initialize(record)
	if record.Ascension==nil then record.Ascension={State="Locked"} end
	if record.Awakened==nil then record.Awakened=false end
	if record.Qualifications==nil then record.Qualifications={} end
end
local function requirements(record,definition,catalyst)
	if definition.RequirementsApproved~=true then return false,"Final requirements need approval" end
	if record.EvolutionForm~=definition.SourceForm or record.Lineage~=definition.RequiredLineage then return false,"Wrong form or lineage" end
	if not number(definition.Growth) or not number(record.Growth) or not number(record.GrowthReserve or 0)
		or record.Growth+(record.GrowthReserve or 0)<definition.Growth then return false,"Growth requirement" end
	if not Rarities.isValid(record.Rarity) or not Rarities.isValid(definition.MinRarity)
		or Rarities.priority(record.Rarity)<Rarities.priority(definition.MinRarity) then return false,"Rarity requirement" end
	for key,value in definition.Affinities or {} do
		if not ({Flesh=true,Flora=true,Mineral=true})[key] or not number(value) or not number(record[key]) or record[key]<value then return false,"Affinity mastery required" end
	end
	for field,list in {EvolutionFamilies=definition.RequiredFamilies,LatentTraits=definition.RequiredTraits,
		Qualifications=definition.RequiredQualifications,LineageTags=definition.RequiredTags} do
		for _,id in list or {} do if type(record[field])~="table" or record[field][id]~=true then return false,"Missing "..field..": "..id end end
	end
	if definition.Catalysts and not table.find(definition.Catalysts,catalyst) then return false,"Compatible catalyst required" end
	return true
end
function Prestige.ascension(record,definition,catalyst)
	if not Prestige.validState(record) then return result("Locked","Invalid persisted prestige state") end
	if type(definition)~="table" then return result("Locked","No ascension definition") end
	if record.Stage==5 and type(record.Ascension)=="table" and record.Ascension.State=="Completed"
		and record.Ascension.Id==definition.Id and record.EvolutionForm==definition.TargetForm then return result("Completed","") end
	if record.Stage~=4 or definition.SourceStage~=4 or definition.TargetStage~=5 then return result("Locked","Requires Stage 4") end
	local ok,reason=requirements(record,definition,catalyst)
	if not ok then return result("Locked",reason) end
	return result(if definition.Enabled==true then "Ready" else "Eligible",if definition.Enabled==true then "" else "Ascension is unreleased")
end
function Prestige.awakening(record,definition,catalyst)
	if not Prestige.validState(record) then return result("Locked","Invalid persisted prestige state") end
	if type(definition)~="table" then return result("Locked","No awakening definition") end
	if record.Awakened==true then
		if type(record.Awakening)=="table" and record.Awakening.Id==definition.Id then return result("Completed","") end
		return result("Locked","Already awakened or incompatible saved awakening")
	end
	if record.Stage~=5 or type(record.Ascension)~="table" or record.Ascension.State~="Completed"
		or record.Ascension.Id~=definition.RequiredAscension then return result("Locked","Completed ascension required") end
	local ok,reason=requirements(record,definition,catalyst)
	if not ok then return result("Locked",reason) end
	-- No implicit success chance: only explicitly guaranteed definitions can be Ready.
	local ready=definition.Enabled==true and definition.Guaranteed==true
	return result(if ready then "Ready" else "Eligible",if ready then "" else "Awakening outcome is not enabled unless explicitly guaranteed")
end
function Prestige.planAwakening(record,definition,catalyst)
	-- Caller must use a staged copy inside an authorized consumption transaction.
	-- This pure handoff API is deliberately NOT exposed by any live remote/feed effect.
	local status=Prestige.awakening(record,definition,catalyst)
	if not status.Ready then return false,status.Reason end
	if not number(record.Revision) or record.Revision>=Max or record.Revision%1~=0 then return false,"Invalid revision" end
	record.Revision+=1 record.Awakened=true
	record.Awakening={Id=definition.Id,Form=definition.Form,Family=definition.Family,Revision=record.Revision,
		Presentation=table.clone(definition.Presentation or {})}
	return true
end
function Prestige.validate()
	local errors={}
	local forms=require(script.Parent.MonsterDefinitions)
	local resources=require(script.Parent.ResourceDefinitions)
	local function check(ok,message) if not ok then table.insert(errors,message) end end
	for kind,definitions in {Ascension=Config.Ascensions,Awakening=Config.Awakenings} do
		for id,d in definitions do
			check(d.Id==id and type(d.Enabled)=="boolean" and type(d.RequirementsApproved)=="boolean","Invalid prestige identity/availability: "..id)
			check(forms.get(d.SourceForm)~=nil and d.RequiredLineage=="ProtoRex","Invalid prestige source/lineage: "..id)
			check(not d.Enabled,"Unreleased prestige must remain disabled: "..id)
			if kind=="Ascension" then
				check(forms.get(d.SourceForm).Stage==4 and forms.get(d.TargetForm) and forms.get(d.TargetForm).Stage==5
					and d.SourceStage==4 and d.TargetStage==5,"Invalid ascension stage reference: "..id)
			else
				check(Config.Ascensions[d.RequiredAscension] and forms.get(d.SourceForm).Stage==5,"Invalid awakening ascension reference: "..id)
				check(type(d.Form)=="string" and type(d.Family)=="string" and type(d.Guaranteed)=="boolean"
					and type(d.Presentation)=="table" and d.Presentation.ModelKey=="Placeholder","Invalid awakening presentation: "..id)
			end
			if d.RequirementsApproved then check(number(d.Growth) and Rarities.isValid(d.MinRarity),"Missing approved prestige requirements: "..id) end
			for _,list in {d.RequiredFamilies,d.RequiredTraits,d.RequiredQualifications,d.RequiredTags or {}} do
				check(type(list)=="table","Invalid prestige requirements list: "..id)
				local seen={} for _,tag in list do
					check(type(tag)=="string" and #tag>0 and not seen[tag],"Invalid/duplicate prestige requirement: "..id)
					seen[tag]=true
				end
			end
			for key,value in d.Affinities do check(({Flesh=true,Flora=true,Mineral=true})[key] and number(value),"Invalid prestige affinity: "..id) end
			for _,resourceId in d.Catalysts or {} do
				local resource=resources.get(resourceId)
				check(resource and resource.ResourceType=="Catalyst","Unknown prestige catalyst: "..id)
			end
		end
	end
	return errors
end
return Prestige
