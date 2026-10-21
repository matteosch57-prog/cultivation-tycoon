-- The building kit: small pieces, each finished on its own, that bigger buildings are assembled
-- from (piece -> bay -> hall). Learned from the 2026-10-21 study of reference temple halls:
-- detail lives at eye level (railings, lattice, brackets) and comes from repetition of one clean
-- piece, not from one-off geometry. Every function takes a world CFrame at the piece's base,
-- front facing +Z, and parents parts to `parent`. Palette = Style.PAL (docs/art/ART_BIBLE.md).
local Style = require(script.Parent:WaitForChild("Style"))

local Kit = {}
local P = Style.P
local PAL = Style.PAL

Kit.RED = Color3.fromHex("B8352B")
Kit.RED_DARK = Color3.fromHex("8E2620")
Kit.PAINT_BLUE = Color3.fromHex("2E5A8C")
Kit.PAINT_GREEN = Color3.fromHex("2F6F55")

local function cylY(parent, height, dia, cf, color, mat)
	return P(parent, Vector3.new(height, dia, dia), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

-- Column: stone drum, red shaft, gold collar, timber capital block. Returns the top CFrame.
function Kit.column(parent, cf, h, dia)
	dia = dia or 1.2
	cylY(parent, 0.5, dia + 0.7, cf * CFrame.new(0, 0.25, 0), PAL.stone)
	cylY(parent, 0.25, dia + 0.35, cf * CFrame.new(0, 0.62, 0), PAL.stoneLight)
	cylY(parent, h - 0.75, dia, cf * CFrame.new(0, 0.75 + (h - 0.75) / 2, 0), Kit.RED)
	cylY(parent, 0.3, dia + 0.15, cf * CFrame.new(0, h - 0.55, 0), PAL.gold)
	P(parent, Vector3.new(dia + 0.3, 0.45, dia + 0.3), cf * CFrame.new(0, h + 0.2, 0), PAL.timber)
	return cf * CFrame.new(0, h + 0.45, 0)
end

-- Railing from a to b (both at deck level, world space): top and bottom rails, a post every
-- ~3 studs with a round cap, and a hui (nested square) panel between posts.
function Kit.railing(parent, a, b, h)
	h = h or 2.2
	local len = (b - a).Magnitude
	if len < 0.5 then
		return
	end
	local cf = CFrame.lookAt(a, b) * CFrame.Angles(0, math.pi / 2, 0) -- local +X runs a -> b
	local n = math.max(1, math.round(len / 3))
	local step = len / n
	P(parent, Vector3.new(len, 0.25, 0.3), cf * CFrame.new(len / 2, h - 0.15, 0), Kit.RED)
	P(parent, Vector3.new(len, 0.2, 0.25), cf * CFrame.new(len / 2, 0.35, 0), Kit.RED)
	for i = 0, n do
		local x = i * step
		P(parent, Vector3.new(0.4, h + 0.2, 0.4), cf * CFrame.new(x, (h + 0.2) / 2, 0), Kit.RED)
		P(parent, Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(x, h + 0.45, 0), PAL.gold, nil, Enum.PartType.Ball)
		if i < n then
			-- the hui panel: an inner frame of four thin bars
			local cx, w, ph = x + step / 2, step - 1.0, h - 1.2
			local cy = 0.45 + ph / 2 + 0.15
			P(parent, Vector3.new(w, 0.12, 0.14), cf * CFrame.new(cx, cy + ph / 2, 0), Kit.RED_DARK)
			P(parent, Vector3.new(w, 0.12, 0.14), cf * CFrame.new(cx, cy - ph / 2, 0), Kit.RED_DARK)
			P(parent, Vector3.new(0.12, ph, 0.14), cf * CFrame.new(cx - w / 2, cy, 0), Kit.RED_DARK)
			P(parent, Vector3.new(0.12, ph, 0.14), cf * CFrame.new(cx + w / 2, cy, 0), Kit.RED_DARK)
		end
	end
end

-- Lattice panel (door or window): a red frame around a dark panel with a gold-cream lattice.
-- `texture` (Content) paints the lattice in one decal; without it the lattice is built from bars.
function Kit.panel(parent, cf, w, h, texture)
	local board = P(parent, Vector3.new(w, h, 0.25), cf * CFrame.new(0, h / 2, 0), PAL.timberDark)
	if texture then
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Front
		d.TextureContent = texture
		d.Parent = board
	else
		local bar = PAL.gold:Lerp(PAL.plaster, 0.35)
		local inset = 0.35
		for k = 0, 1 do
			local iw, ih = w - inset * 2 - k * 1.1, h - inset * 2 - k * 1.4
			local z = 0.16
			P(parent, Vector3.new(iw, 0.12, 0.1), cf * CFrame.new(0, h / 2 + ih / 2, z), bar)
			P(parent, Vector3.new(iw, 0.12, 0.1), cf * CFrame.new(0, h / 2 - ih / 2, z), bar)
			P(parent, Vector3.new(0.12, ih, 0.1), cf * CFrame.new(-iw / 2, h / 2, z), bar)
			P(parent, Vector3.new(0.12, ih, 0.1), cf * CFrame.new(iw / 2, h / 2, z), bar)
		end
		P(parent, Vector3.new(0.12, h - inset * 2, 0.1), cf * CFrame.new(0, h / 2, 0.16), bar)
		P(parent, Vector3.new(w - inset * 2, 0.12, 0.1), cf * CFrame.new(0, h / 2, 0.16), bar)
	end
	-- frame
	P(parent, Vector3.new(w + 0.4, 0.35, 0.4), cf * CFrame.new(0, h + 0.1, 0.05), Kit.RED)
	P(parent, Vector3.new(w + 0.4, 0.35, 0.4), cf * CFrame.new(0, 0.1, 0.05), Kit.RED)
	P(parent, Vector3.new(0.35, h, 0.4), cf * CFrame.new(-w / 2 - 0.05, h / 2, 0.05), Kit.RED)
	P(parent, Vector3.new(0.35, h, 0.4), cf * CFrame.new(w / 2 + 0.05, h / 2, 0.05), Kit.RED)
end

-- Bracket set (dougong) on a column top: three tiers of blocks and arms, each tier wider and
-- projecting further, with painted ends. Returns the height it adds.
function Kit.bracket(parent, cf, scale)
	local s = scale or 1
	-- slim timber arms, centred both ways (a cross), each tier wider; only the arm tips are
	-- painted, as thin caps, so the set reads as carved wood and not as stacked blocks
	local tiers = {
		{ arm = 1.5, paint = Kit.PAINT_GREEN },
		{ arm = 2.3, paint = Kit.PAINT_BLUE },
		{ arm = 3.1, paint = Kit.PAINT_GREEN },
	}
	local th, tw = 0.32 * s, 0.34 * s
	local y = 0
	P(parent, Vector3.new(0.9 * s, 0.4 * s, 0.9 * s), cf * CFrame.new(0, 0.2 * s, 0), PAL.timber) -- bearing block
	y += 0.4 * s
	for _, t in tiers do
		local a = t.arm * s
		local at = cf * CFrame.new(0, y + th / 2, 0)
		P(parent, Vector3.new(a, th, tw), at, PAL.timber)
		P(parent, Vector3.new(tw, th, a), at, PAL.timber)
		local capX = Vector3.new(0.18 * s, th * 1.05, tw + 0.04)
		local capZ = Vector3.new(tw + 0.04, th * 1.05, 0.18 * s)
		for _, sx in { -1, 1 } do
			P(parent, capX, at * CFrame.new(sx * a / 2, 0, 0), t.paint)
			P(parent, capZ, at * CFrame.new(0, 0, sx * a / 2), t.paint)
		end
		-- a small block on the arm, carrying the next tier
		P(parent, Vector3.new(0.5 * s, th, 0.5 * s), at * CFrame.new(0, th, 0), PAL.timberDark)
		y += th * 2
	end
	return y
end

-- Eave edge from a to b: a row of round tile ends (one instanced low-poly cylinder each)
-- under a gold drip line. The roof surface itself is Style.roof.
function Kit.tileEnds(parent, a, b, color)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b) * CFrame.Angles(0, math.pi / 2, 0)
	local n = math.max(2, math.floor(len / 0.9))
	for i = 0, n do
		local x = i * len / n
		-- a short cylinder pointing out of the roof edge (local -Z), so its round face shows
		P(parent, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), color or PAL.gold, nil, Enum.PartType.Cylinder)
	end
	P(parent, Vector3.new(len + 0.4, 0.18, 0.25), cf * CFrame.new(len / 2, -0.4, 0.05), PAL.gold)
end

-- Stone platform with a front stair; a railing runs round the deck edge, open at the stair.
-- Returns the deck CFrame (top surface).
function Kit.platform(parent, cf, W, D, h, stairW)
	P(parent, Vector3.new(W + 0.8, h - 0.4, D + 0.8), cf * CFrame.new(0, (h - 0.4) / 2, 0), PAL.stone)
	P(parent, Vector3.new(W, 0.4, D), cf * CFrame.new(0, h - 0.2, 0), PAL.stoneLight)
	local steps = math.max(2, math.round(h / 0.6))
	local sh, run = h / steps, 1.2
	for i = 1, steps do
		P(parent, Vector3.new(stairW, sh * i, run), cf * CFrame.new(0, sh * i / 2, D / 2 + (steps - i + 0.5) * run), PAL.stoneLight)
	end
	for _, sx in { -1, 1 } do
		local x = sx * (stairW / 2 + 0.4)
		local a = cf * Vector3.new(x, h + 0.3, D / 2)
		local b = cf * Vector3.new(x, 0.6, D / 2 + steps * run)
		P(parent, Vector3.new(0.8, 1.0, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), PAL.stone)
	end
	local deck = cf * CFrame.new(0, h, 0)
	local e = 0.5 -- railing inset from the deck edge
	local function at(x, z)
		return (deck * CFrame.new(x, 0, z)).Position
	end
	Kit.railing(parent, at(-W / 2 + e, D / 2 - e), at(-stairW / 2 - 0.8, D / 2 - e))
	Kit.railing(parent, at(stairW / 2 + 0.8, D / 2 - e), at(W / 2 - e, D / 2 - e))
	Kit.railing(parent, at(-W / 2 + e, -D / 2 + e), at(-W / 2 + e, D / 2 - e))
	Kit.railing(parent, at(W / 2 - e, -D / 2 + e), at(W / 2 - e, D / 2 - e))
	return deck
end

-- A hall assembled from the pieces: platform, a grid of columns with brackets, a red
-- architrave and painted frieze, lattice panels in every front bay behind a porch, plaster
-- walls, then one or two tiled roofs. Long and low, like the reference halls.
-- opts: bays (front), bay (width of one), depth (bays deep), colH, plinth, tile, two (double roof)
function Kit.hall(parent, cf, opts)
	opts = opts or {}
	local nb, bw, nd = opts.bays or 5, opts.bay or 6.5, opts.depth or 2
	local colH = opts.colH or 8
	local W, D = nb * bw, nd * bw
	local m = Instance.new("Model")
	m.Name = opts.name or "KitHall"
	local deck = Kit.platform(m, cf, W + 7, D + 7, opts.plinth or 2, bw * 1.3)
	-- columns + brackets on the outer ring
	local function colAt(x, z)
		local top = Kit.column(m, deck * CFrame.new(x, 0, z), colH)
		Kit.bracket(m, top)
	end
	for i = 0, nb do
		local x = -W / 2 + i * bw
		colAt(x, D / 2)
		colAt(x, -D / 2)
	end
	for j = 1, nd - 1 do
		colAt(-W / 2, -D / 2 + j * bw)
		colAt(W / 2, -D / 2 + j * bw)
	end
	-- architrave (red + gold) and the painted frieze above it, right round
	local beamY = colH + 0.95
	for _, s in { { W, 0, D / 2 }, { W, 0, -D / 2 } } do
		P(m, Vector3.new(W + 1, 0.9, 0.8), deck * CFrame.new(0, beamY - 0.45, s[3]), Kit.RED)
		P(m, Vector3.new(W + 1.1, 0.2, 0.9), deck * CFrame.new(0, beamY - 0.95, s[3]), PAL.gold)
	end
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.8, 0.9, D + 1), deck * CFrame.new(sx * W / 2, beamY - 0.45, 0), Kit.RED)
		P(m, Vector3.new(0.9, 0.2, D + 1.1), deck * CFrame.new(sx * W / 2, beamY - 0.95, 0), PAL.gold)
	end
	-- walls: plaster back and sides, a porch in front (panels set back one stud)
	local wz = D / 2 - 1.2
	P(m, Vector3.new(W - 0.4, colH, 0.6), deck * CFrame.new(0, colH / 2, -D / 2 + 0.3), PAL.plaster, Enum.Material.Plaster)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.6, colH, D - 0.4), deck * CFrame.new(sx * (W / 2 - 0.3), colH / 2, 0), PAL.plaster, Enum.Material.Plaster)
	end
	for i = 0, nb - 1 do
		local x = -W / 2 + (i + 0.5) * bw
		Kit.panel(m, deck * CFrame.new(x, 0.3, wz), bw - 1.6, colH - 1.6, opts.lattice)
		P(m, Vector3.new(bw - 0.4, 1.0, 0.5), deck * CFrame.new(x, colH - 0.6, wz), PAL.plaster, Enum.Material.Plaster)
	end
	P(m, Vector3.new(W, 0.4, D), deck * CFrame.new(0, colH + 0.2, 0), PAL.timberDark) -- ceiling
	if opts.plaque and not opts.two and nb % 2 == 1 then
		-- one roof: the name board hangs in the middle bay, under the architrave
		Kit.plaque(m, deck * CFrame.new(0, colH - 0.85, D / 2 + 0.3), math.min(bw - 1.4, 5), 1.4, opts.plaque)
	end
	-- roofs: eave line just above the bracket tops
	local eaveY = colH + 2.6
	local tile = opts.tile or PAL.tile
	local ridge = tile:Lerp(Color3.new(0, 0, 0), 0.3)
	local ro = { tile = tile, ridge = ridge, kit2 = true, corbels = false, tileEnds = true }
	if opts.two then
		local W2, D2 = W - bw * 1.2, D - bw * 0.6
		local R1 = D / 2 + 4
		local skirt = table.clone(ro)
		skirt.rise, skirt.over, skirt.tStart, skirt.rows = 3.2, 4, (D2 / 2) / R1, 3
		local yfn = Style.roof(m, deck * CFrame.new(0, eaveY, 0), W, D, skirt)
		local joint = eaveY + yfn((D2 / 2) / R1)
		local upH = 3.4
		P(m, Vector3.new(W2, upH + 0.6, D2), deck * CFrame.new(0, joint + upH / 2, 0), PAL.plaster, Enum.Material.Plaster)
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(W2 + 0.3, 0.6, 0.4), deck * CFrame.new(0, joint + upH - 0.2, sz * (D2 / 2 + 0.05)), Kit.RED)
			P(m, Vector3.new(W2 + 0.3, 0.9, 0.4), deck * CFrame.new(0, joint + upH - 1.0, sz * (D2 / 2 + 0.05)), Kit.PAINT_GREEN)
		end
		if opts.plaque then
			-- two roofs: the name board sits between the eaves, on the upper storey's front
			Kit.plaque(m, deck * CFrame.new(0, joint + 0.95, D2 / 2 + 0.25), math.min(W2 * 0.6, 9), 1.6, opts.plaque)
		end
		local top = table.clone(ro)
		top.rise, top.over, top.rows = D2 * 0.32, 3.5, 5
		Style.roof(m, deck * CFrame.new(0, joint + upH + 0.6, 0), W2 + 1, D2 + 1, top)
	else
		local one = table.clone(ro)
		one.rise, one.over, one.rows = D * 0.33, 4, 5
		Style.roof(m, deck * CFrame.new(0, eaveY, 0), W, D, one)
	end
	m.Parent = parent
	return m
end

-- The Main Hall, five levels of one building, each a complete kit hall that grows in bays,
-- depth and roofs (the caller removes the previous level). Level 5 gets gold tiles and towers.
-- Footprints stay inside Main.server's keepClear box (|x| < 38, -58 < z < -14 around the peak).
local GOLD_TILE = Color3.fromHex("D9A43A")
local LEVELS = {
	{ bays = 2, bay = 5, depth = 1, colH = 6, plinth = 1, tile = Color3.fromHex("8C6A44") }, -- humble timber hall
	{ bays = 3, bay = 5.5, depth = 2, colH = 7, plinth = 1.6 },
	{ bays = 5, bay = 6, depth = 2, colH = 8, plinth = 2, two = true },
	{ bays = 5, bay = 6, depth = 2, colH = 8, plinth = 2.4, two = true, wings = true },
	{ bays = 6, bay = 6, depth = 2, colH = 9, plinth = 2.8, two = true, wings = true, tile = GOLD_TILE, towers = true },
}
function Kit.mainHall(parent, cf, level, title)
	local L = LEVELS[math.clamp(level, 1, #LEVELS)]
	local m = Instance.new("Model")
	m.Name = "MainHall" .. level
	Kit.hall(m, cf, { bays = L.bays, bay = L.bay, depth = L.depth, colH = L.colH, plinth = L.plinth, two = L.two, tile = L.tile, name = "Core", plaque = title })
	local coreHalf = (L.bays * L.bay + 7) / 2
	if L.wings then
		for _, sx in { -1, 1 } do
			local x = sx * (coreHalf + 8.5)
			Kit.hall(m, cf * CFrame.new(x, 0, 2), { bays = 2, bay = 4.5, depth = 1, colH = 6, plinth = L.plinth - 0.6, tile = L.tile, name = "Wing" })
		end
	end
	if L.towers then
		for _, sx in { -1, 1 } do
			Style.pagoda(m, cf * CFrame.new(sx * 22, 0, -16), 6, 1, 3, 3)
		end
	end
	m.Parent = parent
	return m
end

-- Name board: a dark board in a gold frame with the name in gold. cf = the board's centre,
-- front facing +Z. Returns the board (callers that rename it later find the TextLabel "Name").
function Kit.plaque(parent, cf, w, h, text)
	P(parent, Vector3.new(w + 0.4, h + 0.4, 0.2), cf * CFrame.new(0, 0, -0.15), PAL.gold)
	local board = P(parent, Vector3.new(w, h, 0.3), cf, PAL.timberDark)
	board.Name = "Plaque"
	if text then
		local gui = Instance.new("SurfaceGui")
		-- the board faces +Z, which is its Back face (Front = LookVector = -Z: the text sat on the
		-- side against the frame and every board read blank in Play)
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud -- (FixedSize squashed the text)
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.6 -- stays readable in the porch shade
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "Name"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.Fantasy
		label.TextColor3 = Color3.fromRGB(255, 214, 110)
		label.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.06, 0)
		pad.PaddingRight = UDim.new(0.06, 0)
		pad.PaddingTop = UDim.new(0.08, 0)
		pad.PaddingBottom = UDim.new(0.08, 0)
		pad.Parent = label
		label.Parent = gui
	end
	return board
end

-- Columns with bracket sets at every (x, z) under `base`; shared by the gate, the pavilion and
-- the bell tower. Returns the eave height above `base` (just over the bracket tops).
local function columnsWithBrackets(parent, base, xs, zs, colH, bracketScale)
	for _, x in xs do
		for _, z in zs do
			local top = Kit.column(parent, base * CFrame.new(x, 0, z), colH, 1.1)
			Kit.bracket(parent, top, bracketScale)
		end
	end
	return colH + 0.45 + (0.4 + 6 * 0.32) * bracketScale
end

local function kitRoof(parent, cf, W, D, rise, over, rows)
	Style.roof(parent, cf, W, D, { rise = rise, over = over, rows = rows, kit2 = true, corbels = false, tileEnds = true, ridge = PAL.tile:Lerp(Color3.new(0, 0, 0), 0.3) })
end

-- Gate (paifang): two kit columns on stone drums, a red double beam with the painted frieze
-- and the name board between, bracket sets along the top, one kit roof with tile ends.
-- Returns the plaque board (front = +Z of cf).
function Kit.gate(parent, cf, width, height, text)
	local m = Instance.new("Model")
	m.Name = "Gate"
	for _, sx in { -1, 1 } do
		local at = cf * CFrame.new(sx * width / 2, 0, 0)
		P(m, Vector3.new(2.6, 1.0, 2.6), at * CFrame.new(0, 0.5, 0), PAL.stone)
		P(m, Vector3.new(1.0, 2.6, 3.8), at * CFrame.new(0, 1.3, 0), PAL.stoneLight) -- drum braces
	end
	local eave = columnsWithBrackets(m, cf, { -width / 2, width / 2 }, { 0 }, height, 0.8)
	local span = width + 2.4
	-- upper beam on the column tops, the painted frieze, lower beam under the board
	P(m, Vector3.new(span, 0.9, 1.0), cf * CFrame.new(0, height - 0.15, 0), Kit.RED)
	P(m, Vector3.new(span + 0.1, 0.18, 1.1), cf * CFrame.new(0, height - 0.65, 0), PAL.gold)
	P(m, Vector3.new(width - 1, 1.5, 0.7), cf * CFrame.new(0, height - 1.55, 0), Kit.PAINT_GREEN)
	P(m, Vector3.new(width - 0.6, 0.8, 0.9), cf * CFrame.new(0, height - 2.7, 0), Kit.RED)
	P(m, Vector3.new(width - 0.5, 0.15, 1.0), cf * CFrame.new(0, height - 3.15, 0), PAL.gold)
	-- more bracket sets riding the upper beam between the columns
	local n = math.max(1, math.floor(width / 4))
	for k = 1, n - 1 do
		Kit.bracket(m, cf * CFrame.new(-width / 2 + k * width / n, height + 0.3, 0), 0.8)
	end
	local plaque = Kit.plaque(m, cf * CFrame.new(0, height - 1.6, 0.55), math.min(7, width * 0.5), 1.6, text)
	kitRoof(m, cf * CFrame.new(0, eave, 0), span + 1.6, 3, 2, 1.6, 3)
	m.Parent = parent
	return plaque
end

-- Open pavilion: a kit platform (railing round three sides), four columns with bracket sets, a
-- red frame and one square kit roof. Returns the model and the deck height.
function Kit.pavilion(parent, cf, w, colH)
	local m = Instance.new("Model")
	m.Name = "Pavilion"
	local h = 1.2
	local deck = Kit.platform(m, cf, w + 3, w + 3, h, 4.5)
	local eave = columnsWithBrackets(m, deck, { -w / 2, w / 2 }, { -w / 2, w / 2 }, colH, 0.8)
	for _, s in { -1, 1 } do
		P(m, Vector3.new(w + 1.1, 0.8, 0.8), deck * CFrame.new(0, colH + 0.05, s * w / 2), Kit.RED)
		P(m, Vector3.new(0.8, 0.8, w + 1.1), deck * CFrame.new(s * w / 2, colH + 0.05, 0), Kit.RED)
		P(m, Vector3.new(w + 1.2, 0.18, 0.9), deck * CFrame.new(0, colH - 0.42, s * w / 2), PAL.gold)
		P(m, Vector3.new(0.9, 0.18, w + 1.2), deck * CFrame.new(s * w / 2, colH - 0.42, 0), PAL.gold)
	end
	P(m, Vector3.new(w + 0.6, 0.3, w + 0.6), deck * CFrame.new(0, colH + 0.6, 0), PAL.timberDark) -- ceiling
	kitRoof(m, deck * CFrame.new(0, eave, 0), w + 1, w + 1, w * 0.3, 3, 5)
	m.Parent = parent
	return m, h
end

-- Bell tower: a kit platform, a stone lower storey with a lattice door and the name board, a
-- railed upper deck on kit columns holding the bronze bell, one square kit roof.
function Kit.bellTower(parent, cf, text)
	local m = Instance.new("Model")
	m.Name = "BellTower"
	local deck = Kit.platform(m, cf, 12, 12, 1.4, 4.5)
	P(m, Vector3.new(8, 5, 8), deck * CFrame.new(0, 2.5, 0), PAL.stoneLight) -- solid lower storey
	Kit.panel(m, deck * CFrame.new(0, 0, 4.05), 2.6, 3.4, nil)
	P(m, Vector3.new(9, 0.5, 9), deck * CFrame.new(0, 5.25, 0), Kit.RED) -- upper deck
	P(m, Vector3.new(9.1, 0.15, 9.1), deck * CFrame.new(0, 4.95, 0), PAL.gold)
	if text then
		Kit.plaque(m, deck * CFrame.new(0, 4.25, 4.2), 4.6, 1.0, text)
	end
	local upper = deck * CFrame.new(0, 5.5, 0)
	local c = 3.6
	local eave = columnsWithBrackets(m, upper, { -c, c }, { -c, c }, 6, 0.7)
	for _, s in { { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } } do
		Kit.railing(m, (upper * CFrame.new(s[1] * c, 0, s[2] * c)).Position, (upper * CFrame.new(s[3] * c, 0, s[4] * c)).Position, 1.6)
	end
	for _, s in { -1, 1 } do
		P(m, Vector3.new(c * 2 + 1, 0.7, 0.7), upper * CFrame.new(0, 6.05, s * c), Kit.RED)
		P(m, Vector3.new(0.7, 0.7, c * 2 + 1), upper * CFrame.new(s * c, 6.05, 0), Kit.RED)
	end
	-- the bronze bell hanging from a beam, and the striker log
	local bronze = Color3.fromHex("7A5A3A")
	P(m, Vector3.new(c * 2, 0.5, 0.5), upper * CFrame.new(0, 5.6, 0), PAL.timberDark)
	cylY(m, 2.8, 2.4, upper * CFrame.new(0, 3.7, 0), bronze, Enum.Material.Metal)
	cylY(m, 0.4, 2.8, upper * CFrame.new(0, 2.35, 0), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(2.4, 2.4, 2.4), upper * CFrame.new(0, 5, 0), bronze, Enum.Material.Metal, Enum.PartType.Ball)
	P(m, Vector3.new(0.5, 0.5, 3.6), upper * CFrame.new(2.4, 3.4, 0), PAL.timber)
	P(m, Vector3.new(c * 2 + 0.6, 0.3, c * 2 + 0.6), upper * CFrame.new(0, 6.55, 0), PAL.timberDark) -- ceiling
	kitRoof(m, upper * CFrame.new(0, eave, 0), 9, 9, 3.4, 2.4, 5)
	m.Parent = parent
	return m
end

-- Moon gate: a plaster wall with a round opening framed by a stone ring, under a kit roof.
-- The ring is cut from short blocks whose outer corners sit on the circle (no teeth); the wall
-- between ring and square is filled with strips whose inner ends hide under the ring
-- (horizontal strips at the sides, vertical ones above and below).
function Kit.moonGate(parent, cf)
	local m = Instance.new("Model")
	m.Name = "MoonGate"
	local R, band = 4.6, 1.0 -- opening radius, ring width
	local Ro = R + band
	local cy = Ro -- the ring stands on the ground
	local half, H = 12, 12.4 -- wall half-width and height
	local thick = 1.4
	local plaster = Enum.Material.Plaster
	local n = 32
	local L = 2 * Ro * math.tan(math.pi / n)
	local rc = R + band / 2
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		P(m, Vector3.new(band, L, thick + 0.4), cf * CFrame.new(math.cos(a) * rc, cy + math.sin(a) * rc, 0) * CFrame.Angles(0, 0, a), PAL.stoneLight)
	end
	-- side panels and the band over the ring
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(half - Ro, H, thick), cf * CFrame.new(sx * (Ro + half) / 2, H / 2, 0), PAL.plaster, plaster)
	end
	P(m, Vector3.new(Ro * 2, H - 2 * Ro, thick), cf * CFrame.new(0, (H + 2 * Ro) / 2, 0), PAL.plaster, plaster)
	-- fill between the ring and its square (the ring's foot is on the ground: nothing below)
	local k = Ro * math.sqrt(0.5)
	local rows = math.ceil(2 * k / 0.6)
	local sh = 2 * k / rows
	for i = 0, rows - 1 do
		local d = -k + (i + 0.5) * sh
		local e = math.sqrt(rc ^ 2 - d ^ 2)
		local len = Ro - e
		for _, s in { -1, 1 } do
			P(m, Vector3.new(len, sh + 0.02, thick), cf * CFrame.new(s * (e + len / 2), cy + d, 0), PAL.plaster, plaster)
		end
		for _, s in { -1, 1 } do
			P(m, Vector3.new(sh + 0.02, len, thick), cf * CFrame.new(d, cy + s * (e + len / 2), 0), PAL.plaster, plaster)
		end
	end
	local cs = Ro - k -- the upper corners, wholly outside the ring
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(cs, cs, thick), cf * CFrame.new(sx * (k + cs / 2), cy + k + cs / 2, 0), PAL.plaster, plaster)
		P(m, Vector3.new(cs, cy - k, thick), cf * CFrame.new(sx * (k + cs / 2), (cy - k) / 2, 0), PAL.plaster, plaster)
		P(m, Vector3.new(half - Ro + 0.2, 0.8, thick + 0.4), cf * CFrame.new(sx * (Ro + half) / 2, 0.4, 0), PAL.stone) -- footing
	end
	-- coping: red band, gold line, then a long kit roof
	P(m, Vector3.new(half * 2 + 0.2, 0.6, thick + 0.3), cf * CFrame.new(0, H + 0.3, 0), Kit.RED)
	P(m, Vector3.new(half * 2 + 0.3, 0.15, thick + 0.4), cf * CFrame.new(0, H - 0.05, 0), PAL.gold)
	kitRoof(m, cf * CFrame.new(0, H + 0.9, 0), half * 2 + 1.5, 2.2, 1.5, 1.3, 3)
	-- garden stones and a sakura behind it (well back, so its crown stays off the wall)
	for i = 1, 3 do
		P(m, Vector3.new(2.4, 1.6, 2), cf * CFrame.new(-6 + i * 3.2, 0.8, -4 - (i % 2) * 2) * CFrame.Angles(0.2, i, 0.1), PAL.rock)
	end
	Style.sakura(m, cf * CFrame.new(8, 0, -8), 77)
	m.Parent = parent
	return m
end

return Kit
