--!nonstrict
-- No new live balance: promotions and prestige await explicit approval.
local Rarities=require(script.Parent.RarityDefinitions)
return {
	RarityCeiling=Rarities.Order[#Rarities.Order],
	RarityRules={
		Keep={Enabled=true,Tiers=0},
		PromoteOne={Enabled=false,Tiers=1}, -- Chance intentionally unspecified
	},
	Ascensions={
		ProtoRexMythic={Id="ProtoRexMythic",Enabled=false,RequirementsApproved=false,
			SourceForm="AscendedRex",TargetForm="MythicRex",SourceStage=4,TargetStage=5,
			RequiredLineage="ProtoRex",Affinities={},RequiredFamilies={},RequiredTraits={},RequiredQualifications={}},
	},
	Awakenings={
		ProtoRexAwakening={Id="ProtoRexAwakening",Enabled=false,RequirementsApproved=false,
			SourceForm="MythicRex",RequiredLineage="ProtoRex",RequiredAscension="ProtoRexMythic",
			Form="AwakenedRexPlaceholder",Family="ProtoRex",Affinities={},RequiredFamilies={},
			RequiredTraits={},RequiredQualifications={},Catalysts={},Guaranteed=false,
			Presentation={ModelKey="Placeholder",DisplayName="Awakened Rex (unreleased)"}},
	},
	-- Technical saturation bounds, not approved economy caps. Empty modifier maps
	-- mean x1. Existing form multipliers and the legacy species floor are retained.
	Multipliers={Min=1,Max=9007199254740991,Rarity={},Stage={},Mutation={},Awakening={}},
}
