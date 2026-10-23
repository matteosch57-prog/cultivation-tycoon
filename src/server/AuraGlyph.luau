-- The ground glyph of the player aura (owner 2026-10-23: "the ground ones are too blurry, Warcraft 3
-- has different shapes"): a crisp array drawn with UI lines and circles on a SurfaceGui lying flat
-- under the feet, a different figure for every realm from 2 (rings, ticks, squares, hexagram,
-- pentagram, lotus petals, the eight trigrams), sharper and fuller with each realm. Two layers turn
-- opposite ways: each lies on its own flat part on a Motor6D from the root (tag "AuraSpin", attribute
-- Spin in degrees a second) whose Transform the client turns (AuraSpin.client): no server motion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AuraGlyph = {}

local PPS = 48 -- SurfaceGui pixels per stud
local BOLD = 1.4 -- every line width x this (owner 2026-10-23: colour and light a bit higher)

-- a point on the canvas (0..1 scale) at radius `r` (scale, 0.5 = the edge) and angle `a` (radians)
local function polar(r, a)
	return 0.5 + math.sin(a) * r, 0.5 - math.cos(a) * r
end

local Draw = {}
Draw.__index = Draw

function Draw.new(gui, px, color, pale)
	return setmetatable({ gui = gui, px = px, color = color, pale = pale }, Draw)
end

-- a circle outline of radius r, `w` = line width in canvas thousandths
function Draw:ring(r, w, pale)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(r * 2, r * 2)
	f.BackgroundTransparency = 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = pale and self.pale or self.color
	s.Thickness = math.max(2, w * BOLD * self.px / 1000)
	s.Parent = f
	f.Parent = self.gui
end

-- a straight line between two canvas points
function Draw:line(x0, y0, x1, y1, w, pale)
	local dx, dy = x1 - x0, y1 - y0
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale((x0 + x1) / 2, (y0 + y1) / 2)
	f.Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, math.max(2, w * BOLD * self.px / 1000))
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.BorderSizePixel = 0
	f.BackgroundColor3 = pale and self.pale or self.color
	f.Parent = self.gui
end

-- star polygon {n/k} on radius r (k = 1 is the plain polygon; {6/2} the hexagram, {5/2} the pentagram)
function Draw:star(n, k, r, w, turn, pale)
	for i = 0, n - 1 do
		local a0, a1 = (i / n + (turn or 0)) * math.pi * 2, ((i + k) / n + (turn or 0)) * math.pi * 2
		local x0, y0 = polar(r, a0)
		local x1, y1 = polar(r, a1)
		self:line(x0, y0, x1, y1, w, pale)
	end
end

-- n radial ticks from r0 to r1
function Draw:ticks(n, r0, r1, w, pale)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local x0, y0 = polar(r0, a)
		local x1, y1 = polar(r1, a)
		self:line(x0, y0, x1, y1, w, pale)
	end
end

-- n filled dots on radius r
function Draw:dots(n, r, d, pale)
	for i = 0, n - 1 do
		local x, y = polar(r, i / n * math.pi * 2)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(d, d)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = pale and self.pale or self.color
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = self.gui
	end
end

-- n lotus petals (outlined ovals pointing out) centred on radius r, `len` long
function Draw:petals(n, r, len, w, pale)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local x, y = polar(r, a)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(len * 0.42, len)
		f.Rotation = math.deg(a)
		f.BackgroundTransparency = 1
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Color = pale and self.pale or self.color
		s.Thickness = math.max(2, w * BOLD * self.px / 1000)
		s.Parent = f
		f.Parent = self.gui
	end
end

-- a soft filled disc of radius r (the light the array throws on the ground)
function Draw:disc(r, transparency)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(r * 2, r * 2)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = self.color
	f.BackgroundTransparency = transparency
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = self.gui
end

-- n thorns or flame tongues standing out from radius r, `h` high (Warcraft 3's Thorns Aura); `inward` points them in
function Draw:spikes(n, r, h, w, pale, inward)
	local half = math.pi / n * 0.55
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local tip = inward and r - h or r + h
		local x0, y0 = polar(r, a - half)
		local x1, y1 = polar(tip, a)
		local x2, y2 = polar(r, a + half)
		self:line(x0, y0, x1, y1, w, pale)
		self:line(x1, y1, x2, y2, w, pale)
	end
end

-- n chevrons pointing in at radius r (Endurance Aura's arrows), each `s` wide
function Draw:chevrons(n, r, s, w, pale)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local x1, y1 = polar(r - s * 0.5, a)
		local da = s / r * 0.6
		local x0, y0 = polar(r + s * 0.3, a - da)
		local x2, y2 = polar(r + s * 0.3, a + da)
		self:line(x0, y0, x1, y1, w, pale)
		self:line(x1, y1, x2, y2, w, pale)
	end
end

-- a ring of seal characters round radius r, each turned to face out from the centre
function Draw:script(text, r, size, pale)
	local chars = {}
	for _, c in utf8.codes(text) do
		table.insert(chars, utf8.char(c))
	end
	for i, ch in chars do
		local a = (i - 1) / #chars * math.pi * 2
		local x, y = polar(r, a)
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(x, y)
		t.Size = UDim2.fromScale(size, size)
		t.Rotation = math.deg(a)
		t.BackgroundTransparency = 1
		t.Text = ch
		t.TextScaled = true
		t.Font = Enum.Font.SourceSansBold
		t.TextColor3 = pale and self.pale or self.color
		t.Parent = self.gui
	end
end

-- the taiji at the centre: its circle, the S between the halves (two half rings) and the two eyes
function Draw:taiji(r, w, pale)
	self:ring(r, w, pale)
	for side = -1, 1, 2 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5 + side * r / 2)
		f.Size = UDim2.fromScale(r, r)
		f.BackgroundTransparency = 1
		f.ClipsDescendants = false
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Color = pale and self.pale or self.color
		s.Thickness = math.max(2, w * 0.7 * BOLD * self.px / 1000)
		s.Transparency = 0.35
		s.Parent = f
		f.Parent = self.gui
		local x, y = 0.5, 0.5 + side * r / 2
		local e = Instance.new("Frame")
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		e.Position = UDim2.fromScale(x, y)
		e.Size = UDim2.fromScale(r * 0.25, r * 0.25)
		e.BorderSizePixel = 0
		e.BackgroundColor3 = pale and self.pale or self.color
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0.5, 0)
		ec.Parent = e
		e.Parent = self.gui
	end
end

-- the eight trigrams round radius r (King Wen's later heaven order; a 0 bar is broken)
local TRIGRAMS = { { 1, 0, 1 }, { 0, 0, 1 }, { 1, 1, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 1, 0, 0 }, { 1, 1, 1 }, { 0, 1, 1 } }
function Draw:bagua(r, size, w, pale)
	for i, bars in TRIGRAMS do
		local a = (i - 1) / 8 * math.pi * 2
		local tx, ty = math.cos(a), math.sin(a) -- along the ring (tangent)
		for b, whole in bars do
			local cx, cy = polar(r + (b - 2) * size * 0.32, a)
			local h = size / 2
			if whole == 1 then
				self:line(cx - tx * h, cy - ty * h, cx + tx * h, cy + ty * h, w, pale)
			else
				local g = size * 0.12
				self:line(cx - tx * h, cy - ty * h, cx - tx * g, cy - ty * g, w, pale)
				self:line(cx + tx * g, cy + ty * g, cx + tx * h, cy + ty * h, w, pale)
			end
		end
	end
end

-- realm -> { outer layer (turns one way), inner layer (turns the other) }; widths in thousandths.
-- Every realm has its own silhouette (owner: "more difference between each"): sun rays, the square
-- with arrows in, the hexagram, the lotus, the trigrams round a taiji, thorns, the 28 mansions, the
-- great lotus in rays, and a ring of seal characters from realm 6.
local RECIPES = {
	[2] = { -- Qi Condensation 气: a ring throwing short sun rays (Devotion Aura)
		function(d) d:disc(0.47, 0.88) d:ring(0.4, 16) d:ticks(16, 0.43, 0.49, 12, true) end,
		function(d) d:ring(0.24, 10, true) d:dots(4, 0.24, 0.04) end,
	},
	[3] = { -- Foundation Establishment 基: the square in the circle, four arrows pointing in
		function(d) d:disc(0.47, 0.88) d:ring(0.47, 16) d:star(4, 1, 0.45, 12) d:chevrons(4, 0.36, 0.08, 10, true) end,
		function(d) d:ring(0.2, 10, true) d:star(4, 1, 0.2, 8, 0.125) d:dots(4, 0.2, 0.035, true) end,
	},
	[4] = { -- Core Formation 丹: the hexagram in a marked ring
		function(d) d:disc(0.47, 0.86) d:ring(0.47, 16) d:ring(0.43, 6, true) d:ticks(24, 0.43, 0.47, 7) end,
		function(d) d:star(6, 2, 0.4, 13) d:ring(0.2, 10, true) d:dots(6, 0.4, 0.04, true) d:dots(1, 0, 0.06) end,
	},
	[5] = { -- Nascent Soul 婴: a lotus opening round the pentagram (the five elements)
		function(d) d:disc(0.47, 0.86) d:ring(0.48, 14) d:petals(12, 0.37, 0.18, 10, true) d:petals(12, 0.4, 0.1, 6) end,
		function(d) d:star(5, 2, 0.27, 13) d:ring(0.27, 8, true) d:dots(5, 0.27, 0.045, true) end,
	},
	[6] = { -- Soul Transformation 神: the eight trigrams round the taiji, seal script outside
		function(d) d:disc(0.47, 0.85) d:ring(0.49, 14) d:ring(0.42, 8, true) d:script("神識化形神識化形神識化形", 0.455, 0.05, true) d:bagua(0.34, 0.09, 10) end,
		function(d) d:taiji(0.17, 10, true) end,
	},
	[7] = { -- Void Refinement 虚: thorns round two squares turning apart (Thorns Aura)
		function(d) d:disc(0.44, 0.85) d:ring(0.42, 14) d:spikes(16, 0.42, 0.07, 9, true) d:star(4, 1, 0.42, 11) end,
		function(d) d:star(4, 1, 0.42, 11, 0.125, true) d:ring(0.2, 10) d:dots(8, 0.2, 0.035, true) d:taiji(0.1, 8) end,
	},
	[8] = { -- Body Integration 合: the 28 lunar mansions round trigrams and a hexagram
		function(d) d:disc(0.47, 0.84) d:ring(0.49, 16) d:ticks(28, 0.45, 0.49, 7, true) d:dots(28, 0.47, 0.012) d:ring(0.45, 6, true) d:bagua(0.37, 0.09, 10) end,
		function(d) d:star(6, 2, 0.27, 11, 0, true) d:ring(0.27, 9) d:petals(8, 0.14, 0.09, 8) end,
	},
	[9] = { -- Mahayana 乘: the great lotus in a crown of rays, the nine-point star
		function(d) d:disc(0.45, 0.83) d:ticks(36, 0.44, 0.5, 8, true) d:ring(0.44, 16) d:petals(16, 0.35, 0.16, 10) d:script("大乘渡世大乘渡世", 0.47, 0.05) end,
		function(d) d:star(9, 4, 0.27, 10, 0, true) d:ring(0.27, 9) d:ring(0.11, 9, true) d:dots(9, 0.27, 0.035) end,
	},
	[10] = { -- True Immortal 仙 and up: the full array, seal script, trigrams, star, taiji
		function(d) d:disc(0.47, 0.82) d:ticks(48, 0.46, 0.5, 6, true) d:ring(0.46, 18) d:script("真仙不朽天地同壽真仙不朽天地同壽", 0.42, 0.045, true) d:ring(0.385, 7) d:bagua(0.32, 0.075, 10, true) end,
		function(d) d:star(12, 5, 0.25, 9) d:ring(0.25, 9, true) d:spikes(12, 0.25, 0.05, 7) d:taiji(0.12, 9, true) end,
	},
}
local SPIN = { 14, -22 } -- degrees a second, outer and inner

-- builds the two layers for `realm` (2 and up) under `hrp` at the root-space offset `at`, diameter `D`
-- the uploaded WC3-style textures for `realm` (owner pick 2026-10-23, tools/aura_textures.py), or nil
-- while they are not uploaded yet (Config.AURA_TEX ids 0): then the UI-drawn RECIPES stand in
local function textures(realm)
	local t = Config.AURA_TEX.realms[math.clamp(realm, 2, 10)]
	return t and t[1] ~= 0 and t[2] ~= 0 and t or nil
end

local function image(gui, id, color, transparency, z)
	local im = Instance.new("ImageLabel")
	im.Size = UDim2.fromScale(1, 1)
	im.BackgroundTransparency = 1
	im.Image = "rbxassetid://" .. id
	im.ImageColor3 = color
	im.ImageTransparency = transparency
	im.ZIndex = z
	im.Parent = gui
end

-- builds the two layers for `realm` (2 and up) under `hrp` at the root-space offset `at`, diameter `D`
function AuraGlyph.build(folder, hrp, realm, at, D, color, pale, brightness)
	local tex = textures(realm)
	local recipe = RECIPES[math.clamp(realm, 2, 10)]
	for i = 1, 2 do
		local p = Instance.new("Part")
		p.Name = "AuraGlyph" .. i
		p.Size = Vector3.new(D, 0.05, D)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.CFrame = hrp.CFrame * at * CFrame.new(0, i * 0.02, 0)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PPS
		gui.LightInfluence = 0
		gui.Brightness = brightness
		gui.ZOffset = i
		gui.MaxDistance = 160
		gui.Parent = p
		if tex then
			-- the outer layer in the realm colour over the shared glow, the inner one pale
			if i == 1 and Config.AURA_TEX.glow ~= 0 then
				image(gui, Config.AURA_TEX.glow, color, 0.35, 1)
			end
			image(gui, tex[i], i == 1 and color or pale, 0, 2)
		else
			recipe[i](Draw.new(gui, D * PPS, color, pale))
		end
		local m = Instance.new("Motor6D")
		m.Name = "AuraSpin"
		m.Part0 = hrp
		m.Part1 = p
		m.C0 = at * CFrame.new(0, i * 0.02, 0)
		m:SetAttribute("Spin", SPIN[i])
		m:AddTag("AuraSpin")
		m.Parent = p
		p.Parent = folder
	end
end

return AuraGlyph
