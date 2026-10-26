-- Mock: a building that never resets and shows one relic per Sect Missions rank (owner 2026-10-25:
-- "A building always on showing some relics based on progression of quests"). Three layouts, ranks 1-4
-- earned, 5-10 dark glass silhouettes (Animal Crossing museum / Prospecting display stands).
-- Run in Studio EDIT through run_code; builds workspace.MockRelicHall at x = 6000 and returns camera
-- spots. Delete the folder after the captures; never save the place with it.
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Kit = require(Server:WaitForChild("Kit"))
local Style = require(Server:WaitForChild("Style"))
local PAL = Style.PAL
local hex = Color3.fromHex

local old = workspace:FindFirstChild("MockRelicHall")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MockRelicHall"
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
local function glow(parent, at, color, rate)
	local box = P(parent, Vector3.new(2, 3, 2), CFrame.new(at), Color3.new(1, 1, 1))
	box.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Speed = NumberRange.new(0.5, 1)
	pe.Acceleration = Vector3.new(0, 1, 0)
	pe.Rate = rate or 6
	pe.Parent = box
	pe:Emit(15)
end

-- the ten relics, Sect Missions ranks 1 to 10 (Config.MISSION_RANKS); t = the top of the plinth
local GOLD = hex("FFD24A")
local RELICS = {
	function(m, t) -- 1 Sweeper: a golden broom
		P(m, Vector3.new(0.35, 4.2, 0.35), t * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, 0.15), PAL.timber)
		P(m, Vector3.new(1.8, 1.4, 0.6), t * CFrame.new(0.15, 0.7, 0), GOLD, Enum.Material.Foil)
	end,
	function(m, t) -- 2 Novice: a wooden practice sword on a stand
		P(m, Vector3.new(2.4, 0.3, 0.8), t * CFrame.new(0, 0.15, 0), PAL.timberDark)
		P(m, Vector3.new(0.3, 4, 0.6), t * CFrame.new(0, 2.6, 0), hex("B98A55"), Enum.Material.Wood)
		P(m, Vector3.new(1.4, 0.3, 0.5), t * CFrame.new(0, 1.1, 0), PAL.timberDark)
	end,
	function(m, t) -- 3 Acolyte: an incense burner
		cylY(m, 1.6, 2.2, t * CFrame.new(0, 0.8, 0), hex("8C6A3A"), Enum.Material.Metal)
		cylY(m, 0.3, 2.6, t * CFrame.new(0, 1.7, 0), hex("B88A3A"), Enum.Material.Metal)
		P(m, Vector3.new(0.15, 1.6, 0.15), t * CFrame.new(0, 2.6, 0), hex("C0392B"))
		glow(m, (t * CFrame.new(0, 3.8, 0)).Position, hex("E8E0D0"), 4)
	end,
	function(m, t) -- 4 Adept: a jade seal with a beast knob
		P(m, Vector3.new(2.4, 1.8, 2.4), t * CFrame.new(0, 0.9, 0), PAL.jade, Enum.Material.Glass)
		P(m, Vector3.new(1.4, 1.4, 1.4), t * CFrame.new(0, 2.5, 0), PAL.jade, Enum.Material.Glass, Enum.PartType.Ball)
	end,
	function(m, t) -- 5 Senior: a bronze ding
		Style.cauldron(m, t, 0.7)
	end,
	function(m, t) -- 6 Deacon: a phoenix feather fan
		for i = -3, 3 do
			P(m, Vector3.new(0.5, 3.6, 0.2), t * CFrame.Angles(0, 0, i * 0.22) * CFrame.new(0, 2, 0), hex("FFB04A"), Enum.Material.Foil)
		end
	end,
	function(m, t) -- 7 Steward: an open scroll on a rack
		P(m, Vector3.new(3, 2.2, 0.15), t * CFrame.new(0, 2, 0) * CFrame.Angles(-0.25, 0, 0), hex("F3E6C4"), Enum.Material.Fabric)
		for _, s in { -1, 1 } do
			cylY(m, 2.6, 0.45, t * CFrame.new(s * 1.6, 2, 0) * CFrame.Angles(-0.25, 0, 0), PAL.timberDark)
		end
	end,
	function(m, t) -- 8 Hall Master: a bronze bell in a frame
		for _, s in { -1, 1 } do
			P(m, Vector3.new(0.4, 4.4, 0.4), t * CFrame.new(s * 1.6, 2.2, 0), PAL.vermilion)
		end
		P(m, Vector3.new(4, 0.4, 0.5), t * CFrame.new(0, 4.4, 0), PAL.timberDark)
		cylY(m, 2.2, 2, t * CFrame.new(0, 2.9, 0), hex("8C6A3A"), Enum.Material.Metal)
	end,
	function(m, t) -- 9 Protector: a sword in stone
		P(m, Vector3.new(2.6, 1.4, 2.2), t * CFrame.new(0, 0.7, 0), PAL.rock, Enum.Material.Slate)
		P(m, Vector3.new(0.3, 4.4, 0.7), t * CFrame.new(0, 3.2, 0), hex("E4ECF2"), Enum.Material.Metal)
		P(m, Vector3.new(1.8, 0.3, 0.5), t * CFrame.new(0, 5, 0), GOLD, Enum.Material.Metal)
		glow(m, (t * CFrame.new(0, 3.5, 0)).Position, hex("CFE6FF"), 6)
	end,
	function(m, t) -- 10 Sect Master: the dragon pearl in a gold coil
		P(m, Vector3.new(2.2, 2.2, 2.2), t * CFrame.new(0, 2.4, 0), hex("FFF2B0"), Enum.Material.Glass, Enum.PartType.Ball)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			P(m, Vector3.new(0.5, 0.5, 0.9), t * CFrame.new(0, 1 + i * 0.25, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.5), GOLD, Enum.Material.Metal)
		end
		glow(m, (t * CFrame.new(0, 2.4, 0)).Position, hex("FFE27A"), 8)
	end,
}
local EARNED = 4

-- a relic on its plinth: earned in full colour, locked as a dark glass silhouette
local function relic(parent, cf, i)
	local m = Instance.new("Model")
	m.Name = "Relic" .. i
	P(m, Vector3.new(4.4, 0.6, 4.4), cf * CFrame.new(0, 0.3, 0), PAL.stone)
	P(m, Vector3.new(3.4, 2.4, 3.4), cf * CFrame.new(0, 1.8, 0), PAL.stoneLight, Enum.Material.Marble)
	P(m, Vector3.new(3.9, 0.4, 3.9), cf * CFrame.new(0, 3.2, 0), PAL.gold, Enum.Material.Metal)
	local item = Instance.new("Model")
	item.Parent = m
	RELICS[i](item, cf * CFrame.new(0, 3.4, 0))
	if i > EARNED then
		for _, d in item:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = hex("1C2030")
				d.Material = Enum.Material.Glass
				d.Transparency = math.max(d.Transparency, 0.3)
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false
				d:Clear()
			elseif d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Trail") then
				d.Enabled = false -- a locked relic shows no flame or glow (Style.cauldron's fire stayed lit)
			end
		end
	end
	m.Parent = parent
end

local function ground(parent, at, w, d)
	P(parent, Vector3.new(w, 2, d), at * CFrame.new(0, -1, 0), PAL.grass, Enum.Material.Grass)
end

local BASE = CFrame.new(6000, 300, 0)
local spots = {}

-- A Relic Pavilion: one big open pavilion, two rows of five plinths under the roof
do
	local at = BASE
	local m = Instance.new("Model")
	m.Name = "A Relic Pavilion"
	m.Parent = root
	ground(m, at, 90, 90)
	local _, h = Kit.pavilion(m, at, 30, 9)
	for i = 1, 10 do
		local row = i <= 5 and 1 or 2
		local k = (i - 1) % 5
		relic(m, at * CFrame.new(-12 + k * 6, h, row == 1 and 6 or -6), i)
	end
	spots[#spots + 1] = { name = "A Relic Pavilion", camFrom = at.Position + Vector3.new(26, 16, 46), lookAt = at.Position + Vector3.new(0, 5, 0) }
end

-- B Relic Terrace: ten plinths along a railed terrace under a painted gate
do
	local at = BASE * CFrame.new(150, 0, 0)
	local m = Instance.new("Model")
	m.Name = "B Relic Terrace"
	m.Parent = root
	ground(m, at, 100, 60)
	P(m, Vector3.new(70, 1.6, 14), at * CFrame.new(0, 0.8, 0), PAL.stoneLight, Enum.Material.Marble)
	Kit.railing(m, (at * CFrame.new(-35, 1.6, -7)).Position, (at * CFrame.new(35, 1.6, -7)).Position, 2)
	Kit.gate(m, at * CFrame.new(0, 1.6, -9), 12, 13, "Relics")
	for i = 1, 10 do
		local x = (i <= 5 and -32 or 8) + ((i - 1) % 5) * 6
		relic(m, at * CFrame.new(x, 1.6, 1), i)
	end
	spots[#spots + 1] = { name = "B Relic Terrace", camFrom = at.Position + Vector3.new(0, 18, 50), lookAt = at.Position + Vector3.new(0, 5, 0) }
end

-- C Relic Pagoda: five open floors, two relics a floor; an earned floor's trim glows gold
do
	local at = BASE * CFrame.new(300, 0, 0)
	local m = Instance.new("Model")
	m.Name = "C Relic Pagoda"
	m.Parent = root
	ground(m, at, 70, 70)
	local FLOOR = 11
	for f = 0, 4 do
		local y = f * FLOOR
		local w = 18 - f * 1.5
		P(m, Vector3.new(w + 2, 1, w + 2), at * CFrame.new(0, y + 0.5, 0), PAL.stoneLight, Enum.Material.Marble)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				P(m, Vector3.new(0.9, FLOOR - 1, 0.9), at * CFrame.new(sx * w / 2, y + FLOOR / 2 + 0.5, sz * w / 2), PAL.vermilion)
			end
		end
		local earned = (f + 1) * 2 <= EARNED
		local trim = P(m, Vector3.new(w + 2.6, 0.5, w + 2.6), at * CFrame.new(0, y + FLOOR - 0.2, 0), earned and GOLD or PAL.timberDark, earned and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		trim.Transparency = 0
		P(m, Vector3.new(w + 6, 0.8, w + 6), at * CFrame.new(0, y + FLOOR + 0.4, 0), PAL.tile, Enum.Material.ClayRoofTiles)
		relic(m, at * CFrame.new(-w / 4, y + 1, 0), f * 2 + 1)
		relic(m, at * CFrame.new(w / 4, y + 1, 0), f * 2 + 2)
	end
	P(m, Vector3.new(1.2, 6, 1.2), at * CFrame.new(0, 5 * FLOOR + 4, 0), GOLD, Enum.Material.Metal)
	spots[#spots + 1] = { name = "C Relic Pagoda", camFrom = at.Position + Vector3.new(34, 30, 58), lookAt = at.Position + Vector3.new(0, 26, 0) }
end

return spots
