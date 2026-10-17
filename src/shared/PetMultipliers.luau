--!nonstrict
local Definitions=require(script.Parent.MonsterDefinitions)
local Config=require(script.Parent.PetProgressionConfig)
local Multipliers={}
function Multipliers.resolve(record,settings)
	settings=settings or Config.Multipliers
	assert(type(settings.Min)=="number" and settings.Min>0 and settings.Min<=settings.Max
		and settings.Max<=9007199254740991,"Invalid multiplier bounds")
	local form=Definitions.get(record.EvolutionForm or record.Species)
	if not form then return {IncomeMultiplier=1,TrainingMultiplier=1} end -- retained unknown-form fallback
	local original=Definitions.get(record.Species)
	local output={}
	for _,channel in {"Income","Training"} do
		local field=channel.."Multiplier"
		local value=math.max(if form then form[field] else 1,if original then original[field] else 1)
		assert(value>0 and value<math.huge,"Invalid form multiplier")
		local function apply(row)
			local factor=if row then row[channel] or 1 else 1
			assert(type(factor)=="number" and factor>0 and factor<math.huge,"Invalid pet multiplier")
			value*=factor -- bound the total, not each intermediate factor
		end
		apply(settings.Rarity[record.Rarity]) apply(settings.Stage[record.Stage])
		local seen={}
		for _,id in record.Mutations or {} do if not seen[id] then seen[id]=true apply(settings.Mutation[id]) end end
		if record.Awakened==true and type(record.Awakening)=="table" then apply(settings.Awakening[record.Awakening.Id]) end
		output[field]=math.clamp(value,settings.Min,settings.Max)
	end
	return output
end
function Multipliers.validate()
	local errors={}
	for _,definition in Definitions.getAll() do
		local ok=pcall(Multipliers.resolve,{Species=definition.Id,EvolutionForm=definition.Id,Rarity="Common",Stage=definition.Stage})
		if not ok then table.insert(errors,"Invalid pet multiplier: "..definition.Id) end
	end
	for kind,map in {Rarity=Config.Multipliers.Rarity,Stage=Config.Multipliers.Stage,Mutation=Config.Multipliers.Mutation,Awakening=Config.Multipliers.Awakening} do
		for id,row in map do
			local known=if kind=="Rarity" then require(script.Parent.RarityDefinitions).isValid(id)
				elseif kind=="Stage" then require(script.Parent.GrowthStageDefinitions).Stages[id]~=nil
				elseif kind=="Mutation" then require(script.Parent.MutationDefinitions).get(id)~=nil
				else Config.Awakenings[id]~=nil
			if not known then table.insert(errors,"Unknown multiplier reference: "..tostring(id)) end
			for channel,value in row do
				if (channel~="Income" and channel~="Training") or type(value)~="number" or value~=value or value<=0 or value>=math.huge then
					table.insert(errors,"Invalid multiplier modifier")
				end
			end
		end
	end
	return errors
end
return Multipliers
