--!strict
local Presentation = require(script.Parent.GuardianPresentation)
local CursePresentation = require(script.Parent.CarryCursePresentation)
Presentation.Start()
CursePresentation.Start()
script.Destroying:Connect(function()
	Presentation.Stop()
	CursePresentation.Stop()
end)
