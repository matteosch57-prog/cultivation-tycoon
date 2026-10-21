-- Leaf-card trees and bushes (owner 2026-10-21: "redo plants and trees", plan A; research
-- 2026-10-21_nature; preview docs/art/mocks/nature_leafcard_trees.jpg). Premium stylized trees on
-- Roblox are leaf cards: a canopy mesh of a few hundred small quads, each showing a painted leaf
-- cluster with see-through edges, turned outward with sphere normals so the canopy shades like
-- one soft mass. The meshes and textures come from tools/nature_assets.py; the owner uploads
-- them (R5, R11): mesh ids in Config.NATURE_MESH, textures as SurfaceAppearances in
-- NatureKit.model.json (a texture with alpha needs a SurfaceAppearance, and only Rojo/Studio may
-- set its ColorMap, so the server clones these). Until both are there, Nature.ready() is false and
-- Style keeps the old trees.
-- Leaves fall from every broadleaf (the owner's favourite), a few lie on the grass under it, and
-- a low emitter slides leaves along the ground with the wind. No Light instances (R3).
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Lowpoly = require(script.Parent:WaitForChild("Lowpoly"))

local Nature = {}

local WHITE = Color3.new(1, 1, 1)

local kit = script.Parent:WaitForChild("NatureKit")
local meshes = {}
for key, id in Config.NATURE_MESH or {} do
	if id ~= "" then
		local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, id, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
		if ok and mp then
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			meshes[key] = mp
		else
			warn("[Tycoon][nature] event=canopy_load_failed")
			print("[Tycoon][nature] canopy", key, id, mp)
		end
	end
end

-- canopy mesh and leaf texture per kind; size = the canopy's box in studs at scale 1
local KIND = {
	sakura = { mesh = "sakura", tex = "sakura", size = Vector3.new(17, 9, 17), fall = { "F4B6C2", "FAD4DC" } },
	ginkgo = { mesh = "ginkgo", tex = "ginkgo", size = Vector3.new(13, 13, 13), fall = { "F2C14E", "FFE08A" } },
	maple = { mesh = "round", tex = "maple", size = Vector3.new(15, 10, 15), fall = { "D9573B", "F28C4B" } },
	pine = { mesh = "pine", tex = "pine" },
	bush = { mesh = "round", tex = "green" },
}

-- Studio preview hooks: try canopies before upload (EditableMesh parts, a folder of
-- SurfaceAppearances made in Edit).
function Nature.setTemplate(key, mp)
	meshes[key] = mp
end
function Nature.setKit(folder)
	kit = folder
end

function Nature.ready(kind)
	local k = KIND[kind]
	return k ~= nil and meshes[k.mesh] ~= nil and kit:FindFirstChild(k.tex) ~= nil
end

local function prep(p, color, mat)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function canopy(parent, kind, size, cf)
	local k = KIND[kind]
	local mp = meshes[k.mesh]:Clone()
	mp.Name = "Canopy"
	mp.Size = size
	mp.CFrame = cf
	kit[k.tex]:Clone().Parent = mp
	mp.Parent = parent
	return mp
end

-- a bark rod from a to b (one low-poly cylinder; no ball at the joint, which read as a bottle neck)
local function limb(parent, a, b, dia, color)
	local p = prep(Lowpoly.mesh(Enum.PartType.Cylinder), color, Enum.Material.Wood)
	p.Size = Vector3.new((b - a).Magnitude + dia * 0.4, dia, dia)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	p.Parent = parent
end

-- Leaves falling from the canopy: slow, few, turning as they fall (Rate x Lifetime ~ 14 live).
local function falling(parent, centre, r, colors)
	local holder = prep(Instance.new("Part"), colors[1])
	holder.Name = "Leaves"
	holder.Transparency = 1
	holder.CastShadow = false
	holder.Size = Vector3.new(r * 1.4, 1, r * 1.4)
	holder.CFrame = CFrame.new(centre)
	holder.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(colors[1], colors[#colors])
	pe.Size = NumberSequence.new(0.32)
	pe.Rate = 2
	pe.Lifetime = NumberRange.new(6, 8)
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.Acceleration = Vector3.new(0, -0.9, 0)
	pe.Drag = 1
	pe.WindAffectsDrag = true
	pe.RotSpeed = NumberRange.new(-120, 120)
	pe.Rotation = NumberRange.new(0, 360)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.LightInfluence = 1
	pe.Parent = holder
end

-- Fallen leaves: flat ones lying on the grass, and a low emitter sliding leaves along the ground
-- with the wind, never above the ankles (Rate x Lifetime ~ 6 live).
local function carpet(parent, cf, r, colors, rng, count)
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r * math.sqrt(rng:NextNumber(0.05, 1))
		local s = rng:NextNumber(0.7, 1.1)
		local p = prep(Lowpoly.mesh(Enum.PartType.Cylinder), colors[(i - 1) % #colors + 1])
		p.Size = Vector3.new(0.06, s, s * 0.7)
		p.CFrame = cf
			* CFrame.new(math.cos(a) * d, 0.06, math.sin(a) * d)
			* CFrame.Angles(0, rng:NextNumber(0, 6.3), math.pi / 2)
		p.CastShadow = false
		p.Parent = parent
	end
	local holder = prep(Instance.new("Part"), colors[1])
	holder.Name = "GroundLeaves"
	holder.Transparency = 1
	holder.CastShadow = false
	holder.Size = Vector3.new(r * 2, 0.2, r * 2)
	holder.CFrame = cf * CFrame.new(0, 0.3, 0)
	holder.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(colors[1], colors[#colors])
	pe.Size = NumberSequence.new(0.3)
	pe.Rate = 1.2
	pe.Lifetime = NumberRange.new(4, 6)
	pe.Speed = NumberRange.new(0.6, 1.4)
	pe.EmissionDirection = Enum.NormalId.Right
	pe.SpreadAngle = Vector2.new(180, 5)
	pe.Drag = 0.6
	pe.WindAffectsDrag = true
	pe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.LightInfluence = 1
	pe.Parent = holder
end

local BARK = Color3.fromHex("4A3330")
local PINE_BARK = Color3.fromHex("4E3A2C")

local function hexes(list)
	local out = {}
	for i, h in list do
		out[i] = Color3.fromHex(h)
	end
	return out
end

-- A broadleaf tree: a gently leaning trunk, four branches up into one leaf-card canopy.
-- kind "sakura", "ginkgo" or "maple"; cf = the ground under the trunk.
function Nature.tree(parent, cf, seed, kind, scale)
	local look = KIND[kind]
	local rng = Random.new(seed or 1)
	local k = scale or 1
	local m = Instance.new("Model")
	m.Name = "Tree_" .. kind
	local lean = rng:NextNumber(0, math.pi * 2)
	local p0 = cf.Position - Vector3.new(0, 0.5, 0)
	local top = (cf * CFrame.new(math.cos(lean) * 1.1 * k, 4.8 * k, math.sin(lean) * 1.1 * k)).Position
	limb(m, p0, top, 1.8 * k, BARK)
	for i = 1, 4 do
		local a = lean + i * 1.6
		limb(m, top, top + Vector3.new(math.cos(a) * 3.2 * k, 2.4 * k, math.sin(a) * 3.2 * k), 0.7 * k, BARK)
	end
	local size = look.size * k
	canopy(
		m,
		kind,
		size,
		CFrame.new(top + Vector3.new(0, size.Y * 0.36, 0)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	)
	local fall = hexes(look.fall)
	falling(m, top + Vector3.new(0, size.Y * 0.2, 0), size.X * 0.4, fall)
	carpet(m, cf, 6.5 * k, fall, rng, 14)
	m.Parent = parent
	return m
end

-- A fir: a slim trunk that runs well up into the canopy (owner 2026-10-21: "the wood a bit higher
-- and thinner"), the drooping leaf-card tiers around it.
function Nature.pine(parent, cf, seed, height)
	local rng = Random.new(seed or 2)
	local h = height or 12
	local m = Instance.new("Model")
	m.Name = "Pine"
	limb(
		m,
		cf.Position - Vector3.new(0, 0.5, 0),
		(cf * CFrame.new(0, h * 0.8, 0)).Position,
		0.55 + h * 0.015,
		PINE_BARK
	)
	local size = Vector3.new(h * 0.68, h * 0.95, h * 0.68)
	canopy(
		m,
		"pine",
		size,
		cf * CFrame.new(0, h * 0.4 + size.Y / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	)
	m.Parent = parent
	return m
end

-- A round leafy bush, with a few flowers on top when `flower` is a colour.
function Nature.bush(parent, cf, seed, size, flower)
	local rng = Random.new(seed or 3)
	local s = size or 3
	local m = Instance.new("Model")
	m.Name = "Bush"
	canopy(
		m,
		"bush",
		Vector3.new(s * 1.2, s * 0.85, s * 1.2),
		cf * CFrame.new(0, s * 0.38, 0) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	)
	if flower then
		for _ = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			local p = prep(Lowpoly.mesh(Enum.PartType.Ball), flower)
			p.Size = Vector3.one * 0.45
			p.CastShadow = false
			p.CFrame = cf
				* CFrame.new(math.cos(a) * s * 0.35, s * 0.78 + rng:NextNumber(0, 0.15), math.sin(a) * s * 0.35)
			p.Parent = m
		end
	end
	m.Parent = parent
	return m
end

-- A spirit lotus (owner 2026-10-21: the herb garden's plants are lotuses with a gem inside):
-- lily pads at the foot, a stem, an open bloom of two petal rings (deep pink at the base, pale at
-- the tips) cupping a faceted gem. The gem holds a small real PointLight (R3: a visible lamp), and
-- a few motes rise from it now and then. `gem` = its colour.
local GEMS = { Color3.fromHex("4FE3C1"), Color3.fromHex("6FB8FF"), Color3.fromHex("C08BFF"), Color3.fromHex("FFD36A") }
Nature.GEMS = GEMS

function Nature.lotus(parent, cf, seed, scale, gem)
	local rng = Random.new(seed or 4)
	local k = scale or 1
	gem = gem or GEMS[math.floor(seed or 4) % #GEMS + 1]
	local m = Instance.new("Model")
	m.Name = "SpiritLotus"
	-- lily pads, a little tilted, around the foot
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.3, 0.3)
		local pad = prep(
			Lowpoly.mesh(Enum.PartType.Cylinder),
			Color3.fromHex("4E8F4A"):Lerp(Color3.fromHex("8CC266"), rng:NextNumber(0, 0.6))
		)
		local s = rng:NextNumber(1.6, 2.2) * k
		pad.Size = Vector3.new(0.12 * k, s, s)
		pad.CFrame = cf
			* CFrame.new(math.cos(a) * 0.9 * k, 0.1 * k, math.sin(a) * 0.9 * k)
			* CFrame.Angles(rng:NextNumber(-0.12, 0.12), a, math.pi / 2 + rng:NextNumber(-0.1, 0.1))
		pad.Parent = m
	end
	local stemTop = cf * CFrame.new(0, 1.5 * k, 0)
	limb(m, cf.Position, stemTop.Position, 0.18 * k, Color3.fromHex("5E9A4A"))
	-- two rings of petals: outer open wide, inner cupped
	local deep, pale = Color3.fromHex("E5739A"), Color3.fromHex("FFF0F4")
	for ring = 1, 2 do
		local n = ring == 1 and 8 or 6
		local tilt = ring == 1 and math.rad(58) or math.rad(28)
		local len = (ring == 1 and 1.25 or 1.0) * k
		for i = 1, n do
			local a = (i + (ring == 2 and 0.5 or 0)) / n * math.pi * 2
			local petal = prep(Lowpoly.mesh(Enum.PartType.Ball), deep:Lerp(pale, ring == 1 and 0.35 or 0.7))
			petal.Size = Vector3.new(0.55 * k, len, 0.22 * k)
			-- turn to face out, lean out by `tilt`, then lift by half a length so the base sits at the centre
			petal.CFrame = stemTop * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -tilt) * CFrame.new(0, len * 0.45, 0)
			petal.CastShadow = false
			petal.Parent = m
		end
	end
	-- the gem: an emerald-cut crystal standing upright in the bloom (owner 2026-10-21): an
	-- octagonal body (two blocks a quarter turn apart) with a narrower crown on top and a pointed
	-- pavilion under it, so it reads cut from every side
	local up = stemTop * CFrame.new(0, 0.85 * k, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 4), 0)
	local function facet(size, at, name)
		local p = prep(Instance.new("Part"), gem, Enum.Material.Glass)
		p.Name = name or "Facet"
		p.Size = size * k
		p.CFrame = at
		p.Transparency = 0.12
		p.Reflectance = 0.2
		p.CastShadow = false
		p.Parent = m
		return p
	end
	local g = facet(Vector3.new(0.42, 0.62, 0.42), up, "Gem")
	facet(Vector3.new(0.42, 0.62, 0.42), up * CFrame.Angles(0, math.pi / 4, 0))
	for _, side in { 1, -1 } do
		-- crown (top) is a short, narrower step; pavilion (bottom) narrows further toward a point
		local w = side == 1 and 0.3 or 0.26
		local step = up * CFrame.new(0, side * 0.36 * k, 0)
		facet(Vector3.new(w, 0.12, w), step)
		facet(Vector3.new(w, 0.12, w), step * CFrame.Angles(0, math.pi / 4, 0))
		if side == -1 then
			facet(Vector3.new(0.14, 0.12, 0.14), up * CFrame.new(0, -0.46 * k, 0) * CFrame.Angles(0, math.pi / 8, 0))
		end
	end
	local light = Instance.new("PointLight")
	light.Color = gem
	light.Range = 5 * k
	light.Brightness = 0.7
	light.Shadows = false
	light.Parent = g
	local a = Instance.new("Attachment")
	a.Parent = g
	local pe = Instance.new("ParticleEmitter") -- Rate x Lifetime ~ 1.5 live
	pe.Color = ColorSequence.new(gem, WHITE)
	pe.LightEmission = 0.6
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.12 * k),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Rate = 0.6
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Speed = NumberRange.new(0.6, 1)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = a
	m.Parent = parent
	return m
end

return Nature
