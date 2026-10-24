-- The HUD language (mock C) as a kit for new screens: outlined chunky text, toy buttons, icons
-- from the shared icon sheet. Same look as Hud.client.luau (which still carries its own copy).
-- Every size goes through Toy.px, so a screen scales with Toy.S (set by the caller).
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))
local Haptic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Haptic"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))

local Toy = {}
Toy.S = 1
Toy.INK = Color3.fromHex("1B1420")
Toy.FONT = Font.fromEnum(Enum.Font.FredokaOne)

function Toy.px(v)
	return math.floor(v * Toy.S + 0.5)
end
local px = Toy.px

function Toy.frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	for k, v in props or {} do
		f[k] = v
	end
	f.Parent = parent
	return f
end
local frame = Toy.frame

function Toy.corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = parent
	return c
end
local corner = Toy.corner

function Toy.list(parent, horizontal, gap, props)
	local l = Instance.new("UIListLayout")
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 0)
	for k, v in props or {} do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- outlined chunky text (never cut: it grows with its text, R4)
function Toy.text(parent, str, size, color, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Toy.FONT
	t.Text = str
	t.TextSize = size
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	for k, v in props or {} do
		t[k] = v
	end
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = math.max(1.5, size * 0.11)
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = t
	t.Parent = parent
	return t
end

-- The shine on a toy button: a glass cap over the top half that fades away downwards (mock
-- glass_bars 3, owner pick 2026-10-21). One white Frame + a vertical transparency gradient.
function Toy.glass(face, radius)
	local g = frame(face, { Size = UDim2.fromScale(0.9, 0.46), Position = UDim2.fromScale(0.05, 0.05), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(g, UDim.new(0, math.max(2, radius - 3)))
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 0.97) })
	grad.Parent = g
	return g
end

-- The light on a ROUND toy button (owner pick B "Dome" of docs/art/mocks/2026-10-22_round_buttons.jpg:
-- the glass cap "looks weird" on circles): lit from above like a ball, the Recruit seal's soft light.
-- A full-face shade (white at the top, clear across the middle, dark at the bottom) and a soft white
-- lift over the top. Both are overlays, so a face that changes colour (ready = gold) keeps its light.
function Toy.dome(face)
	local shade = frame(face, { Name = "Dome", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	corner(shade, UDim.new(0.5, 0))
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.51, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.53, Color3.new(0, 0, 0)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	})
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.66), NumberSequenceKeypoint.new(0.52, 1), NumberSequenceKeypoint.new(1, 0.76) })
	grad.Parent = shade
	Toy.atlasPiece(face, "glow", 0, 0, Color3.new(1, 1, 1), 0.55, { Name = "DomeLift", Position = UDim2.fromScale(0.5, 0.31), Size = UDim2.fromScale(0.8, 0.6) })
	return shade
end

-- the right light for a toy button: the dome on a circle (corner radius at least half its smaller
-- side, in px), the glass cap on everything else
function Toy.shine(face, size, radius)
	local side = math.min(size.X.Offset, size.Y.Offset)
	if side > 0 and radius * 2 >= side - 1 then
		return Toy.dome(face)
	end
	return Toy.glass(face, radius)
end

-- Click feel for every button in the game: "Jelly" (D61, owner pick C of
-- docs/art/mocks/button_feel.html). On touch, not on release, so it answers instantly: the click
-- sound, a phone buzz (Haptic), and the face squashes wide and short onto its shadow; release
-- wobbles it tall, then wide, then settles. Gamepad and keyboard presses (Activated with no touch
-- first) get the same thing in one go.
--   opts.squash  the pieces that squash together (Toy.button passes face + shadow). Default the
--                button itself, unless a layout or AutomaticSize owns its size: then it wobbles
--                through its UIScale instead
--   opts.scale   what grows on mouse-over and pops on Toy.reward (default the button; Toy.button
--                passes its holder)
--   opts.sound   Sfx name for the press (default "click"; false = silent, the caller plays its own)
--   opts.hover   false = no grow on mouse-over
local feels = setmetatable({}, { __mode = "k" }) -- button -> its UIScale, for Toy.reward

local function tw(obj, t, goal, style, dir)
	local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

local function radiusOf(btn)
	local c = btn:FindFirstChildOfClass("UICorner")
	return c and c.CornerRadius or UDim.new(0, 0)
end

-- a white copy of the face's shape for the blink, made once per button
local function flashOf(btn)
	local f = btn:FindFirstChild("FeelFlash")
	if not f then
		f = frame(btn, { Name = "FeelFlash", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 9 })
		corner(f, radiusOf(btn))
	end
	return f
end

-- a thin ring that grows off the button's edge and fades (grow = extra px on each side)
local function ringOff(btn, grow, t, thick)
	local r = frame(btn, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 9 })
	corner(r, radiusOf(btn))
	local st = Instance.new("UIStroke")
	st.Color = Color3.new(1, 1, 1)
	st.Thickness = thick or px(3)
	st.Transparency = 0.15
	st.Parent = r
	tw(r, t, { Size = UDim2.new(1, grow * 2, 1, grow * 2) })
	tw(st, t, { Transparency = 1 })
	task.delay(t, function()
		r:Destroy()
	end)
end

-- the squash keyframes (x, y, seconds): touch, then the release wobble
local SQUASH = { 1.08, 0.86, 0.07 }
local WOBBLE = { { 0.94, 1.1, 0.14 }, { 1.03, 0.97, 0.13 }, { 1, 1, 0.2 } }

local function sizeOwned(g)
	if g.AutomaticSize ~= Enum.AutomaticSize.None then
		return true
	end
	return g.Parent ~= nil and g.Parent:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

function Toy.feel(btn, opts)
	if feels[btn] then
		return feels[btn]
	end
	opts = opts or {}
	-- one UIScale per object counts, so never stack on one the screen already animates
	local target = opts.scale or btn
	if target:FindFirstChildOfClass("UIScale") then
		target = btn
	end
	local sc = target:FindFirstChildOfClass("UIScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "Feel"
		sc.Parent = target
	elseif sc.Name ~= "Feel" then
		sc = nil -- (the button scales itself already: sound and buzz only)
	end
	if sc then
		feels[btn] = sc
	end
	-- squash pieces with their resting Size/Position; they squash about their bottom middle, so
	-- the face presses down onto its shadow and stretches up out of it
	local pieces = {}
	for _, g in opts.squash or (sizeOwned(btn) and {} or { btn }) do
		table.insert(pieces, { g = g })
	end
	local gen = 0
	local function squashTo(sx, sy, t, style)
		for _, p in pieces do
			local g, size, pos = p.g, p.size, p.pos
			local ax, ay = g.AnchorPoint.X, g.AnchorPoint.Y
			local kx, ky = (0.5 - ax) * (1 - sx), (1 - ay) * (1 - sy)
			tw(g, t, {
				Size = UDim2.new(size.X.Scale * sx, size.X.Offset * sx, size.Y.Scale * sy, size.Y.Offset * sy),
				Position = pos + UDim2.new(size.X.Scale * kx, size.X.Offset * kx, size.Y.Scale * ky, size.Y.Offset * ky),
			}, style)
		end
	end
	local function wobble(i, my)
		local k = WOBBLE[i]
		if not k or gen ~= my then
			return
		end
		if #pieces > 0 then
			squashTo(k[1], k[2], k[3], Enum.EasingStyle.Sine)
		elseif sc then
			tw(sc, k[3], { Scale = (k[1] + k[2]) / 2 + (i == 1 and 0.06 or 0) }, Enum.EasingStyle.Sine)
		end
		task.delay(k[3], wobble, i + 1, my)
	end
	local down, lastUp = false, 0
	local function press()
		if down then
			return
		end
		down = true
		gen += 1
		if opts.sound ~= false then
			Sfx.play(opts.sound or "click")
		end
		Haptic.play("click")
		if #pieces > 0 then
			for _, p in pieces do
				if not p.size then -- rest taken at the first touch, when the screen has laid out
					p.size, p.pos = p.g.Size, p.g.Position
				end
			end
			squashTo(SQUASH[1], SQUASH[2], SQUASH[3])
		elseif sc then
			tw(sc, SQUASH[3], { Scale = 0.9 })
		end
	end
	local function release()
		if not down then
			return
		end
		down, lastUp = false, os.clock()
		if sc and #pieces > 0 then
			tw(sc, 0.2, { Scale = 1 })
		end
		wobble(1, gen)
	end
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			press()
		end
	end)
	btn.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			release()
		end
	end)
	btn.MouseLeave:Connect(function()
		release()
		if sc and not down then
			tw(sc, 0.2, { Scale = 1 })
		end
	end)
	if opts.hover ~= false and sc then
		btn.MouseEnter:Connect(function()
			if not down then
				tw(sc, 0.12, { Scale = 1.06 })
			end
		end)
	end
	btn.Activated:Connect(function()
		if not down and os.clock() - lastUp > 0.3 then -- gamepad / keyboard: no touch came first
			press()
			task.delay(SQUASH[3], release)
		end
	end)
	return sc
end

-- The claim moment (Claim, Collect, gifts): a deeper squeeze then a big pop, the face blinks, a
-- wide ring and a burst of gold motes fly off it, the chime and a double buzz. Call it when the
-- reward is confirmed. opts.sound = another Sfx name (default "buyChime"), opts.flyTo = a GuiObject
-- (the qi counter) that qi orbs fly into, opts.onArrive() when the first one lands.
local GOLD_MOTE = Color3.fromHex("FFE36B")
function Toy.reward(btn, opts)
	opts = opts or {}
	Sfx.play(opts.sound or "buyChime")
	Haptic.play("reward")
	local sc = feels[btn]
	if sc then
		sc.Scale = 0.9
		tw(sc, 0.18, { Scale = 1.16 }, Enum.EasingStyle.Quad).Completed:Once(function()
			tw(sc, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	local f = flashOf(btn)
	f.BackgroundTransparency = 0.2
	tw(f, 0.26, { BackgroundTransparency = 1 })
	ringOff(btn, px(26), 0.5, px(4))
	local gui = btn:FindFirstAncestorWhichIsA("LayerCollector")
	if not gui then
		return
	end
	local origin = gui:IsA("GuiBase2d") and gui.AbsolutePosition or Vector2.zero
	local c = btn.AbsolutePosition + btn.AbsoluteSize / 2 - origin
	for i = 1, 16 do
		local a = math.pi * 2 * i / 16 + math.random() * 0.3
		local d = px(70 + math.random() * 60)
		local m = Toy.atlasPiece(gui, "mote", px(16), px(16), i % 2 == 0 and Color3.new(1, 1, 1) or GOLD_MOTE, 0, { Position = UDim2.fromOffset(c.X, c.Y), ZIndex = 50 })
		local t = 0.6 + math.random() * 0.2
		tw(m, t, { Position = UDim2.fromOffset(c.X + math.cos(a) * d, c.Y + math.sin(a) * d * 0.7), Size = UDim2.fromOffset(px(4), px(4)), ImageTransparency = 1 }, Enum.EasingStyle.Quint)
		task.delay(t, function()
			m:Destroy()
		end)
	end
	local to = opts.flyTo
	if to and to:IsDescendantOf(game) then
		local arrived = false
		for i = 1, 8 do
			local orb = Toy.qiIcon(gui, px(24), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), ZIndex = 51 })
			local a = math.random() * math.pi * 2
			local d = px(40 + math.random() * 50)
			tw(orb, 0.25, { Position = UDim2.fromOffset(c.X + math.cos(a) * d, c.Y + math.sin(a) * d * 0.6) }, Enum.EasingStyle.Quad)
			task.delay(0.25 + i * 0.04, function()
				local tc = to.AbsolutePosition + to.AbsoluteSize / 2 - origin
				local t = 0.45
				tw(orb, t, { Position = UDim2.fromOffset(tc.X, tc.Y), Size = UDim2.fromOffset(px(14), px(14)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(t, function()
					orb:Destroy()
					Sfx.play("orb")
					if not arrived then
						arrived = true
						if opts.onArrive then
							opts.onArrive()
						end
					end
				end)
			end)
		end
	end
end

-- toy button: solid shadow + outlined face + its light (Toy.shine: glass cap, dome on a circle). Returns (holder, button).
function Toy.button(parent, size, color, radius)
	local holder = frame(parent, { Size = size })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(4)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	corner(shadow, UDim.new(0, radius))
	local btn = Instance.new("TextButton")
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Parent = holder
	corner(btn, UDim.new(0, radius))
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = btn
	Toy.shine(btn, size, radius)
	Toy.feel(btn, { scale = holder, squash = { btn, shadow } })
	return holder, btn
end

-- Moving auras behind a disciple icon (mock docs/art/mocks/disciple_auras.gif, owner OK
-- 2026-10-21), climbing with the rarity like the RNG games' aura ladders: 1 a breathing glow,
-- 2 two motes circling, 3 a turning ring of dots, 4 slow rays and rising motes, 5 a halo, gold rays
-- and twinkles, 6 clouds drifting round, 7 a turning yin-yang ring and embers, 8 twin rays, gold
-- dust and a halo, 9 every colour, flames and everything. Shapes only; one shared animator moves
-- every aura that is on screen (~30 fps, PerfMark "auras"), nothing runs for a hidden one (R16).
local auras = {}
local animator

local function shown(box)
	local g = box
	while g do
		if g:IsA("LayerCollector") then
			return g.Enabled
		end
		if g:IsA("GuiObject") and not g.Visible then
			return false
		end
		g = g.Parent
	end
	return false
end

local function startAnimator()
	if animator then
		return
	end
	local acc = 0
	animator = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local t0 = PerfMark.begin()
		local t = os.clock()
		for i = #auras, 1, -1 do
			local a = auras[i]
			if not a.box:IsDescendantOf(game) then
				table.remove(auras, i)
			elseif shown(a.box) then
				a.update(t)
			end
		end
		PerfMark.finish("auras", t0)
	end)
end

-- The aura for rarity `idx` filling `box` (S px square, 120 "mock units" across; the disciple sits
-- in the middle). Built from the atlas pieces (Config.DISCIPLE_ATLAS, the mock's own drawings:
-- tools/disciple_atlas.html), tinted with ImageColor3 and moved like the mock
-- (docs/art/mocks/disciple_auras.html): sizes and speeds below are the mock's numbers.
local ATLAS = Config.DISCIPLE_ATLAS
local WHITE = Color3.new(1, 1, 1)
local HALO_GOLD = Color3.fromHex("FFE36B")

function Toy.aura(box, idx, S)
	local u = S / 120
	local base = Config.RARITIES[idx].color
	local function layer(z)
		return frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S, S), ZIndex = z })
	end
	local back, front = layer(1), layer(3)
	-- one atlas piece, centred on (x, y) mock units, w x h mock units
	local function piece(parent, name, w, h, color, transp)
		local c = ATLAS.cells[name]
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = ATLAS.image
		img.ImageRectOffset = Vector2.new(c[1], c[2])
		img.ImageRectSize = Vector2.new(c[3], c[4])
		img.ImageColor3 = color or WHITE
		img.ImageTransparency = transp or 0
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Size = UDim2.fromOffset(w * u, h * u)
		img.Parent = parent
		return img
	end
	local function at(f, x, y)
		f.Position = UDim2.fromOffset(x * u, y * u)
	end
	local tinted = {}

	-- glow (everyone): two soft discs that breathe (the mock's three flat discs, now one soft fade)
	local glows = {}
	for i, k in { 1.45, 0.95 } do
		local g = piece(back, "glow", 1, 1, base, 1 - (i == 1 and 0.85 or 0.8) * (0.62 + idx * 0.05))
		at(g, 60, 60)
		glows[i] = { f = g, k = k }
		table.insert(tinted, g)
	end
	-- rays (Elder up), twin white rays (Heavenly Emperor up)
	local rayA, rayB
	if idx >= 4 then
		rayA = piece(back, idx >= 5 and "rays12" or "rays8", 116, 116, base, 0.4)
		at(rayA, 60, 60)
		table.insert(tinted, rayA)
	end
	if idx >= 8 then
		rayB = piece(back, "rays8", 100, 100, WHITE, 0.35)
		at(rayB, 60, 60)
	end
	-- a turning dashed ring (Core up) or the yin-yang ring (Dao Ancestor)
	local ring
	if idx == 7 then
		ring = piece(back, "yinyang", 100, 100, WHITE, 0.1)
	elseif idx >= 3 then
		ring = piece(back, "ring", 87, 87, base, 0.1)
		table.insert(tinted, ring)
	end
	if ring then
		at(ring, 60, 60)
	end
	-- halo (Immortal, Emperor, Primordial)
	local halo
	if idx == 5 or idx >= 8 then
		halo = piece(back, "halo", 36, 14.4, HALO_GOLD)
		at(halo, 60, 30)
	end
	-- motes circling (Inner, Core): a white core in a coloured halo
	local orbit = {}
	if idx == 2 or idx == 3 then
		for i = 1, idx do
			local outer = piece(front, "mote", 13, 13, base, 0.35)
			local inner = piece(front, "mote", 7, 7, WHITE)
			orbit[i] = { outer, inner }
		end
	end
	-- motes rising (Elder, Celestial, Dao, Emperor, Primordial): embers, gold dust
	local rising = {}
	if idx == 4 or idx >= 6 then
		local col = idx == 7 and Color3.fromHex("FF7A3A") or (idx == 8 and Color3.fromHex("FFD34D") or base)
		for i = 1, idx >= 8 and 8 or 5 do
			local m = piece(front, "mote", 7 + (i % 2) * 2, 7 + (i % 2) * 2, col)
			rising[i] = m
			if idx ~= 7 and idx ~= 8 then
				table.insert(tinted, m)
			end
		end
	end
	-- twinkles (Immortal, Emperor, Primordial)
	local twinkles = {}
	if idx == 5 or idx >= 8 then
		for i = 1, 5 do
			local s = piece(front, "sparkle", 12, 12, WHITE)
			local a = i * 1.37 + 0.3
			at(s, 60 + math.cos(a) * 44, 58 + math.sin(a) * 40)
			twinkles[i] = s
		end
	end
	-- clouds drifting round (Celestial), in front of the disciple on the near side
	local clouds = {}
	if idx == 6 then
		for i = 1, 3 do
			clouds[i] = piece(back, "cloud", 26, 16.25, WHITE)
		end
	end
	-- flames (Primordial)
	local flames = {}
	if idx >= 9 then
		for i = 1, 7 do
			local f = piece(back, "flame", 12.5, 20, base, 0.2)
			f.AnchorPoint = Vector2.new(0.5, 1)
			f.Rotation = (i - 4) * 24
			local a = -math.pi / 2 + (i - 4) * 0.42
			at(f, 60 + math.cos(a) * 36, 68 + math.sin(a) * 40)
			flames[i] = f
		end
	end

	local function update(t)
		local breathe = 0.5 + 0.5 * math.sin(t * 4.2)
		if idx >= 9 then
			local col = Color3.fromHSV((t * 0.33) % 1, 0.55, 1)
			for _, f in tinted do
				f.ImageColor3 = col
			end
			for i, f in flames do
				f.ImageColor3 = Color3.fromHSV((t * 0.33 + i / 7) % 1, 0.6, 1)
				f.Size = UDim2.fromOffset(12.5 * u, 20 * u * (1 + 0.25 * math.sin(t * 8 + i * 1.3)))
			end
		end
		for _, g in glows do
			local d = (34 + idx * 1.6 + breathe * 3) * g.k * 2 * u
			g.f.Size = UDim2.fromOffset(d, d)
		end
		if rayA then
			rayA.Rotation = t * 42
		end
		if rayB then
			rayB.Rotation = -t * 72
		end
		if ring then
			ring.Rotation = t * (idx == 7 and 60 or 120)
		end
		if halo then
			local p = 1 + 0.08 * breathe
			halo.Size = UDim2.fromOffset(36 * u * p, 14.4 * u * p)
		end
		for i, m in orbit do
			local a = t * 2.1 + i * math.pi * 2 / #orbit
			at(m[1], 60 + math.cos(a) * 40, 62 + math.sin(a) * 18)
			at(m[2], 60 + math.cos(a) * 40, 62 + math.sin(a) * 18)
		end
		for i, m in rising do
			local ph = (t * (idx >= 8 and 0.5 or 0.33) + i / #rising) % 1
			at(m, 60 + math.sin(i * 2.3 + ph * 3) * 30, 100 - ph * 85)
			m.ImageTransparency = 1 - math.sin(ph * math.pi)
		end
		for i, s in twinkles do
			local tw = math.max(0, math.sin(t * 4.2 + i * 1.9))
			s.Size = UDim2.fromOffset(12 * u * tw + 0.01, 12 * u * tw + 0.01)
		end
		for i, c in clouds do
			local a = t * 1.05 + i * math.pi * 2 / 3
			local want = math.sin(a) > 0 and front or back
			if c.Parent ~= want then
				c.Parent = want
			end
			at(c, 60 + math.cos(a) * 42, 70 + math.sin(a) * 14)
		end
	end
	update(os.clock())
	table.insert(auras, { box = box, update = update })
	startAnimator()
	return back, front
end

-- one atlas piece (glow, rays12, rays8, ring, halo, mote, ...) as an ImageLabel, w x h px, centred
-- on its Position (the HUD's Recruit seal uses the aura pieces too)
function Toy.atlasPiece(parent, name, w, h, color, transp, props)
	local c = ATLAS.cells[name]
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = ATLAS.image
	img.ImageRectOffset = Vector2.new(c[1], c[2])
	img.ImageRectSize = Vector2.new(c[3], c[4])
	img.ImageColor3 = color or WHITE
	img.ImageTransparency = transp or 0
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromOffset(w, h)
	for k, v in props or {} do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- The red dot (owner 2026-10-22, mock docs/art/mocks/red_dots_A.jpg "ruby gem"): an outlined ruby with
-- a light-to-deep fill, a white glint and a soft red glow, breathing slowly. Sits on the top-right
-- corner of `parent` (a button face, a tab, a tile); Visible = false hides it. One look for every dot:
-- change it here only. Server Dots.luau decides which are lit.
function Toy.dot(parent, size, props)
	size = size or Toy.px(18)
	local holder = Toy.frame(parent, {
		Name = "RedDot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -math.floor(size * 0.15), 0, math.floor(size * 0.15)),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 8,
	})
	for k, v in props or {} do
		holder[k] = v
	end
	Toy.atlasPiece(holder, "glow", size * 2.4, size * 2.4, Color3.fromHex("FF3B3B"), 0.35, { ZIndex = 8 })
	local gem = Toy.frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 9 })
	Toy.corner(gem, UDim.new(0.5, 0))
	local fill = Instance.new("UIGradient")
	fill.Rotation = 55
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FF9A8F")),
		ColorSequenceKeypoint.new(0.35, Color3.fromHex("FF3B3B")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("A8101C")),
	})
	fill.Parent = gem
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = math.max(2, size * 0.13)
	st.Parent = gem
	local glint = Toy.frame(gem, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.34, 0.3),
		Size = UDim2.fromScale(0.32, 0.22),
		Rotation = -30,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = WHITE,
		ZIndex = 10,
	})
	Toy.corner(glint, UDim.new(0.5, 0))
	-- breathing: one looping tween on its own UIScale
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	TweenService:Create(sc, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.14 }):Play()
	return holder
end

-- the disciple picture from the atlas (the mock's drawing), centred in `parent`, `size` px
local function figureImage(parent, size, idx, props)
	local c = ATLAS.cells["fig" .. idx]
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = ATLAS.image
	img.ImageRectOffset = Vector2.new(c[1], c[2])
	img.ImageRectSize = Vector2.new(c[3], c[4])
	img.Size = UDim2.fromOffset(size, size)
	for k, v in props or {} do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- a named disciple's face (Config.DISCIPLE_FACES, 2026-10-23), `size` px, nil until the sheet is uploaded
local function faceImage(parent, size, rarityName, look, props)
	local f = Config.DISCIPLE_FACES
	if f.image == "" or not look then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = f.image
	img.ImageRectOffset = Config.faceCell(rarityName, look)
	img.ImageRectSize = Vector2.new(f.cell, f.cell)
	img.Size = UDim2.fromOffset(size, size)
	for k, v in props or {} do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- Shiny (Pet Simulator 99's sparkle): four white sparkles round `box` (`size` px) that twinkle in turn
local function shinyMarks(box, size)
	for i, at in { { 0.12, 0.14, 0.24 }, { 0.88, 0.2, 0.18 }, { 0.9, 0.82, 0.22 }, { 0.1, 0.78, 0.16 } } do
		local sp = Toy.atlasPiece(box, "sparkle", size * at[3], size * at[3], WHITE, 0, { Position = UDim2.fromScale(at[1], at[2]), ZIndex = 8 })
		local sc = Instance.new("UIScale")
		sc.Scale = 0.55
		sc.Parent = sp
		TweenService:Create(sc, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, i * 0.35), { Scale = 1.15 }):Play()
	end
end

-- A disciple of rarity `rarityName` exactly as the mock draws it: the moving aura and the disciple,
-- straight on whatever is behind (no backdrop disc; owner 2026-10-21: "why a background anyway").
-- Every aura piece stays inside the box. `noAura` draws the bare disciple filling the box.
local function well(parent, size, idx, props, rarityName, look)
	local cg = Instance.new("Frame")
	cg.Size = UDim2.fromOffset(size, size)
	cg.BackgroundTransparency = 1
	cg.BorderSizePixel = 0
	for k, v in props or {} do
		cg[k] = v
	end
	corner(cg, UDim.new(0.5, 0))
	cg.Parent = parent
	Toy.aura(cg, idx, size)
	-- the atlas cell spans 72 units around the figure; drawn at 86 of the well's 120 so the disciple
	-- fills the well like the HUD row of the mock
	local centre = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -math.floor(size * 2 / 120)), ZIndex = 2 }
	if not faceImage(cg, math.floor(size * 92 / 120 + 0.5), rarityName, look, centre) then
		figureImage(cg, math.floor(size * 86 / 120 + 0.5), idx, centre)
	end
	return cg
end

-- `look` (a DISCIPLE_LOOKS key) draws that named disciple's face once the face sheet is uploaded (the
-- rarity's figure until then, and wherever the look is unknown: the Shop, gifts); `shiny` adds the
-- sparkles.
function Toy.disciple(parent, size, rarityName, props, noAura, look, shiny)
	local idx = Config.rarityIndex(rarityName)
	local out
	if noAura then
		out = faceImage(parent, size, rarityName, look, props) or figureImage(parent, size, idx, props)
	else
		out = well(parent, size, idx, props, rarityName, look)
	end
	if shiny then
		shinyMarks(out, size)
	end
	return out
end

-- One index star, the same gem everywhere (the crowns over the disciples, their cards, the index book,
-- the recruit reveal; owner 2026-10-23 "make sure the stars are the same everywhere"): lit in `color`
-- (Config.STAR_COLORS) with a light top and a darker rim, like the life beads; nil = dark glass with a
-- gold rim. `props` sets its size (TextSize, or Size + TextScaled) and place.
local STAR_DARK = { Color3.fromHex("463A56"), Color3.fromHex("241C2E"), Color3.fromHex("C8A050") }
function Toy.starGem(parent, color, props)
	local star = Instance.new("TextLabel")
	star.BackgroundTransparency = 1
	star.FontFace = Toy.FONT
	star.Text = "★"
	star.TextColor3 = Color3.new(1, 1, 1)
	star.AutomaticSize = Enum.AutomaticSize.XY
	star.Size = UDim2.new()
	for k, v in props or {} do
		star[k] = v
	end
	local grad = Instance.new("UIGradient")
	grad.Color = color and ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.6), color) or ColorSequence.new(STAR_DARK[1], STAR_DARK[2])
	grad.Rotation = 90
	grad.Parent = star
	local rim = Instance.new("UIStroke")
	rim.Color = color and color:Lerp(Color3.new(0, 0, 0), 0.5) or STAR_DARK[3]
	rim.Thickness = math.max(1, (star.TextScaled and 12 or star.TextSize) * 0.08)
	rim.LineJoinMode = Enum.LineJoinMode.Round
	rim.Parent = star
	star.Parent = parent
	return star
end

-- a row of the STAR_ROW index stars for `stars` (Config.starRow: gold, then red, then blue over the
-- band before; empty slots dark glass). Returns the row.
function Toy.stars(parent, stars, size, props)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	Toy.list(row, true, 0)
	local colors = Config.starRow(stars)
	for i = 1, Config.STAR_ROW do -- not ipairs: an empty slot is a nil colour
		Toy.starGem(row, colors[i], { TextSize = size, LayoutOrder = i, ZIndex = row.ZIndex })
	end
	return row
end

-- a small dark pill (a count, a tag, the stars)
local function darkPill(parent, props)
	local f = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromHex("1E1726") })
	for k, v in props or {} do
		f[k] = v
	end
	corner(f, UDim.new(1, 0))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, Toy.px(4)), UDim.new(0, Toy.px(4))
	pad.Parent = f
	Toy.list(f, true, 0)
	return f
end
Toy.darkPill = darkPill

-- One disciple as a toy card, the same everywhere a disciple is listed (2026-10-23, owner: "normalize
-- how we show them"): the Disciples book's My Sect and Index tabs, the recruit reveal. A solid shadow,
-- a face lit from the top in the rarity's colours, an ink rim, an inner rim in the rarity's colour
-- (the star colour of each full row of five), the glass cap, the named disciple's face in its moving
-- rarity aura, Shiny sparkles. Not found: a slate card, a dark shape and a "?".
-- `w` = the card's width in px (height 0.89 of it). opts (all optional):
--   found (default true), shiny, stars (a star row under the card; nil = none), count (a "xN" pill,
--   top left), tag (a text pill at the foot, e.g. "Isle 2"), new (a red NEW tag), name (its name
--   under the card, shrunk to fit), order (LayoutOrder).
-- Returns the cell (the card + its lines) and a transparent TextButton over the card for a tap.
local SHAPE = Color3.fromHex("241C2C")
function Toy.discipleTile(parent, w, rarityName, look, opts)
	opts = opts or {}
	local px = Toy.px
	local r = Config.rarity(rarityName)
	local found = opts.found ~= false
	local stars = opts.stars or 0
	local full = Config.STAR_COLORS[math.min(stars // Config.STAR_ROW, #Config.STAR_COLORS)] -- a full row's colour
	local h, rad = math.floor(w * 0.89 + 0.5), math.floor(w * 0.19 + 0.5)
	local cell = frame(parent, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = opts.order or 0 })
	local cl = Toy.list(cell, false, px(2))
	cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local holder = frame(cell, { Size = UDim2.fromOffset(w, h), LayoutOrder = 1 })
	local shadow = frame(holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(3)), BackgroundTransparency = 0, BackgroundColor3 = Toy.INK })
	corner(shadow, UDim.new(0, rad))
	local face = frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ClipsDescendants = true })
	corner(face, UDim.new(0, rad))
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = found and ColorSequence.new(r.color:Lerp(WHITE, 0.62), r.color:Lerp(Toy.INK, 0.12)) or ColorSequence.new(Color3.fromHex("4A3F57"), Color3.fromHex("2A2232"))
	grad.Parent = face
	local st = Instance.new("UIStroke")
	st.Color = Toy.INK
	st.Thickness = px(3)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = face
	Toy.glass(face, rad)
	local faced = Config.DISCIPLE_FACES.image ~= "" and look ~= nil
	if found then
		Toy.disciple(face, w, rarityName, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, faced and px(1) or math.floor(w * 0.075)), ZIndex = 2 }, false, look, opts.shiny)
	else
		local fig = Toy.disciple(face, math.floor(w * (faced and 0.85 or 0.7)), rarityName, faced and { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 2 } or { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, px(4)), ZIndex = 2 }, true, look)
		fig.ImageColor3 = SHAPE -- never pulled: a dark shape
		Toy.text(face, "?", math.floor(w * 0.31), Color3.fromHex("A89BBB"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 3 })
	end
	-- the inner rim: the rarity's colour, the star colour once a row of five is full
	local rim = frame(face, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -px(5), 1, -px(5)), ZIndex = 5 })
	corner(rim, UDim.new(0, rad - px(3)))
	local rs = Instance.new("UIStroke")
	rs.Color = full or (found and r.color:Lerp(WHITE, 0.35) or Color3.fromHex("5E5270"))
	rs.Thickness = full and px(3) or px(2)
	rs.Parent = rim
	if found and opts.shiny then -- a clear gold mark, the sparkles alone are easy to miss (Play check 2026-10-23)
		local m = math.max(px(14), math.floor(w * 0.36)) -- the atlas sparkle in gold (the font has no ✦)
		Toy.atlasPiece(face, "sparkle", m, m, Color3.fromHex("FFD34D"), 0, { Position = UDim2.new(1, -m * 0.45, 1, -m * 0.45), ZIndex = 7 })
	end
	if found and opts.count then
		Toy.text(darkPill(face, { Position = UDim2.fromOffset(px(3), px(3)), ZIndex = 6 }), "x" .. opts.count, px(10), WHITE, { ZIndex = 7 })
	end
	if opts.tag then
		Toy.text(darkPill(face, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(2)), ZIndex = 6 }), opts.tag, px(10), WHITE, { ZIndex = 7 })
	end
	if opts.new then
		local tag = frame(holder, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, px(3), 0, px(1)), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromHex("FF4D4D"), Rotation = 8, ZIndex = 8 })
		corner(tag, UDim.new(0, px(4)))
		local ts = Instance.new("UIStroke")
		ts.Color = Toy.INK
		ts.Thickness = px(2)
		ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ts.Parent = tag
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, px(3)), UDim.new(0, px(3))
		pad.Parent = tag
		Toy.text(tag, "NEW", px(10), WHITE, { ZIndex = 9 })
	end
	if opts.stars then -- on a dark pill (Toy.stars: gold, then red, then blue)
		Toy.stars(darkPill(cell, { LayoutOrder = 2 }), stars, math.max(px(9), math.floor(w * 0.2)))
	end
	if opts.name and look then -- shrunk to the card's width, never cut (R4)
		local n = Toy.text(cell, Config.discipleName(rarityName, look), px(11), WHITE, { LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(w + px(8), px(12)), TextScaled = true })
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = px(11)
		lim.Parent = n
	end
	local tap = Instance.new("TextButton")
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 9
	tap.Parent = holder
	return cell, tap
end

-- Currency marks (owner rule: every price or amount shows its currency's icon)
function Toy.qiIcon(parent, size, props)
	return Toy.icon(parent, "qi", size, props)
end
function Toy.robuxIcon(parent, size, props)
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Image = Config.ROBUX_ICON
	img.Size = UDim2.fromOffset(size, size)
	img.ZIndex = 2 -- over a toy button's glass cap
	for k, v in props or {} do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- An amount with its currency icon in front: returns (row, label). `currency` = "qi" | "karma" | "robux"
function Toy.amount(parent, currency, size, color, props)
	local row = Toy.frame(parent, { AutomaticSize = Enum.AutomaticSize.XY })
	for k, v in props or {} do
		row[k] = v
	end
	Toy.list(row, true, math.max(2, math.floor(size * 0.2)))
	local icon
	if currency == "robux" then
		icon = Toy.robuxIcon(row, math.floor(size * 1.15), { LayoutOrder = 1 })
	else
		icon = Toy.icon(row, currency, math.floor(size * 1.15), { LayoutOrder = 1 })
	end
	icon.Name = "Currency"
	local label = Toy.text(row, "", size, color, { LayoutOrder = 2 })
	return row, label
end

-- one cell of the icon sheet (Config.ICON_ATLAS) as an ImageLabel, size x size px
local ICON_ATLAS = Config.ICON_ATLAS
local function atlasIcon(parent, key, size, props)
	local i = ICON_ATLAS.keys[key]
	local c = ICON_ATLAS.cell
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Image = ICON_ATLAS.image
	img.ImageRectOffset = Vector2.new(i % 8 * c, i // 8 * c)
	img.ImageRectSize = Vector2.new(c, c)
	img.Size = UDim2.fromOffset(size, size)
	img.ZIndex = 2 -- over a toy button's glass cap
	for k, v in props or {} do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- A Flying Sword (D76) before the icon sheet with its cells is uploaded: a toy jian drawn from frames
-- in the sheet's sticker language (ink outline, one light), nose to the top right, in the tier's
-- colours (1 jade, 2 gold, 3 celestial)
local SWORD_GLYPH = {
	{ blade = "CFF7E6", guard = "5FD39B" },
	{ blade = "FFC93C", guard = "E5483F" },
	{ blade = "9FD8FF", guard = "FFC93C" },
}
local function swordGlyph(parent, size, tier, props)
	local box = Toy.frame(parent, { Size = UDim2.fromOffset(size, size) })
	for k, v in props or {} do
		box[k] = v
	end
	local c = SWORD_GLYPH[tier] or SWORD_GLYPH[1]
	local z = box.ZIndex
	local rot = Toy.frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = 45, ZIndex = z })
	local function piece(x, y, w, h, color, round)
		local f = Toy.frame(rot, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromHex(color),
			ZIndex = z,
		})
		Toy.corner(f, UDim.new(round or 0.3, 0))
		local st = Instance.new("UIStroke")
		st.Color = Toy.INK
		st.Thickness = math.max(1.5, size * 0.06)
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = f
		return f
	end
	piece(0.5, 0.36, 0.13, 0.6, c.blade, 0.35) -- the blade, its tip up (turned 45 degrees: top right)
	piece(0.5, 0.67, 0.4, 0.09, c.guard, 0.5)
	piece(0.5, 0.79, 0.09, 0.17, "E5483F", 0.4) -- the grip
	piece(0.5, 0.92, 0.1, 0.1, c.guard, 1) -- the pommel
	return box
end

-- Draws icon `key` in a size x size box; returns the box. A shop item with a `rarity` draws that
-- rarity's disciple with its moving aura.
function Toy.icon(parent, key, size, props)
	local item = Config.shopItem(key)
	if item and item.qiBonus then
		-- the Welcome Pouch: the qi pouch with its disciple peeking out of the corner
		local box = atlasIcon(parent, "shop", size, props)
		Toy.disciple(box, math.floor(size * 0.6), item.rarity, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.12, 1.12), ZIndex = 4 })
		return box
	elseif item and item.rarity and item.seconds then
		-- the Sect Starter Pack: the gift box with its disciple peeking out of the corner
		local box = atlasIcon(parent, "gift", size, props)
		Toy.disciple(box, math.floor(size * 0.6), item.rarity, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.12, 1.12), ZIndex = 4 })
		return box
	elseif item and item.rarity then
		return well(parent, size, Config.rarityIndex(item.rarity), props)
	elseif item and item.ride and (item.id or 0) ~= 0 then
		-- a Flying Sword: its own store icon (the grade's disc, tools/shop_icons/sword_icons.js) from
		-- the pass thumbnail (owner 2026-10-24: "show real sword icons")
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Image = string.format("rbxthumb://type=GamePass&id=%d&w=150&h=150", item.id)
		img.Size = UDim2.fromOffset(size, size)
		img.ZIndex = 2 -- over a toy button's glass cap
		for k, v in props or {} do
			img[k] = v
		end
		img.Parent = parent
		return img
	elseif item and item.ride and not ICON_ATLAS.keys[key] then
		return swordGlyph(parent, size, item.ride, props)
	elseif key == "robux" then
		return Toy.robuxIcon(parent, size, props)
	elseif key == "disciple" then
		-- the disciple keeps its approved figure (owner 2026-10-22: "disciples have a better shape
		-- already"): the Core Disciple, blue robe, from the disciple atlas
		local img = figureImage(parent, size, 3, props)
		if not (props and props.ZIndex) then
			img.ZIndex = 2 -- over a toy button's glass cap
		end
		return img
	elseif ICON_ATLAS.keys[key] then
		return atlasIcon(parent, key, size, props)
	end
	warn("[Toy] no icon for key", key)
	return Toy.frame(parent, { Size = UDim2.fromOffset(size, size) })
end

return Toy
