--!strict

local ResourceTypes = {}

export type AffinityId = "Flesh" | "Floral" | "Mineral" | "Neutral" | "Flesh + Mineral" | "Flesh + Floral"
export type ResourceKind = "Feed" | "Catalyst"

export type ResourceDefinition = {
	Id: string,
	DisplayName: string,
	ResourceType: ResourceKind,
	Area: string,
	Rarity: string,
	PowerRequired: number,
	Growth: number,
	Affinity: AffinityId,
	Affinities: { [string]: number },
	SpawnWeight: number,
	CarrySlowdown: number,
	SpecialEffect: string,
	ModelKey: string,
	BillboardOffset: Vector3,
	Launch: boolean,
}

return ResourceTypes
