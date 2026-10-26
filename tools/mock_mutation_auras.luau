-- Studio mock (2026-10-26, owner: "Looks cheap no? what about a real aura effect? Research some"): three
-- real aura styles for a weather-mutated disciple, in place of the colour wash, for screenshots only.
-- Research: Sol's RNG never recolours the player; an aura is layers around the body: a glowing pool on
-- the ground, wisps or flames rising round the body, themed things orbiting (stars, embers, blades),
-- more layers the rarer it is. Grow a Garden's mutations glow around the crop (Rainbow adds an arc).
--   A  Sol's RNG layers: pool + rising wisps + the mutation's own orbiters (Dewy droplets, Thunderborn
--      lightning arcs, Bloodlit embers, Starforged stars + a halo)
--   B  Light: the pool and the orbiters only (half the particles, for a full platform on a phone)
--   C  Sigil: our WC3-style rune glyph (Config.AURA_TEX) turning under the seat in the mutation's colour
--      and a column of light rising from it, plus the orbiters
-- Run in Play, in the Server datamodel:
--   local run = <this file>; run(game.ServerScriptService.Server.Cultivators)
-- Builds workspace._AuraMock at y=900: 3 rows (A, B, C) 12 studs apart along +Z x 4 columns (Dewy,
-- Thunderborn, Bloodlit, Starforged) 10 studs apart along +X, the same Elder lotus disciple, labels in
-- front, all facing -Z. The player's avatar is never moved. Remove: workspace._AuraMock:Destroy().
return function(CultivatorsModule)
	local Cultivators = require(CultivatorsModule)
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local RunService = game:GetService("RunService")
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local FIRE = "rbxasset://textures/particles/fire_main.dds"
	local GLOW = "rbxassetid://" .. Config.AURA_TEX.glow
	local GLYPH = "rbxassetid://" .. Config.AURA_TEX.realms[6][1]
	local WHITE = Color3.new(1, 1, 1)

	local old = workspace:FindFirstChild("_AuraMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_AuraMock"
	root.Parent = workspace

	local ORIGIN = CFrame.new(0, 900, 0)
	local GAP, ROW = 10, 12
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(GAP * 5, 1, ROW * 3 + 8)
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromHex("3A3F47")
	floor.CFrame = ORIGIN * CFrame.new(GAP * 1.5, -0.5, ROW)
	floor.Parent = root

	local function anchor(parent, cf, size, name)
		local p = Instance.new("Part")
		p.Name = name or "AuraPart"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = size or Vector3.new(1, 1, 1)
		p.CFrame = cf
		p.Parent = parent
		return p
	end
	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence = 0
		e.LightEmission = 0.6
		e.Brightness = 3
		for k, v in props do
			e[k] = v
		end
		e.Parent = parent
		return e
	end
	local function colors(w)
		if w.motion == "rainbow" then
			local keys = {}
			for i = 0, 6 do
				table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(0.3 + 0.48 * i / 6, 0.6, 1)))
			end
			return ColorSequence.new(keys)
		end
		return ColorSequence.new(w.tint:Lerp(WHITE, 0.35), w.tint)
	end

	-- the glowing pool on the ground (Sol's RNG): flat glow discs breathing under the seat
	local function pool(m, cf, w)
		local p = anchor(m, cf * CFrame.new(0, 0.15, 0), Vector3.new(0.2, 0.2, 0.2), "AuraPool")
		emitter(p, {
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
		})
	end

	-- wisps rising round the body to the waist and above (the ring of flames)
	local RISE = {
		Dewy = { Texture = SMOKE, Size = { 1.2, 2.2 }, Speed = { 2, 3.5 }, Rate = 20, Life = { 1, 1.4 }, Trans = 0.15 },
		Thunderborn = { Texture = SPARKLE, Size = { 0.9, 0 }, Speed = { 5, 8 }, Rate = 26, Life = { 0.3, 0.5 }, Trans = 0 },
		Bloodlit = { Texture = FIRE, Size = { 1.6, 0.4 }, Speed = { 3, 5 }, Rate = 22, Life = { 0.7, 1 }, Trans = 0.2 },
		Starforged = { Texture = SPARKLE, Size = { 0.7, 0 }, Speed = { 2, 3 }, Rate = 18, Life = { 1, 1.5 }, Trans = 0 },
	}
	local function rising(m, cf, w)
		local r = RISE[w.mut]
		local ring = anchor(m, cf * CFrame.new(0, -0.6, 0), Vector3.new(4.2, 0.2, 4.2), "AuraRise") -- from just under the hips
		emitter(ring, {
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
		})
	end

	-- the mutation's own orbiters, on a hub that spins (Heartbeat below)
	local spinners = {}
	local function orb(hub, at, size, color, trail)
		local b = Instance.new("Part")
		b.Name = "Orbiter"
		b.Shape = Enum.PartType.Ball
		b.Material = Enum.Material.Neon
		b.Color = color
		b.Size = Vector3.new(size, size, size)
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Anchored = false
		b.Massless = true
		b.CFrame = hub.CFrame * at
		b.Parent = hub
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1 = hub, b
		wc.Parent = b
		if trail then
			emitter(b, trail)
		end
		return b
	end
	-- cf here is at the hips (look.apply); `head` = the top of the head above it
	local function orbiters(m, cf, w, head)
		if w.mut == "Thunderborn" then
			-- short jagged arcs jumping round the body, a new pair every 0.15-0.35 s
			task.spawn(function()
				while m.Parent do
					for _ = 1, 3 do
						local a = math.random() * math.pi * 2
						local from = cf * CFrame.new(math.cos(a) * 1.6, -0.6 + math.random() * 2.8, math.sin(a) * 1.6)
						local b2 = a + (math.random() - 0.5) * 1.8
						local to = cf * CFrame.new(math.cos(b2) * 2.1, -0.6 + math.random() * 3, math.sin(b2) * 2.1)
						local last = from.Position
						for i = 1, 4 do
							local nextAt = from.Position:Lerp(to.Position, i / 4) + (i < 4 and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.7 or Vector3.zero)
							local seg = anchor(m, CFrame.lookAt((last + nextAt) / 2, nextAt), Vector3.new(0.2, 0.2, (nextAt - last).Magnitude), "Arc")
							seg.Transparency = 0
							seg.Material = Enum.Material.Neon
							seg.Color = w.tint:Lerp(WHITE, 0.4)
							task.delay(0.12, function()
								seg:Destroy()
							end)
							last = nextAt
						end
					end
					task.wait(0.15 + math.random() * 0.2)
				end
			end)
			return
		end
		local hub = anchor(m, cf * CFrame.new(0, 0, 0), Vector3.new(0.2, 0.2, 0.2), "OrbitHub")
		local n, rad, y, size, speed = 4, 2.4, 0.8, 0.5, 1.2
		if w.mut == "Bloodlit" then
			n, rad, y, size, speed = 6, 2.2, 0, 0.42, -0.8
		elseif w.mut == "Starforged" then
			n, rad, y, size, speed = 5, 1.9, head - 1, 0.45, 1.8
		end
		for i = 1, n do
			local a = i / n * math.pi * 2
			local c = w.motion == "rainbow" and Color3.fromHSV(0.3 + 0.48 * i / n, 0.6, 1) or w.tint:Lerp(WHITE, 0.3)
			orb(hub, CFrame.new(math.cos(a) * rad, y + (w.mut == "Bloodlit" and (i % 2) * 1.6 or 0), math.sin(a) * rad), size, c, {
				Texture = w.mut == "Bloodlit" and FIRE or SPARKLE,
				Rate = 24, -- a trail behind each as it circles
				Lifetime = NumberRange.new(0.6, 0.9),
				Speed = NumberRange.new(0.2),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 2.6), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(c),
			})
		end
		if w.mut == "Starforged" then -- a halo arc over the head (Grow a Garden's Rainbow arc)
			for i = 1, 16 do
				local a = i / 16 * math.pi * 2
				local seg = anchor(m, cf * CFrame.new(math.cos(a) * 1, head + 0.5, math.sin(a) * 1) * CFrame.Angles(0, -a, 0), Vector3.new(0.16, 0.16, 0.46), "Halo")
				seg.Transparency = 0
				seg.Material = Enum.Material.Neon
				seg.Color = Color3.fromHSV(0.3 + 0.48 * i / 16, 0.55, 1)
			end
		end
		table.insert(spinners, { hub = hub, base = hub.CFrame, speed = speed })
	end

	-- C: the rune glyph turning flat under the seat and a column of light rising from it
	local function sigil(m, cf, w)
		local p = anchor(m, cf * CFrame.new(0, 0.12, 0), Vector3.new(0.2, 0.2, 0.2), "AuraSigil")
		emitter(p, {
			Texture = GLYPH,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01),
			Rate = 1.2,
			Lifetime = NumberRange.new(2.5),
			Size = NumberSequence.new(6.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(25),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.15), NumberSequenceKeypoint.new(0.75, 0.15), NumberSequenceKeypoint.new(1, 1) }),
			Color = colors(w),
			LightEmission = 0.7,
		})
		local col = anchor(m, cf * CFrame.new(0, 0.3, 0), Vector3.new(3, 0.2, 3), "AuraColumn")
		emitter(col, {
			Texture = SPARKLE,
			Shape = Enum.ParticleEmitterShape.Disc,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(0, 0),
			Speed = NumberRange.new(6, 9),
			Rate = 32,
			Lifetime = NumberRange.new(0.8, 1.1),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) }),
			Squash = NumberSequence.new(2.5), -- tall streaks (as the rain)
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Color = colors(w),
		})
	end

	local looks = {
		{ text = "A Sol's RNG", apply = function(m, cf, hips, head, w)
			pool(m, cf, w)
			rising(m, hips, w)
			orbiters(m, hips, w, head)
		end },
		{ text = "B Light", apply = function(m, cf, hips, head, w)
			pool(m, cf, w)
			orbiters(m, hips, w, head)
		end },
		{ text = "C Sigil", apply = function(m, cf, hips, head, w)
			sigil(m, cf, w)
			orbiters(m, hips, w, head)
		end },
	}

	local function label(cf, text)
		local lab = anchor(root, cf, Vector3.new(7, 1.2, 0.2), "Label")
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.Parent = lab
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = WHITE
		t.TextStrokeTransparency = 0
		t.Text = text
		t.Parent = g
	end

	local elder = Config.rarity("Elder")
	for r, look in looks do
		for c, w in Config.WEATHERS do
			local cf = ORIGIN * CFrame.new((c - 1) * GAP, 0, (r - 1) * ROW)
			local m = Cultivators.build(root, cf, "lotus", elder, Config.RARITIES)
			-- the real platform figure keeps its rarity rim (no wash): only the aura is new.
			-- CultivatorIdle switches far figures' emitters off: force them on for the captures on the client
			-- the seated figure floats ~2 studs over its cushion (Studio check 2026-10-26): the rising layer and
			-- the orbiters go round the body, from its hips; the pool and the sigil stay on the cushion
			task.spawn(function()
				local avatar = m:WaitForChild("Avatar", 10)
				local torso = avatar and (avatar:FindFirstChild("UpperTorso") or avatar.PrimaryPart)
				local headPart = avatar and avatar:FindFirstChild("Head")
				local hipY = torso and (torso.Position.Y - cf.Y - 1) or 2
				local headY = headPart and (headPart.Position.Y + headPart.Size.Y / 2 - cf.Y - hipY) or 4
				look.apply(m, cf, cf * CFrame.new(0, hipY, 0), headY, w)
			end)
			label(cf * CFrame.new(0, 0.6, -4.5), (c == 1 and look.text .. " · " or "") .. w.mut)
		end
	end

	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		for _, s in spinners do
			if s.hub.Parent then
				s.hub.CFrame = s.base * CFrame.Angles(0, t * s.speed, 0)
			end
		end
	end)
	return root
end
