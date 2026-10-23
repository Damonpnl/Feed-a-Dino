--!strict
-- Phase 5A PROVISIONAL_BALANCE. No offline income or live boost acquisition.
return table.freeze({
	BaseCashPerSecond = 0.5, -- Retains the prototype starter's 1 Cash / 2 seconds.
	BaseTrainingGain = 5, -- Retained prototype base; trainer now multiplies it.
	TemporaryBoost = 1,
	TickSeconds = 1,
	MaxFrameCredit = 0.25, -- Long stalls never award an unvalidated catch-up burst.
	InteractionDistance = 12,
	MaxNumber = 9007199254740991,
	MaxRate = 1000000000000, -- Technical arithmetic bound, not a new resource gate.
})
