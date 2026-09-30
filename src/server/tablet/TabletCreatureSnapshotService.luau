--!strict

--[[
	Builds defensive, presentation-safe creature snapshots for the Lineage app.
	Does not expose rarity odds, secret catalyst routes, or specialized variant names before discovery.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LineagePresentation = require(Shared:WaitForChild("tablet"):WaitForChild("LineagePresentation"))
local StageConfig = require(Shared:WaitForChild("creatures"):WaitForChild("StageConfig"))
local EvolutionCalculator = require(Shared:WaitForChild("creatures"):WaitForChild("EvolutionCalculator"))

local CreatureState = require(script.Parent.Parent.creatures:WaitForChild("CreatureState"))
local PlayerBaseSessions = require(script.Parent.Parent.creatures:WaitForChild("PlayerBaseSessions"))
local TabletCreatureRemotes = require(script.Parent:WaitForChild("TabletCreatureRemotes"))

local TabletCreatureSnapshotService = {}

local started = false

local function copyTotals(totals: { [string]: number }): { [string]: number }
	local result = {}
	for key, value in totals do
		result[key] = value
	end
	return result
end

local function specializedStatusLabel(influenceLabel: string, qualifies: boolean): string
	if qualifies then
		-- Ready, but do not reveal the exact variant name.
		return "ReadyHidden"
	end
	if influenceLabel == "Developing" then
		return "Developing"
	end
	if influenceLabel == "Trace" then
		return "Undiscovered"
	end
	return "None"
end

local function resolveStatusReason(snapshot: CreatureState.CreatureSnapshot): string
	if not StageConfig.isSupportedEvolutionStage(snapshot.stage) then
		return "UnsupportedStage"
	end
	if snapshot.evolutionReady then
		return "EvolutionReady"
	end
	if not EvolutionCalculator.hasSufficientGrowthForStage(snapshot.stage, snapshot.growthProgress) then
		return "InsufficientGrowth"
	end
	if not EvolutionCalculator.hasSufficientAffinityForStage(
		snapshot.stage,
		snapshot.stageAffinities,
		snapshot.heritageAffinities
	) then
		return "InsufficientAffinity"
	end
	local predictedReason = snapshot.predictedEvolution and snapshot.predictedEvolution.reason
	return predictedReason or "NotReady"
end

function TabletCreatureSnapshotService.buildEmpty(): any
	return {
		hasCreature = false,
	}
end

function TabletCreatureSnapshotService.buildForState(state: CreatureState.CreatureState): any
	local snapshot = CreatureState.getSnapshot(state)
	local isTerminal = LineagePresentation.isTerminalStage(snapshot.stage)
	local requiredGrowth = if isTerminal then nil else snapshot.requiredGrowth
	local statusReason = resolveStatusReason(snapshot)
	local assessment = EvolutionCalculator.assessStageInfluences(snapshot.stageInfluences)
	local publicRoutes = LineagePresentation.getPublicRoutesForForm(snapshot.formId, snapshot.stage)

	local history = {}
	for _, entry in snapshot.lineageHistory do
		table.insert(history, {
			stage = entry.stage,
			formId = entry.formId,
			displayName = LineagePresentation.getCreatureDisplayName(entry.formId),
			routeAffinity = entry.routeAffinity,
			specializedInfluence = entry.specializedInfluence,
			rarityAtStage = entry.rarityAtStage,
		})
	end

	return {
		hasCreature = true,
		creatureId = snapshot.creatureId,
		formId = snapshot.formId,
		displayName = LineagePresentation.getCreatureDisplayName(snapshot.formId),
		stage = snapshot.stage,
		rarity = snapshot.rarity,
		growth = snapshot.growthProgress,
		requiredGrowth = requiredGrowth,
		isTerminalStage = isTerminal,
		stageAffinities = copyTotals(snapshot.stageAffinities),
		heritageAffinities = copyTotals(snapshot.heritageAffinities),
		dominantAffinity = snapshot.dominantEffectiveAffinity,
		stageInfluences = copyTotals(snapshot.stageInfluences),
		strongestInfluence = snapshot.strongestInfluenceId,
		influenceQualification = snapshot.influenceStrengthLabel,
		evolutionQuality = snapshot.stageEvolutionQuality,
		lineageHistory = history,
		evolutionStatus = {
			canEvolve = snapshot.evolutionReady == true,
			reason = statusReason,
		},
		nextEvolution = {
			isTerminal = isTerminal,
			publicRoutes = publicRoutes,
			specializedStatus = specializedStatusLabel(
				snapshot.influenceStrengthLabel,
				assessment.qualifies == true
			),
		},
	}
end

function TabletCreatureSnapshotService.buildForPlayer(player: Player): any
	local session = PlayerBaseSessions.getForPlayer(player)
	if session == nil or session.creature == nil then
		return TabletCreatureSnapshotService.buildEmpty()
	end
	local creature = session.creature
	if typeof(creature.ownerUserId) == "number" and creature.ownerUserId ~= player.UserId then
		warn(string.format(
			"[TabletCreatureSnapshotService] Ownership mismatch player=%s owner=%s",
			player.Name,
			tostring(creature.ownerUserId)
		))
		return TabletCreatureSnapshotService.buildEmpty()
	end
	return TabletCreatureSnapshotService.buildForState(creature)
end

function TabletCreatureSnapshotService.pushForPlayer(player: Player)
	local payload = TabletCreatureSnapshotService.buildForPlayer(player)
	TabletCreatureRemotes.fire(player, "CreatureSnapshotUpdated", payload)
end

function TabletCreatureSnapshotService.start()
	if started then
		return
	end
	started = true
	TabletCreatureRemotes.ensure()

	TabletCreatureRemotes.get("RequestCreatureSnapshot").OnServerEvent:Connect(function(player: Player)
		-- No client-supplied player/base/creature IDs accepted.
		TabletCreatureSnapshotService.pushForPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(_player)
		-- No persistent tablet creature cache yet.
	end)

	print("[TabletCreatureSnapshotService] Lineage snapshot channel ready")
end

return TabletCreatureSnapshotService
