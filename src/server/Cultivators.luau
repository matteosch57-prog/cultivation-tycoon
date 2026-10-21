-- Seated cultivator models for the Meditation Platform. Four looks (sword disciple, lotus maiden,
-- pill monk, elder sage); the rarity sets the robe colour, the trim and the aura tier.
-- Front faces -Z (LookVector). `cf` is the ground point under the cushion.
-- Auras are glowing objects only (particles, ForceField shells): no Light instances (RULES R3),
-- one emitter per model and low rates so a full platform stays cheap on phones.
local Cultivators = {}

local CREAM = Color3.fromRGB(245, 240, 230)
local SKIN = Color3.fromRGB(238, 204, 176)
local HAIR = Color3.fromRGB(28, 24, 26)
local WHITE_HAIR = Color3.fromRGB(232, 230, 226)
local GOLD = Color3.fromHex("D4A445")
local SILVER = Color3.fromRGB(205, 210, 220)
local CUSHION = Color3.fromHex("B8352B"):Lerp(Color3.new(0, 0, 0), 0.3)
local INK = Color3.fromRGB(40, 30, 30)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

Cultivators.LOOKS = { "sword", "lotus", "monk", "elder" }

local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function ball(parent, d, cf, color, mat)
	return P(parent, Vector3.new(d, d, d), cf, color, mat, Enum.PartType.Ball)
end

-- tier 1..5 from the rarity's place in Config.RARITIES
local function tierOf(rarity, rarities)
	for i, r in rarities do
		if r.name == rarity.name then
			return i
		end
	end
	return 1
end

local function colours(rarity, tier)
	local c = {}
	c.robe = rarity.color:Lerp(CREAM, tier == 1 and 0.45 or 0.3)
	c.robeDark = rarity.color:Lerp(Color3.new(0, 0, 0), 0.25)
	c.trim = (tier >= 5 and CREAM) or (tier == 4 and GOLD) or (tier == 3 and SILVER) or CREAM
	c.aura = rarity.color
	return c
end

-- the shared seated body: cushion, crossed legs, robe, sleeves, hands, head with closed eyes
local function body(m, f, c)
	P(m, Vector3.new(0.5, 3.2, 3.2), f * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.pi / 2), CUSHION, nil, Enum.PartType.Cylinder)
	P(m, Vector3.new(3.2, 0.9, 1.9), f * CFrame.new(0, 2.15, -0.2), c.robeDark) -- lap
	P(m, Vector3.new(2.2, 1.0, 1.4), f * CFrame.new(0, 2.85, 0.15), c.robe) -- skirt
	P(m, Vector3.new(1.8, 1.3, 1.1), f * CFrame.new(0, 3.95, 0.15), c.robe) -- torso
	P(m, Vector3.new(0.25, 1.5, 1.12), f * CFrame.new(-0.18, 4.05, 0.15) * CFrame.Angles(0, 0, math.rad(-22)), c.trim) -- crossed collar
	P(m, Vector3.new(0.25, 1.5, 1.12), f * CFrame.new(0.18, 4.05, 0.13) * CFrame.Angles(0, 0, math.rad(22)), c.trim)
	P(m, Vector3.new(1.95, 0.35, 1.2), f * CFrame.new(0, 3.25, 0.15), c.robeDark) -- sash
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.8, 1.6, 0.9), f * CFrame.new(sx * 1.15, 3.55, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(sx * 12)), c.robe)
		P(m, Vector3.new(0.95, 0.55, 0.95), f * CFrame.new(sx * 1.25, 2.75, -0.55), c.robe) -- wide sleeve cuff
		P(m, Vector3.new(0.97, 0.14, 0.97), f * CFrame.new(sx * 1.25, 2.55, -0.55), c.trim)
		P(m, Vector3.new(0.45, 0.4, 0.45), f * CFrame.new(sx * 1.2, 2.75, -1.1), SKIN)
	end
	P(m, Vector3.new(0.5, 0.4, 0.5), f * CFrame.new(0, 4.75, 0.15), SKIN) -- neck
	P(m, Vector3.new(1.25, 1.35, 1.25), f * CFrame.new(0, 5.55, 0.15), SKIN) -- head
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.3, 0.07, 0.05), f * CFrame.new(sx * 0.28, 5.62, -0.48), INK) -- closed eyes
	end
end

local function hairCap(m, f, color)
	P(m, Vector3.new(1.35, 0.6, 1.35), f * CFrame.new(0, 6.05, 0.25), color)
	P(m, Vector3.new(1.35, 1.1, 0.4), f * CFrame.new(0, 5.55, 0.75), color) -- back of the head
end

local LOOK = {}

-- young sword disciple: topknot with ribbon tails, a sword across the back
function LOOK.sword(m, f, c)
	hairCap(m, f, HAIR)
	ball(m, 0.7, f * CFrame.new(0, 6.55, 0.3), HAIR)
	P(m, Vector3.new(0.9, 0.18, 0.18), f * CFrame.new(0, 6.55, 0.3), c.trim) -- hairpin
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.18, 1.2, 0.06), f * CFrame.new(sx * 0.2, 6.0, 0.72) * CFrame.Angles(math.rad(15), 0, math.rad(sx * 10)), c.robeDark) -- ribbon tails
	end
	local back = f * CFrame.new(0, 4.0, 0.85) * CFrame.Angles(0, 0, math.rad(35))
	P(m, Vector3.new(0.32, 3.6, 0.22), back, Color3.fromHex("3A261C")) -- scabbard
	P(m, Vector3.new(0.34, 0.25, 0.24), back * CFrame.new(0, -1.5, 0), c.trim) -- chape
	P(m, Vector3.new(0.9, 0.16, 0.3), back * CFrame.new(0, 1.85, 0), c.trim) -- guard
	P(m, Vector3.new(0.2, 0.75, 0.2), back * CFrame.new(0, 2.3, 0), INK) -- grip
	ball(m, 0.26, back * CFrame.new(0, 2.72, 0), c.trim) -- pommel
end

-- lotus maiden: long hair down the back, twin buns, a shawl ribbon looped over the arms
function LOOK.lotus(m, f, c)
	hairCap(m, f, HAIR)
	P(m, Vector3.new(1.3, 2.2, 0.35), f * CFrame.new(0, 4.85, 0.85), HAIR) -- long hair
	for _, sx in { -1, 1 } do
		ball(m, 0.55, f * CFrame.new(sx * 0.55, 6.35, 0.3), HAIR)
		-- shawl: over the shoulder, down behind the sleeve, out past the knee
		P(m, Vector3.new(0.12, 1.3, 0.5), f * CFrame.new(sx * 1.55, 3.6, 0.4) * CFrame.Angles(0, 0, math.rad(sx * 20)), c.trim)
		P(m, Vector3.new(0.12, 0.5, 1.6), f * CFrame.new(sx * 1.85, 2.9, -0.3) * CFrame.Angles(math.rad(10), 0, math.rad(sx * 15)), c.trim)
	end
	P(m, Vector3.new(2.6, 0.12, 0.5), f * CFrame.new(0, 4.5, 0.55) * CFrame.Angles(math.rad(-20), 0, 0), c.trim) -- shawl across the back
	ball(m, 0.38, f * CFrame.new(0.55, 6.15, -0.05), Color3.fromHex("F4B6C2")) -- hair flower
end

-- pill monk: shaved head, bead necklace, a gourd at the hip
function LOOK.monk(m, f, c)
	P(m, Vector3.new(1.27, 0.25, 1.27), f * CFrame.new(0, 6.25, 0.15), SKIN) -- smooth crown
	for i = 0, 6 do
		local a = math.rad(-75 + i * 25)
		ball(m, 0.22, f * CFrame.new(math.sin(a) * 0.62, 4.4 - math.cos(a) * 0.55, -0.45), Color3.fromHex("5A3A29"))
	end
	ball(m, 0.32, f * CFrame.new(0, 3.75, -0.47), c.trim) -- the large bead
	local hip = f * CFrame.new(1.55, 2.6, 0.35)
	ball(m, 0.75, hip, Color3.fromHex("C9A15A")) -- gourd
	ball(m, 0.5, hip * CFrame.new(0, 0.55, 0), Color3.fromHex("C9A15A"))
	P(m, Vector3.new(0.52, 0.1, 0.52), hip * CFrame.new(0, 0.3, 0), c.robeDark) -- gourd cord
end

-- elder sage: white hair and beard, a crown on the bun, a horsetail whisk in the crook of the arm
function LOOK.elder(m, f, c)
	hairCap(m, f, WHITE_HAIR)
	ball(m, 0.6, f * CFrame.new(0, 6.5, 0.3), WHITE_HAIR)
	P(m, Vector3.new(0.5, 0.45, 0.6), f * CFrame.new(0, 6.75, 0.3), c.trim) -- guan crown
	P(m, Vector3.new(0.7, 0.8, 0.25), f * CFrame.new(0, 4.95, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), WHITE_HAIR) -- beard
	P(m, Vector3.new(0.35, 0.5, 0.22), f * CFrame.new(0, 4.35, -0.68) * CFrame.Angles(math.rad(-10), 0, 0), WHITE_HAIR) -- beard tip
	for _, sx in { -1, 1 } do
		P(m, Vector3.new(0.4, 0.1, 0.08), f * CFrame.new(sx * 0.3, 5.82, -0.5), WHITE_HAIR) -- brows
	end
	local w = f * CFrame.new(-1.3, 3.3, -0.8) * CFrame.Angles(math.rad(-20), 0, math.rad(25))
	P(m, Vector3.new(0.14, 1.7, 0.14), w, Color3.fromHex("5A3A29")) -- whisk handle
	local top = w * CFrame.new(0, 0.85, 0)
	for i, d in { 0.3, 0.24, 0.17 } do
		ball(m, d, top * CFrame.Angles(0, 0, math.rad(-70)) * CFrame.new(0, -0.15 - i * 0.22, 0), WHITE_HAIR) -- horsetail tuft
	end
	P(m, Vector3.new(0.12, 1.1, 0.12), top * CFrame.Angles(0, 0, math.rad(-150)) * CFrame.new(0, 0.55, 0), WHITE_HAIR)
end

-- aura tiers: 1 none, 2 a small ground ring, 3 a wide ring + rising motes, 4 + halo, 5 + three qi orbs
local function aura(m, f, c, tier)
	if tier < 2 then
		return
	end
	if tier >= 3 then
		local core = P(m, Vector3.new(3.4, 0.2, 3.4), f * CFrame.new(0, 1.2, 0), c.aura)
		core.Transparency = 1
		core.Name = "Aura"
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SPARKLE
		pe.Color = ColorSequence.new(c.aura)
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5 + tier * 0.15), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.15)
		pe.Lifetime = NumberRange.new(2.5, 3.5)
		pe.Speed = NumberRange.new(0.8, 1.4)
		pe.Acceleration = Vector3.new(0, 0.4, 0)
		pe.Rate = ({ 0, 0, 5, 7, 10 })[tier]
		pe.SpreadAngle = Vector2.new(15, 15)
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = core
	end
	do
		local d = tier == 2 and 3.8 or 4.6
		local ring = P(m, Vector3.new(0.1, d, d), f * CFrame.new(0, 1.32, 0) * CFrame.Angles(0, 0, math.pi / 2), c.aura, Enum.Material.ForceField, Enum.PartType.Cylinder)
		ring.Name = "AuraRing"
	end
	if tier >= 4 then
		local halo = P(m, Vector3.new(0.1, 3.4, 3.4), f * CFrame.new(0, 5.6, 0.95) * CFrame.Angles(0, math.pi / 2, 0), c.aura, Enum.Material.ForceField, Enum.PartType.Cylinder)
		halo.Name = "Halo"
	end
	if tier >= 5 then
		for i = 0, 2 do
			local a = math.rad(90 + i * 120)
			local orb = ball(m, 0.4, f * CFrame.new(math.cos(a) * 2.4, 4.6 + (i % 2) * 0.6, math.sin(a) * 2.4), c.aura, Enum.Material.Neon)
			orb.Name = "QiOrb"
		end
	end
end

-- build one cultivator. look: one of LOOKS (or an index), rarity: a Config.RARITIES entry.
function Cultivators.build(parent, cf, look, rarity, rarities)
	if typeof(look) == "number" then
		look = Cultivators.LOOKS[(look - 1) % #Cultivators.LOOKS + 1]
	end
	local tier = tierOf(rarity, rarities)
	local c = colours(rarity, tier)
	local m = Instance.new("Model")
	m.Name = "Cultivator_" .. look
	m:SetAttribute("Look", look)
	m:SetAttribute("Rarity", rarity.name)
	body(m, cf, c)
	LOOK[look](m, cf, c)
	aura(m, cf, c, tier)
	m.Parent = parent
	return m
end

return Cultivators
