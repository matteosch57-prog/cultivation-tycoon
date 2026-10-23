-- Studio mock (2026-10-23, owner: "we need some real better sword, so we can sell 3 levels, the trail
-- and aura getting better" + "aura only on sword i meant tho"): the Flying Sword in three tiers built
-- from real Creator Store assets (shortlist _shop_ideas/sword/shortlist.md, coordinator picks), for
-- screenshots only. The aura glows on the BLADE, never on the rider.
--
--   tier  sword (shortlist id)                    trail texture (image id)          blade aura from
--   1     1Sa Jian 74897223654299 (2,399 tris)    1Ta wind2 -> 4537267850           1Aa POF:RE Lunar Flames 8517247103
--   2     2Sa Heavenly sword 13467141475 (1,576)  2Ta skill wind blue 2 -> 6480618759  2Aa Golden Crown Aura 17781650714
--   3     3Sc crystal sword 5131677948 (2,408)    3Ta Unicorns Light Energy -> 94214927232934  blade-only Sapphire Sparkle 154741609 (was 3Aa 80960525975597: a floor swirl)
--
-- STEP 1, Edit mode (the Studio session, once): put the six assets in ServerStorage._SwordAssets as
-- S1 S2 S3 (swords) and A1 A2 A3 (auras), every script deleted (R12). Either insert each id with the
-- Studio MCP insert_asset tool / the Toolbox and rename + move it, or paste this in the command bar
-- (Edit, not Play; GetObjects loads public Creator Store models in Studio):
--[[
local SS = game:GetService("ServerStorage")
local box = SS:FindFirstChild("_SwordAssets") or Instance.new("Folder")
box.Name = "_SwordAssets"
box.Parent = SS
for name, id in { S1 = 74897223654299, S2 = 13467141475, S3 = 5131677948, A1 = 8517247103, A2 = 17781650714, A3 = 154741609 } do
	local old = box:FindFirstChild(name)
	if old then old:Destroy() end
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and objs[1] then
		local m = Instance.new("Model")
		m.Name = name
		for _, o in objs do o.Parent = m end
		for _, d in m:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ModuleScript") then d:Destroy() end
		end
		m.Parent = box
		print("[SwordMock] loaded", name, id, #m:GetDescendants(), "instances")
	else
		warn("[SwordMock] could not load", name, id, objs)
	end
end
]]
-- Do NOT save the place with _SwordAssets in it (Ctrl+S is Matteo's, R5); delete the folder after.
--
-- STEP 2, Play, in the Server datamodel, with a player spawned:
--   local run = <this file>; run()
-- Builds workspace._SwordMock high in the sky away from every pad: ORIGIN (400, 900, 0), the three
-- tiers 16 studs apart along +X, each sword ~11 studs long lying flat (edge forward, nose to -Z), a
-- clone of the first player's avatar standing on it a little leaned, a motion trail (Beams streaming
-- 14 / 18 / 22 studs back from the hilt, wider and brighter each tier), the blade aura (the aura
-- asset's ParticleEmitters / Beams / lights re-parented to Attachments spread along the blade and
-- scaled to it) and a name card over each. The player's own avatar is never moved.
-- FLIP[tier] = true turns a sword whose hilt landed at the nose. Capture: camera (424, 906, 26)
-- looking at (416, 900, 2) shows all three from the front-side; (416, 920, 0) -> (416, 900, 0) from above.
-- v4 (owner "could be more premium still, try"): mock-drawn layers per tier on the blade, see premium().
-- Remove: workspace._SwordMock:Destroy().
return function()
	local Players = game:GetService("Players")
	local ServerStorage = game:GetService("ServerStorage")
	local assets = ServerStorage:FindFirstChild("_SwordAssets")
	assert(assets, "[SwordMock] run step 1 first: ServerStorage._SwordAssets is missing")

	local ORIGIN = CFrame.new(400, 900, 0)
	local LENGTH = 11 -- studs, every blade (TIERS[i].length overrides)
	local FLIP = { false, false, true } -- Studio 2026-10-23: the crystal sword landed hilt forward
	local TIERS = {
		{ name = "Jade Jian 199", length = 12.5, glow = 0.6, alpha = 0.15, trail = 4537267850, back = 14, width = 2.2, light = 0.55, color = Color3.fromHex("8FF5D0"), points = 4, size = 0.35, rate = 0.6 },
		{ name = "Heavenly Sword 399", glow = 0.75, alpha = 0.25, trail = 6480618759, back = 18, width = 3, light = 0.75, color = Color3.fromHex("FFD34D"), points = 6, size = 0.45, rate = 0.85 },
		{ name = "Celestial Crystal Sword 1,199", glow = 0.7, alpha = 0.45, trail = 94214927232934, back = 22, width = 3.4, light = 0.6, color = Color3.fromHex("9FD8FF"), points = 8, size = 0.55, rate = 1.1 },
	}

	local old = workspace:FindFirstChild("_SwordMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_SwordMock"
	root.Parent = workspace

	local function anchorAll(m)
		for _, d in m:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ModuleScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	end

	-- The sword laid flat: longest box axis along -Z (the nose), thinnest axis up (the flat of the
	-- blade faces the sky, the edge cuts forward), scaled to LENGTH, its box centred on `at`.
	local function laySword(src, at, flip, length)
		local m = Instance.new("Model")
		m.Name = "Sword"
		for _, c in src:GetChildren() do
			c:Clone().Parent = m
		end
		anchorAll(m)
		m.Parent = root
		local box, size = m:GetBoundingBox()
		local axes = { { box.RightVector, size.X }, { box.UpVector, size.Y }, { box.LookVector, size.Z } }
		table.sort(axes, function(a, b)
			return a[2] > b[2]
		end)
		local long, mid, thin = axes[1][1], axes[2][1], axes[3][1]
		-- the hilt end: the guard is the part widest across the blade; the hilt is on its side
		local centre = box.Position
		local guardAt, widest = nil, -1
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local w = math.abs(p.CFrame:VectorToObjectSpace(mid).X * p.Size.X) + math.abs(p.CFrame:VectorToObjectSpace(mid).Y * p.Size.Y) + math.abs(p.CFrame:VectorToObjectSpace(mid).Z * p.Size.Z)
				if w > widest then
					widest, guardAt = w, p.Position
				end
			end
		end
		local hiltSign = (guardAt and (guardAt - centre):Dot(long) > 0) and 1 or -1
		if flip then
			hiltSign = -hiltSign
		end
		-- current frame of the blade: Z back toward the hilt (+Z = hilt), Y = thin axis up
		local back = long * hiltSign
		local up = thin
		local right = up:Cross(back).Unit
		-- the pivot becomes the blade's own frame (box centre), so scaling keeps it centred and the
		-- bounding box below is measured in `at`'s axes
		m.WorldPivot = CFrame.fromMatrix(centre, right, up, back)
		m:ScaleTo((length or LENGTH) / axes[1][2])
		m:PivotTo(at)
		local _, size2 = m:GetBoundingBox()
		return m, size2 -- in `at`'s frame: X width, Y thickness, Z length (hilt at +Z)
	end

	local function attach(parent, cf)
		local a = Instance.new("Attachment")
		a.Parent = parent -- parent first: WorldCFrame on a loose attachment is read as its local CFrame
		a.WorldCFrame = cf
		return a
	end

	-- an invisible anchor part for attachments, beams and the name card
	local function anchor(cf)
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = cf
		p.Parent = root
		return p
	end

	-- the rider: a clone of the first player's own avatar, standing on the blade a little leaned, its
	-- feet put on the blade top from its bounding box (the real avatar is never touched)
	local source = Players:GetPlayers()[1]
	local function rider(cf)
		local char = source and source.Character
		if not char then
			warn("[SwordMock] no character to clone: spawn first")
			return
		end
		char.Archivable = true
		local rig = char:Clone()
		for _, d in rig:GetDescendants() do
			if d:IsA("ForceField") then
				d:Destroy()
			end
		end
		anchorAll(rig)
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		rig.Name = "Rider"
		rig.Parent = root
		rig:PivotTo(cf * CFrame.Angles(math.rad(-6), 0, 0))
		local box, size = rig:GetBoundingBox()
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, cf.Position.Y - (box.Position.Y - size.Y / 2), 0))
	end

	-- the motion trail: two crossed Beams (flat and upright, so it reads from the side and from
	-- above) from the hilt streaming `back` studs behind, fading out
	local function trail(cf, t)
		local holder = anchor(cf)
		local a0 = attach(holder, cf * CFrame.new(0, 0, 0))
		local a1 = attach(holder, cf * CFrame.new(0, 0, t.back))
		for k, roll in { 0, 90 } do
			local b0 = attach(holder, a0.WorldCFrame * CFrame.Angles(0, 0, math.rad(roll)))
			local b1 = attach(holder, a1.WorldCFrame * CFrame.Angles(0, 0, math.rad(roll)))
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = b0, b1
			b.Texture = "rbxassetid://" .. t.trail
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureSpeed = 1.2
			b.FaceCamera = false
			b.Segments = 12
			b.Width0 = t.width * (k == 1 and 1 or 0.7)
			b.Width1 = t.width * 0.25
			b.LightEmission = t.light
			b.LightInfluence = 0
			b.Brightness = 1 + t.light * 0.5
			b.Color = ColorSequence.new(Color3.new(1, 1, 1), t.color)
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t.alpha), NumberSequenceKeypoint.new(0.6, 0.5 + t.alpha / 2), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = holder
		end
	end

	-- scaled by k and capped at `cap` studs, so no emitter grows past the blade
	local function scaleSeq(seq, k, cap)
		local kps = {}
		for _, kp in seq.Keypoints do
			local v = math.min(kp.Value * k, cap or math.huge)
			table.insert(kps, NumberSequenceKeypoint.new(kp.Time, v, math.min(kp.Envelope * k, v)))
		end
		return NumberSequence.new(kps)
	end

	-- the blade aura: every ParticleEmitter of the aura asset copied onto `points` attachments along
	-- the blade (sizes and speeds scaled to a blade, the total rate kept near the asset's own x
	-- t.rate), locked to the blade so the glow hugs it; its Beams run hilt to tip; its lights sit at
	-- the blade's middle. An asset with no emitters gets a plain glow in the tier colour.
	local function aura(src, cf, size, t)
		local holder = anchor(cf)
		local points = {}
		for i = 1, t.points do
			local z = (i - 0.5) / t.points * size.Z - size.Z / 2
			table.insert(points, attach(holder, cf * CFrame.new(0, size.Y * 0.5, z)))
		end
		local emitters, beams, lights = {}, {}, {}
		for _, d in src:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				table.insert(emitters, d)
			elseif d:IsA("Beam") then
				table.insert(beams, d)
			elseif d:IsA("Light") then
				table.insert(lights, d)
			end
		end
		if #emitters == 0 then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = 20
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(0.3, 0.8)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
			e.Color = ColorSequence.new(t.color)
			e.LightEmission = 1
			table.insert(emitters, e)
		end
		for _, e in emitters do
			for _, a in points do
				local c = e:Clone()
				c.Size = scaleSeq(e.Size, t.size, math.max(size.X, 1) * 1.2)
				c.Speed = NumberRange.new(math.min(e.Speed.Min * t.size, 1), math.min(e.Speed.Max * t.size, 2))
				c.Lifetime = NumberRange.new(math.min(e.Lifetime.Min, 1), math.min(e.Lifetime.Max, 1.2))
				c.Orientation = Enum.ParticleOrientation.FacingCamera -- flat ground rings never lie on the floor
				c.Rate = math.max(1, e.Rate * t.rate / #points)
				c.LockedToPart = true
				c.Enabled = true
				c.Parent = a
			end
		end
		for _, b in beams do
			if b.Width0 * t.size > size.X * 2 then
				continue -- a wide aura Beam is a floor ring, not a blade glow
			end
			local c = b:Clone()
			c.Attachment0, c.Attachment1 = points[1], points[#points]
			c.Width0 = b.Width0 * t.size
			c.Width1 = b.Width1 * t.size
			c.Parent = holder
		end
		for _, l in lights do
			local c = l:Clone()
			c.Parent = points[math.ceil(#points / 2)]
		end
	end

	-- v4 "more premium" (owner 2026-10-23: "could be more premium still, try"): layers drawn on the
	-- blade by the mock itself, on top of the asset aura, each tier clearly richer than the last:
	--   1 jade: one jade qi ribbon wound round the blade, a soft under-glow, fine jade motes
	--   2 gold: two gold ribbons (a double helix), a shimmer running hilt to tip, gold sparkles and a
	--     second, ember-gold trail layer
	--   3 celestial: three ribbons (white, sky, gold), a vertical halo ring behind the hilt, orbiting
	--     star twinkles, a wide soft cloud trail under the bright one, sparks shed into the trail
	-- Nothing touches the rider: every layer hangs off the blade (owner: "aura only on sword").
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local function beam(holder, a0, a1, color, w0, w1, emission, alpha)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.FaceCamera = true
		b.Segments = 4
		b.Width0, b.Width1 = w0, w1 or w0
		b.LightEmission = emission or 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new(alpha or 0.15)
		b.Parent = holder
		return b
	end
	-- a ribbon wound `turns` times round the blade from hilt to tip, `steps` straight beams long; it
	-- thins toward the tip
	local function ribbon(holder, cf, size, color, turns, phase, radius, width)
		local steps = 28
		local prev
		for k = 0, steps do
			local f = k / steps
			local a = phase + f * turns * math.pi * 2
			local z = size.Z / 2 - f * size.Z
			local at = attach(holder, cf * CFrame.new(math.cos(a) * radius, size.Y / 2 + math.sin(a) * radius * 0.6 + radius * 0.4, z))
			if prev then
				beam(holder, prev, at, color, width * (1 - f * 0.6), width * (1 - (f + 1 / steps) * 0.6), 1, 0.1)
			end
			prev = at
		end
	end
	local function motes(att, color, rate, size, speed, life)
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARKLE
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = rate
		e.Lifetime = NumberRange.new(life or 0.6, (life or 0.6) * 1.6)
		e.Speed = NumberRange.new(speed or 0.2, (speed or 0.2) * 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.1)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LockedToPart = true
		e.Parent = att
		return e
	end
	local function premium(i, cf, size, t)
		local holder = anchor(cf)
		local hilt = attach(holder, cf * CFrame.new(0, size.Y / 2, size.Z / 2))
		local tip = attach(holder, cf * CFrame.new(0, size.Y / 2, -size.Z / 2))
		-- under-glow: a soft flat band of the tier colour just under the blade
		local u0 = attach(holder, cf * CFrame.new(0, -size.Y, size.Z / 2))
		local u1 = attach(holder, cf * CFrame.new(0, -size.Y, -size.Z / 2))
		local under = beam(holder, u0, u1, t.color, size.X * (1.6 + i * 0.4), size.X * 0.8, 1, 0.55)
		under.FaceCamera = false
		-- the ribbons
		local RIBBONS = {
			{ { t.color, 1.5, 0 } },
			{ { Color3.fromHex("FFE9A0"), 2, 0 }, { Color3.fromHex("FFB52E"), 2, math.pi } },
			{ { Color3.new(1, 1, 1), 2.5, 0 }, { Color3.fromHex("8FD3FF"), 2.5, math.pi * 2 / 3 }, { Color3.fromHex("FFD34D"), 2.5, math.pi * 4 / 3 } },
		}
		for _, r in RIBBONS[i] do
			ribbon(holder, cf, size, r[1], r[2], r[3], math.max(size.X * 0.45, 0.35), 0.12 + i * 0.03)
		end
		-- motes along the blade
		for k = 1, 3 + i do
			local z = size.Z / 2 - (k - 0.5) / (3 + i) * size.Z
			local a = attach(holder, cf * CFrame.new(0, size.Y / 2 + 0.2, z))
			motes(a, i == 3 and Color3.fromHex("DFF3FF") or t.color, 2 + i * 2, 0.18 + i * 0.08)
		end
		if i >= 2 then
			-- a shimmer running hilt to tip over the blade
			local sh = beam(holder, hilt, tip, Color3.new(1, 1, 1), size.X * 0.9, size.X * 0.3, 1, 0)
			sh.Texture = "rbxassetid://" .. t.trail
			sh.TextureMode = Enum.TextureMode.Stretch
			sh.TextureSpeed = 2.5
			sh.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.8) })
			-- a second trail layer, ember gold (2) or a wide soft cloud (3), under the bright one
			local back = attach(holder, cf * CFrame.new(0, -0.3, size.Z / 2 + t.back * 0.85))
			local base = attach(holder, cf * CFrame.new(0, -0.3, size.Z / 2))
			local soft = beam(holder, base, back, i == 2 and Color3.fromHex("FF9A2E") or Color3.fromHex("CFE9FF"), t.width * (i == 2 and 1.3 or 2), t.width * 0.4, i == 2 and 0.8 or 0.5, 0)
			soft.FaceCamera = false
			soft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			-- sparks shed off the hilt into the trail
			local s = motes(hilt, i == 2 and Color3.fromHex("FFD34D") or Color3.new(1, 1, 1), 10 + i * 6, 0.25, 4, 0.8)
			s.EmissionDirection = Enum.NormalId.Back
			s.SpreadAngle = Vector2.new(20, 20)
			s.LockedToPart = false
			s.Drag = 2
		end
		if i == 3 then
			-- a vertical halo ring behind the hilt, facing forward
			local ring, r, n = {}, 1.9, 24
			local c = cf * CFrame.new(0, size.Y / 2 + 2.6, size.Z / 2 + 0.8)
			for k = 0, n do
				local a = k / n * math.pi * 2
				ring[k] = attach(holder, c * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0))
				if k > 0 then
					beam(holder, ring[k - 1], ring[k], Color3.fromHex("FFE38A"), 0.16, 0.16, 1, 0.05)
				end
			end
			motes(attach(holder, c), Color3.fromHex("FFF4C2"), 6, 0.5, 0.4, 1.2)
			-- star twinkles orbiting the blade (a ring of emitters at the blade's middle)
			for k = 1, 6 do
				local a = k / 6 * math.pi * 2
				local at = attach(holder, cf * CFrame.new(math.cos(a) * size.X * 1.6, size.Y / 2 + math.sin(a) * 0.8, (k - 3.5) * size.Z / 7))
				motes(at, Color3.fromHex("FFFFFF"), 3, 0.45, 0.1, 1)
			end
		end
	end

	-- a floating name over each sword
	local function sign(text, cf)
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(300, 46)
		g.AlwaysOnTop = true
		g.Parent = anchor(cf)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0
		l.Text = text
		l.Parent = g
	end

	for i, t in TIERS do
		local cf = ORIGIN * CFrame.new((i - 2) * 16, 0, 0)
		local s, a = assets:FindFirstChild("S" .. i), assets:FindFirstChild("A" .. i)
		if not s then
			warn("[SwordMock] missing S" .. i)
			continue
		end
		local sword, size = laySword(s, cf, FLIP[i], t.length)
		-- the blade edge glow in the tier colour, so a slim blade still reads at distance
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = t.color, t.color
		h.FillTransparency = t.glow
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = sword
		local top = cf * CFrame.new(0, size.Y / 2, 0)
		rider(top * CFrame.new(0, 0, 0.5))
		trail(cf * CFrame.new(0, 0, size.Z / 2), t)
		if a then
			aura(a, cf, size, t)
		else
			warn("[SwordMock] missing A" .. i)
		end
		premium(i, cf, size, t)
		sign(t.name, cf * CFrame.new(0, 9, 0))
		print(string.format("[SwordMock] tier %d: blade %.1f x %.2f x %.1f studs", i, size.X, size.Y, size.Z))
	end
	return root
end
