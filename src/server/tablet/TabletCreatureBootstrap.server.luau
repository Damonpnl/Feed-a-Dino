--!strict

local CreaturePresentationTemplateService = require(script.Parent:WaitForChild("CreaturePresentationTemplateService"))
local TabletCreatureSnapshotService = require(script.Parent:WaitForChild("TabletCreatureSnapshotService"))

CreaturePresentationTemplateService.start()
TabletCreatureSnapshotService.start()
