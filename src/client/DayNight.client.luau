-- Day and night (owner 2026-10-23: light C by day, "N2: 10-4m"). Day = the place's own Lighting (light C,
-- authored in Edit, ART_BIBLE "Lighting"); night = Config.NIGHT (blue hour just after sunset). The phase comes
-- from the server clock (Config.DAY_SECONDS + Config.NIGHT_SECONDS a cycle), so every player sees the same hour
-- with nothing replicated; each change is a Config.NIGHT_FADE s smooth blend. The bird bed fades out at night
-- and a cricket bed in. Lighting is written only while a blend runs (R16 rule 4).
-- Studio test: set the workspace attribute DayNightOffset (seconds) on the client to jump in the cycle.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))

Sfx.init()

local N = Config.NIGHT
-- the sky-all-round haze (Config.SKY) is also set by the server at boot; set it here too so the day values read
-- below never catch the place's originals if this script runs first
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	for prop, v in Config.SKY.atmosphere do
		atmosphere[prop] = v
	end
end
-- each blended target: { instance, property, day value (read from the place), night value }
local targets = {}
local function add(inst, prop, night)
	if inst and night ~= nil then
		table.insert(targets, { inst, prop, inst[prop], night })
	end
end
for _, prop in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ExposureCompensation" } do
	add(Lighting, prop, N[prop])
end
local groups = {
	{ atmosphere, N.atmosphere },
	{ Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), N.color },
	{ Lighting:FindFirstChildOfClass("BloomEffect"), N.bloom },
	{ Lighting:FindFirstChildOfClass("SunRaysEffect"), N.sunRays },
}
for _, g in groups do
	if g[1] then
		for prop, night in g[2] do
			add(g[1], prop, night)
		end
	end
end

local crickets = Instance.new("Sound")
crickets.Name = "NightBed"
crickets.SoundId = "rbxassetid://" .. Config.NIGHT_BED.id
crickets.Looped = true
crickets.Volume = 0
crickets.SoundGroup = SoundService:WaitForChild("Ambience")
crickets.Parent = SoundService
crickets:Play()

local function lerp(a, b, k)
	if typeof(a) == "Color3" then
		return a:Lerp(b, k)
	end
	return a + (b - a) * k
end

-- night weight 0..1 at server time `now`: the last NIGHT_FADE s of the day blend in, the last NIGHT_FADE s of
-- the night blend out (smoothstep)
local function nightWeight(now)
	local day, night, fade = Config.DAY_SECONDS, Config.NIGHT_SECONDS, Config.NIGHT_FADE
	local t = (now + (workspace:GetAttribute("DayNightOffset") or 0)) % (day + night)
	local k
	if t < day - fade then
		k = 0
	elseif t < day then
		k = (t - (day - fade)) / fade
	elseif t < day + night - fade then
		k = 1
	else
		k = 1 - (t - (day + night - fade)) / fade
	end
	return k * k * (3 - 2 * k)
end

-- a brand-new save's first NEW_DAY s stay in daylight (thread "Keep new players past 10 minutes": in 2 of
-- 4 fresh-save runs the sky went dark by 1:30, the new player's first look at the sect), then the
-- server's hour blends in over NIGHT_FADE s
local NEW_DAY = 600
local player = game:GetService("Players").LocalPlayer
local function dayHold()
	if player:GetAttribute("NewSave") ~= true then
		return 1
	end
	return math.clamp((time() - NEW_DAY) / Config.NIGHT_FADE, 0, 1)
end

local last = nil
RunService.Heartbeat:Connect(function()
	local k = nightWeight(workspace:GetServerTimeNow()) * dayHold()
	if last and math.abs(k - last) < 0.002 and k ~= 0 and k ~= 1 then
		return
	end
	if k == last then
		return
	end
	last = k
	local t0 = PerfMark.begin()
	for _, t in targets do
		t[1][t[2]] = lerp(t[3], t[4], k)
	end
	if Sfx.birds then
		Sfx.birds.Volume = Sfx.birdsVol * (1 - k)
	end
	crickets.Volume = Config.NIGHT_BED.vol * k
	Lighting:SetAttribute("NightWeight", k) -- local only: read by AuraSpin.client (day-bright aura column)
	PerfMark.finish("daynight", t0)
end)
