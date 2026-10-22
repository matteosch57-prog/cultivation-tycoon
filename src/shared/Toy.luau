-- The HUD language (mock C) as a kit for new screens: outlined chunky text, toy buttons, icons
-- from the shared icon sheet. Same look as Hud.client.luau (which still carries its own copy).
-- Every size goes through Toy.px, so a screen scales with Toy.S (set by the caller).
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))
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

-- toy button: solid shadow + outlined face + glass shine. Returns (holder, button).
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
	Toy.glass(btn, radius)
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local function to(s, t, style)
		TweenService:Create(sc, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	btn.MouseEnter:Connect(function()
		to(1.06, 0.12)
	end)
	btn.MouseButton1Down:Connect(function()
		btn.Position = UDim2.fromOffset(0, px(3))
		to(0.92, 0.06)
	end)
	local function up()
		btn.Position = UDim2.new()
		to(1, 0.35, Enum.EasingStyle.Back)
	end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
	btn.Activated:Connect(function()
		Sfx.play("click")
	end)
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

-- A disciple of rarity `rarityName` exactly as the mock draws it: the moving aura and the disciple,
-- straight on whatever is behind (no backdrop disc; owner 2026-10-21: "why a background anyway").
-- Every aura piece stays inside the box. `noAura` draws the bare disciple filling the box.
local function well(parent, size, idx, props)
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
	figureImage(cg, math.floor(size * 86 / 120 + 0.5), idx, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -math.floor(size * 2 / 120)), ZIndex = 2 })
	return cg
end

function Toy.disciple(parent, size, rarityName, props, noAura)
	local idx = Config.rarityIndex(rarityName)
	if noAura then
		return figureImage(parent, size, idx, props)
	end
	return well(parent, size, idx, props)
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

-- Draws icon `key` in a size x size box; returns the box. A shop item with a `rarity` draws that
-- rarity's disciple with its moving aura.
function Toy.icon(parent, key, size, props)
	local item = Config.shopItem(key)
	if item and item.qiBonus then
		-- the Welcome Pouch: the qi pouch with its disciple peeking out of the corner
		local box = atlasIcon(parent, "shop", size, props)
		Toy.disciple(box, math.floor(size * 0.6), item.rarity, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.12, 1.12), ZIndex = 4 })
		return box
	elseif item and item.rarity then
		return well(parent, size, Config.rarityIndex(item.rarity), props)
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
