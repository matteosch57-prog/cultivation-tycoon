-- Lightning around realm 9+ peaks (src/server/RealmLook.luau marks them: attributes Storm, StormAt,
-- StormBack, StormRadius). Owner pick B: no cloud, only strikes, built from research
-- (REINCARNATION "What each realm shows"):
--  * the channel is a midpoint-displacement path (each split halves the jitter), with 1 or 2 thinner
--    branches that stop in the air
--  * two passes: a thin white core inside a wider pale blue sheath
--  * a flash is 2 to 4 strokes down the same channel (~60 ms lit, 40 to 80 ms dark), re-jittered a
--    little each time, then gone
--  * a short PointLight at the foot for the stroke only (R3: an event flash), thunder after
--    distance / STORM_SOUND_SPEED
-- Strikes land in the air just past the rim behind the peak, never on buildings or players. Only for
-- peaks on screen (R16); about 40 Neon blocks for a third of a second every 8 to 18 s.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local PerfMark = require(Shared:WaitForChild("PerfMark"))
local sect = workspace:WaitForChild("Sect")

local fx = Instance.new("Folder")
fx.Name = "LocalStorm"
fx.Parent = workspace

local CORE = Color3.fromRGB(245, 248, 255)
local SHEATH = Color3.fromRGB(170, 190, 255)
local rng = Random.new()

-- midpoint displacement: points from a to b, `depth` halvings of `jitter`
local function channel(a, b, jitter, depth)
	local pts = { a, b }
	for _ = 1, depth do
		local out = { pts[1] }
		for i = 1, #pts - 1 do
			local p, q = pts[i], pts[i + 1]
			local mid = (p + q) / 2 + Vector3.new(rng:NextNumber(-jitter, jitter), rng:NextNumber(-jitter, jitter) * 0.3, rng:NextNumber(-jitter, jitter))
			table.insert(out, mid)
			table.insert(out, q)
		end
		pts = out
		jitter /= 2
	end
	return pts
end

local function segment(a, b, width, color, transparency)
	local s = Instance.new("Part")
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.CastShadow = false
	s.Material = Enum.Material.Neon
	s.Color = color
	s.Transparency = transparency
	s.Size = Vector3.new(width, width, (b - a).Magnitude + width * 0.5)
	s.CFrame = CFrame.lookAt((a + b) / 2, b)
	return s
end

-- one stroke: the main channel (core + sheath) and its branches, all in one model
local function stroke(top, foot, len)
	local m = Instance.new("Model")
	local main = channel(top, foot, len * 0.12, 4)
	for i = 1, #main - 1 do
		segment(main[i], main[i + 1], 0.7, CORE, 0).Parent = m
		segment(main[i], main[i + 1], 2.2, SHEATH, 0.55).Parent = m
	end
	for _ = 1, rng:NextInteger(1, 2) do
		local from = main[rng:NextInteger(3, #main - 4)]
		local dir = (foot - top).Unit
		local side = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
		local to = from + (dir + side * 0.8).Unit * len * rng:NextNumber(0.15, 0.3)
		local br = channel(from, to, len * 0.04, 3)
		for i = 1, #br - 1 do
			segment(br[i], br[i + 1], 0.4, CORE, 0.25).Parent = m
		end
	end
	return m
end

local function strike(folder, cam)
	local at = folder:GetAttribute("StormAt")
	local back = folder:GetAttribute("StormBack")
	local radius = folder:GetAttribute("StormRadius") or 62
	if typeof(at) ~= "Vector3" or typeof(back) ~= "Vector3" then
		return
	end
	-- a spot in the air past the rim, somewhere around the back half of the peak
	local side = back:Cross(Vector3.yAxis)
	local a = rng:NextNumber(-1.2, 1.2)
	local dir = (back * math.cos(a) + side * math.sin(a)).Unit
	local foot = at + dir * (radius + rng:NextNumber(10, 30)) + Vector3.new(0, rng:NextNumber(-25, -5), 0)
	if not PerfMark.onScreen(cam, foot + Vector3.new(0, 80, 0), 90) then
		return
	end
	local dist = (cam.CFrame.Position - foot).Magnitude
	if dist > Config.STORM_SEE then
		return
	end
	local top = foot + Vector3.new(rng:NextNumber(-40, 40), rng:NextNumber(170, 210), rng:NextNumber(-40, 40))
	local len = (top - foot).Magnitude
	local flickers = rng:NextInteger(Config.STORM_FLICKERS[1], Config.STORM_FLICKERS[2])
	task.spawn(function()
		local light = Instance.new("Part")
		light.Anchored = true
		light.CanCollide = false
		light.CanQuery = false
		light.CanTouch = false
		light.Transparency = 1
		light.Position = foot + Vector3.new(0, 20, 0)
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Color = SHEATH
		pl.Brightness = 0
		pl.Parent = light
		light.Parent = fx
		for f = 1, flickers do
			local m = stroke(top, foot, len)
			m.Parent = fx
			pl.Brightness = f == 1 and 4 or 2.5
			task.wait(0.06)
			m:Destroy()
			pl.Brightness = 0
			if f < flickers then
				task.wait(rng:NextNumber(0.04, 0.08))
			end
		end
		Debris:AddItem(light, 0.1)
	end)
	if dist < Config.STORM_HEAR then
		task.delay(dist / Config.STORM_SOUND_SPEED, function()
			Sfx.play("thunder", { at = foot })
		end)
	end
end

local storms = {} -- [RealmLook folder] = true (only realm 9+ ones carry Storm)
local function track(d)
	if d.Name == "RealmLook" and d:IsA("Folder") then
		storms[d] = true
	end
end
sect.DescendantAdded:Connect(track)
for _, d in sect:GetDescendants() do
	track(d)
end

local nextAt = {} -- [folder] = os.clock() of its next strike
task.spawn(function()
	while true do
		task.wait(0.5)
		local t0 = PerfMark.begin()
		local now = os.clock()
		local cam = workspace.CurrentCamera
		for folder in storms do
			if not folder.Parent then
				storms[folder] = nil
				nextAt[folder] = nil
			elseif folder:GetAttribute("Storm") and cam then
				local at = nextAt[folder]
				if not at then
					nextAt[folder] = now + rng:NextNumber(2, 8)
				elseif now >= at then
					nextAt[folder] = now + rng:NextNumber(Config.STORM_EVERY[1], Config.STORM_EVERY[2])
					strike(folder, cam)
				end
			end
		end
		PerfMark.finish("storm", t0)
	end
end)
