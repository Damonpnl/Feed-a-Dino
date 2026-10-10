# Feed a Pet world tags

World labels use one client renderer. The server publishes attributes and the
`WorldBillboard` CollectionService tag; it never creates the BillboardGui.
Spawning, carrying, pet displays, and guardian states now use this path. The old
inline UI builders in those services were removed. Shop NPC signs are separate
scene content and remain intact. Previously deleted legacy material/creature
label services are not restored.

## Server API

```lua
local BillboardService = require(game.ServerScriptService.Server.BillboardMetadataService)

BillboardService:Create(model, {
    DisplayName = "Giant Serum",
    Rarity = "Mythic",
    ValueText = "+250 Growth",
    Modifier = "Titan",
    ObjectType = "Catalyst",
    Offset = Vector3.new(0, 0.8, 0),
})
BillboardService:Update(model, { ValueText = "+300 Growth" })
BillboardService:Hide(model)
BillboardService:Show(model)
BillboardService:Destroy(model) -- removes tag metadata, not the world model
```

Models and BaseParts are supported. `Offset` is added **above the world-space
top**, not measured from the model pivot. Models need not have a PrimaryPart;
late-arriving streamed geometry is retried. `Create` is idempotent; `Update`
merges only supplied fields. Use `Modifier = ""` to clear a badge. Multiple
comma-separated modifiers are accepted; the highest configured priority wins.
Modifiers never replace the rarity palette.

`BillboardData.resource(definition)` adapts the centralized feeds and catalysts. Growth
or special effect is shown on their value line; the pickup prompt retains the Power requirement.
Carried items retain their label. Pets show their actual cash rate (income per
two-second tick divided by two) and training multiplier. Guardians show state.
No gameplay rewards, rarity odds, or save data are changed by the renderer.

## Client API and hooks

`BillboardController` starts `BillboardService` automatically. LocalScripts can
require `Players.LocalPlayer.PlayerScripts.Client.BillboardService` and use the
same `Create`, `Update`, `Show`, `Hide`, and `Destroy` methods for local effects.
Keep client-only targets untagged so replicated metadata does not overwrite
their local options. Direct `Create` registers immediately but builds the GUI
lazily when visible; do not depend on its return value.

```lua
local tags = require(game.Players.LocalPlayer.PlayerScripts.Client.BillboardService)
local connection = tags.Appeared:Connect(function(target, options)
    -- Optional local sound/particle effect; rate-limit expensive effects here.
end)
-- Disconnect the subscription when its owning controller stops.
connection:Disconnect()
```

`Appeared` and `Disappeared` fire on visibility transitions, including distance
changes; they are not limited to the first world spawn. `Stop()` disconnects
watchers and the manager, destroys its UI and exit anchors, and supports a later
`Start()`. `GetStats()` exposes tracked, visible, animated, retiring, and watcher
counts. Call it from a normal game LocalScript; MCP execution can use a separate
ModuleScript cache from the running game.

## Configuration

- `Shared/RarityDefinitions`: exactly Common, Uncommon, Rare, Epic, Legendary,
  Mythic, Cosmic, Secret, Eternal, Divine; order is independent of spawn weights.
- `Shared/RarityStyles`: all ten tiers; name/value colors and optional
  gradients, outlines, glow, shine, spark count, optional image icon, speed,
  intensity, and priority. Common is static. Only higher rarities get sparks.
- `Shared/ModifierStyles`: badge text/color/priority, including the existing
  `Mutant` mutation alias. One visible badge prevents effect stacking.
- `Shared/BillboardConfig`: sizes, timings, update rates, budgets and presets.
  Feed is full-detail through 70 studs and reduced-detail through 110; Catalyst,
  Monster, Guardian, WorldDrop and Event have their own ranges. Override with
  `NearDistance` and `FarDistance` in the options.

Fixed pixel dimensions and a 0.72–1.0 distance scale prevent far-away growth.
An empty modifier hides the badge instead of substituting a rarity word.
Secret/Eternal/Divine resource distances extend to 300/450/600 studs, still
subject to visibility budgets and occlusion. See `FieldConfig.RarePresentation`.
Text uses FredokaOne, dark strokes and bounded TextScaled sizes. Tags anchor
above the object's top, respect occlusion, and follow their adornee between
geometry updates. Change `AlwaysOnTop` only if seeing tags through walls is
intentional.

One Heartbeat drives the manager. Visibility checks run about eight times per
second, model bounds refresh twice per second, and animation runs at 30 Hz.
At most 60 tags are selected and 16 receive ongoing rarity animation. Priority
then distance determines selection. Medium-distance labels keep name and value
but hide badges/glow/sparks. Hidden/offscreen tags stop animating and their GUI
is disabled after the exit fade. A five-stud exit margin limits boundary flicker.
Visible exits may briefly coexist with newly selected labels during their fade.

Enter takes 220 ms (0.85 → 1.03 → 1 scale). Exit takes 160 ms. When a target is
destroyed, untagged, or streamed out, a temporary client Attachment holds its
last label position until fade completion, then both UI and anchor are removed.

## Verification

Build with `rojo build default.project.json -o <temporary-path>.rbxlx`.
`tests/BillboardSmoke.client.luau` is an opt-in Studio play-mode LocalScript,
outside the Rojo production tree. Put its source in a temporary LocalScript
under PlayerScripts to exercise visual tiers, metadata discovery/updates,
modifier precedence, near/medium/far/behind-camera transitions, fades,
destruction and streaming cleanup, burst budgets, and Stop/Start cleanup.
It reports `Result` and `PassedAssertions` attributes and prints its result.
On success it reports 85 passing assertions and leaves a ten-rarity showcase;
set its `Cleanup` attribute to
true to restore the camera and remove fixtures. Stop play after testing.
