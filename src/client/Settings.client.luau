-- Settings page (BACKLOG "full settings page", owner 2026-10-23: "Settings page ... finish now").
-- The standard set top simulators ship (Pet Simulator 99, Bee Swarm, Muscle Legends: volume sliders,
-- a music pick, switches for vibration and other players' effects, a low-effects switch), on one
-- card in the HUD's style: Sound on the left (Music, Sounds, Ambience, the music track), Game on
-- the right (Vibration, Other players' auras, Cloud sea). A gear button on the HUD's left rail opens
-- it (Player.HudSlots.Left, after Friends). Values apply at once on this screen only; the server
-- keeps them in the save (Remotes.SaveSettings when the page closes) and hands them back on join as
-- the Settings attribute (JSON).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Toy = require(Shared:WaitForChild("Toy"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Haptic = require(Shared:WaitForChild("Haptic"))

Sfx.init()

local px, text, frame = Toy.px, Toy.text, Toy.frame
local INK = Toy.INK
local GOLD = Color3.fromHex("FFD34D")
local JADE = Color3.fromHex("59D39F")
local MUTED = Color3.fromHex("CBBFD6")
local OFF = Color3.fromHex("5A4D66")
local TRACK = Color3.fromHex("2A2034")
local FACE = Color3.fromHex("3A2C44") -- the HUD's button face

-- the page's values; track 0 = the place's MusicTrack
local state = { music = 1, sfx = 1, amb = 1, track = 0, haptic = true, auras = true, clouds = true }
local dirty = false

local gui = Instance.new("ScreenGui")
gui.Name = "Settings" -- in the HUD's MODALS: the HUD hides while the page is up
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = playerGui

local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function computeScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local forced = player:GetAttribute("HudDevice")
	local touch = if forced then forced == "phone" else (playerGui:FindFirstChild("TouchGui") ~= nil or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled))
	if touch then
		return math.clamp(vp.Y / 390, 0.78, 1.1)
	end
	return math.clamp(vp.Y / 554, 1, 1.7)
end

---------------------------------------------------------------------------------------------
-- applying: sound groups, the music pick, the buzz, other players' auras, the cloud sea

-- other players' PlayerAura folders (PlayerAura.luau, under the character): hidden on this screen
local hidden = {} -- [folder] = DescendantAdded connection
local function showAura(folder, show)
	for _, d in folder:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = show
			if not show then
				d:Clear()
			end
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = show
		elseif d:IsA("BasePart") then
			d.LocalTransparencyModifier = show and 0 or 1
		end
	end
end
local function setAura(folder, show)
	if show then
		if hidden[folder] then
			hidden[folder]:Disconnect()
			hidden[folder] = nil
			showAura(folder, true)
		end
	elseif not hidden[folder] then
		showAura(folder, false)
		-- beads and layers added later (a rebirth, a new realm) stay hidden too
		hidden[folder] = folder.DescendantAdded:Connect(function()
			task.defer(showAura, folder, false)
		end)
		folder.Destroying:Connect(function()
			if hidden[folder] then
				hidden[folder]:Disconnect()
				hidden[folder] = nil
			end
		end)
	end
end
local function applyAuras()
	for _, p in Players:GetPlayers() do
		local folder = p ~= player and p.Character and p.Character:FindFirstChild("PlayerAura")
		if folder then
			setAura(folder, state.auras)
		end
	end
end
local function watchPlayer(p)
	if p == player then
		return
	end
	p.CharacterAdded:Connect(function(char)
		local folder = char:WaitForChild("PlayerAura", 20)
		if folder and not state.auras then
			setAura(folder, false)
		end
	end)
end
for _, p in Players:GetPlayers() do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)

-- the cloud sea's particles (Style.cloudSea): the heaviest overdraw on a phone
local function applyClouds()
	local sect = workspace:FindFirstChild("Sect")
	local sea = sect and sect:FindFirstChild("CloudSea")
	if not sea then
		return
	end
	for _, d in sea:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Enabled ~= state.clouds then
			d.Enabled = state.clouds
			if not state.clouds then
				d:Clear()
			end
		end
	end
end
-- the sea streams in after join: apply once it arrives (and again on a stream-in)
task.spawn(function()
	local sect = workspace:WaitForChild("Sect", 60)
	if not sect then
		return
	end
	local function watch(sea)
		sea.DescendantAdded:Connect(function(d)
			if not state.clouds and d:IsA("ParticleEmitter") then
				task.defer(applyClouds)
			end
		end)
		applyClouds()
	end
	local sea = sect:FindFirstChild("CloudSea")
	if sea then
		watch(sea)
	end
	sect.ChildAdded:Connect(function(c)
		if c.Name == "CloudSea" then
			watch(c)
		end
	end)
end)

local function apply()
	Sfx.setVolume("Music", state.music)
	Sfx.setVolume("SFX", state.sfx)
	Sfx.setVolume("Ambience", state.amb)
	Sfx.setTrack(state.track > 0 and state.track or nil)
	Haptic.enabled = state.haptic
	applyAuras()
	applyClouds()
end

-- the saved values, once the server has loaded the save
local loaded = false
local function load()
	local raw = player:GetAttribute("Settings")
	if type(raw) ~= "string" or loaded then
		return
	end
	loaded = true
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(t) == "table" then
		for _, key in { "music", "sfx", "amb" } do
			if type(t[key]) == "number" then
				state[key] = math.clamp(t[key], 0, 1)
			end
		end
		if type(t.track) == "number" and Sfx.MUSIC[t.track] then
			state.track = t.track
		end
		for _, key in { "haptic", "auras", "clouds" } do
			if type(t[key]) == "boolean" then
				state[key] = t[key]
			end
		end
	end
	apply()
end
player:GetAttributeChangedSignal("Settings"):Connect(load)
load()

---------------------------------------------------------------------------------------------
-- the page

local W = 290 -- a column's width (px before scale)
local open -- the veil while the page is up
local dragging -- the slider being dragged: { hit, set }

local function rowFrame(col, order)
	local row = frame(col, { Size = UDim2.fromOffset(px(W), px(44)), LayoutOrder = order })
	return row
end

-- a volume slider: name on the left, the bar and its percent on the right
local function slider(col, order, name, key)
	local row = rowFrame(col, order)
	text(row, name, px(19), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
	local pct = text(row, "", px(16), MUTED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	local barW = px(124)
	local bar = frame(row, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -px(62), 0.5, 0), -- room for "100%" past the knob
		Size = UDim2.fromOffset(barW, px(12)),
		BackgroundTransparency = 0,
		BackgroundColor3 = TRACK,
	})
	Toy.corner(bar, UDim.new(1, 0))
	local bs = Instance.new("UIStroke")
	bs.Color = INK
	bs.Thickness = px(2)
	bs.Parent = bar
	local fill = frame(bar, { Size = UDim2.fromScale(state[key], 1), BackgroundTransparency = 0, BackgroundColor3 = JADE })
	Toy.corner(fill, UDim.new(1, 0))
	local knob = frame(bar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(state[key], 0.5),
		Size = UDim2.fromOffset(px(26), px(26)),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	})
	Toy.corner(knob, UDim.new(1, 0))
	local ks = Instance.new("UIStroke")
	ks.Color = INK
	ks.Thickness = px(3)
	ks.Parent = knob
	local function draw()
		fill.Size = UDim2.fromScale(state[key], 1)
		knob.Position = UDim2.fromScale(state[key], 0.5)
		pct.Text = state[key] == 0 and "Off" or (math.round(state[key] * 100) .. "%")
		pct.TextColor3 = state[key] == 0 and Color3.fromHex("FF9FB0") or MUTED
	end
	draw()
	-- the hit area is taller than the bar: a thumb lands on it easily
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, px(26), 0, px(40))
	hit.ZIndex = 4
	hit.Parent = bar
	local function set(x)
		local v = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		v = math.round(v * 20) / 20
		if v ~= state[key] then
			state[key] = v
			dirty = true
			apply()
			draw()
		end
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = { set = set, input = input }
			set(input.Position.X)
		end
	end)
end

-- an on / off switch
local function switch(col, order, name, key)
	local row = rowFrame(col, order)
	text(row, name, px(19), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
	local holder, btn = Toy.button(row, UDim2.fromOffset(px(66), px(34)), state[key] and JADE or OFF, px(17))
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, 0, 0.5, -px(2))
	local knob = frame(btn, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(state[key] and 0.72 or 0.28, 0.5),
		Size = UDim2.fromOffset(px(24), px(24)),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	})
	Toy.corner(knob, UDim.new(1, 0))
	btn.Activated:Connect(function()
		state[key] = not state[key]
		dirty = true
		apply()
		tween(knob, 0.15, { Position = UDim2.fromScale(state[key] and 0.72 or 0.28, 0.5) })
		tween(btn, 0.15, { BackgroundColor3 = state[key] and JADE or OFF })
	end)
end

-- the music pick: < name >
local function trackPicker(col, order)
	local row = rowFrame(col, order)
	text(row, "Track", px(19), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
	local box = frame(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(px(196), px(36)) })
	local name = text(box, "", px(15), GOLD, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local function current()
		return state.track > 0 and state.track or math.clamp(tonumber(workspace:GetAttribute("MusicTrack")) or 1, 1, #Sfx.MUSIC)
	end
	local function draw()
		name.Text = Sfx.MUSIC[current()].name
	end
	draw()
	for i, dir in { -1, 1 } do
		local holder, btn = Toy.button(box, UDim2.fromOffset(px(32), px(32)), FACE, px(16))
		holder.AnchorPoint = Vector2.new(i == 1 and 0 or 1, 0.5)
		holder.Position = UDim2.fromScale(i == 1 and 0 or 1, 0.5)
		text(btn, dir < 0 and "<" or ">", px(20), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
		btn.Activated:Connect(function()
			state.track = (current() - 1 + dir) % #Sfx.MUSIC + 1
			dirty = true
			apply()
			draw()
		end)
	end
end

local function column(parent, order, title)
	local col = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = order })
	Toy.list(col, false, px(4))
	text(col, title, px(16), MUTED, { LayoutOrder = 0 })
	return col
end

local function close()
	if not open then
		return
	end
	open:Destroy()
	open = nil
	dragging = nil
	gui.Enabled = false
	if dirty then
		dirty = false
		remotes.SaveSettings:FireServer(state)
	end
end

local function build()
	Toy.S = computeScale()
	local veil = Instance.new("TextButton") -- swallows taps on the world behind; a tap outside closes
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromHex("140E1E")
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	veil.Activated:Connect(close)
	tween(veil, 0.3, { BackgroundTransparency = 0.35 })
	open = veil

	local card = frame(veil, {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, px(10)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	Toy.corner(card, UDim.new(0, px(18)))
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromHex("3A2C4A"), Color3.fromHex("1D1520"))
	g.Rotation = 90
	g.Parent = card
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, px(14)), UDim.new(0, px(18))
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(22)), UDim.new(0, px(22))
	pad.Parent = card
	Toy.list(card, false, px(10))
	local pop = Instance.new("UIScale")
	pop.Scale = 0.4
	pop.Parent = card
	tween(pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

	text(card, "Settings", px(30), GOLD, { LayoutOrder = 1 })
	local cols = frame(card, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 })
	local cl = Toy.list(cols, true, px(30))
	cl.VerticalAlignment = Enum.VerticalAlignment.Top
	local sound = column(cols, 1, "Sound")
	slider(sound, 1, "Music", "music")
	trackPicker(sound, 2)
	slider(sound, 3, "Sounds", "sfx")
	slider(sound, 4, "Ambience", "amb")
	local game_ = column(cols, 2, "Game")
	switch(game_, 1, "Vibration", "haptic")
	switch(game_, 2, "Others' auras", "auras")
	switch(game_, 3, "Cloud sea", "clouds")
	text(game_, "Off = smoother on phones", px(14), MUTED, { LayoutOrder = 5 })

	local xHolder, xBtn = Toy.button(veil, UDim2.fromOffset(px(44), px(44)), Color3.fromHex("FF7A6B"), px(12))
	xHolder.AnchorPoint = Vector2.new(1, 0)
	xHolder.Position = UDim2.new(1, -px(16), 0, GuiService.TopbarInset.Max.Y + px(8))
	text(xBtn, "X", px(24), Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	xBtn.Activated:Connect(close)
end

local function show()
	if open then
		return
	end
	remotes.MenuOpened:FireServer("settings") -- analytics Menu
	gui.Enabled = true
	build()
end

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging.input) then
		dragging.set(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragging.input) then
		dragging = nil
	end
end)
player:GetAttributeChangedSignal("HudDevice"):Connect(function()
	if open then
		close()
	end
end)

-- other scripts (and Studio checks) open the page through Player.SettingsOpen
local openEv = Instance.new("BindableEvent")
openEv.Name = "SettingsOpen"
openEv.Parent = player
openEv.Event:Connect(show)

---------------------------------------------------------------------------------------------
-- the gear button: a row of the HUD's left rail, after Friends (LayoutOrder 4)
local root
local function gear(parent, size)
	local box = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = 3 })
	local white = Color3.fromHex("F2ECF7")
	for i = 0, 3 do -- 8 teeth: 4 bars through the centre
		local bar = frame(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(size * 0.24), size),
			Rotation = i * 45,
			BackgroundTransparency = 0,
			BackgroundColor3 = white,
			ZIndex = 3,
		})
		Toy.corner(bar, UDim.new(0, math.max(1, math.floor(size * 0.05))))
	end
	local ring = frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.floor(size * 0.74), math.floor(size * 0.74)), BackgroundTransparency = 0, BackgroundColor3 = white, ZIndex = 3 })
	Toy.corner(ring, UDim.new(1, 0))
	local hole = frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.floor(size * 0.32), math.floor(size * 0.32)), BackgroundTransparency = 0, BackgroundColor3 = FACE, ZIndex = 4 })
	Toy.corner(hole, UDim.new(1, 0))
	local hs = Instance.new("UIStroke")
	hs.Color = INK
	hs.Thickness = math.max(1, math.floor(size * 0.05))
	hs.Parent = hole
	return box
end

local holderGui = Instance.new("ScreenGui") -- the button's home when the HUD is missing
holderGui.Name = "SettingsButton"
holderGui.ResetOnSpawn = false
holderGui.DisplayOrder = 1
holderGui.Parent = playerGui

local function leftRail()
	local slots = player:FindFirstChild("HudSlots")
	local left = slots and slots:FindFirstChild("Left")
	return left and left.Value
end
local function place()
	if not root then
		return
	end
	local rail = leftRail()
	if rail then
		if root.Parent ~= rail then
			root.AnchorPoint = Vector2.new(0, 0)
			root.Position = UDim2.new()
			root.Parent = rail
		end
	elseif root.Parent ~= holderGui then
		root.Position = UDim2.fromOffset(px(12), GuiService.TopbarInset.Max.Y + px(260))
		root.Parent = holderGui
	end
end
local function drawButton()
	Toy.S = computeScale()
	if root then
		root:Destroy()
	end
	root = frame(holderGui, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4 })
	root.Name = "SettingsRow"
	local holder, btn = Toy.button(root, UDim2.fromOffset(px(42), px(42)), FACE, px(11))
	holder.Name = "SettingsHolder"
	btn.Name = "SettingsButton"
	gear(btn, px(28))
	btn.Activated:Connect(show)
	place()
end
drawButton()
task.spawn(function()
	local slots = player:WaitForChild("HudSlots", 30)
	if slots then
		slots:WaitForChild("Rebuilt").Event:Connect(function()
			task.defer(place)
		end)
		place()
	end
end)
player:GetAttributeChangedSignal("HudDevice"):Connect(drawButton)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(drawButton)
