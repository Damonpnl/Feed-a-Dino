--!nonstrict
-- Pure evolution planning; mutators operate only on the caller's staged copy.
local Definitions = require(script.Parent.MonsterDefinitions)
local Config = require(script.Parent.GrowthStageDefinitions)
local Rarities = require(script.Parent.RarityDefinitions)
local Calculator = {}
local affinities = {Flesh=true,Flora=true,Mineral=true}
local function number(value) return type(value)=="number" and value>=0 and value<=Config.MaxNumber end

function Calculator.form(record) return record.EvolutionForm or record.Species end
function Calculator.initialize(record, ownedKey)
	-- Additive migration: never rename ownership keys, existing IDs or unknown fields.
	-- 4A defaulted even evolved legacy forms to Stage 0. Infer only absent schema/form.
	if record.EvolutionVersion == nil then
		if record.EvolutionForm == nil then
			record.EvolutionForm = record.Species
			local definition=Definitions.get(record.Species)
			if (record.Stage or 0)==0 then record.Stage=if definition then definition.Stage else 0 end
		end
		record.EvolutionVersion=Config.Version
	end
	record.PetId = record.PetId or ownedKey -- owner-scoped legacy identity; existing GUIDs untouched
	record.GrowthReserve = record.GrowthReserve or 0
	record.Lineage = record.Lineage or "ProtoRex"
	record.LineageTags = record.LineageTags or {}
	record.LatentTraits = record.LatentTraits or {}
	record.SpecialEvolutions = record.SpecialEvolutions or {}
end
function Calculator.valid(record)
	if type(record)~="table" then return false end
	local definition=Definitions.get(Calculator.form(record))
	if not definition or record.Stage~=definition.Stage or record.EvolutionVersion~=Config.Version then return false end
	for _,key in {"Growth","GrowthReserve","TotalGrowth","Flesh","Flora","Mineral","Revision"} do
		if not number(record[key]) then return false end
	end
	return record.Growth+record.GrowthReserve<=Config.MaxNumber
		and record.TotalGrowth>=record.Growth+record.GrowthReserve and record.Revision%1==0
		and type(record.EvolutionHistory)=="table" and type(record.EvolutionFamilies)=="table"
		and type(record.LineageTags)=="table" and type(record.Mutations)=="table"
		and type(record.PetId)=="string" and #record.PetId>0
end
function Calculator.boundGrowth(record)
	assert(Calculator.valid(record),"Invalid evolution state")
	local available=record.Growth+record.GrowthReserve
	local cap=Definitions.get(Calculator.form(record)).GrowthRequired
	record.Growth=math.min(available,cap)
	record.GrowthReserve=available-record.Growth -- no discarded earned progress
end
function Calculator.eligible(record, branch)
	if not Calculator.valid(record) then return false,"Invalid pet evolution state" end
	if branch.Source~=Calculator.form(record) or branch.SourceStage~=record.Stage or branch.TargetStage~=record.Stage+1 then return false,"Wrong source or stage" end
	if branch.Locked or branch.TargetStage==5 then return false,"Stage 5 awaits Phase 4D eligibility" end
	if branch.Probability and branch.Probability~=1 then return false,"Probability metadata is disabled pending approved policy" end
	if record.Growth+record.GrowthReserve<branch.Growth then return false,"More Growth required" end
	if branch.RequiredLineage and record.Lineage~=branch.RequiredLineage then return false,"Wrong lineage" end
	for _,tag in branch.RequiredTags or {} do if not record.LineageTags[tag] then return false,"Missing lineage trait" end end
	for _,tag in branch.RequiredLatentTraits or {} do if not (record.LatentTraits or {})[tag] then return false,"Missing latent trait" end end
	for _,tag in branch.RequiredSpecialEvolutions or {} do if not (record.SpecialEvolutions or {})[tag] then return false,"Special evolution not enabled" end end
	for _,mutation in branch.RequiredMutations or {} do if not table.find(record.Mutations,mutation) then return false,"Missing special trait" end end
	if branch.MinRarity then
		local rarity,minimum=Rarities.get(record.Rarity),Rarities.get(branch.MinRarity)
		if not rarity or not minimum or rarity.Priority<minimum.Priority then return false,"Rarity requirement" end
	end
	if branch.Family and not record.EvolutionFamilies[branch.Family] then return false,"Missing catalyst family" end
	for key,value in branch.Requirements do if record[key]<value then return false,"Affinity requirement" end end
	if branch.Dominant then
		for key in affinities do if record[key]>record[branch.Dominant] then return false,"Dominant affinity requirement" end end
	end
	return true
end
function Calculator.candidates(record)
	local eligible,fallback={},{}
	local definition=Definitions.get(Calculator.form(record))
	if not definition then return eligible end
	for _,branch in definition.Evolutions do
		if Calculator.eligible(record,branch) then table.insert(if branch.Fallback then fallback else eligible,branch) end
	end
	if #eligible==0 then eligible=fallback end
	table.sort(eligible,function(a,b) return a.Id<b.Id end)
	return eligible
end
local function advance(record, branch)
	assert(Calculator.eligible(record,branch))
	local previous=Calculator.form(record)
	record.Growth=record.Growth+record.GrowthReserve-branch.Growth
	record.GrowthReserve=0
	record.EvolutionForm,record.Stage=branch.Result,branch.TargetStage
	record.LineageTags[previous]=true
	record.LineageTags[branch.Result]=true
	table.insert(record.EvolutionHistory,{Id=branch.Id,From=previous,To=branch.Result,Stage=record.Stage,Revision=record.Revision})
	-- Only five ordinary transitions, not an unbounded per-feed history log.
	record.PendingEvolution=nil
	Calculator.boundGrowth(record)
end
function Calculator.afterFeed(record, forcedBranchId)
	assert(not record.PendingEvolution,"Resolve the existing evolution choice first")
	Calculator.boundGrowth(record)
	local candidates=Calculator.candidates(record)
	if forcedBranchId then
		for _,branch in candidates do
			if branch.Id==forcedBranchId then advance(record,branch) return true,"Configured eligible evolution: "..branch.Result end
		end
		error("Configured forced branch is not eligible")
	end
	if #candidates==1 and Config.AutoAdvanceUnique then
		advance(record,candidates[1])
		return true,"Evolves into " .. Definitions.get(candidates[1].Result).DisplayName .. ". Overflow is retained."
	elseif #candidates>0 then
		local ids={} for _,branch in candidates do table.insert(ids,branch.Id) end
		record.PendingEvolution={Token=tostring(record.Revision)..":"..Calculator.form(record),Revision=record.Revision,
			Source=Calculator.form(record),Stage=record.Stage,Candidates=ids}
		return false,"Evolution choice ready. Choose at your pet; no additional item is consumed."
	end
	return false,if record.Stage>=4 then "Mythic Ascension is locked. Growth is retained." else ""
end
function Calculator.select(record, token, branchId)
	if not Calculator.valid(record) then return false,"Invalid pet evolution state" end
	local pending=record.PendingEvolution
	if type(pending)~="table" or pending.Token~=token or pending.Source~=Calculator.form(record)
		or pending.Stage~=record.Stage or pending.Revision~=record.Revision or type(pending.Candidates)~="table"
		or not table.find(pending.Candidates,branchId) then return false,"Stale or invalid evolution choice" end
	for _,branch in Calculator.candidates(record) do
		if branch.Id==branchId then
			if record.Revision>=Config.MaxNumber then return false,"Revision exhausted" end
			record.Revision+=1
			advance(record,branch)
			return true,"Evolved into "..Definitions.get(branch.Result).DisplayName
		end
	end
	return false,"Choice is no longer eligible"
end

-- Legacy pure query adapter: uses the same graph, never a second first-match engine.
function Calculator.resolve(definition,growth,values,catalystId,families)
	local record={Species=definition.Id,EvolutionForm=definition.Id,Stage=definition.Stage,EvolutionVersion=Config.Version,
		PetId="query",Growth=growth,GrowthReserve=0,TotalGrowth=growth,Revision=0,Flesh=values.Flesh,Flora=values.Flora,Mineral=values.Mineral,
		Lineage="ProtoRex",LineageTags={},EvolutionHistory={},Mutations={},EvolutionFamilies=table.clone(families or {}),Rarity=definition.Rarity}
	for _,edge in definition.Evolutions do if catalystId and edge.Catalyst==catalystId and edge.Family then record.EvolutionFamilies[edge.Family]=true end end
	local candidates=Calculator.candidates(record)
	return if #candidates==1 then candidates[1].Result else nil
end

function Calculator.validate()
	local errors,ids={},{}
	local all=Definitions.getAll()
	local function check(ok,message) if not ok then table.insert(errors,message) end end
	local families={}
	for _,effect in require(script.Parent.SpecialEffectDefinitions) do if effect.Family then families[effect.Family]=true end end
	local latent,special={},{}
	for _,behavior in require(script.Parent.CatalystDefinitions).getBehaviors() do
		for _,effect in behavior.Effects do
			if effect.Kind=="AddLatentTrait" then latent[effect.Id]=true end
			if effect.Kind=="EnableSpecialEvolution" then special[effect.Id]=true end
		end
	end
	for id,definition in all do
		check(Config.Stages[definition.Stage]~=nil,"Missing stage: "..id)
		check(type(definition.Visual)=="table" and definition.Visual.ModelKey=="Placeholder" and number(definition.Visual.Scale) and definition.Visual.Scale>0,"Invalid placeholder: "..id)
		for _,branch in definition.Evolutions do
			check(type(branch.Id)=="string" and not ids[branch.Id],"Duplicate/missing branch ID: "..id)
			if branch.Id then ids[branch.Id]=true end
			local target=all[branch.Result]
			check(target and branch.Source==id and branch.SourceStage==definition.Stage and branch.TargetStage==target.Stage and branch.TargetStage==branch.SourceStage+1,"Invalid reference/stage skip/cycle: "..id)
			check(number(branch.Growth) and branch.Growth>0,"Invalid Growth: "..id)
			check(not branch.Dominant or affinities[branch.Dominant],"Unknown dominant affinity: "..id)
			check(not branch.Family or families[branch.Family],"Unknown catalyst family: "..id)
			check(not branch.RequiredLineage or branch.RequiredLineage==definition.Lineage,"Unreachable lineage: "..id)
			check(not branch.MinRarity or Rarities.isValid(branch.MinRarity),"Unknown rarity: "..id)
			check(branch.Probability==nil or (number(branch.Probability) and branch.Probability<=1),"Invalid probability: "..id)
			for key,value in branch.Requirements do check(affinities[key] and number(value),"Invalid affinity minimum: "..id) end
			for _,tag in branch.RequiredTags or {} do check(all[tag] and all[tag].Stage<=definition.Stage,"Unreachable required lineage tag: "..id) end
			for _,tag in branch.RequiredLatentTraits or {} do check(latent[tag],"Unknown latent trait: "..id) end
			for _,tag in branch.RequiredSpecialEvolutions or {} do check(special[tag],"Unknown special evolution: "..id) end
		end
	end
	-- Structural reachability includes locked future edges; monotone stages prove acyclicity.
	local reachable={ProtoRex=true}
	for _=1,6 do
		for id,definition in all do
			if reachable[id] then for _,edge in definition.Evolutions do if all[edge.Result] then reachable[edge.Result]=true end end end
		end
	end
	for id in all do check(reachable[id],"Unreachable form: "..id) end
	-- Every required prior form must actually be an ancestor, not merely an earlier stage.
	local function reaches(from,target,visited)
		if from==target then return true end
		if visited[from] or not all[from] then return false end
		visited[from]=true
		for _,edge in all[from].Evolutions do if reaches(edge.Result,target,visited) then return true end end
		return false
	end
	for id,definition in all do
		for _,branch in definition.Evolutions do
			for _,tag in branch.RequiredTags or {} do check(reaches(tag,id,{}),"Required lineage is not an ancestor: "..id) end
			if branch.Dominant then
				check((branch.Requirements[branch.Dominant] or 0)>0,"Dominant branch requires an explicit positive minimum: "..id)
			end
			check(branch.Fallback==nil or type(branch.Fallback)=="boolean","Invalid fallback policy: "..id)
			check(branch.Locked==nil or type(branch.Locked)=="boolean","Invalid branch lock: "..id)
			check(branch.TargetStage~=5 or branch.Locked==true,"Stage 5 must remain locked: "..id)
		end
	end
	-- Joint requirements must occur on ONE path, not two mutually exclusive ancestors.
	local paths={}
	local function visit(id,path,depth)
		if depth>6 or not all[id] or path[id] then return end
		local nextPath=table.clone(path) nextPath[id]=true
		paths[id]=paths[id] or {} table.insert(paths[id],nextPath)
		for _,edge in all[id].Evolutions do visit(edge.Result,nextPath,depth+1) end
	end
	visit("ProtoRex",{},0)
	for id,definition in all do
		for _,edge in definition.Evolutions do
			if edge.RequiredTags then
				local possible=false
				for _,path in paths[id] or {} do
					local met=true for _,tag in edge.RequiredTags do if not path[tag] then met=false end end
					if met then possible=true break end
				end
				check(possible,"Mutually exclusive required lineage tags: "..id)
			end
		end
	end
	for stage=0,5 do
		local row=Config.Stages[stage]
		check(row and type(row.Label)=="string" and number(row.GrowthRequired) and row.GrowthRequired>0,"Invalid growth stage "..stage)
	end
	return errors
end
return Calculator
