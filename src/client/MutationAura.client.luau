-- A weather-mutated disciple's aura (owner 2026-10-26: "Looks cheap no? what about a real aura effect?
-- Research some"; mock tools/mock_mutation_auras.luau). Research: Sol's RNG never recolours the player,
-- an aura is layers round the body: a glowing pool on the ground, flames or wisps rising round it, and
-- themed things orbiting; Grow a Garden's mutations glow round the crop. Each mutation its own:
--   Dewy         blue pool, mist rising, water droplets circling
--   Thunderborn  yellow pool, sparks rising, lightning arcs jumping round the body
--   Bloodlit     red pool, flames rising, embers circling both ways
--   Starforged   pool, stars rising and circling the head, a halo over it (green to violet, Config.mutLook)
-- The server only sets the figure's Mutation attribute (Main mutationGlow); this draws on each client
-- from the posed figure (CultivatorIdle lifts and poses it: the server's figure sits ~1.85 studs lower)
-- into its own folder, outside CultivatorIdle's layer budget, under a budget of its own: the nearest
-- AURA_N mutated figures within AURA_R studs draw it, the rest none. The figure's own white rarity orbs
-- are dimmed so the mutation's orbiters read over them.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PerfScene = require(Shared:WaitForChild("PerfScene"))

local TAG = "Cultivator"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local GLOW = "rbxassetid://" .. Config.AURA_TEX.glow
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2
-- [phone or low graphics] = { auras drawn at once, studs }
local BUDGET = { [true] = { n = 6, r = 60 }, [false] = { n = 14, r = 90 } }
local ORB_DIM = 0.6 -- LocalTransparencyModifier of a mutated figure's own white AuraOrbs

local folder = Instance.new("Folder")
folder.Name = "MutationAuras"
folder.Parent = workspace

local auras = {} -- [model] = aura

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	e.LightEmission = 0.6
	e.Brightness = 3
	e.Enabled = false
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end
-- the mutation's colours: its tint, or green to violet for Starforged (Config.mutLook's range)
local function colorAt(w, k)
	if w.motion == "rainbow" then
		return Color3.fromHSV(0.3 + 0.48 * k, 0.6, 1)
	end
	return w.tint:Lerp(WHITE, 0.3)
end
local function colors(w)
	if w.motion == "rainbow" then
		local keys = {}
		for i = 0, 6 do
			table.insert(keys, ColorSequenceKeypoint.new(i / 6, colorAt(w, i / 6)))
		end
		return ColorSequence.new(keys)
	end
	return ColorSequence.new(w.tint:Lerp(WHITE, 0.35), w.tint)
end

-- the rising layer of each mutation (the Sol's RNG ring of flames), from just under the hips
local RISE = {
	Dewy = { Texture = SMOKE, Size = { 1.2, 2.2 }, Speed = { 2, 3.5 }, Rate = 20, Life = { 1, 1.4 }, Trans = 0.15 },
	Thunderborn = { Texture = SPARKLE, Size = { 0.9, 0 }, Speed = { 5, 8 }, Rate = 26, Life = { 0.3, 0.5 }, Trans = 0 },
	Bloodlit = { Texture = FIRE, Size = { 1.6, 0.4 }, Speed = { 3, 5 }, Rate = 22, Life = { 0.7, 1 }, Trans = 0.2 },
	Starforged = { Texture = SPARKLE, Size = { 0.7, 0 }, Speed = { 2, 3 }, Rate = 18, Life = { 1, 1.5 }, Trans = 0 },
}
-- the orbiters: count, radius, height over the hips ("head" = from the top of the head), size, turns/s
local ORBIT = {
	Dewy = { n = 4, rad = 2.4, y = 0.8, size = 0.5, speed = 1.2 },
	Bloodlit = { n = 6, rad = 2.2, y = 0, size = 0.42, speed = -0.8, step = 1.6 },
	Starforged = { n = 5, rad = 1.9, head = -1, size = 0.45, speed = 1.8 },
}

local function build(m, w)
	local avatar = m:WaitForChild("Avatar", 10)
	local torso = avatar and avatar:WaitForChild("UpperTorso", 10)
	local head = avatar and avatar:WaitForChild("Head", 10)
	local seat = m:FindFirstChild("Cushion") or m.PrimaryPart
	if not torso or not head or not seat or not m.Parent then
		return
	end
	local a = { model = m, w = w, torso = torso, head = head, emitters = {}, orbs = {}, halo = {}, on = false, angle = math.random() * TAU }
	a.folder = Instance.new("Folder")
	a.folder.Name = m.Name
	a.folder.Parent = folder
	-- the pool: flat glow discs breathing on the cushion
	local pool = part(a.folder, { CFrame = CFrame.new(seat.Position + Vector3.new(0, seat.Size.Y / 2 + 0.1, 0)) })
	table.insert(a.emitters, emitter(pool, {
		Texture = GLOW,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Rate = 3,
		Lifetime = NumberRange.new(1.6, 2),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 7.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Color = colors(w),
		LightEmission = 0.8,
	}))
	-- the rising ring, moved with the hips every frame
	local r = RISE[w.mut]
	a.rise = part(a.folder, { Size = Vector3.new(4.2, 0.2, 4.2) })
	table.insert(a.emitters, emitter(a.rise, {
		Texture = r.Texture,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NumberRange.new(r.Speed[1], r.Speed[2]),
		Rate = r.Rate,
		Lifetime = NumberRange.new(r.Life[1], r.Life[2]),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r.Size[1]), NumberSequenceKeypoint.new(1, r.Size[2]) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, r.Trans), NumberSequenceKeypoint.new(0.7, r.Trans + 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Color = colors(w),
	}))
	-- the orbiters, each with a trail of its sparks (Thunderborn has arcs instead, in the loop below)
	local o = ORBIT[w.mut]
	if o then
		a.orbit = o
		for i = 1, o.n do
			local c = colorAt(w, i / o.n)
			local b = part(a.folder, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = c, Size = Vector3.new(o.size, o.size, o.size) })
			table.insert(a.orbs, b)
			table.insert(a.emitters, emitter(b, {
				Texture = w.mut == "Bloodlit" and FIRE or SPARKLE,
				Rate = 24,
				Lifetime = NumberRange.new(0.6, 0.9),
				Speed = NumberRange.new(0.2),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size * 2.6), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(c),
			}))
		end
	end
	if w.mut == "Starforged" then -- a halo over the head (Grow a Garden's Rainbow arc)
		for i = 1, 16 do
			table.insert(a.halo, part(a.folder, { Material = Enum.Material.Neon, Color = colorAt(w, i / 16), Size = Vector3.new(0.16, 0.16, 0.46) }))
		end
	end
	-- the figure's own white rarity orbs step back
	a.dimmed = {}
	for _, p in m:GetChildren() do
		if p.Name == "AuraOrb" and p:IsA("BasePart") then
			table.insert(a.dimmed, p)
		end
	end
	auras[m] = a
end

local function drop(m)
	local a = auras[m]
	if a then
		auras[m] = nil
		a.folder:Destroy()
		for _, p in a.dimmed do
			p.LocalTransparencyModifier = 0
		end
	end
end

local function watch(m)
	local function check()
		local w = Config.mutation(m:GetAttribute("Mutation"))
		if auras[m] and (not w or auras[m].w ~= w) then
			drop(m)
		end
		if w and not auras[m] then
			task.spawn(build, m, w)
		end
	end
	m:GetAttributeChangedSignal("Mutation"):Connect(check)
	check()
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(drop)
for _, m in CollectionService:GetTagged(TAG) do
	task.spawn(watch, m)
end

local function setOn(a, on)
	if a.on == on then
		return
	end
	a.on = on
	for _, e in a.emitters do
		e.Enabled = on
		if not on then
			e:Clear()
		end
	end
	for _, p in a.orbs do
		p.Transparency = on and 0 or 1
	end
	for _, p in a.halo do
		p.Transparency = on and 0 or 1
	end
	for _, p in a.dimmed do
		p.LocalTransparencyModifier = on and ORB_DIM or 0
	end
end

-- every 0.5 s: the nearest mutated figures in range draw their aura
task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		if cam then
			local q = UserSettings().GameSettings.SavedQualityLevel.Value -- 0 = automatic
			local b = BUDGET[PerfScene.device() ~= "pc" or (q > 0 and q <= 4)]
			local eye = cam.CFrame.Position
			local list = {}
			for m, a in auras do
				if m.Parent and a.torso.Parent then
					a.dist = (a.torso.Position - eye).Magnitude
					table.insert(list, a)
				else
					drop(m)
				end
			end
			table.sort(list, function(x, y)
				return x.dist < y.dist
			end)
			for i, a in list do
				setOn(a, i <= b.n and a.dist < b.r)
			end
		end
	end
end)

-- a Thunderborn's lightning: short jagged Neon arcs jumping round the body
local function arc(a)
	local hips = a.torso.Position - Vector3.new(0, a.torso.Size.Y / 2 + 0.4, 0)
	local t1 = math.random() * TAU
	local t2 = t1 + (math.random() - 0.5) * 1.8
	local from = hips + Vector3.new(math.cos(t1) * 1.6, math.random() * 2.8, math.sin(t1) * 1.6)
	local to = hips + Vector3.new(math.cos(t2) * 2.1, math.random() * 3, math.sin(t2) * 2.1)
	local color = a.w.tint:Lerp(WHITE, 0.4)
	local segs = {}
	local last = from
	for i = 1, 4 do
		local nextAt = from:Lerp(to, i / 4) + (i < 4 and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.7 or Vector3.zero)
		table.insert(segs, part(a.folder, { Material = Enum.Material.Neon, Color = color, Transparency = 0, Size = Vector3.new(0.2, 0.2, (nextAt - last).Magnitude), CFrame = CFrame.lookAt((last + nextAt) / 2, nextAt) }))
		last = nextAt
	end
	task.delay(0.18, function()
		for _, s in segs do
			s:Destroy()
		end
	end)
end

-- every frame, the drawn auras follow their posed figure: the rising ring at the hips, the orbiters
-- round the body or the head, the halo over it; Thunderborn arcs every 0.15-0.35 s
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for _, a in auras do
		if a.on and a.torso.Parent then
			local hips = a.torso.Position - Vector3.new(0, a.torso.Size.Y / 2 + 0.4, 0)
			local top = a.head.Position.Y + a.head.Size.Y / 2
			a.rise.CFrame = CFrame.new(hips - Vector3.new(0, 0.2, 0))
			local o = a.orbit
			if o then
				a.angle += dt * o.speed
				local y = o.head and top + o.head or hips.Y + o.y
				for i, b in a.orbs do
					local t = a.angle + i / o.n * TAU
					b.CFrame = CFrame.new(hips.X + math.cos(t) * o.rad, y + (o.step and (i % 2) * o.step or 0), hips.Z + math.sin(t) * o.rad)
				end
			end
			for i, s in a.halo do
				local t = i / #a.halo * TAU
				s.CFrame = CFrame.new(a.head.Position.X + math.cos(t), top + 0.5, a.head.Position.Z + math.sin(t)) * CFrame.Angles(0, -t, 0)
			end
			if a.w.mut == "Thunderborn" and now >= (a.nextArc or 0) then
				a.nextArc = now + 0.15 + math.random() * 0.2
				for _ = 1, 3 do
					arc(a)
				end
			end
		end
	end
end)
