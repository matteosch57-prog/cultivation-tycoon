-- Procedural low-poly builders. Each builder takes (ctx, pad) and parents parts to ctx.folder.
-- ctx = { folder, frame (peak CFrame, top surface at y=0, +Z faces the hub), pal (palette) }
local Builders = {}
local Style = require(script.Parent:WaitForChild("Style"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Lowpoly = require(script.Parent:WaitForChild("Lowpoly"))
local Cultivators = require(script.Parent:WaitForChild("Cultivators"))
local Nature = require(script.Parent:WaitForChild("Nature"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local SP = Style.PAL

-- Buildings around the sides face the CENTRE of their islet (their front, +Z, turned toward the
-- courtyard), not the bridge: built facing +Z, the side and corner ones showed their backs to
-- the courtyard and their fronts to the void. `back` pushes it away from the centre.
local function facingCentre(ctx, x, z, back)
	local p = Vector3.new(x, 0, z)
	local i = Config.ISLETS[Config.isletAt(x, z)]
	local c = Vector3.new(i.x, 0, i.z)
	if (c - p).Magnitude < 1 then
		c = p + Vector3.new(0, 0, 1)
	end
	local look = CFrame.lookAt(p, c) * CFrame.Angles(0, math.pi, 0)
	return ctx.frame * look * CFrame.new(0, 0, back or 0)
end

local function part(ctx, size, cf, color, material, props)
	local p = Lowpoly.part(props and props.Shape, size)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = ctx.frame * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			if k ~= "Shape" then -- Lowpoly.part already gave it its shape (a MeshPart has none)
				p[k] = v
			end
		end
	end
	p.Parent = ctx.folder
	return p
end
Builders.part = part

local function cyl(ctx, height, diameter, cf, color, material)
	-- Roblox cylinders run along X: rotate so the axis is vertical.
	return part(ctx, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, { Shape = Enum.PartType.Cylinder })
end
Builders.cyl = cyl

local function glowPart(ctx, size, cf, color, range)
	local p = part(ctx, size, cf, color, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 12
	light.Brightness = 1.5
	light.Parent = p
	return p
end

-- A tiered roof: stacked shrinking slabs with upturned corner tips.
local function roof(ctx, cx, cy, cz, w, d, tiers, pal)
	for i = 0, tiers - 1 do
		local s = 1 - i * 0.22
		local y = cy + i * 1.6
		part(ctx, Vector3.new(w * s + 2, 0.8, d * s + 2), CFrame.new(cx, y, cz), pal.roof, Enum.Material.Slate)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(ctx, Vector3.new(0.8, 0.8, 1.6), CFrame.new(cx + sx * (w * s / 2 + 1), y + 0.5, cz + sz * (d * s / 2 + 1)) * CFrame.Angles(math.rad(-30 * sz), 0, 0), pal.trim, Enum.Material.Metal)
			end
		end
	end
	part(ctx, Vector3.new(0.6, 2, 0.6), CFrame.new(cx, cy + tiers * 1.6 + 0.6, cz), pal.trim, Enum.Material.Metal)
end

-- A simple building: posts, walls on three sides, roof.
local function hall(ctx, cx, cz, w, d, h, pal)
	part(ctx, Vector3.new(w + 2, 1, d + 2), CFrame.new(cx, 0.5, cz), pal.stone, Enum.Material.Cobblestone)
	part(ctx, Vector3.new(w, h, 0.6), CFrame.new(cx, 1 + h / 2, cz - d / 2), pal.wood, Enum.Material.Wood)
	part(ctx, Vector3.new(0.6, h, d), CFrame.new(cx - w / 2, 1 + h / 2, cz), pal.wood, Enum.Material.Wood)
	part(ctx, Vector3.new(0.6, h, d), CFrame.new(cx + w / 2, 1 + h / 2, cz), pal.wood, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		part(ctx, Vector3.new(1, h, 1), CFrame.new(cx + sx * (w / 2 - 0.5), 1 + h / 2, cz + d / 2 - 0.5), pal.wood, Enum.Material.Wood)
	end
	roof(ctx, cx, 1 + h + 0.4, cz, w, d, 2, pal)
end

function Builders.path(ctx)
	-- irregular dressed stone slabs with a darker kerb
	local i = 0
	for z = 58, 10, -3.2 do
		i += 1
		local c = (i % 3 == 0) and SP.stone or SP.stoneLight
		part(ctx, Vector3.new(6.6, 0.35, 2.8), CFrame.new(0, 0.18, z) * CFrame.Angles(0, math.rad((i * 37) % 6 - 3), 0), c)
	end
	for _, sx in { -1, 1 } do
		part(ctx, Vector3.new(0.6, 0.3, 50), CFrame.new(sx * 3.9, 0.15, 34), SP.stone)
	end
end

local function vein(ctx, x, z)
	-- rock bed with a cluster of spirit crystals (the crystal is the light source)
	for k = 0, 2 do
		local a = k * 2.1
		part(ctx, Vector3.new(3.4, 1.6, 3.4), CFrame.new(x + math.cos(a) * 1.8, 0.5, z + math.sin(a) * 1.8) * CFrame.Angles(0.2, a, 0.15), SP.rock)
	end
	local glow = ctx.pal.glow
	local crystal = glowPart(ctx, Vector3.new(1.6, 6, 1.6), CFrame.new(x, 3.6, z) * CFrame.Angles(0, math.rad(45), math.rad(7)), glow, 18)
	part(ctx, Vector3.new(1.15, 1.15, 1.15), CFrame.new(x - 0.35, 6.9, z) * CFrame.Angles(math.rad(45), math.rad(45), 0), glow, Enum.Material.Neon)
	part(ctx, Vector3.new(1, 3.4, 1), CFrame.new(x + 1.6, 2.2, z + 0.8) * CFrame.Angles(0, math.rad(20), math.rad(-22)), glow:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon)
	part(ctx, Vector3.new(0.9, 2.6, 0.9), CFrame.new(x - 1.4, 1.8, z - 1) * CFrame.Angles(math.rad(15), 0, math.rad(25)), glow:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Neon)
	local att = Instance.new("Attachment")
	att.Parent = crystal
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(ctx.pal.glow)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.4, 0)
	pe.Speed = NumberRange.new(2, 4)
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Rate = 6
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = att
end
function Builders.vein1(ctx, pad)
	vein(ctx, pad.x, pad.z)
end
function Builders.vein2(ctx, pad)
	vein(ctx, pad.x, pad.z)
end

function Builders.platform(ctx)
	-- two-tier meditation terrace with a gold band, a taiji centre and a front step
	cyl(ctx, 0.8, 25, CFrame.new(0, 0.4, 0), SP.stone)
	cyl(ctx, 0.3, 24.2, CFrame.new(0, 0.9, 0), SP.gold)
	cyl(ctx, 0.35, 23.4, CFrame.new(0, 1.12, 0), SP.stoneLight)
	cyl(ctx, 0.12, 8, CFrame.new(0, 1.33, 0), SP.timberDark)
	cyl(ctx, 0.14, 6.6, CFrame.new(0, 1.36, 0), SP.plaster)
	part(ctx, Vector3.new(3.3, 0.16, 6.6), CFrame.new(-1.65, 1.4, 0), SP.timberDark) -- dark half of the taiji
	cyl(ctx, 0.16, 3.3, CFrame.new(0, 1.42, 1.65), SP.timberDark)
	cyl(ctx, 0.18, 3.3, CFrame.new(0, 1.44, -1.65), SP.plaster)
	part(ctx, Vector3.new(7, 0.6, 2), CFrame.new(0, 0.3, 13), SP.stone)
	-- four incense stands at the quarter points
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local px, pz = math.cos(a) * 10.4, math.sin(a) * 10.4
		cyl(ctx, 1.4, 1.2, CFrame.new(px, 2, pz), Color3.fromHex("7A5A3A"), Enum.Material.Metal)
		local stick = part(ctx, Vector3.new(0.12, 1.4, 0.12), CFrame.new(px, 3.3, pz), Color3.fromHex("8B3A2B"))
		-- a thin wisp from the stick tip (legacy Smoke made a white fog patch over the courtyard)
		local tip = Instance.new("Attachment")
		tip.Position = Vector3.new(0, 0.7, 0)
		tip.Parent = stick
		local wisp = Instance.new("ParticleEmitter")
		wisp.Texture = "rbxasset://textures/particles/smoke_main.dds"
		wisp.Color = ColorSequence.new(Color3.fromRGB(225, 222, 232))
		wisp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.7) })
		wisp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.6), NumberSequenceKeypoint.new(1, 1) })
		wisp.Lifetime = NumberRange.new(2.5, 3.5)
		wisp.Rate = 3
		wisp.Speed = NumberRange.new(0.8, 1.1)
		wisp.SpreadAngle = Vector2.new(6, 6)
		wisp.Acceleration = Vector3.new(0.15, 0, 0)
		wisp.RotSpeed = NumberRange.new(-20, 20)
		wisp.Parent = tip
	end
end

function Builders.lanterns(ctx)
	for _, sx in { -1, 1 } do
		for _, z in { 27, 34, 41 } do -- clear of the plaza ring road (r 21) and the Sect Gate columns at z=46
			Style.lantern(ctx.folder, ctx.frame * CFrame.new(sx * 6.2, 0, z), 0.9)
		end
	end
end

function Builders.garden(ctx, pad)
	local x, z = pad.x, pad.z
	local rng = Random.new(21)
	for _, bz in { -3.5, 3.5 } do
		-- raised bed with a timber kerb
		part(ctx, Vector3.new(16, 0.9, 5.4), CFrame.new(x, 0.45, z + bz), SP.dirt)
		for _, side in { -1, 1 } do
			part(ctx, Vector3.new(16.6, 1.1, 0.5), CFrame.new(x, 0.55, z + bz + side * 2.9), SP.timber)
		end
		for _, side in { -1, 1 } do
			part(ctx, Vector3.new(0.5, 1.1, 6.2), CFrame.new(x + side * 8.1, 0.55, z + bz), SP.timber)
		end
		for i = -3, 3 do
			local px = x + i * 2.2 + rng:NextNumber(-0.3, 0.3)
			-- spirit lotuses with an emerald-cut gem (owner 2026-10-21, docs/art/mocks/nature_spirit_lotus.jpg)
			Nature.lotus(ctx.folder, ctx.frame * CFrame.new(px, 0.9, z + bz), 44 + i + (bz > 0 and 7 or 0), 0.85)
		end
	end
	-- stepping stones between the beds
	for i = -2, 2 do
		part(ctx, Vector3.new(2, 0.25, 1.4), CFrame.new(x + i * 3.2, 0.12, z) * CFrame.Angles(0, math.rad(i * 9), 0), SP.stoneLight)
	end
end

local function wall(ctx, side)
	Style.wall(ctx.folder, ctx.frame * CFrame.new(side * 54, 0, -2), 88)
end
function Builders.wallL(ctx)
	wall(ctx, -1)
end
function Builders.wallR(ctx)
	wall(ctx, 1)
end

function Builders.furnace(ctx, pad)
	-- the alchemy cauldron under its own open pavilion
	local at = ctx.frame * CFrame.new(pad.x, 0, pad.z)
	local _, deckH = Kit.pavilion(ctx.folder, at, 11, 8)
	Style.cauldron(ctx.folder, at * CFrame.new(0, deckH, 0), 1.25)
end

function Builders.hall(ctx, pad)
	Kit.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -2), { bays = 3, bay = 5.5, depth = 2, colH = 7, plinth = 1.6, name = "DiscipleHall", plaque = pad.name })
end

-- Disciple Quarters: small two-storey halls in the front corners (each adds a disciple slot)
function Builders.quarters1(ctx, pad)
	Kit.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -3), { bays = 2, bay = 5, depth = 1, colH = 6, plinth = 1.2, name = "Quarters", plaque = pad.name })
end
function Builders.quarters2(ctx, pad)
	Kit.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -3), { bays = 3, bay = 5, depth = 1, colH = 6.5, plinth = 1.4, name = "GrandQuarters", plaque = pad.name })
end

-- The Sect Gate replaces the entrance archway on the same spot, grander (Main skips the archway
-- once it stands and puts the owner's name board on this one's "Sign")
function Builders.gate(ctx)
	local sign = Kit.gate(ctx.folder, ctx.frame * CFrame.new(0, 0, Config.ISLAND_RADIUS - 1), 16, 19)
	sign.Name = "Sign"
end

-- the pagoda is bought in two halves that stack exactly (same baseW / tier count)
-- (z=-30 keeps its stair clear of the meditation terrace and its back clear of the shrine stair)
local PAGODA_AT = CFrame.new(0, 0, -74) -- behind the Main Hall, on the second expansion

-- The Main Hall: one building, five levels, always at the back centre of the peak
local MAIN_HALL_AT = CFrame.new(0, 0, -36)
for lv = 1, 5 do
	Builders["mainhall" .. lv] = function(ctx, pad)
		Kit.mainHall(ctx.folder, ctx.frame * MAIN_HALL_AT, lv, pad and pad.name)
	end
end

-- Expansions change the island itself (Main.server rebuilds the grounds); no structure here
function Builders.expand1() end
function Builders.expand2() end

-- Variety buildings on the expanded ground
function Builders.bamboo(ctx, pad)
	Style.bambooGrove(ctx.folder, facingCentre(ctx, pad.x, pad.z), 11)
end
function Builders.training(ctx, pad)
	Style.trainingGround(ctx.folder, facingCentre(ctx, pad.x, pad.z))
end
function Builders.bell(ctx, pad)
	Kit.bellTower(ctx.folder, facingCentre(ctx, pad.x, pad.z), pad.name)
end
function Builders.koi(ctx, pad)
	Style.koiPond(ctx.folder, facingCentre(ctx, pad.x, pad.z), 5)
end
function Builders.library(ctx, pad)
	-- a two-roof kit hall in jade tiles, scroll racks either side of the stair
	local at = facingCentre(ctx, pad.x, pad.z, -4)
	Kit.hall(ctx.folder, at, { bays = 3, bay = 5.5, depth = 2, colH = 7, plinth = 1.6, two = true, tile = Color3.fromHex("2F6B5A"), name = "Library", plaque = pad.name })
	for _, sx in { -1, 1 } do
		local rack = at * CFrame.new(sx * 13.2, 0, 7)
		part(ctx, Vector3.new(0.4, 4, 2.6), ctx.frame:ToObjectSpace(rack * CFrame.new(0, 2, 0)), SP.timberDark)
		for k = 0, 3 do
			cyl(ctx, 0.5, 0.5, ctx.frame:ToObjectSpace(rack * CFrame.new(0.4 * -sx, 0.8 + k * 0.9, 0) * CFrame.Angles(math.pi / 2, 0, 0)), Color3.fromHex("EBDDBA"))
		end
	end
end
function Builders.moongate(ctx, pad)
	Kit.moonGate(ctx.folder, facingCentre(ctx, pad.x, pad.z, -2))
end
-- (on the Summit islet: at the pad, PAGODA_AT was the old spot behind the Main Hall)
function Builders.pagoda1(ctx, pad)
	Kit.pagoda(ctx.folder, pad and ctx.frame * CFrame.new(pad.x, 0, pad.z) or ctx.frame * PAGODA_AT, 10, 1, 2, 5)
end

function Builders.pagoda2(ctx, pad)
	Kit.pagoda(ctx.folder, pad and ctx.frame * CFrame.new(pad.x, 0, pad.z) or ctx.frame * PAGODA_AT, 10, 3, 5, 5)
end

function Builders.array(ctx, pad)
	Style.qiArray(ctx.folder, ctx.frame * CFrame.new(pad.x, 0, pad.z - 2), 8)
end

function Builders.shrine(ctx)
	Kit.hall(ctx.folder, ctx.frame * CFrame.new(0, 0, -55), { bays = 3, bay = 5, depth = 1, colH = 7, plinth = 3, name = "PeakShrine", plaque = "Peak Shrine" })
end

-- The peak itself (island). Built once per plot.
function Builders.island(ctx, radius, bare)
	cyl(ctx, 3, radius * 2, CFrame.new(0, -1.5, 0), Color3.fromRGB(95, 140, 70), Enum.Material.Grass)
	local tiers = { { 8, 1.0 }, { 10, 0.82 }, { 12, 0.6 }, { 14, 0.38 }, { 14, 0.16 } }
	local y = -3
	for _, t in tiers do
		cyl(ctx, t[1], radius * 2 * t[2], CFrame.new(0, y - t[1] / 2, 0), Color3.fromRGB(110, 100, 95), Enum.Material.Rock)
		y -= t[1]
	end
	if bare then
		return
	end
	-- a few boulders and pines around the rim
	local rng = Random.new(7)
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius - rng:NextNumber(3, 8)
		local px, pz = math.cos(a) * r, math.sin(a) * r
		if pz < 45 or math.abs(px) > 12 then -- keep the bridge entrance clear
			if i % 2 == 0 then
				part(ctx, Vector3.new(4, 3, 4) * rng:NextNumber(0.7, 1.4), CFrame.new(px, 1, pz) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Color3.fromRGB(120, 115, 110), Enum.Material.Rock)
			else
				part(ctx, Vector3.new(1, 6, 1), CFrame.new(px, 3, pz), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
				for k = 0, 2 do
					part(ctx, Vector3.new(5 - k * 1.4, 2, 5 - k * 1.4), CFrame.new(px, 5 + k * 1.8, pz) * CFrame.Angles(0, math.rad(k * 30), 0), Color3.fromRGB(50, 100, 60), Enum.Material.Grass)
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Floating Lotus Isles (owner pick C 2026-10-22, docs/art/captures/2026-10-22_platform_C_v2_islets.jpg):
-- a jade lotus deck on a rock islet wrapped in clouds, floating over the Meditation Platform, with a
-- palace lantern in its heart and 4 more disciple seats. Floating stepping stones lead up to it from
-- the platform (isle 1) or the isle before (owner: "make sure we can jump on them one per one"):
-- each step rises at most ISLE_STEP_RISE and lies at most ISLE_STEP_GAP from the last (jump 8.5 studs,
-- walk 28, Config.MOVE), so every step is a plain jump. Meshes: Config.SKY_MESH (Lowpoly.sky).
local ISLES = { -- centre of the lawn's top, peak frame space (the platform is at 0, 0)
	{ x = -17, y = 13, z = 3 },
	{ x = 17, y = 17, z = -3 },
	{ x = 0, y = 25, z = -14 },
}
-- owner 2026-10-22 ("the stone looks a bit cheap; more space for each disciple, bigger aura"): the
-- isles are small floating islands in the peaks' own look (Style.island: lawn, dirt band, a light
-- shelf, faceted rock rings sandstone to slate, hanging spires and roots, grass drips) cut to a
-- shallow depth, wider seats, and isle disciples drawn ISLE_SCALE larger, auras included
local ISLE_R = 8.5 -- the lawn's radius
local ISLE_SEAT_R = 5.6
local ISLE_SCALE = 1.25
local ISLE_STEP_RISE, ISLE_STEP_GAP = 4, 7
local PLATFORM_TOP = 1.3 -- the platform deck's top: a seat's y is measured from it (Builders.disciple)
local CLOUD_WHITE, CLOUD_LILAC = Color3.fromRGB(255, 252, 255), Color3.fromRGB(214, 206, 240)
local SAND, SLATE, SHELF = Color3.fromHex("A08A74"), Color3.fromHex("5A5670"), Color3.fromHex("B8A48C")
local LAWN, SPIRIT = Color3.fromHex("7DAA5C"), Color3.fromHex("6FF2C8")
local LOTUS = { mesh = "rbxassetid://14340526628", tex = "rbxassetid://14340559072", native = Vector3.new(22.23, 28.65, 22.23) }

local function skyPart(ctx, name, size, cf, collide)
	local p = Lowpoly.sky(name)
	if not p then
		return nil
	end
	p:ClearAllChildren()
	p.Size = size
	p.CFrame = ctx.frame * cf
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Parent = ctx.folder
	return p
end

-- the cloud is an old FileMesh: CreateMeshPartAsync refuses it, a SpecialMesh draws it (no collision)
local CLOUD_NATIVE = Vector3.new(13.76, 9.09, 24.67)
local function cloud(ctx, cf, w, rng)
	local size = Vector3.new(w * 0.56, w * 0.37, w)
	local p = part(ctx, size, cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), CLOUD_WHITE:Lerp(CLOUD_LILAC, rng:NextNumber(0, 0.35)), nil, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.FileMesh
	sm.MeshId = Config.SKY_MESH.cloud
	sm.Scale = size / CLOUD_NATIVE
	sm.Parent = p
end

-- decoration that never collides (only lawn tops carry the player)
local function deco(ctx, size, cf, color, material, shape)
	return part(ctx, size, cf, color, material, { Shape = shape, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- a small floating island: lawn top at `at` (its y), radius `r`, a shallow rock underside
local function isleBody(ctx, at, r, rng)
	local top = CFrame.new(at)
	cyl(ctx, 1.4, r * 2, top * CFrame.new(0, -0.7, 0), LAWN, Enum.Material.LeafyGrass)
	cyl(ctx, 1.6, r * 2 + 0.3, top * CFrame.new(0, -1.9, 0), SP.dirt).CanCollide = false
	cyl(ctx, 0.8, r * 1.95, top * CFrame.new(0, -3, 0), SHELF).CanCollide = false
	-- rock rings, narrowing and darkening with depth (Style.island's underside, a third as deep)
	local layers = 4
	local depth = r * 0.95
	local step = depth / layers
	for k = 0, layers - 1 do
		local f = 1 - k / layers
		local ringR = r * 0.95 * f ^ 0.9
		local h = step * 1.5
		local y = -3.4 - k * step - h / 2
		local col = SAND:Lerp(SLATE, (k / (layers - 1)) ^ 0.8)
		local n = math.max(4, math.floor(ringR / 1.6))
		for j = 1, n do
			local a = j / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local sz = math.min(ringR * rng:NextNumber(0.4, 0.55) + 1.2, 5)
			local cr = ringR - sz * 0.5
			local cf = top * CFrame.new(math.cos(a) * cr, y, math.sin(a) * cr) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15))
			deco(ctx, Vector3.new(sz, h, sz), cf, col:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.06)), Enum.Material.Slate)
		end
		deco(ctx, Vector3.new(h, ringR * 1.8, ringR * 1.8), top * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Slate, Enum.PartType.Cylinder)
	end
	-- hanging spires under the middle
	for _ = 1, 2 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, r * 0.3)
		local len = rng:NextNumber(3, 6)
		for j = 0, 3 do
			local sz = (1 - j / 4) * 2.2 + 0.4
			local cf = top * CFrame.new(math.cos(a) * d, -3.4 - depth - j * len / 4, math.sin(a) * d) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
			deco(ctx, Vector3.new(sz, len / 4 + 0.4, sz), cf, SLATE, Enum.Material.Slate)
		end
	end
	-- grass drips over the rim
	local drips = math.floor(r * 1.1)
	for j = 1, drips do
		local a = j / drips * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local len = rng:NextNumber(1.2, 2.6)
		local cf = top * CFrame.new(math.cos(a) * (r + 0.1), -1.3 - len / 2, math.sin(a) * (r + 0.1)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		deco(ctx, Vector3.new(rng:NextNumber(1.2, 2.2), len, 0.6), cf, LAWN:Lerp(SP.grassDark, j % 3 == 0 and 0 or 0.35), Enum.Material.LeafyGrass)
	end
	-- two dangling roots with a leaf tuft (world-space points: the cylinders are placed directly)
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		local prev = Vector3.new(at.X + math.cos(a) * r * 0.8, at.Y - 3.6, at.Z + math.sin(a) * r * 0.8)
		for j = 1, 3 do
			local nxt = prev + Vector3.new(rng:NextNumber(-0.6, 0.6), -rng:NextNumber(1.6, 2.6), rng:NextNumber(-0.6, 0.6))
			local mid, len = (prev + nxt) / 2, (nxt - prev).Magnitude
			local w = 0.32 - j * 0.06
			deco(ctx, Vector3.new(len, w, w), CFrame.lookAt(mid, nxt) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromHex("5E4636"), nil, Enum.PartType.Cylinder)
			prev = nxt
		end
		deco(ctx, Vector3.new(1.1, 1.1, 1.1), CFrame.new(prev) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), SP.grassDark, Enum.Material.LeafyGrass)
	end
end

-- a stepping stone: the peaks' own small floating rock (a lawn cap on faceted rock narrowing to a
-- point, a spirit crystal under it, Style.island); only the lawn cap collides
local function stone(ctx, p, rng)
	local s = 4.4
	cyl(ctx, s * 0.3, s * 1.1, CFrame.new(p.X, p.Y - s * 0.15, p.Z), LAWN, Enum.Material.LeafyGrass)
	for j = 0, 2 do
		local w = s * (0.95 - j * 0.3)
		local cf = CFrame.new(p.X, p.Y - s * (0.45 + j * 0.42), p.Z) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15))
		deco(ctx, Vector3.new(w, s * 0.5, w), cf, Color3.fromHex("8E7C6C"):Lerp(SLATE, j / 2), Enum.Material.Slate)
	end
	local gem = deco(ctx, Vector3.new(s * 0.18, s * 0.6, s * 0.18), CFrame.new(p.X, p.Y - s * 1.55, p.Z) * CFrame.Angles(0, math.rad(45), 0), SPIRIT, Enum.Material.Glass)
	gem.CastShadow = false
end

local function isleTop(i)
	local c = ISLES[i]
	return Vector3.new(c.x, c.y, c.z)
end

-- stepping stones from `a` to `b` (both walking surfaces), bowed sideways a little so the climb
-- reads as a path; neither end gets a stone. Each step rises at most ISLE_STEP_RISE and lies at most
-- ISLE_STEP_GAP from the last (jump 8.5 studs, walk 28, Config.MOVE): every step is a plain jump.
local function steps(ctx, a, b, rng)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local n = math.max(math.ceil(math.abs(b.Y - a.Y) / ISLE_STEP_RISE), math.ceil(flat.Magnitude / ISLE_STEP_GAP))
	local side = flat.Magnitude > 0 and Vector3.new(-flat.Z, 0, flat.X).Unit or Vector3.zero
	for i = 1, n - 1 do
		local t = i / n
		local p = a:Lerp(b, t) + side * math.sin(t * math.pi) * 3
		stone(ctx, p, rng)
		if i % 2 == 1 then
			cloud(ctx, CFrame.new(p.X, p.Y - 4.5, p.Z), rng:NextNumber(6, 8), rng)
		end
	end
end

function Builders.lotusIsle(ctx, i)
	local rng = Random.new(i * 17)
	Lowpoly.skyReady(4)
	local c = isleTop(i)
	isleBody(ctx, c, ISLE_R, rng)
	-- in the middle a jade lotus dais under a palace lantern (a real lamp, R3)
	local k = 8 / LOTUS.native.X
	local lotus = part(ctx, Vector3.new(8, LOTUS.native.Y * k * 0.3, 8), CFrame.new(c.X, c.Y + 0.1, c.Z), Color3.new(1, 1, 1), nil, { CanCollide = false, CanQuery = false })
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.FileMesh
	sm.MeshId = LOTUS.mesh
	sm.TextureId = LOTUS.tex
	sm.Scale = Vector3.new(k, k * 0.3, k)
	sm.Parent = lotus
	cyl(ctx, 0.5, 3.2, CFrame.new(c.X, c.Y + 0.25, c.Z), SP.jade, Enum.Material.Marble)
	local lantern = skyPart(ctx, "lantern", Vector3.new(4.66, 7.6, 4) * (3.2 / 7.6), CFrame.new(c.X, c.Y + 0.5 + 1.6, c.Z), true)
	if lantern then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 175, 95), 10, 1.2
		l.Parent = lantern
	end
	-- clouds hugging the rim and trailing under it
	for _ = 1, 8 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(7.5, 10.5)
		cloud(ctx, CFrame.new(c.X + math.cos(a) * r, c.Y - rng:NextNumber(3, 5), c.Z + math.sin(a) * r), rng:NextNumber(7, 12), rng)
	end
	for _ = 1, 2 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(1, 4)
		cloud(ctx, CFrame.new(c.X + math.cos(a) * r, c.Y - rng:NextNumber(10, 12), c.Z + math.sin(a) * r), rng:NextNumber(8, 12), rng)
	end
	-- the stepping stones up from the platform's rim, or from the isle before
	local from
	if i == 1 then
		-- from the platform's rim a quarter turn round from the isle: straight below it the stones
		-- would stack (each one a ceiling over the last)
		local a = math.atan2(c.Z, c.X) + math.rad(100)
		from = Vector3.new(math.cos(a) * 11, PLATFORM_TOP, math.sin(a) * 11)
	else
		local prev = isleTop(i - 1)
		local dir = Vector3.new(c.X - prev.X, 0, c.Z - prev.Z).Unit
		from = prev + dir * (ISLE_R - 1)
	end
	local back = Vector3.new(from.X - c.X, 0, from.Z - c.Z).Unit
	steps(ctx, from, c + back * (ISLE_R - 1), rng)
end
Builders.lotus1 = function(ctx)
	Builders.lotusIsle(ctx, 1)
end
Builders.lotus2 = function(ctx)
	Builders.lotusIsle(ctx, 2)
end
Builders.lotus3 = function(ctx)
	Builders.lotusIsle(ctx, 3)
end

-- A seated cultivator on the meditation platform (slot 1..). `look` is the disciple's own look (D60;
-- the slot picks one when missing); the rarity picks the robe colour and the aura (Cultivators.luau,
-- mock docs/art/mocks/cultivators_lineup.jpg).
-- `isle` (1..3) seats it on a Floating Lotus Isle instead, at seat `k` (1..4), facing out.
function Builders.disciple(ctx, slot, rarity, arrive, look, isle, k)
	local face
	if isle then
		local d = isleTop(isle)
		local a = math.rad(45 + (k - 1) * 90)
		local x, z = math.cos(a) * ISLE_SEAT_R, math.sin(a) * ISLE_SEAT_R
		face = CFrame.new(d.X + x, d.Y - PLATFORM_TOP, d.Z + z) * CFrame.Angles(0, math.atan2(x, z) + math.pi, 0)
	else
		local a = math.rad(-90 + (slot - 3) * 40)
		local x, z = math.cos(a) * 8.5, -math.sin(a) * 8.5 -- arc on the hub side of the platform
		face = CFrame.new(x, 0, z) * CFrame.Angles(0, math.atan2(x, z), 0) -- face the centre
	end
	local m = Cultivators.build(ctx.folder, ctx.frame * face, look or slot, rarity, Config.RARITIES, { arrive = arrive })
	if isle then -- drawn larger, aura included, standing on the same spot
		m.WorldPivot = ctx.frame * face -- scale about the floor point
		m:ScaleTo(ISLE_SCALE)
	end
	m.Name = "Disciple" .. slot
	return m
end

---------------------------------------------------------------------------------------------
-- District resources (option C, owner 2026-10-21; mock docs/art/mocks/district_resources.html):
-- more copies of the fields' resources and five new types, each a compact plot. `local frame`
-- = the plot's frame relative to the peak, turned to face the centre like the other buildings.
local function plotFrame(ctx, pad)
	return ctx.frame:ToObjectSpace(facingCentre(ctx, pad.x, pad.z))
end

function Builders.vein3(ctx, pad)
	vein(ctx, pad.x, pad.z)
end
function Builders.garden2(ctx, pad)
	Builders.garden(ctx, pad)
end
function Builders.garden3(ctx, pad)
	Builders.garden(ctx, pad)
end

-- Spirit Tea Terrace: three stepped beds climbing away from the path, stone retaining walls, a
-- row of leaf-card tea bushes on each step.
local function tea(ctx, pad)
	local f = plotFrame(ctx, pad)
	for step = 0, 2 do
		local z = 3 - step * 3
		local h = 0.6 + step * 0.7
		part(ctx, Vector3.new(11, h, 3.2), f * CFrame.new(0, h / 2, z), SP.dirt)
		part(ctx, Vector3.new(11.4, h + 0.15, 0.5), f * CFrame.new(0, (h + 0.15) / 2, z + 1.7), SP.stone)
		for i = -2, 2 do
			local at = ctx.frame * f * CFrame.new(i * 2.1, h, z)
			if Nature.ready("bush") then
				Nature.bush(ctx.folder, at, 60 + step * 5 + i, 1.7)
			else
				part(ctx, Vector3.new(1.6, 1.2, 1.6), f * CFrame.new(i * 2.1, h + 0.6, z), Color3.fromHex("4E8F4A"))
			end
		end
	end
end
Builders.tea1 = tea
Builders.tea2 = tea

-- Fire Lotus Pond: a small pond of amber water holding three flame-red lotuses with amber gems.
local FIRE = { Color3.fromHex("E5492F"), Color3.fromHex("FFD38A") }
local function fireLotus(ctx, pad)
	local f = ctx.frame * plotFrame(ctx, pad)
	Style.pond(ctx.folder, f, 5, Color3.fromHex("D9822B"))
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		Nature.lotus(ctx.folder, f * CFrame.new(math.cos(a) * 2.2, 0.25, math.sin(a) * 2.2), 70 + i, 0.75, Color3.fromHex("FFB347"), FIRE)
	end
end
Builders.firelotus1 = fireLotus
Builders.firelotus2 = fireLotus

-- Jade Quarry: a stepped grey-green rock face cut into the ground, jade veins glowing in it (one
-- real light), cut blocks stacked by a little wooden cart.
local JADE = Color3.fromHex("43C78C")
local function jade(ctx, pad)
	local f = plotFrame(ctx, pad)
	local rock = Color3.fromHex("8C9A8E")
	for step = 0, 2 do
		local w = 11 - step * 2.5
		part(ctx, Vector3.new(w, 1.6 + step * 1.6, 3), f * CFrame.new(0, (1.6 + step * 1.6) / 2, -2 - step * 2.2), rock:Lerp(Color3.new(0, 0, 0), step * 0.08), Enum.Material.Slate)
	end
	glowPart(ctx, Vector3.new(0.9, 2.6, 0.9), f * CFrame.new(-2, 2.2, -1.2) * CFrame.Angles(0, 0.6, 0.35), JADE, 14)
	part(ctx, Vector3.new(0.7, 1.8, 0.7), f * CFrame.new(1.8, 3.6, -3.4) * CFrame.Angles(0.2, 0.4, -0.3), JADE, Enum.Material.Neon)
	part(ctx, Vector3.new(0.6, 1.4, 0.6), f * CFrame.new(3.2, 1.6, -1.6) * CFrame.Angles(0, 0, 0.5), JADE, Enum.Material.Neon)
	-- cut blocks and the cart, in front of the face
	for i = 0, 2 do
		part(ctx, Vector3.new(1.2, 1.2, 1.2), f * CFrame.new(-3.6 + i * 1.3, 0.6, 2.4) * CFrame.Angles(0, i * 0.3, 0), JADE:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Marble)
	end
	part(ctx, Vector3.new(2.4, 1, 1.6), f * CFrame.new(2.6, 1, 2.6), SP.timber, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		cyl(ctx, 0.3, 1, f * CFrame.new(2.6 + sx * 0.9, 0.5, 3.5) * CFrame.Angles(math.pi / 2, 0, 0), SP.timberDark)
	end
end
Builders.jade1 = jade
Builders.jade2 = jade
Builders.jade3 = jade

-- Thunder Crystal: a tall violet crystal cluster on a stone plinth that holds a storm's charge;
-- one real light and a few sparks crawling up it.
local THUNDER = Color3.fromHex("9C7BFF")
local function thunder(ctx, pad)
	local f = plotFrame(ctx, pad)
	cyl(ctx, 1, 7, f * CFrame.new(0, 0.5, 0), SP.stone)
	cyl(ctx, 0.4, 5.6, f * CFrame.new(0, 1.2, 0), SP.stoneLight)
	local core = glowPart(ctx, Vector3.new(1.4, 6, 1.4), f * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.rad(45), 0.08), THUNDER, 16)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		part(ctx, Vector3.new(0.8, 3, 0.8), f * CFrame.new(math.cos(a) * 1.4, 2.6, math.sin(a) * 1.4) * CFrame.Angles(0, a, math.rad(25)) * CFrame.Angles(0, math.rad(45), 0), THUNDER:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Neon)
	end
	local at = Instance.new("Attachment")
	at.Parent = core
	local pe = Instance.new("ParticleEmitter") -- sparks: Rate 3 x 0.4 s, ~1 live
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromHex("E3D9FF"), THUNDER)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Speed = NumberRange.new(4, 7)
	pe.Lifetime = NumberRange.new(0.3, 0.5)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Rate = 3
	pe.Parent = at
end
Builders.thunder1 = thunder
Builders.thunder2 = thunder

-- Meditation Spring: a small steaming hot spring in a stone ring, with a stone lantern beside it.
local function spring(ctx, pad)
	local f = ctx.frame * plotFrame(ctx, pad)
	local pond = Style.pond(ctx.folder, f, 3.6, Color3.fromHex("7FD3D9"))
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(5, 0.2, 5)
	holder.CFrame = f * CFrame.new(0, 0.4, 0)
	holder.Parent = pond
	local steam = Instance.new("ParticleEmitter") -- Rate 2 x 4 s, ~8 live
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Size = NumberSequence.new(1.5, 4)
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1) })
	steam.Lifetime = NumberRange.new(3, 5)
	steam.Speed = NumberRange.new(0.6, 1.2)
	steam.Shape = Enum.ParticleEmitterShape.Box
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Rate = 2
	steam.Parent = holder
	Style.lantern(ctx.folder, f * CFrame.new(4.6, 0, -2.6), 0.6)
end
Builders.spring1 = spring
Builders.spring2 = spring

-- Sky Islets (owner pick B 2026-10-22): nothing stands by default, roads and trees included.
-- A bridge pad lays the rope bridge to its islet (Config.bridgeEnds; 3 studs onto each rim).
local function bridge(ctx, pad)
	local a, b = Config.bridgeEnds(pad.id:match("^bridge_(%w+)$"))
	local d = (b - a).Unit
	local lift = Vector3.new(0, 0.05, 0)
	Style.bridge(ctx.folder, ctx.frame * (a - d * 3) + lift, ctx.frame * (b + d * 3) + lift, 7)
end
for name in Config.ISLETS do
	Builders["bridge_" .. name] = bridge
end

-- A path pad: on the heart, the plaza ring round the platform and spokes to the bridges leaving
-- it; on an islet, a road from where its bridge lands to its middle, and on to the bridges leaving
-- it (Harmony, Config.HARMONY_STEP).
local function islandPath(ctx, pad)
	local name = Config.isletOf(pad)
	local i = Config.ISLETS[name]
	local c = Vector3.new(i.x, 0, i.z)
	local hub
	if name == "heart" then
		Style.road(ctx.folder, ctx.frame, {}, 5, Config.PLAZA_RING)
	else
		local _, land = Config.bridgeEnds(name)
		hub = c + (land - c) * 0.35
		Style.road(ctx.folder, ctx.frame, { { land.X, land.Z }, { hub.X, hub.Z } }, 4.5)
	end
	for other, j in Config.ISLETS do
		if j.from == name then
			local foot = Config.bridgeEnds(other)
			local from = hub or c + (foot - c).Unit * Config.PLAZA_RING
			Style.road(ctx.folder, ctx.frame, { { from.X, from.Z }, { foot.X, foot.Z } }, 4.5)
		end
	end
end

-- A grove pad: three trees of its islet's kind round the spot, with a bush between (Harmony).
local GROVE = { heart = "sakura", fields = "sakura", dao = "maple", disciples = "pine", summit = "pine" }
local function grove(ctx, pad)
	local kind = pad.tree or GROVE[Config.isletOf(pad)]
	local rng = Random.new(#pad.id * 31 + math.floor(pad.x))
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(3.5, 5)
		local cf = ctx.frame * CFrame.new(pad.x + math.cos(a) * r, 0, pad.z + math.sin(a) * r)
		local seed = 70 + k * 13 + #pad.id
		if kind == "pine" then
			Style.pine(ctx.folder, cf, seed, 11 + k * 2)
		elseif Nature.ready(kind) then
			Nature.tree(ctx.folder, cf, seed, kind, rng:NextNumber(0.7, 0.85))
		else
			Style.sakura(ctx.folder, cf, seed)
		end
	end
	-- flowers on the bush (a colour, not a flag: Nature.bush paints them) except under pines
	local flower = kind ~= "pine" and Color3.fromHex("FFC2D4") or nil
	Nature.bush(ctx.folder, ctx.frame * CFrame.new(pad.x, 0, pad.z), 90 + #pad.id, 1.6, flower)
end
for name in Config.ISLETS do
	Builders["path_" .. name] = islandPath
	Builders["grove_" .. name] = grove
end

return Builders
