--!strict

--[[
	Shared type contracts for the Savannah expedition vertical slice.
	No Roblox service access.
]]

local ExpeditionTypes = {}

export type ZoneId = "Savannah"
export type NodeTypeId = "InsectNest" | "AncientBush" | "CrystalOutcrop" | "CrystalEruptionNode"
export type EnemyTypeId = "TerritorialRaptor"
export type QuestId = "SavannahBugCollector" | "SavannahCrystalSurvey" | "SavannahWateringHole"
export type EventId = "CrystalEruption"
export type NodeState = "Available" | "GatherPending" | "Depleted" | "Respawning"
export type EnemyState = "Idle" | "Wander" | "Alert" | "Chase" | "Attack" | "Return"
export type QuestStatus = "Inactive" | "Active" | "Completed" | "CompletedUnclaimed"

export type RewardEntry = {
	feedId: string,
	amount: number,
	weight: number?,
}

export type ResourceNodeDefinition = {
	nodeTypeId: NodeTypeId,
	templateName: string,
	regionFolderName: string,
	activeCount: number,
	charges: number,
	respawnMinSeconds: number,
	respawnMaxSeconds: number,
	promptActionText: string,
	promptObjectText: string,
	holdDuration: number,
	guaranteedRewards: { RewardEntry }?,
	weightedRewards: { RewardEntry }?,
}

export type QuestDefinition = {
	questId: QuestId,
	displayName: string,
	objectiveText: string,
	targetAmount: number,
	coinReward: number,
	rewards: { RewardEntry },
}

export type EventDefinition = {
	eventId: EventId,
	displayName: string,
	announcementBody: string,
	initialDelaySeconds: number,
	intervalSeconds: number,
	durationSeconds: number,
	minNodes: number,
	maxNodes: number,
	charges: number,
	livingCrystalBonusChance: number,
}

export type FieldBagState = {
	zoneId: ZoneId?,
	materials: { [string]: number },
	totalItems: number,
	isBanking: boolean,
}

export type PlacementSample = {
	position: Vector3,
	normal: Vector3,
}

export type RegionInfo = {
	part: BasePart,
	fullPath: string,
	area: number,
	depthTier: number?,
	eventEligible: boolean?,
	regionWeight: number?,
}

return ExpeditionTypes
