-- Studio mock (2026-10-23, owner: "we need some real better sword, so we can sell 3 levels, the trail
-- and aura getting better" + "aura only on sword i meant tho"): the Flying Sword in three tiers built
-- from real Creator Store assets (shortlist _shop_ideas/sword/shortlist.md, coordinator picks), for
-- screenshots only. The aura glows on the BLADE, never on the rider.
--
--   tier  sword (shortlist id)                    trail texture (image id)          blade aura from
--   1     1Sa Jian 74897223654299 (2,399 tris)    1Ta wind2 -> 4537267850           1Aa POF:RE Lunar Flames 8517247103
--   2     2Sa Heavenly sword 13467141475 (1,576)  2Ta skill wind blue 2 -> 6480618759  2Aa Golden Crown Aura 17781650714
--   3     3Sc crystal sword 5131677948 (2,408)    3Ta Unicorns Light Energy -> 94214927232934  3Aa "the aura" 80960525975597
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
for name, id in { S1 = 74897223654299, S2 = 13467141475, S3 = 5131677948, A1 = 8517247103, A2 = 17781650714, A3 = 80960525975597 } do
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
-- Remove: workspace._SwordMock:Destroy().
return function()
	local Players = game:GetService("Players")
	local ServerStorage = game:GetService("ServerStorage")
	local assets = ServerStorage:FindFirstChild("_SwordAssets")
	assert(assets, "[SwordMock] run step 1 first: ServerStorage._SwordAssets is missing")

	local ORIGIN = CFrame.new(400, 900, 0)
	local LENGTH = 11 -- studs, every blade
	local FLIP = { false, false, false }
	local TIERS = {
		{ name = "Jade Jian 199", trail = 4537267850, back = 14, width = 2.2, light = 0.55, color = Color3.fromHex("8FF5D0"), points = 4, size = 0.35, rate = 0.6 },
		{ name = "Heavenly Sword 399", trail = 6480618759, back = 18, width = 3, light = 0.75, color = Color3.fromHex("FFD34D"), points = 6, size = 0.45, rate = 0.85 },
		{ name = "Celestial Crystal Sword 1,199", trail = 94214927232934, back = 22, width = 4, light = 1, color = Color3.fromHex("9FD8FF"), points = 8, size = 0.55, rate = 1.1 },
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
	local function laySword(src, at, flip)
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
		m:ScaleTo(LENGTH / axes[1][2])
		m:PivotTo(at)
		local _, size2 = m:GetBoundingBox()
		return m, size2 -- in `at`'s frame: X width, Y thickness, Z length (hilt at +Z)
	end

	local function attach(parent, cf)
		local a = Instance.new("Attachment")
		a.WorldCFrame = cf
		a.Parent = parent
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
			b.Brightness = 1 + t.light
			b.Color = ColorSequence.new(Color3.new(1, 1, 1), t.color)
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = holder
		end
	end

	local function scaleSeq(seq, k)
		local kps = {}
		for _, kp in seq.Keypoints do
			table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
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
				c.Size = scaleSeq(e.Size, t.size)
				c.Speed = NumberRange.new(e.Speed.Min * t.size, e.Speed.Max * t.size)
				c.Rate = math.max(1, e.Rate * t.rate / #points)
				c.LockedToPart = true
				c.Enabled = true
				c.Parent = a
			end
		end
		for _, b in beams do
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
		local _, size = laySword(s, cf, FLIP[i])
		local top = cf * CFrame.new(0, size.Y / 2, 0)
		rider(top * CFrame.new(0, 0, 0.5))
		trail(cf * CFrame.new(0, 0, size.Z / 2), t)
		if a then
			aura(a, cf, size, t)
		else
			warn("[SwordMock] missing A" .. i)
		end
		sign(t.name, cf * CFrame.new(0, 9, 0))
		print(string.format("[SwordMock] tier %d: blade %.1f x %.2f x %.1f studs", i, size.X, size.Y, size.Z))
	end
	return root
end
