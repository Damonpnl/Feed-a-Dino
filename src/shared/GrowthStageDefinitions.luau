--!strict
-- PROVISIONAL_BALANCE: first evolution 25 (about 3-5 Grasslands trips), then 80/160;
-- 3000 is the spec's illustrative Apex threshold. Stage 4/5 use a storage cap, NOT
-- ascension eligibility. AffinityRequired is the dominant-affinity minimum for the
-- stage's branches and must not exceed its GrowthRequired.
return {
	Version = 1,
	AutoAdvanceUnique = true,
	MaxNumber = 9007199254740991,
	FormOverrides = {SpiritDragon=200}, -- retained prototype exception
	Stages = {
		[0] = {Label="Starter", GrowthRequired=25, AffinityRequired=20, Scale=1},
		[1] = {Label="Juvenile", GrowthRequired=80, Scale=1.2},
		[2] = {Label="Mature", GrowthRequired=160, Scale=1.4},
		[3] = {Label="Apex", GrowthRequired=3000, Scale=1.6},
		[4] = {Label="Ascended", GrowthRequired=3000, Scale=1.8, Locked=true},
		[5] = {Label="Mythic Ascension", GrowthRequired=3000, Scale=2, Locked=true},
	},
}
