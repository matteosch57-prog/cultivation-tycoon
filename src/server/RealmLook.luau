-- What each realm from 6 on shows around its peak (ROADMAP M3, research 2026-10-21_reincarnation_design
-- section 4). Cumulative inside a life: realm 8 also has the realm 6 clouds and the realm 7 rocks.
--   6 Void Refinement: clouds hug the rim, tinted with the realm colour
--   7 Body Integration: floating rocks ring the peak
--   8 Mahayana: a second waterfall
--   9 Tribulation Transcendence: a storm cloud over the peak (RealmLook.client draws its lightning)
--  10+ True Immortal: a halo over the Main Hall; its colour climbs the rarity ladder each realm
-- Colours: Config.realmTint. Phone budget (R16): blocks only (12 triangles each), particle
-- clouds the size of the cloud sea's, nothing moves on the server. No fake light (R3): the halo is
-- gold metal lit by the sun; the storm's flashes are short event flashes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))

local RealmLook = {}

local P = Style.P
local PAL = Style.PAL

local function ghost(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- a soft particle cloud recoloured toward `tint` (k = how far)
local function tintedCloud(parent, cf, width, seed, tint, k)
	local m = Style.softCloud(parent, cf, width, seed)
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local kp = d.Color.Keypoints
			d.Color = ColorSequence.new(kp[1].Value:Lerp(tint, k), kp[#kp].Value:Lerp(tint, k * 0.8))
		end
	end
	return m
end

-- a floating chunk of island: rock blocks narrowing downward, a grass cap
local function floatingRock(parent, cf, size, rng)
	local m = Instance.new("Model")
	m.Name = "Rock"
	ghost(P(m, Vector3.new(size * 1.1, size * 0.22, size), cf * CFrame.new(0, size * 0.11, 0), PAL.grass))
	for k = 0, 2 do
		local s = size * (0.95 - k * 0.27)
		local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
		ghost(P(m, Vector3.new(s, size * 0.38, s * 0.9), cf * CFrame.new(0, -size * (0.12 + k * 0.3), 0) * tilt, k == 0 and PAL.dirt or PAL.rock:Lerp(Color3.new(0, 0, 0), k * 0.15)))
	end
	m.Parent = parent
	return m
end

local function rocks(parent, frame, radius, seed)
	local rng = Random.new(seed)
	local n = 7
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		-- keep the bridges (front, +Z) and the shop side clear: skip the front sixth
		if math.abs(math.atan2(math.sin(a - math.pi / 2), math.cos(a - math.pi / 2))) > 0.55 then
			local r = radius + rng:NextNumber(16, 28)
			local cf = frame * CFrame.new(math.cos(a) * r, rng:NextNumber(4, 22), math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			floatingRock(parent, cf, rng:NextNumber(10, 16), rng)
		end
	end
end

local function halo(parent, frame, tint)
	local m = Instance.new("Model")
	m.Name = "Halo"
	-- over the Main Hall (pad spot 0, -30), tipped toward the bridge so it reads from the entrance
	local centre = frame * CFrame.new(0, 46, -30) * CFrame.Angles(math.rad(70), 0, 0)
	local R, n = 18, 28
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local seg = 2 * math.pi * R / n + 0.4
		local p = P(m, Vector3.new(seg, 2.2, 3), centre * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -R), tint, Enum.Material.Foil)
		ghost(p).CastShadow = false
	end
	-- slow motes falling from the ring (not light: LightEmission 0)
	local box = ghost(P(m, Vector3.new(R * 2, 1, R * 2), centre, tint))
	box.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(tint)
	pe.LightEmission = 0
	pe.LightInfluence = 1
	pe.Size = NumberSequence.new(0.6, 0)
	pe.Lifetime = NumberRange.new(4, 6)
	pe.Speed = NumberRange.new(0.5, 1)
	pe.Acceleration = Vector3.new(0, -1, 0)
	pe.Rate = 3
	pe.Parent = box
	m.Parent = parent
	return m
end

-- (Re)builds `plot.look` for plot.realm at plot.radius; nothing happens when neither changed.
function RealmLook.apply(plot)
	local realm, radius = plot.realm or 0, plot.radius or Config.ISLAND_RADIUS
	local key = realm .. "/" .. radius
	if plot.lookKey == key then
		return
	end
	plot.lookKey = key
	if plot.look then
		plot.look:Destroy()
		plot.look = nil
	end
	if realm < Config.REALM_LOOK_FROM then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "RealmLook"
	f:SetAttribute("Realm", realm)
	local frame = plot.frame
	local tint = Config.realmTint(realm)
	-- 6: three clouds hugging the rim just under the lawn, tinted with the realm colour
	for i = 0, 2 do
		local a = math.pi / 2 + math.pi * (0.62 + i * 0.38) -- left, back and right of the peak
		local r = radius * 0.95
		tintedCloud(f, frame * CFrame.new(math.cos(a) * r, -14 - i % 2 * 6, math.sin(a) * r) * CFrame.Angles(0, -a, 0), radius * 1.1, plot.index * 13 + i, tint, Config.REALM_TINT_CLOUD)
	end
	if realm >= 7 then
		rocks(f, frame, radius, plot.index * 31)
	end
	if realm >= 8 then
		Style.waterfall(f, frame, radius, Config.REALM_FALL_ANGLE)
	end
	if realm >= 9 then
		-- the storm sits behind the hall so it never hides the peak from the entrance camera
		local storm = tintedCloud(f, frame * CFrame.new(0, 58, -radius * 0.55), radius * 2, plot.index * 17, Config.REALM_STORM, 0.7)
		storm.Name = "Storm"
		f:SetAttribute("Storm", true)
	end
	if realm >= 10 then
		halo(f, frame, tint)
	end
	f.Parent = plot.folder
	plot.look = f
end

return RealmLook
