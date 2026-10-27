-- What each realm from 6 on shows around its peak (ROADMAP M3, research 2026-10-21_reincarnation_design
-- section 4). Cumulative inside a life: realm 8 also has the realm 6 clouds and the realm 7 rocks.
--   6 Void Refinement: clouds hug the rim, tinted with the realm colour
--   7 Body Integration: floating rocks ring the peak
--   8 Mahayana: a second waterfall
--   9 Tribulation Transcendence: lightning strikes past the rim (RealmLook.client draws it)
--  10+ True Immortal: a halo over the Main Hall; its colour climbs the rarity ladder each realm
-- Colours: Config.realmTint. Phone budget (R16): blocks only (12 triangles each), particle
-- clouds the size of the cloud sea's, nothing moves on the server. No fake light (R3): the halo is
-- gold metal lit by the sun; the lightning is a short event flash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Style = require(script.Parent:WaitForChild("Style"))
local RelicHall = require(script.Parent:WaitForChild("RelicHall"))

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

-- a floating chunk of island: rock blocks narrowing downward, a cap in the lawn's colour (the Sect
-- Style ground, else grass: a green cap over a styled peak read as a stray island, owner 2026-10-27)
local function floatingRock(parent, cf, size, rng, cap)
	local m = Instance.new("Model")
	m.Name = "Rock"
	ghost(P(m, Vector3.new(size * 1.1, size * 0.22, size), cf * CFrame.new(0, size * 0.11, 0), cap))
	for k = 0, 2 do
		local s = size * (0.95 - k * 0.27)
		local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
		ghost(P(m, Vector3.new(s, size * 0.38, s * 0.9), cf * CFrame.new(0, -size * (0.12 + k * 0.3), 0) * tilt, k == 0 and PAL.dirt or PAL.rock:Lerp(Color3.new(0, 0, 0), k * 0.15)))
	end
	m.Parent = parent
	return m
end

-- every piece of land a rock must keep clear of (peak frame x, z, r): the islets and all their lobes
-- (bought or not), the Relic Terrace and the shop island. The rocks once stood 16-28 studs past the
-- heart rim all round, from before the islets: they poked out of the Fields and Dao islets and the
-- bridges (owner 2026-10-27: "weird islands").
local function land()
	local list = {}
	for _, i in Config.ISLETS do
		table.insert(list, { i.x, i.z, i.r })
	end
	for _, l in Config.ISLAND_LOBES do
		table.insert(list, { l.x, l.z, l.r })
	end
	table.insert(list, { RelicHall.ISLE.X, RelicHall.ISLE.Z, RelicHall.ISLE_R })
	table.insert(list, { Config.SHOP_ISLAND_AT.X, Config.SHOP_ISLAND_AT.Z, Config.SHOP_ISLAND_RADIUS })
	return list
end

-- how far (x, z) lies from the nearest bridge line, heart rim to the hub (+Z) or to the shop island
local function bridgeGap(x, z, radius)
	local best = math.huge
	for _, to in { Vector2.new(0, radius + 200), Vector2.new(Config.SHOP_ISLAND_AT.X, Config.SHOP_ISLAND_AT.Z) } do
		local d = to.Unit
		local t = math.clamp(x * d.X + z * d.Y, 0, to.Magnitude)
		best = math.min(best, (Vector2.new(x, z) - d * t).Magnitude)
	end
	return best
end

local ROCKS = 7
local function rocks(parent, frame, radius, seed, cap)
	local rng = Random.new(seed)
	local lands, placed = land(), {}
	for _ = 1, 200 do
		if #placed >= ROCKS then
			break
		end
		local size = rng:NextNumber(10, 16)
		local a = rng:NextNumber(0, math.pi * 2)
		local r = radius + rng:NextNumber(24, 42)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local ok = bridgeGap(x, z, radius) > size + 10
		for _, l in lands do
			ok = ok and math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) - l[3] > size + 10
		end
		for _, q in placed do
			ok = ok and (q - Vector2.new(x, z)).Magnitude > size * 2 + 8
		end
		if ok then
			table.insert(placed, Vector2.new(x, z))
			local cf = frame * CFrame.new(x, rng:NextNumber(4, 22), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			floatingRock(parent, cf, size, rng, cap)
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
	-- 6: three clouds hugging the rim under the lawn, tinted with the realm colour. Their crowns rise
	-- ~0.53 x width over the base (Style.softCloud layers + particle size), so the base sits that far
	-- down: at -14 they billowed 25+ studs over the lawn and the bridges as fog (owner 2026-10-27)
	local width = radius * 1.1
	for i = 0, 2 do
		local a = math.pi / 2 + math.pi * (0.62 + i * 0.38) -- left, back and right of the peak
		local r = radius * 0.95
		local y = -(width * 0.53 + 6) - i % 2 * 6
		tintedCloud(f, frame * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -a, 0), width, plot.index * 13 + i, tint, Config.REALM_TINT_CLOUD)
	end
	if realm >= 7 then
		rocks(f, frame, radius, plot.index * 31, plot.styleGround and plot.styleGround[2] or PAL.grass)
	end
	if realm >= 8 then
		Style.waterfall(f, frame, radius, Config.REALM_FALL_ANGLE)
	end
	if realm >= 9 then
		-- lightning only (owner pick B: two particle hazes and a puff cloud all read wrong).
		-- RealmLook.client strikes the air just past the rim, around the back of the peak.
		f:SetAttribute("Storm", true)
		f:SetAttribute("StormAt", frame.Position)
		f:SetAttribute("StormBack", frame.LookVector) -- the back of the peak (frame +Z faces the hub)
		f:SetAttribute("StormRadius", radius)
	end
	if realm >= 10 then
		halo(f, frame, tint)
	end
	f.Parent = plot.folder
	plot.look = f
end

return RealmLook
