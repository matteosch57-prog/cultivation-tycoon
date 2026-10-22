-- Seated cultivators for the Meditation Platform: real Roblox R15 avatars built from a
-- HumanoidDescription (catalog hanfu, hair, beard), posed cross-legged on their own joints (only the
-- root anchored). The client breathes them through the joints (CultivatorIdle.client.luau): no
-- animation upload needed.
-- Four looks (sword disciple, lotus maiden, pill monk, elder sage); the rarity picks the robe colour
-- and the aura tier. Front faces -Z (LookVector). `cf` is the ground point under the cushion.
-- Auras are layered glowing objects only (magic circles and spirit swords from free Creator Store
-- meshes, particles and trails with built-in textures, so nothing to upload): no Light instances (R3).
-- One piece joins per rarity; rates stay low and the client switches the layers off beyond a short
-- range, so a full platform stays cheap on phones.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Rig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rig"))

local Cultivators = {}

Cultivators.TAG = "Cultivator"
Cultivators.LOOKS = { "sword", "lotus", "monk", "elder" } -- = Config.DISCIPLE_LOOKS (a disciple keeps its look, D60)

local SKIN = Color3.fromRGB(238, 204, 176)
local CUSHION = Color3.fromHex("B8352B"):Lerp(Color3.new(0, 0, 0), 0.3)
local TEX = "rbxasset://textures/particles/"
local SPARKLE = TEX .. "sparkles_main.dds"
local RING = TEX .. "explosion01_shockwave_main.dds"
local GLOW = TEX .. "forcefield_glow_main.dds"
local WHITE = Color3.new(1, 1, 1)
local SEAT = 0.5 -- cushion top above the ground: the folded legs rest here, the client lifts them

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
		{ { 125031843258125, DRESS }, RED_CLOAK }, -- Ethereal Blossom flowing sleeves Hanfu Gown-Black under the red cloak
		{ { 73084763578818, DRESS } }, -- Ancient Gold Koi Empress Hanfu - Red (red-gold, the Emperor's colours)
		{ { 80805967098465, DRESS }, WHITE_CLOAK }, -- Chang'e's Moon Palace Flowing Hanfu-Creamy under the white cloak
	},
}

-- Roblox's own Man and Woman bodies (shaped limbs and hands, not the blocky default) and one anime
-- dynamic head for everyone (owner pick A + C, 2026-10-21: one cohesive style reads premium; a mix of
-- catalog faces read cheap). The head has FaceControls, so the client closes the eyes in meditation,
-- opens them to look at a player and blinks. Each look carries a signature item (sword, fan, flute, guqin).
local MAN = { Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078 }
local WOMAN = { Torso = 86499666, RightArm = 86499698, LeftArm = 86499716, LeftLeg = 86499753, RightLeg = 86499793 }

local ANIME = 14506610025 -- Anime Black - Dynamic Head (Marty_nas)
local WAIST, BACK, NECK = Enum.AccessoryType.Waist, Enum.AccessoryType.Back, Enum.AccessoryType.Neck
local LOOK = {
	-- Black Cultivator's Hair; Cultivator's Azure Cloud Sword at the waist
	sword = { robes = "male", body = MAN, head = ANIME, hair = { 10945619882 }, props = { { 10070649892, WAIST } } },
	-- Hair buns with Hairpins - Black; Wind Cultivator's Fan
	lotus = { robes = "female", body = WOMAN, head = ANIME, hair = { 113503254025840 }, props = { { 15197091452, NECK } } },
	-- Cultivator's Hair - Black; Cultivator's Black Bamboo Flute
	monk = { robes = "male", body = MAN, head = ANIME, hair = { 11639642608 }, props = { { 10070641659, WAIST } } },
	-- White Cultivator's Hair and the white beard; Cultivator's Cloud Guqin on the back
	elder = { robes = "male", body = MAN, head = ANIME, hair = { 12373799299 }, face = { 123149555491840 }, props = { { 10070655361, BACK } } },
}

-- the seated and flying poses (shared: the client turns the arms in the body's frame)
local POSES = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("CultivatorPoses"))

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

-- Ornaments grow with the rarity (owner 2026-10-22: "make sure clothing is good and evolving, same for
-- ornaments"): blossom hairpins for the lotus maiden from Inner, a jade bead necklace from Core, the
-- sun crown (Xi Guan) from Immortal and the great gold crown (Jin Guan) from Heavenly Emperor.
local HAT, NECKLACE = Enum.AccessoryType.Hat, Enum.AccessoryType.Neck
local HAIRPINS = { 14123045587, HAT } -- Traditional Blossom Hairpins in Red (kaixiuuu)
local JADE_BEADS = { 376527115, NECKLACE } -- Jade Necklace with Shell Pendant (Roblox)
local SUN_CROWN = { 94324972899443, HAT } -- Traditional Headpiece | Xi Guan (RUYI)
local GOLD_CROWN = { 105721861896087, HAT } -- Traditional Headpiece | Jin Guan (RUYI)
local function ornaments(look, tier)
	local list = {}
	if look == "lotus" and tier >= 2 and tier < 5 then
		table.insert(list, HAIRPINS)
	end
	if tier >= 3 and look ~= "lotus" then -- the fan already sits at the lotus maiden's neck
		table.insert(list, JADE_BEADS)
	end
	if tier >= 8 then
		table.insert(list, GOLD_CROWN)
	elseif tier >= 5 then
		table.insert(list, SUN_CROWN)
	end
	return list
end

local TROUSERS = Color3.fromHex("2B2530")

local function describe(look, tier)
	local spec = LOOK[look]
	local d = Instance.new("HumanoidDescription")
	for _, k in { "HeadColor", "LeftArmColor", "RightArmColor", "TorsoColor" } do
		d[k] = SKIN
	end
	-- The catalog robes are tops: they stop at the hips, so the folded legs showed bare skin (owner
	-- 2026-10-22: "why are legs out of clothing"). The legs are dark trousers instead; a classic hanfu
	-- pants texture was tried and painted white stripes down the shins.
	d.LeftLegColor, d.RightLegColor = TROUSERS, TROUSERS
	for k, id in spec.body do
		d[k] = id
	end
	d.Head = spec.head
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
	for _, prop in spec.props or {} do
		table.insert(list, { AssetId = prop[1], AccessoryType = prop[2], IsLayered = false })
	end
	for _, o in ornaments(look, tier) do
		table.insert(list, { AssetId = o[1], AccessoryType = o[2], IsLayered = false })
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

-- Pose the rig by walking its joint graph from the root: every part goes where its joint puts it
-- (new rigs have AnimationConstraints, not Motor6Ds). The same rotations are then baked into the
-- joints' rest frames (Rig.bake) and the rig stays live on its joints (Rig.live): the client moves
-- it through them, so the robes, hair and props follow (owner 2026-10-22).
local function pose(m, rot)
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
				at[e.b] = jointChild(e.j, at[e.a], rot[e.j.Name] or CFrame.identity)
				placed = true
			elseif at[e.b] and not at[e.a] then
				-- accessory welds run Handle -> body part: place the handle from the body
				local j = e.j
				at[e.a] = j:IsA("JointInstance") and at[e.b] * j.C1 * j.C0:Inverse() or at[e.b] * j.Attachment1.CFrame * j.Attachment0.CFrame:Inverse()
				placed = true
			end
		end
	end
	for p, cf in at do
		p.CFrame = cf
	end
	Rig.bake(m, rot)
	Rig.live(m)
end

-- posed templates, one per look and tier, built once per server and cloned
local templates, pending = {}, {}

local function template(look, tier, poseName)
	local key = look .. tier .. poseName
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
		pose(m, POSES[poseName])
		-- sit the lowest point of the folded legs on the cushion (a flyer's feet on its sword)
		local low = math.huge
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Handle" then
				low = math.min(low, p.Position.Y - p.Size.Y / 2)
			end
		end
		m:PivotTo(m:GetPivot() + Vector3.new(0, (poseName == "fly" and 0 or SEAT) - low, 0))
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

-- Aura colour: the rarity hue pushed to full saturation, lightening only a little at the end. The
-- first pass lerped 60% toward white and every aura read pale (owner 2026-10-21).
local function vivid(c)
	local h, sat, v = c:ToHSV()
	return Color3.fromHSV(h, math.max(sat, 0.85), math.max(v, 0.9))
end

local function seq(c)
	c = vivid(c)
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(1, c:Lerp(WHITE, 0.2)) })
end

local function fade(peak)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, peak), NumberSequenceKeypoint.new(0.75, peak), NumberSequenceKeypoint.new(1, 1) })
end

local function emitter(att, name, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	-- half additive: fully additive layers wash out to white over the pale floor and sky
	pe.LightEmission = 0.45
	pe.LightInfluence = 0
	pe.Brightness = 2
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

-- Free Creator Store meshes (inserted once 2026-10-21, no scripts in them; R12), drawn through
-- SpecialMesh so nothing is uploaded: a magic circle (115275786272862) and a stylized lotus
-- (14340580562). Scale = studs wanted / the mesh's native size.
local CIRCLE = { mesh = "rbxassetid://131419958270785", native = 3.97 }
local LOTUS = { mesh = "rbxassetid://14340526628", tex = "rbxassetid://14340559072", native = Vector3.new(22.23, 28.65, 22.23) }

-- The spirit sword (owner pick D, 2026-10-22: real steel, black and gold hilt, "an aura around it as
-- for the characters, and light orbs"): a free Creator Store jian (11269915624, no scripts; R12) drawn
-- piece by piece through SpecialMesh with its own colour maps, so nothing is uploaded. Pieces in the
-- sword's frame: tip along +X, `pos` / `size` in studs at scale 1, every piece turned (pi, 0, pi/2).
-- The steel stays steel: the rarity shows as a rim glow (Highlight) and orbs of light along the blade.
local JIAN = {
	{ mesh = 10956379807, tex = 10956397068, pos = Vector3.new(-2.1933, 0, 0), size = Vector3.new(0.3277, 1.1534, 0.2003), native = Vector3.new(2.9453, 10.3657, 1.8003) },
	{ mesh = 10956379653, tex = 10956397925, pos = Vector3.new(-2.1361, 0, 0), size = Vector3.new(0.3022, 1.2911, 0.1848), native = Vector3.new(2.7163, 11.6033, 1.6604) },
	{ mesh = 10956379960, tex = 10956521963, pos = Vector3.new(-1.4156, 0.0043, 0), size = Vector3.new(0.3997, 0.2257, 0.1245), native = Vector3.new(3.5918, 2.0289, 1.1193) },
	{ mesh = 10956379463, tex = 10956395160, pos = Vector3.new(-1.4274, 0.0035, 0), size = Vector3.new(0.3306, 0.1380, 0.1142), native = Vector3.new(2.9708, 1.2403, 1.0261) },
	{ mesh = 10956379290, tex = 10956398849, pos = Vector3.new(0.5989, -0.0006, 0.0018), size = Vector3.new(0.2460, 3.8839, 0.0492), native = Vector3.new(2.2110, 34.9053, 0.4419), blade = true },
}
local JIAN_MID = -0.12 -- the sword's middle along X (pommel -2.8 .. tip 2.55)
local JIAN_TURN = CFrame.Angles(math.pi, 0, math.pi / 2)

local function meshPart(m, name, size, cf, color, meshId, texId, scale)
	local p = P(m, size, cf, color, texId and Enum.Material.SmoothPlastic or Enum.Material.Neon)
	p.Name = name
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.FileMesh
	sm.MeshId = meshId
	sm.TextureId = texId or "" -- no texture: the Neon colour glows through the mesh
	sm.Scale = scale
	sm.Parent = p
	return p
end

-- One jian as a Model `name`: `cf` is its middle, tip along +Y; `k` scales it (1 = 5.35 studs).
local function jian(m, name, cf, color, k)
	local g = Instance.new("Model")
	g.Name = name
	local frame = cf * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(-JIAN_MID * k, 0, 0) -- +X (tip) to +Y
	for _, piece in JIAN do
		local size = piece.size * k
		local part = P(g, Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05)), frame * CFrame.new(piece.pos * k) * JIAN_TURN, WHITE)
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.FileMesh
		sm.MeshId = "rbxassetid://" .. piece.mesh
		sm.TextureId = "rbxassetid://" .. piece.tex
		sm.Scale = size / piece.native
		sm.Parent = part
		if piece.blade then
			-- light orbs drifting off the blade, in the rarity colour
			part.Name = "Blade"
			emitter(part, "BladeOrbs", {
				Texture = GLOW,
				Color = seq(color),
				LightEmission = 1,
				Brightness = 3,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3 * k), NumberSequenceKeypoint.new(1, 0) }),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(0.2, 0.5),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 5,
			})
		end
	end
	-- the aura: a rim glow in the rarity colour around the steel (as on the disciples)
	local h = Instance.new("Highlight")
	h.Name = "Aura"
	h.FillColor = vivid(color)
	h.FillTransparency = 0.82
	h.OutlineColor = vivid(color):Lerp(WHITE, 0.3)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = g
	g.Parent = m
	return g
end

-- a glowing magic circle of diameter d, lying flat (or standing, rotated by the caller)
local function circle(m, name, d, cf, color)
	return meshPart(m, name, Vector3.new(d, 0.1, d), cf, vivid(color), CIRCLE.mesh, nil, Vector3.new(d / CIRCLE.native, 2, d / CIRCLE.native))
end

-- Aura ladder (owner pick A + C, mocks docs/art/mocks/characters_AC2_*.jpg): one more piece per tier,
-- every piece in the rarity colour and light only (no solid balls; R3: glowing objects, no Lights).
--   2 a magic circle on the ground                 3 orbs of light circling at chest height, motes
--   4 the same circle as a halo behind the head    5 a fan of spirit swords behind the back (3)
--   6 a second, wider circle turning the other way, 5 swords
--   7 a lotus seat instead of the cushion, 7 swords 8 a ring pulse on each breath
--   9 every colour in turn (client), 9 swords
-- The client turns the circles, floats the halo and the swords with the figure and circles the orbs;
-- the body's rim glow (a Highlight) comes with the avatar.
local ORBS = { 0, 0, 3, 4, 5, 5, 7, 7, 9 }
local SWORDS = { 0, 0, 0, 0, 3, 5, 7, 7, 9 }
local function aura(m, f, color, tier, flying)
	if tier < 2 then
		return
	end
	local core = P(m, Vector3.new(3.4, 0.2, 3.4), f * CFrame.new(0, 1.2, 0), color)
	core.Transparency = 1
	core.Name = "Aura"
	local ground = attach(core, f, CFrame.new(0, 0.15, 0), "Ground")
	-- motes rise from a ring around the figure: an emitter on an attachment emits from a single point,
	-- inside the body, where the avatar hides every particle
	local shell = P(m, Vector3.new(4.4, 0.2, 4.4), f * CFrame.new(0, 1.3, 0), color)
	shell.Transparency = 1
	shell.Name = "AuraShell"
	if not flying then
		circle(m, "SigilCircle", 4.6 + tier * 0.6, f * CFrame.new(0, 0.06, 0), color).Transparency = 0.1
	end
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
		-- orbs of light: a glow sprite with a white heart and a short tail, no solid ball
		local count = ORBS[tier]
		for i = 0, count - 1 do
			local a = math.rad(90 + i * 360 / count)
			local orb = P(m, Vector3.new(0.3, 0.3, 0.3), f * CFrame.new(math.cos(a) * 2.8, 2.6 + (i % 2) * 0.5, math.sin(a) * 2.8), vivid(color))
			orb.Transparency = 1
			orb.Name = "AuraOrb" -- not "QiOrb": Juice bobs every QiOrb (the collectible orbs)
			-- a soft halo, a twinkling star heart, and sparkles left behind as a tail (a Trail drew
			-- glassy shards in Play)
			emitter(orb, "Glow", { Texture = GLOW, Color = seq(color), LightEmission = 1, Brightness = 3, LockedToPart = true, Speed = NumberRange.new(0), Size = NumberSequence.new(1.3), Transparency = NumberSequence.new(0), Lifetime = NumberRange.new(0.3), Rate = 40 })
			emitter(orb, "Heart", { Texture = SPARKLE, Color = ColorSequence.new(vivid(color):Lerp(WHITE, 0.55)), LightEmission = 1, Brightness = 4, LockedToPart = true, Speed = NumberRange.new(0), Size = NumberSequence.new(0.8), Lifetime = NumberRange.new(0.3), Rate = 40, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) })
			emitter(orb, "Tail", { Texture = SPARKLE, Color = seq(color), LightEmission = 1, Brightness = 3, Speed = NumberRange.new(0), Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.5, 0.7), Rate = 18 })
		end
	end
	if tier >= 4 then
		-- the halo stands behind the head (front is -Z); the client keeps it on the head as it floats
		local d = tier >= 5 and 3.2 or 2.6
		circle(m, "HaloCircle", d, f * CFrame.new(0, 5.15, 0.85) * CFrame.Angles(math.rad(90), 0, 0), color).Transparency = 0.05
		local head = attach(core, f, CFrame.new(0, 5.15, 0.75), "HaloAt")
		emitter(head, "HaloGlow", {
			Texture = GLOW,
			Color = seq(color),
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Size = NumberSequence.new(d * 0.9),
			Transparency = fade(0.7),
			Lifetime = NumberRange.new(3),
			Rate = 0.67,
			ZOffset = -2.5,
		})
	end
	if tier >= 5 then
		-- spirit swords in a fan behind the back, hilts toward the spine, tips out
		local n = SWORDS[tier]
		-- 65 degrees at most: wider, the outer swords crossed the shoulders and the face (Play 2026-10-22)
		local spread = math.rad(n >= 7 and 65 or (n >= 5 and 55 or 40))
		for i = 1, n do
			local ang = -spread + 2 * spread * (i - 1) / (n - 1)
			local k = 0.86
			local cf = f * CFrame.new(0, 3.3, 1.7) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.6 + 2.68 * k, 0)
			jian(m, "Sword", cf, color, k)
		end
	end
	if tier >= 6 and not flying then
		circle(m, "SigilCircle2", 8.5, f * CFrame.new(0, 0.05, 0), color).Transparency = 0.4
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
	if tier >= 9 then
		m:SetAttribute("Prismatic", true)
	end
end

-- the rim glow: a Highlight on the avatar in the rarity colour, stronger for rarer disciples (the
-- client switches it off beyond its glow range)
local function rim(avatar, color, tier)
	if tier < 3 then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "Rim"
	h.FillColor = vivid(color)
	h.FillTransparency = tier >= 5 and 0.78 or 0.88
	h.OutlineColor = vivid(color):Lerp(WHITE, 0.4)
	h.OutlineTransparency = tier >= 5 and 0 or 0.5
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = avatar
end

-- Build one cultivator. look: one of LOOKS (or an index), rarity: a Config.RARITIES entry.
-- Returns the model at once (cushion + aura); the avatar arrives a moment later, once its
-- catalog assets load, unless the model was destroyed meanwhile.
-- A standing, unposed copy for the arrival walk: joints live (the client's Animator plays Roblox's own
-- R15 walk on it), only the root anchored so the client can carry it along the path.
local walkers, walkerPending = {}, {}
local function walkerTemplate(look, tier)
	local key = look .. tier
	if walkers[key] then
		return walkers[key]
	end
	if walkerPending[key] then
		table.insert(walkerPending[key], coroutine.running())
		return coroutine.yield()
	end
	walkerPending[key] = {}
	local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, describe(look, tier), Enum.HumanoidRigType.R15)
	if ok then
		local hum = m:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
		Rig.live(m) -- only the root anchored; streams in whole
		walkers[key] = m
	else
		warn("[Cultivators] walker build failed", look, tier, m)
		m = nil
	end
	local waiting = walkerPending[key]
	walkerPending[key] = nil
	for _, co in waiting do
		task.spawn(co, m)
	end
	return m
end

Cultivators.WALK_FROM = 14 -- studs behind the cushion where an arriving recruit appears

function Cultivators.build(parent, cf, look, rarity, rarities, opts)
	local poseName = opts and opts.pose or "seated"
	local flying = poseName == "fly"
	if typeof(look) == "number" then
		look = Cultivators.LOOKS[(look - 1) % #Cultivators.LOOKS + 1]
	end
	local tier = tierOf(rarity, rarities)
	local m = Instance.new("Model")
	m.Name = "Cultivator_" .. look
	m:SetAttribute("Look", look)
	m:SetAttribute("Rarity", rarity.name)
	m:SetAttribute("Pose", poseName)
	-- the cushion rests on the ground: the cultivator floats above it (client); from Dao Ancestor up a
	-- lotus in bloom (its stem sinks under the floor). A flyer stands on a big spirit sword lying
	-- point forward (-Z), its blade glowing in the rarity colour, wind streaming off it.
	if flying then
		-- lying flat, tip forward (-Z), its broad side up under the feet
		local mount = jian(m, "MountSword", cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0), rarity.color, 1.85)
		local wake = Instance.new("Attachment")
		wake.Position = Vector3.new(0, -0.05, 0)
		wake.Parent = mount:FindFirstChild("Blade")
		emitter(wake, "Wind", {
			Texture = SPARKLE,
			Color = seq(rarity.color),
			LightEmission = 1,
			Size = NumberSequence.new(0.5, 0),
			Speed = NumberRange.new(6, 9),
			Lifetime = NumberRange.new(0.4, 0.7),
			SpreadAngle = Vector2.new(12, 12),
			Rate = 22,
		})
	elseif tier >= 7 then
		local k = 4.9 / LOTUS.native.X
		local size = LOTUS.native * k
		meshPart(m, "Cushion", size, cf * CFrame.new(0, 1.25 - size.Y / 2, 0), WHITE, LOTUS.mesh, LOTUS.tex, Vector3.one * k)
	else
		P(m, Vector3.new(0.5, 3.2, 3.2), cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), CUSHION, nil, Enum.PartType.Cylinder).Name = "Cushion"
	end
	aura(m, cf, rarity.color, tier, flying)
	m.Parent = parent
	task.spawn(function()
		local t = template(look, tier, poseName)
		if not t or not m.Parent then
			return -- the platform was rebuilt while the avatar loaded
		end
		local avatar = t:Clone()
		avatar.Name = "Avatar"
		avatar:PivotTo(cf * avatar:GetPivot())
		rim(avatar, rarity.color, tier)
		avatar.Parent = m
		-- a new recruit walks in (owner 2026-10-22: "arrival is ok"): a standing copy waits behind
		-- the cushion; the client walks it in, bows, then swaps it for the seated figure
		if opts and opts.arrive then
			local w = walkerTemplate(look, tier)
			if w and m.Parent then
				local walker = w:Clone()
				walker.Name = "Walker"
				-- front is -Z: behind the cushion is +Z; feet on the ground (root at hip height)
				local root = walker:FindFirstChild("HumanoidRootPart")
				local hum = walker:FindFirstChildOfClass("Humanoid")
				local up = (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
				walker:PivotTo(cf * CFrame.new(0, up, Cultivators.WALK_FROM))
				walker.Parent = m
				m:SetAttribute("ArrivedAt", workspace:GetServerTimeNow())
				task.delay(20, function()
					if walker.Parent then
						walker:Destroy() -- late joiners only ever see the seated figure
					end
				end)
			end
		end
		CollectionService:AddTag(m, Cultivators.TAG)
	end)
	return m
end

return Cultivators
