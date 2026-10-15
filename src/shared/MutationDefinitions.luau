--!nonstrict
-- Overlays and permanent evolution families are intentionally disjoint.
local Definitions = {}
local all = {}
for _, id in {"Silver","Golden","Rainbow"} do
	all[id]={Id=id,Kind="Overlay",Group="Finish",Enabled=true,AcquisitionEnabled=false}
end
all.Mutant={Id="Mutant",Kind="Overlay",Group="Biological",Enabled=true,AcquisitionEnabled=true}
-- Parasite is a reserved overlay. The named catalyst families (including future
-- examples) are forms, never automatically granted as a second mutation mechanic.
all.Parasite={Id="Parasite",Kind="Overlay",Group="Special",Enabled=false,AcquisitionEnabled=false}
for _, id in {"Titan","Void","Cyber","Spirit","BloodMoon","Celestial","Fire","Crystal","Draconic","Toxic","Primal"} do
	all[id]={Id=id,Kind="EvolutionFamily",Enabled=false,AcquisitionEnabled=false}
end
function Definitions.get(id) return all[id] end
function Definitions.getAll() return all end
function Definitions.canApply(record,id)
	local d=all[id]
	if not d or d.Kind~="Overlay" or not d.Enabled then return false,"Mutation overlay is not enabled" end
	if type(record.Mutations)~="table" then return false,"Invalid mutation state" end
	for _, existing in record.Mutations do
		if existing==id then return false,"Mutation already present" end
		local other=all[existing]
		-- Unknown saved mutations are preserved, but fail closed for new stacking.
		if not other or other.Kind~="Overlay" or other.Group==d.Group then return false,"Incompatible mutation stack" end
	end
	return true
end
function Definitions.apply(record,id)
	local ok,reason=Definitions.canApply(record,id)
	if not ok then return false,reason end
	table.insert(record.Mutations,id)
	return true
end
return Definitions
