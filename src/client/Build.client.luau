-- Step-on pads and the buying feel (concept C "Formation", D27, mock in docs/art/mocks/).
-- Every pad is an invisible server anchor tagged "StepPad"; this script draws it: a carved stone
-- array with two rune rings that turn while you can afford it, a light in its gold heart, a
-- beacon beam and a price card. Walking up, the building's preview rises whole in its final place as
-- a pale spirit glow (owner pick B, 2026-10-22); stepping on spins the rings up and snaps them in,
-- and the bought building lifts apart from that ghost, swirls in and lands with a bell. Building
-- never moves the buyer: pieces that land on you let you through until you step out.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sect = workspace:WaitForChild("Sect")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sfx = require(Shared:WaitForChild("Sfx"))
local PadLook = require(Shared:WaitForChild("PadLook"))
local Toy = require(Shared:WaitForChild("Toy"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local PREVIEW_RANGE = 30 -- studs (horizontal) from the pad centre where the preview starts to show
local PREVIEW_FADE = 12 -- and it is fully there this many studs closer
local SPIRIT = Color3.fromHex("D8FFF0") -- the preview's glow (white with a breath of jade)
local SPIRIT_LTM = 0.78 -- its see-through at full strength (LocalTransparencyModifier)
-- Phone fps 2026-10-24 (owner's Pixel: -30 fps as the Main Hall upgrade's preview appeared): a big
-- building's preview was thousands of see-through Neon parts, each rewritten every frame (fade, breath)
-- and moved every frame (the rise). A preview now draws only its PREVIEW_MAX_PARTS biggest parts (the
-- silhouette: roofs, walls, columns; trims and finials stay hidden), and its parts are only written
-- when the see-through changes by a visible step.
local PREVIEW_MAX_PARTS = 300
local LTM_STEP = 0.01 -- a smaller change of the see-through is not written
local REACH = 2.6 -- the server buys inside this (Main PAD_REACH)
local ANIM_RANGE = 120 -- rings only turn near the camera
local LIGHT_RANGE = 70 -- and only the nearest pads light the ground
local JADE = Color3.fromHex("6FB59C")
local GOLD = Color3.fromHex("D4A445")
local AUTO_GOLD = Color3.fromHex("FFD34D") -- Auto Build (D85): the beam and the "Auto in 0:13" line
local INK = Color3.fromHex("1B1420")
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function fmt(n)
	n = math.floor(n or 0)
	local units = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td" }
	local i, v = 1, n
	while v >= 1000 and i < #units do
		v /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	local digits = v < 10 and 2 or (v < 100 and 1 or 0)
	local f = 10 ^ digits
	return string.format("%." .. digits .. "f%s", math.floor(v * f) / f, units[i])
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalPadFX"
fxFolder.Parent = workspace

local function fxPart(size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = fxFolder
	return p
end

---------------------------------------------------------------------------------------------
-- Scatter: where each piece of a building flies out to during its build-in, keyed on the piece's
-- own position.
local function hash(v, salt)
	local x = math.sin(v.X * 12.9898 + v.Y * 78.233 + v.Z * 37.719 + salt) * 43758.5453
	return x - math.floor(x)
end

local function scatter(parts)
	local centre, minY, maxY = Vector3.zero, math.huge, -math.huge
	for _, p in parts do
		centre += p.Position
		minY = math.min(minY, p.Position.Y)
		maxY = math.max(maxY, p.Position.Y)
	end
	centre /= math.max(#parts, 1)
	local span = math.max(maxY - minY, 1)
	local f = math.clamp(span / 10, 1, 2.5) -- bigger buildings float wider
	local out = {}
	for i, p in parts do
		local pos = p.Position
		local h1, h2, h3 = hash(pos, 1), hash(pos, 2), hash(pos, 3)
		local flat = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z)
		if flat.Magnitude < 0.2 then
			local a = h1 * math.pi * 2
			flat = Vector3.new(math.cos(a), 0, math.sin(a))
		end
		local rel = (pos.Y - minY) / span
		out[i] = {
			off = flat.Unit * (2 + h1 * 2.5) * f + Vector3.new(0, (1.2 + rel * 4) * f, 0),
			rot = Vector3.new((h2 - 0.5) * 0.9, (h3 - 0.5) * 1.4, (h1 - 0.5) * 0.9),
			phase = h3 * 6.28,
			rel = rel,
		}
	end
	return out, centre
end

-- the piece pulled `spread` of the way out (0 = home), swirled `swirl` radians around the centre
local function scattered(home, s, spread, swirl, bob)
	local off = s.off * spread
	if swirl ~= 0 then
		off = CFrame.Angles(0, swirl, 0):VectorToWorldSpace(off)
	end
	return CFrame.new(off + Vector3.new(0, bob or 0, 0)) * home * CFrame.Angles(s.rot.X * spread, s.rot.Y * spread, s.rot.Z * spread)
end

---------------------------------------------------------------------------------------------
-- The formation array (local parts, about 550 triangles a pad)
local RING1, RING2 = 12, 8
local function makeArray(pad, kind)
	local ground = pad.Position.Y - pad.Size.X / 2 -- the anchor is a cylinder lying on its X axis
	local c = CFrame.new(pad.Position.X, ground, pad.Position.Z)
	local k = (kind == "breakthrough" or kind == "rebirth") and 1.25 or 1
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local cyl = Enum.PartType.Cylinder
	local slate = Enum.Material.Slate
	local parts = {
		fxPart(Vector3.new(0.28, 5.8 * k, 5.8 * k), c * CFrame.new(0, 0.14, 0) * up, Color3.fromHex("4E4A57"), slate, cyl),
		fxPart(Vector3.new(0.06, 3 * k, 3 * k), c * CFrame.new(0, 0.31, 0) * up, Color3.fromHex("9C978C"), slate, cyl),
	}
	local heart = fxPart(Vector3.new(0.08, 1.1 * k, 1.1 * k), c * CFrame.new(0, 0.35, 0) * up, GOLD, Enum.Material.Metal, cyl)
	table.insert(parts, heart)
	local light = Instance.new("PointLight") -- the pad is the lamp (R3: pad beacons are allowed)
	light.Range = 10 * k
	light.Shadows = false
	light.Parent = heart
	local segs, locals, rings = {}, {}, {}
	for i = 1, RING1 do
		local a = (i - 1) / RING1 * math.pi * 2
		local s = fxPart(Vector3.new(0.22, 0.08, 0.8) * k, c, JADE, Enum.Material.Neon)
		table.insert(segs, s)
		table.insert(locals, { a = a, r = 2.35 * k, y = 0.33 })
		table.insert(rings, 1)
	end
	for i = 1, RING2 do
		local a = (i - 1) / RING2 * math.pi * 2 + 0.2
		local s = fxPart(Vector3.new(0.5, 0.08, 0.22) * k, c, JADE, Enum.Material.Neon)
		table.insert(segs, s)
		table.insert(locals, { a = a, r = 1.85 * k, y = 0.34 })
		table.insert(rings, 2)
	end
	for _, s in segs do
		table.insert(parts, s)
	end
	-- a ring of light that pulses outward on the ground while the pad is ready
	local pulse = fxPart(Vector3.new(0.05, 5 * k, 5 * k), c * CFrame.new(0, 0.05, 0) * up, JADE, Enum.Material.Neon, cyl)
	pulse.Transparency = 1
	table.insert(parts, pulse)
	local arr = {
		c = c, k = k, parts = parts, segs = segs, locals = locals, rings = rings, light = light, pulse = pulse,
		a1 = 0, a2 = 0, speed = 0, radius = 1, sink = 0,
	}
	local cfs = table.create(#segs)
	function arr.place()
		local base = c - Vector3.new(0, arr.sink, 0)
		for i in segs do
			local l = locals[i]
			local ang = l.a + (rings[i] == 1 and arr.a1 or arr.a2)
			cfs[i] = base * CFrame.Angles(0, ang, 0) * CFrame.new(l.r * arr.radius, l.y, 0) -- ring 1 runs along, ring 2 points out
		end
		workspace:BulkMoveTo(segs, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	function arr.setColor(col, glow)
		for _, s in segs do
			s.Color = col
		end
		pulse.Color = col
		light.Color = col
		arr.glow = glow
	end
	arr.place()
	return arr
end

---------------------------------------------------------------------------------------------
-- Beacon: a beam standing on the pad, visible across the island (local, mine only)
local function makeBeacon(pad)
	local base = fxPart(Vector3.new(3.4, 0.2, 3.4), CFrame.new(pad.Position + Vector3.new(0, 0.3, 0)), JADE)
	base.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 38, 0)
	a1.Parent = base
	local function beam(w0, w1, transp)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = w0
		b.Width1 = w1
		b.Segments = 1
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, transp),
			NumberSequenceKeypoint.new(0.15, transp + 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.Parent = base
		return b
	end
	local core = beam(1.6, 0.6, 0.15)
	local glow = beam(4.2, 2, 0.65)
	local motes = Instance.new("ParticleEmitter")
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Speed = NumberRange.new(6, 11)
	motes.Lifetime = NumberRange.new(1.4, 2.2)
	motes.Size = NumberSequence.new(0.35, 0)
	motes.LightEmission = 1
	motes.Rate = 7
	motes.Parent = base
	local function setColor(c)
		core.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.35), c)
		glow.Color = ColorSequence.new(c)
		motes.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.5))
	end
	return { part = base, setColor = setColor, core = core, glow = glow, motes = motes }
end

---------------------------------------------------------------------------------------------
-- Price card: the HUD language, bigger and plainer (name, what it does, the price)
local function makeCard(pad, kind)
	local bb = Instance.new("BillboardGui")
	bb.ResetOnSpawn = false -- in PlayerGui: the first spawn would wipe it (live joins spawn late)
	bb.Name = "PadCard"
	bb.Adornee = pad
	bb.Size = UDim2.fromOffset(260, 112)
	bb.StudsOffset = Vector3.new(0, 5.5, 0)
	bb.MaxDistance = 110
	-- On top of the 3D: depth-tested cards sat behind the beacon beam, sank half into the
	-- ground up close (the card's quad is centred on its offset) and hid behind the avatar.
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.AnchorPoint = Vector2.new(0.5, 1) -- the distance scale shrinks it toward the pad
	f.Position = UDim2.fromScale(0.5, 1)
	f.BackgroundTransparency = 1
	f.Parent = bb
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	local function text(order, size, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.Size = UDim2.new()
		t.FontFace = FONT
		t.TextSize = size
		t.TextColor3 = color
		t.LayoutOrder = order
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = math.max(2, size * 0.14)
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = t
		t.Parent = f
		return t
	end
	text(1, 22, PadLook.TEXT.title).Text = pad:GetAttribute("Title") or ""
	-- what it gives, always (mock card_text B, owner pick 2026-10-22): (qi drop) +3/s, then in
	-- yellow what a feature building does ("2x Qi pills"). No description lines.
	local income = pad:GetAttribute("Income") or 0
	local feature = pad:GetAttribute("Feature")
	if income > 0 or feature then
		local gives = Instance.new("Frame")
		gives.BackgroundTransparency = 1
		gives.AutomaticSize = Enum.AutomaticSize.XY
		gives.Size = UDim2.new()
		gives.LayoutOrder = 2
		local gl = Instance.new("UIListLayout")
		gl.FillDirection = Enum.FillDirection.Horizontal
		gl.VerticalAlignment = Enum.VerticalAlignment.Center
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Padding = UDim.new(0, 4)
		gl.Parent = gives
		gives.Parent = f
		if income > 0 then
			Toy.icon(gives, "qi", 20, { LayoutOrder = 1 })
			local inc = text(2, 18, PadLook.TEXT.build)
			inc.Text = "+" .. fmt(income) .. "/s"
			inc.Parent = gives
		end
		if feature then
			local ft = text(3, 17, PadLook.TEXT.line)
			ft.Text = feature
			ft.Parent = gives
		end
	end
	-- a worker hire pad: one dot per worker the building can take, gold for the ones hired
	local max = pad:GetAttribute("HireMax")
	if max then
		local dots = Instance.new("Frame")
		dots.BackgroundTransparency = 1
		dots.Size = UDim2.fromOffset(max * 24, 22)
		dots.LayoutOrder = 3
		local dl = Instance.new("UIListLayout")
		dl.FillDirection = Enum.FillDirection.Horizontal
		dl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		dl.VerticalAlignment = Enum.VerticalAlignment.Center
		dl.Padding = UDim.new(0, 6)
		dl.Parent = dots
		for i = 1, max do
			local d = Instance.new("Frame")
			d.Size = UDim2.fromOffset(16, 16)
			d.BackgroundColor3 = i <= (pad:GetAttribute("Hired") or 0) and Color3.fromHex("FFC94A") or Color3.fromHex("6B6170")
			Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
			local st = Instance.new("UIStroke")
			st.Color = INK
			st.Thickness = 2.5
			st.Parent = d
			d.Parent = dots
		end
		dots.Parent = f
	end
	-- the price always shows its currency icon (owner rule): [Need] (qi drop) 1.2K [more]
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.new()
	row.LayoutOrder = 4
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Padding = UDim.new(0, 4)
	rl.Parent = row
	row.Parent = f
	local function part(order, str)
		local t = text(order, 26, PadLook.textColor(kind, true))
		t.Text = str
		t.Parent = row
		return t
	end
	local need = part(1, "Need")
	Toy.icon(row, "qi", 30, { LayoutOrder = 2 })
	local amount = part(3, "")
	local more = part(4, "more")
	-- a red pad says how long until you can afford it at your income now (Plan 1, owner pick 2026-10-24)
	local eta = text(5, 20, PadLook.TEXT.wait)
	eta.Visible = false
	local costText = { need = need, amount = amount, more = more }
	local free = pad:GetAttribute("FreeText") -- a free pad (the idle chest) says what it does instead of a price
	if free then
		row.Visible = false
		text(4, 26, PadLook.textColor(kind, true)).Text = free
	end
	local sc = Instance.new("UIScale")
	sc.Name = "DistanceScale"
	sc.Parent = f
	bb.Parent = player:WaitForChild("PlayerGui")
	return bb, costText, sc, eta
end

-- "in 17s", "in 4:05", "in 1h 05m"
local function etaText(sec)
	sec = math.ceil(sec)
	if sec < 60 then
		return "in " .. sec .. "s"
	elseif sec < 3600 then
		return string.format("in %d:%02d", sec // 60, sec % 60)
	end
	return string.format("in %dh %02dm", sec // 3600, (sec % 3600) // 60)
end

---------------------------------------------------------------------------------------------
-- Effects: sparks + dust, a ripple on the ground, a column of light (short event flashes, R3)
local function burst(position, color, sparkCount, dustCount)
	local holder = fxPart(Vector3.new(8, 1, 8), CFrame.new(position), JADE)
	holder.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), GOLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.Lifetime = NumberRange.new(0.7, 1.2)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, -14, 0)
	sparks.Rate = 0
	sparks.Parent = holder
	sparks:Emit(sparkCount or 45)
	if (dustCount or 0) > 0 then
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
		dust.Size = NumberSequence.new(1.5, 3.5)
		dust.Transparency = NumberSequence.new(0.4, 1)
		dust.Speed = NumberRange.new(6, 9)
		dust.Lifetime = NumberRange.new(0.8, 1.2)
		dust.SpreadAngle = Vector2.new(90, 5)
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Drag = 4
		dust.Rate = 0
		dust.Parent = holder
		dust:Emit(dustCount)
	end
	task.delay(2.5, function()
		holder:Destroy()
	end)
end

local function ripple(c, color, from, to, time)
	local r = fxPart(Vector3.new(0.05, from, from), c * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	r.Transparency = 0.2
	TweenService:Create(r, TweenInfo.new(time or 0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, to, to), Transparency = 1 }):Play()
	task.delay((time or 0.7) + 0.1, function()
		r:Destroy()
	end)
end

local function column(c, color, height, width)
	local p = fxPart(Vector3.new(height, width, width), c * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	p.Transparency = 0.35
	TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = Vector3.new(height, width * 0.25, width * 0.25), Transparency = 1 }):Play()
	task.delay(0.65, function()
		p:Destroy()
	end)
end

---------------------------------------------------------------------------------------------
-- Pads
local pads = {} -- [anchor] = record
local animating = {} -- arrays playing a press (kept alive after their anchor is gone)

local function tweenNumber(time, style, dir, fn, done)
	local v = Instance.new("NumberValue")
	v.Changed:Connect(fn)
	local t = TweenService:Create(v, TweenInfo.new(time, style, dir), { Value = 1 })
	t.Completed:Connect(function()
		v:Destroy()
		if done then
			done()
		end
	end)
	t:Play()
end

-- step on: rings spin up, then snap in with a flash; a bought pad then sinks away
local function playPress(rec, sinkAway)
	local arr = rec.array
	if not arr or arr.pressing then
		return
	end
	arr.pressing = true
	animating[arr] = true
	local col = PadLook.color(rec.kind, true)
	Sfx.play("padSpin")
	task.delay(0.3, function()
		Sfx.play("padSnap")
		ripple(arr.c, col, 5 * arr.k, 16 * arr.k, 0.75)
		column(arr.c, col, 14, 4.4 * arr.k)
		burst(arr.c.Position + Vector3.new(0, 0.6, 0), col, 30, 0)
		tweenNumber(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(x)
			arr.radius = 1 - 0.45 * x
		end)
		if sinkAway then
			Sfx.play("buy")
			task.delay(0.1, function()
				Sfx.play("buyChime")
			end)
			task.delay(0.25, function()
				tweenNumber(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(x)
					arr.sink = 0.6 * x
					for _, p in arr.parts do
						p.LocalTransparencyModifier = x
					end
					arr.light.Brightness = (1 - x) * 2
				end, function()
					animating[arr] = nil
					for _, p in arr.parts do
						p:Destroy()
					end
				end)
			end)
		else
			task.delay(0.35, function()
				tweenNumber(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(x)
					arr.radius = 0.55 + 0.45 * x
				end, function()
					arr.pressing = false
					animating[arr] = nil
				end)
			end)
		end
	end)
end

-- the pad just became affordable: a ping, a ripple and a quick spin
local function playReady(rec)
	local arr = rec.array
	Sfx.play("padReady")
	ripple(arr.c, PadLook.color(rec.kind, true), 5 * arr.k, 11 * arr.k, 0.6)
	arr.kick = 6
end

local function setReady(rec, ok)
	rec.ready = ok
	local col = PadLook.color(rec.kind, ok)
	rec.array.setColor(ok and col or col:Lerp(Color3.new(0.2, 0.15, 0.2), 0.45), ok)
	if rec.beacon then
		rec.beacon.setColor(rec.auto and AUTO_GOLD or col) -- a pad Auto Build will take is gold (D85)
		rec.beacon.core.Width0 = ok and 1.8 or 1.1
		rec.beacon.glow.Width0 = ok and 4.6 or 2.6
		rec.beacon.motes.Rate = ok and 9 or 3
	end
	if rec.costText then
		local tcol = PadLook.textColor(rec.kind, ok)
		for _, t in rec.costText do
			t.TextColor3 = tcol
		end
	end
end

local function preparePreview(rec, preview)
	rec.preview = {}
	for _, d in preview:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(rec.preview, d)
		end
	end
	if #rec.preview > PREVIEW_MAX_PARTS then
		-- biggest first (by the largest face: a long beam counts, a small knob does not); the rest keep
		-- the server's Transparency 1
		local area = {}
		for _, p in rec.preview do
			local sz = p.Size
			area[p] = math.max(sz.X * sz.Y, sz.Y * sz.Z, sz.X * sz.Z)
		end
		table.sort(rec.preview, function(a, b)
			return area[a] > area[b]
		end)
		for i = #rec.preview, PREVIEW_MAX_PARTS + 1, -1 do
			rec.preview[i] = nil
		end
	end
	rec.homes = {}
	for i, p in rec.preview do
		rec.homes[i] = p.CFrame
		p.Material = Enum.Material.Neon
		p.Color = SPIRIT
		p.Transparency = 0
		p.LocalTransparencyModifier = 1
		local sa = p:FindFirstChildOfClass("SurfaceAppearance") -- leaf cards keep their alpha, tinted pale
		if sa then
			pcall(function()
				sa.Color = SPIRIT
			end)
		end
	end
	rec.k = 0
	rec.ltm, rec.lift = nil, nil -- a preview that streamed back in is written fresh
	rec.cfs = table.create(#rec.preview)
end

local function addPad(pad)
	if pads[pad] or not pad:IsA("BasePart") then
		return
	end
	local kind = pad:GetAttribute("PadKind") or "build"
	local owner = pad:GetAttribute("OwnerId")
	local mine = owner == player.UserId
	local rec = { pad = pad, kind = kind, mine = mine, shared = owner == nil, cost = pad:GetAttribute("Cost") or 0 }
	rec.array = makeArray(pad, kind)
	if mine then
		rec.card, rec.costText, rec.scale, rec.eta = makeCard(pad, kind)
		rec.beacon = makeBeacon(pad)
		-- the preview is its own Atomic model under the pad: with streaming it often arrives after the
		-- pad (or streams out and back in), so it is picked up whenever it arrives (owner 2026-10-23:
		-- "only a few have the preview")
		local function hook(preview)
			if preview.Name ~= "Preview" or not preview:IsA("Model") then
				return
			end
			preparePreview(rec, preview)
			preview.AncestryChanged:Connect(function()
				if not preview:IsDescendantOf(pad) and rec.previewModel == preview then
					rec.preview, rec.previewModel, rec.previewShown, rec.lift = nil, nil, false, nil
				end
			end)
			rec.previewModel = preview
		end
		local preview = pad:FindFirstChild("Preview")
		if preview then
			hook(preview)
		end
		pad.ChildAdded:Connect(hook)
		setReady(rec, (player:GetAttribute("Qi") or 0) >= rec.cost)
	else
		setReady(rec, true) -- shop pads, and other players' pads (their qi is theirs)
		if not rec.shared then
			rec.still = true -- another player's pad: drawn, but still and unlit
		end
	end
	pads[pad] = rec
	-- the server prices the open pads again after every buy (Main pricePads); the card reads rec.cost
	pad:GetAttributeChangedSignal("Cost"):Connect(function()
		rec.cost = pad:GetAttribute("Cost") or 0
	end)
	rec.cleanup = function()
		if not pads[pad] then
			return
		end
		pads[pad] = nil
		if rec.card then
			rec.card:Destroy()
		end
		if rec.beacon then
			rec.beacon.part:Destroy()
		end
		if mine and rec.ready and rec.onPad then
			playPress(rec, true) -- bought by me just now (not a realm reset)
		elseif not rec.array.pressing then
			for _, p in rec.array.parts do
				p:Destroy()
			end
		end
	end
	pad.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rec.cleanup()
		end
	end)
end

for _, d in CollectionService:GetTagged("StepPad") do
	task.spawn(addPad, d)
end
CollectionService:GetInstanceAddedSignal("StepPad"):Connect(function(d)
	task.defer(addPad, d) -- let attributes and the Preview child arrive
end)

---------------------------------------------------------------------------------------------
-- Building never moves the buyer (owner 2026-10-22: the server's step-out teleport and the camera
-- swing after it felt jarring). A piece of the new building that lands on your own character lets
-- you through, on your client only, until you have stepped out of it; every other piece collides
-- at once. (A piece that does not collide also never pops the camera in.)
-- (by box maths, not a spatial query: the pieces were just moved by CFrame, and the physics
-- broadphase still holds them where they flew a frame ago, so a query found nothing in Play)
local function box(cf, size)
	local h = size / 2
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return cf.Position,
		Vector3.new(
			math.abs(x.X) * h.X + math.abs(y.X) * h.Y + math.abs(z.X) * h.Z,
			math.abs(x.Y) * h.X + math.abs(y.Y) * h.Y + math.abs(z.Y) * h.Z,
			math.abs(x.Z) * h.X + math.abs(y.Z) * h.Y + math.abs(z.Z) * h.Z
		)
end

-- A piece whose top is at or under the feet is floor, never "on" you: it stays solid (owner
-- 2026-10-27: a held plank under the feet dropped you through a new bridge)
local FLOOR_STEP = 0.6
local function touching(char, list)
	local cf, size = char:GetBoundingBox()
	local c, e = box(cf, size + Vector3.new(1, 0.5, 1))
	local feet = cf.Position.Y - size.Y / 2
	local hit = {}
	for _, p in list do
		local pc, pe = box(p.CFrame, p.Size)
		local d = pc - c
		if pc.Y + pe.Y > feet + FLOOR_STEP and math.abs(d.X) < e.X + pe.X and math.abs(d.Y) < e.Y + pe.Y and math.abs(d.Z) < e.Z + pe.Z then
			hit[p] = true
		end
	end
	return hit
end

local function passThrough(model, parts, collide)
	local char = player.Character
	local onMe = (char and model:GetAttribute("BuyerId") == player.UserId) and touching(char, parts) or {}
	local held, list = {}, {}
	for i, p in parts do
		if collide[i] and onMe[p] then
			held[p] = true
			table.insert(list, p)
		else
			p.CanCollide = collide[i]
		end
	end
	if #list == 0 then
		return
	end
	task.spawn(function()
		while next(held) and model.Parent do
			task.wait(0.25)
			local c = player.Character
			local still = c and touching(c, list) or {}
			for p in held do
				if not still[p] then
					held[p] = nil
					p.CanCollide = true
				end
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- A bridge is walked onto as it is bought (owner 2026-10-27: "often I build it and fall if I
-- continue on it"), so it never flies in: no piece moves or stops colliding. The planks lay
-- themselves out from the end nearest you to the far rim, faster than you can run, a spark at
-- each quarter, and the bell when the far end lands.
local BRIDGE_WAVE, BRIDGE_FADE = 0.55, 0.15 -- seconds for the wave to cross, and each piece to show
local function layBridge(model, parts, effects, mine)
	-- the span's axis: the main direction of the pieces on the ground plane
	local c = Vector3.zero
	for _, p in parts do
		c += p.Position
	end
	c /= #parts
	local sxx, szz, sxz = 0, 0, 0
	for _, p in parts do
		local d = p.Position - c
		sxx += d.X * d.X
		szz += d.Z * d.Z
		sxz += d.X * d.Z
	end
	local a = 0.5 * math.atan2(2 * sxz, sxx - szz)
	local axis = Vector3.new(math.cos(a), 0, math.sin(a))
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (hrp.Position - c):Dot(axis) > 0 then
		axis = -axis -- start at the end you stand by
	end
	local lo, hi = math.huge, -math.huge
	local along = table.create(#parts)
	for i, p in parts do
		along[i] = (p.Position - c):Dot(axis)
		lo, hi = math.min(lo, along[i]), math.max(hi, along[i])
	end
	local span = math.max(hi - lo, 1)
	local starts = table.create(#parts)
	for i, p in parts do
		starts[i] = (along[i] - lo) / span * BRIDGE_WAVE
		p.LocalTransparencyModifier = 1
	end
	local y = c.Y
	local function at(u)
		return Vector3.new(c.X, y, c.Z) + axis * (lo + span * u)
	end
	if mine then
		Sfx.play("gather")
	end
	burst(at(0), JADE, 20, 10)
	local t0 = os.clock()
	local sparked = 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local done = true
		for i, p in parts do
			local v = math.clamp((t - starts[i]) / BRIDGE_FADE, 0, 1)
			if v < 1 then
				done = false
			end
			p.LocalTransparencyModifier = 1 - v
		end
		while sparked < 3 and t >= BRIDGE_WAVE * (sparked + 1) / 4 do
			sparked += 1
			burst(at(sparked / 4), JADE, 14, 0)
		end
		if done or not model.Parent then
			conn:Disconnect()
			for _, p in parts do
				p.LocalTransparencyModifier = 0
			end
			if not model.Parent then
				return
			end
			if mine then
				Sfx.play("padSnap")
				Sfx.play("smallBell")
				Sfx.play("land")
			end
			burst(at(1), JADE, 30, 16)
			for _, e in effects do
				if e.Parent then
					e.Enabled = true
				end
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Build-in: the bought building's pieces lift out from where the preview ghost stood, swirl in
-- and lock together bottom first, then a bell, sparks and a warm flash.
local function animateBuild(model)
	local builtAt = model:GetAttribute("BuiltAt")
	if not builtAt or workspace:GetServerTimeNow() - builtAt > 3 then
		return -- joined late or rebuilt: just show it
	end
	task.wait() -- let the whole subtree arrive
	local parts, effects = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif (d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke")) and d.Enabled then
			d.Enabled = false
			table.insert(effects, d)
		end
	end
	if #parts == 0 then
		return
	end
	local mine = model.Parent and model.Parent.Parent and model.Parent.Parent.Name == ("Peak" .. tostring(player:GetAttribute("PlotIndex")))
	if model.Name:match("^bridge_") then
		layBridge(model, parts, effects, mine)
		return
	end
	local cf, size = model:GetBoundingBox()
	-- the flying pieces must not collide: they shoved the avatar onto the next pads (5 buys)
	local homes, collide = table.create(#parts), table.create(#parts)
	for i, p in parts do
		homes[i] = p.CFrame
		collide[i] = p.CanCollide
		p.CanCollide = false
		p.LocalTransparencyModifier = 1
	end
	local sc = scatter(parts)
	local cfs = table.create(#parts)
	local function pose(spread, swirl)
		for i in parts do
			cfs[i] = scattered(homes[i], sc[i], spread, swirl)
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	pose(0, 0) -- where the preview ghost stood a moment ago
	task.wait(0.3) -- the pad's rings snap first
	if not model.Parent then
		return
	end
	if mine then
		Sfx.play("gather")
	end
	local OUT, IN, STAGGER = 0.25, 0.45, 0.3
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local done = true
		for i, p in parts do
			local s = sc[i]
			local tt = t - s.rel * STAGGER -- bottom pieces first
			local spread, swirl
			if tt < OUT then
				local x = math.max(tt, 0) / OUT
				spread = 0.15 + 0.35 * (1 - (1 - x) * (1 - x))
				swirl = 0
				done = false
			elseif tt < OUT + IN then
				local x = (tt - OUT) / IN
				spread = 0.5 * (1 - x * x * x) -- accelerate into place: a snap, not a drift
				swirl = (1 - x) * (1 - x) * 1.2
				done = false
			else
				spread, swirl = 0, 0
			end
			p.LocalTransparencyModifier = math.max(0, 1 - t / 0.2)
			cfs[i] = scattered(homes[i], s, spread, swirl)
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		if done or not model.Parent then
			conn:Disconnect()
			for i, p in parts do
				p.CFrame = homes[i]
				p.LocalTransparencyModifier = 0
			end
			passThrough(model, parts, collide)
			if not model.Parent then
				return
			end
			-- it locks: a stone snap, a bell, sparks and dust, a warm flash
			if mine then
				Sfx.play("padSnap")
				Sfx.play(model.Name:match("^mainhall") and "hallBell" or "smallBell")
				Sfx.play("land")
			end
			burst(Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 1, cf.Position.Z), JADE, 45, 24)
			local holder = fxPart(Vector3.one, CFrame.new(cf.Position + Vector3.new(0, size.Y * 0.2, 0)), JADE)
			holder.Transparency = 1
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 225, 160)
			light.Range = math.clamp(math.max(size.X, size.Z) * 1.2, 16, 50)
			light.Brightness = 5
			light.Parent = holder
			TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
			task.delay(1, function()
				holder:Destroy()
			end)
			task.delay(0.35, function()
				for _, e in effects do
					if e.Parent then
						e.Enabled = true
					end
				end
			end)
		end
	end)
end

sect.DescendantAdded:Connect(function(d)
	if d:IsA("Model") and d.Parent and d.Parent.Name == "Built" and d:GetAttribute("BuiltAt") then
		task.spawn(animateBuild, d)
	end
end)

---------------------------------------------------------------------------------------------
-- Every frame: rings turn, lights breathe, previews gather (near pads only)
local function updatePreview(rec, hrp, dt)
	local d = hrp and Vector3.new(rec.pad.Position.X - hrp.Position.X, 0, rec.pad.Position.Z - hrp.Position.Z).Magnitude or math.huge
	local target = math.clamp((PREVIEW_RANGE - d) / PREVIEW_FADE, 0, 1)
	rec.k += (target - rec.k) * math.min(1, dt * 5)
	local k = rec.k
	if k < 0.004 then
		if rec.previewShown then
			rec.previewShown = false
			rec.woke = false
			for _, p in rec.preview do
				p.LocalTransparencyModifier = 1
			end
			rec.lift = nil
			rec.ltm = nil
		end
		return
	end
	if not rec.woke and k > 0.02 then
		rec.woke = true
		Sfx.play("padWake")
	end
	rec.previewShown = true
	-- whole and in its real place; it rises the last stud and a half as it fades in, then breathes
	local ltm = 1 - k * (1 - SPIRIT_LTM) + 0.04 * k * math.sin(os.clock() * 2.2)
	if math.abs(ltm - (rec.ltm or -1)) >= LTM_STEP then
		rec.ltm = ltm
		for _, p in rec.preview do
			p.LocalTransparencyModifier = ltm
		end
	end
	local lift = (1 - k) * 1.5
	if math.abs(lift - (rec.lift or -1)) > 0.01 then
		rec.lift = lift
		for i in rec.preview do
			rec.cfs[i] = rec.homes[i] - Vector3.new(0, lift, 0)
		end
		workspace:BulkMoveTo(rec.preview, rec.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local camPos = workspace.CurrentCamera.CFrame.Position
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local t = os.clock()
	local function spin(arr, ready)
		local target = arr.pressing and 9 or (ready and 0.55 or 0)
		arr.kick = math.max(0, (arr.kick or 0) - dt * 8)
		arr.speed += (target + arr.kick - arr.speed) * math.min(1, dt * 4)
		arr.a1 += arr.speed * dt
		arr.a2 -= arr.speed * 1.3 * dt
		arr.place()
		local breath = 0.5 + 0.5 * math.sin(t * 2.4)
		if not arr.pressing then
			arr.light.Brightness = arr.glow and (1.2 + 0.8 * breath) or 0.35
			-- the ground ring pulses outward once per breath while ready
			local x = (t * 0.75) % 1
			arr.pulse.Size = Vector3.new(0.05, (5 + 4 * x) * arr.k, (5 + 4 * x) * arr.k)
			arr.pulse.Transparency = arr.glow and (0.3 + 0.7 * x) or 1
		end
	end
	for _, rec in pads do
		local dist = (rec.array.c.Position - camPos).Magnitude
		if not rec.still and dist < ANIM_RANGE then
			spin(rec.array, rec.ready)
		end
		-- only pads near the camera keep their light on (a peak has 10 shop pads, the hub more)
		local lit = not rec.still and dist < LIGHT_RANGE
		if rec.array.light.Enabled ~= lit then
			rec.array.light.Enabled = lit
		end
		if rec.preview then
			updatePreview(rec, hrp, dt)
		end
	end
	for arr in animating do
		local owned = false
		for _, rec in pads do
			if rec.array == arr then
				owned = true
			end
		end
		if not owned then
			spin(arr, true)
		end
	end
end)

-- a property write only when the value changed (R16 rule 4: each BillboardGui write redraws it)
local function put(obj, prop, value)
	if obj[prop] ~= value then
		obj[prop] = value
	end
end

-- Card text, affordability and stepping, a few times a second (cheap: a handful of pads)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local t0 = PerfMark.begin()
	local qi = player:GetAttribute("Qi") or 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	for pad, rec in pads do
		if not pad:IsDescendantOf(workspace) then
			rec.cleanup() -- a missed AncestryChanged must not leave a pad floating
			continue
		end
		local d = math.huge
		if hrp then
			local dy = hrp.Position.Y - pad.Position.Y
			if dy > -1 and dy < 7 then
				d = Vector3.new(pad.Position.X - hrp.Position.X, 0, pad.Position.Z - hrp.Position.Z).Magnitude
			end
		end
		local onPad = d < REACH
		if rec.shared then
			-- shop pads: the server opens the purchase; here the rings answer the step
			if onPad and not rec.wasOn then
				playPress(rec, false)
			end
			rec.wasOn = onPad
			continue
		end
		if not rec.mine then
			continue
		end
		local ok = qi >= rec.cost
		rec.onPad = d < 4
		-- built before and Auto Build on (D85): the beam turns gold and the wait reads "Auto in 0:13"
		local auto = pad:GetAttribute("Auto") == true and player:GetAttribute("AutoBuildOpen") == true and not player:GetAttribute("AutoBuildOff")
		if auto ~= rec.auto then
			rec.auto = auto
			setReady(rec, ok)
			put(rec.eta, "TextColor3", auto and AUTO_GOLD or PadLook.TEXT.wait)
		end
		if ok ~= rec.ready then
			setReady(rec, ok)
			if ok then
				playReady(rec)
			end
		end
		-- stepping onto a pad you can't afford yet: one soft "not yet" per visit
		if onPad and not ok and not rec.denied then
			rec.denied = true
			Sfx.play("deny")
			rec.array.kick = 2 -- a short twitch
		elseif not onPad then
			rec.denied = false
		end
		-- a beam right beside the camera would fill the screen: fade it out up close
		local camNear = Vector2.new(cam.CFrame.Position.X - pad.Position.X, cam.CFrame.Position.Z - pad.Position.Z).Magnitude < 14
		put(rec.beacon.core, "Enabled", not camNear)
		put(rec.beacon.glow, "Enabled", not camNear)
		-- far cards shrink so a distant pad never buries the HUD; near ones stay full size
		-- (in 0.05 steps, so a camera drifting by a stud does not redraw every card)
		local camDist = (cam.CFrame.Position - pad.Position).Magnitude
		put(rec.scale, "Scale", math.floor(math.clamp(40 / math.max(camDist, 1), 0.6, 1) * 20 + 0.5) / 20)
		-- up close the building is the focus: the card drops to just above the pad
		local near = (rec.k or 0) > 0.3
		if near ~= rec.cardLow then
			rec.cardLow = near
			TweenService:Create(rec.card, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, near and 2.6 or 5.5, 0) }):Play()
		end
		local need = onPad and not ok
		put(rec.costText.need, "Visible", need)
		put(rec.costText.more, "Visible", need)
		put(rec.costText.amount, "Text", need and fmt(rec.cost - qi) or fmt(rec.cost))
		local rate = player:GetAttribute("Rate") or 0
		local wait = not ok and rate > 0 and not pad:GetAttribute("FreeText")
		put(rec.eta, "Visible", wait)
		if wait then
			put(rec.eta, "Text", (rec.auto and "Auto " or "") .. etaText((rec.cost - qi) / rate))
		end
	end
	PerfMark.finish("padcards", t0)
end)

-- Auto Build (D85): a building that built itself gets a gold column from the sky on its pad, the
-- Heavenly Hands at work (the HUD shows the toast)
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify").OnClientEvent:Connect(function(kind, _, at)
	if kind ~= "autoBuilt" or typeof(at) ~= "Vector3" then
		return
	end
	local c = CFrame.new(at)
	Sfx.play("buyChime")
	column(c, AUTO_GOLD, 60, 7)
	ripple(c, AUTO_GOLD, 4, 16, 0.8)
	burst(at + Vector3.new(0, 0.6, 0), AUTO_GOLD, 24, 0)
end)
