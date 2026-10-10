--!strict
return {
	Tag = "WorldBillboard",
	AttributePrefix = "Billboard",
	DistanceInterval = 0.12,
	BoundsInterval = 0.5,
	AnimationInterval = 1 / 30,
	MaxVisible = 60,
	MaxAnimated = 16,
	EnterDuration = 0.22,
	ExitDuration = 0.16,
	Hysteresis = 5,
	Width = 240,
	Height = 94,
	MinScale = 0.72,
	DefaultOffset = Vector3.new(0, 0.8, 0), -- Added above the object's world-space top.
	AlwaysOnTop = false, -- Respect walls; do not reveal loot through the map.
	ObjectTypes = {
		Feed = { Near = 70, Far = 110 },
		Catalyst = { Near = 75, Far = 120 },
		Monster = { Near = 85, Far = 145 },
		Guardian = { Near = 95, Far = 170 },
		WorldDrop = { Near = 95, Far = 165 },
		Event = { Near = 120, Far = 220 },
	},
}
