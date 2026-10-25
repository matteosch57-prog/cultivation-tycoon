-- Sect Styles (Config.SECT_STYLES; research docs/research/2026-10-25_rebirth_new_looks.md, mocks
-- docs/art/mocks/2026-10-25_sect_style_*.png): a rebirth's whole-sect look. dress() recolours a built
-- model to the style's map and puts the style's ornaments on the top ridge of every kit roof (a roof
-- = the ClayRoofTiles parts of one Model, read before the recolour can change their material).
-- ambience() hangs one particle box over the peak. Phone budget (R16): ornaments are a few blocks
-- per roof, no lights, no shadows, never collide; one emitter a peak.
local Style = require(script.Parent:WaitForChild("Style"))

local SectStyle = {}

local PAL = Style.PAL
local GOLD = PAL.gold

local function P(parent, size, cf, color, mat, shape)
	local p = Style.P(parent, size, cf, color, mat, shape)
	p.Name = "StyleOrn"
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- the top ridge of every roofed Model inside `model`: { c = centre, a / b = ridge ends, s = scale }
local function ridges(model)
	local holders = { model }
	for _, d in model:GetDescendants() do
		if d:IsA("Model") then
			table.insert(holders, d)
		end
	end
	local out = {}
	for _, h in holders do
		local top, tiles = -math.huge, {}
		for _, p in h:GetChildren() do
			if p:IsA("BasePart") and p.Material == Enum.Material.ClayRoofTiles then
				table.insert(tiles, p)
				top = math.max(top, p.Position.Y)
			end
		end
		if #tiles > 0 then
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in tiles do
				if p.Position.Y > top - 3 then
					minX, maxX = math.min(minX, p.Position.X), math.max(maxX, p.Position.X)
					minZ, maxZ = math.min(minZ, p.Position.Z), math.max(maxZ, p.Position.Z)
				end
			end
			local w, d = maxX - minX, maxZ - minZ
			local cx, cz, y = (minX + maxX) / 2, (minZ + maxZ) / 2, top + 0.6
			-- the ridge runs along the long side
			local half = math.abs(w - d) / 2
			local along = w >= d and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
			local c = Vector3.new(cx, y, cz)
			table.insert(out, { c = c, a = c - along * half, b = c + along * half, s = math.clamp(math.max(w, d) / 24, 0.6, 1.4) })
		end
	end
	return out
end

-- ornaments ------------------------------------------------------------------------------------
local function pearl(m, at, s, color, mat)
	local d = 1.6 * s
	P(m, Vector3.new(0.5, 1, 0.5) * s, CFrame.new(at + Vector3.new(0, 0.5 * s, 0)), GOLD, Enum.Material.Metal)
	P(m, Vector3.new(d, d, d), CFrame.new(at + Vector3.new(0, s + d / 2, 0)), color, mat or Enum.Material.Glass, Enum.PartType.Ball)
end
local function chiwen(m, at, toward, s, color) -- a ridge beast facing the ridge's middle
	local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local cf = CFrame.lookAt(at, at + flat.Unit)
	P(m, Vector3.new(0.9, 2.2, 1.4) * s, cf * CFrame.new(0, 1.1 * s, 0), color, Enum.Material.Metal)
	P(m, Vector3.new(0.9, 0.9, 1.3) * s, cf * CFrame.new(0, 2.4 * s, 0.5 * s) * CFrame.Angles(-0.5, 0, 0), color, Enum.Material.Metal)
	P(m, Vector3.new(0.7, 0.8, 0.9) * s, cf * CFrame.new(0, 1.7 * s, -1 * s), color, Enum.Material.Metal)
end
local function crystal(m, at, s, color)
	local p = P(m, Vector3.new(1.7, 4.8, 1.7) * s, CFrame.new(at + Vector3.new(0, 2.4 * s, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)), color, Enum.Material.Glass)
	p.Transparency = 0.15
end
local function crescent(m, at, s, color)
	local cf = CFrame.new(at + Vector3.new(0, 2.4 * s, 0))
	for i = 0, 6 do
		local a = math.rad(-110 + i * 36)
		P(m, Vector3.new(0.5, 1.1, 0.5) * s, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.8 * s, 0), color, Enum.Material.Metal)
	end
	P(m, Vector3.new(0.4, 2.4, 0.4) * s, CFrame.new(at + Vector3.new(0, 1.2 * s, 0)), color, Enum.Material.Metal)
end
local function rod(m, at, s, glow)
	P(m, Vector3.new(0.35, 4.5, 0.35) * s, CFrame.new(at + Vector3.new(0, 2.25 * s, 0)), GOLD, Enum.Material.Metal)
	for k = 1, 2 do
		P(m, Vector3.new(1.3 - k * 0.3, 0.2, 1.3 - k * 0.3) * s, CFrame.new(at + Vector3.new(0, (1 + k * 1.3) * s, 0)), GOLD, Enum.Material.Metal)
	end
	P(m, Vector3.new(0.7, 0.7, 0.7) * s, CFrame.new(at + Vector3.new(0, 4.8 * s, 0)), glow, Enum.Material.Neon, Enum.PartType.Ball)
end
local function feather(m, at, s, color)
	local cf = CFrame.new(at)
	for i = -2, 2 do
		P(m, Vector3.new(0.4, 3, 0.2) * s, cf * CFrame.Angles(0, 0, i * 0.28) * CFrame.new(0, 1.6 * s, 0), color, Enum.Material.Foil)
	end
end
local function star(m, at, s, color)
	P(m, Vector3.new(0.5, 2.4, 0.5) * s, CFrame.new(at + Vector3.new(0, 1.2 * s, 0)), PAL.stoneLight, Enum.Material.Metal)
	for k = 0, 2 do
		P(m, Vector3.new(0.5, 3.2, 0.5) * s, CFrame.new(at + Vector3.new(0, 3.4 * s, 0)) * CFrame.Angles(0, 0, k * math.pi / 3), color, Enum.Material.Neon)
	end
end

-- what each `orn` puts on a ridge: the centre piece and the two ends
local ORN = {
	crystal = function(m, r, st)
		crystal(m, r.c, r.s * 1.2, st.ornColor)
		crystal(m, r.a, r.s * 0.7, st.ornColor)
		crystal(m, r.b, r.s * 0.7, st.ornColor)
	end,
	forge = function(m, r, st)
		pearl(m, r.c, r.s, st.ornColor, Enum.Material.Neon)
		chiwen(m, r.a, r.c, r.s, Color3.fromHex("2A2422"))
		chiwen(m, r.b, r.c, r.s, Color3.fromHex("2A2422"))
	end,
	blossom = function(m, r, st)
		pearl(m, r.c, r.s, st.ornColor, Enum.Material.Glass)
	end,
	crescent = function(m, r, st)
		crescent(m, r.c, r.s, st.ornColor)
		pearl(m, r.a, r.s * 0.7, Color3.fromHex("BFD4FF"))
		pearl(m, r.b, r.s * 0.7, Color3.fromHex("BFD4FF"))
	end,
	rod = function(m, r, st)
		rod(m, r.c, r.s, st.ornColor)
		rod(m, r.a, r.s * 0.7, st.ornColor)
		rod(m, r.b, r.s * 0.7, st.ornColor)
	end,
	dragon = function(m, r, st)
		pearl(m, r.c, r.s * 1.2, st.ornColor, Enum.Material.Foil)
		chiwen(m, r.a, r.c, r.s, Color3.fromHex("2F8F5A"))
		chiwen(m, r.b, r.c, r.s, Color3.fromHex("2F8F5A"))
	end,
	pearl = function(m, r, st)
		pearl(m, r.c, r.s * 1.1, st.ornColor)
		pearl(m, r.a, r.s * 0.6, st.ornColor)
		pearl(m, r.b, r.s * 0.6, st.ornColor)
	end,
	feather = function(m, r, st)
		feather(m, r.c, r.s * 1.2, st.ornColor)
		feather(m, r.a, r.s * 0.7, st.ornColor)
		feather(m, r.b, r.s * 0.7, st.ornColor)
	end,
	star = function(m, r, st)
		star(m, r.c, r.s * 1.2, st.ornColor)
		star(m, r.a, r.s * 0.7, st.ornColor)
		star(m, r.b, r.s * 0.7, st.ornColor)
	end,
}

-- `recolour(model, map)` = Skin.recolour (passed in: Skin requires this module)
function SectStyle.dress(model, st, recolour)
	local spots = ridges(model)
	recolour(model, st.map)
	local orn = ORN[st.orn]
	if not orn or #spots == 0 then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "StyleOrnaments"
	for _, r in spots do
		orn(holder, r, st)
	end
	holder.Parent = model
end

-- one drifting particle box over the peak (`frame` = the peak frame, `radius` = the island's)
function SectStyle.ambience(parent, frame, radius, st)
	local box = Instance.new("Part")
	box.Name = "StyleAmbience"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(radius * 1.6, 1, radius * 1.6)
	local fx = st.fx
	box.CFrame = frame * CFrame.new(0, (fx.accel and fx.accel.Y > 0) and 6 or 40, -10) -- rising motes start low, falling ones high
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(fx.color)
	pe.LightEmission = fx.light or 0
	pe.LightInfluence = fx.light and 0.3 or 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, fx.size or 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(6, 9)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Acceleration = fx.accel or Vector3.new(0, -1, 0)
	pe.Rate = 12
	pe.Parent = box
	box.Parent = parent
	return box
end

return SectStyle
