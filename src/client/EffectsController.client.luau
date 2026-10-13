--!strict
local Presentation = require(script.Parent.GuardianPresentation)
Presentation.Start()
script.Destroying:Connect(Presentation.Stop)
