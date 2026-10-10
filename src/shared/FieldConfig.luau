--!strict
return {
	FIELD_CYCLE_SECONDS = 300,
	RESET_WINDOW_SECONDS = 10,
	NODES_PER_AREA = 5,
	DROPPED_DESPAWN_SECONDS = 20,
	RespawnSeconds = { Common = 18, Uncommon = 18, Rare = 18, Epic = 25, Legendary = 25, Mythic = 40, Cosmic = 40 },
	-- Audio assets can be assigned here without changing spawn logic.
	RarePresentation = {
		Secret = {Distance = 300, Aura = 0.6, BeamHeight = 0, Burst = 0, SoundId = "", SoundVolume = 0.5, Label = "RARE FIND"},
		Eternal = {Distance = 450, Aura = 0.85, BeamHeight = 120, Burst = 0, SoundId = "", SoundVolume = 0.7, Label = "ETERNAL ARRIVAL"},
		Divine = {Distance = 600, Aura = 1, BeamHeight = 180, Burst = 24, SoundId = "", SoundVolume = 1, Label = "DIVINE ARRIVAL"},
	},
}
