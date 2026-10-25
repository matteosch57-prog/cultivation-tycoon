-- Mock for 2026-10-25_rebirth_new_looks options B and C. Run in Studio EDIT through run_code; builds
-- workspace.MockRebirthUnlocks at x = 5000 and returns camera spots. Delete the folder after the
-- captures; never save the place with it.
--   B: three buildings a rebirth would open (Sword Forge, Star Observatory, Spirit Beast Den), kit style
--   C: the Relic Terrace, five relic statues on pedestals, the 5th still a dim silhouette ("next rebirth")
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Kit = require(Server:WaitForChild("Kit"))
local Style = require(Server:WaitForChild("Style"))
local PAL = Style.PAL
local hex = Color3.fromHex

local old = workspace:FindFirstChild("MockRebirthUnlocks")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MockRebirthUnlocks"
root.Parent = workspace

local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local function cylY(parent, h, d, cf, color, mat)
	return P(parent, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end
local function fx(parent, at, size, color, accel, light, rate)
	local box = P(parent, size, CFrame.new(at), Color3.new(1, 1, 1))
	box.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = light or 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(3, 5)
	pe.Speed = NumberRange.new(1, 2)
	pe.Acceleration = accel or Vector3.new(0, 1, 0)
	pe.Rate = rate or 15
	pe.Parent = box
	pe:Emit((rate or 15) * 4)
end
local function ground(parent, at, w, d)
	P(parent, Vector3.new(w, 2, d), at * CFrame.new(0, -1, 0), PAL.grass, Enum.Material.Grass)
end

local BASE = CFrame.new(5000, 300, 0)
local spots = {}

-- B1 Sword Forge: a kit hall with a stone chimney, a glowing furnace mouth and a rack of jian
do
	local at = BASE
	local m = Instance.new("Model")
	m.Name = "B1 Sword Forge"
	m.Parent = root
	ground(m, at, 70, 70)
	Kit.hall(m, at, { bays = 3, bay = 5.5, depth = 2, colH = 7, plinth = 1.4, name = "ForgeHall", plaque = "Sword Forge" })
	local ch = at * CFrame.new(12, 0, -4)
	P(m, Vector3.new(5, 26, 5), ch * CFrame.new(0, 13, 0), PAL.stone, Enum.Material.Cobblestone)
	P(m, Vector3.new(6, 1, 6), ch * CFrame.new(0, 26.5, 0), PAL.stoneLight)
	P(m, Vector3.new(3, 3, 0.4), ch * CFrame.new(0, 3, 2.6), hex("FF7A2A"), Enum.Material.Neon)
	fx(m, (ch * CFrame.new(0, 28, 0)).Position, Vector3.new(3, 1, 3), hex("FF9A4A"), Vector3.new(0, 4, 0), 1, 20)
	local rack = at * CFrame.new(-6, 1.4, 14)
	P(m, Vector3.new(10, 0.5, 0.5), rack * CFrame.new(0, 4, 0), PAL.timberDark)
	for i = -2, 2 do
		P(m, Vector3.new(0.25, 5, 0.6), rack * CFrame.new(i * 2, 2.5, 0) * CFrame.Angles(0, 0, 0.08), hex("D8E2EA"), Enum.Material.Metal)
		P(m, Vector3.new(1.2, 0.25, 0.4), rack * CFrame.new(i * 2, 1.1, 0), PAL.gold, Enum.Material.Metal)
	end
	cylY(m, 1.6, 3, at * CFrame.new(4, 2.2, 14), hex("4A4A4F"), Enum.Material.Metal) -- anvil drum
	spots[#spots + 1] = { name = "B1 Sword Forge", camFrom = at.Position + Vector3.new(30, 18, 48), lookAt = at.Position + Vector3.new(0, 8, 0) }
end

-- B2 Star Observatory: a round stone tower, an open top deck with a bronze armillary sphere
do
	local at = BASE * CFrame.new(120, 0, 0)
	local m = Instance.new("Model")
	m.Name = "B2 Star Observatory"
	m.Parent = root
	ground(m, at, 70, 70)
	cylY(m, 2, 22, at * CFrame.new(0, 1, 0), PAL.stoneLight, Enum.Material.Marble)
	cylY(m, 18, 14, at * CFrame.new(0, 11, 0), PAL.plaster, Enum.Material.Plaster)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		P(m, Vector3.new(0.9, 18, 0.9), at * CFrame.new(math.cos(a) * 7.2, 11, math.sin(a) * 7.2), Kit.RED)
	end
	cylY(m, 1, 18, at * CFrame.new(0, 20.5, 0), PAL.stone)
	Kit.railing(m, (at * CFrame.new(-8, 21, 8)).Position, (at * CFrame.new(8, 21, 8)).Position, 2)
	local c = at * CFrame.new(0, 27, 0)
	for k = 0, 2 do
		local ring = c * CFrame.Angles(k * 0.6, k * 1.1, 0)
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2
			P(m, Vector3.new(0.5, 0.5, 1.4), ring * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -4.5), hex("B88A3A"), Enum.Material.Metal)
		end
	end
	P(m, Vector3.new(1.6, 1.6, 1.6), c, hex("CFE6FF"), Enum.Material.Neon, Enum.PartType.Ball)
	cylY(m, 5, 0.8, at * CFrame.new(0, 23.5, 0), hex("B88A3A"), Enum.Material.Metal)
	fx(m, c.Position, Vector3.new(10, 10, 10), hex("DDEBFF"), Vector3.new(0, 0, 0), 1, 10)
	spots[#spots + 1] = { name = "B2 Star Observatory", camFrom = at.Position + Vector3.new(28, 20, 44), lookAt = at.Position + Vector3.new(0, 15, 0) }
end

-- B3 Spirit Beast Den: a moon gate cave in a rock mound, a resting jade qilin statue at its mouth
do
	local at = BASE * CFrame.new(240, 0, 0)
	local m = Instance.new("Model")
	m.Name = "B3 Spirit Beast Den"
	m.Parent = root
	ground(m, at, 70, 70)
	local rng = Random.new(3)
	for _ = 1, 9 do
		local s = rng:NextNumber(8, 14)
		P(m, Vector3.new(s, s * 0.8, s), at * CFrame.new(rng:NextNumber(-10, 10), s * 0.35, rng:NextNumber(-12, -2)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), PAL.rock, Enum.Material.Slate)
	end
	Kit.moonGate(m, at * CFrame.new(0, 0, 2))
	local q = at * CFrame.new(0, 0, 10)
	P(m, Vector3.new(5, 1, 3), q * CFrame.new(0, 0.5, 0), PAL.stone)
	P(m, Vector3.new(4, 2, 2), q * CFrame.new(0, 2, 0), PAL.jade, Enum.Material.Glass)
	P(m, Vector3.new(1.8, 1.8, 1.8), q * CFrame.new(2, 3.2, 0), PAL.jade, Enum.Material.Glass)
	P(m, Vector3.new(0.4, 1.6, 0.4), q * CFrame.new(2.4, 4.6, 0) * CFrame.Angles(0, 0, -0.4), PAL.gold, Enum.Material.Metal)
	fx(m, (at * CFrame.new(0, 6, 2)).Position, Vector3.new(6, 6, 2), hex("9FF5C8"), Vector3.new(0, 0.5, 0), 1, 10)
	spots[#spots + 1] = { name = "B3 Spirit Beast Den", camFrom = at.Position + Vector3.new(26, 14, 40), lookAt = at.Position + Vector3.new(0, 5, 0) }
end

-- C Relic Terrace: a stone terrace with 5 pedestals; relics 1-4 earned, 5 a dark silhouette
do
	local at = BASE * CFrame.new(360, 0, 0)
	local m = Instance.new("Model")
	m.Name = "C Relic Terrace"
	m.Parent = root
	ground(m, at, 80, 60)
	P(m, Vector3.new(56, 1.6, 16), at * CFrame.new(0, 0.8, 0), PAL.stoneLight, Enum.Material.Marble)
	Kit.railing(m, (at * CFrame.new(-28, 1.6, -8)).Position, (at * CFrame.new(28, 1.6, -8)).Position, 2)
	local function pedestal(x)
		local c = at * CFrame.new(x, 1.6, 0)
		P(m, Vector3.new(5, 0.8, 5), c * CFrame.new(0, 0.4, 0), PAL.stone)
		P(m, Vector3.new(3.6, 3, 3.6), c * CFrame.new(0, 2.3, 0), PAL.stoneLight, Enum.Material.Marble)
		P(m, Vector3.new(4.4, 0.5, 4.4), c * CFrame.new(0, 4, 0), PAL.gold, Enum.Material.Metal)
		return c * CFrame.new(0, 4.25, 0)
	end
	local xs = { -22, -11, 0, 11, 22 }
	-- 1 bronze ding cauldron
	local t = pedestal(xs[1])
	Style.cauldron(m, t, 0.8)
	-- 2 jade seal with a coiled top
	t = pedestal(xs[2])
	P(m, Vector3.new(2.6, 2, 2.6), t * CFrame.new(0, 1, 0), PAL.jade, Enum.Material.Glass)
	P(m, Vector3.new(1.4, 1.4, 1.4), t * CFrame.new(0, 2.6, 0), PAL.jade, Enum.Material.Glass, Enum.PartType.Ball)
	-- 3 sword in stone
	t = pedestal(xs[3])
	P(m, Vector3.new(2.6, 1.6, 2.2), t * CFrame.new(0, 0.8, 0), PAL.rock, Enum.Material.Slate)
	P(m, Vector3.new(0.3, 5, 0.7), t * CFrame.new(0, 3.6, 0), hex("E4ECF2"), Enum.Material.Metal)
	P(m, Vector3.new(1.8, 0.3, 0.5), t * CFrame.new(0, 5.6, 0), PAL.gold, Enum.Material.Metal)
	fx(m, (t * CFrame.new(0, 4, 0)).Position, Vector3.new(2, 4, 2), hex("CFE6FF"), Vector3.new(0, 1, 0), 1, 8)
	-- 4 golden phoenix feather fan
	t = pedestal(xs[4])
	for i = -3, 3 do
		P(m, Vector3.new(0.5, 4, 0.2), t * CFrame.Angles(0, 0, i * 0.22) * CFrame.new(0, 2.2, 0), hex("FFC24A"), Enum.Material.Foil)
	end
	-- 5 next rebirth: a dark glass silhouette and a lock plate
	t = pedestal(xs[5])
	local s = P(m, Vector3.new(2, 4, 2), t * CFrame.new(0, 2, 0), hex("20242E"), Enum.Material.Glass)
	s.Transparency = 0.35
	P(m, Vector3.new(2.2, 2.2, 2.2), t * CFrame.new(0, 4.8, 0), hex("20242E"), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.35
	spots[#spots + 1] = { name = "C Relic Terrace", camFrom = at.Position + Vector3.new(0, 16, 36), lookAt = at.Position + Vector3.new(0, 5, 0) }
end

return spots
