--!strict
local Presentation = require(script.Parent.FieldPresentation)
Presentation:Start()
script.Destroying:Connect(function() Presentation:Stop() end)
