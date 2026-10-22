-- Ambience (owner 2026-10-22 "let's do it all"; research docs/research/2026-10-22_ambience_and_perf_easy_wins.md):
--  * wind: workspace.GlobalWind (Config.WIND_*) with slow gusts. Terrain grass, Fire, smoke and every emitter
--    with WindAffectsDrag (petals, leaves, clouds, mist) lean with it; the wind bed swells with each gust.
--    Set on each client (a property the server never writes), so nothing replicates.
--  * place: under a roof (a ray up from the character hits a building of a peak) the hall reverb and muffled
--    outdoor beds (Sfx.setIndoor); outside, the open air. Checked 4 times a second, written only on a change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

local player = Players.LocalPlayer
local sect = workspace:WaitForChild("Sect")

Sfx.init()

-- the wind bed: one non-positional loop in the Ambience group (muffled indoors with the birds)
local bed = Instance.new("Sound")
bed.Name = "WindBed"
bed.SoundId = "rbxassetid://" .. Config.WIND_BED.id
bed.Volume = Config.WIND_BED.vol
bed.Looped = true
bed.SoundGroup = SoundService:WaitForChild("Ambience")
bed.Parent = SoundService
bed:Play()

-- gust envelope 0..1: calm for a random gap, then a smooth swell up and down (a half sine each way)
local rng = Random.new()
local gustStart = os.clock() + rng:NextNumber(Config.WIND_GUST_GAP[1], Config.WIND_GUST_GAP[2])
local function gust(now)
	local t = now - gustStart
	local rise = Config.WIND_GUST_RISE
	if t < 0 then
		return 0
	end
	if t >= rise * 2 then
		gustStart = now + rng:NextNumber(Config.WIND_GUST_GAP[1], Config.WIND_GUST_GAP[2])
		return 0
	end
	return math.sin(t / (rise * 2) * math.pi)
end

-- the roof test: only the peaks' buildings count (trees are not queryable; the altar is not a roof)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function refreshFilter()
	local peaks = {}
	for _, c in sect:GetChildren() do
		if c.Name:match("^Peak%d+$") then
			table.insert(peaks, c)
		end
	end
	rayParams.FilterDescendantsInstances = peaks
end
refreshFilter()
sect.ChildAdded:Connect(refreshFilter)

local indoor = nil
local lastWind = nil
local lastPlace = 0
RunService.Heartbeat:Connect(function()
	local t0 = PerfMark.begin()
	local now = os.clock()
	local g = gust(now)
	-- GlobalWind replicates nothing from here; write it only when it moved enough to see (R16 rule 4)
	local wind = Config.WIND_BASE * (1 + (Config.WIND_GUST - 1) * g)
	if not lastWind or (wind - lastWind).Magnitude > 0.05 then
		workspace.GlobalWind = wind
		lastWind = wind
		bed.Volume = Config.WIND_BED.vol + (Config.WIND_BED.gustVol - Config.WIND_BED.vol) * g
	end
	if now - lastPlace >= 0.25 then
		lastPlace = now
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local inside = false
		if head then
			inside = workspace:Raycast(head.Position, Vector3.new(0, Config.INDOOR_ROOF, 0), rayParams) ~= nil
		end
		if inside ~= indoor then
			indoor = inside
			Sfx.setIndoor(inside)
		end
	end
	PerfMark.finish("ambience", t0)
end)
