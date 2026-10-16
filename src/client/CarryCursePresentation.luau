--!nonstrict
-- Client presentation of the server-assigned carry curse. Reads only the replicated
-- CarryCurse / CarryCurseStart attributes; assignment, timing seeds, and speed are server-owned.
-- Input effects scale the PlayerModule MoveAction bindings (keyboard, gamepad thumbstick, and
-- touch thumbsticks share that one action), so chat, menus, and CoreScripts are never touched.
-- Click-to-move is left unscaled. Older PlayerModules without MoveAction fall back to
-- post-processing ControlModule:GetMoveVector().
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CarryDebuff = require(game.ReplicatedStorage.Shared.CarryDebuff)

local Curse = {}
local INPUT_STEP = "CarryCurseInput"
local CAMERA_STEP = "CarryCurseCamera"
local SWAY_DEGREES = 3

local player = Players.LocalPlayer
local connections = {}
local gui, banner, vignette = nil, nil, nil
local assignment, startTime = nil, 0
local controls = nil
local smoothed = Vector3.zero
local bound = false
local nextText = 0
local moveAction = nil
local scaled: { [Instance]: Vector2 } = {}
local appliedScale = 1
local charge = 0

local function elapsed(): number
	return workspace:GetServerTimeNow() - startTime
end

local function effectOf(kind: string)
	if not assignment then return nil end
	for _, effect in assignment.Effects do
		if CarryDebuff.Catalog[effect.Id] and CarryDebuff.Catalog[effect.Id].Kind == kind then return effect end
	end
	return nil
end

local function reducedMotion(): boolean
	local ok, value = pcall(function() return (GuiService :: any).ReducedMotionEnabled end)
	return ok and value == true
end

local function getControls()
	if controls then return controls end
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then return nil end
	local ok, result = pcall(function() return require(module):GetControls() end)
	if ok then controls = result end
	return controls
end

local function findMoveAction()
	if moveAction and moveAction.Parent then return moveAction end
	for _, root in { player:FindFirstChild("PlayerScripts"), game:GetService("StarterPlayer") } do
		local module = root and root:FindFirstChild("PlayerModule")
		local contexts = module and module:FindFirstChild("InputContexts")
		local action = contexts and contexts:FindFirstChild("MoveAction", true)
		if action and action:IsA("InputAction") then
			moveAction = action
			return action
		end
	end
	return nil
end

-- Binding scales only apply on the next input event, so a held input is re-emitted at the
-- new scale. Held state always equals raw input * appliedScale.
local function setMoveScale(scale: number)
	local action = findMoveAction()
	if not action or scale == appliedScale then return end
	local previous = appliedScale
	appliedScale = scale
	for _, binding in action:GetChildren() do
		if binding:IsA("InputBinding") and not string.find(binding.Name, "ClickToMove", 1, true) then
			if scaled[binding] == nil then scaled[binding] = binding.Vector2Scale end
			local original = scaled[binding]
			binding.Vector2Scale = Vector2.new(original.X * scale, original.Y * scale)
		end
	end
	local state = action:GetState()
	if typeof(state) == "Vector2" and state.Magnitude > 1e-3 then
		action:Fire(state / previous * scale)
	end
end

local function restoreMoveScale()
	setMoveScale(1)
	for binding, original in scaled do
		if binding.Parent then binding.Vector2Scale = original end
	end
	table.clear(scaled)
	appliedScale = 1
	charge = 0
end

local function inputStep(dt: number)
	if not assignment then return end
	local invert = effectOf("Input")
	local inverted = invert ~= nil and CarryDebuff.phase(invert, elapsed()).State == "Active"
	local action = findMoveAction()
	if action then
		local scale = if inverted then -1 else 1
		if effectOf("Momentum") then
			-- Acceleration ramp only: releasing input still stops at once (no forced movement).
			local state = action:GetState()
			local active = typeof(state) == "Vector2" and state.Magnitude > 1e-3
			charge = if active then math.min(1, charge + dt / 0.6) else 0
			scale *= math.round((0.35 + 0.65 * charge) * 20) / 20
		end
		setMoveScale(scale)
		return
	end
	local control = getControls()
	if not control then return end
	local raw = control:GetMoveVector()
	local move = raw
	if inverted then
		move = -move
	end
	if effectOf("Momentum") then
		-- Sluggish turning and acceleration only; output never exceeds the live input,
		-- so releasing the stick or keys always stops the character.
		smoothed = smoothed:Lerp(move, 1 - math.exp(-3.5 * dt))
		local magnitude = math.min(smoothed.Magnitude, move.Magnitude)
		move = if smoothed.Magnitude > 1e-3 then smoothed.Unit * magnitude else Vector3.zero
	end
	if move ~= raw then
		player:Move(move, true)
	end
end

local function cameraStep()
	local sway = effectOf("Camera")
	local camera = workspace.CurrentCamera
	if not sway or not camera or reducedMotion() then return end
	local phase = CarryDebuff.phase(sway, elapsed())
	if phase.State ~= "Active" then return end
	local roll = math.sin(os.clock() * 1.7) * math.rad(SWAY_DEGREES)
	camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, roll)
end

local function setBindings(active: boolean)
	if active == bound then return end
	bound = active
	if active then
		smoothed = Vector3.zero
		RunService:BindToRenderStep(INPUT_STEP, Enum.RenderPriority.Input.Value + 1, inputStep)
		RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, cameraStep)
	else
		RunService:UnbindFromRenderStep(INPUT_STEP)
		RunService:UnbindFromRenderStep(CAMERA_STEP)
		restoreMoveScale()
	end
end

local function edge(parent, name, anchor, position, size, rotation)
	local frame = Instance.new("Frame")
	frame.Name = name frame.AnchorPoint = anchor frame.Position = position frame.Size = size
	frame.BackgroundColor3 = Color3.new(0, 0, 0) frame.BorderSizePixel = 0 frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	gradient.Parent = frame
end

local function build()
	gui = Instance.new("ScreenGui") gui.Name = "CarryCurseHud" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2 gui.Parent = player:WaitForChild("PlayerGui")
	vignette = Instance.new("Frame") vignette.Name = "Vignette" vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1) vignette.Visible = false vignette.Parent = gui
	edge(vignette, "Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0)
	edge(vignette, "Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.16, 1), 180)
	edge(vignette, "Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), 90)
	edge(vignette, "Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.14), 270)
	banner = Instance.new("TextLabel") banner.Name = "CurseStatus" banner.AnchorPoint = Vector2.new(0.5, 0)
	-- IgnoreGuiInset is on for the full-screen vignette; 180 clears the HuntNotice banner.
	banner.Position = UDim2.new(0.5, 0, 0, 180) banner.Size = UDim2.new(0.3, 0, 0, 64)
	banner.BackgroundColor3 = Color3.fromRGB(48, 18, 70) banner.BackgroundTransparency = 0.2
	banner.TextColor3 = Color3.fromRGB(235, 210, 255) banner.TextSize = 16 banner.Font = Enum.Font.GothamBold
	banner.TextWrapped = true banner.Visible = false banner.Parent = gui
end

local function render()
	if not banner then return end
	if not assignment or #assignment.Effects == 0 then
		banner.Visible = false vignette.Visible = false
		return
	end
	local labels, states = {}, {}
	local t = elapsed()
	for _, effect in assignment.Effects do
		table.insert(labels, CarryDebuff.Catalog[effect.Id].Label)
		table.insert(states, CarryDebuff.status(effect, t))
	end
	banner.Text = assignment.Title .. " / " .. table.concat(labels, " + ") .. "\n" .. table.concat(states, "  ·  ")
	banner.Visible = true
	local camera = effectOf("Camera")
	local reducedSway = camera ~= nil and reducedMotion() and CarryDebuff.phase(camera, t).State == "Active"
	vignette.Visible = player:GetAttribute("CurseVignetteDisabled") ~= true and (effectOf("Vision") ~= nil or reducedSway)
end

local function load()
	local encoded = player:GetAttribute("CarryCurse")
	assignment = nil
	if type(encoded) == "string" and encoded ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, encoded)
		if ok and type(decoded) == "table" and type(decoded.Effects) == "table" then assignment = decoded end
	end
	startTime = player:GetAttribute("CarryCurseStart") or 0
	setBindings(assignment ~= nil and (effectOf("Input") ~= nil or effectOf("Momentum") ~= nil or effectOf("Camera") ~= nil))
	render()
end

function Curse.Start()
	if gui then return end
	build()
	table.insert(connections, player:GetAttributeChangedSignal("CarryCurse"):Connect(load))
	table.insert(connections, player:GetAttributeChangedSignal("CarryCurseStart"):Connect(load))
	table.insert(connections, player:GetAttributeChangedSignal("CurseVignetteDisabled"):Connect(render))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		if assignment and os.clock() >= nextText then
			nextText = os.clock() + 0.1
			render()
		end
	end))
	load()
end

function Curse.Stop()
	for _, c in connections do c:Disconnect() end
	connections = {}
	assignment = nil
	setBindings(false)
	if gui then gui:Destroy() end
	gui, banner, vignette = nil, nil, nil
end

function Curse.GetState()
	return {
		Running = gui ~= nil, Bound = bound,
		Effects = if assignment then #assignment.Effects else 0,
		Inverted = (function()
			local invert = effectOf("Input")
			return invert ~= nil and CarryDebuff.phase(invert, elapsed()).State == "Active"
		end)(),
		Banner = if banner and banner.Visible then banner.Text else "",
		Vignette = vignette ~= nil and vignette.Visible,
	}
end

return Curse
