-- Studio mock (2026-10-23, owner: "flying sword could be funny too. mock those 4"): the Flying Sword
-- ride and the +2 Disciple Seats in the 3D world, for screenshots only. Run in Play, in the Server
-- datamodel:
--   local run = <this file>; run(game.ServerScriptService.Server.Cultivators)
-- v2: riders are clones of the first player's own avatar (v1 plain R15 rigs drew as black blocks).
-- Builds workspace._ShopMock high in the sky away from every pad (x = 200, y = 900):
--   Row 1 (z = 0), three swords 14 studs apart along +X, a stand-in avatar riding each, nose to -Z:
--     A  Jade Jian: slim steel blade, gold guard, a jade qi streak behind it
--     B  Golden Blade: wide gold blade, warm qi flames trailing off the back
--     C  Cloud Sword: steel blade riding on a small white cloud
--   Row 2 (z = 24), three seated Lotus Elders 8 studs apart: "Seat" (as now), then two "+2 Seats"
--     with a gold lotus ring and gold motes under the cushion (the paid seats)
-- A label in front of each. The player's own avatar is never moved. Remove: workspace._ShopMock:Destroy().
return function(CultivatorsModule)
	local Cultivators = require(CultivatorsModule)
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local Players = game:GetService("Players")
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local GOLD = Color3.fromHex("FFD34D")
	local JADE = Color3.fromHex("6FF0C0")
	local STEEL = Color3.fromHex("E4FBFF")

	local old = workspace:FindFirstChild("_ShopMock")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "_ShopMock"
	root.Parent = workspace
	local ORIGIN = CFrame.new(200, 900, 0)

	local function part(parent, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		return p
	end
	local function label(text, cf)
		local lab = part(root, Vector3.new(6, 1.2, 0.2), cf, Color3.new(), nil)
		lab.Transparency = 1
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.Parent = lab
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = text
		t.Parent = g
	end
	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARKLE
		e.LightEmission = 1
		for k, v in props do
			e[k] = v
		end
		e.Parent = parent
		return e
	end
	-- a qi streak: a Beam from the sword's tail back along +Z
	local function streak(parent, at, color, width, len)
		local a0 = Instance.new("Attachment")
		a0.Parent = parent
		a0.WorldCFrame = at
		local a1 = Instance.new("Attachment")
		a1.Parent = parent
		a1.WorldCFrame = at * CFrame.new(0, 0, len)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = width, 0
		b.FaceCamera = true
		b.LightEmission = 1
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = parent
		return a0
	end
	-- the rider: a clone of the first player's own avatar (real clothes and hair), standing on the blade,
	-- leaned a little into the flight; its feet are put on the blade from its bounding box
	local source = Players:GetPlayers()[1]
	local function rider(cf)
		local char = source and source.Character
		if not char then
			return
		end
		char.Archivable = true
		local rig = char:Clone()
		for _, d in rig:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("ForceField") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		rig.Name = "Rider"
		rig.Parent = root
		rig:PivotTo(cf * CFrame.Angles(math.rad(-6), 0, 0))
		local box, size = rig:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		rig:PivotTo(rig:GetPivot() + Vector3.new(0, cf.Position.Y - bottom, 0))
	end
	-- a floating name over each sword (a BillboardGui reads at any distance)
	local function sign(text, cf)
		local a = part(root, Vector3.new(0.2, 0.2, 0.2), cf, Color3.new(), nil)
		a.Transparency = 1
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(220, 46)
		g.AlwaysOnTop = true
		g.Parent = a
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = text
		t.Parent = g
	end

	-- Row 1: the swords (nose to -Z, the camera looks at their side from +X or front from -Z)
	local SWORDS = { -- blades 1.6x the first mock (they read as toothpicks under a full avatar)
		{ text = "A  Jade Jian", build = function(m, cf)
			part(m, Vector3.new(1.6, 0.35, 11), cf, STEEL, Enum.Material.Metal)
			part(m, Vector3.new(0.8, 0.36, 2), cf * CFrame.new(0, 0, -6.2), STEEL, Enum.Material.Metal) -- the tip
			part(m, Vector3.new(4.2, 0.6, 0.8), cf * CFrame.new(0, 0, 5.8), GOLD, Enum.Material.Metal) -- guard
			part(m, Vector3.new(0.6, 0.6, 2.6), cf * CFrame.new(0, 0, 7.4), Color3.fromHex("8E1F1A")) -- grip
			part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 0, 8.9), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
			local glow = part(m, Vector3.new(0.45, 0.12, 10.6), cf * CFrame.new(0, 0.2, 0), JADE, Enum.Material.Neon)
			glow.Transparency = 0.35
			local a = streak(glow, cf * CFrame.new(0, 0, 9), JADE, 2.4, 16)
			emitter(a, { Rate = 18, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Back, Color = ColorSequence.new(JADE), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
		end },
		{ text = "B  Golden Blade", build = function(m, cf)
			part(m, Vector3.new(2.6, 0.4, 11.5), cf, GOLD, Enum.Material.Metal)
			part(m, Vector3.new(1.3, 0.41, 2.2), cf * CFrame.new(0, 0, -6.6), GOLD, Enum.Material.Metal)
			part(m, Vector3.new(4.8, 0.8, 0.9), cf * CFrame.new(0, 0, 6.1), Color3.fromHex("B23A2C"), Enum.Material.Metal)
			part(m, Vector3.new(0.7, 0.7, 2.6), cf * CFrame.new(0, 0, 7.8), Color3.fromHex("3A2A14"))
			local a = streak(m:FindFirstChildWhichIsA("BasePart"), cf * CFrame.new(0, 0, 9.2), Color3.fromHex("FFB347"), 3, 14)
			local fire = Instance.new("Fire")
			fire.Color = Color3.fromHex("FFB347")
			fire.SecondaryColor = GOLD
			fire.Size = 3
			fire.Heat = 2
			fire.Parent = a.Parent
			emitter(a, { Rate = 22, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1.5, 3), EmissionDirection = Enum.NormalId.Back, Color = ColorSequence.new(GOLD), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }) })
		end },
		{ text = "C  Cloud Sword", build = function(m, cf)
			part(m, Vector3.new(1.6, 0.35, 11), cf, STEEL, Enum.Material.Metal)
			part(m, Vector3.new(0.8, 0.36, 2), cf * CFrame.new(0, 0, -6.2), STEEL, Enum.Material.Metal)
			part(m, Vector3.new(4.2, 0.6, 0.8), cf * CFrame.new(0, 0, 5.8), GOLD, Enum.Material.Metal)
			for i, o in { { -2.6, 3.2 }, { 0, 4 }, { 2.6, 3.4 }, { 1.2, 2.8 }, { -1.2, 3 } } do
				local c = part(m, Vector3.new(o[2], o[2] * 0.6, o[2]), cf * CFrame.new(o[1] * 0.7, -1.3, o[1] * 1.3), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				c.Transparency = 0.15 + i * 0.03
			end
			emitter(m:FindFirstChildWhichIsA("BasePart"), { Rate = 10, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1), Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }) })
		end },
	}
	for i, s in SWORDS do
		local cf = ORIGIN * CFrame.new((i - 1) * 14, 0, 0)
		local m = Instance.new("Model")
		m.Name = "Sword" .. i
		m.Parent = root
		s.build(m, cf)
		rider(cf * CFrame.new(0, 0.15, -0.5))
		sign(s.text, cf * CFrame.new(0, 8, 0))
	end

	-- Row 2: the seats (Lotus Elders; the two paid seats get a gold lotus ring)
	local floor = part(root, Vector3.new(30, 1, 14), ORIGIN * CFrame.new(8, -0.5, 24), Color3.fromHex("3A3F47"), Enum.Material.Slate)
	floor.CanCollide = true
	local elder = Config.rarity("Elder")
	for i, text in { "Seat", "+2 Seats", "+2 Seats" } do
		local cf = ORIGIN * CFrame.new(i * 8 - 8, 0, 24)
		Cultivators.build(root, cf, "lotus", elder, Config.RARITIES)
		if i > 1 then
			local ring = part(root, Vector3.new(0.2, 5.6, 5.6), cf * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.25
			local inner = part(root, Vector3.new(0.22, 4.8, 4.8), cf * CFrame.new(0, 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("3A3F47"), Enum.Material.Slate, Enum.PartType.Cylinder)
			inner.Transparency = 0
			for k = 0, 7 do -- eight gold petals around the ring
				local a = k / 8 * math.pi * 2
				local p = part(root, Vector3.new(0.9, 0.2, 1.6), cf * CFrame.new(math.cos(a) * 3.3, 0.12, math.sin(a) * 3.3) * CFrame.Angles(0, -a + math.pi / 2, 0), GOLD, Enum.Material.Metal)
				p.Transparency = 0.05
			end
			emitter(ring, { Rate = 6, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.6, 1.2), EmissionDirection = Enum.NormalId.Right, Color = ColorSequence.new(GOLD), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }) })
		end
		label(text, cf * CFrame.new(0, 0.6, -4))
	end
	return root
end
