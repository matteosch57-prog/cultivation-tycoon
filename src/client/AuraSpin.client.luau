-- Turns the ground glyphs of the player auras (src/server/AuraGlyph.luau): each layer's Motor6D
-- (tag "AuraSpin") gets a Transform about the vertical by its Spin attribute (degrees a second).
-- Only glyphs near and on screen turn (R16); the rest hold still where they are. Also preloads the
-- aura textures (Config.AURA_TEX), and blends emitters tagged "AuraDaylight" (the light column) from their
-- night look to their DayBrightness / DayTransparency attributes by day (DayNight.client's NightWeight).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local PerfMark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PerfMark"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- the aura textures load up front, so a new realm's glyph does not pop in a second late (Play 2026-10-23)
task.spawn(function()
	local ids = {}
	local function add(id)
		if id and id ~= 0 then
			local im = Instance.new("ImageLabel")
			im.Image = "rbxassetid://" .. id
			table.insert(ids, im)
		end
	end
	add(Config.AURA_TEX.glow)
	add(Config.AURA_TEX.column)
	add(Config.AURA_TEX.runes)
	for _, pair in Config.AURA_TEX.realms do
		add(pair[1])
		add(pair[2])
	end
	pcall(game:GetService("ContentProvider").PreloadAsync, game:GetService("ContentProvider"), ids)
end)

local NEAR = 160 -- studs, the glyph SurfaceGui's MaxDistance
local GLYPH_R = 8 -- studs, about the largest glyph's radius

local spins = {}
local function add(m)
	if m:IsA("Motor6D") then
		spins[m] = math.rad(m:GetAttribute("Spin") or 0)
	end
end
for _, m in CollectionService:GetTagged("AuraSpin") do
	add(m)
end
CollectionService:GetInstanceAddedSignal("AuraSpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("AuraSpin"):Connect(function(m)
	spins[m] = nil
end)

-- PreSimulation: the engine applies the joints' Transforms in one batch right after
RunService.PreSimulation:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam or next(spins) == nil then
		return
	end
	local t0 = PerfMark.begin()
	local eye = cam.CFrame.Position
	local now = os.clock()
	for m, w in spins do
		local p = m.Part1
		if p and (p.Position - eye).Magnitude < NEAR and PerfMark.onScreen(cam, p.Position, GLYPH_R) then
			m.Transform = CFrame.Angles(0, (now * w) % (math.pi * 2), 0)
		end
	end
	PerfMark.finish("auraSpin", t0)
end)

-- day/night look of the light column: night values are what the server set, day values its attributes
local daylit = {}
local function nightWeight()
	return Lighting:GetAttribute("NightWeight") or 0
end
local function mix(a, b, k)
	local ka, kb, out = a.Keypoints, b.Keypoints, {}
	if #ka ~= #kb then
		return k < 0.5 and b or a
	end
	for i, p in ka do
		table.insert(out, NumberSequenceKeypoint.new(p.Time, kb[i].Value + (p.Value - kb[i].Value) * k))
	end
	return NumberSequence.new(out)
end
local function apply(pe, d, k)
	pe.Brightness = d.dayB + (d.nightB - d.dayB) * k
	pe.Transparency = mix(d.nightT, d.dayT, k)
end
local function addLit(pe)
	if not pe:IsA("ParticleEmitter") or daylit[pe] then
		return
	end
	local d = {
		nightB = pe.Brightness,
		nightT = pe.Transparency,
		dayB = pe:GetAttribute("DayBrightness") or pe.Brightness,
		dayT = pe:GetAttribute("DayTransparency") or pe.Transparency,
	}
	daylit[pe] = d
	apply(pe, d, nightWeight())
end
for _, pe in CollectionService:GetTagged("AuraDaylight") do
	addLit(pe)
end
CollectionService:GetInstanceAddedSignal("AuraDaylight"):Connect(addLit)
CollectionService:GetInstanceRemovedSignal("AuraDaylight"):Connect(function(pe)
	daylit[pe] = nil
end)
-- NightWeight changes only during the 20 s fades, so this runs rarely (R16 rule 4)
Lighting:GetAttributeChangedSignal("NightWeight"):Connect(function()
	local k = nightWeight()
	for pe, d in daylit do
		apply(pe, d, k)
	end
end)
