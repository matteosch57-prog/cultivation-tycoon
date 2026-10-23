-- The ground glyph of the player aura (owner 2026-10-23: "the ground ones are too blurry, Warcraft 3
-- has different shapes"): a crisp array drawn with UI lines and circles on a SurfaceGui lying flat
-- under the feet, a different figure for every realm from 2 (rings, ticks, squares, hexagram,
-- pentagram, lotus petals, the eight trigrams), sharper and fuller with each realm. Two layers turn
-- opposite ways: each lies on its own flat part on a Motor6D from the root (tag "AuraSpin", attribute
-- Spin in degrees a second) whose Transform the client turns (AuraSpin.client): no server motion.
local AuraGlyph = {}

local PPS = 48 -- SurfaceGui pixels per stud

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
	s.Thickness = math.max(2, w * self.px / 1000)
	s.Parent = f
	f.Parent = self.gui
end

-- a straight line between two canvas points
function Draw:line(x0, y0, x1, y1, w, pale)
	local dx, dy = x1 - x0, y1 - y0
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale((x0 + x1) / 2, (y0 + y1) / 2)
	f.Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, math.max(2, w * self.px / 1000))
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
		s.Thickness = math.max(2, w * self.px / 1000)
		s.Parent = f
		f.Parent = self.gui
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

-- realm -> { outer layer (turns one way), inner layer (turns the other) }; widths in thousandths
local RECIPES = {
	[2] = { -- Qi Condensation: a ring and its marks
		function(d) d:ring(0.47, 14) d:ticks(12, 0.4, 0.47, 10, true) end,
		function(d) d:ring(0.28, 10, true) d:dots(4, 0.28, 0.035) end,
	},
	[3] = { -- Foundation Establishment: the square set in the circle
		function(d) d:ring(0.47, 14) d:ring(0.43, 6, true) d:star(4, 1, 0.43, 12) end,
		function(d) d:ring(0.22, 10, true) d:star(4, 1, 0.22, 8, 0.125, true) end,
	},
	[4] = { -- Core Formation: the hexagram
		function(d) d:ring(0.47, 14) d:ring(0.44, 6, true) d:ticks(24, 0.44, 0.47, 6) end,
		function(d) d:star(6, 2, 0.41, 12) d:ring(0.2, 10, true) d:dots(6, 0.41, 0.03, true) end,
	},
	[5] = { -- Nascent Soul: a lotus round the pentagram
		function(d) d:ring(0.48, 14) d:petals(12, 0.38, 0.17, 8, true) end,
		function(d) d:star(5, 2, 0.28, 12) d:ring(0.28, 8, true) end,
	},
	[6] = { -- Soul Transformation: the eight trigrams
		function(d) d:ring(0.48, 14) d:ring(0.3, 8, true) d:bagua(0.39, 0.1, 9) end,
		function(d) d:star(8, 3, 0.26, 9) d:ring(0.1, 8, true) end,
	},
	[7] = { -- Void Refinement: two squares turning against each other
		function(d) d:ring(0.48, 14) d:ticks(36, 0.44, 0.48, 6, true) d:star(4, 1, 0.44, 10) end,
		function(d) d:star(4, 1, 0.44, 10, 0.125, true) d:ring(0.22, 10) d:dots(8, 0.22, 0.03, true) end,
	},
	[8] = { -- Body Integration: trigrams round a hexagram
		function(d) d:ring(0.48, 16) d:ring(0.45, 6, true) d:bagua(0.37, 0.1, 9) end,
		function(d) d:star(6, 2, 0.27, 10, 0, true) d:ring(0.27, 8) d:petals(8, 0.14, 0.09, 7) end,
	},
	[9] = { -- Mahayana: the great lotus and the nine-point star
		function(d) d:ring(0.49, 16) d:ring(0.46, 6, true) d:petals(16, 0.37, 0.16, 8) end,
		function(d) d:star(9, 4, 0.28, 9, 0, true) d:ring(0.28, 8) d:ring(0.12, 8, true) end,
	},
	[10] = { -- True Immortal and up: the full array
		function(d) d:ring(0.49, 16) d:ring(0.46, 6, true) d:ticks(48, 0.43, 0.46, 5) d:bagua(0.36, 0.09, 9, true) end,
		function(d) d:star(12, 5, 0.27, 8) d:ring(0.27, 8, true) d:petals(12, 0.13, 0.09, 6, true) d:dots(12, 0.27, 0.02) end,
	},
}
local SPIN = { 14, -22 } -- degrees a second, outer and inner

-- builds the two layers for `realm` (2 and up) under `hrp` at the root-space offset `at`, diameter `D`
function AuraGlyph.build(folder, hrp, realm, at, D, color, pale, brightness)
	local recipe = RECIPES[math.clamp(realm, 2, 10)]
	for i, draw in recipe do
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
		draw(Draw.new(gui, D * PPS, color, pale))
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
