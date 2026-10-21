-- Seated cultivators for the Meditation Platform: real Roblox R15 avatars built from a
-- HumanoidDescription (catalog hanfu, hair, beard), posed cross-legged and anchored. The client
-- breathes them (CultivatorIdle.client.luau): no animation upload needed.
-- Four looks (sword disciple, lotus maiden, pill monk, elder sage); the rarity picks the robe colour
-- and the aura tier. Front faces -Z (LookVector). `cf` is the ground point under the cushion.
-- Auras are glowing objects only (particles, ForceField shells): no Light instances (RULES R3),
-- one emitter per figure at most so a full platform stays cheap on phones.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Cultivators = {}

Cultivators.TAG = "Cultivator"
Cultivators.LOOKS = { "sword", "lotus", "monk", "elder" }

local SKIN = Color3.fromRGB(238, 204, 176)
local CUSHION = Color3.fromHex("B8352B"):Lerp(Color3.new(0, 0, 0), 0.3)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SEAT = 1.8 -- cushion top above the ground

-- Catalog layered clothing (any experience may dress an NPC in it). Index = rarity tier 1..5:
-- white, green, blue, purple, gold. Creator: Lucky Koi unless noted. Checked as captures, since
-- a dark robe hides the rarity colour.
local ROBES = {
	male = {
		{ 79303524577143, Enum.AccessoryType.Shirt }, -- Male Long Robe Hanfu-White
		{ 100632011366877, Enum.AccessoryType.Shirt }, -- Male Wuxia Hanfu-Green (the long robe green read black)
		{ 138259484709999, Enum.AccessoryType.Shirt }, -- Male Wuxia Hanfu-Blue (the long robe blue read black)
		{ 88444695833424, Enum.AccessoryType.Shirt }, -- Male Long Robe Hanfu-Purple
		{ 113946197012814, Enum.AccessoryType.Shirt }, -- Male Wuxia Hanfu-Gold
	},
	female = {
		{ 12388422808, Enum.AccessoryType.DressSkirt }, -- White Cultivator's Robes (Nexus Exchange)
		{ 76684958127170, Enum.AccessoryType.DressSkirt }, -- Flowing Cloud Hanfu Robe-Green
		{ 124497512666896, Enum.AccessoryType.DressSkirt }, -- Empress Hanfu Robe - Sapphire
		{ 136565350420707, Enum.AccessoryType.DressSkirt }, -- Hanfu-Inspired Imperial Gown-Purple
		{ 124671367097250, Enum.AccessoryType.DressSkirt }, -- Flowing Cloud Hanfu Robe-Gold
	},
}

local LOOK = {
	sword = { robes = "male", hair = { 101082692371776 } }, -- Xianxia Low Ponytail - Black
	lotus = { robes = "female", hair = { 113503254025840 } }, -- Hair buns with Hairpins - Black
	monk = { robes = "male", hair = {} }, -- shaved head
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
	local robe = ROBES[spec.robes][tier]
	local list = { { AssetId = robe[1], AccessoryType = robe[2], IsLayered = true, Order = 1 } }
	for _, id in spec.hair do
		table.insert(list, { AssetId = id, AccessoryType = Enum.AccessoryType.Hair, IsLayered = false })
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

-- aura tiers: 1 none, 2 a small ground ring, 3 a wide ring + rising motes, 4 + halo, 5 + three qi orbs
local function aura(m, f, color, tier)
	if tier < 2 then
		return
	end
	if tier >= 3 then
		local core = P(m, Vector3.new(3.4, 0.2, 3.4), f * CFrame.new(0, 1.2, 0), color)
		core.Transparency = 1
		core.Name = "Aura"
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SPARKLE
		pe.Color = ColorSequence.new(color)
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5 + tier * 0.15), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.15)
		pe.Lifetime = NumberRange.new(2.5, 3.5)
		pe.Speed = NumberRange.new(0.8, 1.4)
		pe.Acceleration = Vector3.new(0, 0.4, 0)
		pe.Rate = ({ 0, 0, 5, 7, 10 })[tier]
		pe.SpreadAngle = Vector2.new(15, 15)
		pe.Shape = Enum.ParticleEmitterShape.Disc
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = core
	end
	local d = tier == 2 and 3.8 or 4.6
	local ring = P(m, Vector3.new(0.1, d, d), f * CFrame.new(0, 1.32, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.ForceField, Enum.PartType.Cylinder)
	ring.Name = "AuraRing"
	if tier >= 4 then
		local halo = P(m, Vector3.new(0.1, 3.4, 3.4), f * CFrame.new(0, 5.2, 0.7) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.ForceField, Enum.PartType.Cylinder)
		halo.Name = "Halo"
	end
	if tier >= 5 then
		for i = 0, 2 do
			local a = math.rad(90 + i * 120)
			local orb = P(m, Vector3.new(0.4, 0.4, 0.4), f * CFrame.new(math.cos(a) * 2.4, 4.2 + (i % 2) * 0.6, math.sin(a) * 2.4), color, Enum.Material.Neon, Enum.PartType.Ball)
			orb.Name = "QiOrb"
		end
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
