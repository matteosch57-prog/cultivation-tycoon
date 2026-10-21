-- Procedural low-poly builders. Each builder takes (ctx, pad) and parents parts to ctx.folder.
-- ctx = { folder, frame (peak CFrame, top surface at y=0, +Z faces the hub), pal (palette) }
local Builders = {}
local Style = require(script.Parent:WaitForChild("Style"))
local Lowpoly = require(script.Parent:WaitForChild("Lowpoly"))
local Cultivators = require(script.Parent:WaitForChild("Cultivators"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local SP = Style.PAL

-- Buildings around the sides face the CENTRE of the peak (their front, +Z, turned toward the
-- courtyard), not the bridge: built facing +Z, the side and corner ones showed their backs to
-- the courtyard and their fronts to the void. `back` pushes it away from the centre.
local function facingCentre(ctx, x, z, back)
	local p = Vector3.new(x, 0, z)
	local look = CFrame.lookAt(p, Vector3.new(0, 0, 0)) * CFrame.Angles(0, math.pi, 0)
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
		local smoke = Instance.new("Smoke")
		smoke.Size = 0.6
		smoke.RiseVelocity = 1.2
		smoke.Opacity = 0.08
		smoke.Color = Color3.fromRGB(230, 230, 240)
		smoke.Parent = stick
	end
end

function Builders.lanterns(ctx)
	for _, sx in { -1, 1 } do
		for _, z in { 18, 29, 40 } do -- clear of the Sect Gate columns at z=46
			Style.lantern(ctx.folder, ctx.frame * CFrame.new(sx * 6.2, 0, z), 0.9)
		end
	end
end

function Builders.garden(ctx, pad)
	local x, z = pad.x, pad.z
	local rng = Random.new(21)
	local greens = { Color3.fromHex("5E9A4A"), Color3.fromHex("4C8A54"), Color3.fromHex("86B85A") }
	local flowers = { Color3.fromHex("F4B6C2"), Color3.fromHex("FFF4D6"), Color3.fromHex("C9A0E8") }
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
			local s = rng:NextNumber(1.2, 1.7)
			part(ctx, Vector3.new(s, s * 0.8, s), CFrame.new(px, 1.3, z + bz) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), greens[(i % 3) + 1])
			if i % 2 == 0 then
				local f = part(ctx, Vector3.new(0.6, 0.6, 0.6), CFrame.new(px, 2.1, z + bz + 0.2), flowers[(i // 2) % 3 + 1])
				f.Shape = Enum.PartType.Ball
			end
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
	Style.pavilion(ctx.folder, at, 11, 8)
	Style.cauldron(ctx.folder, at * CFrame.new(0, 1.5, 0), 1.25)
end

function Builders.hall(ctx, pad)
	Style.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -2), { W = 16, D = 10, colH = 8, plinth = 2, name = "DiscipleHall" })
end

-- Disciple Quarters: small two-storey halls in the front corners (each adds a disciple slot)
function Builders.quarters1(ctx, pad)
	Style.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -3), { W = 12, D = 7, colH = 6, plinth = 1.5, name = "Quarters" })
end
function Builders.quarters2(ctx, pad)
	Style.hall(ctx.folder, facingCentre(ctx, pad.x, pad.z, -3), { W = 14, D = 8, colH = 7, plinth = 1.5, name = "GrandQuarters" })
end

function Builders.gate(ctx)
	Style.archway(ctx.folder, ctx.frame * CFrame.new(0, 0, 46), 16, 13)
end

-- the pagoda is bought in two halves that stack exactly (same baseW / tier count)
-- (z=-30 keeps its stair clear of the meditation terrace and its back clear of the shrine stair)
local PAGODA_AT = CFrame.new(0, 0, -74) -- behind the Main Hall, on the second expansion

-- The Main Hall: one building, five levels, always at the back centre of the peak
local MAIN_HALL_AT = CFrame.new(0, 0, -36)
for lv = 1, 5 do
	Builders["mainhall" .. lv] = function(ctx)
		Style.mainHall(ctx.folder, ctx.frame * MAIN_HALL_AT, lv)
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
	Style.bellTower(ctx.folder, facingCentre(ctx, pad.x, pad.z))
end
function Builders.koi(ctx, pad)
	Style.koiPond(ctx.folder, facingCentre(ctx, pad.x, pad.z), 5)
end
function Builders.library(ctx, pad)
	Style.library(ctx.folder, facingCentre(ctx, pad.x, pad.z, -4))
end
function Builders.moongate(ctx, pad)
	Style.moonGate(ctx.folder, facingCentre(ctx, pad.x, pad.z, -2))
end
function Builders.pagoda1(ctx)
	Style.pagoda(ctx.folder, ctx.frame * PAGODA_AT, 10, 1, 2, 5)
end

function Builders.pagoda2(ctx)
	Style.pagoda(ctx.folder, ctx.frame * PAGODA_AT, 10, 3, 5, 5)
end

function Builders.array(ctx, pad)
	Style.qiArray(ctx.folder, ctx.frame * CFrame.new(pad.x, 0, pad.z - 2), 8)
end

function Builders.shrine(ctx)
	Style.hall(ctx.folder, ctx.frame * CFrame.new(0, 0, -55), { W = 14, D = 7, colH = 7, plinth = 3, name = "PeakShrine" })
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

-- A seated cultivator on the meditation platform (slot 1..). The slot picks one of the four
-- looks; the rarity picks the robe colour and the aura (Cultivators.luau, mock
-- docs/art/mocks/cultivators_lineup.jpg).
function Builders.disciple(ctx, slot, rarity)
	local a = math.rad(-90 + (slot - 3) * 40)
	local x, z = math.cos(a) * 8.5, -math.sin(a) * 8.5 -- arc on the hub side of the platform
	local face = CFrame.new(x, 0, z) * CFrame.Angles(0, math.atan2(x, z), 0) -- face the centre
	local m = Cultivators.build(ctx.folder, ctx.frame * face, slot, rarity, Config.RARITIES)
	m.Name = "Disciple" .. slot
	return m
end

return Builders
