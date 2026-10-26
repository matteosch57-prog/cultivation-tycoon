-- Heavenly Weather in the sky (owner pick B 2026-10-25, mock docs/art/mocks/2026-10-25_live_events.html,
-- copy Grow a Garden's weather): the server sets Weather / WeatherUntil on the Workspace (Main.server
-- weatherTick); every client draws it on its own, nothing else is replicated. One tint over the
-- picture (a ColorCorrectionEffect under the camera, so DayNight's own blend never fights it) and a
-- field of particles that follows the camera:
--   rain     Spirit Rain: blue-white streaks
--   thunder  Thunder Tribulation: heavy violet rain, a lightning bolt and a flash every few seconds
--   blood    Blood Moon: a red tint, a red moon low in the sky, slow red petals
--   star     Starfall: shooting stars across the sky and a few motes drifting down
-- The banner, the HUD line and the odds live in Hud / RecruitOdds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))

Sfx.init()

local FADE = 2.5 -- s for the tint to come and go
local PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local DENSITY = PHONE and 0.6 or 1 -- fewer particles on a phone (R16)

-- the picture's tint per weather (none = the neutral values below)
local TINTS = {
	rain = { TintColor = Color3.fromRGB(214, 228, 255), Brightness = -0.04, Contrast = 0.02, Saturation = -0.12 },
	thunder = { TintColor = Color3.fromRGB(200, 186, 255), Brightness = -0.1, Contrast = 0.08, Saturation = -0.2 },
	blood = { TintColor = Color3.fromRGB(255, 176, 176), Brightness = -0.06, Contrast = 0.1, Saturation = 0.05 },
	star = { TintColor = Color3.fromRGB(222, 246, 255), Brightness = 0.02, Contrast = 0.04, Saturation = 0.08 },
}
local NEUTRAL = { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 }

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "WeatherTint"
for k, v in NEUTRAL do
	tint[k] = v
end
local function camera()
	return workspace.CurrentCamera
end
tint.Parent = camera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	tint.Parent = camera()
end)

local function tween(inst, t, goal)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
	tw:Play()
	return tw
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	for k, v in props or {} do
		p[k] = v
	end
	return p
end

-- the field over the camera that every falling particle comes from
local FIELD = 110
local field = part({ Name = "WeatherField", Size = Vector3.new(FIELD, 1, FIELD) })
local function emitter(props)
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.LightInfluence = 0
	e.Enabled = false
	e.Rate = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = field
	return e
end
local rain = emitter({
	Name = "Rain",
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	Speed = NumberRange.new(70, 90),
	Lifetime = NumberRange.new(0.7, 0.9),
	Size = NumberSequence.new(0.18),
	Squash = NumberSequence.new(3.2), -- a soft blob stretched tall: a streak
	-- no glow and a grey-blue tone: a glowing white streak vanished against the day sky (Studio check
	-- 2026-10-26), a darker one reads on sky and ground alike
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.6) }),
	LightEmission = 0,
	SpreadAngle = Vector2.new(4, 4),
})
local petals = emitter({
	Name = "Petals",
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Speed = NumberRange.new(6, 10),
	Lifetime = NumberRange.new(5, 7),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.3) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-90, 90),
	SpreadAngle = Vector2.new(25, 25),
	LightEmission = 0.5,
	Brightness = 2,
})

local KINDS = {
	rain = { rain = 260, rainColor = Color3.fromRGB(150, 175, 215) },
	thunder = { rain = 420, rainColor = Color3.fromRGB(165, 150, 215), bolts = true },
	blood = { petals = 30, petalColor = Color3.fromRGB(255, 80, 96), moon = Color3.fromRGB(255, 70, 80) },
	star = { petals = 14, petalColor = Color3.fromRGB(190, 250, 255), stars = true },
}

local active -- the weather key drawn now
local moon
local token = 0 -- each start bumps it: the bolt / star loops of an older weather stop

-- the camera's focus on the ground: where bolts land and shooting stars cross
local function focus()
	local cam = camera()
	return cam and cam.Focus.Position or Vector3.zero
end

-- a jagged bolt of Neon from the clouds to the ground in front of the camera, a flash, then thunder
local function bolt(color)
	local cam = camera()
	if not cam then
		return
	end
	-- in front of the camera, 50-130 studs out and off to either side, so it lands in view (around the
	-- focus it was mostly behind or under a level camera, Studio check 2026-10-26)
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-look.Z, 0, look.X)
	local ground = Vector3.new(cam.CFrame.Position.X, focus().Y, cam.CFrame.Position.Z) + look * math.random(50, 130) + side * math.random(-50, 50)
	local top = ground + Vector3.new(math.random(-20, 20), 170, math.random(-20, 20))
	local folder = Instance.new("Folder")
	folder.Name = "WeatherBolt"
	local last = top
	local steps = 7
	for i = 1, steps do
		local t = i / steps
		local nextAt = top:Lerp(ground, t) + (i < steps and Vector3.new(math.random(-9, 9), 0, math.random(-9, 9)) or Vector3.zero)
		local len = (nextAt - last).Magnitude
		local seg = part({
			Name = "Segment",
			Material = Enum.Material.Neon,
			Color = color:Lerp(Color3.new(1, 1, 1), 0.55),
			Transparency = 0,
			Size = Vector3.new(0.9, 0.9, len),
			CFrame = CFrame.lookAt((last + nextAt) / 2, nextAt),
		})
		seg.Parent = folder
		last = nextAt
	end
	folder.Parent = cam
	local flash = tint.Brightness
	tint.Brightness = flash + 0.32
	tween(tint, 0.35, { Brightness = flash })
	task.delay(0.12, function()
		for _, seg in folder:GetChildren() do
			tween(seg, 0.2, { Transparency = 1 })
		end
		task.wait(0.25)
		folder:Destroy()
	end)
	task.delay(0.25 + math.random() * 0.4, function()
		Sfx.play("thunder", { volume = 0.35 })
	end)
end

-- a shooting star: a small Neon head with a trail, across the sky in about a second
local function shootingStar(color)
	local cam = camera()
	if not cam then
		return
	end
	local f = focus()
	local from = f + Vector3.new(math.random(-160, 160), math.random(120, 170), math.random(-160, 160))
	local dir = Vector3.new(math.random(-10, 10), -4, math.random(-10, 10))
	if dir.Magnitude < 1 then
		dir = Vector3.new(1, -0.4, 0)
	end
	local to = from + dir.Unit * math.random(180, 260)
	local head = part({ Name = "WeatherStar", Material = Enum.Material.Neon, Color = color, Transparency = 0, Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(from) })
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
	a0.Parent, a1.Parent = head, head
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = head
	head.Parent = cam
	local t = 0.9 + math.random() * 0.5
	tween(head, t, { CFrame = CFrame.new(to) })
	task.delay(t + 0.7, function()
		head:Destroy()
	end)
end

local function stop()
	active = nil
	token += 1
	rain.Enabled, petals.Enabled = false, false
	tween(tint, FADE, NEUTRAL)
	if moon then
		local m = moon
		moon = nil
		tween(m, FADE, { Transparency = 1 }).Completed:Connect(function()
			m:Destroy()
		end)
	end
end

local function start(key)
	stop()
	local k = KINDS[key]
	local w = Config.weather(key)
	if not k or not w then
		return
	end
	active = key
	token += 1
	local my = token
	tween(tint, FADE, TINTS[key] or NEUTRAL)
	if k.rain then
		rain.Color = ColorSequence.new(k.rainColor)
		rain.Rate = k.rain * DENSITY
		rain.Enabled = true
	end
	if k.petals then
		petals.Color = ColorSequence.new(k.petalColor)
		petals.Rate = k.petals * DENSITY
		petals.Enabled = true
	end
	if k.moon then
		-- 300 studs off at a third of the size: the same in the sky, and still drawn (at 900 Studio and low
		-- graphics never drew it, Studio check 2026-10-26)
		moon = part({ Name = "WeatherMoon", Material = Enum.Material.Neon, Color = k.moon, Shape = Enum.PartType.Ball, Size = Vector3.new(30, 30, 30), Transparency = 1 })
		moon.Parent = camera()
		tween(moon, FADE, { Transparency = 0.05 })
	end
	if k.bolts then
		task.spawn(function()
			task.wait(1.5)
			while token == my do
				bolt(w.color)
				task.wait(4 + math.random() * 6)
			end
		end)
	end
	if k.stars then
		task.spawn(function()
			while token == my do
				shootingStar(w.color)
				task.wait((0.5 + math.random() * 0.8) / DENSITY)
			end
		end)
	end
end

-- the moon's place: low over the horizon in a fixed direction, far off, moving with the camera
local MOON_DIR = Vector3.new(0.55, 0.32, -0.77).Unit
RunService.RenderStepped:Connect(function()
	local cam = camera()
	if not cam or not active then
		return
	end
	if field.Parent ~= cam then
		field.Parent = cam
	end
	local at = cam.CFrame.Position
	field.CFrame = CFrame.new(at.X, at.Y + 45, at.Z)
	if moon then
		moon.CFrame = CFrame.new(at + MOON_DIR * 300)
	end
end)

-- what the server says now: start, change or stop
local function check()
	local key = workspace:GetAttribute("Weather")
	local on = (workspace:GetAttribute("WeatherUntil") or 0) > workspace:GetServerTimeNow()
	if on and key ~= active then
		start(key)
	elseif not on and active then
		stop()
	end
end
workspace:GetAttributeChangedSignal("Weather"):Connect(check)
workspace:GetAttributeChangedSignal("WeatherUntil"):Connect(check)
task.spawn(function()
	while true do
		check()
		task.wait(0.5)
	end
end)
