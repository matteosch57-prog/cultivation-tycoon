-- Flying Sword looks (D76): one template per tier, built once per server and cloned on every mount.
-- The look is the owner-reviewed Studio mock v9 (tools/mock_swords_tiers.luau on the mock branch):
-- the Creator Store blade with a Highlight in the tier colour, ribbons wound round the blade, a
-- shimmer from hilt to tip, motes, the aura asset's emitters spread along the blade, sparks off the
-- hilt and (tier 3) a double gold halo. Every effect hangs off the SWORD, never the rider (owner:
-- "aura only on sword"). Trails are real Trails off the hilt, so they stream only while moving.
--
-- A template is a Model in the blade's frame: nose to -Z, the flat of the blade up, centred on the
-- origin, `Config.SWORD_RIDE.length` long, its top face at y = top. Every part is unanchored,
-- massless, never collides or touches, welded to the invisible `Core`, which SwordRide welds to the
-- rider's root part. The blades come from SwordData (dumped from the Creator Store models in Studio
-- by tools/dump_swords.luau, scripts deleted, R12); until that data exists a plain built blade in the
-- tier colours stands in.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local SwordData = require(script.Parent:WaitForChild("SwordData"))

local SwordLook = {}

local RIDE = Config.SWORD_RIDE
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GLOW = "rbxassetid://" .. Config.AURA_TEX.glow
local GOLD = Color3.fromHex("FFD34D")
local STEEL = Color3.fromHex("E4FBFF")

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function loose(p)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function attach(core, cf)
	local a = Instance.new("Attachment")
	a.CFrame = cf -- Core sits at the origin of the blade frame, so local = blade frame
	a.Parent = core
	return a
end

-- a plain stand-in blade (before SwordData has the real ones): steel blade, gold guard, red grip
local function fallbackParts(m, tier, length)
	local L = length
	local function part(size, cf, color, material, shape)
		local p = loose(Instance.new("Part"))
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.Parent = m
		return p
	end
	local blade = tier == 2 and GOLD or STEEL
	part(Vector3.new(0.9 + tier * 0.15, 0.22, L * 0.72), CFrame.new(0, 0, -L * 0.12), blade, Enum.Material.Metal)
	part(Vector3.new(0.45, 0.23, L * 0.12), CFrame.new(0, 0, -L * 0.53), blade, Enum.Material.Metal) -- the tip
	part(Vector3.new(2.4, 0.4, 0.45), CFrame.new(0, 0, L * 0.26), GOLD, Enum.Material.Metal) -- guard
	part(Vector3.new(0.38, 0.38, L * 0.18), CFrame.new(0, 0, L * 0.38), Color3.fromHex("8E1F1A")) -- grip
	part(Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0, L * 0.49), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	return 0.22
end

-- the real blade from SwordData: each mesh drawn as a Part with a FileMesh (a SpecialMesh's MeshId can
-- be set by a game script; a MeshPart's cannot), sized and placed as the dump measured it
local function dataParts(m, d, length)
	local k = length / d.length
	for _, e in d.parts do
		local p = loose(Instance.new("Part"))
		p.Size = v3(e.size) * k
		local c = e.cf
		p.CFrame = CFrame.new(c[1] * k, c[2] * k, c[3] * k, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		p.Color = Color3.new(e.color[1], e.color[2], e.color[3])
		p.Material = Enum.Material[e.material] or Enum.Material.SmoothPlastic
		p.Transparency = e.transparency or 0
		p.Reflectance = e.reflectance or 0
		if e.mesh then
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.FileMesh
			sm.MeshId = e.mesh
			sm.TextureId = e.tex or ""
			sm.Scale = e.scale and v3(e.scale) * k or Vector3.one
			if e.vertexColor then
				sm.VertexColor = v3(e.vertexColor)
			end
			sm.Parent = p
		elseif e.shape then
			p.Shape = Enum.PartType[e.shape] or Enum.PartType.Block
		end
		p.Parent = m
	end
	return d.thickness * k
end

local function beam(core, a0, a1, color, w0, w1, alpha)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 4
	b.Width0, b.Width1 = w0, w1 or w0
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new(alpha or 0.15)
	b.Parent = core
	return b
end

local function motes(att, color, rate, size, speed, life)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(life or 0.6, (life or 0.6) * 1.6)
	e.Speed = NumberRange.new(speed or 0.2, (speed or 0.2) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.LockedToPart = true
	e.Parent = att
	return e
end

-- a ribbon wound `turns` times round the blade from hilt to tip; it thins toward the tip. 14 straight
-- beams (the mock's 28 halved for phones)
local function ribbon(core, L, top, color, turns, phase, width)
	local steps = 14
	local prev
	for k = 0, steps do
		local f = k / steps
		local a = phase + f * turns * math.pi * 2
		local at = attach(core, CFrame.new(math.cos(a) * 0.45, top * 0.5 + math.sin(a) * 0.22, L / 2 - f * L))
		if prev then
			beam(core, prev, at, color, width * (1 - f * 0.6), width * (1 - (f + 1 / steps) * 0.6), 0.1)
		end
		prev = at
	end
end

local function seq(t)
	local kps = {}
	for _, k in t do
		table.insert(kps, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0))
	end
	return NumberSequence.new(kps)
end
local function colors(t)
	local kps = {}
	for _, k in t do
		table.insert(kps, ColorSequenceKeypoint.new(k[1], Color3.new(k[2], k[3], k[4])))
	end
	return ColorSequence.new(kps)
end

-- the aura asset's emitters (dumped into SwordData, already scaled to a blade by the dump) on
-- `points` attachments along the blade top
local function auraEmitters(core, L, top, list, points)
	if not list or #list == 0 then
		return
	end
	local atts = {}
	for i = 1, points do
		table.insert(atts, attach(core, CFrame.new(0, top, (i - 0.5) / points * L - L / 2)))
	end
	for _, e in list do
		for _, a in atts do
			local p = Instance.new("ParticleEmitter")
			p.Texture = e.texture
			p.Color = colors(e.color)
			p.Size = seq(e.size)
			p.Transparency = seq(e.transparency)
			p.Lifetime = NumberRange.new(e.lifetime[1], e.lifetime[2])
			p.Speed = NumberRange.new(e.speed[1], e.speed[2])
			p.Rate = math.max(1, e.rate / points)
			p.SpreadAngle = Vector2.new(e.spread[1], e.spread[2])
			p.LightEmission = e.lightEmission or 1
			p.LightInfluence = 0
			p.RotSpeed = NumberRange.new(e.rotSpeed[1], e.rotSpeed[2])
			p.Rotation = NumberRange.new(e.rotation[1], e.rotation[2])
			p.Drag = e.drag or 0
			p.ZOffset = e.zOffset or 0
			p.Orientation = Enum.ParticleOrientation.FacingCamera
			p.LockedToPart = true
			p.Parent = a
		end
	end
end

-- a real Trail between two attachments stacked over the hilt (so it is a ribbon behind the blade)
local function trail(core, L, color, texture, life, width, alpha, emission)
	local a0 = attach(core, CFrame.new(0, width / 2, L / 2))
	local a1 = attach(core, CFrame.new(0, -width / 2, L / 2))
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Texture = "rbxassetid://" .. texture
	t.TextureMode = Enum.TextureMode.Stretch
	t.Lifetime = life
	t.MinLength = 0.2
	t.FaceCamera = true
	t.LightEmission = emission
	t.LightInfluence = 0
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, alpha), NumberSequenceKeypoint.new(0.7, 0.5 + alpha / 2), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.3)
	t.Parent = core
	return t
end

local templates = {}

function SwordLook.template(tier)
	if templates[tier] then
		return templates[tier]
	end
	local def = RIDE.tiers[tier]
	local L = RIDE.length
	local m = Instance.new("Model")
	m.Name = "RideSword"
	local core = loose(Instance.new("Part"))
	core.Name = "Core"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.CFrame = CFrame.new()
	core.Parent = m
	m.PrimaryPart = core
	local blade = Instance.new("Model")
	blade.Name = "Blade"
	blade.Parent = m
	local d = SwordData[tier]
	local thick = d and dataParts(blade, d, L) or fallbackParts(blade, tier, L)
	local top = thick / 2
	m:SetAttribute("Top", top) -- SwordRide puts the rider's feet on it
	for _, p in blade:GetChildren() do
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = core, p
		w.Parent = p
	end
	-- the blade edge glow in the tier colour (a slim blade still reads at distance)
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = def.color, def.color
	h.FillTransparency = ({ 0.6, 0.75, 0.7 })[tier]
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = blade
	-- the ribbons, one per tier step
	local RIBBONS = {
		{ { def.color, 0.9, 0 } },
		{ { Color3.fromHex("FFE9A0"), 1.2, 0 }, { Color3.fromHex("FFB52E"), 1.2, math.pi } },
		{ { Color3.new(1, 1, 1), 1.5, 0 }, { Color3.fromHex("8FD3FF"), 1.5, math.pi * 2 / 3 }, { GOLD, 1.5, math.pi * 4 / 3 } },
	}
	for _, r in RIBBONS[tier] do
		ribbon(core, L, top, r[1], r[2], r[3], 0.07 + tier * 0.015)
	end
	-- motes along the blade
	for k = 1, 2 + tier do
		local a = attach(core, CFrame.new(0, top + 0.2, L / 2 - (k - 0.5) / (2 + tier) * L))
		motes(a, tier == 3 and Color3.fromHex("DFF3FF") or def.color, 2 + tier * 2, 0.16 + tier * 0.07)
	end
	auraEmitters(core, L, top, d and d.aura, 2 + tier)
	if tier == 2 then
		-- the Heavenly Sword's own gold glow (Studio 2026-10-23: its aura asset A2 is a hat mesh with no
		-- emitters): a soft gold bloom hugging the blade and gold sparkles rising off it, between the
		-- jade wisps of tier 1 and the halo of tier 3
		for k = 1, 4 do
			local a = attach(core, CFrame.new(0, top, L / 2 - (k - 0.5) / 4 * L))
			local bloom = Instance.new("ParticleEmitter")
			bloom.Texture = GLOW
			bloom.Color = ColorSequence.new(Color3.fromHex("FFE38A"), Color3.fromHex("FFB52E"))
			bloom.LightEmission = 1
			bloom.LightInfluence = 0
			bloom.Rate = 6
			bloom.Lifetime = NumberRange.new(0.5, 0.8)
			bloom.Speed = NumberRange.new(0, 0.1)
			bloom.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0.7) })
			bloom.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.55), NumberSequenceKeypoint.new(1, 1) })
			bloom.LockedToPart = true
			bloom.Parent = a
			local rise = motes(a, GOLD, 4, 0.28, 0.8, 0.9)
			rise.EmissionDirection = Enum.NormalId.Top
			rise.SpreadAngle = Vector2.new(25, 25)
			rise.Acceleration = Vector3.new(0, 1.5, 0)
		end
	end
	-- the trail: a real Trail off the hilt (it streams only while the rider moves)
	trail(core, L, def.color, def.trail, def.trailLife, def.trailWidth, ({ 0.15, 0.25, 0.45 })[tier], ({ 0.55, 0.75, 0.6 })[tier])
	if tier >= 2 then
		-- a shimmer from hilt to tip
		local hilt = attach(core, CFrame.new(0, top, L / 2))
		local tip = attach(core, CFrame.new(0, top, -L / 2))
		local sh = beam(core, hilt, tip, Color3.new(1, 1, 1), 0.4, 0.14, 0)
		sh.Texture = "rbxassetid://" .. def.trail
		sh.TextureMode = Enum.TextureMode.Stretch
		sh.TextureSpeed = 2.5
		sh.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
		-- a second, softer trail layer: ember gold (2) or a wide cloud (3)
		trail(core, L, tier == 2 and Color3.fromHex("FF9A2E") or Color3.fromHex("CFE9FF"), def.trail, def.trailLife * 0.8, def.trailWidth * 1.4, 0.4, tier == 2 and 0.8 or 0.5)
		-- sparks shed off the hilt
		local s = motes(hilt, tier == 2 and GOLD or Color3.new(1, 1, 1), 8 + tier * 5, 0.22, 4, 0.7)
		s.EmissionDirection = Enum.NormalId.Back
		s.SpreadAngle = Vector2.new(20, 20)
		s.LockedToPart = false
		s.Drag = 2
	end
	if tier == 3 then
		-- the double gold halo, now over the blade's FRONT half toward the tip (behind the hilt it sat
		-- over the rider's legs from behind and read as an aura on the player): upright across the
		-- blade, tilted back 35 degrees so it reads from the side and from above
		local c = CFrame.new(0, top + 1.5, -L * 0.32) * CFrame.Angles(math.rad(-35), 0, 0)
		for _, ring in { { 1.3, 0.26, GOLD, 0 }, { 1, 0.1, Color3.new(1, 1, 1), 0.1 } } do
			local prev, n = nil, 20
			for k = 0, n do
				local a = k / n * math.pi * 2
				local at = attach(core, c * CFrame.new(math.cos(a) * ring[1], math.sin(a) * ring[1], 0))
				if prev then
					beam(core, prev, at, ring[3], ring[2], ring[2], ring[4]).Brightness = 3
				end
				prev = at
			end
		end
		local fill = beam(core, attach(core, c * CFrame.new(0, -1.6, 0)), attach(core, c * CFrame.new(0, 1.6, 0)), Color3.fromHex("FFE9A8"), 3.2, 3.2, 0.45)
		fill.Texture = GLOW
		fill.TextureMode = Enum.TextureMode.Stretch
		motes(attach(core, c), Color3.fromHex("FFF4C2"), 5, 0.4, 0.3, 1.1)
	end
	templates[tier] = m
	return m
end

return SwordLook
