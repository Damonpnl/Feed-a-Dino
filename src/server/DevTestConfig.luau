--!strict
-- Explicit developer authorization. Both this flag and RunService:IsStudio() must be true.
-- Published servers never create the developer remote, even if Enabled stays true.
-- RunnerUserIds is an array of UserIds. Empty means every player in this Studio server.
return table.freeze({
	Enabled = true,
	RunnerUserIds = {},
})
