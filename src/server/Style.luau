-- Hero-quality builders (the "look" pass). Everything takes a world CFrame `cf` at ground level,
-- front facing +Z. Palette and proportions follow docs/art/ART_BIBLE.md.
local Style = {}
local Lowpoly = require(script.Parent:WaitForChild("Lowpoly"))

Style.PAL = {
	vermilion = Color3.fromHex("B8352B"),
	tile = Color3.fromHex("3E4656"),
	tileDark = Color3.fromHex("2B313D"),
	gold = Color3.fromHex("D4A445"),
	plaster = Color3.fromHex("EDE3CF"),
	timber = Color3.fromHex("5A3A29"),
	timberDark = Color3.fromHex("3A261C"),
	jade = Color3.fromHex("6FB59C"),
	stone = Color3.fromHex("9C978C"),
	stoneLight = Color3.fromHex("BDB7AB"),
	grass = Color3.fromHex("6E9A55"),
	grassDark = Color3.fromHex("557A43"),
	dirt = Color3.fromHex("7A5B43"),
	rock = Color3.fromHex("8A8078"),
}
local PAL = Style.PAL

local function P(parent, size, cf, color, mat, shape)
	local p = Lowpoly.part(shape, size) -- small balls and cylinders become shared low-poly meshes
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if size.X < 2 and size.Y < 2 or size.Z < 2 and size.Y < 2 then
		p.CastShadow = false -- small detail: shadows cost more than they add
	end
	p.Parent = parent
	return p
end
Style.P = P

local function cylY(parent, height, dia, cf, color, mat)
	return P(parent, Vector3.new(height, dia, dia), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

-- a rod (cylinder) between two world points, with a ball at the far joint to hide seams
local function rod(parent, a, b, dia, color, mat)
	local len = (b - a).Magnitude
	if len < 0.01 then
		return
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	P(parent, Vector3.new(len, dia, dia), cf, color, mat, Enum.PartType.Cylinder)
	P(parent, Vector3.new(dia, dia, dia), CFrame.new(b), color, mat, Enum.PartType.Ball)
end

---------------------------------------------------------------------------------------------
-- Curved hip roof. cf = centre at EAVE level. W >= D (ridge runs along X).
-- opts: rise, over (eave overhang), tStart (0 = full roof; >0 = skirt ring starting there),
--       tile, ridge, under, rows
function Style.roof(parent, cf, W, D, opts)
	opts = opts or {}
	local H = opts.rise or D * 0.45
	local o = opts.over or 4
	local t0 = opts.tStart or 0
	local rows = opts.rows or 7
	local tile = opts.tile or PAL.tile
	local ridgeC = opts.ridge or PAL.tileDark
	local R = D / 2 + o -- horizontal run, ridge line to eave edge
	local Lr = W / 2 - D / 2 -- ridge half-length (45 degree hips in plan)
	local function y(t) -- concave profile: steep at the ridge, flat at the eave, slight kick
		return H * (1 - t) ^ 1.8 + 0.6 * t ^ 8
	end
	local ts = {}
	for i = 0, rows do
		local u = i / rows
		ts[i] = t0 + (1 - t0) * (1 - (1 - u) ^ 1.3) -- denser rows near the eave
	end
	-- 4 slopes: yaw, ridge half-length at t=0, eave half-length at t=1
	local sides = {
		{ yaw = 0, r = Lr, a = W / 2 + o },
		{ yaw = math.pi, r = Lr, a = W / 2 + o },
		{ yaw = math.pi / 2, r = 0, a = D / 2 + o, shift = Lr },
		{ yaw = -math.pi / 2, r = 0, a = D / 2 + o, shift = Lr },
	}
	for _, s in sides do
		local frame = cf * CFrame.Angles(0, s.yaw, 0) * CFrame.new(0, 0, s.shift or 0)
		for i = 0, rows - 1 do
			local ta, tb = ts[i], ts[i + 1]
			local da, db = R * ta, R * tb
			local ya, yb = y(ta), y(tb)
			local len = math.sqrt((db - da) ^ 2 + (yb - ya) ^ 2) + 0.35
			local hl = s.r + (s.a - s.r) * tb
			local ang = math.atan2(ya - yb, db - da)
			local c = frame * CFrame.new(0, (ya + yb) / 2, (da + db) / 2) * CFrame.Angles(ang, 0, 0)
			if opts.kit2 then
				-- kit 2: the tile courses come from the material, not from extra rib parts
				P(parent, Vector3.new(hl * 2, 0.7, len), c, tile, Enum.Material.ClayRoofTiles)
			else
				P(parent, Vector3.new(hl * 2, 0.7, len), c, tile, Enum.Material.SmoothPlastic)
				-- tile ribs: a lighter cap line along each row edge reads as courses of tiles
				P(parent, Vector3.new(hl * 2, 0.25, 0.35), c * CFrame.new(0, 0.42, len / 2 - 0.3), tile:Lerp(Color3.new(1, 1, 1), 0.12), Enum.Material.SmoothPlastic)
			end
		end
		local ye = y(1)
		if opts.kit2 then
			-- kit 2 eave: a round tile-end roll on the edge, then stepped corbel bands under it
			-- (three long parts per side carry the depth the rafter blocks used to)
			if opts.tileEnds then
				-- a row of round tile ends (instanced low-poly cylinders) under a thin gold drip line
				local n = math.max(2, math.floor(s.a * 2 / 1.2))
				for k = 0, n do
					local x = -s.a + k * (s.a * 2 / n)
					P(parent, Vector3.new(0.5, 0.6, 0.6), frame * CFrame.new(x, ye - 0.05, R + 0.15) * CFrame.Angles(0, math.pi / 2, 0), tile:Lerp(Color3.new(1, 1, 1), 0.15), nil, Enum.PartType.Cylinder)
				end
				P(parent, Vector3.new(s.a * 2 + 0.4, 0.15, 0.2), frame * CFrame.new(0, ye - 0.45, R + 0.3), opts.edge or PAL.gold)
			else
				P(parent, Vector3.new(s.a * 2 + 0.4, 0.7, 0.7), frame * CFrame.new(0, ye - 0.05, R + 0.1), opts.edge or PAL.gold, nil, Enum.PartType.Cylinder)
			end
			for k, step in (opts.corbels == false and {} or { { 0.7, 0.9, PAL.timberDark }, { 0.6, 2.0, PAL.timber }, { 0.6, 3.1, PAL.jade:Lerp(PAL.timberDark, 0.35) } }) do
				-- each band ends where it meets the next side's band at the corner (no ends poking out)
				local half = s.a - step[2] + 0.55
				P(parent, Vector3.new(half * 2, step[1], 1.1), frame * CFrame.new(0, ye - 0.6 - k * 0.6, R - step[2]), step[3])
			end
		else
			-- eave fascia + rafter ends (the dark underside line that sells depth)
			P(parent, Vector3.new(s.a * 2, 0.6, 0.5), frame * CFrame.new(0, ye - 0.55, R - 0.1), PAL.timberDark)
			P(parent, Vector3.new(s.a * 2, 0.25, 0.6), frame * CFrame.new(0, ye - 0.25, R + 0.05), PAL.gold)
			local n = math.floor(s.a * 2 / 1.4)
			for k = 1, n - 1 do
				local x = -s.a + k * (s.a * 2 / n)
				P(parent, Vector3.new(0.5, 0.5, 1.6), frame * CFrame.new(x, ye - 1.05, R - 0.9), PAL.timber)
			end
		end
		-- soffit: dark ceiling under the overhang
		local inner = math.max(R * t0, D / 2 - 0.5)
		if s.r == 0 then
			inner = math.max(R * t0, D / 2 - 0.5)
		end
		P(parent, Vector3.new(s.a * 2 - 1, 0.3, R - inner), frame * CFrame.new(0, opts.kit2 and ye - 0.75 or ye - 1.5, (R + inner) / 2), PAL.timberDark)
	end
	-- hip ridges with upturned "flying" tips
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local prev
			local steps = 8
			for i = 0, steps do
				local t = t0 + (1 - t0) * i / steps
				local p = cf * Vector3.new(sx * (Lr + R * t), y(t) + 0.45, sz * R * t)
				if prev then
					rod(parent, prev, p, 0.9, ridgeC)
				end
				prev = p
			end
			-- the curl: out and up past the eave corner
			for _, k in { { 1.07, 0.7 }, { 1.12, 1.7 }, { 1.14, 2.8 } } do
				local p = cf * Vector3.new(sx * (Lr + R * k[1]), y(1) + 0.45 + k[2], sz * R * k[1])
				rod(parent, prev, p, 0.75, ridgeC)
				prev = p
			end
			P(parent, Vector3.new(0.9, 0.9, 0.9), CFrame.new(prev) * CFrame.Angles(0.6, 0.6, 0), PAL.gold, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	-- main ridge + end ornaments (only on a full roof); a square roof gets a finial instead
	if t0 == 0 and Lr < 0.5 then
		local top = cf * CFrame.new(0, H + 0.3, 0)
		P(parent, Vector3.new(1.6, 0.8, 1.6), top, ridgeC)
		cylY(parent, 1.6, 0.9, top * CFrame.new(0, 1.1, 0), PAL.gold, Enum.Material.Metal)
		P(parent, Vector3.new(1.1, 1.1, 1.1), top * CFrame.new(0, 2.3, 0), PAL.gold, Enum.Material.Metal, Enum.PartType.Ball)
	elseif t0 == 0 then
		P(parent, Vector3.new(Lr * 2 + 1.4, 1.3, 1.3), cf * CFrame.new(0, H + 0.5, 0), ridgeC)
		P(parent, Vector3.new(Lr * 2 + 1.6, 0.3, 1.5), cf * CFrame.new(0, H + 1.2, 0), PAL.gold)
		for _, sx in { -1, 1 } do
			local base = cf * CFrame.new(sx * (Lr + 0.4), H + 1.1, 0)
			if opts.kit2 then
				-- kit 2 ridge end: one rising curl that turns back over the ridge (no stacked blocks)
				local prev = base.Position
				for _, k in { { 0.1, 1.0 }, { -0.1, 1.9 }, { -0.6, 2.5 }, { -1.2, 2.6 } } do
					local p = (base * CFrame.new(sx * k[1], k[2], 0)).Position
					rod(parent, prev, p, 0.7, ridgeC)
					prev = p
				end
				P(parent, Vector3.new(0.6, 0.6, 0.6), CFrame.new(prev), PAL.gold, nil, Enum.PartType.Ball)
			else
				P(parent, Vector3.new(1.2, 2.6, 1.2), base * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, sx * 0.25), ridgeC)
				P(parent, Vector3.new(1.0, 1.4, 1.0), base * CFrame.new(sx * 0.7, 2.4, 0) * CFrame.Angles(0, 0, -sx * 0.7), ridgeC)
				P(parent, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(sx * 1.3, 2.9, 0), PAL.gold, nil, Enum.PartType.Ball)
			end
		end
		-- centre jewel on the ridge
		P(parent, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, H + 2, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), PAL.gold)
	end
	return y
end

---------------------------------------------------------------------------------------------
-- stone plinth with a front stair and balustrade. Returns the top height.
local function plinth(parent, cf, W, D, h)
	P(parent, Vector3.new(W + 2, h * 0.55, D + 2), cf * CFrame.new(0, h * 0.275, 0), PAL.stone, Enum.Material.SmoothPlastic)
	P(parent, Vector3.new(W, h * 0.45, D), cf * CFrame.new(0, h * 0.55 + h * 0.225, 0), PAL.stoneLight, Enum.Material.SmoothPlastic)
	P(parent, Vector3.new(W + 0.4, 0.3, D + 0.4), cf * CFrame.new(0, h + 0.15, 0), PAL.stone, Enum.Material.SmoothPlastic)
	-- stair
	local steps = 5
	local sw = 10
	for i = 1, steps do
		local sh = h / steps
		P(parent, Vector3.new(sw, sh * i, 1.4), cf * CFrame.new(0, sh * i / 2, D / 2 + 1 + (steps - i) * 1.4 + 0.7), PAL.stoneLight)
	end
	local run = steps * 1.4
	for _, sx in { -1, 1 } do
		-- sloped side wall of the stair
		local a = cf * Vector3.new(sx * (sw / 2 + 0.6), h + 1.0, D / 2 + 1)
		local b = cf * Vector3.new(sx * (sw / 2 + 0.6), 1.2, D / 2 + 1 + run)
		local len = (b - a).Magnitude
		P(parent, Vector3.new(1.2, 1.6, len), CFrame.lookAt((a + b) / 2, b), PAL.stone)
		P(parent, Vector3.new(1.4, 2.6, 1.4), CFrame.new(b) * CFrame.new(0, 0.3, 0), PAL.stone)
		P(parent, Vector3.new(0.9, 0.9, 0.9), CFrame.new(b) * CFrame.new(0, 2, 0), PAL.stoneLight, nil, Enum.PartType.Ball)
	end
	-- balustrade along the front edge (both sides of the stair)
	for _, sx in { -1, 1 } do
		local x0, x1 = sx * (sw / 2 + 0.6), sx * (W / 2 - 0.5)
		local z = D / 2 - 0.4
		local n = math.max(2, math.floor(math.abs(x1 - x0) / 3))
		for k = 0, n do
			local x = x0 + (x1 - x0) * k / n
			P(parent, Vector3.new(0.6, 2.2, 0.6), cf * CFrame.new(x, h + 1.1, z), PAL.stoneLight)
		end
		P(parent, Vector3.new(math.abs(x1 - x0), 0.4, 0.5), cf * CFrame.new((x0 + x1) / 2, h + 1.9, z), PAL.stoneLight)
		P(parent, Vector3.new(math.abs(x1 - x0), 0.6, 0.3), cf * CFrame.new((x0 + x1) / 2, h + 0.6, z), PAL.stone)
	end
	return h
end

local function lattice(parent, cf, w, h, color)
	-- dark panel with a light grid of bars (doors and windows)
	P(parent, Vector3.new(w, h, 0.3), cf, PAL.timberDark)
	local nv = math.max(2, math.floor(w / 0.9))
	for i = 1, nv - 1 do
		P(parent, Vector3.new(0.15, h, 0.2), cf * CFrame.new(-w / 2 + i * w / nv, 0, 0.18), color)
	end
	local nh = math.max(2, math.floor(h / 1.1))
	for i = 1, nh - 1 do
		P(parent, Vector3.new(w, 0.15, 0.2), cf * CFrame.new(0, -h / 2 + i * h / nh, 0.18), color)
	end
	P(parent, Vector3.new(w + 0.3, 0.3, 0.35), cf * CFrame.new(0, h / 2, 0.1), PAL.vermilion)
	P(parent, Vector3.new(w + 0.3, 0.3, 0.35), cf * CFrame.new(0, -h / 2, 0.1), PAL.vermilion)
end

---------------------------------------------------------------------------------------------
-- The hero hall: plinth, columns, lattice front, bracket sets, double-eave curved hip roof.
function Style.hall(parent, cf, opts)
	opts = opts or {}
	local W, D = opts.W or 30, opts.D or 18
	local bay = W / 5
	local colH = opts.colH or 11
	local m = Instance.new("Model")
	m.Name = opts.name or "Hall"
	local top = plinth(m, cf, W + 6, D + 6, opts.plinth or 3)
	local base = cf * CFrame.new(0, top + 0.3, 0)

	-- columns (front, back, side middles), with stone bases and gold collars
	local cols = {}
	for i = 0, 5 do
		local x = -W / 2 + i * bay
		table.insert(cols, Vector2.new(x, D / 2))
		table.insert(cols, Vector2.new(x, -D / 2))
	end
	for _, sx in { -1, 1 } do
		table.insert(cols, Vector2.new(sx * W / 2, D / 6))
		table.insert(cols, Vector2.new(sx * W / 2, -D / 6))
	end
	for _, c in cols do
		local at = base * CFrame.new(c.X, 0, c.Y)
		P(m, Vector3.new(2, 0.6, 2), at * CFrame.new(0, 0.3, 0), PAL.stone)
		cylY(m, colH, 1.4, at * CFrame.new(0, colH / 2 + 0.6, 0), PAL.vermilion)
		cylY(m, 0.4, 1.6, at * CFrame.new(0, colH - 0.6, 0), PAL.gold)
		-- bracket set (dougong): three stacked, widening blocks (kit 2 uses one frieze instead)
		if not opts.kit2 then
			for k = 0, 2 do
				P(m, Vector3.new(1.4 + k * 0.9, 0.5, 1.4 + k * 0.9), at * CFrame.new(0, colH + 0.85 + k * 0.5, 0), k == 1 and PAL.jade or PAL.timber)
			end
		end
	end
	-- architrave band around the top of the columns
	local beamY = colH + 0.2
	for _, sz in { -1, 1 } do
		P(m, Vector3.new(W + 1.4, 1.2, 1.2), base * CFrame.new(0, beamY, sz * D / 2), PAL.vermilion)
		P(m, Vector3.new(W + 1.5, 0.3, 1.3), base * CFrame.new(0, beamY - 0.45, sz * D / 2), PAL.gold)
	end
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(1.2, 1.2, D + 1.4), base * CFrame.new(sx * W / 2, beamY, 0), PAL.vermilion)
		P(m, Vector3.new(1.3, 0.3, D + 1.5), base * CFrame.new(sx * W / 2, beamY - 0.45, 0), PAL.gold)
	end
	if opts.kit2 then
		-- kit 2 frieze: one painted jade band right round the top of the colonnade, framed by
		-- gold lines (what the reference halls do with a lattice decal, here with three parts a side)
		local fy = beamY + 1.35
		for _, side in { { W + 1.4, 0, D / 2 }, { W + 1.4, 0, -D / 2 }, { 1.2, 1, 0 }, { 1.2, -1, 0 } } do
			local along = side[1] > 2
			local size = along and Vector3.new(W + 1.4, 1.5, 1.0) or Vector3.new(1.0, 1.5, D + 1.4)
			local at = base * CFrame.new(side[2] * W / 2, fy, side[3])
			P(m, size, at, Color3.fromHex("2F6F55"))
			P(m, size + Vector3.new(0.1, -1.25, 0.1), at * CFrame.new(0, 0.75, 0), PAL.gold)
			P(m, size + Vector3.new(0.1, -1.25, 0.1), at * CFrame.new(0, -0.75, 0), PAL.gold)
		end
	end
	-- walls: set back 1.5 studs behind the front colonnade (a shaded porch)
	local wz = D / 2 - 2
	local wallH = colH - 0.4
	local wallMat = opts.kit2 and Enum.Material.Plaster or nil
	P(m, Vector3.new(W - 0.6, wallH, 0.8), base * CFrame.new(0, wallH / 2 + 0.6, -D / 2 + 0.2), PAL.plaster, wallMat)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.8, wallH, D - 0.6), base * CFrame.new(sx * (W / 2 - 0.2), wallH / 2 + 0.6, 0), PAL.plaster, wallMat)
		-- timber frame band at the wall foot
		P(m, Vector3.new(0.9, 1.4, D - 0.4), base * CFrame.new(sx * (W / 2 - 0.2), 1.3, 0), PAL.timber)
	end
	-- front: doors in the middle three bays, lattice windows over plaster in the outer two
	for i = 0, 4 do
		local x = -W / 2 + (i + 0.5) * bay
		if i >= 1 and i <= 3 then
			lattice(m, base * CFrame.new(x, 0.6 + (wallH - 1) / 2, wz), bay - 1.4, wallH - 1, PAL.gold:Lerp(PAL.plaster, 0.4))
		else
			P(m, Vector3.new(bay - 1, 3.4, 0.6), base * CFrame.new(x, 2.3, wz), PAL.plaster)
			lattice(m, base * CFrame.new(x, 4 + (wallH - 4.4) / 2, wz), bay - 1.4, wallH - 4.4, PAL.gold:Lerp(PAL.plaster, 0.4))
		end
	end
	P(m, Vector3.new(W - 0.6, 0.4, D - 4), base * CFrame.new(0, wallH + 0.8, -2), PAL.timberDark) -- ceiling
	-- name plaque between the doors and the beam
	P(m, Vector3.new(6, 1.8, 0.4), base * CFrame.new(0, colH - 1.6, D / 2 + 0.7), PAL.timberDark)
	P(m, Vector3.new(5.2, 1.2, 0.2), base * CFrame.new(0, colH - 1.6, D / 2 + 0.95), PAL.gold)

	-- opts.tile recolours the roofs (gold tiles for the top Main Hall level)
	local tile = opts.tile
	local ridge = tile and tile:Lerp(Color3.new(0, 0, 0), 0.25) or nil
	local eaveY = colH + 2.6
	if opts.single then
		-- one big roof straight over the colonnade (smaller, humbler halls)
		Style.roof(m, base * CFrame.new(0, eaveY, 0), W, D, { rise = D * 0.5, over = 4, rows = 6, tile = tile, ridge = ridge, kit2 = opts.kit2 })
		m.Parent = parent
		return m
	end
	-- lower eave (skirt) around the colonnade
	local W2, D2 = W - 10, D - 8
	local R1 = D / 2 + 5
	local yfn = Style.roof(m, base * CFrame.new(0, eaveY, 0), W, D, { rise = 6, over = 5, tStart = (D2 / 2) / R1, rows = 4, tile = tile, ridge = ridge, kit2 = opts.kit2 })
	local joint = eaveY + yfn((D2 / 2) / R1)
	-- upper storey (clerestory) with its own colour band, then the main roof
	local upH = 4.5
	P(m, Vector3.new(W2, upH + 1, D2), base * CFrame.new(0, joint + (upH + 1) / 2 - 0.5, 0), PAL.plaster)
	for _, sz in { -1, 1 } do
		P(m, Vector3.new(W2 + 0.4, 1, 0.5), base * CFrame.new(0, joint + upH - 0.3, sz * (D2 / 2 + 0.1)), PAL.vermilion)
		for k = 0, 4 do
			local x = -W2 / 2 + 1.5 + k * (W2 - 3) / 4
			P(m, Vector3.new(0.6, upH, 0.4), base * CFrame.new(x, joint + upH / 2, sz * (D2 / 2 + 0.1)), PAL.vermilion)
		end
		lattice(m, base * CFrame.new(-W2 / 4, joint + upH / 2 - 0.2, sz * (D2 / 2 + 0.15)) * CFrame.Angles(0, sz < 0 and math.pi or 0, 0), W2 / 4, upH - 2, PAL.gold:Lerp(PAL.plaster, 0.4))
		lattice(m, base * CFrame.new(W2 / 4, joint + upH / 2 - 0.2, sz * (D2 / 2 + 0.15)) * CFrame.Angles(0, sz < 0 and math.pi or 0, 0), W2 / 4, upH - 2, PAL.gold:Lerp(PAL.plaster, 0.4))
	end
	Style.roof(m, base * CFrame.new(0, joint + upH + 0.8, 0), W2 + 2, D2 + 2, { rise = 7.5, over = 4.5, rows = 7, tile = tile, ridge = ridge, kit2 = opts.kit2 })
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- The Main Hall: one building the player keeps upgrading (levels 1..5). Each level is a
-- complete, bigger building; the caller removes the previous level.
local GOLD_TILE = Color3.fromHex("D9A43A")
function Style.mainHall(parent, cf, level)
	if level == 1 then
		-- thatched hut: timber frame, plaster walls, straw roof
		local m = Instance.new("Model")
		m.Name = "MainHall1"
		P(m, Vector3.new(11, 0.8, 9), cf * CFrame.new(0, 0.4, 0), PAL.stone)
		P(m, Vector3.new(9, 5, 7), cf * CFrame.new(0, 3.3, 0), PAL.plaster)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				P(m, Vector3.new(0.8, 5.4, 0.8), cf * CFrame.new(sx * 4.5, 3.5, sz * 3.5), PAL.timber)
			end
		end
		P(m, Vector3.new(2.4, 3.6, 0.3), cf * CFrame.new(0, 2.6, 3.55), PAL.timberDark)
		Style.roof(m, cf * CFrame.new(0, 6.2, 0), 11, 9, { rise = 3.6, over = 1.6, rows = 4, tile = Color3.fromHex("C9A86A"), ridge = Color3.fromHex("8F7448") })
		m.Parent = parent
		return m
	elseif level == 2 then
		return Style.hall(parent, cf, { W = 16, D = 10, colH = 8, plinth = 2, single = true, name = "MainHall2" })
	elseif level == 3 then
		return Style.hall(parent, cf, { W = 22, D = 13, colH = 10, plinth = 3, name = "MainHall3" })
	end
	-- levels 4 and 5: the great hall flanked by wings (5 adds gold tiles and corner towers)
	local m = Instance.new("Model")
	m.Name = "MainHall" .. level
	local gold = level >= 5 and GOLD_TILE or nil
	Style.hall(m, cf, { W = 28, D = 16, colH = level >= 5 and 13 or 12, plinth = 3.5, tile = gold, name = "Core" })
	for _, sx in { -1, 1 } do
		Style.hall(m, cf * CFrame.new(sx * 24, 0, 3), { W = 12, D = 8, colH = 7, plinth = 2.5, single = true, tile = gold, name = "Wing" })
	end
	if level >= 5 then
		for _, sx in { -1, 1 } do
			Style.pagoda(m, cf * CFrame.new(sx * 24, 0, -12), 6, 1, 3, 3)
		end
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- Variety buildings for the expanded ground

function Style.bambooGrove(parent, cf, seed)
	local rng = Random.new(seed or 3)
	local m = Instance.new("Model")
	m.Name = "BambooGrove"
	cylY(m, 0.4, 16, cf * CFrame.new(0, 0.2, 0), PAL.dirt)
	local greens = { Color3.fromHex("7FB55A"), Color3.fromHex("6AA14C"), Color3.fromHex("93C46A") }
	for i = 1, 16 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 6.5)
		local h = rng:NextNumber(10, 17)
		local base = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		local c = greens[i % 3 + 1]
		cylY(m, h, 0.5, base * CFrame.new(0, h / 2, 0), c)
		for k = 1, math.floor(h / 2.5) do
			cylY(m, 0.18, 0.62, base * CFrame.new(0, k * 2.5, 0), c:Lerp(Color3.new(0, 0, 0), 0.2)) -- nodes
		end
		for k = 0, 2 do
			P(m, Vector3.new(2.2, 0.15, 0.6), base * CFrame.new(0.8, h - k * 1.6, 0) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(-25)), c:Lerp(Color3.fromHex("3F7A3A"), 0.4))
		end
	end
	Style.lantern(m, cf * CFrame.new(7, 0, 6), 0.8)
	m.Parent = parent
	return m
end

function Style.trainingGround(parent, cf)
	local m = Instance.new("Model")
	m.Name = "TrainingGround"
	cylY(m, 0.5, 20, cf * CFrame.new(0, 0.25, 0), PAL.stone)
	cylY(m, 0.55, 17, cf * CFrame.new(0, 0.3, 0), Color3.fromHex("D2C2A2")) -- packed sand
	-- three wooden training dummies
	for k = -1, 1 do
		local at = cf * CFrame.new(k * 5, 0.5, -2 - math.abs(k) * 2)
		cylY(m, 5, 0.9, at * CFrame.new(0, 2.5, 0), PAL.timber)
		cylY(m, 1.6, 1.6, at * CFrame.new(0, 3.6, 0), Color3.fromHex("8A6A48")) -- padded torso
		P(m, Vector3.new(3.6, 0.45, 0.45), at * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(20 * k), 0), PAL.timberDark) -- arms
		P(m, Vector3.new(0.9, 0.9, 0.9), at * CFrame.new(0, 5.2, 0), Color3.fromHex("8A6A48"), nil, Enum.PartType.Ball)
	end
	-- weapon rack with staves
	local rack = cf * CFrame.new(0, 0.5, 6)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.5, 3.4, 0.5), rack * CFrame.new(sx * 3, 1.7, 0), PAL.timberDark)
	end
	P(m, Vector3.new(6.6, 0.4, 0.5), rack * CFrame.new(0, 3, 0), PAL.timberDark)
	for k = -2, 2 do
		P(m, Vector3.new(0.22, 4.2, 0.22), rack * CFrame.new(k * 1.1, 2.1, 0.35) * CFrame.Angles(math.rad(-10), 0, 0), PAL.vermilion)
	end
	-- banner poles at the edge
	for _, sx in { -1, 1 } do
		local at = cf * CFrame.new(sx * 9, 0.5, 4)
		cylY(m, 9, 0.35, at * CFrame.new(0, 4.5, 0), PAL.timberDark)
		P(m, Vector3.new(0.12, 4, 2.2), at * CFrame.new(0, 6.6, sx * -1.15), PAL.vermilion)
	end
	m.Parent = parent
	return m
end

function Style.bellTower(parent, cf)
	local m = Instance.new("Model")
	m.Name = "BellTower"
	plinth(m, cf, 10, 10, 1.5)
	local base = cf * CFrame.new(0, 1.8, 0)
	P(m, Vector3.new(8, 5, 8), base * CFrame.new(0, 2.5, 0), PAL.stoneLight) -- solid lower storey
	P(m, Vector3.new(8.4, 0.5, 8.4), base * CFrame.new(0, 5.1, 0), PAL.vermilion)
	local upper = base * CFrame.new(0, 5.35, 0)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cylY(m, 6, 0.9, upper * CFrame.new(sx * 3.5, 3, sz * 3.5), PAL.vermilion)
		end
	end
	P(m, Vector3.new(8, 0.6, 8), upper * CFrame.new(0, 6.1, 0), PAL.timber)
	-- the bronze bell hanging from a beam
	P(m, Vector3.new(7.4, 0.5, 0.5), upper * CFrame.new(0, 5.6, 0), PAL.timberDark)
	cylY(m, 3, 2.6, upper * CFrame.new(0, 3.6, 0), Color3.fromHex("7A5A3A"), Enum.Material.Metal)
	cylY(m, 0.4, 3, upper * CFrame.new(0, 2.15, 0), PAL.gold, Enum.Material.Metal)
	P(m, Vector3.new(2.6, 2.6, 2.6), upper * CFrame.new(0, 5, 0), Color3.fromHex("7A5A3A"), Enum.Material.Metal, Enum.PartType.Ball)
	-- striker log
	P(m, Vector3.new(0.5, 0.5, 4), upper * CFrame.new(2.6, 3.2, 0), PAL.timber)
	Style.roof(m, upper * CFrame.new(0, 7.2, 0), 9, 9, { rise = 3.6, over = 2.6, rows = 5 })
	m.Parent = parent
	return m
end

function Style.koiPond(parent, cf, seed)
	local rng = Random.new(seed or 8)
	local m = Instance.new("Model")
	m.Name = "KoiPond"
	-- stone rim, then still water (opaque tinted disc: no Glass, no Terrain water)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		P(m, Vector3.new(3.2, 1, 2.2), cf * CFrame.new(math.cos(a) * 8, 0.5, math.sin(a) * 8) * CFrame.Angles(0, -a, 0), i % 2 == 0 and PAL.stone or PAL.stoneLight)
	end
	cylY(m, 0.3, 15.6, cf * CFrame.new(0, 0.55, 0), Color3.fromHex("4FA3C7"))
	cylY(m, 0.31, 9, cf * CFrame.new(1.5, 0.56, -1), Color3.fromHex("5DB6D6"))
	-- lily pads, lotus flowers and koi
	for i = 1, 7 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, 6.5)
		local at = cf * CFrame.new(math.cos(a) * r, 0.74, math.sin(a) * r)
		cylY(m, 0.08, rng:NextNumber(1.2, 2), at, Color3.fromHex("5E9A4A"))
		if i % 2 == 0 then
			P(m, Vector3.new(0.7, 0.6, 0.7), at * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromHex("F7B8CC"))
		end
	end
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local at = cf * CFrame.new(math.cos(a) * 4, 0.6, math.sin(a) * 4) * CFrame.Angles(0, -a, 0)
		P(m, Vector3.new(0.5, 0.25, 1.4), at, i % 2 == 0 and Color3.fromHex("F28C38") or Color3.fromHex("FFFFFF"))
		P(m, Vector3.new(0.6, 0.12, 0.5), at * CFrame.new(0, 0, 0.85), Color3.fromHex("F2A65A")) -- tail
	end
	-- little arched bridge across
	for k = -3, 3 do
		local y = 1.6 + (1 - (k / 3) ^ 2) * 1.4
		P(m, Vector3.new(3, 0.4, 1.3), cf * CFrame.new(0, y, k * 1.25) * CFrame.Angles(math.rad(-k * 9), 0, 0), PAL.vermilion)
	end
	for _, sx in { -1, 1 } do
		for k = -2, 2 do
			local y = 1.6 + (1 - (k / 3) ^ 2) * 1.4
			P(m, Vector3.new(0.3, 1.4, 0.3), cf * CFrame.new(sx * 1.4, y + 0.8, k * 1.6), PAL.vermilion)
		end
	end
	m.Parent = parent
	return m
end

function Style.moonGate(parent, cf)
	local m = Instance.new("Model")
	m.Name = "MoonGate"
	-- a plaster wall with a round opening, built as an arc of blocks
	local R = 4.6
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local x, y = math.cos(a) * (R + 1.2), math.sin(a) * (R + 1.2) + R + 0.6
		P(m, Vector3.new(2.6, 1.6, 1.6), cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, a), PAL.plaster)
	end
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(6, 12.4, 1.4), cf * CFrame.new(sx * 9, 6.2, 0), PAL.plaster)
		P(m, Vector3.new(6.2, 0.6, 1.6), cf * CFrame.new(sx * 9, 0.3, 0), PAL.stone)
	end
	P(m, Vector3.new(24, 0.6, 1.8), cf * CFrame.new(0, 12.7, 0), PAL.vermilion)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(12.6, 0.6, 2.4), cf * CFrame.new(sx * 5.8, 13.4, 0) * CFrame.Angles(0, 0, -sx * math.rad(8)), PAL.tile)
	end
	-- garden stones and a sakura behind it
	for i = 1, 3 do
		P(m, Vector3.new(2.4, 1.6, 2), cf * CFrame.new(-6 + i * 3.2, 0.8, -4 - (i % 2) * 2) * CFrame.Angles(0.2, i, 0.1), PAL.rock)
	end
	Style.sakura(m, cf * CFrame.new(7, 0, -5), 77)
	m.Parent = parent
	return m
end

function Style.library(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Library"
	Style.hall(m, cf, { W = 16, D = 10, colH = 8, plinth = 2, single = true, tile = Color3.fromHex("2F6B5A"), name = "LibraryHall" })
	-- scroll racks on the porch
	for _, sx in { -1, 1 } do
		local at = cf * CFrame.new(sx * 10.5, 2, 6)
		P(m, Vector3.new(0.4, 4, 2.6), at * CFrame.new(0, 2, 0), PAL.timberDark)
		for k = 0, 3 do
			cylY(m, 0.5, 0.5, at * CFrame.new(0.4, 0.8 + k * 0.9, 0) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromHex("EBDDBA"))
		end
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- Stone lantern: a real fixture holding a real light.
function Style.lantern(parent, cf, scale)
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "StoneLantern"
	P(m, Vector3.new(2.6, 0.6, 2.6) * s, cf * CFrame.new(0, 0.3 * s, 0), PAL.stone)
	P(m, Vector3.new(1.9, 0.4, 1.9) * s, cf * CFrame.new(0, 0.8 * s, 0), PAL.stoneLight)
	cylY(m, 2.6 * s, 0.9 * s, cf * CFrame.new(0, 2.3 * s, 0), PAL.stone)
	P(m, Vector3.new(2.2, 0.5, 2.2) * s, cf * CFrame.new(0, 3.8 * s, 0), PAL.stoneLight)
	-- firebox: four corner posts around a flame
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.4, 1.6, 0.4) * s, cf * CFrame.new(sx * 0.75 * s, 4.85 * s, sz * 0.75 * s), PAL.stone)
		end
	end
	local flame = P(m, Vector3.new(0.7, 0.9, 0.7) * s, cf * CFrame.new(0, 4.75 * s, 0), Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 175, 95)
	light.Range = 16 * s
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = flame
	-- roof cap: wide, low, with turned-up corners
	P(m, Vector3.new(3.2, 0.5, 3.2) * s, cf * CFrame.new(0, 5.85 * s, 0), PAL.stone)
	P(m, Vector3.new(2.2, 0.6, 2.2) * s, cf * CFrame.new(0, 6.35 * s, 0), PAL.stone)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P(m, Vector3.new(0.5, 0.5, 0.5) * s, cf * CFrame.new(sx * 1.55 * s, 6.25 * s, sz * 1.55 * s), PAL.stoneLight)
		end
	end
	P(m, Vector3.new(0.7, 0.7, 0.7) * s, cf * CFrame.new(0, 6.95 * s, 0), PAL.stoneLight, nil, Enum.PartType.Ball)
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- Faceted blob: a cluster of rotated cubes (reads low-poly, never a "default ball").
local function blob(parent, center, radius, colors, rng, count)
	for i = 1, count or 6 do
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.6), rng:NextNumber(-1, 1)) * radius * 0.6
		local sz = radius * rng:NextNumber(0.75, 1.1)
		P(parent, Vector3.new(sz, sz * 0.8, sz), CFrame.new(center + off) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), colors[(i - 1) % #colors + 1])
	end
end

function Style.sakura(parent, cf, seed)
	local rng = Random.new(seed or 1)
	local m = Instance.new("Model")
	m.Name = "Sakura"
	local bark = Color3.fromHex("4A3330")
	local pinks = { Color3.fromHex("F4B6C2"), Color3.fromHex("E98FA6"), Color3.fromHex("FAD4DC") }
	-- gently leaning trunk, then 3 branches
	local p0 = cf.Position
	local p1 = (cf * CFrame.new(0.8, 5, 0.3)).Position
	rod(m, p0, p1, 1.4, bark)
	local tips = {}
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.3, 0.3)
		local tip = p1 + Vector3.new(math.cos(a) * 4, rng:NextNumber(2.5, 4), math.sin(a) * 4)
		rod(m, p1, tip, 0.8, bark)
		table.insert(tips, tip)
	end
	for _, tip in tips do
		blob(m, tip + Vector3.new(0, 1, 0), 4, pinks, rng, 6)
	end
	blob(m, p1 + Vector3.new(0, 5, 0), 4.5, pinks, rng, 5)
	-- falling petals that drift with the wind
	local emitterPart = P(m, Vector3.new(6, 1, 6), CFrame.new(p1 + Vector3.new(0, 4, 0)), pinks[1])
	emitterPart.Transparency = 1
	emitterPart.CanCollide = false
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(pinks[1], pinks[3])
	pe.Size = NumberSequence.new(0.3)
	pe.Rate = 3
	pe.Lifetime = NumberRange.new(5, 7)
	pe.Speed = NumberRange.new(0.5, 1)
	pe.Acceleration = Vector3.new(0, -1.2, 0)
	pe.Drag = 1
	pe.WindAffectsDrag = true
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Parent = emitterPart
	m.Parent = parent
	return m
end

function Style.pine(parent, cf, seed, height)
	local rng = Random.new(seed or 2)
	local h = height or 12
	local m = Instance.new("Model")
	m.Name = "Pine"
	local greens = { Color3.fromHex("2E5B47"), Color3.fromHex("3F7A5C"), Color3.fromHex("356A51") }
	cylY(m, h * 0.5, 0.9, cf * CFrame.new(0, h * 0.25, 0), Color3.fromHex("4E3A2C"))
	-- layered octagonal tiers (two cubes at 45 degrees), shrinking upward
	local tiers = 4
	for i = 0, tiers - 1 do
		local w = (h * 0.55) * (1 - i / (tiers + 0.6))
		local y = h * 0.3 + i * h * 0.17
		local yaw = rng:NextNumber(0, 1)
		local c = greens[i % #greens + 1]
		P(m, Vector3.new(w, h * 0.16, w), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0), c)
		P(m, Vector3.new(w, h * 0.16, w), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw + math.pi / 4, 0), c)
		P(m, Vector3.new(w * 0.7, h * 0.08, w * 0.7), cf * CFrame.new(0, y + h * 0.1, 0) * CFrame.Angles(0, yaw + 0.4, 0), c:Lerp(Color3.new(0, 0, 0), 0.1))
	end
	P(m, Vector3.new(h * 0.12, h * 0.12, h * 0.12), cf * CFrame.new(0, h * 0.3 + tiers * h * 0.17, 0) * CFrame.Angles(0, 0.4, 0), greens[2])
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- Floating island: irregular grass top with a darker lip, dirt band, and a faceted rock
-- underside that steps darker with depth and ends in hanging spires. cf = top surface centre.
-- useTerrain: the grass top is real Terrain grass (with Roblox's animated grass blades) instead
-- of a flat green part. Measured 2026-10-21: FillCylinder snaps the surface to the 4-stud grid
-- (only world y = +2 or -2 are reachable), so islands using terrain must stand at world y = 2
-- and the fill is always centred at world y = -4 (height 4), which surfaces exactly at y = 2.
function Style.island(parent, cf, radius, seed, keepClear, useTerrain)
	local rng = Random.new(seed or 5)
	local m = Instance.new("Model")
	m.Name = "Island"
	-- irregular outline: a main disc plus lobes
	local lobes = { { 0, 0, radius } }
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		-- lobes reach at most 1.05 x radius (Main.server clears terrain on that promise)
		local r = radius * rng:NextNumber(0.6, 0.68)
		table.insert(lobes, { math.cos(a) * r, math.sin(a) * r, radius * rng:NextNumber(0.3, 0.37) })
	end
	for _, l in lobes do
		local at = cf * CFrame.new(l[1], 0, l[2])
		if useTerrain then
			-- LeafyGrass: short, no blades (Grass's blades everywhere read as an overgrown field)
			local w = at.Position
			workspace.Terrain:FillCylinder(CFrame.new(w.X, -4, w.Z), 4, l[3], Enum.Material.LeafyGrass)
		else
			cylY(m, 2, l[3] * 2, at * CFrame.new(0, -1, 0), PAL.grass, Enum.Material.SmoothPlastic)
		end
		cylY(m, 1.2, l[3] * 2 + 1.4, at * CFrame.new(0, -1.9, 0), PAL.grassDark, Enum.Material.SmoothPlastic)
		cylY(m, 3, l[3] * 2 + 0.2, at * CFrame.new(0, -4, 0), PAL.dirt, Enum.Material.SmoothPlastic)
	end
	-- rock underside: rings of faceted chunks, narrowing and darkening with depth
	local layers = 6
	local depth = radius * 1.1
	local step = depth / layers
	for k = 0, layers - 1 do
		local f = 1 - k / layers
		local ringR = radius * 0.95 * f ^ 0.9
		local h = step * 1.5
		-- every chunk's TOP stays under the dirt band (y <= -6), so nothing pokes through the grass
		local y = -6.5 - k * step - h / 2
		local n = math.max(3, math.floor(ringR / 3.2))
		-- warm sandstone near the grass, fading to a cool slate that melts into the clouds
		local col = Color3.fromHex("A08A74"):Lerp(Color3.fromHex("5A5670"), (k / (layers - 1)) ^ 0.8)
		for i = 1, n do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local s = math.min(ringR * rng:NextNumber(0.4, 0.55) + 3, 14)
			local at = cf * CFrame.new(math.cos(a) * ringR * 0.72, y, math.sin(a) * ringR * 0.72)
			P(m, Vector3.new(s, h, s), at * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6), rng:NextNumber(-0.12, 0.12)), col:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.06)))
		end
		cylY(m, h, ringR * 1.5, cf * CFrame.new(0, y, 0), col)
	end
	-- hanging spires
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius * 0.35)
		local top = cf * Vector3.new(math.cos(a) * r, -5.5 - depth * 0.7, math.sin(a) * r)
		local len = rng:NextNumber(8, 16)
		for j = 0, 3 do
			local s = (1 - j / 4) * 4 + 0.6
			P(m, Vector3.new(s, len / 4 + 0.5, s), CFrame.new(top - Vector3.new(0, j * len / 4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromHex("524E66"))
		end
	end
	-- tall swaying Grass only in a few meadow patches near the rim, never on paths or plots
	if useTerrain then
		local patches = math.floor(radius / 6)
		for i = 1, patches do
			local a = i / patches * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = radius * rng:NextNumber(0.72, 0.9)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not (keepClear and keepClear(x, z)) then
				local w = (cf * CFrame.new(x, 0, z)).Position
				workspace.Terrain:FillCylinder(CFrame.new(w.X, -4, w.Z), 4, rng:NextNumber(4, 7), Enum.Material.Grass)
			end
		end
	end
	-- a lighter rock shelf right under the dirt band (gives the cliff a crisp top edge)
	cylY(m, 1.6, radius * 1.92, cf * CFrame.new(0, -6.2, 0), Color3.fromHex("B8A48C"))
	-- grass drips over the rim: tapered green tongues hanging down the dirt band
	local drips = math.floor(radius / 2.2)
	for i = 1, drips do
		local a = i / drips * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = radius * rng:NextNumber(0.97, 1.02)
		local len = rng:NextNumber(1.6, 3.8)
		local at = cf * CFrame.new(math.cos(a) * r, -1.6 - len / 2, math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0)
		P(m, Vector3.new(rng:NextNumber(1.6, 3), len, 0.8), at, i % 3 == 0 and PAL.grass or PAL.grassDark)
		P(m, Vector3.new(0.9, len * 0.5, 0.7), at * CFrame.new(0, -len * 0.55, 0), PAL.grassDark)
	end
	-- dangling roots under the shelf
	for i = 1, math.floor(radius / 8) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius * rng:NextNumber(0.75, 0.9)
		local p0 = cf * Vector3.new(math.cos(a) * r, -7, math.sin(a) * r)
		local prev = p0
		for j = 1, 3 do
			local p = prev + Vector3.new(rng:NextNumber(-0.8, 0.8), -rng:NextNumber(2.5, 4), rng:NextNumber(-0.8, 0.8))
			rod(m, prev, p, 0.35 - j * 0.07, Color3.fromHex("5E4636"))
			prev = p
		end
		P(m, Vector3.new(1.4, 1.4, 1.4), CFrame.new(prev) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), PAL.grassDark) -- leaf tuft at the tip
	end
	-- small rocks floating beside the island
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius * rng:NextNumber(1.15, 1.35)
		local s = rng:NextNumber(2.5, 5)
		local at = cf * CFrame.new(math.cos(a) * r, rng:NextNumber(-14, -4), math.sin(a) * r)
		P(m, Vector3.new(s, s * 0.45, s), at, PAL.grass)
		P(m, Vector3.new(s * 0.85, s * 0.9, s * 0.85), at * CFrame.new(0, -s * 0.6, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15), Color3.fromHex("8E7C6C"))
		P(m, Vector3.new(s * 0.45, s * 0.6, s * 0.45), at * CFrame.new(0, -s * 1.2, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromHex("5A5670"))
	end
	-- boulders and grass tufts on the top
	for i = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius * rng:NextNumber(0.75, 0.95)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local at = cf * CFrame.new(x, 0, z)
		if keepClear and keepClear(x, z) then
			-- leave paths and building spots free
		elseif i % 2 == 0 then
			local s = rng:NextNumber(2, 4)
			P(m, Vector3.new(s, s * 0.7, s), at * CFrame.new(0, s * 0.2, 0) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), PAL.rock)
		else
			for t = 1, 3 do
				P(m, Vector3.new(0.3, rng:NextNumber(0.8, 1.4), 0.3), at * CFrame.new(rng:NextNumber(-0.6, 0.6), 0.5, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), PAL.grassDark)
			end
		end
	end
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------
-- Pagoda: square tiers, each a plaster body with vermilion posts and its own curved roof.
-- Builds tiers fromTier..toTier only, so a pagoda can be bought in two halves that line up.
function Style.pagoda(parent, cf, baseW, fromTier, toTier, totalTiers)
	local m = Instance.new("Model")
	m.Name = "Pagoda"
	local y = 0
	if fromTier == 1 then
		plinth(m, cf, baseW + 6, baseW + 6, 2)
	end
	y = 2.3
	for i = 1, totalTiers do
		local w = baseW * (1 - (i - 1) * 0.16)
		local h = (i == 1) and 6 or 4.2
		local build = i >= fromTier and i <= toTier
		local at = cf * CFrame.new(0, y, 0)
		if build then
			P(m, Vector3.new(w, h, w), at * CFrame.new(0, h / 2, 0), PAL.plaster)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					cylY(m, h, 0.9, at * CFrame.new(sx * w / 2, h / 2, sz * w / 2), PAL.vermilion)
				end
			end
			P(m, Vector3.new(w + 0.6, 0.8, w + 0.6), at * CFrame.new(0, h - 0.2, 0), PAL.vermilion)
			P(m, Vector3.new(w + 0.7, 0.25, w + 0.7), at * CFrame.new(0, h - 0.7, 0), PAL.gold)
			-- a lattice window on every face (a door on the ground floor front)
			for k = 0, 3 do
				local face = at * CFrame.Angles(0, k * math.pi / 2, 0)
				local ww = w * 0.42
				local wh = (i == 1 and k == 0) and h - 1.6 or h - 2.4
				lattice(m, face * CFrame.new(0, (i == 1 and k == 0) and wh / 2 + 0.3 or h / 2 - 0.2, w / 2 + 0.1), ww, wh, PAL.gold:Lerp(PAL.plaster, 0.4))
			end
			Style.roof(m, at * CFrame.new(0, h + 0.9, 0), w, w, { rise = w * 0.22, over = 2.6, rows = 5 })
		end
		y += h + 0.9 + w * 0.22 * 0.35
	end
	m.Parent = parent
	return m
end

-- Open pavilion: four columns, a stone floor and a square curved roof.
function Style.pavilion(parent, cf, w, colH)
	local m = Instance.new("Model")
	m.Name = "Pavilion"
	plinth(m, cf, w + 2, w + 2, 1.2)
	local base = cf * CFrame.new(0, 1.5, 0)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = base * CFrame.new(sx * w / 2, 0, sz * w / 2)
			P(m, Vector3.new(1.6, 0.5, 1.6), at * CFrame.new(0, 0.25, 0), PAL.stone)
			cylY(m, colH, 1.1, at * CFrame.new(0, colH / 2 + 0.5, 0), PAL.vermilion)
			for k = 0, 1 do
				P(m, Vector3.new(1.2 + k * 0.8, 0.45, 1.2 + k * 0.8), at * CFrame.new(0, colH + 0.7 + k * 0.45, 0), k == 0 and PAL.jade or PAL.timber)
			end
		end
	end
	for _, sz in { -1, 1 } do
		P(m, Vector3.new(w + 1, 0.9, 0.9), base * CFrame.new(0, colH + 0.3, sz * w / 2), PAL.vermilion)
		P(m, Vector3.new(0.9, 0.9, w + 1), base * CFrame.new(sz * w / 2, colH + 0.3, 0), PAL.vermilion)
	end
	Style.roof(m, base * CFrame.new(0, colH + 1.9, 0), w + 1, w + 1, { rise = w * 0.32, over = 3, rows = 6 })
	m.Parent = parent
	return m
end

-- Sect wall along local Z (length L): stone footing, plaster body, posts and a tiled coping.
function Style.wall(parent, cf, L)
	local m = Instance.new("Model")
	m.Name = "Wall"
	P(m, Vector3.new(2.8, 1.4, L), cf * CFrame.new(0, 0.7, 0), PAL.stone)
	P(m, Vector3.new(1.8, 5, L), cf * CFrame.new(0, 3.9, 0), PAL.plaster)
	P(m, Vector3.new(1.9, 0.6, L), cf * CFrame.new(0, 6.1, 0), PAL.vermilion)
	local posts = math.floor(L / 10)
	for k = 0, posts do
		local z = -L / 2 + k * L / posts
		P(m, Vector3.new(2.2, 5.2, 1), cf * CFrame.new(0, 4, z), PAL.vermilion)
	end
	-- coping: two tilted tile slabs meeting at a ridge, with turned-up ends
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(2, 0.5, L + 1.6), cf * CFrame.new(sx * 0.85, 6.95, 0) * CFrame.Angles(0, 0, -sx * math.rad(24)), PAL.tile)
	end
	P(m, Vector3.new(0.8, 0.8, L + 1.8), cf * CFrame.new(0, 7.45, 0), PAL.tileDark)
	for _, sz in { -1, 1 } do
		P(m, Vector3.new(0.7, 1.6, 0.7), cf * CFrame.new(0, 8, sz * (L / 2 + 0.9)) * CFrame.Angles(sz * 0.5, 0, 0), PAL.tileDark)
	end
	m.Parent = parent
	return m
end

-- Qi gathering array: carved stone disc, 8 pillars (4 braziers with real fire, 4 jade orbs),
-- and a large jade orb floating over the centre on a bronze stand.
function Style.qiArray(parent, cf, r)
	local m = Instance.new("Model")
	m.Name = "QiArray"
	cylY(m, 0.6, r * 2 + 1, cf * CFrame.new(0, 0.3, 0), PAL.stone)
	cylY(m, 0.2, r * 2 - 1, cf * CFrame.new(0, 0.65, 0), PAL.timberDark)
	cylY(m, 0.25, r * 2 - 2, cf * CFrame.new(0, 0.7, 0), PAL.stoneLight)
	cylY(m, 0.3, r * 1.1, cf * CFrame.new(0, 0.75, 0), PAL.gold)
	cylY(m, 0.35, r * 0.9, cf * CFrame.new(0, 0.8, 0), PAL.stoneLight)
	-- eight trigram bars around the inner ring
	for i = 0, 7 do
		local a = i * math.pi / 4
		local at = cf * CFrame.new(math.cos(a) * r * 0.72, 0.9, math.sin(a) * r * 0.72) * CFrame.Angles(0, -a, 0)
		for k = -1, 1 do
			local broken = (i + k) % 3 == 0
			if broken then
				P(m, Vector3.new(0.3, 0.12, 0.9), at * CFrame.new(k * 0.55, 0, -0.65), PAL.timberDark)
				P(m, Vector3.new(0.3, 0.12, 0.9), at * CFrame.new(k * 0.55, 0, 0.65), PAL.timberDark)
			else
				P(m, Vector3.new(0.3, 0.12, 2.4), at * CFrame.new(k * 0.55, 0, 0), PAL.timberDark)
			end
		end
	end
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local at = cf * CFrame.new(math.cos(a) * (r - 0.6), 0, math.sin(a) * (r - 0.6))
		P(m, Vector3.new(1.4, 0.6, 1.4), at * CFrame.new(0, 0.9, 0), PAL.stone)
		P(m, Vector3.new(0.9, 3.6, 0.9), at * CFrame.new(0, 3, 0), PAL.stoneLight)
		if i % 2 == 0 then
			cylY(m, 0.7, 1.6, at * CFrame.new(0, 5.1, 0), Color3.fromHex("7A5A3A"), Enum.Material.Metal)
			local ember = P(m, Vector3.new(1, 0.2, 1), at * CFrame.new(0, 5.5, 0), Color3.fromRGB(255, 140, 60), Enum.Material.Neon)
			local fire = Instance.new("Fire")
			fire.Size = 1.6
			fire.Heat = 4
			fire.Parent = ember
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 160, 80)
			light.Range = 10
			light.Parent = ember
		else
			P(m, Vector3.new(1.1, 1.1, 1.1), at * CFrame.new(0, 5.3, 0), PAL.jade, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	-- centre: bronze tripod stand holding a glowing spirit orb (the orb is the light)
	for _, a in { 0, 120, 240 } do
		local ra = math.rad(a)
		rod(m, (cf * CFrame.new(math.cos(ra) * 1.8, 0.9, math.sin(ra) * 1.8)).Position, (cf * CFrame.new(0, 4.4, 0)).Position, 0.35, Color3.fromHex("7A5A3A"))
	end
	local orb = P(m, Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 5.8, 0), PAL.jade:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = PAL.jade
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = orb
	-- qi streaming INTO the orb: emitted from an invisible shell, moving inward
	-- (emitter Shape only works when the emitter's parent is a BasePart)
	local shell = P(m, Vector3.new(11, 11, 11), cf * CFrame.new(0, 5.8, 0), PAL.jade, nil, Enum.PartType.Ball)
	shell.Transparency = 1
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(PAL.jade:Lerp(Color3.new(1, 1, 1), 0.5))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.1, 0.35)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	pe.Speed = NumberRange.new(4, 4.5)
	pe.Lifetime = NumberRange.new(1, 1.15)
	pe.Rate = 16
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	pe.Parent = shell
	m.Parent = parent
	return m
end

-- Plank rope bridge between two world points at deck height.
function Style.bridge(parent, a, b, width)
	local m = Instance.new("Model")
	m.Name = "Bridge"
	local len = (b - a).Magnitude
	local base = CFrame.lookAt(a, b) -- -Z runs from a to b
	local rng = Random.new(math.floor(a.X + b.Z))
	local n = math.floor(len / 1.9)
	for i = 0, n do
		local d = i * len / n
		local woods = { PAL.timber, Color3.fromHex("6B4630"), Color3.fromHex("4F3324") }
		P(m, Vector3.new(width, 0.5, 1.55), base * CFrame.new(rng:NextNumber(-0.15, 0.15), -0.25, -d) * CFrame.Angles(0, math.rad(rng:NextNumber(-2, 2)), 0), woods[i % 3 + 1])
	end
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.8, 0.8, len), base * CFrame.new(sx * (width / 2 - 0.8), -0.8, -len / 2), PAL.timberDark)
		local posts = math.max(2, math.floor(len / 10))
		local prev
		for k = 0, posts do
			local d = k * len / posts
			local top = (base * CFrame.new(sx * (width / 2 + 0.2), 3.2, -d)).Position
			P(m, Vector3.new(0.7, 3.8, 0.7), base * CFrame.new(sx * (width / 2 + 0.2), 1.4, -d), PAL.timber)
			if prev then
				local mid = (prev + top) / 2 - Vector3.new(0, 0.6, 0) -- rope sag
				rod(m, prev, mid, 0.22, Color3.fromHex("C9B48A"))
				rod(m, mid, top, 0.22, Color3.fromHex("C9B48A"))
			end
			prev = top
		end
	end
	m.Parent = parent
	return m
end

-- Paifang archway with a small curved roof. Returns the plaque part (front = +Z of cf).
function Style.archway(parent, cf, width, height)
	local m = Instance.new("Model")
	m.Name = "Archway"
	for _, sx in { -1, 1 } do
		local at = cf * CFrame.new(sx * width / 2, 0, 0)
		P(m, Vector3.new(2.6, 1.4, 2.6), at * CFrame.new(0, 0.7, 0), PAL.stone)
		P(m, Vector3.new(1.0, 2.4, 3.6), at * CFrame.new(0, 1.2, 0), PAL.stoneLight) -- drum braces
		cylY(m, height, 1.4, at * CFrame.new(0, height / 2, 0), PAL.vermilion)
		cylY(m, 0.4, 1.6, at * CFrame.new(0, height - 2.6, 0), PAL.gold)
	end
	P(m, Vector3.new(width + 3, 1.2, 1.3), cf * CFrame.new(0, height - 1.6, 0), PAL.vermilion)
	P(m, Vector3.new(width + 3.1, 0.3, 1.4), cf * CFrame.new(0, height - 2.25, 0), PAL.gold)
	P(m, Vector3.new(width + 2, 0.9, 1.0), cf * CFrame.new(0, height - 3.4, 0), PAL.vermilion)
	for k = -2, 2 do
		P(m, Vector3.new(0.9, 0.6, 1.4), cf * CFrame.new(k * width / 5, height - 0.7, 0), k % 2 == 0 and PAL.jade or PAL.timber)
	end
	local plaque = P(m, Vector3.new(math.min(8, width * 0.55), 1.8, 0.3), cf * CFrame.new(0, height - 2.6, 0.8), PAL.timberDark)
	P(m, Vector3.new(math.min(8, width * 0.55) + 0.4, 2.2, 0.2), cf * CFrame.new(0, height - 2.6, 0.62), PAL.gold)
	Style.roof(m, cf * CFrame.new(0, height + 0.2, 0), width + 4, 3, { rise = 2.2, over = 1.6, rows = 4 })
	m.Parent = parent
	return plaque
end

-- Bronze incense cauldron (ding) with a real fire.
function Style.cauldron(parent, cf, scale)
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "Cauldron"
	local bronze = Color3.fromHex("7A5A3A")
	for _, a in { 0, 120, 240 } do
		local r = math.rad(a)
		P(m, Vector3.new(0.8, 2.2, 0.8) * s, cf * CFrame.new(math.cos(r) * 1.9 * s, 1.1 * s, math.sin(r) * 1.9 * s), bronze, Enum.Material.Metal)
	end
	cylY(m, 2.4 * s, 5 * s, cf * CFrame.new(0, 3.2 * s, 0), bronze, Enum.Material.Metal)
	cylY(m, 0.5 * s, 5.6 * s, cf * CFrame.new(0, 4.5 * s, 0), PAL.gold, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.5, 1.6, 1.4) * s, cf * CFrame.new(sx * 2.5 * s, 5.2 * s, 0), bronze, Enum.Material.Metal)
	end
	local ember = P(m, Vector3.new(3.6, 0.3, 3.6) * s, cf * CFrame.new(0, 4.6 * s, 0), Color3.fromRGB(255, 140, 60), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size = 4 * s
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = ember
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 22 * s
	light.Brightness = 1.8
	light.Parent = ember
	m.Parent = parent
	return m
end

-- Cumulus: a flat, slightly shaded base with cauliflower puffs piled on top, the way the
-- painted skybox draws its clouds. Opaque (no layered transparency), two tones only so the
-- balls batch, no collisions or queries.
local CLOUD_TOP = Color3.fromHex("FBF8F2")
local CLOUD_BASE = Color3.fromHex("B9C7E6") -- the painted sky shades its clouds blue, not grey
local SMOKE = "rbxasset://textures/particles/smoke_main.dds" -- built-in soft puff, no upload

-- Soft drifting mist hugging a cloud: breaks the hard silhouette of the solid puffs so they
-- read like the painted skybox clouds. Few, big, slow particles (cheap on phones).
local function mist(parent, cf, width, depth, height)
	local box = P(parent, Vector3.new(width, height, depth), cf, CLOUD_TOP)
	box.Transparency = 1
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SMOKE
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Color = ColorSequence.new(Color3.fromHex("FFFFFF"), Color3.fromHex("DCE6F7"))
	pe.LightInfluence = 0.6
	pe.LightEmission = 0.05
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, width * 0.22), NumberSequenceKeypoint.new(1, width * 0.34) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(9, 13)
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.SpreadAngle = Vector2.new(180, 30)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-4, 4)
	pe.Rate = math.clamp(width / 40, 0.6, 2.5)
	pe.Parent = box
	return box
end
Style.mist = mist
local function puff(parent, cf, size, color)
	local b = P(parent, size, cf, color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	b.CastShadow = false
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	return b
end

function Style.cumulus(parent, cf, width, seed)
	local rng = Random.new(seed or 1)
	local m = Instance.new("Model")
	m.Name = "Cumulus"
	local depth = width * rng:NextNumber(0.45, 0.65)
	-- flat shaded underside
	puff(m, cf * CFrame.new(0, 0, 0), Vector3.new(width * 1.05, width * 0.12, depth * 1.05), CLOUD_BASE)
	-- rows of puffs, fewer and bigger toward the top, shifted to make an uneven crown
	local rows = { { n = 7, s = 0.32, y = 0.06, spread = 0.95 }, { n = 5, s = 0.4, y = 0.18, spread = 0.7 }, { n = 3, s = 0.46, y = 0.32, spread = 0.42 }, { n = 1, s = 0.5, y = 0.45, spread = 0 } }
	local shift = rng:NextNumber(-0.15, 0.15) * width
	for ri, r in rows do
		for i = 1, r.n do
			local u = r.n == 1 and 0 or (i - 1) / (r.n - 1) * 2 - 1
			local x = u * width * 0.5 * r.spread + shift * (ri - 1) / 3 + rng:NextNumber(-0.04, 0.04) * width
			local z = rng:NextNumber(-0.2, 0.2) * depth
			local s = width * r.s * rng:NextNumber(0.8, 1.15) * (1 - math.abs(u) * 0.35)
			puff(m, cf * CFrame.new(x, width * r.y + s * 0.1, z), Vector3.new(s, s * 0.85, s), CLOUD_TOP)
		end
	end
	mist(m, cf * CFrame.new(0, width * 0.18, 0), width * 1.1, depth * 1.1, width * 0.35)
	m.Parent = parent
	return m
end

-- Soft cloud made only of big slow smoke particles (no solid balls): a blue-shaded base
-- layer and a white crown, like the painted skybox clouds. ~20-30 live particles each.
function Style.softCloud(parent, cf, width, seed)
	local rng = Random.new(seed or 1)
	local m = Instance.new("Model")
	m.Name = "SoftCloud"
	local function layer(offsetY, w, h, d, c0, c1, sizeK, rate, transp)
		local box = P(m, Vector3.new(w, h, d), cf * CFrame.new(rng:NextNumber(-0.05, 0.05) * width, offsetY, 0), CLOUD_TOP)
		box.Transparency = 1
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SMOKE
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.Color = ColorSequence.new(c0, c1)
		pe.LightInfluence = 0.35
		pe.LightEmission = 0
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, width * sizeK * 0.85), NumberSequenceKeypoint.new(1, width * sizeK) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, transp), NumberSequenceKeypoint.new(0.8, transp), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(14, 18)
		pe.Speed = NumberRange.new(0.1, 0.4)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-2, 2)
		pe.Rate = rate
		pe.Parent = box
		return pe
	end
	local depth = width * 0.55
	layer(0, width, width * 0.08, depth, CLOUD_BASE, Color3.fromHex("C9D5EE"), 0.32, 0.9, 0.05) -- flat shaded base
	layer(width * 0.14, width * 0.75, width * 0.16, depth * 0.8, Color3.fromHex("FFFFFF"), Color3.fromHex("F3F6FC"), 0.36, 0.9, 0) -- body
	layer(width * 0.3, width * 0.4, width * 0.1, depth * 0.5, Color3.fromHex("FFFFFF"), Color3.fromHex("FFFDF5"), 0.3, 0.45, 0) -- crown
	m.Parent = parent
	-- particles need time to fill in: pre-warm by emitting a lifetime's worth now
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d:Emit(math.ceil(d.Rate * 14))
		end
	end
	return m
end

-- A sea of cumulus around `center` between radii r0..r1, at height y below the islands.
function Style.cloudSea(parent, center, r0, r1, count, seed)
	local rng = Random.new(seed or 4)
	local f = Instance.new("Folder")
	f.Name = "CloudSea"
	for i = 1, count do
		local a = i / count * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(r0, r1)
		local w = rng:NextNumber(80, 140) * (0.75 + r / r1 * 0.6) -- farther clouds are bigger
		local y = rng:NextNumber(-12, 12) - (r / r1) * 25
		local cf = CFrame.new(center + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a + math.pi / 2 + rng:NextNumber(-0.4, 0.4), 0)
		Style.softCloud(f, cf, w, i * 7 + (seed or 0))
		if i % 6 == 0 then
			task.wait()
		end
	end
	f.Parent = parent
	return f
end

-- Waterfall pouring off an island's rim at local angle `a` (radians): a pool on the grass,
-- a falling white stream (particles: no Glass, no Terrain water) and mist at its foot.
function Style.waterfall(parent, cf, radius, a)
	local m = Instance.new("Model")
	m.Name = "Waterfall"
	-- edge frame: local -Z points outward over the rim
	local edge = cf * CFrame.new(math.cos(a) * (radius - 1), 0, math.sin(a) * (radius - 1)) * CFrame.Angles(0, -a - math.pi / 2, 0)
	cylY(m, 0.3, 7, edge * CFrame.new(0, 0.05, 3), Color3.fromHex("5FB7D8"))
	cylY(m, 0.6, 8, edge * CFrame.new(0, -0.15, 3), PAL.stone)
	P(m, Vector3.new(3, 0.25, 4), edge * CFrame.new(0, 0.1, 0), Color3.fromHex("7CCBE6"))
	local function emitterBox(size, at)
		local b = P(m, size, at, Color3.new(1, 1, 1))
		b.Transparency = 1
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		return b
	end
	local fall = Instance.new("ParticleEmitter")
	fall.Texture = SMOKE
	fall.Shape = Enum.ParticleEmitterShape.Box
	fall.Color = ColorSequence.new(Color3.fromHex("F2FBFF"), Color3.fromHex("BFE6F5"))
	fall.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.5) })
	fall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	fall.Lifetime = NumberRange.new(2.4, 2.8)
	fall.Speed = NumberRange.new(2, 3)
	fall.EmissionDirection = Enum.NormalId.Front
	fall.Acceleration = Vector3.new(0, -16, 0)
	fall.SpreadAngle = Vector2.new(4, 4)
	fall.LightInfluence = 0.5
	fall.Rate = 26
	fall.Parent = emitterBox(Vector3.new(2.6, 0.2, 0.4), edge * CFrame.new(0, 0, -1.6))
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = SMOKE
	spray.Shape = Enum.ParticleEmitterShape.Box
	spray.Color = ColorSequence.new(Color3.fromHex("FFFFFF"))
	spray.Size = NumberSequence.new(5, 11)
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(3, 4)
	spray.Speed = NumberRange.new(1, 2)
	spray.SpreadAngle = Vector2.new(180, 180)
	spray.LightInfluence = 0.5
	spray.Rate = 4
	spray.Parent = emitterBox(Vector3.new(8, 2, 8), edge * CFrame.new(0, -48, -6))
	m.Parent = parent
	return m
end

-- Soft opaque cloud bank (legacy, kept for the first pass).
function Style.cloud(parent, cf, size, seed)
	local rng = Random.new(seed or 9)
	local m = Instance.new("Model")
	m.Name = "Cloud"
	for i = 1, 7 do
		local s = size * rng:NextNumber(0.45, 0.8)
		local off = Vector3.new(rng:NextNumber(-1, 1) * size * 0.7, rng:NextNumber(-0.1, 0.35) * size * 0.4, rng:NextNumber(-1, 1) * size * 0.4)
		local b = P(m, Vector3.new(s, s * 0.62, s), cf * CFrame.new(off), Color3.fromHex("F4EDE4"), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		b.CastShadow = false
		b.CanCollide = false
	end
	-- cool underside
	local u = P(m, Vector3.new(size * 1.6, size * 0.25, size * 0.9), cf * CFrame.new(0, -size * 0.12, 0), Color3.fromHex("D9D3E6"), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	u.CastShadow = false
	u.CanCollide = false
	m.Parent = parent
	return m
end

return Style
