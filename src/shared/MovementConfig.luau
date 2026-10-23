--!strict
-- PROVISIONAL_BALANCE: evaluate traversal separately from carrying risk.
local milestones = {
	{Power=0, Speed=22, CarrySpeed=22}, {Power=1000, Speed=26, CarrySpeed=24}, {Power=10000, Speed=30, CarrySpeed=27},
	{Power=100000, Speed=36, CarrySpeed=30}, {Power=1000000, Speed=44, CarrySpeed=35},
	{Power=10000000, Speed=54, CarrySpeed=41}, {Power=100000000, Speed=64, CarrySpeed=47}, {Power=150000000, Speed=72, CarrySpeed=52},
}
for _, row in milestones do table.freeze(row) end
return table.freeze({
	Status="PROVISIONAL_BALANCE",
	Milestones=table.freeze(milestones),
	PrecisionSpeed=16,
	-- Separate bounded carry curve BEFORE unchanged resource/curse penalties.
	MaxSpeed=72,
	RequestInterval=0.2,
})
