-- Seated cultivators for the Meditation Platform: real Roblox R15 avatars built from a
-- HumanoidDescription (catalog hanfu, hair, beard), posed cross-legged and anchored. The client
-- breathes them (CultivatorIdle.client.luau): no animation upload needed.
-- Four looks (sword disciple, lotus maiden, pill monk, elder sage); the rarity picks the robe colour
-- and the aura tier. Front faces -Z (LookVector). `cf` is the ground point under the cushion.
-- Auras are layered glowing objects only (particles, beams, trails with built-in textures, so
-- nothing to upload): no Light instances (RULES R3). One layer joins per rarity; rates stay low and the
-- client switches the layers off beyond a short range, so a full platform stays cheap on phones.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Cultivators = {}

Cultivators.TAG = "Cultivator"
Cultivators.LOOKS = { "sword", "lotus", "monk", "elder" }

local SKIN = Color3.fromRGB(238, 204, 176)
local CUSHION = Color3.fromHex("B8352B"):Lerp(Color3.new(0, 0, 0), 0.3)
local TEX = "rbxasset://textures/particles/"
local SPARKLE = TEX .. "sparkles_main.dds"
local VORTEX = TEX .. "forcefield_vortex_main.dds"
local RING = TEX .. "explosion01_shockwave_main.dds"
local GLOW = TEX .. "forcefield_glow_main.dds"
local WHITE = Color3.new(1, 1, 1)
local SEAT = 1.8 -- cushion top above the ground

-- Catalog layered clothing (any experience may dress an NPC in it). Index = rarity tier 1..9:
-- white, green, blue, purple, gold, celestial teal, dao crimson, emperor red-gold, primordial white
-- (its aura cycles every colour); each tier lists its layers, robe
-- first. Creator: Lucky Koi unless noted. Checked as captures, since a dark robe hides the rarity.
local SHIRT, DRESS, JACKET = Enum.AccessoryType.Shirt, Enum.AccessoryType.DressSkirt, Enum.AccessoryType.Jacket
local AZURE = { 94369290663213, JACKET } -- Mint Blue Azure Breeze Hanfu (Japan Kimono)
local RED_CLOAK = { 115620162427301, JACKET } -- Traditional Chinese Red Hanfu Cloak (RUYI)
local WHITE_CLOAK = { 72012744074825, JACKET } -- Traditional Chinese White Hanfu Cloak (RUYI)
local ROBES = {
	male = {
		{ { 79303524577143, SHIRT } }, -- Male Long Robe Hanfu-White
		{ { 100632011366877, SHIRT } }, -- Male Wuxia Hanfu-Green (the long robe green read black)
		{ { 138259484709999, SHIRT } }, -- Male Wuxia Hanfu-Blue (the long robe blue read black)
		{ { 88444695833424, SHIRT } }, -- Male Long Robe Hanfu-Purple
		{ { 113946197012814, SHIRT } }, -- Male Wuxia Hanfu-Gold
		{ AZURE },
		{ { 131611803410283, SHIRT }, RED_CLOAK }, -- Male Long Robe Hanfu-Black Red under the red cloak
		{ { 113946197012814, SHIRT }, RED_CLOAK }, -- Male Wuxia Hanfu-Gold under the red cloak
		{ { 135966334457234, SHIRT }, WHITE_CLOAK }, -- Male Wuxia Hanfu-White Gold Dragon under the white cloak
	},
	female = {
		{ { 12388422808, DRESS } }, -- White Cultivator's Robes (Nexus Exchange)
		{ { 76684958127170, DRESS } }, -- Flowing Cloud Hanfu Robe-Green
		{ { 124497512666896, DRESS } }, -- Empress Hanfu Robe - Sapphire
		{ { 136565350420707, DRESS } }, -- Hanfu-Inspired Imperial Gown-Purple
		{ { 124671367097250, DRESS } }, -- Flowing Cloud Hanfu Robe-Gold
		{ AZURE },
		{ { 106614697052382, DRESS }, RED_CLOAK }, -- Empress Hanfu Robe - Garnet under the red cloak
		{ { 72320280506296, DRESS } }, -- Chang'e's Moon Palace Flowing Hanfu-Amber
		{ { 80805967098465, DRESS }, WHITE_CLOAK }, -- Chang'e's Moon Palace Flowing Hanfu-Creamy under the white cloak
	},
}

local LOOK = {
	sword = { robes = "male", hair = { 101082692371776 } }, -- Xianxia Low Ponytail - Black
	lotus = { robes = "female", hair = { 113503254025840 } }, -- Hair buns with Hairpins - Black
	monk = { robes = "male", hair = {}, hat = { 12136449552 } }, -- shaved head, a strategist's moustache so it reads as a face (Nexus Exchange)
	elder = { robes = "male", hair = { 89557677054617 }, face = { 123149555491840 } }, -- Imperial Crown Hair-White, white beard
}

-- joint rotations of the cross-legged pose, applied in each joint's parent attachment frame
local POSE = {
	-- thighs forward and out, shins folded back across under the other knee (a level swing)
	LeftHip = CFrame.Angles(0, math.rad(50), 0) * CFrame.Angles(math.rad(90), 0, 0),
	RightHip = CFrame.Angles(0, math.rad(-50), 0) * CFrame.Angles(math.rad(90), 0, 0),
	LeftKnee = CFrame.Angles(0, 0, math.rad(140)),
	RightKnee = CFrame.Angles(0, 0, math.rad(-140)),
	-- upper arms hang a little forward and out, forearms reach the knees
	LeftShoulder = CFrame.Angles(math.rad(15), 0, math.rad(-10)),
	RightShoulder = CFrame.Angles(math.rad(15), 0, math.rad(10)),
	LeftElbow = CFrame.Angles(math.rad(35), 0, 0),
	RightElbow = CFrame.Angles(math.rad(35), 0, 0),
}

local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- tier 1..5 from the rarity's place in Config.RARITIES
local function tierOf(rarity, rarities)
	for i, r in rarities do
		if r.name == rarity.name then
			return i
		end
	end
	return 1
end

local function describe(look, tier)
	local spec = LOOK[look]
	local d = Instance.new("HumanoidDescription")
	for _, k in { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" } do
		d[k] = SKIN
	end
	-- one list for layered and rigid accessories (SetAccessories with `true` replaces both)
	local list = {}
	for i, layer in ROBES[spec.robes][tier] do
		table.insert(list, { AssetId = layer[1], AccessoryType = layer[2], IsLayered = true, Order = i })
	end
	for _, id in spec.hair do
		table.insert(list, { AssetId = id, AccessoryType = Enum.AccessoryType.Hair, IsLayered = false })
	end
	for _, id in spec.hat or {} do
		table.insert(list, { AssetId = id, AccessoryType = Enum.AccessoryType.Hat, IsLayered = false })
	end
	for _, id in spec.face or {} do
		table.insert(list, { AssetId = id, AccessoryType = Enum.AccessoryType.Face, IsLayered = false })
	end
	d:SetAccessories(list, true)
	return d
end

-- the CFrame that joint `j` puts its child part at, given the parent part's CFrame
local function jointChild(j, parentCf, rot)
	if j:IsA("JointInstance") then
		return parentCf * j.C0 * rot * j.C1:Inverse()
	end
	return parentCf * j.Attachment0.CFrame * rot * j.Attachment1.CFrame:Inverse()
end

local function jointParts(j)
	if j:IsA("JointInstance") then
		return j.Part0, j.Part1
	end
	local a0, a1 = j.Attachment0, j.Attachment1
	return a0 and a0.Parent, a1 and a1.Parent
end

-- Pose the rig by walking its joint graph from the root: compute every part's target CFrame
-- first, then disable the joints and anchor (new rigs have AnimationConstraints, not Motor6Ds).
local function pose(m)
	local root = m:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, j in m:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("AnimationConstraint") or j:IsA("RigidConstraint") then
			local a, b = jointParts(j)
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				table.insert(joints, { j = j, a = a, b = b })
			end
		end
	end
	local at = { [root] = root.CFrame }
	local placed = true
	while placed do
		placed = false
		for _, e in joints do
			if at[e.a] and not at[e.b] then
				at[e.b] = jointChild(e.j, at[e.a], POSE[e.j.Name] or CFrame.identity)
				placed = true
			elseif at[e.b] and not at[e.a] then
				-- accessory welds run Handle -> body part: place the handle from the body
				local j = e.j
				at[e.a] = j:IsA("JointInstance") and at[e.b] * j.C1 * j.C0:Inverse() or at[e.b] * j.Attachment1.CFrame * j.Attachment0.CFrame:Inverse()
				placed = true
			end
		end
	end
	for _, e in joints do
		e.j.Enabled = false
	end
	for p, cf in at do
		p.Anchored = true
		p.CFrame = cf
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
end

-- posed templates, one per look and tier, built once per server and cloned
local templates, pending = {}, {}

local function template(look, tier)
	local key = look .. tier
	if templates[key] then
		return templates[key]
	end
	if pending[key] then
		table.insert(pending[key], coroutine.running())
		return coroutine.yield()
	end
	pending[key] = {}
	local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, describe(look, tier), Enum.HumanoidRigType.R15)
	if ok then
		local hum = m:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		m:PivotTo(CFrame.identity)
		pose(m)
		-- sit the lowest point of the folded legs on the cushion
		local low = math.huge
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Handle" then
				low = math.min(low, p.Position.Y - p.Size.Y / 2)
			end
		end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame += Vector3.new(0, SEAT - low - 0.4, 0)
			end
		end
		templates[key] = m
	else
		warn("[Cultivators] avatar build failed", look, tier, m)
		m = nil
	end
	local waiting = pending[key]
	pending[key] = nil
	for _, co in waiting do
		task.spawn(co, m)
	end
	return m
end

local function seq(c)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(1, c:Lerp(WHITE, 0.6)) })
end

local function fade(peak)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, peak), NumberSequenceKeypoint.new(0.75, peak), NumberSequenceKeypoint.new(1, 1) })
end

local function emitter(att, name, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.LightEmission = 1
	pe.LightInfluence = 0
	for k, v in props do
		pe[k] = v
	end
	pe.Parent = att
	return pe
end

local function attach(core, f, offset, name)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = core.CFrame:ToObjectSpace(f * offset)
	a.Parent = core
	return a
end

-- Aura layers, one more per rarity tier (research 2026-10-21: premium Roblox auras stack several
-- soft layers at low rates, with colour that brightens toward white, rather than one loud effect):
--   2 a turning qi sigil on the ground      3 rising motes             4 a halo ring behind the head
--   5 three qi orbs with trails             6 a second, wider sigil     7 an outer halo ring
--   8 a ring pulse on each breath           9 every colour in turn (client)
-- Orbs: 3 / 5 / 7 / 7 / 9 from tier 5. Flames and beam ribbons were tried and dropped (2026-10-21):
-- flames hid inside the avatar and the ribbons read as faint white arcs over the bright sky.
local function aura(m, f, color, tier)
	if tier < 2 then
		return
	end
	local core = P(m, Vector3.new(3.4, 0.2, 3.4), f * CFrame.new(0, 1.2, 0), color)
	core.Transparency = 1
	core.Name = "Aura"
	local ground = attach(core, f, CFrame.new(0, 0.15, 0), "Ground")
	-- motes and flames rise from a ring around the figure: an emitter on an attachment emits from a
	-- single point, inside the body, where the avatar hides every particle
	local shell = P(m, Vector3.new(4.4, 0.2, 4.4), f * CFrame.new(0, 1.3, 0), color)
	shell.Transparency = 1
	shell.Name = "AuraShell"
	emitter(ground, "Sigil", {
		Texture = VORTEX,
		Color = seq(color),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		Size = NumberSequence.new(4.6 + tier * 0.25),
		Transparency = fade(0.15),
		Lifetime = NumberRange.new(4),
		Rate = 0.75,
		RotSpeed = NumberRange.new(25),
		Rotation = NumberRange.new(0, 360),
		ZOffset = 0.5, -- toward the camera, so the floor never hides it
	})
	if tier >= 3 then
		emitter(shell, "Motes", {
			Texture = SPARKLE,
			Color = seq(color),
			Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35 + tier * 0.05), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.1),
			Lifetime = NumberRange.new(2.5, 3.5),
			Speed = NumberRange.new(0.8, 1.4),
			Drag = 0.6,
			Acceleration = Vector3.new(0, 0.5, 0),
			SpreadAngle = Vector2.new(15, 15),
			Rate = 3 + tier,
		})
	end
	if tier >= 4 then
		local head = attach(core, f, CFrame.new(0, 5.15, 0.75), "HaloAt")
		emitter(head, "Halo", {
			Texture = RING,
			Color = seq(color),
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Size = NumberSequence.new(2.6),
			Transparency = fade(0.25),
			Lifetime = NumberRange.new(3),
			Rate = 0.67,
			ZOffset = -2,
		})
		emitter(head, "HaloGlow", {
			Texture = GLOW,
			Color = seq(color),
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Size = NumberSequence.new(2.2),
			Transparency = fade(0.7),
			Lifetime = NumberRange.new(3),
			Rate = 0.67,
			ZOffset = -2.5,
		})
	end
	if tier >= 6 then
		-- a second sigil turning the other way, a ring wider than the first
		emitter(ground, "Sigil2", {
			Texture = RING,
			Color = seq(color),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01),
			Size = NumberSequence.new(7.5),
			Transparency = fade(0.3),
			Lifetime = NumberRange.new(4),
			Rate = 0.75,
			RotSpeed = NumberRange.new(-18),
			Rotation = NumberRange.new(0, 360),
			ZOffset = 0.5,
		})
	end
	if tier >= 7 then
		-- an outer halo ring around the first
		emitter(m.Aura.HaloAt, "Halo2", {
			Texture = RING,
			Color = seq(color),
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Size = NumberSequence.new(3.8),
			Transparency = fade(0.45),
			Lifetime = NumberRange.new(3),
			Rate = 0.67,
			RotSpeed = NumberRange.new(30),
			ZOffset = -2,
		})
	end
	if tier >= 8 then
		emitter(ground, "Pulse", {
			Texture = RING,
			Color = seq(color),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.01),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.6),
			Rate = 0, -- the client emits one on each in-breath
		})
	end
	if tier >= 5 then
		local count = ({ 3, 5, 7, 7, 9 })[tier - 4]
		for i = 0, count - 1 do
			local a = math.rad(90 + i * 360 / count)
			local orb = P(m, Vector3.new(0.4, 0.4, 0.4), f * CFrame.new(math.cos(a) * 2.8, 3.3 + (i % 2) * 0.5, math.sin(a) * 2.8), color, Enum.Material.Neon, Enum.PartType.Ball)
			orb.Name = "QiOrb" -- chest height and clear of the head, so no orb crosses the face
			local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
			t0.Position, t1.Position = Vector3.new(0, 0.15, 0), Vector3.new(0, -0.15, 0)
			t0.Parent, t1.Parent = orb, orb
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = t0, t1
			trail.Color = seq(color)
			trail.LightEmission = 1
			trail.Lifetime = 0.5
			trail.Transparency = NumberSequence.new(0.3, 1)
			trail.WidthScale = NumberSequence.new(1, 0)
			trail.FaceCamera = true
			trail.Parent = orb
		end
	end
	if tier >= 9 then
		m:SetAttribute("Prismatic", true)
	end
end

-- Build one cultivator. look: one of LOOKS (or an index), rarity: a Config.RARITIES entry.
-- Returns the model at once (cushion + aura); the avatar arrives a moment later, once its
-- catalog assets load, unless the model was destroyed meanwhile.
function Cultivators.build(parent, cf, look, rarity, rarities)
	if typeof(look) == "number" then
		look = Cultivators.LOOKS[(look - 1) % #Cultivators.LOOKS + 1]
	end
	local tier = tierOf(rarity, rarities)
	local m = Instance.new("Model")
	m.Name = "Cultivator_" .. look
	m:SetAttribute("Look", look)
	m:SetAttribute("Rarity", rarity.name)
	P(m, Vector3.new(0.5, 3.2, 3.2), cf * CFrame.new(0, SEAT - 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), CUSHION, nil, Enum.PartType.Cylinder).Name = "Cushion"
	aura(m, cf, rarity.color, tier)
	m.Parent = parent
	task.spawn(function()
		local t = template(look, tier)
		if not t or not m.Parent then
			return -- the platform was rebuilt while the avatar loaded
		end
		local avatar = t:Clone()
		avatar.Name = "Avatar"
		avatar:PivotTo(cf * avatar:GetPivot())
		avatar.Parent = m
		CollectionService:AddTag(m, Cultivators.TAG)
	end)
	return m
end

return Cultivators
