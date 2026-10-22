-- The launch screen (owner pick A with C's camera dive, mock docs/art/mocks/loading_A.jpg and
-- loading_C.jpg): from the first frame a jade veil, the title and a qi drop that fills with the real
-- progress (game loaded, the HUD drawn, the server's PeakReady once your avatar stands on your
-- peak). Full: the drop glows and turns, "TAP TO ENTER". The tap fades the veil while the camera
-- dives from the sky onto your peak, then sets the local attribute LaunchDone; the Heavenly Gift
-- and the return screen wait for it. Runs from ReplicatedFirst, so it draws before anything else.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Landscape only on phones, turning with the phone between its two landscape sides (owner 2026-10-22;
-- StarterGui carries the same value in default.project.json). The property that turns a player who has
-- already joined is PlayerGui.ScreenOrientation (StarterGui is only copied at join), and the load can
-- put it back to the place default, so it is asserted again for the first seconds (Heavenly RNG's fix).
local function landscape()
	if playerGui.ScreenOrientation ~= Enum.ScreenOrientation.LandscapeSensor then
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end
end
landscape()
task.spawn(function()
	for _ = 1, 10 do
		task.wait(0.5)
		landscape()
	end
end)
-- a phone held upright turns now: size the launch screen for the landscape view, not the upright one
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	while cam.ViewportSize.X < cam.ViewportSize.Y and os.clock() - t0 < 1.5 do
		task.wait()
	end
end

local VEIL = Color3.fromHex("0B1F1A")
local QI_LIGHT = Color3.fromHex("9FF5C8")
local QI_PALE = Color3.fromHex("E8FFF4")
local GOLD = Color3.fromHex("FFD34D")
local INK = Color3.fromHex("1B1420")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local MAX_WAIT = 30 -- s: past this the tap is offered whatever is missing (never a dead screen)
local DIVE = 1.6 -- s of camera dive after the tap

local function tween(obj, t, props, style, dir, reps, rev, delay)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, reps or 0, rev or false, delay or 0), props)
	tw:Play()
	return tw
end

local function scale()
	local vp = workspace.CurrentCamera.ViewportSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return touch and math.clamp(vp.Y / 390, 0.78, 1.1) or math.clamp(vp.Y / 554, 1, 1.7)
end
local S = scale()
local function px(n)
	return math.floor(n * S + 0.5)
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function label(parent, str, size, color, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = str
	t.TextSize = size
	t.TextColor3 = color
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = math.max(2, size / 9)
	st.Parent = t
	for k, v in props or {} do
		t[k] = v
	end
	t.Parent = parent
	return t
end

-- 1. the screen, drawn before Roblox's own loading screen is removed (no flash of the world)
local gui = Instance.new("ScreenGui")
gui.Name = "Launch"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- the veil covers the notch strips too
gui.DisplayOrder = 100 -- over everything, the Intro included
gui.Parent = playerGui

-- white: the gradient below carries the colour (a UIGradient multiplies the background)
local veil = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), Active = true, ZIndex = 1 })
local glowBack = Instance.new("UIGradient")
glowBack.Color = ColorSequence.new(Color3.fromHex("163A30"), VEIL)
glowBack.Rotation = 90
glowBack.Parent = veil

local col = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 2 })
local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, px(4))
layout.Parent = col

label(col, "Cultivation", px(46), QI_PALE, { LayoutOrder = 1 })
label(col, "TYCOON", px(28), GOLD, { LayoutOrder = 2 })
frame(col, { Size = UDim2.fromOffset(1, px(10)), LayoutOrder = 3 })
local DROP = px(140)
local stage = frame(col, { Size = UDim2.fromOffset(DROP, DROP), LayoutOrder = 4 })
frame(col, { Size = UDim2.fromOffset(1, px(10)), LayoutOrder = 5 })
local status = label(col, "Gathering qi...", px(18), QI_LIGHT, { LayoutOrder = 6 })
status.UIStroke.Thickness = 2
local tipLine = label(col, "Walk onto a glowing pad to build", px(15), Color3.fromHex("CBBFD6"), { LayoutOrder = 7 })
tipLine.UIStroke.Enabled = false

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

-- 2. the drop: a dim copy behind, a bright copy clipped from the bottom up by the progress
local fill = 0 -- what the drop shows (eases toward `target`)
local target = 0.05
local clip, rays, dropScale
local function buildDrop()
	local Shared = ReplicatedStorage:WaitForChild("Shared", 20)
	local okToy, Toy = pcall(function()
		return require(Shared:WaitForChild("Toy", 20))
	end)
	if not okToy or not Toy then
		return
	end
	Toy.S = S
	-- rays behind the drop, hidden until it is full
	rays = frame(stage, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(1, 1) })
	for i = 1, 8 do
		local bar = frame(rays, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(px(22), px(i % 2 == 0 and 300 or 380)),
			Rotation = i * 22.5,
			BackgroundTransparency = 1,
			BackgroundColor3 = QI_PALE,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = bar
	end
	local holder = frame(stage, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	dropScale = Instance.new("UIScale")
	dropScale.Parent = holder
	local dim = Instance.new("CanvasGroup")
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.GroupColor3 = Color3.fromHex("2A4A40") -- the empty drop: the same shape in a dark jade
	dim.ZIndex = 2
	dim.Parent = holder
	Toy.qiIcon(dim, DROP)
	clip = frame(holder, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, fill, 0), ClipsDescendants = true, ZIndex = 3 })
	local bright = Toy.qiIcon(clip, DROP)
	bright.AnchorPoint = Vector2.new(0, 1)
	bright.Position = UDim2.fromScale(0, 1)
	for _, d in clip:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 3
		end
	end
end
task.spawn(buildDrop)

-- 3. progress: each step lifts the target; a slow creep keeps it moving while one is pending
local startedAt = os.clock()
local steps = { loaded = false, hud = false, peak = false, body = false }
local WEIGHT = { loaded = 0.3, hud = 0.15, peak = 0.35, body = 0.15 }
local function recompute()
	local t = 0.05
	for k, done in steps do
		if done then
			t += WEIGHT[k]
		end
	end
	target = math.max(target, t)
end
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	steps.loaded = true
	recompute()
end)
task.spawn(function()
	playerGui:WaitForChild("Hud", MAX_WAIT)
	steps.hud = true
	recompute()
end)
task.spawn(function()
	while not player:GetAttribute("PeakReady") do
		player:GetAttributeChangedSignal("PeakReady"):Wait()
	end
	steps.peak = true
	recompute()
end)
task.spawn(function()
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", MAX_WAIT)
	task.wait(0.3) -- the server's place-on-peak runs 0.2 s after the avatar appears
	steps.body = true
	recompute()
end)

local ready = false
local tapPrompt
local conn
conn = RunService.RenderStepped:Connect(function(dt)
	local waited = os.clock() - startedAt
	local all = steps.loaded and steps.hud and steps.peak and steps.body
	local goal = if all or waited > MAX_WAIT then 1 else math.min(0.95, target + waited * 0.006)
	fill += (goal - fill) * math.min(1, dt * 4)
	if goal == 1 and fill > 0.985 then
		fill = 1
	end
	if clip then
		clip.Size = UDim2.new(1, 0, fill, 0)
	end
	status.Text = string.format("Gathering qi... %d%%", math.floor(fill * 100))
	if fill >= 1 and not ready then
		ready = true
		conn:Disconnect()
		tapPrompt()
	end
end)

-- 4. full: glow and TAP; the tap dives the camera onto the peak and opens the game
local entered = false
local function enter()
	if entered or not ready then
		return
	end
	entered = true
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	tween(col, 0.25, { Position = UDim2.fromScale(0.5, 0.42) })
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.3, { TextTransparency = 1 })
			local st = d:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, 0.3, { Transparency = 1 })
			end
		elseif d:IsA("CanvasGroup") then
			tween(d, 0.3, { GroupTransparency = 1 })
		elseif d:IsA("Frame") and d ~= veil and d.BackgroundTransparency < 1 then
			tween(d, 0.3, { BackgroundTransparency = 1 })
		elseif d:IsA("ImageLabel") then
			tween(d, 0.3, { ImageTransparency = 1 })
		end
	end
	if hrp then
		-- the dive: from high above and behind, down to where the follow camera already sits
		local finish = cam.CFrame
		local focus = hrp.Position
		local back = (finish.Position - focus) * Vector3.new(1, 0, 1)
		back = if back.Magnitude > 0.1 then back.Unit else Vector3.new(0, 0, 1)
		local from = focus + back * 70 + Vector3.new(0, 150, 0)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(from, focus)
		tween(cam, DIVE, { CFrame = finish }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
	tween(veil, 0.6, { BackgroundTransparency = 1 }, nil, nil, nil, nil, 0.1)
	task.delay(DIVE, function()
		cam.CameraType = Enum.CameraType.Custom
		gui:Destroy()
		player:SetAttribute("LaunchDone", true) -- local: the Intro gift and the return screen wait for it
	end)
end

tapPrompt = function()
	status.Text = "TAP TO ENTER"
	status.TextSize = px(30)
	status.TextColor3 = Color3.new(1, 1, 1)
	status.UIStroke.Thickness = px(4)
	tipLine.Visible = false
	if rays then
		for _, bar in rays:GetChildren() do
			tween(bar, 0.5, { BackgroundTransparency = 0 })
		end
		tween(rays, 18, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	end
	if dropScale then
		tween(dropScale, 0.15, { Scale = 1.12 }).Completed:Wait()
		tween(dropScale, 0.8, { Scale = 1.04 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
	local pulse = Instance.new("UIScale")
	pulse.Parent = status
	tween(pulse, 0.7, { Scale = 1.08 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	veil.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			enter()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			enter()
		end
	end)
end

-- Studio test hook: player attribute LaunchTap = true taps (no mouse input in tests)
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("LaunchTap"):Connect(function()
		if player:GetAttribute("LaunchTap") then
			enter()
		end
	end)
end
