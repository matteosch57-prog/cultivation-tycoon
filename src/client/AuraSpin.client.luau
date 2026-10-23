-- Turns the ground glyphs of the player auras (src/server/AuraGlyph.luau): each layer's Motor6D
-- (tag "AuraSpin") gets a Transform about the vertical by its Spin attribute (degrees a second).
-- Only glyphs near and on screen turn (R16); the rest hold still where they are. Also preloads the
-- aura textures (Config.AURA_TEX).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
